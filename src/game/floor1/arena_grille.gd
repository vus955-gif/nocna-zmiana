class_name ArenaGrille
extends Node3D
## An iron grille that drops into a doorway for a fight (design 6, 7.4: the
## arena shuts; the Great Court's doorways have no doors of their own): the
## bars wait up in the lintel, slam down when the fight starts (never onto
## the guard: it waits while he stands in the doorway) and rise again when
## it ends. Solid while down (WORLD layer; not a navigation source).
## Origin on the floor in the middle of the doorway, -Z into the arena;
## [member size] = doorway width x height.

const BAR_SPACING := 0.22
const BAR := 0.06
const DEPTH := 0.12
const DROP_TIME := 0.35
const LIFT_TIME := 1.6
## The guard this close to the bars' plane keeps them up a little longer.
const CLEARANCE := 0.9
const IRON := Color(0.2, 0.19, 0.18)

var size := Vector2(4.0, 4.0)
var is_down: bool = false

var _bars: Node3D
var _body: StaticBody3D
var _pending: bool = false
var _tween: Tween = null


static func make(at: Transform3D, doorway: Vector2) -> ArenaGrille:
	var grille := ArenaGrille.new()
	grille.transform = at
	grille.size = doorway
	grille.name = "ArenaGrille"
	return grille


func _ready() -> void:
	_bars = Node3D.new()
	_bars.name = "Bars"
	add_child(_bars)
	var material := StandardMaterial3D.new()
	material.albedo_color = IRON
	material.metallic = 0.7
	material.roughness = 0.5
	var count := maxi(int(size.x / BAR_SPACING), 2)
	for i in count + 1:
		var x := -size.x * 0.5 + size.x * i / float(count)
		_bar(Vector3(BAR, size.y, BAR), Vector3(x, size.y * 0.5, 0.0), material)
	for y: float in [0.15, size.y * 0.5, size.y - 0.15]:
		_bar(Vector3(size.x, BAR * 1.4, BAR * 1.4), Vector3(0.0, y, 0.0), material)
	_body = StaticBody3D.new()
	_body.name = "Body"
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, size.y, DEPTH)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0.0, size.y * 0.5, 0.0)
	_body.add_child(collider)
	add_child(_body)
	_show(false)


func _physics_process(_delta: float) -> void:
	if _pending and not _guard_in_the_way():
		_pending = false
		_slam()


## Shuts the doorway (as soon as nobody stands in it).
func drop() -> void:
	if is_down:
		return
	is_down = true
	if _guard_in_the_way():
		_pending = true
		return
	_slam()


## Opens the doorway again.
func lift() -> void:
	_pending = false
	if not is_down:
		return
	is_down = false
	_body.collision_layer = 0
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_bars, ^"position:y", size.y, LIFT_TIME).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func() -> void: _bars.visible = false)
	Sfx.play_at(&"gate_open", global_position + Vector3.UP * size.y, -2.0)


## True while the bars stand down and block the doorway.
func blocks() -> bool:
	return is_down and not _pending


func _slam() -> void:
	_bars.visible = true
	_bars.position.y = size.y
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_bars, ^"position:y", 0.0, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_body.collision_layer = Layers.WORLD
	Sfx.play_at(&"door_slam", global_position + Vector3.UP * size.y * 0.5)


func _show(down: bool) -> void:
	_bars.visible = down
	_bars.position.y = 0.0 if down else size.y
	_body.collision_layer = Layers.WORLD if down else 0
	_body.collision_mask = 0


func _guard_in_the_way() -> bool:
	var guard := get_tree().get_first_node_in_group(&"player") as Node3D if is_inside_tree() else null
	if guard == null:
		return false
	var local := global_transform.affine_inverse() * guard.global_position
	return absf(local.z) < CLEARANCE and absf(local.x) < size.x * 0.5 + 0.5 and local.y > -0.5 and local.y < size.y


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _bar(box: Vector3, at: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = at
	view.material_override = material
	_bars.add_child(view)
