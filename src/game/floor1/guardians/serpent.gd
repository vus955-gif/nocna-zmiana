class_name Serpent
extends Guardian
## Dwugłowy Wąż - the Two-headed Serpent, the Americas' wing guardian
## (design 7.4; plan docs/superpowers/plans/2026-10-03-straznik-waz.md): a
## 34 m serpent of turquoise mosaic on a carved wooden core, a head at
## each end, asleep coiled on the lower terrace of the Temple of the
## Serpent round the altar's terrace, both heads lying on the upper steps
## of the north flight watching the door. The guard steps in: its eyes
## light, its plates rattle, the heads rise, and it pours down the flight
## and off round its tracks (SerpentCourse: the floor between the fire
## bowls and the terrace, the terraces, the flights, the summit through
## the moon's shaft) - a long body that follows its leading head through
## the same points (SerpentBody), weaving, following the ground, bridging
## the flights it crosses. It fights with both ends (SerpentBrain holds
## every number):
## - the GLOWING HEAD SPITS turquoise at a distance: it rears, its mouth
##   glows, marks spread on the floor round where the guard will be; the
##   shards come down on them in an arc and burst (SerpentShard);
## - the OTHER HEAD BITES up close: it draws back in an S and hisses, a
##   lane on the floor shows the lunge; it shoots out low to its neck's
##   reach (the body sliding after it), then hangs out spent - its weak
##   point counting half again;
## - the TAIL SWEEPS whoever stands by it: the plates rattle, an arc on the
##   floor, the tail winds up the other way and comes round; jump it;
## - the guard keeping to its tail makes it turn round and lead with the
##   other head.
## Phase 2 (< 66 %): the heads turn to each other and the light runs down
## the body: the roles swap; it glides faster. Phase 3 (< 33 %): it slides
## onto the ring round the altar's terrace and closes it but for the gate
## over the north flight, where both heads rise and fight; arches travel
## round the ring - the body is jumped where it lies low, or the fight goes
## on from the summit.
## Damage: the heads are the weak points (the weapons' multiplier; the
## biting head x1.5 while it hangs out); a segment's mosaic plate takes a
## tenth of a hit until 30 raw damage knocks it off (shards, a glowing
## crack beneath), then the bared segment takes full hits (gold marker, no
## multiplier). The lying body is solid but low: jump over it. Its fall:
## SerpentFall; the keeper drops the shard on the summit.
## The node's own transform is its post on the summit; the body lives in
## world space (the rig's root is top-level).

## Announced (the warning starts) and landed: spit, lunge, sweep.
signal telegraphed(attack: StringName)
signal struck(attack: StringName)
## The other head leads now.
signal turned
## The body lies on the ring (phase 3).
signal encircled
## Segment [param segment]'s plate came off.
signal plate_lost(segment: int)

const A := SerpentBrain.Attack
const S := SerpentBrain.State
const END := SerpentBody.End
const NAMES := {SerpentBrain.Attack.SPIT: &"spit", SerpentBrain.Attack.LUNGE: &"lunge", SerpentBrain.Attack.SWEEP: &"sweep"}
## A lying segment's collider: a low box (its top COLLIDER_LIFT +
## COLLIDER_HEIGHT over the belly) the guard jumps (he reaches 0.83 m).
const COLLIDER_HEIGHT := 0.6
const COLLIDER_WIDTH := 0.76
const COLLIDER_LIFT := 0.02
const HEAD_RADIUS := 0.5
## The skull reaches this far past the head joint (the bite).
const SKULL_REACH := 1.9
## Belly dust while gliding (s between puffs).
const DUST_EVERY := 0.12
## The spit's marks lead the guard by this share of his run over the
## flight; the fan's spacing (m).
const SPIT_LEAD := 0.5
const FAN_STEP := 1.4
## The sweep hurts within this of the tail's base (m).
const SWEEP_REACH := 6.5
## The guard this close to the leader: it waits there and fights.
const CLOSE := 4.0
## Phase 3: the ring is closed once the trailing neck root comes this near
## its gate post (or the leader reaches the other), with the leader this
## near the end of its line - the body's length on the trail is not the
## ring's (the hump over the south flight, the wave).
const RING_CLOSE := 0.8
const RING_CLOSE_LEFT := 1.5
## The lateral wave: gliding, and sliding onto the ring (tighter).
const WAVE := 0.25
const WAVE_RING := 0.12
## The ground is looked at this often ahead of the leader (m).
const LOOKAHEAD_STEP := 0.1
const TURQUOISE := SerpentShard.TURQUOISE
const GOLD := Color(1.0, 0.82, 0.5)

var brain := SerpentBrain.new()
var body := SerpentBody.new()
var course := SerpentCourse.new()
var rig: SerpentRig
var moves: SerpentMoves
## Raw damage each plate still takes.
var plate_health := PackedFloat32Array()
var shards: Array[Node] = []

var _look: Node3D
var _zone_factor: float = 1.0
var _gold_frame: int = -1
var _colliders: Array[AnimatableBody3D] = []
## The mouths' lights (one per end).
var _lights: Array[OmniLight3D] = []
var _spit_marks: Array = []
var _spit_at: Array[Vector3] = []
var _lane: GroundMark
var _arc: GroundMark
var _lunge_dir := Vector3.FORWARD
var _lunge_from := Vector3.ZERO
var _lunge_hit := false
var _sweep_hit := false
var _sweep_side: float = 1.0
var _sweep_axis := Vector3.FORWARD
var _sweep_base := Vector3.ZERO
var _sweep_floor: float = 0.0
var _sweep_turn_min: float = INF
## The flights' railings (collision only): the body slides over a flight's
## steps, not over an invisible rail (the fall's skulls ignore them too).
var _rail_rids: Array[RID] = []
var _rail_bodies: Array[PhysicsBody3D] = []
var _dust_timer: float = 0.0
var _arch_s: float = 0.0
var _arch_grow: float = 0.0
var _ring_stage: int = 0
var _ring_from_west := true
var _settled := false
var _guard_before := Vector3.ZERO
var _guard_velocity := Vector3.ZERO


func _init() -> void:
	# (the dev arena's bot: ~40 s; the plan's 1300 made it 33 s, 1500 47 s -
	# phase 3 from the gate is slower for it)
	max_health = 1400.0
	kinematic = true


# --- body -------------------------------------------------------------------

func _build_body() -> void:
	# the segments' own bodies carry the collision; this node has none
	collision_layer = 0
	collision_mask = 0
	_look = Node3D.new()
	_look.name = "Look"
	add_child(_look)
	rig = SerpentRig.create(_look)
	moves = SerpentMoves.new(body)
	body.height_at = _ground_at
	course.build(points)
	plate_health.resize(rig.count)
	plate_health.fill(SerpentBrain.PLATE_HEALTH)
	_build_zones()
	_build_colliders()
	_build_lights()
	brain.telegraphed.connect(_on_telegraphed)
	brain.struck.connect(_on_struck)
	brain.finished.connect(_on_finished)
	brain.state_changed.connect(_on_state_changed)
	brain.reversed.connect(_on_reversed)
	brain.roles_swapped.connect(_on_roles_swapped)
	_rest()


## Hit zones: a head's weak point inside each skull, a box on every
## segment (its plate or its bared core: the zone's name says which).
func _build_zones() -> void:
	for end in 2:
		var zone := _zone(&"head_a" if end == 0 else &"head_b")
		var sphere := SphereShape3D.new()
		sphere.radius = HEAD_RADIUS
		var mark := rig.head_marks[end]
		mark.add_child(Hurtbox.make(zone, sphere, Vector3.ZERO, true))
	for k in rig.count:
		var zone := _zone(StringName("seg_%d" % k))
		var box := BoxShape3D.new()
		var r := body.radii[k]
		box.size = Vector3(2.0 * r, 2.0 * r, SerpentBody.SPACING)
		rig.segments[k].add_child(Hurtbox.make(zone, box, Vector3(0.0, 0.0, SerpentBody.SPACING * 0.5)))


func _zone(zone_name: StringName) -> GuardianZone:
	var zone := GuardianZone.make(self, zone_name)
	add_child(zone)
	return zone


## A low solid box under every segment (the guard jumps it, never walks
## through it), moved with the body.
func _build_colliders() -> void:
	for k in rig.count:
		var collider := AnimatableBody3D.new()
		collider.name = "Solid_%d" % k
		collider.sync_to_physics = true
		collider.collision_layer = Layers.ENEMY
		collider.collision_mask = 0
		var box := BoxShape3D.new()
		box.size = Vector3(COLLIDER_WIDTH, COLLIDER_HEIGHT, SerpentBody.SPACING)
		var shape := CollisionShape3D.new()
		shape.shape = box
		collider.add_child(shape)
		rig.model.add_child(collider)
		_colliders.append(collider)


func _build_lights() -> void:
	for end in 2:
		var light := OmniLight3D.new()
		light.light_color = TURQUOISE
		light.omni_range = 4.0
		light.light_energy = 0.0
		light.shadow_enabled = false
		rig.mouth_marks[end].add_child(light)
		light.position = Vector3(0.0, 0.1, 0.0)
		_lights.append(light)


## Asleep on its ring: the body laid from the east post round to the west,
## both heads over the north flight. End A leads the laid body (the ring's
## line ends at its neck root): a turn-round that was under way is undone.
func _rest() -> void:
	body.lead = END.A
	var path := course.ring_path() if course.ring.size() >= 3 else PackedVector3Array()
	if path.size() < 2:
		# no tracks (a bare test): straight back from the post
		path = PackedVector3Array()
		for i in 70:
			path.append(home.origin + home.basis.z * (35.0 - 0.5 * i))
	body.lay(path)
	if course.ring.size() >= 3:
		course.start_at(body.leader(), course.ring[course.ring.size() - 1])
		moves.gate_center = course.gate_center()
		moves.gate_down = Vector3.FORWARD
		var ramp := _ground_at(course.gate_center())
		moves.gate_floor = ramp if ramp > course.gate_center().y - 2.0 else course.gate_center().y
	else:
		course.start_at(body.leader(), course.nearest(body.leader()) if not course.nodes.is_empty() else -1)
	moves.reset(true)
	body.arches = []
	_arch_s = 0.0
	_arch_grow = 0.0
	_ring_stage = 0
	_pose(0.0)
	# (the segments jumped back to the ring after the guardian's own reset)
	rig.model.reset_physics_interpolation()


func _pose(delta: float) -> void:
	var pose := moves.compose(brain, delta, brain.in_ring() or brain.state == S.DORMANT)
	body.update()
	rig.apply(body, pose, delta)
	_place_colliders()


func _place_colliders() -> void:
	for k in _colliders.size():
		var xform := rig.segments[k].transform
		_colliders[k].transform = xform * Transform3D(Basis.IDENTITY, Vector3(0.0, -body.radii[k] + COLLIDER_LIFT + COLLIDER_HEIGHT * 0.5, SerpentBody.SPACING * 0.5))


## The ground under [param at] (world): a ray down through the arena (the
## flights' railings do not count); the nearest track node's height when
## nothing is there yet.
func _ground_at(at: Vector3) -> float:
	if is_inside_tree():
		var space := get_world_3d().direct_space_state
		if space != null:
			var from := Vector3(at.x, 7.5, at.z)
			var query := PhysicsRayQueryParameters3D.create(from, Vector3(at.x, -1.5, at.z), Layers.WORLD)
			query.exclude = _rail_rids
			var hit := space.intersect_ray(query)
			if not hit.is_empty():
				return (hit["position"] as Vector3).y
	var near := course.nearest(at)
	if near >= 0 and Vector2(course.nodes[near].x - at.x, course.nodes[near].z - at.z).length() < 3.0:
		return course.nodes[near].y
	return home.origin.y if course.nodes.is_empty() else 0.0


# --- damage -------------------------------------------------------------------

func take_zone_damage(info: DamageInfo, zone: StringName) -> void:
	if info == null:
		return
	var key := String(zone)
	var end := -1
	if key.begins_with("head_"):
		end = 0 if key == "head_a" else 1
		_zone_factor = brain.weak_factor(end as END)
		info.weak_point = true
		info.blocked = false
	elif key.begins_with("seg_"):
		var k := int(key.substr(4))
		if rig.plate_on(k):
			_zone_factor = SerpentBrain.PLATE_FACTOR
			info.weak_point = false
			info.blocked = true
			if state != State.DEFEATED and not is_frozen() and hit_counts() and not info.periodic:
				plate_health[k] -= info.amount
				if plate_health[k] <= 0.0:
					_drop_plate(k, info)
		else:
			_zone_factor = SerpentBrain.BARE_FACTOR
			info.weak_point = true   # the gold marker; the weapon added no multiplier
			info.blocked = false
	super(info, zone)
	_zone_factor = 1.0
	if state == State.FIGHT and info.effects and not info.periodic:
		moves.flinch(end, 1.0 if end >= 0 else 0.3)


func _damage_factor(_info: DamageInfo) -> float:
	return _zone_factor


func _drop_plate(k: int, info: DamageInfo) -> void:
	rig.drop_plate(k, info.normal if info.normal.length() > 0.1 else Vector3.UP)
	var at := rig.segments[k].global_transform * Vector3(0.0, body.radii[k] * 0.5, SerpentBody.SPACING * 0.5)
	Fx.impact(at, Vector3.UP, ExhibitMaterial.Kind.METAL, 1.6)
	Fx.impact(at, Vector3.UP, ExhibitMaterial.Kind.WOOD, 1.0)
	Fx.flash(at, GOLD, 2.0, 3.0, 0.2)
	Sfx.play_at(&"shard_break", at, 2.0, 0.1)
	Sfx.play_at(&"break_wood", at, -6.0, 0.1)
	plate_lost.emit(k)


func _hit_effects(info: DamageInfo) -> void:
	if info.weak_point:
		Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.METAL, clampf(info.amount / 10.0, 1.0, 3.0))
		Fx.flash(info.position, GOLD, 2.5, 3.0, 0.08)
		Sfx.play_at(&"hit_wood", info.position, 1.0)
		rig.flash(0.6)
	elif info.blocked:
		# turquoise chips off the mosaic
		Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.MARBLE, 1.0)
		Fx.chunk(info.position, TURQUOISE, randf_range(0.03, 0.06), info.normal * 2.5 + Vector3.UP * 1.5)
		Sfx.play_at(&"hit_marble", info.position, -6.0, 0.25)
	else:
		Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.WOOD, 1.4)
		Sfx.play_at(&"hit_wood", info.position, -2.0)
		rig.flash(0.25)


## One blast can strike a head and the body at once: the grey marker must
## not paint over the gold one.
func _report_hit(info: DamageInfo) -> void:
	var frame := Engine.get_physics_frames()
	if info.weak_point:
		_gold_frame = frame
	elif _gold_frame == frame:
		return
	Events.hit_landed.emit(self, info, false)


# --- the fight ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _settled:
		# the first physics frame: the arena's bodies are in the space now,
		# the ground under the ring is known
		_settled = true
		_find_railings()
		if state == State.DORMANT:
			_rest()
	super(delta)


## The railings of the arena's own flights, to leave out of the ground rays
## (invisible where no balustrade is drawn: the body must not hump over
## them). The museum's other railings (some 140) stay in the world.
func _find_railings() -> void:
	_rail_rids.clear()
	_rail_bodies.clear()
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if node.get_meta(&"kit", &"") != &"railing":
			continue
		if arena_room != &"" and node.get_meta(&"kit_room", &"") != arena_room:
			continue
		# (the kit piece's root is its body)
		if node is StaticBody3D:
			_rail_bodies.append(node as StaticBody3D)
		for solid in node.find_children("*", "StaticBody3D", true, false):
			_rail_bodies.append(solid as StaticBody3D)
	for rail in _rail_bodies:
		_rail_rids.append(rail.get_rid())


func _on_phase(next: int) -> void:
	if next == 1:
		brain.wake()
	else:
		brain.set_phase(next)


func _fight_process(delta: float) -> void:
	var guard := target.global_position
	_guard_velocity = _guard_velocity.lerp((guard - _guard_before) / maxf(delta, 0.001), clampf(delta * 8.0, 0.0, 1.0))
	_guard_before = guard
	brain.update(delta, _sight(guard))
	moves.guard = guard + Vector3.UP * 1.2
	var pose := moves.compose(brain, delta, brain.in_ring())
	_arches(delta)
	_move(delta)
	rig.apply(body, pose, delta)
	_place_colliders()
	_attack_frame(delta)
	_effects(delta, pose)


## What the brain sees: the guard from each head and from the tail.
func _sight(guard: Vector3) -> SerpentBrain.Sight:
	var sight := SerpentBrain.Sight.new()
	var spit := body.head_point(brain.spitter)
	var bite := body.head_point(brain.biter())
	sight.spit_distance = spit.distance_to(guard)
	sight.spit_bearing = _flat(body.head_look(brain.spitter)).angle_to(_flat(guard - spit))
	sight.bite_distance = bite.distance_to(guard)
	sight.bite_bearing = _flat(body.head_look(brain.biter())).angle_to(_flat(guard - bite))
	sight.tail_distance = body.joints[body.trailer_joint()].distance_to(guard)
	sight.nearer_tail = sight.tail_distance + 1.0 < body.leader().distance_to(guard)
	return sight


# --- moving -------------------------------------------------------------------

func _move(delta: float) -> void:
	var speed := brain.wanted_speed()
	match brain.state:
		S.ROAM:
			if course.arrived() or course.next_node() < 0:
				_pick_goal()
		S.ENCIRCLE:
			_encircle_step()
	course.amplitude = WAVE_RING if brain.state == S.ENCIRCLE else WAVE
	var moved := false
	if speed > 0.0 and not course.arrived():
		body.advance(course.advance(speed * delta), _ahead())
		moved = true
	# the lunge carries the body after the biting head when it leads
	if brain.state == S.ATTACK and brain.attack == A.LUNGE and brain.stage == SerpentBrain.Stage.STRIKE and brain.biter() == brain.lead and not brain.in_ring() and not course.arrived():
		var slide := SerpentBrain.LUNGE_SLIDE / maxf(SerpentBrain.stage_length(A.LUNGE, SerpentBrain.Stage.STRIKE, brain.phase), 0.05) * delta
		body.advance(course.advance(slide), _ahead())
		moved = true
	if not moved:
		body.update()


## The line ahead of the leader, LOOKAHEAD_STEP apart: the body lifts
## before a rise there.
func _ahead() -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := ceili(SerpentBody.LOOKAHEAD / LOOKAHEAD_STEP)
	for k in range(1, n + 1):
		out.append(course.peek(LOOKAHEAD_STEP * float(k)))
	return out


## Where to glide: the track node nearest the guard (not back to the one
## it stands on); it waits where it is with the guard close by.
func _pick_goal() -> void:
	if course.nodes.is_empty() or not guard_alive():
		return
	var guard := target.global_position
	if course.arrived() and guard.distance_to(body.leader()) < CLOSE:
		return
	var goal := course.nearest(guard, course.previous_node() if course.next_node() < 0 else -1)
	if goal < 0:
		return
	course.head_for(goal)


## Phase 3: to the nearer gate post, then round the ring to the other.
func _encircle_step() -> void:
	if course.ring.size() < 3:
		brain.encircled()
		return
	match _ring_stage:
		0:
			var posts := course.gate_posts()
			var at := body.leader()
			_ring_from_west = Vector2(at.x - posts[0].x, at.z - posts[0].z).length() <= Vector2(at.x - posts[1].x, at.z - posts[1].z).length()
			course.head_for(course.ring[course.ring.size() - 1] if _ring_from_west else course.ring[0])
			_ring_stage = 1
		1:
			if course.arrived():
				var order := course.ring.duplicate()
				if _ring_from_west:
					order.reverse()
				course.head_along(order)
				_ring_stage = 2
		2:
			# closed when the tail's root reaches the post it left from (or
			# the leader the other): the body on the trail is longer than
			# the ring's line, so the leader may stop short of its post
			var post: Vector3 = course.gate_posts()[0 if _ring_from_west else 1]
			var tail := body.joints[body.trailer_joint()]
			var closed := course.left() < RING_CLOSE_LEFT and Vector2(tail.x - post.x, tail.z - post.z).length() <= RING_CLOSE
			if course.arrived() or closed:
				_ring_stage = 3
				brain.encircled()
				Sfx.play_at(&"serpent_rattle", course.gate_center() + Vector3.UP * 2.0, 2.0, 0.05)
				encircled.emit()


## The ring's travelling arches (phase 3): two humps that go round the
## lying body, growing in as the ring closes.
func _arches(delta: float) -> void:
	if brain.in_ring():
		_arch_grow = move_toward(_arch_grow, 1.0, delta / 1.5)
		_arch_s += SerpentBrain.ARCH_SPEED * delta
		var lying := body.lying_length()
		var arches := []
		for i in 2:
			var s := fposmod(_arch_s + float(i) * lying * 0.5, lying)
			var taper := clampf(minf(s, lying - s) / SerpentBrain.ARCH_HALF_WIDTH, 0.0, 1.0)
			arches.append([s, SerpentBrain.ARCH_HEIGHT * taper * _arch_grow, SerpentBrain.ARCH_HALF_WIDTH])
		body.arches = arches
	elif not body.arches.is_empty():
		_arch_grow = 0.0
		body.arches = []


# --- the attacks ------------------------------------------------------------------

func _on_telegraphed(attack: A) -> void:
	_clear_marks()
	match attack:
		A.SPIT:
			var n := int(SerpentBrain.per_phase(SerpentBrain.SHARDS, brain.phase))
			for i in n:
				var at := _fan_point(i, n)
				var mark := GroundMark.disc(SerpentBrain.SPLASH_RADIUS)
				get_parent().add_child(mark)
				mark.global_transform = Transform3D(Basis.IDENTITY, at)
				_spit_marks.append(mark)
				_spit_at.append(at)
			Sfx.play_at(&"serpent_hiss", rig.mouth_point(brain.spitter), -5.0, 0.1, 1.2)
		A.LUNGE:
			_lane = GroundMark.lane(SerpentBrain.LUNGE_WIDTH + 0.4, SerpentBrain.LUNGE_RANGE + 0.5)
			get_parent().add_child(_lane)
			_aim_lane(0.0)
			Sfx.play_at(&"serpent_hiss", rig.mouth_point(brain.biter()), 2.0, 0.05)
		A.SWEEP:
			var base := body.joints[_tail_base()]
			var tip := body.joints[body.trailer_joint()]
			_sweep_base = base
			_sweep_axis = _flat(tip - base).normalized() if _flat(tip - base).length() > 0.01 else _flat(body.root_direction(brain.trailer()))
			var guard := target.global_position if guard_alive() else base
			_sweep_side = 1.0 if Vector3.UP.cross(_sweep_axis).dot(_flat(guard - base)) >= 0.0 else -1.0
			moves.sweep_side = _sweep_side   # (the moves wind the tail up the other way)
			_sweep_floor = _ground_at(base)
			_sweep_turn_min = INF
			_arc = GroundMark.arc(0.8, SWEEP_REACH, 0.0, _sweep_side * SerpentBody.SWEEP_TURN * 0.95)
			get_parent().add_child(_arc)
			_arc.global_transform = Transform3D(Basis.looking_at(_sweep_axis, Vector3.UP), Vector3(base.x, _ground_at(base) + 0.01, base.z))
			Sfx.play_at(&"serpent_rattle", base + Vector3.UP, 1.0, 0.1)
	telegraphed.emit(NAMES[attack])


func _on_struck(attack: A) -> void:
	match attack:
		A.SPIT:
			_spit()
		A.LUNGE:
			_lunge_from = body.joints[_neck_root(brain.biter())]
			_lunge_hit = false
			Sfx.play_at(&"tail_whoosh", rig.mouth_point(brain.biter()), 0.0, 0.1)
			_clear_lane(0.5)
		A.SWEEP:
			_sweep_hit = false
			_sweep_turn_min = INF
			Sfx.play_at(&"tail_whoosh", _sweep_base + Vector3.UP * 0.5, 2.0, 0.1)
			if _arc != null and is_instance_valid(_arc):
				_arc.progress = 1.0
	struck.emit(NAMES[attack])


func _on_finished(_attack: A) -> void:
	_clear_marks(0.3)


func _on_state_changed(from: S, to: S) -> void:
	match to:
		S.WAKING:
			Sfx.play_at(&"serpent_rattle", course.gate_center() + Vector3.UP * 2.0 if course.ring.size() >= 3 else home.origin, 2.0, 0.05)
		S.ROAM:
			if from == S.WAKING:
				_pick_goal()
		S.PHASE_SHIFT:
			Sfx.play_at(&"guardian_wake", body.head_point(brain.spitter) + Vector3.UP, -6.0)
			Sfx.play_at(&"serpent_rattle", body.joints[body.count >> 1], 0.0, 0.1)
		S.ENCIRCLE:
			_ring_stage = 0
			Sfx.play_at(&"serpent_hiss", body.head_point(brain.lead), 0.0, 0.1, 0.9)


func _on_reversed() -> void:
	body.reverse()
	course.start_on(body.leader(), body.root_direction(brain.lead))
	_pick_goal()
	Sfx.play_at(&"serpent_rattle", body.leader() + Vector3.UP, -2.0, 0.1)
	turned.emit()


func _on_roles_swapped() -> void:
	Fx.flash(rig.mouth_point(brain.spitter), TURQUOISE, 3.0, 5.0, 0.4)
	Sfx.play_at(&"serpent_hiss", rig.mouth_point(brain.spitter), 0.0, 0.1, 1.1)


## Effects that run through an attack: the marks following the guard, the
## lane's aim, the lunge's and the sweep's hits.
func _attack_frame(delta: float) -> void:
	if brain.state != S.ATTACK:
		return
	var length := maxf(SerpentBrain.stage_length(brain.attack, brain.stage, brain.phase), 0.01)
	var progress := brain.stage_time() / length
	match brain.attack:
		A.SPIT:
			if brain.stage == SerpentBrain.Stage.TELEGRAPH:
				var n := _spit_marks.size()
				for i in n:
					var mark := _spit_marks[i] as GroundMark
					if mark == null or not is_instance_valid(mark):
						continue
					if length - brain.stage_time() > 0.15:
						_spit_at[i] = _spit_at[i].lerp(_fan_point(i, n), clampf(delta * 9.0, 0.0, 1.0))
						mark.global_position = _spit_at[i]
					mark.progress = progress
		A.LUNGE:
			if brain.stage == SerpentBrain.Stage.TELEGRAPH:
				_aim_lane(progress)
			elif brain.stage == SerpentBrain.Stage.STRIKE or (brain.stage == SerpentBrain.Stage.RECOVER and brain.stage_time() < 0.35):
				_lunge_frame()
		A.SWEEP:
			if brain.stage == SerpentBrain.Stage.TELEGRAPH:
				if _arc != null and is_instance_valid(_arc):
					_arc.progress = progress
			elif brain.stage == SerpentBrain.Stage.STRIKE or (brain.stage == SerpentBrain.Stage.RECOVER and brain.stage_time() < 0.3):
				# (the tail still comes round, overshooting, into the recovery)
				_sweep_frame()


## Where shard [param i] of [param n] should come down: round where the
## guard will be, spread across his line from the spitting head.
func _fan_point(i: int, n: int) -> Vector3:
	var head := body.head_point(brain.spitter)
	if not guard_alive():
		return head + _flat(body.head_look(brain.spitter)) * 10.0
	var at := target.global_position
	var flight := SerpentShard.flight_time(_flat(at - head).length())
	var lead := SerpentBrain.per_phase([SPIT_LEAD, SPIT_LEAD + 0.1, SPIT_LEAD + 0.25], brain.phase)
	at += _flat(_guard_velocity) * flight * lead
	var across := _flat(at - head)
	across = across.normalized().cross(Vector3.UP) if across.length() > 0.1 else Vector3.RIGHT
	at += across * ((float(i) - float(n - 1) * 0.5) * FAN_STEP)
	at.y = _ground_at(at)
	return at


## The shards leave the mouth for their marks (locked now).
func _spit() -> void:
	_prune_shards()
	var from := rig.mouth_point(brain.spitter)
	for i in _spit_marks.size():
		var to := _spit_at[i]
		var flight := SerpentShard.flight_time(_flat(to - from).length())
		var shard := SerpentShard.make(from, to, flight, SerpentBrain.SHARD_DAMAGE * damage_scale, SerpentBrain.SPLASH_DAMAGE * damage_scale, self, target)
		var mark := _spit_marks[i] as GroundMark
		if mark != null and is_instance_valid(mark):
			mark.progress = 1.0
			shard.mark = mark
		get_parent().add_child(shard)
		shards.append(shard)
	_spit_marks.clear()
	_spit_at.clear()
	Sfx.play_at(&"shard_fire", from, 0.0, 0.1)
	Fx.flash(from, TURQUOISE, 3.0, 4.0, 0.15)
	Fx.impact(from, _flat(body.head_look(brain.spitter)), ExhibitMaterial.Kind.METAL, 1.2)


## The lane from the biting head's root toward the guard (locked for the
## last quarter of the warning).
func _aim_lane(progress: float) -> void:
	if _lane == null or not is_instance_valid(_lane):
		return
	var root := body.joints[_neck_root(brain.biter())]
	if progress < 0.75 and guard_alive():
		var to := _flat(target.global_position - root)
		if to.length() > 0.3:
			_lunge_dir = to.normalized()
		else:
			_lunge_dir = _flat(body.root_direction(brain.biter())).normalized()
	var floor_y := _ground_at(root)
	_lane.global_transform = Transform3D(Basis.looking_at(_lunge_dir, Vector3.UP), Vector3(root.x, floor_y + 0.01, root.z) + _lunge_dir * 0.6)
	_lane.length = SerpentBrain.LUNGE_RANGE + 0.5
	_lane.progress = progress


## The strike: whoever stands in the lane as far as the head has reached
## is bitten.
func _lunge_frame() -> void:
	if _lunge_hit or not guard_alive():
		return
	var guard := target.global_position
	var local := guard - _lunge_from
	var along := _flat(local).dot(_lunge_dir)
	var across := (_flat(local) - _lunge_dir * along).length()
	var head := body.head_point(brain.biter())
	var reach := _flat(head - _lunge_from).dot(_lunge_dir) + SKULL_REACH
	if along < 0.3 or along > reach or across > SerpentBrain.LUNGE_WIDTH * 0.5 + ShockwaveRing.GUARD_RADIUS:
		return
	if local.y < -1.5 or local.y > 2.4:
		return
	_lunge_hit = true
	var info := DamageInfo.make(SerpentBrain.LUNGE_DAMAGE * damage_scale, DamageInfo.Kind.BLUNT, self)
	info.direction = (_lunge_dir + Vector3.UP * 0.25).normalized()
	info.knockback = SerpentBrain.LUNGE_KNOCKBACK
	info.position = guard + Vector3.UP
	target.call(&"take_damage", info)
	Sfx.play_at(&"punch_hit", info.position, 3.0)
	Fx.impact(info.position, -_lunge_dir, ExhibitMaterial.Kind.METAL, 1.5)
	_shake_near(0.5, 8.0)


## The sweep: whoever the tail has come round over is hit - the tail's
## turn at his distance (the joints nearer its base turn less) has passed
## his bearing from where it wound up - unless he is in the air over it
## (or on the terrace above it, or the floor below).
func _sweep_frame() -> void:
	if _sweep_hit or not guard_alive():
		return
	var guard := target.global_position
	var local := _flat(guard - _sweep_base)
	var distance := local.length()
	if distance < 0.5 or distance > SWEEP_REACH:
		return
	var n := float(SerpentBody.SWEEP_JOINTS)
	var i := clampf(distance / SerpentBody.SPACING, 1.0, n)
	var share := i * (i + 1.0) / (n * (n + 1.0))
	var turn := _sweep_side * body.sweep * SerpentBody.SWEEP_TURN * share
	_sweep_turn_min = minf(_sweep_turn_min, turn)
	var angle := _sweep_side * _sweep_axis.signed_angle_to(local.normalized(), Vector3.UP)
	var margin := atan2(ShockwaveRing.GUARD_RADIUS + 0.3, distance)
	if angle < _sweep_turn_min - margin or angle > turn + margin:
		return
	var over := guard.y - maxf(_sweep_floor, _ground_at(guard))
	if over > SerpentBrain.SWEEP_JUMP or over < -1.6:
		return
	_sweep_hit = true
	var info := DamageInfo.make(SerpentBrain.SWEEP_DAMAGE * damage_scale, DamageInfo.Kind.BLUNT, self)
	var out := local.normalized() if distance > 0.1 else _sweep_axis
	info.direction = (out * 0.6 + Vector3.UP.cross(_sweep_axis) * _sweep_side * 0.8 + Vector3.UP * 0.3).normalized()
	info.knockback = SerpentBrain.SWEEP_KNOCKBACK
	info.position = guard + Vector3.UP * 0.5
	target.call(&"take_damage", info)
	Sfx.play_at(&"punch_hit", info.position, 2.0)
	Fx.impact(info.position, Vector3.UP, -1, 1.5)
	_shake_near(0.4, 8.0)


# --- looks ----------------------------------------------------------------------------

## Belly dust where the body glides, the mouths' light.
func _effects(delta: float, pose: SerpentRig.Pose) -> void:
	for end in 2:
		_lights[end].light_energy = pose.head_glow[end] * 2.2
	if brain.wanted_speed() > 0.5 and not course.arrived():
		_dust_timer -= delta
		if _dust_timer <= 0.0:
			_dust_timer = DUST_EVERY
			var ground := body.ground_joints()
			for i in 2:
				var k := randi_range(ground.x, ground.y)
				var at := body.joints[k] + Vector3(randf_range(-0.3, 0.3), -body.radii[k] + 0.05, randf_range(-0.3, 0.3))
				Fx.impact(at, Vector3.UP, -1, 0.45)


# --- calm, freeze, fall ---------------------------------------------------------------

func _on_reset() -> void:
	brain.reset()
	_clear_marks()
	_free_shards()
	rig.restore_plates()
	plate_health.fill(SerpentBrain.PLATE_HEALTH)
	body.sweep = 0.0
	_rest()


func _on_freeze() -> void:
	_clear_marks()
	_free_shards()
	for light in _lights:
		light.light_energy = 0.0


func _on_defeated(info: DamageInfo) -> void:
	brain.die()
	_clear_marks()
	_free_shards()
	var fall := SerpentFall.make(self, info)
	get_parent().add_child(fall)


# --- helpers ------------------------------------------------------------------------

## Where the fight is - between the heads (the node itself stays on its
## summit post; the dev arena's bot circles this).
func focus_point() -> Vector3:
	return (body.head_point(END.A) + body.head_point(END.B)) * 0.5


## The joint the sweeping tail turns about.
func _tail_base() -> int:
	return body.trailer_joint() - SerpentBody.SWEEP_JOINTS if brain.lead == END.A else body.trailer_joint() + SerpentBody.SWEEP_JOINTS


func _neck_root(end: END) -> int:
	return SerpentBody.NECK if end == END.A else body.count - SerpentBody.NECK


func _clear_marks(fade: float = 0.25) -> void:
	for mark: GroundMark in _spit_marks:
		if mark != null and is_instance_valid(mark):
			mark.vanish(fade)
	_spit_marks.clear()
	_spit_at.clear()
	_clear_lane(fade)
	if _arc != null and is_instance_valid(_arc):
		_arc.vanish(fade)
	_arc = null


func _clear_lane(fade: float) -> void:
	if _lane != null and is_instance_valid(_lane):
		_lane.vanish(fade)
	_lane = null


## Forgets the shards that burst.
func _prune_shards() -> void:
	for i in range(shards.size() - 1, -1, -1):
		if not is_instance_valid(shards[i]) or shards[i].is_queued_for_deletion():
			shards.remove_at(i)


func _free_shards() -> void:
	for node in shards:
		if is_instance_valid(node):
			node.queue_free()
	shards.clear()


## Camera shake for a guard within [param reach] m, fading with distance.
func _shake_near(trauma: float, reach: float) -> void:
	if not guard_alive() or not target is Player:
		return
	var distance := target.global_position.distance_to(body.head_point(brain.lead))
	if distance < reach:
		Events.shake_requested.emit(trauma * (1.0 - distance / reach))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
