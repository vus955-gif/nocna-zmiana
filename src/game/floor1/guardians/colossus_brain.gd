class_name ColossusBrain
extends RefCounted
## The Colossus of Ramesses (Egypt's wing guardian, design 7.4) as pure
## logic: its states, the attack it picks, the stages of each attack and
## how long they take in each phase, the phase changes and the scarab
## swarms - and every number of the fight in one table. The Colossus node
## feeds it the guard's flat distance and bearing every physics frame (and
## whether its arm can reach him, how many swarms are alive) and acts on
## its states and signals; the moves sample their clips at clip_time().
##
## DORMANT -(wake)-> WAKING -> IDLE <-> ATTACK (TELEGRAPH -> STRIKE ->
## RECOVER). Phase 2 (set_phase): PHASE_SHIFT (the chest plates fall) as
## soon as the attack under way is over; phase 3: then STAND_UP, after
## which it stands, walks between attacks and its moves change. DEAD is
## final; reset() puts it back to sleep on its throne.
##
## Bearing: the guard's angle from its facing (rad), positive on its left.

signal state_changed(from: State, to: State)
## The warning of [param attack] begins.
signal telegraphed(attack: Attack)
## [param attack] lands (a hand on the floor) or its active part begins (a
## sweep, a beam firing, a swarm pouring out).
signal struck(attack: Attack)
## [param attack] is over.
signal finished(attack: Attack)

enum State { DORMANT, WAKING, IDLE, ATTACK, PHASE_SHIFT, STAND_UP, DEAD }
enum Attack { NONE, SLAM, SWEEP, BEAM, SWARM, BEAM_SWEEP }
enum Stage { TELEGRAPH, STRIKE, RECOVER }

## Eyes ignite, dust pours, the torso grinds round to the guard.
const WAKE_TIME := 2.6
## Phase 2: it rears back, the chest plates break off, the cracks blaze.
const PHASE_SHIFT_TIME := 2.2
## Phase 3: off the throne to its full height.
const STAND_UP_TIME := 3.4
## Before the first attack after waking, a phase shift or the stand-up.
const FIRST_PAUSE := 0.6
## Between attacks, per phase.
const PAUSE: Array[float] = [1.7, 1.3, 1.2]
## Next look when nothing could be picked (the guard at its back).
const RETRY := 0.25

## Per attack, per phase: [telegraph, strike, recover] (s). The telegraph
## is the warning (never under Guardian.MIN_TELEGRAPH); the strike is the
## hand lying on the floor, the sweep passing, the beam firing...
const TIMES := {
	Attack.SLAM: [[0.95, 1.2, 0.9], [0.85, 1.0, 0.8], [0.8, 0.9, 0.7]],
	Attack.SWEEP: [[1.0, 0.6, 0.9], [0.9, 0.55, 0.8], [0.9, 0.55, 0.8]],
	Attack.BEAM: [[1.2, 2.2, 0.6], [1.0, 2.6, 0.5], [1.0, 2.6, 0.5]],
	Attack.SWARM: [[0.9, 0.5, 0.6], [0.9, 0.5, 0.6], [0.9, 0.5, 0.6]],
	Attack.BEAM_SWEEP: [[1.1, 2.0, 0.7], [1.1, 2.0, 0.7], [1.1, 2.0, 0.7]],
}

# --- reach (m from the hips' floor point, rad from its facing) ---------------
const SLAM_RANGE := Vector2(4.5, 13.5)
const SLAM_ARC := 1.92
const SWEEP_RANGE := Vector2(3.8, 8.0)
const SWEEP_ARC := 1.4
const BEAM_ARC := 1.15
const BEAM_MIN := 3.0
const BEAM_SWEEP_MIN := 5.0
## Beyond this the beam is the likelier pick.
const FAR := 11.0

# --- choice -------------------------------------------------------------------
const WEIGHTS := {Attack.SLAM: 3.0, Attack.SWEEP: 3.0, Attack.BEAM: 2.0, Attack.BEAM_SWEEP: 3.0}
const FAR_BEAM_BONUS := 3.0
## The attack just used weighs this much less next time.
const REPEAT_FACTOR := 0.35

# --- swarms (phase 2+) ----------------------------------------------------------
const SWARM_COOLDOWN: Array[float] = [0.0, 14.0, 11.0]
## Cooldown left when phase 2 begins (the plates fall, the scarabs pour).
const SWARM_FIRST := 0.5
## Swarms alive at once, per phase.
const MAX_SWARMS: Array[int] = [0, 2, 3]

# --- the fight's numbers (the node deals them) ---------------------------------
const SLAM_DAMAGE := 34.0
const SLAM_RADIUS := 2.4
const SLAM_KNOCKBACK := 9.0
## The slam's shockwave ring: damage, reach (m), speed (m/s).
const SLAM_RING := Vector3(10.0, 7.0, 10.0)
const SWEEP_DAMAGE := 24.0
const SWEEP_KNOCKBACK := 12.0
## The low sweep passes from this bearing to that one (rad, for the left
## arm; the right arm mirrors it), its forearm along the floor in
## SWEEP_RANGE.
const SWEEP_FROM := 1.66
const SWEEP_TO := -1.22
## Feet higher than this above the floor clear a low sweep or a ring.
const CLEAR_HEIGHT := 0.45
const BEAM_DPS := 30.0
## How fast the beam turns after the guard, per phase (rad/s).
const BEAM_TRACK: Array[float] = [0.26, 0.42, 0.42]
## The beam starts where the guard was this long before it fires.
const BEAM_LEAD := 0.3
const BEAM_SWEEP_DAMAGE := 28.0
## The phase-3 sweep: its arc (rad), centred on the guard.
const BEAM_SWEEP_ARC := 2.09
## Walking (phase 3): a stomp ring per footfall.
const STOMP_RING := Vector3(12.0, 8.0, 9.0)
## It walks up to this far from the guard, turning this fast (rad/s).
const KEEP_DISTANCE := 6.5
const TURN_SPEED := 0.5

var state: State = State.DORMANT
var phase: int = 1
var standing: bool = false
var attack: Attack = Attack.NONE
var stage: Stage = Stage.TELEGRAPH
## Which arm strikes: 1 = its left, -1 = its right.
var side: int = 1
## Set by the node each frame: the line from the shoulder to the guard is
## clear (a slam can come down on him), and how many swarms it has alive.
var slam_clear: bool = true
var swarms_alive: int = 0
var swarm_cooldown: float = 0.0
var rng := RandomNumberGenerator.new()

var _timer: float = 0.0
var _stage_timer: float = 0.0
var _pause: float = 0.0
var _pending_shift := false
var _pending_stand := false
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


func wake() -> void:
	if state == State.DORMANT:
		_enter(State.WAKING)


func die() -> void:
	if state != State.DEAD:
		attack = Attack.NONE
		_enter(State.DEAD)


## Asleep on its throne again (the guard fled): phase 1, seated.
func reset() -> void:
	phase = 1
	standing = false
	attack = Attack.NONE
	stage = Stage.TELEGRAPH
	swarm_cooldown = 0.0
	swarms_alive = 0
	_pending_shift = false
	_pending_stand = false
	_history.clear()
	_enter(State.DORMANT)


## Health crossed into [param next] (2 or 3): the shift waits for the
## attack under way.
func set_phase(next: int) -> void:
	if next <= phase or state == State.DEAD:
		return
	if phase < 2 and next >= 2:
		_pending_shift = true
	if next >= 3:
		_pending_stand = true
	phase = next
	if state == State.IDLE:
		_follow_up()


## Starts [param kind] at once (dev arena, scenarios, tests).
func force_attack(kind: Attack) -> void:
	if state == State.DEAD or state == State.DORMANT:
		return
	_start(kind)


func is_awake() -> bool:
	return state != State.DORMANT and state != State.DEAD


## Seconds in the current state.
func state_time() -> float:
	return _timer


## Seconds in the current stage of the attack.
func stage_time() -> float:
	return _stage_timer


## 0..1 through the current state (WAKING, PHASE_SHIFT, STAND_UP).
func state_progress() -> float:
	match state:
		State.WAKING:
			return clampf(_timer / WAKE_TIME, 0.0, 1.0)
		State.PHASE_SHIFT:
			return clampf(_timer / PHASE_SHIFT_TIME, 0.0, 1.0)
		State.STAND_UP:
			return clampf(_timer / STAND_UP_TIME, 0.0, 1.0)
	return 0.0


## Where the attack's clip stands: 0..1 telegraph, 1..2 strike, 2..3
## recovery.
func clip_time() -> float:
	if state != State.ATTACK:
		return 0.0
	var length := stage_length(attack, stage, phase)
	return float(int(stage)) + (clampf(_stage_timer / length, 0.0, 1.0) if length > 0.0 else 1.0)


## True while it may walk toward a guard [param distance] m away.
func wants_to_walk(distance: float) -> bool:
	return standing and state == State.IDLE and distance > KEEP_DISTANCE


func update(delta: float, distance: float, bearing: float) -> void:
	if state == State.DORMANT or state == State.DEAD:
		return
	_timer += delta
	if phase >= 2 and state != State.PHASE_SHIFT:
		swarm_cooldown = maxf(swarm_cooldown - delta, 0.0)
	match state:
		State.WAKING:
			if _timer >= WAKE_TIME:
				_idle(FIRST_PAUSE)
		State.PHASE_SHIFT:
			if _timer >= PHASE_SHIFT_TIME:
				_pending_shift = false
				swarm_cooldown = SWARM_FIRST
				_idle(FIRST_PAUSE)
				_follow_up()
		State.STAND_UP:
			if _timer >= STAND_UP_TIME:
				_pending_stand = false
				standing = true
				_idle(FIRST_PAUSE)
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
	var limit: int = MAX_SWARMS[clampi(phase - 1, 0, MAX_SWARMS.size() - 1)]
	if phase >= 2 and swarm_cooldown <= 0.0 and swarms_alive < limit and _allowed(Attack.SWARM):
		return Attack.SWARM   # the throne pours them out first
	var weights := {}
	var angle := absf(bearing)
	if slam_clear and distance >= SLAM_RANGE.x and distance <= SLAM_RANGE.y and angle <= SLAM_ARC:
		weights[Attack.SLAM] = WEIGHTS[Attack.SLAM]
	if not standing:
		if distance >= SWEEP_RANGE.x and distance <= SWEEP_RANGE.y and angle <= SWEEP_ARC:
			weights[Attack.SWEEP] = WEIGHTS[Attack.SWEEP]
		if distance >= BEAM_MIN and angle <= BEAM_ARC:
			weights[Attack.BEAM] = WEIGHTS[Attack.BEAM] + (FAR_BEAM_BONUS if distance > FAR else 0.0)
	elif distance >= BEAM_SWEEP_MIN and angle <= BEAM_ARC:
		weights[Attack.BEAM_SWEEP] = WEIGHTS[Attack.BEAM_SWEEP] + (FAR_BEAM_BONUS if distance > FAR else 0.0)
	if weights.is_empty():
		return Attack.NONE
	var total := 0.0
	var only_repeats := true
	for kind: Attack in weights.keys():
		if _allowed(kind):
			only_repeats = false
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


## Which arm reaches a guard at [param bearing]: 1 = its left, -1 = right.
static func arm_for(bearing: float) -> int:
	return 1 if bearing >= 0.0 else -1


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
	if kind == Attack.SWARM:
		swarm_cooldown = SWARM_COOLDOWN[clampi(phase - 1, 0, SWARM_COOLDOWN.size() - 1)]
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
			_idle(PAUSE[clampi(phase - 1, 0, PAUSE.size() - 1)])
			finished.emit(done)
			_follow_up()


## A pending phase change starts as soon as nothing is under way.
func _follow_up() -> void:
	if state != State.IDLE:
		return
	if _pending_shift:
		_enter(State.PHASE_SHIFT)
	elif _pending_stand:
		_enter(State.STAND_UP)


func _idle(pause: float) -> void:
	_pause = pause
	_enter(State.IDLE)


func _enter(next: State) -> void:
	var previous := state
	state = next
	_timer = 0.0
	state_changed.emit(previous, next)
