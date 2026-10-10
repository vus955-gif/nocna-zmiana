extends Node
## The Centaur's poses for the eye (bash tools/run_guardian.sh centaur
## --poses; headless, not part of the suite): its rig, moves, gait and brain
## without the museum, driven through every move - the gaits seen from the
## side over one stride, a galloping turn from behind, the throw (single
## and paired), the rearing kick, the buck, the charge's scrape and run, the
## stun, the call, the tear and the waking - each a strip of frames written
## as part transforms (body space) to tests/_out/guardian_centaur/poses.json.
## tools/art/guardian_poses.py renders each strip in Blender as a filmstrip
## (poses_<strip>.png): the way to judge the animation without a window.

const STEP := 1.0 / 60.0
const OUT := "res://tests/_out/guardian_centaur/"

var holder: Node3D
var rig: CentaurRig
var moves: CentaurMoves
var gait: CentaurGait
var brain: CentaurBrain
var body := Transform3D.IDENTITY
var velocity := Vector3.ZERO
var strips: Array = []


func _ready() -> void:
	holder = Node3D.new()
	add_child(holder)
	rig = CentaurRig.create(holder)
	await get_tree().process_frame
	_gaits()
	_turn()
	_throw(false)
	_throw(true)
	_attack(&"kick", CentaurBrain.Attack.KICK, Vector3(0.0, 1.5, -3.0), [0.0, 0.1, 0.3, 0.5, 0.66, 0.85, 1.0, 1.15, 1.6, 2.5])
	_attack(&"buck", CentaurBrain.Attack.BUCK, Vector3(0.6, 1.5, 3.0), [0.0, 0.3, 0.6, 0.9, 1.0, 1.08, 1.15, 1.4, 2.0, 2.8])
	_charge()
	_attack(&"call", CentaurBrain.Attack.CALL, Vector3(0.0, 1.5, -10.0), [0.0, 0.15, 0.35, 0.6, 0.8, 0.95, 1.0, 1.3, 2.0, 2.9])
	_tear()
	_stun()
	_wake()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var file := FileAccess.open(ProjectSettings.globalize_path(OUT.path_join("poses.json")), FileAccess.WRITE)
	file.store_string(JSON.stringify({"strips": strips}))
	file.close()
	print("centaur poses: %d strips" % strips.size())
	get_tree().quit(0)


func _fresh() -> void:
	moves = CentaurMoves.new(rig)
	gait = CentaurGait.new()
	brain = CentaurBrain.new()
	brain.seed_with(3)
	body = Transform3D.IDENTITY
	velocity = Vector3.ZERO
	gait.place(body)
	brain.wake()
	_steps(CentaurBrain.WAKE_TIME + 0.1, 0.0, 0.0)


## Advances [param seconds]: the body runs at [param speed] along its
## facing, turning [param turn] rad/s; the brain sees the guard at
## moves.guard.
func _steps(seconds: float, speed: float, turn: float) -> void:
	for i in roundi(seconds / STEP):
		_step(speed, turn)


func _step(speed: float, turn: float) -> void:
	var yaw := Basis(Vector3.UP, turn * STEP) * body.basis
	velocity = yaw * Vector3.FORWARD * speed
	body = Transform3D(yaw, body.origin + velocity * STEP)
	var flat := Vector2(moves.guard.x, moves.guard.z)
	brain.update(STEP, flat.length(), atan2(-moves.guard.x, -moves.guard.z))
	gait.update(STEP, body, velocity)
	holder.transform = body
	rig.apply(moves.compose(brain, gait, body, STEP), STEP)


func _frame(label: String) -> Dictionary:
	var parts := {}
	var inverse := holder.global_transform.affine_inverse()
	for name: String in rig.parts:
		var node := rig.parts[name] as Node3D
		parts[name] = _flat(inverse * node.global_transform)
	if rig.left_javelin != null:
		parts["javelin_left"] = _flat(inverse * rig.left_javelin.global_transform)
	var shown := {"javelin": rig.part("javelin").visible, "slab": rig.part("slab").visible,
		"javelin_left": rig.left_javelin != null and rig.left_javelin.visible}
	return {"label": label, "parts": parts, "shown": shown}


static func _flat(xform: Transform3D) -> Array:
	var b := xform.basis
	return [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z, xform.origin.x, xform.origin.y, xform.origin.z]


func _strip(name: String, view: String, frames: Array) -> void:
	strips.append({"name": name, "view": view, "frames": frames})


# --- the strips ---------------------------------------------------------------------

func _gaits() -> void:
	for entry: Array in [["gallop", 10.5], ["canter", 5.6], ["trot", 2.9], ["walk", 1.0], ["charge_run", 15.5]]:
		_fresh()
		moves.guard = Vector3(-6.0, 1.5, -14.0)
		var speed: float = entry[1]
		for i in 120:
			_step(speed * minf(1.0, i / 60.0), 0.0)
		_steps(1.5, speed, 0.0)
		var period := 1.0 / gait.frequency
		var frames: Array = []
		for k in 10:
			frames.append(_frame("%.2f" % (k / 10.0)))
			_steps(period / 10.0, speed, 0.0)
		_strip(entry[0], "side", frames)


func _turn() -> void:
	_fresh()
	moves.guard = Vector3(-8.0, 1.5, -8.0)
	for i in 120:
		_step(10.0 * minf(1.0, i / 60.0), 0.0)
	var frames: Array = []
	for k in 8:
		_steps(0.12, 10.0, 1.2)
		frames.append(_frame("turn %d" % k))
	_strip("turn", "back", frames)


func _throw(pair: bool) -> void:
	_fresh()
	if pair:
		brain.set_phase(3)
		brain.pair = true
		brain.phase = 3
	moves.guard = Vector3(-7.0, 1.5, -10.0)
	var target := Vector3(-7.0, 0.0, -10.0)
	for side in 2:
		var hand := Vector3(0.4 if side == 1 else -0.4, 2.6, -0.8)
		moves.throw_dir[side] = CentaurJavelin.launch_velocity(hand, target, 0.9, CentaurJavelin.GRAVITY).normalized()
	_steps(1.0, 5.5, 0.0)
	brain.force_attack(CentaurBrain.Attack.THROW)
	_sample(&"throw_pair" if pair else &"throw", [0.0, 0.3, 0.6, 0.85, 0.97, 1.03, 1.15, 1.45, 2.2, 2.9], 5.5, "three_quarter")


func _attack(name: StringName, kind: CentaurBrain.Attack, guard: Vector3, times: Array) -> void:
	_fresh()
	moves.guard = guard
	brain.force_attack(kind)
	_sample(name, times, 0.0, "side" if kind != CentaurBrain.Attack.BUCK else "side")


func _charge() -> void:
	_fresh()
	moves.guard = Vector3(0.0, 1.5, -16.0)
	brain.force_attack(CentaurBrain.Attack.CHARGE)
	_sample(&"charge", [0.0, 0.2, 0.35, 0.45, 0.6, 0.75, 0.9, 1.0], 0.0, "side")


func _tear() -> void:
	_fresh()
	brain.set_phase(3)
	moves.guard = Vector3(-4.0, 1.5, -10.0)
	brain.force_attack(CentaurBrain.Attack.TEAR)
	_sample(&"tear", [0.0, 0.4, 0.75, 1.0, 1.15, 1.4, 2.0, 2.45, 2.7, 3.0], 0.0, "three_quarter_left")


func _stun() -> void:
	_fresh()
	moves.guard = Vector3(-3.0, 1.5, -8.0)
	brain.force_attack(CentaurBrain.Attack.CHARGE)
	_steps(CentaurBrain.stage_length(CentaurBrain.Attack.CHARGE, CentaurBrain.Stage.TELEGRAPH, 1) + 0.05, 0.0, 0.0)
	brain.crash()
	var frames: Array = []
	var length := CentaurBrain.STUN_TIME[0]
	for k in 8:
		frames.append(_frame("%.1fs" % (k * length / 8.0)))
		_steps(length / 8.0, 0.0, 0.0)
	_strip("stun", "three_quarter", frames)


func _wake() -> void:
	moves = CentaurMoves.new(rig)
	gait = CentaurGait.new()
	brain = CentaurBrain.new()
	body = Transform3D.IDENTITY
	gait.place(body)
	moves.guard = Vector3(8.0, 1.5, -6.0)
	_step(0.0, 0.0)
	var frames: Array = [_frame("asleep")]
	brain.wake()
	var marks: Array[float] = [0.1, 0.25, 0.38, 0.47, 0.53, 0.6, 0.66, 0.78, 0.95]
	var u := 0.0
	for mark in marks:
		while brain.state == CentaurBrain.State.WAKING and brain.state_progress() < mark:
			# it turns toward the guard as it comes down (the node does this)
			var turning := 1.6 if brain.state_progress() > 0.52 else 0.0
			_step(0.0, -turning)
		frames.append(_frame("%.2f" % mark))
		u = mark
	_strip("wake", "three_quarter", frames)


## Frames of the attack under way at clip times [param times] (it runs at
## [param speed]).
func _sample(name: StringName, times: Array, speed: float, view: String) -> void:
	var frames: Array = []
	for time: float in times:
		var guard := 0
		while brain.state == CentaurBrain.State.ATTACK and brain.clip_time() < time - 0.0001 and guard < 600:
			_step(speed, 0.0)
			guard += 1
		frames.append(_frame("t %.2f" % time))
	_strip(String(name), view, frames)
