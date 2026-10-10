class_name General
extends Guardian
## Generał samurajów - the Samurai General, Asia's wing guardian (design
## 7.4; plan docs/superpowers/plans/2026-10-03-straznik-general.md): an
## empty o-yoroi 2.7 m to the helmet, hanging on its stand behind the post
## in the middle of the Japanese garden under the moon. The guard crosses
## the start line: the armour flies together off the stand piece by piece
## (feet, legs, hips, cuirass, arms, shoulder guards, helmet - a clank at
## each, the ember eyes catch), he draws the nodachi from the scabbard at
## his hip and settles into chudan. Then the duel (GeneralBrain holds every
## number):
## 1. his GUARD: chudan, suri-ashi toward the guard when far; a hit from the
##    front (ShieldGuard's arc) glances off the blade - sparks, a ricochet,
##    a grey marker; his face and the agemaki knot on his back are the weak
##    points (gold markers), the armour takes little;
## 2. the DASH CUT: the blade rises to jodan and glints (>= 0.7 s before the
##    cut), a lane on the gravel follows the guard then locks; the lunge
##    through the guard's place and on (nuki-do: the cut in passing); a miss
##    leaves him stumbling with his back to the guard, a hit ends in chiburi;
##    rocks and lanterns end the lane short (cover);
## 3. the CLOSE CUT up close: jodan, kesa-giri into a cone before him;
## 4. the TASER opens him: in his guard, a telegraph or a recovery it stuns
##    him (then he is immune a while); a FIST on the stunned General finishes
##    the stun for a share of his health, once, and sends him reeling.
## Phase 2 (< 66 %): he leaps onto the tea house eave and shoots volleys of
## ember arrows onto marks (two volleys, or one once his face is hit), again
## every so often. Phase 3 (< 33 %): he plants the sword, the cherry sheds
## its petals, and his dashes come as feints: a whirl of petals, two figures
## - only the real blade glints. His fall: GeneralFall; the keeper drops the
## shard. The tea house (the haven next door) gives no rest until he falls.
## Body space: origin on the floor between the feet, -Z his front.

## Announced (the warning starts) and landed (the damage moment / the
## active part): dash, close, feint, leap_up, volley, leap_down.
signal telegraphed(attack: StringName)
signal struck(attack: StringName)
## A hit glanced off the blade.
signal blocked_hit
## The taser took him; a fist finished the stun.
signal stunned
signal finished_off

const A := GeneralBrain.Attack
const S := GeneralBrain.State
const T := GeneralBrain.Stage
const NAMES := {
	GeneralBrain.Attack.DASH: &"dash", GeneralBrain.Attack.CLOSE: &"close", GeneralBrain.Attack.FEINT: &"feint",
	GeneralBrain.Attack.LEAP_UP: &"leap_up", GeneralBrain.Attack.VOLLEY: &"volley", GeneralBrain.Attack.LEAP_DOWN: &"leap_down",
}
## Damage factors by zone.
const FACE := 1.0
const BACK := 0.75
const ARMOUR := 0.15
## His guard's arc (either side of his front, deg).
const GUARD_ARC := 70.0
## His collider (centre, size), body space.
const BODY_BOX := [Vector3(0.0, 1.4, 0.0), Vector3(0.9, 2.7, 0.9)]
## The stand hangs this far behind the post (m).
const STAND_BACK := 1.2
## The leaps: how high the arc rises over the straight line (up, down), how
## far from the perch he comes down at most (m), the room a landing needs.
const LEAP_APEX := Vector2(1.4, 2.0)
const LEAP_REACH := 10.0
const LANDING_ROOM := 0.8
## The volley: the first mark leads the guard by this share of his run over
## the flight; the others stand on a ring of this radius round it.
const ARROW_LEAD := 0.5
const VOLLEY_RING := 2.4
## The cherry's crown off the post (the greybox garden's; a dressed tree's
## Petals_* emitters take over).
const CHERRY_CROWN := Vector3(5.5, 3.4, -1.5)
## The transformation's moments (progress): the sword planted, the gust.
const PLANT_AT := 0.45
const GUST_AT := 0.5
## Turning (rad/s): in his guard, in a telegraph, stumbling after a miss.
const TURN := 2.6
const TURN_AIM := 3.2
const TURN_STUMBLE := 1.1
const ACCELERATION := 8.0
const BRAKING := 12.0
## A dash's lane ends at least this far from a wall or a rock (m).
const DASH_MARGIN := 1.2
## The lane starts this far ahead of his feet.
const LANE_AHEAD := 0.3
## The guard's body radius.
const GUARD_RADIUS := 0.4
## Probe heights for the way ahead (m).
const PROBE_HEIGHTS: Array[float] = [0.4, 1.0]
const EMBER := Color(1.0, 0.55, 0.2)
const GOLD := Color(1.0, 0.82, 0.5)
const STEEL := Color(0.85, 0.9, 1.0)
## The waking: the parts whose landing clanks (in the order they come).
const CLANK_PARTS: Array[String] = ["foot_r", "thigh_r", "pelvis", "torso", "upperarm_r", "sode_r", "head"]

var brain := GeneralBrain.new()
var feet := GeneralFootwork.new()
var rig: GeneralRig
var moves: GeneralMoves
## His stand (the keeper's, or his own in a bare arena).
var stand: Node3D
## The dash's line (world): where it runs from and to, its direction.
var dash_from := Vector3.ZERO
var dash_to := Vector3.ZERO
var dash_dir := Vector3.FORWARD
## Where the lane locked on the guard (world).
var dash_target := Vector3.ZERO
## The lane's lock happened.
var dash_locked := false

## His arrows in flight (and stuck).
var arrows: Array[Node] = []
## The perch on the eave (world; the keeper's general_perch point, or the
## teahouse model's roof_perch when one stands here).
var perch := Transform3D.IDENTITY
var has_perch := false
## Where the leap down comes down (world, floor).
var landing := Vector3.ZERO
## Where each arrow of the volley under way will come down.
var volley_spots: Array[Vector3] = []

var _look: Node3D
var _zones := {}
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO
var _flying := false
var _land_mark: GroundMark
var _volley_marks: Array = []
var _volley_offsets: Array[Vector3] = []
var _creaked := false
var _perch_searched := false
var _shove_grace: float = 0.0
## Phase 3: the petals and the feint's double.
var storm: PetalStorm
var phantom: GeneralPhantom
var _planted := false
var _gusted := false
var _feint_lanes := false
var _phantom_burst := false
var _zone_factor: float = 1.0
var _gold_frame: int = -1
var _lane: GroundMark
var _cone: GroundMark
var _speed: float = 0.0
var _dash_hit := false
var _glinted := false
var _clanked := {}
var _drawn := false
var _layer_saved: int = 0
var _guard_before := Vector3.ZERO
var _guard_velocity := Vector3.ZERO
## Where he stood when this physics step began (the lunge and the leap are
## flown by hand: the feet need the real way he went, not the velocity).
var _frame_start := Vector3.ZERO
var _stun_spark: float = 0.0
var _eye_light: OmniLight3D
var _glint_light: OmniLight3D


func _init() -> void:
	# (the plan's 1250 measured 85 s for the scenario's bot, which neither
	# flanks nor stuns: his face is behind the blade in chudan, open only in
	# the telegraphs, the stun and on the roof)
	max_health = 1000.0


## His stand behind the post (GuardianKeeper, every night); after his fall
## the kneeling armour with the sword planted stays on the post.
static func dress_arena(level: MuseumFloorLevel, parent: Node3D) -> Array[Node3D]:
	var props: Array[Node3D] = []
	if level.markers.has(&"guardian_general"):
		var post: Transform3D = level.markers[&"guardian_general"]
		var rack := make_stand(post.translated_local(Vector3(0.0, 0.0, STAND_BACK)))
		parent.add_child(rack)
		props.append(rack)
		if GameState.is_guardian_defeated(&"general"):
			var fallen := make_fallen(post)
			parent.add_child(fallen)
			props.append(fallen)
	return props


## The fallen General: his armour kneeling on the post, the nodachi
## planted, the eyes dead (a static piece of the arena after his fall;
## group "general_fallen").
static func make_fallen(at: Transform3D) -> Node3D:
	var root := Node3D.new()
	root.name = "GeneralFallen"
	root.add_to_group(&"general_fallen")
	root.transform = at
	var rig := GeneralRig.create(root)
	rig.apply(GeneralFall.kneel_pose())
	root.set_meta(&"rig", rig)
	return root


## The armour stand: a cedar post with a crossbar and a base (greybox; no
## collision - a thin post), in group "general_stand".
static func make_stand(at: Transform3D) -> Node3D:
	var root := Node3D.new()
	root.name = "GeneralStand"
	root.add_to_group(&"general_stand")
	var cedar := StandardMaterial3D.new()
	cedar.albedo_color = Color(0.42, 0.3, 0.2)
	cedar.roughness = 0.9
	for spec: Array in [[Vector3(0.0, 1.3, 0.0), Vector3(0.14, 2.6, 0.14)], [Vector3(0.0, 2.1, 0.0), Vector3(1.3, 0.1, 0.1)],
			[Vector3(0.0, 0.05, 0.0), Vector3(0.8, 0.1, 0.8)]]:
		var view := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = spec[1]
		view.mesh = box
		view.material_override = cedar
		view.position = spec[0]
		root.add_child(view)
	root.transform = at
	return root


# --- body -------------------------------------------------------------------

func _build_body() -> void:
	_look = Node3D.new()
	_look.name = "Look"
	add_child(_look)
	rig = GeneralRig.create(_look)
	moves = GeneralMoves.new(rig)
	rig.lend_arrow()
	var shape := BoxShape3D.new()
	shape.size = BODY_BOX[1]
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = BODY_BOX[0]
	add_child(collider)
	_build_zones()
	_eye_light = OmniLight3D.new()
	_eye_light.light_color = EMBER
	_eye_light.omni_range = 3.0
	_eye_light.light_energy = 0.0
	_eye_light.shadow_enabled = false
	rig.part("head").add_child(_eye_light)
	_eye_light.position = Vector3(0.0, 0.2, -0.15)
	_glint_light = OmniLight3D.new()
	_glint_light.light_color = STEEL
	_glint_light.omni_range = 4.0
	_glint_light.light_energy = 0.0
	_glint_light.shadow_enabled = false
	rig.part("sword").add_child(_glint_light)
	_glint_light.position = rig.blade_axis_rest * 1.5
	_find_stand()
	rig.set_stand(stand.global_transform)
	_find_perch()
	feet.place(global_transform)
	brain.telegraphed.connect(_on_telegraphed)
	brain.struck.connect(_on_struck)
	brain.finished.connect(_on_finished)
	brain.state_changed.connect(_on_state_changed)
	brain.stunned.connect(func() -> void: stunned.emit())
	feet.step.connect(_on_step)
	_layer_saved = collision_layer
	rig.apply(moves.compose(brain, feet, global_transform, 0.0))


## Hit zones on the parts (they move with him): the face and the back
## (weak), the armour (everything else).
func _build_zones() -> void:
	var armour := _zone(&"armour")
	for view in rig.meshes:
		var key := String(view.name)
		if key == "arrow" or key == "bow" or key == "sword" or view.mesh == null:
			continue
		var box := view.get_aabb()
		var shape := BoxShape3D.new()
		shape.size = box.size.max(Vector3.ONE * 0.1)
		view.add_child(Hurtbox.make(armour, shape, box.get_center()))
	# the sword's hurtbox: the blade (a hit on it is armour, blocked in his
	# guard)
	var sword := rig.part("sword")
	if sword != null:
		var blade := BoxShape3D.new()
		blade.size = Vector3(0.08, 0.08, 1.8)
		var along := LimbIK.aim(Basis.IDENTITY, Vector3.FORWARD, rig.blade_axis_rest)
		var hurt := Hurtbox.make(armour, blade, rig.blade_axis_rest * 0.9)
		hurt.basis = along
		sword.add_child(hurt)
	# the weak points stand proud of the armour's boxes (a shot from the
	# front finds the face under the visor before the helmet, one from
	# behind the agemaki knot before the cuirass)
	var face := BoxShape3D.new()
	face.size = Vector3(0.26, 0.24, 0.36)
	rig.part("head").add_child(Hurtbox.make(_zone(&"face"), face, (rig.rest["face"] as Transform3D).origin + Vector3(0.0, -0.02, -0.15), true))
	var back := BoxShape3D.new()
	back.size = Vector3(0.3, 0.3, 0.22)
	rig.part("torso").add_child(Hurtbox.make(_zone(&"back"), back, (rig.rest["back"] as Transform3D).origin + Vector3(0.0, 0.0, 0.1), true))


func _zone(zone_name: StringName) -> GuardianZone:
	var zone := GuardianZone.make(self, zone_name)
	add_child(zone)
	_zones[zone_name] = zone
	return zone


## His perch: the arena's general_perch point (the eave's corner). No perch:
## no roof visits.
func _find_perch() -> void:
	var found: Array = points.get(&"perch", [])
	if not found.is_empty():
		perch = found[0]
		has_perch = true
	brain.can_roof = has_perch


## A dressed tea house's own roof_perch node (once it stands here) takes
## over the greybox perch: looked for once, at the first leap.
func _search_roof_perch() -> void:
	if _perch_searched:
		return
	_perch_searched = true
	for node in _dressing_root().find_children("roof_perch", "Node3D", true, false):
		var spot := node as Node3D
		if spot != null and spot.global_position.distance_to(home.origin) < 16.0:
			var facing := home.origin - spot.global_position
			perch = Transform3D(Basis.looking_at(Vector3(facing.x, 0.0, facing.z).normalized(), Vector3.UP), spot.global_position)
			has_perch = true
			return


## Where the arena's dressing hangs - the level (the keeper's), else the
## node he stands in (a dev arena, a test) - searched for the tea house's
## roof_perch and the cherry's Petals_* instead of the whole tree.
func _dressing_root() -> Node:
	var keeper := get_parent() as GuardianKeeper
	if keeper != null and keeper.level != null:
		return keeper.level
	return get_parent()


## The stand the keeper raised behind the post, or one of his own (a dev
## arena, a test).
func _find_stand() -> void:
	var at := global_transform.translated_local(Vector3(0.0, 0.0, STAND_BACK))
	for node in get_tree().get_nodes_in_group(&"general_stand"):
		var rack := node as Node3D
		if rack != null and rack.global_position.distance_to(at.origin) < 1.0:
			stand = rack
	if stand == null:
		stand = make_stand(at)
		stand.top_level = true
		add_child(stand)
		stand.global_transform = at


# --- damage -------------------------------------------------------------------

func take_zone_damage(info: DamageInfo, zone: StringName) -> void:
	if info == null:
		return
	if state == State.FIGHT and hit_counts() and _blocks(info):
		_block(info)
		return
	var weak := zone == &"face" or zone == &"back"
	match zone:
		&"face":
			_zone_factor = FACE
		&"back":
			_zone_factor = BACK
		_:
			_zone_factor = ARMOUR
	info.weak_point = weak
	info.blocked = not weak
	# a fist on the stunned General: the finisher (a share of his health
	# instead of the fist's own blow), once a stun
	if state == State.FIGHT and info.can_finish and brain.state == S.STUNNED and brain.finish():
		info.amount = GeneralBrain.FINISH_FRACTION * max_health
		info.weak_point = true
		info.blocked = false
		_zone_factor = 1.0
		_finisher(info)
	super(info, zone)
	_zone_factor = 1.0
	if state != State.FIGHT or not hit_counts():
		return
	if info.kind == DamageInfo.Kind.ELECTRIC and brain.shock():
		_shocked(info)
	if zone == &"face" and brain.on_roof:
		brain.hit_face()


## True while his guard turns [param info]: in his stance, from the front.
func _blocks(info: DamageInfo) -> bool:
	if not brain.blocking():
		return false
	return ShieldGuard.blocks(-global_basis.z, info.direction, info.kind, false, GUARD_ARC)


## A hit glances off the blade: sparks, a ricochet, the clang, a grey
## marker; the blade flicks toward it.
func _block(info: DamageInfo) -> void:
	info.blocked = true
	if info.effects and not info.periodic:
		var at := info.position if info.position.length() > 0.01 else rig.glint_point()
		Fx.impact(at, -info.direction, ExhibitMaterial.Kind.METAL, 1.6)
		var off := Vector3(randf_range(-1.0, 1.0), randf_range(0.2, 1.0), randf_range(-1.0, 1.0)).normalized()
		Fx.tracer(at, at + off * randf_range(2.0, 4.0), STEEL, 0.015, 0.08)
		Sfx.play_at(&"hit_metal", at, 2.0, 0.15, 1.4)
		Sfx.play_at(&"block", at, -2.0)
		moves.parry(global_basis.inverse() * info.direction)
		rig.flash(0.2)
	if not info.periodic:
		Events.hit_landed.emit(self, info, false)
	blocked_hit.emit()


func _damage_factor(_info: DamageInfo) -> float:
	return _zone_factor


## The taser took him: arcs over the armour, the blade drops.
func _shocked(info: DamageInfo) -> void:
	var at := info.position if info.position.length() > 0.01 else global_position + Vector3.UP * 1.5
	Fx.arc(at, rig.part("head").global_position)
	Fx.arc(at, rig.tip_point())
	Fx.flash(global_position + Vector3.UP * 1.6, Color(0.6, 0.8, 1.0), 3.0, 5.0, 0.2)
	Sfx.play_at(&"taser", global_position + Vector3.UP * 1.5, 0.0)
	Events.shake_requested.emit(0.2)


## The finisher's look: the armour rings, he reels.
func _finisher(info: DamageInfo) -> void:
	Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.METAL, 3.0)
	Fx.flash(info.position, GOLD, 4.0, 5.0, 0.2)
	Sfx.play_at(&"punch_hit", info.position, 4.0)
	Sfx.play_at(&"break_metal", info.position, -2.0)
	Fx.hitstop(0.06)
	Events.shake_requested.emit(0.35)
	rig.flash(1.0)
	finished_off.emit()


## The dash's lane on the gravel (while one shows).
func dash_lane() -> GroundMark:
	return _lane if _lane != null and is_instance_valid(_lane) else null


func _hit_effects(info: DamageInfo) -> void:
	if info.weak_point:
		Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.METAL, clampf(info.amount / 12.0, 1.0, 3.0))
		Fx.flash(info.position, GOLD, 2.5, 3.0, 0.08)
		Sfx.play_at(&"hit_metal", info.position, 1.0)
		rig.flash(0.6)
	else:
		# lacquer chips off the lames
		Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.METAL, 1.0)
		Fx.chunk(info.position, Color(0.15, 0.1, 0.1), randf_range(0.02, 0.05), info.normal * 2.0 + Vector3.UP * 1.0)
		Sfx.play_at(&"hit_metal", info.position, -6.0, 0.25)
		rig.flash(0.15)


## One blast can strike the face and the armour at once: the grey marker
## must not paint over the gold one.
func _report_hit(info: DamageInfo) -> void:
	var frame := Engine.get_physics_frames()
	if info.weak_point:
		_gold_frame = frame
	elif _gold_frame == frame:
		return
	Events.hit_landed.emit(self, info, false)


# --- the fight ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_frame_start = global_position
	super(delta)
	if state != State.FIGHT or is_frozen():
		return
	if not guard_alive():
		_idle_frame(delta)


func _on_phase(next: int) -> void:
	if next == 1:
		brain.wake()
	else:
		brain.set_phase(next)


func _fight_process(delta: float) -> void:
	var guard := target.global_position
	_guard_velocity = _guard_velocity.lerp((guard - _guard_before) / maxf(delta, 0.001), clampf(delta * 8.0, 0.0, 1.0))
	_guard_before = guard
	var local := to_local(guard)
	var distance := Vector2(local.x, local.z).length()
	var bearing := atan2(-local.x, -local.z)
	brain.update(delta, distance, bearing)
	_move(delta, guard, distance)
	moves.guard = to_local(guard + Vector3.UP * 1.4)
	moves.aim = (to_local(guard + Vector3.UP * 1.0) - Vector3(0.0, 2.0, 0.0)).normalized()
	_attack_frame(delta)
	feet.update(delta, global_transform, _travel(delta), _flying)
	_animate(delta)
	_state_frame(delta)
	if _shove_grace > 0.0:
		_shove_grace -= delta
		if _shove_grace <= 0.0 and not kinematic:
			collision_mask = Layers.WORLD | Layers.PLAYER
	if Engine.get_physics_frames() % 60 == 0:
		_tidy_arrows()


## The guard fell: whatever he was at runs out - a lunge or a leap is flown
## to its end, no lane or mark stays lit, no new attack begins (up on the
## eave he waits) - and he settles where he stands.
func _idle_frame(delta: float) -> void:
	_clear_marks()
	if phantom != null and is_instance_valid(phantom) and phantom.active:
		phantom.vanish()
	if brain.state != S.ROOF:
		brain.update(delta, INF, 0.0)
	_run_out(delta)
	_speed = move_toward(_speed, 0.0, BRAKING * delta)
	velocity.x = 0.0
	velocity.z = 0.0
	feet.update(delta, global_transform, _travel(delta), _flying)
	_animate(delta)
	_state_frame(delta)


## The part of an attack under way that moves the body, when the guard fell
## in the middle of it: the lunge is flown on (and ends on his feet), the leap
## comes down; the rest (cones, volleys, glints) just lapses.
func _run_out(delta: float) -> void:
	if brain.state != S.ATTACK:
		return
	match brain.attack:
		A.DASH, A.FEINT:
			if brain.stage == T.STRIKE:
				_dash_frame(delta, brain.stage_time() / maxf(brain.current_stage_length(), 0.01))
			elif brain.stage == T.RECOVER:
				_dash_end()
		A.LEAP_UP, A.LEAP_DOWN:
			if brain.stage == T.TELEGRAPH:
				_flight_frame()


## His real speed this physics step (world): the velocity - or, when the body
## is flown by hand (the lunge, the leap: kinematic), the way it went since
## the step began, which the footwork needs to carry the feet along.
func _travel(delta: float) -> Vector3:
	if kinematic:
		return (global_position - _frame_start) / maxf(delta, 0.001)
	return velocity


func _animate(delta: float) -> void:
	var pose := moves.compose(brain, feet, global_transform, delta)
	rig.apply(pose, delta)
	_eye_light.light_energy = 0.9 * clampf(pose.eyes, 0.0, 1.0)
	_glint_light.light_energy = 2.5 * pose.glint


# --- moving -------------------------------------------------------------------

func _move(delta: float, guard: Vector3, _distance: float) -> void:
	var wanted := brain.wanted_speed()
	var turn_to := rotation.y
	var rate := TURN
	var turning := true
	match brain.state:
		S.WAKING:
			turning = brain.draw_progress() > 0.2
			turn_to = _yaw_toward(guard)
		S.GUARD, S.REEL, S.TRANSFORM, S.ROOF:
			turn_to = _yaw_toward(guard)
		S.STUNNED:
			turning = false
		S.ATTACK:
			match brain.attack:
				A.DASH, A.FEINT:
					if brain.stage == T.TELEGRAPH:
						turning = not dash_locked
						rate = TURN_AIM
						turn_to = _yaw_toward(guard)
					elif brain.stage == T.RECOVER:
						rate = TURN_STUMBLE if not brain.landed else TURN
						turn_to = _yaw_toward(guard)
					else:
						turning = false
				A.CLOSE:
					turning = brain.stage == T.TELEGRAPH and brain.stage_time() < 0.4
					turn_to = _yaw_toward(guard)
				A.VOLLEY:
					turning = brain.stage == T.TELEGRAPH
					turn_to = _yaw_toward(guard)
				_:
					turning = brain.stage == T.TELEGRAPH and brain.stage_time() < 0.3
					turn_to = _yaw_toward(guard)
		_:
			turning = false
	if turning:
		var gap := wrapf(turn_to - rotation.y, -PI, PI)
		rotation.y = wrapf(rotation.y + clampf(gap, -rate * delta, rate * delta), -PI, PI)
	if kinematic:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	# the close cut steps in; the reel staggers back
	if brain.state == S.ATTACK and brain.attack == A.CLOSE and brain.stage == T.STRIKE:
		wanted = 2.2
	elif brain.state == S.REEL and brain.state_progress() < 0.5:
		wanted = -1.6
	elif brain.state == S.ATTACK and brain.attack == A.FEINT and brain.stage == T.TELEGRAPH:
		wanted = 0.0
	_speed = move_toward(_speed, wanted, (ACCELERATION if absf(wanted) > absf(_speed) else BRAKING) * delta)
	var forward := -global_basis.z
	velocity.x = forward.x * _speed
	velocity.z = forward.z * _speed
	if brain.state == S.ATTACK and brain.attack == A.FEINT and brain.stage == T.TELEGRAPH:
		_sidestep(delta)


## The world yaw that faces [param point].
func _yaw_toward(point: Vector3) -> float:
	var to := point - global_position
	return atan2(-to.x, -to.z)


## The feint's sidestep (phase 3: both figures out of the whirl; the
## phantom goes the other way).
func _sidestep(_delta: float) -> void:
	var across := _sidestep_velocity(1.0)
	velocity.x += across.x
	velocity.z += across.z


## The sidestep's velocity now for the figure on [param side] of the
## General's feint side (1 = the General, -1 = the phantom).
func _sidestep_velocity(side: float) -> Vector3:
	var t := brain.stage_time()
	if t < GeneralBrain.FEINT_HIDE or t > GeneralBrain.FEINT_APART:
		return Vector3.ZERO
	return global_basis.x * float(brain.feint_side) * side * GeneralBrain.SIDESTEP


## How far the way ahead along [param direction] is clear (m, up to
## [param limit]) from [param from].
func _clear_run(from: Vector3, direction: Vector3, limit: float) -> float:
	var space := get_world_3d().direct_space_state
	var best := limit
	for height in PROBE_HEIGHTS:
		var start := from + Vector3.UP * height
		var query := PhysicsRayQueryParameters3D.create(start, start + direction * limit, Layers.WORLD)
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			best = minf(best, start.distance_to(hit["position"]))
	return best


# --- the attacks ------------------------------------------------------------------

func _on_telegraphed(attack: A) -> void:
	_clear_marks()
	match attack:
		A.DASH:
			_glinted = false
			dash_locked = false
			dash_target = target.global_position if guard_alive() else to_global(Vector3(0.0, 0.0, -6.0))
			_make_lane()
			Sfx.play_at(&"tail_whoosh", rig.tip_point(), -8.0, 0.1, 0.8)
		A.FEINT:
			# the whirl hides him; the double steps out beside him; the lanes
			# come once the figures stand apart
			_glinted = false
			dash_locked = false
			_feint_lanes = false
			_phantom_burst = false
			dash_target = target.global_position if guard_alive() else to_global(Vector3(0.0, 0.0, -6.0))
			_ensure_storm()
			_ensure_phantom()
			storm.whirl(global_position)
			phantom.appear(global_transform)
			Sfx.play_at(&"tail_whoosh", global_position + Vector3.UP, -2.0, 0.1, 0.6)
		A.CLOSE:
			_cone = GroundMark.arc(0.5, GeneralBrain.CLOSE_REACH + 0.5, -GeneralBrain.CLOSE_ARC, GeneralBrain.CLOSE_ARC)
			get_parent().add_child(_cone)
			_cone.global_transform = Transform3D(global_basis.orthonormalized(), global_position)
			Sfx.play_at(&"tail_whoosh", rig.tip_point(), -8.0, 0.1, 0.9)
		A.LEAP_UP:
			_search_roof_perch()
			_leap_from = global_position
			_leap_to = perch.origin
			_flying = false
		A.LEAP_DOWN:
			landing = _landing_spot()
			_leap_from = global_position
			_leap_to = landing
			_flying = false
			_land_mark = GroundMark.disc(GeneralBrain.LAND_RADIUS)
			get_parent().add_child(_land_mark)
			_land_mark.global_transform = Transform3D(Basis.IDENTITY, landing)
			Sfx.play_at(&"tail_whoosh", global_position + Vector3.UP, -6.0, 0.1, 0.7)
		A.VOLLEY:
			_creaked = false
			_volley_begin()
	telegraphed.emit(NAMES[attack])


func _on_struck(attack: A) -> void:
	match attack:
		A.DASH:
			_dash_begin()
		A.FEINT:
			_phantom_gone()
			_dash_begin()
		A.CLOSE:
			_close_cut()
		A.LEAP_UP:
			_land_on_roof()
		A.LEAP_DOWN:
			_land_on_ground()
		A.VOLLEY:
			_loose_arrows()
	struck.emit(NAMES[attack])


func _on_finished(attack: A) -> void:
	match attack:
		A.DASH, A.FEINT:
			_dash_end()
			_clear_marks()
			if phantom != null:
				phantom.vanish()
		A.VOLLEY:
			pass   # the marks went with the arrows
		_:
			_clear_marks()


func _on_state_changed(_from: S, to: S) -> void:
	match to:
		S.WAKING:
			_clanked.clear()
			_drawn = false
		S.TRANSFORM:
			_planted = false
			_gusted = false
		S.STUNNED:
			_dash_end()
			_clear_marks()
			if phantom != null and is_instance_valid(phantom):
				phantom.vanish()


## Effects that run through an attack: the lane, the glint, the dash.
func _attack_frame(delta: float) -> void:
	if brain.state != S.ATTACK:
		return
	var progress := brain.stage_time() / maxf(brain.current_stage_length(), 0.01)
	match brain.attack:
		A.DASH, A.FEINT:
			if brain.stage == T.TELEGRAPH:
				var lock_at := brain.current_stage_length() - GeneralBrain.LANE_LOCK
				if not dash_locked and brain.stage_time() >= lock_at:
					dash_locked = true
				if not dash_locked and guard_alive():
					dash_target = dash_target.lerp(_led_target(), clampf(delta * 10.0, 0.0, 1.0))
				if brain.attack == A.FEINT:
					_feint_frame(delta)
				_place_lane()
				if _lane != null:
					_lane.progress = progress
				if moves.glint > 0.3 and not _glinted:
					_glinted = true
					Fx.flash(rig.glint_point(), STEEL, 3.0, 4.0, 0.25)
					Sfx.play_at(&"samurai_glint", rig.glint_point(), 2.0, 0.05)
			elif brain.stage == T.STRIKE:
				_dash_frame(delta, progress)
			else:
				_dash_end()   # on his feet for the recovery
		A.CLOSE:
			if brain.stage == T.TELEGRAPH and _cone != null and is_instance_valid(_cone):
				_cone.global_transform = Transform3D(global_basis.orthonormalized(), global_position)
				_cone.progress = progress
		A.LEAP_UP, A.LEAP_DOWN:
			if brain.stage == T.TELEGRAPH:
				if _land_mark != null and is_instance_valid(_land_mark):
					_land_mark.progress = progress
				_flight_frame()
		A.VOLLEY:
			if brain.stage == T.TELEGRAPH:
				_volley_frame(delta, progress)


## Where the cut will fall: the guard's place, led by his run over the
## lane's lock and half the lunge (GeneralBrain.DASH_LEAD).
func _led_target() -> Vector3:
	var at := target.global_position
	var ahead := GeneralBrain.LANE_LOCK + 0.5 * GeneralBrain.stage_length(brain.attack, T.STRIKE, brain.phase)
	return at + _flat(_guard_velocity) * ahead * GeneralBrain.per_phase(GeneralBrain.DASH_LEAD, brain.phase)


## The dash's line from [param from] through [param through] and
## DASH_OVERSHOOT on, ending DASH_MARGIN short of a wall or a rock and with
## room either side of its end: [direction, length].
func _aim_dash(from: Vector3, through: Vector3) -> Array:
	var to := through - from
	to.y = 0.0
	var direction := to.normalized() if to.length() > 0.1 else -_flat(global_basis.z).normalized()
	var length := to.length() + GeneralBrain.DASH_OVERSHOOT
	var clear := _clear_run(from, direction, length + DASH_MARGIN) - DASH_MARGIN
	length = clampf(minf(length, clear), 0.5, GeneralBrain.DASH_RANGE.y)
	var across := direction.cross(Vector3.UP).normalized()
	for i in 6:
		var end := from + direction * length
		var room_l := _clear_run(end, across, DASH_MARGIN * 0.7)
		var room_r := _clear_run(end, -across, DASH_MARGIN * 0.7)
		if minf(room_l, room_r) >= DASH_MARGIN * 0.7 - 0.001 or length <= 0.5:
			break
		length = maxf(length - 0.4, 0.5)
	return [direction, length]


## A lane mark on the gravel for a dash.
func _make_lane() -> void:
	_lane = GroundMark.lane(GeneralBrain.DASH_HALF_WIDTH * 2.0 + GUARD_RADIUS * 2.0, 6.0)
	get_parent().add_child(_lane)
	_place_lane()


## His dash's line from his feet through the (locked) target; the lane
## mark drawn along it (when one shows).
func _place_lane() -> void:
	var aimed := _aim_dash(global_position, dash_target)
	dash_dir = aimed[0]
	dash_from = global_position
	dash_to = global_position + dash_dir * float(aimed[1])
	_draw_lane(_lane, dash_from, dash_dir, float(aimed[1]))


static func _draw_lane(lane: GroundMark, from: Vector3, direction: Vector3, length: float) -> void:
	if lane == null or not is_instance_valid(lane):
		return
	var start := from + direction * LANE_AHEAD
	start.y = from.y
	lane.global_transform = Transform3D(Basis.looking_at(direction, Vector3.UP), start)
	lane.length = maxf(length - LANE_AHEAD, 0.3)


## The lunge begins: he flies the lane (kinematic), through the guard.
func _dash_begin() -> void:
	_place_lane()
	_dash_hit = false
	kinematic = true
	velocity = Vector3.ZERO
	_speed = 0.0
	collision_layer = 0
	collision_mask = Layers.WORLD
	if _lane != null and is_instance_valid(_lane):
		_lane.progress = 1.0
	Sfx.play_at(&"samurai_slash", rig.tip_point(), 2.0, 0.05)
	Fx.impact(global_position + Vector3.UP * 0.05, Vector3.UP, -1, 1.5)


## The lunge: along the lane, fast; the blade cuts whoever is in it.
func _dash_frame(_delta: float, progress: float) -> void:
	var before := global_position
	var k := MotionClip.eased(MotionClip.OUT, clampf(progress, 0.0, 1.0))
	global_position = dash_from.lerp(dash_to, k)
	if _dash_hit or not guard_alive():
		return
	var guard := target.global_position
	var flat := Vector3(guard.x, 0.0, guard.z)
	var a := Vector3(before.x, 0.0, before.z)
	var b := Vector3(global_position.x, 0.0, global_position.z)
	var near := Geometry3D.get_closest_point_to_segment(flat, a, b)
	if flat.distance_to(near) <= GeneralBrain.DASH_HALF_WIDTH + GUARD_RADIUS and absf(guard.y - global_position.y) < 1.6:
		_dash_hit = true
		brain.dash_landed()
		var info := DamageInfo.make(GeneralBrain.DASH_DAMAGE * damage_scale, DamageInfo.Kind.BLUNT, self)
		var side := signf((flat - a).cross(dash_dir).y)
		info.direction = (dash_dir + global_basis.x * (side if side != 0.0 else 1.0) * 0.8).normalized()
		info.knockback = GeneralBrain.DASH_KNOCKBACK
		info.position = guard + Vector3.UP
		target.call(&"take_damage", info)
		Fx.impact(info.position, -dash_dir, ExhibitMaterial.Kind.METAL, 1.5)
		Sfx.play_at(&"punch_hit", info.position, 3.0)
		Events.shake_requested.emit(0.3)


## The lunge ends: on his feet again where he stopped.
func _dash_end() -> void:
	if not kinematic or brain.on_roof or _flying:
		return
	_solid()
	feet.place(global_transform)
	Fx.impact(global_position + Vector3.UP * 0.05, Vector3.UP, -1, 1.2)
	Sfx.play_at(&"trex_scrape", global_position, -8.0, 0.1, 1.3)


## The close cut lands: whoever stands in the cone before him.
func _close_cut() -> void:
	_clear_marks(0.15)
	Sfx.play_at(&"samurai_slash", rig.tip_point(), 1.0, 0.05)
	if not guard_alive():
		return
	var local := to_local(target.global_position)
	var flat := Vector2(local.x, local.z)
	var bearing := absf(atan2(-local.x, -local.z))
	if flat.length() <= GeneralBrain.CLOSE_REACH + GUARD_RADIUS and bearing <= GeneralBrain.CLOSE_ARC + 0.15 and local.y > -1.0 and local.y < 2.2:
		var info := DamageInfo.make(GeneralBrain.CLOSE_DAMAGE * damage_scale, DamageInfo.Kind.BLUNT, self)
		var out := _flat(target.global_position - global_position)
		info.direction = (out.normalized() if out.length() > 0.1 else -global_basis.z)
		info.knockback = GeneralBrain.CLOSE_KNOCKBACK
		info.position = target.global_position + Vector3.UP
		target.call(&"take_damage", info)
		Fx.impact(info.position, -info.direction, ExhibitMaterial.Kind.METAL, 1.5)
		Sfx.play_at(&"punch_hit", info.position, 2.0)
		Events.shake_requested.emit(0.25)


# --- the roof: the leaps and the volleys --------------------------------------------

## The flight of a leap (after the crouch): a kinematic arc from where he
## crouched to the perch or the landing spot.
func _flight_frame() -> void:
	var since := brain.stage_time() - GeneralBrain.LEAP_CROUCH
	if since < 0.0:
		return
	if not _flying:
		_flying = true
		kinematic = true
		velocity = Vector3.ZERO
		_speed = 0.0
		collision_layer = 0
		collision_mask = Layers.WORLD
		Fx.impact(global_position + Vector3.UP * 0.05, Vector3.UP, -1, 1.8)
		Sfx.play_at(&"tail_whoosh", global_position + Vector3.UP, 0.0, 0.1, 0.9)
	var k := clampf(since / GeneralBrain.LEAP_FLIGHT, 0.0, 1.0)
	var apex := LEAP_APEX.x if brain.attack == A.LEAP_UP else LEAP_APEX.y
	var at := _leap_from.lerp(_leap_to, k)
	at.y += apex * sin(PI * k)
	global_position = at


## He lands on the eave: stands there (kinematic), facing the garden.
func _land_on_roof() -> void:
	_flying = false
	kinematic = true
	global_position = perch.origin
	rotation.y = _yaw_toward(target.global_position) if guard_alive() else perch.basis.get_euler().y
	feet.place(global_transform)
	Fx.impact(global_position + Vector3.UP * 0.05, Vector3.UP, ExhibitMaterial.Kind.WOOD, 1.2)
	Sfx.play_at(&"hit_metal", global_position, -4.0, 0.2, 0.7)
	Events.shake_requested.emit(0.1)


## He comes down on the landing spot: whoever stands within LAND_RADIUS is
## struck; on his feet again.
func _land_on_ground() -> void:
	_flying = false
	global_position = landing
	_solid()
	# a guard under him is shoved aside, not the General
	collision_mask = Layers.WORLD
	_shove_grace = 0.3
	feet.place(global_transform)
	_clear_marks(0.2)
	Fx.impact(global_position + Vector3.UP * 0.05, Vector3.UP, -1, 3.0)
	Fx.impact(global_position + Vector3.UP * 0.05, Vector3.UP, ExhibitMaterial.Kind.METAL, 1.5)
	Sfx.play_at(&"lamassu_stomp", global_position, -2.0, 0.1)
	Sfx.play_at(&"samurai_slash", rig.tip_point(), 0.0, 0.05)
	Events.shake_requested.emit(0.4)
	if not guard_alive():
		return
	var off := target.global_position - landing
	if Vector2(off.x, off.z).length() <= GeneralBrain.LAND_RADIUS + GUARD_RADIUS and off.y < 1.6 and off.y > -1.0:
		var info := DamageInfo.make(GeneralBrain.LAND_DAMAGE * damage_scale, DamageInfo.Kind.BLUNT, self)
		var out := Vector3(off.x, 0.0, off.z)
		info.direction = out.normalized() if out.length() > 0.1 else -global_basis.z
		info.knockback = GeneralBrain.LAND_KNOCKBACK
		info.position = target.global_position + Vector3.UP
		target.call(&"take_damage", info)
		Sfx.play_at(&"punch_hit", info.position, 2.0)


## Where the leap down comes down: toward the guard, within LEAP_REACH of
## the perch, on clear gravel of the garden (else nearer the post).
func _landing_spot() -> Vector3:
	var floor_y := home.origin.y
	var at := target.global_position if guard_alive() else home.origin
	at.y = floor_y
	var from := Vector3(global_position.x, floor_y, global_position.z)
	var to := at - from
	if to.length() > LEAP_REACH:
		at = from + to.normalized() * LEAP_REACH
	if to.length() < 2.5 and to.length() > 0.01:
		at = from + to.normalized() * 2.5
	for i in 8:
		if _spot_clear(at):
			return at
		at = at.lerp(home.origin, 0.3)
	return home.origin


## True when a landing at [param at] (floor) has room: in the arena, nothing
## within LANDING_ROOM either way, nothing over it.
func _spot_clear(at: Vector3) -> bool:
	if arena_room != &"" and room_of.is_valid() and room_of.call(at + Vector3.UP * 0.5) != arena_room:
		return false
	var space := get_world_3d().direct_space_state
	var down := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.UP * 0.05, Layers.WORLD)
	down.exclude = [get_rid()]
	if not space.intersect_ray(down).is_empty():
		return false
	for direction: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		if _clear_run(at, direction, LANDING_ROOM) < LANDING_ROOM - 0.001:
			return false
	return true


## The volley is announced: a mark for every arrow - the first on the
## guard (leading him), the others on a ring round it, with gaps.
func _volley_begin() -> void:
	var count := brain.arrows()
	volley_spots.clear()
	_volley_marks.clear()
	_volley_offsets.clear()
	var first := _predicted_arrow_spot()
	var turn := brain.rng.randf() * TAU
	for i in count:
		var offset := Vector3.ZERO
		if i > 0:
			var angle := turn + float(i - 1) * TAU / float(count - 1)
			offset = Vector3(cos(angle), 0.0, sin(angle)) * VOLLEY_RING
		_volley_offsets.append(offset)
		var spot := _in_arena(first + offset, first)
		volley_spots.append(spot)
		var mark := GroundMark.disc(GeneralBrain.ARROW_RADIUS)
		get_parent().add_child(mark)
		mark.global_transform = Transform3D(Basis.IDENTITY, spot)
		_volley_marks.append(mark)
	Sfx.play_at(&"tail_whoosh", rig.part("bow").global_position, -6.0, 0.1, 0.6)


## The marks follow the guard through the draw; the bow creaks.
func _volley_frame(delta: float, progress: float) -> void:
	if volley_spots.is_empty():
		return
	var first := volley_spots[0].lerp(_predicted_arrow_spot(), clampf(delta * 8.0, 0.0, 1.0))
	for i in volley_spots.size():
		volley_spots[i] = _in_arena(first + _volley_offsets[i], first)
		var mark: GroundMark = _volley_marks[i] as GroundMark if i < _volley_marks.size() else null
		if mark != null and is_instance_valid(mark):
			mark.global_position = volley_spots[i]
			mark.progress = progress * 0.5
	if not _creaked and brain.stage_time() > 0.3:
		_creaked = true
		Sfx.play_at(&"relief_scrape", rig.part("bow").global_position, -10.0, 0.1, 1.3)


## Where the first arrow should come down: ahead of the guard by part of
## his run over its flight.
func _predicted_arrow_spot() -> Vector3:
	var floor_y := home.origin.y
	if not guard_alive():
		return Vector3(home.origin.x, floor_y, home.origin.z)
	var at := target.global_position
	at.y = floor_y
	var flight := GeneralArrow.flight_time(_flat(at - global_position).length())
	return at + _flat(_guard_velocity) * flight * ARROW_LEAD


## [param at] when it lies in the arena, else drawn toward [param anchor].
## (Cover, by design: the arrows are stopped by the world as they fly -
## GeneralArrow - and the tea house's thatched eave is world, so a guard
## who hugs the tea house wall under the eave is safe from the volleys, as
## behind a rock. The eave is the garden's own cover, not a bug.)
func _in_arena(at: Vector3, anchor: Vector3) -> Vector3:
	if arena_room == &"" or not room_of.is_valid():
		return at
	var spot := at
	for i in 4:
		if room_of.call(spot + Vector3.UP * 0.5) == arena_room:
			return spot
		spot = spot.lerp(anchor, 0.4)
	return anchor


## The arrows leave the bow for their marks (locked now), one for each.
func _loose_arrows() -> void:
	if not guard_alive():
		volley_spots.clear()   # nobody to shoot at: the bow is let down
		return
	var nock := rig.nock_point()
	for i in volley_spots.size():
		var spot := volley_spots[i]
		var flight := GeneralArrow.flight_time(_flat(spot - nock).length())
		var arrow := GeneralArrow.make(nock, spot, flight, GeneralBrain.ARROW_DAMAGE * damage_scale, self, target)
		arrow.radius = GeneralBrain.ARROW_RADIUS
		get_parent().add_child(arrow)
		arrows.append(arrow)
		var mark: GroundMark = _volley_marks[i] as GroundMark if i < _volley_marks.size() else null
		if mark != null and is_instance_valid(mark):
			mark.progress = 1.0
			arrow.mark = mark   # it stays till the arrow comes down
	_volley_marks.clear()
	Fx.flash(nock, EMBER, 2.0, 3.0, 0.15)
	Sfx.play_at(&"samurai_volley", nock, 2.0, 0.05)


## Arrows gone from the world are forgotten.
func _tidy_arrows() -> void:
	var left: Array[Node] = []
	for node in arrows:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			left.append(node)
	arrows = left


## On his feet, solid: after a dash or a landing.
func _solid() -> void:
	kinematic = false
	_flying = false
	collision_layer = _layer_saved
	collision_mask = Layers.WORLD | Layers.PLAYER
	velocity = Vector3.ZERO
	_speed = 0.0


# --- phase 3: the petals, the double ---------------------------------------------------

func _ensure_storm() -> void:
	if storm != null and is_instance_valid(storm):
		return
	var crown := home * CHERRY_CROWN
	storm = PetalStorm.make(PetalStorm.emitters_for(_dressing_root(), home.origin, crown))
	get_parent().add_child(storm)
	storm.global_position = Vector3.ZERO


func _ensure_phantom() -> void:
	if phantom != null and is_instance_valid(phantom):
		return
	phantom = GeneralPhantom.new()
	get_parent().add_child(phantom)


## The transformation's moments: the sword planted, the gust and the
## petals from then on.
func _transform_frame() -> void:
	var u := brain.state_progress()
	if not _planted and u >= PLANT_AT:
		_planted = true
		var tip := rig.tip_point()
		Fx.impact(tip, Vector3.UP, -1, 2.0)
		Fx.impact(tip, Vector3.UP, ExhibitMaterial.Kind.METAL, 1.0)
		Sfx.play_at(&"hit_marble", tip, -2.0, 0.1, 0.8)
		Events.shake_requested.emit(0.25)
	if not _gusted and u >= GUST_AT:
		_gusted = true
		_ensure_storm()
		_ensure_phantom()
		var crown := home * CHERRY_CROWN
		storm.gust(_flat(global_position - crown).normalized())
		storm.start()
		Sfx.play_at(&"tail_whoosh", crown, 2.0, 0.1, 0.5)
		Sfx.play_at(&"guardian_wake", global_position + Vector3.UP * 2.0, -4.0, 0.0, 1.3)
		Fx.flash(rig.eyes_point(), EMBER, 3.0, 5.0, 0.4)
		Events.shake_requested.emit(0.35)


## The feint's telegraph: the figures step apart, both get lanes, the
## double lunges FEINT_PHANTOM_LEAD s early and bursts into petals.
func _feint_frame(delta: float) -> void:
	if phantom == null or not is_instance_valid(phantom):
		return
	var t := brain.stage_time()
	var telegraph := brain.current_stage_length()
	if not _feint_lanes and t >= GeneralBrain.FEINT_APART:
		_feint_lanes = true
		_make_lane()
		phantom.lane = GroundMark.lane(GeneralBrain.DASH_HALF_WIDTH * 2.0 + GUARD_RADIUS * 2.0, 6.0)
		get_parent().add_child(phantom.lane)
	var phantom_start := telegraph - GeneralBrain.FEINT_PHANTOM_LEAD
	var dash_length := GeneralBrain.stage_length(A.FEINT, T.STRIKE, brain.phase)
	var dash_progress := -1.0
	if phantom.active and t >= phantom_start:
		if not phantom.dashing:
			phantom.dashing = true
			var aimed := _aim_dash(phantom.global_position, dash_target)
			phantom.dash_dir = aimed[0]
			phantom.dash_from = phantom.global_position
			phantom.dash_to = phantom.global_position + phantom.dash_dir * float(aimed[1])
			if phantom.lane != null:
				phantom.lane.progress = 1.0
			Sfx.play_at(&"samurai_slash", phantom.global_position + Vector3.UP * 1.5, 0.0, 0.05, 1.1)
		dash_progress = clampf((t - phantom_start) / maxf(dash_length, 0.01), 0.0, 1.0)
	elif phantom.active and _feint_lanes and phantom.lane != null and is_instance_valid(phantom.lane):
		var aimed := _aim_dash(phantom.global_position, dash_target)
		_draw_lane(phantom.lane, phantom.global_position, aimed[0], float(aimed[1]))
		phantom.lane.progress = t / maxf(telegraph, 0.01)
	# the double's clip runs ahead of his
	var ahead := t + GeneralBrain.FEINT_PHANTOM_LEAD
	var clip := ahead / maxf(telegraph, 0.01) if ahead < telegraph else 1.0 + (ahead - telegraph) / maxf(dash_length, 0.01)
	var guard := target.global_position if guard_alive() else dash_target
	phantom.frame(brain, clip, guard, _sidestep_velocity(-1.0), dash_progress, delta)
	if dash_progress >= 1.0 and not _phantom_burst:
		_phantom_gone()


## The double bursts into petals (its dash's end, or the real cut).
func _phantom_gone() -> void:
	if phantom == null or not is_instance_valid(phantom) or not phantom.active:
		return
	_phantom_burst = true
	phantom.burst = true
	if storm != null and is_instance_valid(storm):
		storm.burst(phantom.global_position, phantom.dash_dir)
	Sfx.play_at(&"tail_whoosh", phantom.global_position + Vector3.UP, -4.0, 0.1, 0.7)
	phantom.vanish()


# --- waking, stun, steps -----------------------------------------------------------

func _state_frame(delta: float) -> void:
	match brain.state:
		S.WAKING:
			_waking_frame()
		S.TRANSFORM:
			_transform_frame()
		S.STUNNED:
			_stun_spark -= delta
			if _stun_spark <= 0.0:
				_stun_spark = 0.22
				var at := global_position + Vector3(randf_range(-0.3, 0.3), randf_range(0.8, 2.3), randf_range(-0.3, 0.3))
				Fx.arc(at, at + Vector3(randf_range(-0.4, 0.4), randf_range(-0.3, 0.3), randf_range(-0.4, 0.4)))


## The armour's parts clank home one by one; the eyes catch; the draw.
func _waking_frame() -> void:
	var assembly := brain.assemble_progress()
	for part_name in CLANK_PARTS:
		if _clanked.has(part_name):
			continue
		if GeneralRig.part_assembly(part_name, assembly) >= 1.0:
			_clanked[part_name] = true
			var at := rig.part(part_name).global_position
			Sfx.play_at(&"hit_metal", at, -4.0 if part_name != "head" else 0.0, 0.2, 0.8)
			Fx.impact(at, Vector3.UP, ExhibitMaterial.Kind.METAL, 0.5)
			if part_name == "head":
				Fx.flash(rig.eyes_point(), EMBER, 2.5, 3.0, 0.3)
				Sfx.play_at(&"samurai_glint", rig.eyes_point(), -6.0, 0.0, 0.7)
	if not _drawn and brain.draw_progress() > 0.72:
		_drawn = true
		Sfx.play_at(&"samurai_slash", rig.tip_point(), -2.0, 0.05, 0.9)
		Fx.flash(rig.glint_point(), STEEL, 2.0, 3.0, 0.2)


func _on_step(foot: int) -> void:
	if not is_inside_tree() or state != State.FIGHT:
		return
	var at := feet.foot(foot)
	Fx.impact(Vector3(at.x, global_position.y + 0.03, at.z), Vector3.UP, -1, 0.35)


# --- calm, freeze, fall -------------------------------------------------------------

func _on_reset() -> void:
	_solid()
	brain.reset()
	moves.reset()
	feet.place(global_transform)
	_clear_marks()
	_free_arrows()
	_calm_phase_three()
	rig.apply(moves.compose(brain, feet, global_transform, 0.0))
	_eye_light.light_energy = 0.0
	_glint_light.light_energy = 0.0


func _on_freeze() -> void:
	_clear_marks()
	_free_arrows()
	_calm_phase_three()
	_eye_light.light_energy = 0.0
	_glint_light.light_energy = 0.0


func _on_defeated(info: DamageInfo) -> void:
	# struck down in the air of a leap, he still kneels on the floor (on the
	# eave, he kneels on the eave)
	var drop := _height_over_floor() if _flying else 0.0
	_solid()
	brain.die()
	_clear_marks()
	# a volley loosed just before the blow must not hurt the guard after it
	_free_arrows()
	_calm_phase_three()
	if phantom != null and is_instance_valid(phantom):
		phantom.queue_free()
	var fall := GeneralFall.make(self, info, drop)
	get_parent().add_child(fall)


## How high his feet hang over what is under them (m): the world below him,
## else the arena's floor.
func _height_over_floor() -> float:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.1, global_position + Vector3.DOWN * 12.0, Layers.WORLD)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	var floor_y: float = float(hit["position"].y) if not hit.is_empty() else home.origin.y
	return maxf(global_position.y - floor_y, 0.0)


## The petals stop, the double goes (a calm, the dawn, the fall).
func _calm_phase_three() -> void:
	if storm != null and is_instance_valid(storm):
		storm.stop()
	if phantom != null and is_instance_valid(phantom):
		phantom.vanish()


# --- helpers ------------------------------------------------------------------------

func _clear_marks(fade: float = 0.25) -> void:
	for mark: GroundMark in [_lane, _cone, _land_mark]:
		if mark != null and is_instance_valid(mark):
			mark.vanish(fade)
	for mark: GroundMark in _volley_marks:
		if mark != null and is_instance_valid(mark):
			mark.vanish(fade)
	_volley_marks.clear()
	_lane = null
	_cone = null
	_land_mark = null


func _free_arrows() -> void:
	for node in arrows:
		if is_instance_valid(node):
			node.queue_free()
	arrows.clear()


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
