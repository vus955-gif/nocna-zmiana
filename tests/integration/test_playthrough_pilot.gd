extends TestCase
## The playthrough bot's hands (PlaythroughPilot) and legs (PlaythroughNav)
## on the real guard in the game's scene (Floor I, greybox): walking along
## the head's axes, turning like a mouse within its rate, E on the till
## drawer, the weapon keys, the trigger, the walk out of the booth to the
## drawer. (Some tests put the guard where they need him; the bot itself
## never does.)

const Pilot := preload("res://tests/support/playthrough_pilot.gd")

var museum: Museum
var driver: Driver


class Driver:
	extends Node
	var pilot: PlaythroughPilot
	var nav: PlaythroughNav = null

	func _ready() -> void:
		process_physics_priority = -100

	func _physics_process(delta: float) -> void:
		if nav != null:
			nav.update(delta)
		pilot.apply(delta)


func before_each() -> void:
	Museum.level_id = &"floor1"
	GameState.new_game()
	GameState.seed_base = 7
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	driver = Driver.new()
	driver.pilot = Pilot.new(museum.player)
	museum.add_child(driver)
	await physics_frames(3)


func after_each() -> void:
	if driver != null and driver.pilot != null:
		driver.pilot.release_all()
	if is_instance_valid(museum):
		museum.free()


func _floor_under(at: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP, at + Vector3.DOWN * 30.0, Layers.WORLD)
	var hit := museum.get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3) if not hit.is_empty() else at


func _put_guard(at: Vector3, yaw: float = 0.0) -> void:
	museum.player.global_position = at + Vector3.UP * 0.05
	museum.player.velocity = Vector3.ZERO
	museum.player.head.rotation = Vector3(0.0, yaw, 0.0)
	museum.player.reset_physics_interpolation()


func _court() -> Vector3:
	return _floor_under(Vector3(0, 1, 12))


func test_the_pilot_walks_along_the_world_and_sideways_while_looking_elsewhere() -> void:
	var pilot := driver.pilot
	_put_guard(_court(), 0.0)
	await physics_frames(5)
	var start := museum.player.global_position
	pilot.move(Vector3(1, 0, 0))
	await physics_frames(30)
	var moved := museum.player.global_position - start
	assert_gt(moved.x, 1.8, "half a second east at a walk (%s)" % moved)
	assert_lt(absf(moved.z), 0.3, "straight along the world's x")
	# looking north, walking west: a strafe
	var north := museum.player.global_position + Vector3(0, 1.6, -40)
	pilot.look_at_point(north)
	pilot.move(Vector3(-1, 0, 0))
	await physics_frames(40)
	start = museum.player.global_position
	await physics_frames(30)
	moved = museum.player.global_position - start
	assert_lt(moved.x, -1.8, "strafing west (%s)" % moved)
	assert_lt(pilot.aim_error(north), 1.0, "still looking at the point north")
	pilot.stop()
	await physics_frames(20)
	assert_lt(Vector2(museum.player.velocity.x, museum.player.velocity.z).length(), 0.2, "keys up: he stops")


func test_the_view_turns_like_a_mouse_within_its_rate() -> void:
	var pilot := driver.pilot
	_put_guard(_court(), 0.0)
	await physics_frames(3)
	var behind := museum.player.global_position + Vector3(0, 1.6, 15)
	var yaw_before := museum.player.head.rotation.y
	pilot.look_at_point(behind)
	await physics_frames(1)
	var turned := absf(wrapf(museum.player.head.rotation.y - yaw_before, -PI, PI))
	assert_lt(turned, deg_to_rad(PlaythroughPilot.TURN_RATE) / 60.0 * 2.0 + 0.001, "no snap")
	await physics_frames(40)
	assert_lt(pilot.aim_error(behind), 1.0, "on target within a second")
	# the bot that plays like a person turns slower
	pilot.turn_rate = PlaythroughBot.HUMAN_TURN_RATE
	var ahead := museum.player.global_position + Vector3(0, 1.6, -15)
	yaw_before = museum.player.head.rotation.y
	pilot.look_at_point(ahead)
	await physics_frames(1)
	turned = absf(wrapf(museum.player.head.rotation.y - yaw_before, -PI, PI))
	assert_lt(turned, deg_to_rad(PlaythroughBot.HUMAN_TURN_RATE) / 60.0 * 2.0 + 0.001, "at its own rate")
	await physics_frames(60)
	assert_lt(pilot.aim_error(ahead), 1.0, "on target within a second and a bit")


func test_e_on_the_till_drawer_takes_the_key() -> void:
	var pilot := driver.pilot
	var drawer := museum.floor_game.pickups.drawer
	var out := -drawer.global_basis.z
	_put_guard(_floor_under(drawer.global_position + out * 1.0), atan2(out.x, out.z))
	await physics_frames(3)
	pilot.look_at_point(drawer.global_position + drawer.global_basis * Vector3(0.0, -0.05, -0.18))
	await physics_frames(40)
	assert_eq(museum.player.interactor.focus, drawer as Interactable, "the drawer under the crosshair")
	assert_true(pilot.tap(&"interact"))
	await physics_frames(6)
	assert_true(GameState.pistol_key, "the key is his")


func test_the_weapon_keys_and_the_trigger() -> void:
	var pilot := driver.pilot
	Loadout.grant(museum.player, &"pistol", GameState)
	await physics_frames(2)
	_put_guard(_court(), 0.0)
	assert_eq(pilot.weapon(), &"taser", "the night starts with the taser in hand")
	assert_false(pilot.select_weapon(&"taser"), "in hand already")
	assert_true(pilot.select_weapon(&"pistol"))
	await physics_frames(3)
	assert_eq(pilot.weapon(), &"pistol")
	assert_true(pilot.select_weapon(&"taser"))
	await physics_frames(3)
	assert_eq(pilot.weapon(), &"taser")
	assert_true(pilot.select_weapon(&"pistol"))
	await physics_frames(3)
	assert_eq(pilot.weapon(), &"pistol")
	assert_false(pilot.select_weapon(&"hwacha"), "not his")
	await physics_frames(20)
	var pistol := museum.player.weapons.state_of(&"pistol")
	var before := pistol.magazine
	pilot.look_at_point(museum.player.global_position + Vector3(0, 1.0, -20))
	pilot.firing = true
	await physics_frames(20)
	pilot.firing = false
	assert_lt(pistol.magazine, before, "the trigger fires the pistol")
	var fired := before - pistol.magazine
	await physics_frames(20)
	assert_eq(before - pistol.magazine, fired, "the trigger let go: no more shots")


func test_out_of_the_booth_to_the_till_drawer_on_foot() -> void:
	var pilot := driver.pilot
	var nav := PlaythroughNav.new(museum.player, pilot, museum.floor_level)
	driver.nav = nav
	var drawer := museum.floor_game.pickups.drawer
	var front := _floor_under(drawer.global_position - drawer.global_basis.z * 1.0)
	assert_true(Haven.shelters(museum.player.global_position), "the night starts in the security room")
	var way := nav.path_to(front)
	assert_false(way.is_empty(), "a way out of the booth to the drawer")
	var started := museum.player.global_position
	assert_true(nav.go(front, 0.5))
	var frames := 0
	while nav.status == PlaythroughNav.Status.RUNNING and frames < 60 * 45:
		await physics_frames(1)
		frames += 1
	print("  booth -> till drawer: %.1f m of way, %.1f s, %d stuck" % [PlaythroughNav.length_of(way), frames / 60.0, nav.stuck_events.size()])
	assert_eq(nav.status, PlaythroughNav.Status.ARRIVED, "walked there (%s at %s, from %s)" % [nav.failure, museum.player.global_position, started])
	assert_eq(nav.stuck_events.size(), 0, "round the open door's leaf without catching on it: %s" % [nav.stuck_events])
	pilot.look_at_point(drawer.global_position + drawer.global_basis * Vector3(0.0, -0.05, -0.18))
	await physics_frames(40)
	assert_true(pilot.tap(&"interact"))
	await physics_frames(6)
	assert_true(GameState.pistol_key, "the key is his")
