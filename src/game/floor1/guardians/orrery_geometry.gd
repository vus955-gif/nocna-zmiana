class_name OrreryGeometry
extends RefCounted
## The Great Orrery's measurements (the model "planetarium",
## tools/art/models/planetarium.py, docs/art/kit-pietro1-oswiecenie.md §5)
## and the test of the guard's capsule against its spinning tiers - the
## rules of its arena: the LOW arm's beam (0.30-0.55 m) is jumped, the MID
## arm (chest high, to 3.6 m) is kept away from, under the HIGH arm the
## hanging moons leave a gap (r 3.85-4.45 for a body 0.4 m round) to stand
## in. Planets ride their tiers on rods; each tier has two arms, opposite.
##
## Model space: origin on the floor on the axis, Y up. A tier's own space
## ("tier space") is the model's turned by its spin and lifted to its pivot
## (PIVOT); arm a of tier t points along arm_direction(t, a) there. Every
## test takes the guard as a vertical capsule standing on [param feet]
## (its lowest point) with [param radius] and [param height] (the Player's
## CapsuleShape3D).

const LOW := 0
const MID := 1
const HIGH := 2
const TIER_NAMES: Array[String] = ["tier_low", "tier_mid", "tier_high"]
## Pivot height of each tier (its node's origin over the floor).
const PIVOT: Array[float] = [0.45, 1.6, 2.8]
## Each tier's beam: bottom and top over the floor.
const BEAM: Array[Vector2] = [Vector2(0.3, 0.55), Vector2(1.45, 1.75), Vector2(2.65, 2.95)]
## How far each tier's arms reach from the axis (the tip block's middle).
const REACH: Array[float] = [5.0, 3.6, 5.0]
## The rest bearing of each tier's first arm (rad; the model's angle a:
## direction (cos a, 0, -sin a)); its second arm points the other way.
const ARM_ANGLE: Array[float] = [0.0, PI / 3.0, PI * 2.0 / 3.0]
## Where a beam leaves its hub, and its half width (the flanges).
const HUB := 0.5
const BEAM_HALF := 0.1
## The bearing block on an arm's tip: half its length along the arm, how far
## it juts over and under the beam, its half width.
const TIP := Vector2(0.1, 0.04)
const TIP_HALF := 0.13
## The planets (planet_1..6): [tier, arm, radius from the axis, centre over
## the floor, size (its radius)]. Mercury, Venus (low), Earth, Mars (mid),
## Jupiter, Saturn (high).
const PLANETS := [
	[LOW, 1, 2.4, 1.2, 0.25],
	[LOW, 0, 4.75, 1.3, 0.35],
	[MID, 0, 3.3, 2.45, 0.4],
	[MID, 1, 3.0, 2.35, 0.32],
	[HIGH, 0, 4.5, 3.75, 0.65],
	[HIGH, 1, 4.5, 3.65, 0.5],
]
const PLANET_NAMES: Array[String] = ["Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn"]
## The rods holding the planets: half their width (with the caps).
const ROD_HALF := 0.05
## Earth's Moon on its crank (from Earth's centre, the tier at rest) and
## its size; Saturn's rings (inner, outer radius).
const EARTH_MOON := Vector3(-0.606, 0.12, -0.35)
const EARTH_MOON_SIZE := 0.14
const SATURN_RINGS := Vector2(0.66, 1.05)
## The high tier's hanging moons: radii along each arm, centre heights over
## the floor, their size; the rods hang from the beam's underside.
const MOON_RADII: Array[float] = [1.2, 1.9, 2.6, 3.3, 5.0]
const MOON_HEIGHTS: Array[float] = [1.1, 1.3, 1.1, 1.3, 1.1]
const MOON_SIZE := 0.15
const MOON_ROD := 0.02
## The sun: centre height, shell and core radii; the six petals hinge at
## radius PETAL_HINGE.x, height PETAL_HINGE.y, bearings 30 + 60 k degrees,
## and open by PETAL_OPEN rad about their hinge's tangent.
const SUN_HEIGHT := 5.0
const SUN_RADIUS := 1.1
const CORE_RADIUS := 0.75
const PETAL_HINGE := Vector2(0.953, 4.45)
const PETAL_OPEN := 1.6
## The still base: the stepped drum (radius, top) rings, the column.
const DRUM: Array[Vector2] = [Vector2(2.7, 0.1), Vector2(2.2, 0.18), Vector2(1.45, 0.24)]
const COLUMN_RADIUS := 0.34
## The guard's jump apex (Player: 5 m/s up, gravity 15): the low beam's top
## and its tip block stay under it.
const JUMP_APEX := 0.83


## The direction arm [param arm] (0, 1) of [param tier] points in its tier's
## space.
static func arm_direction(tier: int, arm: int) -> Vector3:
	var angle := ARM_ANGLE[tier] + PI * arm
	return Vector3(cos(angle), 0.0, -sin(angle))


static func planet_tier(planet: int) -> int:
	return int(PLANETS[planet][0])


static func planet_size(planet: int) -> float:
	return float(PLANETS[planet][4])


## Planet [param planet]'s (0..5) centre in its tier's space (the socket).
static func socket(planet: int) -> Vector3:
	var spec: Array = PLANETS[planet]
	var tier := int(spec[0])
	return arm_direction(tier, int(spec[1])) * float(spec[2]) + Vector3.UP * (float(spec[3]) - PIVOT[tier])


static func moon_count() -> int:
	return MOON_RADII.size() * 2


## Hanging moon [param moon] (0..9: five on the first arm, five on the
## second) - its centre and its rod's top in the high tier's space.
static func moon_center(moon: int) -> Vector3:
	var along := arm_direction(HIGH, moon / MOON_RADII.size())
	var i := moon % MOON_RADII.size()
	return along * MOON_RADII[i] + Vector3.UP * (MOON_HEIGHTS[i] - PIVOT[HIGH])


static func moon_pivot(moon: int) -> Vector3:
	var along := arm_direction(HIGH, moon / MOON_RADII.size())
	return along * MOON_RADII[moon % MOON_RADII.size()] + Vector3.UP * (BEAM[HIGH].x - PIVOT[HIGH])


## The planets riding [param tier].
static func tier_planets(tier: int) -> Array[int]:
	var out: Array[int] = []
	for i in PLANETS.size():
		if int(PLANETS[i][0]) == tier:
			out.append(i)
	return out


# --- the arms against the guard --------------------------------------------------

## True when a guard standing on [param feet] (model space, the tier at
## rest) touches the beams of [param tier] (and the rods of the planets in
## [param planets_on]: true = still on its arm). The parts that move on
## their own - planets, moons - are separate (planet_spheres(), and the
## Planetarium tests their nodes).
static func beams_hit(tier: int, feet: Vector3, radius: float, height: float, planets_on: Array[bool]) -> bool:
	var band := BEAM[tier]
	for arm in 2:
		var p := Basis(Vector3.UP, -(ARM_ANGLE[tier] + PI * arm)) * feet
		if capsule_box(p, radius, height, AABB(Vector3(HUB, band.x, -BEAM_HALF), Vector3(REACH[tier] - HUB, band.y - band.x, BEAM_HALF * 2.0))):
			return true
		var tip := AABB(Vector3(REACH[tier] - TIP.x, band.x - TIP.y, -TIP_HALF), Vector3(TIP.x * 2.0, band.y - band.x + TIP.y * 2.0, TIP_HALF * 2.0))
		if capsule_box(p, radius, height, tip):
			return true
		for planet in tier_planets(tier):
			var spec: Array = PLANETS[planet]
			if int(spec[1]) != arm or not planets_on[planet]:
				continue
			var at := float(spec[2])
			var rod := AABB(Vector3(at - ROD_HALF, band.y, -ROD_HALF), Vector3(ROD_HALF * 2.0, float(spec[3]) - float(spec[4]) - band.y, ROD_HALF * 2.0))
			if capsule_box(p, radius, height, rod):
				return true
	return false


## The whole of [param tier] at rest against the guard: beams, rods, the
## planets still on it, the high tier's moons on their rods (unit tests,
## the rules; the fight tests the moving nodes the same way).
static func tier_hits_rest(tier: int, feet: Vector3, radius: float, height: float, planets_on: Array[bool]) -> bool:
	if beams_hit(tier, feet, radius, height, planets_on):
		return true
	var lift := Vector3.UP * PIVOT[tier]
	for planet in tier_planets(tier):
		if not planets_on[planet]:
			continue
		var center := socket(planet) + lift
		if capsule_sphere(feet, radius, height, center, planet_size(planet)):
			return true
		if planet == 2 and capsule_sphere(feet, radius, height, center + EARTH_MOON, EARTH_MOON_SIZE):
			return true
	if tier == HIGH:
		for moon in moon_count():
			var center := moon_center(moon) + lift
			if capsule_sphere(feet, radius, height, center, MOON_SIZE):
				return true
			if capsule_segment(feet, radius, height, moon_pivot(moon) + lift, center, MOON_ROD):
				return true
	return false


# --- capsule tests ------------------------------------------------------------------

## True when a vertical capsule on [param feet] touches [param box].
static func capsule_box(feet: Vector3, radius: float, height: float, box: AABB) -> bool:
	var low := feet.y + radius
	var high := feet.y + maxf(height - radius, radius)
	var dx := maxf(maxf(box.position.x - feet.x, feet.x - box.end.x), 0.0)
	var dz := maxf(maxf(box.position.z - feet.z, feet.z - box.end.z), 0.0)
	var dy := maxf(maxf(box.position.y - high, low - box.end.y), 0.0)
	return dx * dx + dy * dy + dz * dz < radius * radius


## True when a vertical capsule on [param feet] touches a ball of
## [param size] at [param center].
static func capsule_sphere(feet: Vector3, radius: float, height: float, center: Vector3, size: float) -> bool:
	var axis := Vector3(feet.x, clampf(center.y, feet.y + radius, feet.y + maxf(height - radius, radius)), feet.z)
	return axis.distance_to(center) < radius + size


## True when a vertical capsule on [param feet] touches a rod from
## [param a] to [param b] of [param size] (its radius).
static func capsule_segment(feet: Vector3, radius: float, height: float, a: Vector3, b: Vector3, size: float) -> bool:
	var p := feet + Vector3.UP * radius
	var q := feet + Vector3.UP * maxf(height - radius, radius)
	return segment_distance(p, q, a, b) < radius + size


## The shortest distance between segments [param p]-[param q] and
## [param a]-[param b].
static func segment_distance(p: Vector3, q: Vector3, a: Vector3, b: Vector3) -> float:
	var d1 := q - p
	var d2 := b - a
	var r := p - a
	var aa := d1.dot(d1)
	var ee := d2.dot(d2)
	var ff := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if aa <= 0.000001 and ee <= 0.000001:
		return p.distance_to(a)
	if aa <= 0.000001:
		t = clampf(ff / ee, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		if ee <= 0.000001:
			s = clampf(-c / aa, 0.0, 1.0)
		else:
			var bb := d1.dot(d2)
			var denom := aa * ee - bb * bb
			s = clampf((bb * ff - c * ee) / denom, 0.0, 1.0) if denom > 0.000001 else 0.0
			t = (bb * s + ff) / ee
			if t < 0.0:
				t = 0.0
				s = clampf(-c / aa, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((bb - c) / aa, 0.0, 1.0)
	return (p + d1 * s).distance_to(a + d2 * t)
