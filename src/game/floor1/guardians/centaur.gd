class_name Centaur
extends Guardian
## Kentaur z metopy - the Centaur from the metope, Greece's wing guardian
## (design 7.4; plan docs/superpowers/plans/2026-10-03-straznik-kentaur.md):
## a 2.86 m marble centaur standing in a great metope slab in the middle of
## the Parthenon gallery, side on to the arena's mouth like a figure in
## relief. The guard steps in: its eyes ignite, it strains against the
## stone (cracks of light run over the slab), rears and tears free (the
## slab bursts into blocks), crashes down and turns on him. Then it fights
## fast and from a distance (CentaurBrain holds every number):
## 1. it GALLOPS round the guard (CentaurGait: four-beat hooves planted by
##    IK, the barrel rocking and banking, the torso leaning into turns, the
##    tail streaming - dust and sparks under the hooves, the floor shaking
##    as it thunders past), and THROWS JAVELINS on the run: the torso winds
##    back, the javelin glints, a mark on the floor tracks the guard and
##    stops as the javelin leaves; it comes down on the mark in an arc and
##    sticks in the floor; plinths stop it;
## 2. it CHARGES down the gallery: it stops, faces him, drops its torso,
##    levels its javelin like a lance and scrapes a hoof - a lane on the
##    floor shows the run to the first thing in its way; whoever stays in
##    the lane is run down; a plinth, a pediment group, the stump of its
##    metope or a wall stops it dead and it reels (STUNNED: the chest cracks
##    blaze, the weak point counts half again);
## 3. up close it REARS and strikes down with its fore hooves on a mark
##    before it (a ring rolls out - jump it), or, the guard behind it, BUCKS
##    (the hind hooves lash out behind).
## Phase 2 (< 66 %): it rears and cries, and Lapiths step down from the
## pediment groups (CentaurBrain.LAPITHS; again once they fell). Phase 3
## (< 33 %): it tears the metope's piece off its flank and flings it; a
## javelin forms in its left hand - it throws two at once now, faster.
## Damage: the marble chest is the weak point (cracks glowing), the head
## counts x1.25, the human torso and arms x0.5, the horse body x0.25 (grey
## marker, marble chips). Its fall: CentaurFall (it stumbles on, the legs
## fold, it breaks into marble); the keeper drops the seal and the shard.
## Body space: origin on the floor under its barrel, -Z its front.

## Announced (the warning starts) and landed (the damage moment, or the
## start of the active part): throw, kick, buck, charge, call, tear.
signal telegraphed(attack: StringName)
signal struck(attack: StringName)
## The charge ran into something.
signal crashed
## It tore free of its metope (waking).
signal broke_free

const A := CentaurBrain.Attack
const S := CentaurBrain.State
const NAMES := {
	CentaurBrain.Attack.THROW: &"throw", CentaurBrain.Attack.KICK: &"kick", CentaurBrain.Attack.BUCK: &"buck",
	CentaurBrain.Attack.CHARGE: &"charge", CentaurBrain.Attack.CALL: &"call", CentaurBrain.Attack.TEAR: &"tear",
}
## Damage factors by zone (the chest: the brain's weak factor).
const HEAD := 1.25
const MAN := 0.5
const HORSE := 0.25
## Its collider (centre, size), body space: the horse body down to the floor.
const BODY_BOX := [Vector3(0.0, 0.95, 0.12), Vector3(0.86, 1.86, 2.1)]
## The charge runs the guard down within this half-width of its line, from
## behind its chest to this far ahead (m).
const CHARGE_HALF_WIDTH := 0.6
const CHARGE_AHEAD := 2.0
## The waking's moments (progress): the slab cracks, bursts, the hooves land.
const WAKE_CRACK := 0.1
const WAKE_BURST := 0.45
const WAKE_LAND := 0.63
## Turning: lateral grip (m/s^2) and its least and greatest turn rates.
const GRIP := 13.0
const TURN := Vector2(1.1, 3.4)
const ACCELERATION := 10.0
const BRAKING := 14.0
## Its probes for room ahead: heights (m) and the headings it tries.
const PROBE_HEIGHTS: Array[float] = [0.4, 1.0]
const DETOURS: Array[float] = [0.0, 0.35, -0.35, 0.7, -0.7, 1.05, -1.05, 1.4, -1.4]
const GOLD := Color(1.0, 0.82, 0.5)
const LAPITH_PATH := "res://src/enemies/hoplite.gd"

var brain := CentaurBrain.new()
var gait := CentaurGait.new()
var rig: CentaurRig
var moves: CentaurMoves
var metope: CentaurMetope
## The Lapiths it called that still stand.
var lapiths: Array[Node] = []
## Its javelins thrown and not yet gone.
var javelins: Array[Node] = []
## Where each javelin of the throw under way will come down (left, right).
var throw_marks: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
## Its run now (m/s, along its facing).
var speed: float = 0.0
## The charge's line (world, flat).
var charge_dir := Vector3.FORWARD

var _look: Node3D
var _zones := {}
var _zone_factor: float = 1.0
var _gold_frame: int = -1
var _marks: Array = [null, null]
var _lane: GroundMark
var _hoof_mark: GroundMark
var _released: Array[bool] = [true, true]
var _charge_hit := false
var _charge_from := Vector3.ZERO
var _charge_length: float = 0.0
var _yaw_goal: float = 0.0
var _steer_timer: float = 0.0
var _blocked_time: float = 0.0
var _wake_done := {}
var _scrape_timer: float = 0.0
var _scraped := false
var _spark_timer: float = 0.0
var _gallop: AudioStreamPlayer3D
var _chest_light: OmniLight3D
var _guard_before := Vector3.ZERO
var _guard_velocity := Vector3.ZERO
var _lurch := Vector3.RIGHT


func _init() -> void:
	max_health = 850.0


## The metope he sleeps in (GuardianKeeper, every night; after his fall
## the empty stump).
static func dress_arena(level: MuseumFloorLevel, parent: Node3D) -> Array[Node3D]:
	var props: Array[Node3D] = []
	if level.markers.has(&"guardian_centaur"):
		var slab := CentaurMetope.make(level.markers[&"guardian_centaur"], GameState.is_guardian_defeated(&"centaur"))
		parent.add_child(slab)
		props.append(slab)
	return props


# --- body -------------------------------------------------------------------

func _build_body() -> void:
	# it runs through the guard (the charge's contact hurts him), never into
	# him; the world stops it
	collision_mask = Layers.WORLD
	_look = Node3D.new()
	_look.name = "Look"
	add_child(_look)
	rig = CentaurRig.create(_look)
	moves = CentaurMoves.new(rig)
	var shape := BoxShape3D.new()
	shape.size = BODY_BOX[1]
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = BODY_BOX[0]
	add_child(collider)
	_build_zones()
	_chest_light = OmniLight3D.new()
	_chest_light.light_color = GOLD
	_chest_light.omni_range = 5.0
	_chest_light.light_energy = 0.0
	_chest_light.visible = false
	rig.part("chest").add_child(_chest_light)
	_chest_light.position = Vector3(0.0, 0.0, -0.4)
	_gallop = AudioStreamPlayer3D.new()
	_gallop.stream = Sfx.stream_of(&"centaur_gallop")
	_gallop.bus = &"SFX"
	_gallop.max_distance = 60.0
	add_child(_gallop)
	_find_metope()
	_lurch = global_basis.x
	gait.place(global_transform)
	brain.telegraphed.connect(_on_telegraphed)
	brain.struck.connect(_on_struck)
	brain.finished.connect(_on_finished)
	brain.state_changed.connect(_on_state_changed)
	gait.touchdown.connect(_on_touchdown)
	rig.apply(moves.compose(brain, gait, global_transform, 0.0))


## Hit zones on the parts (they move with it): the chest (weak), the head,
## the human torso and arms, the horse body.
func _build_zones() -> void:
	var horse := _zone(&"body")
	var man := _zone(&"torso")
	var head := _zone(&"head")
	for view in rig.meshes:
		var key := String(view.name)
		if key.begins_with("javelin"):
			continue
		var receiver := horse
		if key == "neck":
			receiver = head
		elif key == "torso" or key.begins_with("arm_") or key.begins_with("forearm_") or key.begins_with("wrist_"):
			receiver = man
		var box := view.get_aabb()
		var shape := BoxShape3D.new()
		shape.size = box.size.max(Vector3.ONE * 0.12)
		view.add_child(Hurtbox.make(receiver, shape, box.get_center()))
	# the marble chest, standing proud of the torso: a shot from the front
	# finds it before the torso
	var chest := BoxShape3D.new()
	chest.size = Vector3(0.46, 0.42, 0.24)
	rig.part("chest").add_child(Hurtbox.make(_zone(&"chest"), chest, Vector3(0.0, -0.02, -0.06), true))


func _zone(zone_name: StringName) -> GuardianZone:
	var zone := GuardianZone.make(self, zone_name)
	add_child(zone)
	_zones[zone_name] = zone
	return zone


## The metope the keeper raised at its post, or one of its own (a dev
## arena, a test).
func _find_metope() -> void:
	for node in get_tree().get_nodes_in_group(CentaurMetope.GROUP):
		var slab := node as CentaurMetope
		if slab != null and slab.global_position.distance_to(global_position) < 1.0:
			metope = slab
	if metope == null:
		metope = CentaurMetope.make(global_transform)
		metope.top_level = true
		add_child(metope)
		metope.global_transform = global_transform


# --- damage -------------------------------------------------------------------

func take_zone_damage(info: DamageInfo, zone: StringName) -> void:
	if info == null:
		return
	var weak := zone == &"chest"
	match zone:
		&"chest":
			_zone_factor = brain.weak_factor()
		&"head":
			_zone_factor = HEAD
		&"torso":
			_zone_factor = MAN
		_:
			_zone_factor = HORSE
	info.weak_point = weak
	info.blocked = zone == &"body"
	super(info, zone)
	_zone_factor = 1.0
	if state == State.FIGHT and info.effects and not info.periodic:
		moves.flinch(1.0 if weak else 0.35)


func _damage_factor(_info: DamageInfo) -> float:
	return _zone_factor


func _hit_effects(info: DamageInfo) -> void:
	if info.weak_point:
		Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.MARBLE, clampf(info.amount / 10.0, 1.0, 3.0))
		Fx.flash(info.position, GOLD, 2.5, 3.0, 0.08)
		Sfx.play_at(&"hit_marble", info.position, 1.0)
		rig.flash(0.6)
	elif info.blocked:
		# marble chips fly off the horse
		Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.MARBLE, 1.2)
		Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.METAL, 0.5)
		Fx.chunk(info.position, Color(0.9, 0.87, 0.8), randf_range(0.04, 0.08), info.normal * 2.5 + Vector3.UP * 1.5)
		Sfx.play_at(&"hit_marble", info.position, -6.0, 0.25)
	else:
		Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.MARBLE, 1.4)
		Sfx.play_at(&"hit_marble", info.position, -2.0)
		rig.flash(0.25)


## One blast can strike the chest and the horse at once: the grey marker
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
	var before := global_position
	super(delta)
	if state != State.FIGHT or is_frozen():
		return
	if not guard_alive():
		_idle_frame(delta)
		return
	if brain.state == S.ATTACK and brain.attack == A.CHARGE and brain.stage == CentaurBrain.Stage.STRIKE:
		_charge_moved(before, delta)


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
	brain.lapiths_alive = alive_lapiths()
	brain.update(delta, distance, bearing)
	_move(delta, guard, distance)
	moves.guard = to_local(guard + Vector3.UP * 1.4)
	_attack_frame(delta)
	gait.update(delta, global_transform, velocity)
	_animate(delta)
	_state_frame(delta)
	_sounds(delta)


## The guard fell: it settles where it stands.
func _idle_frame(delta: float) -> void:
	_clear_marks()
	speed = move_toward(speed, 0.0, BRAKING * delta)
	brain.update(delta, INF, 0.0)
	gait.update(delta, global_transform, Vector3.ZERO)
	_animate(delta)
	_sounds(delta)


func _animate(delta: float) -> void:
	var pose := moves.compose(brain, gait, global_transform, delta)
	pose.cracks = maxf(pose.cracks, 0.25 + 0.35 * float(brain.phase - 1))
	rig.apply(pose, delta)


## The Lapiths it called that still stand.
func alive_lapiths() -> int:
	if lapiths.is_empty():
		return 0
	var alive: Array[Node] = []
	for node in lapiths:
		if is_instance_valid(node) and not node.is_queued_for_deletion() and not (node is Enemy and (node as Enemy).health != null and (node as Enemy).health.is_dead()):
			alive.append(node)
	lapiths = alive
	return lapiths.size()


# --- moving -------------------------------------------------------------------

func _move(delta: float, guard: Vector3, distance: float) -> void:
	var wanted := brain.wanted_speed()
	var turn_to := rotation.y
	var turning := true
	match brain.state:
		S.WAKING:
			var u := brain.state_progress()
			wanted = 2.2 if u > 0.55 and u < 0.85 else 0.0
			turning = u > 0.5
			turn_to = _yaw_toward(guard)
		S.ROAM:
			turn_to = _roam_yaw(delta, guard, distance)
		S.ATTACK:
			match brain.attack:
				A.THROW:
					turn_to = _roam_yaw(delta, guard, distance)
				A.KICK:
					turning = brain.stage == CentaurBrain.Stage.TELEGRAPH and brain.stage_time() < 0.15
					turn_to = _yaw_toward(guard)
				A.CHARGE:
					turning = brain.stage == CentaurBrain.Stage.TELEGRAPH and _charge_aiming()
					turn_to = _yaw_toward(guard)
				A.CALL, A.TEAR:
					turn_to = _yaw_toward(guard)
				_:
					turning = false
		_:
			turning = false
	var charging := brain.state == S.ATTACK and brain.attack == A.CHARGE and brain.stage == CentaurBrain.Stage.STRIKE
	var rate := ACCELERATION * (2.4 if charging else 1.0) if wanted > speed else BRAKING * (1.3 if brain.attack == A.CHARGE else 1.0)
	speed = move_toward(speed, wanted, rate * delta)
	if turning:
		var grip := clampf(GRIP / maxf(speed, 0.1), TURN.x, TURN.y)
		if brain.attack == A.CHARGE and brain.state == S.ATTACK:
			grip = TURN.y
		var gap := wrapf(turn_to - rotation.y, -PI, PI)
		# it slows into a sharp turn
		if absf(gap) > 0.9 and not charging:
			speed = move_toward(speed, minf(speed, 4.0), BRAKING * delta)
		rotation.y = wrapf(rotation.y + clampf(gap, -grip * delta, grip * delta), -PI, PI)
	var forward := -global_basis.z
	var along := charge_dir if charging else forward
	if brain.state == S.WAKING:
		along = _lurch
	velocity.x = along.x * speed
	velocity.z = along.z * speed


## The world yaw that faces [param point].
func _yaw_toward(point: Vector3) -> float:
	var to := point - global_position
	return atan2(-to.x, -to.z)


## Circling the guard at its distance, round what stands in the way.
func _roam_yaw(delta: float, guard: Vector3, distance: float) -> float:
	_steer_timer -= delta
	if _steer_timer > 0.0:
		return _yaw_goal
	_steer_timer = 0.1
	var away := Vector3(global_position.x - guard.x, 0.0, global_position.z - guard.z)
	away = away.normalized() if away.length() > 0.01 else global_basis.z
	var tangent := Vector3.UP.cross(away) * float(brain.side)
	var radial := clampf((brain.keep_distance() - distance) / 4.0, -1.0, 1.0)
	var wish := (tangent + away * radial * 1.3).normalized()
	var yaw := atan2(-wish.x, -wish.z)
	for offset in DETOURS:
		if _room_toward(yaw + offset):
			if absf(offset) > 1.0:
				_blocked_time += 0.1
			else:
				_blocked_time = 0.0
			if _blocked_time > 0.6:
				_blocked_time = 0.0
				brain.flip()
			_yaw_goal = yaw + offset
			return _yaw_goal
	# boxed in: turn back the way it came, the other way round
	brain.flip()
	_yaw_goal = rotation.y + PI
	return _yaw_goal


## True when the way toward [param yaw] is clear for a stride or two and
## stays in its gallery.
func _room_toward(yaw: float) -> bool:
	var direction := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var reach := clampf(speed * 0.55, 2.4, 6.5)
	var space := get_world_3d().direct_space_state
	var side := direction.cross(Vector3.UP) * 0.42
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
## [param limit]).
func _clear_run(direction: Vector3, limit: float) -> float:
	var space := get_world_3d().direct_space_state
	var best := limit
	for height in PROBE_HEIGHTS:
		var from := global_position + Vector3.UP * height
		var query := PhysicsRayQueryParameters3D.create(from, from + direction * limit, Layers.WORLD)
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			best = minf(best, from.distance_to(hit["position"]))
	return best


# --- the attacks ------------------------------------------------------------------

func _on_telegraphed(attack: A) -> void:
	_clear_marks()
	match attack:
		A.THROW:
			for side in 2:
				_released[side] = side == 0 and not brain.pair
				if not _released[side]:
					throw_marks[side] = _predicted(side)
					var mark := GroundMark.disc(CentaurBrain.JAVELIN_RADIUS)
					_marks[side] = mark
					get_parent().add_child(mark)
					mark.global_transform = Transform3D(Basis.IDENTITY, throw_marks[side])
			Fx.flash(rig.javelin_tip(1), GOLD, 1.5, 3.0, 0.15)
		A.KICK:
			var at := to_global(Vector3(0.0, 0.0, -CentaurBrain.KICK_REACH))
			at.y = global_position.y
			_hoof_mark = GroundMark.disc(CentaurBrain.KICK_RADIUS)
			get_parent().add_child(_hoof_mark)
			_hoof_mark.global_transform = Transform3D(global_basis.orthonormalized(), at)
			Sfx.play_at(&"tail_whoosh", global_position + Vector3.UP * 2.0, -4.0)
		A.BUCK:
			_hoof_mark = GroundMark.arc(0.6, CentaurBrain.BUCK_REACH + 0.6, PI - CentaurBrain.BUCK_SPREAD, PI + CentaurBrain.BUCK_SPREAD)
			get_parent().add_child(_hoof_mark)
			_hoof_mark.global_transform = Transform3D(global_basis.orthonormalized(), global_position)
		A.CHARGE:
			_scraped = false
			_lane = GroundMark.lane(CHARGE_HALF_WIDTH * 2.0 + 0.4, 6.0)
			get_parent().add_child(_lane)
			_place_lane()
		A.CALL:
			Sfx.play_at(&"guardian_wake", global_position + Vector3.UP * 2.5, 0.0)
		A.TEAR:
			Sfx.play_at(&"relief_crack", rig.part("slab").global_position, 0.0)
	telegraphed.emit(NAMES[attack])


func _on_struck(attack: A) -> void:
	match attack:
		A.THROW:
			_release(1)
		A.KICK:
			_hooves_land()
		A.BUCK:
			_buck_lands()
		A.CHARGE:
			charge_dir = _flat(-global_basis.z).normalized()
			_charge_hit = false
			_charge_from = global_position
			_charge_length = minf(_clear_run(charge_dir, CentaurBrain.CHARGE_RANGE.y), CentaurBrain.CHARGE_RANGE.y)
			if guard_alive():
				_charge_length = minf(_charge_length + 0.5, maxf(_flat(target.global_position - global_position).length() + 7.0, 8.0))
			Sfx.play_at(&"lamassu_charge", global_position + Vector3.UP * 1.5, -3.0, 0.05)
			_shake_near(0.25, 14.0)
		A.CALL:
			_call_lapiths()
		A.TEAR:
			_tear_slab()
	struck.emit(NAMES[attack])


func _on_finished(attack: A) -> void:
	if attack == A.CHARGE and _lane != null:
		_clear_marks(0.4)
	elif attack != A.THROW:
		_clear_marks()
	if attack == A.TEAR:
		Fx.flash(rig.hand_point(0), GOLD, 3.0, 4.0, 0.3)


func _on_state_changed(_from: S, to: S) -> void:
	match to:
		S.WAKING:
			_wake_done.clear()
			_lurch = global_basis.x
		S.STUNNED:
			_chest_light.visible = true


## Effects that run through an attack: the marks, the second javelin, the
## lane, the scrape.
func _attack_frame(delta: float) -> void:
	if brain.state != S.ATTACK:
		return
	var progress := brain.stage_time() / maxf(CentaurBrain.stage_length(brain.attack, brain.stage, brain.phase), 0.01)
	match brain.attack:
		A.THROW:
			if brain.stage == CentaurBrain.Stage.TELEGRAPH:
				for side in 2:
					if not _released[side]:
						throw_marks[side] = throw_marks[side].lerp(_predicted(side), clampf(delta * 9.0, 0.0, 1.0))
						var mark := _marks[side] as GroundMark
						if mark != null and is_instance_valid(mark):
							mark.global_position = throw_marks[side]
							mark.progress = progress
			elif brain.stage == CentaurBrain.Stage.STRIKE and not _released[0] and brain.stage_time() >= CentaurBrain.PAIR_GAP:
				_release(0)
			for side in 2:
				var hand := rig.hand_point(side)
				var flight := CentaurJavelin.flight_time(_flat(throw_marks[side] - hand).length())
				moves.throw_dir[side] = global_basis.inverse() * CentaurJavelin.launch_velocity(hand, throw_marks[side], flight, CentaurJavelin.GRAVITY).normalized()
		A.KICK, A.BUCK:
			if brain.stage == CentaurBrain.Stage.TELEGRAPH and _hoof_mark != null and is_instance_valid(_hoof_mark):
				_hoof_mark.progress = progress
		A.CHARGE:
			if brain.stage == CentaurBrain.Stage.TELEGRAPH:
				_place_lane()
				if _lane != null:
					_lane.progress = progress
				_scrape_frame(delta)
			elif brain.stage == CentaurBrain.Stage.STRIKE:
				_charge_frame()
			else:
				_skid_frame(delta)


## Where javelin [param side] should come down: ahead of the guard by part
## of his run over its flight (the right hand), where he stands (the left).
func _predicted(side: int) -> Vector3:
	if not guard_alive():
		return to_global(Vector3(0.0, 0.0, -10.0))
	var at := target.global_position
	at.y = global_position.y
	if side == 1:
		var flight := CentaurJavelin.flight_time(_flat(at - global_position).length())
		var lead := CentaurBrain.per_phase(CentaurBrain.JAVELIN_LEAD, brain.phase)
		at += _flat(_guard_velocity) * flight * lead
	elif throw_marks[1].distance_to(at) < 2.2:
		# the second one beside the first, not on it
		var across := _flat(at - global_position).normalized().cross(Vector3.UP)
		at += across * 2.2
	return at


## Javelin [param side] leaves the hand for its mark (locked now).
func _release(side: int) -> void:
	if _released[side]:
		return
	_released[side] = true
	var to := throw_marks[side]
	var hand := rig.hand_point(side)
	var flight := CentaurJavelin.flight_time(_flat(to - hand).length())
	var line := CentaurJavelin.launch_velocity(hand, to, flight, CentaurJavelin.GRAVITY).normalized()
	# the tip leaves where it lay in the hand, ahead of the grip
	var javelin := CentaurJavelin.make(hand + line * 1.3, to, flight * 0.9, CentaurBrain.JAVELIN_DAMAGE * damage_scale, self, target)
	javelin.radius = CentaurBrain.JAVELIN_RADIUS
	get_parent().add_child(javelin)
	javelins.append(javelin)
	var mark := _marks[side] as GroundMark
	if mark != null and is_instance_valid(mark):
		mark.progress = 1.0
		javelin.mark = mark   # it stays till the javelin comes down
	_marks[side] = null
	Fx.flash(hand, GOLD, 1.2, 2.5, 0.1)
	Sfx.play_at(&"tail_whoosh", hand, -6.0, 0.1)


func _hooves_land() -> void:
	var at := to_global(Vector3(0.0, 0.0, -CentaurBrain.KICK_REACH))
	at.y = global_position.y
	_clear_marks(0.15)
	for side in [-1.0, 1.0]:
		var hoof := to_global(Vector3(side * 0.24, 0.1, -CentaurBrain.KICK_REACH))
		Fx.impact(hoof, Vector3.UP, ExhibitMaterial.Kind.METAL, 1.6)
		Fx.impact(hoof, Vector3.UP, -1, 2.5)
		Fx.impact(hoof, Vector3.UP, ExhibitMaterial.Kind.MARBLE, 1.5)
	Sfx.play_at(&"lamassu_stomp", at + Vector3.UP * 0.4, 0.0, 0.08)
	_shake_near(0.5, 22.0)
	var ring := ShockwaveRing.make(at, CentaurBrain.KICK_RING.y, CentaurBrain.KICK_RING.z, CentaurBrain.KICK_RING.x * damage_scale, self, 0.6)
	ring.target = target
	get_parent().add_child(ring)
	if not guard_alive():
		return
	var off := target.global_position - at
	if Vector2(off.x, off.z).length() <= CentaurBrain.KICK_RADIUS + ShockwaveRing.GUARD_RADIUS and off.y < 1.6:
		ring.target = null   # the hooves hit him: the ring does not again
		var info := DamageInfo.make(CentaurBrain.KICK_DAMAGE * damage_scale, DamageInfo.Kind.BLUNT, self)
		var out := _flat(target.global_position - global_position)
		info.direction = out.normalized() if out.length() > 0.1 else -global_basis.z
		info.knockback = CentaurBrain.KICK_KNOCKBACK
		info.position = target.global_position + Vector3.UP
		target.call(&"take_damage", info)


func _buck_lands() -> void:
	_clear_marks(0.2)
	Sfx.play_at(&"tail_whoosh", to_global(Vector3(0.0, 0.8, 2.0)), 2.0)
	for side in [-1.0, 1.0]:
		Fx.impact(to_global(Vector3(side * 0.22, 0.5, 2.0)), global_basis.z, -1, 1.5)
	if not guard_alive():
		return
	var local := to_local(target.global_position)
	var behind := Vector2(local.x, local.z)
	var bearing := absf(atan2(-local.x, -local.z))
	if local.z > 0.0 and behind.length() <= CentaurBrain.BUCK_REACH + 0.6 and bearing >= PI - CentaurBrain.BUCK_SPREAD - 0.25 and local.y < 1.8:
		var info := DamageInfo.make(CentaurBrain.BUCK_DAMAGE * damage_scale, DamageInfo.Kind.BLUNT, self)
		info.direction = (global_basis.z + Vector3.UP * 0.3).normalized()
		info.knockback = CentaurBrain.BUCK_KNOCKBACK
		info.position = target.global_position + Vector3.UP
		target.call(&"take_damage", info)
		Sfx.play_at(&"punch_hit", target.global_position, 2.0)
		_shake_near(0.45, 6.0)


# --- the charge ---------------------------------------------------------------------

## True while the charge still aims (until CHARGE_LOCK before it runs).
func _charge_aiming() -> bool:
	var length := CentaurBrain.stage_length(A.CHARGE, CentaurBrain.Stage.TELEGRAPH, brain.phase)
	return brain.stage_time() < length - 0.25


func _place_lane() -> void:
	if _lane == null or not is_instance_valid(_lane):
		return
	var forward := _flat(-global_basis.z).normalized()
	var start := global_position + forward * 0.9
	start.y = global_position.y
	_lane.global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), start)
	_lane.length = maxf(_clear_run(forward, CentaurBrain.CHARGE_RANGE.y) - 0.9, 1.0)


func _scrape_frame(delta: float) -> void:
	if moves.scraping:
		_scrape_timer -= delta
		if _scrape_timer <= 0.0:
			_scrape_timer = 0.07
			var hoof := rig.part("hoof_fr").global_position
			Fx.impact(Vector3(hoof.x, global_position.y + 0.05, hoof.z), Vector3.UP + global_basis.z, -1, 1.4)
			Fx.impact(Vector3(hoof.x, global_position.y + 0.05, hoof.z), Vector3.UP, ExhibitMaterial.Kind.METAL, 0.5)
		if not _scraped:
			_scraped = true
			Sfx.play_at(&"trex_scrape", rig.part("hoof_fr").global_position, -2.0, 0.1)
	else:
		_scraped = false


## The run: it tramples whoever stands in its line.
func _charge_frame() -> void:
	if not _charge_hit and guard_alive():
		var local := to_local(target.global_position)
		if -local.z > -0.8 and -local.z < CHARGE_AHEAD and absf(local.x) < CHARGE_HALF_WIDTH + ShockwaveRing.GUARD_RADIUS and local.y > -1.0 and local.y < 2.4:
			_charge_hit = true
			var side := signf(local.x) if absf(local.x) > 0.05 else 1.0
			var info := DamageInfo.make(CentaurBrain.CHARGE_DAMAGE * damage_scale, DamageInfo.Kind.BLUNT, self)
			info.direction = (charge_dir + global_basis.x * side * 1.3).normalized()
			info.knockback = CentaurBrain.CHARGE_KNOCKBACK
			info.position = target.global_position + Vector3.UP
			target.call(&"take_damage", info)
			Sfx.play_at(&"punch_hit", info.position, 3.0)
			_shake_near(0.6, 8.0)


## After the run's move: into something -> stunned; past the guard -> skid.
func _charge_moved(before: Vector3, delta: float) -> void:
	var run := _flat(global_position - _charge_from).length()
	for i in get_slide_collision_count():
		var contact := get_slide_collision(i)
		var normal := contact.get_normal()
		if absf(normal.y) < 0.7 and normal.dot(charge_dir) < -0.4:
			_crash(contact.get_position(), normal)
			return
	var ahead := _clear_run(charge_dir, 1.3)
	if ahead < 1.25 and speed > 4.0:
		var point := global_position + charge_dir * (ahead + 0.0) + Vector3.UP * 1.0
		_crash(point, -charge_dir)
		return
	var moved := _flat(global_position - before).length()
	if brain.stage_time() > 0.25 and moved < speed * delta * 0.25:
		_crash(global_position + charge_dir * 1.2 + Vector3.UP, -charge_dir)
		return
	if run >= _charge_length:
		brain.charge_done()


func _crash(point: Vector3, normal: Vector3) -> void:
	_charge_frame()   # a guard pinned against it is hit
	brain.crash()
	speed = 0.0
	velocity = Vector3.ZERO
	global_position -= charge_dir * 0.15
	_clear_marks(0.3)
	Fx.impact(point, normal, ExhibitMaterial.Kind.MARBLE, 3.5)
	Fx.impact(point, normal, -1, 3.0)
	for i in 7:
		var fling := normal * randf_range(1.5, 4.0) + Vector3(randf_range(-2.0, 2.0), randf_range(1.0, 4.0), randf_range(-2.0, 2.0))
		Fx.chunk(point + Vector3(randf_range(-0.4, 0.4), randf_range(-0.4, 0.8), randf_range(-0.4, 0.4)), Color(0.9, 0.87, 0.8), randf_range(0.08, 0.2), fling)
	Sfx.play_at(&"trex_impact", point, 2.0)
	Sfx.play_at(&"break_marble", point, -2.0)
	_shake_near(0.8, 30.0)
	Fx.hitstop(0.05)
	crashed.emit()


func _skid_frame(delta: float) -> void:
	if speed < 3.0:
		return
	_spark_timer -= delta
	if _spark_timer <= 0.0:
		_spark_timer = 0.06
		for leg in ["hoof_fl", "hoof_fr"]:
			var hoof := rig.part(leg).global_position
			Fx.impact(Vector3(hoof.x, global_position.y + 0.05, hoof.z), Vector3.UP - charge_dir, ExhibitMaterial.Kind.METAL, 0.8)
			Fx.impact(Vector3(hoof.x, global_position.y + 0.05, hoof.z), Vector3.UP, -1, 1.0)


# --- Lapiths, the torn piece -----------------------------------------------------------

func _call_lapiths() -> void:
	var spots := lapith_spots()
	var count := int(CentaurBrain.per_phase(CentaurBrain.LAPITHS, brain.phase))
	var kind := &"hoplite" if ResourceLoader.exists(LAPITH_PATH) else &"knight"
	for i in count:
		var spot: Transform3D = spots[i % spots.size()]
		var lapith := NightSpawner.make(kind)
		lapith.summoned = true
		lapith.starts_awake = true
		lapith.target = target
		lapith.home_room = arena_room
		lapith.dust_value = 1
		lapith.attack_damage *= damage_scale
		var at := spot.origin - spot.basis.z * 0.6 + spot.basis.x * (0.9 * float(i / spots.size()))
		lapith.position = at + Vector3.UP * 0.05
		lapith.rotation.y = spot.basis.get_euler().y
		get_parent().add_child(lapith)
		lapith.global_position = at + Vector3.UP * 0.05
		lapith.reset_physics_interpolation()
		if lapith.brain != null:
			lapith.brain.wake()
		lapiths.append(lapith)
		Fx.impact(at + Vector3.UP * 1.2, -spot.basis.z, ExhibitMaterial.Kind.MARBLE, 2.5)
		Fx.impact(at + Vector3.UP * 0.2, Vector3.UP, -1, 2.5)
		Fx.flash(at + Vector3.UP * 1.5, GOLD, 2.0, 4.0, 0.3)
		Sfx.play_at(&"relief_crack", at + Vector3.UP, -2.0)
	_shake_near(0.3, 30.0)


## Where its Lapiths step out: its arena's lapith points (by the pediment
## groups), else two spots along the gallery either side of its post.
func lapith_spots() -> Array:
	var found: Array = points.get(&"lapith", [])
	if not found.is_empty():
		return found
	var spots: Array = []
	for along in [-12.0, 12.0]:
		spots.append(Transform3D(home.basis, home.origin + home.basis.x * along))
	return spots


func _tear_slab() -> void:
	var slab := rig.part("slab") as MeshInstance3D
	if slab == null:
		return
	var fling := global_basis * Vector3(-4.5, 3.5, randf_range(-1.0, 1.0))
	if slab.mesh != null and slab.is_inside_tree():
		var materials: Array[Material] = []
		for i in slab.mesh.get_surface_count():
			var source := slab.get_active_material(i)
			materials.append(ArtLibrary.debris_material(source) if source != null else null)
		Fx.piece(MeshShards.whole(slab.mesh), materials, slab.global_transform, fling, 4.0)
	Fx.impact(slab.global_position, -global_basis.x, ExhibitMaterial.Kind.MARBLE, 3.0)
	Sfx.play_at(&"lock_wall_crack", slab.global_position, 2.0)
	Sfx.play_at(&"rubble", slab.global_position, -2.0)
	_shake_near(0.3, 15.0)


# --- waking, stun, sounds ---------------------------------------------------------

func _state_frame(delta: float) -> void:
	_chest_light.visible = brain.state == S.STUNNED
	if _chest_light.visible:
		_chest_light.light_energy = 1.6 + 0.6 * sin(moves.time * 7.0)
		_spark_timer -= delta
		if _spark_timer <= 0.0:
			_spark_timer = 0.25
			Fx.impact(rig.part("chest").global_position, Vector3.DOWN, ExhibitMaterial.Kind.MARBLE, 0.6)
	if brain.state != S.WAKING:
		return
	var u := brain.state_progress()
	metope.strain(clampf((u - WAKE_CRACK) / (WAKE_BURST - WAKE_CRACK), 0.0, 1.0) if u < WAKE_BURST else 0.0)
	if not _wake_done.has(&"crack") and u >= WAKE_CRACK:
		_wake_done[&"crack"] = true
		Sfx.play_at(&"relief_crack", metope.global_position + Vector3.UP * 2.0, 2.0)
	if not _wake_done.has(&"burst") and u >= WAKE_BURST:
		_wake_done[&"burst"] = true
		metope.burst(-home.basis.x)
		Sfx.play_at(&"lock_wall_collapse", metope.global_position + Vector3.UP * 2.0, 2.0, 0.0)
		Sfx.play_at(&"relief_scrape", metope.global_position + Vector3.UP, 0.0)
		Fx.flash(metope.global_position + Vector3.UP * 2.0, Color(1.0, 0.86, 0.62), 5.0, 9.0, 0.4)
		_shake_near(0.5, 30.0)
		broke_free.emit()
	if not _wake_done.has(&"land") and u >= WAKE_LAND:
		_wake_done[&"land"] = true
		for leg in ["hoof_fl", "hoof_fr"]:
			Fx.impact(rig.part(leg).global_position, Vector3.UP, -1, 2.5)
		Sfx.play_at(&"lamassu_stomp", global_position, -4.0, 0.1)
		_shake_near(0.35, 25.0)


func _on_touchdown(leg: int) -> void:
	if gait.speed < 4.0 or not is_inside_tree():
		return
	var hoof := rig.part("hoof_" + CentaurGait.NAMES[leg]).global_position
	var at := Vector3(hoof.x, global_position.y + 0.05, hoof.z)
	Fx.impact(at, Vector3.UP, -1, 0.6 + gait.speed * 0.06)
	if gait.speed > 8.5 and (leg == 1 or leg == 2):
		Fx.impact(at, Vector3.UP, ExhibitMaterial.Kind.METAL, 0.45)
	# the floor shakes as it thunders past
	if guard_alive() and target is Player and gait.speed > 7.0:
		var distance := target.global_position.distance_to(global_position)
		if distance < 7.0:
			Events.shake_requested.emit(0.12 * (1.0 - distance / 7.0))


func _sounds(_delta: float) -> void:
	if _gallop.stream == null:
		return
	var running := gait.speed > 3.0 and state == State.FIGHT
	if running and not _gallop.playing:
		_gallop.play()
	elif not running and _gallop.playing:
		_gallop.stop()
	if running:
		_gallop.pitch_scale = clampf(gait.frequency / 2.0, 0.7, 1.5)
		_gallop.volume_db = linear_to_db(clampf(gait.speed / 9.0, 0.25, 1.2))


# --- calm, freeze, fall -------------------------------------------------------------

func _on_reset() -> void:
	brain.reset()
	moves.reset()
	speed = 0.0
	velocity = Vector3.ZERO
	gait.place(global_transform)
	_clear_marks()
	metope.restore()
	for node in lapiths + javelins:
		if is_instance_valid(node):
			node.queue_free()
	lapiths.clear()
	javelins.clear()
	_chest_light.visible = false
	if _gallop.playing:
		_gallop.stop()
	rig.apply(moves.compose(brain, gait, global_transform, 0.0))


func _on_freeze() -> void:
	_clear_marks()
	_chest_light.visible = false
	if _gallop.playing:
		_gallop.stop()
	for node in javelins:
		if is_instance_valid(node):
			node.queue_free()


func _on_defeated(info: DamageInfo) -> void:
	brain.die()
	_clear_marks()
	if _gallop.playing:
		_gallop.stop()
	# the Lapiths it called crumble with it
	for node in lapiths:
		if is_instance_valid(node) and node is Node3D:
			Fx.impact((node as Node3D).global_position + Vector3.UP * 1.0, Vector3.UP, ExhibitMaterial.Kind.MARBLE, 2.5)
			node.queue_free()
	lapiths.clear()
	var fall := CentaurFall.make(self, info)
	get_parent().add_child(fall)


# --- helpers ------------------------------------------------------------------------

func _clear_marks(fade: float = 0.25) -> void:
	for side in 2:
		var mark := _marks[side] as GroundMark
		if mark != null and is_instance_valid(mark):
			mark.vanish(fade)
		_marks[side] = null
	for mark: GroundMark in [_lane, _hoof_mark]:
		if mark != null and is_instance_valid(mark):
			mark.vanish(fade)
	_lane = null
	_hoof_mark = null


## Camera shake for a guard within [param reach] m, fading with distance.
func _shake_near(trauma: float, reach: float) -> void:
	if not guard_alive() or not target is Player:
		return
	var distance := target.global_position.distance_to(global_position)
	if distance < reach:
		Events.shake_requested.emit(trauma * (1.0 - distance / reach))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
