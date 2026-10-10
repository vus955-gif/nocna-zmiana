class_name Hurtbox
extends Area3D
## Damage-receiving zone. Weapons look for Hurtboxes and send the hit to
## [member receiver] (a node with take_damage()). Weak points (heads) get
## the weapon's weak_point_multiplier.

@export var weak_point: bool = false
var receiver: Node = null


func _init() -> void:
	collision_layer = Layers.HURTBOX
	collision_mask = 0
	monitoring = false
	monitorable = true


## Builds a hurtbox with one shape at a local [param offset].
static func make(receiver_: Node, shape: Shape3D, offset: Vector3, weak: bool = false) -> Hurtbox:
	var hurtbox := Hurtbox.new()
	hurtbox.receiver = receiver_
	hurtbox.weak_point = weak
	hurtbox.position = offset
	var collider := CollisionShape3D.new()
	collider.shape = shape
	hurtbox.add_child(collider)
	return hurtbox
