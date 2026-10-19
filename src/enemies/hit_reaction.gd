class_name HitReaction
extends Node3D
## An exhibit's whole body answering a hit (plan 2026-10-19-gun-feel): it
## leans along the shot, pivoting at its feet (the top goes where the shot
## went), twists a little toward the side it was hit on, rocks back past
## upright and settles - a heavy statue jolted, not a ragdoll. Lives
## between the Enemy and its visual (Enemy.visual is a child), so the model,
## its parts and the hit zones that follow them (ExhibitRig.track) all
## lean together. Sleeps (no physics step) while at rest.

## The rocking spring (Hz, damping ratio: a little swing past upright).
const FREQUENCY := 2.4
const DAMPING := 0.5
## Never leans further than this (rad), however many hits pile up.
const MAX_TILT := 0.32
const MAX_TWIST := 0.2

const TILT_X := 0
const TILT_Z := 1
const TWIST := 2

var _recoil := Recoil.new(3, FREQUENCY, DAMPING)


func _ready() -> void:
	name = "HitReaction"
	set_physics_process(false)


## A hit travelling along [param direction] (the exhibit's own space; only
## its flat part counts) leans the body [param lean] rad that way (a peak),
## and [param twist] rad about its upright axis (signed: + turns it left).
func hit(direction: Vector3, lean: float, twist: float = 0.0) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001 or (lean <= 0.0 and twist == 0.0):
		return
	flat = flat.normalized()
	# turning about UP x flat tips the top toward flat
	var axis := Vector3.UP.cross(flat)
	_recoil.kick(TILT_X, axis.x * lean)
	_recoil.kick(TILT_Z, axis.z * lean)
	_recoil.kick(TWIST, twist)
	set_physics_process(true)


## The lean now as a turn vector (axis times angle, rad) and the twist
## (rad), for tests.
func lean() -> Vector3:
	return Vector3(_recoil.value(TILT_X), 0.0, _recoil.value(TILT_Z))


func twist() -> float:
	return _recoil.value(TWIST)


func resting() -> bool:
	return _recoil.resting(1e-4)


func _physics_process(delta: float) -> void:
	_recoil.step(delta)
	var turn := lean()
	if turn.length() > MAX_TILT:
		_recoil.limit(TILT_X, absf(turn.x) * MAX_TILT / turn.length())
		_recoil.limit(TILT_Z, absf(turn.z) * MAX_TILT / turn.length())
		turn = lean()
	_recoil.limit(TWIST, MAX_TWIST)
	if _recoil.resting(1e-4):
		_recoil.reset()
		transform = Transform3D.IDENTITY
		set_physics_process(false)
		return
	var tilt := Basis(turn.normalized(), turn.length()) if turn.length() > 1e-6 else Basis.IDENTITY
	transform = Transform3D(tilt * Basis(Vector3.UP, twist()), Vector3.ZERO)
