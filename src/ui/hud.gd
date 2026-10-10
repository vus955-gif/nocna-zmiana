class_name Hud
extends CanvasLayer
## Guard HUD built in code: health + stamina (bottom left), weapon + ammo
## (bottom right), crosshair with hit markers, damage vignette, death
## notice, FPS counter and the F1 help panel. In the museum also: the
## night's card at its start (number, modifier), the clock next to the
## night number, the night's goal with the fuse icons under it, a hint line
## near the bottom (a note read, a first-time tip) and the boss's health
## bar at the top (bound through Events.boss_awakened). Above the weapon's
## name a row of slot numbers 1-8: the weapons found so far, the one in
## hand lit. Hints from the world (a lock hit with the wrong tool) come in
## through Events.hint_requested.
## On Floor I (enable_floor()): a small card with the room's name in its
## wing's colour on a first visit, the crystal shards under the goal, and a
## wing guardian's bar with its name and title (Events.guardian_awakened).

const HIT_COLOR := Color(1.0, 1.0, 1.0)
const WEAK_POINT_COLOR := Color(1.0, 0.8, 0.2)
const KILL_COLOR := Color(1.0, 0.25, 0.2)
const BLOCKED_COLOR := Color(0.6, 0.6, 0.6)
const DUST_COLOR := Color(1.0, 0.84, 0.5)
## Seconds the "+n" of a Dust gain stays up (it fades in the last half).
const GAIN_TIME := 1.6
const TOAST_COLOR := Color(0.93, 0.9, 0.84)
## Seconds a toast / a warning stays up (both fade in the last 0.6 s).
const TOAST_TIME := 2.2
const WARNING_TIME := 4.0
## The card at a night's start: seconds on screen, fading in and out.
const CARD_TIME := 5.0
const CARD_FADE_IN := 0.6
const CARD_FADE_OUT := 1.2
## Seconds a hint line stays up by default (it fades in the last 0.6 s).
const HINT_TIME := 6.0
const OBJECTIVE_COLOR := Color(0.93, 0.9, 0.84, 0.92)
const BOSS_COLOR := Color(0.86, 0.14, 0.1)
## Health fractions where the boss's phases change (ticks on its bar).
const BOSS_PHASES: Array[float] = [0.66, 0.33]
## Seconds a world hint (a lock's) stays under the crosshair.
const WORLD_HINT_TIME := 3.5
## Slot numbers: owned, in hand, not found yet.
const SLOT_OWNED := Color(0.93, 0.9, 0.84, 0.8)
const SLOT_EMPTY := Color(0.93, 0.9, 0.84, 0.16)

var player: Player
## Translation keys of the F1 help panel, one paragraph each (the sandbox
## adds its spawn keys).
var help_keys: PackedStringArray = ["HUD_HELP_CONTROLS_P1", "HUD_HELP_TIPS"]
## The night's carried Dust (top right); the sandbox has none.
var show_dust: bool = false
## FPS counter regardless of the option (dev scenes).
var always_show_fps: bool = false
## Night number shown top left (0 = none, the sandbox).
var night: int = 0

var _health_label: Label
var _health_bar: ProgressBar
var _stamina_bar: ProgressBar
## Flashlight battery (under the stamina bar).
var _torch_bar: ProgressBar
var _weapon_label: Label
var _ammo_label: Label
## Slot numbers 1-8 above the weapon's name.
var _slots: HBoxContainer
var _slot_labels: Array[Label] = []
var _battery_bar: ProgressBar
var _crosshair: Crosshair
var _vignette: TextureRect
var _death_label: Label
var _fps_label: Label
var _help: PanelContainer
var _help_label: Label
var _prompt: PanelContainer
var _prompt_key: Label
var _prompt_label: Label
var _dust_box: VBoxContainer
var _dust_row: HBoxContainer
var _dust_label: Label
var _dust_gain: Label
var _gain_amount: int = 0
var _gain_left: float = 0.0
var _bump: float = 0.0
var _night_box: VBoxContainer
var _night_label: Label
var _clock_label: Label
var _objective_row: HBoxContainer
var _objective_label: Label
var _fuse_icons: FuseIcons
var _help_hint: Label
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _boss_ticks: Control
var _boss: Node = null
var _boss_fade: float = 0.0
var _toast: Label
var _toast_left: float = 0.0
var _card: VBoxContainer
var _card_title: Label
var _card_subtitle: Label
var _card_detail: Label
var _card_time: float = INF
var _hint: PanelContainer
var _hint_label: Label
var _hint_left: float = 0.0
## Floor I (built by enable_floor()).
var _room_card: RoomCard = null
var _shards_label: Label = null


## Two small fuses under the night's goal: outlined while missing, amber
## in the guard's pocket, glowing green once in the fuse box.
class FuseIcons extends Control:
	const SIZE := Vector2(12, 26)
	const GAP := 8.0
	var carried: int = 0
	var inserted: int = 0

	func _init() -> void:
		custom_minimum_size = Vector2(SIZE.x * 2.0 + GAP, SIZE.y)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_counts(in_pocket: int, in_box: int) -> void:
		carried = in_pocket
		inserted = in_box
		queue_redraw()

	func _draw() -> void:
		for i in 2:
			var rect := Rect2(Vector2(i * (SIZE.x + GAP), (size.y - SIZE.y) * 0.5), SIZE)
			var body := rect.grow_individual(0, -4, 0, -4)
			if i < inserted:
				draw_rect(body, Color(0.35, 1.0, 0.5, 0.95))
			elif i < inserted + carried:
				draw_rect(body, Color(1.0, 0.72, 0.35, 0.95))
			else:
				draw_rect(body, Color(0.0, 0.0, 0.0, 0.35))
				draw_rect(body, Color(0.93, 0.9, 0.84, 0.55), false, 1.5)
			for cap in [rect.position.y, rect.end.y - 4.0]:
				draw_rect(Rect2(rect.position.x + 2.0, cap, SIZE.x - 4.0, 4.0), Color(0.78, 0.62, 0.3, 0.9))


class Crosshair extends Control:
	const MARKER_TIME := 0.2
	var marker_time: float = 0.0
	var marker_color: Color = Color.WHITE

	func show_marker(color: Color) -> void:
		marker_color = color
		marker_time = MARKER_TIME
		queue_redraw()

	func _process(delta: float) -> void:
		if marker_time > 0.0:
			marker_time = maxf(marker_time - delta, 0.0)
			queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		draw_circle(center, 3.5, Color(0.0, 0.0, 0.0, 0.6))   # outline: readable on pale walls
		draw_circle(center, 2.5, Color(1.0, 1.0, 1.0, 0.9))
		if marker_time <= 0.0:
			return
		var color := Color(marker_color, marker_time / MARKER_TIME)
		for corner in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(center + corner * 7.0, center + corner * 15.0, color, 3.0, true)


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_vignette = _make_vignette()
	root.add_child(_vignette)
	_crosshair = Crosshair.new()
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_crosshair)

	var left := VBoxContainer.new()
	_health_label = _label(30)
	_health_bar = _bar(Vector2(320, 14), Color(0.85, 0.2, 0.18))
	_stamina_bar = _bar(Vector2(320, 8), Color(0.95, 0.8, 0.3))
	left.add_child(_health_label)
	left.add_child(_health_bar)
	left.add_child(_stamina_bar)
	_torch_bar = _bar(Vector2(320, 5), Color(0.95, 0.93, 0.82))
	left.add_child(_torch_bar)
	_pin(root, left, Control.PRESET_BOTTOM_LEFT)

	var right := VBoxContainer.new()
	_slots = HBoxContainer.new()
	_slots.alignment = BoxContainer.ALIGNMENT_END
	_slots.add_theme_constant_override("separation", 10)
	for i in WeaponHolder.SLOT_ORDER.size():
		var slot := _label(16, SLOT_EMPTY)
		slot.text = str(i + 1)
		_slots.add_child(slot)
		_slot_labels.append(slot)
	right.add_child(_slots)
	_weapon_label = _label(22)
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_label = _label(40)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_battery_bar = _bar(Vector2(220, 12), Color(0.4, 0.8, 1.0))
	right.add_child(_weapon_label)
	right.add_child(_ammo_label)
	right.add_child(_battery_bar)
	_pin(root, right, Control.PRESET_BOTTOM_RIGHT)

	_death_label = _label(56, Color(0.9, 0.2, 0.15))
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.visible = false
	_pin(root, _death_label, Control.PRESET_CENTER)

	_fps_label = _label(16, Color(1.0, 1.0, 1.0, 0.6))
	_pin(root, _fps_label, Control.PRESET_CENTER_TOP)

	_dust_box = VBoxContainer.new()
	_dust_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_dust_row = HBoxContainer.new()
	_dust_row.alignment = BoxContainer.ALIGNMENT_END
	_dust_row.add_theme_constant_override("separation", 10)
	_dust_row.add_child(DustIcon.make(1.2))
	_dust_label = _label(38, DUST_COLOR)
	_dust_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dust_row.add_child(_dust_label)
	_dust_box.add_child(_dust_row)
	_dust_gain = _label(24, Color(1.0, 0.95, 0.82))
	_dust_gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dust_gain.modulate.a = 0.0
	_dust_box.add_child(_dust_gain)
	_pin(root, _dust_box, Control.PRESET_TOP_RIGHT)
	_dust_label.text = str(RunState.dust)

	_night_box = VBoxContainer.new()
	_night_box.add_theme_constant_override("separation", 6)
	var night_row := HBoxContainer.new()
	night_row.add_theme_constant_override("separation", 22)
	_night_label = _label(26, Color(0.93, 0.9, 0.84))
	_night_label.label_settings.font = UiTheme.spaced_font(6)
	night_row.add_child(_night_label)
	_clock_label = _label(26, UiTheme.ACCENT)
	_clock_label.label_settings.font = UiTheme.spaced_font(4)
	_clock_label.visible = false
	night_row.add_child(_clock_label)
	_night_box.add_child(night_row)
	_objective_row = HBoxContainer.new()
	_objective_row.add_theme_constant_override("separation", 12)
	_fuse_icons = FuseIcons.new()
	_fuse_icons.visible = false
	_objective_row.add_child(_fuse_icons)
	_objective_label = _label(22, OBJECTIVE_COLOR)
	_objective_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_objective_row.add_child(_objective_label)
	_objective_row.visible = false
	_night_box.add_child(_objective_row)
	_help_hint = _label(20, Color(1.0, 1.0, 1.0, 0.8))
	_night_box.add_child(_help_hint)
	_pin(root, _night_box, Control.PRESET_TOP_LEFT)
	_night_box.visible = night > 0

	# the boss's health bar, top middle, with ticks at its phase changes
	_boss_box = VBoxContainer.new()
	_boss_box.add_theme_constant_override("separation", 6)
	_boss_name = _label(24, Color(0.95, 0.85, 0.8))
	_boss_name.label_settings.font = UiTheme.spaced_font(8)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_name)
	_boss_bar = _bar(Vector2(720, 16), BOSS_COLOR)
	_boss_box.add_child(_boss_bar)
	_boss_ticks = Control.new()
	_boss_ticks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_ticks.draw.connect(_draw_boss_ticks)
	_boss_bar.add_child(_boss_ticks)
	_boss_box.visible = false
	_pin(root, _boss_box, Control.PRESET_CENTER_TOP)
	_boss_box.offset_top += 34.0
	_boss_box.offset_bottom += 34.0
	Events.boss_awakened.connect(_on_boss_awakened)

	_toast = _label(24, TOAST_COLOR)
	_toast.label_settings.font = UiTheme.spaced_font(4)
	_toast.modulate.a = 0.0
	_pin(root, _toast, Control.PRESET_CENTER_TOP)
	_toast.offset_top += 70.0
	_toast.offset_bottom += 70.0
	RunState.dust_changed.connect(_on_dust_changed)

	# the night's card: "NIGHT 3 / BLACKOUT / only the emergency lamps..."
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 8)
	_card_title = _label(64, TOAST_COLOR)
	_card_title.label_settings.font = UiTheme.spaced_font(12)
	_card_subtitle = _label(30, UiTheme.ACCENT)
	_card_subtitle.label_settings.font = UiTheme.spaced_font(6)
	_card_detail = _label(22, Color(TOAST_COLOR, 0.85))
	for line in [_card_title, _card_subtitle, _card_detail]:
		(line as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_card.add_child(line)
	_card.modulate.a = 0.0
	_pin(root, _card, Control.PRESET_CENTER)
	_card.offset_top -= 190.0
	_card.offset_bottom -= 190.0

	# a hint or a note, low in the middle of the screen, over a dark strip
	_hint = PanelContainer.new()
	var hint_style := UiTheme.panel_style(0.0)
	hint_style.bg_color = Color(0.04, 0.035, 0.03, 0.78)
	hint_style.shadow_size = 0
	hint_style.content_margin_left = 26.0
	hint_style.content_margin_right = 26.0
	hint_style.content_margin_top = 12.0
	hint_style.content_margin_bottom = 12.0
	_hint.add_theme_stylebox_override("panel", hint_style)
	_hint_label = _label(24, UiTheme.TEXT)
	_hint_label.label_settings.outline_size = 0
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(420, 0)
	_hint.add_child(_hint_label)
	_hint.modulate.a = 0.0
	root.add_child(_hint)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 170)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN

	# "[E] Upgrade terminal": a keycap and the action on a dark strip
	_prompt = PanelContainer.new()
	var prompt_style := UiTheme.panel_style(0.0)
	prompt_style.bg_color = Color(0.04, 0.035, 0.03, 0.72)
	prompt_style.shadow_size = 0
	prompt_style.content_margin_left = 10.0
	prompt_style.content_margin_right = 22.0
	prompt_style.content_margin_top = 8.0
	prompt_style.content_margin_bottom = 8.0
	_prompt.add_theme_stylebox_override("panel", prompt_style)
	var prompt_row := HBoxContainer.new()
	prompt_row.add_theme_constant_override("separation", 14)
	_prompt.add_child(prompt_row)
	var keycap := PanelContainer.new()
	var cap_style := StyleBoxFlat.new()
	cap_style.bg_color = Color(UiTheme.ACCENT, 0.16)
	cap_style.border_color = UiTheme.ACCENT
	cap_style.set_border_width_all(2)
	cap_style.set_corner_radius_all(4)
	cap_style.content_margin_left = 12.0
	cap_style.content_margin_right = 12.0
	cap_style.content_margin_top = 1.0
	cap_style.content_margin_bottom = 1.0
	keycap.add_theme_stylebox_override("panel", cap_style)
	_prompt_key = _label(24, UiTheme.ACCENT)
	_prompt_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keycap.add_child(_prompt_key)
	prompt_row.add_child(keycap)
	_prompt_label = _label(26, UiTheme.TEXT)
	_prompt_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prompt_row.add_child(_prompt_label)
	_prompt.visible = false
	_pin(root, _prompt, Control.PRESET_CENTER)
	_prompt.offset_top += 120.0
	_prompt.offset_bottom += 120.0

	_help = PanelContainer.new()
	_help_label = _label(20)
	_help.add_child(_help_label)
	_pin(root, _help, Control.PRESET_TOP_LEFT)
	_refresh_texts()

	Events.player_damaged.connect(_on_player_damaged)
	Events.hit_landed.connect(_on_hit_landed)
	Events.hint_requested.connect(_on_hint_requested)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _help_label != null:
		_refresh_texts()
	elif what == NOTIFICATION_PAUSED and _prompt != null:
		_prompt.visible = false   # the HUD stands still under a pausing menu


func hide_help() -> void:
	_help.visible = false


## Bottom edge (canvas units) of what stands in the top left corner right
## now: the night, clock, goal and help line, or the F1 help over them
## (the world's row of artifacts goes under it).
func top_left_bottom() -> float:
	var bottom := 0.0
	for block: Control in [_night_box, _help]:
		if block != null and block.is_visible_in_tree():
			bottom = maxf(bottom, block.position.y + block.get_combined_minimum_size().y)
	return bottom


## A short line at the top (e.g. "Game saved") that fades away.
func show_toast(text: String) -> void:
	_toast.label_settings.font_color = TOAST_COLOR
	_toast.text = text.to_upper()
	_toast_left = TOAST_TIME


## The same line in red, a little longer (e.g. "The game could not be saved").
func show_warning(text: String) -> void:
	_toast.label_settings.font_color = UiTheme.DANGER
	_toast.text = text.to_upper()
	_toast_left = WARNING_TIME


## The night's card: a big [param title] with an optional
## [param subtitle] (accent colour) and [param detail] line; it fades in,
## stays a few seconds and fades out.
func show_card(title: String, subtitle: String = "", detail: String = "") -> void:
	_card_title.text = title.to_upper()
	_card_subtitle.text = subtitle.to_upper()
	_card_subtitle.visible = subtitle != ""
	_card_detail.text = detail
	_card_detail.visible = detail != ""
	_card_time = 0.0


## The night's clock next to its number ("" hides it).
func set_clock(text: String) -> void:
	_clock_label.text = text
	_clock_label.visible = text != ""


func clock_text() -> String:
	return _clock_label.text if _clock_label.visible else ""


## The night's goal under the night number ("" hides it).
func set_objective(text: String) -> void:
	_objective_label.text = text
	_objective_row.visible = text != ""


func objective_text() -> String:
	return _objective_label.text if _objective_row.visible else ""


## The fuse icons beside the goal: [param carried] in the pocket,
## [param inserted] in the box; hidden when [param shown] is false.
func set_fuses(carried: int, inserted: int, shown: bool = true) -> void:
	_fuse_icons.visible = shown
	_fuse_icons.set_counts(carried, inserted)


## [carried, inserted] as the icons show them (-1s when hidden).
func fuse_counts() -> Array[int]:
	if not _fuse_icons.visible:
		return [-1, -1]
	return [_fuse_icons.carried, _fuse_icons.inserted]


## True while the boss's bar is up.
func boss_bar_shown() -> bool:
	return _boss_box.visible and _boss_box.modulate.a > 0.0


## The bar's fill (0-1).
func boss_fraction() -> float:
	return _boss_bar.value


func _on_boss_awakened(boss: Node) -> void:
	_boss = boss
	_boss_name.text = tr("HUD_BOSS_NAME").to_upper()
	var health: Health = boss.get(&"health")
	if health != null:
		_boss_bar.value = health.fraction()
		if not health.changed.is_connected(_on_boss_health):
			health.changed.connect(_on_boss_health)
	if boss.has_signal(&"defeated") and not boss.is_connected(&"defeated", _on_boss_defeated):
		boss.connect(&"defeated", _on_boss_defeated)
	_boss_fade = 0.0
	_boss_box.modulate.a = 1.0
	_boss_box.visible = true
	_boss_ticks.queue_redraw()


func _on_boss_health(current: float, maximum: float) -> void:
	_boss_bar.value = current / maximum if maximum > 0.0 else 0.0


func _on_boss_defeated() -> void:
	_boss_bar.value = 0.0
	_boss_fade = 2.0   # the empty bar lingers a moment, then fades


func _update_boss(delta: float) -> void:
	if _boss_fade <= 0.0:
		return
	_boss_fade = maxf(_boss_fade - delta, 0.0)
	_boss_box.modulate.a = clampf(_boss_fade, 0.0, 1.0)
	if _boss_fade <= 0.0:
		_boss_box.visible = false


func _draw_boss_ticks() -> void:
	var width := _boss_ticks.size.x
	var height := _boss_ticks.size.y
	for at in BOSS_PHASES:
		_boss_ticks.draw_rect(Rect2(width * at - 1.0, 0.0, 2.0, height), Color(0.0, 0.0, 0.0, 0.75))


## A hint or a note under the crosshair, for [param seconds] (fades out).
func show_hint(text: String, seconds: float = HINT_TIME) -> void:
	_hint_label.text = text
	# long notes wrap instead of running off the screen
	_hint_label.custom_minimum_size.x = clampf(text.length() * 11.0, 420.0, 980.0)
	_hint.reset_size()
	_hint_left = seconds


## The hint line while it shows ("" when gone).
func hint_text() -> String:
	return _hint_label.text if _hint_left > 0.0 else ""


func _update_hint(delta: float) -> void:
	_hint_left = maxf(_hint_left - delta, 0.0)
	_hint.modulate.a = clampf(_hint_left / 0.6, 0.0, 1.0)


## The card's lines while it shows ("" when gone), joined by " | ".
func card_text() -> String:
	if _card_time >= CARD_TIME:
		return ""
	var lines: PackedStringArray = [_card_title.text]
	if _card_subtitle.visible:
		lines.append(_card_subtitle.text)
	if _card_detail.visible:
		lines.append(_card_detail.text)
	return " | ".join(lines)


func _update_card(delta: float) -> void:
	if _card_time >= CARD_TIME:
		_card.modulate.a = 0.0
		return
	_card_time += delta
	var fade_in := clampf(_card_time / CARD_FADE_IN, 0.0, 1.0)
	var fade_out := clampf((CARD_TIME - _card_time) / CARD_FADE_OUT, 0.0, 1.0)
	_card.modulate.a = minf(fade_in, fade_out)


## The text of the top line while it shows ("" when gone).
func toast_text() -> String:
	return _toast.text if _toast_left > 0.0 else ""


## Fixed texts, again whenever the language changes.
func _refresh_texts() -> void:
	_death_label.text = tr("HUD_GUARD_DOWN")
	_night_label.text = (tr("HUD_NIGHT") % night).to_upper()
	_help_hint.text = tr("HUD_HELP_HINT") % GameInput.key_label(&"toggle_help")
	var paragraphs: PackedStringArray = []
	for key in help_keys:
		paragraphs.append(tr(key))
	_help_label.text = "\n\n".join(paragraphs)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_help"):
		_help.visible = not _help.visible


func _process(delta: float) -> void:
	_vignette.modulate.a = move_toward(_vignette.modulate.a, 0.0, 1.5 * delta)
	_fps_label.visible = always_show_fps or Settings.data.show_fps
	_fps_label.text = tr("HUD_FPS") % Engine.get_frames_per_second()
	_update_dust(delta)
	_update_toast(delta)
	_update_card(delta)
	_update_hint(delta)
	_update_boss(delta)
	_night_box.visible = night > 0 and not _help.visible
	if not is_instance_valid(player):
		return
	_health_label.text = tr("HUD_HEALTH") % ceili(player.health.current)
	_health_bar.value = player.health.fraction()
	_stamina_bar.value = player.stamina.fraction()
	_stamina_bar.modulate = Color(1.0, 0.45, 0.35) if player.stamina.exhausted else Color.WHITE
	_torch_bar.value = player.battery.fraction()
	var blink := player.battery.is_low() and fmod(Time.get_ticks_msec() / 1000.0, 0.6) < 0.3
	_torch_bar.modulate = Color(1.0, 0.35, 0.3) if blink else Color.WHITE
	_death_label.visible = not player.alive
	_update_prompt()
	var state := player.weapons.current_state()
	_update_slots(state)
	_weapon_label.visible = state != null
	_ammo_label.visible = false
	_battery_bar.visible = false
	if state == null:
		return
	_weapon_label.text = tr(state.data.display_name).to_upper()
	if state.data.volley_count > 1:
		_weapon_label.text += "  ·  " + tr("HUD_VOLLEY") % state.data.volley_count
	if state.has_alt():
		_weapon_label.text += "  ·  " + tr("HUD_AMMO_SLUG" if state.use_alt else "HUD_AMMO_BUCKSHOT")
	match state.data.ammo_mode:
		WeaponData.AmmoMode.MAGAZINE:
			_ammo_label.visible = true
			_ammo_label.text = tr("HUD_RELOADING") if state.is_reloading() else "%d | %d" % [state.magazine, state.reserve]
		WeaponData.AmmoMode.BATTERY:
			_battery_bar.visible = true
			_battery_bar.value = state.battery / state.data.battery_max


## The slot numbers: weapons found lit, the one in hand in the accent
## colour, the rest faint.
func _update_slots(current: WeaponState) -> void:
	for i in _slot_labels.size():
		var id: StringName = WeaponHolder.SLOT_ORDER[i]
		var color := SLOT_EMPTY
		if current != null and current.data.id == id:
			color = UiTheme.ACCENT
		elif player.weapons.has_weapon(id):
			color = SLOT_OWNED
		_slot_labels[i].label_settings.font_color = color


## The slot numbers as shown: "1" lit, "(2)" faint, "[3]" in hand.
func slots_text() -> String:
	var out := PackedStringArray()
	for i in _slot_labels.size():
		var color := _slot_labels[i].label_settings.font_color
		if color == UiTheme.ACCENT:
			out.append("[%d]" % (i + 1))
		elif color == SLOT_OWNED:
			out.append(str(i + 1))
		else:
			out.append("(%d)" % (i + 1))
	return " ".join(out)


func _on_hint_requested(text: String) -> void:
	show_hint(text, WORLD_HINT_TIME)


func _update_toast(delta: float) -> void:
	_toast_left = maxf(_toast_left - delta, 0.0)
	_toast.modulate.a = clampf(_toast_left / 0.6, 0.0, 1.0)


func _update_dust(delta: float) -> void:
	_dust_box.visible = show_dust
	_gain_left = maxf(_gain_left - delta, 0.0)
	_dust_gain.modulate.a = clampf(_gain_left / (GAIN_TIME * 0.5), 0.0, 1.0)
	if _gain_left <= 0.0:
		_gain_amount = 0
	_bump = move_toward(_bump, 0.0, 3.0 * delta)
	_dust_row.pivot_offset = Vector2(_dust_row.size.x, _dust_row.size.y * 0.5)
	_dust_row.scale = Vector2.ONE * (1.0 + 0.25 * _bump * _bump)


func _on_dust_changed(total: int, change: int) -> void:
	_dust_label.text = str(total)
	if change <= 0:
		return
	# gains close together add up into one "+n"
	_gain_amount += change
	_gain_left = GAIN_TIME
	_dust_gain.text = "+%d" % _gain_amount
	_bump = 1.0


## "[E] Use the terminal" under the crosshair while something usable is in focus.
func _update_prompt() -> void:
	var focus := player.interactor.focus
	_prompt.visible = player.alive and is_instance_valid(focus) and GameInput.top_ui() == null
	if _prompt.visible:
		_prompt_key.text = GameInput.key_label(&"interact")
		_prompt_label.text = focus.prompt()


func _on_player_damaged(amount: float, _from: Vector3) -> void:
	_vignette.modulate.a = clampf(0.35 + amount / 40.0, 0.0, 0.9)


func _on_hit_landed(_target: Node, info: DamageInfo, killed: bool) -> void:
	if not is_instance_valid(player) or info == null or info.source != player:
		return
	var color := HIT_COLOR
	if info.blocked:
		color = BLOCKED_COLOR
	elif killed:
		color = KILL_COLOR
	elif info.weak_point:
		color = WEAK_POINT_COLOR
	_crosshair.show_marker(color)
	Sfx.play(&"kill" if killed else &"hit_marker", -8.0)


static func _label(font_size: int, color: Color = Color.WHITE) -> Label:
	var settings := LabelSettings.new()
	settings.font = UiTheme.strong_font()
	settings.font_size = font_size
	settings.font_color = color
	settings.outline_size = 6
	settings.outline_color = Color(0.0, 0.0, 0.0, 0.8)
	var label := Label.new()
	label.label_settings = settings
	return label


static func _bar(min_size: Vector2, fill: Color) -> ProgressBar:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	var foreground := StyleBoxFlat.new()
	foreground.bg_color = fill
	var bar := ProgressBar.new()
	bar.custom_minimum_size = min_size
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.step = 0.001
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", foreground)
	return bar


## Adds [param node] to [param root] anchored to a screen corner or centre.
static func _pin(root: Control, node: Control, preset: Control.LayoutPreset) -> void:
	root.add_child(node)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 32)
	match preset:
		Control.PRESET_BOTTOM_LEFT:
			node.grow_vertical = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_BOTTOM_RIGHT:
			node.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			node.grow_vertical = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_TOP_RIGHT:
			node.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER_TOP:
			node.grow_horizontal = Control.GROW_DIRECTION_BOTH
		Control.PRESET_CENTER:
			node.grow_horizontal = Control.GROW_DIRECTION_BOTH
			node.grow_vertical = Control.GROW_DIRECTION_BOTH


static func _make_vignette() -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.55, 1.0])
	gradient.colors = PackedColorArray([Color(0.6, 0.0, 0.0, 0.0), Color(0.6, 0.0, 0.0, 1.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	return rect


# --- Floor I ---------------------------------------------------------------

## A room's name on its first visit: a strip in its wing's colour, the
## room's name and, smaller, the wing's; it fades in, stays, fades out.
class RoomCard extends PanelContainer:
	const TIME := 4.0
	const FADE_IN := 0.4
	const FADE_OUT := 1.0
	var strip: ColorRect
	var title: Label
	var zone: Label
	var time: float = INF

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := UiTheme.panel_style(0.0)
		style.bg_color = Color(0.04, 0.035, 0.03, 0.74)
		style.shadow_size = 0
		style.content_margin_left = 0.0
		style.content_margin_right = 26.0
		style.content_margin_top = 10.0
		style.content_margin_bottom = 10.0
		add_theme_stylebox_override("panel", style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		add_child(row)
		strip = ColorRect.new()
		strip.custom_minimum_size = Vector2(8, 0)
		row.add_child(strip)
		var lines := VBoxContainer.new()
		lines.add_theme_constant_override("separation", 2)
		row.add_child(lines)
		title = Hud._label(28, UiTheme.TEXT)
		title.label_settings.font = UiTheme.spaced_font(4)
		lines.add_child(title)
		zone = Hud._label(18, Color(UiTheme.TEXT, 0.7))
		zone.label_settings.font = UiTheme.spaced_font(3)
		lines.add_child(zone)
		modulate.a = 0.0

	func show_room(room_name: String, zone_name: String, color: Color) -> void:
		title.text = room_name.to_upper()
		zone.text = zone_name.to_upper()
		zone.visible = zone_name != "" and zone_name != room_name
		strip.color = color
		time = 0.0
		reset_size()

	func shown_text() -> String:
		if time >= TIME:
			return ""
		return title.text + (" | " + zone.text if zone.visible else "")

	func _process(delta: float) -> void:
		if time >= TIME:
			modulate.a = 0.0
			return
		time += delta
		modulate.a = minf(clampf(time / FADE_IN, 0.0, 1.0), clampf((TIME - time) / FADE_OUT, 0.0, 1.0))


## Builds the Floor I parts (once): the room card, the shard line under the
## goal, the guardians' bar.
func enable_floor() -> void:
	if _room_card != null:
		return
	var root := _night_box.get_parent() as Control
	_room_card = RoomCard.new()
	_room_card.name = "RoomCard"
	_pin(root, _room_card, Control.PRESET_CENTER_TOP)
	_room_card.offset_top += 118.0
	_room_card.offset_bottom += 118.0
	_shards_label = _label(20, Color(0.85, 0.35, 0.3, 0.95))
	_shards_label.visible = false
	_night_box.add_child(_shards_label)
	_night_box.move_child(_shards_label, _objective_row.get_index() + 1)
	Events.guardian_awakened.connect(_on_guardian_awakened)


## The card of a room entered for the first time.
func show_room_card(room_name: String, zone_name: String, color: Color) -> void:
	if _room_card == null:
		enable_floor()
	_room_card.show_room(room_name, zone_name, color)


## The card's lines while it shows ("" when gone), joined by " | ".
func room_card_text() -> String:
	return _room_card.shown_text() if _room_card != null else ""


## "Shards: 3/6" under the goal ([param count] <= 0 hides it).
func set_shards(count: int, total: int) -> void:
	if _shards_label == null:
		enable_floor()
	_shards_label.text = (tr("GOAL_SHARDS") % [count, total]) if count > 0 else ""
	_shards_label.visible = count > 0


func shards_text() -> String:
	return _shards_label.text if _shards_label != null and _shards_label.visible else ""


## The boss bar's title line while it shows ("" when gone).
func boss_name_text() -> String:
	return _boss_name.text if boss_bar_shown() else ""


## A wing guardian woke: its bar with "NAME — TITLE" (the T-Rex keeps
## Events.boss_awakened); it fades when the guardian falls or calms down.
func _on_guardian_awakened(guardian: Node, _guardian_id: StringName) -> void:
	_on_boss_awakened(guardian)
	var title := String(guardian.call(&"title")) if guardian.has_method(&"title") else ""
	var shown := String(guardian.call(&"display_name")) if guardian.has_method(&"display_name") else ""
	_boss_name.text = (shown + ("  —  " + title if title != "" else "")).to_upper()
	if guardian.has_signal(&"calmed") and not guardian.is_connected(&"calmed", _on_guardian_calmed):
		guardian.connect(&"calmed", _on_guardian_calmed)


## The guard fled the arena: the guardian is back on its post, the bar goes.
func _on_guardian_calmed() -> void:
	_boss_fade = 0.6
