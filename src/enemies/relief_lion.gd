class_name ReliefLion
extends Wolf
## A lion of the Nineveh lion hunt torn out of its relief (Assyria, design
## pietro-1-projekt 5.2, 7.3): the stuffed wolf's hunt in a flat gypsum
## body - it crouches and pounces from up to 6 m, biting mid-air. Asleep
## it is the carved lion of an awakening slab on the wall (ReliefWall);
## woken, the slab's cracks glow up (0.8 s) and it steps out, untouchable
## and harmless until it is out. Flat: hits on its edge do half (it shows
## its side stalking, turns its head at the guard to run and pounce); its
## eye is the weak point. 40 HP, Dust 4, gypsum chips. The model
## "relief_lion" moves through a ReliefRig; without it a greybox.

const KIND := &"relief_lion"
const BODY_SIZE := Vector3(1.65, 0.62, 0.16)
const BODY_AT := Vector3(-0.12, 0.66, 0.0)
const EYE_RADIUS := 0.08
## The model's "eye" marker (on the carved face).
const EYE_AT := Vector3(-0.69, 0.895, -0.09)
const CHIP_DAMAGE := 10.0

var wall: ReliefWall
var _zones: Array[Hurtbox] = []
var _hurtable := true


func _configure() -> void:
	super()
	max_health = 40.0
	material_kind = ExhibitMaterial.Kind.MARBLE
	dust_value = 4
	notice_sound = &""


func _init() -> void:
	super()
	wall = ReliefWall.new(self, ReliefPanel.Kind.LION)


func _ready() -> void:
	super()
	wall.setup.call_deferred()


func _build_body() -> void:
	add_collider(0.4, 1.0)
	rig = ReliefRig.build(self, ReliefRig.Kind.LION, wall)
	if rig == null:
		_build_greybox()
	var body_zone := add_hurtbox(box_shape(BODY_SIZE), BODY_AT)
	var eye_zone := add_hurtbox(sphere_shape(EYE_RADIUS), EYE_AT, true)
	_zones = [body_zone, eye_zone]
	if rig != null:
		rig.track(body_zone, &"body", true)
		rig.track(eye_zone, &"eye")
	_set_hurtable(false)


func _build_greybox() -> void:
	var stone := body_material(Color(0.62, 0.66, 0.68))
	add_part(box_mesh(Vector3(1.3, 0.5, 0.14)), Vector3(-0.1, 0.7, 0.0), stone)
	add_part(box_mesh(Vector3(0.4, 0.45, 0.15)), Vector3(-0.75, 0.85, 0.0), stone)
	for x in [-0.5, 0.4]:
		add_part(box_mesh(Vector3(0.14, 0.6, 0.12)), Vector3(x, 0.3, 0.0), stone)


## Which way its carved face looks (it turns its head at the guard to run
## and pounce).
func carved_face() -> Vector3:
	var body := rig as ReliefRig
	return body.face_normal() if body != null else -global_basis.z


## Hits on the edge of the slab do half; in the wall nothing lands.
func take_damage(info: DamageInfo) -> void:
	if not wall.hurtable():
		return
	info.amount *= ReliefMoves.edge_factor(carved_face(), info.direction)
	super(info)


func _on_damaged(info: DamageInfo) -> void:
	if info.periodic or info.amount < CHIP_DAMAGE:
		return
	var fling := Vector3(info.direction.x, 0.0, info.direction.z).normalized() * randf_range(1.0, 2.5) \
			+ Vector3(randf_range(-1.0, 1.0), randf_range(2.0, 3.5), randf_range(-1.0, 1.0))
	var body := rig as ReliefRig
	if body != null:
		body.chip(info.position, fling)
	else:
		Fx.chunk(info.position, ExhibitMaterial.color(material_kind), 0.07, fling)


func _physics_process(delta: float) -> void:
	if brain.state == EnemyBrain.State.DESTROYED or is_frozen():
		return
	wall.tick(delta)
	_set_hurtable(wall.hurtable())
	super(delta)


func _may_attack() -> bool:
	return not wall.busy()


func _steer(delta: float, has_target: bool) -> Vector3:
	if wall.busy():
		EnemyCrowd.release(self)
		return Vector3.ZERO
	return super(delta, has_target)


func _on_state_changed(from: EnemyBrain.State, to: EnemyBrain.State) -> void:
	super(from, to)
	if from == EnemyBrain.State.DORMANT and to != EnemyBrain.State.DESTROYED:
		wall.wake()
	elif to == EnemyBrain.State.DORMANT:
		wall.rest()


## Not while it cracks out of its slab, steps or sinks (the wall's own
## clock runs every frame then).
func _may_doze() -> bool:
	return wall == null or wall.state == ReliefMoves.Wall.IN or wall.state == ReliefMoves.Wall.OUT


func _set_hurtable(on: bool) -> void:
	if on == _hurtable:
		return
	_hurtable = on
	for zone in _zones:
		zone.collision_layer = Layers.HURTBOX if on else 0


## Its own chips fly off a heavy hit (no generic ones on top).
func _chips_on_hits() -> bool:
	return false
