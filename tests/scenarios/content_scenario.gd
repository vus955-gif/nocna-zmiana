extends Node
## Visual check of the content pass (not part of the headless suite). Loads
## the content dev arena, stages the key moments of the new weapons, the
## new exhibits and the new upgrades, saves screenshots to
## tests/_out/content/ and a JSON log.
##   --mode=shots  1280x720 window, screenshots (bash tools/run_content.sh --shots)
##   --mode=dry    run with --headless: stages everything, captures nothing,
##                 prints which states each moment reached (logic check)

const OUT_DIR := "res://tests/_out/content/"
const WATCHDOG_SECONDS := 150.0

var dev: ContentDev
var _mode := "shots"
var _camera: Camera3D
var _log: Array = []


func _ready() -> void:
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(_on_watchdog)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
	if DisplayServer.get_name() == "headless":
		_mode = "dry"
	GameInput.capture_allowed = false
	if _mode == "shots":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ignore := FileAccess.open(ProjectSettings.globalize_path("res://tests/_out/.gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	dev = (load("res://src/dev/content_dev.tscn") as PackedScene).instantiate() as ContentDev
	add_child(dev)
	_camera = Camera3D.new()
	_camera.fov = 70.0
	add_child(_camera)
	# the guard only holds the camera here: he must survive every attack
	dev.player.health.max_health = 1000000.0
	dev.player.health.reset()
	dev.hud.hide_help()
	await _seconds(1.0)   # shaders compile, everything settles
	await _gatling_moments()
	await _flare_moments()
	await _find_moments()
	await _raptor_moments()
	await _portrait_moments()
	await _upgrade_moments()
	_write_log()
	Sfx.quit_cleanly(0)


func _gatling_moments() -> void:
	var guard := dev.player
	guard.weapons.select_id(&"gatling")
	_player_view(Vector3(-4.4, 1.7, 3.5), Vector3(-4.4, 1.0, -8.0))
	await _seconds(0.4)
	await _shot("gatling_idle")
	for node in dev.enemies_root.get_children():
		if node is WaxFigure:
			(node as WaxFigure).brain.wake()
	await _seconds(0.5)
	var state := guard.weapons.state_of(&"gatling")
	await _hold_fire(0.45 + 0.9)
	_note("gatling spun up", state.spun_up())
	_note("gatling fired", state.magazine < state.data.magazine_size)
	await _shot("gatling_firing")
	await _hold_fire(0.8)
	_note("spread after a long burst", snappedf(state.spread_for(state.data), 0.01))
	await _shot("gatling_burst_late")
	await _seconds(0.35)
	await _shot("gatling_winding_down")
	dev.clear_enemies()


func _flare_moments() -> void:
	var guard := dev.player
	dev.set_lights(false)
	guard.weapons.select_id(&"flare")
	# a dark corner of the hall: south-west, under nothing but the flare
	_player_view(Vector3(-10.0, 1.7, 10.0), Vector3(-21.5, 0.6, 21.0))
	await _seconds(0.5)
	await _shot("flare_dark_before")
	guard.weapons.try_fire()
	await _until(func() -> bool: return _count(FlareLight) > 0, 1.5, "flare stuck in the corner")
	await _seconds(0.8)
	await _shot("flare_dark_corner")
	# a wax figure set alight
	guard.weapons.state_of(&"flare").magazine = 1
	guard.weapons.state_of(&"flare").cancel_reload()
	var figure := dev.spawn(&"wax", Vector3(0.0, 0.1, 4.0), false)
	figure.max_health = 400.0
	figure.health.max_health = 400.0
	figure.health.reset()
	_player_view(Vector3(0.0, 1.7, 12.0), figure.global_position + Vector3.UP * 1.0)
	await _seconds(0.3)
	guard.weapons.try_fire()
	await _until(func() -> bool: return _burning() != null, 1.5, "flare burning a wax figure")
	await _seconds(0.9)
	_free_view(figure.global_position + Vector3(2.6, 1.6, 2.6), figure.global_position + Vector3.UP * 0.9)
	await _shot("flare_burning_wax")
	_note("wax health after the flare", snappedf(figure.health.current, 0.1) if is_instance_valid(figure) else -1.0)
	dev.set_lights(true)
	dev.clear_enemies()
	for flare in _all(FlareLight):
		flare.queue_free()


func _find_moments() -> void:
	var display := dev.display
	_player_view(display.global_position + Vector3(-4.2, 1.7, 0.6), display.global_position + Vector3(0.0, 1.2, 0.0))
	await _seconds(0.3)
	await _shot("find_chained_gatling")
	var cabinet := dev.cabinet
	_player_view(cabinet.global_position + Vector3(0.0, 0.3, -2.6), cabinet.global_position)
	await _seconds(0.3)
	await _shot("find_fire_cabinet")


func _raptor_moments() -> void:
	dev.clear_enemies()
	var guard := dev.player
	_player_view(Vector3(0.0, 1.7, 14.0), Vector3(0.0, 1.0, -8.0))
	# a close look at one skeleton
	var model := RaptorPack.spawn(dev.enemies_root, Vector3(0.0, 0.1, 6.0), 1, guard, false)[0]
	model.face(Vector3(4.0, 0.0, 9.0))
	await _seconds(0.3)
	_free_view(model.global_position + Vector3(1.9, 1.1, 1.5), model.global_position + Vector3(0.0, 0.7, -0.2))
	await _shot("raptor_close")
	dev.clear_enemies()
	# a pack coming for the guard: seen from above, splitting left and right
	var pack := RaptorPack.spawn(dev.enemies_root, Vector3(0.0, 0.1, -12.0), 4, guard, true)
	await _seconds(1.7)
	_free_view(Vector3(0.0, 19.0, 17.0), Vector3(0.0, 0.0, 3.0))
	await _shot("raptor_pack_flanking")
	var sides: Array = []
	for raptor in pack:
		if is_instance_valid(raptor):
			sides.append("%+d: x %.1f z %.1f" % [int(raptor.flank_side), raptor.global_position.x, raptor.global_position.z])
	_note("raptor side: position", ", ".join(sides))
	await _until(func() -> bool: return _crouching(pack) != null, 3.0, "a raptor crouches to leap")
	var crouched := _crouching(pack)
	if crouched != null:
		_player_view(Vector3(0.0, 1.7, 14.0), crouched.global_position + Vector3.UP * 0.6)
		await _shot("raptor_telegraph")
	await _until(func() -> bool: return _leaping(pack) != null, 1.5, "a raptor in the air")
	var leaper := _leaping(pack)
	if leaper != null:
		_player_view(guard.global_position + Vector3.UP * guard.eye_height, leaper.global_position + Vector3.UP * 0.6)
		await _shot("raptor_leap")
	dev.clear_enemies()


func _portrait_moments() -> void:
	var guard := dev.player
	for portrait in dev.portraits:
		portrait.target = guard
	# keep them asleep: the guard far away
	_player_view(Vector3(-4.0, 1.7, 16.0), Vector3(-22.0, 2.3, 0.0))
	await _seconds(0.3)
	var wall_center := Vector3(ContentDev.GALLERY_X, ContentDev.GALLERY_HEIGHT, 0.0)
	_free_view(Vector3(-13.0, 1.9, 0.0), wall_center)
	await _shot("gallery_asleep")
	var portrait: Portrait = dev.portraits[0]
	var face := portrait.global_position
	# the guard walks up: the eyes follow him
	_player_view(face + Vector3(6.5, -0.6, 3.0), face)
	await _until(func() -> bool: return portrait.eyes_tracking(), 1.0, "portrait eyes track")
	await _seconds(0.4)
	_free_view(face + Vector3(1.4, -0.1, 0.3), face)
	await _shot("portrait_eyes_tracking")
	await _until(func() -> bool: return portrait.vulnerable(), 2.0, "portrait pushes out")
	await _seconds(0.5)
	_free_view(face + Vector3(3.5, -0.4, 3.2), face)
	await _shot("portrait_awake")
	await _until(func() -> bool: return portrait.brain.windup_progress() > 0.7, 3.0, "portrait winds up")
	_player_view(face + Vector3(6.5, -0.6, 3.0), face)
	await _shot("portrait_telegraph")
	await _until(func() -> bool: return _count(PaintBlob) > 0, 1.0, "paint blob in flight")
	await _seconds(0.25)
	var blob := _first(PaintBlob) as Node3D
	if blob != null:
		_free_view(blob.global_position + Vector3(0.5, 0.8, 3.2), blob.global_position)
		await _shot("portrait_paint_blob")
	await _until(func() -> bool: return _count(PaintPuddle) > 0, 2.0, "paint puddle")
	await _seconds(0.3)
	var puddle := _first(PaintPuddle) as Node3D
	if puddle != null:
		_player_view(puddle.global_position + Vector3(2.2, 1.7, 2.2), puddle.global_position)
		await _shot("paint_puddle")
	for node in dev.portraits:
		node.target = _camera   # stops spitting at the guard for the next shots


func _upgrade_moments() -> void:
	var guard := dev.player
	# keen ear: a wax figure winding up behind the guard
	guard.apply_upgrades({&"keen_ear": 1, &"second_wind": 1})
	_player_view(Vector3(0.0, 1.7, 10.0), Vector3(0.0, 1.5, 0.0))
	var figure := dev.spawn(&"wax", Vector3(0.6, 0.1, 11.4), true)
	await _until(func() -> bool: return not guard.threat_indicator.warnings().is_empty(), 3.0, "keen ear warning")
	await _seconds(0.1)
	await _shot("keen_ear_warning")
	if is_instance_valid(figure):
		figure.queue_free()
	# second wind: the killing blow
	guard.health.max_health = 100.0
	guard.health.reset()
	RunState.used.erase(Player.SECOND_WIND)
	guard.take_damage(DamageInfo.make(150.0, DamageInfo.Kind.BLUNT))
	_note("second wind left health", guard.health.current)
	await _seconds(0.5)
	await _shot("second_wind")
	guard.health.max_health = 1000000.0
	guard.health.reset()
	await _seconds(2.0)
	# the terminal lists the new upgrades
	GameState.upgrades = {&"health": 1, &"pockets": 1, &"gatling_spin": 1}
	for id in [&"pistol", &"shotgun", &"gatling"]:
		GameState.add_weapon(id)
	RunState.add_dust(140, false)
	var menu := UpgradeMenu.new()
	add_child(menu)
	menu.open(GameState, RunState)
	menu.select(menu._row_ids.find(&"pockets"))
	await _settle()
	await _shot("terminal_guard_upgrades")
	menu.select(menu._row_ids.find(&"flare_twin"))
	await _settle()
	await _shot("terminal_weapon_upgrades")
	_note("terminal rows", menu._row_ids.size())
	menu.close()


func _hold_fire(seconds: float) -> void:
	var frames := int(seconds * Engine.physics_ticks_per_second)
	for i in frames:
		await get_tree().physics_frame
		dev.player.weapons.try_fire()


func _burning() -> FlareLight:
	for flare in _all(FlareLight):
		if (flare as FlareLight).burning():
			return flare
	return null


func _crouching(pack: Array[Raptor]) -> Raptor:
	for raptor in pack:
		if is_instance_valid(raptor) and raptor.crouch() > 0.6:
			return raptor
	return null


func _leaping(pack: Array[Raptor]) -> Raptor:
	for raptor in pack:
		if is_instance_valid(raptor) and raptor.brain.has_struck() and not raptor.is_on_floor():
			return raptor
	return null


func _on_watchdog() -> void:
	print("MISSED: the %s run did not finish within %d s (watchdog)" % [_mode, int(WATCHDOG_SECONDS)])
	Sfx.quit_cleanly(1)


# --- staging helpers ----------------------------------------------------

## The guard's own eyes (HUD included) at [param eye], looking at [param look].
func _player_view(eye: Vector3, look: Vector3) -> void:
	var guard := dev.player
	guard.global_position = eye - Vector3.UP * guard.eye_height
	guard.velocity = Vector3.ZERO
	guard.reset_physics_interpolation()
	var dir := (look - eye).normalized()
	guard.head.rotation = Vector3(asin(dir.y), atan2(-dir.x, -dir.z), 0.0)
	guard.head.global_position = eye
	guard.camera.current = true


## A free camera (the guard stays where he is).
func _free_view(eye: Vector3, look: Vector3) -> void:
	_camera.global_position = eye
	_camera.look_at(look)
	_camera.reset_physics_interpolation()   # a cut, not a glide from the last spot
	_camera.current = true


func _until(condition: Callable, timeout: float, label: String) -> bool:
	var waited := 0.0
	while waited < timeout:
		if condition.call():
			_note(label, true)
			return true
		await get_tree().physics_frame
		waited += 1.0 / Engine.physics_ticks_per_second
	var ok: bool = condition.call()
	_note(label, ok)
	if not ok:
		print("MISSED: ", label)
	return ok


func _seconds(duration: float) -> void:
	await get_tree().create_timer(duration, true, true).timeout


func _all(type: Variant) -> Array[Node]:
	var found: Array[Node] = []
	for node in dev.find_children("*", "", true, false):
		if is_instance_of(node, type) and not node.is_queued_for_deletion():
			found.append(node)
	return found


func _count(type: Variant) -> int:
	return _all(type).size()


func _first(type: Variant) -> Node:
	var found := _all(type)
	return found[0] if not found.is_empty() else null


func _settle() -> void:
	for i in 3:
		await get_tree().process_frame


func _shot(label: String) -> void:
	if _mode == "dry":
		_note("shot " + label, "skipped (headless)")
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OUT_DIR.path_join("%s.png" % label)
	image.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _note(key: String, value: Variant) -> void:
	_log.append([key, value])
	if _mode == "dry":
		print("  %s: %s" % [key, value])


func _write_log() -> void:
	var entries := {}
	for entry in _log:
		entries[entry[0]] = entry[1]
	var file := FileAccess.open(OUT_DIR.path_join("%s.json" % _mode), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(entries, "  "))
		file.close()
