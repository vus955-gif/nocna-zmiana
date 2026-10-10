class_name ShieldGuard
## The knight's shield rule: blocks hits arriving from the front arc,
## except electric ones (they conduct through the metal), while stunned and
## steep shots from above (firing down from a balcony gets past it).

const HALF_ARC_DEG := 70.0
## Hits falling steeper than this (direction.y below its negative) pass
## over the shield.
const STEEP_FROM_ABOVE := 0.7


## [param facing] = where the knight looks; [param hit_direction] = where
## the hit travels (attacker -> knight); [param half_arc_deg] = how far
## either side of the front the shield covers (a hoplite's round shield:
## less, wider in a phalanx).
static func blocks(facing: Vector3, hit_direction: Vector3, kind: DamageInfo.Kind, stunned: bool, half_arc_deg: float = HALF_ARC_DEG) -> bool:
	if stunned or kind == DamageInfo.Kind.ELECTRIC or hit_direction.normalized().y < -STEEP_FROM_ABOVE:
		return false
	var look := Vector3(facing.x, 0.0, facing.z)
	var toward_attacker := Vector3(-hit_direction.x, 0.0, -hit_direction.z)
	if look.length_squared() < 0.0001 or toward_attacker.length_squared() < 0.0001:
		return false
	return look.normalized().dot(toward_attacker.normalized()) >= cos(deg_to_rad(half_arc_deg))
