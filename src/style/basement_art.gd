class_name BasementArt
extends RefCounted
## Floor I's basement, stage P3 (plan docs/superpowers/plans/2026-10-03-p3-
## oprawa-podziemia.md): the looks of the greybox pieces of the service
## level (zones/basement.gd, service_kit.gd). Rooms get their tiles from
## ArtKit.ROOMS (the basement_* styles); this module dresses the pieces the
## kit has no rule for: the boilers with their flues, fire doors and coal, the
## gantry (deck, posts, rails, open stairs), the pipes in the wings' colours,
## the cross's piers, the transformers, the workshop's benches and half-
## restored exhibits, the stores' racks and crates, the secrets' furniture.
## Pure factories of Node3D trees ("Visual" in the piece's own frame: origin
## = the centre of the base, -Z = front), no collision (the greybox keeps it).
## Bodies are primitives on the kit's tile textures (triplanar, world-mapped);
## racks, crates, cabinets, busts and vases are the kit's models.

## Every kit model this module places (the art test checks each is
## registered and has its file).
const MODELS: Array[String] = [
	"cast_shelf", "asy_tablet_shelf", "shelf_unit", "crate", "camp_crate", "camp_crate_open", "cast_crate",
	"asy_tablet_crate", "lib_filing_cabinet", "gr_plinth_block", "bust", "vase_amphora_bf", "cast_torso",
	"sign_room",
]
## The paint of the metal parts: light steel (court_steel) tinted, dark iron
## (cast_iron) for girders and fittings.
const STEEL := "court_steel"
const IRON := "cast_iron"
const SOOT := Color(0.62, 0.58, 0.56)
const SAFETY := Color(0.9, 0.74, 0.22)
## Steel posts, plates and flues of the boiler hall.
const DARK_STEEL := Color(0.42, 0.44, 0.48)
const EMBER := Color(1.0, 0.42, 0.12)

static var _paints: Dictionary = {}
static var _glow: Dictionary = {}


## True for the rooms of the basement.
static func is_basement(room: StringName) -> bool:
	return String(room).begins_with("basement_")


# --- pieces ----------------------------------------------------------------------

## The look of [param spec] (a basement piece) in its own frame, or null
## where ArtKit's rule for the kit stands (desks, chairs, cases, lockers,
## fuse boxes, grates, lamps...).
static func piece_look(spec: PieceSpec, index: int, layout: LevelLayout) -> Node3D:
	match spec.kit:
		&"pipe":
			return _pipe(spec)
		&"boiler":
			return _boiler(spec)
		&"flue":
			return _flue(spec)
		&"furnace_door":
			return _furnace_door(spec)
		&"coal":
			return _coal(spec)
		&"pier":
			return _pier(spec)
		&"pilaster":
			return _brick_pier(spec)
		&"transformer":
			return _transformer(spec)
		&"well":
			return _well(spec)
		&"bunk":
			return _bunk(spec)
		&"siren":
			return _siren(spec)
		&"balcony":
			return _deck(spec)
		&"balcony_post":
			return _post(spec)
		&"railing":
			return _railing(spec)
		&"crate":
			return _crate(spec, index)
		&"fuse_crate":
			return _crate(spec, index + 1)
		&"shelf":
			return _shelf(spec, layout)
		&"lockers":
			if spec.room == &"basement_archive":
				return _cabinets(spec)
			return _facing(ArtKit.piece(spec.kit, spec.size, spec.room, index), spec, layout)
		&"desk":
			if spec.room == &"basement_workshop":
				return _workbench(spec)
			return _facing(ArtKit.piece(spec.kit, spec.size, spec.room, index), spec, layout)
		&"chair", &"case", &"armor_rack":
			return _facing(ArtKit.piece(spec.kit, spec.size, spec.room, index), spec, layout)
		&"bench":
			return _bench(spec)
		&"pedestal":
			return _pedestal(spec, index)
		&"sculpture":
			return _torso(spec)
		&"wax_head":
			return _wax_head(spec)
		&"urn_shards":
			return _urn_shards(spec)
		&"shield":
			return _shield(spec)
		&"door_leaf":
			return _crypt_door(spec)
	return null


## The plate of a staff-only way (the boarded stairs, the workshop's door
## to the booth): "TYLKO DLA PERSONELU" (the wings' plates have no set for
## the booth).
static func staff_sign(spec: PieceSpec) -> Node3D:
	var root := _holder("Visual")
	var k := spec.size.x / 2.0
	ArtKit._add(root, "sign_room", Transform3D(Basis.from_scale(Vector3(k, k, 1.0)), Vector3(0.0, spec.size.y * 0.5, spec.size.z * 0.5)), "sign_room_personel")
	return root


## The basement's hero pieces (no greybox box stands for them; under
## Floor1Art.dress's heroes, in world space): the freight lift's call box on
## the wall by the bolted door at the tunnel's west end (the lift itself is
## Assyria's), on its own battery: its lamps stay lit in a blackout.
static func dress(layout: LevelLayout, parent: Node3D, rooms: Dictionary = {}) -> void:
	var marker: Variant = layout.markers.get(&"basement_freight_lift")
	if marker == null or layout.room(&"basement_tunnel") == null or not (rooms.is_empty() or rooms.has(&"basement_tunnel")):
		return
	var root := _holder("FreightCallBox")
	root.set_meta(&"kit_room", &"basement_tunnel")
	root.transform = marker
	parent.add_child(root)
	var steel := paint(STEEL, Color(0.45, 0.5, 0.48))
	_box(root, Vector3(0.34, 0.5, 0.1), Vector3(0.0, 0.0, 0.05), steel, false)
	_box(root, Vector3(0.26, 0.18, 0.012), Vector3(0.0, 0.14, -0.006), paint(IRON), false)
	_box(root, Vector3(0.16, 0.06, 0.014), Vector3(0.0, 0.14, -0.008), glow(Color(0.2, 1.0, 0.35), 2.5), false)
	for k in 2:
		_part(root, _cylinder(0.035, 0.03), paint(IRON, Color(2.0, 2.0, 2.0)), Vector3(-0.07 + k * 0.14, -0.06, -0.015), Basis(Vector3.RIGHT, PI * 0.5), false)
	_part(root, _cylinder(0.025, 0.025), glow(Color(1.0, 0.15, 0.1), 3.0), Vector3(0.0, -0.18, -0.012), Basis(Vector3.RIGHT, PI * 0.5), false)
	# the conduit up the wall to the ceiling
	_part(root, _cylinder(0.02, 1.8), paint(IRON), Vector3(0.0, 1.15, 0.03), Basis.IDENTITY, false)


## The gantry's open stairs in the stairs frame (StairsSpec.frame(): origin
## in the middle of the bottom front edge, -Z up the flight): checker-plate
## treads between two steel stringers, pipe handrails on the open sides.
static func stairs(flight: StairsSpec) -> Node3D:
	var root := _holder("Stairs")
	var width := flight.width()
	var rise := flight.top_y - flight.bottom_y
	var steps := flight.step_count()
	var r := rise / steps
	var t := flight.run() / steps
	var plate := paint(STEEL, Color(0.6, 0.58, 0.56))
	for i in steps:
		# step i of ArtKit.stairs: its top at (i + 1) risers, its depth from the
		# nosing one tread back
		_box(root, Vector3(width - 0.1, 0.05, t * 1.05), Vector3(0.0, (i + 1) * r - 0.025, -i * t - t * 0.45), plate)
	# the ramp's line: from the foot to the crest (one tread short of the top)
	var crest := (steps - 1) * t
	var slope := Vector2(crest, rise).length()
	var pitch := atan2(rise, crest)
	var middle := Vector3(0.0, rise * 0.5, -crest * 0.5)
	var posts := maxi(2, int(round(crest / 1.5)) + 1)
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.06, 0.26, slope + 0.2), middle + Vector3(side * (width * 0.5 - 0.03), -0.12, 0.0), paint(IRON), true, Basis(Vector3.RIGHT, pitch))
		if (side < 0.0 and not flight.rail_left) or (side > 0.0 and not flight.rail_right):
			continue
		var rail := paint(STEEL, SAFETY)
		var rx: float = side * (width * 0.5 - 0.05)
		var spin := Basis(Vector3.RIGHT, pitch - PI * 0.5)
		_part(root, _cylinder(0.03, slope), rail, middle + Vector3(rx, 1.0, 0.0), spin, false)
		_part(root, _cylinder(0.025, slope), rail, middle + Vector3(rx, 0.55, 0.0), spin, false)
		for k in posts:
			var f := float(k) / float(posts - 1)
			_box(root, Vector3(0.05, 1.0, 0.05), Vector3(rx, rise * f + 0.5, -crest * f), rail, false)
	return root


## The painted steel of the switchboard's cabinet (Switchboard: the greybox
## stays a plain grey box without the art).
static func cabinet_paint() -> Material:
	return paint(STEEL, Color(0.5, 0.58, 0.54))


## Dresses the switchboard at its marker ([param board]: origin on the
## cabinet's face, -Z into the room; [param body] the cabinet's size): a
## bezel, two gauges, a knife switch, rows of breakers, cables up the wall.
## The cabinet, its two fuse sockets and its lamp are the Switchboard's own.
static func dress_switchboard(board: Node3D, body: Vector3) -> void:
	var root := _holder("Dressing")
	board.add_child(root)
	var iron := paint(IRON, Color(1.6, 1.6, 1.6))
	var half := body * 0.5
	# the bezel round the face
	_box(root, Vector3(body.x + 0.04, 0.05, 0.06), Vector3(0.0, half.y, -0.01), iron, false)
	_box(root, Vector3(body.x + 0.04, 0.05, 0.06), Vector3(0.0, -half.y, -0.01), iron, false)
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.05, body.y, 0.06), Vector3(side * half.x, 0.0, -0.01), iron, false)
	# two gauges high on the panel: a white dial, a dark ring, a needle
	var face := Basis(Vector3.RIGHT, PI * 0.5)
	for x in [-0.3, 0.3]:
		_part(root, _cylinder(0.1, 0.03), iron, Vector3(float(x), 0.45, -0.025), face, false)
		_part(root, _cylinder(0.08, 0.02), paint("plaster", Color(1.0, 1.0, 0.95)), Vector3(float(x), 0.45, -0.04), face, false)
		_box(root, Vector3(0.012, 0.07, 0.01), Vector3(float(x) + 0.015, 0.46, -0.052), paint(IRON), false, Basis(Vector3.BACK, 0.5))
	# the main knife switch under the sockets
	_box(root, Vector3(0.34, 0.3, 0.02), Vector3(0.0, -0.22, -0.01), paint(STEEL, Color(0.3, 0.32, 0.34)), false)
	_box(root, Vector3(0.04, 0.24, 0.03), Vector3(0.0, -0.2, -0.04), paint(STEEL, Color(0.8, 0.8, 0.82)), false, Basis(Vector3.BACK, 0.18))
	_box(root, Vector3(0.1, 0.05, 0.05), Vector3(-0.04, -0.07, -0.05), paint(IRON), false)
	# rows of breakers along the bottom
	for row in 2:
		for k in 6:
			_box(root, Vector3(0.1, 0.12, 0.04), Vector3(-0.4 + k * 0.16, -0.5 - row * 0.15, -0.02), paint(IRON, Color(1.3, 1.3, 1.3)), false)
	# cables climbing the wall to the ceiling
	var cable := paint(IRON)
	for x in [-0.3, 0.0, 0.3]:
		_part(root, _cylinder(0.025, 2.1), cable, Vector3(float(x), half.y + 1.05, body.z - 0.1), Basis.IDENTITY, false)


# --- helpers ----------------------------------------------------------------------

static func _holder(label: String) -> Node3D:
	var n := Node3D.new()
	n.name = label
	return n


## A triplanar painted material of kit texture [param texture] (world-mapped,
## the texture's own 64 px per metre), tinted.
static func paint(texture: String, tint: Color = Color.WHITE) -> Material:
	var key := "%s:%s" % [texture, tint.to_html()]
	if not _paints.has(key):
		var image := ArtLibrary.texture(texture, "albedo")
		var metres := Vector2(image.get_width(), image.get_height()) / 64.0 if image != null else Vector2(2.0, 2.0)
		var mat := ArtLibrary.tiled(texture, metres).duplicate() as ORMMaterial3D
		mat.albedo_color = tint
		_paints[key] = mat
	return _paints[key]


## A glowing part (embers behind a furnace door): dark paint, strong
## emission.
static func glow(color: Color, energy: float = 3.0) -> Material:
	var key := "%s:%s" % [color.to_html(), energy]
	if not _glow.has(key):
		var mat := StandardMaterial3D.new()
		mat.resource_name = "ember"
		mat.albedo_color = Color(0.06, 0.03, 0.02)
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = energy
		_glow[key] = mat
	return _glow[key]


static func _part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3, basis: Basis = Basis.IDENTITY, shadow: bool = true) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	view.transform = Transform3D(basis, at)
	if not shadow:
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(view)
	return view


static func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material, shadow: bool = true, basis: Basis = Basis.IDENTITY) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(parent, mesh, material, at, basis, shadow)


## A cylinder along Y ([param height] long).
static func _cylinder(radius: float, height: float, top_radius: float = -1.0) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 14
	mesh.rings = 1
	return mesh


## Positions along a run of [param length] centred on 0: both ends and every
## [param step] m between.
static func _spaced(length: float, step: float, margin: float) -> Array[float]:
	var out: Array[float] = []
	var span := maxf(length - 2.0 * margin, 0.0)
	var n := maxi(1, int(round(span / step)))
	for k in n + 1:
		out.append(-length * 0.5 + margin + span * float(k) / float(n))
	return out


## [param look] turned half a way round when its front (-Z after the
## piece's yaw) looks at a wall and the open side of the room is behind it:
## the greybox boxes have no front, the kit's models do.
static func _facing(look: Node3D, spec: PieceSpec, layout: LevelLayout) -> Node3D:
	if look == null:
		return null
	if _front_blocked(spec, layout):
		var turned := _holder("Visual")
		look.rotation.y = PI
		turned.add_child(look)
		look.name = "Turned"
		return turned
	return look


static func _front_blocked(spec: PieceSpec, layout: LevelLayout) -> bool:
	var room := layout.room(spec.room) if layout != null else null
	if room == null or room.parts.is_empty():
		return false
	var front := spec.transform().basis * Vector3(0.0, 0.0, -1.0)
	var reach := spec.size.z * 0.5 + 0.7
	var ahead := Vector2(spec.position.x + front.x * reach, spec.position.z + front.z * reach)
	var behind := Vector2(spec.position.x - front.x * reach, spec.position.z - front.z * reach)
	return not room.covers(ahead) and room.covers(behind)


## [param id] fitted to [param size] (its native bounds), its origin on the
## base centre of [param root].
static func _fit_model(root: Node3D, id: String, size: Vector3, at: Vector3 = Vector3.ZERO, yaw: float = 0.0, texture_set: String = "") -> Node3D:
	var box := Floor1Art.bounds(id)
	var k := Vector3(size.x / maxf(box.size.x, 0.01), size.y / maxf(box.size.y, 0.01), size.z / maxf(box.size.z, 0.01))
	return ArtKit._add(root, id, Transform3D(Basis(Vector3.UP, yaw).scaled(k), at), texture_set)


## One MultiMeshInstance3D drawing [param mesh] with [param material] at
## [param transforms] (in [param parent]'s frame): a row's worth of equal
## parts in one draw call.
static func _multi(parent: Node3D, mesh: Mesh, material: Material, transforms: Array[Transform3D], shadow: bool = false) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for k in transforms.size():
		multi.set_instance_transform(k, transforms[k])
	var holder := MultiMeshInstance3D.new()
	holder.multimesh = multi
	if material != null:
		holder.material_override = material
	if not shadow:
		holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(holder)
	return holder


## Kit model [param id] at every transform of [param transforms] (in
## [param parent]'s frame) as MultiMeshes, one per mesh of the model: a rack's
## units, a row of cabinets. The nodes carry the model's id in meta "model".
static func _multi_model(parent: Node3D, id: String, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var model := ArtKit.model(id)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var view := node as MeshInstance3D
		var local := Transform3D.IDENTITY
		var n: Node = view
		while n != null and n != model:
			local = (n as Node3D).transform * local
			n = n.get_parent()
		var placed: Array[Transform3D] = []
		for xf in transforms:
			placed.append(xf * local)
		var holder := _multi(parent, ArtKit.baked_mesh(view), null, placed, true)
		holder.set_meta(&"model", id)
	model.free()


# --- pipes, deck, posts, rails ---------------------------------------------------

## A pipe run in its wing's colour: the pipe, a collar and a bracket to the
## ceiling every 2.5 m; the boiler hall's steam main is lagged (bands).
static func _pipe(spec: PieceSpec) -> Node3D:
	var root := _holder("Visual")
	var d := spec.size.y
	var r := d * 0.5
	var length := spec.size.x
	var tint := spec.tint if spec.tint.a > 0.0 else Color(0.6, 0.6, 0.62)
	var skin := paint(STEEL, tint)
	var along := Basis(Vector3.BACK, PI * 0.5)
	_part(root, _cylinder(r, length), skin, Vector3(0.0, r, 0.0), along, false)
	var lagged := d > 0.3
	var collars: Array[Transform3D] = []
	var brackets: Array[Transform3D] = []
	for x in _spaced(length, 2.5, 0.3):
		collars.append(Transform3D(along, Vector3(x, r, 0.0)))
		brackets.append(Transform3D(Basis.IDENTITY, Vector3(x, d + 0.1, 0.0)))
	var ring := paint(IRON) if not lagged else paint(STEEL, tint.darkened(0.35))
	_multi(root, _cylinder(r + 0.035, 0.1), ring, collars)
	var bracket := BoxMesh.new()
	bracket.size = Vector3(0.06, 0.2, 0.1)
	_multi(root, bracket, paint(IRON), brackets)
	return root


## The gantry's walking plate over a grid of girders: the plate's top is the
## piece's top.
static func _deck(spec: PieceSpec) -> Node3D:
	var s := spec.size
	var root := _holder("Visual")
	_box(root, Vector3(s.x, 0.06, s.z), Vector3(0.0, s.y - 0.03, 0.0), paint(STEEL, Color(0.62, 0.6, 0.58)))
	var along_x := s.x >= s.z
	var long_side := s.x if along_x else s.z
	var short_side := s.z if along_x else s.x
	var n := maxi(2, int(round(short_side / 0.9)) + 1)
	var girder := paint(IRON)
	for i in n:
		var t := -short_side * 0.5 + 0.04 + float(i) * (short_side - 0.08) / float(n - 1)
		var size := Vector3(long_side, s.y - 0.06, 0.08) if along_x else Vector3(0.08, s.y - 0.06, long_side)
		var at := Vector3(0.0, (s.y - 0.06) * 0.5, t) if along_x else Vector3(t, (s.y - 0.06) * 0.5, 0.0)
		_box(root, size, at, girder, false)
	return root


## A steel post under the gantry: shaft, base plate and cap.
static func _post(spec: PieceSpec) -> Node3D:
	var s := spec.size
	var root := _holder("Visual")
	var steel := paint(STEEL, DARK_STEEL)
	_box(root, Vector3(0.2, s.y - 0.1, 0.2), Vector3(0.0, s.y * 0.5, 0.0), steel)
	_box(root, Vector3(minf(s.x, 0.4), 0.05, minf(s.z, 0.4)), Vector3(0.0, 0.025, 0.0), steel, false)
	_box(root, Vector3(0.3, 0.05, 0.3), Vector3(0.0, s.y - 0.025, 0.0), steel, false)
	return root


## A pipe railing in safety yellow: posts every 1.5 m, two rails, a toe plate.
static func _railing(spec: PieceSpec) -> Node3D:
	var s := spec.size
	var root := _holder("Visual")
	var yellow := paint(STEEL, SAFETY)
	var along := Basis(Vector3.BACK, PI * 0.5)
	_part(root, _cylinder(0.03, s.x), yellow, Vector3(0.0, s.y - 0.03, 0.0), along, false)
	_part(root, _cylinder(0.025, s.x), yellow, Vector3(0.0, s.y * 0.5, 0.0), along, false)
	_box(root, Vector3(s.x, 0.12, 0.02), Vector3(0.0, 0.06, 0.0), yellow, false)
	var n := maxi(1, int(ceil(s.x / 1.5)))
	for k in n + 1:
		_box(root, Vector3(0.05, s.y, 0.05), Vector3(-s.x * 0.5 + 0.025 + float(k) * (s.x - 0.05) / float(n), s.y * 0.5, 0.0), yellow, false)
	return root


# --- the boiler hall ----------------------------------------------------------------

## A Cornish boiler: a brick setting with a firebox block in front and a
## cheek wall behind, the riveted drum between them (set back toward the
## flue), a steam dome; the iron front with the fire doors is on +Z.
static func _boiler(spec: PieceSpec) -> Node3D:
	var s := spec.size
	var root := _holder("Visual")
	var brick := paint("brick", SOOT)
	var steel := paint(STEEL, DARK_STEEL)
	var setting := s.y * 0.53
	var cheek := s.y * 0.27
	_box(root, Vector3(s.x, setting, s.z - 0.12), Vector3(0.0, setting * 0.5, -0.06), brick)
	# the firebox block in front (its iron front reaches the cheek's top)
	_box(root, Vector3(s.x, cheek, 1.2), Vector3(0.0, setting + cheek * 0.5, s.z * 0.5 - 0.72), brick)
	_box(root, Vector3(s.x - 0.1, setting + cheek - 0.05, 0.12), Vector3(0.0, (setting + cheek - 0.05) * 0.5, s.z * 0.5 - 0.06), steel)
	_box(root, Vector3(s.x, cheek, 0.48), Vector3(0.0, setting + cheek * 0.5, -s.z * 0.5 + 0.24), brick)
	var radius := 0.95
	var length := s.x - 0.5
	var axis := Vector3(0.0, s.y - radius, -0.4)
	var along := Basis(Vector3.BACK, PI * 0.5)
	_part(root, _cylinder(radius, length), steel, axis, along)
	for x in [-length * 0.5, -2.4, -0.8, 0.8, 2.4, length * 0.5]:
		_part(root, _cylinder(radius + 0.035, 0.1), paint(STEEL, DARK_STEEL.lightened(0.15)), axis + Vector3(float(x), 0.0, 0.0), along, false)
	# the steam dome on the drum and its valve
	_part(root, _cylinder(0.4, 0.5), steel, Vector3(0.9, s.y + 0.2, axis.z))
	_part(root, _cylinder(0.12, 0.45), steel, Vector3(0.9, s.y + 0.7, axis.z), Basis.IDENTITY, false)
	# the ash-pit doors under the fire doors
	for x in [-1.5, 1.5]:
		_box(root, Vector3(1.0, 0.3, 0.05), Vector3(float(x), 0.25, s.z * 0.5 + 0.02), paint(IRON), false)
	return root


## A flue from the shoulder of a boiler's drum to the ceiling (its foot goes
## down into the drum's plating).
static func _flue(spec: PieceSpec) -> Node3D:
	var s := spec.size
	var root := _holder("Visual")
	var steel := paint(STEEL, Color(0.34, 0.33, 0.33))
	var radius := minf(s.x, s.z) * 0.45
	_part(root, _cylinder(radius, s.y + 0.4), steel, Vector3(0.0, s.y * 0.5 - 0.2, 0.0))
	for y in [0.06, s.y * 0.5, s.y - 0.06]:
		_part(root, _cylinder(radius + 0.07, 0.12), steel, Vector3(0.0, float(y), 0.0), Basis.IDENTITY, false)
	return root


## An iron fire door with its glowing slit (+Z is the front, the room's side).
static func _furnace_door(spec: PieceSpec) -> Node3D:
	var s := spec.size
	var root := _holder("Visual")
	var iron := paint(IRON, Color(1.5, 1.5, 1.5))
	_box(root, s, Vector3(0.0, s.y * 0.5, 0.0), iron, false)
	_box(root, Vector3(s.x * 0.62, s.y * 0.2, 0.02), Vector3(0.0, s.y * 0.58, s.z * 0.5 + 0.005), glow(EMBER, 3.5), false)
	_box(root, Vector3(s.x * 0.8, 0.05, 0.05), Vector3(0.0, s.y * 0.88, s.z * 0.5 + 0.02), paint(STEEL, DARK_STEEL), false)
	_box(root, Vector3(0.05, 0.28, 0.06), Vector3(s.x * 0.36, s.y * 0.3, s.z * 0.5 + 0.03), paint(STEEL, DARK_STEEL), false)
	return root


## A heap of coal: black angular lumps, the biggest in the middle.
static func _coal(spec: PieceSpec) -> Node3D:
	var s := spec.size
	var root := _holder("Visual")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.position.x * 31.0) ^ int(spec.position.z * 17.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.055)
	mat.roughness = 0.45
	mat.metallic = 0.15
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	multi.mesh = mesh
	var lumps := 46
	multi.instance_count = lumps
	for k in lumps:
		var u := rng.randf_range(-1.0, 1.0)
		var v := rng.randf_range(-1.0, 1.0)
		var height := s.y * clampf(1.0 - 0.65 * (u * u + v * v), 0.1, 1.0)
		var size := rng.randf_range(0.18, 0.4)
		var at := Vector3(u * (s.x * 0.5 - 0.25), maxf(height - size * 0.5, size * 0.4), v * (s.z * 0.5 - 0.25))
		var basis := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(Vector3(size, size * rng.randf_range(0.6, 1.0), size * rng.randf_range(0.7, 1.1)))
		multi.set_instance_transform(k, Transform3D(basis, at))
	var heap := MultiMeshInstance3D.new()
	heap.multimesh = multi
	heap.material_override = mat
	root.add_child(heap)
	_box(root, Vector3(s.x - 0.3, 0.3, s.z - 0.3), Vector3(0.0, 0.15, 0.0), mat, false)
	return root


# --- the cross, the switchboard, the secrets -----------------------------------------

## A pier of the Reading Room's foundations: brick shaft, stone base, string
## course and capital.
static func _pier(spec: PieceSpec) -> Node3D:
	var s := spec.size
	var root := _holder("Visual")
	var stone := paint("limestone_rustic", Color(0.68, 0.68, 0.72))
	_box(root, Vector3(s.x, 0.5, s.z), Vector3(0.0, 0.25, 0.0), stone)
	_box(root, Vector3(s.x - 0.3, s.y - 0.9, s.z - 0.3), Vector3(0.0, 0.5 + (s.y - 0.9) * 0.5, 0.0), paint("brick", Color(0.72, 0.66, 0.62)))
	_box(root, Vector3(s.x - 0.2, 0.1, s.z - 0.2), Vector3(0.0, s.y * 0.5, 0.0), stone, false)
	_box(root, Vector3(s.x, 0.4, s.z), Vector3(0.0, s.y - 0.2, 0.0), stone)
	return root


## A brick pier of the tunnel's arches against its wall (stone foot and cap).
static func _brick_pier(spec: PieceSpec) -> Node3D:
	var s := spec.size
	var root := _holder("Visual")
	var stone := paint("limestone_rustic", Color(0.7, 0.7, 0.72))
	_box(root, Vector3(s.x, 0.3, s.z), Vector3(0.0, 0.15, 0.0), stone)
	_box(root, Vector3(s.x - 0.1, s.y - 0.6, s.z - 0.08), Vector3(0.0, 0.3 + (s.y - 0.6) * 0.5, 0.0), paint("brick", Color(0.85, 0.8, 0.78)))
	_box(root, Vector3(s.x, 0.3, s.z), Vector3(0.0, s.y - 0.15, 0.0), stone)
	return root


## An oil-filled transformer: tank on a plinth with radiator fins, a
## conservator along the top and three white bushings.
static func _transformer(spec: PieceSpec) -> Node3D:
	var s := spec.size
	var root := _holder("Visual")
	var tank := paint(STEEL, Color(0.55, 0.66, 0.6))
	var base := 0.3
	_box(root, Vector3(s.x, base, s.z), Vector3(0.0, base * 0.5, 0.0), paint("concrete"))
	var tank_h := s.y - base - 0.75
	_box(root, Vector3(s.x - 0.4, tank_h, s.z - 0.9), Vector3(0.0, base + tank_h * 0.5, 0.0), tank)
	var fins := maxi(4, int(round((s.x - 0.6) / 0.28)))
	for side in [-1.0, 1.0]:
		for k in fins:
			var x := -s.x * 0.5 + 0.3 + float(k) * (s.x - 0.6) / float(fins - 1)
			_box(root, Vector3(0.1, tank_h - 0.2, 0.34), Vector3(x, base + tank_h * 0.5, side * (s.z * 0.5 - 0.28)), tank, false)
	_part(root, _cylinder(0.24, s.x - 0.7), tank, Vector3(0.0, base + tank_h + 0.3, -s.z * 0.2), Basis(Vector3.BACK, PI * 0.5), false)
	var ceramic := paint("marble_white", Color(0.95, 0.95, 0.92))
	for x in [-0.7, 0.0, 0.7]:
		_part(root, _cylinder(0.09, 0.45, 0.05), ceramic, Vector3(float(x), base + tank_h + 0.22, s.z * 0.2), Basis.IDENTITY, false)
	return root


## The old well of Montagu House: a stone ring round a dark shaft.
static func _well(spec: PieceSpec) -> Node3D:
	var s := spec.size
	var root := _holder("Visual")
	var radius := minf(s.x, s.z) * 0.5
	_part(root, _cylinder(radius, s.y), paint("stone_rubble", Color(0.8, 0.78, 0.76)), Vector3(0.0, s.y * 0.5, 0.0))
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.01, 0.01, 0.015)
	_part(root, _cylinder(radius * 0.68, 0.02), dark, Vector3(0.0, s.y - 0.01, 0.0), Basis.IDENTITY, false)
	_part(root, _cylinder(radius + 0.05, 0.1), paint("limestone_rustic", Color(0.75, 0.75, 0.78)), Vector3(0.0, s.y - 0.05, 0.0), Basis.IDENTITY, false)
	return root


## A 1940 steel bunk: four posts, two canvas mattresses.
static func _bunk(spec: PieceSpec) -> Node3D:
	var s := spec.size
	var root := _holder("Visual")
	var frame := paint(IRON, Color(1.6, 1.6, 1.6))
	var canvas := paint("plaster", Color(0.45, 0.5, 0.38))
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_box(root, Vector3(0.06, s.y, 0.06), Vector3(x * (s.x * 0.5 - 0.04), s.y * 0.5, z * (s.z * 0.5 - 0.04)), frame, false)
	for y in [0.3, 0.95]:
		_box(root, Vector3(s.x - 0.1, 0.04, s.z - 0.1), Vector3(0.0, float(y), 0.0), frame, false)
		_box(root, Vector3(s.x - 0.14, 0.1, s.z - 0.14), Vector3(0.0, float(y) + 0.07, 0.0), canvas)
	_box(root, Vector3(0.3, 0.08, s.z - 0.2), Vector3(-s.x * 0.5 + 0.3, 0.38, 0.0), paint("plaster", Color(0.85, 0.85, 0.8)), false)
	return root


## A hand-cranked air-raid siren: base, post, motor drum, red horn.
static func _siren(spec: PieceSpec) -> Node3D:
	var s := spec.size
	var root := _holder("Visual")
	var steel := paint(STEEL, Color(0.5, 0.52, 0.55))
	_box(root, Vector3(s.x * 0.85, 0.1, s.z * 0.85), Vector3(0.0, 0.05, 0.0), steel)
	_part(root, _cylinder(0.05, s.y * 0.45), steel, Vector3(0.0, 0.1 + s.y * 0.22, 0.0))
	_part(root, _cylinder(0.18, 0.28), steel, Vector3(0.0, s.y * 0.58, 0.0))
	_part(root, _cylinder(0.1, s.y * 0.3, 0.28), paint(STEEL, Color(0.75, 0.2, 0.16)), Vector3(0.0, s.y * 0.85, 0.0))
	_box(root, Vector3(0.05, 0.05, 0.25), Vector3(0.23, s.y * 0.58, 0.0), steel, false)
	return root


# --- the workshop --------------------------------------------------------------------

## A restorer's bench: a thick oak top on trestle ends, a lower shelf and a
## vise.
static func _workbench(spec: PieceSpec) -> Node3D:
	var s := spec.size
	var root := _holder("Visual")
	var oak := paint("wood_dark", Color(1.15, 1.05, 0.95))
	_box(root, Vector3(s.x, 0.1, s.z), Vector3(0.0, s.y - 0.05, 0.0), oak)
	_box(root, Vector3(s.x - 0.3, 0.12, s.z - 0.25), Vector3(0.0, s.y - 0.16, 0.0), paint("timber"), false)
	for side in [-1.0, 1.0]:
		var x: float = side * (s.x * 0.5 - 0.2)
		for z in [-1.0, 1.0]:
			_box(root, Vector3(0.1, s.y - 0.1, 0.1), Vector3(x, (s.y - 0.1) * 0.5, z * (s.z * 0.5 - 0.15)), paint("timber"), false)
		_box(root, Vector3(0.06, 0.08, s.z - 0.3), Vector3(x, 0.3, 0.0), paint("timber"), false)
	_box(root, Vector3(s.x - 0.5, 0.04, s.z - 0.3), Vector3(0.0, 0.24, 0.0), paint("timber"), false)
	_box(root, Vector3(0.2, 0.14, 0.18), Vector3(s.x * 0.5 - 0.35, s.y + 0.07, s.z * 0.5 - 0.2), paint(IRON, Color(1.6, 1.6, 1.6)), false)
	return root


## A plank bench: a seat on two end boards.
static func _bench(spec: PieceSpec) -> Node3D:
	var s := spec.size
	var root := _holder("Visual")
	var wood := paint("timber", Color(1.2, 1.1, 1.0))
	_box(root, Vector3(s.x, 0.06, s.z), Vector3(0.0, s.y - 0.03, 0.0), wood)
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.06, s.y - 0.06, s.z - 0.08), Vector3(side * (s.x * 0.5 - 0.2), (s.y - 0.06) * 0.5, 0.0), wood, false)
	return root


## A plinth of the plinth store with its exhibit: a bronze bust, then an
## amphora.
static func _pedestal(spec: PieceSpec, index: int) -> Node3D:
	var s := spec.size
	var root := _holder("Visual")
	_fit_model(root, "gr_plinth_block", s)
	if posmod(index, 2) == 0:
		var bust := ArtKit._add(root, "bust", Transform3D(Basis(Vector3.UP, 0.4).scaled(Vector3.ONE * 1.5), Vector3(0.0, s.y, 0.0)), "bust_bronze")
		bust.name = "Bust"
	else:
		ArtKit._add(root, "vase_amphora_bf", Transform3D(Basis(Vector3.UP, 0.8).scaled(Vector3.ONE * 1.5), Vector3(0.0, s.y, 0.0)))
	return root


## A plaster cast of a torso on the bench, half finished.
static func _torso(spec: PieceSpec) -> Node3D:
	var root := _holder("Visual")
	_fit_model(root, "cast_torso", spec.size)
	return root


## A wax head being repaired (a half-size bust).
static func _wax_head(spec: PieceSpec) -> Node3D:
	var root := _holder("Visual")
	ArtKit._add(root, "bust", Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * spec.size.y / 0.62), Vector3.ZERO), "bust")
	return root


## An urn in shards: the lower half built up, the rest in pieces round it.
static func _urn_shards(spec: PieceSpec) -> Node3D:
	var s := spec.size
	var root := _holder("Visual")
	var clay := paint("sandstone", Color(0.95, 0.62, 0.46))
	_part(root, _cylinder(0.22, 0.2, 0.15), clay, Vector3(-s.x * 0.2, 0.1, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.position.x * 13.0) ^ int(spec.position.z * 7.0)
	for k in 7:
		var at := Vector3(rng.randf_range(-s.x * 0.45, s.x * 0.45), 0.02, rng.randf_range(-s.z * 0.4, s.z * 0.4))
		_box(root, Vector3(rng.randf_range(0.1, 0.22), 0.03, rng.randf_range(0.08, 0.16)), at, clay, false, Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))))
	return root


## A bronze shield being mended: a disc with a rim and a boss.
static func _shield(spec: PieceSpec) -> Node3D:
	var s := spec.size
	var root := _holder("Visual")
	var bronze := paint("brass", Color(0.75, 0.62, 0.5))
	var radius := minf(s.x, s.z) * 0.5
	_part(root, _cylinder(radius, 0.05), bronze, Vector3(0.0, 0.03, 0.0), Basis.IDENTITY, false)
	var rim := TorusMesh.new()
	rim.inner_radius = radius - 0.04
	rim.outer_radius = radius
	rim.rings = 20
	rim.ring_segments = 6
	_part(root, rim, bronze, Vector3(0.0, 0.05, 0.0), Basis.IDENTITY, false)
	_part(root, _cylinder(0.13, 0.07, 0.1), bronze, Vector3(0.0, 0.08, 0.0), Basis.IDENTITY, false)
	return root


# --- stores ------------------------------------------------------------------------------

## A rack against a wall or back to back in a row: the kit's shelving models
## by room (the reserve alternates plaster casts, clay tablets and green
## steel; the workshop's are the casts'), crates on the top of tall rows.
static func _shelf(spec: PieceSpec, layout: LevelLayout) -> Node3D:
	var s := spec.size
	var root := _holder("Visual")
	var id := _rack_model(spec)
	var box := Floor1Art.bounds(id)
	# the green steel unit is a metre module (its uprights overlap), the cast
	# and tablet racks are two metres
	var step := 1.0 if id == "shelf_unit" else box.size.x
	var n := maxi(1, int(round(s.x / step)))
	var w := s.x / n
	var back_to_back := s.z >= 0.9
	var depth := s.z * 0.5 if back_to_back else s.z
	var tiers := 1
	var unit_h := box.size.y
	if id == "shelf_unit" and s.y > 2.6:
		tiers = 2
		unit_h = s.y / tiers
	var k := Vector3(w / box.size.x, unit_h / box.size.y, depth / box.size.z)
	var units: Array[Transform3D] = []
	var crates := {}
	for i in n:
		var x := -s.x * 0.5 + (float(i) + 0.5) * w
		for tier in tiers:
			var y := tier * unit_h
			if back_to_back:
				units.append(Transform3D(Basis.from_scale(k), Vector3(x, y, -s.z * 0.25)))
				units.append(Transform3D(Basis(Vector3.UP, PI).scaled(k), Vector3(x, y, s.z * 0.25)))
			else:
				units.append(Transform3D(Basis.from_scale(k), Vector3(x, y, 0.0)))
		# crates on the top of a tall row
		var top := unit_h * tiers
		if s.y - top > 0.55 and (i % 2) == 0:
			var crate := String(["camp_crate", "asy_tablet_crate"][posmod(int(i * 0.5) + int(spec.position.z), 2)])
			var cb := Floor1Art.bounds(crate)
			var kc := minf(minf(minf(w * 0.8 / cb.size.x, (s.z - 0.1) / cb.size.z), (s.y - top) / cb.size.y), 1.1)
			if not crates.has(crate):
				crates[crate] = [] as Array[Transform3D]
			(crates[crate] as Array[Transform3D]).append(Transform3D(Basis(Vector3.UP, 0.1 * float(i % 3)).scaled(Vector3.ONE * kc), Vector3(x, top, 0.0)))
	_multi_model(root, id, units)
	for crate: String in crates:
		_multi_model(root, crate, crates[crate])
	if not back_to_back and _front_blocked(spec, layout):
		var turned := _holder("Visual")
		root.name = "Turned"
		root.rotation.y = PI
		turned.add_child(root)
		return turned
	return root


## The shelving model of a rack by room and row.
static func _rack_model(spec: PieceSpec) -> String:
	match spec.room:
		&"basement_workshop":
			return "cast_shelf"
		&"basement_reserve":
			return ["cast_shelf", "asy_tablet_shelf", "shelf_unit", "cast_shelf", "asy_tablet_shelf"][posmod(int(round((spec.position.z + 4.0) / 6.0)), 5)] as String
	return "shelf_unit"


## A row of filing cabinets, the archive's: one per half metre, fronts toward
## the aisle (the two west rows face each other).
static func _cabinets(spec: PieceSpec) -> Node3D:
	var s := spec.size
	var root := _holder("Visual")
	var n := maxi(1, int(round(s.x / 0.55)))
	var w := s.x / n
	var box := Floor1Art.bounds("lib_filing_cabinet")
	var k := Vector3(w / box.size.x, s.y / box.size.y, s.z / box.size.z)
	var facing := PI if spec.position.x < 14.0 else 0.0
	var row: Array[Transform3D] = []
	for i in n:
		row.append(Transform3D(Basis(Vector3.UP, facing).scaled(k), Vector3(-s.x * 0.5 + (float(i) + 0.5) * w, 0.0, 0.0)))
	_multi_model(root, "lib_filing_cabinet", row)
	return root


## A crate by its proportions: the nearest of the kit's crates (the camp's,
## the plaster casts', the tablets', the lobby's), a different one by place.
static func _crate(spec: PieceSpec, index: int) -> Node3D:
	var s := spec.size
	var root := _holder("Visual")
	var candidates := ["crate", "camp_crate", "camp_crate_open", "cast_crate", "asy_tablet_crate"]
	var scored: Array = []
	for id: String in candidates:
		var b := Floor1Art.bounds(id)
		var miss := absf(log((s.y / s.x) / (b.size.y / b.size.x))) + absf(log((s.z / s.x) / (b.size.z / b.size.x)))
		scored.append([miss, id])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var pick: String = scored[posmod(hash(Vector2i(roundi(spec.position.x * 2.0), roundi(spec.position.z * 2.0))) + index, 2)][1]
	var texture_set := "camp_crate_b" if pick == "camp_crate" and posmod(index, 2) == 1 else ""
	_fit_model(root, pick, s, Vector3.ZERO, 0.0, texture_set)
	return root


## The bricked-up crypt door: oak planks with iron straps (the grille is the
## piece in front of it).
static func _crypt_door(spec: PieceSpec) -> Node3D:
	var s := spec.size
	var root := _holder("Visual")
	_box(root, Vector3(s.x, s.y, s.z), Vector3(0.0, s.y * 0.5, 0.0), paint("wood_dark", Color(0.8, 0.75, 0.7)))
	for y in [0.35, s.y * 0.5, s.y - 0.35]:
		_box(root, Vector3(s.x, 0.14, s.z + 0.03), Vector3(0.0, float(y), 0.0), paint(IRON, Color(1.5, 1.5, 1.5)), false)
	return root
