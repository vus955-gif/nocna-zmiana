class_name ChainLock
extends GateLock
## A wrought-iron double gate chained shut: a thick chain wrapped round the
## two middle stiles in an X with a brass padlock in front (design 4.2).
## It gives way to the shotgun (25 damage summed within 0.4 s: the pellets
## of one blast, or both barrels from afar) or to three punches; anything
## else strikes sparks and shows "Chain - break it with something heavy
## (shotgun, fists)". Broken, the links fly, the padlock drops and the
## leaves swing back on their hinges.

const BAR_SPACING := 0.14
const BAR_RADIUS := 0.012
const FRAME := 0.025
const CHAIN_HEIGHT := 1.05
## The chain's hit zone round the middle of the gate.
const CHAIN_ZONE := Vector3(0.9, 0.8, 0.14)
const SWING := 1.75
const SWING_TIME := 1.1

var _leaves: Array[Node3D] = []
var _chain: Node3D
var _padlock: Node3D
var _chain_rest := Vector3.ZERO


func _init() -> void:
	kind = Kind.CHAIN


func _build_body() -> void:
	var iron := LockArt.metal(LockArt.IRON, 0.5)
	var half := size.x * 0.5
	for side: float in [-1.0, 1.0]:
		var leaf := Node3D.new()
		leaf.name = "LeafL" if side < 0.0 else "LeafR"
		leaf.position = Vector3(side * half, 0.0, 0.0)
		add_child(leaf)
		_leaves.append(leaf)
		var inner := -side * (half - 0.02)   # the middle stile, seen from the hinge
		var top := size.y - 0.04
		LockArt.rod(leaf, FRAME, Vector3(0.0, 0.0, 0.0), Vector3(0.0, top, 0.0), iron)
		LockArt.rod(leaf, FRAME, Vector3(inner, 0.0, 0.0), Vector3(inner, top, 0.0), iron)
		for y: float in [0.08, size.y * 0.42, top]:
			LockArt.rod(leaf, FRAME * 0.8, Vector3(0.0, y, 0.0), Vector3(inner, y, 0.0), iron)
		var bars := maxi(roundi(absf(inner) / BAR_SPACING) - 1, 1)
		for i in bars:
			var x := inner * float(i + 1) / float(bars + 1)
			LockArt.rod(leaf, BAR_RADIUS, Vector3(x, 0.08, 0.0), Vector3(x, top + 0.12, 0.0), iron, 6)
			LockArt.box(leaf, Vector3(0.03, 0.06, 0.03), Vector3(x, top + 0.14, 0.0), iron, Vector3(0.0, 45.0, 0.0))
	_build_chain()
	_add_blocker(Vector3(size.x, size.y, 0.12), Vector3(0.0, size.y * 0.5, 0.0))
	_add_zone(CHAIN_ZONE, Vector3(0.0, CHAIN_HEIGHT, -0.13))
	_add_prompt(Vector3(size.x, size.y, 0.2), Vector3(0.0, size.y * 0.5, 0.0))


## The chain round the middle stiles in an X, a wrap in front and behind,
## the padlock where they cross.
func _build_chain() -> void:
	_chain = Node3D.new()
	_chain.name = "Chain"
	add_child(_chain)
	var steel := LockArt.metal(LockArt.STEEL.darkened(0.35), 0.4)
	var y := CHAIN_HEIGHT
	for z: float in [-0.06, 0.06]:
		LockArt.chain(_chain, Vector3(-0.32, y + 0.22, z), Vector3(0.32, y - 0.22, z), steel)
		LockArt.chain(_chain, Vector3(-0.32, y - 0.22, z), Vector3(0.32, y + 0.22, z), steel)
	LockArt.chain(_chain, Vector3(-0.1, y + 0.02, -0.07), Vector3(0.1, y + 0.02, -0.07), steel)
	_padlock = LockArt.padlock(_chain, Vector3(0.0, y - 0.1, -0.1), 1.2)
	_chain_rest = _chain.position


func _break() -> void:
	var center := global_transform * Vector3(0.0, CHAIN_HEIGHT, -0.1)
	var away := global_basis.z
	for i in 10:
		var fling := away * randf_range(0.5, 2.0) + Vector3(randf_range(-1.5, 1.5), randf_range(0.5, 2.5), randf_range(-1.0, 1.0))
		Fx.chunk(center + Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.2), 0.0), LockArt.STEEL.darkened(0.35), 0.06, fling)
	var body := _padlock.get_child(0) as MeshInstance3D
	if body != null:
		LockArt.throw_piece(body, -away * 1.2 + Vector3(randf_range(-0.6, 0.6), 1.5, 0.0), 10.0)
	Fx.impact(center, -away, ExhibitMaterial.Kind.METAL, 2.0)
	Sfx.play_at(&"lock_chain_break", center, 2.0)
	Events.shake_requested.emit(0.2)


func _show_open(animated: bool) -> void:
	super(animated)
	_chain.visible = false
	for i in _leaves.size():
		var leaf := _leaves[i]
		var target := SWING * (-1.0 if i == 0 else 1.0)   # both swing away (+Z), into the far room
		if not animated:
			leaf.rotation.y = target
			continue
		var tween := create_tween()
		tween.tween_interval(0.25)
		tween.tween_property(leaf, "rotation:y", target, SWING_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if animated:
		get_tree().create_timer(0.3, false).timeout.connect(func() -> void:
			Sfx.play_at(&"gate_swing", global_position + Vector3.UP, -1.0))


func _wrong_effect(info: DamageInfo, counts: bool) -> void:
	Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.METAL, 1.0 if counts else 0.8)
	Sfx.play_at(&"chain_clank" if counts else &"hit_metal", info.position, -2.0)


func _animate_jolt(amount: float) -> void:
	_chain.position = _chain_rest + Vector3(sin(amount * 50.0) * 0.012 * amount, 0.0, 0.0)
