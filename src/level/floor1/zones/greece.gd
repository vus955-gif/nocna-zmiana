extends RefCounted
## Floor I zone "greece" (stage P1, workstream W3; plan:
## docs/superpowers/plans/2026-10-03-p1-w3-egipt-grecja.md). The bright
## counterpart of dark Egypt: white marble in silver moonlight.
## - The Nereid Monument hall is the way in from the Egyptian tombs (the
##   boarded passage): through the dark doorway the full temple facade on
##   its high podium faces the guard across 15 m of bright hall. A stair
##   along the north wall climbs to a balcony, the podium top and the
##   temple porch (y 4.5), and through a door at that height on to...
## - ...the Bassae room's mezzanine (the frieze up there; a U round the
##   room, its own stair back down): the vertical loop. The bolted door from
##   Assyria's Lion Hunt hall opens on the Bassae room's floor. A rope on the
##   mezzanine (a precise shot) drops the hatch to the loft (secret).
## - The vase room (busts float between the cases; a cracked wall to the
##   potsherd store, secret, and past it an iron ring holding the door of
##   the old casting backroom, secret), the Metope room (Lapiths and
##   centaurs; two marble Lapiths flank the arena's mouth) and the cast
##   store (haven, the last door before the Centaur).
## - The Parthenon gallery (39.5 x 18 m, 12 m high, four skylights): the
##   Centaur's arena, long sightlines, low plinths as cover, pediment
##   groups at both ends.
## - Behind its east end the stair tower: down to the passage under the
##   gallery and the basement door (bolted on this side), up to the entrance
##   hall's landing at y = 6 (bolted on this side: the shortcut home).
## Exhibits: hoplites [knight, hoplite] and busts [bust].

const ZONE := &"greece"
const Grey := preload("res://src/level/floor1/floor1_greybox.gd")
const Kit := preload("res://src/level/floor1/zones/west_kit.gd")
const SWING := OpeningSpec.DoorStyle.SWING
const ALWAYS := SpawnSlot.ALWAYS_SET

const HOPLITE: Array[StringName] = [&"knight", &"hoplite"]
const BUST: Array[StringName] = [&"bust"]

## Light recipe (design 10.1): the brightest wing, silver.
const SILVER := Color(0.86, 0.9, 1.0)
const MARBLE_SPOT := Color(0.95, 0.95, 1.0)
const TUBE := Color(0.85, 0.95, 0.88)
const HAVEN_LAMP := Color(1.0, 0.84, 0.62)
const WARM := Color(1.0, 0.8, 0.56)

## Height of the mezzanines, the podium top and the temple porch.
const UPPER := 4.5
const SLAB := 0.4
const RAIL := Vector3(0.15, 1.1, 0.15)
const CENTAUR := Vector3(-44.0, 0.0, 43.0)


static func build(layout: LevelLayout) -> void:
	_rooms(layout)
	_doors(layout)
	_nereid(layout)
	_bassae(layout)
	_vases(layout)
	_metopes(layout)
	_cast_store(layout)
	_parthenon(layout)
	_service(layout)
	_secrets(layout)
	_voice(layout)


# --- rooms and passages -----------------------------------------------------

static func _rooms(layout: LevelLayout) -> void:
	var nereid := Grey.box(layout, &"greece_nereid", Grey.r(-86, -1.5, -64, 25.5), 0.0, 14.0, ZONE, &"ROOM_GREECE_NEREID")
	nereid.skylights.append(Grey.r(-77, 8, -71, 16))
	nereid.skylights.append(Grey.r(-70, 19, -66, 23))
	var podium := Grey.room(layout, &"greece_nereid_podium", [Grey.r(-86, -1.5, -78, 1.5), Grey.r(-86, 1.5, -83, 7), Grey.r(-86, 7, -79, 17)] as Array[Rect2], UPPER, 14.0, ZONE, &"ROOM_GREECE_PODIUM")
	podium.carved = false
	var bassae := Grey.box(layout, &"greece_bassae", Grey.r(-106, -2, -86.5, 16), 0.0, 10.0, ZONE, &"ROOM_GREECE_BASSAE")
	bassae.skylights.append(Grey.r(-100, 4, -92, 11))
	var mezzanine := Grey.room(layout, &"greece_bassae_gallery", [Grey.r(-106, -2, -86.5, 1.5), Grey.r(-106, 1.5, -102.5, 16)] as Array[Rect2], UPPER, 10.0, ZONE, &"ROOM_GREECE_BASSAE_GALLERY")
	mezzanine.carved = false
	var vases := Grey.box(layout, &"greece_vases", Grey.r(-106, 16.5, -86.5, 36), 0.0, 7.0, ZONE, &"ROOM_GREECE_VASES")
	vases.skylights.append(Grey.r(-100, 24, -92, 28))
	var metopes := Grey.room(layout, &"greece_metopes", [Grey.r(-86, 26, -64.5, 39.5), Grey.r(-78, 39.5, -64.5, 51)] as Array[Rect2], 0.0, 9.0, ZONE, &"ROOM_GREECE_METOPES")
	metopes.skylights.append(Grey.r(-82, 30, -74, 34))
	metopes.skylights.append(Grey.r(-74, 42, -68, 47))
	var store := Grey.box(layout, &"greece_cast_store", Grey.r(-86, 40, -78.5, 52), 0.0, 4.5, ZONE, &"ROOM_GREECE_CAST_STORE", false)
	store.haven = true
	var parthenon := Grey.box(layout, &"greece_parthenon", Grey.r(-64, 34, -24.5, 52), 0.0, 12.0, ZONE, &"ROOM_GREECE_PARTHENON")
	for x in [-57.0, -49.0, -40.0, -31.0]:
		parthenon.skylights.append(Grey.r(x - 2.0, 41, x + 2.0, 45))
	for spec: Array in [[&"greece_bassae_loft", Grey.r(-112, 0, -106.5, 10), UPPER, UPPER + 3.5, &"ROOM_GREECE_LOFT"], [&"greece_pottery", Grey.r(-101, 36.5, -91, 44.5), 0.0, 3.5, &"ROOM_GREECE_POTTERY"], [&"greece_cast_cellar", Grey.r(-96, 45, -86.5, 52), 0.0, 3.5, &"ROOM_GREECE_CELLAR"]]:
		var hidden := Grey.box(layout, spec[0], spec[1], spec[2], spec[3], ZONE, spec[4], false)
		hidden.secret = true
	# the stair tower: four flights of 3 m; its floor (y -6), the middle
	# landing (y 0) and the top landing (y 6) lie at its south end
	Grey.tower(layout, &"greece_service_stairs", Grey.r(-24, 39, -17, 53), Floor1Plan.BASEMENT_Y, Floor1Plan.LANDING_Y, 4, 0, false, ZONE)
	Grey.box(layout, &"greece_service_corridor", Grey.r(-28.5, 31, -24.5, 53), Floor1Plan.BASEMENT_Y, Floor1Plan.BASEMENT_Y + 3.0, ZONE, &"ROOM_GREECE_UNDERCROFT", false)


static func _doors(layout: LevelLayout) -> void:
	Grey.door(layout, &"greece_bassae_nereid", Grey.r(-86.5, 3, -86, 6), 0.0, 3.5, &"greece_bassae", &"greece_nereid")
	Grey.door(layout, &"greece_gallery_podium", Grey.r(-86.5, -1, -86, 1.5), UPPER, UPPER + 2.5, &"greece_bassae_gallery", &"greece_nereid_podium")
	Grey.door(layout, &"greece_bassae_vases", Grey.r(-90, 16, -87, 16.5), 0.0, 4.0, &"greece_bassae", &"greece_vases")
	Grey.door(layout, &"greece_nereid_vases", Grey.r(-86.5, 18, -86, 21.5), 0.0, 4.0, &"greece_nereid", &"greece_vases")
	Grey.door(layout, &"greece_nereid_metopes", Grey.r(-78, 25.5, -71, 26), 0.0, 6.0, &"greece_nereid", &"greece_metopes")
	Grey.door(layout, &"greece_vases_metopes", Grey.r(-86.5, 30, -86, 33), 0.0, 4.0, &"greece_vases", &"greece_metopes")
	# the arena's mouth: the Metope room opens into the Parthenon's west end
	Grey.door(layout, &"greece_metopes_parthenon", Grey.r(-64.5, 37, -64, 49), 0.0, 8.0, &"greece_metopes", &"greece_parthenon")
	Grey.door(layout, &"greece_metopes_store", Grey.r(-78.5, 44, -78, 46), 0.0, 2.6, &"greece_metopes", &"greece_cast_store", SWING)
	# (room order: a swing door's leaf opens into room B, away from the
	# tower's landings where the flights start)
	Grey.door(layout, &"greece_parthenon_stairs", Grey.r(-24.5, 50, -24, 52), 0.0, 2.6, &"greece_service_stairs", &"greece_parthenon", SWING)
	Grey.door(layout, &"greece_corridor_stairs", Grey.r(-24.5, 50.5, -24, 52.5), Floor1Plan.BASEMENT_Y, Floor1Plan.BASEMENT_Y + 2.6, &"greece_service_stairs", &"greece_service_corridor", SWING)


# --- the Nereid Monument --------------------------------------------------------

static func _nereid(layout: LevelLayout) -> void:
	var hall := &"greece_nereid"
	var top := &"greece_nereid_podium"
	# the high podium against the west wall, the temple on it facing east:
	# the cella, four Ionic columns on the front edge, three Nereids between
	# them, the roof and pediment over all
	layout.add_piece(&"pedestal", Vector3(-82.5, 0, 12), Vector3(7, UPPER, 10), hall)
	layout.add_piece(&"landing", Vector3(-84.25, UPPER, 12), Vector3(3.5, 5.0, 7.0), top)
	for z in [8.0, 10.65, 13.35, 16.0]:
		layout.add_piece(&"column", Vector3(-79.7, UPPER, z), Vector3(0.8, 5.0, 0.8), top)
	for z in [9.3, 12.0, 14.7]:
		layout.add_piece(&"sculpture", Vector3(-79.7, UPPER, z), Vector3(0.9, 1.9, 0.9), top, -PI * 0.5)
	layout.add_piece(&"landing", Vector3(-82.5, UPPER + 5.0, 12), Vector3(7.2, 1.6, 10.2), top, 0.0, false)
	# the balcony: along the north wall, down the west wall to the podium
	layout.add_piece(&"balcony", Vector3(-82, UPPER - SLAB, 0), Vector3(8, SLAB, 3), top)
	layout.add_piece(&"balcony", Vector3(-84.5, UPPER - SLAB, 4.25), Vector3(3, SLAB, 5.5), top)
	for post in [Vector3(-78.4, 0, 1.1), Vector3(-83.4, 0, 4.25)]:
		layout.add_piece(&"balcony_post", post, Vector3(0.6, UPPER - SLAB, 0.6), hall)
	_rail(layout, Vector3(-80.5, UPPER, 1.425), 5.0, 0.0, top)
	_rail(layout, Vector3(-82.925, UPPER, 4.25), 5.5, PI * 0.5, top)
	_rail(layout, Vector3(-81.0, UPPER, 7.075), 4.0, 0.0, top)
	_rail(layout, Vector3(-79.075, UPPER, 12.0), 10.0, PI * 0.5, top)
	_rail(layout, Vector3(-82.5, UPPER, 16.925), 7.0, 0.0, top)
	var stairs := layout.add_stairs(&"greece_nereid_stairs", Grey.r(-78, -1.5, -66, 1.0), 0.0, UPPER, Vector2(-1, 0), hall, top)
	stairs.step_rise = Floor1Plan.STAIR_RISE
	stairs.rail_right = false
	# benches face the monument; busts on stands down the hall
	for z in [8.5, 15.5]:
		layout.add_piece(&"bench", Vector3(-70.5, 0, z), Vector3(2.6, 0.5, 0.7), hall, PI * 0.5)
	for spot in [Vector3(-66, 0, 3), Vector3(-66, 0, 24), Vector3(-74, 0, 24), Vector3(-82, 0, 23.5)]:
		layout.add_piece(&"bust_plinth", spot, Vector3(0.7, 1.9, 0.7), hall)
	# behind the cella on the podium: the Lewis chess piece
	layout.add_marker(&"chess_3", Vector3(-84.6, UPPER, 16.3), top)
	layout.add_loot(Vector3(-81.4, UPPER, 12.0), top)
	for spot in [Vector3(-66.0, 0, 13.6), Vector3(-80.0, 0, 21.5)]:
		layout.add_loot(spot, hall)
	# light: the moon through the roof well onto the facade, a marble spot
	# on the temple, silver ceiling lamps, a red lamp by each door
	Kit.spot(layout, Vector3(-69.0, 13.2, 12.0), Vector3(-82.0, 6.0, 12.0), MARBLE_SPOT, 5.0, 20.0, 30.0, hall, true)
	for at in [Vector3(-70, 13.2, 3), Vector3(-70, 13.2, 21), Vector3(-80, 13.2, 21)]:
		layout.add_light(LightSpec.MAIN, at, SILVER, 1.8, 14.0, hall, &"ceiling_lamp")
	layout.add_light(LightSpec.MAIN, Vector3(-82.0, 13.2, 0.5), SILVER, 1.2, 10.0, top, &"ceiling_lamp")
	Kit.red(layout, Vector3(-64.2, 4.0, 15.5), PI * 0.5, hall)
	Kit.red(layout, Vector3(-74.5, 6.6, 25.3), 0.0, hall)
	Kit.camera(layout, &"cctv_greece_1", Vector3(-64.6, 11.0, 25.0), Vector3(-80.0, 2.0, 10.0), hall)
	# encounters: hoplites by the podium's foot or walking round the hall,
	# busts by their stands; two busts wait on the porch for whoever climbs
	layout.add_patrol(&"greece_nereid_round", hall, PackedVector3Array([Vector3(-75, 0, 5), Vector3(-67, 0, 5), Vector3(-67, 0, 20.5), Vector3(-75, 0, 20.5)]))
	layout.add_spawn(Vector3(-77.4, 0, 9.0), hall, 0, HOPLITE.duplicate(), true, -PI * 0.5)
	layout.add_spawn(Vector3(-77.4, 0, 15.0), hall, 0, HOPLITE.duplicate(), true, -PI * 0.5)
	layout.add_spawn(Vector3(-67.5, 0, 3.0), hall, 0, BUST.duplicate())
	layout.add_spawn(Vector3(-74.0, 0, 22.5), hall, 0, BUST.duplicate())
	var walker := layout.add_spawn(Vector3(-75, 0, 5), hall, 1, HOPLITE.duplicate(), false)
	walker.patrol = &"greece_nereid_round"
	for spot in [Vector3(-67.5, 0, 22.5), Vector3(-80.5, 0, 22.0), Vector3(-72.0, 0, 12.0)]:
		layout.add_spawn(spot, hall, 1, BUST.duplicate())
	for z in [9.5, 12.0, 14.5]:
		layout.add_spawn(Vector3(-76.0, 0, z), hall, 2, HOPLITE.duplicate(), true, -PI * 0.5)
	layout.add_spawn(Vector3(-66.0, 0, 10.0), hall, 2, BUST.duplicate())
	var woken: Array[int] = []
	for z in [9.0, 15.0]:
		layout.add_spawn(Vector3(-81.35, UPPER, z), top, ALWAYS, BUST.duplicate(), true, -PI * 0.5)
		woken.append(layout.spawn_slots.size() - 1)
	layout.add_ambush(AmbushSpec.on_area(&"greece_podium", top, Grey.r(-86, 7, -79, 17), UPPER - 0.5, UPPER + 3.0, woken))


# --- the Bassae room and its mezzanine ---------------------------------------------

static func _bassae(layout: LevelLayout) -> void:
	var room := &"greece_bassae"
	var upper := &"greece_bassae_gallery"
	layout.add_piece(&"balcony", Vector3(-96.25, UPPER - SLAB, -0.25), Vector3(19.5, SLAB, 3.5), upper)
	layout.add_piece(&"balcony", Vector3(-104.25, UPPER - SLAB, 8.75), Vector3(3.5, SLAB, 14.5), upper)
	for post in [Vector3(-92.5, 0, 1.1), Vector3(-99.0, 0, 1.1), Vector3(-102.9, 0, 6.0), Vector3(-102.9, 0, 11.0)]:
		layout.add_piece(&"balcony_post", post, Vector3(0.6, UPPER - SLAB, 0.6), room)
	_rail(layout, Vector3(-94.5, UPPER, 1.425), 16.0, 0.0, upper)
	_rail(layout, Vector3(-102.425, UPPER, 7.25), 11.5, PI * 0.5, upper)
	var stairs := layout.add_stairs(&"greece_bassae_stairs", Grey.r(-102.5, 13, -90.5, 16), 0.0, UPPER, Vector2(-1, 0), room, upper)
	stairs.step_rise = Floor1Plan.STAIR_RISE
	stairs.rail_left = false
	# the frieze runs round the mezzanine walls at eye height up there
	for x in [-103.0, -98.5, -94.0, -89.5]:
		layout.add_piece(&"painting", Vector3(x, UPPER + 1.2, -1.95), Vector3(3.8, 0.7, 0.08), upper, PI, false)
	for z in [8.5, 12.5]:
		layout.add_piece(&"painting", Vector3(-105.95, UPPER + 1.2, z), Vector3(3.8, 0.7, 0.08), upper, -PI * 0.5, false)
	# the cult statue of Apollo in the middle of the floor
	layout.add_piece(&"pedestal", Vector3(-96.0, 0, 8.0), Vector3(2.4, 1.0, 2.4), room)
	layout.add_piece(&"sculpture", Vector3(-96.0, 1.0, 8.0), Vector3(1.4, 3.6, 1.4), room)
	layout.add_loot(Vector3(-104.0, 0, -0.5), room)
	layout.add_loot(Vector3(-88.0, UPPER, -1.0), upper)
	layout.add_light(LightSpec.MAIN, Vector3(-96.0, 9.4, 8.0), SILVER, 1.8, 14.0, room, &"ceiling_lamp")
	layout.add_light(LightSpec.MAIN, Vector3(-95.0, 9.4, -0.5), SILVER, 1.2, 10.0, upper, &"ceiling_lamp")
	layout.add_light(LightSpec.MAIN, Vector3(-104.2, 9.4, 9.0), SILVER, 1.0, 9.0, upper, &"ceiling_lamp")
	Kit.red(layout, Vector3(-88.5, 3.5, -1.8), PI, room)
	layout.add_spawn(Vector3(-94.0, 0, 5.0), room, 0, HOPLITE.duplicate(), true, PI)
	layout.add_spawn(Vector3(-99.5, 0, 11.0), room, 0, BUST.duplicate())
	layout.add_spawn(Vector3(-91.0, 0, 9.5), room, 1, BUST.duplicate())
	layout.add_spawn(Vector3(-100.0, 0, 4.5), room, 1, BUST.duplicate())
	layout.add_spawn(Vector3(-95.0, UPPER, -0.3), upper, 0, BUST.duplicate())
	layout.add_spawn(Vector3(-104.25, UPPER, 9.0), upper, 1, BUST.duplicate())


# --- the vase room ------------------------------------------------------------------

static func _vases(layout: LevelLayout) -> void:
	var room := &"greece_vases"
	for x in [-101.0, -96.0, -91.0]:
		for z in [22.0, 30.0]:
			layout.add_piece(&"case", Vector3(x, 0, z), Vector3(1.2, 2.0, 1.2), room)
	layout.add_loot(Vector3(-96.0, 1.0, 22.0), room, true)
	layout.add_loot(Vector3(-101.0, 1.0, 30.0), room, true)
	for z in [19.0, 33.5]:
		layout.add_piece(&"bust_plinth", Vector3(-105.2, 0, z), Vector3(0.7, 1.9, 0.7), room)
	layout.add_loot(Vector3(-88.5, 0, 26.0), room)
	layout.add_light(LightSpec.MAIN, Vector3(-96.0, 6.4, 20.0), SILVER, 1.6, 12.0, room, &"ceiling_lamp")
	layout.add_light(LightSpec.MAIN, Vector3(-96.0, 6.4, 32.5), SILVER, 1.6, 12.0, room, &"ceiling_lamp")
	Kit.red(layout, Vector3(-105.8, 4.0, 26.0), -PI * 0.5, room)
	layout.add_patrol(&"greece_vases_aisle", room, PackedVector3Array([Vector3(-88.5, 0, 18.5), Vector3(-88.5, 0, 34.0)]), false)
	var walker := layout.add_spawn(Vector3(-88.5, 0, 18.5), room, 0, HOPLITE.duplicate(), false)
	walker.patrol = &"greece_vases_aisle"
	layout.add_spawn(Vector3(-98.5, 0, 26.0), room, 0, BUST.duplicate())
	layout.add_spawn(Vector3(-93.5, 0, 26.0), room, 0, BUST.duplicate())
	for spot in [Vector3(-103.5, 0, 22.5), Vector3(-103.5, 0, 30.5), Vector3(-93.5, 0, 34.0)]:
		layout.add_spawn(spot, room, 1, BUST.duplicate())


# --- the Metope room: the arena's antechamber -------------------------------------------

static func _metopes(layout: LevelLayout) -> void:
	var room := &"greece_metopes"
	# metopes (Lapiths and centaurs) on the north and south walls
	for x in [-84.0, -81.5, -69.0, -66.5]:
		layout.add_piece(&"painting", Vector3(x, 3.2, 26.04), Vector3(1.25, 1.25, 0.08), room, PI, false)
	for x in [-84.0, -81.5]:
		layout.add_piece(&"painting", Vector3(x, 3.2, 39.46), Vector3(1.25, 1.25, 0.08), room, 0.0, false)
	for x in [-76.0, -73.5, -71.0, -68.5]:
		layout.add_piece(&"painting", Vector3(x, 3.2, 50.96), Vector3(1.25, 1.25, 0.08), room, 0.0, false)
	# two groups on plinths: cover on the way to the arena
	for spot in [Vector3(-80.0, 0, 33.0), Vector3(-71.0, 0, 33.0)]:
		layout.add_piece(&"pedestal", spot, Vector3(2.4, 1.0, 1.6), room)
		layout.add_piece(&"sculpture", spot + Vector3.UP, Vector3(1.8, 2.2, 1.0), room)
	layout.add_piece(&"bench", Vector3(-75.0, 0, 28.6), Vector3(3.0, 0.5, 0.7), room)
	layout.add_marker(&"note_greece_3", Vector3(-75.6, 0.5, 28.6), room)
	layout.add_loot(Vector3(-85.0, 0, 38.5), room)
	layout.add_loot(Vector3(-77.0, 0, 50.0), room)
	layout.add_light(LightSpec.MAIN, Vector3(-80.0, 8.4, 36.0), SILVER, 1.6, 12.0, room, &"ceiling_lamp")
	layout.add_light(LightSpec.MAIN, Vector3(-71.0, 8.4, 30.0), SILVER, 1.6, 12.0, room, &"ceiling_lamp")
	layout.add_light(LightSpec.MAIN, Vector3(-71.0, 8.4, 49.0), SILVER, 1.4, 11.0, room, &"ceiling_lamp")
	Kit.red(layout, Vector3(-64.7, 6.0, 38.0), PI * 0.5, room)
	layout.add_patrol(&"greece_metopes_watch", room, PackedVector3Array([Vector3(-75.5, 0, 41.5), Vector3(-75.5, 0, 49.5)]), false)
	var guard := layout.add_spawn(Vector3(-75.5, 0, 41.5), room, 0, HOPLITE.duplicate(), false)
	guard.patrol = &"greece_metopes_watch"
	layout.add_spawn(Vector3(-83.0, 0, 30.0), room, 0, BUST.duplicate())
	layout.add_spawn(Vector3(-76.0, 0, 36.5), room, 1, BUST.duplicate())
	layout.add_spawn(Vector3(-68.5, 0, 45.0), room, 1, BUST.duplicate())
	# two marble Lapiths flank the arena's mouth and step down together when
	# the guard heads for the Centaur
	var woken: Array[int] = []
	for z in [35.8, 50.0]:
		layout.add_spawn(Vector3(-66.0, 0, z), room, ALWAYS, HOPLITE.duplicate(), true, PI * 0.5)
		woken.append(layout.spawn_slots.size() - 1)
	layout.add_ambush(AmbushSpec.on_area(&"greece_lapiths", room, Grey.r(-72, 38, -64.5, 48), -0.5, 3.0, woken))


static func _cast_store(layout: LevelLayout) -> void:
	var room := &"greece_cast_store"
	layout.add_piece(&"shelf", Vector3(-80.0, 0, 51.6), Vector3(2.4, 2.2, 0.6), room)
	layout.add_piece(&"shelf", Vector3(-84.0, 0, 51.6), Vector3(2.4, 2.2, 0.6), room)
	layout.add_piece(&"desk", Vector3(-80.5, 0, 41.0), Vector3(1.6, 0.78, 0.8), room)
	layout.add_piece(&"plinth", Vector3(-83.0, 0, 46.0), Vector3(0.8, 1.1, 0.8), room)
	layout.add_piece(&"sculpture", Vector3(-83.0, 1.1, 46.0), Vector3(0.6, 0.8, 0.6), room)
	layout.haven_spots[&"cast_store"] = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-85.6, 0, 42.5))
	layout.add_marker(&"museum_map_cast_store", Vector3(-82.0, 1.6, 40.05), room, PI)
	layout.add_marker(&"note_greece_1", Vector3(-80.2, 0.78, 41.0), room)
	layout.add_loot(Vector3(-79.5, 0, 48.5), room)
	layout.add_light(LightSpec.HAVEN, Vector3(-80.9, 1.2, 40.9), HAVEN_LAMP, 1.4, 6.0, room, &"desk_lamp", true)
	layout.add_light(LightSpec.HAVEN, Vector3(-82.0, 4.1, 46.0), HAVEN_LAMP, 0.9, 8.0, room, &"bulb")


# --- the Parthenon gallery: the Centaur's arena ----------------------------------------

static func _parthenon(layout: LevelLayout) -> void:
	var room := &"greece_parthenon"
	# pediment groups: two at the west end beside the mouth, the long one
	# across the east end (cover from the javelins)
	for z in [35.6, 50.4]:
		layout.add_piece(&"pedestal", Vector3(-61.5, 0, z), Vector3(4.0, 1.2, 1.6), room)
		layout.add_piece(&"sculpture", Vector3(-61.5, 1.2, z), Vector3(3.0, 2.0, 1.0), room, PI * 0.5)
	layout.add_piece(&"pedestal", Vector3(-27.5, 0, 43.0), Vector3(2.5, 1.2, 12.0), room)
	# (the figures are drawn on the pedestal's top: their boxes stay within
	# its 2.5 m, no overhang solid where nothing is drawn)
	for z in [39.0, 43.0, 47.0]:
		layout.add_piece(&"sculpture", Vector3(-27.5, 1.2, z), Vector3(1.0, 2.2, 2.4), room, PI * 0.5)
	# low plinths down both sides: the Centaur circles round them
	for x in [-54.0, -44.5, -35.0]:
		for z in [37.5, 48.5]:
			layout.add_piece(&"plinth", Vector3(x, 0, z), Vector3(1.6, 1.4, 1.6), room)
			layout.add_piece(&"sculpture", Vector3(x, 1.4, z), Vector3(0.9, 2.0, 0.9), room)
	# the Centaur sleeps in his metope in the middle of the gallery: side on
	# to the arena's mouth (facing south), the slab at his left (east), so
	# the guard walking in sees him as a figure in relief
	layout.add_marker(&"guardian_centaur", CENTAUR, room, PI)
	layout.add_marker(&"arena_centaur_start", Vector3(-60.0, 0, 43.0), room, -PI * 0.5)
	layout.add_marker(&"arena_centaur_reward", Vector3(-49.5, 0, 43.0), room)
	# where the Lapiths step down from the pediment groups (phase 2)
	var lapiths: Array[Vector3] = [Vector3(-58.6, 0, 35.8), Vector3(-30.0, 0, 47.0), Vector3(-58.6, 0, 50.2), Vector3(-30.0, 0, 39.0)]
	for i in lapiths.size():
		layout.add_marker(StringName("centaur_lapith_%d" % (i + 1)), lapiths[i], room, -PI * 0.5 if lapiths[i].x < -44.0 else PI * 0.5)
	layout.add_marker(&"arena_centaur_door_1", Vector3(-64.0, 0, 43.0), room, -PI * 0.5)
	layout.add_marker(&"arena_centaur_door_2", Vector3(-24.5, 0, 51.0), room, PI * 0.5)
	var supplies: Array[Vector3] = [Vector3(-58.5, 0, 39.5), Vector3(-31.0, 0, 39.0), Vector3(-44.5, 0, 51.0)]
	for i in supplies.size():
		layout.add_marker(StringName("arena_centaur_supply_%d" % (i + 1)), supplies[i], room)
	# the brightest room of the wing: four skylights, silver lamps, a spot
	# on each pediment
	for x in [-58.0, -44.0, -30.0]:
		for z in [37.5, 48.5]:
			layout.add_light(LightSpec.MAIN, Vector3(x, 11.4, z), SILVER, 2.0, 15.0, room, &"ceiling_lamp")
	# (both pediments' figures throw their shadows on the end walls)
	Kit.spot(layout, Vector3(-36.0, 11.5, 43.0), Vector3(-27.5, 2.5, 43.0), MARBLE_SPOT, 4.0, 16.0, 32.0, room, true)
	Kit.spot(layout, Vector3(-52.0, 11.5, 43.0), Vector3(-61.5, 2.0, 43.0), MARBLE_SPOT, 3.0, 16.0, 40.0, room, true)
	Kit.red(layout, Vector3(-63.8, 9.0, 43.0), -PI * 0.5, room)
	Kit.red(layout, Vector3(-24.7, 3.5, 49.0), PI * 0.5, room)
	Kit.camera(layout, &"cctv_greece_2", Vector3(-25.0, 10.5, 34.6), Vector3(-50.0, 1.0, 45.0), room)


## The stair tower and the passage under the gallery (staff): tube lamps,
## a red lamp over each bolted door.
static func _service(layout: LevelLayout) -> void:
	var tower := &"greece_service_stairs"
	for at in [Vector3(-20.5, -1.0, 51.5), Vector3(-20.5, 5.0, 51.5), Vector3(-20.5, 8.6, 51.5), Vector3(-20.5, 2.2, 40.5)]:
		layout.add_light(LightSpec.MAIN, at, TUBE, 0.8, 7.0, tower, &"tube_lamp")
	Kit.red(layout, Vector3(-17.3, Floor1Plan.LANDING_Y + 2.9, 51.0), PI * 0.5, tower)
	var corridor := &"greece_service_corridor"
	var low := Floor1Plan.BASEMENT_Y
	for z in [34.0, 43.0, 51.0]:
		layout.add_light(LightSpec.MAIN, Vector3(-26.5, low + 2.7, z), TUBE, 0.8, 7.0, corridor, &"tube_lamp")
	Kit.red(layout, Vector3(-27.0, low + 2.6, 31.3), 0.0, corridor)
	layout.add_piece(&"crate", Vector3(-28.0, low, 40.0), Vector3(0.9, 0.9, 0.9), corridor)
	layout.add_piece(&"crate", Vector3(-28.0, low, 46.5), Vector3(0.9, 0.8, 1.2), corridor)
	layout.add_marker(&"note_greece_4", Vector3(-28.0, low + 0.9, 40.0), corridor)
	layout.add_loot(Vector3(-25.2, low, 44.0), corridor)
	layout.add_spawn(Vector3(-26.5, low, 37.0), corridor, 0, BUST.duplicate())
	layout.add_spawn(Vector3(-26.5, low, 48.5), corridor, 1, HOPLITE.duplicate(), true, PI)


# --- the three secrets ---------------------------------------------------------------

static func _secrets(layout: LevelLayout) -> void:
	# 1. the loft over the Bassae mezzanine: its hatch hangs on a rope (a
	#    precise shot: the rifle from anywhere, the pistol from close up)
	Kit.gate(layout, &"greece_rope_loft", GateSpec.Kind.ROPE, GateSpec.PRECISE, &"GATE_ROPE", &"greece_gallery_loft", Grey.r(-106.5, 3, -106, 5.5), UPPER, 2.5, &"greece_bassae_gallery", &"greece_bassae_loft", OpeningSpec.DoorStyle.GATE)
	var loft := &"greece_bassae_loft"
	layout.add_piece(&"crate", Vector3(-111.3, UPPER, 8.9), Vector3(1.0, 0.9, 1.0), loft)
	layout.add_piece(&"crate", Vector3(-111.3, UPPER, 1.1), Vector3(1.0, 0.8, 1.4), loft)
	layout.add_loot(Vector3(-111.3, UPPER + 0.9, 8.9), loft, true)
	layout.add_marker(&"note_greece_2", Vector3(-111.3, UPPER + 0.8, 1.1), loft)
	layout.add_marker(&"secret_greece_1", Vector3(-109.0, UPPER, 5.0), loft)
	Kit.glow(layout, Vector3(-109.5, UPPER + 3.1, 6.0), WARM, 1.0, loft)
	Kit.lair(layout, &"greece_loft", loft, Vector3(-109.5, UPPER, 7.5), BUST, Grey.r(-112, 0, -106.5, 10))
	# 2. the potsherd store behind a cracked wall of the vase room (a blast)
	Kit.gate(layout, &"greece_cracked_pottery", GateSpec.Kind.CRACKED, GateSpec.EXPLOSIVE, &"GATE_CRACKED", &"greece_vases_pottery", Grey.r(-97, 36, -95, 36.5), 0.0, 2.4, &"greece_vases", &"greece_pottery", OpeningSpec.DoorStyle.PANEL)
	var pottery := &"greece_pottery"
	layout.add_piece(&"shelf", Vector3(-100.6, 0, 40.5), Vector3(3.0, 2.0, 0.6), pottery, -PI * 0.5)
	layout.add_piece(&"crate", Vector3(-91.6, 0, 43.8), Vector3(1.0, 0.9, 1.0), pottery)
	layout.add_piece(&"crate", Vector3(-91.6, 0, 42.5), Vector3(1.0, 0.7, 0.8), pottery)
	layout.add_loot(Vector3(-91.6, 0.9, 43.8), pottery, true)
	layout.add_marker(&"secret_greece_2", Vector3(-96.0, 0, 40.5), pottery)
	Kit.glow(layout, Vector3(-96.0, 3.2, 41.0), WARM, 0.9, pottery)
	Kit.lair(layout, &"greece_pottery", pottery, Vector3(-94.0, 0, 41.5), HOPLITE, Grey.r(-101, 37.5, -91, 44.5))
	# 3. the old casting backroom past the potsherd store, its door held by
	#    an iron ring (the harpoon pulls it): a secret inside a secret
	Kit.gate(layout, &"greece_hook_cellar", GateSpec.Kind.HOOK, &"harpoon", &"GATE_HOOK", &"greece_pottery_cellar", Grey.r(-95, 44.5, -93, 45), 0.0, 2.4, &"greece_pottery", &"greece_cast_cellar", OpeningSpec.DoorStyle.GATE)
	var cellar := &"greece_cast_cellar"
	layout.add_piece(&"crate", Vector3(-95.2, 0, 51.2), Vector3(1.2, 1.0, 1.2), cellar)
	layout.add_piece(&"pedestal", Vector3(-89.0, 0, 47.0), Vector3(2.0, 0.9, 1.2), cellar)
	layout.add_loot(Vector3(-95.2, 1.0, 51.2), cellar, true)
	layout.add_marker(&"secret_greece_3", Vector3(-91.0, 0, 49.0), cellar)
	Kit.glow(layout, Vector3(-91.0, 3.2, 49.5), WARM, 0.9, cellar)
	Kit.lair(layout, &"greece_cellar", cellar, Vector3(-93.5, 0, 49.5), HOPLITE, Grey.r(-96, 45, -91, 48), 0.0)


## A balcony or podium railing: [param length] m long, centred at
## [param at] (its foot), along x (yaw 0) or along z (yaw PI/2).
static func _rail(layout: LevelLayout, at: Vector3, length: float, yaw: float, room: StringName) -> void:
	layout.add_piece(&"railing", at, Vector3(length, RAIL.y, RAIL.x), room, yaw)

# --- the voice: the System's loudspeakers and the audio guide (plan 2026-10-19-glos-g2-kwestie) ---

## The System in the Nereid hall (on the east wall, north of the boarded
## door from Egypt); stop 5 before the metopes on the south wall.
static func _voice(layout: LevelLayout) -> void:
	layout.add_marker(&"loudspeaker_greece_1", Vector3(-64.15, 4.0, 6.0), &"greece_nereid", PI * 0.5)
	layout.add_marker(&"audioguide_metopes", Vector3(-83.5, 0.0, 36.6), &"greece_metopes", 0.0)
