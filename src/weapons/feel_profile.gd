class_name FeelProfile
extends Resource
## How one weapon feels in the hand and on its target (plan
## 2026-10-19-gun-feel): the kick of its model and of the camera, its share
## of screen shake, muzzle flash, smoke and casings, tracer, how its shot
## sounds, and how heavy its hits land (an exhibit's flinch or stagger, a
## kill that crumbles or is blown apart, the mark it leaves on a wall).
## One file per weapon: res://src/weapons/feel/<weapon id>.tres; of() finds
## it (a weapon without one feels like a neutral default). Numbers only:
## the code that plays them is the same for every weapon.

const DIR := "res://src/weapons/feel/"

@export var id: StringName = &""

@export_group("Model kick")
## Peaks a single shot gives the first-person model, from rest: back toward
## the eye and up (m), sideways (m, random side), muzzle climb (degrees),
## yaw and roll (degrees, random side).
@export var kick_back: float = 0.03
@export var kick_rise: float = 0.0
@export var kick_side: float = 0.0
@export var kick_pitch: float = 4.0
@export var kick_yaw: float = 0.0
@export var kick_roll: float = 0.0
## The kick's spring: how quickly it comes back (Hz) and how much it swings
## past rest on the way (1 = not at all, 0.5 = a heavy gun's bounce).
@export var kick_frequency: float = 8.0
@export var kick_damping: float = 0.8

@export_group("Camera")
## The view's kick (degrees: up, and sideways to a random side) and its
## spring. The aim never moves: the kick sits on top of it and comes back.
@export var camera_pitch: float = 0.0
@export var camera_yaw: float = 0.0
@export var camera_frequency: float = 6.0
@export var camera_damping: float = 0.9
## A short widening of the view (degrees).
@export var fov_punch: float = 0.0
## Screen shake of a shot (trauma) and the most a run of shots builds up to.
@export var shake: float = 0.1
@export var shake_cap: float = 0.5
## Extra trauma when the shot lands on an exhibit (the blow felt).
@export var hit_shake: float = 0.0

@export_group("Muzzle")
## The fire star at the muzzle (m across; 0 = none: the model has its own),
## its colour and how long it shows (s).
@export var flash_size: float = 0.0
@export var flash_color: Color = Color(1.0, 0.85, 0.6)
@export var flash_time: float = 0.05
## The flash's light on the world around the guard.
@export var light_color: Color = Color(1.0, 0.8, 0.5)
@export var light_energy: float = 3.0
@export var light_range: float = 7.0
@export var light_time: float = 0.06
## Puffs of smoke from the muzzle after a shot, and their colour.
@export var smoke: int = 0
@export var smoke_color: Color = Color(0.7, 0.7, 0.72, 0.5)
## Casings thrown out per shot, and the most its action throws when it
## opens (a bolt run back, a break action opened: ViewmodelRig asks
## WeaponHolder.eject()); their colour, size (m), where they leave from
## (the guard's view space, from the muzzle: x right, y up, z toward the
## eye) and how they fly (m/s, same space).
@export var casings: int = 0
@export var breech_casings: int = 0
@export var casing_color: Color = Color(0.86, 0.66, 0.3)
@export var casing_size: Vector3 = Vector3(0.009, 0.009, 0.02)
@export var eject_offset: Vector3 = Vector3(0.0, 0.02, 0.12)
@export var eject_velocity: Vector3 = Vector3(1.5, 1.4, 0.3)

@export_group("Tracer")
@export var tracer_color: Color = Color(1.0, 0.85, 0.55)
@export var tracer_width: float = 0.012
@export var tracer_time: float = 0.05

@export_group("Sound")
## The shot's sound: level (dB), pitch and how much the pitch varies.
@export var sound_db: float = 0.0
@export var sound_pitch: float = 1.0
@export var sound_jitter: float = 0.06

@export_group("Hit")
## How heavy a hit lands, 0..1 (HitFeel: flinch, stagger, a kill that
## crumbles or is blown apart); a shotgun's pellets share it. A blast of
## this weapon lands with blast_weight.
@export var hit_weight: float = 0.3
@export var blast_weight: float = 0.4
## The mark a shot leaves on a wall (m across).
@export var decal_size: float = 0.1

static var _cache: Dictionary = {}
## Weapon id -> whether it has a profile file (has(): one lookup each).
static var _known: Dictionary = {}
static var _neutral: FeelProfile = null


## The profile of weapon [param weapon_id] (a neutral one when it has none).
static func of(weapon_id: StringName) -> FeelProfile:
	if _cache.has(weapon_id):
		return _cache[weapon_id]
	var path := DIR + String(weapon_id) + ".tres"
	var found: FeelProfile = null
	if weapon_id != &"" and ResourceLoader.exists(path):
		found = load(path) as FeelProfile
	if found == null:
		if _neutral == null:
			_neutral = FeelProfile.new()
		found = _neutral
	_cache[weapon_id] = found
	return found


## True when weapon [param weapon_id] has a profile file of its own (the
## file is looked up once per weapon: every hit asks).
static func has(weapon_id: StringName) -> bool:
	if weapon_id == &"":
		return false
	if not _known.has(weapon_id):
		_known[weapon_id] = ResourceLoader.exists(DIR + String(weapon_id) + ".tres")
	return _known[weapon_id]
