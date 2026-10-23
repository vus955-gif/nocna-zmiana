class_name PaintingGaze
extends Node
## Where a plain painting's eyes look (plan 2026-10-21-eskalacja-nocy):
## the uncanny cousin of a Portrait's watch, on a WallPainting that never
## wakes. A look is -1..1 of the eyes' reach (x toward the painting's +X,
## the viewer's left; y up), the PortraitRig's convention:
## - with the Blender model the irises slide on the eye patch's material
##   (uv1_offset; the painting gets its own copy, the shared one is never
##   touched),
## - on the greybox the pupils move within Portrait.PUPIL_TRAVEL.
## As a node (follow()) it makes the eyes follow a target for a while and
## then go back to looking straight out, and frees itself.

## Gains and limits of the look toward a point (the PortraitRig's).
const LOOK_GAIN := Vector2(1.8, 2.4)
const LOOK_LIMIT := Vector2(0.7, 0.6)
## How fast the eyes turn (1/s) and how long they take to settle back.
const LOOK_RATE := 6.0
const SETTLE := 0.8
## The target counts as in front of the painting when it stands at least
## this far out of the wall along its face (m).
const IN_FRONT := 0.5

const META_LOOK := &"gaze_look"
const META_MATERIAL := &"gaze_material"

var painting: WallPainting
var target: Node3D
## Seconds left of following.
var left: float = 0.0
var _look := Vector2.ZERO
var _settling := 0.0


## Makes [param of]'s eyes follow [param who] for [param seconds] (null for
## a painting without a face).
static func follow(of: WallPainting, who: Node3D, seconds: float) -> PaintingGaze:
	if not has_eyes(of):
		return null
	for child in of.get_children():
		if child is PaintingGaze:
			child.queue_free()
	var gaze := PaintingGaze.new()
	gaze.name = "Gaze"
	gaze.painting = of
	gaze.target = who
	gaze.left = seconds
	gaze._look = look_of(of)
	of.add_child(gaze)
	return gaze


## True when [param of] shows a face with eyes that can move.
static func has_eyes(of: WallPainting) -> bool:
	if of == null or not is_instance_valid(of) or not PaintingArt.has_face(of.painting_id):
		return false
	if of.model != null:
		return _eye_mesh(of) != null
	return of.parts.has("pupil_l") and of.parts.has("pupil_r")


## The look [param of] was last given (ZERO: straight out).
static func look_of(of: WallPainting) -> Vector2:
	return of.get_meta(META_LOOK, Vector2.ZERO)


## Points [param of]'s eyes at [param look]. False for a painting without
## movable eyes.
static func set_look(of: WallPainting, look: Vector2) -> bool:
	if not has_eyes(of):
		return false
	var clamped := Vector2(clampf(look.x, -1.0, 1.0), clampf(look.y, -1.0, 1.0))
	of.set_meta(META_LOOK, clamped)
	if of.model != null:
		var material := _own_material(of)
		if material == null:
			return false
		var offset := clamped * ArtLibrary.PORTRAIT_EYES_REACH
		material.uv1_offset = Vector3(offset.x, offset.y, 0.0)
		return true
	var shift := Vector2(clamped.x / LOOK_LIMIT.x, clamped.y / LOOK_LIMIT.y).clamp(-Vector2.ONE, Vector2.ONE) * Portrait.PUPIL_TRAVEL
	for side in ["l", "r"]:
		var pupil: Node3D = of.parts["pupil_" + side]
		var eye: Node3D = of.parts["eye_" + side]
		pupil.position = Vector3(eye.position.x + shift.x, eye.position.y + shift.y, pupil.position.z)
	return true


## The look that points [param of]'s eyes at [param point] (world).
static func look_toward(of: Node3D, point: Vector3) -> Vector2:
	var local := of.global_transform.affine_inverse() * point
	var eyes := _eyes_local(of)
	var to := (local - eyes).normalized()
	return Vector2(clampf(to.x * LOOK_GAIN.x, -LOOK_LIMIT.x, LOOK_LIMIT.x), clampf(to.y * LOOK_GAIN.y, -LOOK_LIMIT.y, LOOK_LIMIT.y))


## True when [param point] stands in front of [param of]'s face (not behind
## its wall).
static func in_front(of: Node3D, point: Vector3) -> bool:
	return (of.global_transform.affine_inverse() * point).z < -IN_FRONT


static func _eyes_local(of: Node3D) -> Vector3:
	var painting := of as WallPainting
	if painting != null and painting.model != null:
		return PaintingArt.model_eye(0.0)
	var left_eye := PaintingArt.canvas_point(PaintingArt.EYE_TEXEL_L)
	var right_eye := PaintingArt.canvas_point(PaintingArt.EYE_TEXEL_R)
	return Vector3((left_eye.x + right_eye.x) * 0.5, left_eye.y, PaintingArt.CANVAS_Z)


static func _eye_mesh(of: WallPainting) -> MeshInstance3D:
	var eyes := of.model.find_child("eyes", true, false) as MeshInstance3D
	return eyes if eyes != null and eyes.visible and eyes.mesh != null else null


## The painting's own copy of the eye material (made the first time).
static func _own_material(of: WallPainting) -> BaseMaterial3D:
	if of.has_meta(META_MATERIAL):
		return of.get_meta(META_MATERIAL) as BaseMaterial3D
	var eyes := _eye_mesh(of)
	if eyes == null:
		return null
	var source := ArtLibrary.material(ArtLibrary.PORTRAIT_EYES_MATERIAL) as BaseMaterial3D
	if source == null:
		source = eyes.get_active_material(0) as BaseMaterial3D
	if source == null:
		return null
	var own := source.duplicate() as BaseMaterial3D
	for i in eyes.mesh.get_surface_count():
		eyes.set_surface_override_material(i, own)
	of.set_meta(META_MATERIAL, own)
	return own


func _process(delta: float) -> void:
	if not is_instance_valid(painting):
		queue_free()
		return
	var goal := Vector2.ZERO
	left -= delta
	if left > 0.0 and is_instance_valid(target) and in_front(painting, target.global_position + Vector3.UP * 1.5):
		goal = look_toward(painting, target.global_position + Vector3.UP * 1.5)
	elif left <= 0.0:
		_settling += delta
	_look = _look.lerp(goal, 1.0 - exp(-LOOK_RATE * delta))
	if left <= 0.0 and _settling >= SETTLE:
		_look = Vector2.ZERO
		set_look(painting, _look)
		queue_free()
		return
	set_look(painting, _look)
