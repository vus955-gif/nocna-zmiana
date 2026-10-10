extends RefCounted
## Floor I zone "basement" (y = -6; design 5.8, 4.4, 4.5; plan docs/
## superpowers/plans/2026-10-03-p1-w5b-podziemia-dach.md): the network of
## shortcuts that makes the museum click. Concrete, pipes, fluorescent tubes
## (some flicker), red emergency lamps; few exhibits ("runaways from the
## stores") in tight corridors.
## - the ring: four service corridors under the edge of the Great Court and
##   the north corridor; every wing's service stairs end at a door in it,
##   bolted on the wing side (Floor1Plan junctions j_basement_*), each with
##   a red lamp, a bulb, a plate and a pipe in its wing's colour;
## - the tunnel west under the Colossus hall to Assyria's freight bay;
## - the cross: the Reading Room's foundations in the middle (the crossing),
##   the cross corridors east and west (Egypt's door faces the west one),
##   the boiler room north and the restoration workshop south - the haven
##   and the hub every wing's door is a short walk from. Its two doors are
##   a shortcut for the guard; nothing lies only behind it (haven floors are
##   a navmesh region of their own);
## - the boiler room: two Cornish boilers, embers, steam, a gantry along the
##   north wall with the first fuse at the end of its east leg (taking it
##   wakes the room; the leg's end has no railing: a 2.8 m drop to get away);
## - the switchboard (both fuses -> power to the north corridor's shutters);
## - the stores between the arms: plinths and showcases (NW), the reserve
##   collection's shelves (SW), the archive's cabinets (SE);
## - under the entrance hall: the corridor from the booth's boarded staff
##   stairs (junction j_booth_basement) and the guards' store;
## - three secrets behind zone gates: the deposit cage (a chain), the
##   Montagu House cellar (a cracked wall: a blast), the 1940 air-raid
##   shelter (a steel door with an iron ring: the harpoon).
## No link to the crypt (the plan has none): its grille in the north wall
## only shows the dark beyond.

const ZONE := &"basement"
const Grey := preload("res://src/level/floor1/floor1_greybox.gd")
const Hub := preload("res://src/level/floor1/zones/hub_kit.gd")
const Kit := preload("res://src/level/floor1/zones/west_kit.gd")
const Svc := preload("res://src/level/floor1/zones/service_kit.gd")
const SWING := OpeningSpec.DoorStyle.SWING
const DOUBLE := OpeningSpec.DoorStyle.DOUBLE_SWING
const ALWAYS := SpawnSlot.ALWAYS_SET

const Y := Floor1Plan.BASEMENT_Y
## Ceilings: service corridors, stores and the workshop, the halls (the
## highest the zone allows under the ground floor's slab), the secrets.
const CORRIDOR := Y + 3.5
const ROOM := Y + 4.0
const HALL := Y + 5.0
const VAULT := Y + 3.0
## Tops of doorways: a door, a door under the gantry or a secret's lock.
const DOOR := Y + 2.6
const LOW_DOOR := Y + 2.4
## The boiler room's gantry deck (2.2 m over it, 2.4 m under its slab).
const GANTRY := Y + 2.8
## Height of the pipes under a corridor's ceiling (their middle).
const PIPES := Y + 3.15

## Runaways from the stores: the stand-in kind first (NightSpawner falls
## back for unknown kinds), the intended one after it.
const WAX: Array[StringName] = [&"wax"]
const WOLF: Array[StringName] = [&"wolf"]
const KNIGHT: Array[StringName] = [&"knight"]
const BUST: Array[StringName] = [&"bust"]
const MUMMY: Array[StringName] = [&"wax", &"mummy"]
const HOPLITE: Array[StringName] = [&"knight", &"hoplite"]
const SCARABS: Array[StringName] = [&"wolf", &"scarabs"]
const JAGUAR: Array[StringName] = [&"wolf", &"jaguar"]
const SAMURAI: Array[StringName] = [&"knight", &"samurai"]

## Each wing's bolted door: [junction, the room on this side, the wing].
const WING_DOORS := [
	[&"j_basement_egypt", &"basement_corridor_west", &"egypt"],
	[&"j_basement_assyria", &"basement_tunnel", &"assyria"],
	[&"j_basement_greece", &"basement_corridor_south", &"greece"],
	[&"j_basement_enlightenment", &"basement_corridor_south", &"enlightenment"],
	[&"j_basement_americas", &"basement_corridor_north", &"americas"],
	[&"j_basement_asia", &"basement_corridor_north", &"asia"],
]
## The cabinets of the switchboard room and the cross's piers.
const PIERS: Array[Vector2] = [Vector2(-5, -14.5), Vector2(5, -14.5), Vector2(-5, -4.5), Vector2(5, -4.5)]
const BOILERS: Array[float] = [-6.25, 6.25]
const SHELF_ROWS: Array[float] = [-4.0, 2.0, 8.0, 14.0, 20.0]
const CABINET_ROWS: Array[float] = [12.0, 16.5, 21.0]


static func build(layout: LevelLayout) -> void:
	_rooms(layout)
	_doors(layout)
	_ring(layout)
	_tunnel(layout)
	_boiler(layout)
	_crossing(layout)
	_axes(layout)
	_workshop(layout)
	_plinths(layout)
	_switchboard(layout)
	_reserve(layout)
	_archive(layout)
	_under_the_hall(layout)
	_secrets(layout)


# --- rooms and passages -------------------------------------------------------

static func _rooms(layout: LevelLayout) -> void:
	Grey.box(layout, &"basement_corridor_north", Grey.r(-30, -38, 30, -34.5), Y, CORRIDOR, ZONE, &"ROOM_BASEMENT_CORRIDOR_NORTH", false)
	Grey.box(layout, &"basement_corridor_west", Grey.r(-30, -34, -26.5, 26), Y, CORRIDOR, ZONE, &"ROOM_BASEMENT_CORRIDOR_WEST", false)
	Grey.box(layout, &"basement_corridor_east", Grey.r(26.5, -34, 30, 26), Y, CORRIDOR, ZONE, &"ROOM_BASEMENT_CORRIDOR_EAST", false)
	Grey.box(layout, &"basement_corridor_south", Grey.r(-30, 26.5, 30, 30), Y, CORRIDOR, ZONE, &"ROOM_BASEMENT_CORRIDOR_SOUTH", false)
	Grey.box(layout, &"basement_tunnel", Grey.r(-55, -37, -30.5, -33), Y, CORRIDOR, ZONE, &"ROOM_BASEMENT_TUNNEL", false)
	Grey.box(layout, &"basement_boiler", Grey.r(-14, -34, 14, -17), Y, HALL, ZONE, &"ROOM_BASEMENT_BOILER", false)
	var gantry := Grey.room(layout, &"basement_boiler_catwalk", [Grey.r(-14, -34, 14, -32), Grey.r(12, -32, 14, -25)] as Array[Rect2], GANTRY, HALL, ZONE, &"ROOM_BASEMENT_CATWALK", false)
	gantry.carved = false
	Grey.box(layout, &"basement_crossing", Grey.r(-7, -16.5, 7, -2.5), Y, HALL, ZONE, &"ROOM_BASEMENT_CROSSING", false)
	Grey.box(layout, &"basement_corridor_spine_w", Grey.r(-26, -12.5, -7.5, -9.5), Y, CORRIDOR, ZONE, &"ROOM_BASEMENT_SPINE", false)
	Grey.box(layout, &"basement_corridor_spine_e", Grey.r(7.5, -12.5, 26, -9.5), Y, CORRIDOR, ZONE, &"ROOM_BASEMENT_SPINE", false)
	var workshop := Grey.box(layout, &"basement_workshop", Grey.r(-7, -2, 7, 9), Y, ROOM, ZONE, &"ROOM_BASEMENT_WORKSHOP", false)
	workshop.haven = true
	Grey.box(layout, &"basement_corridor_workshop", Grey.r(-2, 9.5, 2, 26), Y, CORRIDOR, ZONE, &"ROOM_BASEMENT_WORKSHOP_CORRIDOR", false)
	Grey.box(layout, &"basement_store_plinths", Grey.r(-26, -27.5, -14.5, -13), Y, ROOM, ZONE, &"ROOM_BASEMENT_PLINTHS", false)
	Grey.box(layout, &"basement_switchboard", Grey.r(14.5, -34, 26, -13), Y, ROOM, ZONE, &"ROOM_BASEMENT_SWITCHBOARD", false)
	Grey.box(layout, &"basement_reserve", Grey.r(-26, -9, -7.5, 26), Y, ROOM, ZONE, &"ROOM_BASEMENT_RESERVE", false)
	Grey.room(layout, &"basement_archive", [Grey.r(7.5, -9, 26, 17.5), Grey.r(7.5, 17.5, 19.5, 26)] as Array[Rect2], Y, ROOM, ZONE, &"ROOM_BASEMENT_ARCHIVE", false)
	Grey.room(layout, &"basement_corridor_staff", [Grey.r(-12, 36, 16, 40), Grey.r(-2, 30.5, 2, 36)] as Array[Rect2], Y, CORRIDOR, ZONE, &"ROOM_BASEMENT_STAFF", false)
	Grey.box(layout, &"basement_store_guards", Grey.r(4, 40.5, 16, 52), Y, CORRIDOR, ZONE, &"ROOM_BASEMENT_GUARDS", false)
	for spec: Array in [[&"basement_old_cellar", Grey.r(-26, -34, -14.5, -28), &"ROOM_BASEMENT_OLD_CELLAR"], [&"basement_cage", Grey.r(20, 18, 26, 26), &"ROOM_BASEMENT_CAGE"], [&"basement_shelter", Grey.r(-16, 40.5, -4, 52), &"ROOM_BASEMENT_SHELTER"]]:
		var hidden := Grey.box(layout, spec[0], spec[1], Y, VAULT, ZONE, spec[2], false)
		hidden.secret = true


static func _doors(layout: LevelLayout) -> void:
	var north := &"basement_corridor_north"
	var west := &"basement_corridor_west"
	var east := &"basement_corridor_east"
	var south := &"basement_corridor_south"
	var spine_w := &"basement_corridor_spine_w"
	var spine_e := &"basement_corridor_spine_e"
	var crossing := &"basement_crossing"
	var workshop := &"basement_workshop"
	var axis := &"basement_corridor_workshop"
	var boiler := &"basement_boiler"
	var plinths := &"basement_store_plinths"
	var board := &"basement_switchboard"
	var reserve := &"basement_reserve"
	var archive := &"basement_archive"
	var staff := &"basement_corridor_staff"
	# the ring's corners and its mouths: arches as wide and high as the corridor
	Grey.door(layout, &"basement_north_west", Grey.r(-30, -34.5, -26.5, -34), Y, CORRIDOR, north, west)
	Grey.door(layout, &"basement_north_east", Grey.r(26.5, -34.5, 30, -34), Y, CORRIDOR, north, east)
	Grey.door(layout, &"basement_west_south", Grey.r(-30, 26, -26.5, 26.5), Y, CORRIDOR, west, south)
	Grey.door(layout, &"basement_east_south", Grey.r(26.5, 26, 30, 26.5), Y, CORRIDOR, east, south)
	Grey.door(layout, &"basement_north_tunnel", Grey.r(-30.5, -37, -30, -34.5), Y, CORRIDOR, north, &"basement_tunnel")
	Grey.door(layout, &"basement_west_spine", Grey.r(-26.5, -12.5, -26, -9.5), Y, CORRIDOR, west, spine_w)
	Grey.door(layout, &"basement_spine_w_crossing", Grey.r(-7.5, -12.5, -7, -9.5), Y, CORRIDOR, spine_w, crossing)
	Grey.door(layout, &"basement_crossing_spine_e", Grey.r(7, -12.5, 7.5, -9.5), Y, CORRIDOR, crossing, spine_e)
	Grey.door(layout, &"basement_spine_e_east", Grey.r(26, -12.5, 26.5, -9.5), Y, CORRIDOR, spine_e, east)
	Grey.door(layout, &"basement_passage_south", Grey.r(-2, 26, 2, 26.5), Y, CORRIDOR, axis, south)
	Grey.door(layout, &"basement_south_staff", Grey.r(-2, 30, 2, 30.5), Y, CORRIDOR, south, staff)
	# the boiler room: double doors from the north corridor (under the
	# gantry: 2.4 m), a wide arch to the crossing, the stores either side
	Grey.door(layout, &"basement_north_boiler", Grey.r(-2, -34.5, 2, -34), Y, LOW_DOOR, north, boiler, DOUBLE)
	Grey.door(layout, &"basement_boiler_crossing", Grey.r(-3, -17, 3, -16.5), Y, Y + 4.0, boiler, crossing)
	Grey.door(layout, &"basement_boiler_plinths", Grey.r(-14.5, -22, -14, -20), Y, DOOR, boiler, plinths)
	Grey.door(layout, &"basement_boiler_switchboard", Grey.r(14, -22, 14.5, -20), Y, DOOR, boiler, board, SWING)
	# the workshop: a door north to the crossing and one south to its
	# corridor (their leaves swing into the workshop, along the jambs)
	Grey.door(layout, &"basement_crossing_workshop", Grey.r(-1, -2.5, 1, -2), Y, DOOR, crossing, workshop, SWING)
	Grey.door(layout, &"basement_passage_workshop", Grey.r(-1, 9, 1, 9.5), Y, DOOR, axis, workshop, SWING)
	# the stores' doors (leaves into the stores)
	Grey.door(layout, &"basement_west_plinths", Grey.r(-26.5, -22, -26, -20), Y, DOOR, west, plinths, SWING)
	Grey.door(layout, &"basement_spine_plinths", Grey.r(-22, -13, -20, -12.5), Y, DOOR, spine_w, plinths, SWING)
	Grey.door(layout, &"basement_spine_switchboard", Grey.r(19, -13, 21, -12.5), Y, DOOR, spine_e, board, SWING)
	Grey.door(layout, &"basement_spine_reserve", Grey.r(-21, -9.5, -19, -9), Y, DOOR, spine_w, reserve, SWING)
	Grey.door(layout, &"basement_west_reserve", Grey.r(-26.5, 4, -26, 6), Y, DOOR, west, reserve, SWING)
	Grey.door(layout, &"basement_south_reserve", Grey.r(-21, 26, -19, 26.5), Y, DOOR, south, reserve, SWING)
	Grey.door(layout, &"basement_spine_archive", Grey.r(19, -9.5, 21, -9), Y, DOOR, spine_e, archive, SWING)
	Grey.door(layout, &"basement_east_archive", Grey.r(26, 2, 26.5, 4), Y, DOOR, east, archive, SWING)
	Grey.door(layout, &"basement_south_archive", Grey.r(12, 26, 14, 26.5), Y, DOOR, south, archive, SWING)
	Grey.door(layout, &"basement_staff_guards", Grey.r(9, 40, 11, 40.5), Y, DOOR, staff, &"basement_store_guards", SWING)


# --- the ring ------------------------------------------------------------------

static func _ring(layout: LevelLayout) -> void:
	for row: Array in WING_DOORS:
		_wing_door(layout, row[0], row[1], row[2])
	var north := &"basement_corridor_north"
	var west := &"basement_corridor_west"
	var east := &"basement_corridor_east"
	var south := &"basement_corridor_south"
	# each wing's pipe from its door to the cross (the workshop's corridor
	# for the south wings), under the corridors' ceilings
	_pipe(layout, &"egypt", [Vector3(-29.6, PIPES, -9.9), Vector3(-7.6, PIPES, -9.9)], &"basement_corridor_spine_w")
	_pipe(layout, &"assyria", [Vector3(-54.6, PIPES, -35.2), Vector3(-30.6, PIPES, -35.2)], &"basement_tunnel")
	_pipe(layout, &"assyria", [Vector3(-30.4, PIPES, -35.2), Vector3(-2.6, PIPES, -35.2)], north)
	_pipe(layout, &"americas", [Vector3(-27.0, PIPES, -37.6), Vector3(-2.6, PIPES, -37.6)], north)
	_pipe(layout, &"asia", [Vector3(25.0, PIPES, -37.6), Vector3(2.6, PIPES, -37.6)], north)
	_pipe(layout, &"greece", [Vector3(-27.0, PIPES, 29.6), Vector3(-1.4, PIPES, 29.6)], south)
	_pipe(layout, &"greece", [Vector3(-1.4, PIPES, 26.4), Vector3(-1.4, PIPES, 9.9)], &"basement_corridor_workshop")
	_pipe(layout, &"enlightenment", [Vector3(29.6, PIPES, 26.9), Vector3(1.4, PIPES, 26.9)], south)
	_pipe(layout, &"enlightenment", [Vector3(1.4, PIPES, 26.4), Vector3(1.4, PIPES, 9.9)], &"basement_corridor_workshop")
	# tubes down the middle of each corridor, a few flickering
	var top := CORRIDOR - 0.2
	for x in [-25.0, -15.0, -5.0, 5.0, 15.0, 25.0]:
		Svc.tube(layout, Vector3(x, top, -36.25), north, 4.5, 1.2, true, x == -15.0 or x == 25.0)
		Svc.tube(layout, Vector3(x, top, 28.25), south, 4.5, 1.2, true, x == 5.0)
	for z in [-29.0, -19.0, -6.0, 6.0, 16.0]:
		Svc.tube(layout, Vector3(-28.25, top, z), west, 4.5, 1.2, false, z == 6.0)
		Svc.tube(layout, Vector3(28.25, top, z), east, 4.5, 1.2, false, z == -19.0)
	# the crypt's grille in the north wall: bricked up long ago, the dark
	# of the crypt's stairs behind its bars (no way through)
	var leaf := layout.add_piece(&"door_leaf", Vector3(0, Y, -37.93), Vector3(2.4, 2.6, 0.1), north, PI)
	leaf.tint = Hub.BRONZE
	layout.add_piece(&"grate", Vector3(0, Y + 1.3, -37.86), Vector3(1.0, 0.8, 0.06), north, PI, false)
	layout.add_marker(&"basement_crypt_grille", Vector3(0, Y + 1.5, -37.85), north, PI)
	Svc.red(layout, Vector3(0, Y + 3.0, -37.85), PI, north)
	# crates and vents along the walls (never across a corridor)
	for spot: Array in [[Vector3(-12.5, Y, -37.45), north], [Vector3(-29.45, Y, 12.0), west], [Vector3(29.45, Y, -27.0), east], [Vector3(-14.0, Y, 29.45), south]]:
		var room: StringName = spot[1]
		layout.add_piece(&"crate", spot[0], Vector3(0.9, 0.9, 0.9), room)
		layout.add_loot(spot[0] + Vector3.UP * 0.9, room, true)
	for spot in [Vector3(-8.0, Y, -36.0), Vector3(19.0, Y, 28.25)]:
		layout.add_loot(spot, layout.room_at(spot + Vector3.UP))
	layout.add_loot(Vector3(-28.25, Y, 20.0), west)
	layout.add_loot(Vector3(28.25, Y, -2.0), east)
	# runaways on the ring: one a night in each corridor
	Hub.walker(layout, &"basement_north_walk", north, 0, WAX.duplicate(), PackedVector3Array([Vector3(-22, Y, -36.25), Vector3(22, Y, -36.25)]), false)
	Hub.slots(layout, north, 1, SCARABS.duplicate(), [Vector2(16, -36.25)], Y, Vector2(0, -36.25))
	Hub.slots(layout, north, 2, HOPLITE.duplicate(), [Vector2(-18, -36.25)], Y, Vector2(0, -36.25))
	Hub.slots(layout, west, 0, MUMMY.duplicate(), [Vector2(-28.25, -16)], Y, Vector2(-28.25, 0))
	Hub.walker(layout, &"basement_west_walk", west, 1, HOPLITE.duplicate(), PackedVector3Array([Vector3(-28.25, Y, -29), Vector3(-28.25, Y, 22)]), false)
	Hub.walker(layout, &"basement_east_walk", east, 0, WAX.duplicate(), PackedVector3Array([Vector3(28.25, Y, 22), Vector3(28.25, Y, -29)]), false)
	Hub.slots(layout, east, 1, JAGUAR.duplicate(), [Vector2(28.25, -22)], Y, Vector2(28.25, 0))
	Hub.slots(layout, south, 0, BUST.duplicate(), [Vector2(-10, 28.25)], Y, Vector2(0, 28.25))
	Hub.walker(layout, &"basement_south_walk", south, 1, SAMURAI.duplicate(), PackedVector3Array([Vector3(-24, Y, 28.25), Vector3(24, Y, 28.25)]), false)


## The basement side of a wing's bolted door: a red lamp over one jamb, a
## bulb in the wing's colour over the other and the wing's plate over the
## door, all facing into [param room].
static func _wing_door(layout: LevelLayout, junction_id: StringName, room: StringName, wing: StringName) -> void:
	var j := Floor1Plan.junction(junction_id)
	var face := j.point_in(ZONE, 0.0, 0.0)
	var inward := (face - j.center()).normalized()
	var across := Vector3(inward.z, 0, -inward.x)
	var yaw := atan2(-inward.x, -inward.z)
	# either jamb; a door in a corner gets both lamps over its open side
	var side := j.width() * 0.5 + 0.45
	var spec := layout.room(room)
	var red_at := face + across * side
	var bulb_at := face - across * side
	if not spec.covers(Vector2(red_at.x, red_at.z)):
		red_at = face - across * (side + 0.7)
	elif not spec.covers(Vector2(bulb_at.x, bulb_at.z)):
		bulb_at = face + across * (side + 0.7)
	Svc.red(layout, red_at + inward * 0.12 + Vector3.UP * 2.95, yaw, room)
	var bulb := layout.add_light(LightSpec.MAIN, bulb_at + inward * 0.15 + Vector3.UP * 2.95, Floor1Plan.zone_color(wing), 1.0, 2.5, room, &"bulb")
	bulb.fixture_yaw = yaw
	Hub.wing_sign(layout, StringName("sign_basement_%s_1" % wing), face + inward * 0.05 + Vector3.UP * 2.68, 2.0, yaw, room, wing)


## A pipe in [param wing]'s colour along [param points] (one straight run
## per pair).
static func _pipe(layout: LevelLayout, wing: StringName, points: Array, room: StringName) -> void:
	for i in range(1, points.size()):
		var from: Vector3 = points[i - 1]
		var to: Vector3 = points[i]
		Svc.pipe(layout, from, to, room, Floor1Plan.zone_color(wing))


# --- the tunnel and the freight bay ----------------------------------------------

static func _tunnel(layout: LevelLayout) -> void:
	var room := &"basement_tunnel"
	# brick arches every 6 m (pilasters on both walls)
	for x in [-46.0, -40.0, -34.0]:
		for z in [-36.75, -33.25]:
			layout.add_piece(&"pilaster", Vector3(x, Y, z), Vector3(0.6, 3.5, 0.5), room)
	# the freight bay at the west end: crates off the lift, its call box by
	# the bolted door (the lift itself is Assyria's, later)
	layout.add_piece(&"crate", Vector3(-52.0, Y, -36.4), Vector3(1.6, 1.8, 1.0), room)
	layout.add_piece(&"crate", Vector3(-50.2, Y, -36.45), Vector3(1.2, 1.1, 0.9), room)
	layout.add_loot(Vector3(-50.2, Y + 1.1, -36.45), room, true)
	layout.add_loot(Vector3(-43.0, Y, -35.0), room)
	layout.add_marker(&"basement_freight_lift", Vector3(-54.9, Y + 1.3, -33.6), room, -PI * 0.5)
	for x in [-52.0, -43.0, -34.5]:
		Svc.tube(layout, Vector3(x, CORRIDOR - 0.2, -35.0), room, 4.5, 1.1, true, x == -43.0)
	# a mummy that crept out with the crates wakes in the bay every night
	Kit.lair(layout, &"basement_freight", room, Vector3(-51.5, Y, -34.6), MUMMY.duplicate(), Grey.r(-55, -37, -48, -33), PI * 0.5)


# --- the boiler room ------------------------------------------------------------------

static func _boiler(layout: LevelLayout) -> void:
	var room := &"basement_boiler"
	var deck := &"basement_boiler_catwalk"
	# two Cornish boilers, fire doors to the south, flues to the ceiling
	for x in BOILERS:
		layout.add_piece(&"boiler", Vector3(x, Y, -27), Vector3(7.5, 3.0, 4.0), room)
		layout.add_piece(&"flue", Vector3(x + 1.75 * signf(x), Y + 3.0, -28), Vector3(0.9, 2.0, 0.9), room, 0.0, false)
		var door := layout.add_piece(&"furnace_door", Vector3(x, Y + 0.4, -24.95), Vector3(1.2, 0.9, 0.1), room, 0.0, false)
		door.tint = Svc.EMBER
		layout.add_light(LightSpec.EMERGENCY, Vector3(x, Y + 0.9, -24.3), Svc.EMBER, 1.6, 4.0, room)
	Svc.pipe(layout, Vector3(-13.5, HALL - 0.45, -23.8), Vector3(13.5, HALL - 0.45, -23.8), room, Color(0.4, 0.42, 0.38), 0.4)
	layout.add_piece(&"coal", Vector3(11.75, Y, -30.25), Vector3(2.5, 1.0, 1.5), room)
	# the stoker's table and shelf by the south wall
	layout.add_piece(&"desk", Vector3(-11.5, Y, -18.2), Vector3(1.8, 0.85, 0.9), room)
	layout.add_piece(&"shelf", Vector3(-7.5, Y, -17.3), Vector3(2.4, 2.0, 0.5), room, PI)
	layout.add_marker(&"note_basement_2", Vector3(-11.2, Y + 0.85, -18.2), room)
	layout.add_loot(Vector3(-11.9, Y + 0.85, -18.2), room, true)
	layout.add_loot(Vector3(0, Y, -30.5), room)
	# the gantry: a deck along the north wall and a leg south over the east
	# boiler, on posts; stairs up the west wall; no railing at the leg's end
	Svc.slab(layout, Grey.r(-14, -34, 14, -32), GANTRY, room)
	Svc.slab(layout, Grey.r(12, -32, 14, -25), GANTRY, room)
	for post in [Vector2(-9, -32.25), Vector2(-4.5, -32.25), Vector2(4.5, -32.25), Vector2(9, -32.25), Vector2(12.25, -28.5), Vector2(12.25, -25.3)]:
		layout.add_piece(&"balcony_post", Vector3(post.x, Y, post.y), Vector3(0.4, GANTRY - Svc.SLAB - Y, 0.4), room)
	Svc.rail(layout, Vector3(-12, GANTRY, -32.075), Vector3(12, GANTRY, -32.075), deck)
	Svc.rail(layout, Vector3(12.075, GANTRY, -32), Vector3(12.075, GANTRY, -25), deck)
	var stairs := layout.add_stairs(&"basement_boiler_stairs", Grey.r(-14, -32, -12, -24.5), Y, GANTRY, Vector2(0, -1), room, deck)
	stairs.step_rise = Floor1Plan.STAIR_RISE
	# the first fuse at the end of the leg, by a hissing valve
	layout.add_piece(&"fuse_crate", Vector3(13.3, GANTRY, -25.75), Vector3(0.6, 0.5, 0.45), deck, 0.0, false)
	layout.add_marker(&"fuse_basement", Vector3(13.0, GANTRY + 0.8, -25.8), deck)
	layout.add_loot(Vector3(13.0, GANTRY, -31.0), deck)
	layout.add_marker(&"steam_basement_1", Vector3(0, Y + 2.5, -30.5), room)
	layout.add_marker(&"steam_basement_2", Vector3(13.6, GANTRY + 1.2, -24.6), room)
	layout.add_marker(&"steam_basement_3", Vector3(2.8, Y + 2.2, -33.4), room)
	# light: embers, tubes over the aisle, a caged bulb on the gantry
	Svc.tube(layout, Vector3(0, HALL - 0.3, -20.5), room, 5.0, 1.4)
	Svc.tube(layout, Vector3(-9, HALL - 0.3, -20.5), room, 5.0, 1.2, true, true)
	Svc.tube(layout, Vector3(9, HALL - 0.3, -20.5), room, 5.0, 1.2)
	# (the gantry's bulbs cast the rails' shadows: the hall's two shadows)
	Svc.down(layout, LightSpec.MAIN, Vector3(0, HALL - 0.4, -33.0), Svc.WARM, 1.0, 2.6, deck, &"bulb").shadow = true
	Svc.down(layout, LightSpec.MAIN, Vector3(13.0, HALL - 0.4, -27.5), Svc.WARM, 0.9, 2.6, deck, &"bulb").shadow = true
	Svc.red(layout, Vector3(3.0, Y + 2.0, -33.85), PI, room)
	# taking the fuse wakes what sleeps by the fire doors and behind the boilers
	var woken: Array[int] = []
	layout.add_spawn(Vector3(5.5, Y, -23.2), room, ALWAYS, KNIGHT.duplicate(), true, 0.0)
	woken.append(layout.spawn_slots.size() - 1)
	layout.add_spawn(Vector3(-6.0, Y, -30.5), room, ALWAYS, SCARABS.duplicate(), true, PI)
	woken.append(layout.spawn_slots.size() - 1)
	layout.add_ambush(AmbushSpec.on_pickup(&"basement_fuse", room, &"fuse_basement", woken))
	Hub.walker(layout, &"basement_boiler_round", room, 0, WAX.duplicate(), PackedVector3Array([Vector3(-11, Y, -20.5), Vector3(11, Y, -20.5)]), false)
	Hub.slots(layout, room, 1, HOPLITE.duplicate(), [Vector2(-4.5, -22.5)], Y, Vector2(0, -17))
	Hub.slots(layout, room, 2, BUST.duplicate(), [Vector2(4.5, -19.5)], Y, Vector2(0, -27))


# --- the crossing (the Reading Room's foundations) ------------------------------------

static func _crossing(layout: LevelLayout) -> void:
	var room := &"basement_crossing"
	for pier in PIERS:
		layout.add_piece(&"pier", Vector3(pier.x, Y, pier.y), Vector3(1.6, 5.0, 1.6), room)
	# which way: plates in the wings' colours over the cross's mouths
	var west_yaw := -PI * 0.5
	for row: Array in [[&"egypt", -12.0], [&"assyria", -11.0], [&"greece", -10.0]]:
		Hub.wing_sign(layout, StringName("sign_basement_%s_2" % row[0]), Vector3(-6.95, Y + 3.6, row[1]), 0.9, west_yaw, room, row[0])
	Hub.wing_sign(layout, &"sign_basement_enlightenment_2", Vector3(6.95, Y + 3.6, -11.0), 1.6, PI * 0.5, room, &"enlightenment")
	Hub.wing_sign(layout, &"sign_basement_americas_2", Vector3(-1.0, Y + 4.1, -16.45), 1.6, PI, room, &"americas")
	Hub.wing_sign(layout, &"sign_basement_asia_2", Vector3(1.0, Y + 4.1, -16.45), 1.6, PI, room, &"asia")
	Hub.wing_sign(layout, &"sign_basement_booth_2", Vector3(0, Y + 2.7, -2.55), 1.8, 0.0, room, &"booth")
	Hub.look_marker(layout, &"cctv_basement_1", Vector3(6.4, Y + 4.4, -15.9), Vector3(0, Y + 1.0, -2.5), room)
	# (its shadow: the piers' stripes on the floor)
	Svc.down(layout, LightSpec.MAIN, Vector3(0, HALL - 0.4, -9.5), Svc.TUBE, 2.0, 5.0, room, &"ceiling_lamp").shadow = true
	Svc.tube(layout, Vector3(0, HALL - 0.3, -14.5), room, 5.0, 1.0, true, true)
	Svc.tube(layout, Vector3(0, HALL - 0.3, -4.5), room, 5.0, 1.0)
	layout.add_loot(Vector3(-6.2, Y, -7.5), room)
	Hub.slots(layout, room, 0, BUST.duplicate(), [Vector2(-3.5, -15.0)], Y, Vector2(0, -9.5))
	Hub.slots(layout, room, 1, KNIGHT.duplicate(), [Vector2(3.5, -4.0)], Y, Vector2(0, -9.5))


## The cross corridors east and west of the crossing and the workshop's
## corridor south to the ring: tubes, a bench, nobody on watch.
static func _axes(layout: LevelLayout) -> void:
	var top := CORRIDOR - 0.2
	for x in [-20.0, -12.0]:
		Svc.tube(layout, Vector3(x, top, -11.0), &"basement_corridor_spine_w", 4.5, 1.1, true, x == -12.0)
		Svc.tube(layout, Vector3(-x, top, -11.0), &"basement_corridor_spine_e", 4.5, 1.1, true, x == -20.0)
	var axis := &"basement_corridor_workshop"
	for z in [13.0, 19.0, 24.5]:
		Svc.tube(layout, Vector3(0, top, z), axis, 4.5, 1.0, false, z == 19.0)
	layout.add_piece(&"bench", Vector3(-1.6, Y, 16.0), Vector3(2.0, 0.45, 0.6), axis, -PI * 0.5)
	layout.add_loot(Vector3(0.9, Y, 21.0), axis)


# --- the restoration workshop (haven) ----------------------------------------------

## Four benches with half-glued exhibits either side of the walk from door
## to door, the upgrade terminal on the west wall, the museum map on the
## east wall, the restorer's list of jobs; its own warm light.
static func _workshop(layout: LevelLayout) -> void:
	var room := &"basement_workshop"
	for bench in [Vector2(-3.75, 1.5), Vector2(3.75, 1.5), Vector2(-3.75, 6.0), Vector2(3.75, 6.0)]:
		layout.add_piece(&"desk", Vector3(bench.x, Y, bench.y), Vector3(3.0, 0.9, 1.4), room)
	# what lies on them: a torso, a wax head, an urn in shards, a mended shield
	layout.add_piece(&"sculpture", Vector3(-4.3, Y + 0.9, 1.5), Vector3(0.8, 1.3, 0.6), room, PI * 0.5, false)
	layout.add_piece(&"wax_head", Vector3(3.0, Y + 0.9, 1.4), Vector3(0.35, 0.4, 0.35), room, 0.0, false)
	layout.add_piece(&"urn_shards", Vector3(-3.4, Y + 0.9, 6.1), Vector3(1.2, 0.3, 0.8), room, 0.0, false)
	layout.add_piece(&"shield", Vector3(4.2, Y + 0.9, 6.0), Vector3(1.0, 0.1, 1.0), room, 0.0, false)
	layout.add_piece(&"armor_rack", Vector3(6.3, Y, 7.8), Vector3(1.0, 2.2, 0.8), room, -PI * 0.5)
	for x in [-5.0, 5.0]:
		layout.add_piece(&"shelf", Vector3(x, Y, 8.7), Vector3(2.4, 2.0, 0.5), room, PI)
	layout.haven_spots[&"workshop"] = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-6.6, Y, 3.75))
	layout.add_marker(&"museum_map_workshop", Vector3(6.95, Y + 1.6, 3.75), room, PI * 0.5)
	layout.add_marker(&"note_basement_1", Vector3(3.75, Y + 0.9, 1.9), room)
	layout.add_loot(Vector3(-3.75, Y + 0.9, 5.7), room, true)
	var haven := LightSpec.HAVEN
	Hub.lamp(layout, haven, Vector3(-3.0, Y + 1.35, 1.2), Svc.WARM, 1.4, 4.0, room, &"desk_lamp", 0.0, true)
	Hub.lamp(layout, haven, Vector3(3.0, Y + 1.35, 6.3), Svc.WARM, 1.1, 4.0, room, &"desk_lamp", 0.0, true)
	var tube := Svc.down(layout, haven, Vector3(0, ROOM - 0.2, 3.75), Svc.TUBE, 1.0, 4.5, room, &"tube_lamp")
	tube.fixture_yaw = PI * 0.5


# --- the stores ---------------------------------------------------------------------

## Plinths and empty showcases between exhibitions; the cracked wall of
## the old cellar in its north wall.
static func _plinths(layout: LevelLayout) -> void:
	var room := &"basement_store_plinths"
	for at in [Vector2(-24.25, -25.5), Vector2(-16.25, -25.5), Vector2(-24.25, -15.5), Vector2(-16.25, -15.5)]:
		layout.add_piece(&"case", Vector3(at.x, Y, at.y), Vector3(1.6, 2.0, 1.0), room)
	for at in [Vector2(-24.5, -18.0), Vector2(-16.0, -18.0)]:
		layout.add_piece(&"pedestal", Vector3(at.x, Y, at.y), Vector3(1.2, 1.0, 1.2), room)
	layout.add_loot(Vector3(-24.25, Y + 1.0, -25.5), room, true)
	layout.add_loot(Vector3(-25.2, Y, -14.0), room)
	Svc.tube(layout, Vector3(-20.25, ROOM - 0.2, -24.0), room, 5.0, 1.0)
	Svc.tube(layout, Vector3(-20.25, ROOM - 0.2, -16.5), room, 5.0, 1.0, true, true)
	Hub.slots(layout, room, 0, WAX.duplicate(), [Vector2(-20.5, -16.5)], Y, Vector2(-21, -13))
	Hub.slots(layout, room, 1, HOPLITE.duplicate(), [Vector2(-20.0, -24.0)], Y, Vector2(-21, -21))


## The switchboard room: the board on the north wall between the fuse
## cabinets, two transformers, cable trays, the electrician's desk. An old
## suit of armour stored in the corner wakes when the guard steps up to the
## board.
static func _switchboard(layout: LevelLayout) -> void:
	var room := &"basement_switchboard"
	layout.add_marker(&"switchboard", Vector3(20.25, Y + 1.2, -33.7), room, PI)
	for x in [16.5, 17.8, 22.7, 24.0]:
		layout.add_piece(&"fuse_box", Vector3(x, Y, -33.8), Vector3(1.0, 1.8, 0.4), room, PI)
	for x in [17.5, 23.5]:
		layout.add_piece(&"transformer", Vector3(x, Y, -17.0), Vector3(2.4, 2.6, 2.0), room)
	for x in [16.0, 20.25, 24.5]:
		Svc.pipe(layout, Vector3(x, ROOM - 0.3, -33.5), Vector3(x, ROOM - 0.3, -15.5), room, Color(0.3, 0.3, 0.32), 0.2)
	layout.add_piece(&"desk", Vector3(25.2, Y, -27.0), Vector3(1.6, 0.8, 0.8), room, PI * 0.5)
	layout.add_piece(&"chair", Vector3(24.4, Y, -27.0), Vector3(0.6, 1.0, 0.6), room, -PI * 0.5, false)
	layout.add_marker(&"note_basement_3", Vector3(25.2, Y + 0.8, -26.6), room)
	layout.add_loot(Vector3(25.2, Y + 0.8, -27.5), room, true)
	layout.add_loot(Vector3(19.5, Y, -24.0), room)
	layout.add_loot(Vector3(25.3, Y, -14.0), room)
	Svc.tube(layout, Vector3(20.25, ROOM - 0.2, -30.0), room, 5.0, 1.3)
	Svc.tube(layout, Vector3(20.25, ROOM - 0.2, -21.0), room, 5.0, 1.0)
	Svc.red(layout, Vector3(14.65, Y + 3.0, -19.2), -PI * 0.5, room)
	Kit.lair(layout, &"basement_switchboard", room, Vector3(15.6, Y, -30.5), KNIGHT.duplicate(), Grey.r(17.5, -33.5, 23, -29.5), -PI * 0.5)


## The reserve collection: five rows of shelves west to east with 5 m
## aisles, a walk round them on the west and the east.
static func _reserve(layout: LevelLayout) -> void:
	var room := &"basement_reserve"
	for z in SHELF_ROWS:
		layout.add_piece(&"shelf", Vector3(-16.75, Y, z), Vector3(12.5, 3.2, 1.0), room)
	layout.add_piece(&"crate", Vector3(-25.4, Y, 11.0), Vector3(0.8, 0.8, 0.8), room)
	layout.add_loot(Vector3(-20.0, Y + 1.6, -4.0), room, true)
	layout.add_loot(Vector3(-13.0, Y + 1.6, 14.0), room, true)
	layout.add_loot(Vector3(-24.5, Y, 23.5), room)
	layout.add_loot(Vector3(-11.0, Y, 23.5), room)
	layout.add_loot(Vector3(-9.0, Y, -2.0), room)
	var top := ROOM - 0.2
	for z in [-1.0, 11.0, 23.0]:
		Svc.tube(layout, Vector3(-16.75, top, z), room, 5.0, 1.0, true, z == 11.0)
	Svc.tube(layout, Vector3(-9.0, top, 5.0), room, 5.0, 1.0, false)
	Svc.tube(layout, Vector3(-24.5, top, 17.0), room, 5.0, 0.9, false, true)
	Hub.walker(layout, &"basement_reserve_aisle", room, 0, WAX.duplicate(), PackedVector3Array([Vector3(-9, Y, -6.5), Vector3(-9, Y, 23.5)]), false)
	Hub.slots(layout, room, 0, MUMMY.duplicate(), [Vector2(-16, -1.0)], Y, Vector2(-16, 5))
	Hub.slots(layout, room, 0, BUST.duplicate(), [Vector2(-19, 11.0)], Y, Vector2(-9, 11))
	Hub.slots(layout, room, 1, SCARABS.duplicate(), [Vector2(-24.5, 16.5)], Y, Vector2(-16, 17))
	Hub.slots(layout, room, 1, HOPLITE.duplicate(), [Vector2(-13.0, 5.0)], Y, Vector2(-24, 5))
	Hub.slots(layout, room, 1, WAX.duplicate(), [Vector2(-16.0, 17.0)], Y, Vector2(-9, 17))
	Hub.slots(layout, room, 1, KNIGHT.duplicate(), [Vector2(-16.0, -6.5)], Y, Vector2(-20, -9))
	Hub.slots(layout, room, 2, JAGUAR.duplicate(), [Vector2(-9.0, 11.0)], Y, Vector2(-16, 11))
	Hub.slots(layout, room, 2, MUMMY.duplicate(), [Vector2(-22.0, 23.0)], Y, Vector2(-20, 26))
	Hub.slots(layout, room, 2, BUST.duplicate(), [Vector2(-12.0, -1.0)], Y, Vector2(-16, -1))


## The archive: three rows of filing cabinets north to south, the deposit
## cage (a secret) in its south-east corner.
static func _archive(layout: LevelLayout) -> void:
	var room := &"basement_archive"
	for x in CABINET_ROWS:
		layout.add_piece(&"lockers", Vector3(x, Y, 4.0), Vector3(18.0, 2.2, 0.9), room, PI * 0.5)
	layout.add_piece(&"crate", Vector3(8.2, Y, 25.0), Vector3(1.0, 1.0, 1.0), room)
	layout.add_loot(Vector3(8.2, Y + 1.0, 25.0), room, true)
	layout.add_loot(Vector3(9.0, Y, 16.0), room)
	layout.add_loot(Vector3(24.5, Y, 16.5), room)
	layout.add_loot(Vector3(9.5, Y, -7.5), room)
	var top := ROOM - 0.2
	for x in [9.5, 14.25, 18.75, 23.75]:
		Svc.tube(layout, Vector3(x, top, 4.0), room, 5.0, 1.0, false, x == 18.75)
	Svc.tube(layout, Vector3(13.5, top, 21.5), room, 5.0, 0.9)
	Hub.slots(layout, room, 0, WAX.duplicate(), [Vector2(9.5, 0.0)], Y, Vector2(9.5, 10))
	Hub.slots(layout, room, 0, BUST.duplicate(), [Vector2(14.25, 8.0)], Y, Vector2(14.25, 0))
	Hub.slots(layout, room, 0, KNIGHT.duplicate(), [Vector2(23.5, 15.5)], Y, Vector2(23.5, 0))
	Hub.walker(layout, &"basement_archive_aisle", room, 1, WAX.duplicate(), PackedVector3Array([Vector3(23.75, Y, -6), Vector3(23.75, Y, 15)]), false)
	Hub.slots(layout, room, 1, SCARABS.duplicate(), [Vector2(18.75, 2.0)], Y, Vector2(18.75, 10))
	Hub.slots(layout, room, 1, MUMMY.duplicate(), [Vector2(12.0, 21.5)], Y, Vector2(19, 22))
	Hub.slots(layout, room, 2, SAMURAI.duplicate(), [Vector2(9.5, 10.0)], Y, Vector2(9.5, 0))
	Hub.slots(layout, room, 2, JAGUAR.duplicate(), [Vector2(14.0, -7.0)], Y, Vector2(20, -7))
	Hub.slots(layout, room, 2, HOPLITE.duplicate(), [Vector2(23.75, 5.0)], Y, Vector2(23.75, -5))
	Hub.slots(layout, room, 2, BUST.duplicate(), [Vector2(15.0, 23.5)], Y, Vector2(13, 26))


# --- under the entrance hall --------------------------------------------------------

## The corridor from the booth's boarded staff stairs (their leaves swing
## in here, inside the wall) round to the south corridor's arch on the
## axis; the guards' store off it. The first descent: one sleeping figure.
static func _under_the_hall(layout: LevelLayout) -> void:
	var room := &"basement_corridor_staff"
	layout.add_piece(&"lockers", Vector3(7.0, Y, 36.35), Vector3(5.0, 2.0, 0.6), room, PI)
	layout.add_piece(&"bench", Vector3(-5.0, Y, 36.4), Vector3(2.0, 0.45, 0.6), room, PI)
	Hub.wing_sign(layout, &"sign_basement_booth_1", Vector3(15.95, Y + 2.68, 38.0), 2.0, PI * 0.5, room, &"booth")
	Svc.red(layout, Vector3(15.85, Y + 2.95, 40.0 - 0.45), PI * 0.5, room)
	_pipe(layout, &"booth", [Vector3(15.6, PIPES, 39.6), Vector3(0.4, PIPES, 39.6), Vector3(0.4, PIPES, 30.9)], room)
	var top := CORRIDOR - 0.2
	Svc.tube(layout, Vector3(12.0, top, 38.0), room, 4.5, 1.1)
	Svc.tube(layout, Vector3(3.0, top, 38.0), room, 4.5, 1.0, true, true)
	Svc.tube(layout, Vector3(-8.0, top, 38.0), room, 4.5, 0.9, true, true)
	Svc.tube(layout, Vector3(0, top, 33.0), room, 4.5, 1.0, false)
	layout.add_loot(Vector3(12.5, Y, 39.2), room)
	Hub.slots(layout, room, 0, WAX.duplicate(), [Vector2(-9.5, 37.6)], Y, Vector2(16, 38))
	Hub.slots(layout, room, 1, BUST.duplicate(), [Vector2(-0.6, 33.0)], Y, Vector2(0, 36))
	# the guards' store: lockers, the lantern shelf, spare batteries and shells
	var store := &"basement_store_guards"
	layout.add_piece(&"lockers", Vector3(15.6, Y, 47.0), Vector3(8.0, 2.0, 0.6), store, -PI * 0.5)
	layout.add_piece(&"shelf", Vector3(4.35, Y, 47.0), Vector3(6.0, 2.0, 0.5), store, PI * 0.5)
	layout.add_piece(&"desk", Vector3(10.0, Y, 48.5), Vector3(2.4, 0.8, 1.2), store)
	layout.add_piece(&"crate", Vector3(6.0, Y, 51.3), Vector3(1.2, 0.9, 0.9), store)
	layout.add_loot(Vector3(10.0, Y + 0.8, 48.5), store, true)
	layout.add_loot(Vector3(6.0, Y + 0.9, 51.3), store, true)
	layout.add_loot(Vector3(6.5, Y, 42.5), store)
	layout.add_loot(Vector3(13.0, Y, 43.5), store)
	Svc.tube(layout, Vector3(10.0, top, 44.0), store, 4.5, 1.0)
	Svc.tube(layout, Vector3(10.0, top, 50.0), store, 4.5, 0.9, true, true)
	Hub.slots(layout, store, 0, WAX.duplicate(), [Vector2(7.0, 45.0)], Y, Vector2(10, 41))
	Hub.slots(layout, store, 1, KNIGHT.duplicate(), [Vector2(13.0, 50.5)], Y, Vector2(10, 46))


# --- the three secrets ---------------------------------------------------------------

static func _secrets(layout: LevelLayout) -> void:
	# 1. the deposit cage in the archive: a chained wire door (fists, the
	#    shotgun); confiscated odds and ends, nobody's been in for years
	Kit.gate(layout, &"basement_chain_cage", GateSpec.Kind.CHAIN, GateSpec.HEAVY, &"GATE_CHAIN", &"basement_archive_cage", Grey.r(19.5, 21, 20, 23), Y, 2.4, &"basement_archive", &"basement_cage", DOUBLE)
	var cage := &"basement_cage"
	layout.add_piece(&"crate", Vector3(25.1, Y, 25.1), Vector3(1.2, 1.0, 1.2), cage)
	layout.add_piece(&"shelf", Vector3(25.7, Y, 20.5), Vector3(2.4, 2.0, 0.5), cage, -PI * 0.5)
	layout.add_loot(Vector3(25.1, Y + 1.0, 25.1), cage, true)
	layout.add_loot(Vector3(22.5, Y, 24.8), cage)
	layout.add_marker(&"secret_basement_1", Vector3(23.0, Y, 22.0), cage)
	Svc.down(layout, LightSpec.MAIN, Vector3(23.0, VAULT - 0.3, 22.0), Svc.WARM, 0.9, 2.6, cage, &"bulb")
	# 2. the cellar of Montagu House, the mansion the museum began in:
	#    bricked up behind the plinth store's north wall (a blast); the old
	#    well, wine racks, the founder's wax figure keeping watch
	Kit.gate(layout, &"basement_cracked_cellar", GateSpec.Kind.CRACKED, GateSpec.EXPLOSIVE, &"GATE_CRACKED", &"basement_plinths_cellar", Grey.r(-21, -28, -19, -27.5), Y, 2.4, &"basement_store_plinths", &"basement_old_cellar", OpeningSpec.DoorStyle.PANEL)
	var cellar := &"basement_old_cellar"
	layout.add_piece(&"well", Vector3(-17.0, Y, -31.5), Vector3(1.6, 0.9, 1.6), cellar)
	for x in [-23.0, -18.5]:
		layout.add_piece(&"shelf", Vector3(x, Y, -33.7), Vector3(3.6, 2.0, 0.5), cellar, PI)
	layout.add_piece(&"crate", Vector3(-24.5, Y, -29.2), Vector3(1.0, 0.7, 0.6), cellar)
	layout.add_loot(Vector3(-24.5, Y + 0.7, -29.2), cellar, true)
	layout.add_loot(Vector3(-20.0, Y, -31.0), cellar)
	layout.add_marker(&"secret_basement_2", Vector3(-20.0, Y, -30.0), cellar)
	Svc.down(layout, LightSpec.MAIN, Vector3(-20.0, VAULT - 0.3, -31.0), Svc.WARM, 0.8, 2.6, cellar)
	Kit.lair(layout, &"basement_cellar", cellar, Vector3(-23.5, Y, -31.5), WAX.duplicate(), Grey.r(-25.5, -33.5, -15, -28.5), PI * 0.5)
	# 3. the 1940 air-raid shelter under the entrance hall: a steel door with
	#    an iron ring (the harpoon pulls it out); benches, bunks, the siren,
	#    gas masks and a warden in his mask who never left
	Kit.gate(layout, &"basement_hook_shelter", GateSpec.Kind.HOOK, &"harpoon", &"GATE_HOOK", &"basement_staff_shelter", Grey.r(-9, 40, -7, 40.5), Y, 2.4, &"basement_corridor_staff", &"basement_shelter", OpeningSpec.DoorStyle.GATE)
	var shelter := &"basement_shelter"
	layout.add_piece(&"bench", Vector3(-15.6, Y, 46.0), Vector3(6.0, 0.45, 0.7), shelter, PI * 0.5)
	layout.add_piece(&"bench", Vector3(-4.4, Y, 47.0), Vector3(6.0, 0.45, 0.7), shelter, -PI * 0.5)
	layout.add_piece(&"bunk", Vector3(-13.0, Y, 51.45), Vector3(2.0, 1.6, 0.9), shelter)
	layout.add_piece(&"crate", Vector3(-10.0, Y, 51.5), Vector3(1.2, 0.8, 0.8), shelter)
	layout.add_piece(&"siren", Vector3(-6.0, Y, 51.6), Vector3(0.6, 1.2, 0.6), shelter)
	layout.add_loot(Vector3(-10.0, Y + 0.8, 51.5), shelter, true)
	layout.add_loot(Vector3(-12.5, Y, 43.5), shelter)
	layout.add_marker(&"secret_basement_3", Vector3(-10.0, Y, 46.0), shelter)
	Svc.red(layout, Vector3(-10.0, Y + 2.6, 51.85), PI, shelter)
	Svc.down(layout, LightSpec.MAIN, Vector3(-10.0, VAULT - 0.3, 46.0), Svc.WARM, 0.7, 2.6, shelter, &"bulb")
	Kit.lair(layout, &"basement_shelter", shelter, Vector3(-6.5, Y, 48.5), WAX.duplicate(), Grey.r(-15.5, 43, -4.5, 51.5), PI * 0.5)
