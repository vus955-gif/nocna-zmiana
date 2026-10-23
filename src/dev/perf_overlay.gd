extends CanvasLayer
## The dev performance overlay (autoload "PerfOverlay", F3; backlog #59).
## F3 cycles: off -> numbers -> numbers + systems. It works in dev builds
## (OS.is_debug_build()) and, in any build, with the option "developer tools".
## Off it costs nothing: hidden, not processing, nothing measured.
## - Numbers (right edge, in the HUD's plaque style, refreshed 4 times a
##   second): fps and frame time with the last frames as a graph, the CPU time
##   of the physics tick (the nodes' _physics_process and the physics server's
##   step: physics_frame to process_frame) and of the idle callbacks (_process,
##   timers, deferred calls: process_frame to the renderer's frame_pre_draw,
##   in a window; to the next physics tick headless - the engine's own
##   monitors keep the worst frame of the last second and, in a window, count
##   the wait for the vsync, so they say little), the renderer's CPU and GPU time (measured only
##   while the overlay is up; "-" when the driver gives none), draw calls,
##   objects and triangles, the lamps and shadows the room culling keeps on,
##   the awake exhibits and the guardians in a fight, physics bodies,
##   memory, nodes, the room the guard is in, what perception costs, the
##   pipelines compiled (each one that happens in a frame is a hitch).
## - Systems (left of the numbers): script time per subsystem, from
##   CpuSections: the dearest first, with what the engine and everything
##   unnamed adds up to. It changes the order callbacks run in a little
##   (see CpuSections), which is why it is the third step.
## The same readings are in PerfStats; the headless counterpart that times
## a whole night is tools/run_cpu_profile.sh.

enum Mode { OFF, NUMBERS, SYSTEMS }

## Seconds between two refreshes of the numbers.
const REFRESH := 0.25
## Frames kept for the graph and the average (about two seconds).
const GRAPH_FRAMES := 120
## Seconds between two looks for exhibits that joined a section.
const RESCAN := 2.0
const SYSTEMS_SHOWN := 8
const TEXT_SIZE := 18
const PANEL_WIDTH := 440.0
const SYSTEMS_WIDTH := 420.0
## A bar of the systems list is full at this many ms.
const BAR_MS := 6.0
const BAR_WIDTH := 120.0
const LAYER_ABOVE_ALL := 110

## The rows of the numbers: [key, caption text key].
const ROWS: Array = [
	["frame", "PERF_FRAME"], ["script", "PERF_SCRIPT"], ["physics", "PERF_PHYSICS"], ["render_cpu", "PERF_RENDER_CPU"],
	["render_gpu", "PERF_RENDER_GPU"], ["draw", "PERF_DRAW"], ["geometry", "PERF_GEOMETRY"], ["lights", "PERF_LIGHTS"],
	["rooms", "PERF_ROOMS"], ["ai", "PERF_AI"], ["guardians", "PERF_GUARDIANS"], ["environment", "PERF_ENVIRONMENT"], ["bodies", "PERF_BODIES"],
	["memory", "PERF_MEMORY"], ["nodes", "PERF_NODES"], ["place", "PERF_PLACE"], ["perception", "PERF_PERCEPTION"],
	["pipelines", "PERF_PIPELINES"],
]

var mode: Mode = Mode.OFF
## A dev build (an exported release says false; tests set it).
var debug_build: bool = OS.is_debug_build()
## The subsystems' timing while the systems view is up (null otherwise).
var sections: CpuSections = null

var _root: Control
var _row_box: HBoxContainer
var _numbers: PanelContainer
var _systems: PanelContainer
var _head: Label
var _hint: Label
var _graph: PerfGraph
var _captions: Dictionary = {}
var _values: Dictionary = {}
var _system_rows: Array[Dictionary] = []
var _system_rest: Label
var _systems_title: Label
## Frame times (ms) of the last GRAPH_FRAMES frames (a ring).
var _frames := PackedFloat32Array()
var _head_index: int = 0
var _since_refresh: float = 0.0
var _since_rescan: float = 0.0
var _room: StringName = &""
var _zone: StringName = &""
var _measuring_render := false
var _owns_profiling := false
var _last_stats := {"looks": 0, "rays": 0, "look_usec": 0}
var _last_stats_msec: int = 0
var _shown_ms: Dictionary = {}
## Timing of the physics tick and the idle callbacks since the last refresh
## (microseconds: sum, worst, count), from the tree's frame signals.
var _stamp_physics: int = 0
var _stamp_frame: int = 0
var _hooked := false
var _physics_total := [0, 0, 0]
var _idle_total := [0, 0, 0]


func _ready() -> void:
	layer = LAYER_ABOVE_ALL
	process_mode = Node.PROCESS_MODE_ALWAYS
	_frames.resize(GRAPH_FRAMES)
	_build()
	visible = false
	set_process(false)
	Events.room_entered.connect(_on_room_entered)
	Settings.settings_changed.connect(_on_settings_changed)
	get_tree().scene_changed.connect(_on_scene_changed)
	if OS.get_cmdline_user_args().has("--perf") and allowed():
		set_mode.call_deferred(Mode.NUMBERS)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_perf") and not event.is_echo():
		cycle()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	set_mode(Mode.OFF)


## The overlay may be up: a dev build, or the option "developer tools" is on.
func allowed() -> bool:
	return debug_build or Settings.data.dev_tools


## F3: the next view (nothing when the overlay is not allowed).
func cycle() -> void:
	if not allowed():
		return
	var next: int = (int(mode) + 1) % Mode.size()
	set_mode(next as Mode)


func set_mode(wanted: Mode) -> void:
	if wanted != Mode.OFF and not allowed():
		wanted = Mode.OFF
	mode = wanted
	var on := mode != Mode.OFF
	visible = on
	set_process(on)
	if _systems != null:
		_systems.visible = mode == Mode.SYSTEMS
	_measure(on)
	_hook(on)
	if mode == Mode.SYSTEMS:
		_install_sections()
	else:
		_remove_sections()
	if on and _hint != null:
		_hint.text = tr("PERF_HINT_NUMBERS" if mode == Mode.NUMBERS else "PERF_HINT_SYSTEMS")
		_since_refresh = REFRESH
		refresh()


func _process(delta: float) -> void:
	_frames[_head_index] = delta * 1000.0
	_head_index = (_head_index + 1) % GRAPH_FRAMES
	_since_refresh += delta
	if mode == Mode.SYSTEMS and sections != null:
		_since_rescan += delta
		if _since_rescan >= RESCAN:
			_since_rescan = 0.0
			sections.rescan(true)
	if _since_refresh >= REFRESH:
		_since_refresh = 0.0
		refresh()


## Reads everything once and writes the numbers.
func refresh() -> void:
	var m := PerfStats.monitors()
	var times := PerfStats.render_times(get_viewport())
	var ai := PerfStats.ai(get_tree())
	var lamps := PerfStats.lights(get_tree())
	var average := 0.0
	var worst := 0.0
	var counted := 0
	for ms in _frames:
		if ms > 0.0:
			average += ms
			worst = maxf(worst, ms)
			counted += 1
	average /= maxf(counted, 1)
	_graph.frames = _frames
	_graph.head = _head_index
	_graph.queue_redraw()
	var fps := roundi(m["fps"])
	_head.text = "%d FPS   %.1f ms" % [fps, 1000.0 / maxf(m["fps"], 1.0)]
	_head.add_theme_color_override("font_color", UiTheme.DANGER if fps < 30 else (UiTheme.ACCENT if fps < 55 else UiTheme.GOOD))
	_show(&"frame", "%.1f / %.1f ms" % [average, worst], worst > PerfGraph.FRAME_30)
	_show(&"script", _take(_idle_total))
	_show(&"physics", _take(_physics_total))
	_show(&"render_cpu", ("%.1f ms" % times.x) if times.x > 0.0 else "—")
	_show(&"render_gpu", ("%.1f ms" % times.y) if times.y > 0.0 else "—", times.y > PerfGraph.FRAME_60)
	_show(&"draw", compact(m["draw_calls"]))
	_show(&"geometry", "%s · %s" % [compact(m["objects"]), compact(m["primitives"])])
	if lamps.is_empty():
		_show(&"lights", "—")
		_show(&"rooms", "—")
	else:
		_show(&"lights", "%d (%d) z %d" % [lamps["lamps_on"], lamps["shadows_on"], lamps["lamps"]])
		_show(&"rooms", "%d z %d" % [lamps["rooms_on"], lamps["rooms"]])
	_show(&"ai", "%d · %d  z %d" % [ai["awake"], ai["hunting"], ai["exhibits"]])
	_show(&"guardians", "%d z %d" % [ai["guardians_fighting"], ai["guardians"]])
	var env := PerfStats.environment(get_tree())
	_show(&"environment", ("%d · %d  z %d" % [env["active"], env["down"], env["props"]]) if not env.is_empty() else "—")
	_show(&"bodies", "%d · %d" % [m["bodies"], m["pairs"]])
	_show(&"memory", "%s · %s" % [PerfStats.megabytes(m["memory"]), PerfStats.megabytes(m["video_memory"]) if m["video_memory"] > 0 else "—"])
	_show(&"nodes", "%s (%d)" % [compact(m["nodes"]), m["orphans"]], m["orphans"] > 0)
	_show(&"place", ("%s · %s" % [_room, _zone]) if _room != &"" else "—")
	_show(&"perception", _perception_text())
	_show(&"pipelines", str(m["pipelines"]))
	if mode == Mode.SYSTEMS:
		_refresh_systems(m)


## A big count as "12.3k" / "1.2 M".
static func compact(count: int) -> String:
	if count >= 1000000:
		return "%.1f M" % (count / 1000000.0)
	if count >= 10000:
		return "%.1fk" % (count / 1000.0)
	return str(count)


## The text of one row's value, as shown (tests read it).
func value_text(key: StringName) -> String:
	return (_values[key] as Label).text if _values.has(key) else ""


func _show(key: StringName, text: String, warn: bool = false) -> void:
	var label: Label = _values[key]
	label.text = text
	label.add_theme_color_override("font_color", UiTheme.DANGER if warn else UiTheme.TEXT)


func _perception_text() -> String:
	var now := Time.get_ticks_msec()
	var seconds := (now - _last_stats_msec) / 1000.0
	var stats := PerceptionWorld.stats
	var text := "—"
	if seconds > 0.0 and _last_stats_msec > 0 and PerceptionWorld.profiling:
		var looks := float(int(stats["looks"]) - int(_last_stats["looks"])) / seconds
		var rays := float(int(stats["rays"]) - int(_last_stats["rays"])) / seconds
		var milli := float(int(stats["look_usec"]) - int(_last_stats["look_usec"])) / seconds / 1000.0
		text = "%d/s · %d/s · %.2f ms" % [roundi(looks), roundi(rays), milli]
	_last_stats = {"looks": int(stats["looks"]), "rays": int(stats["rays"]), "look_usec": int(stats["look_usec"])}
	_last_stats_msec = now
	return text


# --- the systems view ---

func _install_sections() -> void:
	_remove_sections()
	var scene := _game_scene()
	if scene == null:
		return
	sections = CpuSections.new()
	add_child(sections)
	MuseumSections.setup(sections, scene)
	sections.install()
	_shown_ms.clear()
	_since_rescan = 0.0


func _remove_sections() -> void:
	if sections != null:
		sections.uninstall()
		sections.queue_free()
		sections = null


## The scene the game runs in (the Museum, or any scene with a level).
func _game_scene() -> Node:
	var level := AudioContext.level(get_tree())
	if level != null and level.get_parent() != null:
		return level.get_parent()
	return get_tree().current_scene


func _refresh_systems(m: Dictionary) -> void:
	if sections == null:
		_systems_title.text = tr("PERF_SYSTEMS_NONE")
		for row in _system_rows:
			(row["box"] as Control).visible = false
		_system_rest.text = ""
		return
	_systems_title.text = tr("PERF_SYSTEMS")
	var report := sections.report()
	var ranked := sections.ranked()
	var named_idle := 0.0
	var named_physics := 0.0
	for i in _system_rows.size():
		var row: Dictionary = _system_rows[i]
		var box: Control = row["box"]
		if i >= ranked.size():
			box.visible = false
			continue
		var section := ranked[i]
		var idle := _smooth(section, "idle", report[section]["idle_ms"])
		var physics := _smooth(section, "physics", report[section]["physics_ms"])
		box.visible = true
		(row["title"] as Label).text = tr("PERF_SYS_" + String(section).to_upper())
		(row["ms"] as Label).text = "%.2f · %.2f" % [idle, physics]
		(row["bar"] as ColorRect).size = Vector2(clampf((idle + physics) / BAR_MS, 0.02, 1.0) * BAR_WIDTH, 10.0)
	for section in ranked:
		named_idle += report[section]["idle_ms"]
		named_physics += report[section]["physics_ms"]
	_system_rest.text = tr("PERF_SYS_REST") % [named_idle, named_physics]
	sections.reset()


## The value eased toward the new reading (windows of a quarter second jump).
func _smooth(section: StringName, kind: String, value: float) -> float:
	var key := "%s/%s" % [section, kind]
	var shown: float = lerpf(float(_shown_ms.get(key, value)), value, 0.4)
	_shown_ms[key] = shown
	return shown


# --- what the overlay listens to ---

func _on_room_entered(room: StringName, zone: StringName, _first: bool) -> void:
	_room = room
	_zone = zone


func _on_settings_changed(key: StringName) -> void:
	if (key == &"dev_tools" or key == &"") and mode != Mode.OFF and not allowed():
		set_mode(Mode.OFF)


func _on_scene_changed() -> void:
	_room = &""
	_zone = &""
	if mode == Mode.SYSTEMS:
		_install_sections.call_deferred()


## The frame signals are listened to only while the overlay is up.
func _hook(on: bool) -> void:
	if on == _hooked or not is_inside_tree():
		return
	_hooked = on
	var tree := get_tree()
	if on:
		tree.physics_frame.connect(_on_physics_frame)
		tree.process_frame.connect(_on_process_frame)
		RenderingServer.frame_pre_draw.connect(_on_pre_draw)
		_physics_total = [0, 0, 0]
		_idle_total = [0, 0, 0]
		_stamp_physics = 0
		_stamp_frame = 0
	else:
		tree.physics_frame.disconnect(_on_physics_frame)
		tree.process_frame.disconnect(_on_process_frame)
		RenderingServer.frame_pre_draw.disconnect(_on_pre_draw)


func _on_physics_frame() -> void:
	var now := Time.get_ticks_usec()
	# headless nothing draws: the idle callbacks end where the next tick starts
	if _stamp_frame > 0 and not PerfStats.renders():
		_add(_idle_total, now - _stamp_frame)
		_stamp_frame = 0
	_stamp_physics = now


func _on_process_frame() -> void:
	var now := Time.get_ticks_usec()
	if _stamp_physics > 0:
		_add(_physics_total, now - _stamp_physics)
		_stamp_physics = 0
	_stamp_frame = now


func _on_pre_draw() -> void:
	if _stamp_frame > 0:
		_add(_idle_total, Time.get_ticks_usec() - _stamp_frame)
		_stamp_frame = 0


static func _add(total: Array, microseconds: int) -> void:
	total[0] += microseconds
	total[1] = maxi(total[1], microseconds)
	total[2] += 1


## "mean (max m)" of a window's ticks in ms, and the window starts anew.
static func _take(total: Array) -> String:
	var text := "—"
	if total[2] > 0:
		text = "%.1f ms (max %.1f)" % [total[0] / 1000.0 / total[2], total[1] / 1000.0]
	total[0] = 0
	total[1] = 0
	total[2] = 0
	return text


func _measure(on: bool) -> void:
	if on != _measuring_render and is_inside_tree():
		_measuring_render = on
		PerfStats.measure_render(get_tree().root, on)
	if on and not PerceptionWorld.profiling:
		PerceptionWorld.profiling = true
		_owns_profiling = true
		_last_stats_msec = 0
	elif not on and _owns_profiling:
		PerceptionWorld.profiling = false
		_owns_profiling = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _numbers != null:
		for key: StringName in _captions:
			(_captions[key] as Label).text = tr((_captions[key] as Label).get_meta(&"text_key"))
		if mode != Mode.OFF:
			_hint.text = tr("PERF_HINT_NUMBERS" if mode == Mode.NUMBERS else "PERF_HINT_SYSTEMS")


# --- building ---

func _build() -> void:
	_root = Control.new()
	_root.theme = UiTheme.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_row_box = HBoxContainer.new()
	_row_box.add_theme_constant_override("separation", 12)
	_row_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_row_box)
	_row_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	_row_box.offset_top = 130.0
	_row_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_systems = _panel(SYSTEMS_WIDTH)
	_row_box.add_child(_systems)
	_numbers = _panel(PANEL_WIDTH)
	_row_box.add_child(_numbers)
	_build_numbers()
	_build_systems()


func _panel(width: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiTheme.plaque(UiTheme.Plaque.HUD))
	return panel


func _build_numbers() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_numbers.add_child(column)
	_head = UiTheme.label("", 28, UiTheme.GOOD, UiTheme.number_font())
	column.add_child(_head)
	_graph = PerfGraph.new()
	_graph.custom_minimum_size = Vector2(0, 46)
	_graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_graph)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 2)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(grid)
	for row: Array in ROWS:
		var caption := UiTheme.label(tr(row[1]), TEXT_SIZE, UiTheme.MUTED)
		caption.set_meta(&"text_key", row[1])
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(caption)
		_captions[StringName(row[0])] = caption
		var value := UiTheme.label("", TEXT_SIZE, UiTheme.TEXT, UiTheme.strong_font())
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(value)
		_values[StringName(row[0])] = value
	_hint = UiTheme.caption("", 14)
	column.add_child(_hint)


func _build_systems() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_systems.add_child(column)
	_systems_title = UiTheme.caption("", 16)
	column.add_child(_systems_title)
	for i in SYSTEMS_SHOWN:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 10)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var title := UiTheme.label("", TEXT_SIZE)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(title)
		var bar := ColorRect.new()
		bar.color = Color(UiTheme.ACCENT, 0.85)
		bar.custom_minimum_size = Vector2(2.0, 10.0)
		bar.size = Vector2(2.0, 10.0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bar_slot := Control.new()
		bar_slot.custom_minimum_size = Vector2(BAR_WIDTH, 10.0)
		bar_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_slot.add_child(bar)
		box.add_child(bar_slot)
		var ms := UiTheme.label("", TEXT_SIZE, UiTheme.TEXT, UiTheme.strong_font())
		ms.custom_minimum_size = Vector2(100, 0)
		ms.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		box.add_child(ms)
		column.add_child(box)
		_system_rows.append({"box": box, "title": title, "bar": bar, "ms": ms})
	_system_rest = UiTheme.label("", 16, UiTheme.MUTED)
	_system_rest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_system_rest)
