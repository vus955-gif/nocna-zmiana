class_name CentaurBrain
extends RefCounted
## The Centaur from the metope (Greece's wing guardian, design 7.4) as pure
## logic: its states, the attack it picks, the stages of each attack and
## how long they take in each phase, the phases, the Lapiths it calls and
## its stun - and every number of the fight in one table. The Centaur node
## feeds it the guard's flat distance and bearing every physics frame (and
## how many Lapiths still fight) and acts on its states and signals; the
## moves sample their clips at clip_time() (0..1 warning, 1..2 strike, 2..3
## recovery), as the Colossus's do.
##
## DORMANT -(wake)-> WAKING (it tears itself out of its metope) -> ROAM
## (circling the guard at a distance) <-> ATTACK (TELEGRAPH -> STRIKE ->
## RECOVER). A charge that runs into something (crash()) ends in STUNNED,
## one that runs on (charge_done()) in its recovery (a skid). Phase 2: it
## calls the Lapiths (CALL) as soon as the attack under way is over, and
## again when they have all fallen; phase 3: it tears the metope's piece off
## its flank (TEAR) and from then on throws two javelins at once. DEAD is
## final; reset() puts it back to sleep.
##
## Bearing: the guard's angle from its facing (rad), positive on its left.

signal state_changed(from: State, to: State)
## The warning of [param attack] begins.
signal telegraphed(attack: Attack)
## [param attack] lands (a javelin leaves the hand, hooves come down) or
## its active part begins (the charge's run, the Lapiths stepping out).
signal struck(attack: Attack)
## [param attack] is over.
signal finished(attack: Attack)

enum State { DORMANT, WAKING, ROAM, ATTACK, STUNNED, DEAD }
enum Attack { NONE, THROW, KICK, BUCK, CHARGE, CALL, TEAR }
enum Stage { TELEGRAPH, STRIKE, RECOVER }

## It strains, the metope cracks, it rears and breaks free, lands facing
## the guard.
const WAKE_TIME := 2.8
## Before the first attack after waking or a stun.
const FIRST_PAUSE := 1.0
## Between attacks, per phase (it circles meanwhile).
const PAUSE: Array[float] = [1.4, 1.1, 0.9]
## Next look when nothing could be picked.
const RETRY := 0.2
## The pause runs this many times faster with the guard within KICK_RANGE.
const CLOSE_HURRY := 3.0

## Per attack, per phase: [telegraph, strike, recover] (s). The telegraph
## is the warning (never under Guardian.MIN_TELEGRAPH): the arm drawn back,
## the rearing, the hoof scraping; the strike is the throw's follow-through
## (two javelins in phase 3), the hooves coming down, the charge's run (it
## ends sooner at a crash or past the guard), the Lapiths stepping out.
const TIMES := {
	Attack.THROW: [[0.8, 0.25, 0.5], [0.7, 0.25, 0.45], [0.6, 0.35, 0.45]],
	Attack.KICK: [[0.7, 0.35, 0.6], [0.7, 0.35, 0.55], [0.65, 0.35, 0.5]],
	Attack.BUCK: [[0.65, 0.3, 0.55], [0.65, 0.3, 0.5], [0.6, 0.3, 0.5]],
	Attack.CHARGE: [[0.9, 2.4, 0.7], [0.8, 2.4, 0.7], [0.7, 2.4, 0.6]],
	Attack.CALL: [[1.0, 0.6, 0.6], [1.0, 0.6, 0.6], [1.0, 0.6, 0.6]],
	Attack.TEAR: [[0.9, 0.5, 0.8], [0.9, 0.5, 0.8], [0.9, 0.5, 0.8]],
}
## A crashed charge leaves it stunned this long, per phase.
const STUN_TIME: Array[float] = [2.6, 2.3, 2.0]

# --- reach (m from its body's centre, rad from its facing) -----------------------
const KICK_RANGE := 4.2
const KICK_ARC := 1.31
const BUCK_RANGE := 3.8
const BUCK_ARC := 2.0
const THROW_MIN := 5.0
## The human torso twists this far round over the barrel to throw.
const THROW_ARC := 1.92
const CHARGE_RANGE := Vector2(7.0, 30.0)
## Beyond this the charge is the likelier pick.
const FAR := 16.0

# --- choice -----------------------------------------------------------------------
const THROW_WEIGHT := 4.0
const CHARGE_WEIGHT: Array[float] = [2.5, 3.0, 3.5]
const FAR_CHARGE_BONUS := 2.0
## The attack just used weighs this much less next time.
const REPEAT_FACTOR := 0.35
## Least time between two charges, and before the first.
const CHARGE_COOLDOWN := 7.0
const CHARGE_FIRST := 3.0

# --- Lapiths (phase 2+) -----------------------------------------------------------
## Lapiths per call, per phase.
const LAPITHS: Array[int] = [0, 2, 3]
## Before it calls again once they have all fallen.
const CALL_COOLDOWN := 25.0

# --- moving ----------------------------------------------------------------------
## Its gallop round the guard, per phase (m/s; the guard sprints 8.5).
const GALLOP: Array[float] = [9.5, 10.5, 11.5]
## The distance it keeps, per phase (m).
const KEEP_DISTANCE: Array[float] = [11.0, 10.0, 9.0]
const CHARGE_SPEED := 15.5
## It changes the way it circles every so often (s).
const FLIP_TIME := Vector2(6.0, 10.0)

# --- the fight's numbers (the node deals them) ---------------------------------
const JAVELIN_DAMAGE := 22.0
## A javelin hurts the guard within this of where it comes down (m).
const JAVELIN_RADIUS := 1.3
## The javelin's flight (s): it lands where the mark stood when it left.
const JAVELIN_FLIGHT := Vector2(0.65, 1.25)
## The mark leads the guard by this share of his run over the flight, per
## phase (phase 3's second javelin goes where he stands).
const JAVELIN_LEAD: Array[float] = [0.5, 0.6, 0.75]
## Phase 3: the second javelin leaves this long after the first.
const PAIR_GAP := 0.15
const KICK_DAMAGE := 28.0
const KICK_KNOCKBACK := 11.0
## The rearing kick's hooves come down this far in front of its centre, in a
## disc of this radius (m).
const KICK_REACH := 1.55
const KICK_RADIUS := 2.2
## The hooves' shockwave: damage, reach (m), speed (m/s).
const KICK_RING := Vector3(8.0, 4.5, 9.0)
const BUCK_DAMAGE := 24.0
const BUCK_KNOCKBACK := 12.0
## The buck's hind hooves lash this far behind its centre (m), this wide (rad).
const BUCK_REACH := 3.4
const BUCK_SPREAD := 0.75
const CHARGE_DAMAGE := 30.0
const CHARGE_KNOCKBACK := 14.0
## The weak point counts this much more while it is stunned.
const STUN_WEAK_FACTOR := 1.5

var state: State = State.DORMANT
var phase: int = 1
var attack: Attack = Attack.NONE
var stage: Stage = Stage.TELEGRAPH
## Its left hand holds a javelin too (phase 3, after TEAR): it throws two.
var pair := false
## Which way it circles the guard: 1 = counter-clockwise (the guard on its
## left), -1 = clockwise.
var side: int = 1
## Set by the node each frame: the Lapiths of its calls still standing.
var lapiths_alive: int = 0
var charge_cooldown: float = CHARGE_FIRST
var call_cooldown: float = 0.0
var rng := RandomNumberGenerator.new()

var _timer: float = 0.0
var _stage_timer: float = 0.0
var _pause: float = 0.0
var _flip: float = 8.0
var _pending_call := false
var _pending_tear := false
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


static func per_phase(values: Array, in_phase: int) -> float:
	return float(values[clampi(in_phase - 1, 0, values.size() - 1)])


func wake() -> void:
	if state == State.DORMANT:
		_enter(State.WAKING)


func die() -> void:
	if state != State.DEAD:
		attack = Attack.NONE
		_enter(State.DEAD)


## Asleep again (the guard fled): phase 1, one javelin.
func reset() -> void:
	phase = 1
	attack = Attack.NONE
	stage = Stage.TELEGRAPH
	pair = false
	side = 1
	lapiths_alive = 0
	charge_cooldown = CHARGE_FIRST
	call_cooldown = 0.0
	_pending_call = false
	_pending_tear = false
	_history.clear()
	_enter(State.DORMANT)


## Health crossed into [param next] (2 or 3): the call and the tear wait for
## the attack under way.
func set_phase(next: int) -> void:
	if next <= phase or state == State.DEAD:
		return
	if phase < 2 and next >= 2:
		_pending_call = true
	if next >= 3:
		_pending_tear = true
	phase = next
	_pause = minf(_pause, 0.3)


## Starts [param kind] at once (dev arena, scenarios, tests).
func force_attack(kind: Attack) -> void:
	if state == State.DEAD or state == State.DORMANT:
		return
	_start(kind)


## The charge ran into something (a plinth, a pediment, a wall): stunned.
func crash() -> void:
	if state != State.ATTACK or attack != Attack.CHARGE or stage != Stage.STRIKE:
		return
	attack = Attack.NONE
	stage = Stage.TELEGRAPH
	charge_cooldown = CHARGE_COOLDOWN
	_enter(State.STUNNED)
	finished.emit(Attack.CHARGE)


## The charge ran past the guard with nothing in its way: it skids.
func charge_done() -> void:
	if state == State.ATTACK and attack == Attack.CHARGE and stage == Stage.STRIKE:
		_next_stage()


func is_awake() -> bool:
	return state != State.DORMANT and state != State.DEAD


## Seconds in the current state.
func state_time() -> float:
	return _timer


## Seconds in the current stage of the attack.
func stage_time() -> float:
	return _stage_timer


## 0..1 through WAKING or STUNNED.
func state_progress() -> float:
	match state:
		State.WAKING:
			return clampf(_timer / WAKE_TIME, 0.0, 1.0)
		State.STUNNED:
			return clampf(_timer / per_phase(STUN_TIME, phase), 0.0, 1.0)
	return 0.0


## Where the attack's clip stands: 0..1 telegraph, 1..2 strike, 2..3
## recovery.
func clip_time() -> float:
	if state != State.ATTACK:
		return 0.0
	var length := stage_length(attack, stage, phase)
	return float(int(stage)) + (clampf(_stage_timer / length, 0.0, 1.0) if length > 0.0 else 1.0)


## How fast it means to go now (m/s): its gallop round the guard, slower
## while it throws, the charge's run, nothing while it rears, scrapes,
## calls or reels.
func wanted_speed() -> float:
	var gallop := per_phase(GALLOP, phase)
	match state:
		State.ROAM:
			return gallop
		State.ATTACK:
			match attack:
				Attack.THROW:
					return gallop * (0.62 if stage == Stage.TELEGRAPH else 0.72)
				Attack.CHARGE:
					return CHARGE_SPEED if stage == Stage.STRIKE else 0.0
				Attack.TEAR:
					return gallop * 0.25
	return 0.0


## The distance it keeps from the guard while circling (m).
func keep_distance() -> float:
	return per_phase(KEEP_DISTANCE, phase)


## The weak point's multiplier now (more while it reels).
func weak_factor() -> float:
	return STUN_WEAK_FACTOR if state == State.STUNNED else 1.0


## Circle the other way (the node: the way ahead is blocked).
func flip() -> void:
	side = -side
	_flip = rng.randf_range(FLIP_TIME.x, FLIP_TIME.y)


func update(delta: float, distance: float, bearing: float) -> void:
	if state == State.DORMANT or state == State.DEAD:
		return
	_timer += delta
	charge_cooldown = maxf(charge_cooldown - delta, 0.0)
	if phase >= 2 and lapiths_alive <= 0:
		call_cooldown = maxf(call_cooldown - delta, 0.0)
	_flip -= delta
	if _flip <= 0.0 and state == State.ROAM:
		flip()
	match state:
		State.WAKING:
			if _timer >= WAKE_TIME:
				_roam(FIRST_PAUSE)
		State.STUNNED:
			if _timer >= per_phase(STUN_TIME, phase):
				_roam(FIRST_PAUSE * 0.6)
		State.ROAM:
			_pause -= delta * (CLOSE_HURRY if distance <= KICK_RANGE else 1.0)
			if _pause <= 0.0:
				var picked := choose(distance, bearing)
				if picked == Attack.NONE:
					_pause = RETRY
				else:
					_start(picked)
		State.ATTACK:
			_stage_timer += delta
			if _stage_timer >= stage_length(attack, stage, phase):
				if attack == Attack.CHARGE and stage == Stage.STRIKE:
					charge_done()   # it ran its longest run
				else:
					_next_stage()


## The attack it would pick now for a guard [param distance] m away at
## [param bearing] (NONE when nothing fits). Rolls the dice.
func choose(distance: float, bearing: float) -> Attack:
	if is_inf(distance):
		return Attack.NONE
	if _pending_call:
		return Attack.CALL
	if _pending_tear:
		return Attack.TEAR
	var angle := absf(bearing)
	# up close it fights with its hooves, nothing else
	if distance <= KICK_RANGE and angle <= KICK_ARC and _allowed(Attack.KICK):
		return Attack.KICK
	if distance <= BUCK_RANGE and angle >= BUCK_ARC and _allowed(Attack.BUCK):
		return Attack.BUCK
	if phase >= 2 and lapiths_alive <= 0 and call_cooldown <= 0.0:
		return Attack.CALL
	var weights := {}
	if distance >= THROW_MIN and angle <= THROW_ARC:
		weights[Attack.THROW] = THROW_WEIGHT
	if charge_cooldown <= 0.0 and distance >= CHARGE_RANGE.x and distance <= CHARGE_RANGE.y:
		weights[Attack.CHARGE] = per_phase(CHARGE_WEIGHT, phase) + (FAR_CHARGE_BONUS if distance > FAR else 0.0)
	if weights.is_empty():
		return Attack.NONE
	var only_repeats := true
	for kind: Attack in weights.keys():
		if _allowed(kind):
			only_repeats = false
	var total := 0.0
	for kind: Attack in weights.keys():
		if not _allowed(kind) and not only_repeats:
			weights[kind] = 0.0
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
	match kind:
		Attack.CALL:
			_pending_call = false
		Attack.TEAR:
			_pending_tear = false
	_enter(State.ATTACK)
	telegraphed.emit(kind)


func _next_stage() -> void:
	match stage:
		Stage.TELEGRAPH:
			stage = Stage.STRIKE
			_stage_timer = 0.0
			if attack == Attack.CALL:
				call_cooldown = CALL_COOLDOWN
			struck.emit(attack)
		Stage.STRIKE:
			stage = Stage.RECOVER
			_stage_timer = 0.0
			if attack == Attack.CHARGE:
				charge_cooldown = CHARGE_COOLDOWN
		Stage.RECOVER:
			var done := attack
			attack = Attack.NONE
			stage = Stage.TELEGRAPH
			if done == Attack.TEAR:
				pair = true
			_roam(per_phase(PAUSE, phase))
			finished.emit(done)


func _roam(pause: float) -> void:
	_pause = pause
	_enter(State.ROAM)


func _enter(next: State) -> void:
	var previous := state
	state = next
	_timer = 0.0
	state_changed.emit(previous, next)
