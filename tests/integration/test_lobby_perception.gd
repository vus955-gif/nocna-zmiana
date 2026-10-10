extends TestCase
## Exhibit perception in the real lobby (design pietro-1-projekt 7.2 and
## 12): the light model reads the lobby's lamps, noise carries through open
## doors only, a dark armory hides the guard until his flashlight comes on,
## and the first night lets him out of the booth without a horde.

var level: LobbyLevel
var museum: Museum
var target: TargetDummy


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _lobby() -> void:
	level = LobbyLevel.new()
	add_child(level)
	level.build()
	LevelPerception.configure_lobby(level)
	target = TargetDummy.new()
	target.position = Vector3(0, 0, 30)   # in the diorama, out of the way
	add_child(target)
	await physics_frames(6)


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _exhibit(kind: GDScript, at: Vector3, toward: Vector3, who: Node3D = null) -> Enemy:
	var enemy: Enemy = kind.new()
	enemy.position = at
	enemy.target = who if who != null else target
	add_child(enemy)
	enemy.face(toward)
	return enemy


func test_the_light_model_reads_the_lobbys_lamps() -> void:
	await _lobby()
	assert_gt(PerceptionWorld.light_at(Vector3(-13, 1, 0)), PerceptionRules.LIT_LEVEL, "the hall is lit")
	assert_gt(PerceptionWorld.light_at(Vector3(-30, 1, 0)), PerceptionRules.LIT_LEVEL, "so is the gallery")
	assert_eq(PerceptionWorld.room_at(Vector3(-30, 1, 0)), &"gallery")
	NightModifiers.set_lights(level, LightSpec.MAIN, false)   # a blackout
	assert_lt(PerceptionWorld.light_at(Vector3(-13, 1, 0)), PerceptionRules.DIM_LEVEL, "dark without power")
	assert_almost_eq(PerceptionWorld.light_at(Vector3(0, 1, 0)), LayoutIllumination.MOON_LEVEL, 0.05, "the moon under the roof lights")
	assert_gt(PerceptionWorld.light_at(Vector3(0, 1, 58)), PerceptionRules.LIT_LEVEL, "the booth keeps its own lamps")


func test_doors_and_rooms_come_from_the_lobby() -> void:
	await _lobby()
	assert_true(PerceptionWorld.is_door_open(&"door_hall_gallery"))
	(level.doors[&"door_hall_gallery"] as Door).close(true)
	assert_false(PerceptionWorld.is_door_open(&"door_hall_gallery"))
	assert_true(PerceptionWorld.is_door_open(&"stairs_w"), "stairs are always open")
	var knight := _exhibit(Knight, Vector3(30, 0, -12), Vector3(30, 0, 0))
	await physics_frames(2)
	assert_eq(knight.bounds_rooms(), [&"armory", &"hall", &"corridor_e"] as Array[StringName], "home and the rooms next door")


func test_a_shot_by_a_wing_door_is_heard_through_it_only_while_it_stands_open() -> void:
	await _lobby()
	var gallery := _exhibit(WaxFigure, Vector3(-23, 0, 0), Vector3(-40, 0, 0))
	var armory := _exhibit(WaxFigure, Vector3(22, 0, 0), Vector3(40, 0, 0))
	await physics_frames(2)
	var pistol := PerceptionRules.weapon_noise(&"pistol")
	# 9 m from the gallery figure, one passage away: 18 x 0.6 = 10.8 m
	(level.doors[&"door_hall_gallery"] as Door).close(true)
	Events.noise_made.emit(Vector3(-14, 0, 0), pistol, &"pistol")
	assert_eq(gallery.brain.state, EnemyBrain.State.DORMANT, "the closed door stops the shot")
	(level.doors[&"door_hall_gallery"] as Door).open(true)
	Events.noise_made.emit(Vector3(-14, 0, 0), pistol, &"pistol")
	assert_eq(gallery.brain.state, EnemyBrain.State.SUSPICIOUS, "through the open door it is heard")
	# the same by the armory's door
	(level.doors[&"door_hall_armory"] as Door).close(true)
	Events.noise_made.emit(Vector3(14, 0, 0), pistol, &"pistol")
	assert_eq(armory.brain.state, EnemyBrain.State.DORMANT, "the armory hears nothing behind its closed door")
	# a gatling burst in the gallery never reaches the armory
	Events.noise_made.emit(Vector3(-21, 0, 0), PerceptionRules.weapon_noise(&"gatling"), &"gatling")
	assert_eq(armory.brain.state, EnemyBrain.State.DORMANT, "a shot in the gallery is not heard in the armory")
	(level.doors[&"door_hall_armory"] as Door).open(true)
	Events.noise_made.emit(Vector3(14, 0, 0), pistol, &"pistol")
	assert_eq(armory.brain.state, EnemyBrain.State.SUSPICIOUS)


func test_in_an_unlit_armory_only_the_flashlight_gives_the_guard_away() -> void:
	await _lobby()
	NightModifiers.set_lights(level, LightSpec.MAIN, false)   # a blackout
	var guard := Player.new()
	guard.position = Vector3(30, 0.05, -2.5)
	add_child(guard)
	var knight := _exhibit(Knight, Vector3(30, 0, -12), Vector3(30, 0, -2.5), guard)
	await _seconds(1.5)
	assert_lt(PerceptionWorld.guard_light(guard), PerceptionRules.DIM_LEVEL, "the armory is dark")
	assert_eq(knight.brain.state, EnemyBrain.State.DORMANT, "a knight 9.5 m ahead does not see him")
	assert_true(guard.set_flashlight(true))
	await _seconds(0.6)
	assert_ne(knight.brain.state, EnemyBrain.State.DORMANT, "with the flashlight on it does")
	assert_true(knight.brain.spotted())


## Design 12: "leaving the booth, within 30 m at most 2 exhibits hunt during
## the first 60 s" - the guard walks out through the staff corridor and the
## diorama into the hall and looks round there, on night 1 of two games.
func test_leaving_the_booth_on_the_first_night_draws_no_horde() -> void:
	for game_seed in [20261002, 77]:
		GameState.new_game()
		GameState.seed_base = game_seed
		museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
		add_child(museum)
		await physics_frames(10)
		assert_true(PerceptionWorld.has_rooms(), "the night configured the lobby's perception")
		var soundly := museum.exhibits().filter(func(e: Enemy) -> bool: return e.sound_asleep > 0.0)
		assert_gt(soundly.size(), 2, "the sleepers on the way out sleep soundly")
		for exhibit: Enemy in soundly:
			assert_true(NightDirector.first_way(museum.lobby.describe()).has(exhibit.home_room))
		var most := await _walk_out(museum.player, 60.0)
		print("  night 1, game %d: at most %d hunting within 30 m in the first 60 s" % [game_seed, most])
		assert_lt(most, 3, "seed %d: %d exhibits hunted him at once" % [game_seed, most])
		museum.free()
		await physics_frames(2)


## Walks the guard from the booth to the hall and round its south end at a
## walk; returns the most exhibits hunting within 30 m of him at once.
func _walk_out(guard: Player, seconds: float) -> int:
	var path: Array[Vector3] = [Vector3(0, 0.1, 57), Vector3(0, 0.1, 50), Vector3(0, 0.1, 44.2), Vector3(0, 0.1, 34),
			Vector3(0, 0.1, 25), Vector3(0, 0.1, 19), Vector3(-6, 0.1, 17), Vector3(6, 0.1, 17), Vector3(0, 0.1, 19)]
	var at := guard.global_position
	var leg := 0
	var step := guard.walk_speed / Engine.physics_ticks_per_second
	var most := 0
	for frame in roundi(seconds * Engine.physics_ticks_per_second):
		var goal := path[leg]
		var to := goal - at
		if to.length() <= step:
			at = goal
			leg = (leg + 1) if leg < path.size() - 1 else 5   # then pace the hall's south end
		else:
			at += to.normalized() * step
		guard.global_position = at
		guard.velocity = Vector3.ZERO
		await get_tree().physics_frame
		var hunting := 0
		for exhibit in museum.exhibits():
			if exhibit.brain.is_hunting() and exhibit.global_position.distance_to(guard.global_position) <= PerceptionRules.HUNT_RADIUS:
				hunting += 1
		most = maxi(most, hunting)
	return most
