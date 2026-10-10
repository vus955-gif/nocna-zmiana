class_name FlareView
extends Node3D
## First-person flare gun, driven by WeaponHolder. While it reloads the
## barrel breaks open (hinged down), the spent case is gone and a fresh red
## flare shows at the breech for the second half of the reload; a loaded
## barrel shows its flare, an empty one does not. Works on any model with
## nodes named "barrel" and "shell".

const OPEN_ANGLE := deg_to_rad(38.0)

var _barrel: Node3D
var _shell: Node3D
var _open: float = 0.0


func _ready() -> void:
	if get_parent() is WeaponHolder:
		ContentViewmodels.add_fill(self)
	_barrel = find_child("barrel", true, false) as Node3D
	_shell = find_child("shell", true, false) as Node3D


func update_view(state: WeaponState, delta: float) -> void:
	var reloading := state.is_reloading()
	_open = move_toward(_open, 1.0 if reloading else 0.0, delta * (6.0 if reloading else 9.0))
	if _barrel != null:
		_barrel.rotation.x = -OPEN_ANGLE * _open
	if _shell != null:
		_shell.visible = state.magazine > 0 or (reloading and state.reload_progress() > 0.5)


func on_fired(_state: WeaponState) -> void:
	pass


func on_hidden() -> void:
	_open = 0.0
