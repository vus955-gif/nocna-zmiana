class_name Floor1ArtRoof
extends RefCounted
## Floor I's roof dressed, stage P5 (plan docs/superpowers/plans/
## 2026-10-10-p5-oprawa-ameryki-dach.md section 4): night outside - the moon
## on the lead flats and on the Reading Room's leaded dome, the city's glow,
## the court's warm light up through the glass, steel catwalks and railings,
## a chimney and a water tank on the plant deck. Pure factories of Node3D
## trees, no collision (the greybox keeps it); Floor1Art asks this module
## for every room whose id starts with "roof_":
## - [method piece_look]: the drum carried up through the roof (Portland
##   ashlar with a string course), its core and the greybox's stepped dome
##   left to the hero dome, the lantern on its top, steel railings, the glass
##   fields' frames and glazing bars, the plant deck's tank, air handlers and
##   chimneys, the pigeon loft's cages, the chessman's ledge;
## - [method dress]: the Reading Room's leaded outer dome on its drum, the
##   catwalks' steel plates;
## - [method extra_lights]: the court's warm glow up through each glass
##   field, the city's glow over the gutters and the deck.

## Every model this module places (the art tests check each is registered,
## on disk and placed).
const MODELS: Array[String] = ["rr_dome_outer", "hall_string_4m", "hall_string_1m"]
## The roof's level (Floor1Plan.ROOF_Y) and the dome: the court kit's outer
## dome (modelled in the court's frame at 21.64-23.69 m) lifted onto the
## drum's top (the greybox drum: 2.5 m over the roof), its lantern on it.
const ROOF_Y := 22.5
const DOME_LIFT := 3.357
const DOME_TOP := 27.05
## The lantern on the dome's top (the greybox lantern stands 0.75 m over it):
## iron posts round a glazed drum, a lead cap and a spire under the red
## warning lamp.
const LANTERN_DROP := 0.75
const LANTERN_POSTS := 16
const LANTERN_R := 1.55
const LANTERN_H := 1.6
const SPIRE_TOP := 2.45
## The railings: painted steel tubes - posts at most 2 m apart (and at both
## ends), a hand rail at 1.05 m, a mid rail, a toe board.
const RAIL_TOP := 1.05
const RAIL_MID := 0.55
const POST_STEP := 2.0
const STEEL := Color(0.18, 0.19, 0.21)
## The glass fields' frames: steel angles round each field, glazing bars
## every 2 m both ways (on the glass, casting no shadow: the truss under the
## glass draws the court's lattice).
const BAR_STEP := 2.0
## The catwalks' steel plates over the lead (flat heroes a hair over the
## roof): the four radial walks, the ring round the dome (an octagon between
## the drum and the ring's railings), the deck's bridge down to the gutter.
const PLATE := 0.025
const PLATE_LIFT := 0.005
const SPOKE := 1.5
const RING_IN := 12.3
const RING_OUT := 15.4
const GUTTER := 26.5
## The north walk's plate (x, z; the other three turned a quarter at a time).
const SPOKE_PLATE := Rect2(-SPOKE, -GUTTER, SPOKE * 2.0, GUTTER - RING_OUT)
const BRIDGE := Rect2(23.0, 30.5, 7.0, 5.5)
const PLATE_TINT := Color(0.42, 0.44, 0.48)

static var _steel: StandardMaterial3D = null
static var _tiles: Dictionary = {}
static var _cage_mesh: StandardMaterial3D = null
## A railing's mesh by its size (railings of one size share it) and the unit
## tube and slab the rods and the toe boards are cut from.
static var _rail_meshes: Dictionary = {}
static var _glazing_meshes: Dictionary = {}
static var _unit_tube: Array = []
static var _unit_slab: Array = []


# --- pieces --------------------------------------------------------------------

## The look of [param spec] (a piece of a roof room) in its own frame, or
## null (the common rules).
static func piece_look(spec: PieceSpec, _index: int, layout: LevelLayout) -> Variant:
	var size := spec.size
	match spec.kit:
		&"dome_drum":
			return _drum(spec)
		&"dome_core", &"dome":
			return _holder("Visual")   # inside the drum / under the hero dome ([method dress])
		&"dome_lantern":
			return _lantern() if absf(spec.yaw) < 0.01 else _holder("Visual")
		&"railing":
			return _railing(size)
		&"roof_glass":
			return _glass(size)
		&"water_tank":
			return _water_tank(size)
		&"plant_unit":
			return _plant_unit(size)
		&"chimney":
			return _chimney(size)
		&"pigeon_cages":
			var cages := _holder("Visual")
			var turned := _cages(size)
			turned.name = "Cages"
			turned.rotation.y = _off_the_wall(spec, layout)
			cages.add_child(turned)
			return cages
		&"plinth":
			return _stone_block(size, spec.room)
	return null


static func _holder(label: String) -> Node3D:
	var n := Node3D.new()
	n.name = label
	return n


## A box of [param box] (in the parent's frame) in [param material].
static func _solid(parent: Node3D, box: AABB, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box.size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	view.position = box.get_center()
	parent.add_child(view)
	return view


## A cylinder of radius [param radius] (tapering to [param radius_b]) from
## [param a] to [param b].
static func _rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material, radius_b: float = -1.0, sides: int = 8) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if radius_b < 0.0 else radius_b
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = sides
	mesh.rings = 1
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	view.transform = Transform3D(Basis(side, up, side.cross(up)), (a + b) * 0.5)
	parent.add_child(view)
	return view


## Painted steel of the railings, the lantern's posts, the tank's legs.
static func steel() -> StandardMaterial3D:
	if _steel == null:
		_steel = StandardMaterial3D.new()
		_steel.resource_name = "roof_steel"
		_steel.albedo_color = STEEL
		_steel.metallic = 0.6
		_steel.roughness = 0.5
	return _steel


## A tile field mapped in the piece's own frame (shared).
static func _tile(id: String) -> Material:
	if not _tiles.has(id):
		_tiles[id] = ArtLibrary.arch_tile(id, true)
	return _tiles[id]


## The yaw (in the piece's frame) turning a wall piece's front (-Z) away from
## the nearer of its room's walls across it (its long side runs along X).
static func _off_the_wall(spec: PieceSpec, layout: LevelLayout) -> float:
	var room := layout.room(spec.room) if layout != null else null
	if room == null or room.parts.is_empty():
		return 0.0
	var part := room.parts[0]
	var back := (Basis(Vector3.UP, spec.yaw) * Vector3.BACK)
	var ahead := spec.position - back * 0.5
	var behind := spec.position + back * 0.5
	# the front faces the room when the wall is behind it (+Z): else turn it
	var gap_ahead := _to_edge(part, Vector2(ahead.x, ahead.z))
	var gap_behind := _to_edge(part, Vector2(behind.x, behind.z))
	return 0.0 if gap_behind < gap_ahead else PI


static func _to_edge(part: Rect2, p: Vector2) -> float:
	return minf(minf(p.x - part.position.x, part.end.x - p.x), minf(p.y - part.position.y, part.end.y - p.y))


## A block of the court's Portland stone with a cap a hair wider.
static func _stone_block(size: Vector3, room: StringName) -> Node3D:
	var root := _holder("Visual")
	var cap := 0.06
	_solid(root, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), Vector3(size.x, size.y - cap, size.z)), ArtKit.field(room, &"wall"))
	_solid(root, AABB(Vector3(-size.x * 0.5 - 0.04, size.y - cap, -size.z * 0.5 - 0.04), Vector3(size.x + 0.08, cap, size.z + 0.08)), ArtKit.field(room, &"wall"))
	return root


## A segment of the drum carried up through the roof (its front, -Z, faces
## out): Portland ashlar filling the box, the court's string course along
## its top on the outer face (under the dome's eaves).
static func _drum(spec: PieceSpec) -> Node3D:
	var root := _holder("Visual")
	var size := spec.size
	_solid(root, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size), ArtKit.field(spec.room, &"wall"))
	var face := _holder("StringCourse")
	face.position = Vector3(0.0, 0.0, -size.z * 0.5)
	root.add_child(face)
	ArtKit.run(face, "hall_string_", -size.x * 0.5, size.x * 0.5, size.y)
	return root


## The lantern on the dome's top in the greybox lantern's frame (it stands
## LANTERN_DROP over the dome): a ring of iron posts round a glazed drum, a
## lead cap and a spire.
static func _lantern() -> Node3D:
	var root := _holder("Visual")
	var base := -LANTERN_DROP
	for k in LANTERN_POSTS:
		var a := TAU * k / LANTERN_POSTS
		var at := Vector3(cos(a), 0.0, sin(a)) * LANTERN_R
		_rod(root, at + Vector3.UP * base, at + Vector3.UP * (base + LANTERN_H), 0.04, steel())
	var drum := CylinderMesh.new()
	drum.top_radius = LANTERN_R - 0.05
	drum.bottom_radius = LANTERN_R - 0.05
	drum.height = LANTERN_H - 0.05
	drum.radial_segments = LANTERN_POSTS
	drum.rings = 1
	var glass := MeshInstance3D.new()
	glass.name = "LanternGlass"
	glass.mesh = drum
	glass.material_override = LevelKit.glass()
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.position = Vector3(0.0, base + LANTERN_H * 0.5, 0.0)
	root.add_child(glass)
	var lead := _tile("cast_iron")
	_solid(root, AABB(Vector3(-LANTERN_R - 0.08, base + LANTERN_H - 0.05, -LANTERN_R - 0.08), Vector3((LANTERN_R + 0.08) * 2.0, 0.08, (LANTERN_R + 0.08) * 2.0)), lead)
	_rod(root, Vector3(0.0, base + LANTERN_H, 0.0), Vector3(0.0, base + LANTERN_H + 0.8, 0.0), 1.8, lead, 0.12, LANTERN_POSTS)
	_rod(root, Vector3(0.0, base + LANTERN_H + 0.8, 0.0), Vector3(0.0, base + SPIRE_TOP, 0.0), 0.06, steel(), 0.015)
	return root


## A steel railing filling its box (along X): posts at most POST_STEP apart,
## the hand rail, the mid rail and the toe board, all of it one mesh (railings
## of one size share it: 350 separate rods and meshes cost the roof as many
## nodes and draws).
static func _railing(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var view := MeshInstance3D.new()
	view.name = "Rails"
	view.mesh = _railing_mesh(size)
	view.material_override = steel()
	root.add_child(view)
	return root


## The rods of a railing of [param size] in its frame, [a, b, radius]: the
## posts (one at each end, at most POST_STEP apart), the hand rail and the
## mid rail (the toe board is a slab, [method _railing_mesh]).
static func railing_rods(size: Vector3) -> Array:
	var rods: Array = []
	var half := size.x * 0.5
	var n := maxi(1, int(ceil(size.x / POST_STEP)))
	for i in n + 1:
		var x := -half + 0.03 + (size.x - 0.06) * i / n
		rods.append([Vector3(x, 0.0, 0.0), Vector3(x, RAIL_TOP, 0.0), 0.025])
	rods.append([Vector3(-half, RAIL_TOP, 0.0), Vector3(half, RAIL_TOP, 0.0), 0.028])
	rods.append([Vector3(-half + 0.03, RAIL_MID, 0.0), Vector3(half - 0.03, RAIL_MID, 0.0), 0.02])
	return rods


## The one mesh of a railing of [param size].
static func _railing_mesh(size: Vector3) -> ArrayMesh:
	var key := Vector3i((size * 1000.0).round())
	if not _rail_meshes.has(key):
		var half := size.x * 0.5
		var mesh := _merged(railing_rods(size), [AABB(Vector3(-half + 0.03, 0.0, -0.01), Vector3(size.x - 0.06, 0.08, 0.02))])
		mesh.resource_name = "roof_railing"
		_rail_meshes[key] = mesh
	return _rail_meshes[key]


## One mesh of [param rods] ([a, b, radius]: eight-sided steel tubes) and
## [param slabs] (AABBs), cut from one unit tube and one unit slab.
static func _merged(rods: Array, slabs: Array) -> ArrayMesh:
	if _unit_tube.is_empty():
		var tube := CylinderMesh.new()
		tube.top_radius = 1.0
		tube.bottom_radius = 1.0
		tube.height = 1.0
		tube.radial_segments = 8
		tube.rings = 1
		_unit_tube = tube.get_mesh_arrays()
		var slab := BoxMesh.new()
		slab.size = Vector3.ONE
		_unit_slab = slab.get_mesh_arrays()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for rod: Array in rods:
		var a: Vector3 = rod[0]
		var b: Vector3 = rod[1]
		var length := a.distance_to(b)
		var up := (b - a) / length
		var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var turn := Basis(side, up, side.cross(up))
		var radius := float(rod[2])
		_append(vertices, normals, indices, _unit_tube, Transform3D(turn * Basis.from_scale(Vector3(radius, length, radius)), (a + b) * 0.5), turn)
	for box: AABB in slabs:
		_append(vertices, normals, indices, _unit_slab, Transform3D(Basis.from_scale(box.size), box.get_center()), Basis.IDENTITY)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Adds the unit mesh [param unit] (get_mesh_arrays) placed by [param place]
## to the arrays; its normals are only turned by [param turn] (the scales are
## about the axes, they keep a rod's or a slab's normals' directions).
static func _append(vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array, unit: Array, place: Transform3D, turn: Basis) -> void:
	var base := vertices.size()
	vertices.append_array(place * (unit[Mesh.ARRAY_VERTEX] as PackedVector3Array))
	normals.append_array(Transform3D(turn, Vector3.ZERO) * (unit[Mesh.ARRAY_NORMAL] as PackedVector3Array))
	for i: int in unit[Mesh.ARRAY_INDEX] as PackedInt32Array:
		indices.append(base + i)


## A glass field on the court's roof: clear glass (no shadow: the moon goes
## through it), steel angles round it and glazing bars every BAR_STEP both
## ways, on the glass and casting no shadow - the angles and the bars one
## steel mesh (fields of one size share it).
static func _glass(size: Vector3) -> Node3D:
	var root := LevelArt.clear_glass_look(size)
	var frame := _holder("Glazing")
	root.add_child(frame)
	var view := MeshInstance3D.new()
	view.name = "Bars"
	view.mesh = _glazing_mesh(size)
	view.material_override = steel()
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	frame.add_child(view)
	return root


## The steel of a glass field of [param size] in its frame: the angles round
## it and the glazing bars across, as slabs.
static func glazing_slabs(size: Vector3) -> Array[AABB]:
	var slabs: Array[AABB] = []
	var top := size.y
	var h := Vector2(size.x * 0.5, size.z * 0.5)
	for side: float in [-1.0, 1.0]:
		slabs.append(AABB(Vector3(-h.x, top, side * h.y - 0.03), Vector3(size.x, 0.05, 0.06)))
		slabs.append(AABB(Vector3(side * h.x - 0.03, top, -h.y), Vector3(0.06, 0.05, size.z)))
	var nx := maxi(1, int(round(size.x / BAR_STEP)))
	for i in range(1, nx):
		var x := -h.x + size.x * i / nx
		slabs.append(AABB(Vector3(x - 0.015, top, -h.y), Vector3(0.03, 0.02, size.z)))
	var nz := maxi(1, int(round(size.z / BAR_STEP)))
	for j in range(1, nz):
		var z := -h.y + size.z * j / nz
		slabs.append(AABB(Vector3(-h.x, top, z - 0.015), Vector3(size.x, 0.02, 0.03)))
	return slabs


static func _glazing_mesh(size: Vector3) -> ArrayMesh:
	var key := Vector3i((size * 1000.0).round())
	if not _glazing_meshes.has(key):
		var mesh := _merged([], glazing_slabs(size))
		mesh.resource_name = "roof_glazing"
		_glazing_meshes[key] = mesh
	return _glazing_meshes[key]


## The plant deck's water tank filling its box: a riveted iron drum with two
## hoops on four steel legs, a conical lid, a ladder up its front (-Z).
static func _water_tank(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var legs := 0.8
	var lid := 0.2
	var r := minf(size.x, size.z) * 0.5 - 0.05
	var body_h := size.y - legs - lid
	var iron := _tile("cast_iron")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_rod(root, Vector3(sx * r * 0.7, 0.0, sz * r * 0.7), Vector3(sx * r * 0.62, legs, sz * r * 0.62), 0.05, steel())
	_solid(root, AABB(Vector3(-r * 0.75, legs - 0.12, -r * 0.75), Vector3(r * 1.5, 0.12, r * 1.5)), steel())
	_rod(root, Vector3(0.0, legs, 0.0), Vector3(0.0, legs + body_h, 0.0), r, iron, -1.0, 24)
	for y: float in [legs + body_h * 0.3, legs + body_h * 0.75]:
		var hoop := TorusMesh.new()
		hoop.inner_radius = r - 0.01
		hoop.outer_radius = r + 0.03
		hoop.rings = 32
		hoop.ring_segments = 6
		var band := MeshInstance3D.new()
		band.mesh = hoop
		band.material_override = steel()
		band.position = Vector3(0.0, y, 0.0)
		root.add_child(band)
	_rod(root, Vector3(0.0, legs + body_h, 0.0), Vector3(0.0, size.y, 0.0), r + 0.03, iron, 0.15, 24)
	# the ladder up the front, from the deck to the lid's rim
	var front := -r - 0.08
	for x: float in [-0.22, 0.22]:
		_rod(root, Vector3(x, 0.0, front), Vector3(x, legs + body_h, front), 0.022, steel())
	for k in 8:
		var y2 := 0.3 + (legs + body_h - 0.4) * k / 7.0
		_rod(root, Vector3(-0.22, y2, front), Vector3(0.22, y2, front), 0.016, steel())
	return root


## An air handler filling its box (along X): a steel cabinet with louvres on
## its long faces and a fan in a ring on its top.
static func _plant_unit(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var body := size.y - 0.1
	_solid(root, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), Vector3(size.x, body, size.z)), _tile("court_steel"))
	for side: float in [-1.0, 1.0]:
		for k in 7:
			var y := 0.25 + (body - 0.5) * k / 6.0
			_solid(root, AABB(Vector3(-size.x * 0.4, y, side * size.z * 0.5 - 0.01), Vector3(size.x * 0.8, 0.03, 0.02)), steel())
	var fan := CylinderMesh.new()
	fan.top_radius = 0.4
	fan.bottom_radius = 0.4
	fan.height = 0.1
	fan.radial_segments = 20
	var hub := MeshInstance3D.new()
	hub.mesh = fan
	hub.material_override = steel()
	hub.position = Vector3(size.x * 0.22, body + 0.05, 0.0)
	root.add_child(hub)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.4
	ring.outer_radius = 0.46
	ring.rings = 24
	ring.ring_segments = 6
	var guard := MeshInstance3D.new()
	guard.mesh = ring
	guard.material_override = steel()
	guard.position = Vector3(size.x * 0.22, body + 0.06, 0.0)
	root.add_child(guard)
	return root


## A chimney stack filling its box: a brick shaft, a stone cap a hair wider,
## a steel cowl on top.
static func _chimney(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var cowl := 0.35
	var cap := 0.1
	var shaft := size.y - cowl - cap
	_solid(root, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), Vector3(size.x, shaft, size.z)), _tile("brick"))
	_solid(root, AABB(Vector3(-size.x * 0.5 - 0.05, shaft, -size.z * 0.5 - 0.05), Vector3(size.x + 0.1, cap, size.z + 0.1)), _tile("portland_ashlar"))
	_rod(root, Vector3(0.0, shaft + cap, 0.0), Vector3(0.0, shaft + cap + cowl * 0.6, 0.0), 0.18, steel(), 0.18, 12)
	_rod(root, Vector3(0.0, shaft + cap + cowl * 0.6, 0.0), Vector3(0.0, size.y, 0.0), 0.35, steel(), 0.12, 12)
	return root


## Wire mesh: dark, see-through, both sides.
static func cage_mesh() -> StandardMaterial3D:
	if _cage_mesh == null:
		_cage_mesh = StandardMaterial3D.new()
		_cage_mesh.resource_name = "pigeon_mesh"
		_cage_mesh.albedo_color = Color(0.25, 0.25, 0.27, 0.45)
		_cage_mesh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cage_mesh.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cage_mesh.roughness = 0.7
		_cage_mesh.metallic = 0.4
	return _cage_mesh


## The pigeon fanciers' cages filling their box (along X, the wire on the
## front, -Z): a frame of battens, three shelves, perches.
static func _cages(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var wood := _tile("boards")
	var h := Vector3(size.x * 0.5, size.y, size.z * 0.5)
	_solid(root, AABB(Vector3(-h.x, 0.0, h.z - 0.03), Vector3(size.x, size.y, 0.03)), wood)
	for x: float in [-h.x, -h.x * 0.33, h.x * 0.33, h.x]:
		_solid(root, AABB(Vector3(x - 0.03, 0.0, -h.z), Vector3(0.06, size.y, size.z)), wood)
	for y: float in [0.0, size.y * 0.34, size.y * 0.67, size.y - 0.04]:
		_solid(root, AABB(Vector3(-h.x, y, -h.z), Vector3(size.x, 0.04, size.z)), wood)
	var wire := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size.x, size.y)
	wire.mesh = quad
	wire.material_override = cage_mesh()
	wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wire.position = Vector3(0.0, size.y * 0.5, -h.z + 0.01)
	root.add_child(wire)
	for k in 6:
		var x2 := -h.x + size.x * (k % 3 + 0.5) / 3.0
		var y2 := size.y * (0.12 + 0.34 * float(k / 3))
		_rod(root, Vector3(x2 - 0.4, y2, 0.0), Vector3(x2 + 0.4, y2, 0.0), 0.015, wood)
	return root


# --- fittings, gates, portals -------------------------------------------------------

## The roof's light fittings (origin = the light); null = the lobby's.
static func fixture(_kit: StringName, _room: StringName) -> Variant:
	return null


## No gates in disguise.
static func gate_leaf(_opening_id: StringName, _size: Vector3, _side: float) -> Variant:
	return null


## The roof's own portals (Floor1Art.PORTALS' form): the pigeon loft's
## hatch and the boarded shed's doors in bare openings.
static func portals() -> Dictionary:
	return {
		&"roof_plant_loft": {&"roof_plant": ["", Vector2.ZERO], &"roof_loft": ["", Vector2.ZERO]},
		&"roof_catwalks_shed": {&"roof_catwalks": ["", Vector2.ZERO], &"roof_shed": ["", Vector2.ZERO]},
	}


## Gates of the roof that wear leaves of their own: none.
static func disguised_gates() -> Array[StringName]:
	return []


# --- hero pieces ------------------------------------------------------------------

## The roof's hero pieces for the dressed rooms ([param rooms] empty: all)
## under [param parent] (world space).
static func dress(layout: LevelLayout, parent: Node3D, rooms: Dictionary = {}) -> void:
	if layout.room(&"roof_catwalks") == null:
		return
	if Floor1Art.wants(rooms, &"roof_catwalks"):
		var dome := Floor1Art.group(parent, "OuterDome", &"roof_catwalks")
		var outer := ArtKit._add(dome, "rr_dome_outer", Transform3D(Basis.IDENTITY, Vector3(0.0, DOME_LIFT, 0.0)))
		outer.set_meta(&"outer_dome", true)
		_walk_plates(Floor1Art.group(parent, "CatwalkPlates", &"roof_catwalks"))
	if Floor1Art.wants(rooms, &"roof_plant"):
		var deck := Floor1Art.group(parent, "DeckBridge", &"roof_plant")
		_plate(deck, BRIDGE)


## The steel plates of the radial catwalks and the ring round the dome.
static func _walk_plates(root: Node3D) -> void:
	for k in 4:
		var turn := Basis(Vector3.UP, PI * 0.5 * k)
		var holder := _holder("Spoke")
		holder.basis = turn
		root.add_child(holder)
		_plate(holder, SPOKE_PLATE)
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	ring.mesh = octagon_ring(RING_IN, RING_OUT, PLATE)
	ring.material_override = plate_steel()
	ring.position = Vector3(0.0, ROOF_Y + PLATE_LIFT, 0.0)
	root.add_child(ring)


## A plate over [param rect] (x, z of its parent's frame) on the roof.
static func _plate(parent: Node3D, rect: Rect2) -> MeshInstance3D:
	return _solid(parent, AABB(Vector3(rect.position.x, ROOF_Y + PLATE_LIFT, rect.position.y), Vector3(rect.size.x, PLATE, rect.size.y)), plate_steel())


## The catwalks' chequer plate: the court's steel field darkened (bare, it
## read white as snow under the full moon).
static func plate_steel() -> Material:
	if not _tiles.has("plate"):
		_tiles["plate"] = ArtLibrary.arch_tile("court_steel", true, PLATE_TINT)
	return _tiles["plate"]


## True when [param at] (a point of the floor plan, in room [param room])
## lies on one of the catwalks' steel plates: the four radial walks and the
## ring round the dome in the catwalks' room, the bridge in the plant deck's.
## The plates are decor over the lead slab with no collision of their own, so
## this is how the footsteps hear them (Surface.of_room_at).
static func on_plate(room: StringName, at: Vector3) -> bool:
	var flat := Vector2(at.x, at.z)
	if room == &"roof_plant":
		return BRIDGE.has_point(flat)
	if room != &"roof_catwalks":
		return false
	# the walks: the point turned back into the north walk's frame
	for k in 4:
		var turn := PI * 0.5 * k
		var local := Vector2(flat.x * cos(turn) - flat.y * sin(turn), flat.x * sin(turn) + flat.y * cos(turn))
		if SPOKE_PLATE.has_point(local):
			return true
	# the ring: an octagon, its faces' middles on bearings 0, 45, ...: the point's
	# distance from the middle measured to the nearest face line
	var apothem := 0.0
	for k in 8:
		var bearing := PI * 0.25 * k
		apothem = maxf(apothem, flat.dot(Vector2(sin(bearing), -cos(bearing))))
	return apothem >= RING_IN and apothem <= RING_OUT


## A flat octagonal ring between the apothems [param inner] and
## [param outer] (its faces' middles on bearings 0, 45, ...), [param thick]
## high: its top and its two rims.
static func octagon_ring(inner: float, outer: float, thick: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corner := 1.0 / cos(PI / 8.0)
	for k in 8:
		var a0 := PI / 8.0 + PI * 0.25 * k
		var a1 := a0 + PI * 0.25
		var d0 := Vector3(sin(a0), 0.0, -cos(a0))
		var d1 := Vector3(sin(a1), 0.0, -cos(a1))
		var i0 := d0 * inner * corner
		var i1 := d1 * inner * corner
		var o0 := d0 * outer * corner
		var o1 := d1 * outer * corner
		var up := Vector3.UP * thick
		var quads: Array = [
			[i0 + up, o0 + up, o1 + up, i1 + up],   # the top
			[o0, o1, o1 + up, o0 + up],   # the outer rim
			[i1, i0, i0 + up, i1 + up],   # the inner rim
		]
		for q: Array in quads:
			for n: int in [0, 1, 2, 0, 2, 3]:
				var p: Vector3 = q[n]
				st.set_uv(Vector2(p.x, p.z))
				st.add_vertex(p)
	st.generate_normals()
	return st.commit()


# --- light recipe extras -------------------------------------------------------------

## The court's lamplight seen up through the glass, the city's sodium glow.
const COURT_GLOW := Color(1.0, 0.8, 0.55)
const CITY_GLOW := Color(0.8, 0.66, 0.5)
## The glow lamps hang just under the glass (in the court's roof wells).
const GLOW_Y := 22.3
## The city's glow: wide spots high over the gutters and the deck.
const CITY_Y := 29.0
## A bare bulb left burning under each hut's roof (the moon's pool alone
## left them black): [room, position].
const HUT_LANTERNS := [[&"roof_shed", Vector3(-27.5, 25.1, -27.0)], [&"roof_loft", Vector3(19.5, 25.1, 38.6)]]
const LANTERN_LIGHT := Color(1.0, 0.78, 0.5)
const CITY_SPOTS := {
	&"roof_catwalks": [Vector3(0.0, CITY_Y, -28.25), Vector3(0.0, CITY_Y, 28.25), Vector3(-28.25, CITY_Y, 0.0), Vector3(28.25, CITY_Y, 0.0)],
	&"roof_plant": [Vector3(30.0, CITY_Y, 40.0)],
}


## The lamps the roof's art asks for (Floor1LightRecipe extras), by the
## rooms of [param layout]: a warm glow under each glass field (the court's
## lamps seen through the glass from the catwalks), the city's glow over the
## gutters and the plant deck. The moon is the directional light's and the
## layout's pools'.
static func extra_lights(layout: LevelLayout) -> Array:
	var out: Array = []
	if layout.room(&"roof_catwalks") != null:
		for spec in layout.pieces:
			if spec.kit != &"roof_glass" or spec.room != &"roof_catwalks":
				continue
			out.append({"room": spec.room, "position": Vector3(spec.position.x, GLOW_Y, spec.position.z), "color": COURT_GLOW,
				"energy": 0.45, "range": 9.0, "rule": &"court_glow"})
	for hut: Array in HUT_LANTERNS:
		if layout.room(hut[0]) != null:
			out.append({"room": hut[0], "position": hut[1], "color": LANTERN_LIGHT, "energy": 1.0, "range": 6.0, "rule": &"lantern",
				"fixture": &"bulb"})
	for room: StringName in CITY_SPOTS:
		if layout.room(room) == null:
			continue
		for at: Vector3 in CITY_SPOTS[room]:
			out.append({"room": room, "position": at, "direction": Vector3.DOWN, "color": CITY_GLOW, "energy": 0.4,
				"range": 22.0, "angle": 75.0, "rule": &"fill"})
	return out
