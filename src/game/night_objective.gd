class_name NightObjective
extends Node3D
## The night's goal (design 7), step by step:
## FUSES   - one fuse in each wing (the drawn points), carried to the fuse
##           box by the grate (RunState.fuses_carried / fuses),
## PULSING - both in: a relay slams, the hall's lamps die (the red
##           emergency lamps stay), the grate lifts 0.4 m and jams, the
##           crystal in its drawn case starts to beat,
## FLIGHT  - the guard comes within 3 m: the case bursts, the crystal flies
##           through the doors to the hall (CrystalRoute), waiting for him,
## BOSS    - it lodges between the T-Rex's ribs: the boss wakes, the hall's
##           doors slam shut, supplies appear, the roar calls wax figures
##           or a raptor pack,
## DESCEND - the boss is dust: the doors open, the grate rolls aside, the
##           stairs lead down into the dark,
## DONE    - he walked into it: the demo ends ([signal demo_finished]).
## What a resumed night keeps (RunState.used): the fuses taken and put in;
## with both in, the night comes back with the power out and the crystal
## beating in its case (a fight left half-way starts over from there, but
## the supplies of the phases already reached do not come again). What the
## roar calls is worth SUMMONED_DUST only: a fight started over and over is
## no Dust farm. Once the night is over (dawn, death, leaving) its boss no
## longer counts.
## After the demo is won, a continued night is its epilogue: no boss, the
## grate open, the way down waiting.

signal stage_changed(stage: Stage)
signal demo_finished

enum Stage { FUSES, PULSING, FLIGHT, BOSS, DESCEND, DONE }

## The skeleton on its pedestal, side on to the south entrance (its model
## faces east: placement of the art integration).
const BOSS_START := Vector3(0.0, 1.25, -11.0)
const BOSS_YAW := -PI * 0.5
## Rooms whose lamps die when the power goes.
const DARK_ROOMS: Array[StringName] = [&"hall", &"balcony"]
## The doors that shut the hall for the fight.
const HALL_DOORS: Array[StringName] = [&"door_hall_gallery", &"door_hall_armory", &"door_hall_diorama"]
const POWER_CUT_DELAY := 0.6
const GRATE_DELAY := 2.5
## Ammo and a medkit in the hall when the fight starts, more at each phase.
const SUPPLIES := {
	1: [[&"bullets", Vector3(-12.0, 0.0, 19.0)], [&"bullets", Vector3(12.0, 0.0, 19.0)], [&"shells", Vector3(0.0, 0.0, 20.5)], [&"medkit", Vector3(-15.8, 0.0, -2.5)]],
	2: [[&"bullets", Vector3(15.8, 0.0, -2.5)], [&"medkit", Vector3(0.0, 6.0, -20.0)]],
	3: [[&"bullets", Vector3(-16.0, 6.0, -6.0)], [&"shells", Vector3(16.0, 6.0, -6.0)], [&"medkit", Vector3(-6.0, 0.0, 19.5)]],
}
## Summoned wax figures and raptors appear at least this far from the guard.
const SUMMON_DISTANCE := 8.0
## Dust of an exhibit the roar brings in (the night's own give their full value).
const SUMMONED_DUST := 1
## RunState.used id of the fight's supplies of a phase ("supplies_<phase>").
const SUPPLIES_PREFIX := "supplies_"
## Chance that a roar calls a raptor pack instead of wax figures (design 2.1).
const RAPTOR_CHANCE := 0.5
## Where a called pack runs in: the hall's corners, clear of the stairs, the
## booth and the pedestal.
const RAPTOR_SPOTS: Array[Vector3] = [Vector3(-11.0, 0.0, 19.5), Vector3(11.0, 0.0, 19.5), Vector3(-11.0, 0.0, -17.0), Vector3(11.0, 0.0, -17.0)]

var museum: Museum
var stage: Stage = Stage.FUSES
## Wing -> FusePickup still lying tonight.
var fuse_pickups: Dictionary = {}
var fuse_box: FuseBox
var crystal: CrystalRelic = null
var boss: TRex = null
var exit: UndercroftExit
## Doors this fight shut (opened again when it is won).
var sealed: Array[Door] = []
## Tuning for every exhibit the roar calls (tonight's stats).
var tune_exhibit: Callable = Callable()

var _supplies: Node3D


## Places the night's goal in [param for_museum]'s lobby and picks up
## where a resumed night was left.
func setup(for_museum: Museum) -> void:
	museum = for_museum
	name = "Objective"
	var run := museum.run
	var night := museum.night
	var markers := museum.lobby.markers
	_supplies = Node3D.new()
	_supplies.name = "Supplies"
	add_child(_supplies)
	# the fuses: taken ones are in the pocket (or already in the box)
	var taken := 0
	for wing: StringName in night.fuses:
		if run.is_used(fuse_id(wing)):
			taken += 1
			continue
		var pickup := FusePickup.new()
		pickup.name = "Fuse_" + String(wing)
		pickup.wing = wing
		pickup.transform = markers[night.fuses[wing]]
		pickup.taken.connect(_on_fuse_taken)
		add_child(pickup)
		fuse_pickups[wing] = pickup
	var inserted := 0
	for i in 2:
		if run.is_used(box_id(i + 1)):
			inserted += 1
	run.fuses = inserted
	run.fuses_carried = maxi(taken - inserted, 0)
	fuse_box = FuseBox.new()
	fuse_box.name = "FuseBox"
	fuse_box.run = run
	fuse_box.transform = markers[&"fuse_box"]
	fuse_box.fed.connect(_on_fuse_box_fed)
	fuse_box.refused.connect(_on_fuse_box_refused)
	add_child(fuse_box)
	fuse_box.set_inserted(inserted)
	exit = UndercroftExit.new()
	exit.name = "UndercroftExit"
	exit.position = (markers[&"undercroft_exit"] as Transform3D).origin
	exit.entered_by_guard.connect(_on_exit_entered)
	add_child(exit)
	if museum.game.demo_complete:
		_epilogue()
		return
	crystal = CrystalRelic.new()
	crystal.name = "Crystal"
	crystal.transform = markers[night.crystal_case]
	crystal.guard = museum.player
	crystal.case_glass = _case_glass(crystal.transform.origin)
	crystal.burst_out.connect(_on_crystal_burst)
	crystal.arrived.connect(_on_crystal_arrived)
	add_child(crystal)
	boss = TRex.new()
	boss.name = "TRex"
	boss.position = BOSS_START
	boss.rotation.y = BOSS_YAW
	boss.target = museum.player
	boss.summon = summon
	boss.phase_changed.connect(_on_boss_phase)
	boss.defeated.connect(_on_boss_defeated)
	add_child(boss)
	if inserted >= 2:
		_power_cut(true)
	else:
		_set_stage(Stage.FUSES)


static func fuse_id(wing: StringName) -> StringName:
	return StringName("fuse_%s" % String(wing))


static func box_id(slot: int) -> StringName:
	return StringName("fuse_box_%d" % slot)


static func supplies_id(phase: int) -> StringName:
	return StringName("%s%d" % [SUPPLIES_PREFIX, phase])


## The roar's call (TRex.summon, from phase 2): with RAPTOR_CHANCE a raptor
## pack, otherwise wax figures. (RaptorPack.summoner() does the same roll,
## but its raptors would miss tonight's tuning and could land next to the
## guard.)
func summon(count: int) -> Array[Enemy]:
	if count <= 0:
		return []
	if museum.run.rng.randf() < RAPTOR_CHANCE:
		var pack := summon_raptors(count)
		if not pack.is_empty():
			return pack
	return summon_wax(count)


## A pack (up to RaptorPack.MAX_SIZE, awake) runs in at one of the hall's
## free corners away from the guard (the farthest free one when none is far
## enough; none at all when every corner is taken).
func summon_raptors(count: int) -> Array[Enemy]:
	var guard := museum.player.global_position
	var free: Array[Vector3] = []
	for spot in RAPTOR_SPOTS:
		if not _occupied(spot, RaptorPack.SPREAD + 0.8):
			free.append(spot)
	if free.is_empty():
		return []
	var spots: Array[Vector3] = []
	var farthest := free[0]
	for spot in free:
		if spot.distance_to(guard) >= SUMMON_DISTANCE:
			spots.append(spot)
		if spot.distance_to(guard) > farthest.distance_to(guard):
			farthest = spot
	var at: Vector3 = spots[museum.run.rng.randi_range(0, spots.size() - 1)] if not spots.is_empty() else farthest
	var called: Array[Enemy] = []
	for raptor in NightSpawner.pack(at, 0.0, clampi(count, 1, RaptorPack.MAX_SIZE)):
		raptor.target = museum.player
		raptor.dust_value = SUMMONED_DUST
		raptor.summoned = true
		if tune_exhibit.is_valid():
			tune_exhibit.call(raptor)
		raptor.brain.wake()
		museum.enemies_root.add_child(raptor)
		raptor.face(guard)
		called.append(raptor)
	Fx.impact(at + Vector3.UP, Vector3.UP, ExhibitMaterial.Kind.BONE, 2.0)
	return called


## Wakes wax figures waiting in the hall, then brings new ones out on the
## hall's wax spots away from the guard.
func summon_wax(count: int) -> Array[Enemy]:
	var called: Array[Enemy] = []
	for node in museum.enemies_root.get_children():
		if called.size() >= count:
			break
		var exhibit := node as Enemy
		if exhibit is WaxFigure and exhibit.brain.state == EnemyBrain.State.DORMANT and museum.lobby.room_at(exhibit.global_position) == &"hall":
			exhibit.summoned = true
			exhibit.brain.relentless = true
			exhibit.brain.wake()
			called.append(exhibit)
	var spots: Array[Vector3] = []
	for slot in museum.level.spawn_slots:
		if slot.room == &"hall" and slot.kinds.has(&"wax") and slot.position.distance_to(museum.player.global_position) >= SUMMON_DISTANCE:
			spots.append(slot.position)
	spots.shuffle()
	for spot in spots:
		if called.size() >= count:
			break
		if _occupied(spot):
			continue
		var wax := WaxFigure.new()
		wax.position = spot + Vector3.UP * 0.05
		wax.target = museum.player
		wax.dust_value = SUMMONED_DUST
		wax.summoned = true
		if tune_exhibit.is_valid():
			tune_exhibit.call(wax)
		wax.brain.wake()
		museum.enemies_root.add_child(wax)
		wax.face(museum.player.global_position)
		Fx.impact(spot + Vector3.UP * 1.0, Vector3.UP, ExhibitMaterial.Kind.WAX, 1.5)
		called.append(wax)
	return called


## Something of the night's stands within [param radius] of [param spot].
func _occupied(spot: Vector3, radius: float = 1.2) -> bool:
	for node in museum.enemies_root.get_children():
		if (node as Node3D).global_position.distance_to(spot) < radius:
			return true
	return false


func _set_stage(next: Stage) -> void:
	stage = next
	_refresh_hud()
	stage_changed.emit(next)
	Events.objective_changed.emit(int(next))


func _refresh_hud() -> void:
	var run := museum.run
	var hud := museum.hud
	match stage:
		Stage.FUSES:
			var found := run.fuses + run.fuses_carried
			hud.set_objective(tr("NIGHT_OBJ_FUSES") % found if found < 2 else tr("NIGHT_OBJ_FUSE_BOX"))
			hud.set_fuses(run.fuses_carried, run.fuses, true)
		Stage.PULSING:
			hud.set_objective(tr("NIGHT_OBJ_PULSE"))
			hud.set_fuses(0, 2, false)
		Stage.FLIGHT:
			hud.set_objective(tr("NIGHT_OBJ_FOLLOW"))
		Stage.BOSS:
			hud.set_objective(tr("NIGHT_OBJ_BOSS"))
		Stage.DESCEND:
			hud.set_objective(tr("NIGHT_OBJ_DESCEND"))
			hud.set_fuses(0, 0, false)
		Stage.DONE:
			hud.set_objective("")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and museum != null and museum.hud != null:
		_refresh_hud()


func _on_fuse_taken(_by: Node, wing: StringName) -> void:
	var run := museum.run
	run.mark_used(fuse_id(wing))
	run.fuses_carried += 1
	fuse_pickups.erase(wing)
	museum.hud.show_toast(tr("HUD_FUSE_TAKEN") % (run.fuses + run.fuses_carried))
	_refresh_hud()


func _on_fuse_box_fed(_by: Node) -> void:
	var run := museum.run
	while run.fuses_carried > 0 and run.fuses < 2:
		run.fuses_carried -= 1
		run.fuses += 1
		run.mark_used(box_id(run.fuses))
	fuse_box.set_inserted(run.fuses)
	_refresh_hud()
	if run.fuses >= 2:
		_power_cut(false)
	else:
		museum.hud.show_toast(tr("HUD_FUSE_IN") % run.fuses)


func _on_fuse_box_refused(_by: Node) -> void:
	museum.hud.show_toast(tr("HUD_NO_FUSES"))


## Both fuses in: the relay, the hall goes dark, the grate jams, the
## crystal beats. [param resumed]: the night comes back like that at once.
func _power_cut(resumed: bool) -> void:
	var run := museum.run
	var grate: Door = museum.lobby.doors.get(&"grate")
	run.crystal_phase = NightState.CrystalPhase.PULSING
	_set_stage(Stage.PULSING)
	if resumed:
		NightModifiers.set_lights(museum.lobby, LightSpec.MAIN, false, DARK_ROOMS)
		if grate != null:
			grate.jam(true)
		crystal.start_pulsing()
		# no Events.power_cut: that is the moment the fuses go in; the music
		# reads the power being out from the PULSING stage announced above
		return
	Sfx.play_at(&"relay", fuse_box.global_position)
	Events.power_cut.emit()
	# the lamps stutter once, then die (on a blackout night they were dark
	# already: no lamp may light up for the stutter)
	var were_lit := museum.night.modifier != &"blackout"
	NightModifiers.set_lights(museum.lobby, LightSpec.MAIN, false, DARK_ROOMS)
	await _wait(0.12)
	if were_lit:
		NightModifiers.set_lights(museum.lobby, LightSpec.MAIN, true, DARK_ROOMS)
	await _wait(0.2)
	NightModifiers.set_lights(museum.lobby, LightSpec.MAIN, false, DARK_ROOMS)
	Events.shake_requested.emit(0.2)
	museum.hud.show_toast(tr("HUD_POWER_OUT"))
	await _wait(POWER_CUT_DELAY)
	if grate != null:
		Sfx.play_at(&"gate_jam", grate.global_position + Vector3.UP * 2.0)
		grate.jam()
	crystal.start_pulsing()
	NightRules.save_progress(museum.game, run)


func _on_crystal_burst() -> void:
	var lobby := museum.lobby
	var case_marker := museum.night.crystal_case
	var closed: Array[StringName] = []
	if museum.night.locked_door != &"":
		closed.append(museum.night.locked_door)
	var room := lobby.describe().room_of(case_marker)
	var socket := boss.skeleton.crystal_position()
	crystal.fly(CrystalRoute.build(lobby.layout, crystal.global_position, room, &"hall", socket, closed))
	museum.run.crystal_phase = NightState.CrystalPhase.FLYING
	_set_stage(Stage.FLIGHT)


func _on_crystal_arrived() -> void:
	var at := crystal.global_position
	crystal.queue_free()
	crystal = null
	Fx.flash(at, CrystalRelic.RED, 8.0, 14.0, 0.5)
	Events.shake_requested.emit(0.5)
	museum.run.crystal_phase = NightState.CrystalPhase.EMBEDDED
	boss.wake()
	_set_stage(Stage.BOSS)
	_seal_hall()
	_drop_supplies(1)


## The hall's doors slam shut for the fight (a door somebody stands in
## waits for him to move); the janitor's key opens none of them meanwhile.
func _seal_hall() -> void:
	var shut := false
	_hold_latches(true)
	for id in HALL_DOORS:
		var door: Door = museum.lobby.doors.get(id)
		if door == null or door.locked:
			continue
		door.lock()
		sealed.append(door)
		Sfx.play_at(&"door_slam", door.global_position + Vector3.UP * 2.0)
		shut = true
	if shut:
		museum.hud.show_toast(tr("HUD_HALL_SEALED"))


## The janitor's-key latches on the hall's doors (the night's locked door
## may be one of them) held for the fight, or let go again.
func _hold_latches(held: bool) -> void:
	var features := museum.features
	if features != null and is_instance_valid(features):
		features.hold_latches(HALL_DOORS, held)


## The supplies of [param phase], once a night (a fight started over after
## "Continue" does not bring them again), as ammo for guns the guard has.
func _drop_supplies(phase: int) -> void:
	if museum.run.is_used(supplies_id(phase)):
		return
	museum.run.mark_used(supplies_id(phase))
	for entry: Array in SUPPLIES.get(phase, []):
		var item := museum.supply_for_guard(entry[0])
		var pickup := Pickup.new()
		pickup.type = Museum.LOOT_TYPES[item]
		pickup.amount = Museum.LOOT_AMOUNTS[item]
		pickup.respawn_time = 0.0
		pickup.position = (entry[1] as Vector3) + Vector3.UP * 0.35
		_supplies.add_child(pickup)
		Fx.flash(pickup.position, Color(1.0, 0.85, 0.5), 2.0, 3.0, 0.4)


func supplies() -> Array[Node]:
	return _supplies.get_children()


func _on_boss_phase(phase: int) -> void:
	_drop_supplies(phase)


func _on_boss_defeated() -> void:
	var game := museum.game
	var run := museum.run
	# a skeleton that falls after dawn (a flare still burning in it) or after
	# the guard fell changes nothing: that night is over
	if museum.night_over() or not run.running:
		return
	game.stats["bosses"] = int(game.stats["bosses"]) + 1
	game.demo_complete = true
	run.crystal_phase = NightState.CrystalPhase.BROKEN
	NightRules.save_progress(game, run)
	_set_stage(Stage.DESCEND)
	for door in sealed:
		door.unlock()
		door.open()
	sealed.clear()
	_hold_latches(false)
	await _wait(GRATE_DELAY)
	_open_the_way()


## Waits [param seconds] of game time on a timer of this node (freed with
## it, so a sequence never resumes after the night is gone).
func _wait(seconds: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.start(seconds)
	await timer.timeout
	timer.queue_free()


## The grate rolls aside and the exit in the dark below is armed.
func _open_the_way() -> void:
	var grate: Door = museum.lobby.doors.get(&"grate")
	if grate != null and not grate.is_open:
		Sfx.play_at(&"gate_open", grate.global_position + Vector3.UP * 2.0)
		grate.open()
	museum.hud.show_toast(tr("HUD_GRATE_OPEN"))
	exit.armed = true


## A night after the demo was won: nothing to fight, the way down open.
func _epilogue() -> void:
	museum.run.crystal_phase = NightState.CrystalPhase.BROKEN
	var grate: Door = museum.lobby.doors.get(&"grate")
	if grate != null:
		grate.open(true)
	for wing: StringName in fuse_pickups:
		(fuse_pickups[wing] as Node).queue_free()
	fuse_pickups.clear()
	fuse_box.set_inserted(2)
	NightModifiers.set_lights(museum.lobby, LightSpec.MAIN, false, DARK_ROOMS)
	exit.armed = true
	_set_stage(Stage.DESCEND)


func _on_exit_entered(_player: Player) -> void:
	if stage != Stage.DESCEND:
		return
	_set_stage(Stage.DONE)
	demo_finished.emit()


## The see-through panes of the display case at [param at] (they burst).
func _case_glass(at: Vector3) -> Array[GeometryInstance3D]:
	var panes: Array[GeometryInstance3D] = []
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if node.get_meta(&"kit", &"") != &"crystal_case" or not museum.lobby.is_ancestor_of(node):
			continue
		var piece := node as Node3D
		if Vector2(piece.global_position.x - at.x, piece.global_position.z - at.z).length() > 0.8:
			continue
		for view in piece.find_children("*", "GeometryInstance3D", true, false):
			var material := (view as GeometryInstance3D).material_override as BaseMaterial3D
			if material != null and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				panes.append(view)
	return panes
