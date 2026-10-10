class_name PortraitRig
extends ExhibitRig
## A living portrait on its Blender model (PaintingArt.model with the
## exhibit shader; the same face a plain painting of its id shows):
## - its eyes follow the guard while it watches, the irises sliding on the
##   eye patch's own material (uv1_offset within
##   ArtLibrary.PORTRAIT_EYES_REACH), smoothly, and back to the middle when
##   it stops; a taser shuts them (lids in the colour of the painted face);
## - the silhouette lights up only once the frame comes out (watching is
##   the eyes' secret), and the frame shudders as it pushes out (the whole
##   exhibit moves: Portrait.pushed);
## - the spit is telegraphed by a gob of its paint welling up at the
##   painted mouth, glowing and lighting the canvas in the paint's colour;
## - broken, the frame splinters (MeshShards slices) and the canvas tears
##   into shreds (PanelShards).

## Eye reach (fraction of PORTRAIT_EYES_REACH) per unit of the sideways /
## upward part of the direction to the guard, and the most they use of it
## (past that the iris slides off the almond of the eye).
const LOOK_GAIN := Vector2(1.8, 2.4)
const LOOK_LIMIT := Vector2(0.7, 0.6)
const LOOK_RATE := 9.0
## Iris travel in metres per unit of uv1_offset (the eye patch's UV scale).
const IRIS_PER_UV := Vector2(0.0625, 0.0314)
const GOB_RADIUS := 0.05
const GOB_LIGHT := 2.4
const SHUDDER_TIME := 0.7
const FRAME_SPLINTERS := 6
## A heavy kill splinters it this much finer.
const GIBBED_SPLINTERS := 2
const CANVAS_SHREDS := Vector2i(3, 3)

var portrait: Portrait
var canvas_name: String = ""
## Where the eyes look: -1..1 of their reach (x: toward the painting's +X,
## the viewer's left; y: up).
var look := Vector2.ZERO

var _eye_material: BaseMaterial3D
var _applied := Vector2(INF, INF)
var _lids: Array[Node3D] = []
var _gob: MeshInstance3D
var _gob_material: StandardMaterial3D
var _gob_light: OmniLight3D
var _gob_size := 0.0
var _shudder := 0.0
var _was_pushed := false


## The rig for [param owner_portrait], or null (greybox).
static func build(owner_portrait: Portrait) -> PortraitRig:
	var loaded := PaintingArt.model(owner_portrait.painting_id, true)
	if loaded == null:
		return null
	var rig := PortraitRig.new()
	rig.portrait = owner_portrait
	rig.canvas_name = PaintingArt.canvas_for(owner_portrait.painting_id)
	return ExhibitRig.attach_model(owner_portrait, rig, loaded, loaded.transform) as PortraitRig


## How far the irises moved from the middle (m, in the painting's space).
func iris_shift() -> Vector2:
	var offset := look * ArtLibrary.PORTRAIT_EYES_REACH
	return Vector2(offset.x * IRIS_PER_UV.x, offset.y * IRIS_PER_UV.y)


## The eye patch's own material (its irises slide), null on a scene.
func eye_material() -> BaseMaterial3D:
	return _eye_material


## Painting-space position of the eye on [param side] (+1 = +X).
func eye_at(side: float) -> Vector3:
	return PaintingArt.model_eye(side)


func _setup() -> void:
	var eyes := part("eyes") as MeshInstance3D
	if eyes != null:
		meshes.erase(eyes)   # no exhibit shader on the patch
		if eyes.visible:
			var source := ArtLibrary.material(ArtLibrary.PORTRAIT_EYES_MATERIAL) as BaseMaterial3D
			_eye_material = source.duplicate() as BaseMaterial3D
			for i in eyes.mesh.get_surface_count():
				eyes.set_surface_override_material(i, _eye_material)
	# shut lids: the painted face's colour, a dark lash line
	var skin := StandardMaterial3D.new()
	skin.albedo_color = PaintingArt.skin_color(canvas_name).darkened(0.08)
	skin.roughness = 0.8
	var lash := StandardMaterial3D.new()
	lash.albedo_color = Color(0.1, 0.06, 0.04)
	lash.roughness = 0.9
	for side in [-1.0, 1.0]:
		var at := PaintingArt.model_eye(side)
		var lid := Node3D.new()
		lid.name = "lid_l" if side > 0.0 else "lid_r"
		lid.position = at + Vector3(0.0, 0.001, -0.0025)
		lid.visible = false
		add_child(lid)
		_add_box(lid, Vector3(0.036, 0.017, 0.002), Vector3.ZERO, skin)
		_add_box(lid, Vector3(0.036, 0.0025, 0.002), Vector3(0.0, -0.0065, -0.0005), lash)
		_lids.append(lid)
	# the telegraph: a gob of paint at the mouth and its glow
	var paint := PaintingArt.paint_color(portrait.painting_id)
	_gob_material = StandardMaterial3D.new()
	_gob_material.albedo_color = paint
	_gob_material.roughness = 0.15
	_gob_material.emission_enabled = true
	_gob_material.emission = paint
	_gob_material.emission_energy_multiplier = 1.5
	var ball := SphereMesh.new()
	ball.radius = GOB_RADIUS
	ball.height = GOB_RADIUS * 1.6
	ball.radial_segments = 12
	ball.rings = 6
	_gob = MeshInstance3D.new()
	_gob.name = "PaintGob"
	_gob.mesh = ball
	_gob.material_override = _gob_material
	_gob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gob.position = Vector3(PaintingArt.MODEL_MOUTH.x, PaintingArt.MODEL_MOUTH.y, PaintingArt.MODEL_CANVAS_Z - 0.01)
	_gob.scale = Vector3.ONE * 0.001
	_gob.visible = false
	add_child(_gob)
	_gob_light = OmniLight3D.new()
	_gob_light.name = "PaintGlow"
	_gob_light.light_color = paint.lerp(Color.WHITE, 0.2)
	_gob_light.light_energy = 0.0
	_gob_light.omni_range = 1.8
	_gob_light.shadow_enabled = false
	_gob_light.position = _gob.position + Vector3(0.0, 0.0, -0.3)
	_gob_light.visible = false
	add_child(_gob_light)


func _pose(delta: float) -> void:
	var state := enemy.brain.state
	var stunned := state == EnemyBrain.State.STUNNED
	# the eyes: toward the guard's head while it watches, else straight out
	var goal := Vector2.ZERO
	if portrait.eyes_tracking() and is_instance_valid(enemy.target):
		var head := enemy.global_transform.affine_inverse() * (enemy.target.global_position + Vector3.UP * 1.5)
		var to := (head - PaintingArt.model_eye(0.0)).normalized()
		goal = Vector2(clampf(to.x * LOOK_GAIN.x, -LOOK_LIMIT.x, LOOK_LIMIT.x), clampf(to.y * LOOK_GAIN.y, -LOOK_LIMIT.y, LOOK_LIMIT.y))
	look = look.lerp(goal, 1.0 - exp(-LOOK_RATE * delta))
	_apply_look()
	for lid in _lids:
		lid.visible = stunned
	# the frame shudders as it comes out of the wall
	var out := portrait.pushed > 0.001
	if out and not _was_pushed:
		_shudder = 1.0
	_was_pushed = out
	_shudder = maxf(_shudder - delta / SHUDDER_TIME, 0.0)
	var wobble := sin(time * 41.0) * 0.045 * _shudder * _shudder
	transform = Transform3D(Basis.from_euler(Vector3(wobble * 0.4, 0.0, wobble)), Vector3.ZERO)
	# the spit's telegraph: the gob wells up with the windup
	var brain := enemy.brain
	var open := brain.windup_progress() if state == EnemyBrain.State.ATTACK and not brain.has_struck() else 0.0
	_gob_size = ExhibitRig.ease_to(_gob_size, open, 18.0 if open > 0.0 else 30.0, delta)
	var shown := _gob_size > 0.02
	_gob.visible = shown
	_gob_light.visible = shown
	if shown:
		var pulse := 1.0 + 0.08 * sin(time * 30.0)
		_gob.scale = Vector3.ONE * _gob_size * pulse
		_gob_light.light_energy = GOB_LIGHT * _gob_size * _gob_size


## Wakes the rim only once the frame is out (watching stays a secret).
func _awake_goal() -> float:
	return 1.0 if portrait.vulnerable() else 0.0


## The glow of the whole painting stays low: the gob is the telegraph.
func _glow_amount() -> float:
	return enemy.brain.windup_progress() * 0.6


func _apply_look() -> void:
	if _eye_material == null:
		return
	var offset := look * ArtLibrary.PORTRAIT_EYES_REACH
	if absf(offset.x - _applied.x) < 0.002 and absf(offset.y - _applied.y) < 0.001:
		return
	_applied = offset
	_eye_material.uv1_offset = Vector3(offset.x, offset.y, 0.0)


## The splinters of the frame (both counts: a plain kill and a heavy one)
## are cut ahead of need.
func _warm_pieces() -> void:
	var frame := part("frame") as MeshInstance3D
	if frame != null:
		MeshShards.warm_slices(frame.mesh, FRAME_SPLINTERS)
		MeshShards.warm_slices(frame.mesh, FRAME_SPLINTERS + GIBBED_SPLINTERS)


## The frame splinters, the canvas tears into shreds, all flying out of the
## wall.
func shatter(center: Vector3, plan: GibPlanner.Plan, push: Vector3) -> void:
	Fx.shatter(center, enemy.material_kind, plan, push, false)
	var out := -enemy.global_basis.z
	var flat := Vector3(push.x, 0.0, push.z)
	flat = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.ZERO
	var frame := part("frame") as MeshInstance3D
	var canvas := part("canvas") as MeshInstance3D
	if frame != null:
		var splinters := FRAME_SPLINTERS + (GIBBED_SPLINTERS if plan.gibbed else 0)
		_throw(frame, MeshShards.slices(frame.mesh, splinters), center, out, flat, plan.impulse, 9.0)
	if canvas != null:
		var cells := CANVAS_SHREDS + (Vector2i.ONE if plan.gibbed else Vector2i.ZERO)
		_throw(canvas, PanelShards.cut(canvas.mesh, cells.x, cells.y), center, out, flat, plan.impulse * 0.7, 6.0)
	model.visible = false
	for lid in _lids:
		lid.visible = false
	_gob.visible = false
	_gob_light.visible = false


func _throw(view: MeshInstance3D, pieces: Array, center: Vector3, out: Vector3, flat: Vector3, impulse: float, spin: float) -> void:
	var xform := view.global_transform
	var materials: Array = []
	for i in view.mesh.get_surface_count():
		materials.append(ArtLibrary.debris_material(view.get_active_material(i)))
	for shard: MeshShards.Piece in pieces:
		var at := xform * shard.center
		var away := at - center
		away = away.normalized() if away.length_squared() > 0.0001 else Vector3.ZERO
		var lift := Vector3.UP * randf_range(0.3, 1.0)
		var velocity := (out * 1.1 + away * 0.9 + flat * 0.5 + lift).normalized() * maxf(impulse, 3.0) * randf_range(0.6, 1.2)
		Fx.piece(shard, MeshShards.materials_for(shard, materials), xform, velocity, spin)


static func _add_box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	view.position = at
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(view)
