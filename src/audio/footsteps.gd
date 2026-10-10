class_name Footsteps
extends Node3D
## Footsteps for the CharacterBody3D it is a child of (the guard or an
## exhibit), without touching the body's script: every physics frame it
## reads the body's real velocity and floor contact.
## - Cadence: a step every stride metres; the stride grows with the square
##   root of the speed, so a run is both faster and longer (PROFILES).
## - Surface: a short ray under each step finds the floor and Surface.of()
##   reads its tag (metadata "surface", physics material name, group,
##   level room; see Surface).
## - The guard (profile "guard", heard flat, 2D) gets his key ring
##   jingling when he runs, a push-off when he jumps and a landing that
##   grows with the fall. Exhibits are heard in 3D (reverb zones apply) and
##   only within HEAR_DISTANCE of the camera.
## - Takes: res://assets/sfx/steps/<set>_<n>.wav (tools/music/gen_foley.py),
##   picked at random, never the same take twice in a row, pitch jittered.
## Attach with Footsteps.attach(body, &"wolf"), or let the Foley autoload
## do it for the guard and the exhibits. The T-Rex has steps of its own.

signal stepped(surface: StringName)
signal landed(fall_speed: float)

const DIR := "res://assets/sfx/steps/"
const BUS := &"SFX"
## stride (m at the reference speed), speed (m/s), min_speed (m/s), db,
## set (the exhibit's own takes), surface_db (the floor under an exhibit,
## heard under its own sound), soft_set (on carpet), flat (2D voices),
## gear_speed (above it the guard runs).
const PROFILES := {
	&"guard": {"stride": 2.4, "speed": 5.5, "min_speed": 1.2, "db": -7.0, "flat": true, "gear_speed": 7.2},
	&"wax": {"stride": 1.2, "speed": 2.4, "min_speed": 0.4, "db": -5.0, "set": &"wax", "surface_db": -16.0},
	&"wolf": {"stride": 1.7, "speed": 6.5, "min_speed": 0.6, "db": -5.0, "set": &"wolf", "soft_set": &"wolf_soft"},
	&"knight": {"stride": 1.2, "speed": 2.0, "min_speed": 0.4, "db": -3.0, "set": &"knight", "surface_db": -9.0},
	&"raptor": {"stride": 2.2, "speed": 7.5, "min_speed": 0.6, "db": -5.0, "set": &"raptor"},
}
const PITCH_JITTER := 0.06
const HEAR_DISTANCE := 35.0
## Falls faster than this (m/s) make a landing; HARD_LANDING is the loudest.
const LANDING_SPEED := 3.5
const HARD_LANDING := 11.0
## Leaving the floor faster than this upwards is a jump.
const JUMP_SPEED := 2.0
const RUN_BOOST_DB := 2.0
const VOICES := 3

static var _takes: Dictionary = {}

@export var profile: StringName = &"guard"
var body: CharacterBody3D
## The floor under the last step.
var surface: StringName = Surface.STONE
var steps_taken: int = 0

var _travel: float = 0.0
var _moving: bool = false
var _was_on_floor: bool = true
var _fall_speed: float = 0.0
var _voices: Array[Node] = []
var _next_voice: int = 0
var _last_take: Dictionary = {}
var _rng := RandomNumberGenerator.new()


## Adds footsteps with [param profile_id] to [param walker].
static func attach(walker: CharacterBody3D, profile_id: StringName) -> Footsteps:
	var steps := Footsteps.new()
	steps.name = "Footsteps"
	steps.profile = profile_id
	walker.add_child(steps)
	return steps


## Every take of [param set] (loaded once).
static func takes_of(set_name: StringName) -> Array[AudioStream]:
	if not _takes.has(set_name):
		var takes: Array[AudioStream] = []
		for n in range(1, 13):
			var path := DIR + "%s_%d.wav" % [set_name, n]
			if not ResourceLoader.exists(path):
				break
			takes.append(load(path))
		_takes[set_name] = takes
	return _takes[set_name]


func _ready() -> void:
	body = get_parent() as CharacterBody3D
	_rng.randomize()
	var flat := is_flat()
	for i in VOICES:
		var voice: Node
		if flat:
			voice = AudioStreamPlayer.new()
		else:
			var spatial := AudioStreamPlayer3D.new()
			spatial.unit_size = 5.0
			spatial.max_distance = HEAR_DISTANCE
			spatial.area_mask |= Layers.REVERB_ZONE
			voice = spatial
		voice.set(&"bus", BUS)
		add_child(voice)
		_voices.append(voice)
	_was_on_floor = body != null and body.is_on_floor()
	if Sfx.has_signal(&"quitting"):
		Sfx.connect(&"quitting", _on_quitting)


## The game quits: no step may still be playing when the engine goes.
func _on_quitting() -> void:
	set_physics_process(false)
	for voice in _voices:
		voice.call(&"stop")


func is_flat() -> bool:
	return bool(_setting("flat", false))


func _physics_process(delta: float) -> void:
	if body == null or not body.is_inside_tree():
		return
	var on_floor := body.is_on_floor()
	var motion := body.get_real_velocity()
	if not on_floor:
		_fall_speed = maxf(_fall_speed, -motion.y)
	if on_floor and not _was_on_floor:
		land(_fall_speed)
	elif not on_floor and _was_on_floor and motion.y > JUMP_SPEED:
		jump()
	if on_floor:
		_fall_speed = 0.0
	_was_on_floor = on_floor
	advance(delta, Vector2(motion.x, motion.z).length(), on_floor)


## Walks [param speed] m/s for [param delta] s; steps when a stride is
## covered. Returns true when a step sounded.
func advance(delta: float, speed: float, on_floor: bool) -> bool:
	if not on_floor or speed < float(_setting("min_speed", 0.5)):
		_moving = false
		_travel = 0.0
		return false
	var stride := stride_for(speed)
	if not _moving:
		_moving = true
		_travel = stride * 0.55   # the first step comes soon after setting off
	_travel += speed * delta
	if _travel < stride:
		return false
	_travel -= stride
	step(speed)
	return true


## Metres between steps at [param speed].
func stride_for(speed: float) -> float:
	return float(_setting("stride", 1.5)) * sqrt(maxf(speed, 0.1) / float(_setting("speed", 3.0)))


## Steps per second at [param speed].
func cadence(speed: float) -> float:
	return speed / stride_for(speed)


func step(speed: float = 0.0) -> void:
	surface = probe_surface()
	steps_taken += 1
	var level := float(_setting("db", -8.0))
	var running := speed >= float(_setting("gear_speed", INF))
	if running:
		level += RUN_BOOST_DB
	_play(step_set(surface), level)
	if _has("surface_db"):
		_play(StringName("step_" + String(surface)), float(_setting("surface_db", -12.0)))
	if running and _rng.randf() < 0.6:
		_play(&"gear", level - 1.0)
	stepped.emit(surface)


## The takes a step on [param ground] uses.
func step_set(ground: StringName) -> StringName:
	if _has("set"):
		if ground == Surface.CARPET and _has("soft_set"):
			return _setting("soft_set", &"")
		return _setting("set", &"")
	return StringName("step_" + String(ground))


func land(fall_speed: float) -> void:
	if fall_speed < LANDING_SPEED:
		return
	surface = probe_surface()
	var weight := clampf(inverse_lerp(LANDING_SPEED, HARD_LANDING, fall_speed), 0.0, 1.0)
	var level := float(_setting("db", -8.0)) + lerpf(-4.0, 4.0, weight)
	if _has("set"):
		_play(step_set(surface), level + 2.0)
	else:
		_play(StringName("land_" + String(surface)), level)
	_travel = 0.0
	landed.emit(fall_speed)


func jump() -> void:
	if not _has("set"):
		_play(&"jump", float(_setting("db", -8.0)) - 1.0)


## The surface under the body (a ray a little over a metre down).
func probe_surface() -> StringName:
	if body == null or not body.is_inside_tree():
		return Surface.STONE
	var from := body.global_position + Vector3.UP * 0.3
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.5, Layers.WORLD, [body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Surface.of(null, body.global_position, get_tree())
	return Surface.of(hit["collider"], hit["position"], get_tree())


func _play(set_name: StringName, level_db: float) -> void:
	var takes := takes_of(set_name)
	if takes.is_empty() or not _audible():
		return
	var pick := _rng.randi_range(0, takes.size() - 1)
	if takes.size() > 1 and pick == int(_last_take.get(set_name, -1)):
		pick = (pick + 1) % takes.size()
	_last_take[set_name] = pick
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.set(&"stream", takes[pick])
	voice.set(&"volume_db", level_db)
	voice.set(&"pitch_scale", 1.0 + _rng.randf_range(-PITCH_JITTER, PITCH_JITTER))
	voice.call(&"play")


func _audible() -> bool:
	if is_flat():
		return true
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	return camera == null or camera.global_position.distance_to(global_position) <= HEAR_DISTANCE


func _setting(key: String, fallback: Variant) -> Variant:
	var data: Dictionary = PROFILES.get(profile, PROFILES[&"guard"])
	return data.get(key, fallback)


func _has(key: String) -> bool:
	var data: Dictionary = PROFILES.get(profile, PROFILES[&"guard"])
	return data.has(key)
