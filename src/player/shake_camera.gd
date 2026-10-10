class_name ShakeCamera
extends Camera3D
## First-person camera: trauma-based shake (see Trauma) driven by
## Events.shake_requested, plus short FOV kicks (dash).

@export var base_fov: float = 70.0
@export var max_offset: float = 0.06
@export var max_roll_deg: float = 2.0

var trauma := Trauma.new()
var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _fov_kick: float = 0.0


func _ready() -> void:
	fov = base_fov
	near = 0.05
	_noise.frequency = 18.0
	Events.shake_requested.connect(add_trauma)


func add_trauma(amount: float) -> void:
	trauma.add(amount)


func kick_fov(degrees: float) -> void:
	_fov_kick = maxf(_fov_kick, degrees)


func _process(delta: float) -> void:
	_time += delta
	trauma.tick(delta)
	var strength := trauma.strength()
	h_offset = max_offset * strength * _noise.get_noise_2d(_time, 0.0)
	v_offset = max_offset * strength * _noise.get_noise_2d(0.0, _time)
	rotation.z = deg_to_rad(max_roll_deg) * strength * _noise.get_noise_2d(_time, 50.0)
	_fov_kick = move_toward(_fov_kick, 0.0, 40.0 * delta)
	fov = base_fov + _fov_kick
