class_name GuardianKeeper
extends Node3D
## The wing guardians of Floor I in the game (design 7.4): every guardian
## not yet defeated stands on its marker (the real one - its script in
## [member registry], else src/game/floor1/guardians/<id>.gd when there is
## one - else a GuardianStub), with its arena = the marker's room; a real
## guardian's script may dress its arena every night, also after its fall
## (static dress_arena(level, parent) -> Array[Node3D]: the Colossus's
## throne and breakable columns); it wakes once the guard crosses the arena's start line
## (marker arena_<guardian>_start, when the zone has one). When it wakes,
## the arena's doors slam shut (markers arena_<guardian>_door_<n>: the Door
## within ARENA_DOOR_REACH m of each, or an ArenaGrille dropping into the
## doorway there when it has no door) and its phase supplies appear (once a
## night per phase; on the arena_<guardian>_supply_<n> markers when there
## are some, else round its post); when the guard
## flees it calms down and the doors open; when it falls it is recorded
## for good (GameState.defeat_guardian, saved), its seal and shard drop
## where it stood (ProgressPickup; on the arena_<guardian>_reward marker
## when the zone has one), its Dust bursts out and the doors open.
## A seal or shard not taken yet waits in the arena on later nights.
## Each guardian gets its arena's named points (markers <id>_<name>_<n>:
## Guardian.points); a phase may call exhibits out of them (PHASE_CALLS:
## the relief warriors stepping off the Lamassu's walls in phase 2).

## Guardian id -> Script of the real guardian (extends Guardian); comes
## before GUARDIAN_PATH (tests force a stand-in here).
static var registry: Dictionary = {}

## Where the real guardian of a wing lives (by its id).
const GUARDIAN_PATH := "res://src/game/floor1/guardians/%s.gd"

const ARENA_DOOR_REACH := 3.0
## RunState.used id of a guardian's phase supplies: "gsupply_<id>_<phase>".
const SUPPLY_PREFIX := "gsupply_"
## Ammo and a medkit round the post at each phase (offsets from the post).
const SUPPLIES := {
	1: [[&"bullets", Vector3(5.0, 0.0, 3.0)], [&"shells", Vector3(-5.0, 0.0, 3.0)]],
	2: [[&"medkit", Vector3(6.0, 0.0, -2.0)], [&"bullets", Vector3(-6.0, 0.0, -2.0)]],
	3: [[&"medkit", Vector3(-4.0, 0.0, 6.0)], [&"shells", Vector3(4.0, 0.0, 6.0)]],
}

## Point name -> [phase, exhibit kind]: in that phase, one awake exhibit of
## that kind steps out at each of the guardian's points of that name (once
## a night).
const PHASE_CALLS := {&"relief": [2, &"relief_warrior"]}
## RunState.used id of a phase's call: "gcall_<id>_<phase>".
const CALL_PREFIX := "gcall_"
## Called exhibits leave this much Dust.
const CALLED_DUST := 1
## Haven id -> the guardian that keeps it shut: the haven neither heals nor
## saves until that guardian has fallen (the tea house off the General's
## garden, design 4.5).
const HAVEN_GUARDS := {&"teahouse": &"general"}

var museum: Museum
var level: MuseumFloorLevel
var game: PersistentState
var run: NightState
## Guardian id -> Guardian standing tonight.
var guardians: Dictionary = {}
## Arena id -> Doors its fight shut and grilles it dropped.
var sealed: Dictionary = {}
## Marker id -> ArenaGrille built for it (kept for the night).
var grilles: Dictionary = {}
## Guardian id -> the props its script dressed the arena with.
var arena_props: Dictionary = {}

var _supplies: Node3D
var _arenas: Node3D


func setup(for_museum: Museum) -> void:
	museum = for_museum
	level = museum.floor_level
	game = museum.game
	run = museum.run
	name = "Guardians"
	_supplies = Node3D.new()
	_supplies.name = "Supplies"
	add_child(_supplies)
	_arenas = Node3D.new()
	_arenas.name = "Arenas"
	add_child(_arenas)
	for plan in Floor1Plan.guardians():
		if not level.markers.has(plan.marker):
			FloorGame.warn_once("GuardianKeeper: no marker %s for the guardian %s" % [plan.marker, plan.id])
			continue
		_dress_arena(plan)
		if game.is_guardian_defeated(plan.id):
			_drop_rewards(plan, reward_spot(plan, (level.markers[plan.marker] as Transform3D).origin), false)
			continue
		_place(plan)


## The real guardian's script for [param guardian_id] (the registry's, else
## its file in GUARDIAN_PATH), or null (a GuardianStub stands in).
static func script_for(guardian_id: StringName) -> Script:
	var registered: Script = registry.get(guardian_id)
	if registered != null:
		return registered
	var path := GUARDIAN_PATH % String(guardian_id)
	return load(path) as Script if ResourceLoader.exists(path) else null


static func make_guardian(plan: Floor1Plan.GuardianPlan) -> Guardian:
	var script := script_for(plan.id)
	var guardian: Guardian = script.new() if script != null else GuardianStub.new()
	guardian.plan = plan
	guardian.guardian_id = plan.id
	guardian.name = "Guardian_" + String(plan.id)
	return guardian


## True while any guardian fights (no rest in a haven meanwhile).
func fighting() -> bool:
	for guardian: Guardian in guardians.values():
		if is_instance_valid(guardian) and guardian.is_fighting():
			return true
	return false


## Dawn: every guardian still standing turns to stone.
func freeze() -> void:
	for guardian: Guardian in guardians.values():
		if is_instance_valid(guardian):
			guardian.freeze()


## The Doors of [param plan]'s arena markers (arena_<id>_door_<n>).
func arena_doors(plan: Floor1Plan.GuardianPlan) -> Array[Door]:
	var found: Array[Door] = []
	for id in _door_markers(plan.id):
		var best := _door_near(id)
		if best != null and not found.has(best):
			found.append(best)
	return found


## Shuts arena [param arena_id] (a guardian's id, or &"trex"): its door
## markers' Doors lock, the doorways without one get a grille. Returns how
## many it shut.
func seal_arena(arena_id: StringName) -> int:
	var shut: Array = []
	for id in _door_markers(arena_id):
		var door := _door_near(id)
		if door != null:
			if door.locked or shut.has(door):
				continue
			door.lock()
			shut.append(door)
			Sfx.play_at(&"door_slam", door.global_position + Vector3.UP * 2.0)
			continue
		var grille := _grille_for(id)
		if grille != null:
			grille.drop()
			shut.append(grille)
	sealed[arena_id] = shut
	return shut.size()


## Opens what seal_arena() shut.
func unseal_arena(arena_id: StringName) -> void:
	for node: Variant in sealed.get(arena_id, []):
		if node is Door and is_instance_valid(node):
			(node as Door).unlock()
			(node as Door).open()
		elif node is ArenaGrille and is_instance_valid(node):
			(node as ArenaGrille).lift()
	sealed.erase(arena_id)


func _door_markers(arena_id: StringName) -> Array[StringName]:
	var prefix := "arena_%s_door_" % String(arena_id)
	var ids: Array[StringName] = []
	for id: StringName in level.markers:
		if String(id).begins_with(prefix):
			ids.append(id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a).naturalnocasecmp_to(String(b)) < 0)
	return ids


## The Door (not a gate's) within ARENA_DOOR_REACH m of marker [param id].
func _door_near(id: StringName) -> Door:
	var at: Vector3 = (level.markers[id] as Transform3D).origin
	var best: Door = null
	var best_distance := ARENA_DOOR_REACH
	for door: Door in level.doors.values():
		var distance := door.global_position.distance_to(at)
		if distance < best_distance and level.layout.gate_of_opening(door.id) == null:
			best_distance = distance
			best = door
	return best


## The grille for door marker [param id]: as wide and high as the doorway
## it stands in (null when no opening is near).
func _grille_for(id: StringName) -> ArenaGrille:
	if grilles.has(id):
		return grilles[id]
	var at: Transform3D = level.markers[id]
	var best: OpeningSpec = null
	var best_distance := ARENA_DOOR_REACH
	for passage in level.layout.openings:
		var distance := passage.center().distance_to(at.origin)
		if distance < best_distance:
			best_distance = distance
			best = passage
	if best == null:
		FloorGame.warn_once("GuardianKeeper: no doorway at %s for a grille" % id)
		return null
	var grille := ArenaGrille.make(at, Vector2(best.width(), best.height()))
	grille.name = "Grille_" + String(id)
	add_child(grille)
	grilles[id] = grille
	return grille


static func supplies_id(guardian_id: StringName, phase: int) -> StringName:
	return StringName("%s%s_%d" % [SUPPLY_PREFIX, String(guardian_id), phase])


func _place(plan: Floor1Plan.GuardianPlan) -> void:
	var guardian := make_guardian(plan)
	guardian.transform = level.markers[plan.marker]
	guardian.arena_room = level.layout.marker_rooms.get(plan.marker, &"")
	guardian.room_of = level.room_at
	guardian.target = museum.player
	var start := StringName("arena_%s_start" % String(plan.id))
	if level.markers.has(start):
		guardian.wake_point = (level.markers[start] as Transform3D).origin
	guardian.points = guardian_points(plan.id)
	DifficultyRules.tune_guardian(guardian, game.difficulty)
	add_child(guardian)
	guardians[plan.id] = guardian
	guardian.awakened.connect(_on_awakened.bind(plan))
	guardian.phase_changed.connect(_on_phase.bind(plan))
	guardian.calmed.connect(_open_arena.bind(plan))
	guardian.defeated.connect(_on_defeated.bind(plan, guardian))


func _on_awakened(plan: Floor1Plan.GuardianPlan) -> void:
	if seal_arena(plan.id) > 0:
		museum.hud.show_toast(tr("HUD_ARENA_SEALED"))


func _open_arena(plan: Floor1Plan.GuardianPlan) -> void:
	unseal_arena(plan.id)


## The named points of [param guardian_id]'s arena: its markers
## <id>_<name>_<n> (or <id>_<name>) as name -> Array of Transform3D, in the
## numbers' order (not its own guardian_ and arena_ markers).
func guardian_points(guardian_id: StringName) -> Dictionary:
	var prefix := String(guardian_id) + "_"
	var found := {}
	var ids: Array = level.markers.keys().filter(func(id: StringName) -> bool: return String(id).begins_with(prefix))
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a).naturalnocasecmp_to(String(b)) < 0)
	for id: StringName in ids:
		var stem := String(id).substr(prefix.length())
		var cut := stem.rfind("_")
		if cut > 0 and stem.substr(cut + 1).is_valid_int():
			stem = stem.substr(0, cut)
		var point_name := StringName(stem)
		if not found.has(point_name):
			found[point_name] = []
		(found[point_name] as Array).append(level.markers[id])
	return found


## The exhibits [param guardian] calls in [param phase] (PHASE_CALLS), once
## a night; returns them.
func call_exhibits(guardian: Guardian, phase: int) -> Array[Enemy]:
	var called: Array[Enemy] = []
	var key := StringName("%s%s_%d" % [CALL_PREFIX, String(guardian.guardian_id), phase])
	if run.is_used(key):
		return called
	for point_name: StringName in PHASE_CALLS:
		var entry: Array = PHASE_CALLS[point_name]
		if int(entry[0]) != phase or not guardian.points.has(point_name):
			continue
		run.mark_used(key)
		for at: Transform3D in guardian.points[point_name]:
			var exhibit := NightSpawner.make(entry[1])
			exhibit.position = at.origin - at.basis.z * 0.6 + Vector3.UP * 0.05
			exhibit.rotation.y = at.basis.get_euler().y
			exhibit.target = museum.player
			exhibit.dust_value = CALLED_DUST
			exhibit.summoned = true
			museum._tune_exhibit(exhibit)
			museum.enemies_root.add_child(exhibit)
			exhibit.brain.wake()
			Fx.impact(at.origin + Vector3.UP * 1.2, -at.basis.z, ExhibitMaterial.Kind.MARBLE, 1.5)
			called.append(exhibit)
	return called


## Phase [param phase]'s supplies round the post, once a night.
func _on_phase(phase: int, plan: Floor1Plan.GuardianPlan) -> void:
	var guardian: Guardian = guardians.get(plan.id)
	if guardian != null:
		call_exhibits(guardian, phase)
	if not level.markers.has(plan.marker):
		return
	var post: Transform3D = level.markers[plan.marker]
	var spots := supply_spots(plan.id)
	if spots.is_empty():
		drop_supplies_at(supplies_id(plan.id, phase), post.origin, phase, level.layout.marker_rooms.get(plan.marker, &""))
	else:
		drop_supplies_on(supplies_id(plan.id, phase), spots, phase)


## The arena's supply spots (arena_<id>_supply_<n> markers, in order).
func supply_spots(guardian_id: StringName) -> Array[Vector3]:
	var prefix := "arena_%s_supply_" % String(guardian_id)
	var ids: Array = level.markers.keys().filter(func(id: StringName) -> bool: return String(id).begins_with(prefix))
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a).naturalnocasecmp_to(String(b)) < 0)
	var spots: Array[Vector3] = []
	for id: StringName in ids:
		spots.append((level.markers[id] as Transform3D).origin)
	return spots


## The supplies of [param phase] on the arena's [param spots] (taking turns
## from phase to phase), once a night for [param key].
func drop_supplies_on(key: StringName, spots: Array[Vector3], phase: int) -> void:
	if run.is_used(key) or spots.is_empty():
		return
	run.mark_used(key)
	var entries: Array = SUPPLIES.get(phase, [])
	for i in entries.size():
		var at := spots[((phase - 1) * entries.size() + i) % spots.size()]
		_supply((entries[i] as Array)[0], at + Vector3(0.6 * i, 0.0, 0.0))


## The supplies of [param phase] round [param center] (in [param arena]
## when given), once a night for [param key] (RunState.used).
func drop_supplies_at(key: StringName, center: Vector3, phase: int, arena: StringName = &"") -> void:
	if run.is_used(key):
		return
	run.mark_used(key)
	for entry: Array in SUPPLIES.get(phase, []):
		var at: Vector3 = center + (entry[1] as Vector3)
		if arena != &"" and level.room_at(at + Vector3.UP * 0.5) != arena:
			at = center + (at - center) * 0.4   # a small arena: closer in
		_supply(entry[0], at)


func _supply(wanted: StringName, at: Vector3) -> void:
	var item := museum.supply_for_guard(wanted)
	var pickup := Pickup.new()
	pickup.type = Museum.LOOT_TYPES[item]
	pickup.amount = Museum.LOOT_AMOUNTS[item]
	pickup.respawn_time = 0.0
	pickup.position = at + Vector3.UP * 0.35
	_supplies.add_child(pickup)
	Fx.flash(pickup.position, Color(1.0, 0.85, 0.5), 2.0, 3.0, 0.4)


## Where [param plan]'s seal and shard lie: its arena's reward marker, or
## [param fallback].
func reward_spot(plan: Floor1Plan.GuardianPlan, fallback: Vector3) -> Vector3:
	var marker := StringName("arena_%s_reward" % String(plan.id))
	if level.markers.has(marker):
		return (level.markers[marker] as Transform3D).origin
	return fallback


## The props [param plan]'s guardian script puts in its arena (every night).
func _dress_arena(plan: Floor1Plan.GuardianPlan) -> void:
	var script := script_for(plan.id)
	if script == null or not script.has_method(&"dress_arena"):
		return
	var dressed: Variant = script.call(&"dress_arena", level, _arenas)
	arena_props[plan.id] = dressed if dressed is Array else []


func _on_defeated(plan: Floor1Plan.GuardianPlan, guardian: Guardian) -> void:
	var at := guardian.global_position
	var reward := reward_spot(plan, guardian.reward_point())
	guardians.erase(plan.id)
	_open_arena(plan)
	if museum.night_over() or not run.running:
		return   # a fall after dawn or death changes nothing
	game.defeat_guardian(plan.id)
	if museum.dust_dropper != null and guardian.dust_value > 0:
		museum.dust_dropper.drop(at + Vector3.UP * 1.5, run.scaled_dust(guardian.dust_value), DustRules.BOSS_MOTES)
	_drop_rewards(plan, reward, true)
	NightRules.save_progress(game, run)
	museum.hud.show_card(tr(plan.name_key), tr("GUARDIAN_DEFEATED"), tr(plan.title_key))


## The seal and the shard of [param plan] at [param at] (those not taken).
func _drop_rewards(plan: Floor1Plan.GuardianPlan, at: Vector3, fresh: bool) -> void:
	var floor_at := Vector3(at.x, at.y, at.z)
	if plan.seal != &"" and not game.seals.has(plan.seal):
		_reward(ProgressPickup.Kind.SEAL, plan.seal, floor_at + Vector3(-0.8, 0.0, 0.0), fresh)
	if plan.shard != &"" and not game.shards.has(plan.shard):
		_reward(ProgressPickup.Kind.SHARD, plan.shard, floor_at + Vector3(0.8, 0.0, 0.0), fresh)


func _reward(kind: ProgressPickup.Kind, id: StringName, at: Vector3, fresh: bool) -> void:
	var pickup := ProgressPickup.make(kind, id, at)
	pickup.game = game
	pickup.run = run
	add_child(pickup)
	pickup.taken.connect(_on_reward_taken)
	if fresh:
		Fx.flash(at + Vector3.UP, ProgressPickup.COLORS[kind], 4.0, 6.0, 0.6)


func _on_reward_taken(kind: ProgressPickup.Kind, id: StringName) -> void:
	museum.hud.show_toast(ProgressPickup.name_of(kind, id))


## True while haven [param haven_id] is kept by a guardian still standing.
func haven_guarded(haven_id: StringName) -> bool:
	var keeper_id: StringName = HAVEN_GUARDS.get(haven_id, &"")
	return keeper_id != &"" and game != null and not game.is_guardian_defeated(keeper_id)
