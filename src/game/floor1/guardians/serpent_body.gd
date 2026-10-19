class_name SerpentBody
extends RefCounted
## The Two-headed Serpent's spine as pure logic (plan
## docs/superpowers/plans/2026-10-03-straznik-waz.md): [member count]
## segments of SPACING m jointed end to end, end A (joint 0, head A) to end
## B (the last joint, head B). The body moves follow-the-leader: the leader
## is the neck root of the leading end (joint NECK, or count - NECK) and
## every joint behind it lies on the trail the leader left, a fixed arc
## length behind - so every segment passes through the same points, and
## the lateral wave the course puts into the leader's path travels down
## the body as it does on a real snake. The trail keeps the ground height
## under the leader ([member height_at]), its slope limited to MAX_SLOPE,
## so the body follows ramps and bridges a step rather than dropping over
## it; each joint rides its own radius over that ground (the belly on the
## floor). [member arches] lift the lying body in smooth humps that keep
## the spacing (the body takes in the slack at its trailing end), and
## [member sweep] bends the trailing tail aside in an arc of constant
## length. The necks (NECK segments each) are cubic Beziers from the body's
## end to wherever the head was asked to be (set_head: a position and a
## look direction), with their handles found so the curve is exactly the
## neck's length; a head out of reach is pulled in along the line.
## reverse() hands the lead to the other head without moving a joint.
## World space throughout; the node turns joints into segment transforms
## (segment_transform: +Z from end A toward end B, the model's axis).

enum End { A, B }

const SPACING := 0.75
## Segments in each neck (the head rides the end joint).
const NECK := 4
## Segments of the whole body (necks included).
const SEGMENTS := 45
## The trail's ground height changes at most this much per metre travelled.
const MAX_SLOPE := 1.2
## The leader looks this far ahead for a rise it must climb (m): the trail
## lifts before a step like a snake reaching onto a ledge, never into its
## side (advance()'s ahead points).
const LOOKAHEAD := 1.3
## A laid path is sampled this densely for the ground under it (m).
const LAY_STEP := 0.1
## Shortest distance between two trail points (finer moves slide the newest
## point on, the leader itself): the trail is a polyline of chords this long
## - a metre of it is ten points, a wave's curve is true to a millimetre.
const TRAIL_STEP := 0.1
## The trail is cut back in lumps this long (m): a cut copies it.
const TRIM_LUMP := 3.0
## Points on a neck's Bezier (a rounded neck is true to ~3 mm).
const CURVE_STEPS := 24
## A neck is left as it is while its root, its target and its looks stay
## within this (m squared, and a dot-product gap) of what it was last laid for.
const NECK_EPSILON_SQ := 1.0e-6
const NECK_DOT_GAP := 5.0e-7
## The neck's arch is found to this (m); a warm start brackets the last
## solution by this much each way.
const ARCH_TOLERANCE := 0.001
const ARCH_WARM := 0.12
## The sweeping tail: its last joints turn aside by this much in all (rad).
const SWEEP_TURN := 1.9
const SWEEP_JOINTS := 7
## The model's segment count and its radius profile (serpent.py).
const MODEL_SEGMENTS := 14
## Where a head rests when nobody asked for a pose: out along the body's
## line and up (root frame: -Z outward).
const HEAD_REST := Vector3(0.0, 0.75, -2.5)
const HEAD_REST_LOOK := Vector3(0.0, -0.15, -1.0)

var count: int = SEGMENTS
## Radius of the body at each joint (count + 1).
var radii: PackedFloat32Array
## Axis positions of the joints (count + 1), end A first.
var joints: PackedVector3Array
## Which head leads.
var lead: End = End.A
## (Vector3) -> float: the ground height under a point (world).
var height_at: Callable = Callable()
## Humps of the lying body: [s along the lying body from end A's neck root
## (m), height (m), half width (m)] each.
var arches: Array = []
## -1..1: the trailing tail bent aside (its last SWEEP_JOINTS joints).
var sweep: float = 0.0

## The leader's trail, oldest point first, the newest = the leader; y is
## the ground height there.
var _trail: PackedVector3Array
## Cumulative length from the oldest trail point.
var _trail_len: PackedFloat32Array
## Ground height under each joint (count + 1; the necks copy their root's).
var _ground: PackedFloat32Array
var _head_target: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _head_look: Array[Vector3] = [Vector3.FORWARD, Vector3.BACK]
var _head_set: Array[bool] = [false, false]
## Per end: what its neck was last laid for ([root, root direction, target,
## look]; empty = lay it) and the arch it needed (warm start).
var _neck_seen: Array = [[], []]
var _neck_arch: Array = [[-1.0], [-1.0]]


func _init(segments: int = SEGMENTS) -> void:
	count = maxi(segments, 2 * NECK + 2)
	radii = radius_profile(count)
	joints.resize(count + 1)
	_ground.resize(count + 1)


# --- the model's profile -----------------------------------------------------------

## Which of the model's 14 segments (1..14) segment [param k] (0-based) of a
## body of [param segments] copies: the first seven are 1..7, the last seven
## 8..14, the middle alternates the fattest two (7, 8).
static func model_segment(k: int, segments: int) -> int:
	if k < 7:
		return k + 1
	if k >= segments - 7:
		return 8 + (k - (segments - 7))
	return 7 if (k - 7) % 2 == 0 else 8


## The body's radius at the A-side joint of the model's segment [param
## original] (1..15: 15 = end B), serpent.py's profile.
static func model_radius(original: int) -> float:
	var t := float(original - 1) / float(MODEL_SEGMENTS)
	return 0.4 + 0.12 * pow(sin(PI * t), 0.7)


## The radius at every joint of a body of [param segments].
static func radius_profile(segments: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(segments + 1)
	for k in segments:
		out[k] = model_radius(model_segment(k, segments))
	out[segments] = model_radius(MODEL_SEGMENTS + 1)
	return out


# --- laying and moving --------------------------------------------------------------

## Lays the body along [param path] (flat points; the ground is sampled
## every LAY_STEP along it): the leader at its last point, the rest behind
## along it (a short path is extended straight back). The resting body
## lies on the highest thing under it and slopes off it each way at
## MAX_SLOPE at most: over a flight's side it humps, it never sinks in.
func lay(path: PackedVector3Array) -> void:
	_trail = PackedVector3Array()
	_trail_len = PackedFloat32Array()
	_forget_necks()
	if path.size() < 2:
		var at := path[0] if path.size() == 1 else Vector3.ZERO
		path = PackedVector3Array([at - Vector3(1.0, 0.0, 0.0), at])
	var dense := PackedVector3Array([Vector3(path[0].x, 0.0, path[0].z)])
	for i in range(1, path.size()):
		var a := Vector3(path[i - 1].x, 0.0, path[i - 1].z)
		var b := Vector3(path[i].x, 0.0, path[i].z)
		var gap := a.distance_to(b)
		if gap < 0.001:
			continue
		var steps := maxi(1, ceili(gap / LAY_STEP))
		for k in range(1, steps + 1):
			dense.append(a.lerp(b, float(k) / float(steps)))
	var ground := PackedFloat32Array()
	for point in dense:
		ground.append(_sample_ground(point))
	for i in range(1, dense.size()):
		ground[i] = maxf(ground[i], ground[i - 1] - MAX_SLOPE * dense[i].distance_to(dense[i - 1]))
	for i in range(dense.size() - 2, -1, -1):
		ground[i] = maxf(ground[i], ground[i + 1] - MAX_SLOPE * dense[i].distance_to(dense[i + 1]))
	for i in dense.size():
		_push_trail(Vector3(dense[i].x, ground[i], dense[i].z), true)
	_extend_trail_back()
	_rebuild_lengths()
	update()


## The leader moves to [param to] (flat; the ground is sampled under it).
## [param ahead]: points of its line further on (flat, within LOOKAHEAD):
## higher ground there lifts the trail already at MAX_SLOPE, so the body
## climbs onto a step rather than into its side; dropping ground is left
## to the slope limit, so it bridges off a step rather than falling.
func advance(to: Vector3, ahead: PackedVector3Array = PackedVector3Array()) -> void:
	if _trail.is_empty():
		lay(PackedVector3Array([to]))
		return
	var last := _trail[_trail.size() - 1]
	var flat := Vector2(to.x - last.x, to.z - last.z).length()
	if flat < 0.0005:
		return
	var ground := _sample_ground(to)
	for point in ahead:
		var gap := Vector2(point.x - to.x, point.z - to.z).length()
		if gap > 0.001:
			ground = maxf(ground, _sample_ground(point) - MAX_SLOPE * gap)
	ground = clampf(ground, last.y - MAX_SLOPE * flat, last.y + MAX_SLOPE * flat)
	_push_trail(Vector3(to.x, ground, to.z), false)
	_trim_trail()
	update()


## The other head leads from here: the trail becomes the body as it lies,
## reversed; no joint moves.
func reverse() -> void:
	var ground := ground_joints()
	var reversed := PackedVector3Array()
	var from := ground.x if lead == End.A else ground.y
	var to := ground.y if lead == End.A else ground.x
	var step := 1 if to > from else -1
	var j := from
	while true:
		reversed.append(Vector3(joints[j].x, _ground[j], joints[j].z))
		if j == to:
			break
		j += step
	lead = End.B if lead == End.A else End.A
	_trail = reversed
	_extend_trail_back()
	_rebuild_lengths()
	_forget_necks()
	update()


## Where head [param end] should be (its pivot, world) and look.
func set_head(end: End, target: Vector3, look: Vector3) -> void:
	_head_target[end] = target
	_head_look[end] = look.normalized() if look.length() > 0.001 else Vector3.FORWARD
	_head_set[end] = true


## Lets head [param end] fall back to its rest pose.
func clear_head(end: End) -> void:
	_head_set[end] = false


## Recomputes every joint from the trail, the arches, the sweep and the
## heads (advance() and lay() do it; call after changing the rest).
func update() -> void:
	if _trail.size() < 2:
		return
	_settle_lying()
	_settle_tail()
	_settle_neck(End.A)
	_settle_neck(End.B)


# --- reading ------------------------------------------------------------------------

## The leader: the neck root of the leading end (axis position).
func leader() -> Vector3:
	return joints[leader_joint()]


func leader_joint() -> int:
	return NECK if lead == End.A else count - NECK


## The trailing end's neck root.
func trailer_joint() -> int:
	return count - NECK if lead == End.A else NECK


## First and last joint (x, y) of the lying body (the neck roots included).
func ground_joints() -> Vector2i:
	return Vector2i(NECK, count - NECK)


## Length of the lying body between the neck roots (m).
func lying_length() -> float:
	return float(count - 2 * NECK) * SPACING


## Arc length of joint [param j] along the lying body from end A's neck
## root (the arches' coordinate).
func s_of_joint(j: int) -> float:
	return float(j - NECK) * SPACING


## The neck root of [param end] as a frame: origin on the joint, -Z the way
## out of the body (flat), +Y up.
func root_frame(end: End) -> Transform3D:
	var root := NECK if end == End.A else count - NECK
	var inward := NECK + 1 if end == End.A else count - NECK - 1
	var out := joints[root] - joints[inward]
	out.y = 0.0
	if out.length() < 0.001:
		out = Vector3.FORWARD
	return Transform3D(Basis.looking_at(out.normalized(), Vector3.UP), joints[root])


## The way out of the body at [param end]'s neck root (3D, unit).
func root_direction(end: End) -> Vector3:
	var root := NECK if end == End.A else count - NECK
	var inward := NECK + 1 if end == End.A else count - NECK - 1
	var out := joints[root] - joints[inward]
	return out.normalized() if out.length() > 0.001 else Vector3.FORWARD


## The ground height under joint [param j].
func ground_of(j: int) -> float:
	return _ground[j]


## Where head [param end]'s pivot is (the end joint).
func head_point(end: End) -> Vector3:
	return joints[0] if end == End.A else joints[count]


## The look direction head [param end] was given (or its rest look).
func head_look(end: End) -> Vector3:
	if _head_set[end]:
		return _head_look[end]
	return root_frame(end).basis * HEAD_REST_LOOK.normalized()


## Segment [param k]'s transform: origin on joint k, +Z toward joint k + 1
## (the model's axis from end A to end B), no roll.
func segment_transform(k: int) -> Transform3D:
	var along := joints[k + 1] - joints[k]
	if along.length() < 0.0005:
		along = root_direction(End.B) if k >= count - NECK else -root_direction(End.A)
	along = along.normalized()
	var up := Vector3.UP
	if absf(along.dot(up)) > 0.98:
		up = Vector3.FORWARD
	var right := up.cross(along).normalized()
	up = along.cross(right).normalized()
	return Transform3D(Basis(right, up, along), joints[k])


## The trail [param back] m behind the leader (flat point, y = the ground
## there): for marks and tests.
func trail_point(back: float) -> Vector3:
	return _sample_trail(back)


# --- the trail ----------------------------------------------------------------------

func _sample_ground(at: Vector3) -> float:
	if height_at.is_valid():
		return float(height_at.call(at))
	return 0.0


## Adds [param point] as the newest (the leader), keeping the cumulative
## lengths; unless [param keep], a point within TRAIL_STEP of the one before
## the newest just moves the newest on.
func _push_trail(point: Vector3, keep: bool) -> void:
	var n := _trail.size()
	if n == 0:
		_trail.append(point)
		_trail_len.append(0.0)
		return
	if not keep and n > 1 and _trail[n - 2].distance_to(point) < TRAIL_STEP:
		_trail[n - 1] = point   # a short move: the leader slides on
		_trail_len[n - 1] = _trail_len[n - 2] + _trail[n - 2].distance_to(point)
		return
	_trail.append(point)
	_trail_len.append(_trail_len[n - 1] + _trail[n - 1].distance_to(point))


## The trail must reach the trailing neck root: a short one runs on
## straight back along its oldest leg.
func _extend_trail_back() -> void:
	var needed := lying_length() + 3.0 * SPACING
	var length := 0.0
	for i in range(1, _trail.size()):
		length += _trail[i].distance_to(_trail[i - 1])
	if length >= needed:
		return
	var back := _trail[0] - _trail[1]
	back.y = 0.0
	back = back.normalized() if back.length() > 0.001 else Vector3.LEFT
	var first := _trail[0]
	var steps := ceili((needed - length) / 0.5)
	var prefix := PackedVector3Array()
	for i in range(steps, 0, -1):
		prefix.append(first + back * (0.5 * i))
	prefix.append_array(_trail)
	_trail = prefix


func _rebuild_lengths() -> void:
	_trail_len.resize(_trail.size())
	var total := 0.0
	_trail_len[0] = 0.0
	for i in range(1, _trail.size()):
		total += _trail[i].distance_to(_trail[i - 1])
		_trail_len[i] = total


## Drops trail points farther behind the leader than the body needs (in
## lumps: a cut copies the trail).
func _trim_trail() -> void:
	var keep := lying_length() + 4.0 * SPACING + 2.0
	var head := _trail_len[_trail_len.size() - 1]
	if _trail.size() < 4 or head - _trail_len[1] <= keep + TRIM_LUMP:
		return
	var cut := 0
	while cut + 2 < _trail.size() and head - _trail_len[cut + 1] > keep:
		cut += 1
	if cut > 0:
		_trail = _trail.slice(cut)
		_rebuild_lengths()


## The index of the last trail point at or before cumulative length
## [param wanted] (0 when none): where a walk back from the leader may stop.
func _trail_before(wanted: float) -> int:
	if wanted <= 0.0:
		return 0
	var low := 0
	var high := _trail.size() - 1
	while high - low > 1:
		var mid := (low + high) >> 1
		if _trail_len[mid] <= wanted:
			low = mid
		else:
			high = mid
	return low


## The trail point [param back] m behind the leader (flat, y = ground).
func _sample_trail(back: float) -> Vector3:
	var head := _trail_len[_trail_len.size() - 1]
	var wanted := head - back
	if wanted <= 0.0:
		var away := _trail[0] - _trail[1]
		return _trail[0] + (away.normalized() if away.length() > 0.001 else Vector3.LEFT) * -wanted
	var low := 0
	var high := _trail.size() - 1
	while high - low > 1:
		var mid := (low + high) >> 1
		if _trail_len[mid] <= wanted:
			low = mid
		else:
			high = mid
	var span := _trail_len[high] - _trail_len[low]
	var t := (wanted - _trail_len[low]) / span if span > 0.0 else 0.0
	return _trail[low].lerp(_trail[high], t)


## Lift of the arches at [param s] along the lying body.
func _lift_at(s: float) -> float:
	var lift := 0.0
	for arch: Array in arches:
		var center := float(arch[0])
		var height := float(arch[1])
		var half := maxf(float(arch[2]), 0.01)
		var d := absf(s - center)
		if d < half:
			lift += height * 0.5 * (1.0 + cos(PI * d / half))
	return lift


# --- settling the joints -------------------------------------------------------------

## The lying joints: rigid links of SPACING walked back along the trail
## (the polyline itself), lifted by the arches.
func _settle_lying() -> void:
	var lying := lying_length()
	var reach := lying + 2.0 * SPACING
	# the trail from the leader back as far as the body reaches
	var newest := _trail.size() - 1
	var head := _trail_len[newest]
	var oldest := _trail_before(head - reach)
	var dense := _trail.slice(oldest)
	dense.reverse()
	var arched := not arches.is_empty()
	var dense_ground := PackedFloat32Array()
	if arched:
		dense_ground.resize(dense.size())
		for i in dense.size():
			var back := head - _trail_len[newest - i]
			var point := dense[i]
			dense_ground[i] = point.y
			point.y += _lift_at(back if lead == End.A else lying - back)
			dense[i] = point
	# rigid links: each joint exactly SPACING from the one before, on the
	# lifted trail (a bend takes up a little of the trail's length)
	var lead_joint := leader_joint()
	var step := 1 if lead == End.A else -1
	var links := count - 2 * NECK
	var walk := chord_walk(dense, links, SPACING)
	var spots: PackedVector3Array = walk[0]
	var where: PackedVector2Array = walk[1]
	var last := dense.size() - 1
	for n in range(0, links + 1):
		var j := lead_joint + step * n
		var at := spots[n]
		var here := where[n]   # (dense index, t)
		var i := int(here.x)
		var next := mini(i + 1, last)
		_ground[j] = lerpf(dense_ground[i], dense_ground[next], here.y) if arched else lerpf(dense[i].y, dense[next].y, here.y)
		joints[j] = Vector3(at.x, at.y + radii[j], at.z)


## The trailing tail bent aside by [member sweep]: its last joints turned
## progressively about the vertical, their spacing kept.
func _settle_tail() -> void:
	if absf(sweep) < 0.001:
		return
	var ground := ground_joints()
	var tip := ground.y if lead == End.A else ground.x
	var step := 1 if lead == End.A else -1
	var base := tip - step * SWEEP_JOINTS
	var n := SWEEP_JOINTS
	var links := PackedVector3Array()
	for i in range(1, n + 1):
		links.append(joints[base + step * i] - joints[base + step * (i - 1)])
	var previous := joints[base]
	for i in range(1, n + 1):
		var j := base + step * i
		# the turn grows toward the tip: joint i has turned i(i+1)/(n(n+1))
		# of the whole sweep
		var total := sweep * SWEEP_TURN * float(i * (i + 1)) / float(n * (n + 1))
		joints[j] = previous + links[i - 1].rotated(Vector3.UP, total)
		previous = joints[j]


## The neck of [param end]: a Bezier of the neck's length from its root to
## the head's target. Left alone while nothing it was laid for has moved.
func _settle_neck(end: End) -> void:
	var root := NECK if end == End.A else count - NECK
	var inward := NECK + 1 if end == End.A else count - NECK - 1
	var root_at := joints[root]
	var away := root_at - joints[inward]
	var root_dir := away.normalized() if away.length() > 0.001 else Vector3.FORWARD
	var target: Vector3
	var look: Vector3
	if _head_set[end]:
		target = _head_target[end]
		look = _head_look[end]
	else:
		var frame := root_frame(end)
		target = frame * HEAD_REST
		look = frame.basis * HEAD_REST_LOOK.normalized()
	var seen: Array = _neck_seen[end]
	if seen.size() == 4 and root_at.distance_squared_to(seen[0]) < NECK_EPSILON_SQ and target.distance_squared_to(seen[2]) < NECK_EPSILON_SQ and root_dir.dot(seen[1]) > 1.0 - NECK_DOT_GAP and look.dot(seen[3]) > 1.0 - NECK_DOT_GAP:
		return
	_neck_seen[end] = [root_at, root_dir, target, look]
	var points := bend(root_at, root_dir, target, look, float(NECK) * SPACING, NECK, _neck_arch[end])
	for i in range(1, points.size()):
		var j := root - i if end == End.A else root + i
		joints[j] = points[i]
		_ground[j] = _ground[root]


## Lays both necks afresh at the next update.
func _forget_necks() -> void:
	_neck_seen = [[], []]


# --- the Bezier necks ----------------------------------------------------------------

## [param n] + 1 points from [param root] to [param head] along a cubic
## Bezier leaving the root along [param root_dir] and arriving at the head
## roughly along [param head_dir] (its look, bent toward the chord), its
## slack taken up by an arch: both handles lifted across the chord (up)
## until [param n] rigid links of [param length] / [param n] walked along
## the curve land on the head (bisection; the arch grows the curve
## monotonically, so the walk never jumps). A head beyond reach is pulled
## in along the line and the chain lies straight. [param memory]: a
## one-element array holding the arch the last call needed (-1 = none); the
## search starts from it and leaves this call's there.
static func bend(root: Vector3, root_dir: Vector3, head: Vector3, head_dir: Vector3, length: float, n: int, memory: Array = []) -> PackedVector3Array:
	var out := PackedVector3Array()
	var chord := head - root
	var distance := chord.length()
	if distance >= length * 0.995 or distance < 0.001:
		var line := chord.normalized() if distance > 0.001 else root_dir.normalized()
		for i in range(0, n + 1):
			out.append(root + line * (length * float(i) / float(n)))
		return out
	var spacing := length / float(n)
	var along := chord / distance
	var d0 := root_dir.normalized()
	# the arrival handle: the look, bent toward the line (a head turned right
	# back would otherwise hook the neck round)
	var d3 := (head_dir.normalized() * 0.5 + along * 0.5)
	d3 = d3.normalized() if d3.length() > 0.001 else along
	var handle := 0.35 * distance
	# the arch's direction: across the chord, up
	var lift := Vector3.UP - along * along.dot(Vector3.UP)
	if lift.length() < 0.05:
		lift = d0 - along * along.dot(d0)
	if lift.length() < 0.05:
		lift = Vector3.RIGHT - along * along.dot(Vector3.RIGHT)
	lift = lift.normalized()
	var curve := _bezier_points(root, root + d0 * handle, head - d3 * handle, head, CURVE_STEPS)
	if _lands_short(curve, n, spacing):
		# the handles alone make it too long (a head near full reach): shorter
		# handles, no arch
		var low_k := 0.0
		var high_k := 1.0
		while high_k - low_k > 0.002:
			var mid_k := 0.5 * (low_k + high_k)
			curve = _bezier_points(root, root + d0 * handle * mid_k, head - d3 * handle * mid_k, head, CURVE_STEPS)
			if _lands_short(curve, n, spacing):
				high_k = mid_k
			else:
				low_k = mid_k
		var k := 0.5 * (low_k + high_k)
		curve = _bezier_points(root, root + d0 * handle * k, head - d3 * handle * k, head, CURVE_STEPS)
		if not memory.is_empty():
			memory[0] = -1.0
	else:
		var low := 0.0
		var high := 1.5 * length
		var guess: float = memory[0] if not memory.is_empty() else -1.0
		if guess >= 0.0:
			# bracket the last arch: a probe either side narrows [low, high]
			var below := maxf(guess - ARCH_WARM, 0.0)
			if below > 0.0:
				if _lands_short(_arched(root, d0, head, d3, handle, lift, below), n, spacing):
					high = below
				else:
					low = below
			var above := minf(guess + ARCH_WARM, high)
			if above > low and above < high:
				if _lands_short(_arched(root, d0, head, d3, handle, lift, above), n, spacing):
					high = above
				else:
					low = above
		while high - low > ARCH_TOLERANCE:
			var mid := 0.5 * (low + high)
			if _lands_short(_arched(root, d0, head, d3, handle, lift, mid), n, spacing):
				high = mid   # it stopped short: the curve is too long
			else:
				low = mid   # the walk ran off the end: the curve is too short
		var b := 0.5 * (low + high)
		curve = _arched(root, d0, head, d3, handle, lift, b)
		if not memory.is_empty():
			memory[0] = b
	out = chord_walk(curve, n, spacing)[0]
	# the walk lands within a hair of the head: close on it (the last link
	# a hair off its length rather than the head floating off its neck)
	if out[n].distance_to(head) < 0.06:
		out[n] = head
	return out


## The neck's curve with both handles lifted by [param b] across the chord.
static func _arched(root: Vector3, d0: Vector3, head: Vector3, d3: Vector3, handle: float, lift: Vector3, b: float) -> PackedVector3Array:
	return _bezier_points(root, root + d0 * handle + lift * b, head - d3 * handle + lift * b, head, CURVE_STEPS)


## Walks [param count] rigid links of [param spacing] along polyline
## [param line] from its first point: [0] the [param count] + 1 points,
## [1] where each lies as Vector2(segment index, t along it; t > 1 on the
## last segment = extrapolated past the end), [2] where the last lies (all
## that is kept unless [param collect]).
static func chord_walk(line: PackedVector3Array, count: int, spacing: float, collect: bool = true) -> Array:
	var points := PackedVector3Array()
	var where := PackedVector2Array()
	if collect:
		points.append(line[0])
		where.append(Vector2(0.0, 0.0))
	var landed := Vector2(0.0, 0.0)
	var index := 0
	var at := line[0]
	var last := line.size() - 1
	for n in count:
		var found := false
		var k := index
		while k < last:
			var a := line[k] if k > index else at
			var b := line[k + 1]
			if b.distance_to(at) >= spacing:
				# the sphere of spacing round `at` cuts a-b at its far root
				var d := a - at
				var e := b - a
				var qa := e.dot(e)
				var qb := 2.0 * d.dot(e)
				var qc := d.dot(d) - spacing * spacing
				var disc := maxf(qb * qb - 4.0 * qa * qc, 0.0)
				var t := clampf((-qb + sqrt(disc)) / (2.0 * qa), 0.0, 1.0) if qa > 0.0 else 1.0
				at = a + e * t
				var full := line[k + 1] - line[k]
				var own := (at - line[k]).dot(full) / full.dot(full) if full.length_squared() > 0.0 else 1.0
				index = k
				landed = Vector2(float(k), clampf(own, 0.0, 1.0))
				found = true
				break
			k += 1
		if not found:
			# off the end: straight on along the last leg
			var leg := line[last] - line[maxi(last - 1, 0)]
			leg = leg.normalized() if leg.length() > 0.0001 else Vector3.FORWARD
			if index < last:
				at = line[last] + leg * (spacing - at.distance_to(line[last]))
			else:
				at = at + leg * spacing
			index = last
			landed = Vector2(float(last), 1.0 + (at - line[last]).length() / maxf(spacing, 0.001))
		if collect:
			where.append(landed)
			points.append(at)
	return [points, where, landed]


## True when [param n] links of [param spacing] walked along [param curve]
## end before its last point (the curve is longer than the chain).
static func _lands_short(curve: PackedVector3Array, n: int, spacing: float) -> bool:
	var landed: Vector2 = chord_walk(curve, n, spacing, false)[2]
	return not (landed.x >= float(curve.size() - 1) - 0.5 and landed.y > 1.0)


static func _bezier_points(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, steps: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(steps + 1)
	var scale := 1.0 / float(steps)
	for i in range(0, steps + 1):
		out[i] = p0.bezier_interpolate(p1, p2, p3, float(i) * scale)
	return out


static func _polyline_length(points: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
	return total
