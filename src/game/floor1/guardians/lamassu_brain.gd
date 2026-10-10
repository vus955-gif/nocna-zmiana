class_name LamassuBrain
extends RefCounted
## The Lamassu (Assyria's wing guardian, design 7.4) as pure logic: its
## states, the attack it picks, the stages of each attack and how long they
## take in each phase, the stun of a charge that ends in cover, the phase
## changes - and every number of the fight in one table. The Lamassu node
## feeds it the guard's flat distance and bearing every physics frame (and
## whether a hop has somewhere to land), tells it when a charge ends
## (end_charge) and acts on its states and signals; the moves sample their
## clips at clip_time().
##
## DORMANT -(wake)-> WAKING (off the plinth) -> IDLE (stalking) <-> ATTACK
## (TELEGRAPH -> STRIKE -> RECOVER). A charge's STRIKE is the run: it ends
## when the node says so (end_charge: cover -> STUNNED, a wall -> the skid
## of RECOVER) or after its longest run. A new phase (set_phase) shifts as
## soon as nothing is under way (PHASE_SHIFT: 2 = it rears and bellows, the
## cracks blaze; 3 = its wings beat it off the floor - hops from then on).
## DEAD is final; reset() puts it back on its plinth.
##
## Bearing: the guard's angle from its facing (rad), positive on its left.

signal state_changed(from: State, to: State)
## The warning of [param attack] begins.
signal telegraphed(attack: Attack)
## [param attack] lands (hooves down, a hop's touchdown), or its active
## part begins (the run, the wind).
signal struck(attack: Attack)
## [param attack] is over (a charge also when it ends in a stun).
signal finished(attack: Attack)

enum State { DORMANT, WAKING, IDLE, ATTACK, STUNNED, PHASE_SHIFT, DEAD }
enum Attack { NONE, CHARGE, GUST, STOMP, HOP }
enum Stage { TELEGRAPH, STRIKE, RECOVER }

## Dust falls off it, the wings unfold, it steps off its plinth.
const WAKE_TIME := 3.0
## Before the first attack after waking, a phase shift or a stun.
const FIRST_PAUSE := 0.8
## Between attacks, per phase.
const PAUSE: Array[float] = [1.9, 1.5, 1.2]
## Next look when nothing could be picked (the guard at its back).
const RETRY := 0.25
## Dazed after a charge into cover, per phase.
const STUN_TIME: Array[float] = [2.6, 2.3, 2.0]
## Entering phase 2 (rears, bellows, the cracks blaze) and 3 (wing beats).
const SHIFT_TIME := {2: 2.4, 3: 2.0}

## Per attack, per phase: [telegraph, strike, recover] (s). The telegraph
## is the warning (never under Guardian.MIN_TELEGRAPH): the pawing, the
## wings rising, the rearing, the crouch and the flight of a hop (its
## shadow marks the landing from the start). The strike: the run (its
## longest), the wind, the hooves landing, the touchdown.
const TIMES := {
	Attack.CHARGE: [[1.0, 2.4, 1.0], [0.95, 2.4, 0.9], [0.85, 2.4, 0.8]],
	Attack.GUST: [[0.8, 0.5, 0.9], [0.8, 0.5, 0.8], [0.7, 0.5, 0.7]],
	Attack.STOMP: [[0.75, 0.25, 0.85], [0.7, 0.25, 0.8], [0.65, 0.25, 0.75]],
	Attack.HOP: [[1.25, 0.3, 0.9], [1.25, 0.3, 0.9], [1.25, 0.3, 0.85]],
}
## A charge stops following the guard this long before it runs.
const CHARGE_LOCK := 0.3
## The share of a hop's telegraph spent crouching (the rest it flies).
const HOP_CROUCH := 0.28

# --- reach (m from its middle, rad from its facing) -----------------------------
const CHARGE_RANGE := Vector2(7.0, 26.0)
const CHARGE_ARC := 0.35
const GUST_RANGE := Vector2(2.5, 12.0)
const GUST_ARC := 0.5
const STOMP_RANGE := 7.5
const STOMP_ARC := 1.3
const HOP_RANGE := Vector2(6.0, 24.0)

# --- choice -------------------------------------------------------------------
## Per phase: attack -> weight (phase 3: the wings take over).
const WEIGHTS: Array[Dictionary] = [
	{Attack.CHARGE: 3.0, Attack.GUST: 2.5, Attack.STOMP: 3.0},
	{Attack.CHARGE: 3.5, Attack.GUST: 2.5, Attack.STOMP: 3.0},
	{Attack.CHARGE: 1.5, Attack.GUST: 6.5, Attack.STOMP: 2.0, Attack.HOP: 2.5},
]
## The attack just used weighs this much less next time.
const REPEAT_FACTOR := 0.35

# --- the fight's numbers (the node deals them) ---------------------------------
const CHARGE_SPEED: Array[float] = [11.5, 12.5, 13.0]
## Seconds to full speed (the heavy start).
const CHARGE_ACCEL_TIME := 0.35
## A charge runs this far past where the guard stood.
const CHARGE_OVERSHOOT := 5.0
const CHARGE_DAMAGE := 32.0
const CHARGE_KNOCKBACK := 14.0
## Braking on its hooves (m/s^2): the skid.
const SKID_DECEL := 20.0
## The gust's cone: reach (m), half angle (rad), the shove (m/s out, m/s
## up), the wind behind it (m/s^2 while it blows), the grit's damage.
const GUST_REACH := 13.0
const GUST_HALF_ANGLE := 0.56
const GUST_PUSH := 10.0
const GUST_LIFT := 3.5
const GUST_WIND := 18.0
const GUST_DAMAGE := 6.0
## The stomp: under the hooves (damage, radius, knockback), then its ring
## (damage, reach, speed).
const STOMP_DAMAGE := 24.0
const STOMP_RADIUS := 1.8
const STOMP_KNOCKBACK := 9.0
const STOMP_RING := Vector3(14.0, 10.0, 9.0)
## The hop: how far (m), under its shadow (damage, radius), its ring.
const HOP_MIN := 6.0
const HOP_MAX := 15.0
const HOP_DAMAGE := 28.0
const HOP_RADIUS := 2.4
const HOP_KNOCKBACK := 10.0
const HOP_RING := Vector3(16.0, 11.0, 10.0)
## Feet higher than this above the floor clear a ring.
const CLEAR_HEIGHT := 0.45

# --- stalking ---------------------------------------------------------------------
const WALK_SPEED: Array[float] = [1.6, 1.9, 2.2]
const TURN_SPEED: Array[float] = [0.9, 1.05, 1.2]
## It closes in to this distance between attacks (within the stomp's reach:
## a guard who stands his ground gets the hooves).
const KEEP_DISTANCE := 6.5
## Turning hard it keeps walking at least this fast: a wide circle, no
## pivoting on the spot.
const MIN_ARC_SPEED := 0.9

var state: State = State.DORMANT
var phase: int = 1
var attack: Attack = Attack.NONE
var stage: Stage = Stage.TELEGRAPH
## The phase a PHASE_SHIFT enters (2 or 3).
var shift_phase: int = 0
## Set by the node: a hop has somewhere to land near the guard.
var hop_clear: bool = true
var rng := RandomNumberGenerator.new()

var _timer: float = 0.0
var _stage_timer: float = 0.0
var _pause: float = 0.0
var _pending_shift: int = 0
var _history: Array[Attack] = []


func seed_with(value: int) -> void:
	rng.seed = value


## Length of [param at] stage of [param kind] in [param in_phase].
static func stage_length(kind: Attack, at: Stage, in_phase: int) -> float:
	var table: Array = TIMES.get(kind, [])
	if table.is_empty():
		return 0.0
	var row: Array = table[clampi(in_phase - 1, 0, table.size() - 1)]
	return float(row[int(at)])


## How long the shift into [param into] (2 or 3) takes.
static func shift_time(into: int) -> float:
	return float(SHIFT_TIME.get(into, 2.0))


static func _per_phase(table: Array[float], in_phase: int) -> float:
	return table[clampi(in_phase - 1, 0, table.size() - 1)]


func wake() -> void:
	if state == State.DORMANT:
		_enter(State.WAKING)


func die() -> void:
	if state != State.DEAD:
		attack = Attack.NONE
		_enter(State.DEAD)


## On its plinth again (the guard fled): phase 1, asleep.
func reset() -> void:
	phase = 1
	attack = Attack.NONE
	stage = Stage.TELEGRAPH
	shift_phase = 0
	hop_clear = true
	_pending_shift = 0
	_history.clear()
	_enter(State.DORMANT)


## Health crossed into [param next] (2 or 3): the shift waits for the
## attack (or the stun) under way.
func set_phase(next: int) -> void:
	if next <= phase or state == State.DEAD:
		return
	phase = next
	_pending_shift = next
	if state == State.IDLE:
		_follow_up()


## Starts [param kind] at once (dev arena, scenarios, tests).
func force_attack(kind: Attack) -> void:
	if state == State.DEAD or state == State.DORMANT:
		return
	_start(kind)


## The running charge ended: in cover ([param crashed]: dazed) or at a wall
## (a skid). Nothing happens unless a charge is running.
func end_charge(crashed: bool) -> void:
	if state != State.ATTACK or attack != Attack.CHARGE or stage != Stage.STRIKE:
		return
	if not crashed:
		stage = Stage.RECOVER
		_stage_timer = 0.0
		return
	attack = Attack.NONE
	stage = Stage.TELEGRAPH
	_enter(State.STUNNED)
	finished.emit(Attack.CHARGE)


func is_awake() -> bool:
	return state != State.DORMANT and state != State.DEAD


## Seconds in the current state.
func state_time() -> float:
	return _timer


## Seconds in the current stage of the attack.
func stage_time() -> float:
	return _stage_timer


## 0..1 through the current state (WAKING, PHASE_SHIFT, STUNNED).
func state_progress() -> float:
	match state:
		State.WAKING:
			return clampf(_timer / WAKE_TIME, 0.0, 1.0)
		State.PHASE_SHIFT:
			return clampf(_timer / shift_time(shift_phase), 0.0, 1.0)
		State.STUNNED:
			return clampf(_timer / _per_phase(STUN_TIME, phase), 0.0, 1.0)
	return 0.0


## Where the attack's clip stands: 0..1 telegraph, 1..2 strike, 2..3
## recovery.
func clip_time() -> float:
	if state != State.ATTACK:
		return 0.0
	var length := stage_length(attack, stage, phase)
	return float(int(stage)) + (clampf(_stage_timer / length, 0.0, 1.0) if length > 0.0 else 1.0)


## True once a charge's aim is fixed (its last CHARGE_LOCK s of pawing and
## the run).
func charge_locked() -> bool:
	if state != State.ATTACK or attack != Attack.CHARGE:
		return false
	if stage != Stage.TELEGRAPH:
		return true
	return _stage_timer >= stage_length(Attack.CHARGE, Stage.TELEGRAPH, phase) - CHARGE_LOCK


## True while it may walk toward a guard [param distance] m away.
func wants_to_walk(distance: float) -> bool:
	return state == State.IDLE and distance > KEEP_DISTANCE


func walk_speed() -> float:
	return _per_phase(WALK_SPEED, phase)


func turn_speed() -> float:
	return _per_phase(TURN_SPEED, phase)


func charge_speed() -> float:
	return _per_phase(CHARGE_SPEED, phase)


func update(delta: float, distance: float, bearing: float) -> void:
	if state == State.DORMANT or state == State.DEAD:
		return
	_timer += delta
	match state:
		State.WAKING:
			if _timer >= WAKE_TIME:
				_idle(FIRST_PAUSE)
				_follow_up()
		State.PHASE_SHIFT:
			if _timer >= shift_time(shift_phase):
				_idle(FIRST_PAUSE)
				_follow_up()
		State.STUNNED:
			if _timer >= _per_phase(STUN_TIME, phase):
				_idle(FIRST_PAUSE)
				_follow_up()
		State.IDLE:
			_pause -= delta
			if _pause <= 0.0:
				var picked := choose(distance, bearing)
				if picked == Attack.NONE:
					_pause = RETRY
				else:
					_start(picked)
		State.ATTACK:
			_stage_timer += delta
			var length := stage_length(attack, stage, phase)
			if _stage_timer >= length:
				_next_stage()


## The attack it would pick now for a guard [param distance] m away at
## [param bearing] (NONE when nothing reaches him). Rolls the dice.
func choose(distance: float, bearing: float) -> Attack:
	if is_inf(distance):
		return Attack.NONE
	var table: Dictionary = WEIGHTS[clampi(phase - 1, 0, WEIGHTS.size() - 1)]
	var angle := absf(bearing)
	var weights := {}
	for kind: Attack in table:
		if _reaches(kind, distance, angle):
			weights[kind] = float(table[kind])
	if weights.is_empty():
		return Attack.NONE
	var only_repeats := true
	for kind: Attack in weights:
		if _allowed(kind):
			only_repeats = false
	var total := 0.0
	for kind: Attack in weights.keys():
		if not _allowed(kind) and not only_repeats:
			weights[kind] = 0.0   # (the only move that reaches him may come again)
		elif not _history.is_empty() and _history[_history.size() - 1] == kind:
			weights[kind] = float(weights[kind]) * REPEAT_FACTOR
		total += float(weights[kind])
	if total <= 0.0:
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


func _reaches(kind: Attack, distance: float, angle: float) -> bool:
	match kind:
		Attack.CHARGE:
			return distance >= CHARGE_RANGE.x and distance <= CHARGE_RANGE.y and angle <= CHARGE_ARC
		Attack.GUST:
			return distance >= GUST_RANGE.x and distance <= GUST_RANGE.y and angle <= GUST_ARC
		Attack.STOMP:
			return distance <= STOMP_RANGE and angle <= STOMP_ARC
		Attack.HOP:
			return hop_clear and distance >= HOP_RANGE.x and distance <= HOP_RANGE.y
	return false


## False when [param kind] was the last two picks (never thrice running).
func _allowed(kind: Attack) -> bool:
	var count := _history.size()
	return not (count >= 2 and _history[count - 1] == kind and _history[count - 2] == kind)


func _start(kind: Attack) -> void:
	attack = kind
	stage = Stage.TELEGRAPH
	_stage_timer = 0.0
	_history.append(kind)
	if _history.size() > 2:
		_history.pop_front()
	_enter(State.ATTACK)
	telegraphed.emit(kind)


func _next_stage() -> void:
	match stage:
		Stage.TELEGRAPH:
			stage = Stage.STRIKE
			_stage_timer = 0.0
			struck.emit(attack)
		Stage.STRIKE:
			stage = Stage.RECOVER
			_stage_timer = 0.0
		Stage.RECOVER:
			var done := attack
			attack = Attack.NONE
			stage = Stage.TELEGRAPH
			_idle(_per_phase(PAUSE, phase))
			finished.emit(done)
			_follow_up()


## A pending phase change starts as soon as nothing is under way.
func _follow_up() -> void:
	if state != State.IDLE or _pending_shift == 0:
		return
	shift_phase = _pending_shift
	_pending_shift = 0
	_enter(State.PHASE_SHIFT)


func _idle(pause: float) -> void:
	_pause = pause
	_enter(State.IDLE)


func _enter(next: State) -> void:
	var previous := state
	state = next
	_timer = 0.0
	state_changed.emit(previous, next)
