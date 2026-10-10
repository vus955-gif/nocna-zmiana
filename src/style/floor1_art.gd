class_name Floor1Art
extends RefCounted
## Floor I's art, stage P2 (plan docs/superpowers/plans/2026-10-03-p2-
## oprawa-hol-egipt.md): the hub - the Great Court, the Reading Room, the
## entrance hall, the booth, the north corridor - and the Egypt wing dressed
## with the court and Egypt kits (docs/art/kit-pietro1-dziedziniec.md,
## kit-pietro1-egipt.md). Pure factories of Node3D trees of ArtLibrary
## models, no collision (the greybox keeps it):
## - [method piece_look]: a layout piece's look where Floor I fits it its
##   own way, an empty look where a hero piece stands instead (the drum's
##   walls, the Reading Room's shelves, the balcony's ring slabs), or null
##   (ArtKit's kit rules);
## - [method fixture], [method passage]: light fittings and door frames by
##   room style and opening;
## - [method dress]: the hero pieces no greybox box stands for - the glass
##   roof, the drum, its bookcases and dome, the balcony, the entrance's
##   mosaic, Egypt's beams, stone lattices and clerestories, the portals of
##   the sealed gates.
## Hero pieces stand where nobody walks (overhead, against walls, inside a
## greybox collision), so navigation and collisions stay the greybox's.

const Court := preload("res://src/level/floor1/zones/court.gd")
const Egypt := preload("res://src/level/floor1/zones/egypt.gd")
## The wings dressed in stage P3 keep their art in modules of their own
## ([method wings]: Floor1ArtGreece, Floor1ArtEnlightenment), asked by the
## prefix of the room id ([method wing_of]). Each has piece_look, fixture,
## dress, gate_leaf, portals and disguised_gates.

## Floor I room id -> its style in ArtKit.ROOMS (the zones P2 dresses;
## MuseumFloorLevel.ART_ZONES). Other zones add theirs in stage P3.
const ROOM_STYLES := {
	&"court": &"court", &"court_balcony": &"court", &"court_reading": &"reading_room",
	&"entrance_hall": &"entrance", &"entrance_gallery": &"entrance", &"entrance_cloakroom": &"cloakroom",
	&"entrance_coat_store": &"closet",
	&"booth_corridor": &"staff_corridor", &"booth_security": &"security", &"booth_staff": &"staff_corridor",
	&"booth_stairs": &"corridor_w", &"booth_watch": &"secret_chamber",
	&"north_hall": &"north_hall", &"north_hall_lodge": &"closet", &"north_hall_crypt": &"crypt",
	&"north_hall_crypt_vault": &"crypt",
	&"egypt_vestibule": &"egypt_vestibule", &"egypt_gallery": &"egypt_gallery", &"egypt_colossus": &"egypt_colossus_hall",
	&"egypt_tomb_passage": &"egypt_tomb", &"egypt_tombs": &"egypt_tomb", &"egypt_tomb_hall": &"egypt_tomb",
	&"egypt_tomb_serdab": &"egypt_tomb", &"egypt_tomb_priest": &"egypt_tomb", &"egypt_conservator": &"egypt_conservator",
	&"egypt_cache": &"closet", &"egypt_service_stairs": &"corridor_w", &"egypt_service_corridor": &"corridor_w",
	# the basement (stage P3, BasementArt): painted service corridors, the boiler room, stores
	&"basement_corridor_north": &"basement_corridor_north", &"basement_corridor_west": &"basement_corridor_egypt",
	&"basement_corridor_east": &"basement_corridor", &"basement_corridor_south": &"basement_corridor",
	&"basement_tunnel": &"basement_tunnel", &"basement_boiler": &"basement_boiler", &"basement_boiler_catwalk": &"basement_boiler",
	&"basement_crossing": &"basement_crossing", &"basement_corridor_spine_w": &"basement_corridor_egypt",
	&"basement_corridor_spine_e": &"basement_corridor", &"basement_workshop": &"basement_workshop",
	&"basement_corridor_workshop": &"basement_corridor", &"basement_store_plinths": &"basement_store",
	&"basement_switchboard": &"basement_switchboard", &"basement_reserve": &"basement_store",
	&"basement_archive": &"basement_office", &"basement_corridor_staff": &"basement_corridor_booth",
	&"basement_store_guards": &"basement_office", &"basement_old_cellar": &"basement_cellar", &"basement_cage": &"basement_vault",
	&"basement_shelter": &"basement_shelter",
	# stage P3: the Greek wing (Floor1ArtGreece) and the Enlightenment wing
	# (Floor1ArtEnlightenment)
	&"greece_nereid": &"greece_nereid", &"greece_nereid_podium": &"greece_nereid", &"greece_bassae": &"greece_bassae",
	&"greece_bassae_gallery": &"greece_bassae", &"greece_vases": &"greece_vases", &"greece_metopes": &"greece_metopes",
	&"greece_cast_store": &"greece_casts", &"greece_parthenon": &"greece_gallery", &"greece_bassae_loft": &"greece_casts",
	&"greece_pottery": &"greece_casts", &"greece_cast_cellar": &"greece_casts", &"greece_service_stairs": &"corridor_w",
	&"greece_service_corridor": &"corridor_w",
	&"enlightenment_library": &"enlightenment_library", &"enlightenment_library_gallery": &"enlightenment_library",
	&"enlightenment_planetarium": &"enlightenment_planetarium", &"enlightenment_observatory": &"enlightenment_planetarium",
	&"enlightenment_roof_stairs": &"corridor_w", &"enlightenment_attic": &"closet",
	&"enlightenment_librarian": &"enlightenment_librarian", &"enlightenment_clocks": &"enlightenment_clocks",
	&"enlightenment_cabinet": &"enlightenment_cabinet", &"enlightenment_portraits": &"enlightenment_portraits",
	&"enlightenment_service_stairs": &"corridor_w", &"enlightenment_stacks": &"corridor_w",
	&"enlightenment_archive": &"enlightenment_librarian", &"enlightenment_bindery": &"closet",
	&"enlightenment_study": &"enlightenment_librarian",
}
## Every model this module places (the art test checks each is registered
## and has its file).
const MODELS: Array[String] = [
	"court_roof_q", "rr_drum_wall", "rr_drum_door", "rr_bookcase", "rr_bookcase_door", "rr_dome_sector", "rr_oculus",
	"rr_desk", "rr_catalogue_arc", "astrolabe", "steam_banner", "steam_engine", "court_bench", "cafe_counter",
	"cafe_table", "cafe_chair", "shop_front", "court_lamp_post", "totem_haida", "sign_wing", "sign_wing_portal",
	"court_map_board", "court_balcony_seg", "court_parapet_2m", "court_parapet_1m", "court_stair_step",
	"court_stair_parapet_4m", "court_stair_mass", "entrance_column", "entrance_door_l", "entrance_door_r",
	"entrance_door_sign", "cloakroom_counter", "entrance_mosaic", "door_grand_leaf_l", "door_grand_leaf_r",
	"hall_arch_4m", "hall_door_reveal_4m", "hall_pilaster_base", "hall_pilaster_shaft", "hall_pilaster_capital",
	"egypt_beam_4m", "egypt_clerestory_3m", "egypt_portal_great", "egypt_portal_4m", "egypt_doorframe_2x2_8",
	"egypt_plinth", "pharaoh_statue", "obelisk", "sekhmet", "rosetta_case", "rosetta_stone", "camp_tent",
	"camp_table", "camp_chair", "camp_crate", "camp_crate_open", "camp_rifle_rack", "camp_lamp",
	"sarcophagus", "coffin", "egypt_torch_lamp", "egypt_spotlight", "banner", "bench_hall",
	"doorframe_2x2_6", "doorframe_2x2_8", "egypt_seal_door_l", "egypt_seal_door_r",
]
## Wing sign texture sets by the zone a sign points to (sign_wing_portal /
## sign_wing; Egypt is the default set).
const WING_SETS := {
	&"egypt": "", &"assyria": "_asyria", &"greece": "_greece", &"enlightenment": "_enlight", &"asia": "_asia",
	&"americas": "_americas",
}
## Door frames of a style key: [model, native opening (w, h)].
const FRAME_KEYS := {"frame_4": Vector2(4.0, 4.5), "frame_2_8": Vector2(2.0, 2.8), "frame_2_6": Vector2(2.0, 2.6)}
## A frame may be scaled this far either way to fit an opening.
const FRAME_STRETCH := Vector2(0.55, 2.0)
## Openings with their own portals: opening -> {room: [model, native
## opening, texture set (optional)]} ("" = a bare opening on that side).
## The sealed gates' portals are hero pieces (SealGate hides their Door):
## SEAL_PORTALS. Wings of stage P3 add theirs (their portals()).
const PORTALS := {
	&"j_court_egypt": {&"court": ["egypt_portal_great", Vector2(6.0, 7.5)], &"egypt_vestibule": ["", Vector2.ZERO]},
	&"egypt_gallery_colossus": {&"egypt_colossus": ["egypt_portal_great", Vector2(6.0, 7.5)], &"egypt_gallery": ["", Vector2.ZERO]},
	&"egypt_vestibule_gallery": {&"egypt_vestibule": ["", Vector2.ZERO], &"egypt_gallery": ["", Vector2.ZERO]},
	&"court_reading_door": {},
	&"j_court_north": {},
	&"j_egypt_assyria": {},
}
## The sealed gates' portals: opening -> [[room whose face, model, native
## opening], ...].
const SEAL_PORTALS := {
	&"j_court_north": [[&"court", "hall_arch_4m", Vector2(4.0, 4.5)], [&"north_hall", "hall_arch_4m", Vector2(4.0, 4.5)]],
	&"j_egypt_assyria": [[&"egypt_colossus", "egypt_portal_great", Vector2(6.0, 7.5)]],
}
## Group of the astrolabe's art (FloorFinale's Astrolabe skips its greybox
## when the level has one).
const ASTROLABE_GROUP := &"floor1_astrolabe_art"
## Group of the hero pieces' decor processes (DecorSpinner; culled by room).
const DECOR_GROUP := &"floor1_decor"
## Egypt's clerestory windows high in the gallery's east wall: z of each,
## the sill's height, the night glow behind the stone lattice.
const CLERESTORY_Z: Array[float] = [15.75, 8.25, 0.75, -6.75]
const CLERESTORY_SILL := 8.05
const NIGHT_GLASS := Color(0.42, 0.54, 0.86)

## Room id -> height (floor to ceiling) of the layout being dressed; door
## frames that would reach a low ceiling are left out ([method prepare]).
static var _heights: Dictionary = {}
static var _bounds_cache: Dictionary = {}
static var _tinted: Dictionary = {}
static var _night_glass: StandardMaterial3D = null


## True when [param layout] is Floor I (the Reading Room is in it).
static func is_floor1(layout: LevelLayout) -> bool:
	return layout != null and layout.room(&"court_reading") != null


## Reads what the frames need of [param layout] (room heights); call before
## building a Floor I level with art.
static func prepare(layout: LevelLayout) -> void:
	_heights.clear()
	for room in layout.rooms:
		_heights[room.id] = room.ceiling_y - room.floor_y


## True when the Floor I art should dress a level the game builds now
## (MuseumFloorLevel's switch and the kit's).
static func enabled() -> bool:
	return LevelArt.enabled and ArtLibrary.models_enabled and MuseumFloorLevel.dress_default


# --- pieces --------------------------------------------------------------------

## The look of [param spec] in its own frame (origin = centre of the base,
## -Z = front), an empty holder where a hero piece stands instead, or null
## (ArtKit's rules for its kit and style).
static func piece_look(spec: PieceSpec, index: int, layout: LevelLayout) -> Node3D:
	if BasementArt.is_basement(spec.room):
		var service := BasementArt.piece_look(spec, index, layout)
		if service != null:
			return service
	# a stage P3 wing's own fits first, then the floor's common ones below
	var wing: Variant = wing_of(spec.room)
	if wing != null:
		var own: Variant = wing.piece_look(spec, index, layout)
		if own is Node3D:
			return own
	var style: StringName = ROOM_STYLES.get(spec.room, &"")
	var size := spec.size
	match spec.kit:
		&"wall":
			# the drum's segments: rr_drum_wall / rr_drum_door ([method dress])
			return _holder("Visual") if spec.room == &"court_reading" else null
		&"shelf":
			if spec.room == &"court_reading":
				return _holder("Visual")
		&"catalogue":
			return _holder("Visual")   # rr_catalogue_arc round the astrolabe ([method dress])
		&"balcony":
			if spec.room == &"court":
				# the ring slabs are the court_balcony_seg models; the landings
				# by the flights stay plain slabs (LevelArt)
				return _holder("Visual") if _on_ring(spec.position) else null
		&"railing":
			if spec.room == &"court_balcony":
				if _on_ring(spec.position):
					return _holder("Visual")   # the segment's own balustrade
				var parapet := _holder("Visual")
				ArtKit.run(parapet, "court_parapet_", -size.x * 0.5, size.x * 0.5, 0.0)
				return parapet
		&"column":
			if style == &"court":
				return _fit(_holder("Visual"), "entrance_column", Vector3(size.x / 1.72, size.y / 12.0, size.z / 1.72))
			if style == &"egypt_colossus_hall":
				return _fit(_holder("Visual"), "egypt_column_open", Vector3(size.x / 2.6, size.y / 11.0, size.z / 2.6))
		&"pedestal":
			if spec.room == &"court_reading":
				return _holder("Visual")   # the astrolabe's own steps ([method dress])
			if String(style).begins_with("egypt"):
				return _fit(_holder("Visual"), "egypt_plinth", size / Vector3(1.0, 0.6, 1.0))
		&"bench":
			if style == &"court":
				return _fit(_holder("Visual"), "court_bench", size / Vector3(3.0, 0.47, 0.56))
			return ArtKit.piece(&"bench", size, &"hall")
		&"cafe_counter":
			return _cafe_counter(size)
		&"cafe_table":
			return _cafe_table(index)
		&"shop_front":
			return _shop(size, spec.room)
		&"grate":
			if style == &"court":
				return _holder("Visual")   # the shop front's own roller grille
		&"totem":
			var totem := _holder("Visual")
			# facing the middle of the court from its corner
			var to_middle := Vector2(-spec.position.x, -spec.position.z)
			ArtKit._add(totem, "totem_haida", Transform3D(Basis(Vector3.UP, atan2(-to_middle.x, -to_middle.y) - spec.yaw), Vector3.ZERO))
			return totem
		&"court_lamp_post":
			return _fit(_holder("Visual"), "court_lamp_post", Vector3.ONE)
		&"court_map_board":
			return _fit(_holder("Visual"), "court_map_board", Vector3.ONE)
		&"signpost":
			var post := _holder("Visual")
			ArtKit._add(post, "sign_wing", Transform3D.IDENTITY, "sign_wing" if spec.position.x < 0.0 else "sign_wing_enlight")
			return post
		&"sign_wing_portal":
			return _wing_sign(spec)
		&"banner":
			return _banner(spec, index)
		&"door_leaf":
			return _leaves(spec)
		&"steam_engine":
			# the flywheel and the governor turn (a decor process: culled by room)
			var engine := _holder("Visual")
			var k := minf(size.x / 1.37, size.z / 3.72)
			var model := ArtKit._add(engine, "steam_engine", Transform3D(Basis.from_scale(Vector3.ONE * k), Vector3.ZERO))
			var parts := ArtLibrary.parts(model)
			var spinner := DecorSpinner.new()
			spinner.name = "EngineSpin"
			spinner.add(parts.get("flywheel") as Node3D, Vector3.RIGHT, 0.9)
			spinner.add(parts.get("governor") as Node3D, Vector3.UP, 1.6)
			_decor(engine, spinner, spec.room)
			return engine
		&"steam_banner":
			# a standing banner on the floor behind the gatling, not a strip on
			# the shelves: from the piece (4.6 m up the bookcases) to the floor
			var banner := _holder("Visual")
			ArtKit._add(banner, "steam_banner", Transform3D(Basis.IDENTITY, Vector3(0.0, -spec.position.y, -0.35)))
			return banner
		&"desk":
			if spec.room == &"court_reading":
				return _fit(_holder("Visual"), "rr_desk", Vector3.ONE)
			if spec.room == &"egypt_gallery":
				return _camp_table(size)
		&"crate":
			return _crate(spec, index)
		&"plinth":
			if String(style).begins_with("egypt"):
				return _plinth(spec, index)
		&"sculpture":
			match spec.room:
				&"egypt_gallery":
					var k2 := size.y / 6.85
					return _fit(_holder("Visual"), "pharaoh_statue", Vector3.ONE * k2)
				&"egypt_vestibule":
					return _fit(_holder("Visual"), "obelisk", size / Vector3(1.5, 6.32, 1.5))
				&"egypt_tomb_serdab":
					return _fit(_holder("Visual"), "sekhmet", Vector3.ONE * size.y / 2.14)
		&"case":
			if spec.room == &"egypt_vestibule":
				return _rosetta(size)
		&"cloakroom_counter":
			return _cloakroom(size)
		&"coat_rack":
			return _holder("Visual")   # the coats hang on the cloakroom counter's rails
		&"pilaster":
			return _pilaster(spec, layout)
		&"sarcophagus":
			var lid := _holder("Visual")
			ArtKit._add(lid, "sarcophagus", Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE * minf(size.z / 2.72, size.x / 1.37)), Vector3.ZERO), "sarcophagus" if index % 2 == 0 else "sarcophagus_red")
			return lid
	return null


## The art module of a stage P3 wing for [param room] (Floor1ArtGreece,
## Floor1ArtEnlightenment), or null.
static func wing_of(room: StringName) -> Variant:
	var id := String(room)
	if id.begins_with("greece_"):
		return Floor1ArtGreece
	if id.begins_with("enlightenment_"):
		return Floor1ArtEnlightenment
	return null


## The art modules of the stage P3 wings.
static func wings() -> Array:
	return [Floor1ArtGreece, Floor1ArtEnlightenment]


## True for a point over the balcony's ring (north of the landings by the
## flights, which end at z -3.5).
static func _on_ring(at: Vector3) -> bool:
	return at.z < -3.6


static func _holder(label: String) -> Node3D:
	var n := Node3D.new()
	n.name = label
	return n


## [param root] with model [param id] scaled by [param scale] at its origin.
static func _fit(root: Node3D, id: String, scale: Vector3, texture_set: String = "") -> Node3D:
	ArtKit._add(root, id, Transform3D(Basis.from_scale(scale), Vector3.ZERO), texture_set)
	return root


## Bounds of model [param id] in its own frame (cached).
static func bounds(id: String) -> AABB:
	if _bounds_cache.has(id):
		return _bounds_cache[id]
	var node := ArtKit.model(id)
	var out := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var n: Node = view
		while n != null and n != node:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var box := xf * view.get_aabb()
		out = box if first else out.merge(box)
		first = false
	node.free()
	_bounds_cache[id] = out
	return out


## The café's counter filling its box: the front on the piece's south face
## (the café floor), the back bar against the wall; stretched at most 30 %
## along the counter.
static func _cafe_counter(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var box := bounds("cafe_counter")
	var stretch := clampf(size.x / box.size.x, 0.85, 1.3)
	var deep := clampf(size.z / box.size.z, 0.85, 1.15)
	# turned to face +Z: the model's front (z -0.42) to the piece's +Z face
	var turn := Basis(Vector3.UP, PI).scaled(Vector3(stretch, 1.0, deep))
	ArtKit._add(root, "cafe_counter", Transform3D(turn, Vector3(0.0, 0.0, size.z * 0.5 + box.position.z * deep)))
	return root


## A marble café table with three bentwood chairs round it (the chairs have
## no collision; they stand where the table's box already keeps people).
static func _cafe_table(index: int) -> Node3D:
	var root := _holder("Visual")
	ArtKit._add(root, "cafe_table", Transform3D.IDENTITY)
	for k in 3:
		var a := TAU * k / 3.0 + index * 0.7
		var at := Vector3(sin(a), 0.0, cos(a)) * 0.62
		ArtKit._add(root, "cafe_chair", Transform3D(Basis(Vector3.UP, a + PI + 0.15 * sin(index + k)), at))
	return root


## The museum shop's kiosk: the box in the court's stone, the shop front
## (closed roller grille) on its north face, scaled to the kiosk's width.
static func _shop(size: Vector3, room: StringName) -> Node3D:
	var root := _holder("Visual")
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size - Vector3(0.0, 0.0, 0.42)
	body.mesh = mesh
	body.material_override = ArtKit.field(room, &"wall")
	body.position = Vector3(0.0, size.y * 0.5, 0.21)
	root.add_child(body)
	var k := size.x / 8.2
	ArtKit._add(root, "shop_front", Transform3D(Basis.from_scale(Vector3.ONE * k), Vector3(0.0, 0.0, -size.z * 0.5 + 0.42)))
	return root


## A plate over a doorway naming the wing beyond in its colours (none for
## the hub's own rooms: the kit has the six wings).
static func _wing_sign(spec: PieceSpec) -> Node3D:
	var root := _holder("Visual")
	var zone := zone_of_tint(spec.tint)
	if zone == &"booth":
		root.free()
		return BasementArt.staff_sign(spec)   # the way back to the booth: "staff only"
	if not WING_SETS.has(zone):
		return root
	# the pylon round the court's door to Egypt is its sign (the plate would
	# sink into its cornice)
	if spec.room == &"court" and zone == &"egypt":
		return root
	var k := minf(spec.size.x / 3.2, spec.size.y / 0.6)
	var suffix: String = WING_SETS[zone]
	ArtKit._add(root, "sign_wing_portal", Transform3D(Basis.from_scale(Vector3.ONE * k), Vector3(0.0, 0.0, spec.size.z * 0.5)), "sign_wing_portal" + suffix)
	return root


## The Floor I zone whose colour is [param tint] (&"" when none).
static func zone_of_tint(tint: Color) -> StringName:
	for zone: StringName in Floor1Plan.ZONES:
		var c := Floor1Plan.zone_color(zone)
		if absf(c.r - tint.r) + absf(c.g - tint.g) + absf(c.b - tint.b) < 0.02:
			return zone
	return &""


## A banner in the colour of the wing it hangs by: the kit's banner with a
## tinted copy of its cloth.
static func _banner(spec: PieceSpec, index: int) -> Node3D:
	var look := ArtKit.piece(&"banner", spec.size, spec.room, index)
	if look == null or spec.tint.a <= 0.0:
		return look
	var tint := spec.tint.lightened(0.25)
	for child in look.find_children("*", "MeshInstance3D", true, false):
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
	return look


## Bronze leaves: the drum's blind portals (two grand leaves in the 3 m
## opening), the entrance's main doors (with the "open from 6:00" sign),
## the lodge's bricked-up north doors.
static func _leaves(spec: PieceSpec) -> Node3D:
	var root := _holder("Visual")
	var size := spec.size
	if spec.room == &"entrance_hall":
		var k := Vector3(size.x * 0.5 / 2.2, size.y / 5.0, 1.0)
		for side in [-1.0, 1.0]:
			var id := "entrance_door_l" if side < 0.0 else "entrance_door_r"
			ArtKit._add(root, id, Transform3D(Basis.from_scale(k), Vector3(side * size.x * 0.25, 0.0, 0.0)))
		# the sign faces the hall (the piece's -Z: the doors stand in the south wall)
		ArtKit._add(root, "entrance_door_sign", Transform3D(Basis.IDENTITY, Vector3(-size.x * 0.25, 1.6, -0.2)))
		return root
	var width := minf(size.x, Court.PORTAL_WIDTH) if spec.room == &"court_reading" else size.x
	for side in [-1.0, 1.0]:
		var id2 := "door_grand_leaf_l" if side < 0.0 else "door_grand_leaf_r"
		ArtKit._add(root, id2, Transform3D(Basis.from_scale(Vector3(width * 0.5 / 2.0, size.y / 4.5, 1.0)), Vector3(side * width * 0.25, 0.0, 0.0)))
	return root


## The expedition's map table (the shotgun lies on it) and a camp chair.
static func _camp_table(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	ArtKit._add(root, "camp_table", Transform3D(Basis.from_scale(size / Vector3(1.4, 0.95, 0.79)), Vector3.ZERO))
	ArtKit._add(root, "camp_chair", Transform3D(Basis(Vector3.UP, 0.3), Vector3(0.35, 0.0, size.z * 0.5 + 0.35)))
	return root


## Crates by room: the 1898 camp's tent and stencilled crates, standing
## coffins in the tomb passage, the expedition's stores.
static func _crate(spec: PieceSpec, index: int) -> Node3D:
	var size := spec.size
	var root := _holder("Visual")
	match spec.room:
		&"egypt_gallery":
			if size.x > 3.0:
				# the tent, its open front to the south (the camp's table)
				var k := minf(size.x / 4.27, size.z / 3.59) * 1.05
				var tent := ArtKit._add(root, "camp_tent", Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * k), Vector3.ZERO))
				# the rifle rack inside, behind the flaps
				ArtKit._add(root, "camp_rifle_rack", Transform3D(Basis(Vector3.UP, PI), Vector3(0.6, 0.0, 0.2)))
				tent.set_meta(&"camp_tent", true)
				return root
			_camp_crate(root, size, index)
			return root
		&"egypt_tomb_passage":
			ArtKit._add(root, "coffin", Transform3D(Basis.from_scale(size / Vector3(0.78, 2.02, 0.72)), Vector3.ZERO), "coffin" if index % 2 == 0 else "coffin_black")
			return root
		&"egypt_cache", &"egypt_service_corridor":
			_camp_crate(root, size, index)
			return root
	root.free()
	return null


## A camp crate filling a crate box of [param size]: the open one (1.0 x
## 0.8 x 0.8) or a closed one (1.02 x 0.6 x 0.63, "EKSPEDYCJA 1898 / TEBY"
## or "OSTROŻNIE / MUZEUM").
static func _camp_crate(root: Node3D, size: Vector3, index: int) -> void:
	if index % 2 == 0:
		ArtKit._add(root, "camp_crate_open", Transform3D(Basis.from_scale(size / Vector3(1.0, 0.8, 0.8)), Vector3.ZERO))
	else:
		ArtKit._add(root, "camp_crate", Transform3D(Basis.from_scale(size / Vector3(1.02, 0.6, 0.63)), Vector3.ZERO), "camp_crate_b" if index % 4 == 1 else "")


## A sarcophagus on a 1 x 0.9 x 2.4 plinth (its long side along the plinth),
## red granite or black; small plinths stay plinths.
static func _plinth(spec: PieceSpec, index: int) -> Node3D:
	var size := spec.size
	var root := _holder("Visual")
	if maxf(size.x, size.z) < 1.5:
		return _fit(root, "egypt_plinth", size / Vector3(1.0, 0.6, 1.0))
	var long_z := size.z > size.x
	var k := maxf(size.x, size.z) / 2.72
	var turn := Basis(Vector3.UP, PI * 0.5) if long_z else Basis.IDENTITY
	ArtKit._add(root, "sarcophagus", Transform3D(turn.scaled(Vector3.ONE * k), Vector3.ZERO), "sarcophagus" if index % 2 == 0 else "sarcophagus_red")
	return root


## The Rosetta Stone in its case on a low granite plinth that fills the
## greybox case's footprint.
static func _rosetta(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var base := 0.35
	ArtKit._add(root, "egypt_plinth", Transform3D(Basis.from_scale(Vector3(size.x, base, size.z) / Vector3(1.0, 0.6, 1.0)), Vector3.ZERO))
	var case := ArtKit._add(root, "rosetta_case", Transform3D(Basis.IDENTITY, Vector3(0.0, base, 0.0)))
	ArtKit._solid_glass(case)
	ArtKit._add(root, "rosetta_stone", Transform3D(Basis.IDENTITY, Vector3(0.0, base + 0.62, 0.0)))
	return root


## The cloakroom's counter, rails and coats: its front to the hall (the
## piece's west face), narrowed to keep the door in the south wall clear.
static func _cloakroom(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var box := bounds("cloakroom_counter")
	var k := 0.88
	var along := minf(4.6 / box.size.x, k)
	# the rails and coats close behind the counter (depth 60 %): the room's
	# east half stays free for the walk to its cracked back wall
	var deep := k * 0.6
	# the model's front (-Z, the counter at z -0.45) turned to -X (west); its
	# width (local x) narrowed
	var turn := Basis(Vector3.UP, PI * 0.5) * Basis.from_scale(Vector3(along, k, deep))
	var front := -0.45 * deep
	ArtKit._add(root, "cloakroom_counter", Transform3D(turn, Vector3(-size.x * 0.5 - front, 0.0, -0.45)))
	return root


## A pilaster from the floor to the ceiling (base, shaft, capital), its back
## on the nearer wall of its room.
static func _pilaster(spec: PieceSpec, layout: LevelLayout) -> Node3D:
	var root := _holder("Visual")
	var size := spec.size
	var back := -1.0
	if layout != null:
		var room := layout.room(spec.room)
		if room != null and not room.parts.is_empty():
			var part := room.parts[0]
			back = 1.0 if absf(spec.position.z - part.position.y) < absf(spec.position.z - part.end.y) else -1.0
	# the models stand on the wall plane (z = 0) and reach toward -Z: turn
	# them to face away from the wall behind the piece
	var turn := Basis(Vector3.UP, PI) if back > 0.0 else Basis.IDENTITY
	var holder := Node3D.new()
	holder.transform = Transform3D(turn, Vector3(0.0, 0.0, -back * size.z * 0.5))
	root.add_child(holder)
	var shaft := size.y - 0.45 - 0.59
	ArtKit._add(holder, "hall_pilaster_base", Transform3D.IDENTITY)
	ArtKit._add(holder, "hall_pilaster_shaft", Transform3D(Basis.from_scale(Vector3(1.0, shaft, 1.0)), Vector3(0.0, 0.45, 0.0)))
	ArtKit._add(holder, "hall_pilaster_capital", Transform3D(Basis.IDENTITY, Vector3(0.0, size.y - 0.59, 0.0)))
	return root


## True when a balcony slab gets the hall's fascia and coffers (the court's
## ring slabs are the balcony models; its landings are plain stone).
static func wants_fascia(spec: PieceSpec) -> bool:
	return spec.room != &"court" and not BasementArt.is_basement(spec.room)


# --- fixtures and frames ---------------------------------------------------------

## The light fitting of fixture [param kit] in [param room] when Floor I
## fits its own (origin = the light), an empty holder where the piece next
## to it carries the lamp, or null (ArtKit's).
static func fixture(kit: StringName, room: StringName) -> Variant:
	var wing: Variant = wing_of(room)
	if wing != null:
		return wing.fixture(kit, room)
	var style: StringName = ROOM_STYLES.get(room, &"")
	if room == &"court_reading" and kit == &"desk_lamp":
		return _holder("Visual")   # the green lamps of rr_desk
	if room == &"egypt_gallery" and (kit == &"bulb" or kit == &"desk_lamp"):
		var lamp := _holder("Visual")
		ArtKit._add(lamp, "camp_lamp", Transform3D(Basis.IDENTITY, Vector3(0.0, -0.17, 0.0)))
		return lamp
	if String(style).begins_with("egypt_") and style != &"egypt_conservator" and kit == &"sconce":
		var torch := _holder("Visual")
		ArtKit._add(torch, "egypt_torch_lamp", Transform3D.IDENTITY)
		return torch
	if kit == &"egypt_spotlight":
		var spot := _holder("Visual")
		ArtKit._add(spot, "egypt_spotlight", Transform3D.IDENTITY)
		return spot
	return null


## Frames of a passage in its Door frame (see ArtKit.passage) when either
## room is a Floor I room: the opening's own portals (PORTALS), else each
## dressed room's best frame for the size, scaled, unless it would reach
## that room's ceiling. Returns a holder (empty: a bare opening).
static func passage(width: float, height: float, depth: float, room_a: StringName, room_b: StringName, opening_id: StringName) -> Variant:
	var root := _holder("Passage")
	for face in [1.0, -1.0]:
		var room := room_a if face > 0.0 else room_b
		if room == &"" or not ROOM_STYLES.has(room):
			continue
		var pick := _pick(opening_id, room, width, height)
		if pick.is_empty() or String(pick[0]) == "":
			continue
		var native: Vector2 = pick[1]
		var k := Vector3(width / native.x, height / native.y, 1.0)
		var model_h := bounds(String(pick[0])).size.y * k.y
		if _heights.has(room) and model_h > float(_heights[room]) + 0.01:
			continue
		var yaw := PI if face > 0.0 else 0.0
		var texture_set: String = pick[2] if pick.size() > 2 else ""
		ArtKit._add(root, String(pick[0]), Transform3D(Basis(Vector3.UP, yaw).scaled(k), Vector3(0, 0, face * depth * 0.5)), texture_set)
		if String(pick[0]) == "hall_arch_4m":
			ArtKit._add(root, "hall_door_reveal_4m", Transform3D(Basis.from_scale(Vector3(k.x, k.y, depth / 1.88)), Vector3.ZERO))
	return root


## How far the portal or frame on [param room]'s face of [param passage]
## reaches past the opening: (margin on each side, height over the floor of
## the opening), or zero when that face has none.
static func frame_extent(passage: OpeningSpec, room: StringName) -> Vector2:
	var pick := _pick(passage.id, room, passage.width(), passage.height())
	if passage.id in SEAL_PORTALS:
		pick = []
		for entry: Array in SEAL_PORTALS[passage.id]:
			if entry[0] == room:
				pick = [entry[1], entry[2]]
	if pick.is_empty() or String(pick[0]) == "":
		return Vector2.ZERO
	var native: Vector2 = pick[1]
	var k := Vector2(passage.width() / native.x, passage.height() / native.y)
	var box := bounds(String(pick[0]))
	if _heights.has(room) and box.size.y * k.y > float(_heights[room]) + 0.01:
		return Vector2.ZERO
	return Vector2(maxf((box.size.x * k.x - passage.width()) * 0.5, 0.0) + 0.1, box.end.y * k.y)


## The frame [model, native opening] on [param room]'s face of opening
## [param opening_id] ([] = none; a model "" = a bare opening).
static func _pick(opening_id: StringName, room: StringName, width: float, height: float) -> Array:
	if PORTALS.has(opening_id):
		var own: Dictionary = PORTALS[opening_id]
		return own.get(room, [])
	for wing: Variant in wings():
		var portals: Dictionary = wing.portals()
		if portals.has(opening_id):
			return (portals[opening_id] as Dictionary).get(room, [])
	return _frame_for(room, width, height)


## The style's frame that fits [width] x [height] best within
## FRAME_STRETCH: [model, native opening], or [].
static func _frame_for(room: StringName, width: float, height: float) -> Array:
	var s := ArtKit.style(room)
	var best: Array = []
	var best_d := INF
	for key: String in FRAME_KEYS:
		if not s.has(key):
			continue
		var native: Vector2 = FRAME_KEYS[key]
		var rx := width / native.x
		var ry := height / native.y
		if rx < FRAME_STRETCH.x or rx > FRAME_STRETCH.y or ry < FRAME_STRETCH.x or ry > FRAME_STRETCH.y:
			continue
		var d := absf(log(rx)) + absf(log(ry))
		if d < best_d:
			best_d = d
			best = [String(s[key]), native]
	return best


# --- the court's stairs -------------------------------------------------------------

## The court's flight in the stairs frame (StairsSpec.frame(): origin in the
## middle of the bottom front edge, -Z up the flight): limestone steps on
## an ashlar mass, solid raked parapets on the open sides.
static func court_stairs(flight: StairsSpec) -> Node3D:
	var root := _holder("Stairs")
	var width := flight.width()
	var rise := flight.top_y - flight.bottom_y
	var run_length := flight.run()
	var steps := flight.step_count()
	var r := rise / steps
	var t := run_length / steps
	for i in steps:
		ArtKit._add(root, "court_stair_step", Transform3D(Basis.from_scale(Vector3(width / 3.0, r / 0.15, t / 0.4)), Vector3(0.0, i * r, -i * t)))
	# the wedge under the steps (z -1..0 in its frame: from the foot up the run)
	ArtKit._add(root, "court_stair_mass", Transform3D(Basis.from_scale(Vector3(width, rise, run_length)), Vector3.ZERO))
	var modules := maxi(1, int(round(run_length / 4.0)))
	var seg := run_length / modules
	for side in [-1.0, 1.0]:
		if (side < 0.0 and not flight.rail_left) or (side > 0.0 and not flight.rail_right):
			continue
		for k in modules:
			var xf := Transform3D(Basis.from_scale(Vector3(1.0, rise / run_length * seg / 1.4894, seg / 4.0)), Vector3(side * (width * 0.5 + 0.16), k * rise / modules, -k * seg))
			ArtKit._add(root, "court_stair_parapet_4m", xf)
	return root


# --- hero pieces ------------------------------------------------------------------

## Adds the hero pieces of every dressed room (all when [param rooms] is
## empty) under [param parent], in world space.
static func dress(layout: LevelLayout, parent: Node3D, rooms: Dictionary = {}) -> void:
	var root := Node3D.new()
	root.name = "Floor1Heroes"
	parent.add_child(root)
	if _wants(rooms, &"court"):
		_court(layout, _group(root, "Court", &"court"))
	if _wants(rooms, &"court_reading"):
		_reading_room(layout, _group(root, "ReadingRoom", &"court_reading"))
	if _wants(rooms, &"entrance_hall"):
		_entrance(_group(root, "Entrance", &"entrance_hall"))
	if _wants(rooms, &"egypt_gallery"):
		_egypt_gallery(layout, _group(root, "EgyptGallery", &"egypt_gallery"))
	if _wants(rooms, &"egypt_colossus"):
		_egypt_colossus(layout, _group(root, "EgyptColossus", &"egypt_colossus"))
	_seal_portals(layout, root, rooms)
	BasementArt.dress(layout, root, rooms)
	for wing: Variant in wings():
		wing.dress(layout, root, rooms)


static func _wants(rooms: Dictionary, room: StringName) -> bool:
	return rooms.is_empty() or rooms.has(room)


## True when [param room] is dressed ([param rooms] empty: all are).
static func wants(rooms: Dictionary, room: StringName) -> bool:
	return _wants(rooms, room)


## A holder of the hero pieces of [param room] under [param parent]
## (meta "kit_room": the culling and the tests find its room).
static func group(parent: Node3D, label: String, room: StringName) -> Node3D:
	return _group(parent, label, room)


## Adds a decor process to [param root] for [param room] (culled with it).
static func decor(root: Node3D, process: Node, room: StringName) -> void:
	_decor(root, process, room)


## True for a gate (a GATE door) that does not look like one: it wears its
## wing's own leaves (gate_leaf) and no steel surround.
static func disguised_gate(opening_id: StringName) -> bool:
	for wing: Variant in wings():
		if (wing.disguised_gates() as Array).has(opening_id):
			return true
	return false


## The leaf of a disguised gate (see [method disguised_gate]) in Door's
## leaf frame, or null.
static func gate_leaf(opening_id: StringName, size: Vector3, side: float) -> Variant:
	for wing: Variant in wings():
		if (wing.disguised_gates() as Array).has(opening_id):
			return wing.gate_leaf(opening_id, size, side)
	return null


static func _group(parent: Node3D, label: String, room: StringName) -> Node3D:
	var n := Node3D.new()
	n.name = label
	n.set_meta(&"kit_room", room)
	parent.add_child(n)
	return n


## The glass roof (four quarters of the triangulated truss: the steel casts
## the lattice, the panes let the moon through) and the balcony's ring.
static func _court(_layout: LevelLayout, root: Node3D) -> void:
	for k in 4:
		ArtKit._add(root, "court_roof_q", Transform3D(Basis(Vector3.UP, deg_to_rad(90.0 * k)), Vector3.ZERO))
	for bearing in Court.RING:
		ArtKit._add(root, "court_balcony_seg", Transform3D(Basis(Vector3.UP, deg_to_rad(-bearing)), Vector3.ZERO))


## The drum (16 segments, a portal every 4), its bookcases and coffered dome
## with the oculus, the card catalogue's ring, the astrolabe (its rings turn
## slowly).
static func _reading_room(layout: LevelLayout, root: Node3D) -> void:
	for k in 16:
		var basis := Basis(Vector3.UP, deg_to_rad(22.5 * k))
		var door := k % 4 == 0
		ArtKit._add(root, "rr_drum_door" if door else "rr_drum_wall", Transform3D(basis, Vector3.ZERO))
		ArtKit._add(root, "rr_bookcase_door" if door else "rr_bookcase", Transform3D(basis, Vector3.ZERO))
		ArtKit._add(root, "rr_dome_sector", Transform3D(basis, Vector3.ZERO))
	ArtKit._add(root, "rr_oculus", Transform3D.IDENTITY)
	for spec in layout.pieces:
		if spec.kit == &"catalogue" and spec.room == &"court_reading":
			var bearing := rad_to_deg(atan2(spec.position.x, -spec.position.z))
			ArtKit._add(root, "rr_catalogue_arc", Transform3D(Basis(Vector3.UP, deg_to_rad(-bearing)), Vector3.ZERO))
	var astrolabe := ArtKit._add(root, "astrolabe", Transform3D.IDENTITY)
	astrolabe.add_to_group(ASTROLABE_GROUP)
	var parts := ArtLibrary.parts(astrolabe)
	var spinner := DecorSpinner.new()
	spinner.name = "AstrolabeRings"
	spinner.add(parts.get("ring_outer") as Node3D, Vector3.UP, 0.06)
	spinner.add(parts.get("ring_middle") as Node3D, Vector3.RIGHT, -0.09)
	spinner.add(parts.get("ring_inner") as Node3D, Vector3.FORWARD, 0.13)
	_decor(root, spinner, &"court_reading")


## The entrance hall's floor mosaic (MVSEVM MDCCLIII) between the benches.
static func _entrance(root: Node3D) -> void:
	ArtKit._add(root, "entrance_mosaic", Transform3D(Basis.from_scale(Vector3(0.68, 1.0, 0.68)), Vector3(0.0, 0.006, 42.0)))


## The Great Gallery: painted beams across the nave (the colossi's
## spotlights hang from them), a stone lattice laid in each light well (the
## moon falls through it in stripes), clerestory windows high in the east
## wall glowing with the night.
static func _egypt_gallery(layout: LevelLayout, root: Node3D) -> void:
	var gallery := layout.room(&"egypt_gallery")
	if gallery == null:
		return
	var part := gallery.parts[0]
	for z in Egypt.BEAMS_Z:
		var beam := Node3D.new()
		beam.name = "Beam"
		beam.position = Vector3(part.position.x, gallery.ceiling_y, z)
		root.add_child(beam)
		ArtKit.run(beam, "egypt_beam_", 0.0, part.size.x, 0.0)
	for well in gallery.skylights:
		_lattice(root, well, gallery.ceiling_y, well.size.y > well.size.x)
	for z in CLERESTORY_Z:
		_clerestory(root, Vector3(part.end.x, CLERESTORY_SILL, z))


## The Colossus hall's lattice: the 9 x 8 m well under a grid of 3 x 2 m
## stone lattices.
static func _egypt_colossus(layout: LevelLayout, root: Node3D) -> void:
	var hall := layout.room(&"egypt_colossus")
	if hall == null:
		return
	for well in hall.skylights:
		var nx := maxi(1, int(round(well.size.x / 3.0)))
		var nz := maxi(1, int(round(well.size.y / 2.0)))
		for i in nx:
			for j in nz:
				var cell := Rect2(well.position.x + i * well.size.x / nx, well.position.y + j * well.size.y / nz, well.size.x / nx, well.size.y / nz)
				_lattice(root, cell, hall.ceiling_y, false)


## One 3 x 2 m clerestory lattice laid flat in a ceiling opening [param
## cell] (world x, z) at [param ceiling_y], its face down into the room, its
## reveal lining the well; [param along_z]: the 3 m side runs along z.
static func _lattice(root: Node3D, cell: Rect2, ceiling_y: float, along_z: bool) -> void:
	var flat := Basis(Vector3.RIGHT, -PI * 0.5)
	if along_z:
		flat = Basis(Vector3.UP, PI * 0.5) * flat
	var long_side := cell.size.y if along_z else cell.size.x
	var short_side := cell.size.x if along_z else cell.size.y
	var basis := flat * Basis.from_scale(Vector3(long_side / 3.0, short_side / 2.0, LevelLayout.SKYLIGHT_WELL / 0.6))
	var centre := Vector3(cell.get_center().x, ceiling_y, cell.get_center().y)
	# the opening's middle (0, 1, 0) on the cell's middle, its face on the ceiling
	var at := centre - basis * Vector3(0.0, 1.0, 0.0)
	ArtKit._add(root, "egypt_clerestory_3m", Transform3D(basis, at))


## A clerestory window in a wall (its sill's middle at [param at] on the
## east wall's face): the lattice stands out of the wall by its reveal, the
## night glows behind the glass.
static func _clerestory(root: Node3D, at: Vector3) -> void:
	# front (-Z) to the room (west: -X); the reveal's back on the wall face
	var turn := Basis(Vector3.UP, PI * 0.5)
	var origin := at + turn * Vector3(0.0, 0.0, -0.6)
	var window := ArtKit._add(root, "egypt_clerestory_3m", Transform3D(turn, origin))
	window.name = "Clerestory"
	var glow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(3.0, 2.0)
	glow.mesh = quad
	glow.material_override = night_glass()
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# QuadMesh faces +Z: turned to face the room, just in front of the wall
	glow.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 1.0, 0.585))
	window.add_child(glow)


## The night behind a clerestory's glass: a cold glow that blooms a little.
static func night_glass() -> StandardMaterial3D:
	if _night_glass == null:
		_night_glass = StandardMaterial3D.new()
		_night_glass.resource_name = "night_glass"
		_night_glass.albedo_color = Color.BLACK
		_night_glass.emission_enabled = true
		_night_glass.emission = NIGHT_GLASS
		_night_glass.emission_energy_multiplier = 1.3
		_night_glass.roughness = 1.0
	return _night_glass


## The portals of the sealed gates (SealGate hides the gate's Door, frame
## and all): a classical arch both sides of the North Gate, the pylon on the
## Colossus hall's face of the Khorsabad Gate.
static func _seal_portals(layout: LevelLayout, root: Node3D, rooms: Dictionary) -> void:
	for opening_id: StringName in SEAL_PORTALS:
		var passage := layout.opening(opening_id)
		if passage == null:
			continue
		var frame := _passage_frame(layout, passage)
		for entry: Array in SEAL_PORTALS[opening_id]:
			var room: StringName = entry[0]
			if not _wants(rooms, room) or (passage.room_a != room and passage.room_b != room):
				continue
			var native: Vector2 = entry[2]
			var k := Vector3(passage.width() / native.x, passage.height() / native.y, 1.0)
			if _heights.has(room) and bounds(String(entry[1])).size.y * k.y > float(_heights[room]) + 0.01:
				continue
			var face := 1.0 if room == passage.room_a else -1.0
			var yaw := PI if face > 0.0 else 0.0
			var local := Transform3D(Basis(Vector3.UP, yaw).scaled(k), Vector3(0, 0, face * passage.depth() * 0.5))
			var portal := ArtKit._add(root, String(entry[1]), frame * local)
			portal.set_meta(&"kit_room", room)


## LevelBuilder.passage_frame without a builder: origin in the middle of the
## passage's floor, -Z from room A to room B.
static func _passage_frame(layout: LevelLayout, passage: OpeningSpec) -> Transform3D:
	var middle := passage.rect.get_center()
	var axis := Vector2(1, 0) if passage.runs_along_x() else Vector2(0, 1)
	var a := layout.room(passage.room_a)
	var nearest := middle
	if a != null:
		var best := INF
		for part in a.parts:
			var p := middle.clamp(part.position, part.end)
			if p.distance_to(middle) < best:
				best = p.distance_to(middle)
				nearest = p
	var a_to_b := -axis if (nearest - middle).dot(axis) > 0.0 else axis
	return Transform3D(Basis(Vector3.UP, atan2(-a_to_b.x, -a_to_b.y)), Vector3(middle.x, passage.floor_y, middle.y))


## Adds a decor process to [param root] for room [param room] (culled with
## the room).
static func _decor(root: Node3D, process: Node, room: StringName) -> void:
	process.set_meta(&"kit_room", room)
	process.add_to_group(DECOR_GROUP)
	root.add_child(process)
