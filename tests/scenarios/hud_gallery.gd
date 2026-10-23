extends Node
## The HUD and the in-game UI, every piece on screen (not part of the
## headless suite): the real Floor I museum at night behind it, the guard at
## the T-Rex's balcony strip. Each view is staged, then captured in both
## languages; the first views also on a 1280x1024 window.
##   bash tools/run_hud_gallery.sh dry            no window: stages every view, checks it
##   bash tools/run_hud_gallery.sh shots [--tag=after] [--views=hud,notice]
##       [--languages=en] [--sizes=1920x1080] [--palettes=0,1,2,3]
##       silent window: tests/_out/hud_style/<tag>_<view>_<lang>_<w>x<h>.png
##       (with --palettes: <tag>_cv<n>_<view>_..., n = SettingsData.ColourVisionMode)
## Views: hud (every live element at once: night, clock, a long goal, fuses,
## shards, Dust and its gain, health, stamina with fatigue and caffeine, the
## torch, the weapon, its slots and ammo, the prompt, the room card, a
## toast, a guardian's bar), notice (a secret's banner, a subtitle, a hint,
## the night's card, exhausted stamina, low health and torch), help (F1),
## pause, options, map, upgrade, note, dawn, death; rims (a row of every
## ammo box and the medkit near the guard, another far down the hall: their
## rims in the palette), markers (the crosshair's four hit markers, one shot
## each: hit, weak point, kill, blocked).

const OUT_DIR := "res://tests/_out/hud_style/"
const WATCHDOG_SECONDS := 540.0
const VIEWS: Array[String] = ["hud", "notice", "help", "pause", "options", "map", "upgrade", "note", "dawn", "death", "rims",
	"marker_hit", "marker_weak_point", "marker_kill", "marker_blocked"]
## The rims view: the pickups shown, near (m ahead of the eye) and far.
const RIM_TYPES: Array[Pickup.Type] = [Pickup.Type.BULLETS, Pickup.Type.SHELLS, Pickup.Type.RIFLE, Pickup.Type.FLARES,
	Pickup.Type.HUNT_ROUNDS, Pickup.Type.HARPOONS, Pickup.Type.ROCKETS, Pickup.Type.MEDKIT]
const RIM_NEAR := 2.6
const RIM_FAR := 11.0
## The rims view turns the guard this far left (rad).
const RIM_TURN := 0.6
## Views shot on the 1280x1024 window too (after the 1920x1080 ones).
const SQUARE_VIEWS: Array[String] = ["hud", "notice", "pause"]
const LANGUAGES: Array[String] = ["en", "pl"]
const STAND := Vector3(13.0, 0.0, -26.0)
const HEAL := 1000000.0

var museum: Museum
var _dry := false
var _tag := "shot"
var _views: PackedStringArray = []
var _languages: PackedStringArray = []
var _sizes: PackedStringArray = []
## Colour-vision palettes to shoot each view in (empty: the settings' own).
var _palettes: PackedStringArray = []
var _palette_tag := ""
var _rim_pickups: Array[Node] = []
var _log: Array = []
var _problems: int = 0
var _usable: Interactable = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(_on_watchdog)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			_tag = arg.trim_prefix("--tag=")
		elif arg.begins_with("--views="):
			_views = arg.trim_prefix("--views=").split(",", false)
		elif arg.begins_with("--languages="):
			_languages = arg.trim_prefix("--languages=").split(",", false)
		elif arg.begins_with("--sizes="):
			_sizes = arg.trim_prefix("--sizes=").split(",", false)
		elif arg.begins_with("--palettes="):
			_palettes = arg.trim_prefix("--palettes=").split(",", false)
	_dry = DisplayServer.get_name() == "headless"
	GameInput.capture_allowed = false
	if not _dry:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
	Settings.set_value(&"graphics_quality", GraphicsQuality.Quality.HIGH, false)
	Settings.set_value(&"show_fps", false, false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ignore := FileAccess.open(ProjectSettings.globalize_path("res://tests/_out/.gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	await _open()
	var palettes: Array[String] = []
	for p in _palettes:
		palettes.append(p)
	if palettes.is_empty():
		palettes.append("")
	for size in [Vector2i(1920, 1080), Vector2i(1280, 1024)]:
		if not _sizes.is_empty() and not _sizes.has("%dx%d" % [size.x, size.y]):
			continue
		if not _dry:
			DisplayServer.window_set_size(size)
			await _frames(6)
		for palette in palettes:
			if palette != "":
				Settings.set_value(&"colour_vision", int(palette), false)
				_palette_tag = "_cv%s" % palette
			for view in VIEWS:
				if not _views.is_empty() and not _views.has(view):
					continue
				if size.x != 1920 and not SQUARE_VIEWS.has(view):
					continue
				for language in LANGUAGES:
					if not _languages.is_empty() and not _languages.has(language):
						continue
					Settings.set_value(&"language", language, false)
					await _frames(2)
					await _stage(view)
					await _shot(view, language)
					await _unstage(view)
		if _dry:
			break
	var file := FileAccess.open(OUT_DIR.path_join("dry.json" if _dry else "%s_metrics.json" % _tag), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"tag": _tag, "views": _log}, "  "))
		file.close()
	print("hud gallery: %d views, %d problems" % [_log.size(), _problems])
	Sfx.quit_cleanly(1 if _problems > 0 else 0)


func _on_watchdog() -> void:
	print("PROBLEM: the HUD gallery did not finish in time")
	Sfx.quit_cleanly(1)


## Night 1 of a new game on Floor I with the art; the guard armed with
## every weapon at the balcony strip, the exhibits standing still, no tips.
func _open() -> void:
	Museum.level_id = &"floor1"
	MuseumFloorLevel.dress_default = true
	GameState.new_game()
	GameState.night = 1
	RunState.reset()
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	var guard := museum.player
	for id in WeaponHolder.SLOT_ORDER:
		var data := load("res://src/weapons/data/%s.tres" % id) as WeaponData
		if data != null and guard.weapons.state_of(id) == null:
			guard.weapons.give(data)
	for state in guard.weapons.owned:
		state.magazine = state.data.magazine_size
		state.reserve = state.data.max_reserve
	if museum.onboarding != null:
		museum.onboarding.process_mode = Node.PROCESS_MODE_DISABLED
	museum.enemies_root.process_mode = Node.PROCESS_MODE_DISABLED
	_put_guard()
	await _seconds(2.5)   # shaders, SDFGI, fog history
	await _until(func() -> bool: return museum.hud.card_text() == "" and museum.hud.room_card_text() == "", 11.0)


func _put_guard() -> void:
	var guard := museum.player
	guard.global_position = STAND + Vector3.UP * 0.05
	guard.velocity = Vector3.ZERO
	guard.reset_physics_interpolation()
	var look := Vector3(0.0, 4.0, -14.0)
	var finale := museum.floor_game.finale if museum.floor_game != null else null
	if finale != null and is_instance_valid(finale.boss):
		look = finale.boss.skeleton.crystal_position()
	var eye := guard.global_position + Vector3.UP * guard.eye_height
	var aim := look - eye
	guard.head.rotation = Vector3(atan2(aim.y, Vector2(aim.x, aim.z).length()) - 0.12, atan2(-aim.x, -aim.z), 0.0)
	guard.head.global_position = eye


func _world_hud() -> WorldHud:
	return museum.floor_game.world.hud if museum.floor_game != null and museum.floor_game.world != null else null


func _subtitles() -> SubtitleBar:
	for node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if node is SubtitleBar:
			return node
	return null


## The longest Floor I goal of the language now.
func _long_goal() -> String:
	var longest := ""
	for key in ["GOAL_GUARDIAN_ENLIGHTENMENT", "GOAL_DESCEND", "GOAL_POWER", "GOAL_GUARDIAN_ASIA"]:
		var text := tr(key)
		if text.length() > longest.length():
			longest = text
	return longest


func _stage(view: String) -> void:
	var hud := museum.hud
	var guard := museum.player
	guard.health.heal(HEAL)
	match view:
		"hud":
			hud.set_clock("23:47")
			hud.set_objective(_long_goal())
			hud.set_fuses(1, 1, true)   # one in the pocket (striped), one in the box (solid, filament)
			hud.set_shards(3, Floor1Plan.SHARD_COUNT)
			guard.weapons.select_id(&"shotgun")
			await _seconds(0.5)
			guard.health.apply_damage(guard.health.max_health * 0.36)
			guard.fatigue.drink(&"espresso")
			guard.fatigue.level = 1.0
			guard.stamina.current = guard.stamina.maximum * 0.42
			guard.stamina._regen_wait = 99.0
			guard.battery.charge = guard.battery.capacity * 0.55
			var state := guard.weapons.current_state()
			state.magazine = maxi(state.data.magazine_size - 1, 0)
			RunState.add_dust(37, false)
			hud._on_dust_changed(RunState.dust, 12)
			_usable = Interactable.new()
			_usable.prompt_key = "PROMPT_SECRET_PLAQUE"
			_usable.add_box(Vector3(0.8, 0.8, 0.8))
			museum.add_child(_usable)
			_usable.global_position = guard.camera.global_position - guard.camera.global_transform.basis.z * 1.3
			var guardian := museum.floor_game.guardians.guardians.get(&"lamassu") as Node if museum.floor_game != null else null
			if guardian != null:
				hud._on_guardian_awakened(guardian, &"lamassu")
				hud._boss_bar.value = 0.58
			hud.show_room_card(tr("ROOM_ENLIGHTENMENT_PORTRAITS"), tr("ZONE_ENLIGHTENMENT"), Floor1Plan.zone_color(&"enlightenment"))
			hud.show_toast(tr("HUD_FUSE_FOUND") % [1, 2])
			await _seconds(0.7)
		"notice":
			hud.set_clock("03:12")
			hud.set_objective(tr("GOAL_SHARDS") % [4, 6])
			hud.set_fuses(0, 0, false)
			guard.weapons.select_id(&"pistol")
			guard.health.apply_damage(guard.health.max_health * 0.78)
			guard.stamina.current = guard.stamina.maximum * 0.12
			guard.stamina.exhausted = true
			guard.stamina._regen_wait = 99.0
			guard.fatigue.level = 0.5
			guard.battery.charge = guard.battery.capacity * 0.08
			var banner := _world_hud()
			if banner != null:
				banner.banner(tr("SECRET_FOUND") % [3, 12], tr("PROMPT_SECRET_PLAQUE"), tr("CHESS_DETAIL"))
			var bar := _subtitles()
			if bar != null:
				Settings.set_value(&"subtitles", true, false)
				bar.show_line(&"VO_HENIEK_NIGHT_1", &"radio", 12.0)
			hud.show_hint(tr("HUD_HINT_FUSES"), 8.0)
			hud.show_card(tr("HUD_NIGHT") % 2, tr(NightModifiers.title_key(&"blackout")), tr(NightModifiers.detail_key(&"blackout")))
			await _seconds(1.2)
			guard.stamina.current = guard.stamina.maximum * 0.12
			guard.stamina.exhausted = true
			guard.stamina._regen_wait = 99.0
			await _frames(2)
		"help":
			hud._help.visible = true
			await _frames(3)
		"pause":
			museum.pause_menu.open()
			await _frames(4)
		"options":
			museum.pause_menu.open()
			museum.pause_menu._open_options()
			await _frames(4)
		"map":
			if museum.floor_game != null and museum.floor_game.map != null:
				museum.floor_game.map.open()
			await _real(0.5)
		"upgrade":
			RunState.add_dust(140, false)
			museum.upgrade_menu.open(GameState, RunState)
			await _real(0.5)
		"note":
			var reader := museum.floor_game.world.reader if museum.floor_game != null else null
			if reader != null:
				reader.open_note(&"note_1")
			await _real(0.6)
		"dawn":
			museum.dawn_screen.play(3, 42, {"found": 5, "total": 12, "tonight": 2, "rewards": 1, "rewards_total": 4})
			await _real(2.4)
		"death":
			museum.death_screen.play(4, 42)
			await _real(1.8)
		"rims":
			# turned to the darker floor on the left, the rows left of the gun in hand
			guard.head.rotation = Vector3(-0.2, guard.head.rotation.y + RIM_TURN, 0.0)
			await _frames(2)
			var eye := guard.camera.global_transform
			var forward := -eye.basis.z
			forward.y = 0.0
			forward = forward.normalized()
			var right := forward.cross(Vector3.UP).normalized()
			for row in [RIM_NEAR, RIM_FAR]:
				var spread: float = 0.3 if row == RIM_NEAR else 0.9
				var middle: Vector3 = guard.global_position + forward * float(row) - right * float(row) * 0.27
				for i in RIM_TYPES.size():
					var box := Pickup.new()
					box.type = RIM_TYPES[i]
					box.respawn_time = 0.0
					museum.add_child(box)
					var at: Vector3 = middle + right * (i - (RIM_TYPES.size() - 1) * 0.5) * spread
					box.global_position = Vector3(at.x, guard.global_position.y + 0.35, at.z)
					_rim_pickups.append(box)
			await _seconds(0.6)
		"marker_hit", "marker_weak_point", "marker_kill", "marker_blocked":
			var kind := StringName(view.trim_prefix("marker_"))
			var role := &"hit" if kind == &"hit" else StringName("hit_" + kind)
			await _frames(2)
			hud._crosshair.show_marker(ColourVision.role(role), kind)


func _unstage(view: String) -> void:
	var hud := museum.hud
	var guard := museum.player
	match view:
		"hud":
			if is_instance_valid(_usable):
				_usable.queue_free()
			hud._release_boss()
			hud._boss_box.visible = false
			guard.fatigue.reset()
			guard.stamina._regen_wait = 0.0
			guard.health.heal(HEAL)
		"notice":
			guard.stamina.exhausted = false
			guard.stamina._regen_wait = 0.0
			guard.stamina.current = guard.stamina.maximum
			guard.fatigue.level = 0.0
			guard.health.heal(HEAL)
			var bar := _subtitles()
			if bar != null:
				bar.clear_line(&"")
			hud._card_time = INF
			hud._hint_left = 0.0
			var banner := _world_hud()
			if banner != null:
				banner._queue.clear()
				banner._current = PackedStringArray()
				banner._banner.visible = false
		"help":
			hud._help.visible = false
		"pause", "options":
			museum.pause_menu.close()
		"map":
			if museum.floor_game != null and museum.floor_game.map != null:
				museum.floor_game.map.close()
				GameInput.pop_ui(museum.floor_game.map)
		"upgrade":
			museum.upgrade_menu.close()
		"note":
			var reader := museum.floor_game.world.reader if museum.floor_game != null else null
			if reader != null:
				reader.close()
				GameInput.pop_ui(reader)
		"dawn":
			museum.dawn_screen.visible = false
			museum.dawn_screen._playing = false
		"death":
			museum.death_screen.visible = false
			museum.death_screen._playing = false
		"rims":
			for box in _rim_pickups:
				if is_instance_valid(box):
					box.queue_free()
			_rim_pickups.clear()
			_put_guard()
		"marker_hit", "marker_weak_point", "marker_kill", "marker_blocked":
			hud._crosshair.marker_time = 0.0
	hud._toast_left = 0.0
	if hud._room_card != null:
		hud._room_card.time = INF
	get_tree().paused = false
	await _frames(3)


func _shot(view: String, language: String) -> void:
	var size := get_viewport().get_visible_rect().size
	var window := DisplayServer.window_get_size() if not _dry else Vector2i(1920, 1080)
	var entry := {"view": view, "lang": language, "window": "%dx%d" % [window.x, window.y], "canvas": "%dx%d" % [size.x, size.y],
		"goal": museum.hud.objective_text(), "boss": museum.hud.boss_name_text(), "toast": museum.hud.toast_text(),
		"card": museum.hud.card_text(), "hint": museum.hud.hint_text(), "room": museum.hud.room_card_text()}
	_log.append(entry)
	print("%s: %s %s" % ["dry" if _dry else "shot", view, str(entry)])
	if _dry:
		return
	museum.hud._vignette.modulate.a = 0.0
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OUT_DIR.path_join("%s%s_%s_%s_%dx%d.png" % [_tag, _palette_tag, view, language, window.x, window.y])
	image.save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))


## Physics ticks until [param condition] holds or [param limit] s pass.
func _until(condition: Callable, limit: float) -> bool:
	var left := limit
	while left > 0.0:
		if condition.call():
			return true
		await get_tree().physics_frame
		left -= 1.0 / Engine.physics_ticks_per_second
	return condition.call()


func _seconds(time: float) -> void:
	for i in roundi(time * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


## Real seconds (menus run while the game is paused).
func _real(time: float) -> void:
	await get_tree().create_timer(time, true, false, true).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
