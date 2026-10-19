class_name Fatigue
extends RefCounted
## Tiredness over the night shift (pure logic, ticked by the player; plan
## docs/superpowers/plans/2026-10-10-kawiarnia-zmeczenie.md). The level
## (0..1) rises with the night's clock on a curve that accelerates after
## midnight (TIME_TOTAL over a whole night: time alone never fills the bar)
## and with exertion (sprint, dash); a rest in a haven brings it down.
## Below THRESHOLD nothing happens; above it the effects grow linearly to
## their caps: stamina capacity (the bar eaten from the right), stamina
## regen, a little weapon sway. A coffee takes a chunk off at once and
## leaves caffeine for a while (COFFEES): espresso short and strong, the
## large one long and weak (the night stands still), the witching special
## strongest, with shaking hands for a moment. A new coffee always takes its
## relief off, but its caffeine only takes over when it lasts longer than
## what is left of the old one's (a short espresso does not throw away a
## large coffee's last minutes). Saved with the guard (to_dict / from_dict).

## Seconds of a night (23:00 to 6:00).
const NIGHT_SECONDS := NightClock.HOURS * NightClock.SECONDS_PER_HOUR
## What a whole night's time alone adds, and the curve of its rate
## (level = TIME_TOTAL * fraction^TIME_CURVE).
const TIME_TOTAL := 0.6
const TIME_CURVE := 1.5
const SPRINT_PER_SEC := 0.0006
const DASH := 0.003
## Taken off per second of rest in a haven.
const REST_PER_SEC := 0.0015
## Below this level nothing happens.
const THRESHOLD := 0.35
## From this level on the guard is worn out (stage 2; the voice comments it).
const WORN_OUT := 0.6
## The effects at level 1.
const CAPACITY_LOSS := 0.30
const REGEN_LOSS := 0.35
const SWAY_GAIN := 1.0
## Seconds the hands shake after the witching special.
const JITTER_TIME := 12.0
## Kind -> relief at once, seconds of caffeine, regen bonus while it lasts,
## whether the level stands still, seconds of shaking hands.
const COFFEES := {
	&"espresso": {"relief": 0.30, "time": 90.0, "regen": 0.25, "block": false, "jitter": 0.0},
	&"large": {"relief": 0.15, "time": 240.0, "regen": 0.10, "block": true, "jitter": 0.0},
	&"special": {"relief": 0.45, "time": 60.0, "regen": 0.40, "block": false, "jitter": JITTER_TIME},
}

var level: float = 0.0
## 0 at 23:00, 1 at dawn; the night's clock sets it (0 where no clock runs).
var night_fraction: float = 0.0
## The coffee whose caffeine still lasts (&"" for none) and its seconds left.
var buff: StringName = &""
var buff_left: float = 0.0
var jitter_left: float = 0.0
## The stage last told (take_rise()).
var _told: int = 0


## The rate of the time component at [param fraction] of the night (per second).
static func time_rate(fraction: float) -> float:
	var x := clampf(fraction, 0.0, 1.0)
	return TIME_TOTAL * TIME_CURVE * pow(x, TIME_CURVE - 1.0) / NIGHT_SECONDS


## One frame: the caffeine runs down, the night and a sprint add (unless the
## large coffee holds the level still), a rest in a haven takes off.
func tick(delta: float, sprinting: bool, resting: bool) -> void:
	if delta <= 0.0:
		return
	_tick_buff(delta)
	var rise := 0.0
	if not blocks_rise():
		rise = time_rate(night_fraction) * delta
		if sprinting:
			rise += SPRINT_PER_SEC * delta
	var fall := REST_PER_SEC * delta if resting else 0.0
	level = clampf(level + rise - fall, 0.0, 1.0)


func add_dash() -> void:
	if not blocks_rise():
		level = minf(level + DASH, 1.0)


## 0 below THRESHOLD, 1 at level 1: the strength of every effect.
func effect() -> float:
	return clampf((level - THRESHOLD) / (1.0 - THRESHOLD), 0.0, 1.0)


## 0 fresh, 1 tired (from THRESHOLD: the effects start), 2 worn out (WORN_OUT).
func stage() -> int:
	if level >= WORN_OUT:
		return 2
	return 1 if level >= THRESHOLD else 0


## The stage when it has risen since the last call (Player tells Events.fatigue_rose), else 0.
## A fall (a coffee, a rest) is not told, but the stage climbs back to be told again.
func take_rise() -> int:
	var now := stage()
	var risen := now if now > _told else 0
	_told = now
	return risen


## Share of the stamina bar still usable (1 down to 1 - CAPACITY_LOSS).
func capacity_factor() -> float:
	return 1.0 - CAPACITY_LOSS * effect()


## Multiplier of the stamina regen: slower when tired, faster on caffeine.
func regen_factor() -> float:
	var factor := 1.0 - REGEN_LOSS * effect()
	if caffeinated():
		factor *= 1.0 + float(COFFEES[buff]["regen"])
	return factor


## Multiplier of the weapon's bob: more when tired, twice while the hands shake.
func sway_factor() -> float:
	return (1.0 + SWAY_GAIN * effect()) * (1.0 + jitter())


## 1 right after the special, 0 once the hands are steady again.
func jitter() -> float:
	return clampf(jitter_left / JITTER_TIME, 0.0, 1.0)


func caffeinated() -> bool:
	return buff != &"" and buff_left > 0.0


## True while the large coffee holds the level still.
func blocks_rise() -> bool:
	return caffeinated() and bool(COFFEES[buff]["block"])


## Drinks a coffee of [param kind]. False for a drink the machine does not know.
func drink(kind: StringName) -> bool:
	if not COFFEES.has(kind):
		return false
	var coffee: Dictionary = COFFEES[kind]
	level = maxf(level - float(coffee["relief"]), 0.0)
	# the caffeine that lasts longer stays (the relief and the shakes always count)
	if not caffeinated() or float(coffee["time"]) >= buff_left:
		buff = kind
		buff_left = float(coffee["time"])
	jitter_left = float(coffee["jitter"])
	return true


## A fresh guard (a new night).
func reset() -> void:
	level = 0.0
	night_fraction = 0.0
	buff = &""
	buff_left = 0.0
	jitter_left = 0.0
	_told = 0


## For the save of a night in progress (the clock's fraction is the clock's).
func to_dict() -> Dictionary:
	return {"level": level, "buff": String(buff), "buff_left": buff_left, "jitter_left": jitter_left}


func from_dict(data: Dictionary) -> void:
	level = clampf(float(data.get("level", 0.0)), 0.0, 1.0)
	var kind := StringName(str(data.get("buff", "")))
	buff_left = maxf(float(data.get("buff_left", 0.0)), 0.0)
	buff = kind if COFFEES.has(kind) and buff_left > 0.0 else &""
	if buff == &"":
		buff_left = 0.0
	jitter_left = clampf(float(data.get("jitter_left", 0.0)), 0.0, JITTER_TIME)
	_told = stage()   # a resumed night does not announce the tiredness it brought back


func _tick_buff(delta: float) -> void:
	jitter_left = maxf(jitter_left - delta, 0.0)
	if buff == &"":
		return
	buff_left -= delta
	if buff_left <= 0.0:
		buff = &""
		buff_left = 0.0
