class_name BiomeMechanics
extends Node3D
## Each wing of Floor I plays its own way (backlog #26; plan
## docs/superpowers/plans/2026-10-21-mechaniki-biomow.md): one mechanic a
## wing, built from the devices' own placement data on the rooms of the
## layout (no zone file names them), installed by FloorGame with one call:
## [code]BiomeMechanics.install(floor_game)[/code] (tests: [method setup] on
## a bare MuseumFloorLevel).
## - Egypt: the tombs' curse plates fire dart slits (TombTrap),
## - Asia: temple bells lure the guardians and daze with their ring
##   (TempleBell),
## - the Americas: the fire bowls go out when shot and the totems see the
##   guard only in firelight (SacredFire, TotemSight),
## - Greece: the arc lamp's beam of daylight, sent on by bronze mirrors,
##   stiffens and burns the exhibits and lights the guard (HeliosLamp,
##   BronzeMirror),
## - the Enlightenment: the regulator's beat stops the exhibits in the
##   fight dead, then hastens them (Regulator),
## - Assyria: hunting nets under the ceilings, shot loose, entangle the
##   exhibits under them (HuntingNet),
## - the basement: cracked steam mains vent across the ring's corridors on
##   a cycle, wheels on the walls shut them (SteamVent),
## Nothing it builds stands on a floor (no collider changes the navmesh or
## the guard's walk): devices hang on walls and ceilings or lie flush in the
## floor, are shot through Hurtboxes and used through Interactables. No
## device serves a guardian's arena. At dawn (Events.dawn_broke) every
## device stops. What a device spends for the night is RunState.used.
## The first time ever the guard walks into a room where a wing's mechanic
## works, one short line tells him its rule (HINT_BIOME_<WING> on the HUD,
## GameState flag "hint_biome_<wing>").

## How far into the night's escalation we are, 0..1 (night-escalation sets
## it once merged; devices may read it to quicken their cycles).
var intensity: float = 0.0
var level: MuseumFloorLevel
var run: NightState
var hud: Hud = null
## -> Player (or null).
var guard_source: Callable
## Every device built.
var devices: Array[BiomeDevice] = []
## Dawn came.
var frozen: bool = false
## Whose flags remember the hints shown (GameState in the game).
var game: PersistentState = null
## Room id -> the wing whose mechanic works there (its hint).
var hint_rooms: Dictionary = {}

const HINT_TIME := 7.0
const HINT_CHECK := 0.5
const HINT_FLAG_PREFIX := "hint_biome_"

var _hint_left: float = 0.0

## The arenas of the guardians: no device serves them.
const ARENA_ROOMS: Array[StringName] = [&"egypt_colossus", &"assyria_courtyard", &"greece_parthenon",
		&"enlightenment_planetarium", &"asia_garden", &"americas_temple", &"court"]


## Builds the mechanics for [param floor_game]'s level and guard.
static func install(floor_game: FloorGame) -> BiomeMechanics:
	var biomes := BiomeMechanics.new()
	biomes.name = "BiomeMechanics"
	floor_game.add_child(biomes)
	var museum := floor_game.museum
	biomes.setup(floor_game.level, func() -> Player: return museum.player, museum.run, museum.hud)
	return biomes


## Builds every wing's devices on [param for_level] (built already).
func setup(for_level: MuseumFloorLevel, guard: Callable, night_run: NightState = null, for_hud: Hud = null) -> void:
	level = for_level
	guard_source = guard
	run = night_run if night_run != null else RunState
	hud = for_hud
	top_level = true
	TombTrap.build_all(self)
	TempleBell.build_all(self)
	SacredFire.build_all(self)
	HeliosLamp.build_all(self)
	Regulator.build_all(self)
	HuntingNet.build_all(self)
	SteamVent.build_all(self)
	if game == null:
		game = GameState
	_index_hints()
	if not Events.dawn_broke.is_connected(freeze):
		Events.dawn_broke.connect(freeze)


## The rooms whose wing's rule the guard learns there: every device's own
## room, and the regulator's whole wing.
func _index_hints() -> void:
	hint_rooms.clear()
	if layout() == null:
		return
	for device in devices:
		var rooms: Array = [device.room]
		if device is Regulator:
			rooms.append_array((device as Regulator).rooms.keys())
		for room_id: StringName in rooms:
			var room := layout().room(room_id)
			if room != null and not hint_rooms.has(room_id):
				hint_rooms[room_id] = room.zone


func _process(delta: float) -> void:
	if hud == null or frozen or game == null:
		return
	_hint_left -= delta
	if _hint_left > 0.0:
		return
	_hint_left = HINT_CHECK
	var player := guard()
	if player == null or not player.alive:
		return
	var wing: StringName = hint_rooms.get(room_at(player.global_position + Vector3.UP * 0.5), &"")
	if wing == &"":
		return
	var flag := StringName(HINT_FLAG_PREFIX + String(wing))
	if game.has_flag(flag):
		return
	game.set_flag(flag)
	hud.show_hint(tr(hint_key(wing)), HINT_TIME)


## The translation key of [param wing]'s rule.
static func hint_key(wing: StringName) -> String:
	return "HINT_BIOME_" + String(wing).to_upper()


## Adds [param device] (made by its class) under this node and to the
## devices.
func adopt(device: BiomeDevice, id: StringName, in_room: StringName) -> void:
	device.host = self
	device.device_id = id
	device.room = in_room
	device.name = String(id)
	add_child(device)
	devices.append(device)


## The devices of class [param kind] (a script, e.g. TombTrap).
func of_kind(kind: Script) -> Array[BiomeDevice]:
	var found: Array[BiomeDevice] = []
	for device in devices:
		if is_instance_valid(device) and device.get_script() == kind:
			found.append(device)
	return found


## Dawn: every device stops.
func freeze() -> void:
	if frozen:
		return
	frozen = true
	for device in devices:
		if is_instance_valid(device):
			device.freeze()


func layout() -> LevelLayout:
	return level.layout if level != null else null


## True when the layout has [param room_id] and it is no guardian's arena.
func serves(room_id: StringName) -> bool:
	return layout() != null and layout().room(room_id) != null and not ARENA_ROOMS.has(room_id)


func guard() -> Player:
	if not guard_source.is_valid():
		return null
	var player: Variant = guard_source.call()
	return player as Player if is_instance_valid(player) else null


func room_at(point: Vector3) -> StringName:
	return layout().room_at(point) if layout() != null else &""


## True when a stun may take hold of [param exhibit] without waking it: it
## is alerted already (EnemyBrain.is_alerted: suspicious, investigating,
## hunting, searching, striking or still stunned) and is not running from a
## blast. The brain ends every stun in a hunt (EnemyBrain.stun), so a
## sleeper, one on its calm round, one walking home and one fleeing are left
## as they are.
static func stunnable(exhibit: Enemy) -> bool:
	return exhibit.brain.is_alerted() and exhibit.brain.state != EnemyBrain.State.FLEE


## The exhibits standing (not destroyed, not stone) within [param radius]
## m of [param point].
static func exhibits_near(point: Vector3, radius: float) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for exhibit in PerceptionWorld.exhibits():
		if not exhibit.is_inside_tree() or exhibit.is_queued_for_deletion() or exhibit.is_frozen():
			continue
		if exhibit.brain.state == EnemyBrain.State.DESTROYED:
			continue
		if exhibit.global_position.distance_squared_to(point) <= radius * radius:
			found.append(exhibit)
	return found
