class_name Floor1ArtAssyria
extends RefCounted
## Floor I's Assyrian wing dressed, stage P4 (plan docs/superpowers/plans/
## 2026-10-10-p4-oprawa-asyria-azja.md section 3; catalogue
## docs/art/kit-pietro1-asyria.md): grey alabaster, bronze and cedar in low,
## harsh light and red torches. Pure factories of Node3D trees of ArtLibrary
## models, no collision (the greybox keeps it); Floor1Art asks this module
## for every room whose id starts with "assyria_":
## - [method piece_look]: steles for the freestanding slabs, alabaster
##   blocks and steles for the genii the Lamassu charges into (their boxes
##   stay as they are), cedar columns, the Black Obelisk, the conservators'
##   scaffold, the hunting pit's chariot and cages, merlons for the gallery's
##   rails, tablet shelves and crates; the wall reliefs give way to the
##   rooms' relief bands (the Lion Hunt gallery keeps its own);
## - [method dress]: the hero pieces - the Khorsabad Gate on the greybox's
##   lamassu boxes, the awakening lion slabs under the gallery, carved
##   thresholds in the doorways, the merlons round the courtyard's sky;
## - [method fixture]: torches (asy_torch) and fire tripods (asy_brazier).

## Every model this module places (the art tests check each is registered,
## on disk and placed). The Balawat leaves are SealGate's (in the game).
const MODELS: Array[String] = [
	"khorsabad_gate", "asy_relief_2m", "asy_relief_1m", "asy_relief_wake", "asy_relief_wake_lion", "asy_frieze_1m",
	"asy_corbel", "asy_plinth", "asy_plinth_low", "asy_torch", "asy_brazier", "asy_tablet_shelf", "asy_tablet_crate",
	"asy_prism", "asy_portal_4m", "asy_threshold_4m", "asy_parapet_2m",
]
## The relief theme (texture set prefix of the asy_relief_ runs) by room;
## "" = the kit's default (the winged genius, the spearman).
const THEMES := {
	&"assyria_gate": "asy_relief_hunt_", &"assyria_balawat": "asy_relief_army_", &"assyria_courtyard": "asy_relief_chariot_",
	&"assyria_lions": "asy_relief_lions_", &"assyria_lions_gallery": "asy_relief_lions_", &"assyria_library": "asy_relief_text_",
	&"assyria_nimrud": "",
}
## The Khorsabad Gate: its origin on the gate hall's face of the wall to
## Egypt (the middle of the opening's floor), its body into the hall (-Z).
const GATE_AT := Vector3(-51.0, 0.0, -39.0)
## A panel on the relief band stands proud of its slabs' faces (0.12 thick)
## by a hair.
const PANEL_PROUD := 0.13
## The sleeping relief lions of the pit: the awakening slabs behind them
## (the slab's back a hair before the band, its face into the pit), the
## middle of each slab's foot and its yaw.
const LION_SLABS := [[Vector3(-95.87, -3.0, -27.0), -PI * 0.5], [Vector3(-79.13, -3.0, -14.0), PI * 0.5]]
## Thresholds lie this much over the passage floor.
const THRESHOLD_LIFT := 0.006
## The merlons' middles stand this far outside the sky well's edge (on the
## rim the shell raises round it).
const MERLON_SET_BACK := 0.25
## Bronze and iron of the procedural pieces, the Black Obelisk's basalt.
const BRONZE := Color(0.55, 0.42, 0.26)
const IRON := Color(0.16, 0.15, 0.15)
const BASALT := Color(0.13, 0.13, 0.15)
const OBELISK_TINT := Color(0.32, 0.32, 0.35)
## The capitals of cedar columns (four corbels) only on columns this tall.
const CAPITAL_FROM := 5.0

static var _bronze: StandardMaterial3D = null
static var _iron: StandardMaterial3D = null
static var _basalt: StandardMaterial3D = null
static var _cedar: Material = null
static var _tinted: Dictionary = {}


# --- pieces --------------------------------------------------------------------

## The look of [param spec] (a piece of an Assyrian room) in its own frame,
## or null (the common rules).
static func piece_look(spec: PieceSpec, index: int, layout: LevelLayout) -> Variant:
	var size := spec.size
	match spec.kit:
		&"lamassu":
			return _holder("Visual")   # the Khorsabad Gate's statues ([method dress])
		&"brazier":
			return _holder("Visual")   # the stand-in a fire tripod's legs stop the guard with (its look is the fixture's)
		&"relief":
			return _relief(spec, layout)
		&"relief_slab":
			return _stele(size, spec.room, _theme(spec.room), _back_theme(spec.room), index)
		&"pedestal":
			if spec.room == &"assyria_courtyard":
				return _banded_block(size, spec.room)
			if spec.room == &"assyria_balawat":
				return _fit("asy_plinth_low", size / Vector3(2.5, 0.4, 1.3))
			return _plinth(size)
		&"sculpture":
			if spec.room == &"assyria_courtyard":
				# a genius on its base: a carved stele filling the greybox box
				return _stele(size, spec.room, "", "asy_relief_text_", index)
			return null
		&"column", &"balcony_post":
			return _cedar_column(size, spec.room)
		&"obelisk":
			return _obelisk(size)
		&"scaffold":
			return _scaffold(size)
		&"chariot":
			return _chariot(size)
		&"cage":
			return _cage(size)
		&"railing":
			var rail := _holder("Visual")
			_merlons(rail, Transform3D.IDENTITY, -size.x * 0.5, size.x * 0.5)
			return rail
		&"shelf":
			return _tablet_shelves(size)
		&"crate":
			return _crate(spec, index)
		&"plinth":
			return _plinth(size)
		&"desk":
			if spec.room == &"assyria_library":
				return _reader_desk(size)
	return null


static func _holder(label: String) -> Node3D:
	var n := Node3D.new()
	n.name = label
	return n


## [param root] with model [param id] scaled by [param scale] at its origin.
static func _fit(id: String, scale: Vector3) -> Node3D:
	var root := _holder("Visual")
	ArtKit._add(root, id, Transform3D(Basis.from_scale(scale), Vector3.ZERO))
	return root


## A box of [param box] (in the parent's frame) in the room's tile field
## [param role] of [param room].
static func _box(parent: Node3D, box: AABB, room: StringName, role: StringName) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box.size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = ArtKit.field(room, role)
	view.position = box.get_center()
	parent.add_child(view)
	return view


## A box of [param box] in [param material].
static func _solid(parent: Node3D, box: AABB, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box.size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	view.position = box.get_center()
	parent.add_child(view)
	return view


## A cylinder of radius [param radius] from [param a] to [param b].
static func _rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material, radius_b: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if radius_b < 0.0 else radius_b
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 12
	mesh.rings = 1
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	view.transform = Transform3D(Basis(side, up, side.cross(up)), (a + b) * 0.5)
	parent.add_child(view)
	return view


static func bronze() -> StandardMaterial3D:
	if _bronze == null:
		_bronze = StandardMaterial3D.new()
		_bronze.resource_name = "asy_bronze"
		_bronze.albedo_color = BRONZE
		_bronze.metallic = 1.0
		_bronze.roughness = 0.38
	return _bronze


static func iron() -> StandardMaterial3D:
	if _iron == null:
		_iron = StandardMaterial3D.new()
		_iron.resource_name = "asy_iron"
		_iron.albedo_color = IRON
		_iron.metallic = 0.7
		_iron.roughness = 0.6
	return _iron


static func basalt() -> StandardMaterial3D:
	if _basalt == null:
		_basalt = StandardMaterial3D.new()
		_basalt.resource_name = "asy_basalt"
		_basalt.albedo_color = BASALT
		_basalt.roughness = 0.55
	return _basalt


## Cedar boards mapped in the piece's own frame (round shafts, planks).
static func cedar() -> Material:
	if _cedar == null:
		_cedar = ArtLibrary.arch_tile("asy_cedar", true)
	return _cedar


## The relief theme of [param room]'s steles' fronts.
static func _theme(room: StringName) -> String:
	return String(THEMES.get(room, ""))


## The theme of their backs: the genius turned the other way behind the
## default genius, the room's own theme elsewhere.
static func _back_theme(room: StringName) -> String:
	var front := _theme(room)
	return "asy_relief_genie_l_" if front == "" else front


## A wall relief of the greybox: nothing where the room's relief band runs
## (the band is the reliefs), runs of lion-hunt slabs on the Lion Hunt
## gallery's walls (over the ring, where no band is), and in the courtyard
## the awakening panels the relief warriors step off (centred on the
## lamassu_relief markers).
static func _relief(spec: PieceSpec, layout: LevelLayout) -> Node3D:
	var root := _holder("Visual")
	match spec.room:
		&"assyria_lions_gallery":
			ArtKit.run(root, "asy_relief_", -spec.size.x * 0.5, spec.size.x * 0.5, 0.0, _theme(spec.room))
		&"assyria_courtyard":
			var floor_y := 0.0
			var room := layout.room(spec.room) if layout != null else null
			if room != null:
				floor_y = room.floor_y - spec.position.y
			# three slabs standing on the floor, a hair before the band: the
			# spearman of the awakening slab in the middle
			var panel := _holder("Panel")
			panel.position = Vector3(0.0, floor_y, -PANEL_PROUD)
			root.add_child(panel)
			ArtKit._add(panel, "asy_relief_1m", Transform3D(Basis.IDENTITY, Vector3(-1.0, 0.0, 0.0)), "asy_relief_chariot_1m")
			ArtKit._add(panel, "asy_relief_wake", Transform3D.IDENTITY)
			ArtKit._add(panel, "asy_relief_1m", Transform3D(Basis.IDENTITY, Vector3(1.0, 0.0, 0.0)), "asy_relief_chariot_1m")
	return root


## A freestanding carved slab (or a genius's stele) filling a box of
## [param size]: an alabaster core, relief slabs on both faces (the kit's 3 m
## slabs, stretched to the box when it is taller), a thin cap.
static func _stele(size: Vector3, room: StringName, front: String, back: String, index: int) -> Node3D:
	var root := _holder("Visual")
	var height := maxf(size.y, 3.0)
	var k := height / 3.0
	_box(root, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), Vector3(size.x, height, size.z)), room, &"reveal")
	for side: float in [-1.0, 1.0]:
		# the face's frame: its run starts at the box's left end seen from
		# that face (+X along the face, -Z out of it)
		var face := _holder("Face")
		var basis := Basis(Vector3.UP, 0.0 if side < 0.0 else PI)
		face.transform = Transform3D(basis.scaled(Vector3(1.0, k, 1.0)), Vector3(side * size.x * 0.5, 0.0, side * size.z * 0.5))
		root.add_child(face)
		var theme := front if side < 0.0 else back
		if index % 2 == 1 and theme == "":
			theme = "asy_relief_genie_l_"
		ArtKit.run(face, "asy_relief_", 0.0, size.x, 0.0, theme)
	_box(root, AABB(Vector3(-size.x * 0.5 - 0.1, height, -size.z * 0.5 - 0.1), Vector3(size.x + 0.2, 0.08, size.z + 0.2)), room, &"reveal")
	return root


## A base of the courtyard's genii: an alabaster block filling its box with
## a painted frieze round its top.
static func _banded_block(size: Vector3, room: StringName) -> Node3D:
	var root := _holder("Visual")
	var cap := 0.06
	_box(root, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), Vector3(size.x, size.y - cap, size.z)), room, &"reveal")
	_box(root, AABB(Vector3(-size.x * 0.5 - 0.05, size.y - cap, -size.z * 0.5 - 0.05), Vector3(size.x + 0.1, cap, size.z + 0.1)), room, &"reveal")
	var band_y := size.y - cap - 0.62
	var h := Vector3(size.x * 0.5, band_y, size.z * 0.5)
	var corners := [Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var out := Vector3((a.x + b.x) * 0.5, 0.0, (a.z + b.z) * 0.5).normalized()
		var face := _holder("Band")
		face.transform = ArtKit.face_transform(a, b, out)
		root.add_child(face)
		ArtKit.run(face, "asy_frieze_", 0.0, a.distance_to(b), 0.0)
	return root


## A plinth of alabaster with a band of rosettes filling [param size].
static func _plinth(size: Vector3) -> Node3D:
	return _fit("asy_plinth", size / Vector3(1.1, 1.0, 1.1))


## A cedar column filling a box of [param size]: a gypsum base, a tapering
## shaft of cedar with bronze bands, four stepped corbels as its capital on
## the tall ones.
static func _cedar_column(size: Vector3, room: StringName) -> Node3D:
	var root := _holder("Visual")
	var base := 0.3
	_box(root, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), Vector3(size.x, base, size.z)), room, &"reveal")
	var r := minf(size.x, size.z) * 0.46
	var top_r := r * 0.86
	var shaft_top := size.y - (0.62 if size.y >= CAPITAL_FROM else 0.1)
	_rod(root, Vector3(0.0, base, 0.0), Vector3(0.0, shaft_top, 0.0), r, cedar(), top_r)
	for y: float in [base + 0.08, shaft_top - 0.2]:
		var band := CylinderMesh.new()
		band.top_radius = r * 1.03
		band.bottom_radius = r * 1.03
		band.height = 0.14
		band.radial_segments = 14
		var view := MeshInstance3D.new()
		view.mesh = band
		view.material_override = bronze()
		view.position = Vector3(0.0, y, 0.0)
		root.add_child(view)
	if size.y >= CAPITAL_FROM:
		for k in 4:
			var basis := Basis(Vector3.UP, PI * 0.5 * k)
			var out := basis * Vector3.FORWARD
			ArtKit._add(root, "asy_corbel", Transform3D(basis, out * (top_r - 0.02) + Vector3(0.0, size.y, 0.0)))
	return root


## The Black Obelisk of Shalmaneser III filling its box: a basalt monolith
## with registers of carving on every face (the kit's inscription slabs,
## darkened) and a stepped top.
static func _obelisk(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var steps := 0.6
	var body := size.y - steps
	_solid(root, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), Vector3(size.x, body, size.z)), basalt())
	var h := Vector3(size.x * 0.5, 0.0, size.z * 0.5)
	var corners := [Vector3(-h.x, 0.0, -h.z), Vector3(h.x, 0.0, -h.z), Vector3(h.x, 0.0, h.z), Vector3(-h.x, 0.0, h.z)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var out := Vector3((a.x + b.x) * 0.5, 0.0, (a.z + b.z) * 0.5).normalized()
		var face := _holder("Register")
		face.transform = ArtKit.face_transform(a, b, out)
		root.add_child(face)
		var w := a.distance_to(b)
		var slab := ArtKit._add(face, "asy_relief_1m", Transform3D(Basis.from_scale(Vector3(w / 1.0, body / 3.0, 1.0)), Vector3(w * 0.5, 0.0, 0.0)), "asy_relief_text_1m")
		_tint(slab, OBELISK_TINT)
	for k in 3:
		var shrink := 1.0 - 0.14 * (k + 1)
		_solid(root, AABB(Vector3(-size.x * 0.5 * shrink, body + k * steps / 3.0, -size.z * 0.5 * shrink), Vector3(size.x * shrink, steps / 3.0, size.z * shrink)), basalt())
	return root


## [param node]'s meshes in darkened copies of their materials (shared per
## material and tint).
static func _tint(node: Node, tint: Color) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		for i in view.mesh.get_surface_count():
			var source := view.get_active_material(i) as BaseMaterial3D
			if source == null:
				continue
			var key := "%s:%s" % [source.get_instance_id(), tint.to_html()]
			if not _tinted.has(key):
				var copy := source.duplicate() as BaseMaterial3D
				copy.albedo_color = tint
				_tinted[key] = copy
			view.set_surface_override_material(i, _tinted[key])


## The conservators' tube scaffold filling its box (long along z): four
## standards, ledgers and transoms every metre, two plank decks, braces.
static func _scaffold(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var hx := size.x * 0.5 - 0.05
	var hz := size.z * 0.5 - 0.1
	var steel := iron()
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_rod(root, Vector3(sx * hx, 0.0, sz * hz), Vector3(sx * hx, size.y, sz * hz), 0.024, steel)
	var levels: Array[float] = []
	var y := 1.0
	while y < size.y - 0.1:
		levels.append(y)
		y += 1.0
	for level_y in levels:
		for sx: float in [-1.0, 1.0]:
			_rod(root, Vector3(sx * hx, level_y, -hz), Vector3(sx * hx, level_y, hz), 0.02, steel)
		for sz: float in [-1.0, 1.0]:
			_rod(root, Vector3(-hx, level_y, sz * hz), Vector3(hx, level_y, sz * hz), 0.02, steel)
	for sx: float in [-1.0, 1.0]:
		_rod(root, Vector3(sx * hx, 0.15, -hz), Vector3(sx * hx, minf(size.y - 0.2, 3.0), hz), 0.016, steel)
	# plank decks on the ledgers (the top one is the working level)
	var decks := [levels[0], levels[-1]] if levels.size() > 1 else levels
	for deck_y in decks:
		_solid(root, AABB(Vector3(-hx + 0.03, deck_y + 0.02, -hz), Vector3(2.0 * hx - 0.06, 0.04, 2.0 * hz)), cedar())
	return root


## The king's hunting chariot filling its box (its pole forward, -Z): a
## cedar cab with a bronze rim on an axle between two spoked bronze wheels,
## the pole and the yoke.
static func _chariot(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var wheel_r := 0.5
	var axle_y := wheel_r
	var axle_z := 0.8
	var cab_w := minf(1.0, size.x - 0.7)
	_solid(root, AABB(Vector3(-cab_w * 0.5, axle_y - 0.05, 0.0), Vector3(cab_w, 0.95, 1.1)), cedar())
	_solid(root, AABB(Vector3(-cab_w * 0.5 - 0.02, axle_y + 0.85, -0.02), Vector3(cab_w + 0.04, 0.08, 1.14)), bronze())
	_rod(root, Vector3(-size.x * 0.5 + 0.05, axle_y, axle_z), Vector3(size.x * 0.5 - 0.05, axle_y, axle_z), 0.05, iron())
	for sx: float in [-1.0, 1.0]:
		var x := sx * (size.x * 0.5 - 0.11)
		var rim := TorusMesh.new()
		rim.inner_radius = wheel_r - 0.06
		rim.outer_radius = wheel_r
		rim.rings = 36
		rim.ring_segments = 8
		var view := MeshInstance3D.new()
		view.mesh = rim
		view.material_override = bronze()
		view.transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(x, axle_y, axle_z))
		root.add_child(view)
		for k in 8:
			var a := TAU * k / 8.0
			var tip := Vector3(x, axle_y + cos(a) * (wheel_r - 0.05), axle_z + sin(a) * (wheel_r - 0.05))
			_rod(root, Vector3(x, axle_y, axle_z), tip, 0.018, cedar())
		var hub := CylinderMesh.new()
		hub.top_radius = 0.09
		hub.bottom_radius = 0.09
		hub.height = 0.16
		var hub_view := MeshInstance3D.new()
		hub_view.mesh = hub
		hub_view.material_override = bronze()
		hub_view.transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(x, axle_y, axle_z))
		root.add_child(hub_view)
	var pole_end := Vector3(0.0, 0.9, -size.z * 0.5 + 0.1)
	_rod(root, Vector3(0.0, axle_y + 0.02, 0.2), pole_end, 0.04, cedar())
	_rod(root, pole_end + Vector3(-0.6, 0.0, 0.0), pole_end + Vector3(0.6, 0.0, 0.0), 0.035, cedar())
	return root


## A lion cage filling its box: an iron frame with bars every 0.3 m on its
## sides and across its top, a plank floor.
static func _cage(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var h := Vector3(size.x * 0.5 - 0.04, size.y - 0.04, size.z * 0.5 - 0.04)
	var steel := iron()
	var corners := [Vector3(-h.x, 0.0, -h.z), Vector3(h.x, 0.0, -h.z), Vector3(h.x, 0.0, h.z), Vector3(-h.x, 0.0, h.z)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		_rod(root, a, a + Vector3.UP * h.y, 0.03, steel)
		_rod(root, a + Vector3.UP * 0.06, b + Vector3.UP * 0.06, 0.03, steel)
		_rod(root, a + Vector3.UP * h.y, b + Vector3.UP * h.y, 0.03, steel)
		var n := maxi(1, int(round(a.distance_to(b) / 0.3)))
		for k in range(1, n):
			var p := a.lerp(b, float(k) / n)
			_rod(root, p + Vector3.UP * 0.06, p + Vector3.UP * h.y, 0.018, steel)
	for k in range(1, 4):
		var x := -h.x + 2.0 * h.x * k / 4.0
		_rod(root, Vector3(x, h.y, -h.z), Vector3(x, h.y, h.z), 0.018, steel)
	_solid(root, AABB(Vector3(-h.x, 0.0, -h.z), Vector3(2.0 * h.x, 0.05, 2.0 * h.z)), cedar())
	return root


## Stepped merlons of the kit along [param frame]'s x from [param x0] to
## [param x1] (2 m modules stretched alike), their middles on z = 0.
static func _merlons(parent: Node3D, frame: Transform3D, x0: float, x1: float) -> void:
	var length := x1 - x0
	var n := maxi(1, int(round(length / 2.0)))
	var k := length / (2.0 * n)
	for i in n:
		var at := frame * Vector3(x0 + (i + 0.5) * 2.0 * k, 0.0, 0.0)
		ArtKit._add(parent, "asy_parapet_2m", Transform3D(frame.basis * Basis.from_scale(Vector3(k, 1.0, 1.0)), at))


## Shelves of clay tablets filling a greybox shelf (its back on the wall).
static func _tablet_shelves(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var n := maxi(1, int(round(size.x / 2.0)))
	var w := size.x / n
	for i in n:
		var x := -size.x * 0.5 + (i + 0.5) * w
		ArtKit._add(root, "asy_tablet_shelf", Transform3D(Basis.from_scale(Vector3(w / 2.0, size.y / 2.2, size.z / 0.5)), Vector3(x, 0.0, 0.0)))
	return root


## Crates by room: the tablet store's crates of tablets in straw (stacked
## two high where the box is tall), the museum's plain crates elsewhere.
static func _crate(spec: PieceSpec, _index: int) -> Variant:
	var size := spec.size
	if spec.room != &"assyria_tablets" and spec.room != &"assyria_lion_cage":
		return null
	var root := _holder("Visual")
	var layers := 2 if size.y > 0.7 else 1
	var h := size.y / layers
	for i in layers:
		ArtKit._add(root, "asy_tablet_crate", Transform3D(Basis(Vector3.UP, 0.08 * i).scaled(Vector3(size.x / 0.9, h / 0.48, size.z / 0.6)), Vector3(0.0, i * h, 0.0)))
	return root


## The night reader's desk with Sennacherib's prism on its end (the note
## lies on the other).
static func _reader_desk(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	ArtKit._add(root, "desk", Transform3D(Basis.from_scale(size / Vector3(1.6, 0.78, 0.8)), Vector3.ZERO))
	ArtKit._add(root, "asy_prism", Transform3D(Basis(Vector3.UP, 0.35), Vector3(-size.x * 0.5 + 0.3, size.y, 0.0)))
	return root


# --- fittings, gates, portals -------------------------------------------------------

## The wing's light fittings (origin = the light): a torch on a lion-mask
## plate (its mount runs back to the wall) for every sconce, a bronze tripod
## of fire under a brazier's flame; null = the lobby's.
static func fixture(kit: StringName, room: StringName) -> Variant:
	match kit:
		&"sconce":
			if room == &"assyria_freight_stairs":
				return null
			var torch := _holder("Visual")
			ArtKit._add(torch, "asy_torch", Transform3D.IDENTITY)
			return torch
		&"brazier":
			var tripod := _holder("Visual")
			ArtKit._add(tripod, "asy_brazier", Transform3D(Basis.IDENTITY, Vector3(0.0, -1.38, 0.0)))
			return tripod
	return null


## No gates in disguise.
static func gate_leaf(_opening_id: StringName, _size: Vector3, _side: float) -> Variant:
	return null


## The wing's own portals (Floor1Art.PORTALS' form): no frame round the
## cracked wall of the tablet store.
static func portals() -> Dictionary:
	return {
		&"assyria_library_tablets": {&"assyria_library": ["", Vector2.ZERO], &"assyria_tablets": ["", Vector2.ZERO]},
	}


## Gates of the wing that wear leaves of their own: none.
static func disguised_gates() -> Array[StringName]:
	return []


# --- hero pieces ------------------------------------------------------------------

## The wing's hero pieces for the dressed rooms ([param rooms] empty: all)
## under [param parent] (world space).
static func dress(layout: LevelLayout, parent: Node3D, rooms: Dictionary = {}) -> void:
	if layout.room(&"assyria_gate") == null:
		return
	if Floor1Art.wants(rooms, &"assyria_gate"):
		_gate(Floor1Art.group(parent, "KhorsabadGate", &"assyria_gate"))
	if Floor1Art.wants(rooms, &"assyria_lions"):
		var pit := Floor1Art.group(parent, "LionPit", &"assyria_lions")
		for slab: Array in LION_SLABS:
			ArtKit._add(pit, "asy_relief_wake_lion", Transform3D(Basis(Vector3.UP, float(slab[1])), slab[0]))
	if Floor1Art.wants(rooms, &"assyria_courtyard"):
		_sky_merlons(layout, Floor1Art.group(parent, "CourtyardMerlons", &"assyria_courtyard"))
	_thresholds(layout, parent, rooms)


## The Khorsabad Gate on the hall's face of the wall to Egypt: its lamassu
## stand in the greybox's lamassu boxes; its own stone doors stay hidden
## (Egypt's seal doors close the passage).
static func _gate(root: Node3D) -> void:
	var gate := ArtKit._add(root, "khorsabad_gate", Transform3D(Basis.IDENTITY, GATE_AT))
	var parts := ArtLibrary.parts(gate)
	for id: String in ["door_l", "door_r"]:
		var door := parts.get(id) as Node3D
		if door != null:
			door.visible = false
	gate.set_meta(&"khorsabad_gate", true)


## Stepped merlons round the courtyard's sky well, on the rim the shell
## raises round it (ceiling + well + roof), their faces to the sky's middle.
static func _sky_merlons(layout: LevelLayout, root: Node3D) -> void:
	var court := layout.room(&"assyria_courtyard")
	if court == null:
		return
	var crown := court.ceiling_y + LevelLayout.SKYLIGHT_WELL + ShellCarver.ROOF_T
	for well in court.skylights:
		var corners := [Vector3(well.position.x, crown, well.position.y), Vector3(well.end.x, crown, well.position.y),
			Vector3(well.end.x, crown, well.end.y), Vector3(well.position.x, crown, well.end.y)]
		var middle := Vector3(well.get_center().x, crown, well.get_center().y)
		for i in 4:
			var a: Vector3 = corners[i]
			var b: Vector3 = corners[(i + 1) % 4]
			var inward := (middle - (a + b) * 0.5)
			inward = Vector3(inward.x, 0.0, inward.z).normalized()
			var frame := ArtKit.face_transform(a, b, inward).translated_local(Vector3(0.0, 0.0, MERLON_SET_BACK))
			_merlons(root, frame, 0.0, a.distance_to(b))


## Carved thresholds ("carpets" of rosettes) in the doorways between the
## wing's own rooms (not in the gates' openings).
static func _thresholds(layout: LevelLayout, parent: Node3D, rooms: Dictionary) -> void:
	var root: Node3D = null
	for passage in layout.openings:
		if not String(passage.room_a).begins_with("assyria_") or not String(passage.room_b).begins_with("assyria_"):
			continue
		if layout.gate_of_opening(passage.id) != null:
			continue
		if not Floor1Art.wants(rooms, passage.room_a) and not Floor1Art.wants(rooms, passage.room_b):
			continue
		if root == null:
			root = Floor1Art.group(parent, "Thresholds", passage.room_a)
		var frame := Floor1Art.passage_frame(layout, passage)
		var k := Vector3(passage.width() / 4.0, 1.0, passage.depth() / 1.2)
		var threshold := ArtKit._add(root, "asy_threshold_4m", frame * Transform3D(Basis.from_scale(k), Vector3(0.0, THRESHOLD_LIFT, 0.0)))
		threshold.set_meta(&"kit_room", passage.room_a)


# --- light recipe extras -------------------------------------------------------------

## The torches' red and the fires' orange.
const TORCH := Color(1.0, 0.45, 0.22)
const FIRE := Color(1.0, 0.5, 0.2)
## Where the fire tripods stand (their flames): by the Black Obelisk against
## the Balawat room's south wall, by the Lamassu's plinth against the
## courtyard's north wall. (Assyria.TRIPODS puts a solid stand-in under each:
## the greybox's, so nobody walks through the legs of a fire.)
const BRAZIERS := {
	&"assyria_balawat": [Vector3(-53.6, 1.38, -78.55), Vector3(-48.4, 1.38, -78.55)],
	&"assyria_courtyard": [Vector3(-84.0, 1.38, -79.6), Vector3(-73.5, 1.38, -79.6)],
}
## Fill lamps (wide, soft, no haze, no shadow: the bounce off alabaster the
## renderer has no time for): room -> [position, range, energy].
const FILLS := {
	&"assyria_gate": [[Vector3(-55.0, 9.6, -48.0), 15.0, 0.7]],
	&"assyria_nimrud": [[Vector3(-88.0, 7.6, -46.0), 13.0, 0.7], [Vector3(-72.0, 7.6, -46.0), 13.0, 0.7]],
	&"assyria_balawat": [[Vector3(-55.0, 7.6, -68.0), 13.0, 0.6]],
	&"assyria_lions": [[Vector3(-87.5, 8.6, -20.5), 17.0, 0.7]],
	&"assyria_library": [[Vector3(-67.0, 5.6, -30.0), 10.0, 0.5]],
}


## The lamps the Assyrian wing's art asks for (Floor1LightRecipe extras),
## by the rooms of [param layout]: the two torches on the Khorsabad Gate's
## towers, the fire tripods, the fills, a cold sky down the courtyard's well
## (the moon's group: no fuse). None lights the floor much (the exhibits'
## light model reads the layout's lamps).
static func extra_lights(layout: LevelLayout) -> Array:
	var out: Array = []
	if layout.room(&"assyria_gate") != null:
		for x: float in [-3.2, 3.2]:
			out.append({"room": &"assyria_gate", "position": GATE_AT + Vector3(x, 3.8, -4.95), "color": TORCH, "energy": 1.1,
				"range": 7.0, "rule": &"torch", "fixture": &"sconce", "fixture_yaw": 0.0})
	for room: StringName in BRAZIERS:
		if layout.room(room) == null:
			continue
		for at: Vector3 in BRAZIERS[room]:
			out.append({"room": room, "position": at, "color": FIRE, "energy": 1.2, "range": 8.0, "rule": &"brazier", "fixture": &"brazier"})
	for room: StringName in FILLS:
		if layout.room(room) == null:
			continue
		for fill: Array in FILLS[room]:
			out.append({"room": room, "position": fill[0], "direction": Vector3.DOWN, "color": Floor1LightRecipe.FILL,
				"energy": float(fill[2]), "range": float(fill[1]), "angle": 75.0, "rule": &"fill"})
	var court := layout.room(&"assyria_courtyard")
	if court != null:
		for well in court.skylights:
			var c := well.get_center()
			var reach := court.ceiling_y - court.floor_y + LevelLayout.SKYLIGHT_WELL + 1.0
			out.append({"room": court.id, "group": LightSpec.MOON, "position": Vector3(c.x, court.ceiling_y + LevelLayout.SKYLIGHT_WELL - 0.2, c.y),
				"direction": Vector3.DOWN, "color": Floor1LightRecipe.MOON_COLOR, "energy": 0.35 * sqrt(well.get_area() / 16.0),
				"range": reach, "angle": 60.0, "rule": &"cold_fill"})
	return out
