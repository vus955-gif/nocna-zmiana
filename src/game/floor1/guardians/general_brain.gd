class_name GeneralBrain
extends RefCounted
## The Samurai General (Asia's wing guardian, design 7.4; plan
## docs/superpowers/plans/2026-10-03-straznik-general.md) as pure logic:
## his states, the attack he picks, the stages of each attack and how long
## they take in each phase, the taser's stun and the fist's finisher, the
## roof visits and the phase 3 feint - every number of the duel in one
## table. The General node feeds him the guard's flat distance and bearing
## every physics frame and acts on his states and signals; the moves sample
## their clips at clip_time() (0..1 warning, 1..2 strike, 2..3 recovery) as
## the other guardians' do.
##
## DORMANT -(wake)-> WAKING (the armour assembles off its stand, then he
## draws the nodachi) -> GUARD (chudan, facing the guard, suri-ashi toward
## him when far) <-> ATTACK (TELEGRAPH -> STRIKE -> RECOVER): the DASH cut
## (a glint on the blade, a lane on the gravel, the lunge through the
## guard's place), the CLOSE cut (jodan, a cone before him), in phase 3 the
## FEINT (a petal whirl, two figures - one a phantom - and only the real
## blade glints). The taser (shock()) in his guard, a telegraph or a
## recovery -> STUNNED (then immune for a while); a fist on the stunned
## General (finish()) hurts him and sends him REELing. Phase 2: LEAP_UP onto
## the tea house eave -> ROOF: VOLLEYs (two, or one once his face is hit) ->
## LEAP_DOWN; again every ROOF_RETURN s. Phase 3: TRANSFORM first (he
## plants the sword, the cherry sheds its petals). DEAD is final; reset()
## puts him back to sleep.
##
## Bearing: the guard's angle from his facing (rad), positive on his left.

signal state_changed(from: State, to: State)
## The warning of [param attack] begins.
signal telegraphed(attack: Attack)
## [param attack] lands / its active part begins (the dash, the arrows
## leaving, the feet touching the roof or the gravel).
signal struck(attack: Attack)
## [param attack] is over (or was called off by a stun).
signal finished(attack: Attack)
## The taser took him.
signal stunned
## A fist finished the stun (the node deals FINISH_FRACTION of his health).
signal finished_off

enum State { DORMANT, WAKING, GUARD, ATTACK, STUNNED, REEL, ROOF, TRANSFORM, DEAD }
enum Attack { NONE, DASH, CLOSE, FEINT, LEAP_UP, VOLLEY, LEAP_DOWN }
enum Stage { TELEGRAPH, STRIKE, RECOVER }

## The waking: the armour's parts fly together off the stand (feet, legs,
## hips, cuirass, arms, shoulder guards, helmet), then the draw.
const ASSEMBLE_TIME := 1.7
const DRAW_TIME := 1.5
const WAKE_TIME := ASSEMBLE_TIME + DRAW_TIME
## Phase 3's entrance: the sword planted, the gust, the petals.
const TRANSFORM_TIME := 2.2
## Before the first attack after waking, a stun, the transformation.
const FIRST_PAUSE := 0.8
## Between attacks on the ground, per phase.
const PAUSE: Array[float] = [1.3, 1.0, 0.8]
## Between volleys on the roof.
const ROOF_PAUSE := 0.5
## Next look when nothing could be picked.
const RETRY := 0.15
## The pause runs this many times faster with the guard within CLOSE_RANGE.
const CLOSE_HURRY := 2.0

## Per attack, per phase: [telegraph, strike, recover] (s). The telegraph is
## the warning (never under Guardian.MIN_TELEGRAPH): the blade raised and
## glinting over the lane, the jodan lift, the crouch and the flight of a
## leap (its landing is the strike: the mark shows all through), the bow
## drawn; the strike: the lunge through the guard's place, the cut, the
## arrows leaving (they fly ARROW_FLIGHT more), the feet landing; the
## recovery: a missed dash's stumble (the back open), the chiburi.
const TIMES := {
	Attack.DASH: [[1.15, 0.25, 1.6], [1.0, 0.24, 1.35], [0.9, 0.22, 0.95]],
	Attack.CLOSE: [[0.8, 0.18, 0.9], [0.75, 0.18, 0.8], [0.7, 0.18, 0.7]],
	Attack.FEINT: [[1.1, 0.22, 0.8], [1.1, 0.22, 0.8], [1.1, 0.22, 0.8]],
	Attack.LEAP_UP: [[1.4, 0.15, 0.4], [1.4, 0.15, 0.4], [1.3, 0.15, 0.35]],
	Attack.VOLLEY: [[0.8, 0.2, 0.6], [0.8, 0.2, 0.6], [0.75, 0.2, 0.55]],
	Attack.LEAP_DOWN: [[1.4, 0.1, 0.5], [1.4, 0.1, 0.5], [1.3, 0.1, 0.45]],
}
## A dash that cut the guard recovers this long instead (chiburi, zanshin).
const DASH_HIT_RECOVER: Array[float] = [0.9, 0.8, 0.7]
const FEINT_HIT_RECOVER: Array[float] = [0.6, 0.6, 0.6]
## The blade's glint begins this long after the dash's telegraph starts
## (so at least 0.7 s before the cut), per phase; the feint's.
const DASH_GLINT_AT: Array[float] = [0.3, 0.25, 0.2]
const FEINT_GLINT_AT := 0.3
## The lane on the gravel follows the guard until this long before the cut,
## leading a running guard by this share of his run over the lock and half
## the lunge (per phase): keep running and the blade meets you; stop or
## turn back and it misses.
const LANE_LOCK := 0.3
const DASH_LEAD: Array[float] = [0.7, 0.85, 1.0]
## The phantom of a feint moves this long before the real blade; the whirl
## hides both figures for this long, then they step apart until this.
const FEINT_PHANTOM_LEAD := 0.25
const FEINT_HIDE := 0.25
const FEINT_APART := 0.45
## A leap: the crouch, then the flight (together the telegraph).
const LEAP_CROUCH := 0.5
const LEAP_FLIGHT := 0.9

# --- reach (m from his feet, rad from his facing) --------------------------------
## The close cut: the guard within this, in this cone (half angle).
const CLOSE_RANGE := 3.2
const CLOSE_ARC := 0.873
const CLOSE_REACH := 2.6
## The dash: from here to there, through the guard's place and on.
const DASH_RANGE := Vector2(1.0, 30.0)
const DASH_OVERSHOOT := 2.0
## Half the width of the cut (plus the guard's radius).
const DASH_HALF_WIDTH := 0.5
## He presses in (suri-ashi) when the guard is farther than this.
const HOLD_FAR := 6.0

# --- choice -------------------------------------------------------------------
const DASH_WEIGHT := 1.0
const FEINT_WEIGHT := 1.4
## The attack just used weighs this much less next time.
const REPEAT_FACTOR := 0.35
## Up on the roof again this long after he came down (phase 2+).
const ROOF_RETURN := 22.0
## Volleys per visit; arrows per volley, per phase.
const VOLLEYS := 2
const ARROWS: Array[int] = [3, 4, 5]

# --- the stun -----------------------------------------------------------------
## The taser's stun, per phase; then no stun for this long.
const STUN_TIME: Array[float] = [2.2, 1.8, 1.5]
const STUN_IMMUNITY := 6.0
## A fist on the stunned General takes this share of his health, once a stun.
const FINISH_FRACTION := 0.14
const REEL_TIME := 0.9

# --- moving ------------------------------------------------------------------------
## Suri-ashi toward the guard, per phase (m/s; the guard walks 4.5).
const ADVANCE: Array[float] = [2.4, 2.8, 3.2]
## The feint's sidestep (m/s, both figures out of the whirl).
const SIDESTEP := 4.5

# --- the fight's numbers (the node deals them) -----------------------------
const DASH_DAMAGE := 34.0
const DASH_KNOCKBACK := 9.0
const CLOSE_DAMAGE := 26.0
const CLOSE_KNOCKBACK := 7.0
## An arrow hurts the guard within this of where it comes down (m); its
## flight (s), by distance.
const ARROW_DAMAGE := 12.0
const ARROW_RADIUS := 1.3
const ARROW_FLIGHT := Vector2(0.75, 1.1)
## The landing off the roof: damage within this radius.
const LAND_DAMAGE := 20.0
const LAND_RADIUS := 1.5
const LAND_KNOCKBACK := 8.0

var state: State = State.DORMANT
var phase: int = 1
var attack: Attack = Attack.NONE
var stage: Stage = Stage.TELEGRAPH
## The dash under way cut the guard (the node reports it: dash_landed()).
var landed := false
## Up on the eave.
var on_roof := false
## Volleys left this visit.
var volleys_left: int = 0
var roof_cooldown: float = 0.0
var stun_immunity: float = 0.0
## He closes in instead of a third dash running.
var advancing := false
## The feint's side (which way the real General steps): 1 left, -1 right.
var feint_side: int = 1
## The node says whether there is a roof to leap to (no perch: no visits).
var can_roof := true
var rng := RandomNumberGenerator.new()

var _timer: float = 0.0
var _stage_timer: float = 0.0
var _pause: float = 0.0
var _distance: float = INF
var _pending_leap := false
var _pending_transform := false
var _leave_roof := false
var _finished_this_stun := false
var _history: Array[Attack] = []


func seed_with(value: int) -> void:
	rng.seed = value


## Length of [param at] stage of [param kind] in [param in_phase] (the
## recovery of a dash that missed).
static func stage_length(kind: Attack, at: Stage, in_phase: int) -> float:
	var table: Array = TIMES.get(kind, [])
	if table.is_empty():
		return 0.0
	var row: Array = table[clampi(in_phase - 1, 0, table.size() - 1)]
	return float(row[int(at)])


static func per_phase(values: Array, in_phase: int) -> float:
	return float(values[clampi(in_phase - 1, 0, values.size() - 1)])


## When the blade glints, from the start of [param kind]'s telegraph (s).
static func glint_at(kind: Attack, in_phase: int) -> float:
	match kind:
		Attack.DASH:
			return per_phase(DASH_GLINT_AT, in_phase)
		Attack.FEINT:
			return FEINT_GLINT_AT
	return INF


func wake() -> void:
	if state == State.DORMANT:
		_enter(State.WAKING)


func die() -> void:
	if state != State.DEAD:
		attack = Attack.NONE
		_enter(State.DEAD)


## Asleep again (the guard fled): phase 1, on the ground.
func reset() -> void:
	phase = 1
	attack = Attack.NONE
	stage = Stage.TELEGRAPH
	landed = false
	on_roof = false
	volleys_left = 0
	roof_cooldown = 0.0
	stun_immunity = 0.0
	advancing = false
	_pending_leap = false
	_pending_transform = false
	_leave_roof = false
	_finished_this_stun = false
	_distance = INF
	_history.clear()
	_enter(State.DORMANT)


## Health crossed into [param next] (2 or 3): the roof visit and the
## transformation wait for the attack under way.
func set_phase(next: int) -> void:
	if next <= phase or state == State.DEAD:
		return
	if phase < 2 and next >= 2:
		_pending_leap = true
	if next >= 3:
		_pending_transform = true
	phase = next
	_pause = minf(_pause, 0.3)


## Starts [param kind] at once (dev arena, scenarios, tests).
func force_attack(kind: Attack) -> void:
	if state == State.DEAD or state == State.DORMANT or state == State.WAKING:
		return
	_start(kind)


## The dash under way cut the guard: a short recovery.
func dash_landed() -> void:
	if state == State.ATTACK and (attack == Attack.DASH or attack == Attack.FEINT) and stage == Stage.STRIKE:
		landed = true


## A hit in the face up on the roof: he comes down after the volley.
func hit_face() -> void:
	if on_roof:
		_leave_roof = true


## The taser's jolt: true when it stunned him (his guard, a telegraph or a
## recovery on the ground, not while immune).
func shock() -> bool:
	if not can_be_stunned():
		return false
	var cancelled := attack
	attack = Attack.NONE
	stage = Stage.TELEGRAPH
	landed = false
	advancing = false
	_finished_this_stun = false
	_enter(State.STUNNED)
	if cancelled != Attack.NONE:
		finished.emit(cancelled)
	stunned.emit()
	return true


## A fist on the stunned General: true the first time in a stun (the node
## deals FINISH_FRACTION of his health); he reels back to his guard.
func finish() -> bool:
	if state != State.STUNNED or _finished_this_stun:
		return false
	_finished_this_stun = true
	stun_immunity = STUN_IMMUNITY
	_enter(State.REEL)
	finished_off.emit()
	return true


## True while the taser would take him.
func can_be_stunned() -> bool:
	if stun_immunity > 0.0 or on_roof:
		return false
	match state:
		State.GUARD:
			return true
		State.ATTACK:
			if attack == Attack.LEAP_UP or attack == Attack.LEAP_DOWN or attack == Attack.VOLLEY:
				return false
			return stage != Stage.STRIKE
	return false


## True while his guard turns hits from the front (chudan on the ground).
func blocking() -> bool:
	return state == State.GUARD


## True while a missed dash leaves his back to the guard (the recovery).
func back_open() -> bool:
	return state == State.ATTACK and (attack == Attack.DASH or attack == Attack.FEINT) and stage == Stage.RECOVER and not landed


## True during the lunge of a dash or a feint.
func dashing() -> bool:
	return state == State.ATTACK and (attack == Attack.DASH or attack == Attack.FEINT) and stage == Stage.STRIKE


func is_awake() -> bool:
	return state != State.DORMANT and state != State.DEAD


## Arrows in a volley now.
func arrows() -> int:
	return int(per_phase(ARROWS, phase))


## Seconds in the current state.
func state_time() -> float:
	return _timer


## Seconds in the current stage of the attack.
func stage_time() -> float:
	return _stage_timer


## 0..1 through WAKING, STUNNED, REEL or TRANSFORM.
func state_progress() -> float:
	match state:
		State.WAKING:
			return clampf(_timer / WAKE_TIME, 0.0, 1.0)
		State.STUNNED:
			return clampf(_timer / per_phase(STUN_TIME, phase), 0.0, 1.0)
		State.REEL:
			return clampf(_timer / REEL_TIME, 0.0, 1.0)
		State.TRANSFORM:
			return clampf(_timer / TRANSFORM_TIME, 0.0, 1.0)
	return 0.0


## 0..1 through the armour's assembly (the first part of the waking).
func assemble_progress() -> float:
	if state != State.WAKING:
		return 1.0 if is_awake() else 0.0
	return clampf(_timer / ASSEMBLE_TIME, 0.0, 1.0)


## 0..1 through the draw (the second part of the waking).
func draw_progress() -> float:
	if state != State.WAKING:
		return 1.0 if is_awake() else 0.0
	return clampf((_timer - ASSEMBLE_TIME) / DRAW_TIME, 0.0, 1.0)


## The current stage's length (a dash that landed recovers faster).
func current_stage_length() -> float:
	if state != State.ATTACK:
		return 0.0
	if stage == Stage.RECOVER and landed:
		if attack == Attack.DASH:
			return per_phase(DASH_HIT_RECOVER, phase)
		if attack == Attack.FEINT:
			return per_phase(FEINT_HIT_RECOVER, phase)
	return stage_length(attack, stage, phase)


## Where the attack's clip stands: 0..1 telegraph, 1..2 strike, 2..3
## recovery.
func clip_time() -> float:
	if state != State.ATTACK:
		return 0.0
	var length := current_stage_length()
	return float(int(stage)) + (clampf(_stage_timer / length, 0.0, 1.0) if length > 0.0 else 1.0)


## How fast he means to go now (m/s, toward the guard): suri-ashi when he
## presses in, nothing while he holds, attacks, reels or stands on the roof.
func wanted_speed() -> float:
	if state != State.GUARD:
		return 0.0
	if advancing:
		return per_phase(ADVANCE, phase)
	if _distance > HOLD_FAR:
		return per_phase(ADVANCE, phase) * 0.7
	return 0.0


func update(delta: float, distance: float, bearing: float) -> void:
	if state == State.DORMANT or state == State.DEAD:
		return
	_timer += delta
	_distance = distance
	stun_immunity = maxf(stun_immunity - delta, 0.0)
	if phase >= 2 and not on_roof and state != State.ATTACK:
		roof_cooldown = maxf(roof_cooldown - delta, 0.0)
	match state:
		State.WAKING:
			if _timer >= WAKE_TIME:
				_guard(FIRST_PAUSE)
		State.STUNNED:
			if _timer >= per_phase(STUN_TIME, phase):
				stun_immunity = STUN_IMMUNITY
				_guard(FIRST_PAUSE * 0.6)
		State.REEL:
			if _timer >= REEL_TIME:
				_guard(FIRST_PAUSE * 0.6)
		State.TRANSFORM:
			if _timer >= TRANSFORM_TIME:
				_guard(FIRST_PAUSE)
		State.GUARD:
			if _pending_transform:
				_pending_transform = false
				_enter(State.TRANSFORM)
				return
			if advancing and distance <= CLOSE_RANGE - 0.3:
				advancing = false
				_pause = minf(_pause, 0.1)
			_pause -= delta * (CLOSE_HURRY if distance <= CLOSE_RANGE else 1.0)
			if _pause <= 0.0:
				var picked := choose(distance, bearing)
				if picked == Attack.NONE:
					_pause = RETRY
				else:
					_start(picked)
		State.ROOF:
			_pause -= delta
			if _pause <= 0.0:
				if volleys_left > 0 and not _leave_roof:
					_start(Attack.VOLLEY)
				else:
					_start(Attack.LEAP_DOWN)
		State.ATTACK:
			_stage_timer += delta
			if _stage_timer >= current_stage_length():
				_next_stage()


## The attack he would pick now for a guard [param distance] m away at
## [param bearing] (NONE when nothing fits: he closes in). Rolls the dice.
func choose(distance: float, bearing: float) -> Attack:
	if is_inf(distance):
		return Attack.NONE
	if can_roof and phase >= 2 and (_pending_leap or roof_cooldown <= 0.0):
		return Attack.LEAP_UP
	if distance <= CLOSE_RANGE and absf(bearing) <= CLOSE_ARC and _allowed(Attack.CLOSE):
		return Attack.CLOSE
	var weights := {}
	if distance >= DASH_RANGE.x and distance <= DASH_RANGE.y:
		weights[Attack.DASH] = DASH_WEIGHT
		if phase >= 3:
			weights[Attack.FEINT] = FEINT_WEIGHT
	if weights.is_empty():
		return Attack.NONE
	var total := 0.0
	for kind: Attack in weights.keys():
		if not _allowed(kind):
			weights[kind] = 0.0
		elif not _history.is_empty() and _history[_history.size() - 1] == kind:
			weights[kind] = float(weights[kind]) * REPEAT_FACTOR
		total += float(weights[kind])
	if total <= 0.0:
		# a third dash running: he walks in for the close cut instead
		advancing = distance > CLOSE_RANGE
		return Attack.NONE
	var roll := rng.randf() * total
	for kind: Attack in weights.keys():
		roll -= float(weights[kind])
		if roll <= 0.0 and float(weights[kind]) > 0.0:
			return kind
	for kind: Attack in weights.keys():
		if float(weights[kind]) > 0.0:
			return kind
	return Attack.NONE


## False when [param kind] was the last two picks (never thrice running).
func _allowed(kind: Attack) -> bool:
	var count := _history.size()
	return not (count >= 2 and _history[count - 1] == kind and _history[count - 2] == kind)


func _start(kind: Attack) -> void:
	attack = kind
	stage = Stage.TELEGRAPH
	_stage_timer = 0.0
	landed = false
	advancing = false
	_history.append(kind)
	if _history.size() > 2:
		_history.pop_front()
	match kind:
		Attack.LEAP_UP:
			_pending_leap = false
			_leave_roof = false
		Attack.FEINT:
			feint_side = 1 if rng.randf() < 0.5 else -1
	_enter(State.ATTACK)
	telegraphed.emit(kind)


func _next_stage() -> void:
	match stage:
		Stage.TELEGRAPH:
			stage = Stage.STRIKE
			_stage_timer = 0.0
			if attack == Attack.LEAP_UP:
				on_roof = true
			elif attack == Attack.LEAP_DOWN:
				on_roof = false
			struck.emit(attack)
		Stage.STRIKE:
			stage = Stage.RECOVER
			_stage_timer = 0.0
			if attack == Attack.VOLLEY:
				volleys_left -= 1
		Stage.RECOVER:
			var done := attack
			attack = Attack.NONE
			stage = Stage.TELEGRAPH
			match done:
				Attack.LEAP_UP:
					volleys_left = VOLLEYS
					_pause = ROOF_PAUSE
					_enter(State.ROOF)
				Attack.VOLLEY:
					_pause = ROOF_PAUSE
					_enter(State.ROOF)
				Attack.LEAP_DOWN:
					roof_cooldown = ROOF_RETURN
					_leave_roof = false
					_guard(FIRST_PAUSE * 0.5)
				_:
					_guard(per_phase(PAUSE, phase))
			finished.emit(done)


func _guard(pause: float) -> void:
	_pause = pause
	_enter(State.GUARD)


func _enter(next: State) -> void:
	var previous := state
	state = next
	_timer = 0.0
	state_changed.emit(previous, next)
