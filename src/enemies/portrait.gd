class_name Portrait
extends Enemy
## A portrait on the gallery wall that is not just a portrait. Asleep it is
## exactly a WallPainting: still, and untouchable (its hit zones are off;
## shots hit the canvas like the wall). When the guard comes within
## SIGHT_RANGE in front of it with a clear view, its eyes start to follow
## him (silently: a sign for the observant); after TRACK_TIME the frame
## pushes out of the wall by PUSH_OUT with a creak, leaving a dark niche,
## and from then on it can be hurt and it spits paint: a gob on an arc
## (10), telegraphed by its mouth opening and glowing in its paint colour,
## that leaves a slowing puddle (PaintPuddle). Its eyes are the weak point,
## a taser shuts them for 3 s. It never moves. Noise and other exhibits do
## not wake it: only its own sight (in front of the canvas, SIGHT_RANGE,
## whatever the light). Once out of its wall it never sleeps again and
## does not count toward the hunter cap.
##
## It wears the painting model on a PortraitRig when there is one (eyes on
## the eye patch, a gob of paint at the mouth as the telegraph, frame
## splinters and canvas shreds when it breaks); else the greybox of
## PaintingArt.build (eye, pupil, lid and mouth meshes).
##
## Place with create_on_wall(transform, painting_id): the origin is the
## middle of the canvas on the wall surface, -Z faces the room.

const KIND := &"portrait"
const SIGHT_RANGE := 10.0
## Once awake it keeps watching the guard this far.
const AWAKE_SIGHT := 16.0
const TRACK_TIME := 1.5
const PUSH_OUT := 0.5
const PUSH_TIME := 0.35
const FIRE_INTERVAL := 2.6
const BLOB_SPEED := 11.0
const BLOB_GRAVITY := 9.0
## Where the blob aims, above the target's origin.
const AIM_HEIGHT := 1.0
const PUPIL_TRAVEL := Vector2(0.012, 0.006)


## Wakes only by the portrait's own sight (not by noise or neighbours);
## awake it watches for good (never searches, never goes back to sleep).
class PortraitBrain extends EnemyBrain:
	var sighted := false

	func _init() -> void:
		super()
		relentless = true

	func wake() -> void:
		if sighted:
			super()

	func hear(_point: Vector3, _follow: bool = true) -> void:
		pass


var painting_id: StringName = &""
## How far the frame stands out of the wall now (0 asleep, PUSH_OUT awake).
var pushed: float = 0.0

var _wall := Transform3D.IDENTITY
var _parts: Dictionary = {}
var _zones: Array[Hurtbox] = []
var _block: StaticBody3D
var _niche: MeshInstance3D
var _struts: Array[MeshInstance3D] = []
var _mouth_material: StandardMaterial3D
var _cooldown: float = 0.0
var _push_tween: Tween = null
## How deep the painting stands off the wall (greybox or model).
var _depth: float = PaintingArt.DEPTH


static func create_on_wall(at: Transform3D, id: StringName) -> Portrait:
	var portrait := Portrait.new()
	portrait.transform = at
	portrait.painting_id = id
	portrait.name = "Portrait_%s" % id
	return portrait


func _configure() -> void:
	brain = PortraitBrain.new()
	max_health = 40.0
	move_speed = 0.0
	turn_speed = 0.0
	sight_range = SIGHT_RANGE
	attack_damage = 10.0
	knockback_resist = 1.0
	wake_radius = 0.0
	eye_height = 0.0
	marker_height = 0.8
	material_kind = ExhibitMaterial.Kind.CANVAS
	notice_sound = &"portrait_creak"
	dust_value = 4
	brain.reaction_time = TRACK_TIME
	brain.attack_range = 14.0
	brain.windup = 0.7
	brain.recovery = 0.25


func _ready() -> void:
	if painting_id == &"":
		painting_id = PaintingArt.ids()[0]
	super()
	_wall = global_transform
	collision_mask = 0   # pinned to its wall: it pushes nothing, nothing moves it
	# asleep its body is no body at all (a flare meets the canvas like the
	# wall: the block below); it becomes one when the frame comes out
	collision_layer = 0


## True while its eyes follow the guard (awake or about to be).
func eyes_tracking() -> bool:
	return brain.state != EnemyBrain.State.DORMANT and brain.state != EnemyBrain.State.STUNNED \
			and brain.state != EnemyBrain.State.DESTROYED


## True once the frame came out and it can be hurt.
func vulnerable() -> bool:
	return not _zones.is_empty() and _zones[0].collision_layer != 0


## Where it looks from and spits from (in front of the canvas).
func eye_point() -> Vector3:
	var eyes := _eye_local(1.0).lerp(_eye_local(-1.0), 0.5)
	return global_transform * Vector3(eyes.x, eyes.y, -0.2)


func mouth_point() -> Vector3:
	var mouth := PaintingArt.canvas_point(PaintingArt.MOUTH_TEXEL)
	if _model_rig() != null:
		mouth = PaintingArt.MODEL_MOUTH
	return global_transform * Vector3(mouth.x, mouth.y, -0.25)


## World position of its eye on [param side] (+1 = its +X, the viewer's
## left) on the canvas: a weak point.
func eye_on_canvas(side: float) -> Vector3:
	return global_transform * _eye_local(side)


## How far the irises moved from the middle (world space, m): toward
## where it looks.
func pupil_shift() -> Vector3:
	var rig_now := _model_rig()
	if rig_now != null:
		var shift := rig_now.iris_shift()
		return global_basis * Vector3(shift.x, shift.y, 0.0)
	var pupil: Node3D = _parts["pupil_l"]
	var eye: Node3D = _parts["eye_l"]
	var local := pupil.position - eye.position
	return global_basis * Vector3(local.x, local.y, 0.0)


func _model_rig() -> PortraitRig:
	return rig as PortraitRig


## Painting-space eye on [param side] (+1 = +X) on the canvas.
func _eye_local(side: float) -> Vector3:
	if _model_rig() != null:
		return PaintingArt.model_eye(side)
	var at := PaintingArt.canvas_point(PaintingArt.EYE_TEXEL_L if side > 0.0 else PaintingArt.EYE_TEXEL_R)
	return Vector3(at.x, at.y, PaintingArt.CANVAS_Z)


func _physics_process(delta: float) -> void:
	if brain.state == EnemyBrain.State.DESTROYED:
		return
	if _cooldown > 0.0:
		_cooldown -= delta
		if _cooldown <= 0.0:
			brain.attack_range = 14.0
	super(delta)
	# pinned to its wall, only ever pushed straight out of it
	global_transform = Transform3D(_wall.basis, _wall.origin - _wall.basis.z * pushed)
	velocity = Vector3.ZERO
	_external = Vector3.ZERO


## Sees the guard only in front of the painting, within its sight range,
## whatever the light (its own rule: no cone, no darkness).
func _look() -> void:
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(&"player") as Node3D
	_sees_target = false
	if _target_alive() and global_position.distance_to(target.global_position) <= sight_range:
		var to := target.global_position + Vector3.UP * 1.4 - eye_point()
		_sees_target = to.dot(-_wall.basis.z) > 0.2 * to.length() and _has_line_of_sight()
	(brain as PortraitBrain).sighted = _sees_target


func counts_as_hunter() -> bool:
	return false


func _has_line_of_sight() -> bool:
	return _clear_line(eye_point(), target.global_position + Vector3.UP * 1.4)


func _apply_gravity(_delta: float) -> void:
	velocity.y = 0.0


## Asleep on its wall it rests (no physics step) like an exhibit on its
## floor.
func resting() -> bool:
	return brain.state == EnemyBrain.State.DORMANT


func _chase_direction(_delta: float, _goal: Vector3) -> Vector3:
	return Vector3.ZERO


func _face_towards(_point: Vector3, _delta: float) -> void:
	pass


func _on_strike() -> void:
	_cooldown = FIRE_INTERVAL - brain.windup
	brain.attack_range = -1.0   # watching until the next gob
	if not _target_alive() or Haven.shelters(target.global_position):
		return
	var mouth := mouth_point()
	var aim := target.global_position + Vector3.UP * AIM_HEIGHT
	if not _clear_line(mouth, aim):
		return
	var flight := clampf(mouth.distance_to(aim) / BLOB_SPEED, 0.45, 1.3)
	var launch := (aim - mouth) / flight + Vector3.UP * 0.5 * BLOB_GRAVITY * flight
	var info := DamageInfo.make(attack_damage, DamageInfo.Kind.BLUNT, self)
	info.knockback = 1.5
	var blob := PaintBlob.throw(mouth, launch, info, PaintingArt.paint_color(painting_id))
	blob.gravity = BLOB_GRAVITY
	blob.exclude = [get_rid()]
	get_parent().add_child(blob)
	Sfx.play_at(&"paint_spit", mouth)


## No call-out when it wakes (only the eyes tell); the frame pushes out
## when the watching is over.
func _on_state_changed(from: EnemyBrain.State, to: EnemyBrain.State) -> void:
	_stun_marker.visible = to == EnemyBrain.State.STUNNED
	if from == EnemyBrain.State.SUSPICIOUS and to == EnemyBrain.State.HUNT:
		_push_out()


func _push_out() -> void:
	if pushed > 0.0 or (_push_tween != null and _push_tween.is_valid()):
		return
	sight_range = AWAKE_SIGHT
	for zone in _zones:
		zone.collision_layer = Layers.HURTBOX
	_block.collision_layer = 0
	# a body for flares (and the other exhibits) to meet, but the guard
	# walks along the wall under a frame hung at head height
	collision_layer = Layers.ENEMY
	var guard := target as PhysicsBody3D
	if guard != null:
		add_collision_exception_with(guard)
		guard.add_collision_exception_with(self)
	_niche.visible = true
	Sfx.play_at(&"portrait_creak", global_position, 2.0)
	Fx.impact(global_position, -_wall.basis.z, -1, 1.5)
	_push_tween = create_tween()
	_push_tween.tween_property(self, "pushed", PUSH_OUT, PUSH_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_visuals(delta: float) -> void:
	super(delta)
	# the niche and the struts stay at the wall while the frame comes out
	_niche.position.z = pushed - 0.005
	for strut in _struts:
		strut.visible = pushed > 0.02
		strut.scale.z = maxf(pushed, 0.01)
		strut.position.z = pushed * 0.5 - _depth * 0.5
	if rig != null:
		return   # eyes, lids and the telegraph live on the PortraitRig
	var tracking := eyes_tracking() and _target_alive()
	var shift := Vector2.ZERO
	if tracking:
		var local := global_transform.affine_inverse() * (target.global_position + Vector3.UP * 1.5)
		var eyes := global_transform.affine_inverse() * eye_point()
		var dir := (local - eyes).normalized()
		shift = Vector2(clampf(dir.x * 2.0, -1.0, 1.0) * PUPIL_TRAVEL.x, clampf(dir.y * 2.0, -1.0, 1.0) * PUPIL_TRAVEL.y)
	var stunned := brain.is_stunned()
	for side in ["l", "r"]:
		var pupil: Node3D = _parts["pupil_" + side]
		var eye: Node3D = _parts["eye_" + side]
		var goal := Vector3(eye.position.x + shift.x, eye.position.y + shift.y, pupil.position.z)
		pupil.position = pupil.position.lerp(goal, 1.0 - exp(-10.0 * delta))
		(_parts["lid_" + side] as Node3D).visible = stunned
	var windup := brain.windup_progress()
	var mouth: Node3D = _parts["mouth"]
	var open := windup if brain.state == EnemyBrain.State.ATTACK and not brain.has_struck() else 0.0
	mouth.scale.y = lerpf(mouth.scale.y, 1.0 + open * 3.5, 1.0 - exp(-16.0 * delta))
	_mouth_material.emission_energy_multiplier = open * open * 4.0


func _build_body() -> void:
	var outer := PaintingArt.CANVAS_SIZE + Vector2.ONE * PaintingArt.FRAME_WIDTH * 2.0
	_depth = PaintingArt.DEPTH
	rig = PortraitRig.build(self)
	if rig != null:
		outer = PaintingArt.MODEL_OUTER
		_depth = PaintingArt.MODEL_DEPTH
	else:
		var gilt := body_material(PaintingArt.GILT)
		gilt.metallic = 0.6
		gilt.roughness = 0.35
		_parts = PaintingArt.build(visual, painting_id, gilt)
		_mouth_material = (_parts["mouth"] as MeshInstance3D).material_override as StandardMaterial3D
	# its body, for flares and bumping heads
	var collider := CollisionShape3D.new()
	collider.shape = box_shape(Vector3(outer.x, outer.y, _depth))
	collider.position = Vector3(0.0, 0.0, -_depth * 0.5)
	add_child(collider)
	# asleep, shots hit it like the wall
	_block = StaticBody3D.new()
	_block.collision_layer = Layers.WORLD
	_block.collision_mask = 0
	var block_shape := CollisionShape3D.new()
	block_shape.shape = box_shape(Vector3(outer.x, outer.y, _depth))
	block_shape.position = Vector3(0.0, 0.0, -_depth * 0.5)
	_block.add_child(block_shape)
	add_child(_block)
	# the dark niche it leaves in the wall, and four struts to it
	_niche = MeshInstance3D.new()
	_niche.mesh = box_mesh(Vector3(outer.x, outer.y, 0.01))
	_niche.material_override = _dark()
	_niche.visible = false
	add_child(_niche)
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			var strut := MeshInstance3D.new()
			strut.mesh = box_mesh(Vector3(0.05, 0.05, 1.0))
			strut.material_override = _dark()
			strut.position = Vector3(x * outer.x * 0.35, y * outer.y * 0.35, 0.0)
			strut.visible = false
			add_child(strut)
			_struts.append(strut)
	# hit zones (off until it wakes): the canvas and frame, the eyes
	_zones.append(add_hurtbox(box_shape(Vector3(outer.x, outer.y, 0.14)), Vector3(0.0, 0.0, -0.06)))
	# (the eye zones stand a little out of the canvas, ahead of the body's
	# zone: the model's frame is deep)
	var ahead := 0.08 if rig != null else 0.05
	for side in [1.0, -1.0]:
		var at := _eye_local(side)
		_zones.append(add_hurtbox(sphere_shape(0.05), Vector3(at.x, at.y, at.z - ahead), true))
	for zone in _zones:
		zone.collision_layer = 0


static func _dark() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.03, 0.025, 0.02)
	material.roughness = 1.0
	return material


## It has its own answer to a hit: no whole-body flinch.
func _reaction_scale() -> float:
	return 0.0
