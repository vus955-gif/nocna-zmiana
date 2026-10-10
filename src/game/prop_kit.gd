class_name PropKit
## Small greybox props of the night (fuses, the fuse box door, the locker
## door, the drawer, the key, the crystal): boxes and shapes with shared
## materials, built in code until stage-3 art replaces them. Every prop
## root is tagged like a LevelKit piece (metadata "kit", "kit_size") so the
## art pass can find it.

static var _materials: Dictionary = {}


## A box mesh of [param size] centred at [param at] under [param parent].
static func box(parent: Node3D, size: Vector3, at: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, at, color, glow)


static func cylinder(parent: Node3D, radius: float, height: float, at: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	return _add(parent, mesh, at, color, glow)


static func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f" % [color.to_html(), glow]
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.5
		if glow > 0.0:
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = glow
		_materials[key] = mat
	return _materials[key]


## A small point light without shadows that fades with distance.
static func glow_light(parent: Node3D, color: Color, energy: float, reach: float, at: Vector3) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.position = at
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = 0.0
	light.distance_fade_enabled = true
	light.distance_fade_begin = 24.0
	light.distance_fade_length = 8.0
	parent.add_child(light)
	return light


static func _add(parent: Node3D, mesh: Mesh, at: Vector3, color: Color, glow: float) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = at
	view.material_override = material(color, glow)
	parent.add_child(view)
	return view
