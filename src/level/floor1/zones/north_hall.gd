extends RefCounted
## Floor I zone "north_hall" (design 5.7, 6; plan docs/superpowers/plans/
## 2026-10-03-p1-w2-hub.md section 2.4).
## - north_hall: the north corridor behind the North Gate (Star Key, a
##   junction gate), 56 x 7 m and 10 m high: pilasters, cases and busts
##   along the walls, the fire shutters to the Americas and Asia (power)
##   and, opposite the gate, the grate over the crypt (internal gate
##   grate_crypt, opened by the game once the T-Rex is dust). Its ends are
##   dark; two wolves sleep there and wake when the guard comes through
##   the gate.
## - north_hall_lodge (secret): the porter's lodge of the old north
##   entrance at the corridor's east end, its shutter held by a rope on a
##   counterweight (zone gate north_hall_rope_lodge: a precise shot).
## - north_hall_crypt (area crypt): the shaft behind the grate, two flights
##   in two lanes: down north from the grate's landing (y 0) to the crypt's
##   floor at y -6, then on down south "into the dark" to y -12, where
##   Floor I ends (marker floor1_exit halfway down).
## - north_hall_crypt_vault (area crypt): the crypt itself, the slab at
##   y -6 with the founders' tombs (a room inside the shaft, not carved).

const ZONE := &"north_hall"
const Grey := preload("res://src/level/floor1/floor1_greybox.gd")
const Hub := preload("res://src/level/floor1/zones/hub_kit.gd")
const CEILING := 10.0
const CRYPT_Y := Floor1Plan.BASEMENT_Y
const DARK_Y := -12.0
const CRYPT_CEILING := 5.5
const SLAB := 0.4
## The two lanes of the shaft: flights between z -62.5 and -46.5.
const FLIGHT_N := -62.5
const FLIGHT_S := -46.5
const PILASTERS_N: Array[float] = [-24.0, -10.0, -6.0, 6.0, 10.0, 23.0]
const PILASTERS_S: Array[float] = [-24.0, -16.0, -8.0, 8.0, 16.0, 23.0]


static func build(layout: LevelLayout) -> void:
	_rooms(layout)
	_corridor(layout)
	_lodge(layout)
	_crypt(layout)
	_encounters(layout)
	_lights(layout)


static func _rooms(layout: LevelLayout) -> void:
	Grey.box(layout, &"north_hall", Grey.r(-30, -38, 26, -31), 0.0, CEILING, ZONE, &"ROOM_NORTH_HALL")
	var lodge := Grey.box(layout, &"north_hall_lodge", Grey.r(26.5, -38, 30, -31), 0.0, 4.0, ZONE, &"ROOM_NORTH_LODGE", false)
	lodge.secret = true
	Grey.box(layout, &"north_hall_crypt", Grey.r(-3, -70, 3, -39), DARK_Y, CRYPT_CEILING, ZONE, &"ROOM_NORTH_CRYPT_STAIRS", false, &"crypt")
	var vault := Grey.box(layout, &"north_hall_crypt_vault", Grey.r(-3, -70, 3, FLIGHT_N), CRYPT_Y, CRYPT_CEILING, ZONE, &"ROOM_CRYPT", false, &"crypt")
	vault.carved = false
	var grate := Grey.door(layout, &"north_hall_grate", Grey.r(-2.5, -39, 2.5, -38), 0.0, 5.0, &"north_hall", &"north_hall_crypt", OpeningSpec.DoorStyle.GATE, RoomGraph.Kind.GATE)
	grate.face_room = &"north_hall"
	layout.add_gate(&"grate_crypt", GateSpec.Kind.EVENT, &"north_hall_grate", &"trex_defeated", &"GATE_GRATE")
	var shutter := Grey.door(layout, &"north_hall_lodge_door", Grey.r(26, -36, 26.5, -33.5), 0.0, 2.6, &"north_hall", &"north_hall_lodge", OpeningSpec.DoorStyle.GATE, RoomGraph.Kind.GATE)
	shutter.face_room = &"north_hall"
	layout.add_gate(&"north_hall_rope_lodge", GateSpec.Kind.ROPE, &"north_hall_lodge_door", GateSpec.PRECISE, &"GATE_ROPE")


static func _corridor(layout: LevelLayout) -> void:
	var room := &"north_hall"
	for x in PILASTERS_N:
		layout.add_piece(&"pilaster", Vector3(x, 0, -37.75), Vector3(1.0, CEILING, 0.5), room)
	for x in PILASTERS_S:
		layout.add_piece(&"pilaster", Vector3(x, 0, -31.25), Vector3(1.0, CEILING, 0.5), room)
	for x in [-27.5, -8.0, 8.0]:
		layout.add_piece(&"case", Vector3(x, 0, -37.45), Vector3(1.4, 1.6, 1.0), room)
		layout.add_loot(Vector3(x, 1.0, -37.45), room, true)
	for x in [-28.0, -20.0, 20.0]:
		layout.add_piece(&"bust_plinth", Vector3(x, 0, -31.4), Vector3(0.7, 1.9, 0.7), room)
	for x in [-12.0, 12.0]:
		layout.add_piece(&"bench", Vector3(x, 0, -34.5), Vector3(3, 0.5, 0.7), room)
	for spot in [Vector3(-29, 0, -33), Vector3(24.8, 0, -36.8), Vector3(0, 0, -36.5)]:
		layout.add_loot(spot, room)
	# signs: the wings beyond the shutters, the court back through the gate
	Hub.wing_sign(layout, &"sign_americas_1", Vector3(-17, 6.0, -37.96), 5.0, PI, room, &"americas")
	Hub.wing_sign(layout, &"sign_asia_1", Vector3(17, 6.0, -37.96), 5.0, PI, room, &"asia")
	Hub.wing_sign(layout, &"sign_court_2", Vector3(0, 8.6, -31.04), 6.0, 0.0, room, &"court")
	for i in 2:
		layout.add_marker(StringName("portrait_north_hall_%d" % (i + 1)), Vector3(-12.5 if i == 0 else 12.5, 2.1, -31.01), room)
	Hub.look_marker(layout, &"cctv_north_hall_1", Vector3(-29.5, 8, -34.5), Vector3(10, 0, -34.5), room)


static func _lodge(layout: LevelLayout) -> void:
	var room := &"north_hall_lodge"
	layout.add_piece(&"desk", Vector3(28.6, 0, -31.6), Vector3(1.6, 0.78, 0.8), room)
	layout.add_piece(&"shelf", Vector3(29.7, 0, -35.5), Vector3(2.0, 2.0, 0.5), room, -PI * 0.5)
	# the old north doors, bricked up behind their bronze leaves
	var doors := layout.add_piece(&"door_leaf", Vector3(28.25, 0, -37.93), Vector3(2.4, 3.0, 0.1), room, PI)
	doors.tint = Hub.BRONZE
	layout.add_loot(Vector3(28.6, 0.78, -31.6), room, true)
	layout.add_loot(Vector3(27.5, 0, -37.0), room)
	layout.add_marker(&"secret_north_hall_1", Vector3(28.2, 0, -34.5), room)


static func _crypt(layout: LevelLayout) -> void:
	var shaft := &"north_hall_crypt"
	var vault := &"north_hall_crypt_vault"
	# lane B (east): from the grate's landing down north to the crypt floor
	var down := layout.add_stairs(&"north_hall_crypt_flight", Grey.r(0, FLIGHT_N, 3, FLIGHT_S), CRYPT_Y, 0.0, Vector2(0, 1), vault, shaft)
	down.step_rise = Floor1Plan.STAIR_RISE
	down.rail_left = false
	# lane A (west): from the crypt floor on down south into the dark
	var dark := layout.add_stairs(&"north_hall_crypt_dark", Grey.r(-3, FLIGHT_N, 0, FLIGHT_S), DARK_Y, CRYPT_Y, Vector2(0, -1), shaft, vault)
	dark.step_rise = Floor1Plan.STAIR_RISE
	dark.rail_left = false
	# the grate's landing (y 0) and the crypt's slab (y -6); open below
	layout.add_piece(&"balcony", Vector3(0, -SLAB, (FLIGHT_S - 39.0) * 0.5), Vector3(6, SLAB, -39.0 - FLIGHT_S), &"north_hall")
	layout.add_piece(&"railing", Vector3(-1.5, 0, FLIGHT_S - 0.075), Vector3(3, 1.1, 0.15), shaft)
	layout.add_piece(&"balcony", Vector3(0, CRYPT_Y - SLAB, (FLIGHT_N - 70.0) * 0.5), Vector3(6, SLAB, FLIGHT_N + 70.0), shaft)
	for x in [-1.7, 1.7]:
		layout.add_piece(&"sarcophagus", Vector3(x, CRYPT_Y, -67.2), Vector3(1.2, 0.9, 2.4), vault)
	layout.add_loot(Vector3(0, CRYPT_Y, -69.3), vault, true)
	layout.add_loot(Vector3(1.5, DARK_Y, -41.0), shaft)
	# halfway down the dark flight: the end of Floor I
	layout.add_marker(Floor1Plan.EXIT_MARKER, Vector3(-1.5, (CRYPT_Y + DARK_Y) * 0.5, (FLIGHT_N + FLIGHT_S) * 0.5), shaft, 0.0)


static func _encounters(layout: LevelLayout) -> void:
	var room := &"north_hall"
	var wax: Array[StringName] = [&"wax"]
	var wolf: Array[StringName] = [&"wolf"]
	var knight: Array[StringName] = [&"knight"]
	var bust: Array[StringName] = [&"bust"]
	# every night: a wolf asleep in each dark end, woken by the guard coming
	# through the North Gate
	var ends: Array[int] = []
	for x in [-28.0, 24.0]:
		layout.add_spawn(Vector3(x, 0, -34.5), room, SpawnSlot.ALWAYS_SET, wolf, true, PI * 0.5 if x < 0.0 else -PI * 0.5)
		ends.append(layout.spawn_slots.size() - 1)
	layout.add_ambush(AmbushSpec.on_area(&"north_hall_gate", room, Grey.r(-4, -34.5, 4, -31), -1.0, 3.0, ends))
	Hub.slots(layout, room, 0, wax, [Vector2(-14, -33)], 0.0, Vector2(0, -34.5))
	Hub.walker(layout, &"north_hall_walk", room, 0, wax, PackedVector3Array([Vector3(-22, 0, -34.5), Vector3(21, 0, -34.5)]), false)
	Hub.slots(layout, room, 1, knight, [Vector2(14, -33)], 0.0, Vector2(0, -34.5))
	Hub.slots(layout, room, 1, wax, [Vector2(-6, -33)], 0.0, Vector2(0, -34.5))
	Hub.slots(layout, room, 2, bust, [Vector2(-17, -33)], 0.0, Vector2(0, -34.5))
	Hub.slots(layout, room, 2, wax, [Vector2(16, -35.5)], 0.0, Vector2(0, -34.5))


static func _lights(layout: LevelLayout) -> void:
	var main := LightSpec.MAIN
	var red := LightSpec.EMERGENCY
	var room := &"north_hall"
	for x in [-10.0, 10.0]:
		Hub.lamp(layout, main, Vector3(x, 4.0, -37.4), Hub.WARM, 1.0, 6.5, room, &"sconce", PI)
	for x in [-16.0, -8.0, 8.0, 16.0]:
		Hub.lamp(layout, main, Vector3(x, 4.0, -31.6), Hub.WARM, 1.0, 6.5, room, &"sconce")
	for x in [-17.0, 0.0, 17.0]:
		Hub.lamp(layout, red, Vector3(x, 5.3, -37.85), Hub.RED, 1.0, 5.0, room, &"emergency_lamp", PI)
	Hub.spot(layout, main, Vector3(28.25, 3.7, -34.5), Vector3(28.25, 0, -34.5), Hub.WARM, 1.0, 3.5, 30.0, &"north_hall_lodge")
	# the crypt: a red lamp over the grate's landing, a lantern by the
	# tombs, nothing further down
	Hub.lamp(layout, red, Vector3(2.8, 3.2, -39.6), Hub.RED, 1.0, 6.0, &"north_hall_crypt", &"emergency_lamp", PI)
	Hub.lamp(layout, main, Vector3(0, CRYPT_Y + 2.4, -69.4), Hub.WARM, 0.6, 5.0, &"north_hall_crypt_vault", &"bulb")
