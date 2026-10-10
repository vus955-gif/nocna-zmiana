extends RefCounted
## Helpers the west wings (zones/egypt.gd, zones/greece.gd) share: zone
## gates for secrets, a dormant exhibit with its ambush, spot / glow / wall
## and emergency lamps, and security camera markers. Pure layout data.

const Grey := preload("res://src/level/floor1/floor1_greybox.gd")
const RED := Color(1.0, 0.12, 0.08)


## A zone gate off the critical path (id prefixed with the zone) on a new
## passage from [param public_room] into [param hidden_room]; the lock
## shows on the public side.
static func gate(layout: LevelLayout, gate_id: StringName, kind: GateSpec.Kind, needs: StringName, label: StringName, opening_id: StringName, rect: Rect2, floor_y: float, top: float, public_room: StringName, hidden_room: StringName, style: OpeningSpec.DoorStyle) -> GateSpec:
	var passage := Grey.door(layout, opening_id, rect, floor_y, floor_y + top, public_room, hidden_room, style, RoomGraph.Kind.GATE)
	passage.face_room = public_room
	return layout.add_gate(gate_id, kind, opening_id, needs, label)


## One dormant exhibit (placed every night) that wakes when the guard walks
## into [param trigger] (floor plan, from just under [param floor_y] up to
## 3 m over it).
static func lair(layout: LevelLayout, ambush_id: StringName, room: StringName, at: Vector3, kinds: Array[StringName], trigger: Rect2, yaw: float = PI) -> void:
	layout.add_spawn(at, room, SpawnSlot.ALWAYS_SET, kinds.duplicate(), true, yaw)
	var woken: Array[int] = [layout.spawn_slots.size() - 1]
	layout.add_ambush(AmbushSpec.on_area(ambush_id, room, trigger, at.y - 0.5, at.y + 3.0, woken))


static func spot(layout: LevelLayout, at: Vector3, target: Vector3, color: Color, energy: float, reach: float, angle: float, room: StringName, shadow: bool = false) -> LightSpec:
	var light := layout.add_light(LightSpec.MAIN, at, color, energy, reach, room, &"", shadow)
	light.kind = LightSpec.Kind.SPOT
	light.direction = (target - at).normalized()
	light.spot_angle = angle
	return light


## A narrow cone straight down: a glow in a small (secret) room that never
## reaches through a wall into the public room next door.
static func glow(layout: LevelLayout, at: Vector3, color: Color, energy: float, room: StringName) -> void:
	spot(layout, at, at + Vector3.DOWN, color, energy, 3.2, 26.0, room)


## A wall lamp; [param yaw] turns the fitting away from its wall (west wall
## -PI/2, east wall PI/2, north wall PI, south wall 0).
static func sconce(layout: LevelLayout, at: Vector3, yaw: float, color: Color, energy: float, room: StringName, reach: float = 6.0) -> void:
	var lamp := layout.add_light(LightSpec.MAIN, at, color, energy, reach, room, &"sconce")
	lamp.fixture_yaw = yaw


## A red emergency lamp (always on), turned like a sconce.
static func red(layout: LevelLayout, at: Vector3, yaw: float, room: StringName) -> void:
	var lamp := layout.add_light(LightSpec.EMERGENCY, at, RED, 1.0, 6.0, room, &"emergency_lamp")
	lamp.fixture_yaw = yaw


## A security camera marker: the lens position, -Z along the view.
static func camera(layout: LevelLayout, marker: StringName, at: Vector3, target: Vector3, room: StringName) -> void:
	layout.markers[marker] = Transform3D(Basis.looking_at(target - at, Vector3.UP), at)
	layout.marker_rooms[marker] = room
