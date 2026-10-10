class_name Wolf
extends Enemy
## Fast, fragile stuffed wolf. Crouches, then pounces from up to 6 m on an
## arc aimed to land on the target, biting mid-air. Skids to a halt on
## landing and is open to punishment while it recovers. Sheds sawdust.

@export var max_leap_speed: float = 13.0
@export var leap_lift: float = 3.5

var _leaping := false
var _leap_hit := false
var _airborne := false


func _configure() -> void:
	max_health = 35.0
	move_speed = 6.5
	turn_speed = 12.0
	attack_damage = 10.0
	attack_reach = 1.7
	eye_height = 0.8
	marker_height = 1.3
	material_kind = ExhibitMaterial.Kind.TAXIDERMY
	dust_value = 4
	notice_sound = &"growl"
	leash = PerceptionRules.HUNTER_LEASH
	brain.reaction_time = 0.6
	brain.attack_range = 6.0
	brain.windup = 0.45
	brain.recovery = 0.9


func _build_body() -> void:
	add_collider(0.35, 0.9)
	rig = WolfRig.build(self)
	if rig == null:
		_build_greybox()
	var body_zone := add_hurtbox(box_shape(Vector3(0.44, 0.48, 1.0)), Vector3(0, 0.6, 0))
	var head_zone := add_hurtbox(sphere_shape(0.2), Vector3(0, 0.82, -0.62), true)
	if rig != null:
		# hit zones ride on the model: a crouch, a pounce, a stunned wolf
		# lying on its side
		rig.track(body_zone, &"body", true)
		rig.track(head_zone, &"head")


func _build_greybox() -> void:
	var fur := body_material(Color(0.5, 0.38, 0.25))
	var dark := body_material(Color(0.28, 0.2, 0.14))
	add_part(box_mesh(Vector3(0.38, 0.4, 0.95)), Vector3(0, 0.6, 0), fur)
	add_part(box_mesh(Vector3(0.26, 0.26, 0.34)), Vector3(0, 0.8, -0.6), fur)
	add_part(box_mesh(Vector3(0.14, 0.12, 0.2)), Vector3(0, 0.74, -0.84), dark)
	for x in [-0.13, 0.13]:
		for z in [-0.35, 0.35]:
			add_part(box_mesh(Vector3(0.09, 0.42, 0.09)), Vector3(x, 0.21, z), dark)
	add_part(box_mesh(Vector3(0.08, 0.08, 0.4)), Vector3(0, 0.7, 0.62), fur, Vector3(25.0, 0.0, 0.0))


func _physics_process(delta: float) -> void:
	super(delta)
	if not _leaping:
		return
	if brain.state != EnemyBrain.State.ATTACK:
		_leaping = false
		return
	if not is_on_floor():
		_airborne = true
	elif _airborne:
		# landed: the bite window closes, the recovery is defenceless
		_airborne = false
		_leaping = false
		_external *= 0.25
		return
	if not _leap_hit and _target_alive() and global_position.distance_to(target.global_position) <= attack_reach and _has_line_of_sight():
		_leap_hit = true
		_deal_damage()


func _on_strike() -> void:
	if not _target_alive():
		return
	var to := target.global_position - global_position
	to.y = 0.0
	if to.length() <= attack_reach:
		super()
		return
	var airtime := 2.0 * leap_lift / GRAVITY
	_external = to.normalized() * clampf(to.length() / airtime, 4.0, max_leap_speed)
	velocity.y = leap_lift
	_leaping = true
	_leap_hit = false
	_airborne = false
	Sfx.play_at(&"growl", global_position)
