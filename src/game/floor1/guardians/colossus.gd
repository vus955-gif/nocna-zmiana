class_name Colossus
extends Guardian
## Kolos Ramzesa - the Colossus of Ramesses, Egypt's wing guardian (design
## 7.4; plan docs/superpowers/plans/2026-10-03-straznik-kolos.md): a 9 m
## red-granite king seated on his throne at the north end of the Colossus
## hall, among seven papyrus columns. He wakes when the guard steps in -
## the eyes ignite, dust pours off him, the throne grinds as he turns -
## and fights in three phases (ColossusBrain holds every number):
## 1. the HAND SLAM (the palm's shadow grows on the floor, the arm rises
##    over his shoulder, falls; a shockwave rolls out - jump it), the LOW
##    SWEEP (the arm draws back grinding, sweeps the floor before his
##    knees - jump it) and the SUN BEAM from his eyes (a charge, then a
##    line that turns slowly after the guard; columns stop it, and crack);
## 2. (< 66 %) he rears back, the chest plates burst off, the cracks blaze
##    (weak points now); scarab swarms pour out of his throne; the beam
##    turns faster;
## 3. (< 33 %) he STANDS UP off the throne and WALKS after the guard - every
##    footfall a ring to jump - and his beam SWEEPS the hall low.
## Damage counts only through the weak points: the uraeus on his crown
## always, the chest cracks once their plates are off (an explosion breaks
## a plate earlier); anything else sparks off the granite (x0.1).
## His fall: the eyes die, the cracks flare, he topples and breaks into
## stone (ColossusFall); the keeper drops the seal and the shard.
## His arena's props are his script's: dress_arena() raises the throne and
## the breakable columns on Egypt's markers every night.
## Body space: origin on the floor under his (seated) hips, -Z his front.

## Announced (the warning starts) and landed (the damage moment, or the
## start of the active part): slam, sweep, beam, swarm, beam_sweep, stomp.
signal telegraphed(attack: StringName)
signal struck(attack: StringName)
## He is up on his feet (phase 3).
signal stood_up

const A := ColossusBrain.Attack
const S := ColossusBrain.State
const NAMES := {
	ColossusBrain.Attack.SLAM: &"slam", ColossusBrain.Attack.SWEEP: &"sweep", ColossusBrain.Attack.BEAM: &"beam",
	ColossusBrain.Attack.SWARM: &"swarm", ColossusBrain.Attack.BEAM_SWEEP: &"beam_sweep",
}
## Hits outside the weak points count this much.
const ARMOUR := 0.1
## Explosive damage that breaks a chest plate before phase 2.
const PLATE_HEALTH := 40.0
## The beam burns in ticks (s).
const BEAM_TICK := 0.2
## Seated colliders (centre, size), body space: legs and feet, torso.
const SEATED_BOXES := [[Vector3(0.0, 1.95, -2.85), Vector3(2.2, 3.9, 2.2)], [Vector3(0.0, 6.2, 0.0), Vector3(2.9, 5.6, 1.6)]]
## Standing collider (centre, size), body space.
const STANDING_BOX := [Vector3(0.0, 5.3, 0.0), Vector3(2.4, 10.6, 1.6)]
## How far round him an obstacle keeps his feet (m).
const BODY_RADIUS := 1.4
## Seconds of guard positions kept (the beam starts where he was).
const TRAIL := 0.6
## How far ahead he checks for room before a step (m).
const LOOK_AHEAD := 2.4
## Yaw offsets (rad) he tries round an obstacle on his way.
const DETOURS: Array[float] = [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5]
## Turning more than this (rad) on the spot makes him re-plant his feet.
const REPLANT := 0.35
const GOLD := Color(1.0, 0.78, 0.36)

var brain := ColossusBrain.new()
var gait := ColossusGait.new()
var rig: ColossusRig
var moves: ColossusMoves
var throne: ColossusThrone
var beam: SunBeam
## Up on his feet (phase 3, after the stand-up).
var standing := false
## Swarms he poured out that still live.
var swarms: Array[Node] = []

var _look: Node3D
var _zones := {}
var _crack_boxes: Array[Hurtbox] = []
var _plate_health: Array[float] = [PLATE_HEALTH, PLATE_HEALTH, PLATE_HEALTH]
var _seated_shapes: Array[CollisionShape3D] = []
var _standing_shape: CollisionShape3D
var _mark: GroundMark
var _weak_hit := false
var _gold_frame: int = -1
var _slam_world := Vector3.ZERO
var _sweep_prev: float = 0.0
var _sweep_done := false
var _beam_burst: int = 0
var _beam_dir := Vector3.FORWARD
var _beam_next: float = 0.0
var _beam_sweep := Vector3.ZERO
var _beam_swept := false
var _trail: Array = []
var _swarm_side: int = 1
var _stand_done := {}
var _plates_blown := false
var _feet_world: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _feet_yaw: Array[float] = [0.0, 0.0]
var _swing_from := Vector3.ZERO
var _swing_to := Vector3.ZERO
var _walk_yaw: float = 0.0
## The step under way carries him forward (else he re-plants on the spot).
var _stepping_forward := false
var _clear_timer: float = 0.0
var _dust_timer: float = 0.0
var _chest_light: OmniLight3D
## The sun gathering in his eyes (the beam's charge lights the hall).
var _eye_light: OmniLight3D
var _grind_cooldown: float = 0.0
var _heading_timer: float = 0.0


func _init() -> void:
	max_health = 1100.0


## The throne and the seven papyrus columns of his hall (GuardianKeeper,
## every night, also after his fall).
static func dress_arena(level: MuseumFloorLevel, parent: Node3D) -> Array[Node3D]:
	var props: Array[Node3D] = []
	if level.markers.has(&"guardian_colossus"):
		var throne_ := ColossusThrone.make(level.markers[&"guardian_colossus"])
		parent.add_child(throne_)
		props.append(throne_)
	var ids: Array = level.markers.keys().filter(func(id: StringName) -> bool: return String(id).begins_with("colossus_column_"))
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a).naturalnocasecmp_to(String(b)) < 0)
	for id: StringName in ids:
		var column := ColossusColumn.make(level.markers[id])
		column.name = "Column_" + String(id).trim_prefix("colossus_column_")
		parent.add_child(column)
		props.append(column)
	return props


# --- body -------------------------------------------------------------------

func _build_body() -> void:
	_look = Node3D.new()
	_look.name = "Look"
	add_child(_look)
	rig = ColossusRig.create(_look)
	moves = ColossusMoves.new(rig)
	for box: Array in SEATED_BOXES:
		_seated_shapes.append(_box_collider(box[0], box[1]))
	_standing_shape = _box_collider(STANDING_BOX[0], STANDING_BOX[1])
	_standing_shape.disabled = true
	_build_zones()
	beam = SunBeam.new()
	add_child(beam)
	_chest_light = OmniLight3D.new()
	_chest_light.light_color = GOLD
	_chest_light.omni_range = 8.0
	_chest_light.light_energy = 0.0
	_chest_light.visible = false
	rig.part("torso").add_child(_chest_light)
	_chest_light.position = Vector3(0.0, 0.6, -1.0)
	_eye_light = OmniLight3D.new()
	_eye_light.light_color = GOLD
	_eye_light.omni_range = 12.0
	_eye_light.light_energy = 0.0
	_eye_light.visible = false
	rig.part("head").add_child(_eye_light)
	_eye_light.position = Vector3(0.0, 0.79, -1.3)
	_find_throne()
	brain.telegraphed.connect(_on_telegraphed)
	brain.struck.connect(_on_struck)
	brain.finished.connect(_on_finished)
	brain.state_changed.connect(_on_state_changed)
	gait.lifted.connect(_on_foot_lifted)
	gait.planted.connect(_on_foot_planted)
	rig.apply(moves.compose(brain, 0.0))


func _box_collider(center: Vector3, size: Vector3) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = center
	add_child(collider)
	return collider


## Hit zones on the parts (they move with him): the granite (armour), the
## uraeus (weak), and over each crack its plate (armour that an explosion
## can break) - the crack's zone once the plate is gone.
func _build_zones() -> void:
	var body := _zone(&"body")
	for view in rig.meshes:
		var key := String(view.name)
		if key in ["eyes", "uraeus"] or key.begins_with("chest_plate") or key.begins_with("crack_"):
			continue
		var box := view.get_aabb()
		var shape := BoxShape3D.new()
		shape.size = box.size.max(Vector3.ONE * 0.2)
		view.add_child(Hurtbox.make(body, shape, box.get_center()))
	# the uraeus: a little larger than the cobra and standing proud of the
	# brow, so a shot from the front finds it before the crown
	var uraeus := rig.part("uraeus")
	var cobra := BoxShape3D.new()
	cobra.size = Vector3(0.42, 0.8, 0.5)
	uraeus.add_child(Hurtbox.make(_zone(&"uraeus"), cobra, Vector3(0.0, 0.14, -0.08), true))
	var torso := rig.part("torso")
	for i in 3:
		var plate := rig.part("chest_plate_%d" % (i + 1))
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.62, 0.56, 0.42)
		var zone := _zone(StringName("plate_%d" % (i + 1)))
		var hurtbox := Hurtbox.make(zone, shape, plate.position + Vector3(0.0, 0.0, -0.1))
		torso.add_child(hurtbox)
		_crack_boxes.append(hurtbox)


func _zone(zone_name: StringName) -> GuardianZone:
	var zone := GuardianZone.make(self, zone_name)
	add_child(zone)
	_zones[zone_name] = zone
	return zone


## The throne the keeper raised at his post, or one of his own (a dev
## arena, a test): he is excepted from colliding with it while seated.
func _find_throne() -> void:
	for node in get_tree().get_nodes_in_group(ColossusThrone.GROUP):
		var candidate := node as ColossusThrone
		if candidate != null and candidate.global_position.distance_to(global_position) < 1.0:
			throne = candidate
	if throne == null:
		throne = ColossusThrone.make(global_transform)
		throne.top_level = true
		add_child(throne)
		throne.global_transform = global_transform
	add_collision_exception_with(throne.body)


# --- damage -------------------------------------------------------------------

func take_zone_damage(info: DamageInfo, zone: StringName) -> void:
	if info == null:
		return
	var weak := zone == &"uraeus" or String(zone).begins_with("crack_")
	if String(zone).begins_with("plate_") and _explosive(info) and state != State.DEFEATED:
		var index := int(String(zone).trim_prefix("plate_"))
		_plate_health[index - 1] -= info.amount
		if _plate_health[index - 1] <= 0.0:
			_break_plate(index, info.direction)
	info.weak_point = weak
	info.blocked = not weak
	_weak_hit = weak
	super(info, zone)
	_weak_hit = false


func _damage_factor(_info: DamageInfo) -> float:
	return 1.0 if _weak_hit else ARMOUR


func _hit_effects(info: DamageInfo) -> void:
	if info.weak_point:
		Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.MARBLE, clampf(info.amount / 12.0, 0.8, 3.0))
		Fx.flash(info.position, GOLD, 2.5, 3.0, 0.08)
		Sfx.play_at(&"hit_marble", info.position, 1.0)
		rig.flash(0.5)
	else:
		# the granite shrugs it off: sparks, a little dust
		Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.METAL, 0.8)
		Fx.impact(info.position, info.normal, -1, 0.6)
		Sfx.play_at(&"hit_marble", info.position, -6.0, 0.25)


## One blast can strike granite and a weak point at once: the grey marker
## must not paint over the gold one.
func _report_hit(info: DamageInfo) -> void:
	var frame := Engine.get_physics_frames()
	if info.weak_point:
		_gold_frame = frame
	elif _gold_frame == frame:
		return
	Events.hit_landed.emit(self, info, false)


static func _explosive(info: DamageInfo) -> bool:
	return GreyLock.is_blast(info) or (info.kind == DamageInfo.Kind.FIRE and not info.periodic)


## Plate [param index] breaks off (an explosion, or phase 2): its crack is
## a weak point from now on.
func _break_plate(index: int, push: Vector3) -> void:
	var fling := global_basis * Vector3(randf_range(-0.6, 0.6), 1.2, -2.2) + push * 1.5
	if not rig.detach_plate(index, fling):
		return
	var zone: GuardianZone = _zones.get(StringName("plate_%d" % index))
	if zone != null:
		zone.zone = StringName("crack_%d" % index)
	_crack_boxes[index - 1].weak_point = true
	var at := rig.part("crack_%d" % index).global_position
	Fx.impact(at, -global_basis.z, ExhibitMaterial.Kind.MARBLE, 3.0)
	Fx.flash(at - global_basis.z * 0.5, GOLD, 5.0, 6.0, 0.35)
	Sfx.play_at(&"lock_wall_crack", at, 0.0)


func reward_point() -> Vector3:
	return global_position if standing else to_global(Vector3(0.0, 0.0, -5.5))


# --- the fight ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	super(delta)
	if state == State.FIGHT and not guard_alive() and beam.is_burning():
		beam.hide_beam()   # the guard fell: the fight stands still
		_clear_mark()


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
	_remember_guard(delta)
	_clear_timer -= delta
	if _clear_timer <= 0.0:
		_clear_timer = 0.2
		brain.slam_clear = _arm_reaches(guard)
	brain.swarms_alive = alive_swarms()
	brain.update(delta, distance, bearing)
	velocity.x = 0.0
	velocity.z = 0.0
	if standing:
		_walk(delta, distance, bearing)
	moves.guard = to_local(guard + Vector3.UP * 1.3)
	if brain.state != S.ATTACK:
		moves.beam_point = moves.guard
	var pose := moves.compose(brain, delta)
	rig.apply(pose, delta)
	_eye_light.visible = pose.charge > 0.05
	_eye_light.light_energy = 3.5 * pose.charge
	# the stone grinds on the throne as he turns
	_grind_cooldown -= delta
	if moves.twist_speed() > 0.22 and _grind_cooldown <= 0.0 and not standing:
		_grind_cooldown = 1.6
		Sfx.play_at(&"colossus_grind", rig.part("torso").global_position, -9.0, 0.15)
	_attack_frame(delta)
	_state_frame(delta)


## Swarms he poured out that still live.
func alive_swarms() -> int:
	if swarms.is_empty():
		return 0
	var alive: Array[Node] = []
	for node in swarms:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			alive.append(node)
	swarms = alive
	return swarms.size()


func _on_telegraphed(attack: A) -> void:
	var local := to_local(target.global_position) if guard_alive() else Vector3(0.0, 0.0, -8.0)
	var bearing := atan2(-local.x, -local.z)
	_clear_mark()
	match attack:
		A.SLAM:
			moves.side = ColossusBrain.arm_for(bearing)
			var flat := Vector2(local.x, local.z)
			var reach := clampf(flat.length(), ColossusBrain.SLAM_RANGE.x, ColossusBrain.SLAM_RANGE.y)
			var point := flat.normalized() * reach if flat.length() > 0.01 else Vector2(0.0, -reach)
			moves.slam_point = Vector3(point.x, 0.0, point.y)
			_slam_world = to_global(moves.slam_point)
			_slam_world.y = global_position.y
			_mark = GroundMark.disc(ColossusBrain.SLAM_RADIUS, 1.15)
			_place_mark(Transform3D(Basis.looking_at(_flat(_slam_world - global_position), Vector3.UP), _slam_world))
			Sfx.play_at(&"colossus_grind", rig.part("upperarm_" + ("l" if moves.side > 0 else "r")).global_position, -2.0)
		A.SWEEP:
			moves.side = ColossusBrain.arm_for(bearing)
			_sweep_done = false
			_sweep_prev = ColossusBrain.SWEEP_FROM * moves.side
			_mark = GroundMark.arc(ColossusBrain.SWEEP_RANGE.x, ColossusBrain.SWEEP_RANGE.y,
					ColossusBrain.SWEEP_FROM * moves.side, ColossusBrain.SWEEP_TO * moves.side)
			_place_mark(Transform3D(global_basis.orthonormalized(), Vector3(global_position.x, global_position.y, global_position.z)))
			Sfx.play_at(&"colossus_grind", global_position + Vector3.UP * 4.0, 1.0)
		A.BEAM:
			Sfx.play_at(&"colossus_charge", rig.eyes_point(), 2.0, 0.02)
		A.BEAM_SWEEP:
			_plan_beam_sweep(local)
			Sfx.play_at(&"colossus_charge", rig.eyes_point(), 2.0, 0.02)
		A.SWARM:
			_swarm_side = 1 if bearing >= 0.0 else -1
			moves.swarm_point = to_local(throne.opening(_swarm_side))
			Sfx.play_at(&"colossus_grind", throne.opening(_swarm_side), -6.0)
	telegraphed.emit(NAMES[attack])


func _on_struck(attack: A) -> void:
	match attack:
		A.SLAM:
			_slam_lands()
		A.SWEEP:
			Sfx.play_at(&"tail_whoosh", global_position + Vector3.UP * 1.0 - global_basis.z * 5.0, 2.0)
			_clear_mark(0.5)
		A.BEAM:
			_beam_burst += 1
			_beam_next = 0.0
			var eyes := rig.eyes_point()
			_beam_dir = (_guard_before(ColossusBrain.BEAM_LEAD) - eyes).normalized()
			Sfx.play_at(&"colossus_beam", eyes, 3.0, 0.02)
		A.BEAM_SWEEP:
			_beam_burst += 1
			_beam_swept = false
			_beam_next = 0.0
			_clear_mark(0.6)
			Sfx.play_at(&"colossus_beam", rig.eyes_point(), 3.0, 0.02)
		A.SWARM:
			_pour_swarm()
	struck.emit(NAMES[attack])


func _on_finished(_attack: A) -> void:
	beam.hide_beam()
	_clear_mark()
	throne.vent(1, 0.0)
	throne.vent(-1, 0.0)


func _on_state_changed(from: S, to: S) -> void:
	match to:
		S.WAKING:
			Sfx.play_at(&"colossus_grind", global_position + Vector3.UP * 5.0, 3.0, 0.02)
			_dust_off(1.0)
			_shake_near(0.25, 30.0)
		S.PHASE_SHIFT:
			_plates_blown = false
			Sfx.play_at(&"colossus_grind", global_position + Vector3.UP * 5.0, 3.0, 0.02)
			Sfx.play_at(&"guardian_wake", global_position + Vector3.UP * 5.0, -2.0)
		S.STAND_UP:
			_stand_done.clear()
			Sfx.play_at(&"colossus_grind", global_position + Vector3.UP * 3.0, 4.0, 0.0)
			_shake_near(0.3, 35.0)
	if from == S.STAND_UP and brain.standing and not standing:
		_finish_stand_up()


## Effects that run through an attack: the warning marks, the sweep, the
## beam.
func _attack_frame(delta: float) -> void:
	if brain.state != S.ATTACK:
		return
	if brain.stage == ColossusBrain.Stage.TELEGRAPH and _mark != null:
		_mark.progress = brain.stage_time() / ColossusBrain.stage_length(brain.attack, brain.stage, brain.phase)
	match brain.attack:
		A.SWEEP:
			if brain.stage == ColossusBrain.Stage.STRIKE:
				_sweep_frame()
		A.BEAM:
			if brain.stage == ColossusBrain.Stage.STRIKE:
				_beam_frame(delta)
			elif brain.stage == ColossusBrain.Stage.TELEGRAPH:
				moves.beam_point = moves.guard   # the head locks on while it charges
		A.BEAM_SWEEP:
			if brain.stage == ColossusBrain.Stage.STRIKE:
				_beam_sweep_frame(delta)
			elif brain.stage == ColossusBrain.Stage.TELEGRAPH:
				moves.beam_point = to_local(_beam_sweep_point(0.0))
		A.SWARM:
			if brain.stage == ColossusBrain.Stage.TELEGRAPH:
				throne.vent(_swarm_side, brain.stage_time() / ColossusBrain.stage_length(A.SWARM, brain.stage, brain.phase))


## Phase shift and stand-up moments.
func _state_frame(delta: float) -> void:
	_chest_light.visible = brain.phase >= 2 and not rig.plates_on.has(true)
	if _chest_light.visible:
		_chest_light.light_energy = 1.2 + 0.3 * sin(moves.time * 2.3)
	match brain.state:
		S.WAKING:
			# dust of the centuries pours off him as he stirs
			_dust_timer -= delta
			if brain.state_progress() < 0.6 and _dust_timer <= 0.0:
				_dust_timer = 0.15
				_dust_off(0.5)
		S.PHASE_SHIFT:
			if not _plates_blown and brain.state_progress() >= ColossusMoves.PLATES_AT:
				_plates_blown = true
				for i in 3:
					_break_plate(i + 1, Vector3.ZERO)
				Sfx.play_at(&"rubble", rig.part("torso").global_position, 2.0)
				Fx.flash(rig.part("torso").global_position - global_basis.z * 1.5, GOLD, 9.0, 14.0, 0.6)
				_shake_near(0.45, 35.0)
		S.STAND_UP:
			_stand_up_frame(delta)


# --- the slam -------------------------------------------------------------------

func _slam_lands() -> void:
	var at := _slam_world
	moves.impact()
	_clear_mark(0.15)
	Sfx.play_at(&"colossus_slam", at + Vector3.UP, 4.0, 0.04)
	Fx.impact(at + Vector3.UP * 0.2, Vector3.UP, ExhibitMaterial.Kind.MARBLE, 4.0)
	Fx.impact(at + Vector3.UP * 0.1, Vector3.UP, -1, 4.0)
	Fx.flash(at + Vector3.UP * 1.5, GOLD, 4.0, 9.0, 0.25)
	for i in 8:
		var fling := Vector3(randf_range(-1.0, 1.0), randf_range(0.6, 1.4), randf_range(-1.0, 1.0)).normalized() * randf_range(3.0, 6.0)
		Fx.chunk(at + Vector3.UP * 0.3, Color(0.3, 0.29, 0.3), randf_range(0.08, 0.2), fling)
	_shake_near(0.6, 32.0)
	var ring := ShockwaveRing.make(at, ColossusBrain.SLAM_RING.y, ColossusBrain.SLAM_RING.z, ColossusBrain.SLAM_RING.x * damage_scale, self, ColossusBrain.SLAM_RADIUS * 0.8)
	ring.target = target
	get_parent().add_child(ring)
	if not guard_alive():
		return
	if _under_palm(at):
		ring.target = null   # the palm itself hit him: the wave does not again
		var info := DamageInfo.make(ColossusBrain.SLAM_DAMAGE * damage_scale, DamageInfo.Kind.BLUNT, self)
		var out := _flat(target.global_position - at)
		info.direction = out.normalized() if out.length() > 0.1 else -global_basis.z
		info.knockback = ColossusBrain.SLAM_KNOCKBACK
		info.position = target.global_position
		target.call(&"take_damage", info)


## True when the guard stands under the palm coming down at [param at]: in
## its shadow's ellipse (plus his body).
func _under_palm(at: Vector3) -> bool:
	var flat := _flat(at - global_position)
	var along := flat.normalized() if flat.length() > 0.01 else -global_basis.z
	var off := target.global_position - at
	var forward := off.dot(along)
	var across := off.dot(Vector3.UP.cross(along))
	var rx := ColossusBrain.SLAM_RADIUS + ShockwaveRing.GUARD_RADIUS
	var rz := ColossusBrain.SLAM_RADIUS * 1.15 + ShockwaveRing.GUARD_RADIUS
	return (across / rx) * (across / rx) + (forward / rz) * (forward / rz) <= 1.0 and absf(off.y) < 1.6


## True when nothing (a column, the throne) stands between his shoulder and
## the guard: a slam could come down on him.
func _arm_reaches(guard: Vector3) -> bool:
	if not is_inside_tree():
		return true
	var shoulder := to_global(Vector3(0.0, 7.4 if standing else 5.6, 0.0))
	var query := PhysicsRayQueryParameters3D.create(shoulder, guard + Vector3.UP * 0.4, Layers.WORLD)
	query.exclude = [throne.body.get_rid()] if not standing else []
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# --- the sweep ------------------------------------------------------------------

func _sweep_frame() -> void:
	var now := moves.sweep_bearing
	var before := _sweep_prev
	_sweep_prev = now
	if moves.sweep_low:
		var hand := rig.part("hand_l" if moves.side > 0 else "hand_r").global_position
		if fmod(moves.time, 0.08) < 1.0 / 60.0:
			Fx.impact(Vector3(hand.x, global_position.y + 0.1, hand.z), Vector3.UP, -1, 1.5)
	if _sweep_done or not moves.sweep_low or not guard_alive():
		return
	var local := to_local(target.global_position)
	var distance := Vector2(local.x, local.z).length()
	if distance < ColossusBrain.SWEEP_RANGE.x - ShockwaveRing.GUARD_RADIUS or distance > ColossusBrain.SWEEP_RANGE.y + 0.6:
		return
	var bearing := atan2(-local.x, -local.z)
	var margin := atan2(ShockwaveRing.GUARD_RADIUS + 0.3, maxf(distance, 1.0))
	if bearing < minf(before, now) - margin or bearing > maxf(before, now) + margin:
		return
	if target.global_position.y - global_position.y > ColossusBrain.CLEAR_HEIGHT:
		return   # he jumped it
	_sweep_done = true
	var info := DamageInfo.make(ColossusBrain.SWEEP_DAMAGE * damage_scale, DamageInfo.Kind.BLUNT, self)
	var swing := signf(now - before)
	# pushed along the sweep (its tangent)
	var tangent := Vector3(-cos(bearing), 0.0, sin(bearing)) * swing
	info.direction = (global_basis * tangent).normalized()
	info.knockback = ColossusBrain.SWEEP_KNOCKBACK
	info.position = target.global_position
	target.call(&"take_damage", info)
	Sfx.play_at(&"punch_hit", target.global_position, 2.0)
	_shake_near(0.4, 8.0)


# --- the beam -------------------------------------------------------------------

func _beam_frame(delta: float) -> void:
	var eyes := rig.eyes_point()
	if guard_alive():
		var wanted := (target.global_position + Vector3.UP * 1.2 - eyes).normalized()
		var angle := _beam_dir.angle_to(wanted)
		var turn: float = ColossusBrain.BEAM_TRACK[clampi(brain.phase - 1, 0, 2)] * delta
		if angle > 0.0001:
			_beam_dir = _beam_dir.slerp(wanted, minf(1.0, turn / angle)).normalized()
	var hit := beam.fire(eyes, eyes + _beam_dir * 10.0, delta)
	moves.beam_point = to_local(eyes + _beam_dir * 12.0)
	_burn(eyes, hit, delta, false)


## Phase 3: the arc's ends round the guard, its radius at his distance.
func _plan_beam_sweep(local: Vector3) -> void:
	var flat := Vector2(local.x, local.z)
	var radius := clampf(flat.length(), 6.0, 18.0)
	var center := atan2(-local.x, -local.z)
	var turn := 1.0 if randf() < 0.5 else -1.0
	_beam_sweep = Vector3(center - turn * ColossusBrain.BEAM_SWEEP_ARC * 0.5, center + turn * ColossusBrain.BEAM_SWEEP_ARC * 0.5, radius)
	# the band it will burn: from where the beam comes down to the head
	# height to where it meets the floor
	var eye_height := rig.eyes_point().y - global_position.y
	var inner := radius * (1.0 - 1.9 / maxf(eye_height, 2.0))
	_mark = GroundMark.arc(maxf(inner, 2.0), radius + 0.6, _beam_sweep.x, _beam_sweep.y)
	_place_mark(Transform3D(global_basis.orthonormalized(), global_position))


func _beam_sweep_point(progress: float) -> Vector3:
	var bearing := lerpf(_beam_sweep.x, _beam_sweep.y, progress)
	return to_global(Vector3(-sin(bearing) * _beam_sweep.z, 0.1, -cos(bearing) * _beam_sweep.z))


func _beam_sweep_frame(delta: float) -> void:
	var progress := brain.stage_time() / ColossusBrain.stage_length(A.BEAM_SWEEP, brain.stage, brain.phase)
	var eyes := rig.eyes_point()
	var point := _beam_sweep_point(clampf(progress, 0.0, 1.0))
	var hit := beam.fire(eyes, point, delta)
	moves.beam_point = to_local(point)
	_burn(eyes, hit, delta, true)


## The beam's end: a column takes a hit (once a firing), the guard burns
## where it passes him (in ticks; the sweep once).
func _burn(eyes: Vector3, hit: Dictionary, delta: float, once: bool) -> void:
	var collider: Object = hit["collider"]
	var end: Vector3 = hit["end"]
	if collider is ColossusColumn:
		(collider as ColossusColumn).beam_hit(_beam_burst, end)
	_beam_next -= delta
	if not guard_alive() or (once and _beam_swept):
		return
	if not SunBeam.segment_hits_capsule(eyes, end, target.global_position, 1.8):
		return
	if _beam_next > 0.0:
		return
	_beam_next = BEAM_TICK
	var amount := ColossusBrain.BEAM_SWEEP_DAMAGE if once else ColossusBrain.BEAM_DPS * BEAM_TICK
	_beam_swept = once
	var info := DamageInfo.make(amount * damage_scale, DamageInfo.Kind.FIRE, self)
	info.direction = (target.global_position - eyes).normalized()
	info.knockback = 2.0 if once else 0.0
	info.position = target.global_position + Vector3.UP * 1.2
	target.call(&"take_damage", info)


## Where the guard stood [param seconds] ago (the beam starts there).
func _guard_before(seconds: float) -> Vector3:
	var now := target.global_position + Vector3.UP * 1.2 if guard_alive() else to_global(Vector3(0.0, 1.2, -10.0))
	if _trail.is_empty():
		return now
	var wanted := moves.time - seconds
	for entry: Array in _trail:
		if float(entry[0]) >= wanted:
			return entry[1]
	return now


func _remember_guard(_delta: float) -> void:
	if not guard_alive():
		return
	_trail.append([moves.time, target.global_position + Vector3.UP * 1.2])
	while not _trail.is_empty() and float(_trail[0][0]) < moves.time - TRAIL:
		_trail.pop_front()


# --- swarms ---------------------------------------------------------------------

func _pour_swarm() -> void:
	var at := throne.opening(_swarm_side)
	throne.vent(_swarm_side, 1.0)
	var swarm := ScarabSwarm.new()
	swarm.summoned = true
	swarm.starts_awake = true
	swarm.target = target
	swarm.home_room = arena_room
	swarm.attack_damage *= damage_scale
	swarm.position = at
	get_parent().add_child(swarm)
	swarm.global_position = at
	swarm.reset_physics_interpolation()
	swarms.append(swarm)
	Fx.impact(at, Vector3.UP, -1, 3.0)
	Sfx.play_at(&"rubble", at, -6.0)


# --- standing up ------------------------------------------------------------------

func _stand_up_frame(_delta: float) -> void:
	var seconds := brain.state_time()
	if not _stand_done.has(&"crack") and seconds >= ColossusMoves.STAND_CRACK:
		_stand_done[&"crack"] = true
		throne.crack(1.5)
		Sfx.play_at(&"lock_wall_crack", throne.global_position + Vector3.UP * 3.0, 3.0)
		_shake_near(0.35, 35.0)
	for i in ColossusMoves.STAND_STOMPS.size():
		var key := StringName("stomp_%d" % i)
		if not _stand_done.has(key) and seconds >= ColossusMoves.STAND_STOMPS[i]:
			_stand_done[key] = true
			var foot := to_global(ColossusMoves.STAND_FEET[i])
			foot.y = global_position.y
			_stomp_effects(foot, 0.55)
			_shove_from(foot, 2.4)
	# the dust of centuries pours off him as he unfolds
	_dust_timer -= _delta
	if seconds > 0.8 and seconds < 3.2 and _dust_timer <= 0.0:
		_dust_timer = 0.12
		for name in ["thigh_l", "thigh_r", "upperarm_l", "upperarm_r", "torso"]:
			var part := rig.part(name).global_position + Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(-0.5, 0.5))
			Fx.impact(part, Vector3.DOWN, -1, 1.2)


## On his feet: his origin moves under his hips, the standing collider takes
## over, the feet are planted where they stand, and he may bump the throne.
func _finish_stand_up() -> void:
	standing = true
	var shift := global_basis * Vector3(ColossusMoves.STAND_PELVIS.x, 0.0, ColossusMoves.STAND_PELVIS.z)
	global_position += shift
	reset_physics_interpolation()
	for i in 2:
		var local := ColossusMoves.STAND_FEET[i] - Vector3(ColossusMoves.STAND_PELVIS.x, 0.0, ColossusMoves.STAND_PELVIS.z)
		local.y = ColossusRig.ANKLE_HEIGHT
		moves.feet[i] = local
		_feet_world[i] = to_global(local)
		_feet_yaw[i] = rotation.y
	_walk_yaw = rotation.y
	for shape in _seated_shapes:
		shape.disabled = true
	_standing_shape.disabled = false
	# (still excepted from the throne: his steps keep clear of it themselves)
	gait.reset()
	_shove_from(global_position, 2.2)
	rig.apply(moves.compose(brain, 0.0))
	stood_up.emit()


# --- walking ------------------------------------------------------------------

func _walk(delta: float, distance: float, bearing: float) -> void:
	var idle := brain.state == S.IDLE
	_heading_timer -= delta
	if idle and guard_alive():
		if _heading_timer <= 0.0:
			_heading_timer = 0.25
			_walk_yaw = _heading(rotation.y + bearing)
		rotation.y = rotate_toward(rotation.y, _walk_yaw, ColossusBrain.TURN_SPEED * delta)
	var aligned := absf(wrapf(_walk_yaw - rotation.y, -PI, PI)) < 0.45
	var feet_yaw := _feet_yaw[0] + wrapf(_feet_yaw[1] - _feet_yaw[0], -PI, PI) * 0.5
	var replant := absf(wrapf(rotation.y - feet_yaw, -PI, PI)) > REPLANT
	var wants := brain.wants_to_walk(distance) and aligned and _room_ahead(rotation.y)
	var moved := gait.update(delta, idle and (wants or replant))
	if moved > 0.0 and _stepping_forward:
		var forward := -global_basis.z
		velocity.x = forward.x * moved / delta
		velocity.z = forward.z * moved / delta
	moves.swing_foot = gait.foot if gait.swinging() else -1
	moves.swing = gait.swing_progress()
	if gait.swinging():
		var foot := gait.foot
		_feet_world[foot] = _swing_from.lerp(_swing_to, MotionClip.eased(MotionClip.IN_OUT, gait.swing_progress()))
	for i in 2:
		var local := to_local(_feet_world[i])
		local.y = ColossusRig.ANKLE_HEIGHT
		moves.feet[i] = local
	for i in 2:
		moves.feet_yaw[i] = wrapf(_feet_yaw[i] - rotation.y, -PI, PI)


func _on_foot_lifted(foot: int) -> void:
	_stepping_forward = brain.wants_to_walk(_guard_distance()) and _room_ahead(rotation.y)
	var forward := -global_basis.z
	var right := global_basis.x
	var ahead := ColossusGait.STEP_LENGTH * 1.5 if _stepping_forward else 0.0
	_swing_from = _feet_world[foot]
	_swing_to = global_position + forward * ahead + right * (0.55 if foot == 1 else -0.55)
	_swing_to.y = global_position.y + ColossusRig.ANKLE_HEIGHT
	_feet_yaw[foot] = rotation.y
	telegraphed.emit(&"stomp")
	Sfx.play_at(&"colossus_grind", _swing_from, -10.0, 0.2)


func _on_foot_planted(foot: int) -> void:
	_feet_world[foot] = _swing_to
	var at := Vector3(_swing_to.x, global_position.y, _swing_to.z)
	_stomp_effects(at, 0.4)
	moves.footfall()
	var ring := ShockwaveRing.make(at, ColossusBrain.STOMP_RING.y, ColossusBrain.STOMP_RING.z, ColossusBrain.STOMP_RING.x * damage_scale, self, 1.0)
	ring.target = target
	get_parent().add_child(ring)
	struck.emit(&"stomp")


func _stomp_effects(at: Vector3, trauma: float) -> void:
	Sfx.play_at(&"colossus_slam", at + Vector3.UP * 0.5, -2.0, 0.08)
	Fx.impact(at + Vector3.UP * 0.15, Vector3.UP, -1, 3.5)
	Fx.impact(at + Vector3.UP * 0.15, Vector3.UP, ExhibitMaterial.Kind.MARBLE, 2.0)
	_shake_near(trauma, 30.0)


func _guard_distance() -> float:
	if not guard_alive():
		return INF
	var local := to_local(target.global_position)
	return Vector2(local.x, local.z).length()


## The way he walks: toward [param wanted] (world yaw), or round what
## stands in the way.
func _heading(wanted: float) -> float:
	for offset in DETOURS:
		if _room_ahead(wanted + offset):
			return wanted + offset
	return wanted


## True when a step toward [param yaw] stays in his hall, clear of the
## throne and the columns (stumps too).
func _room_ahead(yaw: float) -> bool:
	var direction := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var next := global_position + direction * LOOK_AHEAD
	if arena_room != &"" and room_of.is_valid():
		for probe: Vector3 in [next, next + direction * BODY_RADIUS, next + direction.cross(Vector3.UP) * BODY_RADIUS, next - direction.cross(Vector3.UP) * BODY_RADIUS]:
			if room_of.call(probe + Vector3.UP * 0.5) != arena_room:
				return false
	if throne != null and _flat(throne.global_position - next).length() < 3.6:
		return false
	for node in get_tree().get_nodes_in_group(ColossusColumn.GROUP):
		var column := node as Node3D
		if _flat(column.global_position - next).length() < ColossusColumn.RADIUS + BODY_RADIUS + 0.3:
			return false
	return true


# --- calm, freeze, fall -------------------------------------------------------------

func _on_reset() -> void:
	brain.reset()
	moves.reset()
	gait.reset()
	standing = false
	_stepping_forward = false
	rig.restore_plates()
	for i in 3:
		_plate_health[i] = PLATE_HEALTH
		var zone: GuardianZone = _zones.get(StringName("plate_%d" % (i + 1)))
		if zone == null:
			zone = _zones.get(StringName("crack_%d" % (i + 1)))
		if zone != null:
			zone.zone = StringName("plate_%d" % (i + 1))
		_crack_boxes[i].weak_point = false
	for shape in _seated_shapes:
		shape.disabled = false
	_standing_shape.disabled = true
	beam.hide_beam()
	_clear_mark()
	throne.vent(1, 0.0)
	throne.vent(-1, 0.0)
	for node in swarms:
		if is_instance_valid(node):
			node.queue_free()
	swarms.clear()
	_chest_light.visible = false
	_eye_light.visible = false
	rig.apply(moves.compose(brain, 0.0))


func _on_freeze() -> void:
	beam.hide_beam()
	_clear_mark()
	if throne != null:
		throne.vent(1, 0.0)
		throne.vent(-1, 0.0)
	_chest_light.visible = false
	_eye_light.visible = false
	for view in rig.seams[0] + rig.seams[1]:
		(view as Node3D).visible = false


func _on_defeated(info: DamageInfo) -> void:
	brain.die()
	beam.hide_beam()
	_clear_mark()
	throne.vent(1, 0.0)
	throne.vent(-1, 0.0)
	for node in swarms:
		if is_instance_valid(node) and node is Node3D:
			Fx.impact((node as Node3D).global_position + Vector3.UP * 0.8, Vector3.UP, ExhibitMaterial.Kind.TAXIDERMY, 2.0)
			node.queue_free()
	swarms.clear()
	var fall := ColossusFall.make(self, info)
	get_parent().add_child(fall)


# --- helpers ------------------------------------------------------------------------

func _place_mark(at: Transform3D) -> void:
	get_parent().add_child(_mark)
	_mark.global_transform = at


func _clear_mark(fade: float = 0.25) -> void:
	if _mark != null and is_instance_valid(_mark):
		_mark.vanish(fade)
	_mark = null


## Dust shaken off his shoulders and crown.
func _dust_off(strength: float) -> void:
	for name in ["head", "upperarm_l", "upperarm_r", "torso"]:
		var node := rig.part(name)
		if node != null:
			Fx.impact(node.global_position + Vector3.UP * 0.8, Vector3.DOWN, -1, 2.5 * strength)


## Pushes the guard away from [param at] when he stands within
## [param radius] (a foot coming down beside him).
func _shove_from(at: Vector3, radius: float) -> void:
	if not guard_alive() or not target is CharacterBody3D:
		return
	var off := _flat(target.global_position - at)
	if off.length() > radius:
		return
	var away := off.normalized() if off.length() > 0.05 else -global_basis.z
	(target as CharacterBody3D).velocity += away * 9.0 + Vector3.UP * 3.0


## Camera shake for a guard within [param reach] m, fading with distance.
func _shake_near(trauma: float, reach: float) -> void:
	if not guard_alive() or not target is Player:
		return
	var distance := target.global_position.distance_to(global_position)
	if distance < reach:
		Events.shake_requested.emit(trauma * (1.0 - distance / reach))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
