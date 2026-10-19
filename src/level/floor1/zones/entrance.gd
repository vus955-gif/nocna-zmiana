extends RefCounted
## Floor I zone "entrance" (design 5.7; plan docs/superpowers/plans/
## 2026-10-03-p1-w2-hub.md section 2.2): the entrance hall, 32 x 22 m and
## 12 m high, between the main doors (south, shut until 6:00) and the
## Great Court (north, an 8 m arch).
## - entrance_hall: the hall (the cloakroom block cut out of its north-east
##   corner). One grand flight along the west wall climbs from the court end
##   to the gallery; the east side stays open, so the guard stepping out of
##   the staff door (junction j_entrance_booth) sees the whole hall, the
##   ticket desk with the gun locker key, the fire cabinet with the flare
##   gun and the moonlit court beyond the arch.
## - entrance_gallery: the gallery at y = 6 over the main doors (a room
##   inside the hall) with the two landing doors: Greece to the west (bolted
##   from Greece) and the roof hatch to the east (a rope).
## - entrance_cloakroom: the cloakroom with its counter to the hall.
## - entrance_coat_store (secret): behind the cloakroom's cracked back wall
##   (zone gate entrance_cracked_store: a blast - the flare gun found in this
##   very hall, from close up).
## Night 1 walks through here: sleeping wax figures and one patrolling
## figure, never a wolf (design 7.2).

const ZONE := &"entrance"
const Grey := preload("res://src/level/floor1/floor1_greybox.gd")
const Hub := preload("res://src/level/floor1/zones/hub_kit.gd")
const SWING := OpeningSpec.DoorStyle.SWING
const CEILING := 12.0
const LANDING := Floor1Plan.LANDING_Y
## The grand flight: 16 m along the west wall, 40 steps of 0.15 x 0.40 m.
const STAIRS := Rect2(-16, 33, 5, 16)
const COLUMNS: Array[Vector2] = [Vector2(-6, 39), Vector2(6, 39), Vector2(-6, 45), Vector2(6, 45)]
## The ticket booth (its window and till drawer face west).
## The ticket booth: its window and till drawer face north, towards the
## staff door the guard first steps out of.
const BOOTH := Vector3(11, 0, 45.5)


static func build(layout: LevelLayout) -> void:
	_rooms(layout)
	_stairs_and_gallery(layout)
	_hall(layout)
	_cloakroom(layout)
	_encounters(layout)
	_lights(layout)
	_voice(layout)


static func _rooms(layout: LevelLayout) -> void:
	var hall: Array[Rect2] = [Grey.r(-16, 37, 16, 53), Grey.r(-16, 31, 8.5, 37)]
	Grey.room(layout, &"entrance_hall", hall, 0.0, CEILING, ZONE, &"ROOM_ENTRANCE_HALL")
	var gallery := Grey.box(layout, &"entrance_gallery", Grey.r(-16, 49, 16, 53), LANDING, CEILING, ZONE, &"ROOM_ENTRANCE_GALLERY")
	gallery.carved = false
	Grey.box(layout, &"entrance_cloakroom", Grey.r(9, 31, 13, 36.5), 0.0, 3.5, ZONE, &"ROOM_ENTRANCE_CLOAKROOM")
	var store := Grey.box(layout, &"entrance_coat_store", Grey.r(13.5, 31, 16, 36.5), 0.0, 3.5, ZONE, &"ROOM_ENTRANCE_COAT_STORE", false)
	store.secret = true
	# the counter: an opening the counter itself fills (shoot over it, walk round)
	var counter := Grey.door(layout, &"entrance_cloakroom_counter", Grey.r(8.5, 32.5, 9, 35.5), 0.0, 2.4, &"entrance_hall", &"entrance_cloakroom")
	counter.exit_signs = false
	Grey.door(layout, &"entrance_cloakroom_door", Grey.r(11, 36.5, 12.5, 37), 0.0, 2.4, &"entrance_hall", &"entrance_cloakroom", SWING)
	var crack := Grey.door(layout, &"entrance_cloakroom_store", Grey.r(13, 33, 13.5, 35), 0.0, 2.2, &"entrance_cloakroom", &"entrance_coat_store", OpeningSpec.DoorStyle.PANEL, RoomGraph.Kind.GATE)
	crack.face_room = &"entrance_cloakroom"
	layout.add_gate(&"entrance_cracked_store", GateSpec.Kind.CRACKED, &"entrance_cloakroom_store", GateSpec.EXPLOSIVE, &"GATE_CRACKED")


static func _stairs_and_gallery(layout: LevelLayout) -> void:
	var flight := layout.add_stairs(&"entrance_stairs", STAIRS, 0.0, LANDING, Vector2(0, 1), &"entrance_hall", &"entrance_gallery")
	flight.step_rise = Floor1Plan.STAIR_RISE
	flight.rail_right = false   # the west wall
	# the gallery slab (its floor; on the hall, which carries it) and its
	# parapet along the open edge east of the stairs' top
	layout.add_piece(&"balcony", Vector3(0, LANDING - 0.4, 51), Vector3(32, 0.4, 4), &"entrance_hall")
	layout.add_piece(&"railing", Vector3(2.5, LANDING, 49.075), Vector3(27, 1.1, 0.15), &"entrance_gallery")
	for x in [-6.0, 6.0, 12.5]:
		layout.add_piece(&"balcony_post", Vector3(x, 0, 49.4), Vector3(0.6, LANDING - 0.4, 0.6), &"entrance_hall")
	layout.add_piece(&"bench", Vector3(0, LANDING, 52.4), Vector3(3, 0.5, 0.7), &"entrance_gallery")
	layout.add_loot(Vector3(12, LANDING, 52.2), &"entrance_gallery")
	layout.add_loot(Vector3(-8, LANDING, 52.2), &"entrance_gallery")
	Hub.wing_sign(layout, &"sign_greece_1", Vector3(-15.96, LANDING + 2.9, 51), 2.4, -PI * 0.5, &"entrance_gallery", &"greece")


static func _hall(layout: LevelLayout) -> void:
	var room := &"entrance_hall"
	for at in COLUMNS:
		layout.add_piece(&"column", Vector3(at.x, 0, at.y), Vector3(1.4, CEILING, 1.4), room)
	# the sculpture stands in the porch under the gallery: the axis from the
	# hall to the court's arch stays open
	layout.add_piece(&"sculpture", Vector3(0, 0, 50.6), Vector3(2.2, 4.5, 2.2), room)
	for x in [-3.2, 3.2]:
		layout.add_piece(&"bench", Vector3(x, 0, 42), Vector3(2.4, 0.5, 0.7), room, PI * 0.5)
	layout.add_piece(&"ticket_booth", BOOTH, Vector3(4.5, 2.8, 3.5), room)
	# the main doors: shut bronze leaves in the south wall (open at 6:00)
	var doors := layout.add_piece(&"door_leaf", Vector3(0, 0, 52.92), Vector3(4.5, 5.2, 0.15), room)
	doors.tint = Hub.BRONZE
	for at in [Vector3(-9, 0, 51.6), Vector3(14.4, 0, 51.6)]:
		layout.add_piece(&"case", at, Vector3(1.4, 1.6, 1.0), room)
		layout.add_loot(at + Vector3.UP, room, true)
	layout.add_piece(&"crate", Vector3(-14.8, 0, 52.2), Vector3(1.2, 0.9, 1.0), room)
	layout.add_marker(&"ticket_drawer", Vector3(BOOTH.x, 1.0, BOOTH.z - 1.8), room)
	layout.add_marker(&"note_entrance_1", Vector3(BOOTH.x + 1.3, 1.16, BOOTH.z - 1.85), room)
	# the red fire cabinet a few steps north of the staff door
	layout.add_marker(&"flare_cabinet", Vector3(15.9, 1.4, 38.5), room, PI * 0.5)
	layout.add_marker(&"museum_exit", Vector3(0, 0, 52.75), room)
	layout.add_marker(&"museum_map_entrance", Vector3(5.5, 1.6, 31.05), room, PI)
	Hub.wing_sign(layout, &"sign_court_1", Vector3(0, 8.4, 31.04), 6.0, PI, room, &"court")
	Hub.look_marker(layout, &"cctv_entrance_1", Vector3(15.5, 9.0, 37.5), Vector3(-4, 0.5, 46), room)
	for spot in [Vector3(-13.2, 0, 52.2), Vector3(14.6, 0, 48.8), Vector3(-12.8, 0, 31.8), Vector3(4.5, 0, 33.5), Vector3(-8.5, 0, 46.5)]:
		layout.add_loot(spot, room)


static func _cloakroom(layout: LevelLayout) -> void:
	var room := &"entrance_cloakroom"
	layout.add_piece(&"cloakroom_counter", Vector3(9.4, 0, 34), Vector3(0.7, 1.1, 3.4), room)
	layout.add_piece(&"coat_rack", Vector3(11.5, 0, 31.35), Vector3(2.8, 1.8, 0.6), room, PI)
	layout.add_loot(Vector3(11.3, 0, 33.8), room)
	var store := &"entrance_coat_store"
	layout.add_piece(&"shelf", Vector3(15.7, 0, 33.75), Vector3(3.0, 2.0, 0.5), store, PI * 0.5)
	layout.add_piece(&"crate", Vector3(14.3, 0, 36.0), Vector3(0.8, 0.6, 0.6), store)
	layout.add_loot(Vector3(14.6, 0, 31.8), store, true)
	layout.add_marker(&"secret_entrance_1", Vector3(14.75, 0, 34.5), store)


static func _encounters(layout: LevelLayout) -> void:
	var room := &"entrance_hall"
	var wax: Array[StringName] = [&"wax"]
	var bust: Array[StringName] = [&"bust"]
	# set 0 (the gentle first night): four sleepers and one figure walking
	# round the colonnade - the guard's first fight
	Hub.slots(layout, room, 0, wax, [Vector2(-9, 42), Vector2(-3.5, 50.5), Vector2(3.5, 50.5), Vector2(-9.8, 38.5)])
	Hub.walker(layout, &"entrance_colonnade", room, 0, wax, PackedVector3Array([Vector3(-8.5, 0, 36), Vector3(7.5, 0, 36), Vector3(7.5, 0, 47.5), Vector3(-8.5, 0, 47.5)]))
	Hub.slots(layout, room, 1, wax, [Vector2(-9, 42), Vector2(3, 35), Vector2(-3, 48)])
	Hub.slots(layout, room, 1, bust, [Vector2(-8, 33.5), Vector2(8.5, 41.5)])
	Hub.slots(layout, room, 2, wax, [Vector2(3, 37.5), Vector2(-3.5, 50.5), Vector2(3.5, 50.5), Vector2(-3, 35)])
	Hub.slots(layout, room, 2, bust, [Vector2(8.5, 41.5)])
	Hub.walker(layout, &"entrance_west_aisle", room, 2, wax, PackedVector3Array([Vector3(-8.5, 0, 34), Vector3(-8.5, 0, 48)]), false)
	# the gallery: one figure keeps watch over the doors
	var gallery := &"entrance_gallery"
	Hub.slots(layout, gallery, 0, wax, [Vector2(8, 51)], LANDING)
	Hub.slots(layout, gallery, 1, bust, [Vector2(-6, 51)], LANDING)
	Hub.slots(layout, gallery, 2, wax, [Vector2(4, 51.5)], LANDING)


static func _lights(layout: LevelLayout) -> void:
	var main := LightSpec.MAIN
	var room := &"entrance_hall"
	Hub.lamp(layout, main, Vector3(0, 10.4, 42), Hub.WARM, 2.4, 14.0, room, &"chandelier")
	for at in COLUMNS:
		var toward := -signf(at.x)
		var shadow := at.y < 42.0
		Hub.lamp(layout, main, Vector3(at.x + toward * 1.05, 4.4, at.y), Hub.WARM, 1.3, 9.0, room, &"column_lamp", -PI * 0.5 * toward, shadow)
	# the cashier's lamp lights the till drawer for the new guard
	Hub.lamp(layout, main, Vector3(BOOTH.x - 0.8, 1.6, BOOTH.z - 1.4), Hub.WARM, 1.4, 6.0, room, &"desk_lamp")
	for x in [-8.0, 8.0]:
		Hub.lamp(layout, main, Vector3(x, LANDING + 2.4, 52.8), Hub.WARM, 1.0, 7.0, &"entrance_gallery", &"sconce")
	# moonlight through the fanlight over the main doors, down the nave
	Hub.spot(layout, Hub.MOON_GROUP, Vector3(0, 11.3, 52.6), Vector3(0, 0, 40), Hub.MOON, 1.8, 18.0, 16.0, room)
	Hub.lamp(layout, LightSpec.EMERGENCY, Vector3(0, 5.1, 52.75), Hub.RED, 1.0, 6.0, room, &"emergency_lamp")
	Hub.lamp(layout, main, Vector3(11, 3.1, 34), Hub.WARM, 0.7, 4.5, &"entrance_cloakroom", &"bulb")
	Hub.spot(layout, main, Vector3(14.75, 3.1, 33.75), Vector3(14.75, 0, 33.0), Hub.WARM, 0.9, 3.2, 25.0, &"entrance_coat_store")

# --- the voice: the System's loudspeakers and the audio guide (plan 2026-10-19-glos-g2-kwestie) ---

## The System over the hall: on the wall beside the arch to the court.
static func _voice(layout: LevelLayout) -> void:
	layout.add_marker(&"loudspeaker_entrance_1", Vector3(-8.0, 3.6, 31.15), &"entrance_hall", PI)
