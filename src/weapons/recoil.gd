class_name Recoil
extends RefCounted
## A kick on a few channels (a weapon's back, rise, muzzle climb...; the
## camera's pitch and yaw; the guard's landing dip), each a damped spring
## always pulled back to 0: a shot jolts it, it comes back and settles by
## itself, so nothing ever drifts. kick() takes the peak a channel should
## reach from rest (m or degrees, whatever the channel holds) and gives it
## the speed that gets it there with the spring's tuning; kicks fired while
## it is still out add up (a burst climbs), limit() keeps a channel within
## a bound. The spring is stepped by its exact solution, so a kick peaks
## where it was asked to at any frame rate (a stepped spring would lose a
## third of a sharp kick to damping in its first step).

## How quickly a channel comes back (Hz) and how much it swings past rest
## on the way (1 = not at all, 0.5 = a heavy gun's bounce).
var frequency: float = 8.0
var damping: float = 0.8
var values := PackedFloat64Array()
var velocities := PackedFloat64Array()


func _init(channels: int = 1, frequency_hz: float = 8.0, damping_ratio: float = 0.8) -> void:
	values.resize(channels)
	velocities.resize(channels)
	tune(frequency_hz, damping_ratio)


## The spring of every channel (see [member frequency], [member damping]).
func tune(frequency_hz: float, damping_ratio: float) -> void:
	frequency = maxf(frequency_hz, 0.1)
	damping = clampf(damping_ratio, 0.05, 2.0)


func channels() -> int:
	return values.size()


## Jolts [param channel] so that, from rest, it peaks at [param peak].
func kick(channel: int, peak: float) -> void:
	if channel < 0 or channel >= values.size() or peak == 0.0:
		return
	velocities[channel] += peak * TAU * frequency / peak_factor(damping)


func step(delta: float) -> void:
	if delta <= 0.0:
		return
	var omega := TAU * frequency
	for i in values.size():
		var moved := _advance(values[i], velocities[i], omega, damping, delta)
		values[i] = moved.x
		velocities[i] = moved.y


func value(channel: int) -> float:
	return values[channel] if channel >= 0 and channel < values.size() else 0.0


## Keeps [param channel] within +/- [param bound] (a burst climbs only so
## far): at the bound it stops going further out.
func limit(channel: int, bound: float) -> void:
	if channel < 0 or channel >= values.size() or bound <= 0.0:
		return
	if absf(values[channel]) > bound:
		values[channel] = signf(values[channel]) * bound
		if signf(velocities[channel]) == signf(values[channel]):
			velocities[channel] = 0.0


## True when every channel is back at rest (within [param epsilon]).
func resting(epsilon: float = 1e-4) -> bool:
	for i in values.size():
		if absf(values[i]) > epsilon or absf(velocities[i]) > epsilon * 10.0:
			return false
	return true


func reset() -> void:
	values.fill(0.0)
	velocities.fill(0.0)


## Position and speed (x, y) of a spring at [param x] moving at [param v]
## after [param dt] seconds (angular frequency [param omega], damping ratio
## [param zeta], resting at 0): the exact solution.
static func _advance(x: float, v: float, omega: float, zeta: float, dt: float) -> Vector2:
	if absf(zeta - 1.0) < 1e-3:
		var fall := exp(-omega * dt)
		var b := v + omega * x
		return Vector2(fall * (x + b * dt), fall * (v - omega * b * dt))
	if zeta < 1.0:
		var wd := omega * sqrt(1.0 - zeta * zeta)
		var fall := exp(-zeta * omega * dt)
		var c := cos(wd * dt)
		var s := sin(wd * dt)
		var b := (v + zeta * omega * x) / wd
		return Vector2(fall * (x * c + b * s), fall * (v * c - (zeta * omega * b + wd * x) * s))
	var root := sqrt(zeta * zeta - 1.0)
	var r1 := omega * (-zeta + root)
	var r2 := omega * (-zeta - root)
	var c1 := (v - r2 * x) / (r1 - r2)
	var c2 := x - c1
	var e1 := exp(r1 * dt)
	var e2 := exp(r2 * dt)
	return Vector2(c1 * e1 + c2 * e2, r1 * c1 * e1 + r2 * c2 * e2)


## Peak of a spring kicked from rest, as a share of (start speed / omega),
## for damping ratio [param zeta]: 1/e when critically damped, more when it
## bounces, less when it is overdamped.
static func peak_factor(zeta: float) -> float:
	var z := clampf(zeta, 0.05, 2.0)
	if absf(z - 1.0) < 1e-3:
		return exp(-1.0)
	if z < 1.0:
		var root := sqrt(1.0 - z * z)
		return exp(-z / root * atan2(root, z))
	var s := sqrt(z * z - 1.0)
	var r1 := -z + s
	var r2 := -z - s
	var t := log(r2 / r1) / (r1 - r2)
	return (exp(r1 * t) - exp(r2 * t)) / (2.0 * s)
