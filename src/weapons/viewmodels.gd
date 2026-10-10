class_name Viewmodels
## First-person weapon models: the Blender models with the guard's hands
## (ViewmodelRig: vm_pistol, vm_taser, vm_shotgun, vm_fists, vm_gatling,
## vm_flare), or greybox boxes and cylinders built in code when a model is
## off or missing (ContentViewmodels for the gatling and the flare gun). Every
## model has a "Muzzle" marker as a direct child. Materials use the
## engine's viewmodel options (own FOV + squashed depth), so weapons never
## poke into walls.

const FOV := 55.0
## Parts of a vm_* model that belong to the guard, not the weapon.
const HANDS: Array[String] = ["hand_r", "hand_l"]

static var _materials: Dictionary = {}


static func build(id: StringName) -> Node3D:
	var view: Node3D = ViewmodelRig.create(id)
	if view == null:
		view = greybox(id)
	first_person_layer(view)
	return view


## Every mesh of a first-person view on render layer 20 only
## (ArtLibrary.VIEWMODEL_LAYER): the guard's camera shows it, lit by the
## world's lamps and the view's own fill light; other cameras (the CCTV)
## leave it out, so its own FOV never draws it over their walls.
static func first_person_layer(root: Node) -> void:
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).layers = ArtLibrary.VIEWMODEL_LAYER


## The weapon lying in the world (a pickup): its model without the hands
## and without upgrade parts (the museum's own, plain piece), with ordinary
## materials and shadows; null when the model is off or missing (use the
## greybox then).
static func world(id: StringName) -> Node3D:
	var model_name := StringName("vm_" + String(id))
	if not ArtLibrary.has_model(model_name):
		return null
	var root := ArtLibrary.model(String(model_name))
	for hand in HANDS:
		var node := root.find_child(hand, true, false)
		if node != null:
			node.get_parent().remove_child(node)
			node.free()
	for part in root.find_children(WeaponLook.PART_PREFIX + "*", "Node3D", true, false):
		(part as Node3D).visible = false
	return root


static func greybox(id: StringName) -> Node3D:
	if ContentViewmodels.has(id):
		return ContentViewmodels.build(id)   # gatling, flare gun (animated greybox views)
	var root := Node3D.new()
	root.name = String(id)
	match id:
		&"taser":
			_box(root, Vector3(0.07, 0.08, 0.18), Vector3.ZERO, Color(0.85, 0.7, 0.1))
			_box(root, Vector3(0.05, 0.12, 0.06), Vector3(0.0, -0.08, 0.05), Color(0.22, 0.22, 0.22))
			_box(root, Vector3(0.012, 0.012, 0.04), Vector3(-0.02, 0.01, -0.11), Color(0.8, 0.8, 0.85))
			_box(root, Vector3(0.012, 0.012, 0.04), Vector3(0.02, 0.01, -0.11), Color(0.8, 0.8, 0.85))
			_muzzle(root, Vector3(0.0, 0.01, -0.13))
		&"pistol":
			_box(root, Vector3(0.05, 0.07, 0.22), Vector3.ZERO, Color(0.34, 0.34, 0.37))
			_box(root, Vector3(0.045, 0.13, 0.06), Vector3(0.0, -0.09, 0.07), Color(0.22, 0.16, 0.12), Vector3(-12.0, 0.0, 0.0))
			_muzzle(root, Vector3(0.0, 0.01, -0.12))
		&"shotgun":
			_tube(root, 0.022, 0.62, Vector3(-0.024, 0.0, -0.16), Color(0.3, 0.3, 0.33))
			_tube(root, 0.022, 0.62, Vector3(0.024, 0.0, -0.16), Color(0.3, 0.3, 0.33))
			_box(root, Vector3(0.07, 0.07, 0.34), Vector3(0.0, -0.035, 0.2), Color(0.5, 0.3, 0.15))
			_muzzle(root, Vector3(0.0, 0.0, -0.48))
		&"fist":
			_box(root, Vector3(0.1, 0.09, 0.12), Vector3.ZERO, Color(0.22, 0.17, 0.14))
			_box(root, Vector3(0.09, 0.08, 0.14), Vector3(0.0, -0.005, 0.12), Color(0.15, 0.2, 0.35))
			_muzzle(root, Vector3(0.0, 0.0, -0.08))
	return root


static func material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.45
		mat.metallic = 0.2
		mat.use_fov_override = true
		mat.fov_override = FOV
		mat.use_z_clip_scale = true
		mat.z_clip_scale = 0.25
		_materials[color] = mat
	return _materials[color]


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_add(parent, mesh, pos, rot_deg, color)


## Cylinder lying along Z (barrels).
static func _tube(parent: Node3D, radius: float, length: float, pos: Vector3, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	_add(parent, mesh, pos, Vector3(90.0, 0.0, 0.0), color)


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, rot_deg: Vector3, color: Color) -> void:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = pos
	view.rotation_degrees = rot_deg
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.material_override = material(color)
	parent.add_child(view)


static func _muzzle(parent: Node3D, pos: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = "Muzzle"
	marker.position = pos
	parent.add_child(marker)
