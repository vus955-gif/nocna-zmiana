class_name StoryProps
## The small things the staff left lying about (StoryVignettes): built here
## from a few primitives in the house's plain, slightly worn materials, or
## from the art's models where there is one (the lantern, the chairs). No
## collision: they are what the guard steps round, not what stops him.
## Origins: a thing on the floor stands on its origin, -Z the way it points
## (the torch's beam, the arrow's head); a thing on a wall has its origin on
## the wall's face, -Z out of it.

const KINDS: Array[StringName] = [
	&"toolbox", &"lantern", &"stethoscope", &"chalk_tally", &"chalk_cross", &"chalk_arrow",
	&"cap", &"torch", &"scratches", &"basket", &"seed", &"feather", &"chair", &"splint",
	&"oil_can", &"rag", &"plate", &"hammer", &"stool", &"stool_tipped", &"flag", &"leaflet", &"clipboard",
]
const CHALK := Color(0.88, 0.87, 0.82)
const BEAM := Color(1.0, 0.9, 0.7)

static var _materials: Dictionary = {}


## The prop [param kind] (null for an unknown kind). [param seed] varies the
## scattered ones (feathers, scales, scratches).
static func make(kind: StringName, seed: int = 0) -> Node3D:
	var root := Node3D.new()
	root.name = "Prop_" + String(kind)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(kind)) ^ seed
	match kind:
		&"toolbox":
			_toolbox(root)
		&"lantern":
			_lantern(root)
		&"stethoscope":
			_stethoscope(root)
		&"chalk_tally":
			_chalk_tally(root)
		&"chalk_cross":
			_chalk_cross(root)
		&"chalk_arrow":
			_chalk_arrow(root)
		&"cap":
			_cap(root)
		&"torch":
			_torch(root)
		&"scratches":
			_scratches(root, rng)
		&"basket":
			_basket(root)
		&"seed":
			_seed(root)
		&"feather":
			_feather(root, rng)
		&"chair":
			_model_or_box(root, &"chair", Vector3(0.52, 1.0, 0.48), Color(0.36, 0.25, 0.17), true)
		&"splint":
			_splint(root)
		&"oil_can":
			_oil_can(root)
		&"rag":
			_rag(root)
		&"plate":
			_plates(root, rng)
		&"hammer":
			_hammer(root)
		&"stool":
			_model_or_box(root, &"camp_chair", Vector3(0.56, 0.88, 0.53), Color(0.42, 0.33, 0.22), false)
		&"stool_tipped":
			_model_or_box(root, &"camp_chair", Vector3(0.56, 0.88, 0.53), Color(0.42, 0.33, 0.22), true)
		&"flag":
			_flag(root)
		&"leaflet":
			_leaflet(root, rng)
		&"clipboard":
			_clipboard(root)
		_:
			root.free()
			return null
	return root


## A plain material, shared per look.
static func material(color: Color, roughness: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f" % [color.to_html(), roughness, metallic]
	if not _materials.has(key):
		var made := StandardMaterial3D.new()
		made.albedo_color = color
		made.roughness = roughness
		made.metallic = metallic
		_materials[key] = made
	return _materials[key]


static func glow(color: Color, energy: float) -> StandardMaterial3D:
	var key := "glow_%s_%.1f" % [color.to_html(), energy]
	if not _materials.has(key):
		var made := StandardMaterial3D.new()
		made.albedo_color = color
		made.emission_enabled = true
		made.emission = color
		made.emission_energy_multiplier = energy
		_materials[key] = made
	return _materials[key]


## A soft unlit cone of light (no real lamp: the torch's beam on the floor).
static func beam_material() -> StandardMaterial3D:
	if not _materials.has("beam"):
		var made := StandardMaterial3D.new()
		made.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		made.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		made.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		made.cull_mode = BaseMaterial3D.CULL_DISABLED
		made.albedo_color = Color(BEAM, 0.06)
		made.disable_receive_shadows = true
		_materials["beam"] = made
	return _materials["beam"]


static func _box(parent: Node3D, size: Vector3, at: Vector3, look: Material, turn: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = look
	view.position = at
	view.rotation = turn
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if size.y < 0.02 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(view)
	return view


static func _cylinder(parent: Node3D, radius: float, length: float, at: Vector3, look: Material, turn: Vector3 = Vector3.ZERO, top: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0.0 else top
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 12
	mesh.rings = 1
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = look
	view.position = at
	view.rotation = turn
	parent.add_child(view)
	return view


## The art's model [param model] when there is one, else a box of
## [param size]; [param tipped]: lying on its side.
static func _model_or_box(root: Node3D, model: StringName, size: Vector3, color: Color, tipped: bool) -> void:
	var thing := ArtLibrary.try_instance(model)
	if thing == null:
		thing = Node3D.new()
		_box(thing, size, Vector3(0.0, size.y * 0.5, 0.0), material(color))
	thing.name = "Model"
	if tipped:
		# on its side: a quarter turn about its depth axis (its top to -X),
		# its -X side on the floor, centred on the origin
		thing.transform = Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(size.y * 0.5, size.x * 0.5, 0.0))
	root.add_child(thing)


# --- Egypt: Gil's things ----------------------------------------------------

## An open steel toolbox, its lid thrown back, tools on top.
static func _toolbox(root: Node3D) -> void:
	var paint := material(Color(0.55, 0.14, 0.1), 0.6, 0.3)
	var steel := material(Color(0.55, 0.56, 0.58), 0.4, 0.8)
	var wood := material(Color(0.5, 0.36, 0.2))
	_box(root, Vector3(0.5, 0.2, 0.24), Vector3(0.0, 0.1, 0.0), paint)
	_box(root, Vector3(0.5, 0.02, 0.24), Vector3(0.0, 0.24, 0.17), paint, Vector3(deg_to_rad(-70.0), 0.0, 0.0))
	_box(root, Vector3(0.36, 0.015, 0.012), Vector3(0.0, 0.215, 0.0), steel)
	_cylinder(root, 0.012, 0.28, Vector3(-0.1, 0.22, -0.05), wood, Vector3(0.0, 0.0, PI * 0.5 - 0.2))
	_box(root, Vector3(0.06, 0.04, 0.03), Vector3(0.05, 0.25, -0.05), steel)
	_box(root, Vector3(0.22, 0.012, 0.03), Vector3(0.12, 0.215, 0.06), steel, Vector3(0.0, 0.5, 0.0))


## The work lamp: the art's hand lantern (its glass glows), else a box.
static func _lantern(root: Node3D) -> void:
	var lamp := ArtLibrary.try_instance(&"lantern")
	if lamp == null:
		lamp = Node3D.new()
		_box(lamp, Vector3(0.14, 0.2, 0.12), Vector3(0.0, 0.1, 0.0), glow(PropArt.LANTERN_COLOR, 3.0))
	lamp.name = "Model"
	root.add_child(lamp)


## A stethoscope hanging from a nail on the wall.
static func _stethoscope(root: Node3D) -> void:
	var rubber := material(Color(0.07, 0.07, 0.08), 0.6)
	var steel := material(Color(0.7, 0.71, 0.73), 0.3, 0.9)
	_cylinder(root, 0.004, 0.05, Vector3(0.0, 0.0, -0.025), steel, Vector3(PI * 0.5, 0.0, 0.0))
	# the ear tubes hang in a V from the nail, the tube down to the chest piece
	_cylinder(root, 0.004, 0.22, Vector3(-0.035, -0.1, -0.03), steel, Vector3(0.0, 0.0, -0.3))
	_cylinder(root, 0.004, 0.22, Vector3(0.035, -0.1, -0.03), steel, Vector3(0.0, 0.0, 0.3))
	_cylinder(root, 0.006, 0.42, Vector3(0.0, -0.42, -0.03), rubber)
	_cylinder(root, 0.025, 0.012, Vector3(0.0, -0.64, -0.03), steel, Vector3(PI * 0.5, 0.0, 0.0))


## Chalk on the plaster: a tally of knocks in two rows, four strokes and a
## slash to a group (twenty-seven, and counting).
static func _chalk_tally(root: Node3D) -> void:
	var chalk := material(CHALK, 1.0)
	var left := 27
	for row in 2:
		for group in 3:
			if left <= 0:
				return
			var x0 := -0.2 + group * 0.15
			var y := 0.07 - row * 0.15
			var strokes := mini(left, 5)
			for k in mini(strokes, 4):
				_box(root, Vector3(0.008, 0.1, 0.002), Vector3(x0 + k * 0.022, y, -0.003), chalk, Vector3(0.0, 0.0, 0.05 * (k - 1.5)))
			if strokes == 5:
				_box(root, Vector3(0.11, 0.008, 0.002), Vector3(x0 + 0.033, y, -0.004), chalk, Vector3(0.0, 0.0, 0.6))
			left -= strokes


## A chalk cross on the plaster.
static func _chalk_cross(root: Node3D) -> void:
	var chalk := material(CHALK, 1.0)
	_box(root, Vector3(0.42, 0.025, 0.002), Vector3(0.0, 0.0, -0.003), chalk, Vector3(0.0, 0.0, 0.75))
	_box(root, Vector3(0.42, 0.025, 0.002), Vector3(0.0, 0.0, -0.004), chalk, Vector3(0.0, 0.0, -0.75))


## A chalk arrow on the floor, its head to -Z.
static func _chalk_arrow(root: Node3D) -> void:
	var chalk := material(CHALK, 1.0)
	_box(root, Vector3(0.05, 0.003, 0.55), Vector3(0.0, 0.002, 0.05), chalk)
	_box(root, Vector3(0.05, 0.003, 0.26), Vector3(-0.07, 0.002, -0.15), chalk, Vector3(0.0, -0.7, 0.0))
	_box(root, Vector3(0.05, 0.003, 0.26), Vector3(0.07, 0.002, -0.15), chalk, Vector3(0.0, 0.7, 0.0))


# --- the guards' things ----------------------------------------------------------

## A security guard's peaked cap lying tilted on the floor.
static func _cap(root: Node3D) -> void:
	var cloth := material(Color(0.1, 0.12, 0.2), 0.9)
	var visor := material(Color(0.03, 0.03, 0.04), 0.35)
	var brass := material(Color(0.78, 0.6, 0.3), 0.35, 0.85)
	var cap := Node3D.new()
	cap.rotation = Vector3(0.25, 0.0, 0.18)
	cap.position.y = 0.05
	root.add_child(cap)
	_cylinder(cap, 0.1, 0.07, Vector3(0.0, 0.0, 0.0), cloth, Vector3.ZERO, 0.115)
	_cylinder(cap, 0.12, 0.015, Vector3(0.0, 0.04, 0.0), cloth)
	_box(cap, Vector3(0.16, 0.008, 0.07), Vector3(0.0, -0.03, -0.12), visor, Vector3(0.2, 0.0, 0.0))
	_box(cap, Vector3(0.035, 0.03, 0.006), Vector3(0.0, 0.01, -0.1), brass)


## A torch lying on the floor, still shining (its lens glows and a faint
## cone of light lies along the floor, -Z; no real lamp).
static func _torch(root: Node3D) -> void:
	var body := material(Color(0.08, 0.08, 0.09), 0.5, 0.4)
	var rim := material(Color(0.6, 0.6, 0.62), 0.3, 0.9)
	_cylinder(root, 0.02, 0.2, Vector3(0.0, 0.022, 0.1), body, Vector3(PI * 0.5, 0.0, 0.0))
	_cylinder(root, 0.032, 0.05, Vector3(0.0, 0.03, -0.02), rim, Vector3(PI * 0.5, 0.0, 0.0), 0.026)
	_cylinder(root, 0.029, 0.004, Vector3(0.0, 0.03, -0.047), glow(BEAM, 6.0), Vector3(PI * 0.5, 0.0, 0.0))
	var cone := _cylinder(root, 0.4, 1.8, Vector3(0.0, 0.05, -0.95), beam_material(), Vector3(PI * 0.5, 0.0, 0.0), 0.03)
	cone.name = "Beam"
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Claw marks gouged into the floor: four parallel scratches along -Z.
static func _scratches(root: Node3D, rng: RandomNumberGenerator) -> void:
	var gouge := material(Color(0.12, 0.1, 0.08), 1.0)
	var pale := material(Color(0.62, 0.58, 0.5), 1.0)
	for i in 4:
		var x := (i - 1.5) * 0.045 + rng.randf_range(-0.008, 0.008)
		var length := rng.randf_range(0.42, 0.62)
		_box(root, Vector3(0.012, 0.003, length), Vector3(x, 0.002, rng.randf_range(-0.04, 0.04)), gouge, Vector3(0.0, rng.randf_range(-0.06, 0.06), 0.0))
		_box(root, Vector3(0.006, 0.0035, length * 0.9), Vector3(x + 0.009, 0.002, 0.0), pale)


# --- Greece: Turek's pigeons ---------------------------------------------------

## A wicker pigeon basket, its little door open.
static func _basket(root: Node3D) -> void:
	var wicker := material(Color(0.6, 0.46, 0.26), 0.95)
	var dark := material(Color(0.36, 0.26, 0.14), 0.95)
	_box(root, Vector3(0.56, 0.36, 0.4), Vector3(0.0, 0.18, 0.0), wicker)
	for i in 6:
		_box(root, Vector3(0.018, 0.36, 0.41), Vector3(-0.24 + i * 0.096, 0.18, 0.0), dark)
	_box(root, Vector3(0.58, 0.03, 0.42), Vector3(0.0, 0.375, 0.0), dark)
	_box(root, Vector3(0.18, 0.16, 0.015), Vector3(0.1, 0.12, -0.27), wicker, Vector3(0.0, 0.9, 0.0))
	_box(root, Vector3(0.012, 0.012, 0.3), Vector3(0.0, 0.42, 0.0), dark, Vector3(PI * 0.5, 0.0, 0.0))


## A slumped sack of grain and the grain spilt from it.
static func _seed(root: Node3D) -> void:
	var sack := material(Color(0.52, 0.43, 0.3), 1.0)
	var grain := material(Color(0.78, 0.66, 0.4), 1.0)
	var bag := MeshInstance3D.new()
	var round := SphereMesh.new()
	round.radius = 0.2
	round.height = 0.4
	bag.mesh = round
	bag.material_override = sack
	bag.scale = Vector3(0.9, 0.6, 0.8)
	bag.position = Vector3(0.0, 0.12, 0.1)
	root.add_child(bag)
	_cylinder(root, 0.32, 0.012, Vector3(0.05, 0.006, -0.18), grain, Vector3.ZERO, 0.26)


## A pigeon's feather lying on the floor.
static func _feather(root: Node3D, rng: RandomNumberGenerator) -> void:
	var white := material(Color(0.86, 0.86, 0.84).darkened(rng.randf_range(0.0, 0.3)), 1.0)
	_box(root, Vector3(0.035, 0.002, 0.13), Vector3(0.0, 0.002, 0.0), white, Vector3(0.0, rng.randf_range(-0.4, 0.4), 0.0))
	_box(root, Vector3(0.003, 0.003, 0.05), Vector3(0.0, 0.003, 0.08), material(Color(0.5, 0.5, 0.5)))


# --- the Enlightenment: Heniek's splint ---------------------------------------------

## A wooden ruler and a roll of bandage, half unrolled.
static func _splint(root: Node3D) -> void:
	var wood := material(Color(0.78, 0.62, 0.38), 0.7)
	var linen := material(Color(0.9, 0.88, 0.82), 1.0)
	_box(root, Vector3(0.5, 0.006, 0.035), Vector3(0.0, 0.003, 0.0), wood, Vector3(0.0, 0.2, 0.0))
	_cylinder(root, 0.035, 0.06, Vector3(0.18, 0.035, 0.16), linen, Vector3(PI * 0.5, 0.4, 0.0))
	_box(root, Vector3(0.05, 0.002, 0.38), Vector3(0.05, 0.002, 0.3), linen, Vector3(0.0, 0.9, 0.0))


# --- Asia: Kowalik's things ---------------------------------------------------------

static func _oil_can(root: Node3D) -> void:
	var tin := material(Color(0.2, 0.3, 0.2), 0.5, 0.5)
	var brass := material(Color(0.7, 0.55, 0.28), 0.35, 0.85)
	_cylinder(root, 0.05, 0.1, Vector3(0.0, 0.05, 0.0), tin, Vector3.ZERO, 0.04)
	_cylinder(root, 0.006, 0.16, Vector3(0.0, 0.15, -0.05), brass, Vector3(-0.7, 0.0, 0.0), 0.003)


static func _rag(root: Node3D) -> void:
	var cloth := material(Color(0.42, 0.38, 0.32), 1.0)
	var heap := MeshInstance3D.new()
	var round := SphereMesh.new()
	round.radius = 0.12
	round.height = 0.24
	heap.mesh = round
	heap.material_override = cloth
	heap.scale = Vector3(1.2, 0.22, 0.8)
	heap.position = Vector3(0.0, 0.025, 0.0)
	root.add_child(heap)


## A few lacquered armour scales fallen off their laces.
static func _plates(root: Node3D, rng: RandomNumberGenerator) -> void:
	var lacquer := material(Color(0.42, 0.08, 0.06), 0.3, 0.1)
	for i in 3:
		var at := Vector3(rng.randf_range(-0.12, 0.12), 0.004, rng.randf_range(-0.12, 0.12))
		_box(root, Vector3(0.05, 0.006, 0.08), at, lacquer, Vector3(0.0, rng.randf_range(-PI, PI), 0.0))


static func _hammer(root: Node3D) -> void:
	var wood := material(Color(0.46, 0.32, 0.18), 0.7)
	var steel := material(Color(0.4, 0.41, 0.43), 0.4, 0.85)
	_cylinder(root, 0.013, 0.3, Vector3(0.0, 0.016, 0.02), wood, Vector3(PI * 0.5, 0.0, 0.0))
	_box(root, Vector3(0.1, 0.032, 0.032), Vector3(0.0, 0.022, -0.14), steel)


# --- the Americas: the rehearsal ----------------------------------------------------

## A guide's telescopic flag pole lying on the floor, its pennant to -Z.
static func _flag(root: Node3D) -> void:
	var pole := material(Color(0.7, 0.71, 0.73), 0.3, 0.8)
	var cloth := material(Color(0.86, 0.6, 0.12), 0.9)
	_cylinder(root, 0.008, 1.1, Vector3(0.0, 0.01, 0.0), pole, Vector3(PI * 0.5, 0.0, 0.0))
	_box(root, Vector3(0.22, 0.003, 0.16), Vector3(0.11, 0.006, -0.47), cloth, Vector3(0.0, 0.0, 0.0))


## A leaflet of the night tour lying on the floor.
static func _leaflet(root: Node3D, rng: RandomNumberGenerator) -> void:
	var paper := material(Color(0.9, 0.88, 0.82), 1.0)
	var band := material(Color(0.22, 0.56, 0.54), 0.9)
	var sheet := Node3D.new()
	sheet.rotation.y = rng.randf_range(-0.5, 0.5)
	root.add_child(sheet)
	_box(sheet, Vector3(0.15, 0.002, 0.21), Vector3(0.0, 0.002, 0.0), paper)
	_box(sheet, Vector3(0.15, 0.0025, 0.04), Vector3(0.0, 0.0025, -0.075), band)


## A clipboard with its list, dropped face up.
static func _clipboard(root: Node3D) -> void:
	var board := material(Color(0.42, 0.3, 0.18), 0.8)
	var paper := material(Color(0.92, 0.91, 0.86), 1.0)
	var ink := material(Color(0.15, 0.15, 0.2), 1.0)
	var steel := material(Color(0.7, 0.71, 0.73), 0.3, 0.8)
	_box(root, Vector3(0.23, 0.006, 0.32), Vector3(0.0, 0.003, 0.0), board)
	_box(root, Vector3(0.21, 0.002, 0.28), Vector3(0.0, 0.007, 0.01), paper)
	for i in 7:
		_box(root, Vector3(0.12 if i % 2 == 0 else 0.1, 0.001, 0.006), Vector3(-0.02, 0.0085, -0.08 + i * 0.03), ink)
	_box(root, Vector3(0.08, 0.012, 0.025), Vector3(0.0, 0.01, -0.145), steel)
