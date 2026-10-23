extends TestCase
## Greece's mirrors of Helios (plan 2026-10-21-mechaniki-biomow, mechanic 3)
## in a sandbox: the photographer's arc lamp, switched on at its lever,
## throws a beam of daylight at a bronze mirror that sends it on to the
## mirror's chosen mark; an exhibit in the beam slows and burns, one beside
## it does not; the guard in it stands lit for every exhibit to see; a turn
## of the mirror (E or a shot) sends the beam elsewhere; the carbons burn
## out after a while and the lamp must cool before it lights again; dawn
## puts it out.

## The lamp high on the west wall (x -10) aims at the mirror on the east
## wall (x 10); the mirror's marks: back west along z 6, north along x 4.
const LAMP := Vector3(-9.8, 3.0, 0.0)
const MIRROR := Vector3(9.8, 1.5, 0.0)
const MARKS: Array[Vector3] = [Vector3(-9.0, 1.3, 6.0), Vector3(4.0, 1.3, -12.0)]

var host: BiomeMechanics
var lamp: HeliosLamp
var mirror: BronzeMirror
var player: Player


func before_each() -> void:
	GameInput.capture_allowed = false
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color.GRAY)
	Greybox.box(self, Vector3(10.5, 3.0, 0), Vector3(1, 6, 30), Color.GRAY)
	Greybox.box(self, Vector3(-10.5, 3.0, 0), Vector3(1, 6, 30), Color.GRAY)
	Greybox.box(self, Vector3(0, 3.0, -15.5), Vector3(22, 6, 1), Color.GRAY)
	player = Player.new()
	player.position = Vector3(0, 0.05, 12)
	add_child(player)
	host = BiomeMechanics.new()
	host.guard_source = func() -> Player: return player
	add_child(host)
	mirror = BronzeMirror.create({"at": MIRROR, "face": Vector3(-1, 0, 0), "marks": MARKS})
	host.adopt(mirror, &"greece_test_mirror", &"")
	lamp = HeliosLamp.create({"at": LAMP, "face": Vector3(1, 0, 0), "aim": MIRROR}, [mirror])
	host.adopt(lamp, &"greece_test_lamp", &"")
	await physics_frames(2)


func after_each() -> void:
	GameInput.capture_allowed = true


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _wax(at: Vector3) -> WaxFigure:
	var wax := WaxFigure.new()
	wax.target = player
	wax.position = at
	add_child(wax)
	return wax


func test_the_beam_runs_from_the_lamp_by_the_mirror_to_its_mark() -> void:
	assert_false(lamp.lit)
	assert_true(lamp.lever.can_interact(player))
	lamp.lever.interact(player)
	assert_true(lamp.lit, "the arc strikes")
	await physics_frames(2)
	var path := lamp.path
	assert_gt(path.size(), 2.0, "lamp, mirror, end")
	assert_lt(path[0].distance_to(LAMP), 0.6)
	assert_lt(path[1].distance_to(mirror.center()), 0.05, "it meets the mirror")
	var out := (path[2] - path[1]).normalized()
	assert_gt(out.dot((MARKS[0] - mirror.center()).normalized()), 0.99, "and leaves it for its first mark")
	assert_lt(path[2].x, -9.0, "on to the far wall")


func test_an_exhibit_in_the_beam_slows_and_burns_and_one_beside_it_does_not() -> void:
	var lane := MIRROR.lerp(MARKS[0], 0.5)
	var burnt := _wax(Vector3(lane.x, 0.05, lane.z))
	var spared := _wax(Vector3(lane.x, 0.05, lane.z + 3.0))
	await physics_frames(3)
	# (they stand still for the measure: a stung exhibit would walk out)
	burnt.set_physics_process(false)
	spared.set_physics_process(false)
	var full := burnt.health.current
	var speed := burnt.move_speed
	lamp.lever.interact(player)
	await _seconds(1.0)
	assert_lt(burnt.health.current, full - HeliosLamp.BURN_PER_SECOND * 0.6, "daylight burns the living stone")
	assert_almost_eq(burnt.move_speed, speed * HeliosLamp.SLOW, 0.01, "and stiffens it")
	assert_eq(spared.health.current, spared.max_health, "a step out of the beam: nothing")
	assert_almost_eq(spared.move_speed, speed, 0.01)
	burnt.global_position = Vector3(lane.x, 0.05, lane.z - 4.0)
	await _seconds(HeliosLamp.SLOW_HOLD + 0.3)
	assert_almost_eq(burnt.move_speed, speed, 0.01, "out of the light it moves as before")


func test_the_beams_ticks_burn_but_raise_no_alarm_and_wake_nobody() -> void:
	var lane := MIRROR.lerp(MARKS[0], 0.5)
	var sleeper := _wax(Vector3(lane.x, 0.05, lane.z))
	var along := (MARKS[0] - MIRROR).normalized()   # (both stand in the beam, one behind the other)
	var hunter := _wax(Vector3(lane.x + along.x * 1.2, 0.05, lane.z + along.z * 1.2))
	await physics_frames(3)
	sleeper.set_physics_process(false)
	hunter.set_physics_process(false)
	hunter.brain.stun(0.05)
	hunter.brain.update(0.1, false, 5.0)
	var told := {"sleeper": 0, "hunter": 0}
	sleeper.brain.before_event = func() -> void: told["sleeper"] += 1
	hunter.brain.before_event = func() -> void: told["hunter"] += 1
	var full := sleeper.health.current
	lamp.lever.interact(player)
	await _seconds(1.5)
	assert_lt(sleeper.health.current, full - HeliosLamp.BURN_PER_SECOND, "the beam burns the sleeper")
	assert_eq(sleeper.brain.state, EnemyBrain.State.DORMANT, "and does not wake it")
	assert_eq(told["sleeper"], 0, "ten ticks a second are no alarm")
	assert_lt(hunter.health.current, hunter.max_health, "it burns too")
	assert_eq(told["hunter"], 0, "nor do they keep telling a hunter where the guard stands")


func test_the_guard_in_the_beam_stands_lit() -> void:
	PerceptionWorld.configure(func(_p: Vector3) -> float: return 0.0, Callable(), null, Callable())
	var lane := MIRROR.lerp(MARKS[0], 0.5)
	var chest := Vector3(lane.x, 1.0, lane.z)
	assert_almost_eq(PerceptionWorld.light_at(chest), 0.0, 0.001, "a dark hall")
	lamp.lever.interact(player)
	await physics_frames(3)
	assert_almost_eq(PerceptionWorld.light_at(chest), 1.0, 0.001, "in the beam he is as lit as can be")
	assert_almost_eq(PerceptionWorld.light_at(chest + Vector3(0, 0, 3)), 0.0, 0.001, "beside it, dark")


func test_a_turn_of_the_mirror_sends_the_beam_elsewhere() -> void:
	lamp.lever.interact(player)
	await physics_frames(2)
	assert_eq(mirror.mark, 0)
	mirror.handle.interact(player)
	assert_eq(mirror.mark, 1, "E turns it to its next mark")
	await _seconds(BronzeMirror.TURN_TIME + 0.2)
	var path := lamp.path
	assert_gt(path.size(), 2.0)
	if path.size() > 2:
		assert_gt((path[2] - path[1]).normalized().dot((MARKS[1] - mirror.center()).normalized()), 0.99, "now to the second mark")
	var shot := DamageInfo.make(10.0, DamageInfo.Kind.BALLISTIC, player)
	shot.position = mirror.center()
	mirror.take_damage(shot)
	assert_eq(mirror.mark, 0, "a shot on its rim turns it on, round to the first")


func test_the_carbons_burn_out_and_the_lamp_must_cool() -> void:
	lamp.lever.interact(player)
	await _seconds(HeliosLamp.BURN_TIME - HeliosLamp.TELL + 0.1)
	assert_true(lamp.lit)
	assert_true(lamp.sputtering(), "it flickers before it dies")
	assert_gt(HeliosLamp.TELL, 0.6)
	await _seconds(HeliosLamp.TELL + 0.2)
	assert_false(lamp.lit, "burnt out")
	assert_false(lamp.lever.can_interact(player), "too hot to strike again")
	await _seconds(HeliosLamp.COOL)
	assert_true(lamp.lever.can_interact(player), "cool again")


func test_dawn_puts_it_out() -> void:
	lamp.lever.interact(player)
	await physics_frames(2)
	host.freeze()
	assert_false(lamp.lit)
	assert_false(lamp.lever.can_interact(player))
	mirror.handle.interact(player)
	assert_eq(mirror.mark, 0, "and the mirror stays as it is")
