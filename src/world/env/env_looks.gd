class_name EnvLooks
## The looks of the tools the museum's restorers left about (plan
## docs/superpowers/plans/2026-10-21-srodowisko-walka.md): an art-library
## model fitted into a box where there is one (fit()), else plain shapes in
## the museum's materials (box(), cylinder(), rod()); materials are shared.

const IRON := Color(0.2, 0.2, 0.21)
const STEEL := Color(0.52, 0.53, 0.55)
const BRASS := Color(0.72, 0.56, 0.28)
const TIMBER := Color(0.42, 0.29, 0.17)
const ROPE := Color(0.62, 0.53, 0.36)
const GYPSUM := Color(0.8, 0.76, 0.66)
const STONE := Color(0.66, 0.6, 0.5)
const MARBLE := Color(0.88, 0.86, 0.8)
## The hoist's paint: deep green (red belongs to the tags).
const HOIST := Color(0.16, 0.27, 0.2)

static var _materials: Dictionary = {}


## Model [param id] scaled to fill [param size] (its bounds' size; uniform
## when [param uniform]) with its bounds' bottom centre at the origin, or
## null when the model is not there (greybox).
static func fit(id: StringName, size: Vector3, uniform: bool = true) -> Node3D:
	var model := ArtLibrary.try_instance(id)
	if model == null:
		return null
	var box := local_bounds(model)
	if box.size.x <= 0.001 or box.size.y <= 0.001:
		model.free()
		return null
	var k := size / box.size.max(Vector3.ONE * 0.001)
	if uniform:
		var s := minf(k.x, minf(k.y, k.z)) if size.z > 0.0 else minf(k.x, k.y)
		k = Vector3.ONE * s
	var holder := Node3D.new()
	holder.name = String(id)
	var bottom := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	model.transform = Transform3D(Basis.from_scale(k), -bottom * k)
	holder.add_child(model)
	return holder


## The bounds of the meshes under [param node] in its own space (no tree
## needed).
static func local_bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array = [[node, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var current := item[0] as Node3D
		var xform: Transform3D = item[1]
		var view := current as MeshInstance3D
		if view != null and view.mesh != null:
			var placed := xform * view.mesh.get_aabb()
			box = placed if first else box.merge(placed)
			first = false
		for child in current.get_children():
			if child is Node3D:
				stack.append([child, xform * (child as Node3D).transform])
	return box


static func box(parent: Node3D, size: Vector3, at: Vector3, color: Color, roughness: float = 0.8, metallic: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _view(parent, mesh, Transform3D(Basis.IDENTITY, at), color, roughness, metallic)


## An upright cylinder of [param radius] and [param height] centred at [param at].
static func cylinder(parent: Node3D, radius: float, height: float, at: Vector3, color: Color, sides: int = 16, roughness: float = 0.8, metallic: float = 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return _view(parent, mesh, Transform3D(Basis.IDENTITY, at), color, roughness, metallic)


## A rod of [param radius] from [param a] to [param b] (a chain, a rope, a prop).
static func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color, roughness: float = 0.7, metallic: float = 0.0) -> MeshInstance3D:
	var span := b - a
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = maxf(span.length(), 0.01)
	mesh.radial_segments = 8
	mesh.rings = 1
	var up := span.normalized() if span.length() > 0.001 else Vector3.UP
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	var basis := Basis(side, up, side.cross(up))
	return _view(parent, mesh, Transform3D(basis, (a + b) * 0.5), color, roughness, metallic)


static func material(color: Color, roughness: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "%s/%s/%s" % [color, roughness, metallic]
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = roughness
		mat.metallic = metallic
		_materials[key] = mat
	return _materials[key]


static func _view(parent: Node3D, mesh: Mesh, xform: Transform3D, color: Color, roughness: float, metallic: float) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.transform = xform
	view.material_override = material(color, roughness, metallic)
	parent.add_child(view)
	return view
