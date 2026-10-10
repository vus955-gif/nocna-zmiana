class_name AmbienceZone
extends Area3D
## A place with its own room tone. While the listener is inside, Ambience
## plays [member zone] (one of Ambience.ZONES: &"grand_hall", &"gallery",
## &"security", &"corridor", &"secret"); overlapping zones: the higher
## Area3D.priority wins. It takes no part in physics (no layer, no mask,
## not monitoring): Ambience tests the listener's position against its
## box, [member size] with the base centred on the node (floor level) or
## the zone's own BoxShape3D children.

@export var zone: StringName = &"gallery"
## Box size (m) when the zone has no BoxShape3D child of its own.
@export var size := Vector3(10.0, 4.0, 10.0)


## A zone filling [param box] (world space).
static func make(zone_id: StringName, box: AABB, zone_priority: int = 0) -> AmbienceZone:
	var area := AmbienceZone.new()
	area.zone = zone_id
	area.size = box.size
	area.priority = zone_priority
	area.position = Vector3(box.position.x + box.size.x * 0.5, box.position.y, box.position.z + box.size.z * 0.5)
	return area


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	if not AudioContext.has_box(self):
		add_child(AudioContext.floor_box(size))
	add_to_group(&"ambience_zones")


func contains(point: Vector3) -> bool:
	return AudioContext.box_contains(self, point)
