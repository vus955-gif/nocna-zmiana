class_name TotemRig
extends ExhibitRig
## The Totem's model (model "totem", docs/art/kit-pietro1-ameryki.md 8):
## five faces stacked as nested blocks (block_k under block_k-1, pivot at
## the block's bottom), eyes_k and the face_k / mouth_k markers in each, a
## bark hat (cap) on the stump's child list. Animated in code:
## - every block turns on its own about the pole (the faces as turrets:
##   Totem.face_yaw), the nesting means each turns relative to the one
##   below;
## - the telegraph: the spitting face's eyes glow (the shader's glow on
##   that eyes part alone) and the block draws back and up a little (a
##   breath); the spit kicks it forward on a spring;
## - a hit sways the whole pole (two springs on the lowest block);
## - a face shot off: its block and eyes fly as debris (drop_block), the
##   blocks above are hidden with it, the hat falls onto the new top under
##   gravity, bounces and wobbles, the eyes left flare for FLARE_TIME;
## - waking, the faces light up from the bottom one after another (the
##   wake rim per block, Totem.wake_share);
## - a pole with fewer than five faces hides the blocks it never had and
##   wears its hat lower (set_top);
## - asleep it stops posing after a moment (the base's settle), but not
##   while a face is still turning home (a pole that dropped off with its
##   faces turned away): the model follows the faces all the way.

const BLOCKS := 5
## The telegraph's breath: how far the spitting block draws back / rises (m).
const INHALE_BACK := 0.07
const INHALE_UP := 0.03
## The spit's recoil kick (m/s on the block's spring).
const RECOIL := 0.9
## The eyes left flare this long after a face falls (s).
const FLARE_TIME := 0.4
const CAP_GRAVITY := 9.8
## The hat bounces back at this share of its landing speed (once).
const CAP_BOUNCE := 0.3
## Warm glow on the spitting face itself (not only its eyes).
const FACE_WARMTH := 0.35
## The eyes are fully on this far into the telegraph (share of the windup):
## they snap on at once, so the whole telegraph reads.
const EYES_ON := 0.12
## A face this near its place counts as home (rad).
const FACE_HOME := 0.002

var totem: Totem

var _top: int = BLOCKS
var _cap_rest_y: float = 4.6
var _cap_y: float = 4.6
var _cap_v: float = 0.0
var _cap_bounced := false
var _cap_tilt_x := Spring.new(2.6, 0.22)
var _cap_tilt_z := Spring.new(2.3, 0.22)
var _sway_x := Spring.new(1.9, 0.28)
var _sway_z := Spring.new(1.9, 0.28)
var _recoil := Spring.new(3.5, 0.5)
var _recoil_face: int = -1
var _inhale: float = 0.0
var _flare: float = 0.0
## Glow applied to each eyes part (index k - 1), to write only changes.
var _eye_glow := PackedFloat32Array()
var _eye_applied := PackedFloat32Array()
var _block_awake := PackedFloat32Array()
## The parts' names (index k - 1), made once: posed and lit every frame.
var _block_names := PackedStringArray()
var _eyes_names := PackedStringArray()


static func build(owner: Totem) -> TotemRig:
	var rig := TotemRig.new()
	rig.totem = owner
	rig.gib_density = 3.0
	return ExhibitRig.attach(owner, rig, &"totem") as TotemRig


## How bright face [param face]'s eyes glow (0..1, over 1 in a flare).
func face_glow(face: int) -> float:
	if face < 1 or face > _eye_glow.size():
		return 0.0
	return _eye_glow[face - 1]


## Where the hat sits now (enemy space, m).
func cap_height() -> float:
	return _cap_y


## The pole is [param n] faces tall: the blocks above are hidden and the
## hat sits on block n ([param instant]: it is put there, else it falls).
func set_top(n: int, instant: bool) -> void:
	_top = clampi(n, 0, BLOCKS)
	var above := part("block_%d" % (_top + 1))
	if above != null and above.visible:
		above.visible = false
		for view in meshes.duplicate():
			if is_instance_valid(view) and (view == above or above.is_ancestor_of(view)):
				meshes.erase(view)
	var goal := TotemFaces.top_of(_top)
	if instant:
		_cap_y = goal
		_cap_v = 0.0
		_cap_bounced = true
	else:
		_cap_bounced = false
		_flare = FLARE_TIME


## Face [param k]'s block and eyes fly off as debris along [param push];
## the pole above it is hidden with it and the hat starts to fall.
func drop_block(k: int, push: Vector3) -> void:
	var block := part("block_%d" % k)
	if block == null:
		set_top(k - 1, false)
		return
	var flat := Vector3(push.x, 0.0, push.z)
	flat = flat.normalized() if flat.length_squared() > 0.0001 else -enemy.global_basis.z
	for view_name in ["block_%d" % k, "eyes_%d" % k]:
		var view := part(view_name) as MeshInstance3D
		if view == null or view.mesh == null or not view.visible:
			continue
		var materials: Array = []
		for i in view.mesh.get_surface_count():
			materials.append(ArtLibrary.debris_material(view.get_active_material(i)))
		var shard := MeshShards.whole(view.mesh)
		var fling := flat * randf_range(1.5, 3.0) + Vector3(randf_range(-1.0, 1.0), randf_range(2.0, 3.5), randf_range(-1.0, 1.0))
		Fx.piece(shard, MeshShards.materials_for(shard, materials), view.global_transform, fling, 7.0)
	if k <= BLOCKS and k >= 1:
		_eye_glow[k - 1] = 0.0
	_sway_x.kick(randf_range(-1.2, 1.2))
	_sway_z.kick(randf_range(-1.2, 1.2))
	set_top(k - 1, false)


## The spit's recoil on face [param face].
func spat(face: int) -> void:
	_recoil_face = face
	_recoil.reset(0.0)
	_recoil.kick(-RECOIL)


## A hit sways the pole along [param impulse] (world).
func jolt(impulse: Vector3) -> void:
	var local := enemy.global_basis.inverse() * impulse
	_sway_x.kick(local.z * 0.35)
	_sway_z.kick(-local.x * 0.35)


func _setup() -> void:
	var cap := part("cap")
	if cap != null:
		_cap_rest_y = (rest["cap"] as Transform3D).origin.y
		_cap_y = _cap_rest_y
	_eye_glow.resize(BLOCKS)
	_eye_glow.fill(0.0)
	_eye_applied.resize(BLOCKS)
	_eye_applied.fill(-1.0)
	_block_awake.resize(BLOCKS)
	_block_awake.fill(-1.0)
	for k in range(1, BLOCKS + 1):
		_block_names.append("block_%d" % k)
		_eyes_names.append("eyes_%d" % k)


func _physics_process(delta: float) -> void:
	# the faces come home at half rate asleep: keep posing until they have
	if totem != null and _faces_turned():
		_still_frames = 0
	super(delta)


## Some face is not looking out front (rad tolerance FACE_HOME).
func _faces_turned() -> bool:
	for k in range(1, _top + 1):
		if absf(totem.face_yaw(k)) > FACE_HOME:
			return true
	return false


func _pose(delta: float) -> void:
	var brain := enemy.brain
	var w := brain.windup_progress()
	var up := w * w * (3.0 - 2.0 * w)
	var firing := totem.firing_face()
	_inhale = ExhibitRig.ease_to(_inhale, up if firing > 0 else 0.0, 14.0, delta)
	_flare = maxf(_flare - delta, 0.0)
	var sway_x := _sway_x.step(0.0, delta)
	var sway_z := _sway_z.step(0.0, delta)
	var recoil := _recoil.step(0.0, delta) if _recoil_face > 0 else 0.0
	var below := 0.0
	for k in range(1, BLOCKS + 1):
		var yaw := totem.face_yaw(k)
		var local := angle_difference(below, yaw)
		below = yaw
		if k > _top:
			continue
		var shift := Vector3.ZERO
		if k == firing:
			shift = Vector3(0.0, INHALE_UP * _inhale, INHALE_BACK * _inhale)
		if k == _recoil_face:
			shift.z += recoil
		var tilt := Vector3(sway_x * 0.06, local, sway_z * 0.06) if k == 1 else Vector3(0.0, local, 0.0)
		pose_part(_block_names[k - 1], tilt, shift)
		var glow := 0.0
		if k == firing:
			glow = MotionClip.eased(MotionClip.OUT, minf(w / EYES_ON, 1.0))
		if _flare > 0.0:
			glow = maxf(glow, 1.4 * _flare / FLARE_TIME)
		_eye_glow[k - 1] = glow
	_pose_cap(delta)


## The hat: falls onto the top block, bounces once and wobbles.
func _pose_cap(delta: float) -> void:
	var cap := part("cap")
	if cap == null:
		return
	var goal := TotemFaces.top_of(_top)
	if _cap_y > goal + 0.001:
		_cap_v -= CAP_GRAVITY * delta
		_cap_y += _cap_v * delta
		if _cap_y <= goal:
			_cap_y = goal
			if not _cap_bounced and _cap_v < -1.0:
				_cap_bounced = true
				_cap_tilt_x.kick(randf_range(-2.5, 2.5))
				_cap_tilt_z.kick(randf_range(-2.5, 2.5))
				Sfx.play_at(&"hit_wood", enemy.global_position + Vector3.UP * goal, -8.0, 0.1, 0.8)
				_cap_v = -_cap_v * CAP_BOUNCE
			else:
				_cap_v = 0.0
	var tilt_x := _cap_tilt_x.step(0.0, delta)
	var tilt_z := _cap_tilt_z.step(0.0, delta)
	pose_part("cap", Vector3(tilt_x * 0.08, 0.0, tilt_z * 0.08), Vector3(0.0, _cap_y - _cap_rest_y, 0.0))


## The eyes glow on their own parts, not the whole pole.
func _glow_amount() -> float:
	return 0.0


func _update_shading(delta: float) -> void:
	var before := _shading
	super(delta)
	var rewritten := before != _shading   # the base wrote glow 0 on every mesh
	var firing := totem.firing_face()
	for k in range(1, BLOCKS + 1):
		var eyes := part(_eyes_names[k - 1]) as MeshInstance3D
		var block := part(_block_names[k - 1]) as MeshInstance3D
		var glow := _eye_glow[k - 1]
		if rewritten or not is_equal_approx(glow, _eye_applied[k - 1]):
			_eye_applied[k - 1] = glow
			if eyes != null and eyes.visible:
				eyes.set_instance_shader_parameter(&"glow", minf(glow, 1.0))
			if block != null and block.visible:
				block.set_instance_shader_parameter(&"glow", FACE_WARMTH * glow if k == firing else 0.0)
		# waking from the bottom up: each block's rim comes up in its turn
		var share := totem.wake_share(k)
		var awake := _shading.x * share
		if not is_equal_approx(awake, _block_awake[k - 1]):
			_block_awake[k - 1] = awake
			for view in [block, eyes]:
				if view != null:
					view.set_instance_shader_parameter(&"awake", awake)
