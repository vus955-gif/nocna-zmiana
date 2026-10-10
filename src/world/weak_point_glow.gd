class_name WeakPointGlow
extends MeshInstance3D
## The curator's monocle made visible: a glowing shell around one weak
## point (a Hurtbox with weak_point) of an exhibit, slightly larger than the
## hit zone so its rim shows around the head. It lives under the hurtbox,
## so it moves and goes with it.

const SHADER := preload("res://src/world/weak_point.gdshader")
## How much larger than the hit zone.
const GROW := 1.12

static var _material: ShaderMaterial = null


## Puts a glow on [param hurtbox] (once). Returns it, or null when the
## hurtbox has no shape to follow or glows already.
static func attach(hurtbox: Hurtbox) -> WeakPointGlow:
	for child in hurtbox.get_children():
		if child is WeakPointGlow:
			return null
	for child in hurtbox.get_children():
		var collider := child as CollisionShape3D
		if collider == null or collider.shape == null:
			continue
		var mesh := _mesh_for(collider.shape)
		if mesh == null:
			continue
		var glow := WeakPointGlow.new()
		glow.name = "WeakPointGlow"
		glow.mesh = mesh
		glow.transform = collider.transform.scaled_local(Vector3.ONE * GROW)
		glow.material_override = material()
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.add_to_group(&"weak_point_glow")
		hurtbox.add_child(glow)
		return glow
	return null


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	return _material


static func _mesh_for(shape: Shape3D) -> Mesh:
	if shape is SphereShape3D:
		var sphere := SphereMesh.new()
		sphere.radius = (shape as SphereShape3D).radius
		sphere.height = sphere.radius * 2.0
		sphere.radial_segments = 20
		sphere.rings = 10
		return sphere
	if shape is BoxShape3D:
		var box := BoxMesh.new()
		box.size = (shape as BoxShape3D).size
		return box
	if shape is CapsuleShape3D:
		var capsule := CapsuleMesh.new()
		capsule.radius = (shape as CapsuleShape3D).radius
		capsule.height = (shape as CapsuleShape3D).height
		return capsule
	if shape is CylinderShape3D:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = (shape as CylinderShape3D).radius
		cylinder.bottom_radius = cylinder.top_radius
		cylinder.height = (shape as CylinderShape3D).height
		return cylinder
	return null
