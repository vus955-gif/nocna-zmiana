class_name Lamassu
extends Guardian
## The Lamassu, Assyria's wing guardian (design 7.4; plan
## docs/superpowers/plans/2026-10-03-straznik-lamassu.md): a 4 m alabaster
## winged bull with a man's face asleep on its plinth against the palace
## courtyard's north wall, facing the door from Nimrud. The guard crosses
## the start line: dust shivers off it, its eyes light, the head lifts and
## turns, the wings creak open, and it walks down off the plinth hoof by
## hoof (four thuds). Then the heavy ram's fight (LamassuBrain holds every
## number; LamassuGait the hooves, planted in the world by IK; LamassuMoves
## the choreography; LamassuRig the body):
## 1. it STALKS the guard at a walk with a wide turning circle, round the
##    genii and the cedars;
## 2. the CHARGE: the head drops, the right fore hoof paws the floor, a
##    lane shows the run to the first thing in its way; it runs the guard
##    down (CHARGE_DAMAGE, flung aside); it sees a WALL coming and skids to
##    a stop before it - but cannot stop for COVER (a genius's base, a cedar
##    column: the lamassu_cover_<n> markers): it crashes into it and reels
##    STUNNED with its face low (the weak point at a shot's height);
## 3. the WING GUST: the wings spread and rise (an arc on the floor shows
##    the cone), then beat forward - whoever stands in the cone with nothing
##    between is thrown back several metres (a shove, a lift and the wind)
##    and peppered with grit; cover stops the wind;
## 4. the STOMP: it rears onto its hind legs (a disc marks the spot) and
##    crashes its fore hooves down (STOMP_DAMAGE under them) - a shockwave
##    ring rolls out: jump it;
## 5. in phase 3 the HOP: its shadow appears where the guard stands, it
##    crouches, leaps on beating wings and comes down there (HOP_DAMAGE
##    under the shadow, a ring).
## Phase 2 (< 66 %): it rears and bellows, the cracks blaze (the
## lamassu_cracked set) and the keeper calls the relief warriors off the
## walls (GuardianKeeper.PHASE_CALLS). Phase 3 (< 33 %): three wing beats
## lift it off the floor; it drops; hops and gusts from then on.
## Damage: the human face x1.5 (gold), the crown x1 (gold; it breaks off
## after CROWN_HEALTH, the stump stays a weak point), the stone x0.1 (grey,
## chips), the wings x0.1 but they chip (a tip breaks off after
## WING_HEALTH). Its fall: LamassuFall; the keeper drops the seal and the
## shard on arena_lamassu_reward.
## Body space: origin on the floor under its barrel, -Z its front.

## Announced (the warning starts) and landed (the damage moment, or the
## start of the active part): charge, gust, stomp, hop.
signal telegraphed(attack: StringName)
signal struck(attack: StringName)
## The charge ran into cover (stunned) or a wall.
signal crashed
## It stands on the court's floor, off its plinth.
signal stepped_down

const A := LamassuBrain.Attack
const S := LamassuBrain.State
const G := LamassuGait.Mode
const NAMES := {
	LamassuBrain.Attack.CHARGE: &"charge", LamassuBrain.Attack.GUST: &"gust",
	LamassuBrain.Attack.STOMP: &"stomp", LamassuBrain.Attack.HOP: &"hop",
}
## Damage factors by zone.
const FACE := 1.5
const CROWN := 1.0
const STONE := 0.1
const WING := 0.1
## The crown breaks off after this much damage to it; a wing chips every
## WING_CHIP of damage and its tip breaks off after WING_HEALTH.
const CROWN_HEALTH := 160.0
const WING_CHIP := 25.0
const WING_HEALTH := 120.0
## Its collider (centre, size), body space: the bull down to the floor.
const BODY_BOX := [Vector3(0.0, 1.7, 0.1), Vector3(1.3, 3.4, 3.6)]
## A point this near a cover marker is cover: a charge into it stuns.
const COVER_REACH := 2.3
## The charge runs the guard down within this half-width of its line, from
## behind its chest to this far ahead (m).
const CHARGE_HALF_WIDTH := 0.75
const CHARGE_AHEAD := 2.2
## The skid stops this far short of a wall it saw.
const WALL_MARGIN := 0.7
## Its probes for room ahead: heights (m) and the headings it tries.
const PROBE_HEIGHTS: Array[float] = [0.7, 1.5]
const DETOURS: Array[float] = [0.0, 0.4, -0.4, 0.8, -0.8, 1.2, -1.2, 1.6, -1.6]
## Walking: it slows into a sharp turn (rad/s^2 of grip).
const WALK_ACCEL := 3.0
const BRAKING := 6.0
## The waking: it stands and stirs this share of WAKE_TIME, then walks down
## off the plinth at WAKE_WALK m/s; the root sinks to the floor over the
## plinth's edge.
const WAKE_STIR := 0.33
const WAKE_WALK := 1.9
## The hop's arc height (m) and the wind's time (s).
const HOP_HEIGHT := 2.4
const GUST_WIND_TIME := 0.5
## The stomp's hooves land this far ahead of the body (m).
const STOMP_REACH := 1.6
const GOLD := Color(1.0, 0.82, 0.5)
const CRACK := Color(1.0, 0.55, 0.2)

var brain := LamassuBrain.new()
var gait := LamassuGait.new()
var rig: LamassuRig
var moves: LamassuMoves
var plinth: LamassuPlinth
## Its run now (m/s, along its facing or the charge's line).
var speed: float = 0.0
## The charge's line (world, flat).
var charge_dir := Vector3.FORWARD
## The hop: from where, to where (world, on the floor).
var hop_from := Vector3.ZERO
var hop_to := Vector3.ZERO
## Damage taken by the crown and by each wing (left, right).
var crown_damage: float = 0.0
var wing_damage: Array[float] = [0.0, 0.0]

var _look: Node3D
var _zones := {}
var _zone_factor: float = 1.0
var _weak_hit := false
var _gold_frame: int = -1
var _crown_box: Hurtbox
var _lane: GroundMark
var _cone: GroundMark
var _disc: GroundMark
var _shadow: GroundMark
var _charge_hit := false
var _charge_from := Vector3.ZERO
var _charge_length: float = 0.0
var _charge_cover := false
var _yaw_goal: float = 0.0
var _steer_timer: float = 0.0
var _blocked_time: float = 0.0
var _turn_rate: float = 0.0
var _scrape_timer: float = 0.0
var _scraped := false
var _spark_timer: float = 0.0
var _wind_left: float = 0.0
var _wind_dir := Vector3.FORWARD
var _hover_from: float = 0.0
var _wake_done := {}
var _on_plinth := true
var _through_plinth := false
var _hop_check: float = 0.0
var _chip_next: Array[float] = [WING_CHIP, WING_CHIP]
var _crack_light: OmniLight3D


func _init() -> void:
	# (tuned with run_guardian.sh lamassu --bot: about 34 s, like the others)
	max_health = 1900.0


## The plinth it sleeps on (GuardianKeeper, every night; empty after its
## fall). It is a stone the exhibits walk round (the relief warriors of
## phase 2 too): a navigation source of the level, not of [param parent]
## (QA Q4).
static func dress_arena(level: MuseumFloorLevel, parent: Node3D) -> Array[Node3D]:
	var props: Array[Node3D] = []
	if level.markers.has(&"guardian_lamassu"):
		var base := LamassuPlinth.make(level.markers[&"guardian_lamassu"])
		if level.navigation != null:
			level.add_walk_source(base)
		else:
			parent.add_child(base)
		props.append(base)
	return props


# --- body -------------------------------------------------------------------

func _build_body() -> void:
	# it runs through the guard (the charge's contact hurts him), never into
	# him; the world stops it
	collision_mask = Layers.WORLD
	_look = Node3D.new()
	_look.name = "Look"
	add_child(_look)
	rig = LamassuRig.create(_look)
	moves = LamassuMoves.new(rig)
	moves.stomp_point = Vector3(0.0, 0.0, -STOMP_REACH)
	var shape := BoxShape3D.new()
	shape.size = BODY_BOX[1]
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = BODY_BOX[0]
	add_child(collider)
	_build_zones()
	_crack_light = OmniLight3D.new()
	_crack_light.light_color = CRACK
	_crack_light.omni_range = 6.0
	_crack_light.light_energy = 0.0
	_crack_light.visible = false
	rig.part("body").add_child(_crack_light)
	_crack_light.position = Vector3(0.0, -0.3, -0.9)
	_find_plinth()
	# asleep on its plinth: its post is up there (it stands on the plinth's
	# collider; only the waking walk passes through it)
	global_position.y += plinth.top()
	home = global_transform
	_on_plinth = true
	gait.floor_of = _floor_under
	gait.place(global_transform)
	brain.telegraphed.connect(_on_telegraphed)
	brain.struck.connect(_on_struck)
	brain.finished.connect(_on_finished)
	brain.state_changed.connect(_on_state_changed)
	gait.landed.connect(_on_hoof_landed)
	rig.apply(moves.compose(brain, gait, global_transform, 0.0))


## Hit zones on the parts (they move with it): the face (weak, standing
## proud of the head), the crown (weak; on the head, so the stump keeps it
## when the crown is gone), each wing, the stone.
func _build_zones() -> void:
	var stone := _zone(&"body")
	var wings := [_zone(&"wing_l"), _zone(&"wing_r")]
	for view in rig.meshes:
		var key := String(view.name)
		var receiver: GuardianZone = stone
		if key.begins_with("wing_l"):
			receiver = wings[0]
		elif key.begins_with("wing_r"):
			receiver = wings[1]
		elif key == "headdress":
			continue   # the crown's own box, on the head
		var box := view.get_aabb()
		var shape := BoxShape3D.new()
		shape.size = box.size.max(Vector3.ONE * 0.12)
		view.add_child(Hurtbox.make(receiver, shape, box.get_center()))
	# the face, a little in front of the head: a shot from the front finds
	# it before the beard
	var face_at: Vector3 = (rig.rest["face"] as Transform3D).origin
	var face := BoxShape3D.new()
	face.size = Vector3(0.52, 0.62, 0.5)
	rig.part("head").add_child(Hurtbox.make(_zone(&"face"), face, face_at + Vector3(0.0, 0.0, -0.12), true))
	var crown_at: Vector3 = (rig.rest["headdress"] as Transform3D).origin
	var crown := BoxShape3D.new()
	crown.size = Vector3(0.58, 0.82, 0.58)
	_crown_box = Hurtbox.make(_zone(&"crown"), crown, crown_at + Vector3(0.0, 0.4, 0.0), true)
	rig.part("head").add_child(_crown_box)


func _zone(zone_name: StringName) -> GuardianZone:
	var zone := GuardianZone.make(self, zone_name)
	add_child(zone)
	_zones[zone_name] = zone
	return zone


## The plinth the keeper raised at its post, or one of its own (a dev
## arena, a test).
func _find_plinth() -> void:
	for node in get_tree().get_nodes_in_group(LamassuPlinth.GROUP):
		var base := node as LamassuPlinth
		if base != null and base.global_position.distance_to(global_position) < 1.0:
			plinth = base
	if plinth == null:
		plinth = LamassuPlinth.make(global_transform)
		plinth.top_level = true
		add_child(plinth)
		plinth.global_transform = global_transform


## The floor under [param point]: the plinth's top over it, else the court.
func _floor_under(point: Vector3) -> float:
	if plinth != null and is_instance_valid(plinth):
		var local := plinth.to_local(point)
		if absf(local.x) <= LamassuPlinth.SIZE.x * 0.5 and absf(local.z) <= LamassuPlinth.SIZE.z * 0.5:
			return plinth.global_position.y + plinth.top()
	return home.origin.y - plinth.top() if plinth != null else global_position.y


# --- damage -------------------------------------------------------------------

func take_zone_damage(info: DamageInfo, zone: StringName) -> void:
	if info == null:
		return
	var weak := zone == &"face" or zone == &"crown"
	match zone:
		&"face":
			_zone_factor = FACE
		&"crown":
			_zone_factor = CROWN
		&"wing_l", &"wing_r":
			_zone_factor = WING
		_:
			_zone_factor = STONE
	info.weak_point = weak
	info.blocked = not weak
	_weak_hit = weak
	super(info, zone)
	_weak_hit = false
	_zone_factor = 1.0
	if state != State.FIGHT or is_frozen():
		return
	if info.effects and not info.periodic:
		moves.flinch(1.0 if weak else 0.3)
	if zone == &"crown" and rig.crown_on:
		crown_damage += info.amount
		if crown_damage >= CROWN_HEALTH:
			_lose_crown(info)
	elif zone == &"wing_l" or zone == &"wing_r":
		var side := 0 if zone == &"wing_l" else 1
		wing_damage[side] += info.amount
		if wing_damage[side] >= _chip_next[side]:
			_chip_next[side] += WING_CHIP
			_chip_wing(side, info)
		if wing_damage[side] >= WING_HEALTH and rig.tips_on[side]:
			_lose_wing_tip(side, info)


func _damage_factor(_info: DamageInfo) -> float:
	return _zone_factor


func _hit_effects(info: DamageInfo) -> void:
	if info.weak_point:
		Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.MARBLE, clampf(info.amount / 10.0, 1.0, 3.0))
		Fx.flash(info.position, GOLD, 2.5, 3.0, 0.08)
		Sfx.play_at(&"hit_marble", info.position, 1.0)
		rig.flash(0.6)
	else:
		# alabaster chips fly off the stone
		Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.MARBLE, 1.2)
		Fx.chunk(info.position, LamassuRig.ALABASTER, randf_range(0.04, 0.08), info.normal * 2.5 + Vector3.UP * 1.5)
		Sfx.play_at(&"hit_marble", info.position, -6.0, 0.25)


## One blast can strike the face and the stone at once: the grey marker
## must not paint over the gold one.
func _report_hit(info: DamageInfo) -> void:
	var frame := Engine.get_physics_frames()
	if info.weak_point:
		_gold_frame = frame
	elif _gold_frame == frame:
		return
	Events.hit_landed.emit(self, info, false)


func _lose_crown(info: DamageInfo) -> void:
	var fling := info.direction * 3.0 + Vector3.UP * 3.5 if info.direction.length() > 0.1 else Vector3.UP * 4.0
	var piece := rig.drop_crown(fling)
	if piece != null:
		piece.angular_velocity = Vector3(randf_range(-4.0, 4.0), randf_range(-2.0, 2.0), randf_range(-4.0, 4.0))
	# the stump is a shorter target
	(_crown_box.get_child(0) as CollisionShape3D).shape = _stump_shape()
	_crown_box.position.y -= 0.22
	var at := rig.crown_point()
	Fx.impact(at, Vector3.UP, ExhibitMaterial.Kind.MARBLE, 3.0)
	Fx.flash(at, GOLD, 3.0, 4.0, 0.2)
	Sfx.play_at(&"break_marble", at, 0.0)
	_shake_near(0.3, 20.0)


func _stump_shape() -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.56, 0.36, 0.56)
	return shape


func _chip_wing(side: int, info: DamageInfo) -> void:
	var at := rig.part("wing_%s" % LamassuRig.SIDES[side]).global_transform * Vector3(0.0, 0.3, 0.8)
	for i in 4:
		Fx.chunk(at + Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.3), randf_range(-0.4, 0.4)), LamassuRig.ALABASTER,
				randf_range(0.05, 0.11), info.normal * randf_range(1.5, 3.0) + Vector3(randf_range(-1.0, 1.0), randf_range(1.0, 2.5), randf_range(-1.0, 1.0)))
	Fx.impact(at, info.normal, ExhibitMaterial.Kind.MARBLE, 2.0)
	Sfx.play_at(&"break_marble", at, -5.0)


func _lose_wing_tip(side: int, info: DamageInfo) -> void:
	var out := global_basis.x * (-1.0 if side == 0 else 1.0)
	var piece := rig.drop_wing_tip(side, out * 2.5 + info.direction * 1.5 + Vector3.UP * 2.0)
	if piece != null:
		piece.angular_velocity = Vector3(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
	var at := rig.part("wing_%s" % LamassuRig.SIDES[side]).global_transform * Vector3(0.0, 0.5, 1.1)
	Fx.impact(at, out, ExhibitMaterial.Kind.MARBLE, 3.0)
	Sfx.play_at(&"break_marble", at, 1.0)
	_shake_near(0.25, 20.0)


# --- the fight ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var before := global_position
	super(delta)
	if state != State.FIGHT or is_frozen():
		return
	if not guard_alive():
		_idle_frame(delta)
		return
	if _charging():
		_charge_moved(before, delta)


func _on_phase(next: int) -> void:
	if next == 1:
		brain.wake()
	else:
		brain.set_phase(next)


func _fight_process(delta: float) -> void:
	var guard := target.global_position
	var local := to_local(guard)
	var distance := Vector2(local.x, local.z).length()
	var bearing := atan2(-local.x, -local.z)
	_hop_check -= delta
	if _hop_check <= 0.0:
		_hop_check = 0.2
		brain.hop_clear = hop_landing(guard) != Vector3.INF
	brain.update(delta, distance, bearing)
	_move(delta, guard, distance, bearing)
	moves.guard = to_local(guard + Vector3.UP * 1.4)
	_attack_frame(delta)
	gait.update(delta, global_transform, velocity, _turn_rate, _gait_mode())
	_animate(delta)
	_state_frame(delta)
	_leave_plinth()


## The guard fell: it settles where it stands.
func _idle_frame(delta: float) -> void:
	_clear_marks()
	speed = move_toward(speed, 0.0, BRAKING * delta)
	_turn_rate = 0.0
	brain.update(delta, INF, 0.0)
	gait.update(delta, global_transform, Vector3.ZERO, 0.0, G.STAND)
	_animate(delta)


func _animate(delta: float) -> void:
	var pose := moves.compose(brain, gait, global_transform, delta)
	if brain.phase >= 2:
		pose.cracks = maxf(pose.cracks, 0.7 + 0.3 * float(brain.phase - 2) + 0.15 * sin(moves.time * 5.0))
	rig.apply(pose, delta)


## True while the charge runs.
func _charging() -> bool:
	return brain.state == S.ATTACK and brain.attack == A.CHARGE and brain.stage == LamassuBrain.Stage.STRIKE


func _skidding() -> bool:
	return brain.state == S.ATTACK and brain.attack == A.CHARGE and brain.stage == LamassuBrain.Stage.RECOVER


func _flying() -> bool:
	if brain.state != S.ATTACK or brain.attack != A.HOP or brain.stage != LamassuBrain.Stage.TELEGRAPH:
		return false
	return brain.stage_time() >= LamassuBrain.stage_length(A.HOP, LamassuBrain.Stage.TELEGRAPH, brain.phase) * LamassuBrain.HOP_CROUCH


func _gait_mode() -> G:
	match brain.state:
		S.WAKING:
			return G.WALK if speed > 0.2 else G.HOLD
		S.STUNNED:
			return G.STAND
		S.PHASE_SHIFT:
			return G.AIR if moves.hover > 0.05 else G.HOLD
		S.ATTACK:
			match brain.attack:
				A.CHARGE:
					if _charging():
						return G.GALLOP
					if _skidding():
						return G.SKID if speed > 0.4 else G.STAND
					return G.HOLD
				A.GUST, A.STOMP:
					return G.HOLD
				A.HOP:
					if _flying():
						return G.AIR
					return G.HOLD if brain.stage == LamassuBrain.Stage.TELEGRAPH else G.STAND
	return G.WALK if speed > 0.2 or absf(_turn_rate) > 0.15 else G.STAND


# --- moving -------------------------------------------------------------------

func _move(delta: float, guard: Vector3, distance: float, bearing: float) -> void:
	var wanted := 0.0
	var turn_to := rotation.y
	var turning := false
	var grip := brain.turn_speed()
	kinematic = false
	match brain.state:
		S.WAKING:
			_wake_move(delta, guard)
			return
		S.IDLE:
			turning = true
			if brain.wants_to_walk(distance):
				turn_to = _stalk_yaw(delta, guard)
				var gap := absf(wrapf(turn_to - rotation.y, -PI, PI))
				# a wide circle: it keeps walking into a turn, slowly
				wanted = brain.walk_speed() if gap < 0.5 else lerpf(brain.walk_speed(), LamassuBrain.MIN_ARC_SPEED, clampf((gap - 0.5) / 1.0, 0.0, 1.0))
			else:
				turn_to = _yaw_toward(guard)
				grip = brain.turn_speed() * 0.8
		S.ATTACK:
			match brain.attack:
				A.CHARGE:
					if brain.stage == LamassuBrain.Stage.TELEGRAPH:
						turning = not brain.charge_locked()
						turn_to = _yaw_toward(guard)
						grip = brain.turn_speed() * 1.5
					elif _charging():
						wanted = brain.charge_speed()
					else:
						wanted = 0.0
				A.GUST, A.STOMP:
					turning = brain.stage == LamassuBrain.Stage.TELEGRAPH and brain.stage_time() < 0.2
					turn_to = _yaw_toward(guard)
					grip = brain.turn_speed() * 1.5
				A.HOP:
					if _flying():
						_hop_move()
						return
					turning = brain.stage == LamassuBrain.Stage.TELEGRAPH and not _flying()
					turn_to = _yaw_toward(hop_to) if hop_to != Vector3.ZERO else _yaw_toward(guard)
		S.PHASE_SHIFT:
			if brain.shift_phase == 3:
				_hover_move()
				return
	# the run and the skid along the charge's line; otherwise its facing
	if _charging():
		speed = move_toward(speed, wanted, brain.charge_speed() / LamassuBrain.CHARGE_ACCEL_TIME * delta)
	elif _skidding():
		speed = move_toward(speed, 0.0, LamassuBrain.SKID_DECEL * delta)
	else:
		speed = move_toward(speed, wanted, (WALK_ACCEL if wanted > speed else BRAKING) * delta)
	var before_yaw := rotation.y
	if turning:
		var gap := wrapf(turn_to - rotation.y, -PI, PI)
		rotation.y = wrapf(rotation.y + clampf(gap, -grip * delta, grip * delta), -PI, PI)
	_turn_rate = lerpf(_turn_rate, wrapf(rotation.y - before_yaw, -PI, PI) / maxf(delta, 0.001), clampf(delta * 12.0, 0.0, 1.0))
	var along := charge_dir if (_charging() or _skidding()) else -global_basis.z
	velocity.x = along.x * speed
	velocity.z = along.z * speed


## The world yaw that faces [param point].
func _yaw_toward(point: Vector3) -> float:
	var to := point - global_position
	return atan2(-to.x, -to.z)


## Walking after the guard round what stands in the way.
func _stalk_yaw(delta: float, guard: Vector3) -> float:
	_steer_timer -= delta
	if _steer_timer > 0.0:
		return _yaw_goal
	_steer_timer = 0.12
	var yaw := _yaw_toward(guard)
	for offset in DETOURS:
		if _room_toward(yaw + offset):
			_blocked_time = _blocked_time + 0.12 if absf(offset) > 1.0 else 0.0
			_yaw_goal = yaw + offset
			return _yaw_goal
	_yaw_goal = rotation.y + PI
	return _yaw_goal


## True when the way toward [param yaw] is clear for a few strides and
## stays in its court.
func _room_toward(yaw: float) -> bool:
	var direction := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var reach := 3.2
	var space := get_world_3d().direct_space_state
	var side := direction.cross(Vector3.UP) * 0.65
	for height in PROBE_HEIGHTS:
		for offset: Vector3 in [Vector3.ZERO, side, -side]:
			var from := global_position + Vector3.UP * height + offset
			var query := PhysicsRayQueryParameters3D.create(from, from + direction * reach, Layers.WORLD)
			query.exclude = [get_rid()]
			if not space.intersect_ray(query).is_empty():
				return false
	if arena_room != &"" and room_of.is_valid():
		var end := global_position + direction * reach + Vector3.UP * 0.5
		if room_of.call(end) != arena_room:
			return false
	return true


## How far the way ahead along [param direction] is clear (m, up to
## [param limit]) and where it ends: [distance, point, normal].
func _clear_run(direction: Vector3, limit: float) -> Array:
	var space := get_world_3d().direct_space_state
	var best := limit
	var point := global_position + direction * limit
	var normal := -direction
	for height in PROBE_HEIGHTS:
		for offset: Vector3 in [Vector3.ZERO, direction.cross(Vector3.UP) * 0.5, -direction.cross(Vector3.UP) * 0.5]:
			var from := global_position + Vector3.UP * height + offset
			var query := PhysicsRayQueryParameters3D.create(from, from + direction * limit, Layers.WORLD)
			query.exclude = [get_rid()]
			var hit := space.intersect_ray(query)
			if not hit.is_empty():
				var distance := from.distance_to(hit["position"])
				if distance < best:
					best = distance
					point = hit["position"]
					normal = hit["normal"]
	return [best, point, normal]


## True when [param point] lies at cover (a genius's base, a cedar): a
## charge into it stuns.
func cover_hit(point: Vector3) -> bool:
	for at: Transform3D in points.get(&"cover", []):
		if Vector2(at.origin.x - point.x, at.origin.z - point.z).length() <= COVER_REACH:
			return true
	return false


## True when [param point] lies in the gust's cone from [param origin]
## along [param forward] (flat).
static func gust_reaches(origin: Vector3, forward: Vector3, point: Vector3) -> bool:
	var to := Vector3(point.x - origin.x, 0.0, point.z - origin.z)
	var distance := to.length()
	if distance > LamassuBrain.GUST_REACH or distance < 0.01:
		return distance < 0.01
	var flat := Vector3(forward.x, 0.0, forward.z).normalized()
	return flat.angle_to(to / distance) <= LamassuBrain.GUST_HALF_ANGLE


## Where a hop toward [param guard] would come down (world, on the floor):
## where he stands, drawn in to HOP_MAX and out to HOP_MIN, in the court
## with room round it and clear of cover; Vector3.INF when nowhere.
func hop_landing(guard: Vector3) -> Vector3:
	var floor_y := home.origin.y - plinth.top() if plinth != null else global_position.y
	var from := Vector3(global_position.x, floor_y, global_position.z)
	var to := Vector3(guard.x, floor_y, guard.z)
	var line := to - from
	var length := line.length()
	if length < 0.5:
		return Vector3.INF
	line /= length
	length = clampf(length, LamassuBrain.HOP_MIN, LamassuBrain.HOP_MAX)
	for i in 5:
		var reach := length - 1.5 * i
		if reach < LamassuBrain.HOP_MIN:
			break
		var at := from + line * reach
		if _landing_ok(at):
			return at
	return Vector3.INF


func _landing_ok(at: Vector3) -> bool:
	if arena_room != &"" and room_of.is_valid():
		for offset: Vector3 in [Vector3.ZERO, Vector3(2.0, 0.0, 0.0), Vector3(-2.0, 0.0, 0.0), Vector3(0.0, 0.0, 2.0), Vector3(0.0, 0.0, -2.0)]:
			if room_of.call(at + offset + Vector3.UP * 0.5) != arena_room:
				return false
	for cover: Transform3D in points.get(&"cover", []):
		if Vector2(cover.origin.x - at.x, cover.origin.z - at.z).length() < COVER_REACH + 1.2:
			return false
	if plinth != null and Vector2(plinth.global_position.x - at.x, plinth.global_position.z - at.z).length() < 4.5:
		return false
	return true


# --- the waking: down off the plinth ----------------------------------------------------

func _wake_move(delta: float, guard: Vector3) -> void:
	kinematic = true
	var u := brain.state_progress()
	_turn_rate = 0.0
	if u < WAKE_STIR:
		speed = 0.0
		velocity = Vector3.ZERO
		return
	# it walks down and forward; the root sinks to the floor over the edge
	speed = move_toward(speed, WAKE_WALK, 4.0 * delta)
	var forward := -home.basis.z
	global_position += forward * speed * delta
	var ahead := (global_position - home.origin).dot(forward)
	var edge := LamassuPlinth.SIZE.z * 0.5
	var k := clampf((ahead - (edge - 1.0)) / 1.6, 0.0, 1.0)
	global_position.y = home.origin.y - plinth.top() * MotionClip.eased(MotionClip.IN_OUT, k)
	velocity = forward * speed


## Walked clear of its plinth (it stays a step to the bull for the rest of
## the fight: its hooves climb it, nothing wedges it against the wall).
func _leave_plinth() -> void:
	if not _on_plinth or plinth == null or brain.state == S.WAKING:
		return
	var local := plinth.to_local(global_position)
	if absf(local.z) > LamassuPlinth.SIZE.z * 0.5 + BODY_BOX[1].z * 0.5 + 0.2 or absf(local.x) > LamassuPlinth.SIZE.x * 0.5 + 1.0:
		_on_plinth = false
		stepped_down.emit()


## Lets it walk over its plinth as over a step ([param on]: from the
## waking on) or stand on it as on the floor (asleep).
func _pass_plinth(on: bool) -> void:
	if on == _through_plinth or plinth == null:
		return
	_through_plinth = on
	if on:
		add_collision_exception_with(plinth)
	else:
		remove_collision_exception_with(plinth)


# --- the attacks ------------------------------------------------------------------

func _on_telegraphed(attack: A) -> void:
	_clear_marks()
	match attack:
		A.CHARGE:
			_scraped = false
			_lane = GroundMark.lane(CHARGE_HALF_WIDTH * 2.0 + 0.5, 6.0)
			get_parent().add_child(_lane)
			_place_lane()
		A.GUST:
			_cone = GroundMark.arc(1.2, LamassuBrain.GUST_REACH, -LamassuBrain.GUST_HALF_ANGLE, LamassuBrain.GUST_HALF_ANGLE)
			get_parent().add_child(_cone)
			_place_cone()
			Sfx.play_at(&"relief_scrape", global_position + Vector3.UP * 2.5, -4.0)
		A.STOMP:
			var at := _stomp_spot()
			_disc = GroundMark.disc(LamassuBrain.STOMP_RADIUS)
			get_parent().add_child(_disc)
			_disc.global_transform = Transform3D(global_basis.orthonormalized(), at)
			Sfx.play_at(&"relief_scrape", global_position + Vector3.UP * 2.0, -2.0)
		A.HOP:
			hop_from = global_position
			var landing := hop_landing(target.global_position) if guard_alive() else Vector3.INF
			if landing == Vector3.INF:
				landing = to_global(Vector3(0.0, 0.0, -LamassuBrain.HOP_MIN))
				landing.y = home.origin.y - plinth.top()
			hop_to = landing
			_shadow = GroundMark.disc(LamassuBrain.HOP_RADIUS)
			get_parent().add_child(_shadow)
			_shadow.global_transform = Transform3D(Basis.IDENTITY, hop_to)
			Sfx.play_at(&"relief_scrape", global_position + Vector3.UP * 2.5, -2.0)
	telegraphed.emit(NAMES[attack])


func _on_struck(attack: A) -> void:
	match attack:
		A.CHARGE:
			_start_run()
		A.GUST:
			_gust_blows()
		A.STOMP:
			_stomp_lands()
		A.HOP:
			_hop_lands()
	struck.emit(NAMES[attack])


func _on_finished(attack: A) -> void:
	if attack == A.CHARGE and _lane != null:
		_clear_marks(0.4)
	else:
		_clear_marks()
	_wind_left = 0.0
	kinematic = false


func _on_state_changed(_from: S, to: S) -> void:
	match to:
		S.WAKING:
			_wake_done.clear()
			speed = 0.0
			_pass_plinth(true)
		S.STUNNED:
			_crack_light.visible = true
		S.PHASE_SHIFT:
			_hover_from = global_position.y
			if brain.shift_phase == 2:
				Sfx.play_at(&"guardian_wake", global_position + Vector3.UP * 3.0, 2.0)
		S.IDLE:
			kinematic = false
			if _from == S.WAKING:
				global_position.y = home.origin.y - plinth.top()
				velocity = Vector3.ZERO


## Effects that run through an attack: the marks, the scrape, the run, the
## skid, the wind, the flight.
func _attack_frame(delta: float) -> void:
	if brain.state != S.ATTACK:
		return
	var progress := brain.stage_time() / maxf(LamassuBrain.stage_length(brain.attack, brain.stage, brain.phase), 0.01)
	match brain.attack:
		A.CHARGE:
			if brain.stage == LamassuBrain.Stage.TELEGRAPH:
				_place_lane()
				if _lane != null:
					_lane.progress = progress
				_scrape_frame(delta)
			elif brain.stage == LamassuBrain.Stage.STRIKE:
				_charge_frame()
			else:
				_skid_frame(delta)
		A.GUST:
			if brain.stage == LamassuBrain.Stage.TELEGRAPH:
				_place_cone()
				if _cone != null:
					_cone.progress = progress
			elif brain.stage == LamassuBrain.Stage.STRIKE:
				_wind_frame(delta)
		A.STOMP:
			if brain.stage == LamassuBrain.Stage.TELEGRAPH and _disc != null and is_instance_valid(_disc):
				_disc.progress = progress
		A.HOP:
			if brain.stage == LamassuBrain.Stage.TELEGRAPH and _shadow != null and is_instance_valid(_shadow):
				_shadow.progress = progress
				if _flying():
					kinematic = true
					_flap_frame(delta)


# --- the charge ---------------------------------------------------------------------

func _place_lane() -> void:
	if _lane == null or not is_instance_valid(_lane):
		return
	var forward := _flat(-global_basis.z).normalized()
	var start := global_position + forward * 1.2
	start.y = global_position.y
	_lane.global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), start)
	var run: Array = _clear_run(forward, LamassuBrain.CHARGE_RANGE.y)
	_lane.length = maxf(float(run[0]) - 1.2, 1.0)


func _scrape_frame(delta: float) -> void:
	if moves.pawing:
		_scrape_timer -= delta
		if _scrape_timer <= 0.0:
			_scrape_timer = 0.07
			var hoof := rig.contact(1)
			Fx.impact(Vector3(hoof.x, global_position.y + 0.05, hoof.z), Vector3.UP + global_basis.z, -1, 1.6)
			Fx.impact(Vector3(hoof.x, global_position.y + 0.05, hoof.z), Vector3.UP, ExhibitMaterial.Kind.MARBLE, 0.5)
		if not _scraped:
			_scraped = true
			Sfx.play_at(&"trex_scrape", rig.contact(1), -2.0, 0.1)
	else:
		_scraped = false


## The run begins: along its facing, to the first thing in its way - a
## wall it will skid before, cover it will crash into.
func _start_run() -> void:
	charge_dir = _flat(-global_basis.z).normalized()
	_charge_hit = false
	_charge_from = global_position
	var run: Array = _clear_run(charge_dir, LamassuBrain.CHARGE_RANGE.y + 6.0)
	var clear := float(run[0])
	var end: Vector3 = run[1]
	_charge_cover = clear < LamassuBrain.CHARGE_RANGE.y + 5.0 and cover_hit(end)
	var top := brain.charge_speed()
	var skid := top * top / (2.0 * LamassuBrain.SKID_DECEL)
	var past := LamassuBrain.CHARGE_RANGE.y
	if guard_alive():
		past = maxf(_flat(target.global_position - global_position).length() + LamassuBrain.CHARGE_OVERSHOOT, 6.0)
	if _charge_cover:
		_charge_length = clear + 1.0   # into it
	else:
		_charge_length = minf(past, maxf(clear - WALL_MARGIN - skid, 1.0))
	Sfx.play_at(&"lamassu_charge", global_position + Vector3.UP * 1.5, -2.0, 0.05)
	_shake_near(0.25, 14.0)


## The run: it tramples whoever stands in its line.
func _charge_frame() -> void:
	if not _charge_hit and guard_alive():
		var local := to_local(target.global_position)
		if -local.z > -0.8 and -local.z < CHARGE_AHEAD and absf(local.x) < CHARGE_HALF_WIDTH + ShockwaveRing.GUARD_RADIUS and local.y > -1.0 and local.y < 3.0:
			_charge_hit = true
			var side := signf(local.x) if absf(local.x) > 0.05 else 1.0
			var info := DamageInfo.make(LamassuBrain.CHARGE_DAMAGE * damage_scale, DamageInfo.Kind.BLUNT, self)
			info.direction = (charge_dir + global_basis.x * side * 1.4).normalized()
			info.knockback = LamassuBrain.CHARGE_KNOCKBACK
			info.position = target.global_position + Vector3.UP
			target.call(&"take_damage", info)
			Sfx.play_at(&"punch_hit", info.position, 3.0)
			_shake_near(0.6, 8.0)


## After the run's move: into cover -> stunned; into a wall it did not
## see -> a hard stop; far enough -> the skid.
func _charge_moved(before: Vector3, delta: float) -> void:
	var run := _flat(global_position - _charge_from).length()
	for i in get_slide_collision_count():
		var contact := get_slide_collision(i)
		var normal := contact.get_normal()
		if absf(normal.y) < 0.7 and normal.dot(charge_dir) < -0.4:
			_crash(contact.get_position(), normal)
			return
	if _charge_cover:
		var ahead: Array = _clear_run(charge_dir, 1.6)
		if float(ahead[0]) < 1.5 and speed > 4.0:
			_crash(ahead[1], ahead[2])
			return
	var moved := _flat(global_position - before).length()
	if brain.stage_time() > 0.3 and moved < speed * delta * 0.25:
		_crash(global_position + charge_dir * 1.5 + Vector3.UP, -charge_dir)
		return
	if run >= _charge_length:
		brain.end_charge(false)


func _crash(point: Vector3, normal: Vector3) -> void:
	_charge_frame()   # a guard pinned against it is hit
	var stunned := cover_hit(point)
	speed = 0.0
	velocity = Vector3.ZERO
	global_position -= charge_dir * 0.2
	brain.end_charge(stunned)
	_clear_marks(0.3)
	Fx.impact(point, normal, ExhibitMaterial.Kind.MARBLE, 3.5 if stunned else 2.0)
	Fx.impact(point, normal, -1, 3.0)
	for i in 8 if stunned else 3:
		var fling := normal * randf_range(1.5, 4.0) + Vector3(randf_range(-2.0, 2.0), randf_range(1.0, 4.0), randf_range(-2.0, 2.0))
		Fx.chunk(point + Vector3(randf_range(-0.4, 0.4), randf_range(-0.4, 0.8), randf_range(-0.4, 0.4)), LamassuRig.ALABASTER, randf_range(0.08, 0.2), fling)
	Sfx.play_at(&"trex_impact", point, 2.0 if stunned else -2.0)
	Sfx.play_at(&"break_marble", point, -2.0)
	_shake_near(0.8 if stunned else 0.4, 30.0)
	if stunned:
		Fx.hitstop(0.05)
	crashed.emit()


func _skid_frame(delta: float) -> void:
	if speed < 2.5:
		return
	_spark_timer -= delta
	if _spark_timer <= 0.0:
		_spark_timer = 0.06
		for leg in 2:
			var hoof := rig.contact(leg)
			Fx.impact(Vector3(hoof.x, global_position.y + 0.05, hoof.z), Vector3.UP - charge_dir, -1, 1.2)
			Fx.impact(Vector3(hoof.x, global_position.y + 0.05, hoof.z), Vector3.UP, ExhibitMaterial.Kind.MARBLE, 0.4)


# --- the gust ---------------------------------------------------------------------

func _place_cone() -> void:
	if _cone == null or not is_instance_valid(_cone):
		return
	_cone.global_transform = Transform3D(global_basis.orthonormalized(), Vector3(global_position.x, global_position.y, global_position.z))


## True when nothing stands between its chest and the guard's.
func _guard_exposed() -> bool:
	if not guard_alive():
		return false
	var space := get_world_3d().direct_space_state
	var from := rig.chest_point()
	var to := target.global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	query.exclude = [get_rid()]
	return space.intersect_ray(query).is_empty()


## The wings beat: the cone of wind, the shove, the lift, the grit.
func _gust_blows() -> void:
	_clear_marks(0.2)
	var chest := rig.chest_point()
	var forward := _flat(-global_basis.z).normalized()
	_wind_dir = forward
	var gust := WingGust.make(Vector3(chest.x, global_position.y + 0.3, chest.z), forward, LamassuBrain.GUST_REACH, LamassuBrain.GUST_HALF_ANGLE)
	get_parent().add_child(gust)
	Sfx.play_at(&"lamassu_gust", chest, 2.0, 0.05)
	_shake_near(0.35, 16.0)
	_wind_left = 0.0
	if not guard_alive() or not gust_reaches(global_position, forward, target.global_position) or not _guard_exposed():
		return
	var out := _flat(target.global_position - global_position)
	out = out.normalized() if out.length() > 0.1 else forward
	_wind_dir = out
	var info := DamageInfo.make(LamassuBrain.GUST_DAMAGE * damage_scale, DamageInfo.Kind.BLUNT, self)
	info.direction = out
	info.knockback = LamassuBrain.GUST_PUSH
	info.position = target.global_position + Vector3.UP
	target.call(&"take_damage", info)
	if target is CharacterBody3D:
		(target as CharacterBody3D).velocity.y = maxf((target as CharacterBody3D).velocity.y, LamassuBrain.GUST_LIFT)
	if target.has_method(&"yank"):
		target.call(&"yank", out * LamassuBrain.GUST_PUSH * 0.9, GUST_WIND_TIME)
	_wind_left = GUST_WIND_TIME
	for i in 6:
		Fx.chunk(target.global_position + Vector3(randf_range(-0.5, 0.5), randf_range(0.5, 1.6), randf_range(-0.5, 0.5)), WingGust.GRIT,
				randf_range(0.03, 0.06), out * randf_range(4.0, 8.0) + Vector3.UP * randf_range(1.0, 3.0))


## The wind goes on behind the shove for a moment (anything that is not
## the guard, who is yanked).
func _wind_frame(delta: float) -> void:
	if _wind_left <= 0.0 or not guard_alive():
		return
	_wind_left -= delta
	if target.has_method(&"yank") or not target is CharacterBody3D:
		return
	if gust_reaches(global_position, _wind_dir, target.global_position) and _guard_exposed():
		(target as CharacterBody3D).velocity += _wind_dir * LamassuBrain.GUST_WIND * delta


# --- the stomp and the hop -----------------------------------------------------------------

## Where the fore hooves come down (world, on the floor).
func _stomp_spot() -> Vector3:
	var at := to_global(moves.stomp_point)
	at.y = global_position.y
	return at


func _stomp_lands() -> void:
	var at := _stomp_spot()
	_clear_marks(0.15)
	for leg in 2:
		var hoof := to_global(Vector3(moves.stomp_point.x + (-0.41 if leg == 0 else 0.41), 0.0, moves.stomp_point.z))
		hoof.y = global_position.y
		gait.plant_at(leg, hoof)
		Fx.impact(hoof, Vector3.UP, -1, 2.5)
		Fx.impact(hoof, Vector3.UP, ExhibitMaterial.Kind.MARBLE, 1.5)
	moves.footfall(2.0)
	Sfx.play_at(&"lamassu_stomp", at + Vector3.UP * 0.4, 1.0, 0.08)
	_shake_near(0.55, 24.0)
	var ring := ShockwaveRing.make(at, LamassuBrain.STOMP_RING.y, LamassuBrain.STOMP_RING.z, LamassuBrain.STOMP_RING.x * damage_scale, self, LamassuBrain.STOMP_RADIUS)
	ring.target = target
	get_parent().add_child(ring)
	if not guard_alive():
		return
	var off := target.global_position - at
	if Vector2(off.x, off.z).length() <= LamassuBrain.STOMP_RADIUS + ShockwaveRing.GUARD_RADIUS and off.y < 1.6:
		ring.target = null   # the hooves hit him: the ring does not again
		var info := DamageInfo.make(LamassuBrain.STOMP_DAMAGE * damage_scale, DamageInfo.Kind.BLUNT, self)
		var out := _flat(target.global_position - global_position)
		info.direction = out.normalized() if out.length() > 0.1 else -global_basis.z
		info.knockback = LamassuBrain.STOMP_KNOCKBACK
		info.position = target.global_position + Vector3.UP
		target.call(&"take_damage", info)


## The flight: a ballistic arc from hop_from to hop_to over the rest of
## the telegraph, on beating wings.
func _hop_move() -> void:
	kinematic = true
	velocity = Vector3.ZERO
	var length := LamassuBrain.stage_length(A.HOP, LamassuBrain.Stage.TELEGRAPH, brain.phase)
	var u := clampf((brain.stage_time() / length - LamassuBrain.HOP_CROUCH) / (1.0 - LamassuBrain.HOP_CROUCH), 0.0, 1.0)
	var at := hop_from.lerp(hop_to, u)
	at.y = lerpf(hop_from.y, hop_to.y, u) + HOP_HEIGHT * 4.0 * u * (1.0 - u)
	global_position = at
	speed = 0.0
	_turn_rate = 0.0
	var to := _flat(hop_to - hop_from)
	if to.length() > 0.5:
		rotation.y = atan2(-to.x, -to.z)


func _flap_frame(delta: float) -> void:
	_spark_timer -= delta
	if _spark_timer <= 0.0:
		_spark_timer = 0.12
		Fx.impact(global_position + Vector3.UP * 1.5, Vector3.DOWN, -1, 1.2)


func _hop_lands() -> void:
	kinematic = false
	global_position = hop_to
	velocity = Vector3.ZERO
	gait.place(global_transform)
	var at := hop_to
	_clear_marks(0.15)
	for leg in 4:
		Fx.impact(rig.contact(leg), Vector3.UP, -1, 2.5)
	Fx.impact(at, Vector3.UP, ExhibitMaterial.Kind.MARBLE, 2.0)
	moves.footfall(3.0)
	Sfx.play_at(&"lamassu_stomp", at + Vector3.UP * 0.4, 3.0, 0.05)
	_shake_near(0.7, 26.0)
	var ring := ShockwaveRing.make(at, LamassuBrain.HOP_RING.y, LamassuBrain.HOP_RING.z, LamassuBrain.HOP_RING.x * damage_scale, self, LamassuBrain.HOP_RADIUS)
	ring.target = target
	get_parent().add_child(ring)
	if not guard_alive():
		return
	var off := target.global_position - at
	if Vector2(off.x, off.z).length() <= LamassuBrain.HOP_RADIUS + ShockwaveRing.GUARD_RADIUS and off.y < 2.0:
		ring.target = null
		var info := DamageInfo.make(LamassuBrain.HOP_DAMAGE * damage_scale, DamageInfo.Kind.BLUNT, self)
		var out := _flat(target.global_position - at)
		info.direction = out.normalized() if out.length() > 0.1 else -global_basis.z
		info.knockback = LamassuBrain.HOP_KNOCKBACK
		info.position = target.global_position + Vector3.UP
		target.call(&"take_damage", info)


## The phase-3 shift: the wing beats hold it off the floor.
func _hover_move() -> void:
	kinematic = true
	speed = 0.0
	_turn_rate = 0.0
	velocity = Vector3.ZERO
	global_position.y = _hover_from + LamassuMoves.HOVER_HEIGHT * moves.hover


# --- waking, stun, phases ---------------------------------------------------------

func _state_frame(delta: float) -> void:
	var lit := brain.state == S.STUNNED or brain.phase >= 2
	_crack_light.visible = lit
	if lit:
		_crack_light.light_energy = (1.2 if brain.state == S.STUNNED else 0.5) + 0.4 * sin(moves.time * 6.0)
	if brain.state == S.STUNNED:
		_spark_timer -= delta
		if _spark_timer <= 0.0:
			_spark_timer = 0.3
			Fx.impact(rig.face_point(), Vector3.DOWN, ExhibitMaterial.Kind.MARBLE, 0.5)
	elif brain.state == S.PHASE_SHIFT:
		var u := brain.state_progress()
		# (the cracks blaze in the first shift it plays, into phase 2 or
		# straight into 3)
		if brain.phase >= 2 and not rig.cracked and u >= 0.45:
			rig.crack(true)
			Fx.flash(rig.chest_point(), CRACK, 4.0, 8.0, 0.4)
			Fx.impact(rig.chest_point(), -global_basis.z, ExhibitMaterial.Kind.MARBLE, 3.0)
			Sfx.play_at(&"relief_crack", rig.chest_point(), 3.0)
			_shake_near(0.5, 30.0)
		if brain.shift_phase == 3:
			_spark_timer -= delta
			if _spark_timer <= 0.0:
				_spark_timer = 0.15
				Fx.impact(global_position + Vector3.UP * 0.3, Vector3.UP, -1, 2.0 * moves.hover + 0.5)
			if not _wake_done.has(&"drop") and u >= 0.9:
				_wake_done[&"drop"] = true
				global_position.y = _hover_from
				gait.place(global_transform)
				Sfx.play_at(&"lamassu_stomp", global_position, 3.0)
				_shake_near(0.7, 30.0)
				moves.footfall(3.0)
	elif brain.state == S.WAKING:
		var u := brain.state_progress()
		if not _wake_done.has(&"dust") and u >= 0.02:
			_wake_done[&"dust"] = true
			for i in 4:
				Fx.impact(global_position + Vector3(randf_range(-0.6, 0.6), randf_range(1.5, 3.2), randf_range(-1.2, 1.2)), Vector3.DOWN, ExhibitMaterial.Kind.MARBLE, 1.5)
		if not _wake_done.has(&"wings") and u >= 0.14:
			_wake_done[&"wings"] = true
			Sfx.play_at(&"relief_scrape", global_position + Vector3.UP * 2.6, 1.0)
			Sfx.play_at(&"relief_crack", global_position + Vector3.UP * 2.6, -3.0)
			Fx.impact(global_position + Vector3.UP * 2.6, Vector3.UP, ExhibitMaterial.Kind.MARBLE, 2.0)


## A hoof came down: dust, and at speed or stepping down a thud and a
## tremor.
func _on_hoof_landed(leg: int) -> void:
	if not is_inside_tree() or brain.state == S.DORMANT:
		return
	var at := gait.feet[leg]
	var heavy := brain.state == S.WAKING or gait.speed > 4.0 or brain.state == S.PHASE_SHIFT
	Fx.impact(at + Vector3.UP * 0.05, Vector3.UP, -1, 0.7 + gait.speed * 0.08 + (1.5 if heavy else 0.0))
	if heavy:
		Sfx.play_at(&"lamassu_stomp", at, -6.0 if gait.speed > 4.0 else -2.0, 0.1)
		moves.footfall(1.0 if gait.speed > 4.0 else 1.6)
		_shake_near(0.12 if gait.speed > 4.0 else 0.22, 12.0)
	elif brain.state == S.IDLE:
		moves.footfall(0.5)


# --- calm, freeze, fall -------------------------------------------------------------

func _on_reset() -> void:
	brain.reset()
	moves.reset()
	speed = 0.0
	_turn_rate = 0.0
	velocity = Vector3.ZERO
	kinematic = false
	crown_damage = 0.0
	wing_damage = [0.0, 0.0]
	_chip_next = [WING_CHIP, WING_CHIP]
	_wind_left = 0.0
	rig.restore()
	(_crown_box.get_child(0) as CollisionShape3D).shape.size = Vector3(0.58, 0.82, 0.58)
	_crown_box.position = (rig.rest["headdress"] as Transform3D).origin + Vector3(0.0, 0.4, 0.0)
	_clear_marks()
	_on_plinth = true
	_pass_plinth(false)
	_crack_light.visible = false
	gait.place(global_transform)
	rig.apply(moves.compose(brain, gait, global_transform, 0.0))


func _on_freeze() -> void:
	_clear_marks()
	_wind_left = 0.0
	_crack_light.visible = false


func _on_defeated(info: DamageInfo) -> void:
	brain.die()
	_clear_marks()
	_wind_left = 0.0
	# a killing blow in the air (the hop's arc, the phase-3 hover): it kneels
	# on the floor, not in mid-air, its hooves down
	var floor_y := _floor_under(global_position)
	if global_position.y > floor_y + 0.05:
		global_position.y = floor_y
		gait.place(global_transform)
		rig.apply(moves.compose(brain, gait, global_transform, 0.0))
	get_parent().add_child(LamassuFall.make(self, info))


# --- helpers ------------------------------------------------------------------------

func _clear_marks(fade: float = 0.25) -> void:
	for mark: GroundMark in [_lane, _cone, _disc, _shadow]:
		if mark != null and is_instance_valid(mark):
			mark.vanish(fade)
	_lane = null
	_cone = null
	_disc = null
	_shadow = null


## Camera shake for a guard within [param reach] m, fading with distance.
func _shake_near(trauma: float, reach: float) -> void:
	if not guard_alive() or not target is Player:
		return
	var distance := target.global_position.distance_to(global_position)
	if distance < reach:
		Events.shake_requested.emit(trauma * (1.0 - distance / reach))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
