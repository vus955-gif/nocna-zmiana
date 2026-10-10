class_name LobbyDev
extends Node3D
## Dev viewer: walk the lobby as the guard (all weapons) through a night
## drawn by NightDirector, with its exhibits dormant or awake as drawn.
## Command line (after --): --seed=N --night=N.
## Keys: F5 next night, F6 wake every exhibit, F7 main lights on/off
## (blackout preview), F8 teleport to the next room, F9 roofs on/off;
## Esc opens the shared pause menu (which owns the cursor via GameInput).
## Havens are made from the level's zones like the Museum does, so exhibits
## stay out of them and head home while the guard hides there.

const RESPAWN_DELAY := 2.0
## Rooms F8 cycles through.
const TOUR: Array[StringName] = [&"security", &"diorama", &"hall", &"balcony", &"gallery", &"armory", &"corridor_w", &"corridor_e", &"closet"]

var level: LobbyLevel
var player: Player
var hud: Hud
var enemies: Node3D
var config: NightConfig
var night_seed: int = 1
var night: int = 1
var _tour_index: int = 0
var _roofs := true


func _ready() -> void:
	var seed_given := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			night_seed = int(arg.trim_prefix("--seed="))
			seed_given = true
		elif arg.begins_with("--night="):
			night = maxi(int(arg.trim_prefix("--night=")), 1)
	if not seed_given:
		night_seed = randi()
	enemies = Node3D.new()
	enemies.name = "Exhibits"
	add_child(enemies)
	player = Player.new()
	add_child(player)
	for id in [&"taser", &"pistol", &"shotgun"]:
		player.weapons.give(load("res://src/weapons/data/%s.tres" % id))
	player.weapons.select_id(&"pistol")
	hud = Hud.new()
	hud.player = player
	add_child(hud)
	hud.hide_help()
	var pause_menu := PauseMenu.new()
	pause_menu.quit_to_menu_requested.connect(_leave.bind(SceneFlow.MAIN_MENU))
	pause_menu.quit_game_requested.connect(_leave.bind(""))
	add_child(pause_menu)
	Events.player_died.connect(_on_player_died)
	load_night()
	GameInput.set_gameplay_scene(true)


func _exit_tree() -> void:
	GameInput.set_gameplay_scene(false)
	PerceptionWorld.reset()


## Back to the main menu ([param path]) or out of the game ("").
func _leave(path: String) -> void:
	if not SceneFlow.is_running(self):
		return
	if path == "":
		SceneFlow.quit()
	else:
		SceneFlow.goto(path)


## (Re)builds the lobby for the current seed and night and places the guard
## on the security room chair.
func load_night() -> void:
	for exhibit in enemies.get_children():
		enemies.remove_child(exhibit)
		exhibit.queue_free()
	if level != null:
		remove_child(level)
		level.queue_free()
	config = NightDirector.plan(night_seed, night, LobbyLayout.describe(LobbyLayout.create()))
	level = LobbyLevel.new()
	level.name = "Lobby"
	level.night = config
	add_child(level)
	move_child(level, 0)
	level.build()
	for id: StringName in level.haven_zones:
		level.add_child(Haven.make(id, level.haven_zones[id]))
	_roofs = true
	var start := level.player_start
	player.respawn(start.origin, start.basis.get_euler().y)
	LevelPerception.configure_lobby(level, config.modifier)
	NightSpawner.spawn(config, level.spawn_slots, enemies, player)
	print("night %d, seed %d: modifier %s, locked door %s, crystal in %s, fuses %s, %d exhibits, artifacts %s" % [
		night, night_seed, config.modifier, config.locked_door if config.locked_door != &"" else &"none",
		config.crystal_case, config.fuses.values(), config.spawns.size(), config.artifacts])


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not GameInput.gameplay_input():
		return
	match key.physical_keycode:
		KEY_F5:
			night += 1
			night_seed = randi()
			load_night()
		KEY_F6:
			for exhibit in enemies.get_children():
				(exhibit as Enemy).brain.wake()
		KEY_F7:
			_toggle_group(LightSpec.MAIN)
		KEY_F8:
			_teleport_next()
		KEY_F9:
			_roofs = not _roofs
			level.set_roof_visible(_roofs)
		_:
			return
	get_viewport().set_input_as_handled()


func _toggle_group(group: StringName) -> void:
	var lights := get_tree().get_nodes_in_group(group)
	var on := lights.is_empty() or not (lights[0] as Node3D).visible
	for node in lights:
		(node as Node3D).visible = on
	for node in get_tree().get_nodes_in_group(StringName("%s_fixtures" % group)):
		(node as Node3D).visible = on


func _teleport_next() -> void:
	_tour_index = (_tour_index + 1) % TOUR.size()
	var room := level.layout.room(TOUR[_tour_index])
	var middle := room.parts[0].get_center()
	player.respawn(Vector3(middle.x, room.floor_y + 0.1, middle.y), player.head.rotation.y)
	print("teleported to ", room.id)


func _on_player_died() -> void:
	await get_tree().create_timer(RESPAWN_DELAY, false).timeout
	if is_instance_valid(player) and not player.alive:
		var start := level.player_start
		player.respawn(start.origin, start.basis.get_euler().y)
