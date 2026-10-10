extends RefCounted
## Floor I zone "enlightenment" (stage P1, workstream W5a; plan:
## docs/superpowers/plans/2026-10-03-p1-w5a-oswiecenie-azja.md). Dark oak,
## brass and green lampshades; warm pools and the long shadows of the
## bookcases, moon shafts through the library's roof.
## - The King's Library (14 x 70 m, 10 m high) along the Great Court: the
##   court door opens under the upper gallery's bridge into its middle and
##   the hall runs 35 m each way; display cases on the axis, globes at the
##   crossing, two tiers of bookcases, the upper gallery of bookcases at
##   y = 4 all round with a flight on the axis at each end (the loop).
## - Straight across from the court door, through the cabinet's arch: the
##   collector's RIFLE on its table in a warm spot (night 1, no gate).
## - The natural history cabinet (stuffed wolves and fossil raptors wake
##   when the rifle is taken), the clocks and automata (a rope-held grille
##   to the sealed archive), the collectors' portraits, the librarian's
##   office (haven) right by the court door.
## - The Planetarium rotunda (the Great Orrery's arena) behind a portcullis
##   whose counterweight hangs on a rope high under the dome, out of the
##   pistol's reach from anywhere outside: the rifle cuts it, best from the
##   observers' gallery halfway up the dome. Asia's bolted door opens into it.
## - The roof stairs climb from the upper gallery (y 4) past the observers'
##   gallery to the library loft (y 22.5) and the bolted door to the roof.
## - Under the library's south end the closed stacks and the bolted door to
##   the basement; the service stairs come up into the portraits.
## - Three secrets behind zone gates: the sealed archive (rope), the bindery
##   under the library (boards), Sloane's hidden study over the service
##   stairs (an iron ring on a bookcase of the upper gallery: the harpoon).
## Exhibits: flying books [wax, books], stuffed wolves [wolf], fossil
## raptors [raptor], automata [wax]; portraits on portrait_enlightenment_<n>.

const ZONE := &"enlightenment"
const Grey := preload("res://src/level/floor1/floor1_greybox.gd")
const Hub := preload("res://src/level/floor1/zones/hub_kit.gd")
const Kit := preload("res://src/level/floor1/zones/west_kit.gd")
const East := preload("res://src/level/floor1/zones/east_kit.gd")
const SWING := OpeningSpec.DoorStyle.SWING
const ALWAYS := SpawnSlot.ALWAYS_SET

## Stand-in kind first (NightSpawner falls back for unknown kinds), the
## intended one after it.
const BOOKS: Array[StringName] = [&"wax", &"books"]
const WOLF: Array[StringName] = [&"wolf"]
const RAPTOR: Array[StringName] = [&"raptor"]
const AUTOMATON: Array[StringName] = [&"wax"]

## Light recipe (design 10.1): warm lamps, green shades, brass, the moon.
const WARM := Color(1.0, 0.78, 0.5)
const BRASS_SPOT := Color(1.0, 0.86, 0.62)
const PICTURE := Color(1.0, 0.82, 0.6)
const HAVEN_LAMP := Color(1.0, 0.84, 0.62)

## The King's Library and its upper gallery of bookcases.
const LIBRARY := Rect2(31, -36, 14, 70)
const UPPER := 4.0
const SLAB := 0.4
## Lower bookcases (under the gallery) and upper ones (on it).
const CASE_LOW := 3.4
const CASE_HIGH := 3.5
const CASE_DEPTH := 0.5
## Display cases on the library's axis (x 38), clear of the crossing.
const AXIS := 38.0
const CASES_Z: Array[float] = [-17.5, -13.5, -9.5, -5.5, 5.5, 9.5, 13.5, 17.5]
## Posts under the gallery's inner edges.
const POSTS_Z: Array[float] = [-30.0, -20.0, -10.0, 10.0, 20.0, 30.0]
## The walls' runs of bookcases kept clear of the doorways (ranges along
## the wall): the lower tier on the floor, the upper one on the gallery.
const LOW_CLEAR_WEST: Array = [Vector2(-3.5, 3.5)]
const LOW_CLEAR_EAST: Array = [Vector2(-29.5, -23.5), Vector2(-7.0, -4.0), Vector2(-1.75, 1.75), Vector2(15.5, 20.0)]
const UP_CLEAR_WEST: Array = [Vector2(-3.5, 3.5)]
const UP_CLEAR_EAST: Array = [Vector2(-14.75, -12.0), Vector2(26.0, 29.0)]
## The bookcases' bays (stage P3 art, docs/art/kit-pietro1-oswiecenie.md
## 3.1): a 2 m case and a pilaster every BAY m, a 1 m case where a run needs
## it (BAY_SHORT); a run starts and ends with a pilaster (PILASTER wide).
## The upper gallery's sconces hang on these pilasters.
const BAY := 2.22
const BAY_SHORT := 1.22
const PILASTER := 0.32
## The cases may be stretched or squeezed this much to fill a run.
const BAY_STRETCH := 0.1
## The sconces' bulbs: on the upper tier's pilasters, a metre out from the
## wall; the warm lamps under the gallery hang on the lower pilasters.
const SCONCE_OUT := 1.0
const SCONCE_Y := UPPER + 2.7
const SCONCES_Z: Array[float] = [-24.0, -8.0, 8.0, 24.0]
## The standard lamps on the axis: between each globe's plinth and the
## nearest case (a 0.3 m gap).
const STANDARD_Z := 4.05
## Pendants in the 7 m cabinets: the bulb 1.25 m under the ceiling.
const PENDANT_Y := 5.75
## The roof stairs: six flights from the upper gallery to the roof; the
## observers' gallery leaves from the second landing at the north end.
const TOWER := Rect2(45.5, -14.5, 7, 12.5)
const TOWER_FLIGHTS := 6
const LOOKOUT_Y := UPPER + (Floor1Plan.ROOF_Y - UPPER) * 2.0 / TOWER_FLIGHTS
## The Great Orrery's post, the rifle on its table, the counterweight's
## bracket under the dome (the rope hangs 3..6 m over it).
const ORRERY := Vector3(55.25, 0.0, -26.5)
const RIFLE := Vector3(63.9, 0.9, 0.0)
const COUNTERWEIGHT := Vector3(63.5, 14.0, -34.0)


static func build(layout: LevelLayout) -> void:
	_rooms(layout)
	_doors(layout)
	_library(layout)
	_gallery(layout)
	_library_encounters(layout)
	_rotunda(layout)
	_tower_and_loft(layout)
	_librarian(layout)
	_clocks(layout)
	_cabinet(layout)
	_portraits(layout)
	_service(layout)
	_secrets(layout)


# --- the bookcases' rhythm (shared with the art) ------------------------------

## The runs of bookcases along a long wall of the library (z ranges from the
## north wall to the south one, minus [param clear], the doorways): one
## run per stretch of wall, whatever pieces the greybox cuts it into.
static func shelf_spans(clear: Array, from: float = LIBRARY.position.y, to: float = LIBRARY.end.y) -> Array[Vector2]:
	var free: Array[Vector2] = [Vector2(from, to)]
	for blocked: Vector2 in clear:
		var next: Array[Vector2] = []
		for span in free:
			if blocked.y <= span.x or blocked.x >= span.y:
				next.append(span)
				continue
			if blocked.x > span.x:
				next.append(Vector2(span.x, blocked.x))
			if blocked.y < span.y:
				next.append(Vector2(blocked.y, span.y))
		free = next
	return free.filter(func(span: Vector2) -> bool: return span.y - span.x >= 1.0)


## The bays of one run of bookcases from [param from] to [param to]:
## {"pilasters": [centre, ...], "cases": [[centre, 2.0 or 1.0, width], ...]}
## - a pilaster at both ends and between every two cases, a 2 m case per
## bay, 1 m cases at the ends where the length asks for them, all cases
## stretched alike (at most BAY_STRETCH) so the run fills its wall.
static func bays(from: float, to: float) -> Dictionary:
	var inner := to - from - PILASTER
	if inner < BAY_SHORT * (1.0 - BAY_STRETCH):
		return {"pilasters": [(from + to) * 0.5], "cases": []}
	var best := [0, 1, INF]
	for shorts in 4:
		var longs := maxi(0, int(round((inner - shorts * BAY_SHORT) / BAY)))
		if longs + shorts == 0:
			continue
		var stretch := inner / (longs * BAY + shorts * BAY_SHORT)
		var cost := absf(stretch - 1.0) + shorts * 0.01
		if cost < float(best[2]):
			best = [longs, shorts, cost]
	var longs: int = best[0]
	var shorts: int = best[1]
	var stretch := inner / (longs * BAY + shorts * BAY_SHORT)
	# the short bays at the ends (by the doorways), the long ones between
	var order: Array[float] = []
	for i in ceili(shorts * 0.5):
		order.append(BAY_SHORT)
	for i in longs:
		order.append(BAY)
	for i in shorts / 2:
		order.append(BAY_SHORT)
	var pilasters: Array = [from + PILASTER * 0.5]
	var cases: Array = []
	for bay in order:
		var start: float = pilasters[-1]
		var end := start + bay * stretch
		cases.append([(start + end) * 0.5, 2.0 if bay == BAY else 1.0, bay * stretch - (BAY - 2.0)])
		pilasters.append(end)
	return {"pilasters": pilasters, "cases": cases}


## The pilaster nearest [param at] among the runs of [param spans].
static func nearest_pilaster(spans: Array[Vector2], at: float) -> float:
	var best := at
	var best_d := INF
	for span in spans:
		for p: float in bays(span.x, span.y)["pilasters"]:
			if absf(p - at) < best_d:
				best_d = absf(p - at)
				best = p
	return best


# --- rooms and passages -----------------------------------------------------

static func _rooms(layout: LevelLayout) -> void:
	var library := Grey.box(layout, &"enlightenment_library", LIBRARY, 0.0, 10.0, ZONE, &"ROOM_ENLIGHTENMENT_LIBRARY")
	# moon shafts down the axis, one right over the crossing
	for z in [-26.0, -13.0, 0.0, 13.0, 26.0]:
		library.skylights.append(Grey.r(AXIS - 2.0, z - 2.0, AXIS + 2.0, z + 2.0))
	var gallery_parts: Array[Rect2] = [Grey.r(31, -36, 34, 34), Grey.r(42, -36, 45, 34), Grey.r(34, -36, 42, -33), Grey.r(34, 31, 42, 34)]
	var gallery := Grey.room(layout, &"enlightenment_library_gallery", gallery_parts, UPPER, 10.0, ZONE, &"ROOM_ENLIGHTENMENT_GALLERY")
	gallery.carved = false
	var rotunda := Grey.box(layout, &"enlightenment_planetarium", Grey.r(45.5, -38, 65, -15), 0.0, 22.0, ZONE, &"ROOM_ENLIGHTENMENT_PLANETARIUM", true, &"planetarium")
	rotunda.skylights.append(Grey.r(53, -28.5, 57.5, -24.5))
	var lookout := Grey.box(layout, &"enlightenment_observatory", Grey.r(45.5, -18, 52.5, -15), LOOKOUT_Y, 22.0, ZONE, &"ROOM_ENLIGHTENMENT_OBSERVATORY")
	lookout.carved = false
	Grey.tower(layout, &"enlightenment_roof_stairs", TOWER, UPPER, Floor1Plan.ROOF_Y, TOWER_FLIGHTS, 1, true, ZONE)
	Grey.box(layout, &"enlightenment_attic", Grey.r(31, -14.5, 45, -10), Floor1Plan.ROOF_Y, Floor1Plan.ROOF_Y + 3.0, ZONE, &"ROOM_ENLIGHTENMENT_ATTIC", false)
	var librarian := Grey.box(layout, &"enlightenment_librarian", Grey.r(45.5, -9, 52.5, -2.5), 0.0, 3.5, ZONE, &"ROOM_ENLIGHTENMENT_LIBRARIAN", false)
	librarian.haven = true
	Grey.box(layout, &"enlightenment_clocks", Grey.r(53, -14.5, 65, -2), 0.0, 7.0, ZONE, &"ROOM_ENLIGHTENMENT_CLOCKS")
	Grey.box(layout, &"enlightenment_cabinet", Grey.r(45.5, -1.5, 65, 14), 0.0, 7.0, ZONE, &"ROOM_ENLIGHTENMENT_CABINET")
	Grey.room(layout, &"enlightenment_portraits", [Grey.r(45.5, 14.5, 65, 21), Grey.r(51, 21, 65, 34)] as Array[Rect2], 0.0, 7.0, ZONE, &"ROOM_ENLIGHTENMENT_PORTRAITS")
	# the service stairs: two flights from the basement up into the
	# portraits; their top landing lies at the south end, over the door to
	# the closed stacks
	Grey.tower(layout, &"enlightenment_service_stairs", Grey.r(45.5, 21.5, 50.5, 33.5), Floor1Plan.BASEMENT_Y, 0.0, 2, 0, false, ZONE)
	Grey.box(layout, &"enlightenment_stacks", Grey.r(31, 25, 45, 33.5), Floor1Plan.BASEMENT_Y, Floor1Plan.BASEMENT_Y + 3.5, ZONE, &"ROOM_ENLIGHTENMENT_STACKS", false)
	for spec: Array in [
		[&"enlightenment_archive", Grey.r(45.5, -14.5, 52.5, -9.5), 0.0, 3.0, &"ROOM_ENLIGHTENMENT_ARCHIVE"],
		[&"enlightenment_bindery", Grey.r(31, 17, 38, 24.5), Floor1Plan.BASEMENT_Y, Floor1Plan.BASEMENT_Y + 3.0, &"ROOM_ENLIGHTENMENT_BINDERY"],
		[&"enlightenment_study", Grey.r(45.5, 21.5, 50.5, 33.5), UPPER, UPPER + 3.5, &"ROOM_ENLIGHTENMENT_STUDY"],
	]:
		var hidden := Grey.box(layout, spec[0], spec[1], spec[2], spec[3], ZONE, spec[4], false)
		hidden.secret = true


static func _doors(layout: LevelLayout) -> void:
	var library := &"enlightenment_library"
	var low := Floor1Plan.BASEMENT_Y
	# every ground doorway of the library stays under the gallery's slab
	Grey.door(layout, &"enlightenment_library_cabinet", Grey.r(45, -1.25, 45.5, 1.25), 0.0, 3.5, library, &"enlightenment_cabinet")
	Grey.door(layout, &"enlightenment_library_portraits", Grey.r(45, 16, 45.5, 19.5), 0.0, 3.5, library, &"enlightenment_portraits")
	Grey.door(layout, &"enlightenment_library_librarian", Grey.r(45, -6.5, 45.5, -4.5), 0.0, 2.6, library, &"enlightenment_librarian", SWING)
	# the portcullis: shut until the rope under the dome is cut; the rope
	# lock stands on its own marker (planetarium_counterweight)
	var portcullis := Grey.door(layout, &"enlightenment_planetarium_door", Grey.r(45, -29, 45.5, -24), 0.0, 3.5, library, &"enlightenment_planetarium", OpeningSpec.DoorStyle.GATE, RoomGraph.Kind.GATE)
	portcullis.face_room = library
	var rope := layout.add_gate(&"rope_planetarium", GateSpec.Kind.ROPE, &"enlightenment_planetarium_door", &"rifle_hunt", &"GATE_ROPE")
	rope.marker = &"planetarium_counterweight"
	# the roof stairs: from the upper gallery, to the observers' gallery
	# and to the library loft
	Grey.door(layout, &"enlightenment_gallery_tower", Grey.r(45, -14.25, 45.5, -12.5), UPPER, UPPER + 2.6, &"enlightenment_library_gallery", &"enlightenment_roof_stairs")
	Grey.door(layout, &"enlightenment_tower_observatory", Grey.r(46, -15, 48, -14.5), LOOKOUT_Y, LOOKOUT_Y + 2.6, &"enlightenment_roof_stairs", &"enlightenment_observatory")
	Grey.door(layout, &"enlightenment_tower_attic", Grey.r(45, -14.25, 45.5, -12.5), Floor1Plan.ROOF_Y, Floor1Plan.ROOF_Y + 2.5, &"enlightenment_roof_stairs", &"enlightenment_attic")
	Grey.door(layout, &"enlightenment_cabinet_clocks", Grey.r(57, -2, 60, -1.5), 0.0, 4.0, &"enlightenment_cabinet", &"enlightenment_clocks")
	Grey.door(layout, &"enlightenment_cabinet_portraits", Grey.r(57, 14, 61, 14.5), 0.0, 4.0, &"enlightenment_cabinet", &"enlightenment_portraits")
	# (room order: a swing door's leaf opens into room B, away from the
	# stairs' landings)
	Grey.door(layout, &"enlightenment_stairs_portraits", Grey.r(50.5, 31.75, 51, 33.25), 0.0, 2.6, &"enlightenment_service_stairs", &"enlightenment_portraits", SWING)
	# 2 m: the open leaf along its jamb leaves the exhibits' navmesh a way
	# through (at 1.5 m it did not: W7-2)
	Grey.door(layout, &"enlightenment_stairs_stacks", Grey.r(45, 31.5, 45.5, 33.5), low, low + 2.6, &"enlightenment_service_stairs", &"enlightenment_stacks", SWING)


# --- the King's Library ----------------------------------------------------------

static func _library(layout: LevelLayout) -> void:
	var room := &"enlightenment_library"
	# the lower tier of bookcases on every wall, clear of the doorways
	East.along_z(layout, &"shelf", 31.0, 1.0, -36.0, 34.0, 0.0, CASE_LOW, CASE_DEPTH, room, LOW_CLEAR_WEST)
	East.along_z(layout, &"shelf", 45.0, -1.0, -36.0, 34.0, 0.0, CASE_LOW, CASE_DEPTH, room, LOW_CLEAR_EAST)
	East.along_x(layout, &"shelf", -36.0, 1.0, 34.0, 42.0, 0.0, CASE_LOW, CASE_DEPTH, room)
	East.along_x(layout, &"shelf", 34.0, -1.0, 34.0, 42.0, 0.0, CASE_LOW, CASE_DEPTH, room)
	# posts under the gallery's inner edges (cover down the aisles)
	for z in POSTS_Z:
		for x in [33.75, 42.25]:
			layout.add_piece(&"balcony_post", Vector3(x, 0, z), Vector3(0.5, UPPER - SLAB, 0.5), room)
	# glass-topped cases of shells, minerals, coins and instruments on the
	# axis; a green reading lamp on every other one
	for z in CASES_Z:
		layout.add_piece(&"case", Vector3(AXIS, 0, z), Vector3(1.2, 1.1, 2.6), room)
	# (each banker's lamp stands on its case's end toward the crossing)
	for z: float in [-13.5, -5.5, 5.5, 13.5]:
		Hub.lamp(layout, LightSpec.MAIN, Vector3(AXIS, 1.41, z - signf(z) * 1.05), Hub.GREEN_SHADE, 0.7, 4.0, room, &"desk_lamp")
	# the terrestrial and the celestial globe frame the crossing
	for z in [-3.4, 3.4]:
		layout.add_piece(&"plinth", Vector3(AXIS, 0, z), Vector3(1.0, 0.9, 1.0), room)
		var globe := layout.add_piece(&"globe", Vector3(AXIS, 0.9, z), Vector3(1.2, 1.2, 1.2), room, 0.0, false)
		globe.tint = Color(0.62, 0.52, 0.3)
	# the two flights on the axis up to the end galleries
	var gallery := &"enlightenment_library_gallery"
	for spec: Array in [[&"enlightenment_library_stairs_n", Grey.r(36.5, -33, 39.5, -22), Vector2(0, -1)], [&"enlightenment_library_stairs_s", Grey.r(36.5, 20, 39.5, 31), Vector2(0, 1)]]:
		var flight := layout.add_stairs(spec[0], spec[1], 0.0, UPPER, spec[2], room, gallery)
		flight.step_rise = Floor1Plan.STAIR_RISE
	# light: warm pendants between the moon shafts, the moon through the
	# roof, two low standard lamps throwing the bookcases' long shadows down
	# the hall (they stand on the axis between the globes and the cases, in
	# gaps nobody walks through), red lamps by the court door and the
	# portcullis
	for z in [-31.0, -19.5, -6.5, 6.5, 19.5, 31.0]:
		Hub.lamp(layout, LightSpec.MAIN, Vector3(AXIS, 8.8, z), WARM, 1.3, 11.0, room, &"ceiling_lamp")
	for z in [-26.0, -13.0, 0.0, 13.0, 26.0]:
		Hub.spot(layout, Hub.MOON_GROUP, Vector3(AXIS, 11.0, z), Vector3(AXIS + 1.5, 0.0, z + 1.0), Hub.MOON, 1.2, 14.0, 16.0, room)
	for side in [-1.0, 1.0]:
		var standard := Hub.spot(layout, LightSpec.MAIN, Vector3(AXIS, 1.45, side * STANDARD_Z), Vector3(AXIS + side * 2.5, 0.0, side * 24.0), WARM, 3.0, 24.0, 32.0, room, true)
		standard.fixture = &"bulb"
	Kit.red(layout, Vector3(31.3, 3.0, 4.6), -PI * 0.5, room)
	Kit.red(layout, Vector3(44.7, 3.0, -30.2), PI * 0.5, room)
	Kit.camera(layout, &"cctv_enlightenment_1", Vector3(AXIS, 9.3, 33.3), Vector3(AXIS, 0.8, 0.0), room)
	layout.add_loot(Vector3(35.5, 0, -27.0), room)
	layout.add_loot(Vector3(40.5, 0, 25.5), room)
	layout.add_loot(Vector3(32.75, 0, -15.0), room)
	layout.add_loot(Vector3(AXIS, 1.1, -9.5), room, true)


## The upper gallery of bookcases: slabs all round at y 4, the upper tier
## of bookcases against the walls, railings on the inner edges (open where
## the flights arrive), sconces on the bookcases.
static func _gallery(layout: LevelLayout) -> void:
	var room := &"enlightenment_library_gallery"
	var under := UPPER - SLAB
	layout.add_piece(&"balcony", Vector3(32.5, under, -1.0), Vector3(3, SLAB, 70), room)
	layout.add_piece(&"balcony", Vector3(43.5, under, -1.0), Vector3(3, SLAB, 70), room)
	layout.add_piece(&"balcony", Vector3(AXIS, under, -34.5), Vector3(8, SLAB, 3), room)
	layout.add_piece(&"balcony", Vector3(AXIS, under, 32.5), Vector3(8, SLAB, 3), room)
	East.along_z(layout, &"shelf", 31.0, 1.0, -36.0, 34.0, UPPER, CASE_HIGH, CASE_DEPTH, room, UP_CLEAR_WEST)
	East.along_z(layout, &"shelf", 45.0, -1.0, -36.0, 34.0, UPPER, CASE_HIGH, CASE_DEPTH, room, UP_CLEAR_EAST)
	East.along_x(layout, &"shelf", -36.0, 1.0, 34.0, 42.0, UPPER, CASE_HIGH, CASE_DEPTH, room)
	East.along_x(layout, &"shelf", 34.0, -1.0, 34.0, 42.0, UPPER, CASE_HIGH, CASE_DEPTH, room)
	East.rail(layout, Vector3(34.0 - East.RAIL.x * 0.5, UPPER, -1.0), 64.0, true, room)
	East.rail(layout, Vector3(42.0 + East.RAIL.x * 0.5, UPPER, -1.0), 64.0, true, room)
	for x in [35.25, 40.75]:
		East.rail(layout, Vector3(x, UPPER, -33.0 + East.RAIL.x * 0.5), 2.5, false, room)
		East.rail(layout, Vector3(x, UPPER, 31.0 - East.RAIL.x * 0.5), 2.5, false, room)
	# the sconces hang on the upper bookcases' pilasters
	for z in SCONCES_Z:
		var west := nearest_pilaster(shelf_spans(UP_CLEAR_WEST), z)
		var east := nearest_pilaster(shelf_spans(UP_CLEAR_EAST), z)
		Hub.lamp(layout, LightSpec.MAIN, Vector3(31.0 + SCONCE_OUT, SCONCE_Y, west), WARM, 0.8, 6.0, room, &"sconce", -PI * 0.5)
		Hub.lamp(layout, LightSpec.MAIN, Vector3(45.0 - SCONCE_OUT, SCONCE_Y, east), WARM, 0.8, 6.0, room, &"sconce", PI * 0.5)
	layout.add_loot(Vector3(32.7, UPPER, 25.0), room)
	layout.add_loot(Vector3(43.3, UPPER, -25.0), room)


## Flying books all down the hall (stand-ins: wax figures), a figure
## walking the east aisle every night, wolves and raptors in sets 1-2; in
## set 2 the books by the crossing wake as the guard comes in.
static func _library_encounters(layout: LevelLayout) -> void:
	var room := &"enlightenment_library"
	var axis := Vector2(AXIS, 0.0)
	var aisle := PackedVector3Array([Vector3(40.5, 0, -19.0), Vector3(40.5, 0, 18.5)])
	layout.add_patrol(&"enlightenment_library_aisle", room, aisle, false)
	for set_id in 3:
		var walker := layout.add_spawn(aisle[0] if set_id != 1 else aisle[1], room, set_id, BOOKS.duplicate(), false)
		walker.patrol = &"enlightenment_library_aisle"
	Hub.slots(layout, room, 0, BOOKS.duplicate(), [Vector2(35.5, -28.0), Vector2(40.5, -15.0), Vector2(32.75, -6.0), Vector2(43.25, 8.0), Vector2(35.5, 22.0), Vector2(40.5, 27.0)], 0.0, axis)
	Hub.slots(layout, room, 1, BOOKS.duplicate(), [Vector2(40.5, -28.0), Vector2(35.5, -14.0), Vector2(43.25, -11.0), Vector2(32.75, 8.0), Vector2(35.5, 15.0)], 0.0, axis)
	Hub.slots(layout, room, 1, WOLF.duplicate(), [Vector2(35.5, 27.0)], 0.0, axis)
	Hub.slots(layout, room, 2, BOOKS.duplicate(), [Vector2(32.75, -27.0), Vector2(43.25, -18.0), Vector2(43.25, 22.0)], 0.0, axis)
	Hub.slots(layout, room, 2, RAPTOR.duplicate(), [Vector2(32.75, 18.0)], 0.0, axis)
	var crossing := Hub.slots(layout, room, 2, BOOKS.duplicate(), [Vector2(35.5, 6.5), Vector2(40.5, -6.0)], 0.0, axis)
	layout.add_ambush(AmbushSpec.on_area(&"enlightenment_reading", room, Grey.r(34, -3, 42, 3), -0.5, 3.0, crossing))
	# the upper gallery
	var gallery := &"enlightenment_library_gallery"
	Hub.slots(layout, gallery, 0, BOOKS.duplicate(), [Vector2(32.7, -20.0), Vector2(43.3, 0.0), Vector2(AXIS, -34.5)], UPPER, axis)
	Hub.slots(layout, gallery, 1, BOOKS.duplicate(), [Vector2(32.7, 12.0), Vector2(43.3, 20.0)], UPPER, axis)
	Hub.walker(layout, &"enlightenment_gallery_round", gallery, 1, BOOKS.duplicate(), PackedVector3Array([Vector3(32.7, UPPER, -30.0), Vector3(32.7, UPPER, 28.0)]), false)
	Hub.slots(layout, gallery, 2, BOOKS.duplicate(), [Vector2(43.3, -28.0), Vector2(32.7, -10.0), Vector2(AXIS, 32.5)], UPPER, axis)


# --- the Planetarium rotunda (arena) ----------------------------------------------

static func _rotunda(layout: LevelLayout) -> void:
	var room := &"enlightenment_planetarium"
	# the Great Orrery stands in the middle (the guardian brings it); a brass
	# ecliptic ring in the floor round it, nothing solid within 9 m
	layout.add_marker(&"guardian_planetarium", ORRERY, room, PI * 0.5)
	var ring := layout.add_piece(&"floor", ORRERY, Vector3(11.0, 0.02, 11.0), room, 0.0, false)
	ring.tint = Color(0.62, 0.5, 0.28)
	layout.add_marker(&"arena_planetarium_start", Vector3(48.5, 0, -26.5), room, -PI * 0.5)
	# its Star Key and shard: on the floor before it toward the door, clear of
	# its still arms
	layout.add_marker(&"arena_planetarium_reward", Vector3(49.0, 0, -26.5), room, -PI * 0.5)
	# arena doors: origin in the doorway (just inside), -Z into the arena, X
	# across it (a grille drops there for the fight)
	layout.add_marker(&"arena_planetarium_door_1", Vector3(45.75, 0, -26.5), room, -PI * 0.5)
	layout.add_marker(&"arena_planetarium_door_2", Vector3(50.0, 0, -37.75), room, PI)
	var supplies: Array[Vector3] = [Vector3(49.0, 0, -19.5), Vector3(61.5, 0, -19.0), Vector3(61.0, 0, -34.0)]
	for i in supplies.size():
		layout.add_marker(StringName("arena_planetarium_supply_%d" % (i + 1)), supplies[i], room)
	# instruments in the four corners: cover from the rolling planets
	for corner: Vector2 in [Vector2(47.5, -17.5), Vector2(63.0, -17.5), Vector2(63.0, -35.5), Vector2(47.5, -35.5)]:
		layout.add_piece(&"pedestal", Vector3(corner.x, 0, corner.y), Vector3(1.6, 1.2, 1.6), room)
		layout.add_piece(&"sculpture", Vector3(corner.x, 1.2, corner.y), Vector3(1.0, 2.0, 1.0), room, Hub.facing(corner, Vector2(ORRERY.x, ORRERY.z)))
	# the counterweight's bracket high on the east wall under the dome: the
	# rope hangs from a pulley 6 m over it, out of the pistol's reach
	layout.add_piece(&"balcony", COUNTERWEIGHT + Vector3(0.25, -SLAB, 0.0), Vector3(2.5, SLAB, 2.0), room)
	var toward := Hub.facing(Vector2(COUNTERWEIGHT.x, COUNTERWEIGHT.z), Vector2(49.0, -16.5))
	layout.add_marker(&"planetarium_counterweight", COUNTERWEIGHT, room, toward)
	# light: the moon through the oculus onto the orrery, a warm spot that
	# throws its arms' shadows, brass sconces round the walls, a spot on the
	# counterweight, red lamps by both doors
	Hub.spot(layout, Hub.MOON_GROUP, Vector3(ORRERY.x, 21.6, ORRERY.z), ORRERY + Vector3.UP, Hub.MOON, 2.0, 25.0, 18.0, room)
	Hub.spot(layout, LightSpec.MAIN, Vector3(48.0, 19.5, -30.0), ORRERY + Vector3.UP * 2.5, BRASS_SPOT, 5.0, 26.0, 24.0, room, true)
	Hub.spot(layout, LightSpec.MAIN, Vector3(57.0, 21.4, -24.0), COUNTERWEIGHT + Vector3.UP * 4.5, BRASS_SPOT, 3.0, 18.0, 14.0, room)
	# (the sconces' bulbs 0.45 m out: their plates on the walls)
	for at: Array in [[Vector3(45.95, 5.0, -33.0), -PI * 0.5], [Vector3(45.95, 5.0, -20.0), -PI * 0.5], [Vector3(64.55, 5.0, -33.0), PI * 0.5], [Vector3(64.55, 5.0, -20.0), PI * 0.5], [Vector3(46.5, 5.0, -37.55), PI], [Vector3(60.0, 5.0, -37.55), PI], [Vector3(56.0, 5.0, -15.45), 0.0], [Vector3(62.0, 5.0, -15.45), 0.0]]:
		Hub.lamp(layout, LightSpec.MAIN, at[0], WARM, 1.0, 8.0, room, &"sconce", at[1])
	Kit.red(layout, Vector3(45.7, 3.9, -29.6), -PI * 0.5, room)
	Kit.red(layout, Vector3(53.0, 3.4, -37.8), PI, room)
	# the observers' gallery halfway up the dome: a slab off the roof stairs'
	# landing, a railing, the observers' log on a writing desk
	var lookout := &"enlightenment_observatory"
	layout.add_piece(&"balcony", Vector3(49.0, LOOKOUT_Y - SLAB, -16.5), Vector3(7, SLAB, 3), lookout)
	East.rail(layout, Vector3(49.0, LOOKOUT_Y, -18.0 + East.RAIL.x * 0.5), 7.0, false, lookout)
	East.rail(layout, Vector3(52.5 - East.RAIL.x * 0.5, LOOKOUT_Y, -16.5), 3.0, true, lookout)
	# (the desk stands against the west wall, clear of the door from the stairs)
	layout.add_piece(&"desk", Vector3(45.9, LOOKOUT_Y, -17.0), Vector3(1.2, 0.8, 0.6), lookout, PI * 0.5)
	layout.add_piece(&"telescope", Vector3(51.6, LOOKOUT_Y, -15.5), Vector3(0.5, 1.4, 0.5), lookout, 0.0, false)
	layout.add_marker(&"note_enlightenment_3", Vector3(45.9, LOOKOUT_Y + 0.8, -17.0), lookout, -PI * 0.5)
	layout.add_loot(Vector3(50.0, LOOKOUT_Y, -16.4), lookout)
	Hub.lamp(layout, LightSpec.MAIN, Vector3(45.8, LOOKOUT_Y + 1.11, -16.6), Hub.GREEN_SHADE, 0.6, 4.0, lookout, &"desk_lamp")


# --- the roof stairs and the library loft -------------------------------------------

static func _tower_and_loft(layout: LevelLayout) -> void:
	var tower := &"enlightenment_roof_stairs"
	for at in [Vector3(49.0, 9.4, -13.4), Vector3(49.0, 15.6, -13.4), Vector3(49.0, 24.9, -13.4), Vector3(49.0, 12.6, -3.1), Vector3(49.0, 18.8, -3.1)]:
		Hub.lamp(layout, LightSpec.MAIN, at, Hub.TUBE, 0.8, 7.0, tower, &"tube_lamp")
	Kit.red(layout, Vector3(45.7, UPPER + 2.9, -11.8), -PI * 0.5, tower)
	# the loft over the library: trusses, crates, a lantern; the bolted door
	# to the roof catwalks at its west end, the chess piece on a crate by it
	var loft := &"enlightenment_attic"
	var roof := Floor1Plan.ROOF_Y
	for x in [34.0, 37.5, 41.0]:
		layout.add_piece(&"beam", Vector3(x, roof + 2.7, -12.25), Vector3(0.3, 0.3, 4.5), loft, 0.0, false)
	layout.add_piece(&"crate", Vector3(33.5, roof, -13.8), Vector3(0.9, 0.8, 0.9), loft)
	layout.add_piece(&"crate", Vector3(43.0, roof, -10.6), Vector3(1.2, 1.0, 0.8), loft)
	layout.add_marker(&"chess_6", Vector3(33.5, roof + 0.8, -13.8), loft)
	layout.add_loot(Vector3(39.0, roof, -12.25), loft)
	layout.add_loot(Vector3(43.0, roof + 1.0, -10.6), loft, true)
	Hub.lamp(layout, LightSpec.MAIN, Vector3(38.0, roof + 2.5, -12.25), WARM, 0.7, 9.0, loft, &"bulb")
	Kit.red(layout, Vector3(31.3, roof + 2.6, -13.0), -PI * 0.5, loft)


# --- the librarian's office (haven) -----------------------------------------------

static func _librarian(layout: LevelLayout) -> void:
	var room := &"enlightenment_librarian"
	# (the door's leaf swings in along the north jamb: x 45.5..47.5 stays free)
	layout.add_piece(&"desk", Vector3(50.4, 0, -4.0), Vector3(1.8, 0.78, 0.9), room)
	layout.add_piece(&"chair", Vector3(50.4, 0, -4.9), Vector3(0.6, 1.0, 0.6), room, PI, false)
	layout.add_piece(&"shelf", Vector3(50.0, 0, -8.7), Vector3(3.0, 1.4, 0.5), room)
	layout.haven_spots[&"librarian"] = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(52.1, 0, -6.6))
	layout.add_marker(&"museum_map_librarian", Vector3(48.0, 1.6, -2.55), room)
	layout.add_marker(&"note_enlightenment_1", Vector3(50.0, 0.78, -3.9), room)
	layout.add_loot(Vector3(48.5, 0, -3.4), room)
	layout.add_light(LightSpec.HAVEN, Vector3(50.9, 1.09, -3.8), HAVEN_LAMP, 1.4, 6.0, room, &"desk_lamp", true)
	layout.add_light(LightSpec.HAVEN, Vector3(49.0, 3.1, -5.75), HAVEN_LAMP, 0.8, 7.0, room, &"bulb")


# --- the clocks and automata -----------------------------------------------------------

static func _clocks(layout: LevelLayout) -> void:
	var room := &"enlightenment_clocks"
	# longcase clocks along the east wall, a wall of clocks on the north,
	# the astronomical clock in the middle, the automaton writer at his desk
	for z in [-12.5, -10.0, -7.5, -5.0]:
		layout.add_piece(&"clock", Vector3(64.6, 0, z), Vector3(0.7, 2.5, 0.5), room, PI * 0.5)
	for x in [55.5, 58.0, 60.5, 63.0]:
		layout.add_piece(&"painting", Vector3(x, 3.0, -14.46), Vector3(1.0, 1.0, 0.08), room, PI, false)
	layout.add_piece(&"pedestal", Vector3(59.5, 0, -8.0), Vector3(2.0, 0.6, 2.0), room)
	layout.add_piece(&"clock", Vector3(59.5, 0.6, -8.0), Vector3(1.4, 3.8, 1.4), room)
	layout.add_piece(&"desk", Vector3(56.0, 0, -4.5), Vector3(1.4, 0.8, 0.8), room)
	# light: warm lamps, a spot through the astronomical clock's pendulums
	for x in [56.0, 62.0]:
		Hub.lamp(layout, LightSpec.MAIN, Vector3(x, PENDANT_Y, -8.25), WARM, 1.2, 9.0, room, &"ceiling_lamp")
	Hub.spot(layout, LightSpec.MAIN, Vector3(55.0, 6.6, -12.5), Vector3(59.5, 2.0, -8.0), WARM, 3.0, 12.0, 28.0, room, true)
	Kit.red(layout, Vector3(61.0, 3.6, -2.2), 0.0, room)
	layout.add_loot(Vector3(63.0, 0, -3.3), room)
	layout.add_loot(Vector3(56.0, 0.8, -4.5), room, true)
	# the writer wakes when the guard reaches the astronomical clock; a
	# book or another automaton by night
	var writer: Array[int] = []
	layout.add_spawn(Vector3(56.0, 0, -6.0), room, ALWAYS, AUTOMATON.duplicate(), true, PI)
	writer.append(layout.spawn_slots.size() - 1)
	layout.add_ambush(AmbushSpec.on_area(&"enlightenment_clockwork", room, Grey.r(56, -11, 63, -5), -0.5, 3.0, writer))
	Hub.slots(layout, room, 0, AUTOMATON.duplicate(), [Vector2(62.5, -12.0)], 0.0, Vector2(59.5, -8.0))
	Hub.slots(layout, room, 1, BOOKS.duplicate(), [Vector2(55.5, -12.0)], 0.0, Vector2(59.5, -8.0))


# --- the natural history cabinet (the rifle) --------------------------------------------

static func _cabinet(layout: LevelLayout) -> void:
	var room := &"enlightenment_cabinet"
	# the collector's rifle on a table before its rack, on the axis of the
	# court door (z 0 stays clear all the way across)
	layout.add_piece(&"shelf", Vector3(64.75, 0, 0.0), Vector3(2.4, 2.2, 0.5), room, PI * 0.5)
	layout.add_piece(&"desk", Vector3(RIFLE.x, 0, 0.0), Vector3(1.6, 0.9, 0.9), room, PI * 0.5)
	layout.add_marker(&"weapon_rifle_hunt", RIFLE, room, PI * 0.5)
	layout.add_marker(&"note_enlightenment_2", Vector3(RIFLE.x, 0.9, -0.55), room, PI * 0.5)
	layout.add_loot(Vector3(RIFLE.x, 0.9, 0.55), room, true)
	# specimen cabinets round the walls, antlers over them
	East.along_x(layout, &"shelf", -1.5, 1.0, 46.0, 64.0, 0.0, 2.2, 0.5, room, [Vector2(56.5, 60.5)])
	East.along_x(layout, &"shelf", 14.0, -1.0, 46.0, 64.5, 0.0, 2.2, 0.5, room, [Vector2(56.5, 61.5)])
	East.along_z(layout, &"shelf", 45.5, 1.0, 2.5, 13.5, 0.0, 2.2, 0.5, room)
	East.along_z(layout, &"shelf", 65.0, -1.0, 2.5, 13.5, 0.0, 2.2, 0.5, room)
	for x in [49.0, 53.0, 61.0]:
		layout.add_piece(&"painting", Vector3(x, 3.6, 13.96), Vector3(1.4, 0.9, 0.08), room, 0.0, false)
	# two dioramas: the wolves, the fossil raptors
	for x in [51.0, 59.0]:
		layout.add_piece(&"pedestal", Vector3(x, 0, 6.5), Vector3(5.0, 0.5, 3.0), room)
	for x in [49.8, 52.2]:
		layout.add_piece(&"sculpture", Vector3(x, 0.5, 6.5), Vector3(1.0, 1.2, 0.6), room, PI * 0.5)
	for x in [58.0, 60.0]:
		layout.add_piece(&"sculpture", Vector3(x, 0.5, 6.5), Vector3(0.8, 1.9, 0.8), room)
	# light: a warm spot on the rifle (its shadow on the rack), lamps over
	# the dioramas, a red lamp by the library's arch
	Hub.spot(layout, LightSpec.MAIN, Vector3(61.5, 5.0, 0.0), RIFLE, WARM, 4.0, 9.0, 26.0, room, true)
	for x in [51.0, 59.0]:
		Hub.lamp(layout, LightSpec.MAIN, Vector3(x, PENDANT_Y, 6.5), WARM, 1.1, 9.0, room, &"ceiling_lamp")
	Kit.red(layout, Vector3(45.7, 3.4, 2.0), -PI * 0.5, room)
	Kit.camera(layout, &"cctv_enlightenment_2", Vector3(46.2, 6.4, 13.4), RIFLE, room)
	layout.add_loot(Vector3(55.0, 0, 3.0), room)
	layout.add_loot(Vector3(47.5, 0, 11.0), room)
	# taking the rifle wakes a wolf and a raptor off their dioramas (every
	# night); a book or a third beast by night
	var woken: Array[int] = []
	woken.append_array(Hub.slots(layout, room, ALWAYS, WOLF.duplicate(), [Vector2(51.0, 9.5)], 0.0, Vector2(RIFLE.x, 0.0)))
	woken.append_array(Hub.slots(layout, room, ALWAYS, RAPTOR.duplicate(), [Vector2(59.0, 9.5)], 0.0, Vector2(RIFLE.x, 0.0)))
	layout.add_ambush(AmbushSpec.on_pickup(&"enlightenment_rifle", room, &"weapon_rifle_hunt", woken))
	Hub.slots(layout, room, 0, BOOKS.duplicate(), [Vector2(48.0, 3.5)], 0.0, Vector2(55.0, 0.0))
	Hub.slots(layout, room, 1, WOLF.duplicate(), [Vector2(62.5, 4.0)], 0.0, Vector2(55.0, 0.0))


# --- the collectors' portraits -----------------------------------------------------------

static func _portraits(layout: LevelLayout) -> void:
	var room := &"enlightenment_portraits"
	var portraits := [
		[Vector3(64.99, 2.1, 23.0), PI * 0.5], [Vector3(64.99, 2.1, 27.5), PI * 0.5], [Vector3(64.99, 2.1, 32.0), PI * 0.5],
		[Vector3(51.01, 2.1, 24.5), -PI * 0.5], [Vector3(51.01, 2.1, 28.5), -PI * 0.5],
		[Vector3(48.25, 2.1, 20.99), 0.0], [Vector3(48.5, 2.1, 14.51), PI], [Vector3(63.0, 2.1, 14.51), PI],
	]
	for i in portraits.size():
		var at: Vector3 = portraits[i][0]
		var yaw: float = portraits[i][1]
		layout.add_marker(StringName("portrait_enlightenment_%d" % (i + 1)), at, room, yaw)
		layout.add_piece(&"painting", at - Vector3.UP * 0.9, Vector3(1.4, 1.8, 0.08), room, yaw, false)
		# a picture light over each frame (a wall lamp: its plate on the wall)
		var out := Basis(Vector3.UP, yaw) * Vector3.FORWARD
		var picture := Hub.spot(layout, LightSpec.MAIN, at + Vector3.UP * 1.6 + out * 0.45, at, PICTURE, 0.9, 4.0, 40.0, room)
		picture.fixture = &"sconce"
		picture.fixture_yaw = yaw
	for z in [24.0, 30.0]:
		layout.add_piece(&"bench", Vector3(58.0, 0, z), Vector3(3.0, 0.5, 0.7), room, PI * 0.5)
	for x in [52.5, 63.5]:
		layout.add_piece(&"bust_plinth", Vector3(x, 0, 17.75), Vector3(0.7, 1.9, 0.7), room)
	Hub.lamp(layout, LightSpec.MAIN, Vector3(56.0, PENDANT_Y, 17.75), WARM, 1.0, 9.0, room, &"ceiling_lamp")
	Hub.lamp(layout, LightSpec.MAIN, Vector3(58.0, PENDANT_Y, 27.5), WARM, 1.0, 9.0, room, &"ceiling_lamp")
	Kit.red(layout, Vector3(45.7, 3.4, 20.3), -PI * 0.5, room)
	layout.add_loot(Vector3(63.5, 0, 33.0), room)
	layout.add_loot(Vector3(46.5, 0, 20.0), room)
	var middle := Vector2(58.0, 24.0)
	Hub.slots(layout, room, 0, BOOKS.duplicate(), [Vector2(48.5, 17.75), Vector2(54.5, 32.0)], 0.0, middle)
	Hub.slots(layout, room, 0, WOLF.duplicate(), [Vector2(60.5, 27.0)], 0.0, middle)
	Hub.slots(layout, room, 1, BOOKS.duplicate(), [Vector2(55.5, 19.5), Vector2(62.5, 22.5), Vector2(54.0, 26.0)], 0.0, middle)
	Hub.slots(layout, room, 2, BOOKS.duplicate(), [Vector2(48.5, 16.0)], 0.0, middle)
	Hub.slots(layout, room, 2, RAPTOR.duplicate(), [Vector2(62.0, 32.0)], 0.0, middle)


# --- the service stairs and the closed stacks ---------------------------------------------

static func _service(layout: LevelLayout) -> void:
	var stairs := &"enlightenment_service_stairs"
	var low := Floor1Plan.BASEMENT_Y
	Hub.lamp(layout, LightSpec.MAIN, Vector3(48.0, -0.8, 32.5), Hub.TUBE, 0.8, 7.0, stairs, &"tube_lamp")
	Hub.lamp(layout, LightSpec.MAIN, Vector3(48.0, 2.6, 22.5), Hub.TUBE, 0.8, 7.0, stairs, &"tube_lamp")
	Kit.red(layout, Vector3(45.7, low + 2.8, 31.4), -PI * 0.5, stairs)
	# the closed stacks under the library's south end: rows of rolling
	# shelves, the bolted door to the basement on the west (its leaf swings
	# in along x 31..32.5 by z 28), the stairs' door on the east
	var stacks := &"enlightenment_stacks"
	for x in [35.5, 38.5, 41.5]:
		layout.add_piece(&"shelf", Vector3(x, low, 29.0), Vector3(4.0, 2.4, 0.8), stacks, PI * 0.5)
	layout.add_piece(&"crate", Vector3(43.5, low, 26.0), Vector3(1.0, 0.9, 0.6), stacks)
	for x in [33.0, 43.0]:
		Hub.lamp(layout, LightSpec.MAIN, Vector3(x, low + 3.1, 29.0), Hub.TUBE, 0.7, 7.0, stacks, &"tube_lamp")
	Kit.red(layout, Vector3(31.3, low + 2.8, 27.3), -PI * 0.5, stacks)
	layout.add_loot(Vector3(33.0, low, 32.5), stacks)
	layout.add_loot(Vector3(43.5, low + 0.9, 26.0), stacks, true)
	Hub.slots(layout, stacks, 0, BOOKS.duplicate(), [Vector2(37.0, 32.5)], low, Vector2(38.0, 29.0))
	Hub.slots(layout, stacks, 1, WOLF.duplicate(), [Vector2(40.0, 26.0)], low, Vector2(38.0, 29.0))


# --- the three secrets ---------------------------------------------------------------

static func _secrets(layout: LevelLayout) -> void:
	var low := Floor1Plan.BASEMENT_Y
	# 1. the sealed archive under the roof stairs: a grille in the clocks
	#    room's west wall held by a counterweight rope (a precise shot)
	Kit.gate(layout, &"enlightenment_rope_archive", GateSpec.Kind.ROPE, GateSpec.PRECISE, &"GATE_ROPE", &"enlightenment_clocks_archive", Grey.r(52.5, -12.5, 53, -10.5), 0.0, 2.6, &"enlightenment_clocks", &"enlightenment_archive", OpeningSpec.DoorStyle.GATE)
	var archive := &"enlightenment_archive"
	layout.add_piece(&"shelf", Vector3(49.0, 0, -14.25), Vector3(6.0, 2.4, 0.5), archive)
	layout.add_piece(&"crate", Vector3(51.5, 0, -10.3), Vector3(0.9, 0.8, 0.9), archive)
	layout.add_loot(Vector3(51.5, 0.8, -10.3), archive, true)
	layout.add_loot(Vector3(46.5, 0, -10.2), archive)
	layout.add_marker(&"secret_enlightenment_1", Vector3(49.0, 0, -12.0), archive)
	Kit.glow(layout, Vector3(49.0, 2.7, -12.0), Hub.GREEN_SHADE, 0.9, archive)
	Kit.lair(layout, &"enlightenment_archive", archive, Vector3(48.0, 0, -11.0), BOOKS, Grey.r(45.5, -14.5, 52.5, -9.5))
	# 2. the bindery under the library, boarded up off the closed stacks
	Kit.gate(layout, &"enlightenment_boards_bindery", GateSpec.Kind.BOARDS, GateSpec.HEAVY, &"GATE_BOARDS", &"enlightenment_stacks_bindery", Grey.r(33, 24.5, 35.5, 25), low, 2.4, &"enlightenment_stacks", &"enlightenment_bindery", OpeningSpec.DoorStyle.DOUBLE_SWING)
	var bindery := &"enlightenment_bindery"
	layout.add_piece(&"crate", Vector3(32.0, low, 18.2), Vector3(1.4, 1.6, 1.0), bindery)   # the press
	layout.add_piece(&"desk", Vector3(36.0, low, 17.6), Vector3(2.4, 0.9, 0.9), bindery)
	layout.add_marker(&"note_enlightenment_4", Vector3(36.4, low + 0.9, 17.6), bindery)
	layout.add_loot(Vector3(35.4, low + 0.9, 17.6), bindery, true)
	layout.add_marker(&"secret_enlightenment_2", Vector3(34.5, low, 20.5), bindery)
	Kit.glow(layout, Vector3(34.5, low + 2.7, 20.5), WARM, 0.9, bindery)
	Kit.lair(layout, &"enlightenment_bindery", bindery, Vector3(36.5, low, 21.0), BOOKS, Grey.r(31, 17, 38, 22.5))
	# 3. Sloane's hidden study over the service stairs: an iron ring on a
	#    bookcase of the upper gallery (the harpoon pulls it out)
	Kit.gate(layout, &"enlightenment_hook_study", GateSpec.Kind.HOOK, &"harpoon", &"GATE_HOOK", &"enlightenment_gallery_study", Grey.r(45, 26.5, 45.5, 28.5), UPPER, 2.4, &"enlightenment_library_gallery", &"enlightenment_study", OpeningSpec.DoorStyle.GATE)
	var study := &"enlightenment_study"
	East.along_z(layout, &"shelf", 50.5, -1.0, 22.0, 33.0, UPPER, 2.4, 0.5, study)
	layout.add_piece(&"desk", Vector3(47.0, UPPER, 23.2), Vector3(1.6, 0.8, 0.8), study)
	layout.add_loot(Vector3(47.0, UPPER + 0.8, 23.2), study, true)
	layout.add_loot(Vector3(47.0, UPPER, 32.5), study)
	layout.add_marker(&"secret_enlightenment_3", Vector3(47.5, UPPER, 27.5), study)
	Kit.glow(layout, Vector3(47.5, UPPER + 3.2, 27.5), WARM, 1.0, study)
	Kit.lair(layout, &"enlightenment_study", study, Vector3(47.5, UPPER, 30.0), WOLF, Grey.r(45.5, 21.5, 50.5, 33.5), 0.0)
