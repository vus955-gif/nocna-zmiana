class_name PowerShutter
extends GateLock
## A steel fire shutter rolled down over an opening, its housing above and
## a red lamp beside it: "No power" (design 4.2). No weapon moves it; it
## rolls up when power_on() is called (the switchboard downstairs, wired
## by the floor's progress code): the lamp turns green, the motor whines,
## the slats wind up into the housing.

const SLAT := 0.12
const ROLL_TIME := 2.4
const RED := Color(1.0, 0.12, 0.06)
const GREEN := Color(0.25, 1.0, 0.35)

var _curtain: Node3D
var _lamp: MeshInstance3D
var _lamp_light: OmniLight3D


func _init() -> void:
	kind = Kind.POWER


func _build_body() -> void:
	var steel := LockArt.metal(LockArt.STEEL.darkened(0.2), 0.5)
	var dark := LockArt.metal(LockArt.IRON, 0.6)
	var w := size.x
	var h := size.y
	_curtain = Node3D.new()
	_curtain.name = "Curtain"
	add_child(_curtain)
	var slats := ceili(h / SLAT)
	for i in slats:
		var y := (i + 0.5) * SLAT
		LockArt.box(_curtain, Vector3(w - 0.04, SLAT * 0.86, 0.04), Vector3(0.0, y, 0.0), steel)
		LockArt.box(_curtain, Vector3(w - 0.04, SLAT * 0.14, 0.025), Vector3(0.0, y + SLAT * 0.5, -0.004), dark)
	LockArt.box(_curtain, Vector3(w - 0.02, 0.06, 0.07), Vector3(0.0, 0.03, 0.0), dark)   # the bottom bar
	LockArt.box(self, Vector3(w + 0.3, 0.42, 0.42), Vector3(0.0, h + 0.21, 0.08), dark)   # the housing
	for side: float in [-1.0, 1.0]:
		LockArt.box(self, Vector3(0.08, h, 0.12), Vector3(side * (w * 0.5 + 0.02), h * 0.5, 0.0), dark)
	_lamp = LockArt.box(self, Vector3(0.1, 0.1, 0.06), Vector3(w * 0.5 + 0.22, 2.0, -0.05), LockArt.lamp(RED))
	LockArt.box(self, Vector3(0.16, 0.24, 0.04), Vector3(w * 0.5 + 0.22, 1.95, -0.01), dark)
	_lamp_light = OmniLight3D.new()
	_lamp_light.light_color = RED
	_lamp_light.light_energy = 0.6
	_lamp_light.omni_range = 2.0
	_lamp_light.shadow_enabled = false
	_lamp_light.position = Vector3(w * 0.5 + 0.22, 2.0, -0.25)
	add_child(_lamp_light)
	_add_blocker(Vector3(w, h, 0.1), Vector3(0.0, h * 0.5, 0.0))
	_add_face_zones(Vector3(w, h, 0.1), Vector3(0.0, h * 0.5, 0.0))
	_add_prompt(Vector3(w, h, 0.2), Vector3(0.0, h * 0.5, 0.0))


## Power is back: the shutter rolls up (the gate opens).
func power_on() -> void:
	open()


func use(_by: Node) -> void:
	Sfx.play_at(&"power_dead", _lamp.global_position, 0.0)
	_hint(tr("LOCK_POWER_HINT"), true)


func _break() -> void:
	Sfx.play_at(&"lock_power_on", _lamp.global_position, 0.0)
	Sfx.play_at(&"lock_shutter_roll", global_position + Vector3.UP * size.y, 0.0)


func _show_open(animated: bool) -> void:
	super(animated)
	_lamp.material_override = LockArt.lamp(GREEN)
	_lamp_light.light_color = GREEN
	var rolled := Vector3(1.0, 0.04, 1.0)
	var up := Vector3(0.0, size.y, 0.0)
	if not animated:
		_curtain.scale = rolled
		_curtain.position = up
		return
	var tween := create_tween()
	tween.tween_interval(0.3)
	tween.tween_property(_curtain, "scale", rolled, ROLL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(_curtain, "position", up, ROLL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _wrong_effect(info: DamageInfo, _counts: bool) -> void:
	Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.METAL, 0.9)
	Sfx.play_at(&"hit_metal", info.position, -2.0)


func _play_rattle() -> void:
	Sfx.play_at(&"power_dead", global_position + Vector3.UP, -2.0)


func _animate_jolt(amount: float) -> void:
	_curtain.position.z = sin(amount * 45.0) * 0.008 * amount
