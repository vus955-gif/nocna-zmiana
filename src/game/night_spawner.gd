class_name NightSpawner
## Places the exhibits of a NightConfig on a level's spawn slots (the
## Museum and the lobby dev viewer). Each exhibit carries the index of its
## spawn slot in metadata SLOT_META: a resumed night leaves out the slots
## whose exhibit is gone already (RunState.killed_slots). Unknown kinds fall
## back to FALLBACK so encounter sets stay complete. Floor I slots list a
## stand-in kind first and the intended kind after it ([wax, mummy]):
## preferred() picks the intended one once it can be built. A raptor slot holds a
## whole pack (3-4, the same for the same night), every member with the
## slot's index and one pack id. Every exhibit belongs to its slot's room
## (Enemy.home_room); an awake slot's exhibit patrols a loop in that room
## (PerceptionRules.patrol_route; a pack keeps its post) instead of sleeping
## - or the route [param tune] gave it (Floor I's PatrolSpec).

const FALLBACK := &"wax"
## Meta key on each exhibit: the index of its slot in the level's spawn_slots.
const SLOT_META := &"spawn_slot"
## Kinds that come as a pack from one slot.
const PACK := &"raptor"
## A slot of flying books holds a whole flock (BookFlock: 4-6, the same
## for the same night), every book with the slot's index.
const FLOCK := &"books"
## Kinds make() builds (anything else falls back to FALLBACK).
const BUILDS: Array[StringName] = [&"wolf", &"knight", &"wax", &"bust", &"raptor", &"mummy", &"hoplite", &"scarabs",
		&"relief_warrior", &"relief_lion", &"books"]


## Creates, places and adds the exhibits under [param parent]. Awake ones
## patrol (they notice [param target], null = the node in group "player",
## by their senses like every exhibit). [param tune] (optional, called with each exhibit
## before it enters the tree) adjusts stats, e.g. the full moon's.
## Slots listed in [param skip] (slot indices) stay empty (destroyed
## earlier tonight); [param losses] (slot -> raptors lost) thins the packs
## a resumed night brings back.
static func spawn(config: NightConfig, slots: Array[SpawnSlot], parent: Node, target: Node3D = null, tune: Callable = Callable(), skip: Array[int] = [], losses: Dictionary = {}) -> Array[Enemy]:
	var placed: Array[Enemy] = []
	for entry in config.spawns:
		if entry.slot < 0 or entry.slot >= slots.size() or skip.has(entry.slot):
			continue
		var slot := slots[entry.slot]
		var members: Array[Enemy] = []
		if entry.kind == PACK or entry.kind == FLOCK:
			var left := group_size(config, entry.slot, entry.kind) - int(losses.get(entry.slot, 0))
			if left <= 0:
				continue
			members = pack(slot.position, slot.yaw, left) if entry.kind == PACK else BookFlock.make_members(slot.position, slot.yaw, left)
		else:
			var enemy := make(entry.kind)
			enemy.position = slot.position + Vector3.UP * 0.05
			enemy.rotation.y = slot.yaw
			members.append(enemy)
		for enemy in members:
			enemy.target = target
			enemy.home_room = slot.room
			enemy.set_meta(SLOT_META, entry.slot)
			if tune.is_valid():
				tune.call(enemy)
			if not entry.dormant:
				enemy.starts_awake = true
				if members.size() == 1 and enemy.patrol_route.is_empty():
					enemy.patrol_route = PerceptionRules.patrol_route(slot.position, slot.room, PerceptionWorld.room_at)
			parent.add_child(enemy)
			placed.append(enemy)
	return placed


static func make(kind: StringName) -> Enemy:
	match kind:
		&"wolf":
			return Wolf.new()
		&"knight":
			return Knight.new()
		&"wax":
			return WaxFigure.new()
		&"bust":
			return Bust.new()
		&"raptor":
			return Raptor.new()
		&"mummy":
			return Mummy.new()
		&"hoplite":
			return Hoplite.new()
		&"scarabs":
			return ScarabSwarm.new()
		&"relief_warrior":
			return ReliefWarrior.new()
		&"relief_lion":
			return ReliefLion.new()
		&"books":
			return FlyingBook.new()   # a lone book (spawn() brings a whole flock)
	return make(FALLBACK)


## True when make() builds [param kind] itself (no fallback).
static func builds(kind: StringName) -> bool:
	return BUILDS.has(kind)


## The kind a slot listing [param kinds] gets: a single kind is
## [param drawn] (the night's draw); a Floor I pair [stand-in, intended...]
## gives the last kind that can be built, so the intended exhibit replaces
## its stand-in as soon as it exists ([wax, mummy] -> mummy; [wolf, scarabs]
## -> scarabs; a kind still to come keeps its stand-in).
static func preferred(kinds: Array[StringName], drawn: StringName) -> StringName:
	if kinds.size() < 2:
		return drawn
	for i in range(kinds.size() - 1, -1, -1):
		if builds(kinds[i]):
			return kinds[i]
	return drawn


## How many exhibits [param config] places (a pack counts every raptor),
## leaving out the slots in [param skip] and the raptors in [param losses].
static func exhibit_count(config: NightConfig, skip: Array[int] = [], losses: Dictionary = {}) -> int:
	var count := 0
	for entry in config.spawns:
		if not skip.has(entry.slot):
			count += maxi(group_size(config, entry.slot, entry.kind) - int(losses.get(entry.slot, 0)), 0)
	return count


## How many exhibits one slot of [param kind] brings tonight: a raptor
## pack (pack_size), a flock of books (flock_size), else one.
static func group_size(config: NightConfig, slot: int, kind: StringName) -> int:
	if kind == PACK:
		return pack_size(config, slot)
	if kind == FLOCK:
		return flock_size(config, slot)
	return 1


## How many books the flock of [param slot] counts tonight: 4 to 6, from
## the night's seed (the same night always brings the same flocks).
static func flock_size(config: NightConfig, slot: int) -> int:
	var roll := RandomNumberGenerator.new()
	roll.seed = config.night_seed * 37 + config.night * 11 + slot
	return roll.randi_range(BookFlock.MIN_SIZE, BookFlock.MAX_SIZE)


## How many raptors the pack of [param slot] counts tonight: 3 or 4, from
## the night's seed (the same night always brings the same packs).
static func pack_size(config: NightConfig, slot: int) -> int:
	var roll := RandomNumberGenerator.new()
	roll.seed = config.night_seed * 31 + config.night * 7 + slot
	return roll.randi_range(RaptorPack.MIN_SIZE, RaptorPack.MAX_SIZE)


## A pack of [param count] raptors around [param center], not in the tree
## yet: in a small circle like RaptorPack.spawn(), flank sides alternating,
## so half of it goes for the guard's right and half for his left.
static func pack(center: Vector3, yaw: float, count: int) -> Array[Enemy]:
	var members: Array[Enemy] = []
	var pack_id := Raptor.new_pack_id()
	for i in count:
		var raptor := Raptor.new()
		raptor.pack_id = pack_id
		var angle := TAU * i / float(maxi(count, 1))
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * (RaptorPack.SPREAD if count > 1 else 0.0)
		raptor.position = center + offset + Vector3.UP * 0.05
		raptor.rotation.y = yaw
		raptor.flank_side = 1.0 if i % 2 == 0 else -1.0
		members.append(raptor)
	return members
