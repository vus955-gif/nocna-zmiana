extends TestCase
## The Serpent's parts on a bare floor (no museum): its rig (the model
## stretched to the body's length, the heads on the end segments, the
## greybox of the same names), the segments placed on the body's joints
## with the heads looking out, a plate shot off baring its core, and its
## moves: the spitting head rears with its mouth aglow, the biting head
## draws back and shoots out to the neck's reach, the tail winds up and
## sweeps round toward the guard, the heads watch the guard, phase 2's
## light runs down the body from one head to the other; and its turquoise
## shards: the arc comes down on the mark, the splash hurts a guard beside
## the burst, a plinth stops one short.

const A := SerpentBrain.Attack
const S := SerpentBrain.State
const END := SerpentBody.End
const STEP := 1.0 / 60.0

var world: Node3D


func before_each() -> void:
	world = Node3D.new()
	add_child(world)
	var ground := StaticBody3D.new()
	ground.collision_layer = Layers.WORLD
	var shape := BoxShape3D.new()
	shape.size = Vector3(120.0, 1.0, 120.0)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = -0.5
	ground.add_child(collider)
	world.add_child(ground)


func after_each() -> void:
	world.free()


## A body laid straight along +X with end A's neck root at x = 0 (end B
## toward -X), its rig in the world, moves and an awake brain:
## [body, rig, moves, brain].
func _rigged(awake: bool = true) -> Array:
	var body := SerpentBody.new()
	body.height_at = func(_at: Vector3) -> float: return 0.0
	var path := PackedVector3Array()
	for i in 81:
		path.append(Vector3(-40.0 + i * 0.5, 0.0, 0.0))
	body.lay(path)
	var holder := Node3D.new()
	holder.name = "Body"
	world.add_child(holder)
	var rig := SerpentRig.create(holder)
	var moves := SerpentMoves.new(body)
	var brain := SerpentBrain.new()
	brain.seed_with(4)
	moves.guard = Vector3(10.0, 1.4, 0.0)
	var kit := [body, rig, moves, brain]
	if awake:
		brain.wake()
		_drive(kit, SerpentBrain.WAKE_TIME + 0.05)
	else:
		_drive(kit, 0.1)
	return kit


## Drives [param kit] for [param seconds]; calls [param each] every frame.
func _drive(kit: Array, seconds: float, each: Callable = Callable()) -> void:
	var body: SerpentBody = kit[0]
	var rig: SerpentRig = kit[1]
	var moves: SerpentMoves = kit[2]
	var brain: SerpentBrain = kit[3]
	for i in roundi(seconds / STEP):
		brain.update(STEP, _sight(body, brain, moves.guard))
		var pose := moves.compose(brain, STEP)
		body.update()
		rig.apply(body, pose, STEP)
		if each.is_valid():
			each.call()


func _sight(body: SerpentBody, brain: SerpentBrain, guard: Vector3) -> SerpentBrain.Sight:
	var sight := SerpentBrain.Sight.new()
	var spit := body.head_point(brain.spitter)
	var bite := body.head_point(brain.biter())
	sight.spit_distance = spit.distance_to(guard)
	sight.spit_bearing = body.head_look(brain.spitter).angle_to(guard - spit)
	sight.bite_distance = bite.distance_to(guard)
	sight.bite_bearing = body.head_look(brain.biter()).angle_to(guard - bite)
	sight.tail_distance = body.joints[body.trailer_joint()].distance_to(guard)
	sight.nearer_tail = sight.tail_distance < body.leader().distance_to(guard)
	return sight


func test_the_rig_stretches_the_model_and_the_greybox_has_its_parts() -> void:
	var holder := Node3D.new()
	world.add_child(holder)
	var rig := SerpentRig.create(holder)
	assert_eq(rig.segments.size(), SerpentBody.SEGMENTS)
	var names := {}
	for k in rig.segments.size():
		var seg := rig.segments[k]
		assert_eq(String(seg.name), "segment_%d" % (k + 1))
		assert_false(names.has(seg.name), "unique")
		names[seg.name] = true
		assert_eq(seg.get_parent(), rig.model, "flattened under the root")
		assert_not_null(rig.tiles[k], "plating on segment %d" % k)
		assert_eq(rig.tiles[k].get_parent(), seg)
		assert_true(rig.plates_on[k])
	assert_eq(rig.skull(END.A).get_parent(), rig.segments[0], "head A on the first segment")
	assert_eq(rig.skull(END.B).get_parent(), rig.segments[rig.count - 1], "head B on the last")
	for end in 2:
		assert_not_null(rig.head_marks[end])
		assert_not_null(rig.mouth_marks[end])
		assert_not_null(rig.jaws[end])
	assert_eq(rig.plates_left(), SerpentBody.SEGMENTS)
	var grey := SerpentRig._make_greybox()
	var found := {}
	for node in grey.find_children("*", "Node3D", true, false):
		found[String(node.name)] = true
	for k in range(1, SerpentBody.MODEL_SEGMENTS + 1):
		assert_true(found.has("segment_%d" % k) and found.has("tiles_%d" % k) and found.has("seg_%d" % k), "greybox segment %d" % k)
	for part in ["skull_a", "jaw_a", "head_a", "mouth_a", "skull_b", "jaw_b", "head_b", "mouth_b"]:
		assert_true(found.has(part), "greybox %s" % part)
	grey.free()


func test_applied_to_a_straight_body_the_segments_sit_on_the_joints_and_the_heads_look_out() -> void:
	var kit := _rigged(false)
	var body: SerpentBody = kit[0]
	var rig: SerpentRig = kit[1]
	for k in rig.count:
		assert_lt(rig.segments[k].global_position.distance_to(body.joints[k]), 0.001, "segment %d on joint %d" % [k, k])
		assert_gt(rig.segments[k].global_basis.z.dot((body.joints[k + 1] - body.joints[k]).normalized()), 0.999, "segment %d along the body" % k)
	# head A beyond end A (+X here), head B beyond end B (-X), both raised
	assert_gt(rig.mouth_point(END.A).x, body.joints[0].x + 1.0, "head A's mouth out past its end")
	assert_lt(rig.mouth_point(END.B).x, body.joints[body.count].x - 1.0, "head B's mouth out past its end")
	assert_gt(rig.head_point(END.A).y, body.radii[0] + 0.3, "head A raised")
	assert_gt(rig.head_forward(END.A).dot(body.head_look(END.A)), 0.98, "head A looks where it was told")
	assert_gt(rig.head_forward(END.B).dot(body.head_look(END.B)), 0.98, "head B too")
	assert_gt(rig.head_forward(END.A).x, 0.8, "out along the line")
	assert_lt(rig.head_forward(END.B).x, -0.8)


func test_a_plate_shot_off_bares_the_core() -> void:
	var kit := _rigged(false)
	var rig: SerpentRig = kit[1]
	var before := Fx.chunk_count()
	rig.drop_plate(10, Vector3.UP)
	assert_false(rig.plate_on(10))
	assert_false(rig.tiles[10].visible, "the mosaic is gone")
	assert_eq(rig.plates_left(), SerpentBody.SEGMENTS - 1)
	if not rig.greybox:
		assert_gt(Fx.chunk_count(), before, "it flew off as debris")
	rig.drop_plate(10, Vector3.UP)
	assert_eq(rig.plates_left(), SerpentBody.SEGMENTS - 1, "once")
	rig.restore_plates()
	assert_true(rig.plate_on(10))
	assert_true(rig.tiles[10].visible)


func test_the_spitting_head_rears_with_its_mouth_aglow_and_the_biting_head_shoots_out() -> void:
	var kit := _rigged()
	var body: SerpentBody = kit[0]
	var rig: SerpentRig = kit[1]
	var moves: SerpentMoves = kit[2]
	var brain: SerpentBrain = kit[3]
	moves.guard = Vector3(12.0, 1.4, 0.0)
	_drive(kit, 1.0)
	var rest_a := body.head_point(END.A)
	var root_a := body.joints[SerpentBody.NECK]
	assert_gt(rest_a.y - root_a.y, 0.5, "at rest the head rides raised")
	brain.force_attack(A.SPIT)
	_drive(kit, SerpentBrain.stage_length(A.SPIT, SerpentBrain.Stage.TELEGRAPH, 1) * 0.95)
	assert_gt(body.head_point(END.A).y, rest_a.y + 0.25, "it rears up")
	assert_lt(body.head_point(END.A).x, rest_a.x - 0.15, "and back")
	assert_gt(moves.pose.jaw[END.A], 0.5, "the jaw opens")
	assert_gt(moves.pose.head_glow[END.A], 0.8, "the mouth glows")
	assert_lt(moves.pose.head_glow[END.B], 0.5, "the other head does not")
	_drive(kit, 1.5)
	assert_eq(brain.state, S.ROAM)
	# the lunge from head B at a guard beyond end B
	var root_b := body.joints[body.count - SerpentBody.NECK]
	moves.guard = root_b + Vector3(-4.5, 1.4, 0.0)
	_drive(kit, 0.6)
	brain.force_attack(A.LUNGE)
	assert_eq(brain.attack_end(), END.B)
	_drive(kit, SerpentBrain.stage_length(A.LUNGE, SerpentBrain.Stage.TELEGRAPH, 1) * 0.9)
	var coiled := body.head_point(END.B)
	assert_gt(coiled.x, root_b.x - 2.0, "it draws back into its S")
	assert_gt(moves.pose.jaw[END.B], 0.4, "hissing, the jaw open")
	var farthest := [0.0]
	var lowest := [INF]
	_drive(kit, SerpentBrain.stage_length(A.LUNGE, SerpentBrain.Stage.TELEGRAPH, 1) * 0.1 + SerpentBrain.stage_length(A.LUNGE, SerpentBrain.Stage.STRIKE, 1) + 0.15, func() -> void:
		var head := body.head_point(END.B)
		farthest[0] = maxf(farthest[0], root_b.distance_to(head))
		lowest[0] = minf(lowest[0], head.y))
	assert_gt(farthest[0], 2.7, "it shoots out to the neck's reach (%.2f m)" % farthest[0])
	assert_lt(lowest[0], root_b.y + 0.35, "low")
	assert_eq(brain.stage, SerpentBrain.Stage.RECOVER)
	assert_gt(root_b.distance_to(body.head_point(END.B)), 2.4, "it hangs out spent")
	_drive(kit, SerpentBrain.stage_length(A.LUNGE, SerpentBrain.Stage.RECOVER, 1) + 1.0)
	assert_lt(root_b.distance_to(body.head_point(END.B)), 2.8, "and comes back")
	for k in rig.count:
		var gap := body.joints[k + 1].distance_to(body.joints[k])
		assert_almost_eq(gap, SerpentBody.SPACING, 0.02, "the chain stays whole through it all (%d)" % k)


func test_the_tail_winds_up_and_sweeps_round_toward_the_guard() -> void:
	var kit := _rigged()
	var body: SerpentBody = kit[0]
	var moves: SerpentMoves = kit[2]
	var brain: SerpentBrain = kit[3]
	var tip := body.joints[body.trailer_joint()]
	moves.guard = tip + Vector3(1.0, 1.4, 3.0)
	_drive(kit, 0.5)
	brain.force_attack(A.SWEEP)
	assert_eq(brain.attack_end(), END.B, "the trailing end")
	_drive(kit, SerpentBrain.stage_length(A.SWEEP, SerpentBrain.Stage.TELEGRAPH, 1) * 0.9)
	var wound := body.joints[body.trailer_joint()]
	assert_gt(moves.pose.rattle, 0.6, "the plates rattle")
	assert_lt(wound.z, tip.z - 0.3, "it winds up away from the guard")
	var swung := [0.0]
	_drive(kit, SerpentBrain.stage_length(A.SWEEP, SerpentBrain.Stage.TELEGRAPH, 1) * 0.1 + SerpentBrain.stage_length(A.SWEEP, SerpentBrain.Stage.STRIKE, 1) + 0.2, func() -> void:
		swung[0] = maxf(swung[0], body.joints[body.trailer_joint()].z))
	assert_gt(swung[0], tip.z + 1.8, "and comes round toward him (%.2f m)" % (swung[0] - tip.z))
	_drive(kit, SerpentBrain.stage_length(A.SWEEP, SerpentBrain.Stage.RECOVER, 1) + 1.2)
	assert_lt(absf(body.sweep), 0.1, "it settles")
	assert_lt(body.joints[body.trailer_joint()].distance_to(tip), 0.3)


func test_the_heads_watch_the_guard_and_phase_twos_light_runs_down_the_body() -> void:
	var kit := _rigged()
	var body: SerpentBody = kit[0]
	var moves: SerpentMoves = kit[2]
	var brain: SerpentBrain = kit[3]
	moves.guard = Vector3(6.0, 1.4, 6.0)
	_drive(kit, 1.5)
	var look := body.head_look(END.A)
	assert_gt(look.z, 0.35, "head A turned toward the guard's side")
	assert_gt(look.x, 0.3, "while still looking out along its line")
	assert_gt(moves.pose.head_glow[END.A], moves.pose.head_glow[END.B], "the spitting head glows")
	# (the guard out of every reach: nothing to attack while the light passes)
	moves.guard = Vector3(6.0, 1.4, 40.0)
	for i in 600:
		if brain.state == S.ROAM:
			break
		_drive(kit, STEP)
	brain.set_phase(2)
	_drive(kit, 0.1)
	assert_eq(brain.state, S.PHASE_SHIFT)
	_drive(kit, SerpentBrain.SHIFT_TIME * 0.45)
	assert_gt(moves.pose.light_s, 0.2, "the light is on its way down the body")
	assert_lt(moves.pose.light_s, 0.8)
	var a_look := body.head_look(END.A)
	var b_look := body.head_look(END.B)
	assert_lt(a_look.x, 0.2, "head A turns back toward head B")
	assert_gt(b_look.x, -0.2, "and head B toward head A")
	_drive(kit, SerpentBrain.SHIFT_TIME * 0.6 + 0.8)
	assert_eq(brain.spitter, END.B)
	assert_lt(moves.pose.light_s, 0.0, "the light arrived")
	assert_gt(moves.pose.head_glow[END.B], moves.pose.head_glow[END.A], "head B glows now")


# --- the shards ----------------------------------------------------------------------

## A guard stand-in: a body on the player's layer that records its hits.
class Guard:
	extends StaticBody3D
	var alive := true
	var hits: Array[DamageInfo] = []

	func _init() -> void:
		collision_layer = Layers.PLAYER
		collision_mask = 0
		var shape := CapsuleShape3D.new()
		shape.radius = 0.4
		shape.height = 1.8
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position.y = 0.9
		add_child(collider)

	func take_damage(info: DamageInfo) -> void:
		hits.append(info)


func test_a_shards_arc_comes_down_on_its_mark_in_its_time() -> void:
	var from := Vector3(0.0, 1.3, 0.0)
	for to: Vector3 in [Vector3(-6.0, 0.0, -9.0), Vector3(3.0, 0.0, -16.0), Vector3(0.0, 0.0, -5.0)]:
		var time := SerpentShard.flight_time(Vector2(to.x - from.x, to.z - from.z).length())
		assert_true(time >= SerpentBrain.SHARD_FLIGHT.x and time <= SerpentBrain.SHARD_FLIGHT.y)
		var shard := SerpentShard.make(from, to, time, 12.0, 10.0)
		var v := shard.velocity
		var end := from + v * time + Vector3.DOWN * 0.5 * SerpentShard.GRAVITY * time * time
		assert_lt(end.distance_to(to), 0.001, "on target %s" % str(to))
		assert_gt(v.y, 0.0, "spat up its arc")
		shard.free()
	var landed := SerpentShard.make(Vector3(0.0, 1.3, 0.0), Vector3(0.0, 0.0, -9.0), 0.9, 12.0, 10.0)
	var mark := GroundMark.disc(SerpentBrain.SPLASH_RADIUS)
	world.add_child(mark)
	mark.global_position = Vector3(0.0, 0.0, -9.0)
	landed.mark = mark
	var ends := watch(landed.finished)
	world.add_child(landed)
	var where := [Vector3.INF]
	for i in 80:
		if is_instance_valid(landed) and landed.is_inside_tree():
			where[0] = landed.global_position
		await get_tree().physics_frame
	assert_eq(ends.size(), 1, "it burst")
	if ends.size() == 1:
		assert_eq(ends[0][0], Projectile.End.WALL, "on the floor")
	assert_lt(Vector2(where[0].x, where[0].z + 9.0).length(), 0.35, "within a step of its mark (%s)" % where[0])
	assert_lt(where[0].y, 0.3, "down on the floor")
	assert_true(not is_instance_valid(mark) or mark.is_queued_for_deletion() or mark._fade != null, "the mark fades out")


func test_a_shards_splash_hurts_the_guard_beside_the_burst_and_a_plinth_stops_one() -> void:
	var near := Guard.new()
	world.add_child(near)
	near.global_position = Vector3(0.7, 0.0, -9.3)
	var far := Guard.new()
	world.add_child(far)
	far.global_position = Vector3(2.5, 0.0, -9.0)
	await physics_frames(2)
	# (aimed beside the near guard, not at him: the splash, not a hit)
	var shard := SerpentShard.make(Vector3(0.0, 1.3, 0.0), Vector3(-0.3, 0.0, -9.0), 0.9, 12.0, 10.0, null, near)
	world.add_child(shard)
	await physics_frames(80)
	assert_eq(near.hits.size(), 1, "the near guard felt the splash")
	if near.hits.size() == 1:
		assert_almost_eq(near.hits[0].amount, 10.0, 0.01)
		assert_gt(near.hits[0].direction.x, 0.5, "pushed away from the burst")
	assert_eq(far.hits.size(), 0, "the far one did not")
	# straight into a guard: the hit, and no splash on top of it
	var struck := Guard.new()
	world.add_child(struck)
	struck.global_position = Vector3(6.0, 0.0, -8.0)
	await physics_frames(2)
	var direct := SerpentShard.make(Vector3(6.0, 1.3, 0.0), Vector3(6.0, 0.0, -8.0), 0.8, 12.0, 10.0, null, struck)
	world.add_child(direct)
	await physics_frames(70)
	assert_eq(struck.hits.size(), 1, "one hit for a shard through him")
	if struck.hits.size() == 1:
		assert_almost_eq(struck.hits[0].amount, 12.0, 0.01, "the shard's own damage")
	# a plinth half way stops it short of its mark
	var plinth := StaticBody3D.new()
	plinth.collision_layer = Layers.WORLD
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 1.4, 1.6)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	plinth.add_child(collider)
	world.add_child(plinth)
	plinth.global_position = Vector3(-8.0, 0.7, -8.0)
	await physics_frames(2)
	var blocked := SerpentShard.make(Vector3(-8.0, 1.0, 0.0), Vector3(-8.0, 0.0, -10.0), 0.9, 12.0, 10.0)
	var ends := watch(blocked.finished)
	world.add_child(blocked)
	var last := [Vector3.ZERO]
	for i in 80:
		if is_instance_valid(blocked) and blocked.is_inside_tree():
			last[0] = blocked.global_position
		await get_tree().physics_frame
	assert_eq(ends.size(), 1)
	assert_gt(last[0].z, -8.0, "the plinth took it, short of the mark (%s)" % last[0])
