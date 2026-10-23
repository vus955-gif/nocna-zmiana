class_name EnemyCrowd
extends RefCounted
## Crowd rules for many exhibits chasing one guard (20-40 at once):
## - melee attackers close to their target take one of RING_SLOTS places on
##   a ring around it instead of all aiming at its centre; when every place
##   is taken, the rest wait a step further out. Only an attacker that sees
##   its target on the same floor takes part (not through a floor or wall),
## - exhibits on their feet (hunting, attacking, investigating, searching,
##   going home, patrolling) closer than SEPARATION_RADIUS push apart (same
##   floor only).
## Pure helpers (AttackRing, separation) plus a registry of active exhibits.

const RING_SLOTS := 10
const SEPARATION_RADIUS := 1.1
## Push speed (m/s) at full overlap.
const SEPARATION_SPEED := 1.6
## Chasers this close (m) to their target head for a ring place.
const ENGAGE_RANGE := 6.0
## ... and give it up again beyond this.
const DISENGAGE_RANGE := 7.5
## Ring radius as a fraction of the attacker's attack range.
const RING_FRACTION := 0.75
## Waiting attackers stand this much further out than the ring.
const WAIT_MARGIN := 0.8
## Exhibits more than this apart in height are on different floors.
const SAME_FLOOR := 1.2


## Places around one target. Owners are instance ids (0 = free).
class AttackRing:
	var owners: Array[int] = []

	func _init() -> void:
		owners.resize(EnemyCrowd.RING_SLOTS)
		owners.fill(0)

	## The place [param who] holds, or the free one closest to
	## [param bearing] (radians, 0 = +X, towards +Z); -1 when all are taken.
	func claim(who: int, bearing: float) -> int:
		var held := owners.find(who)
		if held >= 0:
			return held
		var best := -1
		var best_gap := INF
		for i in owners.size():
			if owners[i] != 0:
				continue
			var gap := absf(angle_difference(bearing, angle(i)))
			if gap < best_gap:
				best_gap = gap
				best = i
		if best >= 0:
			owners[best] = who
		return best

	func release(who: int) -> void:
		var held := owners.find(who)
		if held >= 0:
			owners[held] = 0

	func is_empty() -> bool:
		return owners.count(0) == owners.size()

	static func angle(index: int) -> float:
		return TAU * index / EnemyCrowd.RING_SLOTS


static var _members: Array[Enemy] = []
## Target instance id -> AttackRing
static var _rings: Dictionary = {}
## Attacker instance id -> target instance id of the ring it stands on.
static var _held: Dictionary = {}
## Where the chasing members stand this physics frame (read once per frame
## for everyone's push_for: no node is asked for its position n times),
## sorted into a grid of SEPARATION_RADIUS cells (cell -> Array of indices
## into _chasers): a push looks at the nine cells round its own only.
static var _snapshot_frame: int = -1
static var _chasers := PackedVector3Array()
static var _chaser_ids := PackedInt64Array()
static var _cells: Dictionary = {}


static func join(enemy: Enemy) -> void:
	if not _members.has(enemy):
		_members.append(enemy)


static func leave(enemy: Enemy) -> void:
	_members.erase(enemy)
	release(enemy)


static func member_count() -> int:
	return _members.size()


## Where [param enemy] should head for when chasing [param target]: a ring
## place when it fights in melee, is close, sees the target
## ([param sees]) and stands on its floor; else the target itself.
static func chase_goal(enemy: Enemy, target: Node3D, melee: bool, attack_range: float, sees: bool = true) -> Vector3:
	var goal := target.global_position
	var offset := enemy.global_position - goal
	var other_floor := absf(offset.y) > SAME_FLOOR
	offset.y = 0.0
	var distance := offset.length()
	if not melee or not sees or other_floor or distance > DISENGAGE_RANGE or (distance > ENGAGE_RANGE and not _holds_place(enemy, target)):
		release(enemy)
		return goal
	var key := target.get_instance_id()
	if not _rings.has(key):
		_rings[key] = AttackRing.new()
	var ring: AttackRing = _rings[key]
	var bearing := atan2(offset.z, offset.x) if distance > 0.01 else 0.0
	var place := ring.claim(enemy.get_instance_id(), bearing)
	if place >= 0:
		_held[enemy.get_instance_id()] = key
	var radius := attack_range * RING_FRACTION
	if place < 0:
		var away := offset / distance if distance > 0.01 else Vector3.RIGHT
		return goal + away * (radius + WAIT_MARGIN)
	var slot_angle := AttackRing.angle(place)
	return goal + Vector3(cos(slot_angle), 0.0, sin(slot_angle)) * radius


## Gives up [param enemy]'s ring place (cheap when it holds none: called
## every frame for most chasers).
static func release(enemy: Enemy) -> void:
	var who := enemy.get_instance_id()
	if not _held.has(who):
		return
	var key: int = _held[who]
	_held.erase(who)
	var ring: AttackRing = _rings.get(key)
	if ring == null:
		return
	ring.release(who)
	if ring.is_empty():
		_rings.erase(key)


static func _holds_place(enemy: Enemy, target: Node3D) -> bool:
	return _held.get(enemy.get_instance_id(), 0) == target.get_instance_id()


## Push (m/s) away from nearby chasing members on the same floor (dormant
## exhibits stand where they were put and push nobody). The others'
## positions are those of the start of this physics frame (see
## [method chasers]).
static func push_for(enemy: Enemy) -> Vector3:
	chasers()
	var others: Array[Vector3] = []
	var here := enemy.global_position
	var me := enemy.get_instance_id()
	var home := _cell(here)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var bucket: Variant = _cells.get(home + Vector2i(dx, dz))
			if bucket == null:
				continue
			for i: int in bucket:
				if _chaser_ids[i] == me:
					continue
				var there := _chasers[i]
				if absf(there.y - here.y) < SAME_FLOOR and absf(there.x - here.x) < SEPARATION_RADIUS and absf(there.z - here.z) < SEPARATION_RADIUS:
					others.append(there)
	return separation(here, others) * SEPARATION_SPEED


## Where every chasing (or attacking) member stands, taken once per
## physics frame and shared by all of them.
static func chasers() -> PackedVector3Array:
	var frame := Engine.get_physics_frames()
	if frame == _snapshot_frame:
		return _chasers
	_snapshot_frame = frame
	_chasers.clear()
	_chaser_ids.clear()
	_cells.clear()
	for other in _members:
		# (the sleepers, most of a floor, are passed over first and cheaply)
		if not is_instance_valid(other) or other.brain.state == EnemyBrain.State.DORMANT or not other.is_inside_tree():
			continue
		if not other.brain.is_active():
			continue
		var at := other.global_position
		var cell := _cell(at)
		var bucket: Array = _cells.get(cell, [])
		if bucket.is_empty():
			_cells[cell] = bucket
		bucket.append(_chasers.size())
		_chasers.append(at)
		_chaser_ids.append(other.get_instance_id())
	return _chasers


static func _cell(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x / SEPARATION_RADIUS), floori(at.z / SEPARATION_RADIUS))


## Sum of pushes away from [param others] (flat), each growing from 0 at
## SEPARATION_RADIUS to 1 when touching; capped at length 1.
static func separation(here: Vector3, others: Array[Vector3]) -> Vector3:
	var push := Vector3.ZERO
	for there in others:
		var away := here - there
		away.y = 0.0
		var distance := away.length()
		# exact overlaps are left to the physics bodies
		if distance >= SEPARATION_RADIUS or distance < 0.001:
			continue
		push += away / distance * (1.0 - distance / SEPARATION_RADIUS)
	return push.limit_length(1.0)
