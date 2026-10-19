class_name ShakeCamera
extends Camera3D
## First-person camera: trauma-based shake (see Trauma) driven by
## Events.shake_requested, short FOV kicks (dash, a heavy shot), a weapon's
## kick (kick(): a spring on pitch and yaw over the aim, plan
## 2026-10-19-gun-feel) and a blast's push (feel_blast()). The kick sits on
## top of the head's turn and always springs back: the aim never drifts.
## The guard's walking bob and landing dip come in through [member motion]
## and [member motion_fov] (Player). [member shake_scale] is the screen
## shake option: it scales the shake, the kick, the blasts' push and the
## FOV kicks (a heavy shot, a dash, a stagger).

const PITCH := 0
const YAW := 1
## The kick never takes the view further than this (degrees): a burst
## climbs to it and holds.
const KICK_PITCH_MAX := 4.0
const KICK_YAW_MAX := 2.0
## A blast is felt within this many of its radii (at least BLAST_REACH_MIN
## metres), its trauma at most BLAST_TRAUMA (and never past BLAST_CAP),
## its push at most BLAST_PITCH degrees up and BLAST_YAW away from it.
const BLAST_REACH := 5.0
const BLAST_REACH_MIN := 6.0
const BLAST_TRAUMA := 0.45
const BLAST_CAP := 0.6
const BLAST_PITCH := 1.4
const BLAST_YAW := 0.8

@export var base_fov: float = 70.0
@export var max_offset: float = 0.06
@export var max_roll_deg: float = 2.0

var trauma := Trauma.new()
## The kick (degrees): PITCH up, YAW to the left.
var recoil := Recoil.new(2, 6.0, 0.9)
## The screen shake option (0..1).
var shake_scale: float = 1.0
## Walking bob and landing dip (m, in the head's space) and the sprint's
## widening of the view (degrees), set by the Player every frame.
var motion := Vector3.ZERO
var motion_fov: float = 0.0
var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _fov_kick: float = 0.0


func _ready() -> void:
	fov = base_fov
	near = 0.05
	_noise.frequency = 18.0
	Events.shake_requested.connect(add_trauma)


## Raises the trauma by [param amount], but past [param cap] only as far as
## the cap (a weapon's run of shots rumbles at its own level instead of
## piling up to full shake); trauma already above the cap stays.
func add_trauma(amount: float, cap: float = 1.0) -> void:
	if amount <= 0.0:
		return
	if cap >= 1.0:
		trauma.add(amount)
	else:
		trauma.value = maxf(trauma.value, minf(trauma.value + amount, cap))


func kick_fov(degrees: float) -> void:
	_fov_kick = maxf(_fov_kick, degrees)


## A weapon's kick: the view jumps [param pitch_deg] up and [param yaw_deg]
## sideways (as peaks from rest) and springs back with [param frequency]
## (Hz) and [param damping].
func kick(pitch_deg: float, yaw_deg: float, frequency: float = 6.0, damping: float = 0.9) -> void:
	recoil.tune(frequency, damping)
	recoil.kick(PITCH, pitch_deg)
	recoil.kick(YAW, yaw_deg)


## A blast at [param center] of [param radius] m: within reach the view
## shakes and is pushed up and away from it, the more the closer.
func feel_blast(center: Vector3, radius: float, strength: float = 1.0) -> void:
	if not is_inside_tree():
		return
	var to := global_position - center
	var reach := maxf(radius * BLAST_REACH, BLAST_REACH_MIN)
	var distance := to.length()
	if distance >= reach:
		return
	var near_share := 1.0 - distance / reach
	add_trauma(BLAST_TRAUMA * near_share * near_share * strength, BLAST_CAP)
	var side := (global_basis.inverse() * to).x if distance > 0.01 else 0.0
	kick(BLAST_PITCH * near_share * strength, clampf(side, -1.0, 1.0) * BLAST_YAW * near_share * strength, 5.0, 0.7)


## The kick now (degrees: x pitch, y yaw), before the shake option.
func kick_angles() -> Vector2:
	return Vector2(recoil.value(PITCH), recoil.value(YAW))


func _process(delta: float) -> void:
	_time += delta
	trauma.tick(delta)
	recoil.step(delta)
	recoil.limit(PITCH, KICK_PITCH_MAX)
	recoil.limit(YAW, KICK_YAW_MAX)
	var strength := trauma.strength() * shake_scale
	h_offset = max_offset * strength * _noise.get_noise_2d(_time, 0.0)
	v_offset = max_offset * strength * _noise.get_noise_2d(0.0, _time)
	rotation = Vector3(deg_to_rad(recoil.value(PITCH)) * shake_scale, deg_to_rad(recoil.value(YAW)) * shake_scale,
			deg_to_rad(max_roll_deg) * strength * _noise.get_noise_2d(_time, 50.0))
	position = motion
	_fov_kick = move_toward(_fov_kick, 0.0, 40.0 * delta)
	fov = base_fov + _fov_kick * shake_scale + motion_fov
