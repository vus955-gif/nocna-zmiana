class_name Knight
extends Enemy
## Armoured knight. The shield blocks frontal hits (not electric ones, nor
## steep shots from above); a taser stun drops the guard. Turns slowly, so
## flanking works. Shrugs off most knockback and sheds armour plates when
## hit hard.

var _shield: MeshInstance3D


func _configure() -> void:
	max_health = 180.0
	move_speed = 2.0
	turn_speed = 2.2
	attack_damage = 25.0
	attack_reach = 2.4
	knockback_resist = 0.7
	eye_height = 1.7
	marker_height = 2.3
	material_kind = ExhibitMaterial.Kind.METAL
	dust_value = 8
	brain.reaction_time = 1.0
	brain.attack_range = 2.0
	brain.windup = 0.95
	brain.recovery = 1.0


func _build_body() -> void:
	add_collider(0.42, 2.0)
	rig = KnightRig.build(self)
	if rig == null:
		_build_greybox()
	add_hurtbox(box_shape(Vector3(0.62, 1.45, 0.45)), Vector3(0, 0.85, 0))
	var head_zone := add_hurtbox(sphere_shape(0.2), Vector3(0, 1.8, 0), true)
	if rig != null:
		rig.track(head_zone, &"head")


func _build_greybox() -> void:
	var steel := body_material(Color(0.62, 0.64, 0.68))
	var dark := body_material(Color(0.25, 0.26, 0.3))
	add_part(box_mesh(Vector3(0.62, 0.8, 0.4)), Vector3(0, 1.2, 0), steel)
	add_part(box_mesh(Vector3(0.5, 0.3, 0.35)), Vector3(0, 0.7, 0), dark)
	for x in [-0.15, 0.15]:
		add_part(box_mesh(Vector3(0.18, 0.7, 0.2)), Vector3(x, 0.35, 0), steel)
	add_part(box_mesh(Vector3(0.32, 0.36, 0.34)), Vector3(0, 1.8, 0), steel)
	add_part(box_mesh(Vector3(0.22, 0.04, 0.02)), Vector3(0, 1.82, -0.175), dark)
	add_part(box_mesh(Vector3(0.06, 0.06, 1.0)), Vector3(0.42, 1.2, -0.5), steel)
	_shield = add_part(box_mesh(Vector3(0.7, 1.0, 0.08)), Vector3(-0.1, 1.1, -0.42), body_material(Color(0.55, 0.12, 0.1)))


func _blocks(info: DamageInfo) -> bool:
	return ShieldGuard.blocks(-global_transform.basis.z, info.direction, info.kind, brain.is_stunned())


func _on_damaged(info: DamageInfo) -> void:
	if info.amount >= 15.0:
		# the model loses one of its plates; the greybox (or a bare suit)
		# spits a steel chunk
		if rig is KnightRig and (rig as KnightRig).shed_plate(info):
			return
		var fling := Vector3(randf_range(-2.0, 2.0), 3.0, randf_range(-2.0, 2.0))
		Fx.chunk(info.position, ExhibitMaterial.color(material_kind), 0.14, fling)


## (the greybox's shield arm back up before it dozes)
func _may_doze() -> bool:
	return _shield == null or absf(_shield.rotation.x) < DOZE_STILL


func _update_visuals(delta: float) -> void:
	super(delta)
	if _shield == null:
		return   # the model's rig lowers its own shield arm
	var lowered := brain.is_stunned()
	var weight := 1.0 - exp(-10.0 * delta)
	_shield.rotation.x = lerpf(_shield.rotation.x, -1.2 if lowered else 0.0, weight)
	_shield.position.y = lerpf(_shield.position.y, 0.6 if lowered else 1.1, weight)
