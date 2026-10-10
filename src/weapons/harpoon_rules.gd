class_name HarpoonRules
## What a harpoon does to an exhibit it hits (design 7.1), as pure logic:
## a light one (max health up to WeaponData.pin_max_health) with a wall
## within pin_reach behind it is PINNED to that wall (and breaks there); a
## medium one is PULLED pull_distance metres toward the guard and stunned;
## a heavy one (max health above heavy_health, or hard to push) only takes
## the damage. Guardians and the boss are not plain exhibits: damage only.

enum Verdict { DAMAGE, PIN, PULL }

## From this knockback resistance on an exhibit counts as heavy (a knight).
const HEAVY_RESIST := 0.75


## The verdict for an exhibit of [param max_health] and
## [param knockback_resist] with the nearest wall [param wall_distance]
## metres behind it (INF: none) hit with harpoon [param data].
static func verdict(max_health: float, knockback_resist: float, wall_distance: float, data: WeaponData) -> Verdict:
	if max_health <= data.pin_max_health and wall_distance <= data.pin_reach:
		return Verdict.PIN
	if max_health <= data.heavy_health and knockback_resist < HEAVY_RESIST:
		return Verdict.PULL
	return Verdict.DAMAGE


## Push (m/s) that slides a body [param distance] metres along the floor
## before the ground friction stops it (v^2 = 2 a d).
static func pull_speed(distance: float) -> float:
	return sqrt(2.0 * Enemy.GROUND_FRICTION * maxf(distance, 0.0))
