class_name PaintPuddle
extends Area3D
## A puddle of wet paint on the floor (a Portrait's gob). For LIFETIME
## seconds a guard standing in it walks SLOW times as fast (40% slower);
## the last FADE seconds it dries away.

const LIFETIME := 3.0
const FADE := 0.6
const RADIUS := 0.9
## Speed factor while standing in it.
const SLOW := 0.6
## How long one frame in it keeps the guard slowed (steps out = free).
const STICK := 0.15
## How far below the splash a floor may be.
const FLOOR_PROBE := 3.0

static var _splat: Texture2D = null

var paint := Color(0.75, 0.1, 0.18)
var _age: float = 0.0
var _decal: Decal


## A puddle on the floor below [param at]; null when there is no floor
## within FLOOR_PROBE (a splash high on a wall).
static func spill(parent: Node, at: Vector3, color: Color) -> PaintPuddle:
	if parent == null or not parent.is_inside_tree():
		return null
	var space := parent.get_viewport().find_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.2, at + Vector3.DOWN * FLOOR_PROBE, Layers.WORLD)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return null
	var puddle := PaintPuddle.new()
	puddle.paint = color
	var floor_point: Vector3 = hit["position"]
	var holder := parent as Node3D
	var local := holder.global_transform.affine_inverse() * floor_point if holder != null else floor_point
	puddle.position = local
	puddle.rotation.y = randf() * TAU
	parent.add_child(puddle)
	return puddle


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitoring = true
	monitorable = false
	var shape := CylinderShape3D.new()
	shape.radius = RADIUS
	shape.height = 0.8
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.3
	add_child(collider)
	_decal = Decal.new()
	_decal.size = Vector3(RADIUS * 2.2, 0.6, RADIUS * 2.2)
	_decal.texture_albedo = _splat_texture()
	_decal.modulate = paint
	_decal.albedo_mix = 0.95
	_decal.position.y = 0.1
	add_child(_decal)
	Sfx.play_at(&"paint_splat", global_position, -4.0)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	_decal.albedo_mix = 0.95 * clampf((LIFETIME - _age) / FADE, 0.0, 1.0)
	for body in get_overlapping_bodies():
		var guard := body as Player
		if guard != null and guard.alive:
			guard.slow(SLOW, STICK)


## A blotchy round splat (white with alpha; the decal tints it).
static func _splat_texture() -> Texture2D:
	if _splat == null:
		var size := 48
		var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var lobes: Array[Vector3] = []
		for i in 7:
			var angle := TAU * i / 7.0 + rng.randf_range(-0.3, 0.3)
			lobes.append(Vector3(cos(angle), sin(angle), rng.randf_range(0.18, 0.32)))
		for y in size:
			for x in size:
				var p := Vector2(x - size * 0.5 + 0.5, y - size * 0.5 + 0.5) / (size * 0.5)
				var inside := p.length() < 0.62
				for lobe in lobes:
					if p.distance_to(Vector2(lobe.x, lobe.y) * 0.62) < lobe.z:
						inside = true
				var shade := 1.0 - 0.25 * p.length()
				image.set_pixel(x, y, Color(shade, shade, shade, 1.0 if inside else 0.0))
		_splat = ImageTexture.create_from_image(image)
	return _splat
