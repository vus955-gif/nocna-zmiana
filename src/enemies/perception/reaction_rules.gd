class_name ReactionRules
extends RefCounted
## How exhibits answer what happens round them (backlog #24): a shot, a
## sprinting guard, broken glass, a blast, a fallen exhibit, a door that
## opened. Pure logic; PerceptionWorld feeds in the noise's source, each
## listener's profile (EnemyRoles) and how close the noise was, and applies
## the answers. Graded, never a horde:
## - LOOK: it turns its head to the noise and settles again (SUSPICIOUS
##   without following),
## - INVESTIGATE: it goes to look (never a hunt: it hunts only what it sees),
## - FLEE: it runs from the point, then goes home (the skittish, from a
##   blast),
## - at most INVESTIGATE_CAP listeners investigate one event (the nearest
##   first); at a plain noise (a shot, a step, glass, a blast) the nearest
##   curious one always does, so a lone listener still comes to look - not
##   at a door or a fall, which send nobody whatever the dice say (a knight
##   within earshot of any door would walk over every time); everyone else
##   only turns its head. PerceptionWorld spends the cap over a stretch of
##   time and place (SEND_WINDOW, SEND_AREA): a burst of gunfire gets no
##   more out of their sleep than a single shot.
## - the soft noises (a door, a fall, a step, a landing) do not wake a
##   sound sleeper (the first night's gentle start) at all.

enum Reaction { NONE, LOOK, INVESTIGATE, FLEE }

## How many may go to look at one event...
const INVESTIGATE_CAP := 3
## ...and at the events within SEND_AREA metres of each other over
## SEND_WINDOW seconds together (PerceptionWorld keeps the count).
const SEND_WINDOW := 6.0
const SEND_AREA := 20.0
## Noise sources with their own rules (anything else is a plain noise: a
## shot, a step, glass).
const SOURCE_FALL := &"fall"
const SOURCE_DOOR := &"door"
const SOURCE_BLAST := &"blast"
## Chance to investigate a plain noise: curiosity x (BASE + (1 - BASE) x closeness).
const PLAIN_BASE := 0.35
## A fallen exhibit draws the kinds that gather: FALL_BASE + (1 - FALL_BASE) x closeness.
const FALL_BASE := 0.5
## ...and the others at this share of their curiosity (x closeness).
const FALL_OTHERS := 0.3
## A blast frightens the skittish: skittish x (BLAST_BASE + (1 - BLAST_BASE) x closeness).
const BLAST_BASE := 0.5
## A weapon this loud (m, PerceptionRules.WEAPON_NOISE) goes off with a bang
## (a shot, not a punch or a taser's crackle).
const BANG_NOISE := 12.0
## The noises a sound sleeper sleeps through: a door, a crash, a step, a landing.
const SOFT_SOURCES: Array[StringName] = [SOURCE_DOOR, SOURCE_FALL, &"sprint", &"landing"]


## True for a sudden bang: a blast, or a shot of a weapon at least
## BANG_NOISE loud (what spooks a calm flock of books).
static func is_bang(source: StringName) -> bool:
	if source == SOURCE_BLAST:
		return true
	return float(PerceptionRules.WEAPON_NOISE.get(source, 0.0)) >= BANG_NOISE


## True for a noise a sound sleeper (Enemy.sound_asleep) does not wake to.
static func is_soft(source: StringName) -> bool:
	return SOFT_SOURCES.has(source)


## True when the nearest curious listener of [param source] always goes to
## look (a plain noise); a door and a fall leave it to the dice.
static func sends_a_visitor(source: StringName) -> bool:
	return source != SOURCE_DOOR and source != SOURCE_FALL


## 0 at the edge of what it could hear .. 1 at the noise itself.
static func closeness(distance: float, radius: float, loudness: float) -> float:
	var reach := radius * loudness
	if reach <= 0.0:
		return 0.0
	return clampf(1.0 - distance / reach, 0.0, 1.0)


## One listener's answer to a noise of [param source], by its
## [param profile] (EnemyRoles), [param closeness] (0..1) and a die
## [param roll] (0..1).
static func decide(source: StringName, profile: Dictionary, closeness_: float, roll: float) -> Reaction:
	var near := clampf(closeness_, 0.0, 1.0)
	var curiosity: float = profile.get("curiosity", 0.0)
	match source:
		SOURCE_BLAST:
			var skittish: float = profile.get("skittish", 0.0)
			var flee := skittish * (BLAST_BASE + (1.0 - BLAST_BASE) * near)
			if skittish > 0.0 and roll < flee:
				return Reaction.FLEE
			var rest := (roll - flee) / maxf(1.0 - flee, 0.001)
			return _look_or_go(curiosity * (PLAIN_BASE + (1.0 - PLAIN_BASE) * near), rest, curiosity)
		SOURCE_FALL:
			if profile.get("gathers", false):
				return _look_or_go(FALL_BASE + (1.0 - FALL_BASE) * near, roll, curiosity)
			return _look_or_go(curiosity * FALL_OTHERS * near, roll, curiosity)
		SOURCE_DOOR:
			var door: float = profile.get("door", 0.0)
			return _look_or_go(door * sqrt(near), roll, door)
	return _look_or_go(curiosity * (PLAIN_BASE + (1.0 - PLAIN_BASE) * near), roll, curiosity)


static func _look_or_go(chance: float, roll: float, able: float) -> Reaction:
	if able <= 0.0:
		return Reaction.LOOK
	return Reaction.INVESTIGATE if roll < chance else Reaction.LOOK


## Applies the cap to [param decided] (the listeners' answers, nearest
## first) given which of them are [param curious] (may go at all): with
## [param guaranteed] the nearest curious one that did not flee goes
## whatever it rolled (a plain noise; not a door or a fall), at most
## [param budget] go, the rest look. [param fresh] says which listeners
## rest (asleep, on their round, only looking up): only they count against
## the budget - one already about (investigating, searching, on its way
## home) follows the new noise for free; empty = all of them rest. With no
## budget left (others were sent to this place a moment ago) the nearest
## curious one gets no free pass either.
static func cap(decided: Array, curious: Array, budget: int = INVESTIGATE_CAP, fresh: Array = [], guaranteed: bool = true) -> Array:
	var out := decided.duplicate()
	if guaranteed:
		_send_the_nearest(out, curious, budget, fresh)
	var going := 0
	for i in out.size():
		if out[i] != Reaction.INVESTIGATE or not _is_fresh(fresh, i):
			continue
		if going >= budget:
			out[i] = Reaction.LOOK
		else:
			going += 1
	return out


## The nearest curious listener that did not flee goes (budget willing).
static func _send_the_nearest(out: Array, curious: Array, budget: int, fresh: Array) -> void:
	for i in out.size():
		if i < curious.size() and curious[i] and out[i] != Reaction.FLEE:
			if budget > 0 or not _is_fresh(fresh, i):
				out[i] = Reaction.INVESTIGATE
			return


static func _is_fresh(fresh: Array, i: int) -> bool:
	return i >= fresh.size() or bool(fresh[i])
