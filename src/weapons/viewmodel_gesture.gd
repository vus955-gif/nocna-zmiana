class_name ViewmodelGesture
extends RefCounted
## What the guard's free left hand does, and how the weapon in hand makes
## way for it (owner's note 45, plan 2026-10-21-animacje-fpp), as one
## timeline at a time:
## - JAB (no weapon, or a handgun in the right hand): the left fist comes
##   up from under the frame on an arc (cocked, rising, driving in to
##   WeaponHolder.FIST_HIT), follows through, and drops back out low; the
##   handgun is pulled back and aside as the shoulders turn into the blow;
## - BASH (a long gun, held in both hands: a free left fist would be a
##   second left hand): the gun is coiled to the right and driven forward
##   and across with a twist; SHOVE (a heavy piece): shoved straight out;
## - REACH (interact, E): the left hand reaches out under the crosshair,
##   takes hold with a turn of the wrist and comes back; a handgun makes
##   way, a two-handed weapon is first lowered out of the frame (its left
##   hand lets go of the fore-end) and brought back up once the hand is
##   gone again.
## Poses are in the holder's space: fist() places the fist view, weapon()
## is a layer [offset, turn] for the weapon in hand, weapon_lower() a share
## of its holster pose. Everything eases from key to key (keyed curves,
## Bezier paths), so nothing jumps; hurry() plays the rest four times as
## fast (a shot needs the weapon).

enum Kind { NONE, JAB, BASH, SHOVE, REACH, REACH_TWO }

## The jab: its length (s), the cocked start under the frame (the fist
## comes up to the frame's edge first), the arc's rise, the hit
## (WeaponHolder.FIST_HIT), the low way back; when the strike lands and how
## long it follows through. Measured: the fist never moves more than about
## its own width in a frame (the strike is the fastest motion of all).
const JAB_TIME := 0.32
const JAB_FROM := Vector3(-0.24, -0.36, -0.26)
const JAB_COCK := Vector3(-0.22, -0.27, -0.3)
const JAB_RISE := Vector3(-0.18, -0.12, -0.44)
const JAB_HIT := Vector3(-0.05, -0.14, -0.62)
const JAB_BACK := Vector3(-0.1, -0.33, -0.46)
const JAB_COCKED_AT := 0.04
const JAB_HIT_AT := 0.13
const JAB_HELD_TO := 0.17
## How much the strike slows into the hit (0: an even drive).
const JAB_SLOWING := 0.3
## The shoulders turning into a jab: the handgun pulled back and aside.
const JAB_WEAPON := [
	[0.0, Vector3.ZERO, Vector3.ZERO],
	[0.04, Vector3(0.005, -0.005, 0.012), Vector3(0.0, 0.03, 0.0)],
	[0.13, Vector3(0.03, -0.025, 0.035), Vector3(-0.04, -0.1, 0.06)],
	[0.17, Vector3(0.03, -0.025, 0.035), Vector3(-0.04, -0.1, 0.06)],
	[0.32, Vector3.ZERO, Vector3.ZERO],
]
## A long gun's bash: coiled right, driven forward and across with a twist,
## held a beat, back. (Measured with the longest barrel: its muzzle never
## sweeps more than about a fist's width a frame.)
const BASH := [
	[0.0, Vector3.ZERO, Vector3.ZERO],
	[0.05, Vector3(0.015, -0.01, 0.04), Vector3(0.0, -0.1, -0.07)],
	[0.17, Vector3(-0.07, 0.03, -0.11), Vector3(0.08, 0.32, 0.35)],
	[0.21, Vector3(-0.075, 0.03, -0.115), Vector3(0.08, 0.34, 0.37)],
	[0.38, Vector3.ZERO, Vector3.ZERO],
]
## A heavy piece shoved out from the hip.
const SHOVE := [
	[0.0, Vector3.ZERO, Vector3.ZERO],
	[0.08, Vector3(0.0, -0.015, 0.05), Vector3(0.04, 0.0, 0.0)],
	[0.17, Vector3(-0.02, 0.025, -0.1), Vector3(0.1, 0.06, 0.12)],
	[0.21, Vector3(-0.02, 0.025, -0.105), Vector3(0.1, 0.06, 0.12)],
	[0.38, Vector3.ZERO, Vector3.ZERO],
]
## The reach: its length (s) for the hand, from under the frame to under
## the crosshair (out on a rising curve, back on a lower one); the hold
## with the wrist's turn between REACH_HOLD and REACH_BACK.
const REACH_TIME := 0.54
const REACH_FROM := Vector3(-0.24, -0.36, -0.26)
const REACH_OUT := Vector3(-0.2, -0.2, -0.4)
const REACH_AT := Vector3(-0.07, -0.12, -0.5)
const REACH_IN := Vector3(-0.14, -0.3, -0.4)
const REACH_HOLD := 0.2
const REACH_BACK := 0.34
## A handgun making way for the reaching hand.
const REACH_WEAPON := [
	[0.0, Vector3.ZERO, Vector3.ZERO],
	[0.14, Vector3(0.025, -0.035, 0.02), Vector3(-0.06, -0.06, 0.04)],
	[0.34, Vector3(0.025, -0.035, 0.02), Vector3(-0.06, -0.06, 0.04)],
	[0.54, Vector3.ZERO, Vector3.ZERO],
]
## A two-handed weapon: down out of the frame by TWO_DOWN, the hand starts
## out at TWO_HAND_AT, the weapon comes back up from TWO_UP to TWO_TIME
## (the hand is under the frame again by then).
const TWO_DOWN := 0.28
const TWO_HAND_AT := 0.22
const TWO_UP := 0.7
const TWO_TIME := 0.98
## hurry(): the rest of the gesture this many times as fast.
const HURRY := 4.0

## A gesture restarted while one runs (a blow during a reach, E pressed
## again) hands what would jump to decaying carries: the fist's and the
## weapon layer's offsets from where they were die away on critically
## damped springs (CARRY_OMEGA), and the weapon comes back up from where it
## was lowered (TAIL_OMEGA, twice as quick after a shot). Below CARRY_REST
## a carry is done.
const CARRY_OMEGA := 16.0
const TAIL_OMEGA := 14.0
const CARRY_REST := 0.0001

var kind: Kind = Kind.NONE
## Seconds into the gesture.
var t: float = 0.0
var _speed: float = 1.0
## Where the fist starts (a jab thrown while the hand is out starts there).
var _fist_from := JAB_FROM
## Seconds the reach's hold is still drawn out by (E pressed again).
var _hold_extra := 0.0
## A jab thrown by the free hand of a two-handed reach: the weapon (and
## its left hand) stays out of the frame until the fist is gone again.
var _lowered := false
## The carries (see CARRY_OMEGA) and their velocities.
var _fist_off := Vector3.ZERO
var _fist_off_v := Vector3.ZERO
var _fist_turn_off := Vector3.ZERO
var _fist_turn_off_v := Vector3.ZERO
var _weapon_off := Vector3.ZERO
var _weapon_off_v := Vector3.ZERO
var _weapon_turn_off := Vector3.ZERO
var _weapon_turn_off_v := Vector3.ZERO
var _tail := 0.0
var _tail_v := 0.0
var _tail_quick := false


## A blow: a jab with the left fist when no weapon is up in the hands
## ([param weapon_up] false) or a handgun is; a long gun bashes, a heavy
## piece shoves ([param grip]: ViewmodelMotion.Grip). During a two-handed
## reach with the free hand out, that hand throws the jab and the weapon
## stays down until it is gone; otherwise a blow thrown mid-gesture starts
## from where everything is (the carries).
func punch(grip: int, weapon_up: bool) -> void:
	var was := _pose()
	var hand_out := _raw_shows_fist()
	var free_hand := kind == Kind.REACH_TWO and hand_out
	var from: Vector3 = (_raw_fist()[1] as Vector3) if hand_out else JAB_FROM
	_speed = 1.0
	t = 0.0
	_hold_extra = 0.0
	_lowered = false
	if free_hand:
		kind = Kind.JAB
		_fist_from = from
		_lowered = true
	elif not weapon_up or grip == ViewmodelMotion.Grip.ONE_HAND:
		kind = Kind.JAB
		_fist_from = from
	elif grip == ViewmodelMotion.Grip.LONG:
		kind = Kind.BASH
	else:
		kind = Kind.SHOVE
	_carry(was)


## The reach of an interaction (E). Ignored while a blow is under way (the
## interaction itself still happens). Pressed again during a reach, the
## reach goes on: on its way out it carries on, holding it holds longer,
## on its way back the hand goes out again from where it is, and a
## two-handed weapon on its way back up goes down again from where it is.
func reach(grip: int, weapon_up: bool) -> void:
	if kind == Kind.JAB or kind == Kind.BASH or kind == Kind.SHOVE:
		return
	var want := Kind.REACH_TWO if weapon_up and grip != ViewmodelMotion.Grip.ONE_HAND else Kind.REACH
	if kind == want:
		_reach_again()
		return
	var was := _pose()
	_speed = 1.0
	t = 0.0
	_hold_extra = 0.0
	_lowered = false
	kind = want
	_carry(was)


func _reach_again() -> void:
	_speed = 1.0
	if kind == Kind.REACH_TWO and t >= TWO_UP:
		# on its way back up: down again from the same lowered share
		var was := _pose()
		t = TWO_DOWN * _smoothstep_inverse(_raw_lower())
		_hold_extra = 0.0
		_carry(was)
		return
	var r := _hand_time()
	if r < REACH_HOLD:
		return   # on its way out (or not yet out): it goes on
	if r < REACH_BACK:
		_hold_extra = r - REACH_HOLD   # holding: the hold starts over
		return
	var was := _pose()
	t += REACH_HOLD - r   # on its way back: out to the hold again
	_hold_extra = 0.0
	_carry(was)


func step(delta: float) -> void:
	_settle_carries(delta)
	if kind == Kind.NONE:
		return
	var advance := delta * _speed
	if _hold_extra > 0.0:
		var r := _hand_time()
		if r >= REACH_HOLD and r < REACH_BACK:
			var held := minf(_hold_extra, advance)
			_hold_extra -= held
			advance -= held
	t += advance
	if t >= length():
		var was := _pose()
		kind = Kind.NONE
		t = 0.0
		_speed = 1.0
		_hold_extra = 0.0
		_lowered = false
		_carry(was)


## The rest of the gesture four times as fast (a shot needs the weapon).
func hurry() -> void:
	if kind != Kind.NONE:
		_speed = HURRY
	_tail_quick = true


## True while a gesture runs or the weapon is still settling from one.
func active() -> bool:
	return kind != Kind.NONE or _tail > 0.0 or _weapon_off != Vector3.ZERO or _weapon_turn_off != Vector3.ZERO


## The running gesture's length (s).
func length() -> float:
	match kind:
		Kind.JAB:
			return JAB_TIME
		Kind.BASH:
			return float((BASH.back() as Array)[0])
		Kind.SHOVE:
			return float((SHOVE.back() as Array)[0])
		Kind.REACH:
			return REACH_TIME
		Kind.REACH_TWO:
			return TWO_TIME
	return 0.0


## True while the free left fist is out (a jab or a reach).
func shows_fist() -> bool:
	return _raw_shows_fist()


## [shown, position, turn] of the fist view.
func fist() -> Array:
	var raw := _raw_fist()
	if not raw[0]:
		return raw
	return [true, (raw[1] as Vector3) + _fist_off, (raw[2] as Vector3) + _fist_turn_off]


## [offset, turn] the weapon in hand takes for the gesture.
func weapon() -> Array:
	var raw := _raw_weapon()
	return [(raw[0] as Vector3) + _weapon_off, (raw[1] as Vector3) + _weapon_turn_off]


## How far the weapon in hand is lowered out of the frame for the gesture
## (a share of its holster pose).
func weapon_lower() -> float:
	return maxf(_raw_lower(), _tail)


func _raw_shows_fist() -> bool:
	if kind == Kind.JAB or kind == Kind.REACH:
		return true
	return kind == Kind.REACH_TWO and t >= TWO_HAND_AT and t - TWO_HAND_AT < REACH_TIME


func _raw_fist() -> Array:
	if not _raw_shows_fist():
		return [false, JAB_FROM, Vector3.ZERO]
	if kind == Kind.JAB:
		return [true, _jab_at(t), _jab_turn(t)]
	var r := _hand_time()
	return [true, _reach_at(r), _reach_turn(r)]


func _raw_weapon() -> Array:
	match kind:
		Kind.JAB:
			return ViewmodelMotion.keyed(JAB_WEAPON, t)
		Kind.BASH:
			return ViewmodelMotion.keyed(BASH, t)
		Kind.SHOVE:
			return ViewmodelMotion.keyed(SHOVE, t)
		Kind.REACH:
			return ViewmodelMotion.keyed(REACH_WEAPON, t)
	return [Vector3.ZERO, Vector3.ZERO]


func _raw_lower() -> float:
	if kind == Kind.JAB and _lowered:
		return 1.0
	if kind != Kind.REACH_TWO:
		return 0.0
	if t < TWO_DOWN:
		return smoothstep(0.0, TWO_DOWN, t)
	if t < TWO_UP:
		return 1.0
	return 1.0 - smoothstep(TWO_UP, TWO_TIME, t)


## The reaching hand's own time (s into its reach; below 0 before a
## two-handed weapon lets it go).
func _hand_time() -> float:
	return t - TWO_HAND_AT if kind == Kind.REACH_TWO else t


## [fist shown, fist position, fist turn, weapon offset, weapon turn,
## lower] as shown now (carries included).
func _pose() -> Array:
	var f := fist()
	var w := weapon()
	return [f[0], f[1], f[2], w[0], w[1], weapon_lower()]


## After a restart: whatever [param was] shown and the new gesture would
## not show is carried (and dies away from there).
func _carry(was: Array) -> void:
	var f := _raw_fist()
	if was[0] and f[0]:
		_fist_off = (was[1] as Vector3) - (f[1] as Vector3)
		_fist_turn_off = (was[2] as Vector3) - (f[2] as Vector3)
	elif not f[0]:
		_fist_off = Vector3.ZERO
		_fist_off_v = Vector3.ZERO
		_fist_turn_off = Vector3.ZERO
		_fist_turn_off_v = Vector3.ZERO
	var w := _raw_weapon()
	_weapon_off = (was[3] as Vector3) - (w[0] as Vector3)
	_weapon_turn_off = (was[4] as Vector3) - (w[1] as Vector3)
	var lower := float(was[5])
	if lower > _raw_lower() and lower > _tail + 1e-6:
		_tail = lower
		_tail_v = 0.0


func _settle_carries(delta: float) -> void:
	var moved: Array = ViewmodelMotion.follow3(_fist_off, _fist_off_v, Vector3.ZERO, CARRY_OMEGA, delta)
	_fist_off = moved[0]
	_fist_off_v = moved[1]
	moved = ViewmodelMotion.follow3(_fist_turn_off, _fist_turn_off_v, Vector3.ZERO, CARRY_OMEGA, delta)
	_fist_turn_off = moved[0]
	_fist_turn_off_v = moved[1]
	moved = ViewmodelMotion.follow3(_weapon_off, _weapon_off_v, Vector3.ZERO, CARRY_OMEGA, delta)
	_weapon_off = moved[0]
	_weapon_off_v = moved[1]
	moved = ViewmodelMotion.follow3(_weapon_turn_off, _weapon_turn_off_v, Vector3.ZERO, CARRY_OMEGA, delta)
	_weapon_turn_off = moved[0]
	_weapon_turn_off_v = moved[1]
	if _fist_off.length() < CARRY_REST and _fist_off_v.length() < CARRY_REST * 10.0:
		_fist_off = Vector3.ZERO
		_fist_off_v = Vector3.ZERO
	if _fist_turn_off.length() < CARRY_REST and _fist_turn_off_v.length() < CARRY_REST * 10.0:
		_fist_turn_off = Vector3.ZERO
		_fist_turn_off_v = Vector3.ZERO
	if _weapon_off.length() < CARRY_REST and _weapon_off_v.length() < CARRY_REST * 10.0:
		_weapon_off = Vector3.ZERO
		_weapon_off_v = Vector3.ZERO
	if _weapon_turn_off.length() < CARRY_REST and _weapon_turn_off_v.length() < CARRY_REST * 10.0:
		_weapon_turn_off = Vector3.ZERO
		_weapon_turn_off_v = Vector3.ZERO
	if _tail > 0.0:
		var tail := ViewmodelMotion.follow(_tail, _tail_v, 0.0, TAIL_OMEGA * (2.0 if _tail_quick else 1.0), delta)
		_tail = tail.x
		_tail_v = tail.y
		if _tail < CARRY_REST:
			_tail = 0.0
			_tail_v = 0.0
	if _tail <= 0.0 and kind == Kind.NONE:
		_tail_quick = false


## u in 0..1 with smoothstep(0, 1, u) == [param s].
static func _smoothstep_inverse(s: float) -> float:
	return clampf(0.5 - sin(asin(clampf(1.0 - 2.0 * s, -1.0, 1.0)) / 3.0), 0.0, 1.0)


## The jab's fist at [param at] s: cocked, the strike's arc (quick out of
## the cock, slowing into the hit), the follow-through, the low way back.
func _jab_at(at: float) -> Vector3:
	if at < JAB_COCKED_AT:
		return _fist_from.lerp(JAB_COCK if _fist_from == JAB_FROM else _fist_from, smoothstep(0.0, JAB_COCKED_AT, at))
	var cocked := JAB_COCK if _fist_from == JAB_FROM else _fist_from
	if at < JAB_HIT_AT:
		var u := (at - JAB_COCKED_AT) / (JAB_HIT_AT - JAB_COCKED_AT)
		# from a hand already out: a gentle arc straight on toward the hit
		var rise := JAB_RISE if _fist_from == JAB_FROM else _fist_from.lerp(JAB_HIT, 0.5) + Vector3(0.0, 0.03, 0.0)
		return _bezier(cocked, rise, JAB_HIT, u + JAB_SLOWING * u * (1.0 - u))
	if at < JAB_HELD_TO:
		return JAB_HIT + Vector3(0.0, 0.0, -0.012) * ViewmodelMotion.bump(at, JAB_HIT_AT, JAB_HELD_TO)
	var back := smoothstep(JAB_HELD_TO, JAB_TIME, at)
	return _bezier(JAB_HIT, JAB_BACK, JAB_FROM, back)


## The jab's fist turned toward the middle as it drives in (the rig rolls
## it into the blow by how far out it is).
func _jab_turn(at: float) -> Vector3:
	var drive := smoothstep(JAB_COCKED_AT, JAB_HIT_AT, at) * (1.0 - smoothstep(JAB_HELD_TO, JAB_TIME, at))
	return Vector3(0.08, 0.16, 0.0) * drive


func _reach_at(at: float) -> Vector3:
	if at < REACH_HOLD:
		return _bezier(REACH_FROM, REACH_OUT, REACH_AT, smoothstep(0.0, REACH_HOLD, at))
	if at < REACH_BACK:
		return REACH_AT + Vector3(0.0, 0.0, -0.012) * ViewmodelMotion.bump(at, REACH_HOLD, REACH_BACK)
	return _bezier(REACH_AT, REACH_IN, REACH_FROM, smoothstep(REACH_BACK, REACH_TIME, at))


## The reaching hand: turned in toward the middle on the way out, the
## wrist turning over as it takes hold, unwinding on the way back.
func _reach_turn(at: float) -> Vector3:
	var out := smoothstep(0.0, REACH_HOLD, at) * (1.0 - smoothstep(REACH_BACK, REACH_TIME, at))
	var twist := smoothstep(REACH_HOLD, REACH_BACK, at) * (1.0 - smoothstep(REACH_BACK, REACH_TIME, at))
	return Vector3(0.12 * out, 0.12 * out, -0.25 * out - 0.35 * twist)


static func _bezier(a: Vector3, control: Vector3, b: Vector3, u: float) -> Vector3:
	var v := 1.0 - u
	return a * (v * v) + control * (2.0 * v * u) + b * (u * u)
