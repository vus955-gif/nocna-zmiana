class_name Floor1ArtEnlightenment
extends RefCounted
## Floor I's Enlightenment wing dressed, stage P3 (plan docs/superpowers/
## plans/2026-10-03-p3-oprawa-grecja-oswiecenie.md section 4; catalogue
## docs/art/kit-pietro1-oswiecenie.md): dark oak and mahogany, brass, green
## lampshades, thousands of book spines. Pure factories of Node3D trees of
## ArtLibrary models, no collision (the greybox keeps it); Floor1Art asks
## this module for every room whose id starts with "enlightenment_":
## - [method piece_look]: the library's cases, globes, granite columns and
##   railings, the cabinets' specimen cases, the rifle's rack, dioramas,
##   clocks, the librarian's desk, the observers' telescope... (the
##   library's greybox shelves give way to the bookcase runs);
## - [method dress]: the hero pieces - the King's Library's bookcases in
##   two tiers (every run from pilaster to pilaster, the bays of
##   Enlightenment.bays(): the gallery's sconces hang on the same
##   pilasters), their brass ladder rails, the gallery's iron consoles,
##   busts on brackets, the light wells, the clock walls, signs;
## - [method fixture]: green-shaded wall lamps, banker's lamps, pendants,
##   standard lamps; [method library_stairs]: the oak flights.

const Enlightenment := preload("res://src/level/floor1/zones/enlightenment.gd")

## Every model this module places (the art tests check each is registered,
## on disk and placed).
const MODELS: Array[String] = [
	"lib_bookcase_a_2m", "lib_bookcase_b_2m", "lib_bookcase_c_2m", "lib_bookcase_1m", "lib_bookcase_up_a_2m",
	"lib_bookcase_up_b_2m", "lib_bookcase_up_1m", "lib_bookcase_pilaster_low", "lib_bookcase_pilaster_up",
	"lib_ladder_rail_2m", "lib_ladder", "lib_walkway_bracket", "lib_walkway_fascia_4m", "lib_walkway_fascia_end",
	"lib_railing_2m", "lib_railing_1m", "lib_railing_post", "lib_bust_bracket", "lib_skylight_well_4m",
	"lib_cornice_4m", "lib_coffer_2m", "lib_sign", "lib_case_shells", "lib_case_minerals", "lib_case_coins",
	"lib_case_instruments", "lib_globe_terrestrial", "lib_globe_celestial", "lib_lamp_wall", "lib_lamp_reading",
	"lib_lamp_pendant", "lib_lamp_standard", "lib_stair_step_1m", "lib_stair_stringer_4m", "lib_stair_railing_4m",
	"lib_stair_newel", "lib_nh_shelf_a", "lib_nh_shelf_b", "lib_antlers", "lib_diorama_base", "lib_rifle_rack",
	"lib_clock_longcase", "lib_clock_wall", "lib_automaton_writer", "lib_bird_cage", "lib_office_desk",
	"lib_office_chair", "lib_card_catalogue", "lib_filing_cabinet", "lib_doorframe_2x2_8", "lib_portal_4x4_5",
	"gr_column_ionic", "gr_plinth_block", "timber_beam_4m", "frame_1_2x0_9", "frame_0_6x0_8", "frame_3x2",
]
## The library's long walls (x) and short walls (z) and the extent of the
## short walls' runs (between the long walls' bookcases).
const WEST := 31.0
const EAST := 45.0
const NORTH := -36.0
const SOUTH := 34.0
const SHORT_RUN := Vector2(34.0, 42.0)
## The lower tier stands under the gallery's slab (its underside 3.6 m).
const SLAB_UNDER := Enlightenment.UPPER - Enlightenment.SLAB
## Busts on brackets over the upper bookcases (the bracket's top), every
## BUST_EVERY-th pilaster of the long walls.
const BUST_Y := 7.92
const BUST_EVERY := 4
## Polished red granite of the library's columns (a tint over the marble).
const GRANITE := Color(0.62, 0.42, 0.38)
const BRASS := Color(0.78, 0.6, 0.32)
const OAK := Color(0.28, 0.18, 0.1)
## The lower tier's warm wall lamps (light recipe extras): on the pilasters
## nearest these z, 2.6 m up, a metre out from the wall.
const LOW_SCONCES_Z: Array[float] = [-30.0, -17.0, 8.0, 26.0]
const LOW_SCONCE_Y := 2.6

static var _tinted: Dictionary = {}
static var _brass: StandardMaterial3D = null
static var _oak: StandardMaterial3D = null


# --- pieces --------------------------------------------------------------------

## The look of [param spec] (a piece of an Enlightenment room) in its own
## frame, or null (the common rules).
static func piece_look(spec: PieceSpec, index: int, layout: LevelLayout) -> Variant:
	var size := spec.size
	match spec.kit:
		&"shelf":
			match spec.room:
				&"enlightenment_library", &"enlightenment_library_gallery":
					if _is_tool_case(spec):
						return _tool_bookcase(size, spec.position.y > Enlightenment.UPPER * 0.5)
					return _holder("Visual")   # the bookcase runs ([method dress])
				&"enlightenment_cabinet":
					if _by_rifle(spec, layout):
						return _rifle_rack(size)
					return _specimen_cases(size, index)
				&"enlightenment_librarian":
					return _card_catalogues(size)
				&"enlightenment_study":
					return _bookcase_piece(size)
		&"balcony_post":
			if spec.room == &"enlightenment_library":
				return _granite_column(size)
		&"case":
			if spec.room == &"enlightenment_library":
				return _glass_case(spec, size)
		&"plinth":
			if spec.room == &"enlightenment_library":
				return _globe(spec, spec.position.z > 0.0, 0.0)
		&"globe":
			return _holder("Visual")   # the globe stands on the floor in the plinth's place
		&"railing":
			return _railing(size)
		&"pedestal":
			match spec.room:
				&"enlightenment_cabinet":
					return _diorama(size)
				&"enlightenment_planetarium":
					return _plinth(size)
				&"enlightenment_clocks":
					var stand := _holder("Visual")
					_box(stand, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size), spec.room, &"reveal")
					return stand
		&"sculpture":
			match spec.room:
				&"enlightenment_cabinet":
					return _specimen(spec, index)
				&"enlightenment_planetarium":
					# instruments in the corners: a globe on each pedestal, its
					# front to the orrery
					var toward := _yaw_to(spec, Vector2(Enlightenment.ORRERY.x, Enlightenment.ORRERY.z))
					return _globe(spec, spec.position.x > Enlightenment.ORRERY.x, toward)
		&"painting":
			match spec.room:
				&"enlightenment_cabinet":
					var antlers := _holder("Visual")
					ArtKit._add(antlers, "lib_antlers", Transform3D(Basis.IDENTITY, Vector3(0.0, size.y * 0.5, size.z * 0.5)))
					return antlers
				&"enlightenment_clocks", &"enlightenment_portraits":
					# the clock walls ([method dress]); the portraits are the
					# game's (WallPainting / Portrait on the markers)
					return _holder("Visual")
		&"clock":
			return _clock(spec, size)
		&"desk":
			match spec.room:
				&"enlightenment_librarian", &"enlightenment_study":
					return _office_desk(size)
				&"enlightenment_clocks":
					return _automata_table(size)
		&"chair":
			if spec.room == &"enlightenment_librarian":
				var chair := _holder("Visual")
				ArtKit._add(chair, "lib_office_chair", Transform3D.IDENTITY)
				return chair
		&"floor":
			if spec.room == &"enlightenment_planetarium":
				return _ecliptic(size)
		&"telescope":
			return _telescope(size)
		&"beam":
			var beam := _holder("Visual")
			# the timber runs along its x: turned along the piece's z, hung
			# from the box's top
			ArtKit._add(beam, "timber_beam_4m", Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis.from_scale(Vector3(size.z / 4.0, size.y / 0.42, size.x / 0.34)), Vector3(0.0, size.y, 0.0)))
			return beam
	return null


static func _holder(label: String) -> Node3D:
	var n := Node3D.new()
	n.name = label
	return n


static func _box(parent: Node3D, box: AABB, room: StringName, role: StringName) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box.size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = ArtKit.field(room, role)
	view.position = box.get_center()
	parent.add_child(view)
	return view


## Yaw (in [param spec]'s frame) that turns a model's front (-Z) to the
## world point [param target] (x, z).
static func _yaw_to(spec: PieceSpec, target: Vector2) -> float:
	var d := target - Vector2(spec.position.x, spec.position.z)
	return atan2(-d.x, -d.y) - spec.yaw


## True for the cabinet's shelf the collector's rifle lies before.
static func _by_rifle(spec: PieceSpec, layout: LevelLayout) -> bool:
	var rifle := Enlightenment.RIFLE
	if layout != null and layout.markers.has(&"weapon_rifle_hunt"):
		rifle = (layout.markers[&"weapon_rifle_hunt"] as Transform3D).origin
	return Vector2(spec.position.x - rifle.x, spec.position.z - rifle.z).length() < 1.5


## The collector's gun cupboard, its back on the wall behind the table
## where the rifle lies (its brass cradles empty: the gun is out on the
## table, in the warm spot).
static func _rifle_rack(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var box := Floor1Art.bounds("lib_rifle_rack")
	ArtKit._add(root, "lib_rifle_rack", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, size.z * 0.5 - box.end.z)))
	return root


## Natural history cabinets along a wall: glazed cases of fossils, skulls
## and jars, filling the greybox's run (their backs on the wall).
static func _specimen_cases(size: Vector3, index: int) -> Node3D:
	var root := _holder("Visual")
	var n := maxi(1, int(round(size.x / 2.06)))
	var w := size.x / n
	var box := Floor1Art.bounds("lib_nh_shelf_a")
	for i in n:
		var id := "lib_nh_shelf_a" if posmod(index + i, 2) == 0 else "lib_nh_shelf_b"
		var x := -size.x * 0.5 + (i + 0.5) * w
		var case := ArtKit._add(root, id, Transform3D(Basis.from_scale(Vector3(w / 2.06, 1.0, 1.0)), Vector3(x, 0.0, size.z * 0.5 - box.end.z)))
		ArtKit._solid_glass(case)
	return root


## The librarian's catalogue: two card catalogues and a filing cabinet
## along the wall, filling the greybox shelf.
static func _card_catalogues(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var ids := ["lib_card_catalogue", "lib_filing_cabinet", "lib_card_catalogue"]
	var widths := [1.24, 0.52, 1.24]
	var total := 3.0
	var k := size.x / total
	var x := -size.x * 0.5
	for i in ids.size():
		var w: float = widths[i] * k
		var box := Floor1Art.bounds(String(ids[i]))
		ArtKit._add(root, String(ids[i]), Transform3D(Basis.from_scale(Vector3(k, 1.0, 1.0)), Vector3(x + w * 0.5, 0.0, size.z * 0.5 - box.end.z)))
		x += w
	return root


## A run of upper-tier bookcases filling a greybox shelf from end to end
## (Sloane's study): pilaster, cases, pilaster.
static func _bookcase_piece(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var bays := Enlightenment.bays(-size.x * 0.5, size.x * 0.5)
	var frame := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, size.z * 0.5))
	_run(root, frame, bays, true, 3)
	return root


## True for the library's greybox shelf an env tool takes over (EnvCatalog:
## a topple of a "shelf" piece; the tool finds it within a metre of its
## "near", EnvToppleTool._piece_near).
static func _is_tool_case(spec: PieceSpec) -> bool:
	for entry in EnvCatalog.tools():
		if entry.get("kit", &"") == spec.kit and entry.get("room", &"") == spec.room and entry.has("near"):
			if spec.position.distance_to(entry["near"]) < 1.0:
				return true
	return false


## The ranges along the library's long wall at [param wall_x] (WEST or
## EAST) the env tools' bookcases take in [param upper]'s tier (the greybox
## pieces they topple): each draws its own cases ([method _tool_bookcase]).
static func tool_cases(wall_x: float, upper: bool) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var doors: Array = _doorways(wall_x, upper)
	for entry in EnvCatalog.tools():
		if entry.get("kit", &"") != &"shelf" or not entry.has("near"):
			continue
		if not [&"enlightenment_library", &"enlightenment_library_gallery"].has(entry.get("room", &"")):
			continue
		var near: Vector3 = entry["near"]
		if absf(near.x - wall_x) > 1.0 or (near.y > Enlightenment.UPPER * 0.5) != upper:
			continue
		var span := Enlightenment.shelf_piece(doors, near.z)
		if span != Vector2.ZERO:
			out.append(span)
	return out


## What the runs of the long wall at [param wall_x] keep clear of in
## [param upper]'s tier: its doorways and the env tools' bookcases.
static func run_clear(wall_x: float, upper: bool) -> Array:
	var out: Array = _doorways(wall_x, upper).duplicate()
	out.append_array(tool_cases(wall_x, upper))
	return out


static func _doorways(wall_x: float, upper: bool) -> Array:
	if absf(wall_x - WEST) < 1.0:
		return Enlightenment.UP_CLEAR_WEST if upper else Enlightenment.LOW_CLEAR_WEST
	return Enlightenment.UP_CLEAR_EAST if upper else Enlightenment.LOW_CLEAR_EAST


## The look of a wall bookcase an env tool brings down: the run's cases
## between the run's own end pilasters (the run is cut there,
## [method run_clear]) and the pilasters between them, without the
## gallery's iron consoles (they stay with the wall), and an oak back (the
## run's cases are open behind: face down, its back is what shows). The
## front of the piece is its -Z, its back on the wall.
static func _tool_bookcase(size: Vector3, upper: bool) -> Node3D:
	var root := _holder("Visual")
	var half := size.x * 0.5 + Enlightenment.PILASTER
	var bays := Enlightenment.bays(-half, half)
	var pilasters: Array = bays["pilasters"]
	bays["pilasters"] = pilasters.slice(1, pilasters.size() - 1)
	var frame := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, size.z * 0.5))
	_run(root, frame, bays, upper, 0, 1.0, false, false)
	var back := MeshInstance3D.new()
	back.name = "Back"
	var board := BoxMesh.new()
	board.size = Vector3(size.x, 3.3 if upper else SLAB_UNDER, 0.03)
	back.mesh = board
	back.material_override = _oak_material()
	back.position = Vector3(0.0, board.size.y * 0.5, size.z * 0.5 - 0.03)
	root.add_child(back)
	return root


## A column of polished red granite under the gallery's edge (the Ionic
## order, tinted).
static func _granite_column(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var k := minf(size.x / 1.1, size.z / 1.0)
	var column := ArtKit._add(root, "gr_column_ionic", Transform3D(Basis.from_scale(Vector3(k, size.y / 7.0, k)), Vector3.ZERO))
	_tint(column, GRANITE)
	return root


## [param node]'s meshes in tinted copies of their materials (shared per
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
				copy.roughness = 0.25
				_tinted[key] = copy
			view.set_surface_override_material(i, _tinted[key])


## A glass-topped case on the library's axis (its length along the axis),
## shells, minerals, coins and instruments in turn.
static func _glass_case(spec: PieceSpec, size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var ids := ["lib_case_shells", "lib_case_minerals", "lib_case_coins", "lib_case_instruments"]
	var order := Enlightenment.CASES_Z.find(spec.position.z)
	var id: String = ids[posmod(order if order >= 0 else 0, ids.size())]
	var box := Floor1Art.bounds(id)
	var k := minf(size.z / box.size.x, size.x / box.size.z) * 0.98
	var case := ArtKit._add(root, id, Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis.from_scale(Vector3(k, size.y / box.size.y, k)), Vector3.ZERO))
	ArtKit._solid_glass(case)
	return root


## A floor globe (terrestrial or [param celestial]) on its tripod, turned
## by [param yaw]; the globe turns on its tilted axis very slowly.
static func _globe(spec: PieceSpec, celestial: bool, yaw: float) -> Node3D:
	var root := _holder("Visual")
	var id := "lib_globe_celestial" if celestial else "lib_globe_terrestrial"
	var globe := ArtKit._add(root, id, Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO))
	var spinner := DecorSpinner.new()
	spinner.name = "GlobeTurns"
	spinner.add(ArtLibrary.parts(globe).get("globe") as Node3D, Vector3(0.397, 0.918, 0.0), 0.04 if celestial else -0.03)
	Floor1Art.decor(root, spinner, spec.room)
	return root


## A plinth of marble (the Greek kit's) filling [param size].
static func _plinth(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	ArtKit._add(root, "gr_plinth_block", Transform3D(Basis.from_scale(size / Vector3(1.0, 1.1, 1.0)), Vector3.ZERO))
	return root


## A Regency railing along the piece's x (symmetric): mahogany rail on cast
## iron, a post with a brass ball at both ends and every 4 m.
static func _railing(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var length := size.x
	var n := maxi(1, int(round(length / 4.0)))
	var bay := length / n
	for k in n + 1:
		var x := -length * 0.5 + k * bay
		ArtKit._add(root, "lib_railing_post", Transform3D(Basis.IDENTITY, Vector3(x, 0.0, 0.0)))
		if k == n:
			break
		var holder := _holder("Bay")
		holder.position = Vector3(x + 0.1, 0.0, 0.0)
		root.add_child(holder)
		ArtKit.run(holder, "lib_railing_", 0.0, bay - 0.2, 0.0)
	return root


## The diorama's low stand filling the greybox pedestal: its ground at the
## pedestal's top (where the wolves and raptors stand).
static func _diorama(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	ArtKit._add(root, "lib_diorama_base", Transform3D(Basis.from_scale(Vector3(size.x / 3.2, size.y / 0.33, size.z / 1.84)), Vector3.ZERO))
	return root


## A stuffed wolf or a fossil raptor of the dioramas (the exhibits' own
## models, asleep): along the greybox box, the raptors turned aside.
static func _specimen(spec: PieceSpec, index: int) -> Node3D:
	var root := _holder("Visual")
	var raptor := spec.size.y > 1.5
	var body := ArtLibrary.exhibit(&"raptor" if raptor else &"wolf")
	if body == null:
		return root
	var turn := (0.6 if posmod(index, 2) == 0 else -0.8) if raptor else (PI * 0.5 if posmod(index, 2) == 0 else -PI * 0.5)
	body.transform = Transform3D(Basis(Vector3.UP, turn), Vector3.ZERO)
	root.add_child(body)
	return root


## A clock by size: a longcase clock against the wall (its pendulum swings,
## its hands go round), or the astronomical clock in the middle of the room -
## four longcase clocks back to back in a tower, a face to every side.
static func _clock(spec: PieceSpec, size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var spinner := DecorSpinner.new()
	spinner.name = "Clockwork"
	if size.y < 3.0:
		var box := Floor1Art.bounds("lib_clock_longcase")
		var clock := ArtKit._add(root, "lib_clock_longcase", Transform3D(Basis.from_scale(Vector3(1.0, size.y / box.size.y, 1.0)), Vector3(0.0, 0.0, size.z * 0.5 - box.end.z)))
		_tick(spinner, clock, spec.position.z * 0.37)
	else:
		var k := minf(size.y / 2.59, 1.4)
		var box2 := Floor1Art.bounds("lib_clock_longcase")
		var out := box2.size.x * k * 0.5 + box2.end.z * k
		for side in 4:
			var basis := Basis(Vector3.UP, PI * 0.5 * side)
			var face := ArtKit._add(root, "lib_clock_longcase", Transform3D(basis.scaled(Vector3.ONE * k), basis * Vector3(0.0, 0.0, -out)))
			_tick(spinner, face, 0.25 * side)
	Floor1Art.decor(root, spinner, spec.room)
	return root


## A longcase clock's motion: the seconds pendulum (two seconds a swing),
## the hands going round (the minute hand once in ten minutes: the night
## runs fast in here).
static func _tick(spinner: DecorSpinner, clock: Node3D, phase: float) -> void:
	var parts := ArtLibrary.parts(clock)
	spinner.swing(parts.get("pendulum") as Node3D, Vector3.BACK, 0.12, 2.0, phase)
	spinner.add(parts.get("hand_minute") as Node3D, Vector3.BACK, TAU / 600.0)
	spinner.add(parts.get("hand_hour") as Node3D, Vector3.BACK, TAU / 7200.0)


## A mahogany partners' desk filling the greybox desk (its top on the box's).
static func _office_desk(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	ArtKit._add(root, "lib_office_desk", Transform3D(Basis.from_scale(Vector3(size.x / 1.7, size.y / 0.76, size.z / 0.79)), Vector3.ZERO))
	return root


## The automata's table in the clocks room: the writer at his little desk
## (head turning, pen hand writing) and the mechanical robin in its cage,
## the middle of the table left free.
static func _automata_table(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	ArtKit._add(root, "desk", Transform3D(Basis.from_scale(size / Vector3(1.6, 0.79, 0.81)), Vector3.ZERO))
	var top := size.y
	var writer := ArtKit._add(root, "lib_automaton_writer", Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * 0.85), Vector3(-size.x * 0.5 + 0.34, top, 0.0)))
	var cage := ArtKit._add(root, "lib_bird_cage", Transform3D(Basis(Vector3.UP, PI * 0.8), Vector3(size.x * 0.5 - 0.25, top, 0.05)))
	var spinner := DecorSpinner.new()
	spinner.name = "Automata"
	var w := ArtLibrary.parts(writer)
	spinner.swing(w.get("head") as Node3D, Vector3.UP, 0.35, 7.0)
	spinner.swing(w.get("arm_r") as Node3D, Vector3.RIGHT, 0.05, 0.9)
	spinner.swing(ArtLibrary.parts(cage).get("bird_head") as Node3D, Vector3.BACK, 0.25, 2.6)
	Floor1Art.decor(root, spinner, &"enlightenment_clocks")
	return root


## The brass ecliptic in the rotunda's floor round the orrery: two rings
## and the twelve marks of the zodiac between them, flush with the marble.
static func _ecliptic(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var outer := minf(size.x, size.z) * 0.5
	var view := MeshInstance3D.new()
	view.name = "Ecliptic"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for ring: Vector2 in [Vector2(outer - 0.12, outer), Vector2(outer - 0.62, outer - 0.54)]:
		_annulus(st, ring.x, ring.y, 96, 0.012)
	for k in 12:
		var a := TAU * k / 12.0
		var dir := Vector3(sin(a), 0.0, -cos(a))
		var side := Vector3(dir.z, 0.0, -dir.x) * 0.03
		var p0 := dir * (outer - 0.54)
		var p1 := dir * (outer - 0.12)
		for tri: Array in [[p0 - side, p1 - side, p1 + side], [p0 - side, p1 + side, p0 + side]]:
			for p: Vector3 in tri:
				st.add_vertex(p + Vector3.UP * 0.012)
	view.mesh = st.commit()
	view.material_override = _inlay()
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(view)
	return root


static func _annulus(st: SurfaceTool, inner: float, outer: float, segments: int, y: float) -> void:
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var i0 := Vector3(sin(a0) * inner, y, -cos(a0) * inner)
		var o0 := Vector3(sin(a0) * outer, y, -cos(a0) * outer)
		var i1 := Vector3(sin(a1) * inner, y, -cos(a1) * inner)
		var o1 := Vector3(sin(a1) * outer, y, -cos(a1) * outer)
		for p: Vector3 in [i0, o0, o1, i0, o1, i1]:
			st.add_vertex(p)


## Polished brass.
static func brass() -> StandardMaterial3D:
	if _brass == null:
		_brass = StandardMaterial3D.new()
		_brass.resource_name = "brass"
		_brass.albedo_color = BRASS
		_brass.metallic = 1.0
		_brass.roughness = 0.32
	return _brass


static var _inlay_brass: StandardMaterial3D = null


## Brass let into a floor (seen from above only, either winding).
static func _inlay() -> StandardMaterial3D:
	if _inlay_brass == null:
		_inlay_brass = brass().duplicate() as StandardMaterial3D
		_inlay_brass.resource_name = "brass_inlay"
		_inlay_brass.cull_mode = BaseMaterial3D.CULL_DISABLED
		_inlay_brass.roughness = 0.4
	return _inlay_brass


static func _oak_material() -> StandardMaterial3D:
	if _oak == null:
		_oak = StandardMaterial3D.new()
		_oak.resource_name = "oak"
		_oak.albedo_color = OAK
		_oak.roughness = 0.55
	return _oak


## The observers' brass telescope on its oak tripod, aimed up at the dome
## over the orrery (the kit has none: a few turned shapes).
static func _telescope(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var head := size.y * 0.78
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		var foot := Vector3(sin(a) * 0.3, 0.0, cos(a) * 0.3)
		var top := Vector3(0.0, head, 0.0)
		_rod(root, foot, top, 0.018, _oak_material())
	# the tube: from behind the head up toward the rotunda's middle (south-east)
	var aim := Vector3(0.45, 0.6, -0.65).normalized()
	_rod(root, Vector3(0.0, head, 0.0) - aim * 0.45, Vector3(0.0, head, 0.0) + aim * 0.85, 0.055, brass())
	_rod(root, Vector3(0.0, head, 0.0) - aim * 0.6, Vector3(0.0, head, 0.0) - aim * 0.45, 0.025, brass())
	return root


## A cylinder of radius [param radius] from [param a] to [param b].
static func _rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 10
	mesh.rings = 1
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	view.transform = Transform3D(Basis(side, up, side.cross(up)), (a + b) * 0.5)
	parent.add_child(view)


# --- fittings, gates, portals -------------------------------------------------------

## The wing's light fittings (origin = the light): green-shaded wall lamps
## (their plate on the wall behind), banker's lamps, pendants on a rod,
## the library's standard lamps; null = the lobby's.
static func fixture(kit: StringName, room: StringName) -> Variant:
	var id := ""
	match kit:
		&"sconce":
			id = "lib_lamp_wall"
		&"desk_lamp":
			id = "lib_lamp_reading"
		&"ceiling_lamp":
			id = "lib_lamp_pendant"
		&"bulb":
			if room == &"enlightenment_library":
				id = "lib_lamp_standard"
	if id == "":
		return null
	var root := _holder("Visual")
	ArtKit._add(root, id, Transform3D.IDENTITY)
	return root


## Doorways with portals of their own (Floor1Art.PORTALS' form): the
## library's doorways stand under its gallery's slab (0.1 m over them): no
## frame on the library's face; Sloane's study opens through a bookcase.
static func portals() -> Dictionary:
	return {
		&"enlightenment_library_cabinet": {&"enlightenment_library": ["", Vector2.ZERO], &"enlightenment_cabinet": ["lib_doorframe_2x2_8", Vector2(2.0, 2.8)]},
		&"enlightenment_library_portraits": {&"enlightenment_library": ["", Vector2.ZERO], &"enlightenment_portraits": ["lib_portal_4x4_5", Vector2(4.0, 4.5)]},
		&"enlightenment_planetarium_door": {&"enlightenment_library": ["", Vector2.ZERO], &"enlightenment_planetarium": ["lib_portal_4x4_5", Vector2(4.0, 4.5)]},
		&"enlightenment_gallery_study": {&"enlightenment_library_gallery": ["", Vector2.ZERO], &"enlightenment_study": ["lib_doorframe_2x2_8", Vector2(2.0, 2.8)]},
	}


## Gates that do not look like gates: the bookcase in the upper gallery
## that hides Sloane's study.
static func disguised_gates() -> Array[StringName]:
	return [&"enlightenment_gallery_study"]


## A leaf of the study's hidden door: a shallow shelf of book spines facing
## the gallery (room A, the door frame's +Z).
static func gate_leaf(_opening_id: StringName, size: Vector3, _side: float) -> Variant:
	var root := _holder("Visual")
	var k := Vector3(size.x / 1.0, size.y / 3.3, size.z / 0.51)
	ArtKit._add(root, "lib_bookcase_up_1m", Transform3D(Basis(Vector3.UP, PI).scaled(k), Vector3(0.0, 0.0, -size.z * 0.5)))
	return root


# --- the library's stairs -------------------------------------------------------------

## A flight of the library in the stairs frame (StairsSpec.frame(): origin
## in the middle of the bottom front edge, -Z up the flight): oak steps with
## brass nosings over a mahogany-panelled mass, moulded stringers, cast iron
## balusters with a mahogany rail, a newel with a brass urn at the foot of
## each railed side.
static func library_stairs(flight: StairsSpec) -> Node3D:
	var root := _holder("Stairs")
	var width := flight.width()
	var rise := flight.top_y - flight.bottom_y
	var run_length := flight.run()
	var steps := flight.step_count()
	var r := rise / steps
	var t := run_length / steps
	for i in steps:
		ArtKit._add(root, "lib_stair_step_1m", Transform3D(Basis.from_scale(Vector3(width, r / 0.15, t / 0.4)), Vector3(0.0, i * r, -i * t)))
	var wedge := ArtKit._add(root, "stair_wedge", Transform3D(Basis.from_scale(Vector3(width, rise, run_length)), Vector3.ZERO))
	for view in wedge.find_children("*", "MeshInstance3D", true, false):
		(view as MeshInstance3D).material_override = ArtKit.field(flight.room_low, &"reveal")
	var modules := maxi(1, int(round(run_length / 4.0)))
	var seg := run_length / modules
	var k := Vector3(1.0, rise / modules / 1.5, seg / 4.0)
	for side in [-1.0, 1.0]:
		var x: float = side * (width * 0.5 + 0.07)
		for m in modules:
			var xf := Transform3D(Basis.from_scale(k), Vector3(x, m * rise / modules, -m * seg))
			ArtKit._add(root, "lib_stair_stringer_4m", xf)
			if (side < 0.0 and flight.rail_left) or (side > 0.0 and flight.rail_right):
				ArtKit._add(root, "lib_stair_railing_4m", xf)
		if (side < 0.0 and flight.rail_left) or (side > 0.0 and flight.rail_right):
			ArtKit._add(root, "lib_stair_newel", Transform3D(Basis.IDENTITY, Vector3(x, 0.0, 0.35)))
	return root


# --- hero pieces ------------------------------------------------------------------

## The wing's hero pieces for the dressed rooms ([param rooms] empty: all)
## under [param parent] (world space).
static func dress(layout: LevelLayout, parent: Node3D, rooms: Dictionary = {}) -> void:
	var library := layout.room(&"enlightenment_library")
	if library == null:
		return
	if Floor1Art.wants(rooms, &"enlightenment_library"):
		var cases := Floor1Art.group(parent, "LibraryBookcases", &"enlightenment_library")
		bookcases(cases)
		var hall := Floor1Art.group(parent, "Library", &"enlightenment_library")
		for well in library.skylights:
			_well(hall, well, library.ceiling_y)
		_signs(hall)
		_corner_paintings(hall)
		_ladders(hall)
	if Floor1Art.wants(rooms, &"enlightenment_clocks"):
		var clocks := Floor1Art.group(parent, "ClockWall", &"enlightenment_clocks")
		var room := layout.room(&"enlightenment_clocks")
		if room != null:
			var part := room.parts[0]
			for k in 3:
				var x := part.position.x + part.size.x * (0.25 + 0.25 * k)
				ArtKit._add(clocks, "lib_clock_wall", Transform3D(Basis(Vector3.UP, PI), Vector3(x, room.floor_y, part.position.y)))
	if Floor1Art.wants(rooms, &"enlightenment_portraits"):
		_scenes(Floor1Art.group(parent, "PortraitGallery", &"enlightenment_portraits"))
	if Floor1Art.wants(rooms, &"enlightenment_planetarium"):
		var rotunda := Floor1Art.group(parent, "Rotunda", &"enlightenment_planetarium")
		var dome := layout.room(&"enlightenment_planetarium")
		for well in dome.skylights:
			_well(rotunda, well, dome.ceiling_y)
		# two iron consoles under the counterweight's bracket
		var weight := Enlightenment.COUNTERWEIGHT
		for dz in [-0.6, 0.6]:
			ArtKit._add(rotunda, "lib_walkway_bracket", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(dome.parts[0].end.x, weight.y - Enlightenment.SLAB, weight.z + dz)))


## The King's Library's bookcases: every wall's runs in both tiers, each
## from pilaster to pilaster, a brass ladder rail along the lower cases, an
## iron console under the gallery at every lower pilaster, busts on
## brackets over the upper tier.
static func bookcases(root: Node3D) -> void:
	for tier in 2:
		var upper := tier == 1
		var y := Enlightenment.UPPER if upper else 0.0
		var west := run_clear(WEST, upper)
		var east := run_clear(EAST, upper)
		for span in Enlightenment.shelf_spans(west):
			_wall_run(root, Vector3(WEST, y, 0.0), -PI * 0.5, span, upper, 0)
		for span in Enlightenment.shelf_spans(east):
			_wall_run(root, Vector3(EAST, y, 0.0), PI * 0.5, span, upper, 1)
		_wall_run(root, Vector3(0.0, y, NORTH), PI, SHORT_RUN, upper, 2)
		_wall_run(root, Vector3(0.0, y, SOUTH), 0.0, SHORT_RUN, upper, 3)


## One run of bookcases on a wall: the wall's frame from [param wall] (its
## plane's coordinate; the other one 0) and [param yaw] (the cases' fronts
## into the room), [param span] along it (z for the long walls, x for the
## short ones).
static func _wall_run(root: Node3D, wall: Vector3, yaw: float, span: Vector2, upper: bool, offset: int) -> void:
	var along_z := absf(sin(yaw)) > 0.5
	var bays := Enlightenment.bays(span.x, span.y)
	# the run's frame: its x along increasing world coordinate, -Z into the room
	var basis := Basis(Vector3.UP, yaw)
	var flip := 1.0 if basis.x.dot(Vector3.BACK if along_z else Vector3.RIGHT) > 0.0 else -1.0
	var origin := Vector3(wall.x, wall.y, 0.0) if along_z else Vector3(0.0, wall.y, wall.z)
	var frame := Transform3D(basis, origin)
	_run(root, frame, bays, upper, offset, flip, along_z)


## Places the pilasters and cases of [param bays] in [param frame] (the
## wall plane: model -Z into the room); a bay's coordinate c lies at
## frame.basis.x * c * [param flip]. The lower tier carries the ladder rail
## and the gallery's consoles (unless [param consoles] is false), the long
## walls' upper tier the busts.
static func _run(root: Node3D, frame: Transform3D, bays: Dictionary, upper: bool, offset: int, flip: float = 1.0, long_wall: bool = false, consoles: bool = true) -> void:
	var lower_ids := ["lib_bookcase_a_2m", "lib_bookcase_b_2m", "lib_bookcase_c_2m"]
	var upper_ids := ["lib_bookcase_up_a_2m", "lib_bookcase_up_b_2m"]
	var pilaster := "lib_bookcase_pilaster_up" if upper else "lib_bookcase_pilaster_low"
	var k := offset
	for entry: Array in bays["cases"]:
		var c: float = entry[0]
		var native: float = entry[1]
		var width: float = entry[2]
		var at := frame * Vector3(c * flip, 0.0, 0.0)
		var basis := frame.basis * Basis.from_scale(Vector3(width / native, 1.0, 1.0))
		var id: String
		var texture_set := ""
		if native < 1.5:
			id = "lib_bookcase_up_1m" if upper else "lib_bookcase_1m"
		elif upper:
			id = upper_ids[k % upper_ids.size()]
		else:
			id = lower_ids[k % lower_ids.size()]
			if (k / lower_ids.size()) % 2 == 1:
				texture_set = id + "_v2"
		k += 1
		ArtKit._add(root, id, Transform3D(basis, at), texture_set)
		if not upper and native > 1.5:
			ArtKit._add(root, "lib_ladder_rail_2m", Transform3D(basis, at))
	var i := 0
	for p: float in bays["pilasters"]:
		var at := frame * Vector3(p * flip, 0.0, 0.0)
		ArtKit._add(root, pilaster, Transform3D(frame.basis, at))
		if not upper:
			# the iron console: its top under the slab, its back on the pilaster's face
			if consoles:
				ArtKit._add(root, "lib_walkway_bracket", Transform3D(frame.basis, at + frame.basis * Vector3(0.0, SLAB_UNDER - at.y, -0.6)))
		elif long_wall and i % BUST_EVERY == BUST_EVERY / 2:
			var bracket := ArtKit._add(root, "lib_bust_bracket", Transform3D(frame.basis, Vector3(at.x, BUST_Y, at.z)))
			var spot := ArtLibrary.parts(bracket).get("bust_spot") as Node3D
			var bust_at := bracket.transform * (spot.position if spot != null else Vector3(0.0, 0.0, -0.24))
			# (the bust's face is its +Z)
			ArtKit._add(root, "bust", Transform3D(frame.basis * Basis(Vector3.UP, PI), bust_at), "bust_bronze" if (i / BUST_EVERY) % 2 == 1 else "")
		i += 1


## A light well of the library or the rotunda: the panelled well with its
## iron laylight, a hair inside the shell's well.
static func _well(root: Node3D, well: Rect2, ceiling_y: float) -> void:
	var k := Vector3(well.size.x / 4.0 * 0.99, LevelLayout.SKYLIGHT_WELL / 1.47, well.size.y / 4.0 * 0.99)
	var frame := ArtKit._add(root, "lib_skylight_well_4m", Transform3D(Basis.from_scale(k), Vector3(well.get_center().x, ceiling_y, well.get_center().y)))
	for view in frame.find_children("*_glass", "MeshInstance3D", true, false):
		(view as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The KING'S LIBRARY sign's middle over the court's doorway (inside), at
## twice the kit's size (0.68 m high): over the doorway's exit sign (its
## light 0.45 m over the 7 m arch, the sign 0.3 m high), under the cornice.
const KING_SIGN_Y := 8.2


## Green enamel signs: KING'S LIBRARY over the court's doorway (inside),
## and under the gallery's edge before each cabinet's doorway.
static func _signs(root: Node3D) -> void:
	ArtKit._add(root, "lib_sign", Transform3D(Basis(Vector3.UP, -PI * 0.5).scaled(Vector3.ONE * 2.0), Vector3(WEST, KING_SIGN_Y, 0.0)))
	var edge := 42.0 - 0.13
	for sign: Array in [[0.0, "lib_sign_natural"], [17.75, "lib_sign_collectors"], [-5.5, "lib_sign_librarian"], [-26.5, "lib_sign_orrery"]]:
		ArtKit._add(root, "lib_sign", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(edge, SLAB_UNDER - 0.19, float(sign[0]))), String(sign[1]))


## Small pictures in the corners the bookcases leave bare (the short walls'
## ends, both tiers).
static func _corner_paintings(root: Node3D) -> void:
	var size := Vector3(1.2, 0.9, 0.08)
	var seed := 0
	for tier_y in [1.35, Enlightenment.UPPER + 1.35]:
		for corner: Array in [[32.8, NORTH, PI], [43.2, NORTH, PI], [32.8, SOUTH, 0.0], [43.2, SOUTH, 0.0]]:
			var yaw: float = corner[2]
			var picture := ArtKit.piece(&"painting", size, &"enlightenment_library", seed)
			seed += 1
			if picture == null:
				continue
			var wall := Vector3(float(corner[0]), tier_y, float(corner[1]))
			picture.transform = Transform3D(Basis(Vector3.UP, yaw), wall + Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, -0.04))
			root.add_child(picture)


## The collectors' gallery: between its portraits (the game hangs them on
## the markers) landscapes and still lifes in the hall's frames - a big one
## over the bench by the cabinet's door, small ones in the narrow piers.
## Each: [canvas centre on the wall, the frame's yaw (front into the room),
## size].
const SCENES := [
	[Vector3(65.0, 2.1, 25.25), PI * 0.5, Vector2(0.6, 0.8)], [Vector3(65.0, 2.1, 29.75), PI * 0.5, Vector2(0.6, 0.8)],
	[Vector3(51.0, 2.1, 26.5), -PI * 0.5, Vector2(1.2, 0.9)], [Vector3(53.5, 2.6, 14.5), PI, Vector2(3.0, 2.0)],
]


static func _scenes(root: Node3D) -> void:
	var seed := 1
	for entry: Array in SCENES:
		var size: Vector2 = entry[2]
		var picture := ArtKit.piece(&"painting", Vector3(size.x, size.y, 0.08), &"enlightenment_portraits", seed)
		seed += 1
		if picture == null:
			continue
		var basis := Basis(Vector3.UP, float(entry[1]))
		var wall: Vector3 = entry[0]
		picture.transform = Transform3D(basis, wall - Vector3.UP * size.y * 0.5 + basis * Vector3(0.0, 0.0, -0.04))
		root.add_child(picture)


## The library ladders: one on the north wall west of the stairs' head, one
## on the south wall east of the other (under the bridges, off the aisles),
## hooked on the rail of the lower cases.
static func _ladders(root: Node3D) -> void:
	for spot: Array in [[35.2, NORTH, PI], [40.8, SOUTH, 0.0]]:
		var basis := Basis(Vector3.UP, float(spot[2]))
		ArtKit._add(root, "lib_ladder", Transform3D(basis, Vector3(float(spot[0]), 0.0, float(spot[1])) + basis * Vector3(0.0, 0.0, -0.62)))


# --- light recipe extras -------------------------------------------------------------

## The lower tier's warm wall lamps (Floor1LightRecipe extras): green-shaded
## lamps on the lower pilasters nearest LOW_SCONCES_Z on both long walls,
## pools of warm light in the aisles under the gallery (little energy: the
## exhibits' light model reads the layout's lamps).
static func extra_lights() -> Array:
	var out: Array = []
	for z: float in LOW_SCONCES_Z:
		# (on the runs' pilasters: never on an env tool's bookcase, which falls)
		for wall: Array in [[WEST, run_clear(WEST, false), -PI * 0.5, 1.0], [EAST, run_clear(EAST, false), PI * 0.5, -1.0]]:
			var at := Enlightenment.nearest_pilaster(Enlightenment.shelf_spans(wall[1]), z)
			var x: float = float(wall[0]) + float(wall[3]) * Enlightenment.SCONCE_OUT
			out.append({"room": &"enlightenment_library", "position": Vector3(x, LOW_SCONCE_Y, at), "color": Enlightenment.WARM,
				"energy": 0.45, "range": 4.5, "rule": &"sconce", "fixture": &"sconce", "fixture_yaw": wall[2]})
	return out
