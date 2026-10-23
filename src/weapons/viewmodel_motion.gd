class_name ViewmodelMotion
## How each first-person weapon moves as a whole (plan
## 2026-10-21-animacje-fpp): its grip class (a handgun in one hand, a long
## gun in two, a heavy piece carried low), how quickly it is put away and
## drawn (WeaponSwitch: a handgun is out and up in a third of a second, the
## gatling takes twice that), and the poses WeaponHolder lays over its rest:
## put away (the holster pose at "lower" 1), carried on the run, pulled
## back from a wall (WallProbe). Poses are [offset (m), turn (rad: pitch,
## yaw, roll)] in the holder's space, added to the weapon's rest like the
## other layers. keyed() eases between keyed poses for the gestures.

enum Grip { ONE_HAND, LONG, HEAVY }

## Per weapon: its grip class, seconds to put it away (out of the frame)
## and to draw it (settled), and the draw's damping (below 1 it comes up a
## touch past its rest and settles: a light piece bounces, a heavy one
## sinks into the hands).
const HANDLING := {
	&"taser": {"grip": Grip.ONE_HAND, "holster": 0.11, "draw": 0.24, "damping": 0.68},
	&"pistol": {"grip": Grip.ONE_HAND, "holster": 0.11, "draw": 0.24, "damping": 0.68},
	&"flare": {"grip": Grip.ONE_HAND, "holster": 0.12, "draw": 0.26, "damping": 0.7},
	&"shotgun": {"grip": Grip.LONG, "holster": 0.14, "draw": 0.3, "damping": 0.76},
	&"rifle_hunt": {"grip": Grip.LONG, "holster": 0.15, "draw": 0.36, "damping": 0.78},
	&"harpoon": {"grip": Grip.LONG, "holster": 0.15, "draw": 0.37, "damping": 0.78},
	&"hwacha": {"grip": Grip.HEAVY, "holster": 0.17, "draw": 0.38, "damping": 0.84},
	&"gatling": {"grip": Grip.HEAVY, "holster": 0.19, "draw": 0.42, "damping": 0.88},
}
const LIGHT := {"grip": Grip.ONE_HAND, "holster": 0.11, "draw": 0.24, "damping": 0.7}

## Put away (lower = 1): down out of the frame, the muzzle tipped down and
## rolled away; a long gun swings across, a heavy one sinks. (Measured:
## from WeaponSwitch.HIDE_AT on, every vertex of every model is under the
## plane of the frame's bottom edge; a handgun tipped further would show
## its slide's top.)
const HOLSTER := {
	Grip.ONE_HAND: [Vector3(0.04, -0.36, 0.04), Vector3(-0.35, 0.15, 0.5)],
	Grip.LONG: [Vector3(0.04, -0.34, 0.08), Vector3(-0.6, 0.2, 0.4)],
	Grip.HEAVY: [Vector3(0.02, -0.38, 0.08), Vector3(-0.5, 0.1, 0.3)],
}
## Carried on the run (full sprint): a handgun pulled in low and canted,
## a long gun across the body ("port arms"), a heavy piece low at the hip;
## and how hard each one rocks with the stride (rad). (Seen in the window:
## tipped about the hand, a handgun's slide rises into the middle of the
## frame - so it is carried well down and not pulled toward the eye.)
const SPRINT := {
	Grip.ONE_HAND: [Vector3(-0.03, -0.12, 0.0), Vector3(-0.22, 0.26, 0.4)],
	Grip.LONG: [Vector3(-0.03, -0.07, 0.05), Vector3(-0.12, 0.45, 0.42)],
	Grip.HEAVY: [Vector3(0.0, -0.09, 0.06), Vector3(-0.3, 0.12, 0.18)],
}
const SPRINT_SWING := {Grip.ONE_HAND: 0.05, Grip.LONG: 0.06, Grip.HEAVY: 0.08}
## Up against a wall (pull 1): back toward the chest, muzzle down and in.
const WALL := {
	Grip.ONE_HAND: [Vector3(-0.01, -0.03, 0.09), Vector3(-0.22, 0.12, 0.1)],
	Grip.LONG: [Vector3(0.0, -0.05, 0.14), Vector3(-0.28, 0.18, 0.12)],
	Grip.HEAVY: [Vector3(0.0, -0.06, 0.12), Vector3(-0.25, 0.1, 0.08)],
}
## A wall nearer than this (m, along the view) starts pulling the weapon
## back (its muzzle would be drawn over it); WallProbe.FULL_AT is as near
## as the guard ever gets.
const WALL_START := {Grip.ONE_HAND: 0.72, Grip.LONG: 0.9, Grip.HEAVY: 0.95}


static func handling(id: StringName) -> Dictionary:
	return HANDLING.get(id, LIGHT)


static func grip_of(id: StringName) -> int:
	return handling(id)["grip"]


static func holster_time(id: StringName) -> float:
	return handling(id)["holster"]


static func draw_time(id: StringName) -> float:
	return handling(id)["draw"]


static func draw_damping(id: StringName) -> float:
	return handling(id)["damping"]


static func holster_pose(grip: int) -> Array:
	return HOLSTER[grip]


static func sprint_pose(grip: int) -> Array:
	return SPRINT[grip]


static func wall_pose(grip: int) -> Array:
	return WALL[grip]


static func wall_start(grip: int) -> float:
	return WALL_START[grip]


## [offset, turn] at [param t] of [param keys] ([t, offset, turn] each, in
## order of t): each key held, eased in and out of it (smoothstep), the
## first before the first key and the last after the last.
static func keyed(keys: Array, t: float) -> Array:
	if keys.is_empty():
		return [Vector3.ZERO, Vector3.ZERO]
	var first: Array = keys[0]
	if t <= float(first[0]):
		return [first[1], first[2]]
	for i in range(1, keys.size()):
		var b: Array = keys[i]
		if t <= float(b[0]):
			var a: Array = keys[i - 1]
			var span := float(b[0]) - float(a[0])
			var u := smoothstep(0.0, 1.0, (t - float(a[0])) / span) if span > 0.0 else 1.0
			return [(a[1] as Vector3).lerp(b[1], u), (a[2] as Vector3).lerp(b[2], u)]
	var last: Array = keys[keys.size() - 1]
	return [last[1], last[2]]


## One step of [param delta] s of a critically damped spring pulling
## [param value] (moving at [param velocity]) toward [param target] at
## [param omega] (1/s; settled to 5 % in about 4.7 / omega s): unlike an
## exponential ease it starts from its own velocity, so a new target (a run
## ended, a reload cut short) never snaps the first frame. Returns
## Vector2(value, velocity). Exact for any step.
static func follow(value: float, velocity: float, target: float, omega: float, delta: float) -> Vector2:
	var x := value - target
	var push := (velocity + omega * x) * delta
	var decay := exp(-omega * delta)
	return Vector2(target + (x + push) * decay, (velocity - omega * push) * decay)


## follow() for a Vector3: [value, velocity].
static func follow3(value: Vector3, velocity: Vector3, target: Vector3, omega: float, delta: float) -> Array:
	var x := value - target
	var push := (velocity + x * omega) * delta
	var decay := exp(-omega * delta)
	return [target + (x + push) * decay, (velocity - push * omega) * decay]


## A smooth bump 0 -> 1 -> 0 as [param t] runs from [param from] to
## [param to] (0 outside): a jolt that starts and ends at rest.
static func bump(t: float, from: float, to: float) -> float:
	if t <= from or t >= to:
		return 0.0
	return sin(PI * (t - from) / (to - from))
