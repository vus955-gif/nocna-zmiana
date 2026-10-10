class_name PerceptionWorld
extends RefCounted
## What exhibit perception knows about the running level (design:
## pietro-1-projekt 7.2) - a static contract every level fills in:
## - configure(illumination, room_of, graph, door_open): how lit a point is
##   (0 dark .. 1 lit, the guard's own light not included), which room a
##   point lies in, the level's RoomGraph (passage ids) and whether a
##   passage is open. reset() goes back to the defaults: everything lit, no
##   rooms (plain distances), every door open - arenas and the sandbox work
##   without any configuration.
## - The difficulty (sight scale, hunter cap; design 7.5).
## - Every exhibit in the scene (Enemy joins on entering the tree).
## - The guard's light this physics frame: the level's light at his chest,
##   flares nearby, and his flashlight (on = always lit).
## - The hunter cap: at most hunter_cap exhibits hunt within
##   PerceptionRules.HUNT_RADIUS of the guard.
## - Noise: weapon shots (Events.weapon_fired, at the guard) and
##   Events.noise_made reach the exhibits that can hear them (the same room
##   or rooms behind open passages, PerceptionRules.hearing_rooms). A noise
##   made inside a haven carries nowhere.

## The guard's light is measured this high over his feet (m).
const CHEST := 1.0

## Exhibits see this much further (1 = night shift).
static var sight_scale: float = 1.0
## At most this many exhibits hunt near the guard at once.
static var hunter_cap: int = PerceptionRules.HUNTER_CAP
## Counters for performance runs: sight checks, rays cast, microseconds
## spent looking (only while [member profiling]), noises.
static var stats := {"looks": 0, "rays": 0, "look_usec": 0, "noises": 0}
static var profiling := false
## How many exhibits reacted to the last noise.
static var last_heard: int = 0

static var _illumination: Callable = Callable()
static var _room_of: Callable = Callable()
static var _graph: RoomGraph = null
static var _door_open: Callable = Callable()
static var _holders: Array = []
static var _exhibits: Array[Enemy] = []
static var _listening := false
static var _flare_lamp: LightSpec = null
## The guard's light, once per physics frame.
static var _light_frame: int = -1
static var _light_guard: int = 0
static var _light_level: float = 1.0
## The guard's room, once per physics frame.
static var _room_frame: int = -1
static var _room_guard: int = 0
static var _guard_room: StringName = &""
## The hunter cap's count, once per physics frame (instance id -> true).
static var _cap_frame: int = -1
static var _cap_hunters: Dictionary = {}


## The callables' objects (a LayoutIllumination, a LevelLayout...) are
## kept alive here until the next configure() or reset(): a Callable does
## not hold on to a RefCounted on its own.
static func configure(illumination: Callable, room_of: Callable, graph: RoomGraph, door_open: Callable) -> void:
	_illumination = illumination
	_room_of = room_of
	_graph = graph
	_door_open = door_open
	_holders.clear()
	for callable in [illumination, room_of, door_open]:
		var owner: Object = (callable as Callable).get_object() if (callable as Callable).is_valid() else null
		if owner is RefCounted:
			_holders.append(owner)
	_forget_frame()


## Back to the defaults: everything lit, no rooms, all doors open.
static func reset() -> void:
	configure(Callable(), Callable(), null, Callable())


## 0 calm shift, 1 night shift (default), 2 double shift.
static func set_difficulty(level: int) -> void:
	var row: Array = PerceptionRules.DIFFICULTY[clampi(level, 0, PerceptionRules.DIFFICULTY.size() - 1)]
	sight_scale = row[0]
	hunter_cap = row[1]


static func has_rooms() -> bool:
	return _room_of.is_valid()


## How lit [param point] is by the level (1 without a light model).
static func light_at(point: Vector3) -> float:
	return clampf(_illumination.call(point), 0.0, 1.0) if _illumination.is_valid() else 1.0


## The room [param point] lies in (&"" without rooms or outside them).
static func room_at(point: Vector3) -> StringName:
	return _room_of.call(point) if _room_of.is_valid() else &""


static func room_graph() -> RoomGraph:
	return _graph


static func is_door_open(passage: StringName) -> bool:
	return not _door_open.is_valid() or _door_open.call(passage)


## An exhibit's rooms: [param explicit] when set, else its home room and
## the rooms next door (PerceptionRules.territory); none without rooms.
static func territory_of(home_room: StringName, explicit: Array[StringName]) -> Array[StringName]:
	if not explicit.is_empty():
		return explicit
	if not has_rooms():
		return [] as Array[StringName]
	return PerceptionRules.territory(_graph, home_room)


# --- the exhibits -----------------------------------------------------------------

static func join(enemy: Enemy) -> void:
	if not _exhibits.has(enemy):
		_exhibits.append(enemy)
	listen()


static func leave(enemy: Enemy) -> void:
	_exhibits.erase(enemy)
	_cap_hunters.erase(enemy.get_instance_id())


## Every exhibit in the scene (valid ones).
static func exhibits() -> Array[Enemy]:
	var found: Array[Enemy] = []
	for enemy in _exhibits:
		if is_instance_valid(enemy):
			found.append(enemy)
	return found


# --- the guard ----------------------------------------------------------------------

## How lit the guard is this physics frame: his flashlight (on = 1), else
## the level's light at his chest plus nearby flares.
static func guard_light(guard: Node3D) -> float:
	if guard == null or not is_instance_valid(guard):
		return 1.0
	var frame := Engine.get_physics_frames()
	if frame == _light_frame and guard.get_instance_id() == _light_guard:
		return _light_level
	_light_frame = frame
	_light_guard = guard.get_instance_id()
	var player := guard as Player
	if player != null and player.battery.on:
		_light_level = 1.0
		return _light_level
	var chest := guard.global_position + Vector3.UP * CHEST
	var level := light_at(chest)
	if level < 1.0:
		level += flare_light(chest)
	_light_level = clampf(level, 0.0, 1.0)
	return _light_level


## Light from the flares burning near [param point].
static func flare_light(point: Vector3) -> float:
	var total := 0.0
	for at in FlareLight.lit_positions():
		if _flare_lamp == null:
			_flare_lamp = LightSpec.make(LightSpec.MAIN, Vector3.ZERO, FlareLight.LIGHT_COLOR, FlareLight.LIGHT_ENERGY, FlareLight.LIGHT_RANGE, &"")
		_flare_lamp.position = at
		total += LayoutIllumination.contribution(_flare_lamp, point)
	return total


## The guard's room this physics frame.
static func guard_room(guard: Node3D) -> StringName:
	if guard == null or not is_instance_valid(guard) or not has_rooms():
		return &""
	var frame := Engine.get_physics_frames()
	if frame != _room_frame or guard.get_instance_id() != _room_guard:
		_room_frame = frame
		_room_guard = guard.get_instance_id()
		_guard_room = room_at(guard.global_position)
	return _guard_room


# --- the hunter cap --------------------------------------------------------------------

## True when [param enemy] may hunt its target: it hunts already, stands
## farther than HUNT_RADIUS from it, or fewer than hunter_cap exhibits hunt
## near it (then it takes a place for this frame).
static func may_hunt(enemy: Enemy) -> bool:
	if not enemy.counts_as_hunter() or not is_instance_valid(enemy.target):
		return true
	var guard_at := enemy.target.global_position
	if enemy.global_position.distance_to(guard_at) > PerceptionRules.HUNT_RADIUS:
		return true
	_count_hunters(guard_at)
	var id := enemy.get_instance_id()
	if _cap_hunters.has(id):
		return true
	if _cap_hunters.size() < hunter_cap:
		_cap_hunters[id] = true
		return true
	return false


## How many exhibits hunt within HUNT_RADIUS of [param guard_at] now.
static func hunters_near(guard_at: Vector3) -> int:
	var count := 0
	for enemy in _exhibits:
		if is_instance_valid(enemy) and enemy.counts_as_hunter() and enemy.brain.is_hunting() \
				and enemy.global_position.distance_to(guard_at) <= PerceptionRules.HUNT_RADIUS:
			count += 1
	return count


static func _count_hunters(guard_at: Vector3) -> void:
	var frame := Engine.get_physics_frames()
	if frame == _cap_frame:
		return
	_cap_frame = frame
	_cap_hunters.clear()
	for enemy in _exhibits:
		if is_instance_valid(enemy) and enemy.counts_as_hunter() and enemy.brain.is_hunting() \
				and enemy.global_position.distance_to(guard_at) <= PerceptionRules.HUNT_RADIUS:
			_cap_hunters[enemy.get_instance_id()] = true


# --- noise ---------------------------------------------------------------------------

## Hooks the noise signals of the Events bus (once).
static func listen() -> void:
	if _listening:
		return
	_listening = true
	Events.weapon_fired.connect(_on_weapon_fired)
	Events.noise_made.connect(_on_noise_made)


## A noise of [param radius] metres at [param at]: every exhibit that hears
## it reacts (Enemy.hear). Returns how many did.
static func noise(at: Vector3, radius: float, _source: StringName = &"") -> int:
	last_heard = 0
	if radius <= 0.0 or Haven.shelters(at):
		return 0
	stats["noises"] = int(stats["noises"]) + 1
	var from := room_at(at)
	var reach := {}
	if from != &"" and _graph != null:
		reach = PerceptionRules.hearing_rooms(_graph, from, _door_open)
	var heard := 0
	for enemy in exhibits():
		if not enemy.is_inside_tree():
			continue
		var distance := enemy.global_position.distance_to(at)
		if distance > radius:
			continue
		var loudness := 1.0
		if from != &"":
			var room := enemy.current_room()
			if room != &"":
				loudness = reach.get(room, 0.0)
		if PerceptionRules.heard(distance, radius, loudness) and enemy.hear(at, from):
			heard += 1
	last_heard = heard
	return heard


static func _on_weapon_fired(weapon_id: StringName) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var guard := tree.get_first_node_in_group(&"player") as Node3D
	if guard != null and guard.is_inside_tree():
		noise(guard.global_position, PerceptionRules.weapon_noise(weapon_id), weapon_id)


static func _on_noise_made(at: Vector3, radius: float, source: StringName) -> void:
	noise(at, radius, source)


static func _forget_frame() -> void:
	_light_frame = -1
	_room_frame = -1
	_cap_frame = -1
	_cap_hunters.clear()
