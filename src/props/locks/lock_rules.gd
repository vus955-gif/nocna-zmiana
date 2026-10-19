class_name LockRules
## What breaks which gate lock (design 4.2 and the 1 fix of the chain), as
## pure logic. One readable language: every lock has its tool, every other
## hit only strikes sparks (or dust, or splinters) and shows the hint.
##
## | lock    | opens                                                    |
## |---------|----------------------------------------------------------|
## | CHAIN   | shotgun: 25 summed within 0.4 s (pellets add up); 3 punches |
## | BOARDS  | shotgun: 25 summed within 0.4 s; 5 punches; any blast    |
## | CRACKED | blasts: 40 summed within 0.3 s (a fire-arrow volley);     |
## |         | 3 flares fired from within 5 m                           |
## | ROPE    | the rifle from anywhere; the pistol from within 15 m     |
## | HOOK    | the harpoon                                              |
## | BOLT    | E from the bolt's side (no weapon)                       |
## | POWER   | power_on() (no weapon)                                   |
## A lock-breaking round (DamageInfo.lock_breaker: the rifle with the
## secrets' peep sight) snaps a chain or a board at once, from anywhere.

enum Verdict { WRONG, SUM, STRIKE, OPEN }

const ROPE_PISTOL_RANGE := 15.0
const FLARE_POINT_BLANK := 5.0
const CHAIN_SUM := 25.0
const CHAIN_WINDOW := 0.4
const CHAIN_PUNCHES := 3
const BOARDS_PUNCHES := 5
const CRACKED_SUM := 40.0
const CRACKED_WINDOW := 0.3
const CRACKED_FLARES := 3


## The verdict on hit [param info] for a lock of [param kind].
static func verdict(kind: GateLock.Kind, info: DamageInfo) -> Verdict:
	match kind:
		GateLock.Kind.CHAIN:
			if info.lock_breaker:
				return Verdict.OPEN
			if info.weapon == &"shotgun":
				return Verdict.SUM
			if info.weapon == &"fists":
				return Verdict.STRIKE
		GateLock.Kind.BOARDS:
			if info.explosive or info.lock_breaker:
				return Verdict.OPEN
			if info.weapon == &"shotgun":
				return Verdict.SUM
			if info.weapon == &"fists":
				return Verdict.STRIKE
		GateLock.Kind.CRACKED:
			if info.explosive and info.weapon == &"flare" and fired_within(info, FLARE_POINT_BLANK):
				return Verdict.STRIKE
			if info.explosive:
				return Verdict.SUM
		GateLock.Kind.ROPE:
			if info.weapon == &"rifle_hunt":
				return Verdict.OPEN
			if info.weapon == &"pistol" and fired_within(info, ROPE_PISTOL_RANGE):
				return Verdict.OPEN
		GateLock.Kind.HOOK:
			if info.weapon == &"harpoon":
				return Verdict.OPEN
	return Verdict.WRONG


## True when the shot was fired within [param metres] of where it landed.
static func fired_within(info: DamageInfo, metres: float) -> bool:
	return info.origin != Vector3.INF and info.origin.distance_to(info.position) <= metres


## A fresh tally with the numbers of a lock of [param kind].
static func tally_for(kind: GateLock.Kind) -> LockTally:
	match kind:
		GateLock.Kind.CHAIN:
			return LockTally.new(CHAIN_WINDOW, CHAIN_SUM, CHAIN_PUNCHES)
		GateLock.Kind.BOARDS:
			return LockTally.new(CHAIN_WINDOW, CHAIN_SUM, BOARDS_PUNCHES)
		GateLock.Kind.CRACKED:
			return LockTally.new(CRACKED_WINDOW, CRACKED_SUM, CRACKED_FLARES)
	return LockTally.new(0.4, 0.0, 0)


## Translation key of the lock's line under the crosshair.
static func prompt_key(kind: GateLock.Kind) -> String:
	match kind:
		GateLock.Kind.CHAIN:
			return "LOCK_CHAIN_PROMPT"
		GateLock.Kind.BOARDS:
			return "LOCK_BOARDS_PROMPT"
		GateLock.Kind.CRACKED:
			return "LOCK_CRACKED_PROMPT"
		GateLock.Kind.ROPE:
			return "LOCK_ROPE_PROMPT"
		GateLock.Kind.HOOK:
			return "LOCK_HOOK_PROMPT"
		GateLock.Kind.BOLT:
			return "LOCK_BOLT_PROMPT"
	return "LOCK_POWER_PROMPT"


## Translation key of the hint a wrong hit shows (a pistol shot at a rope
## from too far tells the guard to come closer).
static func wrong_hint_key(kind: GateLock.Kind, info: DamageInfo) -> String:
	if kind == GateLock.Kind.ROPE and info.weapon == &"pistol":
		return "LOCK_ROPE_FAR"
	if kind == GateLock.Kind.POWER:
		return "LOCK_POWER_HINT"
	return prompt_key(kind)
