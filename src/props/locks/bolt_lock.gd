class_name BoltLock
extends GateLock
## A staff door bolted from one side (design 4.2, the shortcuts opened from
## the inside): from the bolt's side E draws the bolt and the door swings
## away from the guard; from the other side the line says "Bolted from the
## other side" and E only rattles it. No weapon opens it (shots thud into
## the wood). The bolt sits on the back (+Z) by default: the guard who
## comes from the front (-Z) finds it shut.

const BOLT_TRAVEL := 0.16
const SWING := 1.65
const SWING_TIME := 0.9

## True: the bolt is on the front (-Z) side instead.
@export var bolt_in_front: bool = false

var _leaf: Node3D
var _bolt: Node3D


func _init() -> void:
	kind = Kind.BOLT


func _build_body() -> void:
	var wood := LockArt.tile("wood_dark", 1.0, Color(0.3, 0.2, 0.14))
	var iron := LockArt.metal(LockArt.IRON, 0.5)
	var w := size.x - 0.04
	var h := size.y - 0.03
	_leaf = Node3D.new()
	_leaf.name = "Leaf"
	_leaf.position = Vector3(-size.x * 0.5 + 0.02, 0.0, 0.0)   # hinged on the left (seen from the front)
	add_child(_leaf)
	LockArt.box(_leaf, Vector3(w, h, 0.06), Vector3(w * 0.5, h * 0.5, 0.0), wood)
	for y: float in [0.3, h * 0.5, h - 0.3]:
		for side: float in [-1.0, 1.0]:
			LockArt.box(_leaf, Vector3(w * 0.45, 0.05, 0.012), Vector3(w * 0.25, y, side * 0.036), iron)
	var face := -1.0 if bolt_in_front else 1.0
	_bolt = Node3D.new()
	_bolt.name = "Bolt"
	_bolt.position = Vector3(w - 0.12, h * 0.5, face * 0.06)
	_leaf.add_child(_bolt)
	LockArt.rod(_bolt, 0.018, Vector3(-0.2, 0.0, 0.0), Vector3(0.14, 0.0, 0.0), LockArt.metal(LockArt.STEEL, 0.4), 8)
	LockArt.box(_bolt, Vector3(0.025, 0.07, 0.025), Vector3(-0.08, 0.04, 0.0), iron)
	for x: float in [-0.16, -0.02]:
		LockArt.box(_leaf, Vector3(0.05, 0.06, 0.035), Vector3(w - 0.12 + x, h * 0.5, face * 0.055), iron)
	LockArt.box(self, Vector3(0.06, 0.1, 0.05), Vector3(size.x * 0.5 + 0.01, h * 0.5, face * 0.07), iron)   # the keeper
	_add_blocker(Vector3(size.x, size.y, 0.1), Vector3(0.0, size.y * 0.5, 0.0))
	_add_face_zones(Vector3(size.x, size.y, 0.12), Vector3(0.0, size.y * 0.5, 0.0))
	_add_prompt(Vector3(size.x, size.y, 0.2), Vector3(0.0, size.y * 0.5, 0.0))


## True when [param by] stands on the bolt's side of the door.
func on_bolt_side(by: Node) -> bool:
	var body := by as Node3D
	if body == null:
		return false
	var depth := (body.global_position - global_position).dot(global_basis.z)
	return depth < 0.0 if bolt_in_front else depth > 0.0


func prompt_text() -> String:
	var guard := get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
	return tr("LOCK_BOLT_OPEN") if on_bolt_side(guard) else tr("LOCK_BOLT_PROMPT")


## From the bolt's side E draws it; from the other side it only rattles.
func use(by: Node) -> void:
	if on_bolt_side(by):
		open()
		return
	_jolt = maxf(_jolt, 0.8)
	Sfx.play_at(&"bolt_rattle", global_position + Vector3.UP * 1.2, -1.0)
	_hint(tr("LOCK_BOLT_PROMPT"), true)


func _break() -> void:
	Sfx.play_at(&"lock_bolt_slide", _bolt.global_position, 0.0)


func _show_open(animated: bool) -> void:
	super(animated)
	# the leaf swings away from the bolt's side (the guard who drew it)
	var target := SWING * (-1.0 if bolt_in_front else 1.0)
	if not animated:
		_bolt.position.x -= BOLT_TRAVEL
		_leaf.rotation.y = target
		return
	var tween := create_tween()
	tween.tween_property(_bolt, "position:x", _bolt.position.x - BOLT_TRAVEL, 0.25)
	tween.tween_interval(0.1)
	tween.tween_callback(func() -> void: Sfx.play_at(&"gate_swing", global_position + Vector3.UP, -2.0))
	tween.tween_property(_leaf, "rotation:y", target, SWING_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _wrong_effect(info: DamageInfo, _counts: bool) -> void:
	Fx.impact(info.position, info.normal, -1, 0.7)
	Sfx.play_at(&"lock_boards_hit", info.position, -4.0)


func _play_rattle() -> void:
	Sfx.play_at(&"bolt_rattle", global_position + Vector3.UP * 1.2, -3.0)


func _animate_jolt(amount: float) -> void:
	_leaf.rotation.y = sin(amount * 40.0) * 0.01 * amount
