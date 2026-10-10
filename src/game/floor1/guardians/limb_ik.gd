class_name LimbIK
## Limb solving for rigid-part rigs (the guardians): turning a bone onto a
## direction by the smallest turn from its rest (so it keeps a natural
## twist) and the classic two-bone reach (a leg's hip, knee and ankle).


## The basis that turns [param rest] so that the bone's own [param axis]
## (in the bone's space, e.g. the way to its child joint) points along
## [param direction] (in the parent's space), by the smallest turn.
static func aim(rest: Basis, axis: Vector3, direction: Vector3) -> Basis:
	var from := (rest * axis).normalized()
	var to := direction.normalized()
	if from.is_zero_approx() or to.is_zero_approx():
		return rest
	var cosine := clampf(from.dot(to), -1.0, 1.0)
	if cosine > 0.99999:
		return rest
	var pivot := from.cross(to)
	if pivot.length_squared() < 0.0000001:
		# opposite: turn half round any axis across the bone
		pivot = from.cross(Vector3.UP)
		if pivot.length_squared() < 0.0000001:
			pivot = from.cross(Vector3.RIGHT)
	var turn := Basis(pivot.normalized(), acos(cosine))
	return (turn * rest).orthonormalized()


## Two bones of [param l1] and [param l2] reaching [param reach] from the
## root: x = the first bone's angle from the reach line, y = how far the
## second bone bends back from the first one's line (0 = straight), both in
## radians, in the plane of the bend. A reach out of range comes out as
## near as the bones allow (straight when too far).
static func two_bone(l1: float, l2: float, reach: float) -> Vector2:
	var d := clampf(reach, absf(l1 - l2) + 0.0001, l1 + l2 - 0.00001)
	var root := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	var inner := acos(clampf((l1 * l1 + l2 * l2 - d * d) / (2.0 * l1 * l2), -1.0, 1.0))
	return Vector2(root, PI - inner)


## Where the middle joint of two bones of [param l1] and [param l2] lies
## when the chain runs from [param root] to [param end]: in the plane of
## the reach line and [param pole] (the way the joint bends - a knee
## forward, a hock back, an elbow out), on the pole's side. Beyond reach the
## chain lies straight toward the end.
static func joint(root: Vector3, end: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3:
	var reach := end - root
	var distance := reach.length()
	var line := reach / distance if distance > 0.0001 else Vector3.DOWN
	var bend := pole - line * pole.dot(line)
	if bend.length_squared() < 0.00000001:
		bend = line.cross(Vector3.RIGHT if absf(line.x) < 0.9 else Vector3.FORWARD)
	bend = bend.normalized()
	var angles := two_bone(l1, l2, distance)
	return root + (line * cos(angles.x) + bend * sin(angles.x)) * l1
