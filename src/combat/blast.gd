class_name Blast
## A small explosion (the flare's burst): every hit zone within
## [param radius] that the blast can reach through the air takes one hit
## (per receiver, not per zone) and is pushed away from the centre. Fire
## melts wax twice as fast (ExhibitMaterial.fire_factor()). The guard, who
## has no hit zones, is checked by distance: his own blast only takes what
## he has above GUARD_FLOOR of his health (a small price for a shot at his
## feet) but always pushes him.

## The guard's own blast never takes him below this share of his health.
const GUARD_FLOOR := 0.5
## The guard counts as in range this much further out (his body's radius).
const GUARD_RADIUS := 0.4
const GUARD_CHEST := 0.9


## Damages everything in range. [param push_hint] is the direction used
## for a receiver right at the centre (the flare's flight). Returns the
## receivers that were hit (the guard included).
## [param world] is any node in the scene (it gives the physics space).
## Every hit is [member DamageInfo.explosive] and carries [param weapon]
## and [param origin] (where the shot was fired from); [param sound] is
## the bang.
static func explode(world: Node, center: Vector3, radius: float, damage: float, knockback: float,
		kind: DamageInfo.Kind, source: Node, push_hint: Vector3 = Vector3.FORWARD, weapon: StringName = &"",
		origin: Vector3 = Vector3.INF, sound: StringName = &"flare_blast") -> Array[Node]:
	var hit: Array[Node] = []
	if not world.is_inside_tree():
		return hit
	var space := world.get_viewport().find_world_3d().direct_space_state
	for hurtbox in Hitscan.sphere_hurtboxes(space, center, radius):
		var receiver := hurtbox.receiver
		if receiver == null or receiver == source or hit.has(receiver) or not receiver.has_method(&"take_damage"):
			continue
		var at := hurtbox.global_position
		if not _clear(space, center, at):
			continue
		hit.append(receiver)
		var direction := _away(center, at, push_hint)
		var info := DamageInfo.make(scaled(damage, receiver, kind), kind, source)
		info.position = at
		info.normal = -direction
		info.direction = direction
		info.knockback = knockback
		info.explosive = true
		info.weapon = weapon
		info.origin = origin
		receiver.take_damage(info)
	for node in world.get_tree().get_nodes_in_group(&"player"):
		var guard := node as Player
		if guard == null or not guard.alive or hit.has(guard):
			continue
		var chest := guard.global_position + Vector3.UP * GUARD_CHEST
		if chest.distance_to(center) > radius + GUARD_RADIUS or not _clear(space, center, chest):
			continue
		hit.append(guard)
		_hurt_guard(guard, center, damage, knockback, kind, source, push_hint)
	Fx.impact(center, Vector3.UP, ExhibitMaterial.Kind.METAL, 2.0)   # sparks
	Fx.impact(center, Vector3.UP, -1, 1.5)
	Fx.flash(center, Color(1.0, 0.5, 0.2), 6.0, radius * 3.0, 0.25)
	Sfx.play_at(sound, center)
	return hit


## [param amount] of [param kind] as it lands on [param receiver] (wax
## takes fire double).
static func scaled(amount: float, receiver: Node, kind: DamageInfo.Kind) -> float:
	var exhibit := receiver as Enemy
	if exhibit == null:
		return amount
	return amount * ExhibitMaterial.fire_factor(exhibit.material_kind, kind)


## The guard in his own blast (or an exhibit's): full damage from anyone
## else, from himself only what lies above GUARD_FLOOR. Always pushed.
static func _hurt_guard(guard: Player, center: Vector3, damage: float, knockback: float, kind: DamageInfo.Kind,
		source: Node, push_hint: Vector3) -> void:
	var amount := damage
	if source == guard:
		amount = clampf(guard.health.current - guard.health.max_health * GUARD_FLOOR, 0.0, damage)
	var direction := _away(center, guard.global_position + Vector3.UP * GUARD_CHEST, push_hint)
	if amount <= 0.0:
		guard.velocity += Vector3(direction.x, 0.0, direction.z) * knockback
		return
	var info := DamageInfo.make(amount, kind, source)
	info.position = center
	info.direction = direction
	info.knockback = knockback
	guard.take_damage(info)


static func _away(center: Vector3, point: Vector3, hint: Vector3) -> Vector3:
	var flat := Vector3(point.x - center.x, 0.0, point.z - center.z)
	if flat.length() > 0.25:
		return flat.normalized()
	var fallback := Vector3(hint.x, 0.0, hint.z)
	return fallback.normalized() if fallback.length() > 0.01 else Vector3.FORWARD


static func _clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	return space.intersect_ray(query).is_empty()
