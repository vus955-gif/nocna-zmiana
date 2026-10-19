class_name TotemFaces
extends RefCounted
## The totem's pure logic (design pietro-1-projekt 5.6): a pole of 3-5
## carved faces, each a turret. The faces are its health (FACE_HEALTH
## apiece): the top one takes full damage, a lower one or the stump only
## LOWER_FACTOR of it ("dead wood"), so it is shot off from the top; every
## FACE_HEALTH of damage the top block falls. The fewer faces, the faster it
## spits (interval()). Which face shoots: the one aimed closest at the guard
## within FIRE_ARC_DEG with a clear line from its mouth (pick_face()). The
## model stacks block_1..5 at BLOCK_BASE + BLOCK_HEIGHT * (k - 1) (kit
## docs/art/kit-pietro1-ameryki.md 8).

const FACE_HEALTH := 30.0
const DUST_PER_FACE := 3
const LOWER_FACTOR := 0.35
const FIRE_ARC_DEG := 20.0
const BLOCK_BASE := 0.35
const BLOCK_HEIGHT := 0.85
const MIN_FACES := 3
const MAX_FACES := 5
## Seconds between shots with one face / with five (linear between).
const INTERVAL_ONE := 0.8
const INTERVAL_FIVE := 2.0
## Turn rate (rad/s) of the lowest face / the fifth (higher turns faster).
const TURN_LOW := 0.9
const TURN_HIGH := 1.5
## The face markers' heights in the model (face_1..5), for the greybox and
## for sight from the top face.
const FACE_HEIGHTS: Array[float] = [0.87, 1.79, 2.59, 3.41, 4.31]


## How many faces [param health] still holds up ([param face_health] each).
static func faces_left(health: float, face_health: float = FACE_HEALTH) -> int:
	if health <= 0.0:
		return 0
	return ceili(health / maxf(face_health, 0.001))


## Health of a totem of [param faces] faces.
static func health_for(faces: int) -> float:
	return FACE_HEALTH * faces


## Dust a totem of [param faces] faces leaves.
static func dust_for(faces: int) -> int:
	return DUST_PER_FACE * faces


## Seconds between shots with [param faces] faces left: 5 -> 2.0 ... 1 -> 0.8.
static func interval(faces: int) -> float:
	var share := clampf((faces - 1) / 4.0, 0.0, 1.0)
	return lerpf(INTERVAL_ONE, INTERVAL_FIVE, share)


## Which block a hit [param height] metres up the pole lands on: 0 the
## stump, 1..5 the faces, 6 above the fifth (the hat).
static func block_at(height: float) -> int:
	if height < BLOCK_BASE:
		return 0
	return mini(int((height - BLOCK_BASE) / BLOCK_HEIGHT) + 1, MAX_FACES + 1)


## Damage multiplier of a hit on [param block] while [param top] is the
## highest face left: full on the top face and anything above it, dead
## wood below.
static func hit_factor(block: int, top: int) -> float:
	return 1.0 if block >= top else LOWER_FACTOR


## How many faces the totem at [param point] has: 3-5, fixed for the place
## (its metre cell: the spawner's 5 cm lift off the slot changes nothing).
static func count_for(point: Vector3) -> int:
	var cell := Vector3i(point.floor())
	var h := (cell.x * 73856093) ^ (cell.y * 19349663) ^ (cell.z * 83492791)
	return MIN_FACES + posmod(h, MAX_FACES - MIN_FACES + 1)


## How fast face [param block] (1..5) turns (rad/s): higher turns faster.
static func turn_rate(block: int) -> float:
	var share := clampf((block - 1) / 4.0, 0.0, 1.0)
	return lerpf(TURN_LOW, TURN_HIGH, share)


## The face (1..[param top]) that shoots now: the one whose yaw
## ([param yaws], index k - 1) lies closest to [param guard_yaw] within
## FIRE_ARC_DEG and whose line is clear ([param clear] called with the face
## number); aimed alike, the higher face shoots (the one the guard is
## shooting at); -1 when no face is aimed.
static func pick_face(yaws: PackedFloat32Array, top: int, guard_yaw: float, clear: Callable) -> int:
	var best := -1
	var best_off := INF
	var arc := deg_to_rad(FIRE_ARC_DEG)
	for face in range(mini(top, yaws.size()), 0, -1):
		var off := absf(angle_difference(yaws[face - 1], guard_yaw))
		if off > arc or off >= best_off - 0.001:
			continue
		if not clear.call(face):
			continue
		best = face
		best_off = off
	return best


## Height of face [param block]'s marker in the model (the stump's top
## for 0).
static func face_height(block: int) -> float:
	if block < 1:
		return BLOCK_BASE
	return FACE_HEIGHTS[mini(block, MAX_FACES) - 1]


## Height of the top of block [param block] (where the hat sits with that
## many faces left).
static func top_of(block: int) -> float:
	return BLOCK_BASE + BLOCK_HEIGHT * block
