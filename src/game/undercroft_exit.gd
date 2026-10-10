class_name UndercroftExit
extends Area3D
## A zone halfway down the stairs behind the grate, in the dark: once it
## is armed (the boss is dead), the guard walking in ends the demo.

signal entered_by_guard(player: Player)

const SIZE := Vector3(4.0, 3.0, 2.0)

var armed: bool = false


func _init() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitoring = true
	monitorable = false


func _ready() -> void:
	var box := BoxShape3D.new()
	box.size = SIZE
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = Vector3(0.0, SIZE.y * 0.5, 0.0)
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _physics_process(_delta: float) -> void:
	# armed while he already stands in it (he may have waited there)
	if armed:
		for body in get_overlapping_bodies():
			_on_body_entered(body)


func _on_body_entered(body: Node3D) -> void:
	var guard := body as Player
	if armed and guard != null and guard.alive:
		armed = false
		entered_by_guard.emit(guard)
