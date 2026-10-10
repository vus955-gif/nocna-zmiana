class_name Interactable
extends Area3D
## Something the guard can use with the interact key (E): a terminal, a
## weapon to take, a note. It sits on the INTERACT layer only, so the guard's
## probe finds it while shots, bodies and debris pass through. Subclasses
## override interact() or others listen to [signal interacted].

signal interacted(by: Node)

## Translation key of the action shown in the HUD ("[E] <prompt>").
@export var prompt_key: String = ""
var enabled: bool = true


func _init() -> void:
	collision_layer = Layers.INTERACT
	collision_mask = 0
	monitoring = false
	monitorable = true


func prompt() -> String:
	return tr(prompt_key)


func can_interact(_by: Node) -> bool:
	return enabled


func interact(by: Node) -> void:
	interacted.emit(by)


## Adds a box the guard has to look at, centred at a local [param offset].
func add_box(size: Vector3, offset: Vector3 = Vector3.ZERO) -> CollisionShape3D:
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = offset
	add_child(shape)
	return shape
