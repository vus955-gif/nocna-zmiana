class_name StoryLayer
extends Node
## Tells the ambient story (plan 2026-10-21-akustyka-ambient, backlog #41):
## a child of the Ambience autoload that feeds an AmbientStory with what goes
## on and plays what it picks, sparse, by zone and by the night's phase -
## the building settling, ducts ticking, steps next door that nobody makes,
## exhibits shifting on their plinths (at a real sleeping exhibit, in its
## material), whispers in Egypt, clocks in the Enlightenment, the city at
## the windows, the booth's radio, thunder on rainy nights - and keeps its
## silences (havens, a sleeping guardian next door, dead air, the voice).
## Everything plays on the Ambience bus (the voice ducks it), in 3D, with
## its distance baked in (no zone reverb). Off in test runs with Ambience.
## - The night's phase: Events.night_phase_changed (the night escalation's
##   curve) when the game has it, else from the clock: hour_struck 1:00 /
##   3:00 / 5:00 and the witching hour.
## - Rain: decided per night (AmbientStory.rain_tonight), heard as the
##   Ambience beds of the rain's zones.
## - Hushes: a guardian's fall, an uncanny moment (Events.uncanny_event when
##   the game has it).

## Unit size (m) of a story's player by where it sounds (larger: carries farther).
const UNIT := {"around": 14.0, "close": 4.0, "next_room": 10.0, "exhibit": 10.0, "street": 30.0, "sky": 45.0, "room": 6.0}
## Hours after midnight on the clock's face -> phase (1:00 uneasy, 3:00 the
## witching hour, 5:00 before dawn).
const HOUR_PHASES := {1: AmbientStory.UNEASY, 3: AmbientStory.WITCHING, 5: AmbientStory.PREDAWN}

var story := AmbientStory.new()
## True on a night with rain (its beds play in the rain's zones).
var raining: bool = false
## Dawn came: the story is over for the night.
var ended: bool = false
## The last story told (debug, tests): its data entry plus "at" and "sound".
var last_told: Dictionary = {}

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	Events.night_started.connect(_on_night_started)
	Events.hour_struck.connect(_on_hour_struck)
	Events.witching_hour.connect(func() -> void: set_phase(AmbientStory.WITCHING))
	Events.dawn_broke.connect(func() -> void: ended = true)
	Events.guardian_defeated.connect(func(_id: StringName) -> void:
		story.hush(float(AmbientStory.data()["silence"]["after_guardian"])))
	# the night escalation's signals, when the game has them (coordinated by data only)
	if Events.has_signal(&"night_phase_changed"):
		Events.connect(&"night_phase_changed", func(value: int) -> void: set_phase(value, true))
	if Events.has_signal(&"uncanny_event"):
		Events.connect(&"uncanny_event", func(_id: StringName, _room: StringName) -> void:
			story.hush(float(AmbientStory.data()["silence"]["after_uncanny"])))


## A blank night (no night announced: menus, dev scenes).
func reset() -> void:
	story = AmbientStory.new()
	raining = false
	ended = false
	last_told = {}


## The night's phase from now on (never back within a night, unless
## [param exact]: the night escalation says so itself).
func set_phase(value: int, exact: bool = false) -> void:
	story.phase = clampi(value, AmbientStory.CALM, AmbientStory.PREDAWN) if exact else maxi(story.phase, value)


## Looks at the world and moves the story on by [param delta]; plays what
## is due. Ambience calls it every POLL s.
func tick(delta: float) -> Dictionary:
	_look()
	var due := story.advance(delta)
	if not due.is_empty():
		tell(due)
	return due


## Plays [param entry] (a story of the data) now. Returns the player, or null.
func tell(entry: Dictionary) -> AudioStreamPlayer3D:
	last_told = entry.duplicate()
	if entry.has("hush_layer"):
		Ambience.hush_layer(StringName(entry["hush_layer"]), float(entry.get("seconds", 4.0)))
		return null
	var ears: Variant = AudioContext.listener_position(get_viewport()) if is_inside_tree() else null
	if ears == null:
		return null
	var sound := StringName(entry.get("sound", ""))
	var where := String(entry.get("where", "around"))
	var at: Variant = null
	if sound == &"shift":
		var exhibit := _sleeping_exhibit(ears, entry.get("distance", [8.0, 30.0]))
		sound = StringName("shift_" + material_of(exhibit))
		if exhibit != null:
			at = exhibit.global_position + Vector3.UP * 0.8
	if at == null:
		at = place(where, ears, entry)
	if at == null:
		return null
	var pitch: Array = entry.get("pitch", [1.0, 1.0])
	var player := Ambience.play_story(sound, at, float(entry.get("db", -10.0)), _rng.randf_range(float(pitch[0]), float(pitch[1])),
			float(UNIT.get(where, 12.0)))
	last_told["sound"] = sound
	last_told["at"] = at
	if player != null and float(entry.get("move", 0.0)) > 0.0 and player.stream != null:
		var angle := _rng.randf() * TAU
		var to: Vector3 = (at as Vector3) + Vector3(cos(angle), 0.0, sin(angle)) * float(entry["move"])
		player.create_tween().tween_property(player, ^"position", to, player.stream.get_length() / maxf(player.pitch_scale, 0.1))
	return player


## Where a story of kind [param where] sounds around [param ears] (null:
## nowhere fits - a room that is not on this level).
func place(where: String, ears: Vector3, entry: Dictionary) -> Variant:
	var span: Array = entry.get("distance", [10.0, 22.0])
	var distance := _rng.randf_range(float(span[0]), float(span[1]))
	var angle := _rng.randf() * TAU
	var flat := Vector3(cos(angle), 0.0, sin(angle))
	match where:
		"close":
			return ears + flat * distance + Vector3.UP * _rng.randf_range(-0.3, 0.6)
		"street":
			return ears + flat * distance + Vector3.UP * 3.0
		"sky":
			return ears + flat * distance * 0.5 + Vector3.UP * distance
		"next_room":
			var next: Variant = _next_room_point(ears)
			if next != null:
				return next
		"room":
			return _room_point(entry.get("rooms", []))
	return ears + flat * distance + Vector3.UP * _rng.randf_range(-1.0, 4.0)


## The middle of a room one passage from the ears' room (null: no level).
func _next_room_point(ears: Vector3) -> Variant:
	var level := AudioContext.level(get_tree())
	var graph := Ambience.acoustics.graph_of(level)
	if graph == null:
		return null
	var here: StringName = level.call(&"room_at", ears)
	var rooms := graph.neighbours(here)
	if rooms.is_empty():
		return null
	var layout := level.get(&"layout") as LevelLayout
	var room := layout.room(rooms[_rng.randi_range(0, rooms.size() - 1)]) if layout != null else null
	if room == null or room.parts.is_empty():
		return null
	var middle := room.parts[0].get_center()
	return Vector3(middle.x, room.floor_y + 1.2, middle.y)


## The middle of the first of [param ids] this level has (null: none).
func _room_point(ids: Array) -> Variant:
	var level := AudioContext.level(get_tree())
	var layout := level.get(&"layout") as LevelLayout if level != null else null
	if layout == null:
		return null
	for id: Variant in ids:
		var room := layout.room(StringName(id))
		if room != null and not room.parts.is_empty():
			var middle := room.parts[0].get_center()
			return Vector3(middle.x, room.floor_y + 1.2, middle.y)
	return null


## A sleeping exhibit [param span] m from the ears, out of their sight if
## one is (null: none in range).
func _sleeping_exhibit(ears: Vector3, span: Array) -> Node3D:
	var seen: Array[Node3D] = []
	var hidden: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var exhibit := node as Enemy
		if exhibit == null or not exhibit.is_inside_tree() or exhibit.brain.state != EnemyBrain.State.DORMANT:
			continue
		var d := exhibit.global_position.distance_to(ears)
		if d < float(span[0]) or d > float(span[1]):
			continue
		if Ambience.acoustics.line_clear(ears, exhibit.global_position):
			seen.append(exhibit)
		else:
			hidden.append(exhibit)
	var pool := hidden if not hidden.is_empty() else seen
	return pool[_rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else null


## stone / wood / metal / soft: how [param exhibit] sounds when it shifts
## (stone without one).
static func material_of(exhibit: Node) -> String:
	var enemy := exhibit as Enemy
	if enemy == null:
		return "stone"
	var key: Variant = ExhibitMaterial.Kind.find_key(enemy.material_kind)
	return String(AmbientStory.data().get("materials", {}).get(String(key), "stone"))


## The world as the story needs it: zone, haven, sleeping guardians, a
## fight, the voice, power.
func _look() -> void:
	story.zone = Ambience.zone if not ended else &""
	story.raining = raining
	story.dark = Ambience.is_dark(Ambience.zone)
	story.voice = VoiceDirector.current_line() != &""
	var state := Music.state()
	story.fighting = state == MusicDirector.State.COMBAT or state == MusicDirector.State.BOSS or state == MusicDirector.State.GUARDIAN
	story.in_haven = false
	story.guardian = AmbientStory.GUARDIAN_NONE
	var ears: Variant = AudioContext.listener_position(get_viewport()) if is_inside_tree() else null
	var level := AudioContext.level(get_tree()) if is_inside_tree() else null
	if ears == null or level == null:
		return
	var here: StringName = level.call(&"room_at", ears)
	var layout := level.get(&"layout") as LevelLayout
	var room := layout.room(here) if layout != null else null
	story.in_haven = room != null and room.haven
	var graph := Ambience.acoustics.graph_of(level)
	for node in get_tree().get_nodes_in_group(&"guardians"):
		var keeper := node as Guardian
		if keeper == null or keeper.state != Guardian.State.DORMANT or keeper.arena_room == &"":
			continue
		if keeper.arena_room == here:
			story.guardian = AmbientStory.GUARDIAN_ARENA
			return
		if graph != null and graph.hops(here, keeper.arena_room) == 1:
			story.guardian = AmbientStory.GUARDIAN_NEAR


func _on_night_started(number: int, modifier: StringName) -> void:
	var night_seed := GameState.night_seed()
	reset()
	story.start_night(number, modifier, night_seed)
	story.modifier = modifier
	raining = AmbientStory.rain_tonight(number, modifier, night_seed)


func _on_hour_struck(hour: int) -> void:
	for start: int in HOUR_PHASES:
		if hour >= start and hour < 6:
			set_phase(HOUR_PHASES[start])
