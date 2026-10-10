class_name TRexBrain
extends RefCounted
## The T-Rex boss as pure logic: states, phases, attack choice, cooldowns
## and the damage rule. The TRex node feeds it the guard's flat distance and
## bearing every physics frame, reports charge impacts and taser hits, and
## acts on its states and signals.
##
## DORMANT -(wake)-> WAKING -> STALK. From STALK: TAIL_WINDUP -> TAIL_SWIPE,
## CHARGE_WINDUP -> CHARGE -> STUNNED (wall) | SKID | CHARGE_WINDUP (the
## second charge of phase 3), ROAR. STAGGER (taser on the crystal) breaks
## anything but a stun; DEAD is final.

signal state_changed(from: State, to: State)
signal phase_changed(phase: int)
## The loud moment of a roar: call exhibits and/or bring down the ceiling.
signal roar_peak(summon: bool, debris: bool)
## A tail swipe starts: the whip sweeps and hits for TAIL_HIT_TIME.
signal tail_strike
## A charge starts running; its direction is locked now.
signal charge_started

enum State { DORMANT, WAKING, STALK, CHARGE_WINDUP, CHARGE, SKID, STUNNED, TAIL_WINDUP, TAIL_SWIPE, ROAR, STAGGER, DEAD }
enum Zone { CRYSTAL, BONE }

const WAKE_TIME := 3.0
## First charge windup; the second charge of phase 3 winds up faster.
const CHARGE_WINDUP_TIME := 1.0
const FOLLOWUP_WINDUP_TIME := 0.7
## The windup only counts down while facing the guard this closely (rad).
const CHARGE_AIM_TOLERANCE := 0.44
## A charge may begin when the guard is within this bearing (rad).
const CHARGE_START_ARC := 1.05
## For the last part of the windup the aim no longer follows the guard.
const CHARGE_LOCK_TIME := 0.4
## A windup that never lines up is dropped after this long.
const CHARGE_WINDUP_GIVE_UP := 3.5
const CHARGE_SPEED := 14.0
## A charge runs this far past the guard's distance at its start.
const CHARGE_OVERSHOOT := 7.0
const CHARGE_MIN_TIME := 0.6
const CHARGE_MAX_TIME := 2.6
const CHARGE_MAX_RANGE := 32.0
const STUN_TIME := 2.5
const SKID_TIME := 0.9
## It whips at a guard behind it (bearing beyond TAIL_REAR_ANGLE, about 135
## degrees) within TAIL_RANGE: where the real tail reaches as it sweeps
## (about 3.5 to 6 m out, within 35-40 degrees of straight back; closer in
## it passes overhead). A guard further aside makes it turn instead.
const TAIL_RANGE := 6.0
const TAIL_REAR_ANGLE := 2.36
## The telegraph: the tail swings away before the whip. Long enough to get
## out of the tail's band in any direction by walking (0.3 s reaction); a
## late reaction needs a sprint or a dash (see test_trex.gd).
const TAIL_WINDUP_TIME := 0.75
const TAIL_SWIPE_TIME := 0.8
## The whip is dangerous from the start of the swipe until this long into
## it; by then the tail has swept through and only swings out.
const TAIL_HIT_TIME := 0.25
const TAIL_COOLDOWN := 2.5
const ROAR_TIME := 1.6
const ROAR_PEAK_AT := 0.5
const SUMMON_INTERVAL := 20.0
## Next try when the hall is already full of summoned exhibits.
const SUMMON_RETRY := 5.0
const DEBRIS_INTERVAL := 10.0
const STAGGER_TIME := 1.0
const STAGGER_COOLDOWN := 8.0
## A guard this close in front makes the charge come sooner (2x).
const CLOSE_RANGE := 6.0
const FIRST_CHARGE_DELAY := 3.0
const PHASE_2_AT := 0.66
const PHASE_3_AT := 0.33
## Per phase (index = phase - 1).
const CHARGE_COOLDOWNS: Array[float] = [9.0, 6.0, 6.5]
const WALK_SPEEDS: Array[float] = [3.5, 4.5, 4.5]
const TURN_SPEEDS: Array[float] = [1.3, 1.7, 1.7]
const CHARGE_TURN_SPEED := 2.6
const CRYSTAL_STUNNED_MULTIPLIER := 1.5
const BONE_MULTIPLIER := 0.1

var state: State = State.DORMANT
var phase: int = 1
## Set by the boss: false while its summoned exhibits fill the hall.
var can_summon: bool = true
## A phase change roar waits for the next free moment.
var pending_phase_roar: bool = false
## Length of the current charge run (s).
var charge_time: float = 0.0
var charge_cooldown: float = FIRST_CHARGE_DELAY
var tail_cooldown: float = 0.0
var summon_cooldown: float = 0.0
var debris_cooldown: float = 0.0
var stagger_cooldown: float = 0.0
## What the current roar does.
var roar_summons: bool = false
var roar_debris: bool = false

var _timer: float = 0.0
var _windup_left: float = 0.0
var _charges_left: int = 0
var _peaked: bool = false
## The current windup is the quicker second charge of phase 3.
var _followup: bool = false


## Damage taken per point dealt to [param zone] in [param at] state.
static func damage_multiplier(zone: Zone, at: State) -> float:
	if at == State.DORMANT or at == State.DEAD:
		return 0.0
	if zone == Zone.BONE:
		return BONE_MULTIPLIER
	return CRYSTAL_STUNNED_MULTIPLIER if at == State.STUNNED else 1.0


static func phase_for(health_fraction: float) -> int:
	if health_fraction <= PHASE_3_AT:
		return 3
	if health_fraction <= PHASE_2_AT:
		return 2
	return 1


func wake() -> void:
	if state == State.DORMANT:
		_enter(State.WAKING)


func is_awake() -> bool:
	return state != State.DORMANT and state != State.WAKING and state != State.DEAD


## Seconds spent in the current state.
func state_time() -> float:
	return _timer


func walk_speed() -> float:
	return WALK_SPEEDS[phase - 1]


func turn_speed() -> float:
	return CHARGE_TURN_SPEED if state == State.CHARGE_WINDUP else TURN_SPEEDS[phase - 1]


## True while the tail whip of a swipe can hit.
func is_whipping() -> bool:
	return state == State.TAIL_SWIPE and _timer <= TAIL_HIT_TIME


## True while a charge windup still turns to follow the guard.
func is_tracking() -> bool:
	return state == State.CHARGE_WINDUP and _windup_left > CHARGE_LOCK_TIME


## 0..1 through the current telegraph (charge or tail windup), else 0.
func windup_progress() -> float:
	match state:
		State.CHARGE_WINDUP:
			var total := _windup_total()
			return clampf(1.0 - _windup_left / total, 0.0, 1.0)
		State.TAIL_WINDUP:
			return clampf(_timer / TAIL_WINDUP_TIME, 0.0, 1.0)
	return 0.0


func set_health_fraction(fraction: float) -> void:
	var next := phase_for(fraction)
	if next > phase:
		phase = next
		pending_phase_roar = true
		phase_changed.emit(phase)


## A charge ran into level geometry.
func hit_wall() -> void:
	if state == State.CHARGE:
		_enter(State.STUNNED)


## Taser on the crystal. Returns true when it staggered the boss.
func stagger() -> bool:
	if stagger_cooldown > 0.0:
		return false
	match state:
		State.DORMANT, State.WAKING, State.STUNNED, State.STAGGER, State.DEAD:
			return false
	stagger_cooldown = STAGGER_COOLDOWN
	_enter(State.STAGGER)
	return true


func die() -> void:
	if state != State.DEAD:
		_enter(State.DEAD)


## Jumps straight into [param next] (dev arena, scenarios, tests).
func force(next: State) -> void:
	_enter(next)


## [param distance] = flat distance to the guard (INF without one);
## [param angle] = signed bearing of the guard from the facing (rad).
func update(delta: float, distance: float, angle: float) -> void:
	if state == State.DORMANT or state == State.DEAD:
		return
	_timer += delta
	if state != State.WAKING:
		_tick_cooldowns(delta, distance, angle)
	match state:
		State.WAKING:
			if _timer >= WAKE_TIME:
				_enter(State.STALK)
		State.STALK:
			_choose(distance, angle)
		State.CHARGE_WINDUP:
			_wind_up(delta, distance, angle)
		State.CHARGE:
			if _timer >= charge_time:
				if _charges_left > 0:
					_charges_left -= 1
					_enter(State.CHARGE_WINDUP)
				else:
					_enter(State.SKID)
		State.SKID:
			if _timer >= SKID_TIME:
				_enter(State.STALK)
		State.STUNNED:
			if _timer >= STUN_TIME:
				_enter(State.STALK)
		State.STAGGER:
			if _timer >= STAGGER_TIME:
				_enter(State.STALK)
		State.TAIL_WINDUP:
			if _timer >= TAIL_WINDUP_TIME:
				_enter(State.TAIL_SWIPE)
		State.TAIL_SWIPE:
			if _timer >= TAIL_SWIPE_TIME:
				_enter(State.STALK)
		State.ROAR:
			if not _peaked and _timer >= ROAR_PEAK_AT:
				_peaked = true
				# the cooldowns start only now: a taser stagger before the peak
				# delays the summons, it cannot cancel them
				if roar_summons:
					summon_cooldown = SUMMON_INTERVAL
				if roar_debris:
					debris_cooldown = DEBRIS_INTERVAL
				roar_peak.emit(roar_summons, roar_debris)
			if _timer >= ROAR_TIME:
				_enter(State.STALK)


func _tick_cooldowns(delta: float, distance: float, angle: float) -> void:
	var close := distance < CLOSE_RANGE and absf(angle) <= CHARGE_START_ARC
	charge_cooldown -= delta * (2.0 if close else 1.0)
	tail_cooldown -= delta
	stagger_cooldown -= delta
	if phase >= 2:
		summon_cooldown -= delta
	if phase >= 3:
		debris_cooldown -= delta


func _choose(distance: float, angle: float) -> void:
	if is_inf(distance):
		return
	if pending_phase_roar:
		pending_phase_roar = false
		roar(phase >= 2 and can_summon, phase >= 3)
		return
	if absf(angle) >= TAIL_REAR_ANGLE and distance <= TAIL_RANGE and tail_cooldown <= 0.0:
		_enter(State.TAIL_WINDUP)
		return
	if charge_cooldown <= 0.0 and absf(angle) <= CHARGE_START_ARC and distance <= CHARGE_MAX_RANGE:
		_charges_left = 1 if phase >= 3 else 0
		_enter(State.CHARGE_WINDUP)
		return
	var summon := phase >= 2 and summon_cooldown <= 0.0
	if summon and not can_summon:
		summon_cooldown = SUMMON_RETRY
		summon = false
	var debris := phase >= 3 and debris_cooldown <= 0.0
	if summon or debris:
		roar(summon, debris)


func _wind_up(delta: float, distance: float, angle: float) -> void:
	if is_inf(distance) or _timer >= CHARGE_WINDUP_GIVE_UP:
		_end_charging()
		_enter(State.STALK)
		return
	# the countdown waits until the boss faces the guard; once locked it runs out
	if absf(angle) <= CHARGE_AIM_TOLERANCE or not is_tracking():
		_windup_left -= delta
	if _windup_left <= 0.0:
		charge_time = clampf((distance + CHARGE_OVERSHOOT) / CHARGE_SPEED, CHARGE_MIN_TIME, CHARGE_MAX_TIME)
		_enter(State.CHARGE)
		charge_started.emit()


## Starts a roar that summons and/or brings down debris at its peak (their
## cooldowns start there too).
func roar(summon: bool, debris: bool) -> void:
	roar_summons = summon
	roar_debris = debris
	_enter(State.ROAR)


func _end_charging() -> void:
	_charges_left = 0
	charge_cooldown = CHARGE_COOLDOWNS[phase - 1]


func _windup_total() -> float:
	return FOLLOWUP_WINDUP_TIME if _followup else CHARGE_WINDUP_TIME


func _enter(next: State) -> void:
	var previous := state
	match next:
		State.CHARGE_WINDUP:
			_followup = previous == State.CHARGE
			_windup_left = _windup_total()
		State.STUNNED, State.SKID:
			_end_charging()
		State.STAGGER:
			if previous == State.CHARGE_WINDUP or previous == State.CHARGE:
				_end_charging()
				charge_cooldown *= 0.5
		State.TAIL_SWIPE:
			tail_cooldown = TAIL_COOLDOWN
	state = next
	_timer = 0.0
	_peaked = false
	state_changed.emit(previous, next)
	if next == State.TAIL_SWIPE:
		tail_strike.emit()
