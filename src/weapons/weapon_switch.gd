class_name WeaponSwitch
extends RefCounted
## Putting one weapon away and drawing the next (owner's note 45, plan
## 2026-10-21-animacje-fpp). Every weapon on the move has a "lower": 0 up
## in the hands, 1 down out of the frame (WeaponHolder lays
## ViewmodelMotion's holster pose over it in that share). The weapon put
## away falls with a steady pull (slow out of the hands, quick out of the
## frame) and is out of sight (HIDE_AT) in its holster time; once every
## weapon going down is gone, the one drawn comes up on a spring tuned to
## settle in its draw time, a touch past its rest when it is light (its
## damping, ViewmodelMotion.draw_damping). Lower and speed carry over a
## change of mind, so a weapon called back on its way down (or put away on
## its way up) turns round where it is. A shot during the switch hurries
## it: whatever is going down is out at once and the draw is quicker. The
## logic of the switch (which weapon fires) is the holder's and is never
## held up by this.

## A weapon going down is out of sight from this lower on (the holster
## pose puts every part under the frame).
const HIDE_AT := 0.92
## A shot during the switch: the draw's spring this much quicker.
const HURRY := 1.8
## Settled: within this of the rest, at most this fast (lower per second).
const SETTLE_LOWER := 0.003
const SETTLE_SPEED := 0.05
## The draw's spring settles to SETTLE_LOWER in its draw time:
## ln(1 / SETTLE_LOWER) / (damping * omega) = draw time.
const SETTLE_LOG := 5.8

## The weapon coming up (&"" when none is).
var drawing: StringName = &""
## Weapon id -> Vector2(lower, speed) of every weapon on the move.
var _moving: Dictionary = {}
## The weapons going down, in the order they were put away.
var _going: Array[StringName] = []
var _hurry: float = 1.0


## [param from] (&"" for none) is put away and [param to] is drawn; any
## other weapon still on the move goes down as well.
func begin(from: StringName, to: StringName) -> void:
	if to == &"":
		return
	_hurry = 1.0
	if from != &"" and from != to and not _moving.has(from):
		_moving[from] = Vector2.ZERO   # it was up in the hands
	for id: StringName in _moving:
		if id != to and not _going.has(id):
			_going.append(id)
	_going.erase(to)
	if not _moving.has(to):
		_moving[to] = Vector2(1.0, 0.0)   # from out of the frame
	drawing = to


## Moves every weapon on the move by [param delta] seconds. Returns the
## weapons that went out of sight in this step (hide them).
func step(delta: float) -> Array[StringName]:
	var hidden: Array[StringName] = []
	for id in _going.duplicate():
		var state: Vector2 = _moving[id]
		var time := maxf(ViewmodelMotion.holster_time(id), 0.02)
		var pull := 2.0 * HIDE_AT / (time * time)
		state.y += pull * delta
		state.x += state.y * delta
		if state.x >= HIDE_AT:
			_going.erase(id)
			_moving.erase(id)
			hidden.append(id)
		else:
			_moving[id] = state
	if drawing != &"" and _going.is_empty() and _moving.has(drawing):
		var state: Vector2 = _moving[drawing]
		var zeta := ViewmodelMotion.draw_damping(drawing)
		var omega := SETTLE_LOG / (zeta * maxf(ViewmodelMotion.draw_time(drawing), 0.05)) * _hurry
		state = Recoil._advance(state.x, state.y, omega, zeta, delta)
		if absf(state.x) < SETTLE_LOWER and absf(state.y) < SETTLE_SPEED:
			_moving.erase(drawing)
			drawing = &""
		else:
			_moving[drawing] = state
	return hidden


## A shot during the switch: everything going down is out of sight at once
## (returned: hide them) and the draw comes up HURRY times quicker.
func hurry() -> Array[StringName]:
	var gone: Array[StringName] = _going.duplicate()
	for id in gone:
		_moving.erase(id)
	_going.clear()
	_hurry = HURRY
	return gone


## How far weapon [param id] is down: 0 up in the hands (or not on the
## move), 1 out of the frame; a little below 0 while a draw settles.
func lower(id: StringName) -> float:
	var state: Variant = _moving.get(id)
	return (state as Vector2).x if state != null else 0.0


## The weapons going down now.
func holstering() -> Array[StringName]:
	return _going.duplicate()


## True while any weapon is on the move.
func busy() -> bool:
	return not _moving.is_empty()


## Nothing on the move any more (a weapon put away for good: hidden).
func reset() -> void:
	_moving.clear()
	_going.clear()
	drawing = &""
	_hurry = 1.0
