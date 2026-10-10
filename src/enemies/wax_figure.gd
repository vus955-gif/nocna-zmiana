class_name WaxFigure
extends Enemy
## Slow wax figure in a period costume. Walks in groups, hits in melee and
## melts under fire (it sags as it loses health, hit zones included).

const BODY_Y := 0.72
const BODY_HEIGHT := 1.3
const HEAD_Y := 1.55

var _body_shape: CapsuleShape3D
var _body_zone: Hurtbox
var _head_zone: Hurtbox


func _configure() -> void:
	max_health = 60.0
	move_speed = 2.4
	attack_damage = 12.0
	attack_reach = 1.9
	eye_height = 1.5
	marker_height = 2.0
	material_kind = ExhibitMaterial.Kind.WAX
	dust_value = 3
	brain.reaction_time = 0.8
	brain.attack_range = 1.6
	brain.windup = 0.55
	brain.recovery = 0.7


func _build_body() -> void:
	add_collider(0.35, 1.75)
	rig = WaxRig.build(self)
	if rig == null:
		_build_greybox()
	_body_shape = capsule_shape(0.34, BODY_HEIGHT)
	_body_zone = add_hurtbox(_body_shape, Vector3(0, BODY_Y, 0))
	_head_zone = add_hurtbox(sphere_shape(0.22), Vector3(0, HEAD_Y, 0), true)
	if rig != null:
		rig.track(_head_zone, &"head")   # the weak point stays on the head


func _build_greybox() -> void:
	var costume := body_material(Color(0.35, 0.18, 0.2))
	var wax := body_material(Color(0.93, 0.82, 0.62))
	var torso := CapsuleMesh.new()
	torso.radius = 0.28
	torso.height = 1.25
	add_part(torso, Vector3(0, BODY_Y, 0), costume)
	var head := SphereMesh.new()
	head.radius = 0.19
	head.height = 0.38
	add_part(head, Vector3(0, HEAD_Y, 0), wax)
	for side in [-1.0, 1.0]:
		add_part(box_mesh(Vector3(0.12, 0.6, 0.12)), Vector3(0.36 * side, 1.0, -0.05), wax)


func _on_damaged(_info: DamageInfo) -> void:
	var left := health.fraction()
	var spread := 1.0 + (1.0 - left) * 0.1
	var sag := lerpf(0.8, 1.0, left)
	visual.scale = Vector3(spread, sag, spread)
	# the hit zones sag with the body, so a headshot still means the head
	_body_zone.position.y = BODY_Y * sag
	_body_shape.height = BODY_HEIGHT * sag
	_head_zone.position.y = HEAD_Y * sag
