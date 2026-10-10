class_name Floor1ArtGreece
extends RefCounted
## Floor I's Greek wing dressed, stage P3 (plan docs/superpowers/plans/
## 2026-10-03-p3-oprawa-grecja-oswiecenie.md section 3; catalogue
## docs/art/kit-pietro1-grecja.md): the brightest wing, white marble under
## silver moonlight. Pure factories of Node3D trees of ArtLibrary models, no
## collision (the greybox keeps it); Floor1Art asks this module for every
## room whose id starts with "greece_":
## - [method piece_look]: the podium of the Nereid Monument, the Nereids,
##   Greek plinths, the pediment groups (fitted round the greybox boxes the
##   Centaur charges into, which stay as they are), metopes, vase cases, the
##   cast store's shelves; null = Floor1Art's and ArtKit's rules;
## - [method dress]: the hero pieces - the Nereid temple on its podium (its
##   front columns on the greybox's), the skylights' iron laylights, the
##   Doric entablature over the Parthenon gallery's mouth;
## - [method fixture]: none of its own (the lobby's fittings).

const Greece := preload("res://src/level/floor1/zones/greece.gd")

## Every model this module places (the art tests check each is registered,
## on disk and placed).
const MODELS: Array[String] = [
	"nereid_podium", "nereid_temple", "nereid_a", "nereid_b", "nereid_c", "nereid_d", "gr_skylight_4m",
	"gr_plinth_block", "gr_column_ionic", "gr_ped_reclining", "gr_ped_goddesses", "gr_ped_seated", "gr_ped_horse",
	"gr_ped_torso", "gr_metope_a", "gr_metope_b", "gr_metope_c", "gr_metope_d", "gr_cornice_doric_4m",
	"vase_case_tall", "vase_case_wall_2m", "vase_volute", "vase_amphora_bf", "vase_amphora_rf", "vase_krater",
	"vase_hydria", "vase_kylix", "vase_lekythos", "cast_shelf", "cast_head", "cast_crate",
]
## Openings with portals of their own (Floor1Art.PORTALS' form): none, the
## room styles' Erechtheion portals fit every doorway of the wing.

## The Nereid Monument: the podium's body fills the greybox podium (7 deep,
## 10 wide, 4.5 high; the base step stands proud); the temple's cella front
## on the greybox cella's face (x -82.5), its back in the west wall (no
## deeper than the wall: the Bassae room is behind it), its stylobate 2 cm
## over the podium's top, the whole 13.6 m high in the 14 m hall.
const PODIUM_SCALE := Vector3(10.0 / 7.2, 4.5 / 4.4, 7.0 / 4.0)
const TEMPLE_SCALE := Vector3(7.0 / 6.2, 1.4, 1.739)
const TEMPLE_ORIGIN := Vector3(-83.02, 4.1, 12.0)
## The front columns' line (the greybox's columns) and the nereids' scale.
const PORCH_X := -79.7
const NEREID_SCALE := 0.95
## Skylight frames: one model per cell about 4 m square; the well's depth
## (LevelLayout.SKYLIGHT_WELL) over the model's 2 m.
const SKYLIGHT_CELL := 4.0
## The Doric entablature over the arena's mouth (Parthenon face), m.
const MOUTH_ENTABLATURE := 9.6
## Vases for the six cases (by their place: west to east, north row
## first; the two that may hold loot stay empty).
const CASE_VASES: Array[String] = ["vase_volute", "vase_hydria", "vase_amphora_bf", "vase_lekythos", "vase_krater", "vase_amphora_rf"]


# --- pieces --------------------------------------------------------------------

## The look of [param spec] (a piece of a Greek room) in its own frame, or
## null (the common rules).
static func piece_look(spec: PieceSpec, index: int, layout: LevelLayout) -> Variant:
	var size := spec.size
	match spec.kit:
		&"pedestal":
			if spec.room == &"greece_nereid" and size.y > 4.0:
				return _podium(size)
			if spec.room == &"greece_parthenon" and size.z > 6.0:
				return _east_pediment(size)
			if maxf(size.x, size.z) > 3.0:
				return _long_plinth(size, spec.room)
			return _plinth(size)
		&"plinth":
			return _plinth(size)
		&"sculpture":
			return _sculpture(spec, index, layout)
		&"column", &"landing":
			if spec.room == &"greece_nereid_podium":
				return _holder("Visual")   # the temple's columns, cella and roof ([method dress])
		&"balcony_post":
			return _ionic(size)
		&"painting":
			if spec.room == &"greece_metopes":
				return _metope(size, index)
			if spec.room == &"greece_bassae_gallery":
				return _holder("Visual")   # the Bassae frieze is the room's band at 5.7 m
		&"case":
			if spec.room == &"greece_vases":
				return _vase_case(spec, index, layout)
		&"shelf":
			if spec.room == &"greece_cast_store":
				return _cast_shelf(size)
			if spec.room == &"greece_pottery":
				return _pottery_shelf(size)
		&"bust_plinth":
			return _bust_plinth(spec, index, layout)
		&"crate":
			if spec.room != &"greece_service_corridor":
				return _crate(size, index)
	return null


static func _holder(label: String) -> Node3D:
	var n := Node3D.new()
	n.name = label
	return n


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


## The podium of the Nereid Monument filling the greybox podium: its front
## (the battle frieze) to the east, the hall.
static func _podium(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var k := Vector3(size.z / 7.2, size.y / 4.4, size.x / 4.0)
	ArtKit._add(root, "nereid_podium", Transform3D(Basis(Vector3.UP, -PI * 0.5) * Basis.from_scale(k), Vector3.ZERO))
	return root


## A Greek plinth (grey body, white mouldings) filling [param size].
static func _plinth(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	ArtKit._add(root, "gr_plinth_block", Transform3D(Basis.from_scale(size / Vector3(1.0, 1.1, 1.0)), Vector3.ZERO))
	return root


## A long low plinth of the pediment groups filling [param size]: a block
## of marble (world-mapped: it stretches to any length), a thin cap, the grey
## base moulding of the walls round its foot.
static func _long_plinth(size: Vector3, room: StringName) -> Node3D:
	var root := _holder("Visual")
	var cap := 0.08
	_box(root, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), Vector3(size.x, size.y - cap, size.z)), room, &"reveal")
	_box(root, AABB(Vector3(-size.x * 0.5 - 0.05, size.y - cap, -size.z * 0.5 - 0.05), Vector3(size.x + 0.1, cap, size.z + 0.1)), room, &"reveal")
	var h := Vector3(size.x * 0.5, 0.0, size.z * 0.5)
	var corners := [Vector3(-h.x, 0.0, -h.z), Vector3(h.x, 0.0, -h.z), Vector3(h.x, 0.0, h.z), Vector3(-h.x, 0.0, h.z)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var out := ((a + b) * 0.5).normalized()
		var face := _holder("Base")
		face.transform = ArtKit.face_transform(a, b, out)
		root.add_child(face)
		ArtKit.run(face, "gr_base_", 0.0, a.distance_to(b), 0.0)
	return root


## A column of the Ionic order under a balcony (round: the narrower side
## of the box sets its girth).
static func _ionic(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var k := minf(size.x / 1.1, size.z / 1.0)
	ArtKit._add(root, "gr_column_ionic", Transform3D(Basis.from_scale(Vector3(k, size.y / 7.0, k)), Vector3.ZERO))
	return root


## The east pediment on its long plinth (2.5 x 1.2 x 12, along z) and the
## figures in a row facing the gallery (west) - Dionysos reclining, Demeter
## and Kore, the three goddesses - over the greybox's three fins (the
## Centaur's stun walls, kept as they are).
static func _east_pediment(size: Vector3) -> Node3D:
	var root := _long_plinth(size, &"greece_parthenon")
	# facing west: the model's -Z to -X, its width along -Z (north first)
	var west := Basis(Vector3.UP, PI * 0.5)
	for figure: Array in [["gr_ped_reclining", 1.25, -4.4], ["gr_ped_seated", 1.25, -0.6], ["gr_ped_goddesses", 1.2, 3.6]]:
		var k: float = figure[1]
		ArtKit._add(root, String(figure[0]), Transform3D(west.scaled(Vector3.ONE * k), Vector3(-0.15, size.y, float(figure[2]))))
	return root


## A free-standing sculpture of the wing by room: the Nereids between the
## temple's columns, the pediment groups and statues of the Parthenon
## gallery, Apollo's colossal torso at Bassae, the Lapith-and-centaur
## metopes on steles, a plaster head in the cast store.
static func _sculpture(spec: PieceSpec, index: int, layout: LevelLayout) -> Variant:
	var size := spec.size
	match spec.room:
		&"greece_nereid_podium":
			# between the columns, running east over the waves
			var ids := ["nereid_a", "nereid_b", "nereid_c"]
			var nereid := _holder("Visual")
			var id: String = ids[int(round((spec.position.z - 9.3) / 2.7)) % ids.size()]
			ArtKit._add(nereid, id, Transform3D(Basis(Vector3.UP, -PI * 0.5 - spec.yaw).scaled(Vector3.ONE * NEREID_SCALE), Vector3.ZERO))
			return nereid
		&"greece_parthenon":
			if maxf(size.x, size.z) > 2.0:
				# the east pediment's figures stand on its long plinth (the
				# pedestal's look) over these boxes
				return _west_group(spec) if spec.position.x < -44.0 else _holder("Visual")
			return _gallery_statue(spec)
		&"greece_bassae":
			var apollo := _holder("Visual")
			var k := minf(size.y / 2.22, 1.6)
			ArtKit._add(apollo, "gr_ped_torso", Transform3D(Basis(Vector3.UP, _yaw_to(spec, Vector2(-86.5, 8.0))).scaled(Vector3.ONE * k), Vector3.ZERO))
			return apollo
		&"greece_metopes":
			return _metope_stele(size, index)
		&"greece_cast_store":
			var head := _holder("Visual")
			ArtKit._add(head, "cast_head", Transform3D(Basis(Vector3.UP, _yaw_to(spec, Vector2(-82.0, 44.0))), Vector3.ZERO))
			return head
	return null


## Yaw (in [param spec]'s frame) that turns a model's front (-Z) to the
## world point [param target] (x, z).
static func _yaw_to(spec: PieceSpec, target: Vector2) -> float:
	var d := target - Vector2(spec.position.x, spec.position.z)
	return atan2(-d.x, -d.y) - spec.yaw


## A pediment group at the west end, on its box (1 m deep, 3 m wide, facing
## west into the mouth, across a 1.6 m plinth): a marble block under the
## whole box down to the floor (the box stands proud of the plinth either
## side; nobody walks under it) and the figures on it - the river god
## Ilissos on the north, the torso of Poseidon and Selene's horse on the
## south.
static func _west_group(spec: PieceSpec) -> Node3D:
	var root := _holder("Visual")
	var size := spec.size
	var base := 0.25
	_box(root, AABB(Vector3(-size.x * 0.5, -spec.position.y, -size.z * 0.5), Vector3(size.x, spec.position.y + base, size.z)), spec.room, &"reveal")
	if spec.position.z < 43.0:
		ArtKit._add(root, "gr_ped_reclining", Transform3D(Basis.from_scale(Vector3.ONE * 1.1), Vector3(0.0, base, -0.02)))
	else:
		ArtKit._add(root, "gr_ped_torso", Transform3D(Basis.from_scale(Vector3.ONE * 0.95), Vector3(0.75, base, 0.0)))
		ArtKit._add(root, "gr_ped_horse", Transform3D(Basis.from_scale(Vector3.ONE * 1.15), Vector3(-0.65, base, 0.05)))
	return root


## A statue on a low plinth along the gallery's sides, turned to the axis:
## the colossal torso at both ends, the Nereids between (by place: west to
## east, the north side first).
static func _gallery_statue(spec: PieceSpec) -> Node3D:
	var root := _holder("Visual")
	var ids := ["gr_ped_torso", "nereid_b", "nereid_d", "nereid_c", "nereid_a", "gr_ped_torso"]
	var place := clampi(int(round((spec.position.x + 54.0) / 9.5)), 0, 2) + (3 if spec.position.z > 43.0 else 0)
	var id: String = ids[place]
	var yaw := _yaw_to(spec, Vector2(spec.position.x, 43.0))
	var k := spec.size.y / 2.22 if id == "gr_ped_torso" else spec.size.y / 2.02
	ArtKit._add(root, id, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * k), Vector3.ZERO))
	return root


## A metope in the wall (the greybox's painting: its back on the wall),
## the four Lapith-and-centaur slabs in turn.
static func _metope(size: Vector3, index: int) -> Node3D:
	var root := _holder("Visual")
	var id := "gr_metope_%s" % ["a", "b", "c", "d"][posmod(index, 4)]
	var k := size.x / 1.29
	ArtKit._add(root, id, Transform3D(Basis.from_scale(Vector3(k, size.y / 1.32, k)), Vector3(0.0, 0.0, size.z * 0.5)))
	return root


## A group on its pedestal in the Metope room: two metopes back to back on
## a stele (a marble foot and cap), as the museum shows the slabs it has no
## wall for.
static func _metope_stele(size: Vector3, index: int) -> Node3D:
	var root := _holder("Visual")
	var foot := 0.12
	var k := size.x / 1.29 * 0.97
	_box(root, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), Vector3(size.x, foot, size.z)), &"greece_metopes", &"reveal")
	var letters := ["a", "b", "c", "d"]
	for side in [0, 1]:
		var id := "gr_metope_%s" % letters[posmod(index * 2 + side, 4)]
		ArtKit._add(root, id, Transform3D(Basis(Vector3.UP, PI * side).scaled(Vector3.ONE * k), Vector3(0.0, foot, 0.0)))
	var top := foot + 1.32 * k
	_box(root, AABB(Vector3(-size.x * 0.5, top, -size.z * 0.5), Vector3(size.x, 0.1, size.z)), &"greece_metopes", &"reveal")
	return root


## A tall case of one vase on a low marble foot filling the greybox case
## (1.2 x 2 x 1.2); a case where the night may leave loot stays empty.
static func _vase_case(spec: PieceSpec, index: int, layout: LevelLayout) -> Node3D:
	var root := _holder("Visual")
	var size := spec.size
	var foot := 0.1
	_box(root, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), Vector3(size.x, foot, size.z)), spec.room, &"reveal")
	var k := (size.y - foot) / 1.95
	var case := ArtKit._add(root, "vase_case_tall", Transform3D(Basis.from_scale(Vector3(1.0, k, 1.0)), Vector3(0.0, foot, 0.0)))
	ArtKit._solid_glass(case)
	if _holds_loot(spec, layout):
		return root
	var place := clampi(int(round((spec.position.x + 101.0) / 5.0)), 0, 2) + (3 if spec.position.z > 26.0 else 0)
	# the vase unscaled on the case's spot (0.96 up the case)
	ArtKit._add(root, CASE_VASES[place], Transform3D(Basis(Vector3.UP, 0.4 * index), Vector3(0.0, foot + 0.96 * k, 0.0)))
	return root


## True when a container loot spot lies in [param spec]'s footprint.
static func _holds_loot(spec: PieceSpec, layout: LevelLayout) -> bool:
	if layout == null:
		return false
	var area := spec.footprint().grow(0.05)
	for spot in layout.loot_spots:
		if spot.room == spec.room and spot.container and area.has_point(Vector2(spot.position.x, spot.position.z)):
			return true
	return false


## The cast store's shelves of plaster fragments, filling the greybox
## shelf (its back on the wall).
static func _cast_shelf(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var n := maxi(1, int(round(size.x / 2.0)))
	var w := size.x / n
	for i in n:
		var x := -size.x * 0.5 + (i + 0.5) * w
		ArtKit._add(root, "cast_shelf", Transform3D(Basis.from_scale(Vector3(w / 2.0, size.y / 2.2, size.z / 0.6)), Vector3(x, 0.0, size.z * 0.5)))
	return root


## The potsherd store's shelf: two wall cases with the pots nobody has room
## for upstairs (cups, oil flasks, water jars), their backs on the wall.
static func _pottery_shelf(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var w := size.x * 0.5
	var k := Vector3(w / 2.04, size.y / 2.3, size.z / 0.64)
	var rows := [["vase_hydria", "vase_lekythos", "vase_hydria"], ["vase_lekythos", "vase_kylix", "vase_lekythos"], ["vase_kylix", "vase_kylix"]]
	for side in [-1.0, 1.0]:
		var at := Vector3(side * w * 0.5, 0.0, size.z * 0.5 - 0.02 * k.z)
		var case := ArtKit._add(root, "vase_case_wall_2m", Transform3D(Basis.from_scale(k), at))
		ArtKit._solid_glass(case)
		for shelf in 3:
			var row: Array = rows[shelf]
			var y: float = [0.91, 1.45, 1.95][shelf] * k.y
			for i in row.size():
				var x := at.x + (i - (row.size() - 1) * 0.5) * w * 0.3
				ArtKit._add(root, String(row[i]), Transform3D(Basis(Vector3.UP, 0.7 * i + side).scaled(Vector3.ONE * 0.85), Vector3(x, y, at.z - 0.3 * k.z)))
	return root


## A portrait bust on a Greek plinth, turned to the middle of its room.
static func _bust_plinth(spec: PieceSpec, index: int, layout: LevelLayout) -> Node3D:
	var root := _holder("Visual")
	var size := spec.size
	var shaft := size.y - 0.6
	ArtKit._add(root, "gr_plinth_block", Transform3D(Basis.from_scale(Vector3(size.x, shaft / 1.1, size.z)), Vector3.ZERO))
	# (the bust's face is its +Z: turned half round, as ArtKit does)
	var yaw := 0.0
	var room := layout.room(spec.room) if layout != null else null
	if room != null and not room.parts.is_empty():
		yaw = _yaw_to(spec, room.parts[0].get_center())
	ArtKit._add(root, "bust", Transform3D(Basis(Vector3.UP, yaw + PI), Vector3(0.0, shaft, 0.0)), "bust_bronze" if posmod(index, 3) == 1 else "")
	return root


## Crates of the stores: an open one with plaster in the shavings, or a
## plain one, filling the box.
static func _crate(size: Vector3, index: int) -> Node3D:
	var root := _holder("Visual")
	if posmod(index, 2) == 0:
		ArtKit._add(root, "cast_crate", Transform3D(Basis.from_scale(size / Vector3(1.2, 1.35, 0.96)), Vector3(0.0, 0.0, 0.03 * size.z)))
	else:
		ArtKit._add(root, "crate", Transform3D(Basis.from_scale(size / Vector3(1.07, 1.02, 1.04)), Vector3.ZERO))
	return root


## No fittings of its own: the lobby's lamps light the marble.
static func fixture(_kit: StringName, _room: StringName) -> Variant:
	return null


## No gates in disguise.
static func gate_leaf(_opening_id: StringName, _size: Vector3, _side: float) -> Variant:
	return null


## The wing's own portals (Floor1Art.PORTALS' form): none.
static func portals() -> Dictionary:
	return {}


## Gates of the wing that wear leaves of their own: none.
static func disguised_gates() -> Array[StringName]:
	return []


# --- hero pieces ------------------------------------------------------------------

## The wing's hero pieces for the dressed rooms ([param rooms] empty: all)
## under [param parent] (world space).
static func dress(layout: LevelLayout, parent: Node3D, rooms: Dictionary = {}) -> void:
	if layout.room(&"greece_nereid") == null:
		return
	if Floor1Art.wants(rooms, &"greece_nereid"):
		_temple(Floor1Art.group(parent, "NereidTemple", &"greece_nereid"))
	var wells := Floor1Art.group(parent, "GreekSkylights", &"greece_parthenon")
	for room in layout.rooms:
		if room.zone == Greece.ZONE and Floor1Art.wants(rooms, room.id):
			for well in room.skylights:
				skylight(wells, well, room.ceiling_y)
	if Floor1Art.wants(rooms, &"greece_parthenon"):
		_mouth(layout, Floor1Art.group(parent, "ParthenonMouth", &"greece_parthenon"))


## The temple of the Nereid Monument on its podium: the model fitted to the
## greybox's cella and porch, its four front columns moved onto the
## greybox's columns (kept round), the corner columns (they would stand on
## the porch's free floor) left out.
static func _temple(root: Node3D) -> void:
	var basis := Basis(Vector3.UP, -PI * 0.5) * Basis.from_scale(TEMPLE_SCALE)
	var temple := ArtKit._add(root, "nereid_temple", Transform3D(basis, TEMPLE_ORIGIN))
	var parts := ArtLibrary.parts(temple)
	# the greybox's columns: z 8, 10.65, 13.35, 16 on x PORCH_X; the model's
	# x runs along world +z, its +z toward world -x
	var porch_z := -(PORCH_X - TEMPLE_ORIGIN.x) / TEMPLE_SCALE.z
	var columns := {"nereid_column_1": 16.0, "nereid_column_2": 13.35, "nereid_column_3": 10.65, "nereid_column_4": 8.0}
	for id: String in columns:
		var column := parts.get(id) as Node3D
		if column == null:
			continue
		var x := (float(columns[id]) - TEMPLE_ORIGIN.z) / TEMPLE_SCALE.x
		column.transform = Transform3D(Basis.from_scale(Vector3(1.0, 1.0, TEMPLE_SCALE.x / TEMPLE_SCALE.z)), Vector3(x, column.position.y, porch_z))
	for id in ["nereid_column_5", "nereid_column_6"]:
		var corner := parts.get(id) as Node3D
		if corner != null:
			corner.visible = false
	temple.set_meta(&"nereid_temple", true)


## The iron laylight of a skylight well [param well] (world x, z) in a
## ceiling at [param ceiling_y]: one gr_skylight_4m per cell of about 4 m,
## a hair inside the well's walls, its depth the well's.
static func skylight(parent: Node3D, well: Rect2, ceiling_y: float) -> void:
	var nx := maxi(1, int(round(well.size.x / SKYLIGHT_CELL)))
	var nz := maxi(1, int(round(well.size.y / SKYLIGHT_CELL)))
	var cell := Vector2(well.size.x / nx, well.size.y / nz)
	var k := Vector3(cell.x / 4.0 * 0.99, LevelLayout.SKYLIGHT_WELL / 2.0, cell.y / 4.0 * 0.99)
	for i in nx:
		for j in nz:
			var at := Vector3(well.position.x + (i + 0.5) * cell.x, ceiling_y, well.position.y + (j + 0.5) * cell.y)
			var frame := ArtKit._add(parent, "gr_skylight_4m", Transform3D(Basis.from_scale(k), at))
			for view in frame.find_children("*_glass", "MeshInstance3D", true, false):
				(view as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A Doric entablature over the arena's mouth on the gallery's face: the
## lintel the Metope room's frieze runs into (8 - 9.6 m over the floor).
static func _mouth(layout: LevelLayout, root: Node3D) -> void:
	var mouth := layout.opening(&"greece_metopes_parthenon")
	if mouth == null:
		return
	var a := Vector3(mouth.rect.end.x, 0.0, mouth.rect.position.y)
	var b := Vector3(mouth.rect.end.x, 0.0, mouth.rect.end.y)
	var holder := Node3D.new()
	holder.name = "MouthEntablature"
	holder.transform = ArtKit.face_transform(a, b, Vector3.RIGHT)
	holder.position.y = MOUTH_ENTABLATURE
	root.add_child(holder)
	ArtKit.run(holder, "gr_cornice_doric_", 0.0, a.distance_to(b), 0.0)


# --- light recipe extras -------------------------------------------------------------

## The sky in the skylights (cold, no haze, moonlight's group: no fuse).
const SKY := Color(0.58, 0.68, 1.0)
## Warm accents on the sculpture (the catalogue's recipe) and a pale wash
## on the friezes, whose relief lives on light grazing it.
const WARM_ACCENT := Color(1.0, 0.76, 0.5)
const FRIEZE_WASH := Color(1.0, 0.93, 0.84)


## The lamps the Greek wing's art asks for (Floor1LightRecipe extras), by
## the rooms of [param layout]: a soft sky down every light well; washes
## grazing the Parthenon frieze from under the cornice and the Bassae
## frieze from under the ceiling; warm accents on the Nereid temple's
## pediment and on the metopes. None casts a shadow or lights the floor
## much (the exhibits' light model reads the layout's lamps).
static func extra_lights(layout: LevelLayout) -> Array:
	var out: Array = []
	for room in layout.rooms:
		if room.zone != Greece.ZONE:
			continue
		for well in room.skylights:
			var c := well.get_center()
			var reach := room.ceiling_y - room.floor_y + LevelLayout.SKYLIGHT_WELL + 1.0
			var spread := rad_to_deg(atan2(maxf(well.size.x, well.size.y) * 0.5 + 2.0, reach - 1.0))
			out.append({"room": room.id, "group": LightSpec.MOON, "position": Vector3(c.x, room.ceiling_y + LevelLayout.SKYLIGHT_WELL - 0.2, c.y),
				"direction": Vector3.DOWN, "color": SKY, "energy": 0.35 * sqrt(well.get_area() / 16.0), "range": reach,
				"angle": clampf(spread, 25.0, 60.0), "rule": &"cold_fill"})
	if layout.room(&"greece_parthenon") != null:
		for x in [-57.0, -44.0, -31.0]:
			for wall: Vector2 in [Vector2(34.0, 1.0), Vector2(52.0, -1.0)]:
				_aim(out, &"greece_parthenon", Vector3(x, 10.4, wall.x + wall.y * 1.6), Vector3(x, 2.0, wall.x), FRIEZE_WASH, 0.9, 11.0, 55.0)
	if layout.room(&"greece_nereid") != null:
		_aim(out, &"greece_nereid", Vector3(-68.0, 12.6, 12.0), Vector3(-80.2, 11.4, 12.0), WARM_ACCENT, 1.4, 18.0, 18.0)
	if layout.room(&"greece_metopes") != null:
		for pair: Array in [[Vector3(-82.75, 3.8, 26.04), 1.0, 26.0], [Vector3(-67.75, 3.8, 26.04), 1.0, 26.0],
				[Vector3(-82.75, 3.8, 39.46), -1.0, 26.0], [Vector3(-72.25, 3.8, 50.96), -1.0, 40.0]]:
			var target: Vector3 = pair[0]
			_aim(out, &"greece_metopes", Vector3(target.x, 7.2, target.z + float(pair[1]) * 4.5), target, WARM_ACCENT, 1.1, 9.0, float(pair[2]))
	if layout.room(&"greece_bassae") != null:
		for wash: Array in [[Vector3(-102.0, 9.3, 1.0), Vector3(-102.0, 6.1, -2.0)], [Vector3(-96.0, 9.3, 1.0), Vector3(-96.0, 6.1, -2.0)],
				[Vector3(-90.0, 9.3, 1.0), Vector3(-90.0, 6.1, -2.0)], [Vector3(-103.0, 9.3, 8.0), Vector3(-106.0, 6.1, 8.0)],
				[Vector3(-89.5, 9.3, 8.0), Vector3(-86.5, 6.1, 8.0)], [Vector3(-96.0, 9.3, 13.0), Vector3(-96.0, 6.1, 16.0)]]:
			_aim(out, &"greece_bassae", wash[0], wash[1], FRIEZE_WASH, 0.7, 7.0, 50.0)
	return out


## Appends a spot from [param from] at [param target] (a wash: no shadow,
## little haze).
static func _aim(out: Array, room: StringName, from: Vector3, target: Vector3, color: Color, energy: float, reach: float, angle: float) -> void:
	out.append({"room": room, "position": from, "direction": (target - from).normalized(), "color": color,
		"energy": energy, "range": reach, "angle": angle, "rule": &"wash"})
