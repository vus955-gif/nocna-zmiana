class_name DustRules
## How much Dust a destroyed exhibit leaves and how it splits into motes.
## Night bonuses (full moon, the fountain coin...) are applied afterwards by
## RunState.scaled_dust(), so a mote always carries its final value.

const FINISHER_MULTIPLIER := 1.5
const MAX_MOTES := 4
## The boss bursts into this many motes.
const BOSS_MOTES := 12
## Roughly this much Dust per mote (a wax figure drops one, a knight three).
const DUST_PER_MOTE := 3


## Dust for one kill: the exhibit's value, x1.5 (rounded up) for a fist
## finisher.
static func kill_value(base: int, finisher: bool) -> int:
	if base <= 0:
		return 0
	if not finisher:
		return base
	return ceili(snappedf(base * FINISHER_MULTIPLIER, 0.0001))


## Splits [param total] into 1 to [param max_motes] motes of near-equal
## value (larger first). Exhibits use the default of 4; the boss more.
static func split(total: int, max_motes: int = MAX_MOTES) -> Array[int]:
	var motes: Array[int] = []
	if total <= 0:
		return motes
	var count := mini(clampi(ceili(total / float(DUST_PER_MOTE)), 1, maxi(max_motes, 1)), total)
	var each := total / count
	var extra := total % count
	for i in count:
		motes.append(each + (1 if i < extra else 0))
	return motes
