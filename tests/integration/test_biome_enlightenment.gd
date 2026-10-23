extends TestCase
## The Enlightenment's regulator (plan 2026-10-21-mechaniki-biomow,
## mechanic 4) in a sandbox: the master clock strikes every BEAT s; a
## second before it whirs and the exhibits it holds glint; on the strike
## every exhibit in the fight stops dead for TICK s ("tick") and then runs
## HASTE faster for HASTE_TIME s ("tock"); sleepers are left alone; a shot
## through its glass stops the pendulum for STOP_TIME s, then it winds
## itself up again; dawn stops it.

const CLOCK := Vector3(-6.0, 0.0, 0.0)

var host: BiomeMechanics
var regulator: Regulator
var player: Player


func before_each() -> void:
	GameInput.capture_allowed = false
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color.GRAY)
	Greybox.box(self, Vector3(-6.5, 3.0, 0), Vector3(1, 6, 20), Color.GRAY)
	player = Player.new()
	player.position = Vector3(6, 0.05, 6)
	add_child(player)
	host = BiomeMechanics.new()
	host.guard_source = func() -> Player: return player
	add_child(host)
	regulator = Regulator.create({"at": CLOCK, "face": Vector3(1, 0, 0)})
	host.adopt(regulator, &"enlightenment_test_regulator", &"")
	await physics_frames(2)


func after_each() -> void:
	GameInput.capture_allowed = true


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


## A wax figure fighting the guard (a moment's stun: then it hunts).
func _fighter(at: Vector3) -> WaxFigure:
	var wax := WaxFigure.new()
	wax.target = player
	wax.position = at
	wax.attack_damage = 0.0   # (the guard must outlive the wait for the beat)
	add_child(wax)
	wax.brain.stun(0.05)
	return wax


## Runs the clock up to [param before] s before its next strike.
func _to_strike(before: float) -> void:
	await _seconds(maxf(regulator.until_strike() - before, 0.0))


func test_it_strikes_every_beat_with_a_whirr_first() -> void:
	assert_gt(Regulator.BEAT, 10.0)
	await _to_strike(Regulator.TELL + 0.3)
	assert_false(regulator.tolling())
	assert_eq(regulator.strikes, 0)
	await _seconds(0.5)
	assert_true(regulator.tolling(), "the whirr before the strike")
	assert_gt(Regulator.TELL, 0.6)
	await _seconds(Regulator.TELL)
	assert_eq(regulator.strikes, 1)
	await _seconds(Regulator.BEAT)
	assert_eq(regulator.strikes, 2, "and again a beat later")


func test_the_fighters_stop_dead_on_the_tick_then_run_faster_on_the_tock() -> void:
	var wax := _fighter(Vector3(2, 0.05, 2))
	var sleeper := WaxFigure.new()
	sleeper.target = player
	sleeper.position = Vector3(-2, 0.05, -6)
	add_child(sleeper)
	await physics_frames(10)
	assert_true(wax.brain.state in [EnemyBrain.State.HUNT, EnemyBrain.State.ATTACK], "it fights")
	var pace := wax.move_speed
	await _to_strike(0.2)
	assert_false(wax.brain.is_stunned())
	await _seconds(0.3)
	assert_true(wax.brain.is_stunned(), "tick: it stops dead")
	assert_eq(sleeper.brain.state, EnemyBrain.State.DORMANT, "a sleeper sleeps through it")
	await _seconds(Regulator.TICK + 0.1)
	assert_almost_eq(wax.move_speed, pace * Regulator.HASTE, 0.01, "tock: it runs on faster")
	await _seconds(Regulator.HASTE_TIME)
	assert_almost_eq(wax.move_speed, pace, 0.01, "then at its own pace again")


func test_a_shot_through_its_glass_stops_it_for_a_while() -> void:
	var info := DamageInfo.make(10.0, DamageInfo.Kind.BALLISTIC, player)
	info.position = regulator.pendulum_point()
	regulator.take_damage(info)
	assert_true(regulator.stopped(), "the pendulum hangs still")
	assert_true(regulator.glass_broken)
	await _seconds(Regulator.BEAT + 1.0)
	assert_eq(regulator.strikes, 0, "no strike while it is stopped")
	await _seconds(Regulator.STOP_TIME - Regulator.BEAT - 1.0 - Regulator.REWIND + 0.2)
	assert_true(regulator.rewinding(), "it winds itself up again, audibly")
	await _seconds(Regulator.REWIND + 0.1)
	assert_false(regulator.stopped())
	await _seconds(regulator.until_strike() + 0.1)
	assert_eq(regulator.strikes, 1, "and keeps time again")


func test_dawn_stops_it() -> void:
	host.freeze()
	await _seconds(Regulator.BEAT + 1.0)
	assert_eq(regulator.strikes, 0)
