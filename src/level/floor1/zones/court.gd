extends RefCounted
## Floor I zone "court" (design 5.7 and 6; plan docs/superpowers/plans/
## 2026-10-03-p1-w2-hub.md section 2.1): the Great Court, 60 x 60 m under
## the glass roof (y 22; the roof itself is stage P2's hero piece), round
## the Reading Room's drum, and the arena of the T-Rex finale.
## - court: the whole court. Doors: the entrance hall (south arch), Egypt
##   (west), the Enlightenment (east), the North Gate (north, Star Key).
## - court_reading (area reading_room): the Reading Room inside the drum,
##   a nested room added before the court (room_at: equal floors go to the
##   first room listed). Carved too, so the light model keeps its lamps and
##   the court's apart (the drum's walls are pieces; carving inside the
##   court changes nothing in the shell). Its only door is the north portal
##   with the Owl Seal gate (gate_reading_room); the crystal flies from the
##   astrolabe in the middle through that door to the T-Rex.
## - court_balcony: the balcony at y = 7 round the north half of the drum
##   (a room inside the court, not carved), reached by two straight flights
##   on the drum's flanks.
## The drum is 16 flat wall segments (vertex radius 12.5, outer face 12.26,
## inner face 11.2; art plan art-court). Bearings: degrees clockwise from
## north; segment j stands on bearing j * 22.5.

const ZONE := &"court"
const Grey := preload("res://src/level/floor1/floor1_greybox.gd")
const Hub := preload("res://src/level/floor1/zones/hub_kit.gd")
const CEILING := 22.0
const READING_CEILING := 20.0
const BALCONY_Y := 7.0
## The drum (art plan): vertex radius, outer and inner face (apothems).
const DRUM_RADIUS := 12.5
const DRUM_OUT := 12.26
const DRUM_IN := 11.2
## Outer side of a segment: 2 * 12.5 * sin(11.25 deg).
const SEGMENT := 4.877
## The north portal (the Owl Seal door): 3 m wide, 4.5 m high - the
## opening of the art's drum portal (rr_drum_door: jambs 0.94 m on a 4.88 m
## segment).
const PORTAL_WIDTH := 3.0
const PORTAL_HEIGHT := 4.5
## Bookcases inside (two storeys of shelves, art plan: 0..9.2 m), as deep
## as the drawn bookcase's lower storey (rr_bookcase: 0.55 m off the drum's
## inner face; the box stood 0.35 m proud of it, QA Q7).
const SHELF_DEPTH := 0.55
const SHELF_HEIGHT := 9.2
## The balcony ring: from the drum's face out to this apothem.
const BALCONY_OUT := 16.5
const SLAB := 0.4
## Bearings of the balcony's ring slabs (the ends are rectangular landings).
const RING: Array[float] = [-67.5, -45.0, -22.5, 0.0, 22.5, 45.0, 67.5]
## The two flights to the balcony: 19 m for 7 m (47 steps, 20.2 deg).
const STAIRS_W := Rect2(-18, 0, 3, 19)
const STAIRS_E := Rect2(15, 0, 3, 19)
## The T-Rex's pedestal north of the drum (12 x 1.2 x 6 m).
const PEDESTAL := Vector3(0, 0, -22.5)
const PEDESTAL_SIZE := Vector3(12, 1.2, 6)
## Radial desks of the Reading Room (bearings) and the steam exhibition.
const DESKS: Array[float] = [22.5, 67.5, 112.5, 247.5, 292.5, 337.5]
const GATLING := Vector3(0, 0, 8.6)
## The café (plan 2026-10-10-kawiarnia-zmeczenie): the counter in the
## north-west corner, its west end by the west wall and its back bar against
## the north wall, so the barista's aisle behind it (LevelKit.cafe_aisle: the
## kit splits the collision) has one way in, from the east, shut by the
## counter flap (CafeCorner lifts it). 2.6 m deep: the model's aisle grows
## to 1.14 m (Floor1Art._cafe_counter stretches it x1.14, within its limit).
const CAFE_AT := Vector3(-27.4, 0, -28.7)
const CAFE_SIZE := Vector3(5.1, 1.1, 2.6)
## The flap closing the aisle's east end, its front to the court.
const CAFE_FLAP_AT := Vector3(-24.6, 0, -28.84)
const CAFE_FLAP_SIZE := Vector3(1.14, 1.1, 0.5)
## On the counter's top: the espresso machine (its levers to the barista,
## -Z) and the chalk slate (to the court); on the back bar's top: the
## coffee urn (to the aisle). From the model's geometry (court_props.py
## cafe_counter, mirrored in x by the import and turned by Floor1Art: the
## cake case by the west wall, the machine at x -26.6, the till by the
## flap; the counter's top z -28.29..-27.41, the back bar's top z -29.99..
## -29.37 at 0.94); test_art_court checks them against the mesh.
const CAFE_MACHINE := Vector3(-26.58, 1.03, -28.0)
const CAFE_SLATE := Vector3(-27.05, 1.03, -27.74)
const CAFE_URN := Vector3(-26.4, 0.94, -29.55)
## Lamp posts on the court floor (warm pools of light).
const LAMP_POSTS: Array[Vector2] = [
	Vector2(-7, 27), Vector2(7, 27), Vector2(-26, 17.5), Vector2(26, -6),
	Vector2(-16, -26), Vector2(19, -21), Vector2(-21, 8), Vector2(14, 25.5),
]
## Exhibit posts on the court floor (each set uses most of them).
const SPOTS: Array[Vector2] = [
	Vector2(-4.5, 25.5), Vector2(4.5, 25.5), Vector2(-12, 22), Vector2(12, 22),
	Vector2(-22, 24), Vector2(-24, 13), Vector2(25, 16), Vector2(-8, 15),
	Vector2(8, 15), Vector2(-21, 5), Vector2(21, 4), Vector2(-26, 2),
	Vector2(-22, -8), Vector2(22, -10), Vector2(-27.5, -14), Vector2(25, -16),
	Vector2(-14, -22), Vector2(14, -24), Vector2(-9, -27), Vector2(9, -27),
	Vector2(-17, -12), Vector2(17, -13), Vector2(-3.5, -13.8), Vector2(3.5, -13.8),
]


static func build(layout: LevelLayout) -> void:
	_rooms(layout)
	_drum(layout)
	_reading_room(layout)
	_balcony(layout)
	_court_floor(layout)
	_finale(layout)
	_markers(layout)
	_encounters(layout)
	_lights(layout)
	_voice(layout)


# --- rooms ----------------------------------------------------------------

static func _rooms(layout: LevelLayout) -> void:
	var reading := Grey.room(layout, &"court_reading", reading_parts(), 0.0, READING_CEILING, ZONE, &"ROOM_COURT_READING", true, &"reading_room")
	reading.carved = true
	var court := Grey.box(layout, &"court", Grey.r(-30, -30, 30, 30), 0.0, CEILING, ZONE, &"ROOM_COURT")
	# the glass of the roof: wells in the slab over the court under the roof's
	# glass fields (zones/roof.gd), so the moon falls through the steel truss
	# (stage P2's hero roof hangs under them); the catwalks, the gutter and the
	# ring walk round the dome stay solid
	court.skylights.append_array(glass_fields())
	var balcony_parts: Array[Rect2] = [Grey.r(-12.5, -16.5, 12.5, -9), Grey.r(-18, -12, -12.5, 0), Grey.r(12.5, -12, 18, 0)]
	var balcony := Grey.room(layout, &"court_balcony", balcony_parts, BALCONY_Y, CEILING, ZONE, &"ROOM_COURT_BALCONY")
	balcony.carved = false
	var door := Grey.door(layout, &"court_reading_door", Grey.r(-PORTAL_WIDTH * 0.5, -12.5, PORTAL_WIDTH * 0.5, -11), 0.0, PORTAL_HEIGHT, &"court", &"court_reading", OpeningSpec.DoorStyle.GATE, RoomGraph.Kind.GATE)
	door.face_room = &"court"
	layout.add_gate(&"gate_reading_room", GateSpec.Kind.SEAL, &"court_reading_door", &"seal_owl", &"GATE_SEAL_OWL")
	var chain := layout.add_gate(&"chain_gatling", GateSpec.Kind.CHAIN, &"", GateSpec.HEAVY, &"GATE_CHAIN")
	chain.marker = &"gatling_case"


## The court's skylights: inside the roof's glass fields (an L in each
## quarter between the ring walk, 15.6 m out, and the gutter, 26.4 m; the
## radial catwalks 1.6 m either side of the axes), on the 0.5 m grid; the
## north-west field stops short of the roofers' shed.
static func glass_fields() -> Array[Rect2]:
	var fields: Array[Rect2] = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var far := 21.5 if sx < 0.0 and sz < 0.0 else 26.0
			fields.append(_quarter(sx, sz, 2.0, far, 16.0, 26.0))
			fields.append(_quarter(sx, sz, 16.0, 26.0, 2.0, 16.0))
	return fields


## The rectangle a..b along x and c..d along z mirrored into the quarter
## (sign [param sx], [param sz]).
static func _quarter(sx: float, sz: float, a: float, b: float, c: float, d: float) -> Rect2:
	var x0 := minf(sx * a, sx * b)
	var z0 := minf(sz * c, sz * d)
	return Rect2(x0, z0, b - a, d - c)


## The Reading Room's floor plan: bands inscribed in the drum's inner face
## (no band reaches outside the drum, so room_at never puts the court's
## floor in the Reading Room).
static func reading_parts() -> Array[Rect2]:
	var parts: Array[Rect2] = [Grey.r(-10.5, -3.5, 10.5, 3.5)]
	for side in [-1.0, 1.0]:
		parts.append(_band(side, 3.5, 6.0, 9.5))
		parts.append(_band(side, 6.0, 7.5, 7.5))
		parts.append(_band(side, 7.5, 9.5, 6.0))
		parts.append(_band(side, 9.5, 10.5, 3.5))
	return parts


static func _band(side: float, near: float, far: float, half: float) -> Rect2:
	if side < 0.0:
		return Grey.r(-half, -far, half, -near)
	return Grey.r(-half, near, half, far)


# --- the drum ---------------------------------------------------------------

static func _drum(layout: LevelLayout) -> void:
	var middle := (DRUM_OUT + DRUM_IN) * 0.5
	var thick := DRUM_OUT - DRUM_IN
	for j in 16:
		var bearing := j * 22.5
		var yaw := Hub.yaw_out(bearing)
		var at := Hub.at_bearing(middle, bearing)
		if j != 0:
			layout.add_piece(&"wall", at, Vector3(SEGMENT, CEILING, thick), &"court_reading", yaw)
			if j % 4 == 0:
				_blind_portal(layout, bearing)
			continue
		# the north portal: two jambs and the wall over the door
		var jamb := (SEGMENT - PORTAL_WIDTH) * 0.5
		for side in [-1.0, 1.0]:
			var x: float = side * (PORTAL_WIDTH + jamb) * 0.5
			layout.add_piece(&"wall", Vector3(x, 0, at.z), Vector3(jamb, CEILING, thick), &"court_reading", yaw)
		layout.add_piece(&"wall", Vector3(0, PORTAL_HEIGHT, at.z), Vector3(PORTAL_WIDTH, CEILING - PORTAL_HEIGHT, thick), &"court_reading", yaw)


## West, south and east portals stay shut (the art's bronze doors): the
## exhibition is entered only by the north door.
static func _blind_portal(layout: LevelLayout, bearing: float) -> void:
	for apothem in [DRUM_OUT + 0.06, DRUM_IN - 0.06]:
		var leaf := layout.add_piece(&"door_leaf", Hub.at_bearing(apothem, bearing), Vector3(PORTAL_WIDTH, PORTAL_HEIGHT, 0.1), &"court_reading", Hub.yaw_out(bearing), false)
		leaf.tint = Hub.BRONZE


# --- the Reading Room ---------------------------------------------------------

static func _reading_room(layout: LevelLayout) -> void:
	var room := &"court_reading"
	# bookcases round the wall, two storeys high (none at the north door)
	for j in range(1, 16):
		var bearing := j * 22.5
		layout.add_piece(&"shelf", Hub.at_bearing(DRUM_IN - SHELF_DEPTH * 0.5, bearing), Vector3(4.0, SHELF_HEIGHT, SHELF_DEPTH), room, Hub.yaw_in(bearing))
	# radial desks with green lamps; the catalogue ring round the astrolabe
	for bearing in DESKS:
		layout.add_piece(&"desk", Hub.at_bearing(6.5, bearing), Vector3(1.4, 0.78, 4.0), room, Hub.yaw_out(bearing))
	for bearing in [45.0, 135.0, 225.0, 315.0]:
		layout.add_piece(&"catalogue", Hub.at_bearing(3.2, bearing), Vector3(2.6, 1.1, 0.7), room, Hub.yaw_in(bearing))
	# the astrolabe's stepped base (art: three round steps of radius 2.2 /
	# 1.75 / 1.3 m, 0.16 m each): walked up on a ramp through their nosings
	layout.add_piece(&"dais", Vector3.ZERO, Vector3(4.4, 0.48, 4.4), room)
	layout.add_marker(&"astrolabe", Vector3(0, 0.3, 0), room)
	# "The Age of Steam and Steel": the chained gatling on the south axis,
	# seen from the north door past the astrolabe; the engine, a case
	layout.add_marker(&"gatling_case", GATLING, room)
	layout.add_piece(&"steam_engine", Hub.at_bearing(6.0, 220.0), Vector3(2.2, 2.6, 3.0), room, Hub.yaw_in(220.0))
	layout.add_piece(&"steam_banner", Vector3(0, 4.6, DRUM_IN - 0.96), Vector3(6, 1.5, 0.1), room, 0.0, false)
	var case_at := Hub.at_bearing(9.2, 150.0)
	layout.add_piece(&"case", case_at, Vector3(1.4, 1.6, 1.0), room, Hub.yaw_in(150.0))
	layout.add_loot(case_at + Vector3.UP, room, true)
	for spot in [Vector3(4.95, 0, -4.95), Vector3(-4.95, 0, -4.95), Vector3(9.0, 0, 2.0)]:
		layout.add_loot(spot, room)
	var desk := Hub.at_bearing(6.5, 292.5)
	layout.add_marker(&"note_court_2", Vector3(desk.x, 0.78, desk.z), room, Hub.yaw_in(292.5))
	Hub.look_marker(layout, &"cctv_court_3", Vector3(0, 9.5, 9.6), Vector3(0, 1.0, -6), room)


# --- the balcony and its stairs --------------------------------------------------

static func _balcony(layout: LevelLayout) -> void:
	var y := BALCONY_Y
	var depth := BALCONY_OUT - DRUM_OUT
	var outer := 2.0 * BALCONY_OUT * tan(deg_to_rad(11.25))
	for bearing in RING:
		# the slab is the court's (it stands in the court); its parapet the balcony's
		layout.add_piece(&"balcony", Hub.at_bearing(DRUM_OUT + depth * 0.5, bearing, y - SLAB), Vector3(outer, SLAB, depth), &"court", Hub.yaw_out(bearing))
		layout.add_piece(&"railing", Hub.at_bearing(BALCONY_OUT - 0.075, bearing, y), Vector3(outer, 1.1, 0.15), &"court_balcony", Hub.yaw_out(bearing))
		layout.add_piece(&"column", Hub.at_bearing(BALCONY_OUT - 0.6, bearing), Vector3(1.0, y - SLAB, 1.0), &"court")
	for side in [-1.0, 1.0]:
		# the landing where the flight arrives (x 12.26..18, z -3.5..0)
		var inner := DRUM_OUT
		var width := 18.0 - inner
		layout.add_piece(&"balcony", Vector3(side * (inner + width * 0.5), y - SLAB, -1.75), Vector3(width, SLAB, 3.5), &"court")
		layout.add_piece(&"railing", Vector3(side * 17.925, y, -1.75), Vector3(3.5, 1.1, 0.15), &"court_balcony", PI * 0.5)
		layout.add_piece(&"railing", Vector3(side * 17.25, y, -3.425), Vector3(1.5, 1.1, 0.15), &"court_balcony")
		layout.add_piece(&"railing", Vector3(side * (inner + 15.0) * 0.5, y, -0.075), Vector3(15.0 - inner, 1.1, 0.15), &"court_balcony")
		layout.add_piece(&"column", Vector3(side * 17.4, 0, -2.9), Vector3(1.0, y - SLAB, 1.0), &"court")
	for flight_rect in [STAIRS_W, STAIRS_E]:
		var flight := layout.add_stairs(&"court_stairs_w" if flight_rect == STAIRS_W else &"court_stairs_e", flight_rect, 0.0, y, Vector2(0, -1), &"court", &"court_balcony")
		flight.step_rise = Floor1Plan.STAIR_RISE
	var room := &"court_balcony"
	for bearing in [-45.0, 45.0]:
		layout.add_piece(&"bench", Hub.at_bearing(DRUM_OUT + 0.7, bearing, y), Vector3(2.4, 0.5, 0.6), room, Hub.yaw_out(bearing))
	layout.add_loot(Vector3(0, y, -15.5), room)
	layout.add_loot(Vector3(-16.5, y, -2.5), room)
	layout.add_loot(Vector3(10.5, y, -10.0), room)
	# the Lewis chessman: up here, by the drum, for the thorough
	layout.add_marker(&"chess_1", Vector3(-9.3, y, -9.3), room, Hub.yaw_out(-45.0))


# --- the court's floor -----------------------------------------------------------

static func _court_floor(layout: LevelLayout) -> void:
	var room := &"court"
	layout.add_piece(&"info_desk", Vector3(0, 0, 21), Vector3(8, 1.1, 2.4), room, PI)
	for x in [-9.0, 9.0]:
		layout.add_piece(&"bench", Vector3(x, 0, 24), Vector3(3, 0.5, 0.7), room)
	for x in [-21.0, 21.0]:
		layout.add_piece(&"bench", Vector3(x, 0, 13), Vector3(3, 0.5, 0.7), room)
	# the café in the north-west corner: the counter in the corner with the
	# barista's aisle behind it and the flap shutting the aisle; tables (cover)
	layout.add_piece(&"cafe_counter", CAFE_AT, CAFE_SIZE, room)
	layout.add_piece(&"cafe_flap", CAFE_FLAP_AT, CAFE_FLAP_SIZE, room, -PI * 0.5)
	for at in [Vector2(-25, -22), Vector2(-21.5, -22), Vector2(-25, -18.5), Vector2(-21.5, -18.5)]:
		layout.add_piece(&"cafe_table", Vector3(at.x, 0, at.y), Vector3(1.0, 0.75, 1.0), room)
	# the museum shop (closed: a grate over its window) in the south-east,
	# a dark corner behind it
	layout.add_piece(&"shop_front", Vector3(23, 0, 23.5), Vector3(6, 3.4, 5), room)
	layout.add_piece(&"grate", Vector3(23, 0.2, 20.95), Vector3(5.4, 2.8, 0.1), room, 0.0, false)
	# the Haida totem pole in the north-east corner (a wall to stun the T-Rex)
	layout.add_piece(&"totem", Vector3(24, 0, -24), Vector3(2, 12, 2), room)
	layout.add_piece(&"sculpture", Vector3(-23.5, 0, -1), Vector3(2.4, 4.5, 2.4), room)
	layout.add_piece(&"sculpture", Vector3(23.5, 0, 6.5), Vector3(2.4, 4.5, 2.4), room)
	for at in [Vector3(-29.2, 0, -12), Vector3(29.2, 0, 14)]:
		layout.add_piece(&"case", at, Vector3(1.4, 1.6, 1.0), room, PI * 0.5)
		layout.add_loot(at + Vector3.UP, room, true)
	for at in LAMP_POSTS:
		layout.add_piece(&"court_lamp_post", Vector3(at.x, 0, at.y), Vector3(0.5, 4.6, 0.5), room)
	layout.add_piece(&"court_map_board", Vector3(-8.5, 0, 25.5), Vector3(2.2, 2.4, 0.3), room, PI)
	for x in [-12.5, 12.5]:
		layout.add_piece(&"signpost", Vector3(x, 0, 28.5), Vector3(0.3, 2.8, 0.3), room)
	# (the café's box of loot stands on the back bar: a reason to go behind the counter)
	for spot in [Vector3(-25.9, 0.94, -29.42), Vector3(28, 0, 28), Vector3(-13.6, 0, 8), Vector3(13.6, 0, 8),
			Vector3(0, 0, -14.2), Vector3(-26, 0, -26), Vector3(26.5, 0, -27.5), Vector3(-28, 0, 28)]:
		layout.add_loot(spot, room)


# --- the finale --------------------------------------------------------------------

static func _finale(layout: LevelLayout) -> void:
	var room := &"court"
	layout.add_piece(&"pedestal", PEDESTAL, PEDESTAL_SIZE, room)
	# the T-Rex side on to the drum, facing east (as in the lobby)
	layout.add_marker(Floor1Plan.TREX_MARKER, PEDESTAL + Vector3.UP * PEDESTAL_SIZE.y, room, -PI * 0.5)
	# the crystal's flight: over the astrolabe, through the north door,
	# under the balcony's edge, into the T-Rex's ribs
	layout.add_marker(&"crystal_path_1", Vector3(0, 2.5, 0), &"court_reading")
	layout.add_marker(&"crystal_path_2", Vector3(0, 2.5, -11.75), room, PI)
	layout.add_marker(&"crystal_path_3", Vector3(0, 3.5, -16.5), room, PI)
	layout.add_marker(&"arena_trex_start", PEDESTAL + Vector3.UP * PEDESTAL_SIZE.y, room, -PI * 0.5)
	# the fight's supplies, like the lobby's: 1-4 when it starts, 5-6 at
	# phase 2 (one on the balcony), 7-9 at phase 3 (two on the landings)
	var supplies: Array[Vector3] = [
		Vector3(-11, 0, 19.5), Vector3(11, 0, 19.5), Vector3(0, 0, 25.5), Vector3(-25, 0, 9.5),
		Vector3(26, 0, 9.5), Vector3(0, BALCONY_Y, -14.6),
		Vector3(-15.5, BALCONY_Y, -1.8), Vector3(15.5, BALCONY_Y, -1.8), Vector3(-20, 0, -14),
	]
	for i in supplies.size():
		layout.add_marker(StringName("arena_trex_supply_%d" % (i + 1)), supplies[i], &"court_balcony" if supplies[i].y > 1.0 else room)
	# where a pack called by the roar runs in: the four corners
	var corners: Array[Vector2] = [Vector2(-27, 27), Vector2(27, -27.5), Vector2(-27.5, -23), Vector2(27, 27)]
	for i in corners.size():
		layout.add_marker(StringName("arena_trex_raptor_%d" % (i + 1)), Vector3(corners[i].x, 0, corners[i].y), room, Hub.facing(corners[i], Vector2.ZERO))
	# the court's doorways the fight shuts (-Z into the arena)
	layout.add_marker(&"arena_trex_door_1", Vector3(0, 0, 29.75), room)
	layout.add_marker(&"arena_trex_door_2", Vector3(-29.75, 0, 23), room, -PI * 0.5)
	layout.add_marker(&"arena_trex_door_3", Vector3(29.75, 0, 0), room, PI * 0.5)
	layout.add_marker(&"arena_trex_door_4", Vector3(0, 0, -29.75), room, PI)


# --- signs, notes, cameras, paintings ------------------------------------------------

static func _markers(layout: LevelLayout) -> void:
	var room := &"court"
	# wing signs over the doorways (the colour of the zone beyond) and
	# banners beside them
	Hub.wing_sign(layout, &"sign_egypt_1", Vector3(-29.96, 7.6, 23), 4.5, -PI * 0.5, room, &"egypt")
	Hub.wing_sign(layout, &"sign_enlightenment_1", Vector3(29.96, 7.6, 0), 4.5, PI * 0.5, room, &"enlightenment")
	Hub.wing_sign(layout, &"sign_north_hall_1", Vector3(0, 8.6, -29.96), 6.0, PI, room, &"north_hall")
	Hub.wing_sign(layout, &"sign_entrance_1", Vector3(0, 8.6, 29.96), 6.0, 0.0, room, &"entrance")
	var banners := [
		[Vector3(-29.9, 1.5, 17.6), -PI * 0.5, &"egypt"], [Vector3(-29.9, 1.5, 28.4), -PI * 0.5, &"egypt"],
		[Vector3(29.9, 1.5, -5.4), PI * 0.5, &"enlightenment"], [Vector3(29.9, 1.5, 5.4), PI * 0.5, &"enlightenment"],
		[Vector3(-6.4, 1.5, -29.9), PI, &"north_hall"], [Vector3(6.4, 1.5, -29.9), PI, &"north_hall"],
	]
	for entry: Array in banners:
		var banner := layout.add_piece(&"banner", entry[0], Vector3(1.4, 5.5, 0.1), room, entry[1], false)
		banner.tint = Floor1Plan.zone_color(entry[2])
	for i in 2:
		var x := -12.5 if i == 0 else 12.5
		layout.add_marker(StringName("signpost_court_%d" % (i + 1)), Vector3(x, 0, 28.5), room, PI)
	layout.add_marker(&"museum_map_court", Vector3(-8.5, 1.6, 25.33), room, PI)
	# the System's loudspeakers: high on the long walls, one at each end of the court
	layout.add_marker(&"loudspeaker_court_1", Vector3(-29.85, 3.2, 12.0), room, -PI * 0.5)
	layout.add_marker(&"loudspeaker_court_2", Vector3(29.85, 3.2, -12.0), room, PI * 0.5)
	# the café: a note on the counter's free top (between the machine and the
	# cake case), the machine, the slate and the urn (CafeCorner)
	layout.add_marker(&"note_court_1", Vector3(-27.6, 1.1, -27.85), room)
	layout.add_marker(&"cafe_machine", CAFE_MACHINE, room)
	layout.add_marker(&"cafe_slate", CAFE_SLATE, room, PI)
	layout.add_marker(&"cafe_urn", CAFE_URN, room, PI)
	# a hidden drawer under the information desk's counter (staff side)
	layout.add_marker(&"secret_court_1", Vector3(0, 0.3, 19.75), room)
	Hub.look_marker(layout, &"cctv_court_1", Vector3(29.4, 12, 29.4), Vector3(-6, 0, 4), room)
	Hub.look_marker(layout, &"cctv_court_2", Vector3(-29.4, 12, -29.4), PEDESTAL + Vector3.UP * 2.0, room)
	var portraits := [[Vector3(-29.99, 2.1, -6), -PI * 0.5], [Vector3(-29.99, 2.1, 7), -PI * 0.5], [Vector3(29.99, 2.1, -12), PI * 0.5], [Vector3(29.99, 2.1, 10.5), PI * 0.5]]
	for i in portraits.size():
		layout.add_marker(StringName("portrait_court_%d" % (i + 1)), portraits[i][0], room, portraits[i][1])


# --- encounters --------------------------------------------------------------------

static func _encounters(layout: LevelLayout) -> void:
	var room := &"court"
	var wax: Array[StringName] = [&"wax"]
	var bust: Array[StringName] = [&"bust"]
	var knight: Array[StringName] = [&"knight"]
	var raptor: Array[StringName] = [&"raptor"]
	var wolf: Array[StringName] = [&"wolf"]
	# set 0, the gentle first night: sleepers only (wax figures, a few
	# busts in the north) and one figure walking the south side
	Hub.slots(layout, room, 0, wax, SPOTS.slice(0, 16))
	Hub.slots(layout, room, 0, bust, SPOTS.slice(16, 22))
	Hub.walker(layout, &"court_south", room, 0, wax, PackedVector3Array([Vector3(-11, 0, 27.5), Vector3(11, 0, 27.5), Vector3(11, 0, 17), Vector3(-11, 0, 17)]))
	# set 1: the T-Rex's pack sleeps behind the pedestal and wakes when the
	# guard comes round the drum; knights about the porch
	Hub.slots(layout, room, 1, wax, SPOTS.slice(0, 12))
	Hub.slots(layout, room, 1, bust, SPOTS.slice(12, 18))
	var pack := Hub.slots(layout, room, 1, raptor, SPOTS.slice(18, 20))
	Hub.slots(layout, room, 1, knight, SPOTS.slice(20, 24))
	Hub.walker(layout, &"court_trex", room, 1, wax, PackedVector3Array([Vector3(-9, 0, -18), Vector3(9, 0, -18), Vector3(9, 0, -27.5), Vector3(-9, 0, -27.5)]))
	layout.add_ambush(AmbushSpec.on_area(&"court_trex_pack", room, Grey.r(-12, -30, 12, -17), -1.0, 4.0, pack))
	# set 2: wolves in the north corners, a figure walking round the drum
	Hub.slots(layout, room, 2, wax, SPOTS.slice(0, 14))
	Hub.slots(layout, room, 2, wolf, SPOTS.slice(14, 16))
	Hub.slots(layout, room, 2, bust, SPOTS.slice(16, 20))
	Hub.slots(layout, room, 2, knight, SPOTS.slice(20, 24))
	var ring := PackedVector3Array()
	for k in 8:
		ring.append(Hub.at_bearing(20.5, 22.5 + 45.0 * k))
	Hub.walker(layout, &"court_ring", room, 2, wax, ring)
	# the balcony
	var balcony := &"court_balcony"
	var y := BALCONY_Y
	var drum := Vector2.ZERO
	Hub.slots(layout, balcony, 0, wax, [Vector2(0, -14.4)], y, drum)
	Hub.slots(layout, balcony, 0, bust, [Vector2(-13.5, -6.5)], y, drum)
	Hub.slots(layout, balcony, 1, wax, [Vector2(9.5, -10.5), Vector2(-15, -2)], y, drum)
	var watch := Hub.slots(layout, balcony, 2, wax, [Vector2(-9.5, -10.5), Vector2(9.5, -10.5)], y, drum)
	layout.add_ambush(AmbushSpec.on_area(&"court_balcony_apex", balcony, Grey.r(-4, -16.5, 4, -12.5), y - 1.0, y + 2.5, watch))
	# the Reading Room: knights of "The Age of Steam and Steel" flank the
	# gatling every night and wake when it is taken
	var reading := &"court_reading"
	var stage: Array[int] = []
	for x in [-2.6, 2.6]:
		layout.add_spawn(Vector3(x, 0, 7.4), reading, SpawnSlot.ALWAYS_SET, knight, true, 0.0)
		stage.append(layout.spawn_slots.size() - 1)
	layout.add_ambush(AmbushSpec.on_pickup(&"court_gatling", reading, &"gatling_case", stage))
	var ne := Vector2(6.58, -6.58)
	var nw := Vector2(-6.58, -6.58)
	var se := Vector2(6.58, 6.58)
	var sw := Vector2(-6.58, 6.58)
	Hub.slots(layout, reading, 0, knight, [ne])
	Hub.slots(layout, reading, 0, wax, [nw])
	Hub.slots(layout, reading, 1, knight, [Vector2(-9.3, 0)])
	Hub.slots(layout, reading, 1, wax, [se])
	Hub.slots(layout, reading, 2, knight, [sw])
	Hub.slots(layout, reading, 2, wax, [Vector2(9.3, 0)])


# --- light -----------------------------------------------------------------------------

## Moon pools (the glass roof), warm lamp posts, the T-Rex's display spot,
## red lamps; dark on purpose: the corner behind the shop, the alleys by
## the drum, the porch under the balcony, the café's back. No court lamp
## reaches into the drum, no Reading Room lamp reaches out (test).
static func _lights(layout: LevelLayout) -> void:
	var main := LightSpec.MAIN
	var red := LightSpec.EMERGENCY
	var room := &"court"
	for i in LAMP_POSTS.size():
		var at := LAMP_POSTS[i]
		Hub.lamp(layout, main, Vector3(at.x, 4.4, at.y), Hub.WARM, 1.6, 10.0, room, &"", 0.0, i < 2)
	var moon := [
		[Vector3(-16, 21.5, 16), Vector3(-19, 0, 21)], [Vector3(17, 21.5, -14), Vector3(21, 0, -18)],
		[Vector3(-17, 21.5, -16), Vector3(-20, 0, -20)], [Vector3(16, 21.5, 13), Vector3(19, 0, 16)],
		[Vector3(0, 21.5, 23), Vector3(0, 0, 25.5)],
	]
	for pair: Array in moon:
		Hub.spot(layout, Hub.MOON_GROUP, pair[0], pair[1], Hub.MOON, 1.3, 30.0, 14.0, room)
	Hub.spot(layout, main, Vector3(12, 16, -12), PEDESTAL + Vector3.UP * 3.5, Hub.WARM, 10.0, 24.0, 22.0, room, true)
	Hub.lamp(layout, red, Vector3(0, 5.0, -14.0), Hub.RED, 1.0, 4.0, room, &"emergency_lamp", PI)
	Hub.lamp(layout, red, Vector3(-29.8, 4.5, -20), Hub.RED, 1.0, 6.0, room, &"emergency_lamp", -PI * 0.5)
	Hub.lamp(layout, red, Vector3(29.8, 4.5, 20), Hub.RED, 1.0, 6.0, room, &"emergency_lamp", PI * 0.5)
	# the balcony: sconces on the drum's face
	for bearing in [-67.5, -22.5, 22.5, 67.5]:
		Hub.lamp(layout, main, Hub.at_bearing(DRUM_OUT + 0.15, bearing, 9.6), Hub.WARM, 1.0, 7.0, &"court_balcony", &"sconce", Hub.yaw_in(bearing))
	# the Reading Room: green desk lamps, gallery lamps, the gatling's spot,
	# the moon through the oculus onto the astrolabe, a red lamp by the door
	var reading := &"court_reading"
	for bearing in DESKS:
		Hub.lamp(layout, main, Hub.at_bearing(6.5, bearing, 1.25), Hub.GREEN_SHADE, 0.8, 4.5, reading, &"desk_lamp", Hub.yaw_out(bearing))
	for bearing in [45.0, 135.0, 225.0, 315.0]:
		Hub.lamp(layout, main, Hub.at_bearing(9.6, bearing, 4.6), Hub.WARM, 0.9, 4.0, reading, &"sconce", Hub.yaw_in(bearing))
	Hub.spot(layout, main, Vector3(0, 8.0, 5.5), GATLING + Vector3.UP, Hub.WARM, 2.6, 8.5, 20.0, reading)
	Hub.spot(layout, Hub.MOON_GROUP, Vector3(0, 19.5, 0), Vector3.ZERO, Hub.MOON, 1.6, 21.0, 10.0, reading)
	Hub.lamp(layout, red, Vector3(0, 5.2, -10.2), Hub.RED, 0.9, 3.5, reading, &"emergency_lamp")

# --- the voice: the System's loudspeakers and the audio guide (plan 2026-10-19-glos-g2-kwestie) ---

## Two more loudspeakers on the court's south and north walls (beside the
## arches, over the floor's reach), stop 11 before the astrolabe (off the
## line from the door, between the catalogues and the desks) and stop 12 on
## the balcony, the T-Rex below it to the north.
static func _voice(layout: LevelLayout) -> void:
	layout.add_marker(&"loudspeaker_court_3", Vector3(-14.0, 3.6, 29.85), &"court", 0.0)
	layout.add_marker(&"loudspeaker_court_4", Vector3(14.0, 3.6, -29.85), &"court", PI)
	layout.add_marker(&"audioguide_astrolabe", Vector3(0.0, 0.0, -4.0), &"court_reading", 0.0)
	layout.add_marker(&"audioguide_trex", Vector3(4.6, BALCONY_Y, -14.5), &"court_balcony", 2.834)   # 1.2 m in from the railing, facing the drum
