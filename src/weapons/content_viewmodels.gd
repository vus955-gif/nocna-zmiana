class_name ContentViewmodels
## Greybox first-person models of the content pass: the crank gatling
## (Kartaczownica, 1871) and the flare gun, the fallback when the Blender
## models (ArtLibrary ids vm_gatling / vm_flare, on a ViewmodelRig) are off
## or missing, and the greybox exhibits' display pieces. Built like
## Viewmodels (boxes and cylinders, viewmodel materials, a "Muzzle" marker
## on the root), with the parts the views animate named ("barrels",
## "crank", "belt", "barrel", "shell", "Muzzle"). The root carries
## the view script (GatlingView / FlareView) that WeaponHolder drives; the
## meshes sit under a "model" node the view may jolt (the holder moves the
## root).

const IDS: Array[StringName] = [&"gatling", &"flare", &"rifle_hunt", &"harpoon", &"hwacha"]

const BRASS := Color(0.74, 0.56, 0.24)
const STEEL := Color(0.24, 0.25, 0.27)
const DARK := Color(0.12, 0.12, 0.13)
const WOOD := Color(0.42, 0.26, 0.14)
const OLIVE := Color(0.26, 0.3, 0.2)
const ORANGE := Color(0.95, 0.38, 0.06)
const FLARE_RED := Color(0.8, 0.1, 0.08)


static func has(id: StringName) -> bool:
	return IDS.has(id)


## The same fill light a ViewmodelRig carries (it reaches only the first-
## person layer), for a content view in the guard's hands.
static func add_fill(view: Node3D) -> void:
	var fill := OmniLight3D.new()
	fill.name = "Fill"
	fill.position = ViewmodelRig.FILL_AT
	fill.light_color = ViewmodelRig.FILL_COLOR
	fill.light_energy = ViewmodelRig.FILL_ENERGY
	fill.light_specular = 0.6
	fill.omni_range = 1.4
	fill.light_cull_mask = ArtLibrary.VIEWMODEL_LAYER
	fill.shadow_enabled = false
	view.add_child(fill)


static func build(id: StringName) -> Node3D:
	match id:
		&"gatling":
			return _gatling()
		&"flare":
			return _flare()
		&"rifle_hunt":
			return _rifle()
		&"harpoon":
			return _harpoon()
		&"hwacha":
			return _hwacha()
	return null


## Greybox hunting rifle: a long blued barrel on a walnut stock, the bolt
## handle on the right ("bolt"), iron sights.
static func _rifle() -> Node3D:
	var root := Node3D.new()
	root.name = "rifle_hunt"
	var model := _node(root, "model", Vector3(0.0, 0.0, 0.0))
	_box(model, Vector3(0.05, 0.07, 0.5), Vector3(0.0, -0.035, 0.12), WOOD)
	_tube(model, 0.012, 0.62, Vector3(0.0, 0.0, -0.36), STEEL)
	_box(model, Vector3(0.035, 0.04, 0.16), Vector3(0.0, 0.0, -0.02), STEEL)
	var bolt := _node(model, "bolt", Vector3(0.0, 0.0, 0.04))
	_box(bolt, Vector3(0.06, 0.012, 0.012), Vector3(0.03, 0.0, 0.0), STEEL)
	_box(bolt, Vector3(0.02, 0.02, 0.02), Vector3(0.06, 0.0, 0.0), DARK).name = "bolt_knob"
	_box(model, Vector3(0.006, 0.012, 0.006), Vector3(0.0, 0.018, -0.66), BRASS)
	_muzzle(root, Vector3(0.0, 0.0, -0.67))
	return root


## Greybox harpoon gun: a thick short barrel on a stock with the harpoon
## ("head") sticking out of the muzzle.
static func _harpoon() -> Node3D:
	var root := Node3D.new()
	root.name = "harpoon"
	var model := _node(root, "model", Vector3.ZERO)
	_box(model, Vector3(0.06, 0.08, 0.36), Vector3(0.0, -0.04, 0.12), WOOD)
	_tube(model, 0.03, 0.42, Vector3(0.0, 0.0, -0.2), STEEL)
	var head := _node(model, "head", Vector3(0.0, 0.0, -0.41))
	_tube(head, 0.01, 0.3, Vector3(0.0, 0.0, -0.12), DARK)
	_box(head, Vector3(0.05, 0.012, 0.07), Vector3(0.0, 0.0, -0.28), STEEL)
	_muzzle(root, Vector3(0.0, 0.0, -0.42))
	return root


## Greybox fire-arrow chest: a red box of six tubes on a short stock, an
## arrow in every tube ("rocket_1".."rocket_6").
static func _hwacha() -> Node3D:
	var root := Node3D.new()
	root.name = "hwacha"
	var model := _node(root, "model", Vector3(0.02, -0.03, 0.0))
	_box(model, Vector3(0.18, 0.12, 0.3), Vector3(0.0, 0.0, -0.1), FLARE_RED.darkened(0.3))
	_box(model, Vector3(0.05, 0.08, 0.2), Vector3(0.0, -0.08, 0.12), WOOD)
	for i in 6:
		var at := Vector3(-0.055 + (i % 3) * 0.055, -0.03 + floori(i / 3.0) * 0.06, -0.26)
		var rocket := _node(model, "rocket_%d" % (i + 1), at)
		_tube(rocket, 0.008, 0.06, Vector3(0.0, 0.0, -0.03), BRASS)
	_muzzle(root, Vector3(0.02, -0.03, -0.28))
	return root


## Six barrels round a spindle, brass breech, crank on the right, an ammo
## box with a belt of rounds on the left, spade grips at the back.
static func _gatling() -> Node3D:
	var root := GatlingView.new()
	root.name = "gatling"
	var model := _node(root, "model", GatlingView.MODEL_REST)
	model.scale = Vector3.ONE * GatlingView.MODEL_SCALE
	# breech casing and the back plate
	_box(model, Vector3(0.15, 0.15, 0.2), Vector3(0.0, 0.0, 0.06), BRASS)
	_box(model, Vector3(0.12, 0.12, 0.03), Vector3(0.0, 0.0, 0.175), STEEL)
	# spade grips
	for side in [-1.0, 1.0]:
		_box(model, Vector3(0.025, 0.1, 0.03), Vector3(side * 0.045, -0.02, 0.22), WOOD, Vector3(-15.0, 0.0, 0.0))
	# the turning cluster: barrels, spindle, two bands
	var barrels := _node(model, "barrels", Vector3(0.0, 0.0, -0.04))
	for i in 6:
		var angle := TAU * i / 6.0
		_tube(barrels, 0.013, 0.56, Vector3(cos(angle) * 0.042, sin(angle) * 0.042, -0.27), STEEL).name = "barrel_%d" % i
	_tube(barrels, 0.018, 0.58, Vector3(0.0, 0.0, -0.27), DARK)
	for z in [-0.12, -0.44]:
		_tube(barrels, 0.062, 0.025, Vector3(0.0, 0.0, z), BRASS)
	# a fixed muzzle ring holding the barrel ends
	_tube(model, 0.064, 0.03, Vector3(0.0, 0.0, -0.56), STEEL)
	# the crank on the right: a hub, an arm and a wooden handle
	var crank := _node(model, "crank", Vector3(0.09, 0.0, 0.08))
	_tube(crank, 0.02, 0.03, Vector3(0.0, 0.0, 0.0), STEEL, Vector3(0.0, 0.0, 90.0))
	_box(crank, Vector3(0.018, 0.12, 0.022), Vector3(0.012, -0.05, 0.0), STEEL)
	_tube(crank, 0.013, 0.07, Vector3(0.045, -0.1, 0.0), WOOD, Vector3(0.0, 0.0, 90.0))
	# ammo box and the belt running into the breech
	var belt := _node(model, "belt", Vector3(-0.14, -0.05, 0.04))
	_box(belt, Vector3(0.1, 0.11, 0.15), Vector3.ZERO, OLIVE)
	for i in 5:
		_box(belt, Vector3(0.012, 0.03, 0.022), Vector3(0.055 + i * 0.012, 0.05 + i * 0.006, -0.02 + (i % 2) * 0.004), BRASS)
	_muzzle(root, GatlingView.MODEL_REST + Vector3(0.0, 0.0, -0.58) * GatlingView.MODEL_SCALE)
	return root


## A stubby orange break-action flare pistol with a red flare cartridge.
static func _flare() -> Node3D:
	var root := FlareView.new()
	root.name = "flare"
	var model := _node(root, "model", Vector3(0.0, 0.0, 0.02))
	model.scale = Vector3.ONE * 0.85
	_box(model, Vector3(0.055, 0.07, 0.1), Vector3(0.0, -0.005, 0.03), ORANGE)
	_box(model, Vector3(0.05, 0.13, 0.065), Vector3(0.0, -0.09, 0.08), ORANGE.darkened(0.25), Vector3(-14.0, 0.0, 0.0))
	_box(model, Vector3(0.012, 0.03, 0.02), Vector3(0.0, 0.04, 0.075), DARK)
	_box(model, Vector3(0.01, 0.045, 0.035), Vector3(0.0, -0.05, 0.035), DARK)
	# the barrel hinges down at its front-bottom edge (break action)
	var barrel := _node(model, "barrel", Vector3(0.0, -0.02, -0.02))
	_tube(barrel, 0.03, 0.2, Vector3(0.0, 0.035, -0.08), ORANGE)
	_tube(barrel, 0.02, 0.005, Vector3(0.0, 0.035, -0.182), DARK)
	var shell := _node(barrel, "shell", Vector3(0.0, 0.035, 0.03))
	_tube(shell, 0.024, 0.03, Vector3.ZERO, FLARE_RED)
	_tube(shell, 0.01, 0.032, Vector3.ZERO, BRASS)
	_muzzle(root, Vector3(0.0, 0.013, -0.14))
	return root


static func _node(parent: Node3D, node_name: String, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = pos
	parent.add_child(node)
	return node


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, pos, rot_deg, color)


## Cylinder lying along Z unless turned by [param rot_deg] (added to the
## lying-down turn).
static func _tube(parent: Node3D, radius: float, length: float, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 10
	mesh.rings = 1
	return _add(parent, mesh, pos, Vector3(90.0, 0.0, 0.0) + rot_deg, color)


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, rot_deg: Vector3, color: Color) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = pos
	view.rotation_degrees = rot_deg
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.layers = ArtLibrary.VIEWMODEL_LAYER   # first person only: lit by the view's fill light, never in a CCTV feed
	view.material_override = Viewmodels.material(color)
	parent.add_child(view)
	return view


static func _muzzle(parent: Node3D, pos: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = "Muzzle"
	marker.position = pos
	parent.add_child(marker)
