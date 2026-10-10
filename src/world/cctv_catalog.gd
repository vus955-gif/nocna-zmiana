class_name CctvCatalog
## The lobby's six security cameras (design: rozbudowa section 5): where
## each hangs, what it looks at, which room it watches and what its feed is
## called; plus the night clock burnt into the feeds. Pure data.

## One camera: id (1-6 on the console), name key, watched room, lens
## position and the point it looks at.
class Camera:
	var number: int = 1
	var id: StringName = &""
	var room: StringName = &""
	var position := Vector3.ZERO
	var target := Vector3.ZERO
	var fov: float = 64.0
	## Translation key of its name ("" = CCTV_CAM_<ID>).
	var label_key: String = ""

	func _init(number_: int, id_: StringName, room_: StringName, at: Vector3, looking_at: Vector3, field: float = 64.0) -> void:
		number = number_
		id = id_
		room = room_
		position = at
		target = looking_at
		fov = field

	## Lens transform (-Z along the view).
	func transform() -> Transform3D:
		return Transform3D(Basis.looking_at(target - position, Vector3.UP), position)

	func name_key() -> String:
		return label_key if label_key != "" else "CCTV_CAM_" + String(id).to_upper()


## The night's own clock (NightClock: 23:00 -> 06:00 in 21 minutes, one
## second of play is twenty on the clock), in seconds of the day.
const CLOCK_START := NightClock.START_HOUR * 3600
const CLOCK_SPEED := 3600.0 / NightClock.SECONDS_PER_HOUR
const CLOCK_END := ((NightClock.START_HOUR + NightClock.HOURS) % 24) * 3600


## The six cameras in console order.
static func cameras() -> Array[Camera]:
	var list: Array[Camera] = [
		Camera.new(1, &"hall", &"hall", Vector3(15.2, 12.4, 21.2), Vector3(0.0, 2.0, -9.0), 66.0),
		Camera.new(2, &"gallery", &"gallery", Vector3(-20.8, 5.7, 12.8), Vector3(-36.0, 0.8, -2.0)),
		Camera.new(3, &"armory", &"armory", Vector3(20.8, 5.7, -12.8), Vector3(36.0, 0.8, 2.0)),
		Camera.new(4, &"diorama", &"diorama", Vector3(13.2, 7.2, 24.8), Vector3(-5.0, 0.4, 38.0)),
		Camera.new(5, &"balcony", &"balcony", Vector3(17.2, 9.7, 3.4), Vector3(-6.0, 6.2, -20.0), 70.0),
		Camera.new(6, &"staff", &"staff_corridor", Vector3(1.15, 2.62, 53.1), Vector3(0.0, 1.0, 45.2), 70.0),
	]
	return list


## "23:41:07" after [param seconds] of the night (it stops at 06:00:00).
static func clock_text(seconds: float) -> String:
	var total := CLOCK_START + int(maxf(seconds, 0.0) * CLOCK_SPEED)
	var day := 24 * 3600
	total = mini(total, day + CLOCK_END) % day
	return "%02d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]


## Floor I's six hub cameras (stage P1: the entrance hall, the Great Court
## south and north, the Reading Room, the north corridor, the staff
## corridor), each with the room it watches.
static func floor_cameras() -> Array[Camera]:
	var list: Array[Camera] = [
		Camera.new(1, &"entrance", &"entrance_hall", Vector3(15.3, 9.0, 31.8), Vector3(-6.0, 0.5, 47.0), 70.0),
		Camera.new(2, &"court_south", &"court", Vector3(-29.3, 12.0, 29.3), Vector3(2.0, 0.5, 16.0), 70.0),
		Camera.new(3, &"court_north", &"court", Vector3(29.3, 12.0, -29.3), Vector3(0.0, 1.0, -20.0), 70.0),
		Camera.new(4, &"reading", &"court_reading", Vector3(-12.0, 9.0, 12.0), Vector3(2.0, 0.5, -2.0), 70.0),
		Camera.new(5, &"north", &"north_hall", Vector3(-29.5, 6.5, -31.5), Vector3(8.0, 0.5, -36.0), 66.0),
		Camera.new(6, &"corridor", &"booth_corridor", Vector3(27.2, 2.6, 42.8), Vector3(17.0, 1.0, 41.5), 70.0),
	]
	return list


## The zones whose cameras come first (the booth's wall shows the first
## six: the hub round the guard's post), in this order; the wings follow.
const HUB_ZONES: Array[StringName] = [&"booth", &"entrance", &"court", &"north_hall"]
## Cameras on the booth's monitor wall.
const WALL := 6


## The zone of a camera marker cctv_<zone>_<n> (&"" for another id).
static func marker_zone(id: StringName) -> StringName:
	var text := String(id)
	if not text.begins_with("cctv_"):
		return &""
	text = text.substr(5)
	var cut := text.rfind("_")
	return StringName(text.substr(0, cut) if cut > 0 and text.substr(cut + 1).is_valid_int() else text)


## Sort order of the camera markers: the hub's zones first (HUB_ZONES),
## then the wings by name, each zone's cameras by number.
static func marker_before(a: StringName, b: StringName) -> bool:
	var zone_a := marker_zone(a)
	var zone_b := marker_zone(b)
	var rank_a := HUB_ZONES.find(zone_a)
	var rank_b := HUB_ZONES.find(zone_b)
	rank_a = rank_a if rank_a >= 0 else HUB_ZONES.size()
	rank_b = rank_b if rank_b >= 0 else HUB_ZONES.size()
	if rank_a != rank_b:
		return rank_a < rank_b
	if zone_a != zone_b:
		return String(zone_a) < String(zone_b)
	return String(a).naturalnocasecmp_to(String(b)) < 0


## The cameras of a level: its cctv_<zone>_<n> markers (the hub's first:
## marker_before; each looks along its marker's -Z and a little down; its
## name is its room's), at most [param count] of them (0: all), the
## defaults filling up to the wall's six.
static func cameras_from(markers: Dictionary, marker_rooms: Dictionary, room_names: Dictionary, defaults: Array[Camera], count: int = 0) -> Array[Camera]:
	var ids: Array = markers.keys().filter(func(id: StringName) -> bool: return String(id).begins_with("cctv_") and id != &"cctv_wall")
	ids.sort_custom(marker_before)
	var list: Array[Camera] = []
	for id: StringName in ids:
		if count > 0 and list.size() >= count:
			break
		var at: Transform3D = markers[id]
		var room: StringName = marker_rooms.get(id, &"")
		var camera := Camera.new(list.size() + 1, id, room, at.origin, at.origin - at.basis.z * 10.0 + Vector3.DOWN * 3.0, 70.0)
		camera.label_key = String(room_names.get(room, ""))
		list.append(camera)
	for camera in defaults:
		if list.size() >= WALL:
			break
		camera.number = list.size() + 1
		list.append(camera)
	return list
