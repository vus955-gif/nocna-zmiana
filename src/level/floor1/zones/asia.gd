extends RefCounted
## Floor I zone "asia" (stage P1, workstream W5a; plan:
## docs/superpowers/plans/2026-10-03-p1-w5a-oswiecenie-azja.md). Red
## lacquer, bronze, porcelain and paper lanterns; the moon only in the
## Japanese garden.
## - The fire shutter from the north corridor rolls up on the China and
##   South Asia hall: the big Buddha in a golden spot faces the doorway down
##   12 m of red columns and lanterns; in the wall beside him cracks with
##   moonlight seeping through (the garden, for later).
## - The porcelain gallery (fragile cases) leads to the Korea hall: the
##   HWACHA on its cart in the middle (bronze Fu dogs and an ashigaru wake
##   when it is taken) and the door to the Planetarium, bolted on this side
##   (the shortcut back to the Enlightenment).
## - The samurai armour hall: rows of armour on racks, the armourer's vault
##   chained shut in its north-east corner; a loop back to the porcelain.
## - With the fire chest's volley the cracked wall gives way: the Japanese
##   garden under the open roof - raked gravel, rocks and stone lanterns for
##   cover, a cherry tree, a pond - and the General waiting in the middle.
##   The tea house (haven) and the bell shrine open off the garden; both are
##   arena doors (shut while he fights).
## - The service stairs by the porcelain go down to the basement door
##   (bolted on this side); at their foot a cracked wall hides the crate
##   store of the 1910 expedition.
## Exhibits: bronze Fu dogs [wolf, fu_dog] in pairs, samurai armour
## [knight, samurai_armor].

const ZONE := &"asia"
const Grey := preload("res://src/level/floor1/floor1_greybox.gd")
const Hub := preload("res://src/level/floor1/zones/hub_kit.gd")
const Kit := preload("res://src/level/floor1/zones/west_kit.gd")
const East := preload("res://src/level/floor1/zones/east_kit.gd")
const SWING := OpeningSpec.DoorStyle.SWING
const ALWAYS := SpawnSlot.ALWAYS_SET

## Stand-in kind first, the intended one after it.
const FU_DOG: Array[StringName] = [&"wolf", &"fu_dog"]
const ARMOUR: Array[StringName] = [&"knight", &"samurai_armor"]

## Light recipe (design 10.1): warm lanterns, gold on the Buddha, the cold
## moon over the garden.
const LANTERN := Color(1.0, 0.62, 0.36)
const GOLD := Color(1.0, 0.8, 0.45)
const STONE_LAMP := Color(1.0, 0.7, 0.42)
const HAVEN_LAMP := Color(1.0, 0.84, 0.62)
const LACQUER := Color(0.62, 0.16, 0.12)

const BUDDHA := Vector3(13.5, 0.0, -57.0)
const HWACHA := Vector3(46.5, 0.9, -51.0)
const GENERAL := Vector3(17.5, 0.0, -75.0)
## The tea house's thatched eave over the garden (an L round its north-east
## corner, underside EAVE_Y, EAVE_THICK thick): the General's perch for the
## volleys of his phase 2 (marker arena_general_perch on the corner). The
## greybox tea house is a room 3.5 m high cut off from the garden by a wall
## as tall as the garden, so its roof cannot be seen from the arena: the
## eave is an element of the garden room instead. The teahouse model's own
## roof_perch takes over once it stands here (dressing; note for it: that
## model assumes the tea house's east face at x = 10.5, the greybox's is 12.5).
const EAVE_Y := 3.5
const EAVE_THICK := 0.4
const PERCH := Vector3(13.6, EAVE_Y + EAVE_THICK, -76.6)
const THATCH := Color(0.6, 0.5, 0.3)
## The cracked wall into the garden (x 6..10 in the hall's north wall).
const CRACK := Vector3(8.0, 0.0, -62.25)
const COLUMNS: Array[Vector2] = [Vector2(7.5, -45), Vector2(7.5, -51), Vector2(19.5, -45), Vector2(19.5, -51)]


static func build(layout: LevelLayout) -> void:
	_rooms(layout)
	_doors(layout)
	_china(layout)
	_porcelain(layout)
	_korea(layout)
	_armor(layout)
	_garden(layout)
	_teahouse(layout)
	_service(layout)
	_secrets(layout)
	_voice(layout)


# --- rooms and passages -----------------------------------------------------

static func _rooms(layout: LevelLayout) -> void:
	Grey.box(layout, &"asia_china", Grey.r(4, -62, 23, -39), 0.0, 12.0, ZONE, &"ROOM_ASIA_CHINA")
	# the service stairs: two flights; their top landing at the south end
	# opens into the porcelain gallery, their foot holds the basement door
	Grey.tower(layout, &"asia_service_stairs", Grey.r(23.5, -53, 28.5, -39), Floor1Plan.BASEMENT_Y, 0.0, 2, 1, false, ZONE)
	Grey.room(layout, &"asia_porcelain", [Grey.r(23.5, -62, 36.5, -53.5), Grey.r(29, -53.5, 36.5, -39.5)] as Array[Rect2], 0.0, 6.0, ZONE, &"ROOM_ASIA_PORCELAIN")
	Grey.box(layout, &"asia_korea", Grey.r(37, -62, 56, -39), 0.0, 8.0, ZONE, &"ROOM_ASIA_KOREA")
	Grey.room(layout, &"asia_armor", [Grey.r(30.5, -86, 50, -62.5), Grey.r(50, -76.5, 56, -62.5)] as Array[Rect2], 0.0, 8.0, ZONE, &"ROOM_ASIA_ARMOR")
	# the Japanese garden: an L round the tea house plus the strip before the
	# bell shrine, under an open roof (greybox: wide light wells)
	var garden_parts: Array[Rect2] = [Grey.r(12.5, -86, 24, -62.5), Grey.r(4, -77.5, 12.5, -62.5), Grey.r(24, -80, 30, -62.5)]
	var garden := Grey.room(layout, &"asia_garden", garden_parts, 0.0, 14.0, ZONE, &"ROOM_ASIA_GARDEN", true, &"asia_garden")
	garden.skylights.append(Grey.r(13, -85, 23.5, -64))
	garden.skylights.append(Grey.r(5, -76, 12, -64))
	garden.skylights.append(Grey.r(24.5, -79, 29.5, -64))
	var teahouse := Grey.box(layout, &"asia_teahouse", Grey.r(4, -86, 12, -78), 0.0, 3.5, ZONE, &"ROOM_ASIA_TEAHOUSE", false, &"asia_garden")
	teahouse.haven = true
	for spec: Array in [
		[&"asia_armory_vault", Grey.r(50.5, -86, 56, -77), 0.0, 4.0, &"ROOM_ASIA_VAULT", &""],
		[&"asia_garden_shrine", Grey.r(24.5, -86, 30, -80.5), 0.0, 4.0, &"ROOM_ASIA_SHRINE", &"asia_garden"],
		[&"asia_crate_store", Grey.r(15, -52, 23, -40), Floor1Plan.BASEMENT_Y, Floor1Plan.BASEMENT_Y + 3.0, &"ROOM_ASIA_CRATES", &""],
	]:
		var hidden := Grey.box(layout, spec[0], spec[1], spec[2], spec[3], ZONE, spec[4], false, spec[5])
		hidden.secret = true


static func _doors(layout: LevelLayout) -> void:
	Grey.door(layout, &"asia_china_porcelain", Grey.r(23, -60, 23.5, -56), 0.0, 4.0, &"asia_china", &"asia_porcelain")
	Grey.door(layout, &"asia_porcelain_korea", Grey.r(36.5, -50, 37, -46), 0.0, 4.0, &"asia_porcelain", &"asia_korea")
	Grey.door(layout, &"asia_porcelain_armor", Grey.r(31, -62.5, 35, -62), 0.0, 4.0, &"asia_porcelain", &"asia_armor")
	Grey.door(layout, &"asia_korea_armor", Grey.r(44, -62.5, 48, -62), 0.0, 4.0, &"asia_korea", &"asia_armor")
	# (a swing door's leaf opens into room B: the porcelain, the tea house)
	Grey.door(layout, &"asia_stairs_porcelain", Grey.r(28.5, -41.75, 29, -39.75), 0.0, 2.6, &"asia_service_stairs", &"asia_porcelain", SWING)
	Grey.door(layout, &"asia_garden_teahouse", Grey.r(12, -83, 12.5, -81), 0.0, 2.6, &"asia_garden", &"asia_teahouse", SWING)
	# the cracked wall into the garden: a blast (the fire chest's volley,
	# three flares from close up)
	var wall := Grey.door(layout, &"asia_garden_wall", Grey.r(6, -62.5, 10, -62), 0.0, 4.0, &"asia_china", &"asia_garden", OpeningSpec.DoorStyle.PANEL, RoomGraph.Kind.GATE)
	wall.face_room = &"asia_china"
	layout.add_gate(&"cracked_garden", GateSpec.Kind.CRACKED, &"asia_garden_wall", GateSpec.EXPLOSIVE, &"GATE_CRACKED")


# --- the China and South Asia hall ------------------------------------------------

static func _china(layout: LevelLayout) -> void:
	var room := &"asia_china"
	# the big Buddha on his lotus base against the north wall, facing the
	# shutter; behind him a narrow way round and an offering table
	layout.add_piece(&"pedestal", BUDDHA, Vector3(7.0, 1.5, 6.0), room)
	layout.add_piece(&"sculpture", BUDDHA + Vector3(0, 1.5, -0.5), Vector3(5.0, 7.5, 4.0), room, PI)
	layout.add_piece(&"plinth", Vector3(BUDDHA.x, 0, -61.2), Vector3(0.6, 0.9, 0.6), room)
	layout.add_marker(&"chess_7", Vector3(BUDDHA.x, 0.9, -61.2), room)
	# red lacquer columns, the bronze incense burner on the axis
	for at in COLUMNS:
		var column := layout.add_piece(&"column", Vector3(at.x, 0, at.y), Vector3(1.2, 12.0, 1.2), room)
		column.tint = LACQUER
	layout.add_piece(&"plinth", Vector3(BUDDHA.x, 0, -48.0), Vector3(1.6, 1.2, 1.6), room)
	# a guardian Fu dog of stone on each side of the shutter (the lion and the
	# lioness). The statue is 2.5 m from snout to tail and the box of each is
	# as long, so nobody walks through a snout; the pedestals run on to 0.4 m
	# off the south wall and stop where they did on the live pair's side (the
	# haunches of the dog at x 20.5 would clip the east pedestal's corner)
	for x in [12.0, 22.0]:
		layout.add_piece(&"pedestal", Vector3(x, 0, -40.775), Vector3(1.4, 1.0, 2.75), room)
		layout.add_piece(&"sculpture", Vector3(x, 1.0, -40.775), Vector3(1.0, 1.8, 2.55), room, PI)
	# bronzes in cases along the west wall
	East.along_z(layout, &"case", 4.0, 1.0, -58.0, -42.0, 0.0, 2.0, 1.0, room, [], 4.0, 1.0)
	# paper lanterns over the hall
	for at in [Vector3(10.0, 6.0, -44.0), Vector3(17.0, 6.0, -44.0), Vector3(6.0, 6.0, -54.0), Vector3(21.0, 6.0, -54.0)]:
		var lantern := layout.add_piece(&"lantern", at, Vector3(0.6, 0.9, 0.6), room, 0.0, false)
		lantern.tint = LANTERN
		Hub.lamp(layout, LightSpec.MAIN, at + Vector3.UP * 0.4, LANTERN, 1.2, 10.0, room)
	# gold on the Buddha (his shadow on the wall), the moon seeping through
	# the cracks beside him, red lamps by the shutter and the arch
	Hub.spot(layout, LightSpec.MAIN, Vector3(BUDDHA.x, 11.2, -46.0), BUDDHA + Vector3(0, 5.5, -0.5), GOLD, 7.0, 20.0, 26.0, room, true)
	Hub.spot(layout, Hub.MOON_GROUP, Vector3(CRACK.x, 3.6, -61.7), Vector3(CRACK.x + 0.5, 0.0, -58.0), Hub.MOON, 0.6, 6.0, 30.0, room)
	Kit.red(layout, Vector3(13.0, 4.0, -39.8), 0.0, room)
	Kit.red(layout, Vector3(22.8, 4.2, -55.0), PI * 0.5, room)
	Kit.camera(layout, &"cctv_asia_1", Vector3(22.5, 10.5, -40.0), BUDDHA + Vector3(0, 3, 0), room)
	layout.add_loot(Vector3(6.5, 0, -40.5), room)
	layout.add_loot(Vector3(19.5, 0, -61.0), room)
	layout.add_loot(Vector3(BUDDHA.x, 1.2, -48.0), room, true)
	# set 0: a pair of Fu dogs inside the shutter and an armour; set 1: the
	# pair by the Buddha wakes when the guard comes close, two armours by the
	# burner; set 2: an armour walking round the burner, two Fu dogs
	var middle := Vector2(BUDDHA.x, -48.0)
	Hub.slots(layout, room, 0, FU_DOG.duplicate(), [Vector2(9.5, -42.5), Vector2(20.5, -42.5)], 0.0, Vector2(17.0, -39.5))
	Hub.slots(layout, room, 0, ARMOUR.duplicate(), [Vector2(6.0, -48.0)], 0.0, middle)
	var pair := Hub.slots(layout, room, 1, FU_DOG.duplicate(), [Vector2(8.5, -55.5), Vector2(18.5, -55.5)], 0.0, middle)
	layout.add_ambush(AmbushSpec.on_area(&"asia_buddha", room, Grey.r(9, -54, 18, -50), -0.5, 3.0, pair))
	Hub.slots(layout, room, 1, ARMOUR.duplicate(), [Vector2(10.0, -47.0), Vector2(17.0, -47.0)], 0.0, Vector2(17.0, -39.5))
	Hub.walker(layout, &"asia_china_round", room, 2, ARMOUR.duplicate(), PackedVector3Array([Vector3(10, 0, -45.5), Vector3(17, 0, -45.5), Vector3(17, 0, -50.5), Vector3(10, 0, -50.5)]))
	# (the west one 0.6 m off the west cases: lying along its diagonal, its
	# tail and its haunch's reach would run into the case at x 5)
	Hub.slots(layout, room, 2, FU_DOG.duplicate(), [Vector2(6.6, -55.5), Vector2(21.0, -47.0)], 0.0, middle)


# --- the porcelain gallery ----------------------------------------------------------

static func _porcelain(layout: LevelLayout) -> void:
	var room := &"asia_porcelain"
	# fragile cases down the middle (breaking glass carries)
	for at: Vector2 in [Vector2(28.0, -57.75), Vector2(33.0, -57.75), Vector2(32.75, -51.0), Vector2(32.75, -47.0), Vector2(32.75, -43.0)]:
		layout.add_piece(&"case", Vector3(at.x, 0, at.y), Vector3(1.2, 1.9, 1.2), room)
	for z in [-52.5, -42.5]:
		layout.add_piece(&"plinth", Vector3(35.8, 0, z), Vector3(0.7, 1.1, 0.7), room)
		layout.add_piece(&"sculpture", Vector3(35.8, 1.1, z), Vector3(0.5, 0.8, 0.5), room, 0.0, false)
	for at in [Vector3(30.0, 5.0, -57.75), Vector3(32.75, 5.0, -46.0)]:
		var lantern := layout.add_piece(&"lantern", at, Vector3(0.5, 0.8, 0.5), room, 0.0, false)
		lantern.tint = LANTERN
		Hub.lamp(layout, LightSpec.MAIN, at + Vector3.UP * 0.3, LANTERN, 1.1, 9.0, room)
	Kit.red(layout, Vector3(29.2, 3.0, -42.5), -PI * 0.5, room)
	layout.add_loot(Vector3(25.5, 0, -54.5), room)
	layout.add_loot(Vector3(35.5, 0, -40.5), room)
	Hub.slots(layout, room, 0, ARMOUR.duplicate(), [Vector2(26.0, -55.5)], 0.0, Vector2(30.0, -57.75))
	Hub.slots(layout, room, 0, FU_DOG.duplicate(), [Vector2(30.5, -45.0)], 0.0, Vector2(32.75, -47.0))
	Hub.slots(layout, room, 1, ARMOUR.duplicate(), [Vector2(35.0, -55.5), Vector2(30.75, -49.0)], 0.0, Vector2(32.75, -47.0))


# --- the Korea hall (the hwacha) -------------------------------------------------------

static func _korea(layout: LevelLayout) -> void:
	var room := &"asia_korea"
	# the fire-arrow cart in the middle, lit warm, seen from the porcelain arch
	# (the box holds the whole hwacha display of the dressing: its stand's
	# cushion under the marker, the cart behind it to the east)
	layout.add_piece(&"pedestal", Vector3(HWACHA.x + 1.325, 0, HWACHA.z), Vector3(3.55, HWACHA.y, 1.4), room)
	layout.add_marker(&"weapon_hwacha", HWACHA, room, PI * 0.5)
	layout.add_marker(&"note_asia_1", HWACHA + Vector3(0.7, 0, 0.45), room, PI * 0.5)
	# the bell pavilion's stone platform in the hall's south-east corner (the
	# dressing raises the bell tower on it), clear of the bronze pair's slots
	# by the cart and of the loot by the east wall
	layout.add_piece(&"pedestal", Vector3(52.0, 0, -58.3), Vector3(3.3, 1.0, 3.7), room)
	# celadon on the north wall, the moon jar, a folding screen on the east
	East.along_x(layout, &"case", -62.0, 1.0, 38.0, 55.0, 0.0, 1.9, 1.0, room, [Vector2(43.5, 48.5)])
	layout.add_piece(&"plinth", Vector3(41.0, 0, -57.5), Vector3(0.9, 1.0, 0.9), room)
	layout.add_piece(&"sculpture", Vector3(41.0, 1.0, -57.5), Vector3(0.7, 0.7, 0.7), room, 0.0, false)
	for z in [-55.0, -51.5, -48.0]:
		layout.add_piece(&"painting", Vector3(55.96, 2.4, z), Vector3(3.2, 2.2, 0.08), room, PI * 0.5, false)
	# light: the cart in a warm spot, lanterns, red lamps by the bolted door
	# to the Planetarium and the porcelain arch
	Hub.spot(layout, LightSpec.MAIN, Vector3(HWACHA.x - 4.0, 7.4, HWACHA.z + 3.0), HWACHA, GOLD, 4.0, 12.0, 24.0, room, true)
	for at in [Vector3(41.0, 6.2, -45.0), Vector3(52.0, 6.2, -45.0), Vector3(41.0, 6.2, -57.0), Vector3(52.0, 6.2, -57.0)]:
		var lantern := layout.add_piece(&"lantern", at, Vector3(0.6, 0.9, 0.6), room, 0.0, false)
		lantern.tint = LANTERN
		Hub.lamp(layout, LightSpec.MAIN, at + Vector3.UP * 0.4, LANTERN, 1.1, 9.0, room)
	Kit.red(layout, Vector3(46.8, 3.0, -39.8), 0.0, room)
	Kit.red(layout, Vector3(37.2, 3.6, -51.0), -PI * 0.5, room)
	Kit.camera(layout, &"cctv_asia_2", Vector3(55.5, 7.4, -40.0), HWACHA, room)
	layout.add_loot(Vector3(54.5, 0, -59.5), room)
	layout.add_loot(Vector3(38.5, 0, -41.0), room)
	layout.add_loot(Vector3(40.75, 1.9, -61.5), room, true)
	# taking the hwacha wakes the bronze pair and an ashigaru round the cart
	# (every night); an armour walking the hall or a third dog by night
	var woken: Array[int] = []
	woken.append_array(Hub.slots(layout, room, ALWAYS, FU_DOG.duplicate(), [Vector2(43.0, -54.5), Vector2(50.0, -54.5)], 0.0, Vector2(HWACHA.x, HWACHA.z)))
	woken.append_array(Hub.slots(layout, room, ALWAYS, ARMOUR.duplicate(), [Vector2(46.5, -56.0)], 0.0, Vector2(HWACHA.x, HWACHA.z)))
	layout.add_ambush(AmbushSpec.on_pickup(&"asia_hwacha", room, &"weapon_hwacha", woken))
	Hub.walker(layout, &"asia_korea_walk", room, 0, ARMOUR.duplicate(), PackedVector3Array([Vector3(40, 0, -43), Vector3(53, 0, -43)]), false)
	Hub.slots(layout, room, 1, FU_DOG.duplicate(), [Vector2(53.0, -46.0)], 0.0, Vector2(HWACHA.x, HWACHA.z))
	Hub.slots(layout, room, 1, ARMOUR.duplicate(), [Vector2(40.0, -50.0)], 0.0, Vector2(HWACHA.x, HWACHA.z))


# --- the samurai armour hall ------------------------------------------------------------

static func _armor(layout: LevelLayout) -> void:
	var room := &"asia_armor"
	# suits on racks along the walls and on two islands in the middle
	for x in [32.5, 35.0, 37.5, 40.0, 42.5, 45.0]:
		layout.add_piece(&"armor_rack", Vector3(x, 0, -85.4), Vector3(0.8, 2.2, 0.6), room, PI)
	for x in [38.0, 40.5, 52.0, 54.5]:
		layout.add_piece(&"armor_rack", Vector3(x, 0, -63.1), Vector3(0.8, 2.2, 0.6), room)
	for x in [36.5, 44.5]:
		layout.add_piece(&"pedestal", Vector3(x, 0, -74.0), Vector3(6.0, 0.4, 2.0), room)
		for dx in [-2.0, 0.0, 2.0]:
			layout.add_piece(&"armor_rack", Vector3(x + dx, 0.4, -74.0), Vector3(0.8, 2.2, 0.6), room, PI)
	layout.add_piece(&"plinth", Vector3(53.0, 0, -70.0), Vector3(1.4, 1.0, 1.4), room)   # the war drum
	for at: Array in [[Vector3(30.56, 3.5, -74.0), -PI * 0.5], [Vector3(49.94, 3.5, -82.5), PI * 0.5]]:
		var banner := layout.add_piece(&"banner", at[0], Vector3(1.4, 4.0, 0.1), room, at[1], false)
		banner.tint = LACQUER
	for at in [Vector3(36.0, 6.4, -80.0), Vector3(45.0, 6.4, -80.0), Vector3(36.0, 6.4, -68.0), Vector3(45.0, 6.4, -68.0), Vector3(53.0, 6.4, -69.5)]:
		var lantern := layout.add_piece(&"lantern", at, Vector3(0.6, 0.9, 0.6), room, 0.0, false)
		lantern.tint = LANTERN
		Hub.lamp(layout, LightSpec.MAIN, at + Vector3.UP * 0.4, LANTERN, 1.1, 10.0, room)
	Hub.spot(layout, LightSpec.MAIN, Vector3(40.5, 7.4, -70.0), Vector3(40.5, 1.0, -74.0), GOLD, 3.0, 12.0, 40.0, room, true)
	Kit.red(layout, Vector3(33.0, 4.4, -62.7), 0.0, room)
	Kit.red(layout, Vector3(49.8, 3.0, -79.0), PI * 0.5, room)
	layout.add_loot(Vector3(32.0, 0, -64.5), room)
	layout.add_loot(Vector3(54.5, 0, -75.5), room)
	layout.add_loot(Vector3(53.0, 1.0, -70.0), room, true)
	# two armours guard the vault's door every night and step down as the
	# guard comes near; by night more armour, or the Fu dogs
	var guard := Hub.slots(layout, room, ALWAYS, ARMOUR.duplicate(), [Vector2(47.5, -84.0), Vector2(47.5, -78.0)], 0.0, Vector2(40.0, -74.0))
	layout.add_ambush(AmbushSpec.on_area(&"asia_armor_guard", room, Grey.r(43, -85, 50, -77), -0.5, 3.0, guard))
	var middle := Vector2(40.5, -74.0)
	Hub.slots(layout, room, 0, ARMOUR.duplicate(), [Vector2(34.0, -69.0), Vector2(41.0, -66.0)], 0.0, middle)
	Hub.walker(layout, &"asia_armor_rows", room, 0, ARMOUR.duplicate(), PackedVector3Array([Vector3(32.5, 0, -79.5), Vector3(48.5, 0, -77.0), Vector3(48.5, 0, -68.5), Vector3(32.5, 0, -68.5)]))
	Hub.slots(layout, room, 1, FU_DOG.duplicate(), [Vector2(40.5, -66.0), Vector2(54.0, -66.0)], 0.0, middle)
	Hub.slots(layout, room, 1, ARMOUR.duplicate(), [Vector2(33.5, -77.0)], 0.0, middle)
	Hub.slots(layout, room, 2, ARMOUR.duplicate(), [Vector2(36.5, -77.5), Vector2(44.5, -70.5), Vector2(53.5, -73.0)], 0.0, middle)


# --- the Japanese garden (the General's arena) -----------------------------------------

static func _garden(layout: LevelLayout) -> void:
	var room := &"asia_garden"
	# raked gravel (a flat bed, no collision), the pond and its stones
	var gravel := layout.add_piece(&"floor", Vector3(18.25, 0, -74.25), Vector3(11.5, 0.02, 23.5), room, 0.0, false)
	gravel.tint = Color(0.78, 0.76, 0.7)
	var pond := layout.add_piece(&"floor", Vector3(8.5, 0, -73.0), Vector3(5.0, 0.02, 4.0), room, 0.0, false)
	pond.tint = Color(0.12, 0.2, 0.24)
	# rocks in a ring round the General's post: cover from his arrows
	for spec: Array in [[Vector2(8.5, -69.0), 1.4], [Vector2(15.5, -66.5), 1.8], [Vector2(21.5, -68.0), 1.4], [Vector2(26.5, -73.5), 1.8], [Vector2(19.0, -84.0), 1.4], [Vector2(13.5, -78.0), 1.8]]:
		var at: Vector2 = spec[0]
		layout.add_piece(&"rock", Vector3(at.x, 0, at.y), Vector3(2.2, spec[1], 1.8), room, Hub.facing(at, Vector2(GENERAL.x, GENERAL.z)))
	# stone lanterns, warm and low
	for at: Vector2 in [Vector2(13.5, -64.0), Vector2(28.5, -64.0), Vector2(28.5, -78.5), Vector2(5.5, -76.0)]:
		layout.add_piece(&"pedestal", Vector3(at.x, 0, at.y), Vector3(0.7, 1.7, 0.7), room)
		# (the flame in the fire box of the kit's Kasuga lantern: 1.36 m)
		Hub.lamp(layout, LightSpec.MAIN, Vector3(at.x, 1.36, at.y), STONE_LAMP, 0.6, 5.0, room)
	# the cherry tree (only the trunk stops anybody)
	layout.add_piece(&"column", Vector3(23.0, 0, -76.5), Vector3(0.6, 4.5, 0.6), room)
	var crown := layout.add_piece(&"tree_crown", Vector3(23.0, 3.4, -76.5), Vector3(5.0, 3.0, 5.0), room, 0.0, false)
	crown.tint = Color(0.95, 0.72, 0.78)
	# the General and his arena
	layout.add_marker(&"guardian_general", GENERAL, room, Hub.facing(Vector2(GENERAL.x, GENERAL.z), Vector2(CRACK.x, CRACK.z)))
	layout.add_marker(&"arena_general_start", Vector3(8.0, 0, -65.5), room)
	# arena doors: origin in the doorway (just inside), -Z into the arena, X
	# across it (a grille drops into the broken wall and the shrine's door,
	# the tea house's own door locks)
	layout.add_marker(&"arena_general_door_1", Vector3(8.0, 0, -62.75), room)
	layout.add_marker(&"arena_general_door_2", Vector3(12.75, 0, -82.0), room, -PI * 0.5)
	layout.add_marker(&"arena_general_door_3", Vector3(23.75, 0, -83.0), room, PI * 0.5)
	var supplies: Array[Vector3] = [Vector3(6.5, 0, -66.5), Vector3(28.0, 0, -66.5), Vector3(16.0, 0, -84.8)]
	for i in supplies.size():
		layout.add_marker(StringName("arena_general_supply_%d" % (i + 1)), supplies[i], room)
	# the tea house's eave (see EAVE_Y): along its east face and its north
	# face, the General's perch on the corner, turned to his post; his shard
	# falls in the moonlight before the post
	for spec: Array in [[Vector3(13.4, EAVE_Y, -81.75), Vector3(1.8, EAVE_THICK, 8.5)], [Vector3(9.15, EAVE_Y, -76.6), Vector3(10.3, EAVE_THICK, 1.8)]]:
		var eave := layout.add_piece(&"balcony", spec[0], spec[1], room)
		eave.tint = THATCH
	layout.add_marker(&"arena_general_perch", PERCH, room, Hub.facing(Vector2(PERCH.x, PERCH.z), Vector2(GENERAL.x, GENERAL.z)))
	# (the same perch as the General's own point, general_perch -> Guardian.points[&"perch"]: the keeper hands those over)
	layout.add_marker(&"general_perch", PERCH, room, Hub.facing(Vector2(PERCH.x, PERCH.z), Vector2(GENERAL.x, GENERAL.z)))
	layout.add_marker(&"arena_general_reward", Vector3(GENERAL.x, 0, -72.0), room)
	# light: the moon through the open roof, a red lamp by the broken wall
	for pair: Array in [[Vector3(18.0, 15.0, -72.0), Vector3(16.0, 0, -77.0)], [Vector3(8.5, 15.0, -70.0), Vector3(8.0, 0, -72.0)], [Vector3(27.0, 15.0, -70.0), Vector3(26.0, 0, -74.0)]]:
		Hub.spot(layout, Hub.MOON_GROUP, pair[0], pair[1], Hub.MOON, 1.6, 22.0, 24.0, room)
	Kit.red(layout, Vector3(11.0, 3.6, -62.7), 0.0, room)
	layout.add_loot(Vector3(5.5, 0, -64.0), room)
	layout.add_loot(Vector3(26.0, 0, -79.2), room)


static func _teahouse(layout: LevelLayout) -> void:
	var room := &"asia_teahouse"
	var mats := layout.add_piece(&"floor", Vector3(7.0, 0, -82.5), Vector3(6.0, 0.02, 6.0), room, 0.0, false)
	mats.tint = Color(0.72, 0.68, 0.46)
	layout.add_piece(&"desk", Vector3(7.0, 0, -82.5), Vector3(1.2, 0.4, 0.8), room)   # the low table
	layout.haven_spots[&"teahouse"] = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(4.4, 0, -82.0))
	layout.add_marker(&"museum_map_teahouse", Vector3(7.0, 1.6, -85.95), room, PI)
	layout.add_marker(&"note_asia_2", Vector3(7.2, 0.4, -82.5), room)
	layout.add_loot(Vector3(9.5, 0, -79.0), room)
	# (the paper lamp of the dressed interior hangs in the room's middle)
	layout.add_light(LightSpec.HAVEN, Vector3(7.0, 2.8, -82.0), HAVEN_LAMP, 1.2, 7.0, room, &"bulb", true)
	layout.add_light(LightSpec.HAVEN, Vector3(5.0, 1.0, -79.0), LANTERN, 0.7, 4.0, room)


## The service stairs (staff): tube lamps, a red lamp over the bolted
## basement door at their foot.
static func _service(layout: LevelLayout) -> void:
	var room := &"asia_service_stairs"
	var low := Floor1Plan.BASEMENT_Y
	Hub.lamp(layout, LightSpec.MAIN, Vector3(26.0, -0.8, -40.5), Hub.TUBE, 0.8, 7.0, room, &"tube_lamp")
	Hub.lamp(layout, LightSpec.MAIN, Vector3(26.0, 2.6, -51.5), Hub.TUBE, 0.8, 7.0, room, &"tube_lamp")
	Kit.red(layout, Vector3(25.0, low + 2.9, -39.3), 0.0, room)


# --- the three secrets ---------------------------------------------------------------

static func _secrets(layout: LevelLayout) -> void:
	var low := Floor1Plan.BASEMENT_Y
	# 1. the armourer's vault, chained shut off the armour hall (heavy)
	Kit.gate(layout, &"asia_chain_vault", GateSpec.Kind.CHAIN, GateSpec.HEAVY, &"GATE_CHAIN", &"asia_armor_vault", Grey.r(50, -82, 50.5, -80), 0.0, 2.4, &"asia_armor", &"asia_armory_vault", OpeningSpec.DoorStyle.DOUBLE_SWING)
	var vault := &"asia_armory_vault"
	for z in [-84.5, -82.0]:
		layout.add_piece(&"armor_rack", Vector3(55.4, 0, z), Vector3(0.8, 2.2, 0.6), vault, PI * 0.5)
	layout.add_piece(&"crate", Vector3(52.5, 0, -85.4), Vector3(1.2, 0.8, 0.8), vault)   # the chest
	layout.add_loot(Vector3(52.2, 0.8, -85.4), vault, true)
	layout.add_marker(&"note_asia_3", Vector3(52.9, 0.8, -85.4), vault)
	layout.add_loot(Vector3(53.0, 0, -78.0), vault)
	layout.add_marker(&"secret_asia_1", Vector3(53.0, 0, -81.5), vault)
	Kit.glow(layout, Vector3(53.0, 3.7, -81.5), LANTERN, 0.9, vault)
	Kit.lair(layout, &"asia_vault", vault, Vector3(53.5, 0, -80.5), ARMOUR, Grey.r(50.5, -86, 56, -77), -PI * 0.5)
	# 2. the crate store of the 1910 expedition under the China hall, behind
	#    a cracked wall at the foot of the service stairs (a blast)
	Kit.gate(layout, &"asia_cracked_crates", GateSpec.Kind.CRACKED, GateSpec.EXPLOSIVE, &"GATE_CRACKED", &"asia_stairs_crates", Grey.r(23, -48, 23.5, -46), low, 2.4, &"asia_service_stairs", &"asia_crate_store", OpeningSpec.DoorStyle.PANEL)
	var crates := &"asia_crate_store"
	layout.add_piece(&"crate", Vector3(16.4, low, -50.6), Vector3(1.4, 1.2, 1.2), crates)
	layout.add_piece(&"crate", Vector3(16.2, low, -42.5), Vector3(1.2, 1.0, 1.0), crates)
	layout.add_piece(&"crate", Vector3(20.0, low, -50.8), Vector3(1.0, 0.9, 1.0), crates)
	layout.add_marker(&"note_asia_4", Vector3(16.2, low + 1.0, -42.5), crates)
	layout.add_loot(Vector3(16.4, low + 1.2, -50.6), crates, true)
	layout.add_loot(Vector3(20.0, low, -41.2), crates)
	layout.add_marker(&"secret_asia_2", Vector3(18.5, low, -46.0), crates)
	Kit.glow(layout, Vector3(18.5, low + 2.7, -46.0), LANTERN, 0.8, crates)
	Kit.lair(layout, &"asia_crates", crates, Vector3(19.0, low, -44.0), FU_DOG, Grey.r(15, -52, 21, -40), PI * 0.5)
	# 3. the bell shrine off the garden, its grille held by a rope (a
	#    precise shot) - after the General
	Kit.gate(layout, &"asia_rope_shrine", GateSpec.Kind.ROPE, GateSpec.PRECISE, &"GATE_ROPE", &"asia_garden_shrine_door", Grey.r(24, -84, 24.5, -82), 0.0, 2.6, &"asia_garden", &"asia_garden_shrine", OpeningSpec.DoorStyle.GATE)
	var shrine := &"asia_garden_shrine"
	layout.add_piece(&"plinth", Vector3(28.5, 0, -85.3), Vector3(1.2, 1.0, 0.8), shrine)   # the altar
	layout.add_piece(&"sculpture", Vector3(26.0, 0, -85.2), Vector3(1.0, 1.6, 1.0), shrine)   # the bell
	layout.add_loot(Vector3(28.5, 1.0, -85.3), shrine, true)
	layout.add_loot(Vector3(29.0, 0, -81.3), shrine)
	layout.add_marker(&"secret_asia_3", Vector3(27.0, 0, -83.0), shrine)
	Kit.glow(layout, Vector3(27.0, 3.7, -83.0), STONE_LAMP, 0.9, shrine)
	Kit.lair(layout, &"asia_shrine", shrine, Vector3(27.5, 0, -82.0), ARMOUR, Grey.r(24.5, -86, 30, -80.5), -PI * 0.5)

# --- the voice: the System's loudspeakers and the audio guide (plan 2026-10-19-glos-g2-kwestie) ---

## The System by the shutter from the north corridor; stop 7 beside the
## Buddha's lotus base (east, clear of the burner and the columns), stop 8
## between the two rows of armour.
static func _voice(layout: LevelLayout) -> void:
	layout.add_marker(&"loudspeaker_asia_1", Vector3(8.0, 4.0, -39.15), &"asia_china", 0.0)
	layout.add_marker(&"audioguide_buddha", Vector3(18.4, 0.0, -53.4), &"asia_china", PI)
	layout.add_marker(&"audioguide_armour", Vector3(40.5, 0.0, -71.2), &"asia_armor", PI)
