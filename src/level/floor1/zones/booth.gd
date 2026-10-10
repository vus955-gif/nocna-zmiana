extends RefCounted
## Floor I zone "booth" (design 5.7; plan docs/superpowers/plans/
## 2026-10-03-p1-w2-hub.md section 2.3): the night shift's own corner east
## of the entrance hall.
## - booth_corridor: the staff corridor from the entrance hall's staff door
##   (junction j_entrance_booth) along the booth: to the security room, the
##   staff room and the service stairs. Nothing lies only behind the haven
##   (haven floors are a navmesh region of their own).
## - booth_security: the start haven (CCTV wall, desk and the chair the
##   guard wakes in facing the monitors, gun locker, upgrade terminal, the
##   museum map on the wall, Heniek's sticky note).
## - booth_staff: the staff room (a loop: corridor -> staff room -> haven).
## - booth_stairs: the service stairs down to the boarded basement door
##   (junction j_booth_basement, gate boards_staff_stairs) at y = -6.
## - booth_watch (secret): the 1912 night-watch room under the corridor,
##   behind an old iron door chained shut at the foot of the stairs (zone
##   gate booth_chain_watch: fists or the shotgun) - the first chain the
##   guard meets. The watchman's log, a cache.
## No exhibits here: the night starts gently (design 7.2).

const ZONE := &"booth"
const Grey := preload("res://src/level/floor1/floor1_greybox.gd")
const Hub := preload("res://src/level/floor1/zones/hub_kit.gd")
const SWING := OpeningSpec.DoorStyle.SWING
const LOW := Floor1Plan.BASEMENT_Y
## Ceiling of the booth's rooms (the roof's stair tower stands from y = 4).
const CEILING := 3.0
const WATCH_CEILING := LOW + 2.8


static func build(layout: LevelLayout) -> void:
	_rooms(layout)
	_security(layout)
	_staff_room(layout)
	_stairs_and_watch_room(layout)
	_lights(layout)


static func _rooms(layout: LevelLayout) -> void:
	Grey.box(layout, &"booth_corridor", Grey.r(17, 40, 38, 43), 0.0, CEILING, ZONE, &"ROOM_BOOTH_CORRIDOR", false)
	var security := Grey.box(layout, &"booth_security", Grey.r(28, 43.5, 38, 48), 0.0, CEILING, ZONE, &"ROOM_BOOTH_SECURITY", false)
	security.haven = true
	Grey.box(layout, &"booth_staff", Grey.r(17, 43.5, 27.5, 48), 0.0, CEILING, ZONE, &"ROOM_BOOTH_STAFF", false)
	# 21 m of stairwell: bottom landing x 17..19 at the basement door, the
	# flight x 19..35 rising east, top landing x 35..38 off the corridor
	Grey.stairwell(layout, &"booth_stairs", Grey.r(17, 36, 38, 39.5), LOW, 0.0, Vector2(1, 0), ZONE)
	var watch := Grey.box(layout, &"booth_watch", Grey.r(17, 40, 25, 46), LOW, WATCH_CEILING, ZONE, &"ROOM_BOOTH_WATCH", false)
	watch.secret = true
	# swing leaves open into the second room along the jamb: their corners
	# stay clear
	Grey.door(layout, &"booth_corridor_security", Grey.r(29, 43, 31, 43.5), 0.0, 2.6, &"booth_corridor", &"booth_security", SWING)
	Grey.door(layout, &"booth_corridor_staff", Grey.r(23, 43, 25, 43.5), 0.0, 2.6, &"booth_corridor", &"booth_staff", SWING)
	Grey.door(layout, &"booth_staff_security", Grey.r(27.5, 45.5, 28, 47.5), 0.0, 2.6, &"booth_staff", &"booth_security", SWING)
	var stairs := Grey.door(layout, &"booth_corridor_stairs", Grey.r(35.5, 39.5, 37.5, 40), 0.0, 2.6, &"booth_corridor", &"booth_stairs")
	stairs.exit_signs = false
	# the old watch room: an iron door at the stairs' foot, chained long ago
	var passage := Grey.door(layout, &"booth_stairs_watch", Grey.r(17, 39.5, 19, 40), LOW, LOW + 2.4, &"booth_stairs", &"booth_watch", OpeningSpec.DoorStyle.DOUBLE_SWING, RoomGraph.Kind.GATE)
	passage.face_room = &"booth_stairs"
	layout.add_gate(&"booth_chain_watch", GateSpec.Kind.CHAIN, &"booth_stairs_watch", GateSpec.HEAVY, &"GATE_CHAIN")


static func _security(layout: LevelLayout) -> void:
	var room := &"booth_security"
	layout.add_piece(&"desk", Vector3(33, 0, 46.6), Vector3(3.2, 0.78, 1.1), room)
	layout.add_piece(&"cctv_wall", Vector3(33, 0, 47.65), Vector3(5, 2.4, 0.6), room)
	layout.add_piece(&"chair", Vector3(33, 0, 45.5), Vector3(0.6, 1.0, 0.6), room, PI, false)
	layout.add_piece(&"lockers", Vector3(35.5, 0, 43.8), Vector3(2.5, 2.0, 0.6), room, PI)
	layout.add_piece(&"shelf", Vector3(28.3, 0, 44.4), Vector3(1.4, 1.8, 0.5), room, -PI * 0.5)
	# the guard wakes in the chair facing the monitors (like the lobby)
	layout.player_start = Transform3D(Basis(Vector3.UP, PI), Vector3(33, 0.05, 45.5))
	# the upgrade terminal against the east wall, facing into the room
	layout.haven_spots[&"security"] = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(37.4, 0, 45.2))
	layout.add_marker(&"pistol_locker", Vector3(35.5, 1.0, 44.12), room, PI)
	layout.add_marker(&"cctv_wall", Vector3(33, 1.5, 47.35), room)
	layout.add_marker(&"museum_map_booth", Vector3(28.05, 1.6, 47.0), room, -PI * 0.5)
	layout.add_marker(&"note_heniek", Vector3(34.2, 0.78, 46.4), room)


static func _staff_room(layout: LevelLayout) -> void:
	var room := &"booth_staff"
	layout.add_piece(&"lockers", Vector3(20.5, 0, 47.7), Vector3(4.0, 2.0, 0.6), room)
	layout.add_piece(&"desk", Vector3(22, 0, 46.2), Vector3(1.8, 0.75, 1.0), room)
	layout.add_piece(&"bench", Vector3(17.45, 0, 45.6), Vector3(2.2, 0.5, 0.7), room, -PI * 0.5)
	layout.add_piece(&"crate", Vector3(17.5, 0, 47.4), Vector3(0.8, 1.8, 0.7), room)
	layout.add_loot(Vector3(22, 0.75, 46.2), room)
	layout.add_loot(Vector3(20, 0, 44.6), room)
	layout.add_loot(Vector3(20.5, 0, 41.5), &"booth_corridor")
	layout.add_loot(Vector3(32, 0, 41.5), &"booth_corridor")
	Hub.look_marker(layout, &"cctv_booth_1", Vector3(17.3, 2.7, 40.3), Vector3(37, 1.0, 41.5), &"booth_corridor")


static func _stairs_and_watch_room(layout: LevelLayout) -> void:
	layout.add_loot(Vector3(18, LOW, 36.7), &"booth_stairs")
	var room := &"booth_watch"
	layout.add_piece(&"desk", Vector3(21.5, LOW, 45.3), Vector3(1.6, 0.78, 0.8), room)
	layout.add_piece(&"chair", Vector3(21.5, LOW, 44.5), Vector3(0.6, 1.0, 0.6), room, PI, false)
	layout.add_piece(&"bench", Vector3(24.5, LOW, 42.5), Vector3(2.0, 0.5, 0.9), room, PI * 0.5)
	layout.add_piece(&"armor_rack", Vector3(17.5, LOW, 43.0), Vector3(1.2, 2.2, 0.8), room, -PI * 0.5)
	layout.add_piece(&"case", Vector3(18.5, LOW, 45.45), Vector3(1.4, 1.6, 0.8), room)
	# the watchman's log (1912) on his desk, and his cache in the case
	layout.add_marker(&"note_booth_1", Vector3(21.7, LOW + 0.78, 45.3), room)
	layout.add_marker(&"secret_booth_1", Vector3(21.5, LOW, 42.5), room)
	layout.add_loot(Vector3(18.5, LOW + 1.0, 45.45), room, true)
	layout.add_loot(Vector3(22.5, LOW, 41.2), room)


static func _lights(layout: LevelLayout) -> void:
	var main := LightSpec.MAIN
	var haven := LightSpec.HAVEN
	for x in [20.0, 26.0, 32.0, 36.5]:
		Hub.lamp(layout, main, Vector3(x, CEILING - 0.2, 41.5), Hub.TUBE, 0.8, 6.0, &"booth_corridor", &"tube_lamp")
	Hub.lamp(layout, main, Vector3(22, CEILING - 0.2, 45.5), Hub.TUBE, 0.7, 7.0, &"booth_staff", &"tube_lamp")
	Hub.lamp(layout, main, Vector3(22.6, 1.2, 46.5), Hub.WARM, 0.8, 4.0, &"booth_staff", &"desk_lamp")
	# the haven keeps its light in a blackout: desk lamp, a tube, the monitors
	Hub.lamp(layout, haven, Vector3(32, 1.16, 46.5), Hub.WARM, 1.6, 7.0, &"booth_security", &"desk_lamp", 0.0, true)
	Hub.lamp(layout, haven, Vector3(33, CEILING - 0.2, 44.5), Hub.TUBE, 0.6, 7.0, &"booth_security", &"tube_lamp")
	Hub.lamp(layout, haven, Vector3(33, 1.5, 47.1), Color(0.4, 0.9, 0.8), 0.6, 3.5, &"booth_security")
	Hub.lamp(layout, main, Vector3(36.5, CEILING - 0.2, 37.75), Hub.TUBE, 0.6, 6.0, &"booth_stairs", &"tube_lamp")
	Hub.lamp(layout, LightSpec.EMERGENCY, Vector3(17.25, LOW + 2.5, 37.75), Hub.RED, 1.0, 5.0, &"booth_stairs", &"emergency_lamp", -PI * 0.5)
	# the watch room: a faint glow on the desk, a cone that stays inside
	Hub.spot(layout, main, Vector3(21.5, WATCH_CEILING - 0.3, 45.0), Vector3(21.5, LOW, 45.3), Hub.WARM, 1.0, 3.2, 30.0, &"booth_watch")
