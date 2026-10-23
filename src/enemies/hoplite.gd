class_name Hoplite
extends Enemy
## The marble hoplite of the Greek wing (design pietro-1-projekt 5.3),
## built on the knight's shield: 140 HP, a round shield covering 60 degrees
## either side of its front (not electric hits, not steep shots from above,
## not while stunned: the taser drops it), a spear thrust from 3 m (a 0.7 s
## telegraph: the shield comes up, the spear draws back, its bronze tip
## glints; then a lunge and the thrust, 18) and a heavy recovery. Its weak
## point is the face in the helmet's eye openings, just over the shield
## rim. Two or three awake hoplites close together fight as a phalanx
## (Phalanx): a line across the way to the guard with overlapping shields
## (each man's cover widens toward his neighbours; the shield plates close
## the gap between them), wheeling slowly, advancing at its slowest man's
## pace, closing ranks when a man falls out. Asleep it is a statue with its
## spear upright. Marble chips fly off hard hits; a blow to the head knocks
## off its crest, low blows its greaves. The model "hoplite" moves through
## a HopliteRig; without it a greybox.

const KIND := &"hoplite"
const SHIELD_HALF_ARC := 60.0
const THRUST_CONE_DEG := 30.0
## The lunge of the thrust (m/s, dies down on the floor: ~0.6 m).
const LUNGE := 6.0
## Hit zones: the shield plate (the aspis on the left forearm, the model's
## "shield" pivot), the body, the helmet and the face (weak point; the
## model's "face" marker).
const SHIELD_SIZE := Vector3(0.9, 0.9, 0.1)
const SHIELD_AT := Vector3(-0.12, 1.18, -0.42)
const BODY_SIZE := Vector3(0.5, 1.3, 0.38)
const BODY_Y := 0.8
const HELMET_AT := Vector3(0.0, 1.72, 0.01)
const HELMET_RADIUS := 0.15
const FACE_AT := Vector3(0.0, 1.715, -0.11)
const FACE_RADIUS := 0.085
## Seconds between looks for comrades to form a phalanx with.
const JOIN_CHECK := 0.3
## Calm hoplites this close (m, the same room) are a line: when one of them
## goes to look at something the others go with it (quietly), whatever the
## noise's cap of investigators (backlog #25: the line moves as one). Only
## the one that heard it calls its line - the comrades it called do not call
## theirs in turn, or a long row of them would all go.
const LINE_RADIUS := 8.0
## A line is at most this many comrades besides itself (the nearest): three
## men go to look, never more.
const LINE_MAX := 2
## Marble chips fly off a hit of at least CHIP_DAMAGE; a head hit of
## PLATE_DAMAGE knocks the crest off, a low one (under GREAVE_HEIGHT) a
## greave.
const CHIP_DAMAGE := 12.0
const PLATE_DAMAGE := 20.0
const GREAVE_HEIGHT := 0.6

var _join_timer: float = 0.0
## It has called its line for this errand (cleared when it rests again).
var _line_called := false


func _configure() -> void:
	max_health = 140.0
	move_speed = 2.1
	turn_speed = 2.6
	attack_damage = 18.0
	attack_reach = 3.4
	knockback_resist = 0.6
	eye_height = 1.7
	marker_height = 2.4
	material_kind = ExhibitMaterial.Kind.MARBLE
	dust_value = 7
	notice_sound = &"bust_grind"
	block_sound = &"hoplite_shield"
	windup_lean = 0.05
	strike_lean = -0.1
	brain.reaction_time = 0.9
	brain.attack_range = 3.0
	brain.windup = 0.7
	brain.recovery = 0.9


func _ready() -> void:
	super()
	_join_timer = randf() * JOIN_CHECK


func _exit_tree() -> void:
	Phalanx.leave(self)
	super()


func _build_body() -> void:
	add_collider(0.36, 1.95)
	rig = HopliteRig.build(self)
	if rig == null:
		_build_greybox()
	var body_zone := add_hurtbox(box_shape(BODY_SIZE), Vector3(0.0, BODY_Y, 0.0))
	var face_zone := add_hurtbox(sphere_shape(FACE_RADIUS), FACE_AT, true)
	var helmet_zone := add_hurtbox(sphere_shape(HELMET_RADIUS), HELMET_AT)
	var shield_zone := add_hurtbox(box_shape(SHIELD_SIZE), SHIELD_AT)
	if rig != null:
		rig.track(body_zone, &"torso", true)
		rig.track(face_zone, &"head")
		rig.track(helmet_zone, &"head")
		rig.track(shield_zone, &"shield", true)


func _build_greybox() -> void:
	var marble := body_material(Color(0.9, 0.88, 0.82))
	var bronze := body_material(Color(0.55, 0.38, 0.2))
	var paint := body_material(Color(0.62, 0.22, 0.16))
	add_part(box_mesh(Vector3(0.46, 0.6, 0.3)), Vector3(0, 1.25, 0), marble)
	add_part(box_mesh(Vector3(0.5, 0.25, 0.34)), Vector3(0, 0.9, 0), paint)
	for x in [-0.11, 0.11]:
		add_part(box_mesh(Vector3(0.15, 0.85, 0.16)), Vector3(x, 0.43, 0), marble)
	add_part(box_mesh(Vector3(0.26, 0.3, 0.28)), Vector3(0, 1.72, 0), marble)
	add_part(box_mesh(Vector3(0.05, 0.16, 0.36)), Vector3(0, 1.92, 0.02), paint)
	add_part(box_mesh(Vector3(0.9, 0.9, 0.08)), SHIELD_AT, bronze)
	add_part(box_mesh(Vector3(0.04, 0.04, 2.8)), Vector3(0.33, 1.08, -0.6), marble)


## Its phalanx (null: it fights alone).
func phalanx() -> Phalanx:
	return Phalanx.of(self)


## How far either side of its front the shield covers a hit travelling
## along [param direction]: wider toward a neighbour in the line.
func shield_arc(direction: Vector3) -> float:
	var arc := SHIELD_HALF_ARC
	var pack := phalanx()
	if pack == null:
		return arc
	var sides := pack.neighbours(self)
	var toward := Vector3(-direction.x, 0.0, -direction.z)
	var side := toward.dot(Phalanx.right_of(-global_basis.z))
	if (side > 0.0 and sides.y > 0) or (side < 0.0 and sides.x > 0):
		arc += Phalanx.OVERLAP_ARC
	return arc


func _physics_process(delta: float) -> void:
	if brain.state == EnemyBrain.State.DESTROYED or is_frozen():
		return
	_join_timer -= delta
	if _join_timer <= 0.0:
		_join_timer = JOIN_CHECK
		_look_for_comrades()
	var pack := phalanx()
	if pack != null and _target_alive():
		pack.update(delta, target.global_position)
	super(delta)


## Hunting and alone, it forms a line with the hunting hoplites near it in
## its room (or joins theirs).
func _look_for_comrades() -> void:
	if not brain.is_hunting() or phalanx() != null:
		return
	var room := current_room()
	var near: Array = []
	for other in PerceptionWorld.exhibits():
		var comrade := other as Hoplite
		if comrade == null or comrade == self or not comrade.brain.is_hunting() or not comrade.is_inside_tree():
			continue
		if comrade.global_position.distance_to(global_position) > Phalanx.JOIN_RADIUS:
			continue
		if room != &"" and comrade.current_room() != room:
			continue
		near.append(comrade)
	if not near.is_empty():
		Phalanx.join(self, near)


## Sent to look at a noise, it takes its line along at once (so the line
## turns and steps off together, whoever of it the noise's cap picked).
func react(point: Vector3, point_room: StringName, reaction: ReactionRules.Reaction, source: StringName = &"") -> bool:
	var awake := super(point, point_room, reaction, source)
	if reaction == ReactionRules.Reaction.INVESTIGATE and brain.state == EnemyBrain.State.SUSPICIOUS and _within_bounds(point, point_room):
		_rally_line(point)
	return awake


## Going to look at something (however it came to), it takes its line
## along: the calm hoplites near it in its room come too, quietly.
func _on_state_changed(from: EnemyBrain.State, to: EnemyBrain.State) -> void:
	super(from, to)
	if to == EnemyBrain.State.DORMANT or to == EnemyBrain.State.PATROL:
		_line_called = false
	elif to == EnemyBrain.State.INVESTIGATE and from == EnemyBrain.State.SUSPICIOUS:
		_rally_line(brain.last_known)


## Calls its line once per errand - and only when it went to look on its own
## account: not when it was called itself (quiet), nor when it saw the guard.
func _rally_line(point: Vector3) -> void:
	if _line_called or brain.quiet or brain.spotted():
		return
	_line_called = true
	var room := current_room()
	var near: Array = []
	for other in PerceptionWorld.exhibits():
		var comrade := other as Hoplite
		if comrade == null or comrade == self or not comrade.is_inside_tree() or comrade.is_frozen():
			continue
		if not comrade.brain.is_calm() and comrade.brain.state != EnemyBrain.State.SUSPICIOUS:
			continue
		if comrade.brain.spotted():
			continue   # it saw the guard: its own hunt comes first
		var distance := comrade.global_position.distance_to(global_position)
		if distance > LINE_RADIUS:
			continue
		if room != &"" and comrade.current_room() != room:
			continue
		near.append([distance, comrade])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in mini(near.size(), LINE_MAX):
		var comrade: Hoplite = near[i][1]
		comrade.end_doze()   # (its sleep caught up before it is told to keep quiet)
		comrade.brain.quiet = true
		comrade.brain.hear(point, true)


## In a phalanx it walks to its place in the line and faces the line's
## front; alone it closes to spear reach on the attack ring.
func _steer(delta: float, has_target: bool) -> Vector3:
	var pack := phalanx()
	if pack != null and brain.state == EnemyBrain.State.HUNT and has_target and brain.knows_guard():
		EnemyCrowd.release(self)
		var place := pack.goal_for(self)
		var move := Vector3.ZERO
		if Vector2(place.x - global_position.x, place.z - global_position.z).length() > 0.12:
			move = _chase_direction(delta, place) * move_speed * pack.pace_for(self)
		_turn_to_yaw(atan2(-pack.front.x, -pack.front.z), delta)
		return move
	return super(delta, has_target)


## A spear fighter keeps its place on the ring at spear reach.
func _uses_attack_ring() -> bool:
	return brain.attack_range > 0.0


func _blocks(info: DamageInfo) -> bool:
	return ShieldGuard.blocks(-global_basis.z, info.direction, info.kind, brain.is_stunned(), shield_arc(info.direction))


## The thrust: a lunge, and the spear finds him in reach within its cone.
func _on_strike() -> void:
	if not _target_alive():
		return
	var forward := -global_basis.z
	Sfx.play_at(&"hoplite_thrust", global_position + Vector3.UP * 1.5)
	shove(forward * LUNGE)
	var to := target.global_position - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() > attack_reach or flat.length() < 0.01:
		return
	if forward.dot(flat.normalized()) >= cos(deg_to_rad(THRUST_CONE_DEG)) and _has_line_of_sight():
		_deal_damage()


func _on_damaged(info: DamageInfo) -> void:
	if info.periodic or info.amount < CHIP_DAMAGE:
		return
	var fling := Vector3(info.direction.x, 0.0, info.direction.z).normalized() * randf_range(1.0, 2.5) \
			+ Vector3(randf_range(-1.0, 1.0), randf_range(2.5, 4.0), randf_range(-1.0, 1.0))
	var body := rig as HopliteRig
	if body == null:
		Fx.chunk(info.position, ExhibitMaterial.color(material_kind), randf_range(0.06, 0.11), fling)
		return
	body.chip(info.position, fling)
	if info.amount < PLATE_DAMAGE:
		return
	var height := info.position.y - global_position.y
	if info.weak_point or height > 1.6:
		body.shed("plate_crest", info.direction)
	elif height < GREAVE_HEIGHT:
		var local := global_transform.affine_inverse() * info.position
		body.shed("plate_greave_l" if local.x < 0.0 else "plate_greave_r", info.direction)


## Its own chips fly off a heavy hit (no generic ones on top).
func _chips_on_hits() -> bool:
	return false
