class_name OrreryBrain
extends RefCounted
## The Great Orrery (the Enlightenment wing's guardian, design 7.4) as pure
## logic: its states, the tiers' speeds, the attack it picks, the stages of
## each attack and how long they take in each phase, and every number of
## the fight in one table. The Planetarium node feeds it the guard's flat
## distance from the axis every physics frame, sets its tiers' drives to
## tier_target() and acts on its states and signals; the moves sample their
## clips at clip_time() and state_progress().
##
## DORMANT -(wake)-> WAKING -> IDLE <-> ATTACK (TELEGRAPH -> STRIKE ->
## RECOVER). The phases count the planets shot off (planet_lost): two gone
## -> phase 2, four -> phase 3, each a SHIFT (the tiers brake, the sun opens
## a notch, then turn the other way, faster) as soon as the attack under
## way is over; the sixth gone -> UNVEIL (the sun opens, its core bared:
## [member exposed]), the final turn of the screw (level 3). DEAD is final;
## reset() puts it to sleep whole.
##
## Attacks: SURGE (one tier speeds up - or turns round, from phase 2 - for
## a while: its lamps, its chime, the gears' clatter warn), LAUNCH (a
## planet leaves its socket for half an orbit round the hall and comes
## back), FLARE (phase 2+: the sun throws flares that arc onto the floor).

signal state_changed(from: State, to: State)
## The warning of [param attack] begins.
signal telegraphed(attack: Attack)
## [param attack]'s active part begins (the tier surges, the planet flies,
## the flares leave the sun).
signal struck(attack: Attack)
## [param attack] is over.
signal finished(attack: Attack)

enum State { DORMANT, WAKING, IDLE, ATTACK, SHIFT, UNVEIL, DEAD }
enum Attack { NONE, SURGE, LAUNCH, FLARE }
enum Stage { TELEGRAPH, STRIKE, RECOVER }

const PLANETS := 6
## Gears catch, the loop starts, the tiers start turning after WAKE_SPIN of
## it, the sun breathes, the planets light up one by one.
const WAKE_TIME := 3.0
const WAKE_SPIN := 0.25
## A phase's shift: the tiers brake for SHIFT_BRAKE of it (lamps, chimes:
## the warning), then spin up to the new phase's speeds.
const SHIFT_TIME := 2.4
const SHIFT_BRAKE := 0.55
## The sixth planet gone: the sun blooms open (its core bared at once).
const UNVEIL_TIME := 2.8
const UNVEIL_BRAKE := 0.5
## While braking the tiers idle at this share of the speed they had.
const BRAKE_SHARE := 0.15
## Before the first attack after waking, a shift or the unveil.
const FIRST_PAUSE := 0.8
## Between attacks, per level (phase 1, 2, 3, the bared sun).
const PAUSE: Array[float] = [2.0, 1.6, 1.3, 1.2]
## Next look when nothing could be picked.
const RETRY := 0.25

## Per attack, per level: [telegraph, strike, recover] (s). The telegraph
## is the warning (never under Guardian.MIN_TELEGRAPH).
const TIMES := {
	Attack.SURGE: [[1.1, 3.0, 1.2], [0.95, 3.2, 1.0], [0.85, 3.4, 0.9], [0.85, 3.4, 0.9]],
	Attack.LAUNCH: [[1.2, 6.5, 0.6], [1.1, 6.0, 0.6], [1.0, 5.5, 0.6], [1.0, 5.5, 0.6]],
	Attack.FLARE: [[1.3, 1.6, 0.8], [1.3, 1.6, 0.8], [1.1, 1.8, 0.8], [1.0, 1.9, 0.8]],
}

# --- the tiers ---------------------------------------------------------------------
## Cruise of each tier (low, mid, high) per level (rad/s; the sign is the
## way it turns: every phase turns them round, faster).
const CRUISE := [
	[0.75, -0.9, 1.05, -1.2],
	[-0.35, 0.45, -0.55, 0.6],
	[0.45, -0.55, 0.65, -0.75],
]
## How fast each tier's speed can change (rad/s²): heavy brass.
const RATE: Array[float] = [1.4, 0.9, 1.0]
## A surge: this many times its cruise, or (from phase 2, at REVERSE_CHANCE)
## turned round at REVERSE_FACTOR.
const SURGE_FACTOR := 2.4
const REVERSE_FACTOR := -1.8
const REVERSE_CHANCE := 0.5

# --- choice ---------------------------------------------------------------------------
## A guard nearer the axis than this is among the arms (surges weigh more);
## farther, the orbits and flares do.
const NEAR := 6.2
const WEIGHTS := {Attack.SURGE: 6.0, Attack.LAUNCH: 3.0, Attack.FLARE: 3.0}
## A surge far from the guard only keeps the hall's rhythm.
const FAR_SURGE := 1.5
const FAR_BONUS := 2.0
## The attack just used weighs this much less next time.
const REPEAT_FACTOR := 0.35
## Flares a FLARE throws, per level.
const FLARES: Array[int] = [0, 1, 3, 4]

var state: State = State.DORMANT
## 1..3 (the bared sun fights on in phase 3).
var phase: int = 1
## The sun is open, its core a weak point.
var exposed := false
var attack: Attack = Attack.NONE
var stage: Stage = Stage.TELEGRAPH
## Which planets are still on their arms (shot off = false).
var planets_on: Array[bool] = [true, true, true, true, true, true]
## The tier of the SURGE under way, and its factor on that tier's cruise.
var surge_tier: int = 0
var surge_factor: float = SURGE_FACTOR
## The planet of the LAUNCH under way (-1: none).
var launch_planet: int = -1
var rng := RandomNumberGenerator.new()

var _timer: float = 0.0
var _stage_timer: float = 0.0
var _pause: float = 0.0
## The level whose cruise the tiers follow now (the old one while braking).
var _cruise_level: int = 0
var _pending_shift := false
var _pending_unveil := false
var _history: Array[Attack] = []
var _last_planet: int = -1
## The guard's distance from the axis given last.
var _distance: float = INF


func seed_with(value: int) -> void:
	rng.seed = value


## Length of [param at] stage of [param kind] at [param in_level] (0..3).
static func stage_length(kind: Attack, at: Stage, in_level: int) -> float:
	var table: Array = TIMES.get(kind, [])
	if table.is_empty():
		return 0.0
	var row: Array = table[clampi(in_level, 0, table.size() - 1)]
	return float(row[int(at)])


## 0, 1, 2 for phases 1-3; 3 once the sun is bared.
func level() -> int:
	return 3 if exposed else clampi(phase - 1, 0, 2)


func planets_left() -> int:
	return planets_on.count(true)


func wake() -> void:
	if state == State.DORMANT:
		_enter(State.WAKING)


func die() -> void:
	if state != State.DEAD:
		attack = Attack.NONE
		_enter(State.DEAD)


## Asleep and whole again (the guard fled): every planet on its arm.
func reset() -> void:
	phase = 1
	exposed = false
	attack = Attack.NONE
	stage = Stage.TELEGRAPH
	launch_planet = -1
	_last_planet = -1
	_cruise_level = 0
	_pending_shift = false
	_pending_unveil = false
	_history.clear()
	for i in PLANETS:
		planets_on[i] = true
	_enter(State.DORMANT)


## Planet [param planet] was shot off: the phases count it; a LAUNCH of it
## ends (its orbit has nothing to carry).
func planet_lost(planet: int) -> void:
	if not planets_on[planet] or state == State.DEAD:
		return
	planets_on[planet] = false
	var lost := PLANETS - planets_left()
	var next := 1 + mini(lost / 2, 2)
	if next > phase:
		phase = next
		_pending_shift = true
	if lost >= PLANETS:
		_pending_unveil = true
	if state == State.ATTACK and attack == Attack.LAUNCH and launch_planet == planet and stage != Stage.RECOVER:
		stage = Stage.RECOVER
		_stage_timer = 0.0
	if state == State.IDLE:
		_follow_up()


## Starts [param kind] at once (dev arena, scenarios, tests).
func force_attack(kind: Attack) -> void:
	if state == State.DEAD or state == State.DORMANT:
		return
	if kind == Attack.LAUNCH and _free_planets().is_empty():
		return
	_start(kind)


func is_awake() -> bool:
	return state != State.DORMANT and state != State.DEAD


func state_time() -> float:
	return _timer


func stage_time() -> float:
	return _stage_timer


## 0..1 through the current state (WAKING, SHIFT, UNVEIL).
func state_progress() -> float:
	match state:
		State.WAKING:
			return clampf(_timer / WAKE_TIME, 0.0, 1.0)
		State.SHIFT:
			return clampf(_timer / SHIFT_TIME, 0.0, 1.0)
		State.UNVEIL:
			return clampf(_timer / UNVEIL_TIME, 0.0, 1.0)
	return 0.0


## Where the attack's clip stands: 0..1 telegraph, 1..2 strike, 2..3
## recovery.
func clip_time() -> float:
	if state != State.ATTACK:
		return 0.0
	var length := stage_length(attack, stage, level())
	return float(int(stage)) + (clampf(_stage_timer / length, 0.0, 1.0) if length > 0.0 else 1.0)


## The speed [param tier]'s drive should turn at now (rad/s).
func tier_target(tier: int) -> float:
	match state:
		State.DORMANT, State.DEAD:
			return 0.0
		State.WAKING:
			return 0.0 if state_progress() < WAKE_SPIN else _cruise(tier, _cruise_level)
		State.SHIFT, State.UNVEIL:
			var brake := SHIFT_BRAKE if state == State.SHIFT else UNVEIL_BRAKE
			if state_progress() < brake:
				return _cruise(tier, _cruise_level) * BRAKE_SHARE
			return _cruise(tier, level())
		State.ATTACK:
			if attack == Attack.SURGE and stage == Stage.STRIKE and tier == surge_tier:
				return _cruise(tier, _cruise_level) * surge_factor
	return _cruise(tier, _cruise_level)


func update(delta: float, distance: float) -> void:
	if state == State.DORMANT or state == State.DEAD:
		return
	_timer += delta
	_distance = distance
	match state:
		State.WAKING:
			if _timer >= WAKE_TIME:
				_idle(FIRST_PAUSE)
				_follow_up()   # planets shot off before it woke (a shot from afar)
		State.SHIFT:
			if _timer >= SHIFT_TIME:
				_pending_shift = false
				_cruise_level = level()
				_idle(FIRST_PAUSE)
				_follow_up()
		State.UNVEIL:
			if _timer >= UNVEIL_TIME:
				_pending_unveil = false
				_cruise_level = level()
				_idle(FIRST_PAUSE)
		State.IDLE:
			_pause -= delta
			if _pause <= 0.0:
				var picked := choose(distance)
				if picked == Attack.NONE:
					_pause = RETRY
				else:
					_start(picked)
		State.ATTACK:
			_stage_timer += delta
			if _stage_timer >= stage_length(attack, stage, level()):
				_next_stage()


## The attack it would pick now for a guard [param distance] m from its
## axis (NONE when nothing can be done). Rolls the dice.
func choose(distance: float) -> Attack:
	if is_inf(distance):
		return Attack.NONE
	var near := distance < NEAR
	var weights := {}
	weights[Attack.SURGE] = WEIGHTS[Attack.SURGE] if near else FAR_SURGE
	if not _free_planets().is_empty():
		weights[Attack.LAUNCH] = WEIGHTS[Attack.LAUNCH] + (0.0 if near else FAR_BONUS)
	if FLARES[level()] > 0:
		weights[Attack.FLARE] = WEIGHTS[Attack.FLARE] + (0.0 if near else FAR_BONUS)
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


## How many flares a FLARE throws now.
func flare_count() -> int:
	return FLARES[level()]


func _cruise(tier: int, at_level: int) -> float:
	return float(CRUISE[tier][clampi(at_level, 0, 3)])


## Planets on their arms that may fly.
func _free_planets() -> Array[int]:
	var out: Array[int] = []
	for i in PLANETS:
		if planets_on[i]:
			out.append(i)
	return out


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
		Attack.SURGE:
			_pick_surge()
		Attack.LAUNCH:
			_pick_planet()
	_enter(State.ATTACK)
	telegraphed.emit(kind)


## The tier to surge (those whose arms reach the guard weigh more) and how.
func _pick_surge() -> void:
	var weights: Array[float] = []
	var total := 0.0
	for tier in 3:
		var reaching := _distance <= OrreryGeometry.REACH[tier] + 1.2
		weights.append(3.0 if reaching else 1.0)
		total += weights[tier]
	var roll := rng.randf() * total
	surge_tier = 2
	for tier in 3:
		roll -= weights[tier]
		if roll <= 0.0:
			surge_tier = tier
			break
	surge_factor = SURGE_FACTOR
	if phase >= 2 and rng.randf() < REVERSE_CHANCE:
		surge_factor = REVERSE_FACTOR


func _pick_planet() -> void:
	var free := _free_planets()
	if free.size() > 1:
		free.erase(_last_planet)
	launch_planet = free[rng.randi_range(0, free.size() - 1)]
	_last_planet = launch_planet


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
			launch_planet = -1
			_idle(PAUSE[level()])
			finished.emit(done)
			_follow_up()


## A pending unveil or shift starts as soon as nothing is under way.
func _follow_up() -> void:
	if state != State.IDLE:
		return
	if _pending_unveil:
		_pending_shift = false
		exposed = true
		_enter(State.UNVEIL)
	elif _pending_shift:
		_enter(State.SHIFT)


func _idle(pause: float) -> void:
	_pause = pause
	_enter(State.IDLE)


func _enter(next: State) -> void:
	var previous := state
	state = next
	_timer = 0.0
	state_changed.emit(previous, next)
