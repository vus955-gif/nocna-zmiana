extends TestCase
## The basement's steam (plan 2026-10-21-mechaniki-biomow, mechanic 7) in a
## sandbox: a cracked valve on a corridor's pipe vents scalding steam across
## the corridor every PERIOD s - a hiss TELL s first - for BURST s; whoever
## stands in the plume then is scalded (the guard, an exhibit in a hurry;
## the resting runaways know the cellar's rhythm) and an exhibit in it is
## blind; the wheel on the wall shuts it for VALVE_TIME s; dawn stops it.

## A corridor along x, 3.5 m wide (z 0..3.5): the vent in its north wall.
const VENT := Vector3(0.0, 0.0, 0.0)

var host: BiomeMechanics
var vent: SteamVent
var player: Player


func before_each() -> void:
	GameInput.capture_allowed = false
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color.GRAY)
	Greybox.box(self, Vector3(0, 1.75, -0.5), Vector3(30, 3.5, 1), Color.GRAY)
	Greybox.box(self, Vector3(0, 1.75, 4.0), Vector3(30, 3.5, 1), Color.GRAY)
	player = Player.new()
	player.position = Vector3(8, 0.05, 1.75)
	add_child(player)
	host = BiomeMechanics.new()
	host.guard_source = func() -> Player: return player
	add_child(host)
	vent = SteamVent.create({"at": VENT, "dir": Vector3(0, 0, 1), "across": 3.5, "height": 3.5, "valve": Vector3(2.5, 0.0, 0.0), "offset": 0.0})
	host.adopt(vent, &"basement_test_vent", &"")
	await physics_frames(2)


func after_each() -> void:
	GameInput.capture_allowed = true


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _to_burst(before: float) -> void:
	await _seconds(maxf(vent.until_burst() - before, 0.0))


func test_it_hisses_then_vents_on_its_cycle() -> void:
	assert_gt(SteamVent.TELL, 0.6)
	await _to_burst(SteamVent.TELL + 0.3)
	assert_eq(vent.phase, SteamVent.Phase.QUIET)
	await _seconds(0.5)
	assert_eq(vent.phase, SteamVent.Phase.HISSING, "the hiss before the blast")
	await _seconds(SteamVent.TELL)
	assert_eq(vent.phase, SteamVent.Phase.VENTING)
	await _seconds(SteamVent.BURST + 0.1)
	assert_eq(vent.phase, SteamVent.Phase.QUIET)
	assert_eq(vent.bursts, 1)


func test_the_guard_in_the_plume_is_scalded_and_beside_it_not() -> void:
	player.global_position = Vector3(0.3, 0.05, 1.8)
	await _to_burst(0.1)
	var full := player.health.current
	await _seconds(0.2 + 1.0)
	assert_lt(player.health.current, full - SteamVent.GUARD_PER_SECOND * 0.7, "scalded")
	player.global_position = Vector3(SteamVent.HALF_WIDTH + 1.0, 0.05, 1.8)
	await physics_frames(2)
	var after := player.health.current
	await _seconds(1.0)
	assert_eq(player.health.current, after, "a step along the corridor: out of it")


func test_the_scald_hurts_at_every_tick_but_cries_out_about_once_a_second() -> void:
	player.global_position = Vector3(0.3, 0.05, 1.8)
	var cries := watch(Events.player_damaged)
	await _to_burst(0.1)
	var full := player.health.current
	await _seconds(0.1 + SteamVent.BURST)
	assert_lt(player.health.current, full - SteamVent.GUARD_PER_SECOND * (SteamVent.BURST - 0.5), "scalded all through the burst")
	assert_gt(cries.size(), 0, "he feels it")
	assert_lt(cries.size(), 4, "but not at each of the ten ticks: the hurt sound and the shake come about once a second")


func _wax(at: Vector3) -> WaxFigure:
	var wax := WaxFigure.new()
	wax.target = player
	wax.position = at
	wax.attack_damage = 0.0
	add_child(wax)
	return wax


func test_an_exhibit_in_a_hurry_is_scalded_and_blinded() -> void:
	var hurried := _wax(Vector3(0.0, 0.05, 2.0))
	await physics_frames(3)
	hurried.set_physics_process(false)
	hurried.brain.alarm(player.global_position)
	var sight := hurried.sight_range
	await _to_burst(0.0)
	await _seconds(1.0)
	assert_lt(hurried.health.current, hurried.max_health - SteamVent.EXHIBIT_PER_SECOND * 0.7, "scalded")
	assert_almost_eq(hurried.sight_range, SteamVent.BLIND_RANGE, 0.01, "blind in the steam")
	await _seconds(SteamVent.BURST + SteamVent.BLIND_HOLD)
	assert_almost_eq(hurried.sight_range, sight, 0.01, "it sees again")


func test_the_steams_ticks_scald_but_raise_no_alarm() -> void:
	var hurried := _wax(Vector3(0.0, 0.05, 2.0))
	await physics_frames(3)
	hurried.set_physics_process(false)
	hurried.brain.alarm(player.global_position)
	var told := [0]
	hurried.brain.before_event = func() -> void: told[0] += 1
	await _to_burst(0.0)
	await _seconds(1.5)
	assert_lt(hurried.health.current, hurried.max_health - SteamVent.EXHIBIT_PER_SECOND, "scalded")
	assert_eq(told[0], 0, "a tick of steam is no hit that tells it where the guard stands")


func test_a_runaway_at_rest_keeps_out_of_it() -> void:
	var resting := _wax(Vector3(-0.4, 0.05, 1.0))
	await physics_frames(3)
	resting.set_physics_process(false)
	await _to_burst(0.0)
	await _seconds(SteamVent.BURST + 0.2)
	assert_eq(vent.bursts, 1)
	assert_eq(resting.health.current, resting.max_health, "the runaways at rest know the cellar's rhythm")


func test_the_wheel_shuts_it_for_a_while() -> void:
	assert_true(vent.valve.can_interact(player))
	vent.valve.interact(player)
	assert_true(vent.shut())
	assert_false(vent.valve.can_interact(player), "already shut")
	await _seconds(SteamVent.PERIOD + 1.0)
	assert_eq(vent.bursts, 0, "no steam while shut")
	await _seconds(SteamVent.VALVE_TIME - SteamVent.PERIOD)
	assert_false(vent.shut(), "the pressure builds up again")
	await _seconds(vent.until_burst() + SteamVent.TELL + 0.2)
	assert_eq(vent.bursts, 1)


func test_dawn_stops_it() -> void:
	host.freeze()
	await _seconds(SteamVent.PERIOD + 1.0)
	assert_eq(vent.bursts, 0)
