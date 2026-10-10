class_name MotionClip
extends RefCounted
## Keyframed motion for code-driven rigs (the guardians' pattern, see
## docs/superpowers/plans/2026-10-03-straznik-kolos.md): named channels of
## float keys, each key reached along its own easing curve from the key
## before it. A move is written as data -
## [codeblock]
## clip.key(&"raise", 0.0, 0.0).key(&"raise", 0.7, 1.0, MotionClip.IN_OUT)
## [/codeblock]
## - and sampled at any time (before the first key: its value; after the
## last: its value). The guardians sample their clips in stage-normalised
## time (0..1 telegraph, 1..2 strike, 2..3 recovery), so a phase that
## shortens a telegraph keeps the shape of the move.

enum Ease { LINEAR, IN, OUT, IN_OUT, OUT_BACK, HOLD }

## Steady (a sweep at constant speed).
const LINEAR := Ease.LINEAR
## Accelerating (a fall, a strike coming down).
const IN := Ease.IN
## Decelerating (a lift coming to rest).
const OUT := Ease.OUT
## Smooth both ends (most moves).
const IN_OUT := Ease.IN_OUT
## Overshoots the key and settles back (weight arriving).
const OUT_BACK := Ease.OUT_BACK
## Keeps the previous value until the key's time, then jumps.
const HOLD := Ease.HOLD

## Overshoot of OUT_BACK (the classic 1.70158: about 10 %).
const BACK := 1.70158

## Channel -> Array of [time, value, ease], sorted by time.
var _channels: Dictionary = {}
var _duration: float = 0.0


## Adds a key to [param channel]; returns the clip (for chaining).
func key(channel: StringName, time: float, value: float, curve: Ease = Ease.IN_OUT) -> MotionClip:
	var keys: Array = _channels.get(channel, [])
	var at := keys.size()
	for i in keys.size():
		if float(keys[i][0]) > time:
			at = i
			break
	keys.insert(at, [time, value, curve])
	_channels[channel] = keys
	_duration = maxf(_duration, time)
	return self


## True when the clip has keys for [param channel].
func has(channel: StringName) -> bool:
	return _channels.has(channel)


## Time of the last key of any channel.
func duration() -> float:
	return _duration


## The value of [param channel] at [param time] ([param fallback] for a
## channel without keys).
func sample(channel: StringName, time: float, fallback: float = 0.0) -> float:
	var keys: Array = _channels.get(channel, [])
	if keys.is_empty():
		return fallback
	if time <= float(keys[0][0]):
		return float(keys[0][1])
	for i in range(1, keys.size()):
		var next: Array = keys[i]
		if time < float(next[0]):
			var previous: Array = keys[i - 1]
			var span := float(next[0]) - float(previous[0])
			var x := (time - float(previous[0])) / span if span > 0.0 else 1.0
			return lerpf(float(previous[1]), float(next[1]), eased(next[2], x))
	return float(keys[keys.size() - 1][1])


## [param x] (0..1) through curve [param kind].
static func eased(kind: Ease, x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	match kind:
		Ease.IN:
			return x * x * x
		Ease.OUT:
			var inverse := 1.0 - x
			return 1.0 - inverse * inverse * inverse
		Ease.IN_OUT:
			if x < 0.5:
				return 4.0 * x * x * x
			var tail := -2.0 * x + 2.0
			return 1.0 - tail * tail * tail * 0.5
		Ease.OUT_BACK:
			var t := x - 1.0
			return 1.0 + (BACK + 1.0) * t * t * t + BACK * t * t
		Ease.HOLD:
			return 1.0 if x >= 1.0 else 0.0
	return x
