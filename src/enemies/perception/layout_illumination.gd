class_name LayoutIllumination
extends RefCounted
## How lit a point is (0 dark .. 1 lit), from a LevelLayout's lamps: the
## light model of exhibit perception (PerceptionWorld.configure() takes
## [method at] as its illumination). Cheap and simple on purpose:
## - only lamps of the point's own room count (walls stop light); a room
##   that is not carved (a balcony inside the hall) shares the light of the
##   room it stands in, both ways; a point outside every room takes all,
## - one lamp gives energy x luminance of its colour x (1 - (d / range)^2),
##   nothing beyond its range or outside a spot's cone; a red emergency
##   lamp is therefore half-dark at best,
## - a lamp counts only while its group has power in its room (the
##   [code]powered[/code] callable: blackout, power cut),
## - moonlight ([member moon_level]) falls under the room's skylights.
## The guard's own flashlight and flares are added by PerceptionWorld.

## Light under a skylight on a plain night (half-dark) and on a full moon.
const MOON_LEVEL := 0.3
const FULL_MOON_LEVEL := 0.5

var moon_level: float = MOON_LEVEL

var _layout: LevelLayout
## (group: StringName, room: StringName) -> bool; invalid = always powered.
var _powered: Callable
## Room id -> Array of LightSpec lighting it.
var _by_room: Dictionary = {}
var _all: Array[LightSpec] = []
## Lamps put out (shot down for the night: EnvLayer.put_out; a doused fire
## bowl until it burns again: SacredFire) -> true.
var _out: Dictionary = {}


## The light model of [param layout] (its lights plus [param extra]);
## [param powered] (group, room) -> bool tells which lamps are on.
static func from_layout(layout: LevelLayout, powered: Callable = Callable(), extra: Array[LightSpec] = []) -> LayoutIllumination:
	var model := LayoutIllumination.new()
	model._layout = layout
	model._powered = powered
	model._all.assign(layout.lights + extra)
	var shares := _shared_rooms(layout)
	for room in layout.rooms:
		var lamps: Array[LightSpec] = []
		var lit_by: Array = shares.get(room.id, [room.id])
		for spec in model._all:
			if lit_by.has(spec.room):
				lamps.append(spec)
		model._by_room[room.id] = lamps
	return model


## Light level at [param point] (measure at the guard's chest).
func at(point: Vector3) -> float:
	var room_id := _layout.room_at(point) if _layout != null else &""
	var lamps: Array[LightSpec] = _all
	if room_id != &"":
		lamps = _by_room.get(room_id, _all)
	var total := 0.0
	for spec in lamps:
		if _powered.is_valid() and not _powered.call(spec.group, spec.room):
			continue
		if _out.has(spec):
			continue
		total += contribution(spec, point)
		if total >= 1.0:
			return 1.0
	if room_id != &"" and moon_level > 0.0 and _under_skylight(room_id, point):
		total += moon_level
	return clampf(total, 0.0, 1.0)


## Puts out the lamp standing at [param position] (a lamp shot down for the
## night: EnvLayer.put_out; a fire bowl doused: SacredFire); true when there
## was one.
func put_out(position: Vector3) -> bool:
	for spec in _all:
		if spec.position.distance_to(position) < 0.05:
			_out[spec] = true
			return true
	return false


## Gives back the light of the lamp at [param position] put out before (a
## fire bowl burning again: SacredFire); true when one there was out.
func put_back(position: Vector3) -> bool:
	for spec: LightSpec in _out.keys():
		if spec.position.distance_to(position) < 0.05:
			_out.erase(spec)
			return true
	return false


## This model as the Callable PerceptionWorld.configure() takes.
func callable() -> Callable:
	return at


## What one lamp gives at [param point] (0 when out of reach).
static func contribution(spec: LightSpec, point: Vector3) -> float:
	var to := point - spec.position
	var distance := to.length()
	if spec.light_range <= 0.0 or distance >= spec.light_range:
		return 0.0
	if spec.kind == LightSpec.Kind.SPOT and distance > 0.01:
		var aim := spec.direction.normalized()
		if aim.dot(to / distance) < cos(deg_to_rad(spec.spot_angle)):
			return 0.0
	var color := spec.color
	var luminance := 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b
	var falloff := 1.0 - pow(distance / spec.light_range, 2.0)
	return maxf(spec.energy, 0.0) * luminance * falloff


## A [code]powered[/code] callable that reads the real lamps under
## [param root] (LevelLighting: each Light3D is in its LightSpec group and
## carries meta "room"): a group has power in a room while any of its
## lamps there is visible. A group and room without lamp nodes counts as
## powered.
static func powered_by_nodes(root: Node) -> Callable:
	var index := {}   # group -> room -> Array of Light3D
	for node in root.get_children():
		var lamp := node as Light3D
		if lamp == null:
			continue
		var room: StringName = lamp.get_meta(&"room", &"")
		for group in [LightSpec.MAIN, LightSpec.FLICKER, LightSpec.EMERGENCY, LightSpec.HAVEN]:
			if not lamp.is_in_group(group):
				continue
			var rooms: Dictionary = index.get(group, {})
			index[group] = rooms
			var lamps: Array = rooms.get(room, [])
			rooms[room] = lamps
			lamps.append(lamp)
	return func(group: StringName, room: StringName) -> bool:
		var lamps: Array = (index.get(group, {}) as Dictionary).get(room, [])
		if lamps.is_empty():
			return true
		for lamp: Variant in lamps:
			if is_instance_valid(lamp) and (lamp as Light3D).visible:
				return true
		return false


func _under_skylight(room_id: StringName, point: Vector3) -> bool:
	var room := _layout.room(room_id)
	if room == null:
		return false
	for opening in room.skylights:
		if opening.has_point(Vector2(point.x, point.z)):
			return true
	return false


## Room id -> rooms whose lamps light it: itself, and a room that is not
## carved shares with the carved room it stands in (and back).
static func _shared_rooms(layout: LevelLayout) -> Dictionary:
	var shares := {}
	for room in layout.rooms:
		shares[room.id] = [room.id]
	for guest in layout.rooms:
		if guest.carved or guest.parts.is_empty():
			continue
		var middle := guest.parts[0].get_center()
		for host in layout.rooms:
			if host == guest or not host.carved or host.floor_y > guest.floor_y or not host.covers(middle):
				continue
			(shares[guest.id] as Array).append(host.id)
			(shares[host.id] as Array).append(guest.id)
	return shares
