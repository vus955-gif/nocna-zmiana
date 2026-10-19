extends Node
## Windowed visual check (not part of the headless suite). Loads the
## sandbox, stages one moment, saves screenshots and a JSON state dump to
## tests/_out/. Usage: bash tools/run_scenario.sh <name>, where name is one
## of: overview, shotgun_gib, taser_finisher, knight_block, wolf_pounce, perf,
## ui_2a, gun_feel (every weapon's shot, hit and kill on a wax figure, its
## marks on wood, metal, carpet and stone, the sprint carry; plan
## 2026-10-19-gun-feel). All but "perf" and "ui_2a" run in a 1280x720 window; "perf"
## maximizes the window and measures the average frame rate; "ui_2a" runs
## in 1600x900 and shoots the stage-2a screens into tests/_out/2a/ (main
## menu, options, HUD, terminal, pause, death screen, the hall at night).
## Saves and settings go to tests/_out/saves (SavePaths), never the real ones.

const OUT_DIR := "res://tests/_out/"
const UI_DIR := "res://tests/_out/2a/"

var sandbox: Sandbox
var _scenario := "overview"


func _ready() -> void:
	Museum.level_id = &"lobby"   # a lobby scenario (the game plays Floor I)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			_scenario = arg.trim_prefix("--scenario=")
	GameInput.capture_allowed = false
	if _scenario == "perf":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1600, 900) if _scenario == "ui_2a" else Vector2i(1280, 720))
	var out := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out)
	var ignore := FileAccess.open(out.path_join(".gdignore"), FileAccess.WRITE)
	ignore.close()
	if _scenario == "ui_2a":
		await _ui_2a()
		Sfx.quit_cleanly(0)
		return
	sandbox = (load("res://src/arena/sandbox.tscn") as PackedScene).instantiate() as Sandbox
	add_child(sandbox)
	await _frames(60)   # let shaders compile before judging anything
	match _scenario:
		"overview":
			await _overview()
		"shotgun_gib":
			await _shotgun_gib()
		"taser_finisher":
			await _taser_finisher()
		"knight_block":
			await _knight_block()
		"wolf_pounce":
			await _wolf_pounce()
		"perf":
			await _perf()
		"gun_feel":
			await _gun_feel()
		_:
			print("Unknown scenario: ", _scenario)
	_dump_state()
	Sfx.quit_cleanly(0)   # stops sounds and gives the audio thread time before quitting


func _overview() -> void:
	await _shot("help")
	sandbox.hud.hide_help()
	sandbox.player.head.rotation.y = deg_to_rad(40.0)
	await _frames(5)
	await _shot("turned")
	sandbox.player.set_flashlight(true)
	sandbox.player.head.rotation = Vector3(deg_to_rad(-10.0), deg_to_rad(-30.0), 0.0)
	await _frames(5)
	await _shot("flashlight")


func _shotgun_gib() -> void:
	var guard := sandbox.player
	sandbox.hud.hide_help()
	sandbox.clear_enemies()
	sandbox.spawn(&"wax", guard.global_position + Vector3(0.0, 0.0, -3.0), false)
	guard.weapons.select_id(&"shotgun")
	guard.head.rotation.x = deg_to_rad(-12.0)   # aim at the torso so every pellet lands
	await _frames(40)
	await _shot("before")
	guard.weapons.try_fire()
	await _frames(2)
	await _shot("t02")
	await _frames(6)
	await _shot("t08")
	await _frames(40)
	await _shot("t48")


func _taser_finisher() -> void:
	var guard := sandbox.player
	sandbox.hud.hide_help()
	sandbox.clear_enemies()
	var wax := sandbox.spawn(&"wax", guard.global_position + Vector3(0.0, 0.0, -1.4), false)
	guard.weapons.select_id(&"taser")
	await _frames(30)
	guard.weapons.try_fire()
	await _frames(3)
	await _shot("zap")
	await _frames(20)
	await _shot("stunned")
	guard.weapons.try_punch()
	await _frames(4)
	await _shot("finisher")
	print("wax destroyed by finisher: ", not is_instance_valid(wax) or wax.is_queued_for_deletion())


func _knight_block() -> void:
	var guard := sandbox.player
	sandbox.hud.hide_help()
	sandbox.clear_enemies()
	var knight := sandbox.spawn(&"knight", guard.global_position + Vector3(0.0, 0.0, -4.0), false)
	guard.weapons.select_id(&"pistol")
	await _frames(20)
	guard.weapons.try_fire()
	await _frames(2)
	await _shot("blocked")
	print("knight health after a frontal shot: ", knight.health.current)


func _wolf_pounce() -> void:
	sandbox.hud.hide_help()
	sandbox.clear_enemies()
	sandbox.spawn(&"wolf", sandbox.player.global_position + Vector3(0.0, 0.0, -9.0), true)
	for i in 6:
		await _frames(10)
		await _shot("t%02d" % ((i + 1) * 10))


## Every weapon on a sturdy wax figure 4.5 m ahead: just after the shot
## (flash, kick), the kick's peak (the view, the flinch), the settle, then a
## killing shot; the marks of the pistol, shotgun and rifle on tagged
## panels; the weapon carried for a sprint. The view's and the model's kick
## peaks are printed per weapon.
func _gun_feel() -> void:
	var guard := sandbox.player
	sandbox.hud.hide_help()
	sandbox.clear_enemies()
	for id in [&"gatling", &"flare", &"rifle_hunt", &"harpoon", &"hwacha"]:
		guard.weapons.give(load("res://src/weapons/data/%s.tres" % id))
	var start := guard.global_position
	for id: StringName in [&"taser", &"pistol", &"shotgun", &"gatling", &"flare", &"rifle_hunt", &"harpoon", &"hwacha"]:
		sandbox.clear_enemies()
		Fx.clear()
		guard.respawn(start, 0.0)
		guard.head.rotation.x = deg_to_rad(-6.0)
		var wax := sandbox.spawn(&"wax", start + Vector3(0.0, 0.0, -4.5), false)
		wax.health.max_health = 600.0
		wax.health.current = 600.0
		wax.set_physics_process(false)   # it stands where it is hit (its flinch is its own)
		for state in guard.weapons.owned:
			state.reserve = state.data.max_reserve
			state.magazine = state.data.magazine_size
			state.battery = state.data.battery_max
		guard.weapons.select_id(id)
		await _frames(50)
		if id == &"pistol" or id == &"shotgun":
			await _shot("%s_0" % id)
		var top := Vector3.ZERO
		if id == &"gatling":
			for i in 50:
				guard.weapons.try_fire()
				await _frames(1)
			await _shot("%s_a" % id)
			for i in 8:
				guard.weapons.try_fire()
				await _frames(1)
			await _shot("%s_b" % id)
		else:
			guard.weapons.try_fire()
			await _frames(1)
			await _shot("%s_a" % id)
			for i in 3:
				await _frames(1)
				top = top.max(Vector3(rad_to_deg(guard.camera.rotation.x), guard.weapons.view_kick()[0], guard.weapons.view_kick()[3]))
			await _shot("%s_b" % id)
			await _frames(10)
			await _shot("%s_c" % id)
		print("%s: view kick %.2f deg, model back %.3f m, climb %.1f deg, trauma %.2f" % [id, top.x, top.y, top.z, guard.camera.trauma.value])
		await _frames(70)
		if is_instance_valid(wax) and not wax.is_queued_for_deletion():
			wax.health.current = 1.0
			for state in guard.weapons.owned:
				state.magazine = state.data.magazine_size
			guard.weapons.try_fire()
			await _frames(3)
			await _shot("%s_kill" % id)
			await _frames(12)
			await _shot("%s_kill2" % id)
		await _frames(30)
	# marks: three panels side by side 2.5 m ahead, shot by the pistol, the shotgun and the rifle
	sandbox.clear_enemies()
	Fx.clear()
	guard.respawn(start, 0.0)
	var panels: Array[StaticBody3D] = []
	for i in 3:
		var panel := Greybox.box(sandbox, start + Vector3(-1.4 + 1.4 * i, 1.5, -2.5), Vector3(1.3, 2.4, 0.1), Color(0.5, 0.48, 0.45))
		panel.set_meta(&"surface", [&"wood", &"steel", &"carpet"][i])
		panels.append(panel)
	await _frames(20)
	for i in 3:
		for id: StringName in [&"pistol", &"shotgun", &"rifle_hunt"]:
			guard.weapons.select_id(id)
			for state in guard.weapons.owned:
				state.magazine = state.data.magazine_size
			guard.head.rotation = Vector3(deg_to_rad([-10.0, 0.0, 10.0][[&"pistol", &"shotgun", &"rifle_hunt"].find(id)]), atan2(1.4 - 1.4 * i, 2.5), 0.0)
			await _frames(30)
			guard.weapons.try_fire()
			await _frames(4)
	guard.head.rotation = Vector3.ZERO
	await _frames(40)
	await _shot("marks")
	for panel in panels:
		panel.queue_free()
	# the sprint carry
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	guard.weapons.select_id(&"shotgun")
	await _frames(45)
	await _shot("sprint")
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")


func _perf() -> void:
	sandbox.hud.hide_help()
	var start := Time.get_ticks_usec()
	var frames := 0
	while Time.get_ticks_usec() - start < 4000000:
		await get_tree().process_frame
		frames += 1
	print("average FPS over 4 s at %s: %.0f" % [DisplayServer.window_get_size(), frames / 4.0])


## Stage 2a screens, each saved as tests/_out/2a/<name>.png.
func _ui_2a() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(UI_DIR))
	SavePaths.clear_test_dir()
	Settings.reset_to_defaults(false)
	GameState.new_game()
	GameState.night = 3
	GameState.run_dust = 34
	GameState.save_game()
	# the title screen and the options over it
	var menu := (load(SceneFlow.MAIN_MENU) as PackedScene).instantiate() as MainMenu
	add_child(menu)
	await _frames(40)
	await _ui_shot("main_menu")
	menu.options_button.pressed.emit()
	await _frames(8)
	await _ui_shot("options")
	menu.options.close()
	menu.queue_free()
	await _frames(2)
	# a night in the museum: the booth, the terminal in reach, Dust coming in
	var museum := (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	await _frames(90)   # shaders
	var guard := museum.player
	guard.respawn(Vector3(-17.5, 0.1, 15.4), 0.0)
	guard.head.rotation.x = deg_to_rad(-12.0)
	await _frames(20)
	RunState.add_dust(12)
	await _frames(6)
	await _ui_shot("hud")
	var terminal := museum.find_children("*", "UpgradeTerminal", true, false)[0] as UpgradeTerminal
	terminal.interact(guard)
	museum.upgrade_menu.select(museum.upgrade_menu._row_ids.find(&"pistol_damage"))
	await _frames(8)
	await _ui_shot("terminal")
	museum.upgrade_menu.close()
	await _frames(4)
	museum.pause_menu.open()
	await _frames(8)
	await _ui_shot("pause")
	museum.pause_menu.close()
	# the hall at night, flashlight on
	guard.respawn(Vector3(0.0, 0.1, 12.0), 0.0)
	guard.head.rotation.x = deg_to_rad(-4.0)
	guard.set_flashlight(true)
	await _frames(30)
	await _ui_shot("hall")
	# death: fade, 23:00
	guard.take_damage(DamageInfo.make(999.0, DamageInfo.Kind.BLUNT))
	await get_tree().create_timer(Museum.DEATH_DELAY + DeathScreen.FADE_TIME + 0.8).timeout
	await _ui_shot("death")
	await museum.next_night_requested
	museum.queue_free()
	await _frames(2)


func _ui_shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("dry run, no picture: ", label)   # --headless checks the staging only
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := UI_DIR.path_join("%s.png" % label)
	image.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OUT_DIR.path_join("%s_%s.png" % [_scenario, label])
	image.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _dump_state() -> void:
	var enemies: Array = []
	for node in sandbox.enemies_root.get_children():
		var enemy := node as Enemy
		if enemy != null and not enemy.is_queued_for_deletion():
			enemies.append({
				"type": enemy.get_script().get_global_name(),
				"state": EnemyBrain.State.keys()[enemy.brain.state],
				"health": enemy.health.current,
				"position": str(enemy.global_position),
			})
	var state := {
		"scenario": _scenario,
		"fps": Engine.get_frames_per_second(),
		"player": {
			"health": sandbox.player.health.current,
			"stamina": sandbox.player.stamina.current,
			"position": str(sandbox.player.global_position),
		},
		"enemies": enemies,
		"debris_chunks": Fx.chunk_count(),
	}
	var file := FileAccess.open(OUT_DIR.path_join("%s_state.json" % _scenario), FileAccess.WRITE)
	file.store_string(JSON.stringify(state, "  "))
	file.close()
