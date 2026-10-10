class_name OrreryMoves
extends RefCounted
## The Great Orrery's choreography: from the brain's state, the tiers'
## drives (OrreryDrive, set by the Planetarium) and its springs it composes
## the Pose its rig shows. Clockwork with weight:
## - gear backlash: a tier lags behind its drive while it speeds up and
##   swings past when it stops, then settles (a spring on the spin);
## - the brass rocks on its bearings when a tier heaves, shudders when its
##   surge is coming, jolts when a planet leaves it;
## - the hanging moons are pendulums: they trail a tier that speeds up,
##   swing past one that stops, lean out (a little) when it races;
## - every planet spins on its own axis (Earth's Moon circles her, Saturn's
##   rings rock); a hit jolts a planet on its rod; a planet about to fly
##   spins up, glows, trembles;
## - the sun's petals open on springs, each a beat after the last, a notch
##   wider every phase, wide when it gathers a flare, fully when bared;
## - the light pulses with the gears' beat (faster each phase): the core,
##   the planets' heat (the weak points breathe), the petals.
## Sampled from the brain's clip_time() / state_progress(), like the
## Colossus's moves (docs/superpowers/plans/2026-10-03-straznik-kolos.md).

const S := OrreryBrain.State
const A := OrreryBrain.Attack
const ST := OrreryBrain.Stage
const G := preload("res://src/game/floor1/guardians/orrery_geometry.gd")

## The petals' opening per level (rad): shut, ajar, wider, bloomed.
const PETALS: Array[float] = [0.0, 0.35, 0.55, G.PETAL_OPEN]
## The gears' beat per level (Hz).
const BEAT: Array[float] = [1.1, 1.4, 1.7, 2.1]
## How far a tier lags its drive per rad/s² it speeds up by (rad).
const LAG := 0.035
## How far it rocks per rad/s² (roll, pitch; rad).
const ROCK := Vector2(0.007, -0.004)
## Each planet's own spin (rad/s): Mercury .. Saturn (Venus turns back).
const SPINS: Array[float] = [0.7, -0.3, 1.1, 1.0, 2.0, 1.6]
const EARTH_MOON_SPEED := 0.8
## The moons' pendulums: how far they may trail, how far lean out (rad).
const SWING_MAX := 0.35
const OUTWARD_MAX := 0.1
const GRAVITY := 9.8
## The planets' glow: at rest, its beat, about to fly, flying.
const PLANET_GLOW := Vector4(0.14, 0.08, 1.0, 0.75)

var rig: OrreryRig
var pose := OrreryRig.Pose.new()
var time: float = 0.0
## The tiers' drives (the Planetarium's).
var drives: Array[OrreryDrive] = []
## The planet readied for a launch (its warning), and how far (0..1).
var charging_planet: int = -1
var charge: float = 0.0
## Which planets fly now (the fight's).
var flying: Array[bool] = [false, false, false, false, false, false]

var _lag: Array[Spring] = []
var _roll: Array[Spring] = []
var _pitch: Array[Spring] = []
var _jolt: Array = []
var _swing: Array[Spring] = []
var _lean: Array[Spring] = []
var _petal: Array[Spring] = []
var _sun := Spring.new(1.8, 0.45)
var _spin: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _earth_moon: float = 0.0
var _beat: float = 0.0
var _noise := FastNoiseLite.new()
var _wake: MotionClip
var _clunked := false
var _flare_burst: float = 0.0


func _init(for_rig: OrreryRig, for_drives: Array[OrreryDrive]) -> void:
	rig = for_rig
	drives = for_drives
	_noise.seed = 9
	_noise.frequency = 1.0
	for t in 3:
		_lag.append(Spring.new(1.4, 0.3))
		_roll.append(Spring.new(2.2, 0.22))
		_pitch.append(Spring.new(2.6, 0.25))
	for k in 6:
		_jolt.append([Spring.new(3.0, 0.22), Spring.new(3.0, 0.22), Spring.new(3.0, 0.22)])
		_petal.append(Spring.new(1.5 + 0.09 * k, 0.32))
	for m in G.moon_count():
		# a rod of ~1.45 m swings at ~0.42 Hz
		_swing.append(Spring.new(0.42, 0.1))
		_lean.append(Spring.new(0.42, 0.25))
	_build_clips()


## The pose for [param brain]'s moment, advanced by [param delta].
func compose(brain: OrreryBrain, delta: float) -> OrreryRig.Pose:
	time += delta
	var p := pose
	if brain.state == S.DORMANT:
		_still()
		return p
	var level := brain.level()
	var waking := brain.state == S.WAKING
	var progress := brain.state_progress()
	p.awake = clampf(progress / 0.3, 0.0, 1.0) if waking else 1.0
	_beat = fmod(_beat + BEAT[level] * delta, 1.0)
	var pulse := pow(0.5 + 0.5 * cos(TAU * _beat), 3.0)
	if waking and not _clunked and progress >= 0.04:
		_clunked = true
		clunk(1.0)
	_tiers(brain, delta)
	_moons(delta)
	_planets(brain, delta, pulse, waking, progress)
	_petals_and_sun(brain, delta, pulse, waking, progress)
	_lamps(brain, waking, progress)
	return p


## Every tier jolts (gears catching, a phase's brake, the seize).
func clunk(strength: float) -> void:
	for t in 3:
		_roll[t].kick(0.05 * strength * (1.0 if t % 2 == 0 else -1.0))
		_pitch[t].kick(-0.04 * strength)
		_lag[t].kick(-0.06 * strength)


## Planet [param planet] took a hit travelling [param direction] (its
## tier's space): it jolts on its rod.
func hit_planet(planet: int, direction: Vector3, strength: float = 1.0) -> void:
	var push := direction.normalized() * 0.9 * clampf(strength, 0.3, 2.0)
	for i in 3:
		(_jolt[planet][i] as Spring).kick(push[i])


## A planet left tier [param tier] (or slammed back into its socket): the
## arm bounces.
func recoil(tier: int, strength: float = 1.0) -> void:
	_roll[tier].kick(0.06 * strength)
	_pitch[tier].kick(0.05 * strength)


## The sun threw its flares: the petals snap open a little more, the core
## flashes.
func flare_burst() -> void:
	_flare_burst = 1.0
	_sun.kick(4.0)
	for k in 6:
		_petal[k].kick(0.9)


## At rest again (the guard fled): springs still.
func reset() -> void:
	_clunked = false
	charging_planet = -1
	charge = 0.0
	_flare_burst = 0.0
	for s: Spring in _lag + _roll + _pitch + _swing + _lean + _petal:
		s.reset(0.0)
	for springs: Array in _jolt:
		for s: Spring in springs:
			s.reset(0.0)
	_sun.reset(0.0)
	for k in 6:
		_spin[k] = 0.0
		flying[k] = false
	_earth_moon = 0.0
	_still()


# --- parts -------------------------------------------------------------------------

## The museum piece: everything at rest where the drives stand.
func _still() -> void:
	var p := pose
	p.awake = 0.0
	p.sun = 0.0
	p.earth_moon = 0.0
	p.rings = Vector2.ZERO
	for t in 3:
		p.tier_yaw[t] = drives[t].angle if t < drives.size() else 0.0
		p.tier_rock[t] = Vector2.ZERO
		p.tier_glow[t] = 0.0
		p.lamps[t] = 0.0
	for k in 6:
		p.planet_spin[k] = _spin[k]
		p.planet_glow[k] = 0.0
		p.planet_jolt[k] = Vector3.ZERO
		p.petals[k] = 0.0
	for m in p.moon_swing.size():
		p.moon_swing[m] = Vector2.ZERO


func _tiers(brain: OrreryBrain, delta: float) -> void:
	var p := pose
	var shudder_tier := -1
	var shudder := 0.0
	if brain.state == S.ATTACK and brain.attack == A.SURGE and brain.stage == ST.TELEGRAPH:
		shudder_tier = brain.surge_tier
		shudder = 0.016 * clampf(brain.clip_time(), 0.0, 1.0)
	var shifting := (brain.state == S.SHIFT or brain.state == S.UNVEIL)
	for t in 3:
		var drive := drives[t]
		var lag := _lag[t].step(-LAG * drive.acceleration, delta)
		p.tier_yaw[t] = drive.angle + lag
		var tremble := Vector2.ZERO
		if t == shudder_tier or shifting:
			var amount := shudder if t == shudder_tier else 0.008
			tremble = Vector2(_noise.get_noise_2d(time * 40.0, t * 10.0), _noise.get_noise_2d(t * 10.0, time * 40.0)) * amount
		p.tier_rock[t] = Vector2(_roll[t].step(ROCK.x * drive.acceleration, delta), _pitch[t].step(ROCK.y * drive.acceleration, delta)) + tremble


func _moons(delta: float) -> void:
	var p := pose
	var drive := drives[G.HIGH]
	for m in p.moon_swing.size():
		var radius := G.MOON_RADII[m % G.MOON_RADII.size()]
		var trail := clampf(-atan(drive.acceleration * radius / GRAVITY), -SWING_MAX, SWING_MAX)
		var lean := clampf(atan(drive.speed * drive.speed * radius / GRAVITY), 0.0, OUTWARD_MAX)
		# a breath of air keeps them from hanging dead still
		trail += 0.012 * sin(time * 2.6 + m * 1.7)
		p.moon_swing[m] = Vector2(_swing[m].step(trail, delta), _lean[m].step(lean, delta))


func _planets(brain: OrreryBrain, delta: float, pulse: float, waking: bool, progress: float) -> void:
	var p := pose
	var speed_up := 1.0 + 0.15 * brain.level()
	for k in 6:
		var rate := SPINS[k] * speed_up
		if k == charging_planet:
			rate *= 1.0 + 2.5 * charge
		_spin[k] = wrapf(_spin[k] + rate * delta, -PI, PI)
		p.planet_spin[k] = _spin[k]
		var jolt := Vector3((_jolt[k][0] as Spring).step(0.0, delta), (_jolt[k][1] as Spring).step(0.0, delta), (_jolt[k][2] as Spring).step(0.0, delta))
		var glow := PLANET_GLOW.x + PLANET_GLOW.y * pulse
		if waking:
			# they light up one by one, each with a flare
			var lit := clampf((progress - 0.3 - 0.08 * k) / 0.06, 0.0, 1.0)
			glow = lit * (glow + 0.6 * clampf(1.0 - (progress - 0.36 - 0.08 * k) / 0.15, 0.0, 1.0))
		if k == charging_planet:
			glow = lerpf(glow, PLANET_GLOW.z, charge)
			jolt += Vector3(_noise.get_noise_2d(time * 50.0, k * 7.0), 0.0, _noise.get_noise_2d(k * 7.0, time * 50.0)) * 0.03 * charge
		elif flying[k]:
			glow = PLANET_GLOW.w + 0.2 * pulse
		p.planet_glow[k] = glow
		p.planet_jolt[k] = jolt
	_earth_moon = wrapf(_earth_moon + EARTH_MOON_SPEED * speed_up * delta, -PI, PI)
	p.earth_moon = _earth_moon
	p.rings = Vector2(0.05 * sin(time * 1.3), 0.04 * cos(time * 0.9)) + Vector2(p.planet_jolt[5].x, p.planet_jolt[5].z) * 0.6


func _petals_and_sun(brain: OrreryBrain, delta: float, pulse: float, waking: bool, progress: float) -> void:
	var p := pose
	var level := brain.level()
	var base := PETALS[level]
	var sun := 0.35 + 0.15 * pulse
	var extra := 0.0
	match brain.state:
		S.WAKING:
			base = 0.0
			extra = _wake.sample(&"petals", progress)
			sun = _wake.sample(&"sun", progress) + 0.1 * pulse * progress
		S.SHIFT:
			# old opening while it brakes, then the new notch
			if progress < OrreryBrain.SHIFT_BRAKE:
				base = PETALS[clampi(level - 1, 0, 3)]
				sun = 0.2 + 0.1 * pulse
			else:
				sun = 1.4 * clampf(1.0 - (progress - OrreryBrain.SHIFT_BRAKE) / 0.35, 0.0, 1.0) + 0.5 + 0.2 * pulse
		S.UNVEIL:
			if progress < OrreryBrain.UNVEIL_BRAKE:
				base = PETALS[2] + 0.06 * sin(time * 30.0) * progress
				sun = 0.6 + 1.2 * progress
			else:
				sun = 2.2 - 0.8 * clampf((progress - OrreryBrain.UNVEIL_BRAKE) / 0.5, 0.0, 1.0)
		S.ATTACK:
			if brain.attack == A.FLARE:
				var t := brain.clip_time()
				if t < 1.0:
					extra = 0.42 * MotionClip.eased(MotionClip.IN_OUT, t)
					sun += 1.3 * MotionClip.eased(MotionClip.IN, t)
				elif t < 2.0:
					extra = 0.42 * (1.0 - MotionClip.eased(MotionClip.IN_OUT, t - 1.0))
	if level >= 1 and brain.state != S.WAKING:
		sun += 0.25 + (0.6 if brain.exposed else 0.0)
	_flare_burst = move_toward(_flare_burst, 0.0, 2.5 * delta)
	sun += 1.2 * _flare_burst
	var breath := 0.05 * pulse if not waking else 0.0
	for k in 6:
		var target := base + extra + breath * (1.0 + 0.3 * sin(k * 1.9))
		p.petals[k] = clampf(_petal[k].step(target, delta), -0.05, G.PETAL_OPEN + 0.2)
	p.sun = maxf(_sun.step(sun, delta), 0.0) * (1.0 + 0.05 * _noise.get_noise_1d(time * 20.0))


func _lamps(brain: OrreryBrain, waking: bool, progress: float) -> void:
	var p := pose
	for t in 3:
		p.lamps[t] = 0.0
		p.tier_glow[t] = 0.0
	if waking:
		# a lamp test as it comes to: low, middle, high
		for t in 3:
			var at := 0.1 + 0.08 * t
			p.lamps[t] = 1.0 if progress > at and progress < at + 0.07 else 0.0
		return
	match brain.state:
		S.SHIFT, S.UNVEIL:
			var brake := OrreryBrain.SHIFT_BRAKE if brain.state == S.SHIFT else OrreryBrain.UNVEIL_BRAKE
			var progress_ := brain.state_progress()
			for t in 3:
				if progress_ < brake:
					p.lamps[t] = 1.0 if fmod(time * 2.5 - t / 3.0 + 3.0, 1.0) < 0.5 else 0.15
				else:
					p.lamps[t] = clampf(1.0 - (progress_ - brake) / 0.4, 0.0, 1.0)
				p.tier_glow[t] = 0.35 * p.lamps[t]
		S.ATTACK:
			var t := brain.clip_time()
			match brain.attack:
				A.SURGE:
					var tier := brain.surge_tier
					if t < 1.0:
						# flickers on, then burns: the warning
						var blink := 1.0 if t > 0.3 or fmod(time * 14.0, 1.0) < 0.6 else 0.2
						p.lamps[tier] = blink * clampf(t / 0.12, 0.0, 1.0)
						p.tier_glow[tier] = 0.8 * MotionClip.eased(MotionClip.IN, t)
					elif t < 2.0:
						p.lamps[tier] = 1.0
						p.tier_glow[tier] = 0.55
					else:
						p.lamps[tier] = clampf(3.0 - t, 0.0, 1.0)
						p.tier_glow[tier] = 0.55 * clampf(3.0 - t, 0.0, 1.0)
				A.LAUNCH:
					if brain.launch_planet >= 0 and t < 1.2:
						p.lamps[G.planet_tier(brain.launch_planet)] = 0.6 * clampf(t / 0.2, 0.0, 1.0)


func _build_clips() -> void:
	var O := MotionClip.OUT
	var IO := MotionClip.IN_OUT
	# waking: a breath of light through the petals, the core flares, settles
	_wake = MotionClip.new()
	_wake.key(&"petals", 0.0, 0.0).key(&"petals", 0.15, 0.0, MotionClip.HOLD).key(&"petals", 0.36, 0.2, O).key(&"petals", 0.62, 0.0, IO)
	_wake.key(&"sun", 0.0, 0.0).key(&"sun", 0.14, 0.0, MotionClip.HOLD).key(&"sun", 0.22, 1.5, O).key(&"sun", 0.55, 0.35, IO)
