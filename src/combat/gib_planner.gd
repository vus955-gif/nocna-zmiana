class_name GibPlanner
## Decides how a destroyed exhibit falls apart. A plain kill makes it crumble
## into a few big pieces; heavy overkill (or a fist finisher) tears it into
## many small, fast ones. Armour always sheds a couple of extra plates; a
## skeleton scatters into many little bones, a portrait into splinters, a
## mummy into rags of bandage, carved wood into splinters.
## The weight of the killing blow ([param force] of plan(), HitFeel; plan
## 2026-10-19-gun-feel) changes how: a light weapon's kill crumbles (slow
## pieces that drop by the body), a heavy one's tears it apart sooner and
## throws the pieces back along the shot.

const GIB_RATIO := 0.5
const MAX_IMPULSE := 10.0
const MAX_CHUNKS := 13
## With a force: the overkill share that tears it apart is GIB_RATIO times
## GIB_SCALE.x (lightest) .. GIB_SCALE.y (heaviest); the pieces' speed is
## scaled by IMPULSE_SCALE, their share of the shot's direction by PUSH,
## of upward throw by LIFT and of outward scatter by SPREAD.
const GIB_SCALE := Vector2(1.3, 0.35)
const IMPULSE_SCALE := Vector2(0.6, 1.6)
const PUSH := Vector2(0.3, 1.5)
const LIFT := Vector2(0.35, 0.9)
const SPREAD := Vector2(0.55, 0.75)


class Plan:
	var gibbed: bool = false
	var chunks: int = 3
	var chunk_size: float = 0.35
	var impulse: float = 2.0
	var particles: int = 24
	## How the pieces fly: share of the hit's direction, of upward throw,
	## of outward scatter (ExhibitRig.shatter, Fx.shatter).
	var push: float = 0.9
	var lift: float = 0.85
	var spread: float = 0.7


## [param overkill] = damage beyond the health that was left;
## [param force] = the killing blow's weight 0..1 (negative: not known,
## the plain plan).
static func plan(kind: ExhibitMaterial.Kind, overkill: float, max_health: float, finisher: bool, force: float = -1.0) -> Plan:
	var result := Plan.new()
	var ratio := maxf(overkill, 0.0) / maxf(max_health, 1.0)
	var weight := clampf(force, 0.0, 1.0)
	var threshold := GIB_RATIO * (lerpf(GIB_SCALE.x, GIB_SCALE.y, weight) if force >= 0.0 else 1.0)
	result.gibbed = finisher or ratio >= threshold
	if result.gibbed:
		result.chunks = 7 + mini(int(ratio * 2.0), 4)
		result.chunk_size = 0.22
		result.impulse = minf(5.0 + ratio * 2.5, MAX_IMPULSE)
		result.particles = 64
	else:
		result.chunks = 3
		result.chunk_size = 0.35
		result.impulse = 2.0 + ratio * 2.0
		result.particles = 24
	if kind == ExhibitMaterial.Kind.METAL:
		result.chunks += 2
	elif kind == ExhibitMaterial.Kind.BONE:
		result.chunks += 4
		result.chunk_size *= 0.45
	elif kind == ExhibitMaterial.Kind.CANVAS:
		result.chunks += 2
		result.chunk_size *= 0.6
	elif kind == ExhibitMaterial.Kind.LINEN:
		result.chunks += 3
		result.chunk_size *= 0.6
	elif kind == ExhibitMaterial.Kind.WOOD:
		result.chunks += 2   # splinters
		result.chunk_size *= 0.7
	result.chunks = mini(result.chunks, MAX_CHUNKS)
	if force >= 0.0:
		result.impulse = minf(result.impulse * lerpf(IMPULSE_SCALE.x, IMPULSE_SCALE.y, weight), MAX_IMPULSE)
		result.push = lerpf(PUSH.x, PUSH.y, weight)
		result.lift = lerpf(LIFT.x, LIFT.y, weight)
		result.spread = lerpf(SPREAD.x, SPREAD.y, weight)
	return result
