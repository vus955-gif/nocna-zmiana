class_name SerpentBrain
extends RefCounted
## The Two-headed Serpent (the Americas' wing guardian, design 7.4; plan
## docs/superpowers/plans/2026-10-03-straznik-waz.md) as pure logic: its
## states, the attack it picks and from which end, the stages of each
## attack and their lengths per phase, the phases, which head leads the
## glide and which head glows - and every number of the fight in one table.
## The Serpent node feeds it what it sees every physics frame (Sight: the
## guard's distance and bearing from the spitting head and from the biting
## one, his distance from the tail's root, whether he keeps nearer the tail
## than the leading head) and acts on its states and signals; the moves
## sample their clips at clip_time() (0..1 warning, 1..2 strike, 2..3
## recovery), as the Colossus's and the Centaur's do.
##
## DORMANT -(wake)-> WAKING (eyes, the rattle, the heads rise) -> ROAM
## (gliding its tracks) <-> ATTACK (TELEGRAPH -> STRIKE -> RECOVER): the
## glowing head SPITs turquoise at a distance, the other head LUNGEs up
## close, the trailing tail SWEEPs whoever stands by it. The guard keeping
## to its tail makes it turn round (reverse(): the other head leads).
## Phase 2 (< 66 %): once the attack under way is over, PHASE_SHIFT - the
## heads turn to each other and the light passes to the other head (the
## roles swap), then it glides faster. Phase 3 (< 33 %): ENCIRCLE - it
## slides onto the ring round the altar's terrace (the node says when it
## is there: encircled()), then RING - both heads fight from the gate, no
## sweep, no turning. DEAD is final; reset() puts it back to sleep.
##
## Bearings: the guard's angle from a head's look (rad, absolute).

signal state_changed(from: State, to: State)
## The warning of [param attack] begins.
signal telegraphed(attack: Attack)
## [param attack] lands (the shards leave, the head strikes, the tail
## comes round).
signal struck(attack: Attack)
## [param attack] is over.
signal finished(attack: Attack)
## The other head leads the glide now.
signal reversed
## Phase 2's light passed to the other head: the roles swapped.
signal roles_swapped

enum State { DORMANT, WAKING, ROAM, ATTACK, PHASE_SHIFT, ENCIRCLE, RING, DEAD }
enum Attack { NONE, SPIT, LUNGE, SWEEP }
enum Stage { TELEGRAPH, STRIKE, RECOVER }


## What the Serpent node sees this frame.
class Sight:
	extends RefCounted
	## The guard's distance (m) and bearing (rad, absolute, from the head's
	## look) from the spitting head.
	var spit_distance: float = INF
	var spit_bearing: float = 0.0
	## The same from the biting head.
	var bite_distance: float = INF
	var bite_bearing: float = 0.0
	## The guard's distance from the trailing tail's root (m).
	var tail_distance: float = INF
	## True while the guard is nearer the trailing end than the leading one.
	var nearer_tail: bool = false


## The eyes light, the plates rattle, both heads rise from the steps.
const WAKE_TIME := 2.8
## Before the first attack after waking or reaching the ring.
const FIRST_PAUSE := 1.2
## Between attacks, per phase.
const PAUSE: Array[float] = [1.6, 1.3, 1.1]
## Next look when nothing could be picked.
const RETRY := 0.2
## Phase 2: the heads turn to each other, the light runs down the body.
const SHIFT_TIME := 2.0

## Per attack, per phase: [telegraph, strike, recover] (s). The telegraph
## is the warning (never under Guardian.MIN_TELEGRAPH): the spitting head
## rears and its mouth glows, the biting head draws back in an S and
## hisses, the tail's plates rattle and lift; the strike is the shards'
## leaving, the lunge, the sweep coming round.
const TIMES := {
	Attack.SPIT: [[0.7, 0.4, 0.6], [0.7, 0.4, 0.55], [0.65, 0.4, 0.5]],
	Attack.LUNGE: [[0.7, 0.22, 1.4], [0.7, 0.22, 1.3], [0.65, 0.22, 1.2]],
	Attack.SWEEP: [[0.9, 0.55, 0.8], [0.85, 0.55, 0.75], [0.8, 0.55, 0.7]],
}

# --- moving (m/s) ---------------------------------------------------------------
## The glide, per phase (the guard walks 5, sprints 8.5).
const SPEED: Array[float] = [2.6, 3.6, 2.0]
## The slide to the ring (phase 3).
const SLIDE_SPEED := 4.5
## The spitting head keeps gliding at this share of the pace.
const SPIT_GLIDE := 0.5
## The lunge carries the body forward this far over its strike (m).
const LUNGE_SLIDE := 1.5

# --- reach (m from a head's pivot or the tail's root, rad from its look) -------
const SPIT_RANGE := Vector2(5.0, 18.0)
const SPIT_ARC := 1.75
const LUNGE_RANGE := 6.0
const LUNGE_ARC := 1.4
const SWEEP_RANGE := 5.0

# --- choice ------------------------------------------------------------------------
const SPIT_WEIGHT := 3.0
const LUNGE_WEIGHT := 4.0
const SWEEP_WEIGHT := 3.0
## The attack just used weighs this much less next time.
const REPEAT_FACTOR := 0.35
## The guard nearer the tail for this long: the other head leads.
const REVERSE_AFTER := 2.5
const REVERSE_COOLDOWN := 6.0

# --- the fight's numbers (the node deals them) -------------------------------------
## Shards per spit, per phase; each one's damage, the splash where it
## bursts (damage within the radius), their flight (s: longer throws fly
## longer).
const SHARDS: Array[int] = [3, 4, 5]
const SHARD_DAMAGE := 12.0
const SPLASH_DAMAGE := 10.0
const SPLASH_RADIUS := 1.1
const SHARD_FLIGHT := Vector2(0.7, 1.2)
## The lunge: damage, knockback, its lane's width (m).
const LUNGE_DAMAGE := 30.0
const LUNGE_KNOCKBACK := 12.0
const LUNGE_WIDTH := 1.4
## The sweep: damage, knockback; a guard this high off the floor is over it.
const SWEEP_DAMAGE := 22.0
const SWEEP_KNOCKBACK := 9.0
const SWEEP_JUMP := 0.45
## A segment's mosaic plate falls off after this much raw damage; a plated
## segment takes this share of a hit, a bare one all of it.
const PLATE_HEALTH := 30.0
const PLATE_FACTOR := 0.1
const BARE_FACTOR := 1.0
## The biting head counts this much more while it hangs out after a lunge.
const LUNGE_RECOVER_WEAK := 1.5
## The ring's arches: height (m), half width (m), how they travel (m/s).
const ARCH_HEIGHT := 1.3
const ARCH_HALF_WIDTH := 2.4
const ARCH_SPEED := 2.0

var state: State = State.DORMANT
var phase: int = 1
var attack: Attack = Attack.NONE
var stage: Stage = Stage.TELEGRAPH
## The head that leads the glide.
var lead: SerpentBody.End = SerpentBody.End.A
## The head that glows and spits; the other bites.
var spitter: SerpentBody.End = SerpentBody.End.A
var rng := RandomNumberGenerator.new()

var _timer: float = 0.0
var _stage_timer: float = 0.0
var _pause: float = 0.0
var _toward_tail: float = 0.0
var _reverse_cooldown: float = 0.0
var _pending_shift := false
var _pending_ring := false
var _ring_done := false
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


## Asleep again (the guard fled): phase 1, head A leads and glows.
func reset() -> void:
	phase = 1
	attack = Attack.NONE
	stage = Stage.TELEGRAPH
	lead = SerpentBody.End.A
	spitter = SerpentBody.End.A
	_toward_tail = 0.0
	_reverse_cooldown = 0.0
	_pending_shift = false
	_pending_ring = false
	_history.clear()
	_enter(State.DORMANT)


## Health crossed into [param next] (2 or 3): the light passes and the
## ring waits for the attack under way.
func set_phase(next: int) -> void:
	if next <= phase or state == State.DEAD:
		return
	if phase < 2 and next >= 2:
		_pending_shift = true
	if next >= 3:
		_pending_ring = true
	phase = next
	_pause = minf(_pause, 0.3)


## Starts [param kind] at once (dev arena, scenarios, tests).
func force_attack(kind: Attack) -> void:
	if state == State.DEAD or state == State.DORMANT or state == State.WAKING:
		return
	_start(kind)


## The other head leads from now (the node turns the body round).
func reverse() -> void:
	lead = SerpentBody.End.B if lead == SerpentBody.End.A else SerpentBody.End.A
	_toward_tail = 0.0
	_reverse_cooldown = REVERSE_COOLDOWN
	reversed.emit()


## The body lies on the ring (the node): it fights from the gate now.
func encircled() -> void:
	if state == State.ENCIRCLE:
		_pause = FIRST_PAUSE
		_enter(State.RING)


func is_awake() -> bool:
	return state != State.DORMANT and state != State.DEAD


## The head that bites (the one that does not glow).
func biter() -> SerpentBody.End:
	return SerpentBody.End.B if spitter == SerpentBody.End.A else SerpentBody.End.A


## The trailing end (its head follows; its neck is the sweeping tail).
func trailer() -> SerpentBody.End:
	return SerpentBody.End.B if lead == SerpentBody.End.A else SerpentBody.End.A


## Which end performs the attack under way (the spit's head, the lunge's
## head, the sweep's tail).
func attack_end() -> SerpentBody.End:
	match attack:
		Attack.SPIT:
			return spitter
		Attack.LUNGE:
			return biter()
		Attack.SWEEP:
			return trailer()
	return lead


## Seconds in the current state.
func state_time() -> float:
	return _timer


## Seconds in the current stage of the attack.
func stage_time() -> float:
	return _stage_timer


## 0..1 through WAKING or PHASE_SHIFT.
func state_progress() -> float:
	match state:
		State.WAKING:
			return clampf(_timer / WAKE_TIME, 0.0, 1.0)
		State.PHASE_SHIFT:
			return clampf(_timer / SHIFT_TIME, 0.0, 1.0)
	return 0.0


## Where the attack's clip stands: 0..1 telegraph, 1..2 strike, 2..3
## recovery.
func clip_time() -> float:
	if state != State.ATTACK:
		return 0.0
	var length := stage_length(attack, stage, phase)
	return float(int(stage)) + (clampf(_stage_timer / length, 0.0, 1.0) if length > 0.0 else 1.0)


## How fast the leader means to glide now (m/s): its pace while roaming
## (half of it while the head spits), the slide to the ring, nothing while
## it coils, sweeps, passes the light or lies in the ring.
func wanted_speed() -> float:
	match state:
		State.ROAM:
			return per_phase(SPEED, phase)
		State.ATTACK:
			if attack == Attack.SPIT:
				return per_phase(SPEED, phase) * SPIT_GLIDE
			return 0.0
		State.ENCIRCLE:
			return SLIDE_SPEED
	return 0.0


## The multiplier of head [param end]'s weak point now.
func weak_factor(end: SerpentBody.End) -> float:
	if state == State.ATTACK and attack == Attack.LUNGE and stage == Stage.RECOVER and end == biter():
		return LUNGE_RECOVER_WEAK
	return 1.0


func update(delta: float, sight: Sight) -> void:
	if state == State.DORMANT or state == State.DEAD:
		return
	_timer += delta
	_reverse_cooldown = maxf(_reverse_cooldown - delta, 0.0)
	match state:
		State.WAKING:
			if _timer >= WAKE_TIME:
				_roam(FIRST_PAUSE)
		State.PHASE_SHIFT:
			if _timer >= SHIFT_TIME:
				spitter = biter()
				roles_swapped.emit()
				if _pending_ring:
					_pending_ring = false
					_enter(State.ENCIRCLE)
				else:
					_roam(0.6)
		State.ROAM:
			if _pending_shift:
				_pending_shift = false
				_enter(State.PHASE_SHIFT)
				return
			if _pending_ring:
				_pending_ring = false
				_enter(State.ENCIRCLE)
				return
			_turning(delta, sight, true)
			if state != State.ROAM:
				return
			_pause -= delta
			if _pause <= 0.0:
				var picked := choose(sight)
				if picked == Attack.NONE:
					_pause = RETRY
				else:
					_start(picked)
		State.RING:
			_pause -= delta
			if _pause <= 0.0:
				var picked := choose(sight)
				if picked == Attack.NONE:
					_pause = RETRY
				else:
					_start(picked)
		State.ATTACK:
			_turning(delta, sight, false)
			_stage_timer += delta
			if _stage_timer >= stage_length(attack, stage, phase):
				_next_stage()


## The guard keeping nearer the tail: after a while the other head leads
## (counted through an attack too, turned only between them).
func _turning(delta: float, sight: Sight, may_turn: bool) -> void:
	if sight.nearer_tail:
		_toward_tail += delta
	else:
		_toward_tail = maxf(_toward_tail - delta * 2.0, 0.0)
	if may_turn and _toward_tail >= REVERSE_AFTER and _reverse_cooldown <= 0.0:
		reverse()


## The attack it would pick now (NONE when nothing fits). Rolls the dice.
func choose(sight: Sight) -> Attack:
	var weights := {}
	if sight.bite_distance <= LUNGE_RANGE and sight.bite_bearing <= LUNGE_ARC:
		weights[Attack.LUNGE] = LUNGE_WEIGHT
	if sight.spit_distance >= SPIT_RANGE.x and sight.spit_distance <= SPIT_RANGE.y and sight.spit_bearing <= SPIT_ARC:
		weights[Attack.SPIT] = SPIT_WEIGHT
	if state != State.RING and sight.tail_distance <= SWEEP_RANGE:
		weights[Attack.SWEEP] = SWEEP_WEIGHT
	if weights.is_empty():
		return Attack.NONE
	# up close the bite comes first, whatever else fits
	if weights.has(Attack.LUNGE) and _allowed(Attack.LUNGE) and sight.bite_distance <= LUNGE_RANGE * 0.6:
		return Attack.LUNGE
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
			if _pending_shift:
				_pending_shift = false
				_enter(State.PHASE_SHIFT)
			elif _pending_ring:
				_pending_ring = false
				_enter(State.ENCIRCLE)
			else:
				_pause = per_phase(PAUSE, phase)
				_enter(State.RING if in_ring() else State.ROAM)
			finished.emit(done)


## True when the fight goes on from the ring (phase 3, encircled): the
## body lies still on it, attacks come from the gate.
func in_ring() -> bool:
	return _ring_done


func _roam(pause: float) -> void:
	_pause = pause
	_enter(State.ROAM)


func _enter(next: State) -> void:
	var previous := state
	state = next
	_timer = 0.0
	if next == State.RING:
		_ring_done = true
	elif next == State.DORMANT or next == State.ENCIRCLE or next == State.WAKING:
		_ring_done = false
	state_changed.emit(previous, next)
