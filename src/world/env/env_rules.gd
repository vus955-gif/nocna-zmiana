class_name EnvRules
## The rules of the museum's reactive environment and of its tools (plan
## docs/superpowers/plans/2026-10-21-srodowisko-walka.md, backlog #22, #23,
## #39). Pure numbers; the props (EnvProp and its kinds) and the tools
## (EnvTool) play them:
## - glass and ceramics break to any real hit (a taser's arc only crackles,
##   a burning tick does nothing),
## - a bare bulb bursts at once; a hanging lamp swings, and falls once it has
##   taken its fixture's share of damage, to a crushing hit or a blast,
## - a bust topples off its plinth to a heavy hit, a blast or enough small ones,
## - a painting tilts on its nail with every hit and slips off past
##   PAINTING_FALL_TILT (or to a crushing hit, a blast),
## - a banner tears down after BANNER_HITS hits, to fire, a crushing hit or
##   a blast,
## - a tool goes off when its tag is hit by anything, by a blast beside it,
##   or once its body has taken TOOL_BODY_HP,
## - whatever can hurt is warned for (creak, shake, a mark on the floor) at
##   least MIN_WARNING seconds - the game's telegraph rule,
## - the guard in the way of his own tool takes what his own blast would
##   (Blast.GUARD_FLOOR: never below half his health),
## - what broke stays broken for the night (RunState.used, USED_PREFIX).

## The game's telegraph rule (>= 0.6 s), a tool's creak and a prop's.
const MIN_WARNING := 0.6
const TOOL_WARNING := 1.0
const PROP_WARNING := 0.7
## Hit weights (HitFeel): heavy topples a bust, crushing brings a lamp, a
## painting or a banner down at once.
const HEAVY := HitFeel.HEAVY_WEIGHT
const CRUSHING := HitFeel.STAGGER_WEIGHT
## Damage a hanging lamp takes before it falls, by its fixture (a bulb
## bursts: lamp_bursts()).
const LAMP_HP := {&"bulb": 1.0, &"ceiling_lamp": 30.0, &"lantern": 18.0}
const DEFAULT_LAMP_HP := 30.0
## A swing's start (rad/s) for the lightest and the heaviest hit, and the cap.
const SWING_LIGHT := 0.35
const SWING_HEAVY := 2.2
const MAX_SWING := 2.6
## Damage that knocks a bust off by small hits.
const BUST_HP := 40.0
## A painting's tilt (degrees) per hit, lightest to heaviest, and where it slips.
const TILT_LIGHT := 4.0
const TILT_HEAVY := 16.0
const PAINTING_FALL_TILT := 22.0
const BANNER_HITS := 3
## Damage the body of a tool (not its tag) takes before it goes off.
const TOOL_BODY_HP := 60.0
## The guard's own tool never takes him below this share of his health.
const GUARD_FLOOR := Blast.GUARD_FLOOR
## Pages a book shelf sheds: the lightest hit, a heavy one's extra, the cap.
const PAGES_LIGHT := 2
const PAGES_HEAVY := 9
const MAX_PAGES_PER_HIT := 14
## How far (m) the noises carry: glass, a ceramic, a small fall (a lamp, a
## bust, a painting) and a tool's crash.
const NOISE_GLASS := 14.0
const NOISE_CERAMIC := 10.0
const NOISE_FALL := 9.0
const NOISE_CRASH := 22.0
## Props in motion at once (swinging, tilting, warning, falling); the oldest
## swing settles at once to make room. Props on the floor, and their hit
## zones (static areas: a case's or a bust's are anchored on four sides).
const ACTIVE_CAP := 16
const MAX_PROPS := 420
const MAX_ZONES := 640
## Debris pieces one break adds (Fx's own cap keeps the total).
const MAX_PIECES_PER_BREAK := 8
## RunState.used ids of what broke tonight.
const USED_PREFIX := "env:"


## The weight (0..1) of [param info] on a prop: the hit's own (HitFeel), a
## blast at least CRUSHING.
static func weight(info: DamageInfo) -> float:
	if info == null:
		return 0.0
	var w := HitFeel.weight(info)
	return maxf(w, CRUSHING) if info.explosive else w


## True for a hit that does anything to a prop at all (no burning tick, no
## empty hit).
static func real(info: DamageInfo) -> bool:
	return info != null and not info.periodic and (info.amount > 0.0 or info.explosive)


static func breaks_glass(info: DamageInfo) -> bool:
	if not real(info):
		return false
	return info.explosive or info.kind != DamageInfo.Kind.ELECTRIC


## A bare bulb has nothing to fall with: it bursts.
static func lamp_bursts(fixture: StringName) -> bool:
	return fixture == &"bulb"


## True when a lamp of [param fixture] that has taken [param total] so far
## (this hit included) comes down.
static func lamp_falls(fixture: StringName, total: float, info: DamageInfo) -> bool:
	if not real(info):
		return false
	if info.explosive or weight(info) >= CRUSHING:
		return true
	return total >= float(LAMP_HP.get(fixture, DEFAULT_LAMP_HP))


## The swing's start (rad/s) a hit gives a hanging lamp.
static func swing_speed(info: DamageInfo) -> float:
	return minf(lerpf(SWING_LIGHT, SWING_HEAVY, weight(info)), MAX_SWING)


static func bust_topples(total: float, info: DamageInfo) -> bool:
	if not real(info):
		return false
	return info.explosive or weight(info) >= HEAVY or total >= BUST_HP


## The tilt (degrees, unsigned) a hit gives a painting.
static func painting_tilt(info: DamageInfo) -> float:
	return lerpf(TILT_LIGHT, TILT_HEAVY, weight(info))


static func painting_falls(tilt: float, info: DamageInfo) -> bool:
	if not real(info):
		return false
	return info.explosive or weight(info) >= CRUSHING or absf(tilt) >= PAINTING_FALL_TILT


## [param hits] counts this one.
static func banner_falls(hits: int, info: DamageInfo) -> bool:
	if not real(info):
		return false
	return info.explosive or info.kind == DamageInfo.Kind.FIRE or weight(info) >= CRUSHING or hits >= BANNER_HITS


static func pages_for(info: DamageInfo) -> int:
	if not real(info):
		return 0
	return mini(PAGES_LIGHT + int(round(PAGES_HEAVY * weight(info))), MAX_PAGES_PER_HIT)


## True when a tool goes off: [param on_tag] its tag was hit, [param body]
## damage its body has taken so far (this hit included).
static func tool_triggered(on_tag: bool, body: float, info: DamageInfo) -> bool:
	if not real(info):
		return false
	return on_tag or info.explosive or body >= TOOL_BODY_HP


## What the guard with [param health] of [param max_health] takes of
## [param amount]: set off by himself ([param by_guard]) as from his own
## blast, never below GUARD_FLOOR of his health.
static func guard_damage(health: float, max_health: float, amount: float, by_guard: bool) -> float:
	if not by_guard:
		return amount
	return clampf(health - max_health * GUARD_FLOOR, 0.0, amount)


static func used_id(id: StringName) -> StringName:
	return StringName(USED_PREFIX + String(id))
