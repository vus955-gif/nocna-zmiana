class_name LobbyLayout
## The museum lobby as data (design: etap-2-projekt section 5, deviations in
## docs/superpowers/plans/2026-09-30-etap-2b1-lobby.md). Metres, Y up,
## -Z = north, middle of the main hall = origin. Rectangles are
## Rect2(x0, z0, width, depth) on the 0.5 m grid. No build logic here:
## LevelBuilder turns this into nodes.

const BALCONY_Y := 6.0
const HALL_CEILING := 14.0
## The side balconies end where the stairs arrive; the flights run from
## there to STAIRS_FOOT_Z. 16 m for 6 m keeps the slope at 20.6 degrees:
## with 0.25 m navigation cells and a 0.1 m climb, Recast joins neighbouring
## cells only on slopes up to about 21.8 degrees.
const STAIRS_TOP_Z := 4.0
const STAIRS_FOOT_Z := 20.0
const STAIRS_RISE := 0.15
## Behind the grate: the undercroft, then stairs down into the dark (the
## end of the demo lies at their foot).
const STAIRWELL_FLOOR := -4.0

const HALL := Color(0.66, 0.6, 0.52)
const GALLERY := Color(0.62, 0.64, 0.68)
const ARMORY := Color(0.6, 0.46, 0.4)
const DIORAMA := Color(0.46, 0.55, 0.42)
const SERVICE := Color(0.46, 0.48, 0.52)
const STAFF := Color(0.5, 0.5, 0.46)
const SECURITY := Color(0.56, 0.54, 0.44)
const CLOSET := Color(0.52, 0.42, 0.32)
const SECRET := Color(0.5, 0.4, 0.56)
const UNDERCROFT := Color(0.3, 0.3, 0.33)

## Crystal candidate case markers (one per wing, the diorama, the hall).
const CRYSTAL_CASES: Array[StringName] = [&"crystal_case_gallery", &"crystal_case_armory", &"crystal_case_diorama", &"crystal_case_hall"]
## Wing -> its two fuse point markers.
const FUSE_POINTS := {
	&"A": [&"fuse_a_1", &"fuse_a_2"],
	&"B": [&"fuse_b_1", &"fuse_b_2"],
}
const WARM := Color(1.0, 0.78, 0.52)
const TUBE := Color(0.85, 0.95, 0.88)
const COOL := Color(0.6, 0.72, 1.0)
const RED := Color(1.0, 0.12, 0.08)

## Wall spots for paintings in the gallery (8) and over the side balconies
## (4); NightDirector turns 2-4 of them into portraits that wake.
const PORTRAIT_SPOTS: Array[StringName] = [
	&"portrait_1", &"portrait_2", &"portrait_3", &"portrait_4", &"portrait_5", &"portrait_6",
	&"portrait_7", &"portrait_8", &"portrait_9", &"portrait_10", &"portrait_11", &"portrait_12",
]
## Height of a painting's canvas centre over its floor.
const PORTRAIT_HEIGHT := 2.1

const SECRETS: Array[StringName] = [&"secret_painting", &"secret_vent", &"secret_plaque", &"secret_case", &"secret_notes", &"secret_closet"]
## Wall spots for plain scenic paintings that never wake (landscapes, seas,
## still lifes): a second row over the gallery's portraits and two on the
## north balcony wall. Marker origin = the canvas middle on the wall face,
## -Z into the room. Never the portrait spots.
const SCENE_SPOTS: Array[StringName] = [
	&"scene_1", &"scene_2", &"scene_3", &"scene_4", &"scene_5", &"scene_6",
	&"scene_7", &"scene_8", &"scene_9", &"scene_10",
]
const NOTES: Array[StringName] = [&"note_1", &"note_2", &"note_3"]


static func create() -> LevelLayout:
	var layout := LevelLayout.new()
	layout.id = &"lobby"
	_rooms(layout)
	_openings(layout)
	_hall(layout)
	_balcony(layout)
	_gallery(layout)
	_armory(layout)
	_diorama(layout)
	_corridors(layout)
	_security(layout)
	_hidden_rooms(layout)
	_lights(layout)
	_dressing(layout)
	return layout


## What NightDirector needs to know about the lobby [param layout]:
## the generic description plus crystal cases, fuse points, the rooms that
## must stay reachable and the spots that always hold an artifact.
static func describe(layout: LevelLayout) -> LevelDescription:
	var description := LevelDescription.from_layout(layout)
	description.crystal_cases = CRYSTAL_CASES.duplicate()
	for wing: StringName in FUSE_POINTS:
		var points: Array[StringName] = []
		points.assign(FUSE_POINTS[wing])
		description.fuse_points[wing] = points
	var objectives: Array[StringName] = [&"hall"]
	var objective_markers: Array[StringName] = [&"fuse_box", &"grate"]
	objective_markers.append_array(CRYSTAL_CASES)
	for wing: StringName in description.fuse_points:
		objective_markers.append_array(description.fuse_points[wing])
	for marker in objective_markers:
		var room := description.room_of(marker)
		if room != &"" and not objectives.has(room):
			objectives.append(room)
	description.objective_rooms = objectives
	description.boss_room = &"hall"
	description.portrait_spots = PORTRAIT_SPOTS.duplicate()
	var locked_case: Vector3 = (layout.markers[&"secret_case"] as Transform3D).origin
	for i in layout.loot_spots.size():
		var spot := layout.loot_spots[i]
		if spot.container and (spot.room == &"secret_chamber" or spot.position.distance_to(locked_case) < 0.1):
			description.always_artifact_spots.append(i)
	return description


static func _r(x0: float, z0: float, x1: float, z1: float) -> Rect2:
	return Rect2(x0, z0, x1 - x0, z1 - z0)


static func _rooms(layout: LevelLayout) -> void:
	var hall := layout.add_room(&"hall", [_r(-18, -22, 18, 22)] as Array[Rect2], 0.0, HALL_CEILING, HALL)
	# three roof lights along the hall; moonlight falls on the T-Rex and the floor
	for x in [-5.0, 0.0, 5.0]:
		hall.skylights.append(_r(x - 1.5, -17, x + 1.5, 13))
	var balcony := layout.add_room(&"balcony", [_r(-18, -22, -14, STAIRS_TOP_Z), _r(-14, -22, 14, -18), _r(14, -22, 18, STAIRS_TOP_Z)] as Array[Rect2], BALCONY_Y, HALL_CEILING, HALL)
	balcony.carved = false
	layout.add_room(&"gallery", [_r(-40, -14, -20, 14)] as Array[Rect2], 0.0, 7.0, GALLERY)
	layout.add_room(&"armory", [_r(20, -14, 40, 14)] as Array[Rect2], 0.0, 7.0, ARMORY)
	layout.add_room(&"diorama", [_r(-14, 24, 14, 44)] as Array[Rect2], 0.0, 8.0, DIORAMA)
	layout.add_room(&"corridor_w", [_r(-34, 14.5, -30, 30), _r(-30, 26, -14.5, 30)] as Array[Rect2], 0.0, 3.5, SERVICE)
	layout.add_room(&"corridor_e", [_r(30, 14.5, 34, 30), _r(14.5, 26, 30, 30)] as Array[Rect2], 0.0, 3.5, SERVICE)
	layout.add_room(&"staff_corridor", [_r(-1.5, 44.5, 1.5, 53.5)] as Array[Rect2], 0.0, 3.0, STAFF)
	var security := layout.add_room(&"security", [_r(-5, 54, 5, 62)] as Array[Rect2], 0.0, 3.0, SECURITY)
	security.haven = true
	var closet := layout.add_room(&"closet", [_r(-2, -26, 2, -23)] as Array[Rect2], BALCONY_Y, 9.0, CLOSET)
	closet.haven = true
	closet.secret = true
	var chamber := layout.add_room(&"secret_chamber", [_r(-44, 4, -41, 9)] as Array[Rect2], 0.0, 3.2, SECRET)
	chamber.secret = true
	var niche := layout.add_room(&"shotgun_niche", [_r(41, -2.5, 43.5, 2.5)] as Array[Rect2], 0.0, 3.0, SECRET)
	niche.secret = true
	# service shaft: a strip behind the hall's south wall, then a climbing
	# slot between the hall and the gallery up to the west balcony
	var vent := layout.add_room(&"vent", [_r(-19.5, 22.5, -12, 23.5), _r(-19.5, 3, -18.5, 22.5)] as Array[Rect2], 0.0, 8.4, SERVICE.darkened(0.2))
	vent.secret = true
	layout.add_room(&"undercroft", [_r(-3, -26, 3, -22.5)] as Array[Rect2], 0.0, 5.0, UNDERCROFT)
	layout.add_room(&"stairwell", [_r(-2, -38, 2, -26.5)] as Array[Rect2], STAIRWELL_FLOOR, 2.6, UNDERCROFT.darkened(0.4))


static func _openings(layout: LevelLayout) -> void:
	# grand double doors from the hall (4 m wide, through 2 m of wall)
	layout.add_opening(&"door_hall_gallery", _r(-20, -2, -18, 2), 0.0, 4.5, &"hall", &"gallery", OpeningSpec.DoorStyle.DOUBLE_SWING, RoomGraph.Kind.LOCKABLE)
	layout.add_opening(&"door_hall_armory", _r(18, -2, 20, 2), 0.0, 4.5, &"hall", &"armory", OpeningSpec.DoorStyle.DOUBLE_SWING, RoomGraph.Kind.LOCKABLE)
	layout.add_opening(&"door_hall_diorama", _r(-2, 22, 2, 24), 0.0, 4.5, &"hall", &"diorama", OpeningSpec.DoorStyle.DOUBLE_SWING, RoomGraph.Kind.OPEN)
	# technical corridors: sliding service doors
	layout.add_opening(&"door_gallery_corridor", _r(-33, 14, -31, 14.5), 0.0, 2.8, &"gallery", &"corridor_w", OpeningSpec.DoorStyle.SLIDE, RoomGraph.Kind.LOCKABLE)
	layout.add_opening(&"door_corridor_w_diorama", _r(-14.5, 27, -14, 29), 0.0, 2.8, &"corridor_w", &"diorama", OpeningSpec.DoorStyle.SLIDE, RoomGraph.Kind.LOCKABLE)
	layout.add_opening(&"door_armory_corridor", _r(31, 14, 33, 14.5), 0.0, 2.8, &"armory", &"corridor_e", OpeningSpec.DoorStyle.SLIDE, RoomGraph.Kind.LOCKABLE)
	layout.add_opening(&"door_corridor_e_diorama", _r(14, 27, 14.5, 29), 0.0, 2.8, &"corridor_e", &"diorama", OpeningSpec.DoorStyle.SLIDE, RoomGraph.Kind.LOCKABLE)
	# staff route to the security room
	layout.add_opening(&"door_diorama_staff", _r(-1, 44, 1, 44.5), 0.0, 2.6, &"diorama", &"staff_corridor", OpeningSpec.DoorStyle.SWING, RoomGraph.Kind.OPEN)
	layout.add_opening(&"door_staff_security", _r(-1, 53.5, 1, 54), 0.0, 2.6, &"staff_corridor", &"security", OpeningSpec.DoorStyle.SWING, RoomGraph.Kind.OPEN)
	# the grate to the undercroft (opens after the boss, stage 2c)
	var grate := layout.add_opening(&"grate", _r(-3, -22.5, 3, -22), 0.0, 5.0, &"hall", &"undercroft", OpeningSpec.DoorStyle.GATE, RoomGraph.Kind.GATE)
	grate.face_room = &"hall"
	# beyond the grate: an arch to the stairs down
	var arch := layout.add_opening(&"undercroft_arch", _r(-2, -26.5, 2, -26), 0.0, 2.6, &"undercroft", &"stairwell")
	arch.exit_signs = false   # no way out down there
	# false panels
	var closet := layout.add_opening(&"panel_closet", _r(-1, -23, 1, -22), BALCONY_Y, BALCONY_Y + 2.2, &"balcony", &"closet", OpeningSpec.DoorStyle.PANEL, RoomGraph.Kind.SECRET)
	closet.face_room = &"balcony"
	var painting := layout.add_opening(&"panel_painting", _r(-41, 5.5, -40, 7.5), 0.0, 2.4, &"gallery", &"secret_chamber", OpeningSpec.DoorStyle.PANEL, RoomGraph.Kind.SECRET)
	painting.face_room = &"gallery"
	painting.panel_kit = &"painting_panel"
	var plaque := layout.add_opening(&"panel_plaque", _r(40, -1, 41, 1), 0.0, 2.4, &"armory", &"shotgun_niche", OpeningSpec.DoorStyle.PANEL, RoomGraph.Kind.SECRET)
	plaque.face_room = &"armory"
	var vent_in := layout.add_opening(&"panel_vent_in", _r(-13.5, 23.5, -12, 24), 0.0, 2.2, &"diorama", &"vent", OpeningSpec.DoorStyle.PANEL, RoomGraph.Kind.SECRET)
	vent_in.face_room = &"diorama"
	vent_in.panel_kit = &"vent_grille"
	var vent_out := layout.add_opening(&"panel_vent_out", _r(-18.5, 3, -18, 4.5), BALCONY_Y, BALCONY_Y + 2.2, &"vent", &"balcony", OpeningSpec.DoorStyle.PANEL, RoomGraph.Kind.SECRET)
	vent_out.face_room = &"balcony"
	vent_out.panel_kit = &"vent_grille"


static func _hall(layout: LevelLayout) -> void:
	# stairs along the side walls, from the south up to the balcony ends
	var west := layout.add_stairs(&"stairs_w", _r(-18, STAIRS_TOP_Z, -14, STAIRS_FOOT_Z), 0.0, BALCONY_Y, Vector2(0, -1), &"hall", &"balcony")
	west.rail_left = false
	west.step_rise = STAIRS_RISE
	var east := layout.add_stairs(&"stairs_e", _r(14, STAIRS_TOP_Z, 18, STAIRS_FOOT_Z), 0.0, BALCONY_Y, Vector2(0, -1), &"hall", &"balcony")
	east.rail_right = false
	east.step_rise = STAIRS_RISE
	for x in [-10.0, 10.0]:
		for z in [-8.0, 8.0]:
			layout.add_piece(&"column", Vector3(x, 0, z), Vector3(1.6, HALL_CEILING, 1.6), &"hall")
	layout.add_piece(&"pedestal", Vector3(0, 0, -11), Vector3(12, 1.2, 6), &"hall")
	layout.add_piece(&"trex", Vector3(0, 1.2, -11), Vector3(11, 5, 3), &"hall")
	layout.add_piece(&"info_desk", Vector3(0, 0, 7.5), Vector3(8, 1.1, 3), &"hall")
	layout.add_piece(&"ticket_booth", Vector3(-9.5, 0, 15.5), Vector3(4.5, 2.8, 3.5), &"hall", PI)
	layout.add_piece(&"fuse_box", Vector3(4.5, 1.1, -21.85), Vector3(0.7, 0.9, 0.3), &"hall", PI, false)
	for spot in [Vector3(-4, 0, -3), Vector3(4, 0, -3)]:
		layout.add_piece(&"bench", spot, Vector3(3, 0.5, 0.7), &"hall")
	for spot in [Vector3(-4.5, 0, 14), Vector3(4.5, 0, 14)]:
		layout.add_piece(&"bench", spot, Vector3(3, 0.5, 0.7), &"hall")
	# cases under the side balconies; the east one is locked (secret 4)
	layout.add_piece(&"case", Vector3(-16.5, 0, -8), Vector3(1.4, 1.6, 1.0), &"hall", PI * 0.5)
	layout.add_piece(&"case", Vector3(16.5, 0, -6), Vector3(1.4, 1.6, 1.0), &"hall", -PI * 0.5)
	layout.add_piece(&"case", Vector3(16.5, 0, -14), Vector3(1.4, 1.6, 1.0), &"hall", -PI * 0.5)
	for side in [-1.0, 1.0]:
		for z in [-16.5, -11.0]:
			layout.add_piece(&"painting", Vector3(side * 17.95, 2.0, z), Vector3(3, 2, 0.08), &"hall", side * PI * 0.5, false)
	for x in [-11.0, 11.0]:
		layout.add_piece(&"painting", Vector3(x, 1.8, -21.95), Vector3(3.5, 2.2, 0.08), &"hall", PI, false)
	layout.add_loot(Vector3(-16.5, 1.0, -8), &"hall", true)
	layout.add_loot(Vector3(16.5, 1.0, -6), &"hall", true)
	layout.add_loot(Vector3(16.5, 1.0, -14), &"hall", true)
	for spot in [Vector3(-13, 0, -6), Vector3(13, 0, -4), Vector3(0, 1.1, 7.5), Vector3(-9.5, 0, 18.5), Vector3(3, 0, 19), Vector3(-6, 0, -16.5)]:
		layout.add_loot(spot, &"hall")
	layout.add_marker(&"grate", Vector3(0, 0, -22), &"hall", PI)
	layout.add_marker(&"fuse_box", Vector3(4.5, 1.1, -21.7), &"hall", PI)
	layout.add_marker(&"ticket_drawer", Vector3(-9.5, 1.0, 17.3), &"hall", PI)
	layout.add_marker(&"secret_case", Vector3(16.5, 1.0, -14), &"hall", -PI * 0.5)
	# encounters: wax groups, a few wolves and knights
	var wax: Array[StringName] = [&"wax"]
	var wolf: Array[StringName] = [&"wolf"]
	var knight: Array[StringName] = [&"knight"]
	for spot in [Vector3(-5, 0, 3), Vector3(-3.5, 0, 4.5), Vector3(5, 0, 3), Vector3(3.5, 0, 4), Vector3(-8, 0, 12), Vector3(8, 0, 12)]:
		layout.add_spawn(spot, &"hall", 0, wax)
	layout.add_spawn(Vector3(-8, 0, -15.5), &"hall", 0, wolf)
	layout.add_spawn(Vector3(8, 0, -15.5), &"hall", 0, wolf, false)
	for spot in [Vector3(-10, 0, -5.5), Vector3(-7.5, 0, -6), Vector3(10, 0, -5.5), Vector3(12, 0, 10), Vector3(-12, 0, 10)]:
		layout.add_spawn(spot, &"hall", 1, wax)
	layout.add_spawn(Vector3(0, 0, -18.5), &"hall", 1, knight)
	# a raptor pack by the south benches ("Velociraptor - a pack")
	layout.add_spawn(Vector3(0, 0, 17), &"hall", 1, [&"raptor"] as Array[StringName])
	layout.add_spawn(Vector3(-12.5, 0, 0), &"hall", 1, wolf)
	layout.add_spawn(Vector3(12.5, 0, 0), &"hall", 1, wolf, false)
	for spot in [Vector3(-10, 0, 18.5), Vector3(-8.5, 0, 20), Vector3(-11.5, 0, 20.5), Vector3(8, 0, 19), Vector3(10, 0, 18.5), Vector3(9, 0, 20.5)]:
		layout.add_spawn(spot, &"hall", 2, wax)
	layout.add_spawn(Vector3(0, 0, 13), &"hall", 2, wax, false)
	layout.add_spawn(Vector3(-15.5, 0, -16), &"hall", 2, knight)
	layout.add_spawn(Vector3(0, 0, -4), &"hall", 2, [&"raptor"] as Array[StringName])
	layout.add_spawn(Vector3(15.5, 0, -16), &"hall", 2, knight)


static func _balcony(layout: LevelLayout) -> void:
	var y := BALCONY_Y
	var side_length := STAIRS_TOP_Z + 22.0
	var side_middle := (STAIRS_TOP_Z - 22.0) * 0.5
	layout.add_piece(&"balcony", Vector3(-16, y - 0.4, side_middle), Vector3(4, 0.4, side_length), &"balcony")
	layout.add_piece(&"balcony", Vector3(0, y - 0.4, -20), Vector3(28, 0.4, 4), &"balcony")
	layout.add_piece(&"balcony", Vector3(16, y - 0.4, side_middle), Vector3(4, 0.4, side_length), &"balcony")
	# parapets along the inner edges (the stair tops stay open)
	var rail_length := STAIRS_TOP_Z + 18.15
	var rail_middle := (STAIRS_TOP_Z - 18.15) * 0.5
	layout.add_piece(&"railing", Vector3(-14.075, y, rail_middle), Vector3(rail_length, 1.1, 0.15), &"balcony", PI * 0.5)
	layout.add_piece(&"railing", Vector3(0, y, -18.075), Vector3(28.3, 1.1, 0.15), &"balcony")
	layout.add_piece(&"railing", Vector3(14.075, y, rail_middle), Vector3(rail_length, 1.1, 0.15), &"balcony", PI * 0.5)
	# posts carrying the balcony edge
	for side in [-1.0, 1.0]:
		for z in [-18.4, -11.0, -4.0, 3.0]:
			layout.add_piece(&"balcony_post", Vector3(side * 14.4, 0, z), Vector3(0.6, y - 0.4, 0.6), &"hall")
		layout.add_piece(&"balcony_post", Vector3(side * 7.0, 0, -18.4), Vector3(0.6, y - 0.4, 0.6), &"hall")
	# the hall's crystal candidate stands on the west balcony
	layout.add_piece(&"crystal_case", Vector3(-16.9, y, -14), Vector3(1.2, 1.8, 1.2), &"balcony", -PI * 0.5)
	layout.add_marker(&"crystal_case_hall", Vector3(-16.9, y + 1.0, -14), &"balcony", -PI * 0.5)
	layout.add_piece(&"bench", Vector3(16.9, y, -8), Vector3(2.4, 0.5, 0.6), &"balcony", -PI * 0.5)
	layout.add_piece(&"desk", Vector3(16.8, y, -1), Vector3(0.8, 0.8, 1.4), &"balcony")
	layout.add_marker(&"note_3", Vector3(16.8, y + 0.8, -1), &"balcony", -PI * 0.5)
	layout.add_marker(&"secret_notes", Vector3(16.8, y + 0.8, -1), &"balcony", -PI * 0.5)
	layout.add_marker(&"secret_closet", Vector3(0, y, -22), &"balcony")
	# paintings over the side balconies, between the sconces
	var hung := 8
	for side in [-1.0, 1.0]:
		for z in [-12.0, -4.0]:
			layout.add_marker(PORTRAIT_SPOTS[hung], Vector3(side * 17.99, y + PORTRAIT_HEIGHT, z), &"balcony", side * PI * 0.5)
			hung += 1
	for spot in [Vector3(-16, y, -20), Vector3(16, y, -20.5), Vector3(5, y, -20.5)]:
		layout.add_loot(spot, &"balcony")
	var wax: Array[StringName] = [&"wax"]
	var wolf: Array[StringName] = [&"wolf"]
	var knight: Array[StringName] = [&"knight"]
	layout.add_spawn(Vector3(-16, y, -9.5), &"balcony", 0, wax)
	layout.add_spawn(Vector3(-16, y, -4), &"balcony", 0, wax)
	layout.add_spawn(Vector3(-6, y, -20), &"balcony", 0, wolf, false)
	layout.add_spawn(Vector3(15.5, y, -12), &"balcony", 0, knight)
	layout.add_spawn(Vector3(10, y, -20), &"balcony", 0, [&"raptor"] as Array[StringName])
	for spot in [Vector3(-3, y, -20), Vector3(3, y, -20), Vector3(8.5, y, -20.5)]:
		layout.add_spawn(spot, &"balcony", 1, wax)
	layout.add_spawn(Vector3(15.5, y, -4.5), &"balcony", 1, wolf, false)
	layout.add_spawn(Vector3(15.5, y, 2.5), &"balcony", 1, wolf)
	layout.add_spawn(Vector3(-9, y, -20), &"balcony", 2, knight)
	layout.add_spawn(Vector3(-15.5, y, 0), &"balcony", 2, wax)
	layout.add_spawn(Vector3(-16, y, -19.5), &"balcony", 2, wax)
	layout.add_spawn(Vector3(15.5, y, -16), &"balcony", 2, wolf, false)


static func _gallery(layout: LevelLayout) -> void:
	for x in [-34.0, -26.0]:
		for z in [-10.0, -5.0, 5.0, 10.0]:
			layout.add_piece(&"bust_plinth", Vector3(x, 0, z), Vector3(0.7, 1.9, 0.7), &"gallery")
	layout.add_piece(&"sculpture", Vector3(-30, 0, 0), Vector3(2.2, 4.5, 2.2), &"gallery")
	for z in [-7.5, 7.5]:
		layout.add_piece(&"bench", Vector3(-30, 0, z), Vector3(2.4, 0.5, 0.6), &"gallery")
	layout.add_piece(&"crystal_case", Vector3(-37.5, 0, 0), Vector3(1.2, 1.8, 1.2), &"gallery", PI * 0.5)
	layout.add_marker(&"crystal_case_gallery", Vector3(-37.5, 1.0, 0), &"gallery", PI * 0.5)
	for z in [-11.0, 11.0]:
		layout.add_piece(&"case", Vector3(-22.5, 0, z), Vector3(1.4, 1.6, 1.0), &"gallery", -PI * 0.5)
		layout.add_loot(Vector3(-22.5, 1.0, z), &"gallery", true)
	# fuse A: one of two crates at the west end
	layout.add_piece(&"crate", Vector3(-38.5, 0, -11.5), Vector3(0.9, 0.8, 0.9), &"gallery")
	layout.add_piece(&"crate", Vector3(-38.5, 0, 11.5), Vector3(0.9, 0.8, 0.9), &"gallery")
	layout.add_marker(&"fuse_a_1", Vector3(-38.5, 0.8, -11.5), &"gallery", PI * 0.5)
	layout.add_marker(&"fuse_a_2", Vector3(-38.5, 0.8, 11.5), &"gallery", PI * 0.5)
	for z in [-9.0, 10.0]:
		layout.add_piece(&"painting", Vector3(-39.95, 2.2, z), Vector3(2.4, 1.8, 0.08), &"gallery", -PI * 0.5, false)
	layout.add_marker(&"secret_painting", Vector3(-40, 0, 6.5), &"gallery", -PI * 0.5)
	# painting spots: north and south walls, and the wall to the hall (its
	# door between them); on the wall surface, a painting's -Z to the room
	var hung := 0
	for x in [-36.0, -30.0, -24.0]:
		layout.add_marker(PORTRAIT_SPOTS[hung], Vector3(x, PORTRAIT_HEIGHT, -13.99), &"gallery", PI)
		layout.add_marker(PORTRAIT_SPOTS[hung + 1], Vector3(x, PORTRAIT_HEIGHT, 13.99), &"gallery", 0.0)
		hung += 2
	for z in [-8.0, 8.0]:
		layout.add_marker(PORTRAIT_SPOTS[hung], Vector3(-20.01, PORTRAIT_HEIGHT, z), &"gallery", PI * 0.5)
		hung += 1
	for spot in [Vector3(-30, 0, 12.5), Vector3(-24, 0, -12.5), Vector3(-37.5, 0, -6)]:
		layout.add_loot(spot, &"gallery")
	var bust: Array[StringName] = [&"bust"]
	var wax: Array[StringName] = [&"wax"]
	for spot in [Vector3(-34, 0, -7.5), Vector3(-26, 0, -7.5), Vector3(-34, 0, 7.5)]:
		layout.add_spawn(spot, &"gallery", 0, bust)
	for spot in [Vector3(-24, 0, -3), Vector3(-24, 0, 3)]:
		layout.add_spawn(spot, &"gallery", 0, wax)
	for spot in [Vector3(-26, 0, 7.5), Vector3(-36, 0, -3)]:
		layout.add_spawn(spot, &"gallery", 1, bust)
	for spot in [Vector3(-30, 0, -11), Vector3(-27.5, 0, 11), Vector3(-32.5, 0, 11)]:
		layout.add_spawn(spot, &"gallery", 1, wax)
	for spot in [Vector3(-22.5, 0, -6), Vector3(-22.5, 0, 6), Vector3(-37, 0, -6.5), Vector3(-37, 0, 6.5)]:
		layout.add_spawn(spot, &"gallery", 2, wax)
	layout.add_spawn(Vector3(-30, 0, -3.5), &"gallery", 2, bust)


static func _armory(layout: LevelLayout) -> void:
	for x in [25.0, 35.0]:
		for z in [-10.0, -5.0, 5.0, 10.0]:
			layout.add_piece(&"armor_rack", Vector3(x, 0, z), Vector3(1.2, 2.2, 0.8), &"armory", PI * 0.5 if x < 30.0 else -PI * 0.5)
	layout.add_piece(&"case", Vector3(30, 0, 0), Vector3(6, 1.4, 1.4), &"armory")
	layout.add_piece(&"crystal_case", Vector3(37.5, 0, -3), Vector3(1.2, 1.8, 1.2), &"armory", -PI * 0.5)
	layout.add_marker(&"crystal_case_armory", Vector3(37.5, 1.0, -3), &"armory", -PI * 0.5)
	for z in [-11.0, 11.0]:
		layout.add_piece(&"case", Vector3(22.5, 0, z), Vector3(1.4, 1.6, 1.0), &"armory", PI * 0.5)
		layout.add_loot(Vector3(22.5, 1.0, z), &"armory", true)
	# fuse B: a crate in the north-east corner or by the south wall
	layout.add_piece(&"crate", Vector3(38.5, 0, -11.5), Vector3(0.9, 0.8, 0.9), &"armory")
	layout.add_piece(&"crate", Vector3(27, 0, 12.8), Vector3(0.9, 0.8, 0.9), &"armory")
	layout.add_marker(&"fuse_b_1", Vector3(38.5, 0.8, -11.5), &"armory", -PI * 0.5)
	layout.add_marker(&"fuse_b_2", Vector3(27, 0.8, 12.8), &"armory")
	layout.add_piece(&"plaque", Vector3(39.95, 1.4, 1.6), Vector3(0.5, 0.3, 0.04), &"armory", PI * 0.5, false)
	layout.add_marker(&"secret_plaque", Vector3(40, 0, 0), &"armory", PI * 0.5)
	layout.add_piece(&"bench", Vector3(30, 0, -12.9), Vector3(2.4, 0.5, 0.6), &"armory")
	# the chained gatling between the south racks, its plaque to the hall door
	layout.add_marker(&"gatling_display", Vector3(30, 0, 7), &"armory", PI * 0.5)
	layout.add_marker(&"note_2", Vector3(30.6, 0.5, -12.9), &"armory")
	for spot in [Vector3(25, 0, 12.5), Vector3(35, 0, -12.5), Vector3(38.5, 0, 12.5)]:
		layout.add_loot(spot, &"armory")
	var knight: Array[StringName] = [&"knight"]
	var wax: Array[StringName] = [&"wax"]
	for spot in [Vector3(25, 0, -7.5), Vector3(35, 0, 7.5)]:
		layout.add_spawn(spot, &"armory", 0, knight)
	for spot in [Vector3(23, 0, 3), Vector3(23, 0, -3)]:
		layout.add_spawn(spot, &"armory", 0, wax)
	layout.add_spawn(Vector3(30, 0, -4), &"armory", 1, knight)
	for spot in [Vector3(28, 0, 10), Vector3(32, 0, 10), Vector3(28, 0, -10), Vector3(32, 0, -10)]:
		layout.add_spawn(spot, &"armory", 1, wax)
	for spot in [Vector3(25, 0, 7.5), Vector3(35, 0, -7.5), Vector3(37.5, 0, 4)]:
		layout.add_spawn(spot, &"armory", 2, knight)
	layout.add_spawn(Vector3(30, 0, 4), &"armory", 2, wax)


static func _diorama(layout: LevelLayout) -> void:
	for side in [-1.0, 1.0]:
		layout.add_piece(&"grass", Vector3(side * 8.25, 0, 36), Vector3(9.5, 0.04, 12), &"diorama", 0.0, false)
		for z in [32.5, 39.5]:
			layout.add_piece(&"fence", Vector3(side * 3.25, 0, z), Vector3(5, 0.7, 0.1), &"diorama", PI * 0.5)
	for rock in [[Vector3(-11, 0, 32.5), Vector3(2.4, 1.6, 2.0)], [Vector3(-5.5, 0, 34.5), Vector3(2.0, 1.4, 2.0)], [Vector3(11, 0, 32.5), Vector3(2.4, 1.8, 2.2)], [Vector3(5.5, 0, 39.5), Vector3(2.2, 1.3, 2.0)]]:
		layout.add_piece(&"rock", rock[0], rock[1], &"diorama", 0.3)
	layout.add_piece(&"crystal_case", Vector3(-11.5, 0, 42.3), Vector3(1.2, 1.8, 1.2), &"diorama")
	layout.add_marker(&"crystal_case_diorama", Vector3(-11.5, 1.0, 42.3), &"diorama")
	layout.add_piece(&"case", Vector3(11.5, 0, 42.5), Vector3(1.4, 1.6, 1.0), &"diorama")
	layout.add_loot(Vector3(11.5, 1.0, 42.5), &"diorama", true)
	layout.add_piece(&"case", Vector3(-7, 0, 25), Vector3(1.4, 1.6, 1.0), &"diorama", PI)
	layout.add_loot(Vector3(-7, 1.0, 25), &"diorama", true)
	layout.add_marker(&"secret_vent", Vector3(-12.75, 0, 24), &"diorama", PI)
	# the fire cabinet with the flare gun on the wall to the hall (its back on
	# the wall surface, facing the diorama)
	layout.add_marker(&"flare_cabinet", Vector3(5, 1.4, 24), &"diorama", PI)
	for spot in [Vector3(-12.5, 0, 43), Vector3(12.5, 0, 25.5), Vector3(0, 0, 36)]:
		layout.add_loot(spot, &"diorama")
	var wolf: Array[StringName] = [&"wolf"]
	var wax: Array[StringName] = [&"wax"]
	for spot in [Vector3(-8, 0, 32.5), Vector3(-7.5, 0, 37.5), Vector3(-9, 0, 40)]:
		layout.add_spawn(spot, &"diorama", 0, wolf)
	for spot in [Vector3(7.5, 0, 35.5), Vector3(9, 0, 38)]:
		layout.add_spawn(spot, &"diorama", 0, wolf)
	for spot in [Vector3(-6, 0, 30.5), Vector3(6, 0, 30.5)]:
		layout.add_spawn(spot, &"diorama", 1, wolf)
	for spot in [Vector3(-10, 0, 27.5), Vector3(10, 0, 27.5)]:
		layout.add_spawn(spot, &"diorama", 1, wax)
	for spot in [Vector3(-9, 0, 36.5), Vector3(9, 0, 36.5), Vector3(-5, 0, 42), Vector3(8.5, 0, 42.5)]:
		layout.add_spawn(spot, &"diorama", 2, wolf)


static func _corridors(layout: LevelLayout) -> void:
	for side in [-1.0, 1.0]:
		var room := &"corridor_w" if side < 0.0 else &"corridor_e"
		layout.add_piece(&"crate", Vector3(side * 33.3, 0, 25), Vector3(1.0, 1.0, 1.0), room)
		layout.add_piece(&"crate", Vector3(side * 20, 0, 29.3), Vector3(1.2, 0.9, 1.0), room)
		layout.add_loot(Vector3(side * 32, 0, 28), room)
		var wax: Array[StringName] = [&"wax"]
		var wolf: Array[StringName] = [&"wolf"]
		layout.add_spawn(Vector3(side * 32, 0, 19.5), room, 0, wax)
		layout.add_spawn(Vector3(side * 32, 0, 22.5), room, 0, wax)
		layout.add_spawn(Vector3(side * 24, 0, 28), room, 1, wolf)
		layout.add_spawn(Vector3(side * 26.5, 0, 27.5), room, 1, wax if side > 0.0 else wolf)
	layout.add_piece(&"lockers", Vector3(-1.2, 0, 49), Vector3(2.0, 2.0, 0.5), &"staff_corridor", -PI * 0.5)


static func _security(layout: LevelLayout) -> void:
	layout.add_piece(&"cctv_wall", Vector3(0, 0, 61.65), Vector3(5, 2.4, 0.6), &"security")
	layout.add_piece(&"desk", Vector3(0, 0, 60.3), Vector3(3.2, 0.78, 1.1), &"security")
	layout.add_piece(&"chair", Vector3(0, 0, 59.2), Vector3(0.6, 1.0, 0.6), &"security", PI, false)
	layout.add_piece(&"lockers", Vector3(4.65, 0, 57.5), Vector3(2.5, 2.0, 0.6), &"security", PI * 0.5)
	layout.add_piece(&"shelf", Vector3(-4.7, 0, 55.5), Vector3(1.6, 1.8, 0.5), &"security", -PI * 0.5)
	layout.player_start = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.05, 59.2))
	# the upgrade terminal (stage 2a) stands against the west wall
	layout.haven_spots[&"security"] = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-4.55, 0, 58))
	layout.add_marker(&"cctv_wall", Vector3(0, 1.5, 61.35), &"security")
	layout.add_marker(&"pistol_locker", Vector3(4.35, 1.0, 58.2), &"security", PI * 0.5)
	layout.add_marker(&"note_1", Vector3(0.9, 0.78, 60.2), &"security")


static func _hidden_rooms(layout: LevelLayout) -> void:
	# broom closet above the grate (haven 2)
	layout.add_piece(&"shelf", Vector3(0, BALCONY_Y, -25.7), Vector3(3.5, 2.2, 0.5), &"closet")
	layout.add_piece(&"crate", Vector3(1.4, BALCONY_Y, -23.6), Vector3(0.5, 0.6, 0.5), &"closet")
	layout.haven_spots[&"closet"] = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-1.6, BALCONY_Y, -24.5))
	layout.add_loot(Vector3(1.2, BALCONY_Y, -24.6), &"closet")
	# chamber behind the painting: the artifact pedestal
	layout.add_piece(&"plinth", Vector3(-42.5, 0, 6.5), Vector3(0.8, 1.0, 0.8), &"secret_chamber")
	layout.add_loot(Vector3(-42.5, 1.0, 6.5), &"secret_chamber", true)
	# niche behind the plaque wall: the shotgun case
	layout.add_piece(&"case", Vector3(42.6, 0, 0), Vector3(2.0, 1.6, 0.8), &"shotgun_niche", PI * 0.5)
	layout.add_marker(&"shotgun_case", Vector3(42.6, 1.0, 0), &"shotgun_niche", PI * 0.5)
	# stairs down into the dark behind the undercroft (the demo ends there)
	var down := layout.add_stairs(&"stairwell_steps", _r(-2, -35, 2, -26.5), STAIRWELL_FLOOR, 0.0, Vector2(0, 1), &"stairwell", &"undercroft")
	down.step_rise = STAIRS_RISE
	layout.add_marker(&"undercroft_exit", Vector3(0, -1.6, -31.5), &"stairwell", PI)
	# service shaft: steps up the slot and a landing at the balcony exit (no
	# railings: the slot is one metre wide, the shaft's walls are the rails,
	# and a rail each side would leave the guard no room to climb)
	var shaft := layout.add_stairs(&"vent_steps", _r(-19.5, 4.5, -18.5, 22.5), 0.0, BALCONY_Y, Vector2(0, -1), &"vent", &"vent")
	shaft.rail_left = false
	shaft.rail_right = false
	layout.add_piece(&"landing", Vector3(-19, 0, 3.75), Vector3(1, BALCONY_Y, 1.5), &"vent")


## Warm lamps (main_lights), red emergency lamps (always on), haven lamps.
## Exit signs over doorways come from the openings themselves.
static func _lights(layout: LevelLayout) -> void:
	var main := LightSpec.MAIN
	var red := LightSpec.EMERGENCY
	var haven := LightSpec.HAVEN
	# hall: a lamp on the inner face of each column (the only hall lamps with shadows)
	for x in [-10.0, 10.0]:
		for z in [-8.0, 8.0]:
			var toward := -signf(x)
			var lamp := layout.add_light(main, Vector3(x + toward * 1.35, 4.6, z), WARM, 2.2, 13.0, &"hall", &"column_lamp", true)
			lamp.fixture_yaw = -PI * 0.5 * toward
	# sconces under the side balconies (flanking the wing doors) and on the north wall
	for side in [-1.0, 1.0]:
		for z in [-17.0, -10.0, -3.4, 3.4]:
			var sconce := layout.add_light(main, Vector3(side * 17.8, 3.3, z), WARM, 1.0, 7.0, &"hall", &"sconce")
			sconce.fixture_yaw = side * PI * 0.5
		var north := layout.add_light(main, Vector3(side * 6.5, 3.3, -21.8), WARM, 1.0, 7.0, &"hall", &"sconce")
		north.fixture_yaw = PI
		layout.add_light(main, Vector3(side * 5.0, 4.0, 21.8), WARM, 1.2, 9.0, &"hall", &"sconce")
		# balcony level
		for z in [-16.0, -8.0, 0.0]:
			var upper := layout.add_light(main, Vector3(side * 17.8, 8.6, z), WARM, 1.0, 8.0, &"balcony", &"sconce")
			upper.fixture_yaw = side * PI * 0.5
		var upper_north := layout.add_light(main, Vector3(side * 9.0, 8.6, -21.8), WARM, 1.0, 8.0, &"balcony", &"sconce")
		upper_north.fixture_yaw = PI
	# wings: ceiling lamps plus one shadowed spot on the centre piece
	for wing in [[&"gallery", -30.0], [&"armory", 30.0]]:
		var room: StringName = wing[0]
		var middle: float = wing[1]
		for dx in [-5.0, 5.0]:
			for z in [-7.0, 7.0]:
				layout.add_light(main, Vector3(middle + dx, 6.1, z), WARM, 1.5, 11.0, room, &"ceiling_lamp")
		var spot := layout.add_light(main, Vector3(middle, 6.9, 0), WARM, 4.0, 10.0, room, &"", true)
		spot.kind = LightSpec.Kind.SPOT
		spot.spot_angle = 30.0
	for x in [-8.0, 8.0]:
		for z in [30.0, 40.0]:
			layout.add_light(main, Vector3(x, 7.1, z), WARM, 1.3, 11.0, &"diorama", &"ceiling_lamp")
	# the T-Rex on its pedestal: a display spot from high over the hall's
	# south side (it dies with the fuse box's power cut)
	var display := layout.add_light(main, Vector3(0, 12.6, -1.0), WARM, 14.0, 24.0, &"hall", &"", true)
	display.kind = LightSpec.Kind.SPOT
	display.direction = (Vector3(0, 3.0, -11) - display.position).normalized()
	display.spot_angle = 30.0
	var moonlit := layout.add_light(main, Vector3(-8, 7.9, 36), COOL, 3.0, 10.0, &"diorama", &"", true)
	moonlit.kind = LightSpec.Kind.SPOT
	moonlit.spot_angle = 50.0
	# service corridors: cold tubes
	for side in [-1.0, 1.0]:
		var room := &"corridor_w" if side < 0.0 else &"corridor_e"
		for at in [Vector3(side * 32, 3.3, 18), Vector3(side * 32, 3.3, 26), Vector3(side * 22, 3.3, 28)]:
			layout.add_light(main, at, TUBE, 0.9, 7.0, room, &"tube_lamp")
	layout.add_light(main, Vector3(0, 2.8, 49), TUBE, 0.8, 6.0, &"staff_corridor", &"tube_lamp")
	# secret rooms: a faint glow on what hides there, a narrow cone straight
	# down that never reaches through a wall into the public room next door
	var chamber := layout.add_light(main, Vector3(-42.5, 2.9, 6.5), Color(0.7, 0.4, 1.0), 1.2, 3.2, &"secret_chamber")
	chamber.kind = LightSpec.Kind.SPOT
	chamber.spot_angle = 25.0
	var niche := layout.add_light(main, Vector3(42.25, 2.8, 0), WARM, 1.0, 3.0, &"shotgun_niche")
	niche.kind = LightSpec.Kind.SPOT
	niche.spot_angle = 22.0
	# havens keep their own light in a blackout
	layout.add_light(haven, Vector3(-1.0, 1.16, 60.4), WARM, 1.6, 7.0, &"security", &"desk_lamp", true)
	layout.add_light(haven, Vector3(0, 2.8, 57), TUBE, 0.6, 7.0, &"security", &"tube_lamp")
	layout.add_light(haven, Vector3(0, 1.5, 61.0), Color(0.4, 0.9, 0.8), 0.6, 3.5, &"security")
	layout.add_light(haven, Vector3(0, 8.6, -24.5), WARM, 0.9, 5.0, &"closet", &"bulb")
	# red emergency lamps, always on (one over the arch to the stairs down:
	# the first steps show, the rest is dark)
	layout.add_light(red, Vector3(0, 2.3, -27.6), RED, 1.1, 6.5, &"stairwell", &"emergency_lamp")
	for side in [-1.0, 1.0]:
		layout.add_light(red, Vector3(side * 17.5, 4.6, 21.8), RED, 1.0, 6.0, &"hall", &"emergency_lamp")
		var under := layout.add_light(red, Vector3(side * 17.5, 4.6, -21.8), RED, 1.0, 6.0, &"hall", &"emergency_lamp")
		under.fixture_yaw = PI
		var gallery := layout.add_light(red, Vector3(-39.8, 5.2, side * 12), RED, 1.0, 6.0, &"gallery", &"emergency_lamp")
		gallery.fixture_yaw = -PI * 0.5
		var armory := layout.add_light(red, Vector3(39.8, 5.2, side * 12), RED, 1.0, 6.0, &"armory", &"emergency_lamp")
		armory.fixture_yaw = PI * 0.5
		layout.add_light(red, Vector3(side * 12, 6.0, 43.8), RED, 1.0, 6.0, &"diorama", &"emergency_lamp")


## Set dressing (stage 3 art): what the kit hangs and stands about the
## rooms without changing their play - room signs over the wing doors, the
## hall's chandelier, banners and weapon racks in the armory, storm-broken
## trees in the diorama, scenic paintings in the gallery (markers; see
## SCENE_SPOTS). Racks and trees collide (only the trunk), the rest not.
static func _dressing(layout: LevelLayout) -> void:
	var sign := Vector3(2.0, 0.32, 0.04)
	# a model's front is -Z: yaw -PI/2 faces +X, PI/2 faces -X, PI faces +Z
	layout.add_piece(&"sign_gallery", Vector3(-13.84, 5.29, 0.0), sign, &"hall", -PI * 0.5, false)
	layout.add_piece(&"sign_armory", Vector3(13.84, 5.29, 0.0), sign, &"hall", PI * 0.5, false)
	layout.add_piece(&"sign_diorama", Vector3(0.0, 5.84, 21.98), sign, &"hall", 0.0, false)
	layout.add_piece(&"sign_hall", Vector3(-19.98, 5.19, 0.0), sign, &"gallery", PI * 0.5, false)
	layout.add_piece(&"sign_hall", Vector3(19.98, 5.19, 0.0), sign, &"armory", -PI * 0.5, false)
	layout.add_piece(&"sign_staff", Vector3(0.0, 2.84, 43.98), sign, &"diorama", 0.0, false)
	# the chandelier over the entrance end of the hall (its light is its fixture)
	layout.add_light(LightSpec.MAIN, Vector3(0.0, 10.95, 17.0), Color(1.0, 0.76, 0.5), 2.6, 15.0, &"hall", &"chandelier")
	# armory: banners high on the long walls, weapon racks flat on the end walls
	for z in [-9.0, 0.0, 9.0]:
		layout.add_piece(&"banner", Vector3(39.99, 2.94, z), Vector3(1.51, 2.77, 0.38), &"armory", PI * 0.5, false)
	for z in [-7.0, 7.0]:
		layout.add_piece(&"banner", Vector3(20.01, 2.94, z), Vector3(1.51, 2.77, 0.38), &"armory", -PI * 0.5, false)
	for x in [26.0, 34.0]:
		layout.add_piece(&"weapon_rack", Vector3(x, 0.0, -13.79), Vector3(2.1, 2.62, 0.4), &"armory", PI)
	for x in [25.5, 37.0]:
		layout.add_piece(&"weapon_rack", Vector3(x, 0.0, 13.79), Vector3(2.1, 2.62, 0.4), &"armory")
	# diorama: two storm-broken trees on the grass, clear of the wolves' slots
	layout.add_piece(&"dead_tree", Vector3(-11.5, 0.04, 38.5), Vector3(3.2, 5.9, 1.6), &"diorama", 0.7)
	layout.add_piece(&"dead_tree", Vector3(11.5, 0.04, 37.5), Vector3(2.6, 4.8, 1.3), &"diorama", 2.4)
	# scenic paintings: over the gallery's portraits (between and above them)
	var hung := 0
	for x in [-39.0, -33.0, -27.0, -21.5]:
		layout.add_marker(SCENE_SPOTS[hung], Vector3(x, 3.85, -13.99), &"gallery", PI)
		layout.add_marker(SCENE_SPOTS[hung + 1], Vector3(x, 3.85, 13.99), &"gallery", 0.0)
		hung += 2
	# and on the north balcony wall, flanking the closet's panel
	for x in [-4.5, 4.5]:
		layout.add_marker(SCENE_SPOTS[hung], Vector3(x, BALCONY_Y + PORTRAIT_HEIGHT, -21.99), &"balcony", PI)
		hung += 1
