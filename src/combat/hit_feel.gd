class_name HitFeel
## How hard a hit lands and what that does (plan 2026-10-19-gun-feel). A
## hit's weight (0..1) comes from the weapon that dealt it (DamageInfo.impact,
## set from its FeelProfile; a shotgun's pellets each carry their share),
## else from that weapon's profile (a blast: its blast_weight), else from the
## damage (an exhibit's blow). Pure numbers; Enemy plays them:
## - every hit: the exhibit flinches along the shot (HitReaction) - a light
##   round a small jolt, a heavy one a real reel, less the steadier it
##   stands (knockback resistance);
## - a heavy hit (HEAVY_WEIGHT): chips of its material fly off;
## - a staggering hit (STAGGER_WEIGHT) on an exhibit that gives way: its legs
##   stop for STAGGER_TIME and it starts no attack (one already winding up
##   goes on: the telegraphs never change), then it cannot be staggered
##   again for STAGGER_COOLDOWN; a moment of hitstop;
## - a kill: a light weapon's crumbles, a heavy one's is blown back and
##   apart (GibPlanner's force), with its hitstop, shake and a deeper crunch.

enum Tier { FLINCH, HEAVY, STAGGER }

const HEAVY_WEIGHT := 0.45
const STAGGER_WEIGHT := 0.75
## Exhibits this steady (knockback resistance) are never staggered.
const STAGGER_RESIST := 0.7
const STAGGER_TIME := 0.35
const STAGGER_COOLDOWN := 1.2
## A staggered exhibit's legs carry it at this share of its pace.
const STAGGER_MOVE := 0.15
## The flinch's lean (rad) for the lightest and the heaviest hit on an
## exhibit that gives way fully; RESIST_DAMPING of its knockback
## resistance holds it back. The twist from a hit off its middle (rad).
const TILT_LIGHT := 0.035
const TILT_HEAVY := 0.26
const RESIST_DAMPING := 0.75
const TWIST := 0.14
## Hitstop (real s) of a staggering hit, of a heavy kill, of any torn-apart kill.
const HIT_HITSTOP := 0.03
const KILL_HITSTOP_HEAVY := 0.075
const KILL_HITSTOP_GIB := 0.05
## Kill shake (trauma): a heavy kill's, from HEAVY_WEIGHT up; a torn-apart
## light one's.
const KILL_SHAKE_HEAVY := Vector2(0.15, 0.3)
const KILL_SHAKE_GIB := 0.12
## Chips need at least this much damage.
const CHIP_DAMAGE := 12.0
## A blow without a weapon weighs its damage over this.
const DAMAGE_FOR_FULL_WEIGHT := 80.0


## The weight of [param info] (0 for a tick of burning).
static func weight(info: DamageInfo) -> float:
	if info == null or info.periodic:
		return 0.0
	if info.impact > 0.0:
		return clampf(info.impact, 0.0, 1.0)
	if FeelProfile.has(info.weapon):
		var profile := FeelProfile.of(info.weapon)
		return clampf(profile.blast_weight if info.explosive else profile.hit_weight, 0.0, 1.0)
	return clampf(info.amount / DAMAGE_FOR_FULL_WEIGHT, 0.0, 1.0)


static func tier(hit_weight: float) -> Tier:
	if hit_weight >= STAGGER_WEIGHT:
		return Tier.STAGGER
	if hit_weight >= HEAVY_WEIGHT:
		return Tier.HEAVY
	return Tier.FLINCH


## The flinch's lean (rad) of a hit of [param hit_weight] on an exhibit of
## knockback resistance [param resist].
static func tilt(hit_weight: float, resist: float) -> float:
	return lerpf(TILT_LIGHT, TILT_HEAVY, clampf(hit_weight, 0.0, 1.0)) * (1.0 - RESIST_DAMPING * clampf(resist, 0.0, 1.0))


## True when a hit of [param hit_weight] staggers an exhibit of knockback
## resistance [param resist].
static func staggers(hit_weight: float, resist: float) -> bool:
	return hit_weight >= STAGGER_WEIGHT and resist < STAGGER_RESIST


static func hit_hitstop(hit_weight: float) -> float:
	return HIT_HITSTOP if hit_weight >= STAGGER_WEIGHT else 0.0


## Hitstop of a kill by a hit of [param force] ([param gibbed]: torn apart).
static func kill_hitstop(force: float, gibbed: bool) -> float:
	if force >= STAGGER_WEIGHT:
		return KILL_HITSTOP_HEAVY
	return KILL_HITSTOP_GIB if gibbed else 0.0


## Shake (trauma) of a kill by a hit of [param force].
static func kill_shake(force: float, gibbed: bool) -> float:
	if force >= HEAVY_WEIGHT:
		return lerpf(KILL_SHAKE_HEAVY.x, KILL_SHAKE_HEAVY.y, inverse_lerp(HEAVY_WEIGHT, 1.0, minf(force, 1.0)))
	return KILL_SHAKE_GIB if gibbed else 0.0
