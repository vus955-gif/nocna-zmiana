extends TestCase
## Assyria's hunting nets (plan 2026-10-21-mechaniki-biomow, mechanic 2)
## in a sandbox: a shot into a net's bundle under the ceiling drops it; it
## lands DROP_TIME s later over a circle of RADIUS m and entangles every
## exhibit under it for ENTANGLE s (one beside it or on a gallery above is
## left alone); the guard caught under it is slowed a moment; a net drops
## once a night (RunState.used: a night resumed finds it lying torn); dawn
## leaves the rest hanging.

const NET := Vector3(0.0, 5.0, 0.0)

var host: BiomeMechanics
var net: HuntingNet
var player: Player


func before_each() -> void:
	GameInput.capture_allowed = false
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color.GRAY)
	player = Player.new()
	player.position = Vector3(0, 0.05, 12)
	add_child(player)
	host = BiomeMechanics.new()
	host.guard_source = func() -> Player: return player
	host.run = RunState
	add_child(host)
	net = HuntingNet.create({"at": NET, "floor": 0.0, "ceiling": 8.0})
	host.adopt(net, &"assyria_test_net", &"")
	await physics_frames(2)


func after_each() -> void:
	GameInput.capture_allowed = true


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _shot() -> void:
	var info := DamageInfo.make(20.0, DamageInfo.Kind.BALLISTIC, player)
	info.position = net.knot()
	net.take_damage(info)


func _fighter(at: Vector3) -> WaxFigure:
	var wax := WaxFigure.new()
	wax.target = player
	wax.position = at
	wax.attack_damage = 0.0
	add_child(wax)
	wax.brain.stun(0.05)
	return wax


func test_a_shot_drops_it_on_whoever_is_under_it() -> void:
	var caught := _fighter(Vector3(1.0, 0.05, 1.0))
	var beside := _fighter(Vector3(HuntingNet.RADIUS + 2.0, 0.05, 0.0))
	await physics_frames(10)
	caught.global_position = Vector3(1.0, 0.05, 1.0)
	beside.global_position = Vector3(HuntingNet.RADIUS + 2.0, 0.05, 0.0)
	caught.set_physics_process(false)
	beside.set_physics_process(false)
	assert_false(net.dropped)
	_shot()
	assert_true(net.dropped, "the rope is cut")
	assert_false(caught.brain.is_stunned(), "it is still falling")
	await _seconds(HuntingNet.DROP_TIME + 0.05)
	assert_true(caught.brain.is_stunned(), "caught in the net")
	assert_false(beside.brain.is_stunned(), "a step outside it: free")
	assert_eq(net.caught, 1)
	assert_gt(HuntingNet.ENTANGLE, 3.0, "long enough to deal with it")


func test_a_sleeper_or_a_calm_walker_under_it_is_left_as_it_is() -> void:
	var sleeper := WaxFigure.new()
	sleeper.target = player
	sleeper.position = Vector3(1.0, 0.05, 1.0)
	add_child(sleeper)
	var walker := WaxFigure.new()
	walker.target = player
	walker.position = Vector3(-1.0, 0.05, 1.0)
	add_child(walker)
	var seen := _fighter(Vector3(0.0, 0.05, -1.0))
	await physics_frames(10)
	walker.brain.start_patrol()
	for exhibit in [sleeper, walker, seen]:
		exhibit.set_physics_process(false)
	seen.global_position = Vector3(0.0, 0.05, -1.0)
	assert_eq(sleeper.brain.state, EnemyBrain.State.DORMANT)
	assert_eq(walker.brain.state, EnemyBrain.State.PATROL)
	_shot()
	await _seconds(HuntingNet.DROP_TIME + 0.05)
	assert_true(seen.brain.is_stunned(), "the one on to the guard is caught")
	assert_eq(sleeper.brain.state, EnemyBrain.State.DORMANT, "a net stuns, it does not wake: a stunned sleeper would rise hunting")
	assert_eq(walker.brain.state, EnemyBrain.State.PATROL, "nor does it turn a calm round into a hunt")
	assert_eq(net.caught, 1, "only the awake one counts as caught")


func test_a_sleeper_the_cutting_shots_own_noise_wakes_is_not_netted() -> void:
	player.global_position = Vector3(0.0, 0.05, 4.0)   # (the shot is loud in his hand)
	var sleeper := WaxFigure.new()
	sleeper.target = player
	sleeper.position = Vector3(1.0, 0.05, 1.0)
	add_child(sleeper)
	await physics_frames(3)
	sleeper.set_physics_process(false)
	assert_eq(sleeper.brain.state, EnemyBrain.State.DORMANT)
	_shot()
	Events.weapon_fired.emit(&"pistol")   # the holder fires this right after the hit
	assert_ne(sleeper.brain.state, EnemyBrain.State.DORMANT, "the shot's noise woke it (suspicious now)")
	await _seconds(HuntingNet.DROP_TIME + 0.05)
	assert_false(sleeper.brain.is_stunned(), "it was asleep when the rope was cut: the net does not take it")
	assert_eq(net.caught, 0)


func test_the_guard_under_it_is_slowed_a_moment() -> void:
	player.global_position = Vector3(0.5, 0.05, 0.5)
	await physics_frames(3)
	_shot()
	await _seconds(HuntingNet.DROP_TIME + 0.05)
	assert_lt(player.speed_factor(), 1.0, "tangled feet")
	await _seconds(HuntingNet.GUARD_SLOW_TIME + 0.2)
	assert_almost_eq(player.speed_factor(), 1.0, 0.001, "and free again")


func test_one_on_a_gallery_above_is_left_alone() -> void:
	Greybox.box(self, Vector3(0, 2.8, 0), Vector3(3, 0.4, 3), Color.GRAY)
	var above := _fighter(Vector3(0.0, 3.05, 0.0))
	await physics_frames(10)
	above.global_position = Vector3(0.0, 3.05, 0.0)
	above.set_physics_process(false)
	_shot()
	await _seconds(HuntingNet.DROP_TIME + 0.05)
	assert_false(above.brain.is_stunned(), "the net falls past the gallery's level, not on it")


func test_it_drops_once_a_night_and_a_resumed_night_finds_it_lying() -> void:
	_shot()
	await _seconds(HuntingNet.DROP_TIME + 0.05)
	assert_true(RunState.is_used(net.used_id()), "remembered for the night")
	var drops := net.drops
	_shot()
	assert_eq(net.drops, drops, "nothing more to drop")
	var again := HuntingNet.create({"at": NET + Vector3(6, 0, 0), "floor": 0.0, "ceiling": 8.0})
	RunState.mark_used(StringName("%s%s" % [HuntingNet.USED_PREFIX, "assyria_test_net_2"]))
	host.adopt(again, &"assyria_test_net_2", &"")
	await physics_frames(2)
	assert_true(again.dropped, "a resumed night: it lies torn where it fell")
	assert_true(again.zone == null, "nothing left to shoot")


func test_dawn_leaves_it_hanging() -> void:
	host.freeze()
	_shot()
	assert_false(net.dropped)
