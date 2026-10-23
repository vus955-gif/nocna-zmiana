class_name Hitscan
## Static helpers for instant-hit weapons and melee sweeps.


## Other areas (triggers, havens) a ray may pass before giving up.
const MAX_SKIPPED_AREAS := 4
## Overlaps asked for per sphere query, and how many queries (each without
## the zones found before) one sweep may take.
const QUERY_BATCH := 32
const MAX_BATCHES := 16
## The museum's props' zones one piercing round may pass on top of its
## targets (a glass case has four overlapping zones).
const MAX_PROP_ZONES := 24


## Casts a ray against level geometry and hurtboxes. Returns {} on a miss,
## else {position, normal, collider, hurtbox (null for walls), rid}. A ray
## that starts inside a shape (point-blank) hits it at [param from] with a
## zero normal. Areas that are not hurtboxes never stop a shot, even one left
## on the WORLD layer (an Area3D's default) that the shot starts inside.
## [param exclude]: shapes' objects the ray passes through (a piercing shot's
## earlier targets).
static func ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD | Layers.HURTBOX, exclude.duplicate())
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.hit_from_inside = true
	for attempt in MAX_SKIPPED_AREAS + 1:
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return {}
		var collider: Object = hit["collider"]
		if collider is Area3D and not collider is Hurtbox:
			var skipped := query.exclude
			skipped.append(hit["rid"])
			query.exclude = skipped
			continue
		return {
			"position": hit["position"],
			"normal": hit["normal"],
			"collider": collider,
			"hurtbox": collider as Hurtbox,
			"rid": hit["rid"],
		}
	return {}


## A ray that goes on through up to [param max_targets] targets (the
## hunting rifle). Returns the hits in order: one per receiver (the first of
## its zones the ray crosses decides the weak point; its other zones are
## passed through), and a wall last (hurtbox null) when one stops the ray.
## The museum's props on the way (a case's glass, a lamp, a tool's tag:
## EnvProp, EnvTag) are hit too but do not count against
## [param max_targets]; their zones have a budget of their own
## (MAX_PROP_ZONES), so a row of them never ends the shot early.
static func pierce(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, max_targets: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var receivers: Array[Node] = []
	var passed: Array[RID] = []
	var targets := 0
	var steps := 0
	var prop_steps := 0
	while steps < maxi(max_targets, 1) * 8 and prop_steps < MAX_PROP_ZONES:
		var hit := ray(space, from, to, passed)
		if hit.is_empty():
			break
		var hurtbox: Hurtbox = hit["hurtbox"]
		if hurtbox == null:
			out.append(hit)   # a wall ends the shot
			break
		var prop := is_prop(hurtbox)
		if prop:
			prop_steps += 1
		else:
			steps += 1
		passed.append(hit["rid"])
		# a pane the round goes through lets it past the solid case round it
		# (EnvGlass: the glass of a display case)
		for rid: RID in hurtbox.get_meta(&"pierced_bodies", []):
			if not passed.has(rid):
				passed.append(rid)
		if receivers.has(hurtbox.receiver):
			continue   # another zone of a target already hit
		receivers.append(hurtbox.receiver)
		out.append(hit)
		if not prop:
			targets += 1
			if targets >= max_targets:
				break
	return out


## True when [param hurtbox] is a zone of the museum's reactive props
## (EnvProp: glass, lamps, busts...; EnvTag: a tool's red tag), not a target.
static func is_prop(hurtbox: Hurtbox) -> bool:
	return hurtbox != null and (hurtbox.receiver is EnvProp or hurtbox.receiver is EnvTag)


## Random direction inside a cone around [param forward]
## ([param spread_deg] = half-angle).
static func spread_direction(forward: Vector3, spread_deg: float, rng: RandomNumberGenerator) -> Vector3:
	var dir := forward.normalized()
	if spread_deg <= 0.0:
		return dir
	var angle := deg_to_rad(spread_deg) * sqrt(rng.randf())
	var spin := rng.randf() * TAU
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 0.001:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(dir).normalized()
	var offset := (side * cos(spin) + up * sin(spin)) * tan(angle)
	return (dir + offset).normalized()


## Hurtboxes overlapping a sphere (melee, blasts, the taser's jump),
## each once, closest first. A zone made of many shapes (a T-Rex bone of
## several pieces, its rib cage's exact mesh) reports one overlap per
## shape or triangle and can fill a whole batch of results, so the query
## repeats without the zones found so far until a batch comes back short:
## a crystal or a wax figure next to the T-Rex's leg is never crowded out.
static func sphere_hurtboxes(space: PhysicsDirectSpaceState3D, center: Vector3, radius: float) -> Array[Hurtbox]:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var found := shape_hurtboxes(space, shape, Transform3D(Basis.IDENTITY, center))
	found.sort_custom(func(a: Hurtbox, b: Hurtbox) -> bool:
		return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
	return found


## Hurtboxes overlapping [param shape] at [param frame], each once, in the
## order the physics found them, in batches (see sphere_hurtboxes(): a zone
## of many shapes never crowds out the others). A falling load's strike
## (EnvStrike) asks this way too.
static func shape_hurtboxes(space: PhysicsDirectSpaceState3D, shape: Shape3D, frame: Transform3D) -> Array[Hurtbox]:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = frame
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = Layers.HURTBOX
	var found: Array[Hurtbox] = []
	var seen: Array[RID] = []
	for batch in MAX_BATCHES:
		var hits := space.intersect_shape(query, QUERY_BATCH)
		var fresh := false
		for hit in hits:
			var rid: RID = hit["rid"]
			if seen.has(rid):
				continue
			seen.append(rid)
			fresh = true
			var hurtbox := hit["collider"] as Hurtbox
			if hurtbox != null:
				found.append(hurtbox)
		if hits.size() < QUERY_BATCH or not fresh:
			break
		query.exclude = seen
	return found
