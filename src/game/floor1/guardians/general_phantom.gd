class_name GeneralPhantom
extends Node3D
## The General's double in the feint of his phase 3 (General): a second
## copy of the model with a rig and moves of its own, no hit zones, no
## blade's glint and no damage. It steps out of the whirl of petals beside
## him, gets a lane on the gravel like his, lunges down it
## GeneralBrain.FEINT_PHANTOM_LEAD s before the real blade and bursts into
## petals where its dash ends. Hidden between feints.
## World space (top_level): the General places it.

var rig: GeneralRig
var moves: GeneralMoves
var feet := GeneralFootwork.new()
var lane: GroundMark
## Its dash's line (world).
var dash_from := Vector3.ZERO
var dash_to := Vector3.ZERO
var dash_dir := Vector3.FORWARD
## Shown (a feint under way).
var active := false
## Its dash runs now; it ran and burst.
var dashing := false
var burst := false

var _speed: float = 0.0
var _look: Node3D


func _init() -> void:
	top_level = true
	name = "GeneralPhantom"


func _ready() -> void:
	_look = Node3D.new()
	_look.name = "Look"
	add_child(_look)
	rig = GeneralRig.create(_look)
	moves = GeneralMoves.new(rig)
	visible = false


## It steps out of the whirl at [param at], the General's frame.
func appear(at: Transform3D) -> void:
	global_transform = at
	reset_physics_interpolation()
	feet.place(global_transform)
	moves.reset()
	active = true
	dashing = false
	burst = false
	_speed = 0.0
	visible = true


## It is gone (the burst, a stun, the reset).
func vanish() -> void:
	active = false
	dashing = false
	visible = false
	clear_lane()


func clear_lane(fade: float = 0.25) -> void:
	if lane != null and is_instance_valid(lane):
		lane.vanish(fade)
	lane = null


## One frame: posed from the General's [param brain] at the clip time
## [param clip_time] (its own, ahead of the General's), facing
## [param guard] (world), moving by [param velocity] (world, the sidestep)
## or along its dash at [param dash_progress] (0..1, -1 = not dashing).
func frame(brain: GeneralBrain, clip_time: float, guard: Vector3, velocity: Vector3, dash_progress: float, delta: float) -> void:
	if not active:
		return
	if dash_progress >= 0.0:
		var k := MotionClip.eased(MotionClip.OUT, clampf(dash_progress, 0.0, 1.0))
		global_position = dash_from.lerp(dash_to, k)
		velocity = dash_dir * 30.0
	else:
		global_position += velocity * delta
		var to := guard - global_position
		var yaw := atan2(-to.x, -to.z)
		var gap := wrapf(yaw - rotation.y, -PI, PI)
		rotation.y = wrapf(rotation.y + clampf(gap, -3.2 * delta, 3.2 * delta), -PI, PI)
	feet.update(delta, global_transform, velocity)
	moves.guard = to_local(guard + Vector3.UP * 1.4)
	moves.clip_shift = clip_time - brain.clip_time()
	var pose := moves.compose(brain, feet, global_transform, delta)
	pose.glint = 0.0   # never: the tell
	rig.apply(pose, delta)
