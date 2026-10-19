extends RefCounted
## Floor I zone "americas" (stage P1, workstream W4; plan:
## docs/superpowers/plans/2026-10-03-p1-w4-asyria-ameryki.md). Mexico, Rapa
## Nui and the Pacific: dark red walls, turquoise, obsidian and carved wood,
## the most theatrical light of the floor: fire, lit from below.
## - The North America hall behind the fire shutter from the north corridor
##   (power): a tipi, a bison, a kayak, masks; the glow of the totem hall
##   through its north-west arch.
## - The totem hall (12 m high) joins the two halves of the wing.
## - The Moai room behind the bronze Balawat doors from Assyria (the Wing
##   Seal): dark but for one stone head lit from below. An iron ring on the
##   back of its plinth: the harpoon turns it, and behind it stairs lead
##   down into a hideout (secret).
## - The Pacific gallery: the whaling display with the HARPOON (taking it
##   wakes the whalers' watch), and down the gallery's length the floor
##   that caved in, a war canoe hanging over the void and, beyond the bars
##   on its far side, the fire of the Serpent Temple.
## - The collapsed floor: the canoe gate hook_canoe (the harpoon pulls the
##   canoe down across the gap: the only way to the temple). Whoever falls
##   in walks out through the store under the totem hall to the stair tower.
## - The Temple of the Serpent in the Mexico gallery (area americas_temple):
##   a stepped platform of two terraces the Two-headed Serpent coils over,
##   4.5 m walks round it, fire bowls at its corners, one shaft of moon on
##   the altar.
## - The stair tower down to the basement door (bolted on this side), the
##   totem carvers' workshop behind a cracked wall and the boarded-up
##   collection store under the totem hall (secrets).
## Exhibits: totems [bust, totem] and jaguar warriors [wolf, jaguar]
## (stand-in first, intended kind after it).
## The greybox deck over the gap (piece canoe_bridge) stands in for the
## canoe the HookLock lays across it: the game leaves the piece out when
## the real lock is in the build (GateLocks.STAND_INS; the level alone
## keeps it).

const ZONE := &"americas"
const Grey := preload("res://src/level/floor1/floor1_greybox.gd")
const Kit := preload("res://src/level/floor1/zones/west_kit.gd")
const Hub := preload("res://src/level/floor1/zones/hub_kit.gd")
const NW := preload("res://src/level/floor1/zones/northwest_kit.gd")
const ALWAYS := SpawnSlot.ALWAYS_SET
const SWING := OpeningSpec.DoorStyle.SWING

const TOTEM: Array[StringName] = [&"bust", &"totem"]
const JAGUAR: Array[StringName] = [&"wolf", &"jaguar"]

## Light recipe (design 10.1): theatrical, from below, fire.
const FIRE := Color(1.0, 0.5, 0.2)
const EMBER := Color(1.0, 0.3, 0.1)
const UPLIGHT := Color(1.0, 0.62, 0.36)
const LANTERN := Color(1.0, 0.74, 0.46)
const TUBE := Color(0.85, 0.95, 0.88)

const LOW := Floor1Plan.BASEMENT_Y
## The hideout's floor behind the moai.
const HIDE_Y := -3.0
const MOAI := Vector3(-40.5, 0.0, -56.6)
const HARPOON := Vector3(-40.5, 1.0, -79.0)
## The war canoe hanging over the collapsed floor.
const CANOE := Vector3(-27.75, 6.5, -79.0)
const SERPENT := Vector3(-15.5, 3.0, -72.25)
## The temple's stepped platform: the lower terrace (y 1.5), the upper one
## (y 3) and the four flights (3 m wide, 1.5 m over 4 m each).
const TIER := 1.5
const T1 := Rect2(-20, -79, 11.5, 13.5)
const T2 := Rect2(-18, -75, 7.5, 5.5)
const STAIR_X := Vector2(-15.75, -12.75)


static func build(layout: LevelLayout) -> void:
	_rooms(layout)
	_doors(layout)
	_north(layout)
	_totems(layout)
	_moai(layout)
	_pacific(layout)
	_pit(layout)
	_temple(layout)
	_service(layout)
	_secrets(layout)
	_voice(layout)


# --- rooms and passages -----------------------------------------------------

static func _rooms(layout: LevelLayout) -> void:
	Grey.box(layout, &"americas_north", Grey.r(-22, -58, -4, -39), 0.0, 7.0, ZONE, &"ROOM_AMERICAS_NORTH")
	# the stair tower: two flights (up north in the west lane from the
	# basement door to the slab at y -3, back south in the east lane to the
	# top landing at y 0 by the hall's door). (With the first flight in the
	# east lane Recast left that flight without a mesh: keep this order.)
	Grey.tower(layout, &"americas_service_stairs", Grey.r(-29, -52, -22.5, -39), LOW, 0.0, 2, 0, false, ZONE)
	Grey.room(layout, &"americas_totems", [Grey.r(-34.5, -72.5, -25, -58), Grey.r(-34.5, -58, -22.5, -52.5)] as Array[Rect2], 0.0, 12.0, ZONE, &"ROOM_AMERICAS_TOTEMS")
	Grey.box(layout, &"americas_moai", Grey.r(-46, -72.5, -35, -52.5), 0.0, 9.0, ZONE, &"ROOM_AMERICAS_MOAI")
	Grey.box(layout, &"americas_pacific", Grey.r(-46, -85.5, -31, -73), 0.0, 10.0, ZONE, &"ROOM_AMERICAS_PACIFIC")
	Grey.box(layout, &"americas_pit", Grey.r(-30.5, -83, -25, -75), LOW, 10.0, ZONE, &"ROOM_AMERICAS_PIT", false)
	var temple := Grey.box(layout, &"americas_temple", Grey.r(-24.5, -86, -4, -58.5), 0.0, 12.0, ZONE, &"ROOM_AMERICAS_TEMPLE", true, &"americas_temple")
	temple.skylights.append(Grey.r(-16.5, -74.5, -12.5, -70))
	Grey.box(layout, &"americas_undercroft", Grey.r(-29.5, -74.5, -25.5, -52.5), LOW, LOW + 3.0, ZONE, &"ROOM_AMERICAS_UNDERCROFT", false)
	# the hideout behind the moai: a flight down south from the hidden door
	# (top landing at y 0) and the chamber beside it at its foot (y -3)
	var hideout := Grey.stairwell(layout, &"americas_moai_hideout", Grey.r(-41.5, -52, -38.5, -39.5), HIDE_Y, 0.0, Vector2(0, -1), ZONE, 2.5, &"ROOM_AMERICAS_HIDEOUT")
	hideout.parts.append(Grey.r(-46, -49.5, -41.5, -39.5))
	hideout.secret = true
	for spec: Array in [
		[&"americas_workshop", Grey.r(-37.5, -52, -29.5, -44), 0.0, 3.5, &"ROOM_AMERICAS_WORKSHOP"],
		[&"americas_store", Grey.r(-34, -72, -30, -62), LOW, LOW + 3.0, &"ROOM_AMERICAS_STORE"],
	]:
		var hidden := Grey.box(layout, spec[0], spec[1], spec[2], spec[3], ZONE, spec[4], false)
		hidden.secret = true


static func _doors(layout: LevelLayout) -> void:
	# (room order: a swing door's leaf opens into room B, here the hall)
	Grey.door(layout, &"americas_stairs_north", Grey.r(-22.5, -41.25, -22, -39.75), 0.0, 2.6, &"americas_service_stairs", &"americas_north", SWING)
	Grey.door(layout, &"americas_undercroft_stairs", Grey.r(-28.5, -52.5, -26.5, -52), LOW, LOW + 2.6, &"americas_undercroft", &"americas_service_stairs")
	Grey.door(layout, &"americas_totems_north", Grey.r(-22.5, -57.5, -22, -53), 0.0, 6.0, &"americas_totems", &"americas_north")
	Grey.door(layout, &"americas_moai_totems", Grey.r(-35, -66, -34.5, -61), 0.0, 6.0, &"americas_moai", &"americas_totems")
	Grey.door(layout, &"americas_moai_pacific", Grey.r(-42, -73, -38, -72.5), 0.0, 6.0, &"americas_moai", &"americas_pacific")
	Grey.door(layout, &"americas_pacific_totems", Grey.r(-34, -73, -31.5, -72.5), 0.0, 4.0, &"americas_pacific", &"americas_totems")
	# the gallery's floor ends at the edge of the collapse; across the gap
	# the canoe gate into the temple (the harpoon pulls the canoe down)
	Grey.door(layout, &"americas_pacific_pit", Grey.r(-31, -83, -30.5, -75), 0.0, 8.0, &"americas_pacific", &"americas_pit")
	var bridge := Grey.door(layout, &"americas_canoe_bridge", Grey.r(-25, -81, -24.5, -77), 0.0, 5.0, &"americas_pit", &"americas_temple", OpeningSpec.DoorStyle.GATE, RoomGraph.Kind.GATE)
	bridge.face_room = &"americas_pit"
	layout.add_gate(&"hook_canoe", GateSpec.Kind.HOOK, &"americas_canoe_bridge", &"harpoon", &"GATE_HOOK")
	Grey.door(layout, &"americas_pit_undercroft", Grey.r(-28.5, -75, -26.5, -74.5), LOW, LOW + 2.6, &"americas_pit", &"americas_undercroft")


# --- the North America hall ----------------------------------------------------------

static func _north(layout: LevelLayout) -> void:
	var room := &"americas_north"
	# the Plains: a tipi and a bison; the Arctic: a kayak on its stand; the
	# Northwest Coast: masks in cases along the north wall
	layout.add_piece(&"tipi", Vector3(-8.0, 0, -53.0), Vector3(4.2, 5.5, 4.2), room)
	layout.add_piece(&"pedestal", Vector3(-13.0, 0, -50.0), Vector3(2.0, 0.4, 3.4), room)
	layout.add_piece(&"bison", Vector3(-13.0, 0.4, -50.0), Vector3(1.5, 1.9, 3.0), room)
	layout.add_piece(&"pedestal", Vector3(-5.2, 0, -44.5), Vector3(1.0, 0.9, 5.4), room)
	layout.add_piece(&"kayak", Vector3(-5.2, 0.9, -44.5), Vector3(0.7, 0.4, 5.0), room)
	for x in [-18.0, -13.0]:
		layout.add_piece(&"case", Vector3(x, 0, -57.4), Vector3(2.4, 1.6, 1.0), room)
	layout.add_loot(Vector3(-13.0, 1.6, -57.4), room, true)
	layout.add_piece(&"bench", Vector3(-12.0, 0, -44.0), Vector3(3.0, 0.5, 0.7), room)
	layout.add_marker(&"note_americas_2", Vector3(-12.6, 0.5, -44.0), room)
	for spot in [Vector3(-21.2, 0, -49.0), Vector3(-4.8, 0, -57.2)]:
		layout.add_loot(spot, room)
	# fire: bowls by the arch to the totems and in the east, uplights on the
	# tipi and the bison, wall torches; a red lamp over the shutter
	NW.fire(layout, Vector3(-20.3, 0, -51.5), room)
	NW.fire(layout, Vector3(-6.0, 0, -40.6), room)
	Kit.spot(layout, Vector3(-8.0, 0.3, -49.6), Vector3(-8.0, 4.5, -53.0), UPLIGHT, 3.0, 9.0, 34.0, room, true)
	Kit.spot(layout, Vector3(-13.0, 0.3, -46.4), Vector3(-13.0, 1.8, -50.0), UPLIGHT, 2.0, 7.0, 30.0, room)
	Kit.sconce(layout, Vector3(-4.2, 2.6, -50.0), PI * 0.5, FIRE, 1.0, room, 7.0)
	Kit.sconce(layout, Vector3(-21.8, 2.6, -45.0), -PI * 0.5, FIRE, 1.0, room, 7.0)
	Kit.red(layout, Vector3(-17.0, 5.4, -39.2), 0.0, room)
	Kit.camera(layout, &"cctv_americas_1", Vector3(-4.6, 6.2, -57.4), Vector3(-17, 1.0, -39.5), room)
	layout.add_spawn(Vector3(-17.5, 0, -54.0), room, 0, JAGUAR.duplicate(), true, PI)
	layout.add_spawn(Vector3(-9.5, 0, -44.5), room, 0, JAGUAR.duplicate(), true, PI)
	layout.add_spawn(Vector3(-19.5, 0, -46.5), room, 0, TOTEM.duplicate(), true, PI)
	Hub.walker(layout, &"americas_north_round", room, 1, JAGUAR.duplicate(), PackedVector3Array([Vector3(-19, 0, -47), Vector3(-8, 0, -47), Vector3(-8, 0, -42), Vector3(-19, 0, -42)]))
	layout.add_spawn(Vector3(-19.5, 0, -55.3), room, 1, TOTEM.duplicate(), true, PI)
	layout.add_spawn(Vector3(-6.0, 0, -56.0), room, 1, TOTEM.duplicate(), true, PI * 0.5)
	layout.add_spawn(Vector3(-16.0, 0, -55.3), room, 2, JAGUAR.duplicate(), true, PI)
	layout.add_spawn(Vector3(-10.5, 0, -47.5), room, 2, JAGUAR.duplicate(), true, PI)
	layout.add_spawn(Vector3(-8.5, 0, -40.8), room, 2, JAGUAR.duplicate(), true, PI)


# --- the totem hall -----------------------------------------------------------------

static func _totems(layout: LevelLayout) -> void:
	var room := &"americas_totems"
	# poles down the middle and against the east wall, fire at their feet,
	# each lit from below
	for at in [Vector2(-29.75, -69.5), Vector2(-29.75, -62.5), Vector2(-28.5, -55.25), Vector2(-25.6, -66.0)]:
		layout.add_piece(&"totem_pole", Vector3(at.x, 0, at.y), Vector3(1.0, 10.0, 1.0), room)
	NW.fire(layout, Vector3(-29.75, 0, -67.6), room, 1.4, 6.0)
	NW.fire(layout, Vector3(-31.4, 0, -55.25), room, 1.4, 6.0)
	Kit.spot(layout, Vector3(-29.75, 0.3, -71.6), Vector3(-29.75, 8.0, -69.5), UPLIGHT, 3.2, 12.0, 26.0, room, true)
	Kit.spot(layout, Vector3(-29.75, 0.3, -60.4), Vector3(-29.75, 8.0, -62.5), UPLIGHT, 2.6, 12.0, 26.0, room)
	Kit.spot(layout, Vector3(-27.0, 0.3, -66.0), Vector3(-25.6, 8.0, -66.0), UPLIGHT, 2.2, 11.0, 24.0, room)
	Kit.red(layout, Vector3(-22.7, 5.0, -56.8), PI * 0.5, room)
	for spot in [Vector3(-33.6, 0, -59.0), Vector3(-23.2, 0, -53.2)]:
		layout.add_loot(spot, room)
	# one pole is awake every night; a jaguar or another pole join it
	layout.add_spawn(Vector3(-32.2, 0, -66.0), room, ALWAYS, TOTEM.duplicate(), true, -PI * 0.5)
	layout.add_spawn(Vector3(-27.3, 0, -60.0), room, 0, JAGUAR.duplicate(), true, PI)
	layout.add_spawn(Vector3(-27.3, 0, -71.2), room, 1, TOTEM.duplicate(), true, 0.0)
	layout.add_spawn(Vector3(-33.0, 0, -55.0), room, 1, JAGUAR.duplicate(), true, PI)


# --- the Moai room ----------------------------------------------------------------

static func _moai(layout: LevelLayout) -> void:
	var room := &"americas_moai"
	# the head on its plinth at the south end, facing the room; 2.5 m behind
	# it the hidden door (its iron ring on the back of the plinth)
	layout.add_piece(&"pedestal", MOAI, Vector3(3.2, 1.4, 3.2), room)
	layout.add_piece(&"moai", MOAI + Vector3(0, 1.4, 0), Vector3(2.4, 5.2, 2.0), room)
	# carved wooden figures (moai kavakava) in cases along the walls
	for at in [Vector2(-45.2, -70.5), Vector2(-45.2, -56.0), Vector2(-35.8, -70.5)]:
		layout.add_piece(&"case", Vector3(at.x, 0, at.y), Vector3(1.0, 1.8, 1.0), room)
	layout.add_loot(Vector3(-45.2, 1.8, -70.5), room, true)
	layout.add_loot(Vector3(-36.0, 0, -53.3), room)
	# darkness, and the one head lit from below; dim torches by the doors
	Kit.spot(layout, Vector3(-40.5, 0.25, -59.6), MOAI + Vector3(0, 4.6, -0.2), UPLIGHT, 5.0, 9.0, 34.0, room, true)
	Kit.sconce(layout, Vector3(-45.8, 2.4, -67.5), -PI * 0.5, FIRE, 0.6, room, 5.0)
	Kit.sconce(layout, Vector3(-35.2, 2.4, -59.5), PI * 0.5, FIRE, 0.6, room, 5.0)
	Kit.red(layout, Vector3(-36.5, 5.0, -72.3), PI, room)
	Kit.red(layout, Vector3(-45.8, 5.6, -60.6), -PI * 0.5, room)
	# a jaguar crouches beside the plinth and springs when the guard walks
	# up to the head (every night)
	var crouching := Vector3(-43.6, 0, -56.2)
	layout.add_spawn(crouching, room, ALWAYS, JAGUAR.duplicate(), true, 0.0)
	var woken: Array[int] = [layout.spawn_slots.size() - 1]
	layout.add_ambush(AmbushSpec.on_area(&"americas_moai", room, Grey.r(-44, -62, -37, -59), -0.5, 3.0, woken))
	layout.add_spawn(Vector3(-37.0, 0, -69.5), room, 0, JAGUAR.duplicate(), true, PI)
	layout.add_spawn(Vector3(-37.2, 0, -56.5), room, 1, TOTEM.duplicate(), true, 0.0)
	layout.add_spawn(Vector3(-43.5, 0, -70.0), room, 1, JAGUAR.duplicate(), true, PI)


# --- the Pacific gallery ---------------------------------------------------------------

static func _pacific(layout: LevelLayout) -> void:
	var room := &"americas_pacific"
	# the whaling display: a whaleboat on its cradles, harpoons racked on the
	# wall and the harpoon gun on its stand, turned to the canoe
	layout.add_piece(&"whaleboat", Vector3(-44.2, 0, -79.5), Vector3(1.8, 1.3, 7.0), room)
	layout.add_piece(&"harpoon_rack", Vector3(-40.5, 1.2, -85.4), Vector3(3.0, 2.0, 0.15), room, PI, false)
	layout.add_piece(&"plinth", Vector3(HARPOON.x, 0, HARPOON.z), Vector3(0.9, 1.0, 0.7), room)
	layout.add_marker(&"weapon_harpoon", HARPOON, room, -PI * 0.5)
	layout.add_piece(&"crate", Vector3(-41.8, 0, -80.4), Vector3(0.8, 0.9, 0.8), room)
	layout.add_marker(&"note_americas_1", Vector3(-41.8, 0.9, -80.4), room)
	# barkcloth and masks of the islands in cases along the north wall
	for x in [-37.5, -35.0]:
		layout.add_piece(&"case", Vector3(x, 0, -84.9), Vector3(2.2, 1.8, 1.0), room)
	layout.add_loot(Vector3(-37.5, 1.8, -84.9), room, true)
	for spot in [Vector3(-45.3, 0, -84.8), Vector3(-33.0, 0, -81.5)]:
		layout.add_loot(spot, room)
	# the whalers' lantern over the harpoon (its shadow), a fire bowl between
	# the doors, a torch on the west wall
	layout.add_light(LightSpec.MAIN, Vector3(-41.0, 2.8, -80.0), LANTERN, 2.4, 8.0, room, &"bulb", true)
	NW.fire(layout, Vector3(-36.0, 0, -74.0), room, 1.4, 6.0)
	Kit.spot(layout, Vector3(-42.0, 0.3, -76.0), Vector3(-44.2, 2.5, -80.0), UPLIGHT, 1.6, 7.0, 34.0, room)
	Kit.sconce(layout, Vector3(-45.8, 2.6, -75.0), -PI * 0.5, FIRE, 0.9, room, 6.0)
	Kit.red(layout, Vector3(-31.2, 5.2, -84.3), PI * 0.5, room)
	Kit.camera(layout, &"cctv_americas_2", Vector3(-45.4, 8.5, -73.6), Vector3(-38, 0.6, -80), room)
	# taking the harpoon wakes the whalers' watch: a jaguar in the corner, a
	# totem by the edge of the collapse (every night)
	var woken: Array[int] = []
	for spot: Array in [[Vector3(-44.5, 0, -74.3), JAGUAR], [Vector3(-32.0, 0, -84.0), TOTEM]]:
		var kinds: Array[StringName] = []
		kinds.assign(spot[1])
		var at: Vector3 = spot[0]
		layout.add_spawn(at, room, ALWAYS, kinds, true, Hub.facing(Vector2(at.x, at.z), Vector2(HARPOON.x, HARPOON.z)))
		woken.append(layout.spawn_slots.size() - 1)
	layout.add_ambush(AmbushSpec.on_pickup(&"americas_whalers", room, &"weapon_harpoon", woken))
	layout.add_spawn(Vector3(-37.5, 0, -77.5), room, 0, TOTEM.duplicate(), true, PI * 0.5)
	layout.add_spawn(Vector3(-34.5, 0, -78.5), room, 1, JAGUAR.duplicate(), true, PI * 0.5)


## The collapsed floor: 6 m down to the rubble, the deck across it (the
## canoe's stand-in), the war canoe hanging over the void lit from below by
## the embers of the fallen fire display.
static func _pit(layout: LevelLayout) -> void:
	var room := &"americas_pit"
	layout.add_piece(&"canoe_bridge", Vector3(-27.75, -NW.SLAB, -79.0), Vector3(5.5, NW.SLAB, 3.0), room)
	layout.add_piece(&"war_canoe", CANOE + Vector3(0, -0.9, 0), Vector3(1.3, 0.9, 7.4), room, 0.0, false)
	layout.add_marker(&"americas_canoe", CANOE, room, PI * 0.5)
	for spec: Array in [[Vector3(-29.5, LOW, -78.0), Vector3(1.6, 0.8, 1.6)], [Vector3(-26.0, LOW, -82.0), Vector3(1.4, 0.6, 1.2)]]:
		layout.add_piece(&"rubble", spec[0], spec[1], room)
	layout.add_loot(Vector3(-29.6, LOW, -82.2), room)
	layout.add_light(LightSpec.MAIN, Vector3(-27.75, LOW + 0.8, -79.0), EMBER, 2.5, 9.0, room)
	# (from the gap's north end: the deck's shadow misses the canoe)
	Kit.spot(layout, Vector3(-29.5, LOW + 0.4, -82.6), CANOE + Vector3(0, -0.7, 0), FIRE, 4.0, 15.0, 30.0, room, true)
	Kit.red(layout, Vector3(-25.2, 4.2, -76.5), PI * 0.5, room)
	layout.add_spawn(Vector3(-27.75, LOW, -81.8), room, 0, JAGUAR.duplicate(), true, 0.0)
	layout.add_spawn(Vector3(-26.5, LOW, -76.5), room, 1, TOTEM.duplicate(), true, PI)


# --- the Temple of the Serpent (the guardian's arena) ----------------------------------

static func _temple(layout: LevelLayout) -> void:
	var room := &"americas_temple"
	# the stepped platform: two terraces, flights up the north and south faces
	NW.tier(layout, &"temple_tier", T1, 0.0, TIER, room)
	NW.tier(layout, &"temple_tier", T2, TIER, TIER * 2.0, room)
	NW.flight(layout, &"americas_temple_n1", Grey.r(STAIR_X.x, -83, STAIR_X.y, -79), 0.0, TIER, Vector2(0, 1), room, room)
	NW.flight(layout, &"americas_temple_n2", Grey.r(STAIR_X.x, -79, STAIR_X.y, -75), TIER, TIER * 2.0, Vector2(0, 1), room, room)
	NW.flight(layout, &"americas_temple_s1", Grey.r(STAIR_X.x, -65.5, STAIR_X.y, -61.5), 0.0, TIER, Vector2(0, -1), room, room)
	NW.flight(layout, &"americas_temple_s2", Grey.r(STAIR_X.x, -69.5, STAIR_X.y, -65.5), TIER, TIER * 2.0, Vector2(0, -1), room, room)
	# the altar house on the upper terrace; the Lewis chess piece beside it
	layout.add_piece(&"shrine", Vector3(-12.0, TIER * 2.0, -72.25), Vector3(2.4, 2.6, 2.4), room)
	layout.add_piece(&"plinth", Vector3(-11.3, TIER * 2.0, -70.2), Vector3(0.5, 0.8, 0.5), room)
	layout.add_marker(&"chess_5", Vector3(-11.3, TIER * 2.0 + 0.8, -70.2), room)
	# low altars against the side walls (cover), fire bowls at the corners
	for at in [Vector2(-23.5, -72.0), Vector2(-5.0, -72.0)]:
		layout.add_piece(&"altar", Vector3(at.x, 0, at.y), Vector3(1.6, 1.2, 1.6), room)
	for at in [Vector2(-21.2, -84.0), Vector2(-7.3, -84.0), Vector2(-21.2, -61.0), Vector2(-7.3, -61.0)]:
		NW.fire(layout, Vector3(at.x, 0, at.y), room, 1.8, 9.0)
	layout.add_marker(&"guardian_serpent", SERPENT, room, PI * 0.5)
	layout.add_marker(&"arena_serpent_start", Vector3(-22.5, 0, -79.0), room, -PI * 0.5)
	layout.add_marker(&"arena_serpent_door_1", Vector3(-24.5, 0, -79.0), room, -PI * 0.5)
	var supplies: Array[Vector3] = [Vector3(-22.5, 0, -60.5), Vector3(-6.0, 0, -84.5), Vector3(-6.0, 0, -60.5)]
	for i in supplies.size():
		layout.add_marker(StringName("arena_serpent_supply_%d" % (i + 1)), supplies[i], room)
	# the Serpent's tracks (SerpentCourse; the body is 0.52 m thick and
	# weaves 0.25 m): the floor loop round the walks between the fire bowls
	# and the terrace (swerving in past the side altars), crossing the lower
	# flights just over their feet (a low hump); the lower terrace's loop, crossing the upper flights the
	# same way; the links it climbs (pairs: the two lower flights, the gate's
	# posts down to the north flight's foot); the summit
	# track over the upper terrace west of the altar house, through the
	# moon's shaft; and the phase-3 ring round the altar's terrace, 1.1 m off
	# its face, its gate (the first two markers: west and east posts) over
	# the north flight, where the heads rise
	var mid := (STAIR_X.x + STAIR_X.y) * 0.5
	var tracks := {
		"path": [
			Vector3(-23.05, 0, -82.3), Vector3(mid, 0, -82.3), Vector3(-5.45, 0, -82.3), Vector3(-7.1, 0, -72.25),
			Vector3(-5.45, 0, -62.3), Vector3(mid, 0, -62.3), Vector3(-23.05, 0, -62.3), Vector3(-21.4, 0, -72.25),
		],
		"loop": [
			Vector3(-19.1, TIER, -78.3), Vector3(mid, TIER, -78.3), Vector3(-9.4, TIER, -78.3), Vector3(-9.4, TIER, -76.1),
			Vector3(-9.4, TIER, -68.4), Vector3(-9.4, TIER, -66.2), Vector3(mid, TIER, -66.2), Vector3(-19.1, TIER, -66.2),
			Vector3(-19.1, TIER, -68.4), Vector3(-19.1, TIER, -76.1),
		],
		"stair": [
			Vector3(mid, 0, -82.3), Vector3(mid, TIER, -78.3), Vector3(mid, 0, -62.3), Vector3(mid, TIER, -66.2),
			# (the gate's posts down over the north flight's side to its foot:
			# the way the resting serpent leaves its ring without crossing itself)
			Vector3(-16.3, TIER, -76.1), Vector3(mid, TIER, -78.3), Vector3(-12.2, TIER, -76.1), Vector3(mid, TIER, -78.3),
		],
		"summit": [
			Vector3(mid, TIER, -78.3), Vector3(mid, TIER * 2.0, -74.4), Vector3(-15.7, TIER * 2.0, -73.3),
			Vector3(-15.7, TIER * 2.0, -71.2), Vector3(mid, TIER * 2.0, -70.1), Vector3(mid, TIER, -66.2),
		],
		"ring": [
			Vector3(-16.3, TIER, -76.1), Vector3(-12.2, TIER, -76.1), Vector3(-9.4, TIER, -76.1), Vector3(-9.4, TIER, -68.4),
			Vector3(mid, TIER, -68.4), Vector3(-19.1, TIER, -68.4), Vector3(-19.1, TIER, -76.1),
		],
	}
	for group: String in tracks:
		var spots: Array = tracks[group]
		for i in spots.size():
			layout.add_marker(StringName("serpent_%s_%d" % [group, i + 1]), spots[i], room)
	# its reward lies in the moon's shaft on the summit
	layout.add_marker(&"arena_serpent_reward", Vector3(-14.5, TIER * 2.0, -72.25), room)
	for spot in [Vector3(-23.6, 0, -85.3), Vector3(-4.7, 0, -59.2)]:
		layout.add_loot(spot, room)
	# fire from below up both faces, a flame on the altar house, a single
	# shaft of moon onto the upper terrace through the roof
	Kit.spot(layout, Vector3(-14.25, 0.3, -84.8), Vector3(-14.25, 4.0, -73.0), UPLIGHT, 4.0, 16.0, 28.0, room, true)
	Kit.spot(layout, Vector3(-14.25, 0.3, -59.4), Vector3(-14.25, 4.0, -71.5), UPLIGHT, 3.0, 16.0, 28.0, room)
	layout.add_light(LightSpec.MAIN, Vector3(-12.0, TIER * 2.0 + 3.0, -72.25), FIRE, 1.2, 6.0, room)
	Hub.spot(layout, Hub.MOON_GROUP, Vector3(-14.5, 11.6, -72.25), Vector3(-14.5, TIER * 2.0, -72.25), Hub.MOON, 2.0, 12.0, 22.0, room)
	Kit.red(layout, Vector3(-24.3, 5.4, -76.6), -PI * 0.5, room)


## The stair tower and the store under the totem hall (staff): tube lamps,
## a red lamp over the bolted basement door.
static func _service(layout: LevelLayout) -> void:
	var tower := &"americas_service_stairs"
	for at in [Vector3(-25.75, 2.6, -40.2), Vector3(-25.75, -0.6, -50.8), Vector3(-27.0, -1.0, -40.2)]:
		layout.add_light(LightSpec.MAIN, at, TUBE, 0.8, 7.0, tower, &"tube_lamp")
	Kit.red(layout, Vector3(-27.0, LOW + 2.8, -39.2), 0.0, tower)
	var store := &"americas_undercroft"
	for z in [-70.0, -61.0, -55.0]:
		layout.add_light(LightSpec.MAIN, Vector3(-27.5, LOW + 2.7, z), TUBE, 0.7, 7.0, store, &"tube_lamp")
	Kit.red(layout, Vector3(-29.3, LOW + 2.6, -67.0), -PI * 0.5, store)
	layout.add_piece(&"crate", Vector3(-26.1, LOW, -66.0), Vector3(0.9, 0.9, 1.2), store)
	layout.add_piece(&"crate", Vector3(-26.1, LOW, -58.0), Vector3(0.9, 1.1, 1.0), store)
	layout.add_loot(Vector3(-28.8, LOW, -56.0), store)
	layout.add_spawn(Vector3(-27.5, LOW, -63.0), store, 0, JAGUAR.duplicate(), true, PI)
	Hub.walker(layout, &"americas_undercroft_walk", store, 1, JAGUAR.duplicate(), PackedVector3Array([Vector3(-27.5, LOW, -72.0), Vector3(-27.5, LOW, -55.0)]), false)


# --- the three secrets ------------------------------------------------------------------

static func _secrets(layout: LevelLayout) -> void:
	# 1. the hideout behind the moai: the harpoon hooks the ring on the back
	#    of its plinth, the head turns, stairs lead down into the dark
	Kit.gate(layout, &"americas_hook_moai", GateSpec.Kind.HOOK, &"harpoon", &"GATE_HOOK", &"americas_moai_hideout_door", Grey.r(-41.5, -52.5, -39.5, -52), 0.0, 2.4, &"americas_moai", &"americas_moai_hideout", OpeningSpec.DoorStyle.GATE)
	var hideout := &"americas_moai_hideout"
	layout.add_piece(&"crate", Vector3(-45.3, HIDE_Y, -46.0), Vector3(0.9, 0.5, 1.8), hideout)
	layout.add_piece(&"crate", Vector3(-45.3, HIDE_Y, -41.0), Vector3(1.0, 0.9, 1.0), hideout)
	layout.add_marker(&"note_americas_3", Vector3(-45.3, HIDE_Y + 0.5, -46.0), hideout)
	layout.add_loot(Vector3(-45.3, HIDE_Y + 0.9, -41.0), hideout, true)
	layout.add_loot(Vector3(-42.5, HIDE_Y, -40.3), hideout)
	layout.add_marker(&"secret_americas_1", Vector3(-43.5, HIDE_Y, -44.0), hideout)
	Kit.glow(layout, Vector3(-43.5, HIDE_Y + 2.7, -44.5), FIRE, 0.9, hideout)
	Kit.lair(layout, &"americas_hideout", hideout, Vector3(-43.5, HIDE_Y, -47.5), JAGUAR, Grey.r(-46, -49.5, -41.5, -39.5), PI)
	# 2. the totem carvers' workshop behind a cracked wall of the totem hall
	#    (a blast); the unfinished pole still lies on the floor
	Kit.gate(layout, &"americas_cracked_workshop", GateSpec.Kind.CRACKED, GateSpec.EXPLOSIVE, &"GATE_CRACKED", &"americas_totems_workshop", Grey.r(-33.5, -52.5, -31.5, -52), 0.0, 2.4, &"americas_totems", &"americas_workshop", OpeningSpec.DoorStyle.PANEL)
	var workshop := &"americas_workshop"
	layout.add_piece(&"totem_log", Vector3(-33.5, 0, -46.0), Vector3(6.0, 1.0, 1.0), workshop)
	layout.add_piece(&"desk", Vector3(-36.6, 0, -49.5), Vector3(2.0, 0.9, 0.9), workshop, PI * 0.5)
	layout.add_loot(Vector3(-36.6, 0.9, -49.5), workshop, true)
	layout.add_loot(Vector3(-30.3, 0, -44.8), workshop)
	layout.add_marker(&"secret_americas_2", Vector3(-33.5, 0, -49.0), workshop)
	Kit.glow(layout, Vector3(-33.5, 3.2, -48.5), FIRE, 0.9, workshop)
	Kit.lair(layout, &"americas_workshop", workshop, Vector3(-31.0, 0, -50.5), TOTEM, Grey.r(-37.5, -52, -29.5, -47.5), 0.0)
	# 3. the collection store under the totem hall, boarded up in the 1930s
	Kit.gate(layout, &"americas_boards_store", GateSpec.Kind.BOARDS, GateSpec.HEAVY, &"GATE_BOARDS", &"americas_undercroft_store", Grey.r(-30, -68, -29.5, -66), LOW, 2.4, &"americas_undercroft", &"americas_store", OpeningSpec.DoorStyle.DOUBLE_SWING)
	var store := &"americas_store"
	layout.add_piece(&"crate", Vector3(-33.4, LOW, -70.5), Vector3(1.0, 1.2, 1.4), store)
	layout.add_piece(&"crate", Vector3(-33.4, LOW, -64.0), Vector3(1.0, 0.9, 1.2), store)
	layout.add_marker(&"note_americas_4", Vector3(-33.4, LOW + 0.9, -64.0), store)
	layout.add_loot(Vector3(-33.4, LOW + 1.2, -70.5), store, true)
	layout.add_loot(Vector3(-31.0, LOW, -71.2), store)
	layout.add_marker(&"secret_americas_3", Vector3(-32.0, LOW, -67.0), store)
	Kit.glow(layout, Vector3(-32.0, LOW + 2.7, -67.5), LANTERN, 0.8, store)
	Kit.lair(layout, &"americas_store", store, Vector3(-31.5, LOW, -63.5), JAGUAR, Grey.r(-34, -70, -30, -62))

# --- the voice: the System's loudspeakers and the audio guide (plan 2026-10-19-glos-g2-kwestie) ---

## The System by the shutter from the north corridor (under the painted
## frieze, which runs at about 4 m); stop 9 at the totems' door from the
## north hall, stop 10 before the moai (off the way across).
static func _voice(layout: LevelLayout) -> void:
	layout.add_marker(&"loudspeaker_americas_1", Vector3(-10.0, 3.3, -39.15), &"americas_north", 0.0)
	layout.add_marker(&"audioguide_totems", Vector3(-26.5, 0.0, -58.8), &"americas_totems", -PI * 0.5)
	layout.add_marker(&"audioguide_moai", Vector3(-38.0, 0.0, -60.2), &"americas_moai", 0.0)
