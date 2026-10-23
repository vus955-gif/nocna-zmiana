class_name Acoustics
extends Node
## Room acoustics (plan 2026-10-21-akustyka-ambient, backlog #40), driven by
## data/audio/acoustics.json:
## - profiles: eleven kinds of space (vast, hall, gallery, room, store,
##   corridor, library, concrete, steel, garden, open), each a ReverbZone
##   preset whose reverb bus gets the file's settings at start
##   (ensure_buses(): the file wins over default_bus_layout.tres and makes
##   the buses the layout lacks), the parameters of its pre-rendered room
##   tails (tools/music/acoustics_tails.py) and how loud they play;
## - rooms: every room of Floor I -> [profile, send] (Ambience.reverb_for
##   reads it after the lobby's own map, before the words and zones);
## - tails / weapons: which shots and blasts get the room's tail;
## - occlusion: what one or two walls do to a positional sound.
## A child of the Ambience autoload, made in its _ready; Ambience hands it
## every Sfx voice as it starts (on_voice).

const DATA_PATH := "res://data/audio/acoustics.json"
## Pre-rendered room tails: tail_<profile>_<class>.ogg (tools/music/acoustics_tails.py).
const TAIL_DIR := "res://assets/ambience/tails/"
const RETURN_BUS := &"SFXReturn"
const SFX_BUS := &"SFX"

## Seconds one walker's occlusion answer serves its next steps.
const STEP_REUSE := 0.4

static var _data: Dictionary = {}
static var _profile_by_preset: Dictionary = {}

## Seconds of game time (advance(); throttles tails, ages the step cache).
var clock: float = 0.0
## Layout instance id -> its AcousticGraph (one level at a time).
var _graphs: Dictionary = {}
## Walker instance id -> [clock, walls].
var _step_walls: Dictionary = {}
## Tails playing now, oldest first.
var _tails: Array[Node] = []
## Throttle key (a tail class, a weapon) -> clock of its last tail.
var _last_tail: Dictionary = {}
## "<profile>_<class>" -> AudioStream (loaded at start).
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()


## The parsed data file (read once).
static func data() -> Dictionary:
	if _data.is_empty():
		var text := FileAccess.get_file_as_string(DATA_PATH)
		var parsed: Variant = JSON.parse_string(text)
		_data = parsed if parsed is Dictionary else {"profiles": {}, "rooms": {}, "tails": {}, "weapons": {}, "occlusion": []}
		_profile_by_preset.clear()
		for id: String in _data.get("profiles", {}):
			_profile_by_preset[preset_of(StringName(id))] = StringName(id)
	return _data


## Ids of the acoustic profiles.
static func profiles() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: String in data().get("profiles", {}):
		ids.append(StringName(id))
	return ids


## The profile [param id] ({} when unknown).
static func profile(id: StringName) -> Dictionary:
	return data().get("profiles", {}).get(String(id), {})


## The ReverbZone.Preset of profile [param id] (-1 when unknown).
static func preset_of(id: StringName) -> int:
	var name: String = data().get("profiles", {}).get(String(id), {}).get("preset", "")
	return int(ReverbZone.Preset.get(name, -1))


## The profile of a ReverbZone preset (&"" when none).
static func profile_of_preset(preset: int) -> StringName:
	data()
	return _profile_by_preset.get(preset, &"")


## [preset, send] of a room named in the data's room table ([] when not).
static func room_reverb(room_id: StringName) -> Array:
	var entry: Variant = data().get("rooms", {}).get(String(room_id))
	if not entry is Array or (entry as Array).size() < 2:
		return []
	var preset := preset_of(StringName(entry[0]))
	return [preset, float(entry[1])] if preset >= 0 else []


## The acoustic profile of a level room (the table, the lobby's map, a word
## of its id or its zone: Ambience.reverb_for).
static func profile_of_room(room_id: StringName, zone: StringName = &"") -> StringName:
	return profile_of_preset(int(Ambience.reverb_for(room_id, zone)[0]))


## [tail class, dB] of [param sound] ([] when it rings nowhere).
static func tail_of(sound: StringName) -> Array:
	var entry: Variant = data().get("tails", {}).get(String(sound))
	return [String(entry[0]), float(entry[1])] if entry is Array else []


## How occluded a positional sound is: 0 clear (a line of sight, or the same
## room - a pillar does not muffle a hall), 1 obstructed (next door, round
## the corner), 2 occluded (two rooms and more). [param hops]: passages
## between the ears' room and the source's (AcousticGraph; negative: the
## rooms are not known, only the ray decides).
static func walls_for(hops: int, clear: bool) -> int:
	if clear or hops == 0:
		return 0
	if hops < 0 or hops == 1:
		return 1
	return 2


## The occlusion level for [param walls] ({} for none): bus, cutoff_hz,
## slope, gain_db, keep_room (the source's own room reverb still heard).
static func occlusion_level(walls: int) -> Dictionary:
	if walls <= 0:
		return {}
	var levels: Array = data().get("occlusion", [])
	var best: Dictionary = {}
	for level: Dictionary in levels:
		if int(level["walls"]) <= walls and (best.is_empty() or int(level["walls"]) > int(best["walls"])):
			best = level
	return best


## Makes the buses the data asks for and gives them its settings: every
## profile's reverb bus (into SFXReturn, wet only) and the occlusion buses
## (into SFX: a low-pass, a level, maybe a dark reverb).
static func ensure_buses() -> void:
	for id in profiles():
		var preset := preset_of(id)
		if preset < 0:
			continue
		var bus := _bus(ReverbZone.BUSES[preset], RETURN_BUS)
		var reverb := _effect(bus, 0, AudioEffectReverb) as AudioEffectReverb
		_apply(reverb, profile(id).get("bus", {}))
		reverb.dry = 0.0
	for level: Dictionary in data().get("occlusion", []):
		var bus := _bus(StringName(level["bus"]), SFX_BUS)
		AudioServer.set_bus_volume_db(bus, float(level.get("gain_db", 0.0)))
		var filter := _effect(bus, 0, AudioEffectLowPassFilter) as AudioEffectLowPassFilter
		filter.cutoff_hz = float(level.get("cutoff_hz", 2000.0))
		filter.db = _slope(int(level.get("slope", 12)))
		if level.has("reverb"):
			_apply(_effect(bus, 1, AudioEffectReverb), level["reverb"])


static func _bus(bus_name: StringName, send: StringName) -> int:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, bus_name)
	AudioServer.set_bus_send(bus, send)
	return bus


## The effect at [param index] of [param bus] when it is a [param type],
## else a new one put there.
static func _effect(bus: int, index: int, type: Variant) -> AudioEffect:
	if index < AudioServer.get_bus_effect_count(bus):
		var found := AudioServer.get_bus_effect(bus, index)
		if is_instance_of(found, type):
			return found
	var made: AudioEffect = type.new()
	AudioServer.add_bus_effect(bus, made, mini(index, AudioServer.get_bus_effect_count(bus)))
	return made


static func _apply(effect: Object, settings: Dictionary) -> void:
	for key: String in settings:
		effect.set(key, float(settings[key]))


static func _slope(db_per_octave: int) -> AudioEffectFilter.FilterDB:
	match db_per_octave:
		6:
			return AudioEffectFilter.FILTER_6DB
		18:
			return AudioEffectFilter.FILTER_18DB
		24:
			return AudioEffectFilter.FILTER_24DB
	return AudioEffectFilter.FILTER_12DB


# --- the running game ---------------------------------------------------------

func _ready() -> void:
	_rng.randomize()
	for id in profiles():
		for kind: String in data().get("tail_classes", {}):
			var path := TAIL_DIR + "tail_%s_%s.ogg" % [id, kind]
			if ResourceLoader.exists(path):
				_streams["%s_%s" % [id, kind]] = load(path)   # up front, not mid-fight
	Events.weapon_fired.connect(_on_weapon_fired)


## Moves the clock on (Ambience.advance calls it every frame).
func advance(delta: float) -> void:
	clock += delta


## Forgets the level (a scene swap).
func forget() -> void:
	_graphs.clear()
	_step_walls.clear()
	_last_tail.clear()


## A voice Sfx just started (Ambience hands over every one): a positional
## sound behind walls goes through its occlusion bus; a shot or a blast
## named in the data's tails gets its room's tail - the guard's own (flat)
## the tail of the room he stands in, a positional one the tail of the room
## it sounds in.
func on_voice(voice: Node) -> void:
	var sound: StringName = voice.get_meta(&"sound", &"")
	var tail := tail_of(sound)
	var spatial := voice as AudioStreamPlayer3D
	if spatial != null:
		if spatial.bus != SFX_BUS:
			return
		var walls := walls_to(spatial.global_position)
		route(spatial, walls)
		if not tail.is_empty():
			var where := profile_at(spatial.global_position)
			play_tail(tail[0], where if where != &"" else listener_profile(), float(tail[1]) + spatial.volume_db,
					spatial.global_position, walls)
	elif voice is AudioStreamPlayer and (voice as AudioStreamPlayer).bus == SFX_BUS and not tail.is_empty():
		play_tail(tail[0], listener_profile(), float(tail[1]) + (voice as AudioStreamPlayer).volume_db)


## Plays the tail of [param kind] (crack, boom, blast) of a room of
## [param profile_id]: flat on SFXReturn, or at [param at] in 3D (no zone
## reverb: the tail is the room; two walls and more: through the occlusion
## bus). Throttled per class (tail_gap), at most tail_voices at once (the
## oldest makes room). Returns the player, or null.
func play_tail(kind: String, profile_id: StringName, db: float, at: Variant = null, walls: int = 0) -> Node:
	var stream: AudioStream = _streams.get("%s_%s" % [profile_id, kind])
	if stream == null or not is_inside_tree():
		return null
	if clock - float(_last_tail.get(kind, -INF)) < float(data().get("tail_gap", 0.07)):
		return null
	_last_tail[kind] = clock
	_tails.assign(_playing())
	while _tails.size() >= int(data().get("tail_voices", 6)):
		_release(_tails.pop_front())
	var player: Node
	if at == null:
		var flat := AudioStreamPlayer.new()
		flat.bus = RETURN_BUS
		player = flat
	else:
		var spatial := AudioStreamPlayer3D.new()
		var level := occlusion_level(walls)
		spatial.bus = RETURN_BUS if bool(level.get("keep_room", true)) else StringName(level["bus"])
		spatial.area_mask = 0
		spatial.unit_size = float(data().get("tail_unit_size", 24.0))
		spatial.max_db = 0.0   # a room's tail never swells past its level up close
		spatial.max_distance = Sfx.MAX_DISTANCE * 1.5
		spatial.position = at
		player = spatial
	player.set(&"stream", stream)
	player.set(&"volume_db", float(profile(profile_id).get("tail_db", -6.0)) + db)
	player.set(&"pitch_scale", _rng.randf_range(0.97, 1.03))
	player.set_meta(&"tail", StringName("%s_%s" % [profile_id, kind]))
	add_child(player)
	player.call(&"play")
	player.connect(&"finished", player.queue_free)
	_tails.append(player)
	return player


## The tails playing now.
func tails() -> Array[Node]:
	var playing: Array[Node] = []
	playing.assign(_playing())
	return playing


## The listed tails still there: a freed one (gone with its scene, or
## finished and freed) is dropped - the lambda takes it untyped, a typed
## parameter cannot even receive a freed object (an engine error).
func _playing() -> Array:
	return _tails.filter(func(node: Variant) -> bool: return is_instance_valid(node) and not (node as Node).is_queued_for_deletion())


## Stops every tail (a scene swap, quitting).
func stop_all() -> void:
	for node in _tails:
		if is_instance_valid(node):
			_release(node)
	_tails.clear()


func _release(node: Node) -> void:
	node.call(&"stop")
	remove_child(node)
	node.queue_free()


## The acoustic profile of the room the listener stands in (&"" outside
## every reverb zone).
func listener_profile() -> StringName:
	var zone: ReverbZone = Ambience.listener_zone()
	if zone == null:
		var ears: Variant = AudioContext.listener_position(get_viewport()) if is_inside_tree() else null
		zone = zone_at(ears) if ears != null else null
	return profile_of_preset(zone.preset) if zone != null else &""


## The acoustic profile of the space around [param point]: its level room's
## (the same answer the room's automatic reverb zone got), else the reverb
## zone around it (&"" none).
func profile_at(point: Vector3) -> StringName:
	var level := AudioContext.level(get_tree()) if is_inside_tree() else null
	var layout: Variant = level.get(&"layout") if level != null else null
	if layout is LevelLayout:
		var room := (layout as LevelLayout).room((layout as LevelLayout).room_at(point + Vector3.UP * 0.3))
		if room != null:
			return profile_of_room(room.id, room.zone)
	var zone := zone_at(point)
	return profile_of_preset(zone.preset) if zone != null else &""


## The reverb zone around [param point] (the highest priority), or null.
func zone_at(point: Vector3) -> ReverbZone:
	var best: ReverbZone = null
	for node in get_tree().get_nodes_in_group(&"reverb_zones"):
		var zone := node as ReverbZone
		if zone != null and (best == null or zone.priority > best.priority) and zone.contains(point):
			best = zone
	return best


## A weapon with no sound of its own per shot (the gatling's rattle is a
## loop): its tail, at most every few tenths of a second (data "weapons").
func _on_weapon_fired(weapon_id: StringName) -> void:
	var entry: Variant = data().get("weapons", {}).get(String(weapon_id))
	if not Ambience.enabled or not entry is Array:
		return
	var key := "weapon_" + String(weapon_id)
	if clock - float(_last_tail.get(key, -INF)) < float(entry[2]):
		return
	_last_tail[key] = clock
	play_tail(String(entry[0]), listener_profile(), float(entry[1]))


## A walker's step (Footsteps): the same routing, its answer reused for
## STEP_REUSE s (an exhibit steps twice a second).
func route_step(voice: AudioStreamPlayer3D, walker: Node3D) -> void:
	var key := walker.get_instance_id()
	var known: Variant = _step_walls.get(key)
	var walls: int
	if known is Array and clock - float(known[0]) < STEP_REUSE:
		walls = int(known[1])
	else:
		walls = walls_to(walker.global_position)
		_step_walls[key] = [clock, walls]
	route(voice, walls)


## Sends [param voice] through the bus of [param walls] (SFX when clear);
## occluded voices lose their room's reverb (keep_room false).
func route(voice: AudioStreamPlayer3D, walls: int) -> void:
	var level := occlusion_level(walls)
	if level.is_empty():
		voice.bus = SFX_BUS
		voice.area_mask |= Layers.REVERB_ZONE
		return
	voice.bus = StringName(level["bus"])
	if bool(level.get("keep_room", true)):
		voice.area_mask |= Layers.REVERB_ZONE
	else:
		voice.area_mask &= ~Layers.REVERB_ZONE


## Walls between the ears (the camera, else the guard) and [param point];
## 0 when nobody listens.
func walls_to(point: Vector3) -> int:
	if not is_inside_tree():
		return 0
	var ears: Variant = AudioContext.listener_position(get_viewport())
	if ears == null:
		return 0
	return walls_between(ears, point, AudioContext.level(get_tree()))


## Walls between [param ears] and [param point] in [param level] (a node
## with room_at() and a layout; null: the ray alone).
func walls_between(ears: Vector3, point: Vector3, level: Node) -> int:
	if line_clear(ears, point):
		return 0
	var graph := graph_of(level)
	if graph == null:
		return walls_for(-1, false)
	var lift := Vector3.UP * float(data().get("occlusion_lift", 0.6))
	var here: StringName = level.call(&"room_at", ears)
	var there: StringName = level.call(&"room_at", point + lift)
	if here == &"" or there == &"" or not graph.has_room(here) or not graph.has_room(there):
		return walls_for(-1, false)
	return walls_for(graph.hops(here, there), false)


## True when nothing of the world (Layers.WORLD) stands between [param ears]
## and [param point] (raised by occlusion_lift: a sound at an exhibit's feet
## is heard from its body); a hit within occlusion_near of the point counts
## as clear (the floor or the wall it stands at).
func line_clear(ears: Vector3, point: Vector3) -> bool:
	var target := point + Vector3.UP * float(data().get("occlusion_lift", 0.6))
	var space := get_viewport().find_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return true
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(ears, target, Layers.WORLD))
	return hit.is_empty() or (hit["position"] as Vector3).distance_to(target) <= float(data().get("occlusion_near", 0.5))


## The AcousticGraph of [param level]'s layout (null without rooms).
func graph_of(level: Node) -> AcousticGraph:
	if level == null or not level.has_method(&"room_at"):
		return null
	var layout: Variant = level.get(&"layout")
	if not layout is Object or not ("rooms" in layout):
		return null
	var key := (layout as Object).get_instance_id()
	if not _graphs.has(key):
		_graphs.clear()
		_graphs[key] = AcousticGraph.from_layout(layout)
	return _graphs[key]
