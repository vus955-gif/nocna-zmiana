class_name GibPlanner
## Decides how a destroyed exhibit falls apart. A plain kill makes it crumble
## into a few big pieces; heavy overkill (or a fist finisher) tears it into
## many small, fast ones. Armour always sheds a couple of extra plates; a
## skeleton scatters into many little bones, a portrait into splinters, a
## mummy into rags of bandage, carved wood into splinters.

const GIB_RATIO := 0.5
const MAX_IMPULSE := 10.0
const MAX_CHUNKS := 13


class Plan:
	var gibbed: bool = false
	var chunks: int = 3
	var chunk_size: float = 0.35
	var impulse: float = 2.0
	var particles: int = 24


## [param overkill] = damage beyond the health that was left.
static func plan(kind: ExhibitMaterial.Kind, overkill: float, max_health: float, finisher: bool) -> Plan:
	var result := Plan.new()
	var ratio := maxf(overkill, 0.0) / maxf(max_health, 1.0)
	result.gibbed = finisher or ratio >= GIB_RATIO
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
	return result
