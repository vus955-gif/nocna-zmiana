extends TestCase
## A raptor pack on the lobby's navigation mesh: from the diorama it finds
## its way into the hall, splits round the guard and reaches him; up the
## stairs to the balcony too.

const FAST_FORWARD := 8

var level: LobbyLevel
var target: TargetDummy
var _ticks: int
var _max_steps: int


func before_each() -> void:
	_ticks = Engine.physics_ticks_per_second
	_max_steps = Engine.max_physics_steps_per_frame
	level = LobbyLevel.new()
	add_child(level)
	level.build()
	target = TargetDummy.new()
	add_child(target)
	await physics_frames(6)   # the navigation map syncs a few frames after baking


func after_each() -> void:
	Engine.physics_ticks_per_second = _ticks
	Engine.max_physics_steps_per_frame = _max_steps
	Engine.time_scale = 1.0


## Runs up to [param seconds]; returns each raptor's closest distance.
## The pack is summoned: it always knows where the target is (this is
## about finding the way).
func _hunt(pack: Array[Raptor], seconds: float, reach: float) -> Dictionary:
	var closest := {}
	for raptor in pack:
		raptor.summoned = true
		raptor.brain.wake()
		closest[raptor] = INF
	Engine.physics_ticks_per_second = _ticks * FAST_FORWARD
	Engine.max_physics_steps_per_frame = _max_steps * FAST_FORWARD
	Engine.time_scale = FAST_FORWARD
	for frame in int(seconds * _ticks):
		await get_tree().physics_frame
		var waiting := 0
		for raptor in pack:
			if not is_instance_valid(raptor):
				continue
			closest[raptor] = minf(closest[raptor], raptor.global_position.distance_to(target.global_position))
			if closest[raptor] > reach:
				waiting += 1
		if waiting == 0:
			break
	return closest


func test_pack_from_the_diorama_reaches_the_guard_in_the_hall() -> void:
	target.position = Vector3(0, 0, 4)
	var pack := RaptorPack.spawn(self, Vector3(0, 0, 36), 4, target, false)
	var closest := await _hunt(pack, 12.0, 2.0)
	for raptor in pack:
		assert_lt(closest[raptor], 2.0, "a raptor got stuck at %s" % raptor.global_position)


func test_pack_climbs_to_the_balcony() -> void:
	target.position = Vector3(-16, 6, -12)
	var pack := RaptorPack.spawn(self, Vector3(4, 0, 10), 3, target, false)
	var closest := await _hunt(pack, 14.0, 2.5)
	for raptor in pack:
		assert_lt(closest[raptor], 2.5, "a raptor got stuck at %s" % raptor.global_position)
