extends RefCounted
## Floor I zone "assyria" (stage P1, workstream W4; plan:
## docs/superpowers/plans/2026-10-03-p1-w4-asyria-ameryki.md). The palaces
## of Nineveh and Nimrud: grey alabaster, bronze and cedar in low, harsh
## light and red torches, built round the palace courtyard.
## - The Khorsabad Gate hall: through the seal doors from the Colossus hall
##   the guard walks between the two lamassu (4.5 m) guarding this side;
##   straight ahead, through the Balawat arch, the Black Obelisk stands lit
##   from below at the end of a 40 m axis.
## - The Balawat Gates room: the bronze-banded seal doors to the Americas
##   (the Wing Seal), cases of bronze bands, two cedar posts, the obelisk.
## - The palace courtyard (30.5 x 27 m, 14 m high, open to the moon): the
##   Lamassu's arena, room to charge, four genii on bases and two cedar
##   columns as cover, relief warriors on its walls for phase 2
##   (lamassu_relief_<n>); its doors to Nimrud and Balawat shut for the
##   fight.
## - The Nimrud palace gallery (36.5 x 13 m): reliefs on both walls, a spine
##   of freestanding slabs; at its far end the conservators' scaffold with
##   the second fuse (taking it wakes the warriors by the scaffold).
## - The Lion Hunt hall from Nineveh: a sunken hunting pit (y -3) under a
##   gallery ring at the ground floor's height, two flights down; relief
##   lions sleep under the gallery. Off the gallery: the bolted door to the
##   Greek Bassae room (the shortcut west). Off the pit, under the gallery:
##   the "lions' gate" to the freight stairs (down to the basement door,
##   bolted on this side) and the royal lion cage (secret: a rope).
## - The library of Ashurbanipal over the freight stairs, between the gate
##   hall and the Lion Hunt gallery; behind a cracked wall the tablet store
##   (secret); off the stairs' foot the freight lift car (secret: a chain).
## Exhibits: relief warriors [wax, relief_warrior] and relief lions
## [wolf, relief_lion] (stand-in first, intended kind after it).

const ZONE := &"assyria"
const Grey := preload("res://src/level/floor1/floor1_greybox.gd")
const Kit := preload("res://src/level/floor1/zones/west_kit.gd")
const Hub := preload("res://src/level/floor1/zones/hub_kit.gd")
const NW := preload("res://src/level/floor1/zones/northwest_kit.gd")
const ALWAYS := SpawnSlot.ALWAYS_SET

const RELIEF_WARRIOR: Array[StringName] = [&"wax", &"relief_warrior"]
const RELIEF_LION: Array[StringName] = [&"wolf", &"relief_lion"]

## Light recipe (design 10.1): low, harsh light and red torches; the moon
## only over the courtyard.
const TORCH := Color(1.0, 0.45, 0.22)
const RAKE := Color(0.74, 0.82, 1.0)
const WORK := Color(1.0, 0.8, 0.56)
const TUBE := Color(0.85, 0.95, 0.88)
## Height of the torches over their floor.
const TORCH_Y := 2.4

## The hunting pit's floor and the basement's.
const PIT_Y := -3.0
const LOW := Floor1Plan.BASEMENT_Y
## The gallery ring of the Lion Hunt hall (x, z): north, south, west, east.
const GALLERY: Array[Rect2] = [Rect2(-96, -38.5, 17, 3), Rect2(-96, -6, 17, 3), Rect2(-96, -35.5, 3, 29.5), Rect2(-82, -35.5, 3, 29.5)]
const LAMASSU_SEAT := Vector3(-78.75, 0.0, -74.0)
const OBELISK := Vector3(-51.0, 0.0, -76.5)
const FUSE := Vector3(-96.5, 0.9, -44.0)
## The courtyard's cover: four genii on bases and two cedar columns.
const GENII: Array[Vector2] = [Vector2(-87, -71), Vector2(-70.5, -71), Vector2(-87, -61.5), Vector2(-70.5, -61.5)]
const CEDARS: Array[Vector2] = [Vector2(-85, -77), Vector2(-72.5, -77)]
## The fire tripods of the dressing (Floor1ArtAssyria.BRAZIERS: their
## flames 1.38 m over these points), against the Balawat room's south wall
## by the Black Obelisk and the courtyard's north wall by the Lamassu's
## plinth. A solid box under each (a stand-in: the fixture draws the tripod),
## or a guard walks through the legs of a fire.
const TRIPODS := {
	&"assyria_balawat": [Vector2(-53.6, -78.55), Vector2(-48.4, -78.55)],
	&"assyria_courtyard": [Vector2(-84.0, -79.6), Vector2(-73.5, -79.6)],
}
## Where the relief warriors step off the arena's walls in phase 2:
## [floor point 0.6 m off the wall, yaw facing into the arena].
const RELIEFS := [
	[Vector3(-93.4, 0, -74), -PI * 0.5], [Vector3(-93.4, 0, -60), -PI * 0.5],
	[Vector3(-64.1, 0, -77), PI * 0.5], [Vector3(-64.1, 0, -58), PI * 0.5],
	[Vector3(-89, 0, -79.4), PI], [Vector3(-68, 0, -79.4), PI],
]


static func build(layout: LevelLayout) -> void:
	_rooms(layout)
	_doors(layout)
	_gate(layout)
	_balawat(layout)
	_courtyard(layout)
	_nimrud(layout)
	_lions(layout)
	_library(layout)
	_freight(layout)
	_secrets(layout)
	_voice(layout)


# --- rooms and passages -----------------------------------------------------

static func _rooms(layout: LevelLayout) -> void:
	Grey.box(layout, &"assyria_gate", Grey.r(-63, -57, -47, -39), 0.0, 10.0, ZONE, &"ROOM_ASSYRIA_GATE")
	Grey.box(layout, &"assyria_balawat", Grey.r(-63, -79, -47, -57.5), 0.0, 8.0, ZONE, &"ROOM_ASSYRIA_BALAWAT")
	var court := Grey.box(layout, &"assyria_courtyard", Grey.r(-94, -80, -63.5, -53), 0.0, 14.0, ZONE, &"ROOM_ASSYRIA_COURTYARD")
	# the open roof: the sky over all but a roofed walk round the walls
	court.skylights.append(Grey.r(-89, -76, -68.5, -57))
	Grey.box(layout, &"assyria_nimrud", Grey.r(-100, -52.5, -63.5, -39.5), 0.0, 8.0, ZONE, &"ROOM_ASSYRIA_NIMRUD")
	Grey.box(layout, &"assyria_lions", Grey.r(-96, -38.5, -79, -3), PIT_Y, 9.0, ZONE, &"ROOM_ASSYRIA_LIONS")
	var gallery := Grey.room(layout, &"assyria_lions_gallery", GALLERY.duplicate(), 0.0, 9.0, ZONE, &"ROOM_ASSYRIA_LIONS_GALLERY")
	gallery.carved = false
	Grey.box(layout, &"assyria_library", Grey.r(-78.5, -38.5, -56.5, -22), 0.0, 6.0, ZONE, &"ROOM_ASSYRIA_LIBRARY")
	# the freight stairs under the library: from the pit's level (y -3,
	# the lions' gate) one flight down west to east to the basement door
	var freight := Grey.stairwell(layout, &"assyria_freight_stairs", Grey.r(-78.5, -38.5, -56, -34), LOW, PIT_Y, Vector2(-1, 0), ZONE, 3.0, &"ROOM_ASSYRIA_FREIGHT")
	freight.ceiling_y = -0.5   # the library's floor slab lies over it
	for spec: Array in [
		[&"assyria_tablets", Grey.r(-74, -21.5, -64, -14), 0.0, 3.0, &"ROOM_ASSYRIA_TABLETS"],
		[&"assyria_lion_cage", Grey.r(-104, -24, -96.5, -16), PIT_Y, 0.0, &"ROOM_ASSYRIA_LION_CAGE"],
		[&"assyria_freight_lift", Grey.r(-62, -33.5, -57, -29.5), LOW, LOW + 3.0, &"ROOM_ASSYRIA_LIFT"],
	]:
		var hidden := Grey.box(layout, spec[0], spec[1], spec[2], spec[3], ZONE, spec[4], false)
		hidden.secret = true


static func _doors(layout: LevelLayout) -> void:
	# the axis from the Khorsabad Gate: through the Balawat arch to the obelisk
	Grey.door(layout, &"assyria_gate_balawat", Grey.r(-54, -57.5, -48, -57), 0.0, 7.0, &"assyria_gate", &"assyria_balawat")
	Grey.door(layout, &"assyria_gate_nimrud", Grey.r(-63.5, -52, -63, -44), 0.0, 6.0, &"assyria_gate", &"assyria_nimrud")
	Grey.door(layout, &"assyria_gate_library", Grey.r(-62, -39, -59, -38.5), 0.0, 3.5, &"assyria_gate", &"assyria_library")
	# the arena's two doors (they shut for the fight)
	Grey.door(layout, &"assyria_nimrud_courtyard", Grey.r(-82, -53, -76, -52.5), 0.0, 7.0, &"assyria_nimrud", &"assyria_courtyard")
	Grey.door(layout, &"assyria_courtyard_balawat", Grey.r(-63.5, -72, -63, -66), 0.0, 7.0, &"assyria_courtyard", &"assyria_balawat")
	# into the Lion Hunt hall on its gallery; the lions' gate under it
	Grey.door(layout, &"assyria_nimrud_lions", Grey.r(-90, -39.5, -86, -38.5), 0.0, 4.0, &"assyria_nimrud", &"assyria_lions_gallery")
	Grey.door(layout, &"assyria_library_lions", Grey.r(-79, -30, -78.5, -27), 0.0, 3.5, &"assyria_library", &"assyria_lions_gallery")
	Grey.door(layout, &"assyria_lions_freight", Grey.r(-79, -38, -78.5, -34.5), PIT_Y, -0.6, &"assyria_lions", &"assyria_freight_stairs")


# --- the Khorsabad Gate hall -------------------------------------------------------

static func _gate(layout: LevelLayout) -> void:
	var room := &"assyria_gate"
	# the two lamassu guarding this side of the gate: bodies along the
	# passage, the bearded heads facing the gate (south), 3.0 m between them
	# (the boxes are the Khorsabad Gate's towers, x +-1.5..3.5 of the axis
	# and from the wall's face to the gate's north face, as the kit asks:
	# docs/art/kit-pietro1-asyria.md 6; the dressing stands the gate model on them)
	for x in [-53.5, -48.5]:
		layout.add_piece(&"lamassu", Vector3(x, 0, -41.5), Vector3(2.0, 4.5, 5.0), room, PI)
	# tribute bearers on the walls; a stele as cover off the axis
	for z in [-41.5, -55.0]:
		NW.relief(layout, Vector3(-62.94, 0.8, z), 3.5, 2.6, -PI * 0.5, room)
	for z in [-43.5, -49.5, -55.0]:
		NW.relief(layout, Vector3(-47.06, 0.8, z), 3.5, 2.6, PI * 0.5, room)
	NW.relief(layout, Vector3(-59.0, 0.8, -56.94), 4.0, 2.6, PI, room)
	layout.add_piece(&"relief_slab", Vector3(-57.5, 0, -48.0), Vector3(3.0, 2.6, 0.6), room, PI * 0.5)
	layout.add_piece(&"bench", Vector3(-48.6, 0, -51.5), Vector3(2.6, 0.5, 0.7), room, PI * 0.5)
	layout.add_marker(&"note_assyria_1", Vector3(-48.6, 0.5, -51.0), room, PI * 0.5)
	for spot in [Vector3(-61.9, 0, -56.1), Vector3(-47.9, 0, -56.2)]:
		layout.add_loot(spot, room)
	# torches low on the walls; cold light from the floor rakes the lamassu
	for z in [-42.0, -55.0]:
		Kit.sconce(layout, Vector3(-62.8, TORCH_Y, z), -PI * 0.5, TORCH, 1.1, room, 7.0)
	for z in [-45.0, -53.5]:
		Kit.sconce(layout, Vector3(-47.2, TORCH_Y, z), PI * 0.5, TORCH, 1.1, room, 7.0)
	Kit.spot(layout, Vector3(-56.5, 0.5, -48.5), Vector3(-53.3, 3.8, -41.5), RAKE, 2.6, 12.0, 26.0, room, true)
	Kit.spot(layout, Vector3(-47.6, 0.5, -48.5), Vector3(-48.7, 3.8, -41.5), RAKE, 2.0, 10.0, 26.0, room)
	Kit.red(layout, Vector3(-55.5, 4.5, -39.2), 0.0, room)
	Kit.red(layout, Vector3(-55.0, 4.6, -56.8), PI, room)
	Kit.camera(layout, &"cctv_assyria_1", Vector3(-47.6, 8.5, -56.4), Vector3(-51, 1.0, -39.5), room)
	# two warriors step off the wall reliefs once the guard is past the
	# lamassu (every night); a third walks the west side
	var woken: Array[int] = []
	for spot: Array in [[Vector3(-61.8, 0, -41.8), -PI * 0.5], [Vector3(-48.2, 0, -54.2), PI * 0.5]]:
		layout.add_spawn(spot[0], room, ALWAYS, RELIEF_WARRIOR.duplicate(), true, spot[1])
		woken.append(layout.spawn_slots.size() - 1)
	layout.add_ambush(AmbushSpec.on_area(&"assyria_gate_reliefs", room, Grey.r(-56, -48, -47.5, -44), -0.5, 3.0, woken))
	Hub.walker(layout, &"assyria_gate_walk", room, 0, RELIEF_WARRIOR.duplicate(), PackedVector3Array([Vector3(-60, 0, -55), Vector3(-60, 0, -43)]), false)
	layout.add_spawn(Vector3(-54.5, 0, -52.5), room, 1, RELIEF_LION.duplicate(), true, PI)
	layout.add_spawn(Vector3(-50.0, 0, -47.0), room, 1, RELIEF_WARRIOR.duplicate(), true, PI)


# --- the Balawat Gates ----------------------------------------------------------

static func _balawat(layout: LevelLayout) -> void:
	var room := &"assyria_balawat"
	# the Black Obelisk of Shalmaneser III closes the axis, lit from below
	layout.add_piece(&"pedestal", OBELISK, Vector3(2.0, 0.6, 2.0), room)
	layout.add_piece(&"obelisk", OBELISK + Vector3(0, 0.6, 0), Vector3(1.2, 4.2, 1.2), room)
	layout.add_marker(&"black_obelisk", OBELISK + Vector3(0, 0.6, 0), room)
	Kit.spot(layout, Vector3(-51.0, 0.4, -73.0), OBELISK + Vector3(0, 3.6, 0), TORCH, 4.0, 9.0, 30.0, room, true)
	# behind it, on an offering stand: the Lewis chess piece
	layout.add_piece(&"plinth", Vector3(-52.6, 0, -78.3), Vector3(0.6, 1.0, 0.6), room)
	layout.add_marker(&"chess_4", Vector3(-52.6, 1.0, -78.3), room)
	# cases of bronze bands along the west wall; bands round the seal doors
	for z in [-76.0, -60.5]:
		layout.add_piece(&"case", Vector3(-61.6, 0, z), Vector3(3.0, 1.4, 1.0), room, PI * 0.5)
	layout.add_loot(Vector3(-61.6, 1.4, -60.5), room, true)
	NW.relief(layout, Vector3(-47.06, 0.6, -71.5), 4.0, 3.0, PI * 0.5, room)
	NW.relief(layout, Vector3(-47.06, 0.6, -59.5), 3.0, 3.0, PI * 0.5, room)
	# two cedar posts as cover, off the axis
	for at in [Vector2(-56, -67), Vector2(-48.4, -71)]:
		layout.add_piece(&"column", Vector3(at.x, 0, at.y), Vector3(1.2, 7.8, 1.2), room)
	for spot in [Vector3(-58.5, 0, -78.2), Vector3(-47.8, 0, -58.3)]:
		layout.add_loot(spot, room)
	_tripods(layout, room)
	for z in [-63.0, -78.0]:
		Kit.sconce(layout, Vector3(-62.8, TORCH_Y, z), -PI * 0.5, TORCH, 1.0, room, 7.0)
	for z in [-68.5, -75.0]:
		Kit.sconce(layout, Vector3(-47.2, TORCH_Y, z), PI * 0.5, TORCH, 1.0, room, 7.0)
	# a glint of bronze on the seal doors to the Americas
	Kit.spot(layout, Vector3(-52.0, 0.5, -64.0), Vector3(-47.0, 2.5, -64.0), WORK, 2.4, 8.0, 34.0, room)
	Kit.red(layout, Vector3(-47.2, 5.5, -66.6), PI * 0.5, room)
	Kit.red(layout, Vector3(-55.0, 4.5, -57.7), 0.0, room)
	layout.add_spawn(Vector3(-58.5, 0, -73.5), room, 0, RELIEF_WARRIOR.duplicate(), true, PI * 0.5)
	layout.add_spawn(Vector3(-54.0, 0, -61.0), room, 0, RELIEF_WARRIOR.duplicate(), true, 0.0)
	layout.add_spawn(Vector3(-48.5, 0, -75.5), room, 0, RELIEF_LION.duplicate(), true, 0.0)
	Hub.walker(layout, &"assyria_balawat_round", room, 1, RELIEF_WARRIOR.duplicate(), PackedVector3Array([Vector3(-58.5, 0, -60.5), Vector3(-58.5, 0, -74), Vector3(-53.5, 0, -74), Vector3(-53.5, 0, -60.5)]))
	layout.add_spawn(Vector3(-49.0, 0, -60.5), room, 1, RELIEF_LION.duplicate(), true, PI)
	layout.add_spawn(Vector3(-60.0, 0, -69.0), room, 1, RELIEF_LION.duplicate(), true, -PI * 0.5)
	layout.add_spawn(Vector3(-59.0, 0, -58.8), room, 2, RELIEF_WARRIOR.duplicate(), true, 0.0)
	layout.add_spawn(Vector3(-55.0, 0, -72.5), room, 2, RELIEF_WARRIOR.duplicate(), true, PI)
	layout.add_spawn(Vector3(-49.0, 0, -68.0), room, 2, RELIEF_WARRIOR.duplicate(), true, PI * 0.5)


## The solid stand-ins under the room's fire tripods (see TRIPODS).
static func _tripods(layout: LevelLayout, room: StringName) -> void:
	for at: Vector2 in TRIPODS.get(room, []):
		layout.add_piece(&"brazier", Vector3(at.x, 0, at.y), Vector3(0.62, 1.4, 0.62), room)


# --- the palace courtyard (the Lamassu's arena) -----------------------------------

static func _courtyard(layout: LevelLayout) -> void:
	var room := &"assyria_courtyard"
	# the Lamassu waits against the north wall, facing the door from Nimrud
	layout.add_marker(&"guardian_lamassu", LAMASSU_SEAT, room, PI)
	layout.add_marker(&"arena_lamassu_start", Vector3(-79.0, 0, -56.0), room)
	# the doors (-Z into the arena): from Nimrud, from Balawat
	layout.add_marker(&"arena_lamassu_door_1", Vector3(-79.0, 0, -53.0), room)
	layout.add_marker(&"arena_lamassu_door_2", Vector3(-63.5, 0, -69.0), room, PI * 0.5)
	var supplies: Array[Vector3] = [Vector3(-91.5, 0, -56.0), Vector3(-66.0, 0, -56.0), Vector3(-91.5, 0, -77.5)]
	for i in supplies.size():
		layout.add_marker(StringName("arena_lamassu_supply_%d" % (i + 1)), supplies[i], room)
	# cover from the charges and the wing gusts: four genii, two cedars (the
	# Lamassu's cover markers: a charge into one of these stuns it)
	for at in GENII:
		layout.add_piece(&"pedestal", Vector3(at.x, 0, at.y), Vector3(2.6, 1.2, 2.6), room)
		layout.add_piece(&"sculpture", Vector3(at.x, 1.2, at.y), Vector3(1.4, 3.2, 1.0), room, PI)
	for at in CEDARS:
		layout.add_piece(&"column", Vector3(at.x, 0, at.y), Vector3(1.2, 13.5, 1.2), room)
	var covers: Array[Vector2] = GENII + CEDARS
	for i in covers.size():
		layout.add_marker(StringName("lamassu_cover_%d" % (i + 1)), Vector3(covers[i].x, 0, covers[i].y), room)
	# its seal and shard fall in the moonlight in the middle of the court
	layout.add_marker(&"arena_lamassu_reward", Vector3(-78.75, 0, -66.5), room)
	# the relief warriors of phase 2 step off these slabs
	for i in RELIEFS.size():
		var spot: Array = RELIEFS[i]
		var at: Vector3 = spot[0]
		var yaw: float = spot[1]
		layout.add_marker(StringName("lamassu_relief_%d" % (i + 1)), at, room, yaw)
		var back := Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.54)
		NW.relief(layout, at + back + Vector3.UP * 0.6, 3.0, 3.0, yaw, room)
	for spot in [Vector3(-92.8, 0, -54.2), Vector3(-64.8, 0, -78.8)]:
		layout.add_loot(spot, room)
	_tripods(layout, room)
	# the moon pours in through the open roof (no fuse: always on); torches
	# low round the walls, one behind the Lamassu throwing it forward
	Hub.spot(layout, Hub.MOON_GROUP, Vector3(-78.75, 13.6, -66.5), Vector3(-78.75, 0, -66.5), Hub.MOON, 2.6, 20.0, 70.0, room, true)
	Kit.sconce(layout, Vector3(-78.75, 2.6, -79.8), PI, TORCH, 1.6, room, 9.0)
	Kit.sconce(layout, Vector3(-93.8, TORCH_Y, -67.0), -PI * 0.5, TORCH, 1.1, room, 7.0)
	for z in [-75.5, -61.5]:
		Kit.sconce(layout, Vector3(-63.7, TORCH_Y, z), PI * 0.5, TORCH, 1.1, room, 7.0)
	for x in [-88.0, -70.0]:
		Kit.sconce(layout, Vector3(x, TORCH_Y, -53.2), 0.0, TORCH, 1.1, room, 7.0)
	Kit.red(layout, Vector3(-83.0, 5.5, -53.2), 0.0, room)
	Kit.red(layout, Vector3(-63.7, 5.5, -72.8), PI * 0.5, room)


# --- the Nimrud palace gallery ----------------------------------------------------

static func _nimrud(layout: LevelLayout) -> void:
	var room := &"assyria_nimrud"
	# relief slabs along both walls (the doors to the courtyard x -82..-76,
	# to the Lion Hunt gallery x -90..-86)
	for x in [-95.5, -89.5, -85.0, -71.5, -66.0]:
		NW.relief(layout, Vector3(x, 0.6, -52.44), 3.5, 2.4, PI, room)
	for x in [-96.0, -80.0, -74.0, -68.0]:
		NW.relief(layout, Vector3(x, 0.6, -39.56), 4.0, 2.4, 0.0, room)
	# a spine of freestanding slabs down the middle: cover, broken sightlines
	for x in [-90.5, -80.0, -69.5]:
		layout.add_piece(&"relief_slab", Vector3(x, 0, -46.0), Vector3(4.0, 2.6, 0.6), room)
	# the conservators' scaffold at the far end, the fuse on their trolley
	layout.add_piece(&"scaffold", Vector3(-99.2, 0, -46.0), Vector3(1.2, 3.2, 4.0), room)
	layout.add_piece(&"desk", Vector3(-96.5, 0, -44.0), Vector3(1.4, 0.9, 0.8), room)
	layout.add_piece(&"crate", Vector3(-96.8, 0, -49.5), Vector3(1.0, 0.9, 1.0), room)
	layout.add_marker(&"fuse_assyria", FUSE, room, PI * 0.5)
	layout.add_loot(Vector3(-96.8, 0.9, -49.5), room, true)
	for spot in [Vector3(-99.2, 0, -40.3), Vector3(-64.3, 0, -40.3)]:
		layout.add_loot(spot, room)
	for x in [-92.5, -71.0]:
		Kit.sconce(layout, Vector3(x, 2.3, -52.3), PI, TORCH, 1.0, room, 7.0)
	for x in [-93.0, -78.0, -66.5]:
		Kit.sconce(layout, Vector3(x, 2.3, -39.7), 0.0, TORCH, 1.0, room, 7.0)
	# cold light raking down the reliefs from the floor at the east end
	Kit.spot(layout, Vector3(-64.5, 0.4, -51.0), Vector3(-98.0, 1.4, -51.6), RAKE, 3.2, 34.0, 16.0, room, true)
	Kit.spot(layout, Vector3(-64.5, 0.4, -41.0), Vector3(-98.0, 1.4, -40.4), RAKE, 2.4, 34.0, 16.0, room)
	# the conservators' work lamp over the trolley
	layout.add_light(LightSpec.MAIN, Vector3(-97.2, 2.6, -45.0), WORK, 2.0, 7.0, room, &"bulb", true)
	Kit.red(layout, Vector3(-83.0, 5.0, -52.3), PI, room)
	Kit.red(layout, Vector3(-91.0, 3.6, -39.7), 0.0, room)
	Kit.camera(layout, &"cctv_assyria_2", Vector3(-64.2, 7.0, -52.0), Vector3(-95.0, 0.8, -45.0), room)
	# taking the fuse wakes the two warriors by the scaffold (every night)
	var woken: Array[int] = []
	for at in [Vector3(-97.4, 0, -51.4), Vector3(-94.0, 0, -40.6)]:
		layout.add_spawn(at, room, ALWAYS, RELIEF_WARRIOR.duplicate(), true, Hub.facing(Vector2(at.x, at.z), Vector2(FUSE.x, FUSE.z)))
		woken.append(layout.spawn_slots.size() - 1)
	layout.add_ambush(AmbushSpec.on_pickup(&"assyria_fuse", room, &"fuse_assyria", woken))
	Hub.walker(layout, &"assyria_nimrud_aisle", room, 0, RELIEF_WARRIOR.duplicate(), PackedVector3Array([Vector3(-92, 0, -42.5), Vector3(-66, 0, -42.5)]), false)
	layout.add_spawn(Vector3(-75.0, 0, -49.5), room, 0, RELIEF_WARRIOR.duplicate(), true, 0.0)
	layout.add_spawn(Vector3(-86.0, 0, -49.5), room, 1, RELIEF_LION.duplicate(), true, 0.0)
	layout.add_spawn(Vector3(-70.0, 0, -42.5), room, 1, RELIEF_LION.duplicate(), true, PI)
	layout.add_spawn(Vector3(-80.0, 0, -42.5), room, 1, RELIEF_WARRIOR.duplicate(), true, PI)
	layout.add_spawn(Vector3(-88.0, 0, -42.5), room, 2, RELIEF_WARRIOR.duplicate(), true, PI)
	layout.add_spawn(Vector3(-74.5, 0, -49.5), room, 2, RELIEF_WARRIOR.duplicate(), true, 0.0)


# --- the Lion Hunt hall: the pit and its gallery ------------------------------------

static func _lions(layout: LevelLayout) -> void:
	var hall := &"assyria_lions"
	var ring := &"assyria_lions_gallery"
	# the gallery: slabs round the walls at the ground floor's height, on
	# posts at the pit's corners and halfway along its long sides
	for part in GALLERY:
		NW.slab(layout, part, 0.0, ring)
	for at in [Vector2(-93.3, -35.2), Vector2(-81.7, -35.2), Vector2(-93.3, -6.3), Vector2(-81.7, -6.3), Vector2(-93.3, -20.75), Vector2(-81.7, -20.75)]:
		layout.add_piece(&"balcony_post", Vector3(at.x, PIT_Y, at.y), Vector3(0.6, -NW.SLAB - PIT_Y, 0.6), hall)
	NW.rail(layout, Vector3(-89.0, 0, -35.575), 8.0, 0.0, ring)
	NW.rail(layout, Vector3(-86.0, 0, -5.925), 8.0, 0.0, ring)
	NW.rail(layout, Vector3(-93.075, 0, -20.75), 29.5, PI * 0.5, ring)
	NW.rail(layout, Vector3(-81.925, 0, -20.75), 29.5, PI * 0.5, ring)
	# two flights down into the pit, at opposite corners: across the pit is
	# the short way from Nimrud to the Greek door, round the gallery the dry one
	var north_east := NW.flight(layout, &"assyria_lions_stairs_ne", Grey.r(-85, -35.5, -82, -27.5), PIT_Y, 0.0, Vector2(0, -1), hall, ring)
	north_east.rail_right = false
	var south_west := NW.flight(layout, &"assyria_lions_stairs_sw", Grey.r(-93, -14, -90, -6), PIT_Y, 0.0, Vector2(0, 1), hall, ring)
	south_west.rail_right = false
	# the royal hunt down in the pit: the king's chariot, relief slabs, cages
	layout.add_piece(&"relief_slab", Vector3(-90.5, PIT_Y, -24.0), Vector3(4.0, 2.6, 0.6), hall)
	layout.add_piece(&"relief_slab", Vector3(-84.0, PIT_Y, -12.0), Vector3(4.0, 2.6, 0.6), hall)
	layout.add_piece(&"chariot", Vector3(-84.5, PIT_Y, -20.5), Vector3(1.8, 1.6, 3.2), hall)
	for at in [Vector2(-91.5, -31.5), Vector2(-91.6, -18.0)]:
		layout.add_piece(&"cage", Vector3(at.x, PIT_Y, at.y), Vector3(1.8, 1.8, 1.8), hall)
	# the Lion Hunt reliefs round the walls over the gallery
	for z in [-31.0, -22.0, -13.0]:
		NW.relief(layout, Vector3(-95.94, 0.9, z), 6.0, 2.4, -PI * 0.5, ring)
	for z in [-21.0, -12.0]:
		NW.relief(layout, Vector3(-79.06, 0.9, z), 6.0, 2.4, PI * 0.5, ring)
	NW.relief(layout, Vector3(-82.5, 0.9, -38.44), 5.0, 2.4, PI, ring)
	NW.relief(layout, Vector3(-93.0, 0.9, -38.44), 4.0, 2.4, PI, ring)
	NW.relief(layout, Vector3(-83.0, 0.9, -3.06), 6.0, 2.4, 0.0, ring)
	layout.add_loot(Vector3(-90.0, PIT_Y, -34.5), hall)
	layout.add_loot(Vector3(-84.5, PIT_Y + 1.6, -20.5), hall, true)
	layout.add_loot(Vector3(-95.2, 0, -4.0), ring)
	# torches over the gallery and down in the pit; cold light rakes the pit
	# from two corners (long shadows of the chariot and the slabs)
	for z in [-26.5, -17.5]:
		Kit.sconce(layout, Vector3(-95.8, TORCH_Y, z), -PI * 0.5, TORCH, 1.1, ring, 7.0)
	for z in [-33.5, -16.5]:
		Kit.sconce(layout, Vector3(-79.2, TORCH_Y, z), PI * 0.5, TORCH, 1.1, ring, 7.0)
	Kit.sconce(layout, Vector3(-88.0, TORCH_Y, -38.3), PI, TORCH, 1.0, ring, 6.0)
	Kit.sconce(layout, Vector3(-93.0, TORCH_Y, -3.2), 0.0, TORCH, 1.0, ring, 6.0)
	Kit.sconce(layout, Vector3(-95.8, PIT_Y + 1.8, -24.0), -PI * 0.5, TORCH, 0.9, hall, 6.0)
	Kit.sconce(layout, Vector3(-79.2, PIT_Y + 1.8, -12.0), PI * 0.5, TORCH, 0.9, hall, 6.0)
	Kit.spot(layout, Vector3(-92.5, PIT_Y + 0.5, -7.0), Vector3(-83.5, PIT_Y + 1.0, -33.5), RAKE, 3.0, 32.0, 22.0, hall, true)
	Kit.spot(layout, Vector3(-82.5, PIT_Y + 0.5, -34.5), Vector3(-91.5, PIT_Y + 1.0, -8.0), RAKE, 2.2, 32.0, 22.0, hall)
	Kit.red(layout, Vector3(-91.5, 3.4, -3.2), 0.0, ring)
	Kit.red(layout, Vector3(-79.2, PIT_Y + 2.0, -33.8), PI * 0.5, hall)
	# two relief lions sleep under the gallery and leap out when the guard
	# drops into the pit (every night)
	var woken: Array[int] = []
	for spot: Array in [[Vector3(-94.5, PIT_Y, -27.0), -PI * 0.5], [Vector3(-80.5, PIT_Y, -14.0), PI * 0.5]]:
		layout.add_spawn(spot[0], hall, ALWAYS, RELIEF_LION.duplicate(), true, spot[1])
		woken.append(layout.spawn_slots.size() - 1)
	layout.add_ambush(AmbushSpec.on_area(&"assyria_lion_hunt", hall, Grey.r(-92, -26, -83, -15), PIT_Y - 0.5, -0.5, woken))
	for spot: Array in [
		[Vector3(-90.5, PIT_Y, -27.5), 0, RELIEF_LION], [Vector3(-84.0, PIT_Y, -16.0), 0, RELIEF_LION],
		[Vector3(-88.5, PIT_Y, -9.5), 0, RELIEF_LION], [Vector3(-86.0, PIT_Y, -25.5), 0, RELIEF_WARRIOR],
		[Vector3(-91.5, PIT_Y, -20.5), 1, RELIEF_LION], [Vector3(-83.0, PIT_Y, -25.0), 1, RELIEF_LION],
		[Vector3(-88.5, PIT_Y, -16.0), 1, RELIEF_WARRIOR], [Vector3(-87.0, PIT_Y, -32.5), 1, RELIEF_WARRIOR],
		[Vector3(-91.0, PIT_Y, -28.5), 2, RELIEF_LION], [Vector3(-83.5, PIT_Y, -9.0), 2, RELIEF_LION],
	]:
		var kinds: Array[StringName] = []
		kinds.assign(spot[2])
		layout.add_spawn(spot[0], hall, spot[1], kinds)
	Hub.walker(layout, &"assyria_pit_run", hall, 2, RELIEF_LION.duplicate(), PackedVector3Array([Vector3(-87.25, PIT_Y, -33.0), Vector3(-87.25, PIT_Y, -9.0)]), false)
	# warriors watch from the gallery, or one walks round it
	layout.add_spawn(Vector3(-92.0, 0, -37.0), ring, 0, RELIEF_WARRIOR.duplicate(), true, 0.0)
	layout.add_spawn(Vector3(-84.0, 0, -4.5), ring, 0, RELIEF_WARRIOR.duplicate(), true, PI)
	Hub.walker(layout, &"assyria_gallery_round", ring, 1, RELIEF_WARRIOR.duplicate(), PackedVector3Array([Vector3(-94.5, 0, -37), Vector3(-80.5, 0, -37), Vector3(-80.5, 0, -4.5), Vector3(-94.5, 0, -4.5)]))
	layout.add_spawn(Vector3(-94.5, 0, -14.0), ring, 1, RELIEF_WARRIOR.duplicate(), true, -PI * 0.5)


# --- the library of Ashurbanipal -----------------------------------------------------

static func _library(layout: LevelLayout) -> void:
	var room := &"assyria_library"
	# two rows of tablet cases (cover), shelves of tablets round the walls
	for x in [-73.0, -67.5, -62.0]:
		for z in [-34.0, -27.0]:
			layout.add_piece(&"case", Vector3(x, 0, z), Vector3(2.6, 1.3, 1.2), room)
	for x in [-75.5, -69.0]:
		layout.add_piece(&"shelf", Vector3(x, 0, -38.15), Vector3(4.0, 2.4, 0.6), room)
	for x in [-75.0, -62.5]:
		layout.add_piece(&"shelf", Vector3(x, 0, -22.35), Vector3(4.0, 2.4, 0.6), room)
	layout.add_piece(&"shelf", Vector3(-56.85, 0, -34.5), Vector3(4.0, 2.4, 0.6), room, PI * 0.5)
	# the Flood Tablet in its own case under a spot; the night reader's desk
	layout.add_piece(&"case", Vector3(-59.5, 0, -30.5), Vector3(1.2, 1.4, 1.0), room)
	layout.add_marker(&"flood_tablet", Vector3(-59.5, 1.4, -30.5), room)
	layout.add_piece(&"desk", Vector3(-76.5, 0, -24.0), Vector3(1.6, 0.78, 0.8), room)
	layout.add_piece(&"chair", Vector3(-76.5, 0, -24.9), Vector3(0.6, 1.0, 0.6), room, PI, false)
	layout.add_marker(&"note_assyria_2", Vector3(-76.2, 0.78, -24.0), room)
	layout.add_loot(Vector3(-67.5, 1.3, -27.0), room, true)
	for spot in [Vector3(-77.7, 0, -32.5), Vector3(-57.5, 0, -23.0)]:
		layout.add_loot(spot, room)
	for z in [-35.0, -24.5]:
		Kit.sconce(layout, Vector3(-78.3, TORCH_Y, z), -PI * 0.5, TORCH, 1.0, room, 7.0)
	Kit.sconce(layout, Vector3(-56.7, TORCH_Y, -26.0), PI * 0.5, TORCH, 1.0, room, 7.0)
	Kit.sconce(layout, Vector3(-66.0, TORCH_Y, -38.3), PI, TORCH, 1.0, room, 7.0)
	layout.add_light(LightSpec.MAIN, Vector3(-77.0, 1.2, -23.8), WORK, 1.0, 5.0, room, &"desk_lamp")
	Kit.spot(layout, Vector3(-59.5, 5.4, -30.5), Vector3(-59.5, 1.4, -30.5), WORK, 2.4, 7.0, 22.0, room)
	Kit.red(layout, Vector3(-60.5, 3.9, -38.3), PI, room)
	layout.add_spawn(Vector3(-70.25, 0, -30.5), room, 0, RELIEF_WARRIOR.duplicate(), true, -PI * 0.5)
	layout.add_spawn(Vector3(-64.75, 0, -24.3), room, 0, RELIEF_WARRIOR.duplicate(), true, 0.0)
	layout.add_spawn(Vector3(-58.3, 0, -24.5), room, 0, RELIEF_LION.duplicate(), true, PI * 0.5)
	layout.add_spawn(Vector3(-76.0, 0, -36.3), room, 1, RELIEF_WARRIOR.duplicate(), true, PI)
	layout.add_spawn(Vector3(-65.0, 0, -36.3), room, 1, RELIEF_WARRIOR.duplicate(), true, PI)
	layout.add_spawn(Vector3(-60.0, 0, -24.5), room, 1, RELIEF_WARRIOR.duplicate(), true, 0.0)
	Hub.walker(layout, &"assyria_library_aisle", room, 2, RELIEF_WARRIOR.duplicate(), PackedVector3Array([Vector3(-76.0, 0, -30.5), Vector3(-63.5, 0, -30.5)]), false)
	layout.add_spawn(Vector3(-74.0, 0, -24.6), room, 2, RELIEF_LION.duplicate(), true, 0.0)


## The freight stairs under the library (staff): tube lamps, crates on the
## long bottom landing, a red lamp over the bolted basement door.
static func _freight(layout: LevelLayout) -> void:
	var room := &"assyria_freight_stairs"
	for x in [-77.0, -71.5, -62.0]:
		layout.add_light(LightSpec.MAIN, Vector3(x, -0.8, -36.25), TUBE, 0.8, 8.0, room, &"tube_lamp")
	Kit.red(layout, Vector3(-56.3, LOW + 2.8, -37.3), PI * 0.5, room)
	layout.add_piece(&"crate", Vector3(-64.5, LOW, -37.85), Vector3(1.2, 1.0, 1.0), room)
	layout.add_piece(&"crate", Vector3(-63.2, LOW, -37.85), Vector3(1.0, 0.8, 1.0), room)
	layout.add_loot(Vector3(-65.8, LOW, -35.0), room)
	layout.add_spawn(Vector3(-62.5, LOW, -36.0), room, 0, RELIEF_LION.duplicate(), true, -PI * 0.5)
	layout.add_spawn(Vector3(-60.0, LOW, -36.5), room, 1, RELIEF_WARRIOR.duplicate(), true, -PI * 0.5)


# --- the three secrets --------------------------------------------------------------

static func _secrets(layout: LevelLayout) -> void:
	# 1. the tablet store behind a cracked wall of the library (a blast)
	Kit.gate(layout, &"assyria_cracked_tablets", GateSpec.Kind.CRACKED, GateSpec.EXPLOSIVE, &"GATE_CRACKED", &"assyria_library_tablets", Grey.r(-70, -22, -68, -21.5), 0.0, 2.4, &"assyria_library", &"assyria_tablets", OpeningSpec.DoorStyle.PANEL)
	var tablets := &"assyria_tablets"
	for x in [-71.5, -66.5]:
		layout.add_piece(&"shelf", Vector3(x, 0, -14.35), Vector3(3.5, 2.2, 0.6), tablets)
	layout.add_piece(&"crate", Vector3(-73.2, 0, -16.0), Vector3(1.0, 0.9, 1.0), tablets)
	layout.add_loot(Vector3(-73.2, 0.9, -16.0), tablets, true)
	layout.add_loot(Vector3(-64.8, 0, -20.6), tablets)
	layout.add_marker(&"secret_assyria_1", Vector3(-69.0, 0, -18.0), tablets)
	Kit.glow(layout, Vector3(-69.0, 2.7, -17.5), WORK, 0.9, tablets)
	Kit.lair(layout, &"assyria_tablets", tablets, Vector3(-66.0, 0, -17.0), RELIEF_WARRIOR, Grey.r(-74, -19.5, -64, -14))
	# 2. the royal lion cage off the hunting pit: its drop gate hangs on a
	#    rope running up out of reach (a precise shot)
	Kit.gate(layout, &"assyria_rope_cage", GateSpec.Kind.ROPE, GateSpec.PRECISE, &"GATE_ROPE", &"assyria_lions_cage", Grey.r(-96.5, -21, -96, -19), PIT_Y, 2.4, &"assyria_lions", &"assyria_lion_cage", OpeningSpec.DoorStyle.GATE)
	var cage := &"assyria_lion_cage"
	layout.add_piece(&"crate", Vector3(-103.2, PIT_Y, -23.0), Vector3(1.4, 0.5, 1.0), cage)
	layout.add_piece(&"crate", Vector3(-103.3, PIT_Y, -17.0), Vector3(1.0, 0.8, 1.0), cage)
	layout.add_marker(&"note_assyria_4", Vector3(-103.3, PIT_Y + 0.8, -17.0), cage)
	layout.add_loot(Vector3(-103.2, PIT_Y + 0.5, -23.0), cage, true)
	layout.add_loot(Vector3(-97.6, PIT_Y, -16.8), cage)
	layout.add_marker(&"secret_assyria_2", Vector3(-100.0, PIT_Y, -20.0), cage)
	Kit.glow(layout, Vector3(-100.5, PIT_Y + 2.7, -20.5), TORCH, 0.8, cage)
	Kit.lair(layout, &"assyria_cage", cage, Vector3(-101.5, PIT_Y, -19.5), RELIEF_LION, Grey.r(-104, -24, -98, -16), -PI * 0.5)
	# 3. the freight lift car at the stairs' foot, its cage gate chained
	Kit.gate(layout, &"assyria_chain_lift", GateSpec.Kind.CHAIN, GateSpec.HEAVY, &"GATE_CHAIN", &"assyria_freight_lift_door", Grey.r(-61, -34, -59, -33.5), LOW, 2.6, &"assyria_freight_stairs", &"assyria_freight_lift", OpeningSpec.DoorStyle.GATE)
	var lift := &"assyria_freight_lift"
	layout.add_piece(&"crate", Vector3(-61.1, LOW, -30.25), Vector3(1.2, 1.4, 1.0), lift)
	layout.add_piece(&"crate", Vector3(-57.9, LOW, -30.25), Vector3(1.2, 1.0, 1.0), lift)
	layout.add_marker(&"note_assyria_3", Vector3(-57.9, LOW + 1.0, -30.25), lift)
	layout.add_loot(Vector3(-61.1, LOW + 1.4, -30.25), lift, true)
	layout.add_marker(&"secret_assyria_3", Vector3(-59.5, LOW, -31.0), lift)
	Kit.glow(layout, Vector3(-59.5, LOW + 2.7, -31.5), WORK, 0.8, lift)
	Kit.lair(layout, &"assyria_lift", lift, Vector3(-59.5, LOW, -32.2), RELIEF_WARRIOR, Grey.r(-62, -33.5, -57, -29.5), 0.0)

# --- the voice: the System's loudspeakers and the audio guide (plan 2026-10-19-glos-g2-kwestie) ---

## The System at the Khorsabad Gate (the gate's wall, between the library
## door and the west lamassu); stop 3 at the west lamassu's flank (five
## legs: it walks seen from the side), stop 4 before the flood tablet's case.
static func _voice(layout: LevelLayout) -> void:
	layout.add_marker(&"loudspeaker_assyria_1", Vector3(-57.5, 4.0, -39.15), &"assyria_gate", 0.0)
	layout.add_marker(&"audioguide_lamassu", Vector3(-56.3, 0.0, -41.0), &"assyria_gate", PI * 0.5)
	layout.add_marker(&"audioguide_flood", Vector3(-58.0, 0.0, -32.4), &"assyria_library", 0.0)
