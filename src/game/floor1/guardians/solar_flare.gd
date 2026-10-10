class_name SolarFlare
extends Projectile
## A flare of the Great Orrery's sun: a slow ball of fire on an arc onto a
## spot of the floor that is marked from the moment it leaves (GroundMark,
## darkening as it comes). Where it lands it splashes fire once over
## RADIUS: step out of the mark - or shoot it down in the air (any weapon
## hit bursts it, no splash). Configure with launch(), then add_child().

const RADIUS := 2.0
const DAMAGE := 18.0
## Its arc's gravity (m/s²): slow and high.
const ARC_GRAVITY := 9.0
const CORE := Color(1.0, 0.86, 0.55)
const GLOW := Color(1.0, 0.52, 0.14)
## The guard's body radius (the splash reaches its edge).
const GUARD_RADIUS := 0.4

## Where it comes down and how long it flies.
var landing := Vector3.ZERO
var flight: float = 1.5
## Who the splash may hurt.
var target: Node3D = null
var splash_damage: float = DAMAGE
var mark: GroundMark

static var _ball: SphereMesh = null


## A flare from [param from] onto [param to] in [param time] s (an arc
## under ARC_GRAVITY); [param info] = its splash (amount, source).
static func launch(from: Vector3, to: Vector3, time: float, info: DamageInfo, guard: Node3D) -> SolarFlare:
	var flare := SolarFlare.new()
	var t := maxf(time, 0.3)
	var velocity_ := (to - from) / t + Vector3.UP * (0.5 * ARC_GRAVITY * t)
	flare.velocity = velocity_
	flare.damage = info
	flare.splash_damage = info.amount if info != null else DAMAGE
	flare.landing = to
	flare.flight = t
	flare.target = guard
	flare._start = Transform3D(Projectile._facing(velocity_), from)
	flare._placed = true
	flare.transform = flare._start
	flare.gravity = ARC_GRAVITY
	flare.radius = 0.28
	flare.lifetime = t + 1.5
	flare.hit_mask = Layers.WORLD | Layers.PLAYER
	flare.material_kind = ExhibitMaterial.Kind.METAL
	flare.core_color = CORE
	flare.glow_color = GLOW
	flare.light_energy = 2.2
	flare.break_sound = &"flare_blast"
	return flare


func _ready() -> void:
	super()
	name = "SolarFlare"
	mark = GroundMark.disc(RADIUS)
	get_parent().add_child.call_deferred(mark)
	_place_mark.call_deferred()
	finished.connect(_on_finished)


func _place_mark() -> void:
	if is_instance_valid(mark) and mark.is_inside_tree():
		mark.global_transform = Transform3D(Basis.IDENTITY, landing)


func _physics_process(delta: float) -> void:
	super(delta)
	if is_instance_valid(mark):
		mark.progress = _age / flight


## It came down (on the floor, a wall, the guard): the splash.
func _impact(_collider: Object, point: Vector3, normal: Vector3) -> void:
	var hurt := _splash(point)
	_burst(point, normal, 1.6)
	Fx.flash(point + Vector3.UP * 0.6, GLOW, 5.0, RADIUS * 3.0, 0.3)
	for i in 6:
		var fling := Vector3(randf_range(-1.0, 1.0), randf_range(0.6, 1.6), randf_range(-1.0, 1.0)).normalized() * randf_range(2.5, 5.0)
		Fx.chunk(point + Vector3.UP * 0.1, CORE, 0.05, fling)
	_end(End.HIT if hurt else End.WALL)


## Fire over RADIUS round [param point]: true when it hurt the guard.
func _splash(point: Vector3) -> bool:
	if not is_instance_valid(target) or not target.is_inside_tree() or not target.has_method(&"take_damage"):
		return false
	var alive: Variant = target.get(&"alive")
	if alive is bool and not alive:
		return false
	var off := target.global_position - point
	if Vector2(off.x, off.z).length() > RADIUS + GUARD_RADIUS * 0.5 or absf(off.y) > 1.4:
		return false
	var info := _hit_info(point, Vector3.UP)
	info.amount = splash_damage
	info.kind = DamageInfo.Kind.FIRE
	var out := Vector3(off.x, 0.0, off.z)
	info.direction = out.normalized() if out.length() > 0.1 else Vector3.UP
	info.knockback = 4.0
	info.position = target.global_position + Vector3.UP
	target.call(&"take_damage", info)
	return true


func _on_finished(_reason: End) -> void:
	if is_instance_valid(mark):
		mark.vanish(0.2)


## A ball of fire with its halo and trail.
func _build_visuals() -> void:
	super()
	var core := _spin.get_child(0) as MeshInstance3D
	if _ball == null:
		_ball = SphereMesh.new()
		_ball.radius = 0.22
		_ball.height = 0.44
		_ball.radial_segments = 12
		_ball.rings = 6
	core.mesh = _ball
	core.rotation_degrees = Vector3.ZERO
	for child in get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh == Projectile._halo_mesh():
			(child as Node3D).scale = Vector3.ONE * 2.6
