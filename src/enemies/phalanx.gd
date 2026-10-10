class_name Phalanx
extends RefCounted
## Hoplites fighting shoulder to shoulder (design pietro-1-projekt 5.3):
## two or three awake hoplites close together form a line across the way
## to the guard, SPACING apart, so their round shields (SHIELD_WIDTH)
## overlap into one wall; the line faces [member front] and wheels toward
## the guard at most WHEEL_RATE rad/s (run round its end and the shields
## come too late), advances at the pace of its slowest man until its front
## stands HOLD_DISTANCE from him (spear reach), and closes ranks when a man
## falls out (stunned, destroyed, strayed LEAVE_DISTANCE from his place).
## Static helpers are pure geometry; the registry ties hoplites to their
## phalanx (Hoplite asks it every frame).

const SPACING := 0.8
const SHIELD_WIDTH := 0.9
## Hunting hoplites this close (m) form (or join) a phalanx.
const JOIN_RADIUS := 4.0
const MAX_MEMBERS := 3
## A man this far from his place has left the line.
const LEAVE_DISTANCE := 6.0
const WHEEL_RATE := 1.2
## Degrees a man's shield cover widens toward a neighbour's side.
const OVERLAP_ARC := 25.0
const HOLD_DISTANCE := 2.6
## While the line advances its places lie STEP metres ahead of its
## rearmost man: the line moves at his pace, the men ahead of their place
## wait for him (only shuffling sideways into line).
const STEP := 0.7

## Its men, left to right as seen from behind.
var members: Array[Enemy] = []
## Which way the line faces (flat, unit).
var front := Vector3.FORWARD
## The middle of the line now.
var center := Vector3.ZERO
## Where the middle of the line is heading (its men's places are around it).
var goal := Vector3.ZERO

var _frame: int = -1

## instance id -> Phalanx
static var _of: Dictionary = {}


## [param count] places on a line through [param middle] across
## [param facing], [param spacing] apart, left to right as seen from behind.
static func slots(middle: Vector3, facing: Vector3, count: int, spacing: float = SPACING) -> PackedVector3Array:
	var out := PackedVector3Array()
	var right := right_of(facing)
	for i in count:
		out.append(middle + right * ((i - (count - 1) * 0.5) * spacing))
	return out


## [param facing] turned toward [param wanted] (both flat) by at most
## [param rate] x [param delta] radians.
static func wheel(facing: Vector3, wanted: Vector3, delta: float, rate: float = WHEEL_RATE) -> Vector3:
	var from := Vector3(facing.x, 0.0, facing.z)
	var to := Vector3(wanted.x, 0.0, wanted.z)
	if to.length_squared() < 0.0001:
		return from.normalized() if from.length_squared() > 0.0001 else Vector3.FORWARD
	if from.length_squared() < 0.0001:
		return to.normalized()
	var a := atan2(-from.x, -from.z)
	var b := atan2(-to.x, -to.z)
	var turned := rotate_toward(a, b, rate * delta)
	return Vector3(-sin(turned), 0.0, -cos(turned))


## How much neighbouring shields overlap (m; above 0 = no gap).
static func shield_overlap(spacing: float = SPACING, width: float = SHIELD_WIDTH) -> float:
	return width - spacing


## The right of someone facing [param facing] (flat).
static func right_of(facing: Vector3) -> Vector3:
	var flat := Vector3(facing.x, 0.0, facing.z)
	return flat.normalized().cross(Vector3.UP) if flat.length_squared() > 0.0001 else Vector3.RIGHT


# --- the registry ----------------------------------------------------------

## The phalanx [param member] stands in (null: none).
static func of(member: Enemy) -> Phalanx:
	var pack := _of.get(member.get_instance_id()) as Phalanx
	if pack != null and not pack.members.has(member):
		_of.erase(member.get_instance_id())   # a stale entry (its man was freed)
		return null
	return pack


## [param member] forms a phalanx with the nearest of [param others] (none
## in a full one), or joins one of theirs. Returns its phalanx or null.
static func join(member: Enemy, others: Array) -> Phalanx:
	if of(member) != null:
		return of(member)
	var best: Enemy = null
	var best_distance := JOIN_RADIUS
	for other: Enemy in others:
		if other == member or not is_instance_valid(other):
			continue
		var pack := of(other)
		if pack != null and pack.members.size() >= MAX_MEMBERS:
			continue
		var distance := other.global_position.distance_to(member.global_position)
		if distance <= best_distance:
			best_distance = distance
			best = other
	if best == null:
		return null
	var pack := of(best)
	if pack == null:
		pack = Phalanx.new()
		pack._add(best)
		pack.front = -best.global_basis.z
		pack.front.y = 0.0
		pack.front = pack.front.normalized() if pack.front.length_squared() > 0.0001 else Vector3.FORWARD
	pack._add(member)
	pack._order()
	pack.center = Vector3.ZERO
	for man in pack.members:
		pack.center += man.global_position
	pack.center /= pack.members.size()
	pack.goal = pack.center
	return pack


## Takes [param member] out of its phalanx (a phalanx of one dissolves).
static func leave(member: Enemy) -> void:
	var pack := of(member)
	if pack == null:
		return
	pack.members.erase(member)
	_of.erase(member.get_instance_id())
	if pack.members.size() < 2:
		pack._dissolve()


## Forgets every phalanx (tests, a new night).
static func reset() -> void:
	_of.clear()


## Once per physics frame (whoever asks first): drops the men who left,
## wheels toward [param guard] and moves the line's goal.
func update(delta: float, guard: Vector3) -> void:
	var frame := Engine.get_physics_frames()
	if frame == _frame:
		return
	_frame = frame
	for member in members.duplicate():
		if not is_instance_valid(member):
			members.erase(member)
		elif not _fit(member):
			Phalanx.leave(member)
	if members.size() < 2:
		_dissolve()
	if members.size() < 2:
		return
	center = Vector3.ZERO
	for member in members:
		center += member.global_position
	center /= members.size()
	var to_guard := guard - center
	to_guard.y = 0.0
	front = Phalanx.wheel(front, to_guard, delta)
	_order()
	var rear := INF
	for member in members:
		rear = minf(rear, (member.global_position - center).dot(front))
	goal = center + front * minf(rear + STEP, to_guard.dot(front) - HOLD_DISTANCE)


## Where [param member] should stand now.
func goal_for(member: Enemy) -> Vector3:
	var index := members.find(member)
	if index < 0:
		return member.global_position
	var places := Phalanx.slots(goal, front, members.size())
	var place := places[index]
	place.y = member.global_position.y
	# a man already past his place waits for the line: he only steps aside
	var behind := (member.global_position - place).dot(front)
	if behind > 0.0:
		place += front * behind
	return place


## Share of his speed [param member] walks at: a man ahead of the
## rearmost slows down (to a quarter half a metre ahead) so the line
## straightens.
func pace_for(member: Enemy) -> float:
	if members.size() < 2:
		return 1.0
	var rear := INF
	for man in members:
		rear = minf(rear, man.global_position.dot(front))
	var ahead := member.global_position.dot(front) - rear
	return clampf(1.0 - ahead / 0.5, 0.25, 1.0)


## Neighbours of [param member]: x = one on its left, y = one on its right.
func neighbours(member: Enemy) -> Vector2i:
	var index := members.find(member)
	if index < 0:
		return Vector2i.ZERO
	return Vector2i(1 if index > 0 else 0, 1 if index < members.size() - 1 else 0)


func _add(member: Enemy) -> void:
	members.append(member)
	_of[member.get_instance_id()] = self


## Left to right along the line, as they stand.
func _order() -> void:
	var right := Phalanx.right_of(front)
	members.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.global_position.dot(right) < b.global_position.dot(right))


## Still a man of the line: alive, in the tree, hunting (not stunned), not
## strayed far from his place.
func _fit(member: Enemy) -> bool:
	if not member.is_inside_tree() or not member.brain.is_hunting():
		return false
	return member.global_position.distance_to(goal_for(member)) <= LEAVE_DISTANCE


func _dissolve() -> void:
	for member in members:
		if is_instance_valid(member):
			_of.erase(member.get_instance_id())
	members.clear()
