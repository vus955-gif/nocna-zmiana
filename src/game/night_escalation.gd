class_name NightEscalation
extends RefCounted
## The night's curve (plan 2026-10-21-eskalacja-nocy, backlog #34): the
## night starts quiet and strange and ends overrun. Read off the night's
## clock (NightClock: seconds since 23:00), pure:
## - CALM 23:00-1:00: ambiguous little things, minutes apart,
## - UNEASY 1:00-3:00: things that cannot be shrugged off; the noises next
##   door carry to the exhibits,
## - WITCHING 3:00-5:00: the witching hour (NightWatch: exhibits x1.2);
##   lamps die for seconds, rooms go dark,
## - PREDAWN 5:00-6:00: the museum is overrun until dawn.
## The UncannyDirector asks it how long to wait for the next event of the
## ambient pool (gap()), how likely a room left behind changes
## (change_scale()) and how far its noises carry to the exhibits
## (noise_scale(): only through the perception's own noise bus, so the
## ecology's limits hold). intensity() is the curve as one number for
## whoever wants it (music, ambience, biome devices).

enum Phase { CALM, UNEASY, WITCHING, PREDAWN }

const PHASES: Array[int] = [Phase.CALM, Phase.UNEASY, Phase.WITCHING, Phase.PREDAWN]
const NAMES: Array[StringName] = [&"calm", &"uneasy", &"witching", &"predawn"]
## Hours after 23:00 at which each phase begins (1:00, 3:00 = the witching
## hour, 5:00).
const STARTS: Array[int] = [0, 2, NightClock.WITCHING_AFTER, 6]
## Seconds between two events of the ambient pool, [shortest, longest], per
## phase (on nights 2-3 without a modifier).
const GAPS: Array[Vector2] = [Vector2(100.0, 160.0), Vector2(70.0, 110.0), Vector2(45.0, 75.0), Vector2(28.0, 45.0)]
## The intensity at the start of each phase and at dawn (linear between).
const LEVELS: Array[float] = [0.1, 0.35, 0.65, 0.9, 1.0]
## A room left behind changes with its event's chance times this.
const CHANGE_SCALE: Array[float] = [0.5, 0.8, 1.0, 1.0]
## The ambient noises reach the exhibits this many times their radius
## (0: the calm start wakes nobody).
const NOISE_SCALE: Array[float] = [0.0, 0.8, 1.0, 1.2]
## Night 1 learns (gaps this much longer); from FAST_NIGHT on they shorten.
const FIRST_NIGHT := 1.35
const FAST_NIGHT := 4
const FAST := 0.85
## The modifier's share of the gaps (a calm night is calm).
const MODIFIER_GAP := {&"calm": 1.3, &"full_moon": 0.9}
## Seconds of a night before its first ambient event (times the night's and
## the modifier's factor).
const FIRST_WAIT := 45.0


static func phase_at(elapsed: float) -> int:
	var phase := Phase.CALM
	for candidate in PHASES:
		if elapsed >= phase_start(candidate):
			phase = candidate
	return phase


## Seconds after 23:00 at which [param phase] begins.
static func phase_start(phase: int) -> float:
	return STARTS[clampi(phase, 0, STARTS.size() - 1)] * NightClock.SECONDS_PER_HOUR


static func phase_name(phase: int) -> StringName:
	return NAMES[clampi(phase, 0, NAMES.size() - 1)]


## 0..1: LEVELS[phase] at its start rising linearly to the next phase's
## level (the last phase to 1.0 at dawn).
static func intensity(elapsed: float) -> float:
	var t := clampf(elapsed, 0.0, NightClock.seconds_to_dawn())
	var phase := phase_at(t)
	var start := phase_start(phase)
	var end := phase_start(phase + 1) if phase + 1 < PHASES.size() else NightClock.seconds_to_dawn()
	var along := clampf((t - start) / maxf(end - start, 1.0), 0.0, 1.0)
	return lerpf(LEVELS[phase], LEVELS[phase + 1], along)


## The night's and the modifier's factor on the gaps.
static func gap_factor(night: int, modifier: StringName) -> float:
	var factor := 1.0
	if night <= 1:
		factor = FIRST_NIGHT
	elif night >= FAST_NIGHT:
		factor = FAST
	return factor * float(MODIFIER_GAP.get(modifier, 1.0))


## Seconds until the next ambient event in [param phase]: [param roll]
## (0..1, the director's generator) picks within the phase's range.
static func gap(phase: int, night: int, modifier: StringName, roll: float) -> float:
	var span: Vector2 = GAPS[clampi(phase, 0, GAPS.size() - 1)]
	return lerpf(span.x, span.y, clampf(roll, 0.0, 1.0)) * gap_factor(night, modifier)


## Seconds of a fresh night before its first ambient event.
static func first_wait(night: int, modifier: StringName) -> float:
	return FIRST_WAIT * gap_factor(night, modifier)


static func change_scale(phase: int) -> float:
	return CHANGE_SCALE[clampi(phase, 0, CHANGE_SCALE.size() - 1)]


static func noise_scale(phase: int) -> float:
	return NOISE_SCALE[clampi(phase, 0, NOISE_SCALE.size() - 1)]
