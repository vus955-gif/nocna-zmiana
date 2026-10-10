class_name RopeLock
extends GateLock
## A rope out of reach holding a counterweight (design 4.2): it hangs from
## a pulley [member height] metres up, the iron weight [member hang] metres
## below it. Only a precise shot cuts it: the rifle from anywhere, the
## pistol from within 15 m. Cut, the rope snaps (the top whips up), the
## weight drops to the floor with a thud. What the weight held (a bridge, a
## bell, a portcullis) answers to [signal opened]. It blocks no passage
## itself. The origin is on the floor right under the weight. A rope with
## [member requirement] &"rifle_hunt" (GateSpec) takes the rifle only.

const WEIGHT := Vector3(0.36, 0.42, 0.36)
const ROPE_RADIUS := 0.022
## The rope's hit zone is this wide (a fair target from afar).
const ROPE_ZONE := 0.32
const DROP_TIME := 0.55

## The pulley's height above the floor and the rope's length below it.
@export var height: float = 6.0
@export var hang: float = 3.0
## &"rifle_hunt": only the rifle cuts it (the floor's GateSpec requirement).
@export var requirement: StringName = &""

var _upper: Node3D
var _lower: Node3D
var _pulley: Node3D


func _init() -> void:
	kind = Kind.ROPE


func _build_body() -> void:
	var iron := LockArt.metal(LockArt.IRON, 0.55)
	var rope := LockArt.matte(LockArt.ROPE, 0.95)
	var bottom := maxf(height - hang, WEIGHT.y)
	_pulley = Node3D.new()
	_pulley.name = "Pulley"
	_pulley.position = Vector3(0.0, height, 0.0)
	add_child(_pulley)
	LockArt.box(_pulley, Vector3(0.9, 0.16, 0.16), Vector3(0.0, 0.2, 0.0), LockArt.tile("timber", 1.0, Color(0.4, 0.3, 0.2)))
	LockArt.ring(_pulley, 0.12, 0.03, Vector3(0.0, 0.0, 0.0), Vector3.BACK, iron)
	LockArt.rod(_pulley, 0.015, Vector3(0.0, 0.12, 0.0), Vector3(0.0, 0.2, 0.0), iron)
	# the rope is cut where it is hit: two halves meeting in the middle
	var middle := (height + bottom) * 0.5
	_upper = Node3D.new()
	_upper.name = "RopeTop"
	_upper.position = Vector3(0.0, height, 0.0)
	add_child(_upper)
	LockArt.rod(_upper, ROPE_RADIUS, Vector3.ZERO, Vector3(0.0, middle - height, 0.0), rope, 6)
	_lower = Node3D.new()
	_lower.name = "Weight"
	_lower.position = Vector3(0.0, bottom, 0.0)
	add_child(_lower)
	LockArt.rod(_lower, ROPE_RADIUS, Vector3(0.0, middle - bottom, 0.0), Vector3(0.0, 0.0, 0.0), rope, 6)
	LockArt.ring(_lower, 0.06, 0.014, Vector3(0.0, -0.04, 0.0), Vector3.BACK, iron)
	LockArt.box(_lower, WEIGHT, Vector3(0.0, -0.1 - WEIGHT.y * 0.5, 0.0), iron)
	LockArt.box(_lower, Vector3(WEIGHT.x + 0.04, 0.05, WEIGHT.z + 0.04), Vector3(0.0, -0.12, 0.0), iron)
	_add_zone(Vector3(ROPE_ZONE, height - bottom - 0.3, ROPE_ZONE), Vector3(0.0, middle, 0.0))
	_add_prompt(Vector3(ROPE_ZONE, height - bottom, ROPE_ZONE), Vector3(0.0, middle, 0.0))


## The rope's hit zone stands free in the air: nothing to block.
func blocks_passage() -> bool:
	return false


## A rifle-only rope turns the pistol away (with its own hint).
func take_damage(info: DamageInfo) -> void:
	if not is_open and info != null and requirement == &"rifle_hunt" and info.weapon == &"pistol":
		_jolt = maxf(_jolt, 0.4)
		_wrong_effect(info, false)
		_hint(tr("LOCK_ROPE_RIFLE"))
		return
	super(info)


func _break() -> void:
	var cut := global_transform * Vector3(0.0, (height + maxf(height - hang, WEIGHT.y)) * 0.5, 0.0)
	Fx.impact(cut, -global_basis.z, ExhibitMaterial.Kind.CANVAS, 1.2)
	Sfx.play_at(&"lock_rope_snap", cut, 1.0)


func _show_open(animated: bool) -> void:
	super(animated)
	var floor_y := WEIGHT.y + 0.12
	if not animated:
		_lower.position.y = floor_y
		_lower.rotation.z = 0.12
		_upper.scale = Vector3(1.0, 0.25, 1.0)
		return
	var whip := create_tween()
	whip.tween_property(_upper, "scale", Vector3(1.0, 0.25, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var drop := create_tween()
	drop.tween_property(_lower, "position:y", floor_y, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_callback(_land)
	drop.tween_property(_lower, "rotation:z", 0.12, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _land() -> void:
	var at := global_transform * Vector3(0.0, 0.05, 0.0)
	Fx.impact(at, Vector3.UP, -1, 3.0)
	Sfx.play_at(&"lock_counterweight", at, 2.0)
	Events.shake_requested.emit(0.25)


func _wrong_effect(info: DamageInfo, _counts: bool) -> void:
	Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.CANVAS, 0.5)
	Sfx.play_at(&"hit_canvas", info.position, -6.0)


func _play_rattle() -> void:
	Sfx.play_at(&"hit_canvas", global_position + Vector3.UP * height * 0.5, -8.0)


func _animate_jolt(amount: float) -> void:
	_lower.rotation.z = sin(amount * 18.0) * 0.06 * amount
