class_name Totem
extends Enemy
## The Totem of the Americas wing (design pietro-1-projekt 5.6): a cedar
## pole of 3-5 carved faces (TotemFaces.count_for its place, or [member
## faces]), 30 HP a face, Dust 3 a face, carved WOOD (chips, hit_wood /
## break_wood). It never moves: every face is a turret turning on its own
## toward the guard (higher faces faster); the top face takes full damage,
## a lower one or the stump only dents (TotemFaces.hit_factor), so it is
## shot off from the top: every 30 damage the top block bursts into chips
## and flies off, the bark hat drops onto the new top and bounces, the pole
## sways, the eyes left flare. The face aimed closest at the guard (within
## 20 degrees, a clear line from its mouth) spits:
## - the telegraph SPIT_WINDUP s: that face's eyes glow and it draws back
##   (a breath), turning only at COMMIT_TURN of its rate (commitment); a
##   hit that takes the spitting face off calls the shot off,
## - the spit: a cedar shard (Projectile, shootable) from the face's mouth
##   along the way the face points, pitched at the guard's chest,
## - then it waits TotemFaces.interval(faces left): the fewer faces, the
##   faster (5 -> 2 s ... 1 -> 0.8 s).
## Asleep it is an exhibit, every face looking out front, watching a
## 160-degree cone; waking, the faces turn one after another from the
## bottom with a creak, then it watches all round. Awake without the guard
## in sight the faces sweep slowly about what they last saw; back asleep
## they turn to the front again. It does not count as a hunter. The model
## "totem" (kit docs/art/kit-pietro1-ameryki.md 8) moves through a
## TotemRig; without it a greybox of stacked blocks.

const KIND := &"totem"
const SPIT_SPEED := 8.5
const SPIT_DAMAGE := 9.0
const SPIT_KNOCKBACK := 2.0
const SPIT_WINDUP := 0.7
const SPIT_RECOVERY := 0.15
const RANGE := 20.0
## Where the shard aims, over the guard's feet (his chest).
const AIM_HEIGHT := 1.1
## The spitting face turns at this share of its rate in the telegraph.
const COMMIT_TURN := 0.4
## Waking, face k begins to turn WAKE_STAGGER * (k - 1) s after the first.
const WAKE_STAGGER := 0.18
## Awake without the guard in sight, the faces sweep this far either side
## of what they watch (rad).
const SCAN_ARC := 0.45
## How often it looks for the face that has the guard in its sights (s).
const AIM_INTERVAL := 0.1
const COLLIDER_RADIUS := 0.55
## Hit zones: one box a block (turning with it), a sphere on each face's
## marker (the top one the weak point), a box on the stump.
const ZONE_SIZE := Vector3(0.95, TotemFaces.BLOCK_HEIGHT, 0.95)
const FACE_ZONE_RADIUS := 0.22
const FACE_OUT := -0.48
## The mouths' heights and how far out they lie in the model (kit 8).
const MOUTH_HEIGHTS: Array[float] = [0.55, 1.5, 2.35, 3.14, 3.99]
const MOUTH_OUT: Array[float] = [-0.62, -0.56, -0.74, -0.58, -0.72]
const CEDAR := Color(0.55, 0.3, 0.16)
const AMBER := Color(1.0, 0.72, 0.3)
const CREAK_DB := -9.0
## Dust "from the faces": the default (a caller that sets dust_value keeps it).
const DUST_FROM_FACES := -1

## How many faces it has (0 = from its place, TotemFaces.count_for). Set
## before it enters the tree.
var faces: int = 0

var _top: int = 0
var _face_health: float = TotemFaces.FACE_HEALTH
## World yaw of each face (index k - 1).
var _yaw := PackedFloat32Array()
var _cooldown: float = 0.0
var _firing: int = -1
var _aimed: int = -1
var _aim_timer: float = 0.0
## Seconds since it woke (-1 asleep): the faces begin to turn in order.
var _awake_time: float = -1.0
## Highest face that has begun to turn since it woke (the creaks).
var _creaked: int = 0
var _time: float = 0.0
var _collider: CollisionShape3D
var _block_zones: Array[Hurtbox] = []
var _face_zones: Array[Hurtbox] = []
var _grey_blocks: Array[Node3D] = []
var _grey_eyes: Array[StandardMaterial3D] = []
var _grey_cap: Node3D = null


func _configure() -> void:
	max_health = TotemFaces.health_for(TotemFaces.MAX_FACES)   # scaled to its faces in _ready()
	move_speed = 0.0
	turn_speed = 0.0
	attack_damage = SPIT_DAMAGE
	attack_reach = RANGE
	knockback_resist = 1.0
	eye_height = TotemFaces.face_height(TotemFaces.MAX_FACES)
	marker_height = TotemFaces.top_of(TotemFaces.MAX_FACES) + 0.5
	material_kind = ExhibitMaterial.Kind.WOOD
	dust_value = DUST_FROM_FACES   # 3 a face, set in _ready() unless a caller chose
	notice_sound = &"portrait_creak"
	sight_cone_deg = PerceptionRules.WIDE_CONE_DEG
	windup_lean = 0.0
	strike_lean = 0.0
	brain.reaction_time = 0.9
	brain.attack_range = RANGE
	brain.windup = SPIT_WINDUP
	brain.recovery = SPIT_RECOVERY


func _ready() -> void:
	if faces <= 0:
		faces = TotemFaces.count_for(global_position)
	faces = clampi(faces, 1, TotemFaces.MAX_FACES)
	# a tune's multiplier (the difficulty, a modifier) is kept: the health
	# of five faces scaled to its own
	max_health = max_health * faces / float(TotemFaces.MAX_FACES)
	if dust_value == DUST_FROM_FACES:
		dust_value = TotemFaces.dust_for(faces)
	_top = faces
	_face_health = max_health / faces
	super()
	_yaw.resize(faces)
	_yaw.fill(_world_yaw())
	_set_top(faces, true)
	_aim_timer = randf() * AIM_INTERVAL


func _build_body() -> void:
	var shape := CylinderShape3D.new()
	shape.radius = COLLIDER_RADIUS
	shape.height = TotemFaces.top_of(faces) + 0.45
	_collider = CollisionShape3D.new()
	_collider.shape = shape
	_collider.position.y = shape.height * 0.5
	add_child(_collider)
	rig = TotemRig.build(self)
	if rig == null:
		_build_greybox()
	add_hurtbox(box_shape(Vector3(1.1, TotemFaces.BLOCK_BASE, 1.1)), Vector3(0.0, TotemFaces.BLOCK_BASE * 0.5, 0.0))
	for k in range(1, faces + 1):
		var zone := add_hurtbox(box_shape(ZONE_SIZE), Vector3(0.0, TotemFaces.top_of(k - 1) + TotemFaces.BLOCK_HEIGHT * 0.5, 0.0))
		var face := add_hurtbox(sphere_shape(FACE_ZONE_RADIUS), Vector3(0.0, TotemFaces.face_height(k), FACE_OUT), k == faces)
		if rig != null:
			rig.track(zone, "block_%d" % k, true)
			rig.track(face, "face_%d" % k)
		_block_zones.append(zone)
		_face_zones.append(face)


## Stacked boxes on turning pivots (no model): a stump, a block a face with
## a darker face plate and two glowing eyes, a hat on top.
func _build_greybox() -> void:
	var cedar := body_material(Color(0.52, 0.27, 0.16))
	var paint := body_material(Color(0.12, 0.1, 0.09))
	var stone := body_material(Color(0.4, 0.4, 0.38))
	var stump := CylinderMesh.new()
	stump.top_radius = 0.4
	stump.bottom_radius = 0.44
	stump.height = TotemFaces.BLOCK_BASE
	add_part(stump, Vector3(0.0, TotemFaces.BLOCK_BASE * 0.5, 0.0), cedar)
	var collar := CylinderMesh.new()
	collar.top_radius = 0.58
	collar.bottom_radius = 0.66
	collar.height = 0.2
	add_part(collar, Vector3(0.0, 0.1, 0.0), stone)
	for k in range(1, faces + 1):
		var pivot := Node3D.new()
		pivot.name = "block_%d" % k
		pivot.position.y = TotemFaces.top_of(k - 1)
		visual.add_child(pivot)
		_grey_blocks.append(pivot)
		var block := MeshInstance3D.new()
		block.mesh = box_mesh(Vector3(0.84, TotemFaces.BLOCK_HEIGHT - 0.02, 0.84))
		block.position.y = TotemFaces.BLOCK_HEIGHT * 0.5
		block.material_override = cedar
		pivot.add_child(block)
		var plate := MeshInstance3D.new()
		plate.mesh = box_mesh(Vector3(0.6, 0.5, 0.1))
		plate.position = Vector3(0.0, TotemFaces.face_height(k) - pivot.position.y, -0.45)
		plate.material_override = paint
		pivot.add_child(plate)
		var eyes := StandardMaterial3D.new()
		eyes.albedo_color = Color(0.9, 0.6, 0.2)
		eyes.emission_enabled = true
		eyes.emission = AMBER
		eyes.emission_energy_multiplier = 0.0
		_grey_eyes.append(eyes)
		for x in [-0.14, 0.14]:
			var eye := MeshInstance3D.new()
			eye.mesh = box_mesh(Vector3(0.1, 0.06, 0.04))
			eye.position = Vector3(x, TotemFaces.face_height(k) - pivot.position.y + 0.1, -0.52)
			eye.material_override = eyes
			pivot.add_child(eye)
	var hat := CylinderMesh.new()
	hat.top_radius = 0.2
	hat.bottom_radius = 0.6
	hat.height = 0.45
	_grey_cap = add_part(hat, Vector3(0.0, TotemFaces.top_of(faces) + 0.22, 0.0), paint)


# --- what the rig and the tests read ---------------------------------------------

## Faces still standing.
func faces_now() -> int:
	return _top


## The face winding up a shot (-1 none).
func firing_face() -> int:
	return _firing


## Which way face [param face] looks, relative to the pole's front (rad).
func face_yaw(face: int) -> float:
	if face < 1 or face > _yaw.size():
		return 0.0
	return angle_difference(_world_yaw(), _yaw[face - 1])


## World yaw from the pole toward [param point].
func yaw_to(point: Vector3) -> float:
	var to := point - global_position
	if Vector2(to.x, to.z).length_squared() < 0.0001:
		return _world_yaw()
	return atan2(-to.x, -to.z)


## 0..1: how far face [param face] is into waking (the faces come alive
## from the bottom up); 1 once it is up, or asleep.
func wake_share(face: int) -> float:
	if _awake_time < 0.0:
		return 1.0
	return clampf((_awake_time - WAKE_STAGGER * (face - 1)) / 0.5, 0.0, 1.0)


## How bright face [param face]'s eyes glow now (0..1 and over in a flare).
func face_glow(face: int) -> float:
	var hold := rig as TotemRig
	if hold != null:
		return hold.face_glow(face)
	if face >= 1 and face <= _grey_eyes.size():
		return _grey_eyes[face - 1].emission_energy_multiplier / 3.0
	return 0.0


## It shoots from afar: the navmesh need not bring it anywhere.
func _attacks_from_range() -> bool:
	return true


## A pole on its plinth takes no place in the hunter cap.
func counts_as_hunter() -> bool:
	return false


func _uses_attack_ring() -> bool:
	return false


# --- the step --------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if brain.state == EnemyBrain.State.DESTROYED or is_frozen():
		return
	_time += delta
	if _cooldown > 0.0:
		_cooldown -= delta
	if _awake_time >= 0.0:
		_awake_time += delta
	_aim_timer -= delta
	if _aim_timer <= 0.0:
		_aim_timer = AIM_INTERVAL
		_aimed = _aimed_face()
	super(delta)
	if brain.state == EnemyBrain.State.DESTROYED:
		return
	_turn_faces(delta)
	if rig == null:
		_pose_greybox(delta)


## The pole never walks nor turns.
func _steer(_delta: float, _has_target: bool) -> Vector3:
	EnemyCrowd.release(self)
	return Vector3.ZERO


func _face_towards(_point: Vector3, _delta: float) -> void:
	pass


func _turn_to_yaw(_yaw_: float, _delta: float) -> void:
	pass


## A shot waits for its interval and for a face with the guard in its sights.
func _may_attack() -> bool:
	return _cooldown <= 0.0 and _aimed > 0


## Awake it watches all round with every face.
func _can_see_target() -> bool:
	if brain.state == EnemyBrain.State.DORMANT:
		return super()
	var cone := sight_cone_deg
	sight_cone_deg = 360.0
	var seen := super()
	sight_cone_deg = cone
	return seen


func _on_state_changed(from: EnemyBrain.State, to: EnemyBrain.State) -> void:
	super(from, to)
	match to:
		EnemyBrain.State.ATTACK:
			_firing = _aimed if _aimed > 0 else _top
		EnemyBrain.State.DORMANT:
			_awake_time = -1.0
			_creaked = 0
			_firing = -1
		_:
			if from == EnemyBrain.State.DORMANT:
				_awake_time = 0.0
				_creaked = 0
			if from == EnemyBrain.State.ATTACK:
				_firing = -1


## The spit: a cedar shard from the face's mouth the way the face points,
## pitched at his chest; then the interval (shorter with fewer faces).
func _on_strike() -> void:
	_cooldown = TotemFaces.interval(_top) - SPIT_WINDUP
	var face := _firing
	_firing = -1
	if face < 1 or face > _top or not _target_alive() or Haven.shelters(target.global_position):
		return
	var muzzle := _mouth(face)
	var chest := target.global_position + Vector3.UP * AIM_HEIGHT
	if not _clear_line(muzzle, chest):
		return   # he ducked behind cover in the telegraph
	var yaw := _yaw[face - 1]
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var flat := Vector2(chest.x - muzzle.x, chest.z - muzzle.z).length()
	var direction := (forward * flat + Vector3.UP * (chest.y - muzzle.y)).normalized()
	var info := DamageInfo.make(attack_damage, DamageInfo.Kind.BLUNT, self)
	info.knockback = SPIT_KNOCKBACK
	var shard := Projectile.create(muzzle, direction * SPIT_SPEED, info)
	shard.material_kind = ExhibitMaterial.Kind.WOOD
	shard.core_color = CEDAR
	shard.glow_color = AMBER
	shard.break_sound = &"hit_wood"
	shard.light_energy = 0.7
	shard.radius = 0.15
	shard.exclude = [get_rid()]
	get_parent().add_child(shard)
	Sfx.play_at(&"totem_spit", muzzle)
	var hold := rig as TotemRig
	if hold != null:
		hold.spat(face)


## The face with the guard in its sights now (-1 none): aimed within the
## arc, a clear line from its mouth to his chest.
func _aimed_face() -> int:
	if not _sees_target or not _target_alive() or _top < 1:
		return -1
	var chest := target.global_position + Vector3.UP * AIM_HEIGHT
	var clear := func(face: int) -> bool: return _clear_line(_mouth(face), chest)
	return TotemFaces.pick_face(_yaw, _top, yaw_to(chest), clear)


## Where face [param face]'s mouth is now (world).
func _mouth(face: int) -> Vector3:
	if rig != null:
		return global_transform * rig.part_transform("mouth_%d" % face).origin
	var k := clampi(face, 1, TotemFaces.MAX_FACES) - 1
	return global_transform * (Basis(Vector3.UP, face_yaw(face)) * Vector3(0.0, MOUTH_HEIGHTS[k], MOUTH_OUT[k]))


## Every face turns on its own toward what the pole watches: the guard
## while it knows where he is, else a slow sweep about what it last saw;
## asleep back to the front. Waking, the faces begin from the bottom up,
## each with a creak; the spitting face turns slowly (commitment).
func _turn_faces(delta: float) -> void:
	var dormant := brain.state == EnemyBrain.State.DORMANT
	var front := _world_yaw()
	var watched := Vector3.INF
	var sweep := false
	if not dormant:
		if brain.knows_guard() and _target_alive():
			watched = target.global_position
		elif brain.state == EnemyBrain.State.SEARCH and brain.looking_around():
			watched = brain.goal
		elif brain.state != EnemyBrain.State.RETURN and not brain.last_known.is_zero_approx():
			watched = brain.last_known   # (exactly zero: it saw and heard nothing yet, the world origin is no place to look)
		sweep = watched != Vector3.INF and not brain.knows_guard()
	var committed := brain.state == EnemyBrain.State.ATTACK and not brain.has_struck()
	for k in range(1, _top + 1):
		if _awake_time >= 0.0 and _awake_time < WAKE_STAGGER * (k - 1):
			break   # its turn to wake has not come
		if _awake_time >= 0.0 and k > _creaked:
			_creaked = k
			Sfx.play_at(&"portrait_creak", global_position + Vector3.UP * TotemFaces.face_height(k), CREAK_DB, 0.15, 0.85 + 0.08 * k)
		var goal := front
		if watched != Vector3.INF:
			goal = yaw_to(watched)
			if sweep:
				goal += sin(_time * (0.35 + 0.08 * k) + k * 1.7) * SCAN_ARC
		var rate := TotemFaces.turn_rate(k)
		if committed and k == _firing:
			rate *= COMMIT_TURN
		elif dormant:
			rate *= 0.5
		_yaw[k - 1] = rotate_toward(_yaw[k - 1], goal, rate * delta)


# --- damage: shot off from the top -----------------------------------------------------

## A hit's place on the pole sets its worth: full on the top face (or the
## weak point), dead wood below. A burn tick (fire sits wherever the flames
## do, low on the pole) eats the whole of it: no dead wood for fire.
func take_damage(info: DamageInfo) -> void:
	if brain.state == EnemyBrain.State.DESTROYED or is_frozen():
		return
	if not info.weak_point and not info.periodic and not info.position.is_zero_approx():
		var local := global_transform.affine_inverse() * info.position
		info.amount *= TotemFaces.hit_factor(TotemFaces.block_at(local.y), _top)
	super(info)


## The pole sways; every FACE_HEALTH of damage the top block comes off.
func _on_damaged(info: DamageInfo) -> void:
	var hold := rig as TotemRig
	if hold != null and not info.periodic:
		hold.jolt(info.direction * clampf(info.amount / 12.0, 0.4, 2.5))
	var burst := Vector3.INF
	while _top > 0 and TotemFaces.faces_left(health.current, _face_health) < _top:
		burst = _drop_top(info.direction)
	# one crack for the blow, however many faces it took; a killing blow is
	# cracked by the pole's own destruction
	if burst != Vector3.INF and not health.is_dead():
		Sfx.play_at(&"break_wood", burst, -2.0)


## The top block bursts into chips and flies off; the hat drops onto the
## new top; the shot of a face just shot off is called off. Returns where
## the block burst.
func _drop_top(push: Vector3) -> Vector3:
	var k := _top
	_top -= 1
	var center := global_transform * Vector3(0.0, TotemFaces.top_of(k - 1) + TotemFaces.BLOCK_HEIGHT * 0.5, 0.0)
	var hold := rig as TotemRig
	if hold != null:
		hold.drop_block(k, push)
	elif k - 1 < _grey_blocks.size():
		_grey_blocks[k - 1].visible = false
	Fx.impact(center, Vector3.UP, ExhibitMaterial.Kind.WOOD, 2.0)
	for zone in [_block_zones[k - 1], _face_zones[k - 1]]:
		zone.collision_layer = 0
		zone.monitorable = false
	if _top >= 1:
		_face_zones[_top - 1].weak_point = true
	_set_top(_top, false)
	if _firing == k:
		_firing = -1
		brain.interrupt()
	if _aimed > _top:
		_aimed = -1
	return center


## The pole is [param n] faces tall now: sight from the top face, the stun
## marker and the collider above it, the hat on it.
func _set_top(n: int, instant: bool) -> void:
	eye_height = TotemFaces.face_height(n) if n >= 1 else TotemFaces.BLOCK_BASE
	marker_height = TotemFaces.top_of(n) + 0.5
	if _stun_marker != null:
		_stun_marker.position.y = marker_height
	if _collider != null:
		var shape := _collider.shape as CylinderShape3D
		shape.height = TotemFaces.top_of(n) + 0.45
		_collider.position.y = shape.height * 0.5
	var hold := rig as TotemRig
	if hold != null:
		hold.set_top(n, instant)


func _pose_greybox(delta: float) -> void:
	var w := brain.windup_progress()
	for k in range(1, _grey_blocks.size() + 1):
		var pivot := _grey_blocks[k - 1]
		pivot.rotation.y = face_yaw(k)
		var glow := 0.0
		if k == _firing and w > 0.0:
			glow = 3.0 * minf(w / TotemRig.EYES_ON, 1.0)
		elif brain.state != EnemyBrain.State.DORMANT:
			glow = 0.4
		_grey_eyes[k - 1].emission_energy_multiplier = glow
		if k - 1 < _face_zones.size() and k <= _top:
			_face_zones[k - 1].position = Vector3(sin(pivot.rotation.y) * FACE_OUT, TotemFaces.face_height(k), cos(pivot.rotation.y) * FACE_OUT)
	if _grey_cap != null:
		var goal := TotemFaces.top_of(_top) + 0.22
		_grey_cap.position.y = ExhibitRig.ease_to(_grey_cap.position.y, goal, 6.0, delta)


## It has its own answer to a hit: no whole-body flinch.
func _reaction_scale() -> float:
	return 0.0
