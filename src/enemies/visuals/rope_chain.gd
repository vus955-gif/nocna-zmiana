class_name RopeChain
extends RefCounted
## A rope of points in world space (Verlet integration with distance
## constraints): the mummy's bandage whip and its loose bandage strips. The
## first point is pinned to a root that the owner moves every step (a
## wrist, the back of the head); the rest swing behind it on their own, so
## they lag, overshoot and settle without being animated. [method
## pull_toward] steers points toward targets (the whip's telegraph and its
## lash) with a per-point weight; weight 0 leaves a point to the physics.
## Lengths may change at any time (the whip unrolls and coils back).

## Fraction of its velocity a point loses every step (air drag).
var damping: float = 0.08
var gravity := Vector3(0.0, -9.8, 0.0)
## Free points never sink below this height (the floor it drags on; -INF =
## none). Points on it lose their horizontal swing to friction.
var floor_y: float = -INF
var friction: float = 0.3
## World positions; [0] is the root.
var points := PackedVector3Array()
## Length of segment i (from point i to point i + 1).
var lengths := PackedFloat32Array()

var _previous := PackedVector3Array()


## A rope of [param count] segments of [param length] hanging straight
## down from [param root], at rest.
static func hanging(root: Vector3, count: int, length: float) -> RopeChain:
	var rope := RopeChain.new()
	for i in count + 1:
		rope.points.append(root + Vector3.DOWN * length * i)
	for i in count:
		rope.lengths.append(length)
	rope._previous = rope.points.duplicate()
	return rope


## Moves every point at once (the rope keeps its shape and loses its
## swing): the owner teleported.
func place(root: Vector3) -> void:
	if points.is_empty():
		return
	var shift := root - points[0]
	for i in points.size():
		points[i] += shift
	_previous = points.duplicate()


## One step: free points move on with their velocity plus gravity, the
## root is pinned to [param root], then [param iterations] passes pull every
## segment back to its length (from the root outwards: the root never
## moves).
func step(delta: float, root: Vector3, iterations: int = 4) -> void:
	if points.is_empty():
		return
	var keep := 1.0 - damping
	var fall := gravity * delta * delta
	for i in range(1, points.size()):
		var now := points[i]
		points[i] = now + (now - _previous[i]) * keep + fall
		_previous[i] = now
	points[0] = root
	_previous[0] = root
	for pass_index in iterations:
		for i in lengths.size():
			var a := points[i]
			var b := points[i + 1]
			var span := b - a
			var distance := span.length()
			if distance < 0.00001:
				continue
			var fix := span * ((distance - lengths[i]) / distance)
			if i == 0:
				points[i + 1] = b - fix   # the root is pinned: the other end takes it all
			else:
				points[i] = a + fix * 0.5
				points[i + 1] = b - fix * 0.5
	if floor_y > -INF:
		for i in range(1, points.size()):
			if points[i].y < floor_y:
				var slide := points[i] - _previous[i]
				points[i].y = floor_y
				_previous[i] = points[i] - Vector3(slide.x, 0.0, slide.z) * (1.0 - friction)


## Draws each free point toward [param targets][i] by
## (1 - exp(-[param rate] * [param delta])) times [param weights][i]
## (missing entries: no pull). The move counts as velocity too, so a
## released point flies on (the lash's follow-through).
func pull_toward(targets: PackedVector3Array, weights: PackedFloat32Array, delta: float, rate: float) -> void:
	var share := 1.0 - exp(-rate * delta)
	for i in range(1, mini(points.size(), mini(targets.size(), weights.size()))):
		var weight := clampf(weights[i], 0.0, 1.0)
		if weight <= 0.0:
			continue
		points[i] = points[i].lerp(targets[i], share * weight)


## Gives every free point [param velocity] (m/s) more, as one step of
## [param delta] would: a hit swings the rope.
func kick(velocity: Vector3, delta: float) -> void:
	for i in range(1, points.size()):
		points[i] += velocity * delta * (float(i) / (points.size() - 1))


## The rope's full length (the sum of its segments).
func span() -> float:
	var total := 0.0
	for length in lengths:
		total += length
	return total


## Unit direction of segment [param i] (down when it has no length).
func direction(i: int) -> Vector3:
	var run := points[i + 1] - points[i]
	return run / run.length() if run.length() > 0.00001 else Vector3.DOWN


## The last point.
func tip() -> Vector3:
	return points[points.size() - 1]
