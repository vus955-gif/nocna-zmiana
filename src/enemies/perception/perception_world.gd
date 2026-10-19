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
## - Noise: weapon shots (Events.weapon_fired, at the guard),
##   Events.noise_made, a door's creak (Events.door_creaked: it belongs to
##   the two rooms the door joins) and fallen exhibits (Events.enemy_destroyed)
##   reach the exhibits that can hear them (the same room or rooms behind
##   open passages, PerceptionRules.hearing_rooms). A noise made inside a
##   haven carries nowhere. Each listener answers by its kind and how close
##   the noise was (ReactionRules: look, investigate, flee), at most
##   INVESTIGATE_CAP of them going to look (backlog #24). The ones that can
##   not answer (a wreck, stone, a hunter) are not listeners, and a sound
##   sleeper hears no door, crash or step.

## The guard's light is measured this high over his feet (m).
const CHEST := 1.0
## The guard's trail (what a wolf sniffs): a crumb every TRAIL_STEP metres
## he walks, kept TRAIL_LIFE seconds, at most TRAIL_MAX of them.
const TRAIL_STEP := 1.5
const TRAIL_LIFE := 25.0
const TRAIL_MAX := 24
## The calm routines run only this many passages from the guard's room (as
## the RoomCuller keeps rooms lit: what he may see or hear of).
const ROUTINE_HOPS := 2

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
## The trail: [position, age in seconds], oldest first; tracked once per
## physics frame.
static var _trail: Array = []
static var _trail_frame: int = -1
static var _trail_last := Vector3.INF
## Whose trail it is (instance id): another guard starts a fresh one.
static var _trail_guard: int = 0
## Game time (s), advanced once per physics frame by the exhibits
## (track()), and the exhibits sent to look lately: [time, where].
static var _clock: float = 0.0
static var _sends: Array = []
## The rooms near the guard (room -> true), for the room he stands in.
static var _near_from: StringName = &""
static var _near_rooms: Dictionary = {}


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


## The rooms at most ROUTINE_HOPS passages (any door, open or not) from
## the guard's room (room -> true; worked out again only when he changes
## rooms). Empty without rooms or with the guard outside them: no room rule.
static func rooms_near_guard(guard: Node3D) -> Dictionary:
	var room := guard_room(guard)
	if room == &"" or _graph == null or not _graph.has_room(room):
		return {}
	if room != _near_from:
		_near_from = room
		_near_rooms = {room: true}
		var frontier: Array[StringName] = [room]
		for hop in ROUTINE_HOPS:
			var next: Array[StringName] = []
			for here in frontier:
				for door in _graph.doors_of_room(here):
					var ends := _graph.door_rooms(door)
					var other: StringName = ends[1] if ends[0] == here else ends[0]
					if not _near_rooms.has(other):
						_near_rooms[other] = true
						next.append(other)
			frontier = next
	return _near_rooms


# --- the trail -------------------------------------------------------------------------

## Lays the guard's trail (once per physics frame, whoever calls first;
## [param guard] null: only the time moves on): a crumb every TRAIL_STEP
## metres, the old ones fading after TRAIL_LIFE.
static func track(guard: Node3D, delta: float) -> void:
	var frame := Engine.get_physics_frames()
	if frame == _trail_frame:
		return
	_trail_frame = frame
	_clock += delta
	for crumb: Array in _trail:
		crumb[1] = float(crumb[1]) + delta
	while not _trail.is_empty() and float(_trail[0][1]) > TRAIL_LIFE:
		_trail.pop_front()
	if guard == null or not is_instance_valid(guard) or not guard.is_inside_tree():
		return
	if guard.get_instance_id() != _trail_guard:
		_trail.clear()
		_trail_last = Vector3.INF
		_trail_guard = guard.get_instance_id()
	var at := guard.global_position
	if _trail_last != Vector3.INF and at.distance_to(_trail_last) < TRAIL_STEP:
		return
	_trail_last = at
	_trail.append([at, 0.0])
	while _trail.size() > TRAIL_MAX:
		_trail.pop_front()


## The crumbs still fresh, oldest first.
static func trail() -> PackedVector3Array:
	var crumbs := PackedVector3Array()
	for crumb: Array in _trail:
		crumbs.append(crumb[0])
	return crumbs


## The freshest crumb within [param within] metres of [param near] that is
## at least [param min_age] seconds old (Vector3.INF when there is none): a
## scent is where he WAS, not the crumb he is dropping this moment.
static func freshest_crumb(near: Vector3, within: float, min_age: float = 0.0) -> Vector3:
	for i in range(_trail.size() - 1, -1, -1):
		if float(_trail[i][1]) < min_age:
			continue
		var at: Vector3 = _trail[i][0]
		if at.distance_to(near) <= within:
			return at
	return Vector3.INF


## Forgets the trail (a new night, tests).
static func clear_trail() -> void:
	_trail.clear()
	_trail_last = Vector3.INF
	_trail_frame = -1
	_trail_guard = 0


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
	Events.door_creaked.connect(_on_door_creaked)
	Events.enemy_destroyed.connect(_on_enemy_destroyed)


## A noise of [param radius] metres at [param at] from [param source] (a
## weapon id, &"sprint", &"glass", ReactionRules.SOURCE_FALL / _DOOR /
## _BLAST...): every exhibit that hears it answers by its kind and how
## close it was (ReactionRules.decide, then the cap: the nearest curious
## one goes to look at a plain noise, at most INVESTIGATE_CAP do - fewer
## when others were sent near there in the last SEND_WINDOW seconds - the
## rest turn their heads). It carries from the room it is made in; a noise
## made in a wall (a door's creak) belongs to the [param rooms] given
## instead, all of them at full strength. Returns how many are awake for it.
static func noise(at: Vector3, radius: float, source: StringName = &"", rooms: Array[StringName] = []) -> int:
	last_heard = 0
	if radius <= 0.0 or Haven.shelters(at):
		return 0
	stats["noises"] = int(stats["noises"]) + 1
	var origin := noise_rooms(at, rooms)
	var reach := {}
	if _graph != null:
		for room in origin:
			var heard_in := PerceptionRules.hearing_rooms(_graph, room, _door_open)
			for key: StringName in heard_in:
				reach[key] = maxf(float(reach.get(key, 0.0)), float(heard_in[key]))
	var soft := ReactionRules.is_soft(source)
	# the ones awake and past answering (hunting, fleeing...) are awake for it
	# but take no place; [distance, enemy, closeness], nearest first
	var heard := 0
	var listeners: Array = []
	for enemy in exhibits():
		if not enemy.is_inside_tree() or enemy.is_frozen() or enemy.is_queued_for_deletion():
			continue
		var distance := enemy.global_position.distance_to(at)
		if distance > radius:
			continue
		var loudness := 1.0
		if not origin.is_empty():
			var room := enemy.current_room()
			if room != &"":
				loudness = reach.get(room, 0.0)
		if not PerceptionRules.heard(distance, radius, loudness):
			continue
		var state := enemy.brain.state
		if state == EnemyBrain.State.DESTROYED:
			continue
		if state == EnemyBrain.State.HUNT or state == EnemyBrain.State.ATTACK or state == EnemyBrain.State.STUNNED or state == EnemyBrain.State.FLEE:
			heard += 1
			continue
		if soft and enemy.sound_asleep > 0.0 and state == EnemyBrain.State.DORMANT:
			continue
		listeners.append([distance, enemy, ReactionRules.closeness(distance, radius, loudness)])
	listeners.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var decided: Array = []
	var curious: Array = []
	for entry: Array in listeners:
		var enemy: Enemy = entry[1]
		var profile := enemy.profile()
		decided.append(ReactionRules.decide(source, profile, entry[2], enemy.brain.rng.randf()))
		var able: float = profile.get("door", 0.0) if source == ReactionRules.SOURCE_DOOR else profile.get("curiosity", 0.0)
		curious.append(able > 0.0)
	var fresh: Array = []
	for entry: Array in listeners:
		var state: EnemyBrain.State = (entry[1] as Enemy).brain.state
		fresh.append(state == EnemyBrain.State.DORMANT or state == EnemyBrain.State.PATROL or state == EnemyBrain.State.SUSPICIOUS)
	var answers := ReactionRules.cap(decided, curious, ReactionRules.INVESTIGATE_CAP - recent_sends(at), fresh, ReactionRules.sends_a_visitor(source))
	# the ones that only look up (and the ones that run) first: when an
	# investigator then stands up and rouses its sleeping neighbours, those
	# who heard the noise themselves are looking already and stay with
	# their own answer (the chain only reaches those out of earshot)
	for sweep in 2:
		for i in listeners.size():
			var going: bool = answers[i] == ReactionRules.Reaction.INVESTIGATE
			if going != (sweep == 1):
				continue
			var enemy: Enemy = listeners[i][1]
			if enemy.react(at, _room_for(enemy, origin), answers[i], source):
				heard += 1
			if going and fresh[i] and enemy.brain.is_alerted():
				_sends.append([_clock, at])
	last_heard = heard
	return heard


## The rooms a noise at [param at] belongs to: the [param rooms] it was made
## in when it is given (a door's creak: the two it joins), else the room it
## lies in; none without rooms or outside them (plain distances).
static func noise_rooms(at: Vector3, rooms: Array[StringName] = []) -> Array[StringName]:
	var found: Array[StringName] = []
	if not has_rooms():
		return found
	for room in rooms:
		if room != &"" and not found.has(room):
			found.append(room)
	if found.is_empty():
		var here := room_at(at)
		if here != &"":
			found.append(here)
	return found


## The room to tell [param enemy] the noise came from: its own side of a
## wall noise when that lies in its bounds.
static func _room_for(enemy: Enemy, origin: Array[StringName]) -> StringName:
	if origin.size() < 2:
		return origin[0] if origin.size() == 1 else &""
	var bounds := enemy.bounds_rooms()
	for room in origin:
		if bounds.has(room):
			return room
	return origin[0]


## How many exhibits were sent to look within ReactionRules.SEND_AREA of
## [param at] in the last ReactionRules.SEND_WINDOW seconds.
static func recent_sends(at: Vector3) -> int:
	while not _sends.is_empty() and _clock - float(_sends[0][0]) > ReactionRules.SEND_WINDOW:
		_sends.pop_front()
	var count := 0
	for send: Array in _sends:
		if (send[1] as Vector3).distance_to(at) <= ReactionRules.SEND_AREA:
			count += 1
	return count


static func _on_weapon_fired(weapon_id: StringName) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var guard := tree.get_first_node_in_group(&"player") as Node3D
	if guard != null and guard.is_inside_tree():
		noise(guard.global_position, PerceptionRules.weapon_noise(weapon_id), weapon_id)


static func _on_noise_made(at: Vector3, radius: float, source: StringName) -> void:
	noise(at, radius, source)


## A door creaks open: heard in the two rooms it joins.
static func _on_door_creaked(at: Vector3, radius: float, room_a: StringName, room_b: StringName) -> void:
	var rooms: Array[StringName] = [room_a, room_b]
	noise(at, radius, ReactionRules.SOURCE_DOOR, rooms)


## An exhibit crashed down: its neighbours hear it (not one that fell out
## of the level: nothing happened where anyone could hear).
static func _on_enemy_destroyed(enemy: Node, info: DamageInfo, _finisher: bool) -> void:
	if Enemy.fell_out(info):
		return
	var fallen := enemy as Node3D
	if fallen == null or not is_instance_valid(fallen) or not fallen.is_inside_tree():
		return
	noise(fallen.global_position, PerceptionRules.FALL_NOISE, ReactionRules.SOURCE_FALL)


static func _forget_frame() -> void:
	_light_frame = -1
	_room_frame = -1
	_near_from = &""
	_near_rooms = {}
	_sends.clear()
	_cap_frame = -1
	_cap_hunters.clear()
	clear_trail()
