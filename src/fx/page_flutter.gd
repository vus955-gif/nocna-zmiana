class_name PageFlutter
extends Node3D
## A loose page of a shot book (the flying books' "paper gore", design
## pietro-1-projekt 5.4) falling like a leaf: a quick push out of the
## book, then a slow sway from side to side down to the floor, tilting
## into each swing and turning as it goes; it lands flat, lies a few
## seconds and shrinks away. Pages from a book killed by fire smoulder
## (a warm glow that dies as they fall). The model "flying_book_page"
## (two-sided printed leaf); without it a plain paper quad.
## scatter() puts them under the Fx service, so Fx.clear() (a scene
## change) sweeps them up; at most MAX_PAGES lie about at once.

const MAX_PAGES := 60
## Seconds a landed page lies before it shrinks away (random in range).
const REST_TIME := Vector2(6.0, 9.0)
const SHRINK_TIME := 0.6
## Longest a page may stay in the air (it fell off a ledge into a pit).
const AIR_TIME := 12.0
const FLOOR_RAY := 30.0
const PAPER := Color(0.86, 0.8, 0.66)

## The falling-leaf motion of one page (pure: no nodes).
class Motion extends RefCounted:
	const GRAVITY := 9.8
	## Steady sinking speed (m/s): paper sinks slowly.
	const SINK := 0.85
	## How fast a push out of the book dies down in the air (per second).
	const AIR_DRAG := 2.2

	var position := Vector3.ZERO
	## The push (dies down) plus the sinking.
	var velocity := Vector3.ZERO
	## The horizontal line it sways along (unit).
	var axis := Vector3.RIGHT
	var phase: float = 0.0
	## Sway: rad/s of the pendulum and its speed at the bottom (m/s).
	var swing_rate: float = 3.2
	var swing_speed: float = 0.9
	var spin_rate: float = 1.0
	var yaw: float = 0.0
	var floor_y: float = -INF
	var landed := false

	func _init(at: Vector3, push: Vector3, rng: RandomNumberGenerator) -> void:
		position = at
		velocity = push
		var angle := rng.randf() * TAU
		axis = Vector3(cos(angle), 0.0, sin(angle))
		phase = rng.randf() * TAU
		swing_rate = rng.randf_range(2.6, 3.8)
		swing_speed = rng.randf_range(0.6, 1.1)
		spin_rate = rng.randf_range(-1.6, 1.6)
		yaw = rng.randf() * TAU

	## One step of [param delta] seconds.
	func step(delta: float) -> void:
		if landed:
			return
		var flat := Vector3(velocity.x, 0.0, velocity.z) * exp(-AIR_DRAG * delta)
		var fall := velocity.y - GRAVITY * delta
		# it sinks no faster than SINK, and slowest at the ends of a swing
		# (where the leaf turns and catches the air)
		var catch := 0.45 + 0.75 * absf(cos(phase))
		fall = maxf(fall, -SINK * catch)
		velocity = Vector3(flat.x, fall, flat.z)
		phase += swing_rate * delta
		var sway := axis * cos(phase) * swing_speed
		position += (velocity + sway) * delta
		yaw += spin_rate * delta
		if position.y <= floor_y:
			position.y = floor_y
			landed = true

	## How far it tips into its swing (rad, about the line across the sway).
	func tilt() -> float:
		return 0.0 if landed else -sin(phase) * 0.65

	## Its orientation: lying (the leaf's face up), turned, tipped into the
	## swing.
	func basis() -> Basis:
		var across := Vector3.UP.cross(axis).normalized()
		return Basis(across, tilt()) * Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5)


static var _pages: Array = []
static var _mesh: Mesh = null
static var _material: Material = null
static var _loaded := false
static var _rng := RandomNumberGenerator.new()

var motion: Motion
var _view: MeshInstance3D
var _left: float = 0.0
var _rest: float = 0.0
var _smoulder: float = 0.0
var _shrinking := false


## [param count] pages flying out of [param at] (world space), pushed
## along [param push] with a spread; [param scorched] pages smoulder.
## Returns the pages (already under Fx).
static func scatter(at: Vector3, count: int, push: Vector3 = Vector3.ZERO, scorched: bool = false) -> Array[PageFlutter]:
	var made: Array[PageFlutter] = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or count <= 0:
		return made
	var fx := tree.root.get_node_or_null(^"Fx")
	if fx == null:
		return made
	var floor_y := _floor_under(fx as Node, at)
	for i in count:
		var spread := Vector3(_rng.randf_range(-1.6, 1.6), _rng.randf_range(0.6, 2.2), _rng.randf_range(-1.6, 1.6))
		var page := PageFlutter.new()
		page.motion = Motion.new(at + spread * 0.06, push + spread, _rng)
		page.motion.floor_y = floor_y + 0.004 + 0.002 * (i % 4)
		page._smoulder = 1.0 if scorched else 0.0
		page.transform = Transform3D(page.motion.basis(), page.motion.position)
		fx.add_child(page)
		made.append(page)
		_pages.append(page)
	_pages = _pages.filter(func(p: Variant) -> bool: return is_instance_valid(p) and not (p as PageFlutter).is_queued_for_deletion())
	while _pages.size() > MAX_PAGES:
		var oldest: PageFlutter = _pages.pop_front()
		oldest.queue_free()
	return made


## How many pages lie or fall about now.
static func count() -> int:
	_pages = _pages.filter(func(p: Variant) -> bool: return is_instance_valid(p) and not (p as PageFlutter).is_queued_for_deletion())
	return _pages.size()


func _ready() -> void:
	_load()
	_view = MeshInstance3D.new()
	_view.mesh = _mesh
	_view.material_override = _material
	_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_view)
	if _material is ShaderMaterial:
		_view.set_instance_shader_parameter(&"glow", _smoulder * 0.6)
	_left = AIR_TIME


func _physics_process(delta: float) -> void:
	if _shrinking:
		return
	if not motion.landed:
		motion.step(delta)
		_left -= delta
		if motion.landed:
			_rest = randf_range(REST_TIME.x, REST_TIME.y)
		elif _left <= 0.0:
			_shrink()
			return
	else:
		_rest -= delta
		if _rest <= 0.0:
			_shrink()
			return
	if _smoulder > 0.0:
		_smoulder = maxf(_smoulder - delta * 0.6, 0.0)
		if _material is ShaderMaterial:
			_view.set_instance_shader_parameter(&"glow", _smoulder * 0.6)
	transform = Transform3D(motion.basis(), motion.position)


func _shrink() -> void:
	_shrinking = true
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, SHRINK_TIME)
	tween.tween_callback(queue_free)


## The floor under [param at] (level geometry), or far below.
static func _floor_under(fx: Node, at: Vector3) -> float:
	var world := (fx.get_viewport() as Viewport).find_world_3d() if fx.get_viewport() != null else null
	if world == null:
		return at.y - FLOOR_RAY
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.1, at + Vector3.DOWN * FLOOR_RAY, Layers.WORLD)
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return at.y - FLOOR_RAY
	return (hit["position"] as Vector3).y


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var model := ArtLibrary.exhibit(&"flying_book_page")
	if model != null:
		var view := model.find_child("flying_book_page", true, false) as MeshInstance3D
		if view != null and view.mesh != null:
			_mesh = view.mesh
			_material = ArtLibrary.debris_material(view.get_active_material(0))
		model.free()
	if _mesh == null:
		var quad := QuadMesh.new()
		quad.size = Vector2(0.21, 0.31)
		_mesh = quad
		var paper := StandardMaterial3D.new()
		paper.albedo_color = PAPER
		paper.cull_mode = BaseMaterial3D.CULL_DISABLED
		paper.roughness = 0.9
		_material = paper
