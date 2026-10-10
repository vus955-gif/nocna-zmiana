class_name BossDev
extends Node3D
## Dev arena for the lobby boss fight (stage 2c-1, not part of the game
## flow): a 36 x 44 m hall laid out like the lobby's main hall (four columns
## at (+-10, +-8), the T-Rex on its 12 x 6 m pedestal in profile to the
## entrance, skylight strips), the guard with every weapon and full pockets,
## the HUD, pickups, a dev overlay and keys to drive the fight. The boss's
## roar calls wax figures from six spots along the walls.
## Run: bash tools/run_boss.sh

const HALL := Vector2(36.0, 44.0)
const WALL_HEIGHT := 14.0
const COLUMN_SIZE := 2.0
const COLUMNS: Array[Vector3] = [Vector3(-10, 0, -8), Vector3(10, 0, -8), Vector3(-10, 0, 8), Vector3(10, 0, 8)]
const PEDESTAL_CENTER := Vector3(0.0, 0.6, -11.0)
const PEDESTAL_SIZE := Vector3(12.0, 1.2, 6.0)
const BOSS_START := Vector3(0.5, 1.25, -11.0)
## Facing west: seen in profile from the entrance (south).
const BOSS_YAW := PI * 0.5
const PLAYER_START := Vector3(0.0, 0.1, 16.0)
const RESPAWN_DELAY := 2.0
## Where the roar's wax figures step out of the shadows along the walls.
const SUMMON_POINTS: Array[Vector3] = [
	Vector3(-16, 0.1, -18), Vector3(16, 0.1, -18), Vector3(-16.5, 0.1, 2),
	Vector3(16.5, 0.1, 2), Vector3(-9, 0.1, 20), Vector3(9, 0.1, 20),
]
const BUST_POINTS: Array[Vector3] = [Vector3(-14, 0.1, -3), Vector3(14, 0.1, -3), Vector3(0, 0.1, 6)]
const FLOOR := Color(0.36, 0.35, 0.37)
const WALL := Color(0.55, 0.52, 0.48)
const STONE := Color(0.5, 0.47, 0.43)
const KEYS := "B obudź T-Reksa   N popiersia   F5 figury woskowe   F8 usuń eksponaty   K następna faza   T nowy T-Rex"

var player: Player
var hud: Hud
var boss: TRex = null
var exhibits: Node3D
var _overlay: Label
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var region := NavigationRegion3D.new()
	region.name = "Hall"
	add_child(region)
	build_hall(region, self)
	add_lighting(self)
	region.bake_navigation_mesh(false)
	exhibits = Node3D.new()
	exhibits.name = "Exhibits"
	add_child(exhibits)
	player = Player.new()
	player.position = PLAYER_START
	add_child(player)
	for id in [&"taser", &"pistol", &"shotgun"]:
		player.weapons.give(load("res://src/weapons/data/%s.tres" % id))
	for state in player.weapons.owned:
		state.reserve = state.data.max_reserve
	player.weapons.select_id(&"pistol")
	hud = Hud.new()
	hud.player = player
	add_child(hud)
	hud.hide_help()
	# Esc: the shared pause menu (it also owns the cursor, through GameInput)
	var pause_menu := PauseMenu.new()
	pause_menu.quit_to_menu_requested.connect(_leave.bind(SceneFlow.MAIN_MENU))
	pause_menu.quit_game_requested.connect(_leave.bind(""))
	add_child(pause_menu)
	_add_overlay()
	_place_pickups()
	reset_boss()
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


## A fresh dormant T-Rex on the pedestal (the old one and its bones go).
func reset_boss() -> TRex:
	if is_instance_valid(boss):
		boss.queue_free()
	var old_remains := get_node_or_null(^"TRexRemains")
	if old_remains != null:
		old_remains.name = "OldRemains"
		old_remains.queue_free()
	boss = TRex.new()
	boss.position = BOSS_START
	boss.rotation.y = BOSS_YAW
	boss.target = player
	boss.summon = summon_wax
	add_child(boss)
	return boss


## Brings the boss down to its next phase threshold (then kills it).
func boss_to_next_phase() -> void:
	if not is_instance_valid(boss) or boss.is_dead():
		return
	if boss.is_dormant():
		boss.wake()
	var fraction := boss.health.fraction()
	var goal := TRexBrain.PHASE_2_AT
	if fraction <= TRexBrain.PHASE_3_AT:
		goal = 0.0
	elif fraction <= TRexBrain.PHASE_2_AT:
		goal = TRexBrain.PHASE_3_AT
	var info := DamageInfo.make(maxf(boss.health.current - goal * boss.max_health, 1.0), DamageInfo.Kind.BALLISTIC, null)
	info.position = boss.skeleton.crystal_position()
	info.direction = Vector3.FORWARD
	boss.take_zone_damage(info, TRexBrain.Zone.CRYSTAL)


## The roar's summon: [param count] awake wax figures at the wall spots.
func summon_wax(count: int) -> Array:
	var spots := SUMMON_POINTS.duplicate()
	for i in range(spots.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap: Vector3 = spots[i]
		spots[i] = spots[j]
		spots[j] = swap
	var called: Array = []
	for i in count:
		var at: Vector3 = spots[i % spots.size()]
		Fx.impact(at + Vector3.UP * 1.0, Vector3.UP, ExhibitMaterial.Kind.WAX, 2.0)
		called.append(spawn_wax(at, true))
	return called


func spawn_wax(at: Vector3, awake: bool) -> WaxFigure:
	var figure := WaxFigure.new()
	_place(figure, at, awake)
	return figure


func spawn_bust(at: Vector3, awake: bool) -> Bust:
	var bust := Bust.new()
	_place(bust, at, awake)
	return bust


func clear_exhibits() -> void:
	for node in exhibits.get_children():
		exhibits.remove_child(node)
		node.queue_free()


func _place(enemy: Enemy, at: Vector3, awake: bool) -> void:
	enemy.position = at
	enemy.target = player
	enemy.summoned = awake   # called into the boss fight: no bounds
	exhibits.add_child(enemy)
	enemy.face(player.global_position)
	if awake:
		enemy.brain.wake()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.physical_keycode:
			KEY_B:
				if is_instance_valid(boss):
					boss.wake()
			KEY_N:
				for at in BUST_POINTS:
					spawn_bust(at, true)
			KEY_K:
				boss_to_next_phase()
			KEY_T:
				reset_boss()
	if event.is_action_pressed(&"spawn_wax"):
		summon_wax(3)
	elif event.is_action_pressed(&"clear_enemies"):
		clear_exhibits()


func _process(_delta: float) -> void:
	if not is_instance_valid(boss):
		_overlay.text = "T-REX POKONANY   (T — nowy)\n" + KEYS
		return
	_overlay.text = "T-REX  %d / %d   faza %d   %s\n%s" % [
		ceili(boss.health.current), int(boss.max_health), boss.phase,
		TRexBrain.State.keys()[boss.brain.state], KEYS]


func _on_player_died() -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(RESPAWN_DELAY, false).timeout
	if not is_inside_tree():
		return   # the arena was left while it waited
	if is_instance_valid(player) and not player.alive:
		player.respawn(PLAYER_START)
		for state in player.weapons.owned:
			state.reserve = state.data.max_reserve


func _add_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 11
	add_child(layer)
	var settings := LabelSettings.new()
	settings.font_size = 18
	settings.font_color = Color(1.0, 0.85, 0.8)
	settings.outline_size = 5
	settings.outline_color = Color(0.0, 0.0, 0.0, 0.85)
	_overlay = Label.new()
	_overlay.label_settings = settings
	_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 16)
	_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _place_pickups() -> void:
	var layout := [
		[Pickup.Type.BULLETS, 24, Vector3(-16.0, 0.5, 14.0)],
		[Pickup.Type.BULLETS, 24, Vector3(16.0, 0.5, 14.0)],
		[Pickup.Type.SHELLS, 6, Vector3(-16.0, 0.5, -6.0)],
		[Pickup.Type.SHELLS, 6, Vector3(16.0, 0.5, -6.0)],
		[Pickup.Type.MEDKIT, 25, Vector3(-6.0, 0.5, 18.0)],
		[Pickup.Type.MEDKIT, 25, Vector3(6.0, 0.5, 18.0)],
	]
	for entry in layout:
		var pickup := Pickup.new()
		pickup.type = entry[0]
		pickup.amount = entry[1]
		pickup.position = entry[2]
		add_child(pickup)


## Floor, walls, columns and pedestal (into the navigation [param region])
## and a roof with three skylight strips (into [param root], so no navmesh
## grows on top of it).
static func build_hall(region: NavigationRegion3D, root: Node3D) -> void:
	var navmesh := NavigationMesh.new()
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_collision_mask = Layers.WORLD
	navmesh.agent_radius = 0.5
	navmesh.agent_height = 2.0
	navmesh.cell_height = 0.1
	navmesh.agent_max_climb = 0.1
	navmesh.agent_max_slope = 40.0
	region.navigation_mesh = navmesh
	var half := HALL * 0.5
	Greybox.box(region, Vector3(0, -0.5, 0), Vector3(HALL.x, 1, HALL.y), FLOOR)
	Greybox.box(region, Vector3(0, WALL_HEIGHT * 0.5, -half.y - 0.5), Vector3(HALL.x + 2, WALL_HEIGHT, 1), WALL)
	Greybox.box(region, Vector3(0, WALL_HEIGHT * 0.5, half.y + 0.5), Vector3(HALL.x + 2, WALL_HEIGHT, 1), WALL)
	Greybox.box(region, Vector3(-half.x - 0.5, WALL_HEIGHT * 0.5, 0), Vector3(1, WALL_HEIGHT, HALL.y), WALL)
	Greybox.box(region, Vector3(half.x + 0.5, WALL_HEIGHT * 0.5, 0), Vector3(1, WALL_HEIGHT, HALL.y), WALL)
	for at in COLUMNS:
		Greybox.box(region, at + Vector3.UP * WALL_HEIGHT * 0.5, Vector3(COLUMN_SIZE, WALL_HEIGHT, COLUMN_SIZE), STONE)
	Greybox.box(region, PEDESTAL_CENTER, PEDESTAL_SIZE, STONE)
	# roof slabs between three skylight strips (z -13.5..-10.5, -1.5..1.5, 10.5..13.5)
	for span in [Vector2(-22.0, -13.5), Vector2(-10.5, -1.5), Vector2(1.5, 10.5), Vector2(13.5, 22.0)]:
		var depth: float = span.y - span.x
		Greybox.box(root, Vector3(0, WALL_HEIGHT + 0.3, (span.x + span.y) * 0.5), Vector3(HALL.x + 2, 0.6, depth), WALL)


static func add_lighting(parent: Node) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.48, 0.62)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.glow_enabled = true
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.014
	env.volumetric_fog_albedo = Color(0.8, 0.85, 1.0)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.68, 0.76, 1.0)
	moon.light_energy = 1.1
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-62.0, 25.0, 0.0)
	parent.add_child(moon)
	for at in COLUMNS:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.76, 0.48)
		lamp.light_energy = 1.8
		lamp.omni_range = 13.0
		lamp.shadow_enabled = true
		lamp.position = at + Vector3(0.0, 6.0, 0.0) - at.normalized() * 1.3
		parent.add_child(lamp)
	for x in [-14.0, 14.0]:
		var alarm := OmniLight3D.new()
		alarm.light_color = Color(1.0, 0.15, 0.1)
		alarm.light_energy = 1.2
		alarm.omni_range = 9.0
		alarm.position = Vector3(x, 4.0, -21.0)
		parent.add_child(alarm)
	var particle_floor := GPUParticlesCollisionHeightField3D.new()
	particle_floor.size = Vector3(HALL.x, 14.0, HALL.y)
	particle_floor.position = Vector3(0.0, 6.0, 0.0)
	particle_floor.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_512
	parent.add_child(particle_floor)
