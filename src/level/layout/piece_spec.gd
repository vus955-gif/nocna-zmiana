class_name PieceSpec
extends RefCounted
## One level piece: a kit id (what it is), where it stands (the centre of
## its base), how big it is and which way it faces (-Z = front after yaw).

var kit: StringName = &""
var position := Vector3.ZERO
var size := Vector3.ONE
## Radians around +Y.
var yaw: float = 0.0
var room: StringName = &""
var collide: bool = true
## Alpha 0 = take the room's tint.
var tint := Color(0.0, 0.0, 0.0, 0.0)


static func make(kit_id: StringName, at: Vector3, dimensions: Vector3, room_id: StringName, facing: float = 0.0, solid: bool = true) -> PieceSpec:
	var piece := PieceSpec.new()
	piece.kit = kit_id
	piece.position = at
	piece.size = dimensions
	piece.room = room_id
	piece.yaw = facing
	piece.collide = solid
	return piece


func transform() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), position)


## Floor-plan footprint (axis-aligned bounds of the rotated base).
func footprint() -> Rect2:
	var half := Vector2(size.x, size.z) * 0.5
	var corners: Array[Vector2] = [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]
	var rect := Rect2()
	for i in corners.size():
		var turned := corners[i].rotated(-yaw) + Vector2(position.x, position.z)
		rect = Rect2(turned, Vector2.ZERO) if i == 0 else rect.expand(turned)
	return rect
