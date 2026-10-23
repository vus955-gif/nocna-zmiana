class_name Haven
extends Area3D
## A safe room (the security booth, later the broom closet). The Museum
## heals and saves when the guard walks in ([signal guard_entered]).
## Exhibits never get in: the faces of the zone carry invisible walls on the
## ENEMY_BLOCK layer that only exhibits collide with, and an exhibit leaves
## a guard standing inside alone (see shelters()). Shots, the guard and
## debris pass the walls freely. A haven shut for a while (the café's
## pocket during the T-Rex fight: set_active(false)) shelters nobody and its
## walls let exhibits through.

signal guard_entered(player: Player)
signal guard_exited(player: Player)

## Thickness of the exhibit-only walls.
const WALL := 0.3
## Slack when testing points against the zone (feet on the floor count).
const MARGIN := 0.05

static var _active: Array[Haven] = []

var id: StringName = &""
## The zone in world space (the Haven itself is never moved).
var bounds := AABB()
## False while the haven is shut (see set_active()).
var active: bool = true

var _walls: StaticBody3D = null


static func make(haven_id: StringName, zone: AABB) -> Haven:
	var haven := Haven.new()
	haven.id = haven_id
	haven.bounds = zone
	haven.name = "Haven_" + String(haven_id)
	haven.position = zone.get_center()
	return haven


## True when [param point] lies in any haven of the running scene.
static func shelters(point: Vector3) -> bool:
	return at(point) != null


static func at(point: Vector3) -> Haven:
	for haven in _active:
		if is_instance_valid(haven) and haven.active and haven.contains(point):
			return haven
	return null


func _init() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitoring = true
	monitorable = false


func _enter_tree() -> void:
	if not _active.has(self):
		_active.append(self)
	PerceptionWorld.shelters_changed()


func _exit_tree() -> void:
	_active.erase(self)
	PerceptionWorld.shelters_changed()


func _ready() -> void:
	var box := BoxShape3D.new()
	box.size = bounds.size
	var shape := CollisionShape3D.new()
	shape.shape = box
	add_child(shape)
	_build_walls()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func contains(point: Vector3) -> bool:
	return bounds.grow(MARGIN).has_point(point)


## Shuts ([param flag] false) or opens the haven: shut, it shelters nobody
## and its walls stop no exhibit.
func set_active(flag: bool) -> void:
	active = flag
	PerceptionWorld.shelters_changed()   # (the exhibits ask once a frame)
	if _walls != null:
		_walls.collision_layer = Layers.ENEMY_BLOCK if flag else 0


func _build_walls() -> void:
	var walls := StaticBody3D.new()
	walls.name = "ExhibitWalls"
	walls.collision_layer = Layers.ENEMY_BLOCK if active else 0
	walls.collision_mask = 0
	add_child(walls)
	_walls = walls
	var half := bounds.size * 0.5
	var height := bounds.size.y + 1.0
	var faces := [
		[Vector3(half.x, 0.0, 0.0), Vector3(WALL, height, bounds.size.z + WALL)],
		[Vector3(-half.x, 0.0, 0.0), Vector3(WALL, height, bounds.size.z + WALL)],
		[Vector3(0.0, 0.0, half.z), Vector3(bounds.size.x + WALL, height, WALL)],
		[Vector3(0.0, 0.0, -half.z), Vector3(bounds.size.x + WALL, height, WALL)],
	]
	for face in faces:
		var box := BoxShape3D.new()
		box.size = face[1]
		var shape := CollisionShape3D.new()
		shape.shape = box
		shape.position = face[0]
		walls.add_child(shape)


func _on_body_entered(body: Node3D) -> void:
	var guard := body as Player
	if guard != null:
		guard_entered.emit(guard)


func _on_body_exited(body: Node3D) -> void:
	var guard := body as Player
	if guard != null:
		guard_exited.emit(guard)
