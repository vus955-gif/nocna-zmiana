class_name EnvStrike
## Where a falling, toppling or rolling thing lands and what it does there
## (plan docs/superpowers/plans/2026-10-21-srodowisko-walka.md): the hit
## zones under a disc (a lamp, a chandelier, a slab dropping) or a box (a
## column or a bookcase lying down, a wheel's path) - exhibits and the
## museum's other props alike (a chandelier lands on a glass case: the case
## breaks) - and the guard in it, who takes what EnvRules.guard_damage
## allows (his own tool: never below half his health) and is always pushed.
## Every blow is credited to who set the thing going (Dust and the night's
## counts for the guard).

## The guard counts as in a zone this far past its edge (his body's radius).
const GUARD_RADIUS := 0.4


## The receivers (with take_damage()) whose hit zones overlap the upright
## cylinder of [param radius] and [param height] standing on [param base],
## each once, closest first; never one of [param exclude].
static func in_disc(world: Node3D, base: Vector3, radius: float, height: float, exclude: Array = []) -> Array[Node]:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	return _query(world, shape, Transform3D(Basis.IDENTITY, base + Vector3.UP * height * 0.5), base, exclude)


## The receivers whose hit zones overlap the box of [param size] centred at
## [param frame] (its origin; turned as it is), each once, closest first.
static func in_box(world: Node3D, frame: Transform3D, size: Vector3, exclude: Array = []) -> Array[Node]:
	var shape := BoxShape3D.new()
	shape.size = size
	return _query(world, shape, frame, frame.origin, exclude)


## True when [param guard] stands in the cylinder (in_disc()).
static func guard_in_disc(guard: Node3D, base: Vector3, radius: float, height: float) -> bool:
	if guard == null:
		return false
	var at := guard.global_position
	var flat := Vector2(at.x - base.x, at.z - base.z).length()
	return flat <= radius + GUARD_RADIUS and at.y >= base.y - 0.6 and at.y <= base.y + height


## True when [param guard] stands in the box (in_box()).
static func guard_in_box(guard: Node3D, frame: Transform3D, size: Vector3) -> bool:
	if guard == null:
		return false
	var local := frame.affine_inverse() * (guard.global_position + Vector3.UP * 0.9)
	var half := size * 0.5 + Vector3(GUARD_RADIUS, 0.9, GUARD_RADIUS)
	return absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z


## One blow on [param receiver]: [param amount] of [param kind] from
## [param from] (pushed away from it, or along [param push] when given),
## credited to [param source]; a crushing weight (staggers, tears apart).
static func hit(receiver: Node, amount: float, kind: DamageInfo.Kind, source: Node, from: Vector3,
		push: Vector3 = Vector3.ZERO, knockback: float = 0.0, stun: float = 0.0) -> DamageInfo:
	var at := (receiver as Node3D).global_position if receiver is Node3D else from
	var direction := push
	if direction.length() < 0.01:
		direction = Vector3(at.x - from.x, 0.0, at.z - from.z)
	direction = direction.normalized() if direction.length() > 0.01 else Vector3.DOWN
	var info := DamageInfo.make(Blast.scaled(amount, receiver, kind), kind, source if is_instance_valid(source) else null)
	info.position = at + Vector3.UP * 0.8
	info.normal = -direction
	info.direction = direction
	info.knockback = knockback
	info.stun_time = stun
	info.impact = 1.0
	info.weapon = &"env"
	info.origin = from
	receiver.take_damage(info)
	return info


## The guard in the way: what EnvRules.guard_damage allows of
## [param amount] (all of it when [param by_guard] is false), always a push
## of [param knockback] away from [param from] (or along [param push]).
## Returns the damage dealt.
static func hurt_guard(guard: Player, amount: float, by_guard: bool, from: Vector3, push: Vector3 = Vector3.ZERO,
		knockback: float = 6.0, kind: DamageInfo.Kind = DamageInfo.Kind.BLUNT, source: Node = null) -> float:
	if guard == null or not guard.alive:
		return 0.0
	var direction := push
	if direction.length() < 0.01:
		direction = Vector3(guard.global_position.x - from.x, 0.0, guard.global_position.z - from.z)
	direction = Vector3(direction.x, 0.0, direction.z)
	direction = direction.normalized() if direction.length() > 0.01 else Vector3.FORWARD
	var dealt := EnvRules.guard_damage(guard.health.current, guard.health.max_health, amount, by_guard)
	if dealt <= 0.0:
		guard.velocity += direction * knockback
		return 0.0
	var info := DamageInfo.make(dealt, kind, source)
	info.position = from
	info.direction = direction
	info.knockback = knockback
	guard.take_damage(info)
	return dealt


static func _query(world: Node3D, shape: Shape3D, frame: Transform3D, from: Vector3, exclude: Array) -> Array[Node]:
	var out: Array[Node] = []
	if world == null or not world.is_inside_tree():
		return out
	# (in batches, like a blast's sweep: a zone of many shapes - a T-Rex's
	# rib cage - never crowds out the exhibits beside it)
	for zone in Hitscan.shape_hurtboxes(world.get_world_3d().direct_space_state, shape, frame):
		if zone == null or zone.receiver == null or not is_instance_valid(zone.receiver):
			continue
		var receiver := zone.receiver
		if out.has(receiver) or exclude.has(receiver) or not receiver.has_method(&"take_damage"):
			continue
		out.append(receiver)
	out.sort_custom(func(a: Node, b: Node) -> bool:
		var pa := (a as Node3D).global_position if a is Node3D else from
		var pb := (b as Node3D).global_position if b is Node3D else from
		return pa.distance_squared_to(from) < pb.distance_squared_to(from))
	return out
