class_name FloorEncounters
extends Node
## The encounters of Floor I beyond the night's draw (design 7.2):
## - patrols: an exhibit of a spawn slot naming a PatrolSpec walks its
##   route (Enemy.patrol_route, set by tune_from_layout() before it enters
##   the tree; a there-and-back route comes back the same way),
## - ambushes: sleeping exhibits of an AmbushSpec's slots wake together
##   when the guard walks into its area or takes the pickup at its marker
##   (the mummies round the shotgun); once a night (RunState.used
##   "ambush_<id>", so a resumed night does not spring it again). Mummies
##   of an ambush sleep in tombs (Mummy.entombed) and climb out of them.

const CHECK := 0.2
const USED_PREFIX := "ambush_"

var museum: Museum
var layout: LevelLayout
var run: NightState
## Ambushes still waiting tonight.
var waiting: Array[AmbushSpec] = []

var _left: float = 0.0


func setup(for_museum: Museum, pickups: FloorPickups) -> void:
	museum = for_museum
	layout = museum.floor_level.layout
	run = museum.run
	name = "Encounters"
	for ambush in layout.ambushes:
		if not run.is_used(used_id(ambush.id)):
			waiting.append(ambush)
	if pickups != null:
		pickups.taken.connect(_on_pickup_taken)


static func used_id(ambush_id: StringName) -> StringName:
	return StringName(USED_PREFIX + String(ambush_id))


## Sets [param exhibit]'s patrol route from its slot's PatrolSpec, and puts
## a mummy of an ambush's slot to sleep in a tomb (it climbs out when the
## ambush wakes it). Call before it enters the tree: NightSpawner's tune.
static func tune_from_layout(exhibit: Enemy, floor_layout: LevelLayout) -> void:
	if not exhibit.has_meta(NightSpawner.SLOT_META):
		return
	var index := int(exhibit.get_meta(NightSpawner.SLOT_META))
	if index < 0 or index >= floor_layout.spawn_slots.size():
		return
	var mummy := exhibit as Mummy
	if mummy != null:
		for ambush in floor_layout.ambushes:
			if ambush.slots.has(index):
				mummy.entombed = true
	var slot := floor_layout.spawn_slots[index]
	if slot.patrol == &"":
		return
	var patrol := floor_layout.patrol(slot.patrol)
	if patrol == null or patrol.points.size() < 2:
		FloorGame.warn_once("FloorEncounters: slot %d names no usable patrol %s" % [index, slot.patrol])
		return
	exhibit.patrol_route = route_of(patrol)


## The points an exhibit walks round and round: a loop as it is, a
## there-and-back route out and back again.
static func route_of(patrol: PatrolSpec) -> PackedVector3Array:
	var route := patrol.points.duplicate()
	if not patrol.loop:
		for i in range(patrol.points.size() - 2, 0, -1):
			route.append(patrol.points[i])
	return route


func _process(delta: float) -> void:
	_left -= delta
	if _left > 0.0 or waiting.is_empty():
		return
	_left = CHECK
	var guard := museum.player
	if not is_instance_valid(guard) or not guard.alive:
		return
	for ambush in waiting.duplicate():
		if ambush.trigger == AmbushSpec.Trigger.AREA and ambush.triggered_by(guard.global_position):
			spring(ambush)


## Wakes [param ambush]'s sleepers (once a night).
func spring(ambush: AmbushSpec) -> int:
	waiting.erase(ambush)
	run.mark_used(used_id(ambush.id))
	var woken := 0
	for exhibit in museum.exhibits():
		if not exhibit.has_meta(NightSpawner.SLOT_META) or not ambush.slots.has(int(exhibit.get_meta(NightSpawner.SLOT_META))):
			continue
		if exhibit.brain.state != EnemyBrain.State.DORMANT:
			continue
		exhibit.sound_asleep = 0.0
		exhibit.brain.wake()
		woken += 1
	return woken


func _on_pickup_taken(marker: StringName) -> void:
	for ambush in waiting.duplicate():
		if ambush.trigger == AmbushSpec.Trigger.PICKUP and ambush.marker == marker:
			spring(ambush)
