class_name GatlingView
extends Node3D
## The greybox first-person gatling (ContentViewmodels, when the vm_gatling
## model is off or missing; the model runs on ViewmodelRig), driven by
## WeaponHolder every frame it is in hand (update_view) and on every round
## (on_fired). The barrel cluster and the crank turn with
## WeaponState.barrel_speed(); each round jolts the gun a little; a long
## burst makes the barrels glow. Sounds, heat, smoke and the jolt come from
## its GatlingDriver (shared with the model's rig). Works on any model with
## nodes named "model", "barrels" and "crank".

const GLOW := Color(1.0, 0.28, 0.08)
## Where the model sits inside the view and how big it is (the holder
## moves the view's root).
const MODEL_REST := Vector3(0.02, -0.07, 0.0)
const MODEL_SCALE := 0.62

var _model: Node3D
var _barrels: Node3D
var _crank: Node3D
var _hot: Array[StandardMaterial3D] = []
var _driver: GatlingDriver


func _ready() -> void:
	if get_parent() is WeaponHolder:
		ContentViewmodels.add_fill(self)
	_model = find_child("model", false, false) as Node3D
	_barrels = find_child("barrels", true, false) as Node3D
	_crank = find_child("crank", true, false) as Node3D
	if _barrels != null:
		_hot = _own_glowing_materials(_barrels, "barrel_")
	_driver = GatlingDriver.new()
	var muzzle := get_node_or_null(^"Muzzle") as Node3D
	_driver.position = muzzle.position if muzzle != null else Vector3(0, 0, -0.55)
	add_child(_driver)


## Called by WeaponHolder every frame while the gatling is in hand.
func update_view(state: WeaponState, delta: float) -> void:
	var speed := state.barrel_speed()
	if _barrels != null:
		_barrels.rotate_object_local(Vector3.BACK, GatlingDriver.BARREL_SPEED * speed * delta)
	if _crank != null:
		_crank.rotate_object_local(Vector3.RIGHT, -GatlingDriver.CRANK_SPEED * speed * delta)
	_driver.update(state, delta)
	var glow := _driver.glow()
	for material in _hot:
		material.emission_energy_multiplier = glow * glow * 1.6
	if _model != null:
		_model.position = MODEL_REST + _driver.jolt


## Called by WeaponHolder on every round fired.
func on_fired(_state: WeaponState) -> void:
	_driver.fired()


## Called by WeaponHolder when the gatling is put away.
func on_hidden() -> void:
	_driver.hidden()


## The barrel meshes (named [param prefix]...) get their own copy of their
## material, able to glow.
static func _own_glowing_materials(node: Node, prefix: String) -> Array[StandardMaterial3D]:
	var out: Array[StandardMaterial3D] = []
	var copies := {}
	for child in node.find_children(prefix + "*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		var source := view.material_override as StandardMaterial3D
		if source == null:
			continue
		if not copies.has(source):
			var copy := source.duplicate() as StandardMaterial3D
			copy.emission_enabled = true
			copy.emission = GLOW
			copy.emission_energy_multiplier = 0.0
			copies[source] = copy
			out.append(copy)
		view.material_override = copies[source]
	return out
