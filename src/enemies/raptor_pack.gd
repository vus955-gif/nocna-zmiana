class_name RaptorPack
## Raptors come in packs (design: 3-4 together). spawn() sets a pack down
## in a small circle, flank sides alternating (+1, -1, ...), so half of it
## goes for the guard's right and half for his left. summoner() makes a
## summon callback for the T-Rex roar (TRex.summon): with its chance a pack
## of raptors, otherwise the fallback (the wax figures of the boss arena).

const MIN_SIZE := 3
const MAX_SIZE := 4
## Pack members stand this far from the pack's centre.
const SPREAD := 1.2


## Spawns [param count] raptors around [param center] (world space) under
## [param parent], facing [param target]; awake ones are summoned: they
## hunt at once, no bounds.
static func spawn(parent: Node, center: Vector3, count: int, target: Node3D, awake: bool,
		rng: RandomNumberGenerator = null) -> Array[Raptor]:
	var pack: Array[Raptor] = []
	var pack_id := Raptor.new_pack_id()
	var space := parent as Node3D
	var to_local := space.global_transform.affine_inverse() if space != null and space.is_inside_tree() else Transform3D.IDENTITY
	for i in count:
		var raptor := Raptor.new()
		var angle := TAU * i / maxf(count, 1) + (rng.randf_range(-0.3, 0.3) if rng != null else 0.0)
		var at := center + Vector3(cos(angle), 0.0, sin(angle)) * (SPREAD if count > 1 else 0.0)
		raptor.position = to_local * at
		raptor.flank_side = 1.0 if i % 2 == 0 else -1.0
		raptor.pack_id = pack_id
		raptor.target = target
		raptor.summoned = awake
		parent.add_child(raptor)
		if target != null and target.is_inside_tree():
			raptor.face(target.global_position)
		if awake:
			raptor.brain.wake()
		pack.append(raptor)
	return pack


## A callback for TRex.summon: called with the number of exhibits wanted,
## it returns the exhibits it brought (Array). With [param chance] (0..1)
## a pack of raptors (count kept within 1..MAX_SIZE) runs in, awake, at a
## random one of [param spots]; otherwise [param fallback] answers (e.g.
## BossDev.summon_wax). Without a valid fallback it is always raptors.
static func summoner(parent: Node, spots: Array[Vector3], target: Node3D, fallback: Callable = Callable(),
		chance: float = 0.5, rng: RandomNumberGenerator = null) -> Callable:
	var roll := rng
	if roll == null:
		roll = RandomNumberGenerator.new()
		roll.randomize()
	return func(count: int) -> Array:
		var called: Array = []
		if count <= 0:
			return called
		if fallback.is_valid() and roll.randf() >= chance:
			var others: Variant = fallback.call(count)
			return others if others is Array else called
		var at: Vector3 = spots[roll.randi_range(0, spots.size() - 1)] if not spots.is_empty() else Vector3.ZERO
		Fx.impact(at + Vector3.UP, Vector3.UP, ExhibitMaterial.Kind.BONE, 2.0)
		called.append_array(spawn(parent, at, clampi(count, 1, MAX_SIZE), target, true, roll))
		return called
