class_name PaintBlob
extends Projectile
## A gob of paint spat by a Portrait: a wobbling blob on an arc. It hits
## the guard (10) or splats on the level; either way it leaves a slowing
## PaintPuddle on the floor below. Shot down in mid-air it just bursts
## (no puddle): the answer for the quick.

var paint := Color(0.75, 0.1, 0.18)

static var _blob_mesh: SphereMesh = null


## A blob at [param from] flying with [param velocity_]. Add it to the
## tree yourself (after setting gravity and exclude).
static func throw(from: Vector3, velocity_: Vector3, info: DamageInfo, color: Color) -> PaintBlob:
	var blob := PaintBlob.new()
	blob.paint = color
	blob.velocity = velocity_
	blob.damage = info
	blob._start = Transform3D(Projectile._facing(velocity_), from)
	blob._placed = true
	blob.transform = blob._start
	blob.radius = 0.14
	blob.lifetime = 4.0
	blob.material_kind = ExhibitMaterial.Kind.CANVAS
	blob.core_color = color
	blob.glow_color = color.lightened(0.3)
	blob.light_energy = 0.6
	blob.break_sound = &"paint_splat"
	return blob


func _impact(collider: Object, point: Vector3, normal: Vector3) -> void:
	var parent := get_parent()
	super(collider, point, normal)
	PaintPuddle.spill(parent, point + normal * 0.1, paint)


## Coloured splashes instead of stone chips.
func _burst(point: Vector3, normal: Vector3, strength: float) -> void:
	Fx.impact(point, normal, ExhibitMaterial.Kind.CANVAS, strength * 0.6)
	for i in 4:
		var fling := (normal + Vector3(randf_range(-0.9, 0.9), randf_range(0.2, 1.0), randf_range(-0.9, 0.9))) * 2.2
		Fx.chunk(point + normal * 0.05, paint, 0.05, fling)
	Sfx.play_at(break_sound, point, -2.0)


## A wobbling blob, its halo and trail in the paint's colour.
func _build_visuals() -> void:
	super()
	var core := _spin.get_child(0) as MeshInstance3D
	core.mesh = _blob()
	core.rotation_degrees = Vector3.ZERO
	var material := StandardMaterial3D.new()
	material.albedo_color = paint
	material.roughness = 0.15
	material.emission_enabled = true
	material.emission = paint
	material.emission_energy_multiplier = 0.6
	core.material_override = material


func _animate() -> void:
	super()
	var wobble := 1.0 + 0.18 * sin(_age * 26.0)
	_spin.scale = Vector3(wobble, 1.0 / wobble, 1.0)


static func _blob() -> SphereMesh:
	if _blob_mesh == null:
		_blob_mesh = SphereMesh.new()
		_blob_mesh.radius = 0.12
		_blob_mesh.height = 0.24
		_blob_mesh.radial_segments = 10
		_blob_mesh.rings = 6
	return _blob_mesh
