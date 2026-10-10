class_name Sandbox
extends Node3D
## Combat sandbox (stage 1a, now a dev scene: tools/run_sandbox.sh): the
## grey hall, the guard with all weapons, HUD, a starting set of dormant
## exhibits, F5-F8 to spawn more (and clear them), respawning pickups, a quick respawn
## after death and the pause menu (Esc).

const PLAYER_START := Vector3(0.0, 0.1, 16.0)
const RESPAWN_DELAY := 2.0
## Group centres, clear of level geometry for the whole scatter (x 20 keeps
## a group off both the ramp, x <= 18, and the east wall, x >= 22).
const SPAWN_POINTS: Array[Vector3] = [
	Vector3(-15.0, 0.1, -8.0), Vector3(20.0, 0.1, -6.0), Vector3(-16.0, 0.1, 4.0),
	Vector3(16.0, 0.1, 6.0), Vector3(0.0, 0.1, -9.0), Vector3(-8.0, 3.9, -18.0),
]
const GROUP_SIZES := {&"wax": 3, &"wolf": 2, &"knight": 1}
## Group members stand up to this far (m, along x and z) from the centre.
const GROUP_SCATTER := 1.5

var player: Player
var hud: Hud
var pause_menu: PauseMenu
var enemies_root: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var region := NavigationRegion3D.new()
	region.name = "Arena"
	add_child(region)
	SandboxArena.build(region)
	SandboxArena.add_lighting(self)
	region.bake_navigation_mesh(false)
	enemies_root = Node3D.new()
	enemies_root.name = "Enemies"
	add_child(enemies_root)
	player = Player.new()
	player.position = PLAYER_START
	add_child(player)
	for id in [&"taser", &"pistol", &"shotgun"]:
		player.weapons.give(load("res://src/weapons/data/%s.tres" % id))
	player.weapons.select_id(&"pistol")
	hud = Hud.new()
	hud.player = player
	hud.help_keys = ["HUD_HELP_CONTROLS_P1", "HUD_HELP_SANDBOX_P1", "HUD_HELP_TIPS"]
	hud.always_show_fps = true
	add_child(hud)
	pause_menu = PauseMenu.new()
	pause_menu.quit_to_menu_requested.connect(_leave.bind(SceneFlow.MAIN_MENU))
	pause_menu.quit_game_requested.connect(_leave.bind(""))
	add_child(pause_menu)
	_place_pickups()
	_spawn_starting_exhibits()
	Events.player_died.connect(_on_player_died)
	GameInput.set_gameplay_scene(true)


func _exit_tree() -> void:
	GameInput.set_gameplay_scene(false)


## Back to the main menu ([param path]) or out of the game ("").
func _leave(path: String) -> void:
	if not SceneFlow.is_running(self):
		return
	if path == "":
		SceneFlow.quit()
	else:
		SceneFlow.goto(path)


## Spawns one exhibit ([param kind] = &"wax", &"wolf" or &"knight").
func spawn(kind: StringName, at: Vector3, awake: bool) -> Enemy:
	var enemy: Enemy
	match kind:
		&"wax":
			enemy = WaxFigure.new()
		&"wolf":
			enemy = Wolf.new()
		&"knight":
			enemy = Knight.new()
		_:
			return null
	enemy.position = at
	enemy.target = player
	enemy.summoned = awake   # an arena wave: it hunts the guard wherever he is
	enemies_root.add_child(enemy)
	enemy.face(player.global_position)
	if awake:
		enemy.brain.wake()
	return enemy


## Spawns an awake group at a random spawn point.
func spawn_group(kind: StringName) -> void:
	var base: Vector3 = SPAWN_POINTS[_rng.randi_range(0, SPAWN_POINTS.size() - 1)]
	var count: int = GROUP_SIZES.get(kind, 1)
	for i in count:
		var offset := Vector3.ZERO
		if i > 0:
			offset = Vector3(_rng.randf_range(-GROUP_SCATTER, GROUP_SCATTER), 0.0, _rng.randf_range(-GROUP_SCATTER, GROUP_SCATTER))
		spawn(kind, base + offset, true)


func clear_enemies() -> void:
	for enemy in enemies_root.get_children():
		enemies_root.remove_child(enemy)
		enemy.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"spawn_wax"):
		spawn_group(&"wax")
	elif event.is_action_pressed(&"spawn_wolf"):
		spawn_group(&"wolf")
	elif event.is_action_pressed(&"spawn_knight"):
		spawn_group(&"knight")
	elif event.is_action_pressed(&"clear_enemies"):
		clear_enemies()


func _spawn_starting_exhibits() -> void:
	for at in [Vector3(-6.0, 0.1, -6.0), Vector3(-4.5, 0.1, -7.5), Vector3(-7.5, 0.1, -8.5)]:
		spawn(&"wax", at, false)
	for at in [Vector3(11.0, 0.1, -10.0), Vector3(12.5, 0.1, -9.0)]:
		spawn(&"wolf", at, false)
	spawn(&"knight", Vector3(-10.0, 3.9, -18.0), false)


func _place_pickups() -> void:
	var layout := [
		[Pickup.Type.BULLETS, 12, Vector3(-18.0, 0.5, 18.0)],
		[Pickup.Type.BULLETS, 12, Vector3(18.0, 0.5, 18.0)],
		[Pickup.Type.SHELLS, 4, Vector3(-18.0, 0.5, -10.0)],
		[Pickup.Type.SHELLS, 4, Vector3(18.0, 0.5, 10.0)],
		[Pickup.Type.MEDKIT, 25, Vector3(0.0, 1.1, 0.0)],
		[Pickup.Type.MEDKIT, 25, Vector3(8.0, 4.25, -20.0)],
	]
	for entry in layout:
		var pickup := Pickup.new()
		pickup.type = entry[0]
		pickup.amount = entry[1]
		pickup.position = entry[2]
		add_child(pickup)


func _on_player_died() -> void:
	await get_tree().create_timer(RESPAWN_DELAY, false).timeout
	if is_instance_valid(player) and not player.alive:
		player.respawn(PLAYER_START)
