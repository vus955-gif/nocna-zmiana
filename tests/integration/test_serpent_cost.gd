extends TestCase
## What the Serpent's body and rig cost to pose every frame (a bare floor,
## the real model, headless). Gliding through a fight it was 2.4 ms a frame:
## the trail resampled 585 times, each neck solved by a 28-step bisection of
## 65-point curves, ~270 string-keyed shader-uniform lookups. Now: the
## trail walked as it lies, a neck left alone while nothing it was laid for
## moved and warm-started when it must be, the uniforms keyed by slot and
## sent only when they changed - about a fifth of that. The bound below is
## generous (the best of several batches, so a busy machine does not trip
## it): it catches a return of the old cost, not a few percent.

const STEP := 1.0 / 60.0
const BATCHES := 5
const FRAMES := 60
## Milliseconds a frame (average) the pair body.update() + rig.apply() may cost.
const BUDGET_MS := 1.5

var world: Node3D


func before_each() -> void:
	world = Node3D.new()
	add_child(world)


func after_each() -> void:
	world.free()


func _rigged() -> Array:
	var body := SerpentBody.new()
	body.height_at = func(_at: Vector3) -> float: return 0.0
	var holder := Node3D.new()
	world.add_child(holder)
	var rig := SerpentRig.create(holder)
	return [body, rig, SerpentMoves.new(body), SerpentBrain.new()]


## The best of BATCHES batches of FRAMES frames: the average microseconds
## [param frame] (called with the frame number) reports it spent, in ms.
func _best_batch(frame: Callable) -> float:
	var best := INF
	var n := 0
	for batch in BATCHES + 1:
		var spent := 0
		for i in FRAMES:
			spent += int(frame.call(n))
			n += 1
		# (the first batch warms the caches and does not count)
		if batch > 0:
			best = minf(best, float(spent) / 1000.0 / float(FRAMES))
	return best


func test_a_fighting_serpent_gliding_costs_little_to_pose() -> void:
	var kit := _rigged()
	var body: SerpentBody = kit[0]
	var rig: SerpentRig = kit[1]
	var moves: SerpentMoves = kit[2]
	var brain: SerpentBrain = kit[3]
	brain.seed_with(4)
	var path := PackedVector3Array()
	for i in 81:
		path.append(Vector3(-40.0 + i * 0.5, 0.0, 0.0))
	body.lay(path)
	moves.guard = Vector3(10.0, 1.4, 6.0)
	brain.wake()
	var sight := SerpentBrain.Sight.new()
	sight.spit_distance = 10.0
	sight.bite_distance = 5.0
	sight.tail_distance = 20.0
	var x := [0.0]
	var cost := _best_batch(func(_n: int) -> int:
		brain.update(STEP, sight)
		var pose := moves.compose(brain, STEP)
		x[0] += 2.6 * STEP
		var started := Time.get_ticks_usec()
		body.advance(Vector3(x[0], 0.0, 0.25 * sin(x[0] * 1.4)))   # (updates the joints)
		rig.apply(body, pose, STEP)
		return Time.get_ticks_usec() - started)
	assert_lt(cost, BUDGET_MS * time_slack(), "gliding: %.3f ms a frame" % cost)
	# the work was real: the chain whole, the rig on it
	for j in range(1, body.count + 1):
		assert_almost_eq(body.joints[j].distance_to(body.joints[j - 1]), SerpentBody.SPACING, 0.02, "joint %d" % j)
	assert_lt(rig.segments[10].global_position.distance_to(body.joints[10]), 0.001, "the rig followed the body")


func test_a_serpent_lying_on_its_ring_under_travelling_arches_costs_little_to_pose() -> void:
	var kit := _rigged()
	var body: SerpentBody = kit[0]
	var rig: SerpentRig = kit[1]
	var moves: SerpentMoves = kit[2]
	var brain: SerpentBrain = kit[3]
	brain.seed_with(4)
	# a ring: a 280 degree arc of radius 5 m
	var path := PackedVector3Array()
	for i in 61:
		var angle := deg_to_rad(280.0) * float(i) / 60.0
		path.append(Vector3(5.0 * cos(angle), 0.0, 5.0 * sin(angle)))
	body.lay(path)
	moves.guard = Vector3(0.0, 1.4, 12.0)
	brain.wake()
	var sight := SerpentBrain.Sight.new()
	sight.spit_distance = 10.0
	sight.bite_distance = 5.0
	sight.tail_distance = 20.0
	var lying := body.lying_length()
	var cost := _best_batch(func(n: int) -> int:
		brain.update(STEP, sight)
		var pose := moves.compose(brain, STEP, true)
		var arches := []
		for i in 2:
			var s := fposmod(2.0 * STEP * float(n) + float(i) * lying * 0.5, lying)
			arches.append([s, 1.3 * clampf(minf(s, lying - s) / 2.4, 0.0, 1.0), 2.4])
		body.arches = arches
		var started := Time.get_ticks_usec()
		body.update()
		rig.apply(body, pose, STEP)
		return Time.get_ticks_usec() - started)
	assert_lt(cost, BUDGET_MS * time_slack(), "on the ring: %.3f ms a frame" % cost)
	var ground := body.ground_joints()
	for j in range(ground.x + 1, ground.y + 1):
		assert_almost_eq(body.joints[j].distance_to(body.joints[j - 1]), SerpentBody.SPACING, 0.02, "joint %d" % j)
