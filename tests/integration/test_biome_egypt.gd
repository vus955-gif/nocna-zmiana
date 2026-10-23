extends TestCase
## Egypt's curse plates (plan 2026-10-21-mechaniki-biomow, mechanic 1) in a
## sandbox: a plate in a floor fires the dart slits of the wall in front of
## it after a 0.7 s tell; whoever stands on the line then takes the volley
## (the guard a little, an exhibit a lot), a wall stops the darts, the guard
## who steps off in time is spared; alarmed walkers set it off, sleepers,
## the swarm and a jumping guard do not; the plate rearms after a while; the
## volley is a noise; dawn stops it.

## A 12 m hall along x: the mouth in the east wall (x 6) firing west, the
## plate on the line 4 m in.
const MOUTH := Vector3(6.0, 0.0, 0.0)
const PLATE := Vector3(2.0, 0.0, 0.0)

var host: BiomeMechanics
var trap: TombTrap
var player: Player


func before_each() -> void:
	GameInput.capture_allowed = false
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(30, 1, 30), Color.GRAY)
	Greybox.box(self, Vector3(6.5, 2.0, 0), Vector3(1, 4, 12), Color.GRAY)
	Greybox.box(self, Vector3(-6.5, 2.0, 0), Vector3(1, 4, 12), Color.GRAY)
	player = Player.new()
	player.position = Vector3(0, 0.05, 6)
	add_child(player)
	host = BiomeMechanics.new()
	host.guard_source = func() -> Player: return player
	add_child(host)
	trap = TombTrap.create({"plate": PLATE, "mouth": MOUTH, "dir": Vector3(-1, 0, 0), "length": 12.0})
	host.adopt(trap, &"egypt_test_trap", &"")
	await physics_frames(3)


func after_each() -> void:
	GameInput.capture_allowed = true


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _stand(at: Vector3) -> void:
	player.global_position = at + Vector3.UP * 0.02
	player.velocity = Vector3.ZERO
	await physics_frames(6)


func _wax(at: Vector3, alarmed: bool) -> WaxFigure:
	var wax := WaxFigure.new()
	wax.target = player
	wax.position = at
	add_child(wax)
	if alarmed:
		wax.brain.alarm(player.global_position)
	return wax


func test_the_plate_fires_the_line_after_the_tell() -> void:
	var full := player.health.current
	await _stand(PLATE)
	assert_eq(trap.phase, TombTrap.Phase.PRIMED, "the plate sinks at once")
	await _seconds(TombTrap.TELL - 0.2)
	assert_eq(player.health.current, full, "nothing flies during the tell")
	assert_eq(trap.volleys, 0)
	await _seconds(0.3)
	assert_eq(trap.volleys, 1, "the volley")
	assert_almost_eq(player.health.current, full - TombTrap.GUARD_DAMAGE, 0.01, "the guard on the line is hit")
	assert_gt(TombTrap.TELL, 0.6, "a telegraph the owner can read")


func test_a_guard_who_steps_off_the_line_in_time_is_spared() -> void:
	var full := player.health.current
	await _stand(PLATE)
	assert_eq(trap.phase, TombTrap.Phase.PRIMED)
	await _stand(PLATE + Vector3(0, 0, 1.5))
	await _seconds(TombTrap.TELL + 0.2)
	assert_eq(trap.volleys, 1)
	assert_eq(player.health.current, full, "off the line: no darts")


func test_an_exhibit_on_the_line_takes_the_volley_and_a_wall_stops_it() -> void:
	var near := _wax(Vector3(-2.0, 0.05, 0.2), false)
	Greybox.box(self, Vector3(-4.0, 2.0, 0), Vector3(0.5, 4, 3), Color.GRAY)
	var behind := _wax(Vector3(-5.2, 0.05, 0.0), false)
	await physics_frames(3)
	var near_full := near.health.current
	var behind_full := behind.health.current
	await _stand(PLATE)
	await _seconds(TombTrap.TELL + 0.2)
	assert_almost_eq(near.health.current, near_full - TombTrap.EXHIBIT_DAMAGE, 0.01, "the exhibit on the line")
	assert_eq(behind.health.current, behind_full, "the wall took the darts meant for the one behind it")


func test_alarmed_walkers_set_it_off_but_sleepers_and_swarms_do_not() -> void:
	await _stand(Vector3(0, 0, 6))
	var sleeper := _wax(PLATE, false)
	await _seconds(0.5)
	assert_eq(trap.phase, TombTrap.Phase.ARMED, "a sleeper lying on it is part of the tomb")
	sleeper.free()
	var swarm := ScarabSwarm.new()
	swarm.target = player
	swarm.position = PLATE
	add_child(swarm)
	swarm.brain.alarm(player.global_position)
	await _seconds(0.5)
	assert_eq(trap.phase, TombTrap.Phase.ARMED, "the beetles are too light")
	swarm.free()
	_wax(PLATE, true)
	await _seconds(0.5)
	assert_ne(trap.phase, TombTrap.Phase.ARMED, "an alarmed mummy blunders onto it")


func test_a_guard_in_the_air_does_not_press_it() -> void:
	player.global_position = PLATE + Vector3.UP * 1.2
	player.velocity = Vector3.ZERO
	await physics_frames(2)
	assert_eq(trap.phase, TombTrap.Phase.ARMED, "jumped over")


func test_it_rearms_after_a_while_and_not_before() -> void:
	await _stand(PLATE)
	await _seconds(TombTrap.TELL + 0.2)
	assert_eq(trap.volleys, 1)
	assert_eq(trap.phase, TombTrap.Phase.RESETTING)
	await _seconds(TombTrap.RESET - 1.0)
	assert_eq(trap.volleys, 1, "no second volley while it resets")
	await _stand(Vector3(0, 0, 6))
	await _seconds(1.5)
	assert_eq(trap.phase, TombTrap.Phase.ARMED, "armed again")


func test_the_volley_is_a_noise_of_the_trap() -> void:
	var noises := watch(Events.noise_made)
	await _stand(PLATE)
	await _seconds(TombTrap.TELL + 0.2)
	var heard := noises.filter(func(args: Array) -> bool: return args[2] == TombTrap.NOISE_SOURCE)
	assert_eq(heard.size(), 1, "the clatter of the darts carries")
	if heard.size() == 1:
		assert_almost_eq(float(heard[0][1]), TombTrap.NOISE, 0.01)


func test_dawn_stops_it() -> void:
	host.freeze()
	await _stand(PLATE)
	await _seconds(TombTrap.TELL + 0.2)
	assert_eq(trap.phase, TombTrap.Phase.ARMED)
	assert_eq(trap.volleys, 0)
