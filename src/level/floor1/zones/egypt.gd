extends RefCounted
## Floor I zone "egypt" (stage P1, workstream W3; plan:
## docs/superpowers/plans/2026-10-03-p1-w3-egipt-grecja.md). The gold
## standard wing and the game's first "wow":
## - the Rosetta vestibule off the Great Court: through its 15 m arch the
##   first long view down the Great Gallery, past two rows of colossi in
##   warm spotlights and cold moon pools, to the lit 1898 expedition camp
##   with the SHOTGUN on its table (on the main path, seen from the court
##   door) and on to the seated Colossus at the far end;
## - the Great Gallery (16 x 32.5 m, 11 m high): mummies wake from the
##   sarcophagi round the camp when the guard takes the gun;
## - the Colossus hall (24 x 24 m, 14 m high), Ramesses' arena: papyrus
##   columns as cover from the beam (markers colossus_column_<n>: the
##   guardian's script raises breakable columns there, ColossusColumn; they
##   crack and break), the Khorsabad Gate to Assyria in its north wall, a
##   side door from the tombs;
## - the tombs west of the gallery (dark, low): the tomb passage, the burial
##   chambers (the boarded passage to Greece), the sarcophagus hall; the
##   conservator's room (haven) off the burial chambers;
## - the service stairs down to the basement door (bolted on this side);
## - three secrets behind zone gates (no false panels: see the plan): the
##   expedition's store (chained, off the service stairs), the serdab
##   (cracked wall: a blast) and the priest's tomb behind a false door
##   (an iron ring: the harpoon).
## Exhibits: mummies [wax, mummy], scarab swarms [wolf, scarabs] and wax
## "archaeologists" [wax] (stand-in first, intended kind after it).

const ZONE := &"egypt"
const Grey := preload("res://src/level/floor1/floor1_greybox.gd")
const Kit := preload("res://src/level/floor1/zones/west_kit.gd")
const SWING := OpeningSpec.DoorStyle.SWING
const NONE := OpeningSpec.DoorStyle.NONE
const ALWAYS := SpawnSlot.ALWAYS_SET

## Stand-in kind first (NightSpawner falls back for unknown kinds), the
## intended one after it.
const MUMMY: Array[StringName] = [&"wax", &"mummy"]
const SCARABS: Array[StringName] = [&"wolf", &"scarabs"]
const ARCHAEOLOGIST: Array[StringName] = [&"wax"]

## Light recipe (design 10.1): a cold moon, warm spotlights on the colossi,
## the camp's oil lamps, faint tomb torches; the darkest wing.
const SPOT_WARM := Color(1.0, 0.78, 0.5)
const OIL := Color(1.0, 0.68, 0.36)
const TORCH := Color(1.0, 0.58, 0.3)
const MOON := Color(0.6, 0.7, 1.0)
const TUBE := Color(0.85, 0.95, 0.88)
const HAVEN_LAMP := Color(1.0, 0.84, 0.62)

## The gallery's two rows of colossi (x of the rows, z of the pairs).
const COLOSSUS_ROWS: Array[float] = [-48.0, -36.0]
const COLOSSUS_Z: Array[float] = [12.0, 4.5, -3.0, -10.5]
## The painted beams across the nave (stage P2 art: z of each, between the
## light wells) and, per pair of colossi, the beam their spotlights hang
## from (a museum spotlight clamped under the beam, aimed across the nave).
const BEAMS_Z: Array[float] = [17.5, 10.25, 6.0, 2.75, -1.25, -8.75]
const SPOT_BEAM := {12.0: 10.25, 4.5: 2.75, -3.0: -1.25, -10.5: -8.75}
## The spotlight's lens under a beam (the beam's underside is 10.3 m; the
## clamp reaches 0.45 m above the lens).
const SPOT_Y := 9.85
## The arena's papyrus columns (ColossusColumn: cracked by the second hit of
## the Colossus's beam, broken by the third).
const COLUMNS: Array[Vector2] = [
	Vector2(-50.5, -18), Vector2(-50.5, -25), Vector2(-46.5, -21.5), Vector2(-38.5, -21.5),
	Vector2(-34.5, -18), Vector2(-34.5, -25), Vector2(-34.5, -32),
]
## Where the shotgun lies: the camp table, halfway up the gallery.
const SHOTGUN := Vector3(-43.0, 0.85, 3.0)
const COLOSSUS_SEAT := Vector3(-42.5, 0.0, -32.5)


static func build(layout: LevelLayout) -> void:
	_rooms(layout)
	_doors(layout)
	_vestibule(layout)
	_gallery(layout)
	_camp(layout)
	_arena(layout)
	_tombs(layout)
	_conservator(layout)
	_service(layout)
	_secrets(layout)
	_voice(layout)


# --- rooms and passages -----------------------------------------------------

static func _rooms(layout: LevelLayout) -> void:
	Grey.box(layout, &"egypt_vestibule", Grey.r(-50, 19.5, -31, 30), 0.0, 7.5, ZONE, &"ROOM_EGYPT_VESTIBULE")
	var gallery := Grey.box(layout, &"egypt_gallery", Grey.r(-50, -13.5, -34, 19), 0.0, 11.0, ZONE, &"ROOM_EGYPT_GALLERY")
	# clerestory light wells down the nave: cold moon pools between the colossi
	for z in [13.0, 6.5, -6.0, -12.5]:
		gallery.skylights.append(Grey.r(-43, z, -41, z + 3.0))
	var arena := Grey.box(layout, &"egypt_colossus", Grey.r(-55, -38, -31, -14), 0.0, 14.0, ZONE, &"ROOM_EGYPT_COLOSSUS")
	arena.skylights.append(Grey.r(-47, -28, -38, -20))
	Grey.box(layout, &"egypt_tomb_passage", Grey.r(-55, -13.5, -50.5, 0), 0.0, 4.0, ZONE, &"ROOM_EGYPT_TOMB_PASSAGE")
	Grey.room(layout, &"egypt_tombs", [Grey.r(-56.5, 0.5, -50.5, 7.5), Grey.r(-63, 7.5, -50.5, 15)] as Array[Rect2], 0.0, 4.0, ZONE, &"ROOM_EGYPT_TOMB")
	var conservator := Grey.box(layout, &"egypt_conservator", Grey.r(-63, 0.5, -57, 7), 0.0, 3.5, ZONE, &"ROOM_EGYPT_CONSERVATOR", false)
	conservator.haven = true
	Grey.box(layout, &"egypt_tomb_hall", Grey.r(-60, 15.5, -50.5, 30), 0.0, 4.5, ZONE, &"ROOM_EGYPT_SARCOPHAGI")
	for spec: Array in [[&"egypt_tomb_serdab", Grey.r(-63, 15.5, -60.5, 21), &"ROOM_EGYPT_SERDAB"], [&"egypt_tomb_priest", Grey.r(-63, 21.5, -60.5, 30), &"ROOM_EGYPT_PRIEST"], [&"egypt_cache", Grey.r(-33.5, 11, -31, 19), &"ROOM_EGYPT_CACHE"]]:
		var hidden := Grey.box(layout, spec[0], spec[1], 0.0, 3.0, ZONE, spec[2], false)
		hidden.secret = true
	# the service stairs along the court wall: 16 m of flight rising south to
	# the gallery's staff door. At their foot an L-shaped store under the
	# gallery floor holds the bolted basement door: the junction's door
	# leaf swings in along the store's north wall, so the way to the stairs
	# goes round it, through the stairwell's west wall
	Grey.stairwell(layout, &"egypt_service_stairs", Grey.r(-33.5, -10, -31, 10.5), Floor1Plan.BASEMENT_Y, 0.0, Vector2(0, 1), ZONE, 2.5)
	Grey.room(layout, &"egypt_service_corridor", [Grey.r(-40, -13, -31, -10.5), Grey.r(-40, -10.5, -34, -7.5)] as Array[Rect2], Floor1Plan.BASEMENT_Y, Floor1Plan.BASEMENT_Y + 3.0, ZONE, &"ROOM_EGYPT_UNDERCROFT", false)


static func _doors(layout: LevelLayout) -> void:
	# the reveal: a 15 m arch from the low vestibule into the 11 m gallery
	Grey.door(layout, &"egypt_vestibule_gallery", Grey.r(-49.5, 19, -34.5, 19.5), 0.0, 7.0, &"egypt_vestibule", &"egypt_gallery")
	Grey.door(layout, &"egypt_gallery_colossus", Grey.r(-47.5, -14, -37.5, -13.5), 0.0, 10.0, &"egypt_gallery", &"egypt_colossus")
	Grey.door(layout, &"egypt_passage_colossus", Grey.r(-54, -14, -52, -13.5), 0.0, 3.0, &"egypt_tomb_passage", &"egypt_colossus")
	Grey.door(layout, &"egypt_gallery_passage", Grey.r(-50.5, -8.5, -50, -6), 0.0, 3.0, &"egypt_gallery", &"egypt_tomb_passage")
	Grey.door(layout, &"egypt_passage_tombs", Grey.r(-54, 0, -52, 0.5), 0.0, 3.0, &"egypt_tomb_passage", &"egypt_tombs")
	Grey.door(layout, &"egypt_gallery_tombs", Grey.r(-50.5, 7.5, -50, 10), 0.0, 3.5, &"egypt_gallery", &"egypt_tombs")
	Grey.door(layout, &"egypt_tombs_conservator", Grey.r(-57, 2.5, -56.5, 4.5), 0.0, 2.6, &"egypt_tombs", &"egypt_conservator", SWING)
	Grey.door(layout, &"egypt_tombs_hall", Grey.r(-56, 15, -53.5, 15.5), 0.0, 3.0, &"egypt_tombs", &"egypt_tomb_hall")
	Grey.door(layout, &"egypt_vestibule_hall", Grey.r(-50.5, 25.5, -50, 28.5), 0.0, 3.5, &"egypt_vestibule", &"egypt_tomb_hall")
	# (room order: a swing door's leaf opens into room B, here the gallery)
	Grey.door(layout, &"egypt_gallery_stairs", Grey.r(-34, 8.25, -33.5, 10.25), 0.0, 2.6, &"egypt_service_stairs", &"egypt_gallery", SWING)
	Grey.door(layout, &"egypt_stairs_corridor", Grey.r(-34, -9.75, -33.5, -8.25), Floor1Plan.BASEMENT_Y, Floor1Plan.BASEMENT_Y + 2.6, &"egypt_service_corridor", &"egypt_service_stairs")


# --- the vestibule ------------------------------------------------------------

static func _vestibule(layout: LevelLayout) -> void:
	var room := &"egypt_vestibule"
	# the Rosetta Stone in its case, facing the court door
	layout.add_piece(&"case", Vector3(-43, 0, 25.5), Vector3(2.2, 2.0, 1.6), room, -PI * 0.5)
	layout.add_marker(&"rosetta_stone", Vector3(-43, 1.0, 25.5), room, -PI * 0.5)
	layout.add_piece(&"bench", Vector3(-38.5, 0, 26.5), Vector3(3, 0.5, 0.7), room, PI * 0.5)
	# an obelisk frames the arch on the west (the east side stays clear: the
	# line from the court door to the camp runs there)
	layout.add_piece(&"sculpture", Vector3(-48.75, 0, 21.25), Vector3(1.0, 5.5, 1.0), room)
	layout.add_marker(&"note_egypt_3", Vector3(-38.5, 0.5, 25.9), room, PI * 0.5)
	# the System: a loudspeaker on the court wall beside the arch (the arch
	# is 7 m high: "over the door" hung it in mid-air); the audio guide's
	# stop 1 a step and a half in front of the stone, pulpit toward the
	# visitor coming from the court
	layout.add_marker(&"loudspeaker_egypt_1", Vector3(-31.05, 4.6, 28.0), room, PI * 0.5)
	layout.add_marker(&"audioguide_rosetta", Vector3(-40.7, 0, 24.0), room, -PI * 0.5)
	for spot in [Vector3(-48.5, 0, 28.5), Vector3(-33.0, 0, 28.8)]:
		layout.add_loot(spot, room)
	var stone_lamp := Kit.spot(layout, Vector3(-38.5, 7.0, 25.5), Vector3(-43, 1.2, 25.5), SPOT_WARM, 4.0, 10.0, 22.0, room, true)
	stone_lamp.fixture = &"egypt_spotlight"
	layout.add_light(LightSpec.MAIN, Vector3(-40.5, 6.9, 24.75), MOON, 0.6, 12.0, room, &"ceiling_lamp")
	Kit.red(layout, Vector3(-49.8, 4.6, 28.5), -PI * 0.5, room)
	# two archaeologists of the temporary exhibition by the stone, or one
	# and a mummy
	layout.add_spawn(Vector3(-46.5, 0, 23.0), room, 0, ARCHAEOLOGIST.duplicate(), true, -PI * 0.5)
	layout.add_spawn(Vector3(-44.0, 0, 28.5), room, 0, ARCHAEOLOGIST.duplicate(), true, PI)
	layout.add_spawn(Vector3(-47.5, 0, 28.0), room, 1, ARCHAEOLOGIST.duplicate(), true, -PI * 0.5)
	layout.add_spawn(Vector3(-36.5, 0, 28.8), room, 1, MUMMY.duplicate())


# --- the Great Gallery ---------------------------------------------------------

static func _gallery(layout: LevelLayout) -> void:
	var room := &"egypt_gallery"
	# two rows of colossi on pedestals, facing the nave, each in a warm
	# spotlight from across the nave
	for x in COLOSSUS_ROWS:
		var west := x < -42.0
		for z in COLOSSUS_Z:
			layout.add_piece(&"pedestal", Vector3(x, 0, z), Vector3(2.6, 1.0, 2.6), room)
			layout.add_piece(&"sculpture", Vector3(x, 1.0, z), Vector3(2.0, 6.0, 2.0), room, -PI * 0.5 if west else PI * 0.5)
			var from := Vector3(x + (5.5 if west else -5.5), SPOT_Y, float(SPOT_BEAM[z]))
			var lamp := Kit.spot(layout, from, Vector3(x, 4.8, z), SPOT_WARM, 3.0, 13.0, 24.0, room, z > 10.0)
			lamp.fixture = &"egypt_spotlight"
	# a cold fill under the light wells, a red lamp at each end
	for z in [14.5, -4.5]:
		layout.add_light(LightSpec.MAIN, Vector3(-42, 10.4, z), MOON, 0.5, 14.0, room)
	Kit.red(layout, Vector3(-49.8, 5.0, 17.5), -PI * 0.5, room)
	Kit.red(layout, Vector3(-34.2, 5.0, -12.0), PI * 0.5, room)
	for spot in [Vector3(-47.5, 0, 0.6), Vector3(-36.0, 0, -6.8), Vector3(-36.2, 0, 16.6)]:
		layout.add_loot(spot, room)
	# the camera over the vestibule arch looks down the nave
	Kit.camera(layout, &"cctv_egypt_1", Vector3(-34.6, 9.5, 18.4), Vector3(-44, 0.8, -4), room)
	# one archaeologist walks the east side of the nave, there and back
	layout.add_patrol(&"egypt_gallery_nave", room, PackedVector3Array([Vector3(-38.6, 0, 16.5), Vector3(-38.6, 0, -12.0)]), false)
	var walker := layout.add_spawn(Vector3(-38.6, 0, 16.5), room, 0, ARCHAEOLOGIST.duplicate(), false)
	walker.patrol = &"egypt_gallery_nave"
	layout.add_spawn(Vector3(-45.5, 0, 8.6), room, 0, MUMMY.duplicate(), true, -PI * 0.5)
	layout.add_spawn(Vector3(-45.5, 0, -8.0), room, 1, MUMMY.duplicate(), true, -PI * 0.5)
	layout.add_spawn(Vector3(-38.6, 0, -8.5), room, 1, SCARABS.duplicate())
	var second := layout.add_spawn(Vector3(-38.6, 0, -12.0), room, 2, ARCHAEOLOGIST.duplicate(), false, PI)
	second.patrol = &"egypt_gallery_nave"
	layout.add_spawn(Vector3(-45.6, 0, 15.5), room, 2, SCARABS.duplicate())


## The expedition camp of 1898 halfway up the gallery: the tent, crates, the
## map table with the shotgun, two oil lamps (the brightest spot of the
## wing) and three sarcophagi the expedition dug up. Taking the gun wakes the
## mummies lying by them and a scarab swarm (every night: ALWAYS_SET).
static func _camp(layout: LevelLayout) -> void:
	var room := &"egypt_gallery"
	layout.add_piece(&"crate", Vector3(-44.25, 0, 0.0), Vector3(3.5, 2.4, 3.0), room)   # the tent
	layout.add_piece(&"desk", Vector3(-43.0, 0, 3.0), Vector3(1.6, 0.85, 0.9), room)
	layout.add_piece(&"crate", Vector3(-45.4, 0, 2.7), Vector3(1.0, 0.9, 1.0), room)
	layout.add_piece(&"crate", Vector3(-45.4, 0, 3.9), Vector3(1.0, 0.9, 1.0), room)
	layout.add_marker(&"weapon_shotgun", SHOTGUN, room, PI)
	layout.add_marker(&"note_egypt_1", Vector3(-43.55, 0.85, 3.15), room, PI)
	layout.add_loot(Vector3(-45.4, 0.9, 3.9), room, true)
	layout.add_light(LightSpec.MAIN, Vector3(-43.2, 2.3, 2.0), OIL, 3.0, 9.0, room, &"bulb", true)
	# (the oil lamp stands on the crate: its flame 0.17 m over the crate's top)
	layout.add_light(LightSpec.MAIN, Vector3(-45.4, 1.07, 2.7), OIL, 1.2, 5.0, room, &"desk_lamp")
	# the expedition's finds: two sarcophagi east of the camp, one north
	layout.add_piece(&"plinth", Vector3(-40.0, 0, 5.2), Vector3(1.0, 0.9, 2.4), room)
	layout.add_piece(&"plinth", Vector3(-40.0, 0, -2.6), Vector3(1.0, 0.9, 2.4), room)
	layout.add_piece(&"plinth", Vector3(-44.5, 0, -5.4), Vector3(1.0, 0.9, 2.4), room, PI * 0.5)
	var woken: Array[int] = []
	for spot: Array in [[Vector3(-41.6, 0, 4.2), PI], [Vector3(-41.6, 0, -2.6), 0.0], [Vector3(-44.5, 0, -6.8), 0.0]]:
		layout.add_spawn(spot[0], room, ALWAYS, MUMMY.duplicate(), true, spot[1])
		woken.append(layout.spawn_slots.size() - 1)
	layout.add_spawn(Vector3(-38.6, 0, 7.6), room, ALWAYS, SCARABS.duplicate())
	woken.append(layout.spawn_slots.size() - 1)
	layout.add_ambush(AmbushSpec.on_pickup(&"egypt_camp", room, &"weapon_shotgun", woken))


# --- the Colossus hall (arena) --------------------------------------------------

static func _arena(layout: LevelLayout) -> void:
	var room := &"egypt_colossus"
	# Ramesses sits against the north wall, facing the gallery; his throne
	# and base come with the guardian (keep x -46.5..-38.5, z -37.5..-28.5 free)
	layout.add_marker(&"guardian_colossus", COLOSSUS_SEAT, room, PI)
	layout.add_marker(&"arena_colossus_start", Vector3(-42.5, 0, -16.5), room)
	layout.add_marker(&"arena_colossus_door_1", Vector3(-42.5, 0, -14.0), room)
	layout.add_marker(&"arena_colossus_door_2", Vector3(-53.0, 0, -14.0), room)
	var supplies: Array[Vector3] = [Vector3(-42.5, 0, -17.5), Vector3(-53.0, 0, -22.0), Vector3(-32.5, 0, -21.5)]
	for i in supplies.size():
		layout.add_marker(StringName("arena_colossus_supply_%d" % (i + 1)), supplies[i], room)
	# the seal and the shard fall in the moonlight under the roof well
	layout.add_marker(&"arena_colossus_reward", Vector3(-42.5, 0, -24.0), room)
	# the columns are the guardian's (they break): only their places here
	for i in COLUMNS.size():
		layout.add_marker(StringName("colossus_column_%d" % (i + 1)), Vector3(COLUMNS[i].x, 0, COLUMNS[i].y), room)
	# behind the throne, an offering stand: the Lewis chess piece
	layout.add_piece(&"plinth", Vector3(-36.0, 0, -36.8), Vector3(0.6, 1.0, 0.6), room)
	layout.add_marker(&"chess_2", Vector3(-36.0, 1.0, -36.8), room)
	# two warm spotlights on the Colossus, the moon through the roof well,
	# torches on the side walls, red lamps by the doors
	var target := COLOSSUS_SEAT + Vector3(0, 6.0, 0)
	for lamp in [Kit.spot(layout, Vector3(-50.0, 12.5, -21.0), target, SPOT_WARM, 6.0, 22.0, 28.0, room, true),
			Kit.spot(layout, Vector3(-35.0, 12.5, -21.0), target, SPOT_WARM, 6.0, 22.0, 28.0, room)]:
		(lamp as LightSpec).fixture = &"egypt_spotlight"
	Kit.spot(layout, Vector3(-42.5, 13.4, -24.0), Vector3(-42.5, 0, -24.5), MOON, 2.5, 16.0, 35.0, room)
	for z in [-20.0, -30.0]:
		Kit.sconce(layout, Vector3(-54.8, 3.5, z), -PI * 0.5, TORCH, 0.9, room)
		Kit.sconce(layout, Vector3(-31.2, 3.5, z), PI * 0.5, TORCH, 0.9, room)
	Kit.red(layout, Vector3(-47.0, 4.5, -14.2), 0.0, room)
	Kit.red(layout, Vector3(-51.0, 3.6, -14.2), 0.0, room)


# --- the tombs ------------------------------------------------------------------

static func _tombs(layout: LevelLayout) -> void:
	# the tomb passage: standing coffins, the side door into the arena
	var passage := &"egypt_tomb_passage"
	for z in [-9.0, -4.0]:
		layout.add_piece(&"crate", Vector3(-54.4, 0, z), Vector3(0.86, 2.0, 0.76), passage, PI * 0.5)   # (a MummyTomb coffin's size)
	Kit.sconce(layout, Vector3(-50.7, 2.6, -3.0), PI * 0.5, TORCH, 0.5, passage)
	layout.add_loot(Vector3(-52.6, 0, -1.4), passage)
	layout.add_spawn(Vector3(-52.6, 0, -11.0), passage, 0, SCARABS.duplicate())
	layout.add_spawn(Vector3(-52.6, 0, -3.0), passage, 1, MUMMY.duplicate(), true, PI)
	# the burial chambers: sarcophagi flank the way to the boarded door
	var tombs := &"egypt_tombs"
	layout.add_piece(&"plinth", Vector3(-57.5, 0, 9.0), Vector3(1.0, 0.9, 2.4), tombs, PI * 0.5)
	layout.add_piece(&"plinth", Vector3(-57.5, 0, 13.6), Vector3(1.0, 0.9, 2.4), tombs, PI * 0.5)
	layout.add_piece(&"plinth", Vector3(-53.5, 0, 3.5), Vector3(1.0, 0.9, 2.4), tombs)
	layout.add_loot(Vector3(-57.5, 0.9, 9.0), tombs, true)
	layout.add_loot(Vector3(-61.5, 0, 8.3), tombs)
	Kit.sconce(layout, Vector3(-60.0, 2.6, 7.7), PI, TORCH, 0.5, tombs)
	Kit.red(layout, Vector3(-62.8, 3.2, 12.0), -PI * 0.5, tombs)
	layout.add_spawn(Vector3(-57.5, 0, 11.3), tombs, 0, MUMMY.duplicate(), true, -PI * 0.5)
	layout.add_spawn(Vector3(-53.5, 0, 6.2), tombs, 0, MUMMY.duplicate())
	layout.add_patrol(&"egypt_tombs_walk", tombs, PackedVector3Array([Vector3(-52.0, 0, 11.3), Vector3(-61.0, 0, 11.3)]), false)
	var shuffler := layout.add_spawn(Vector3(-52.0, 0, 11.3), tombs, 1, MUMMY.duplicate(), false, PI * 0.5)
	shuffler.patrol = &"egypt_tombs_walk"
	layout.add_spawn(Vector3(-55.0, 0, 1.6), tombs, 1, SCARABS.duplicate())
	# the sarcophagus hall: two rows of lidded coffins; whatever lies by them
	# wakes when the guard reaches the middle of the hall
	var hall := &"egypt_tomb_hall"
	for x in [-57.5, -53.0]:
		for z in [19.5, 24.5]:
			layout.add_piece(&"plinth", Vector3(x, 0, z), Vector3(1.0, 0.9, 2.4), hall)
	layout.add_loot(Vector3(-53.0, 0.9, 19.5), hall, true)
	layout.add_loot(Vector3(-58.8, 0, 16.6), hall)
	Kit.sconce(layout, Vector3(-59.8, 2.8, 18.0), -PI * 0.5, TORCH, 0.5, hall)
	Kit.sconce(layout, Vector3(-50.7, 2.8, 22.0), PI * 0.5, TORCH, 0.5, hall)
	Kit.red(layout, Vector3(-50.7, 3.9, 29.0), PI * 0.5, hall)
	var woken: Array[int] = []
	for spot: Array in [[Vector3(-55.3, 0, 19.5), 0, MUMMY], [Vector3(-55.3, 0, 24.5), 0, MUMMY], [Vector3(-51.7, 0, 22.0), 1, MUMMY], [Vector3(-58.8, 0, 28.6), 1, SCARABS]]:
		var kinds: Array[StringName] = []
		kinds.assign(spot[2])
		layout.add_spawn(spot[0], hall, spot[1], kinds)
		woken.append(layout.spawn_slots.size() - 1)
	layout.add_ambush(AmbushSpec.on_area(&"egypt_sarcophagi", hall, Grey.r(-58, 20.5, -52, 23.5), -0.5, 3.0, woken))


static func _conservator(layout: LevelLayout) -> void:
	var room := &"egypt_conservator"
	layout.add_piece(&"desk", Vector3(-58.4, 0, 1.45), Vector3(1.6, 0.78, 0.8), room)
	layout.add_piece(&"chair", Vector3(-58.4, 0, 2.3), Vector3(0.6, 1.0, 0.6), room, PI, false)
	layout.add_piece(&"shelf", Vector3(-60.0, 0, 6.65), Vector3(2.4, 1.9, 0.5), room)
	layout.add_piece(&"crate", Vector3(-62.4, 0, 6.3), Vector3(0.8, 0.7, 0.8), room)
	layout.haven_spots[&"conservator"] = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-62.6, 0, 3.8))
	layout.add_marker(&"museum_map_conservator", Vector3(-60.5, 1.6, 0.52), room, PI)
	layout.add_marker(&"note_egypt_2", Vector3(-58.0, 0.78, 1.4), room)
	layout.add_loot(Vector3(-61.6, 0, 5.6), room)
	layout.add_light(LightSpec.HAVEN, Vector3(-58.9, 1.2, 1.3), HAVEN_LAMP, 1.4, 6.0, room, &"desk_lamp", true)
	layout.add_light(LightSpec.HAVEN, Vector3(-60.0, 3.1, 3.75), HAVEN_LAMP, 0.8, 7.0, room, &"bulb")


## The service stairs (staff): a tube lamp over each landing, a red lamp
## over the bolted basement door at the bottom.
static func _service(layout: LevelLayout) -> void:
	var room := &"egypt_service_stairs"
	layout.add_light(LightSpec.MAIN, Vector3(-32.25, 2.7, -9.0), TUBE, 1.0, 11.0, room, &"tube_lamp")
	layout.add_light(LightSpec.MAIN, Vector3(-32.25, 2.7, 9.25), TUBE, 0.7, 6.0, room, &"tube_lamp")
	# the store under the gallery: crates of casts, the bolted basement door
	var store := &"egypt_service_corridor"
	var low := Floor1Plan.BASEMENT_Y
	layout.add_light(LightSpec.MAIN, Vector3(-36.0, low + 2.7, -11.75), TUBE, 0.8, 7.0, store, &"tube_lamp")
	Kit.red(layout, Vector3(-31.3, low + 2.6, -11.5), PI * 0.5, store)
	layout.add_piece(&"crate", Vector3(-39.3, low, -12.3), Vector3(1.0, 0.9, 1.0), store)
	layout.add_piece(&"crate", Vector3(-38.0, low, -12.4), Vector3(1.2, 0.7, 0.8), store)
	layout.add_loot(Vector3(-36.5, low, -11.5), store)
	layout.add_spawn(Vector3(-35.0, low, -11.75), store, 0, SCARABS.duplicate(), true, -PI * 0.5)
	layout.add_spawn(Vector3(-37.0, low, -11.0), store, 1, MUMMY.duplicate(), true, -PI * 0.5)


# --- the three secrets -----------------------------------------------------------

static func _secrets(layout: LevelLayout) -> void:
	# 1. the expedition's store, chained shut off the service stairs' top
	#    landing: the first chain the guard meets after the shotgun
	Kit.gate(layout, &"egypt_chain_cache", GateSpec.Kind.CHAIN, GateSpec.HEAVY, &"GATE_CHAIN", &"egypt_stairs_cache", Grey.r(-33.25, 10.5, -31.25, 11), 0.0, 2.6, &"egypt_service_stairs", &"egypt_cache", OpeningSpec.DoorStyle.DOUBLE_SWING)
	var cache := &"egypt_cache"
	# crates of the expedition stacked at the far end, a lantern left lit
	layout.add_piece(&"crate", Vector3(-32.85, 0, 18.45), Vector3(1.2, 0.9, 1.0), cache)
	layout.add_piece(&"crate", Vector3(-31.6, 0, 18.45), Vector3(1.0, 1.1, 1.0), cache)
	layout.add_loot(Vector3(-32.85, 0.9, 18.45), cache, true)
	layout.add_loot(Vector3(-32.25, 0, 12.6), cache)
	layout.add_marker(&"note_egypt_4", Vector3(-31.6, 1.1, 18.45), cache, -PI * 0.5)
	layout.add_marker(&"secret_egypt_1", Vector3(-32.25, 0, 14.5), cache)
	Kit.glow(layout, Vector3(-32.3, 2.7, 15.0), OIL, 1.0, cache)
	Kit.lair(layout, &"egypt_cache", cache, Vector3(-32.25, 0, 16.6), SCARABS, Grey.r(-33.5, 13.5, -31, 19))
	# 2. the serdab: a cracked wall in the burial chambers, a slit in it and
	#    the ka statue's eyes glowing behind (a blast: flares, the fire chest)
	Kit.gate(layout, &"egypt_cracked_serdab", GateSpec.Kind.CRACKED, GateSpec.EXPLOSIVE, &"GATE_CRACKED", &"egypt_tombs_serdab", Grey.r(-62.5, 15, -61, 15.5), 0.0, 2.4, &"egypt_tombs", &"egypt_tomb_serdab", OpeningSpec.DoorStyle.PANEL)
	var serdab := &"egypt_tomb_serdab"
	layout.add_piece(&"sculpture", Vector3(-62.3, 0, 20.3), Vector3(0.8, 1.9, 0.8), serdab, 0.0)
	layout.add_piece(&"plinth", Vector3(-61.0, 0, 20.4), Vector3(0.7, 1.0, 0.7), serdab)
	layout.add_loot(Vector3(-61.0, 1.0, 20.4), serdab, true)
	layout.add_marker(&"secret_egypt_2", Vector3(-61.75, 0, 17.5), serdab)
	Kit.glow(layout, Vector3(-62.3, 2.7, 19.8), TORCH, 0.8, serdab)
	Kit.lair(layout, &"egypt_serdab", serdab, Vector3(-61.75, 0, 18.8), MUMMY, Grey.r(-63, 15.5, -60.5, 21))
	# 3. the priest's tomb behind a false-door stela with an iron ring (the
	#    harpoon pulls it out of the sarcophagus hall's west wall)
	Kit.gate(layout, &"egypt_hook_false_door", GateSpec.Kind.HOOK, &"harpoon", &"GATE_HOOK", &"egypt_hall_priest", Grey.r(-60.5, 24.5, -60, 26.5), 0.0, 2.4, &"egypt_tomb_hall", &"egypt_tomb_priest", OpeningSpec.DoorStyle.GATE)
	var priest := &"egypt_tomb_priest"
	layout.add_piece(&"plinth", Vector3(-62.2, 0, 28.0), Vector3(0.9, 0.9, 2.2), priest)
	layout.add_loot(Vector3(-62.2, 0.9, 28.0), priest, true)
	layout.add_marker(&"secret_egypt_3", Vector3(-61.75, 0, 25.5), priest)
	Kit.glow(layout, Vector3(-62.0, 2.7, 27.0), TORCH, 0.8, priest)
	Kit.lair(layout, &"egypt_priest", priest, Vector3(-61.6, 0, 23.0), MUMMY, Grey.r(-63, 24, -60.5, 30))

# --- the voice: the System's loudspeakers and the audio guide (plan 2026-10-19-glos-g2-kwestie) ---

## Stop 2 in the Great Gallery: before the first of Ramesses' statues on
## the east row, facing the visitor who comes in from the vestibule.
static func _voice(layout: LevelLayout) -> void:
	layout.add_marker(&"audioguide_ramesses", Vector3(-38.6, 0.0, 13.8), &"egypt_gallery", PI)
