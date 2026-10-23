class_name FlyingBook
extends Enemy
## A flying book of the Enlightenment wing (design pietro-1-projekt 5.4):
## one of a flock of 4-6 (BookFlock, one spawn slot). 18 HP, Dust 2, paper
## (CANVAS: shreds and tearing), fire x2. Asleep it stands closed on a
## shelf with its spine to the room (or lies in a stack on the floor);
## woken, it slides out, its covers burst open and the flock takes off
## one after another. Awake it flies open like a maw, spine behind, covers
## beating as wings, hovering at its own height (by the guard's when it
## hunts) and bobbing. Hunting, the flock circles the guard (BookFlock's
## ring); one at a time a book in front of him dives:
## - telegraph DIVE_WINDUP s: it stops, rears back, spreads its covers
##   flat (the illuminated eyes on the spread stare at him), pages riffle,
##   a rustle (book_flap); a hit in the telegraph calls the dive off,
## - the dive: straight at his chest as it was when the telegraph ended
##   (a step aside dodges it), DIVE_SPEED for at most DIVE_TIME; within
##   DIVE_CONTACT it bites once (DIVE_DAMAGE) and snaps shut,
## - then it pulls up and away, beating hard, defenceless for a moment.
## A shot-down book bursts into pages that see-saw down like leaves
## (PageFlutter; scorched by fire) and the rest of the flock scatters.
## The model "flying_book" (four bindings, sizes from octavo to folio)
## moves through a BookRig; without it a greybox.

const KIND := &"books"
const DIVE_WINDUP := 0.7
const DIVE_RECOVERY := 1.1
const DIVE_SPEED := 11.0
const DIVE_TIME := 1.0
## It bites the guard's chest this close (m).
const DIVE_CONTACT := 0.75
const DIVE_DAMAGE := 7.0
const DIVE_KNOCKBACK := 3.0
## Where it aims: the guard's chest over his feet (m).
const AIM_HEIGHT := 1.3
## It dives only from in front of the guard: within this of where he looks.
const VIEW_HALF_ARC := 75.0
## Pull-up after the dive (m/s: forward, up), dying down.
const PULL_FORWARD := 3.0
const PULL_UP := 4.5
## Hover spring: vertical speed per metre off its height, and its cap.
const HOVER_STIFFNESS := 4.0
const HOVER_MAX_SPEED := 3.0
## How fast a push dies down in the air (m/s per second).
const AIR_DRAG := 9.0
## Bobbing: metres, and a rate per book (Hz).
const BOB := 0.18
const BOB_RATE := Vector2(0.9, 1.3)
## Height over the floor while it is not hunting (m), by member.
const CRUISE_HEIGHT := Vector2(1.7, 2.4)
## It keeps this far under a ceiling (m), and never lower than this over
## the floor while it hunts a guard on a lower floor.
const CEILING_GAP := 0.45
const FLOOR_GAP := 1.0
const FLOOR_CHECK := 0.15
## Sliding off its shelf / back onto it (s); how far out it slides (m).
const LAUNCH_TIME := 0.45
const LAND_TIME := 0.6
const LAUNCH_OUT := 0.35
## Arriving home it stops this far out from its shelf (m).
const HOME_OUT := 0.6
## Pages that fly off a hit, and off a destroyed book.
const PAGES_HIT := Vector2i(1, 2)
const PAGES_DEATH := Vector2i(6, 9)
const COLLIDER_RADIUS := 0.17
const ZONE_RADIUS := 0.2
## The bindings, and how big a book may be (scale of the quarto model).
const BINDINGS: Array[String] = ["flying_book", "flying_book_green", "flying_book_blue", "flying_book_black"]
const SIZE := Vector2(1.05, 1.3)
const COVER := Color(0.42, 0.12, 0.1)
const PAGE := Color(0.88, 0.82, 0.68)

## Its flock (null: a lone book).
var flock: BookFlock = null
## Its place in the flock (picks binding, size, height).
var flock_index: int = 0
## Its own height over the floor / over the guard's feet (m).
var hover_height: float = 2.0
## How big it is (scale of the model).
var size: float = 1.15

var _perch := Transform3D.IDENTITY
var _has_perch := false
var _perched := false
var _perch_ready := false
var _launch: float = 0.0
var _landing: float = 0.0
var _land_from := Transform3D.IDENTITY
var _wake_delay: float = -1.0
var _wake_spotted := false
var _wake_point := Vector3.ZERO
var _diving := false
var _dive_hit := false
var _dive_left: float = 0.0
var _dive_dir := Vector3.ZERO
var _dive_aim := Vector3.ZERO
var _pulling: float = 0.0
var _pull := Vector3.ZERO
var _floor_y: float = NAN
var _ceiling_y: float = INF
var _floor_timer: float = 0.0
var _time: float = 0.0
var _bob_rate: float = 1.1
var _collider: CollisionShape3D
var _zone: Hurtbox
var _flock_sound: AudioStreamPlayer3D = null


func _configure() -> void:
	max_health = 18.0
	move_speed = 4.4
	turn_speed = 9.0
	attack_damage = DIVE_DAMAGE
	attack_reach = DIVE_CONTACT
	eye_height = 0.0
	marker_height = 0.4
	material_kind = ExhibitMaterial.Kind.CANVAS
	dust_value = 2
	notice_sound = &"book_flap"
	windup_lean = 0.0
	strike_lean = 0.0
	brain.reaction_time = 0.5
	brain.attack_range = 8.0
	brain.windup = DIVE_WINDUP
	brain.recovery = DIVE_RECOVERY


func _ready() -> void:
	var shade := fposmod(flock_index * 0.618 + 0.1, 1.0)
	hover_height = lerpf(BookFlock.RING_HEIGHT.x, BookFlock.RING_HEIGHT.y, fposmod(flock_index * 0.381 + 0.15, 1.0))
	size = lerpf(SIZE.x, SIZE.y, shade)
	_bob_rate = lerpf(BOB_RATE.x, BOB_RATE.y, fposmod(flock_index * 0.73, 1.0))
	_time = randf() * TAU
	if flock != null:
		flock.join(self)
	super()
	# a flyer: it meets the level and the haven doors, never the guard (a
	# dive passes through him) nor the other exhibits
	collision_mask = Layers.WORLD | Layers.ENEMY_BLOCK
	var guard := target as PhysicsBody3D
	if guard != null:
		add_collision_exception_with(guard)
		guard.add_collision_exception_with(self)
	nav.path_height_offset = -hover_height
	# a book that starts awake takes off where it was put
	_perch_ready = starts_awake


func _exit_tree() -> void:
	if flock != null:
		flock.leave(self)
	super()


func _build_body() -> void:
	_collider = CollisionShape3D.new()
	_collider.shape = sphere_shape(COLLIDER_RADIUS)
	add_child(_collider)
	rig = BookRig.build(self, BINDINGS[flock_index % BINDINGS.size()], size)
	if rig == null:
		_build_greybox()
	_zone = add_hurtbox(sphere_shape(ZONE_RADIUS * size), Vector3.ZERO)
	if rig != null:
		rig.track(_zone, &"body")


func _build_greybox() -> void:
	var cover := body_material(COVER)
	var page := body_material(PAGE)
	add_part(box_mesh(Vector3(0.04, 0.33, 0.04) * size), Vector3(0, 0, 0.03 * size), cover)
	for side in [-1.0, 1.0]:
		add_part(box_mesh(Vector3(0.2, 0.33, 0.012) * size), Vector3(0.1 * side, 0, -0.05) * size, cover, Vector3(0, -40.0 * side, 0))
		add_part(box_mesh(Vector3(0.17, 0.3, 0.03) * size), Vector3(0.08 * side, 0, -0.06) * size, page, Vector3(0, -40.0 * side, 0))


# --- what the rig reads ------------------------------------------------------------

## Sitting closed on its shelf (asleep).
func perched() -> bool:
	return _perched


## 0..1 while it slides off its shelf (1 = just started), else 0.
func launching() -> float:
	return _launch / LAUNCH_TIME if _launch > 0.0 else 0.0


## 0..1 while it settles back onto its shelf (1 = just started), else 0.
func landing() -> float:
	return _landing / LAND_TIME if _landing > 0.0 else 0.0


## Flying its dive.
func diving() -> bool:
	return _diving


## Its dive found the guard (the covers snap shut).
func bit() -> bool:
	return _dive_hit


## 0..1 while it pulls up after a dive (beating hard).
func pulling() -> float:
	return clampf(_pulling / DIVE_RECOVERY, 0.0, 1.0)


## Where its dive is headed (world, unit), zero when not diving.
func dive_direction() -> Vector3:
	return _dive_dir if _diving else Vector3.ZERO


# --- per frame ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if brain.state == EnemyBrain.State.DESTROYED or is_frozen():
		return
	_time += delta
	if flock != null:
		# (the flock's clock moves one frame a frame: a dozing tick's delta spans many)
		flock.tick(get_physics_process_delta_time(), Engine.get_physics_frames())
	if not _perch_ready:
		_settle_on_perch()
	_tick_wake(delta)
	super(delta)
	if brain.state == EnemyBrain.State.DESTROYED:
		return
	_tick_shelf(delta)
	_tick_dive(delta)
	_update_flock_sound()


## Asleep on its shelf it is a museum piece: no physics step.
func resting() -> bool:
	return _perched or _launch > 0.0 or _landing > 0.0


## It dozes on its shelf once it sits there: not while it slides off or
## onto it, nor while its turn to wake with the flock counts down.
func _may_doze() -> bool:
	return _perch_ready and _perched and _launch <= 0.0 and _landing <= 0.0 and _wake_delay < 0.0 \
			and (_flock_sound == null or not _flock_sound.playing)


## Hovers on a spring at its height (by the guard's while it hunts),
## bobbing; dives and pulls up on its own; drops when stunned.
func _apply_gravity(delta: float) -> void:
	if resting():
		velocity.y = 0.0
		return
	if brain.is_stunned():
		super(delta)
		return
	_external = _external.move_toward(Vector3.ZERO, AIR_DRAG * delta)
	if _diving:
		velocity.y = _dive_dir.y * DIVE_SPEED
		return
	if _pulling > 0.0:
		velocity.y = _pull.y * (_pulling / DIVE_RECOVERY)
		return
	_floor_timer -= delta
	if _floor_timer <= 0.0 or is_nan(_floor_y):
		_floor_timer = FLOOR_CHECK
		_probe_room()
	var goal := _hover_goal() + sin(_time * TAU * _bob_rate) * BOB
	velocity.y = clampf((goal - global_position.y) * HOVER_STIFFNESS, -HOVER_MAX_SPEED, HOVER_MAX_SPEED)


## The height it hovers at now.
func _hover_goal() -> float:
	var floor_y := _floor_y if not is_nan(_floor_y) else global_position.y - hover_height
	var goal := floor_y + lerpf(CRUISE_HEIGHT.x, CRUISE_HEIGHT.y, fposmod(flock_index * 0.381 + 0.15, 1.0))
	if brain.is_hunting() and _target_alive():
		goal = maxf(floor_y + FLOOR_GAP, target.global_position.y + hover_height)
	elif brain.state == EnemyBrain.State.RETURN and _has_perch \
			and Vector2(global_position.x - _perch.origin.x, global_position.z - _perch.origin.z).length() < 3.0:
		goal = _perch.origin.y
	return minf(goal, _ceiling_y - CEILING_GAP)


## Where it flies this frame: its place on the ring round the guard while
## it hunts him in plain view, its dive and pull-up, the base navigation
## otherwise (flying at its height).
func _steer(delta: float, has_target: bool) -> Vector3:
	if resting() or brain.is_stunned():
		return Vector3.ZERO
	if brain.state == EnemyBrain.State.ATTACK:
		if _diving:
			return Vector3(_dive_dir.x, 0.0, _dive_dir.z) * DIVE_SPEED
		if _pulling > 0.0:
			return Vector3(_pull.x, 0.0, _pull.z) * (_pulling / DIVE_RECOVERY)
		if has_target and not brain.has_struck():
			_face_towards(target.global_position, delta)
		return Vector3.ZERO
	if brain.state == EnemyBrain.State.HUNT and has_target and brain.knows_guard() and _sees_target and flock != null:
		var slot := flock.ring_slot(self, target.global_position)
		var to := slot - global_position
		to.y = 0.0
		_face_towards(target.global_position, delta)
		_ring_goal = false
		EnemyCrowd.release(self)
		var reach := to.length()
		if reach < 0.05:
			return EnemyCrowd.push_for(self)
		return to / reach * minf(move_speed, reach * 2.0) + EnemyCrowd.push_for(self)
	return super(delta, has_target)


## Walking (flying) somewhere at a pace: a flock spreads round the point
## (its own place in a loose cloud); going home it heads for the spot in
## front of its shelf.
func _walk_to(delta: float, point: Vector3, pace: float) -> Vector3:
	if brain.state == EnemyBrain.State.RETURN and _has_perch:
		point = _perch.origin + _perch.basis.z * HOME_OUT
	elif flock != null:
		var angle := TAU * flock_index / float(maxi(flock.members.size(), 1))
		point += Vector3(cos(angle), 0.0, sin(angle)) * 1.2
	return super(delta, point, pace)


## A flyer: it may dive at a guard the navmesh cannot bring it to.
func _attacks_from_range() -> bool:
	return true


## One book of the flock at a time, from in front of the guard, along a
## clear line, never while it slides off or onto its shelf.
func _may_attack() -> bool:
	if resting() or not _target_alive():
		return false
	if flock != null and not flock.can_dive(self):
		return false
	return _in_guard_view() and _clear_line(global_position, _aim_point())


## The flock counts as one hunter: its lead's.
func counts_as_hunter() -> bool:
	return flock == null or flock.is_lead(self)


## A fright spooks the whole flock (its ring widens, nobody dives for a
## moment) instead of sending one book flying off: a blast it would flee
## (EnemyRoles: skittish), or a bang - a shot - heard while the flock
## circles calm on the wing. Asleep on the shelf, or hunting, it answers as
## any exhibit (a fright then only turns its head).
func react(point: Vector3, point_room: StringName, reaction: ReactionRules.Reaction, source: StringName = &"") -> bool:
	var fright := reaction == ReactionRules.Reaction.FLEE or (ReactionRules.is_bang(source) and brain.is_calm())
	if fright and flock != null and brain.is_awake():
		flock.spook()
		return true
	if reaction == ReactionRules.Reaction.FLEE:
		reaction = ReactionRules.Reaction.LOOK
	return super(point, point_room, reaction, source)


## The flock hunts with its lead: a member waits when the lead may not.
func _brief_brain(has_target: bool, sheltered: bool) -> void:
	super(has_target, sheltered)
	if flock == null or flock.is_lead(self):
		return
	var lead := flock.lead() as FlyingBook
	if lead != null and not lead.brain.is_hunting() and not lead.brain.may_hunt:
		brain.may_hunt = false


func _on_state_changed(from: EnemyBrain.State, to: EnemyBrain.State) -> void:
	super(from, to)
	if from == EnemyBrain.State.ATTACK and flock != null:
		flock.end_dive(self)
	if from == EnemyBrain.State.ATTACK or to == EnemyBrain.State.STUNNED:
		_diving = false
		_pulling = 0.0
	match to:
		EnemyBrain.State.ATTACK:
			if flock != null:
				flock.begin_dive(self)
			Sfx.play_at(&"book_flap", global_position, -2.0)
		EnemyBrain.State.DORMANT:
			if _has_perch and not _perched:
				_landing = LAND_TIME
				_land_from = global_transform
				_collider.disabled = true
		EnemyBrain.State.DESTROYED, EnemyBrain.State.PATROL:
			pass   # (awake from the start: the whole flock takes off as it is)
		_:
			if from == EnemyBrain.State.DORMANT:
				_take_off()
				_wake_flock()


## The end of the telegraph: the dive goes for his chest as it is now.
func _on_strike() -> void:
	if not _target_alive() or Haven.shelters(target.global_position):
		_begin_pull()
		return
	_dive_aim = _aim_point()
	var to := _dive_aim - global_position
	if to.length() < 0.05 or not _clear_line(global_position, _dive_aim):
		_begin_pull()
		return
	_dive_dir = to.normalized()
	_diving = true
	_dive_hit = false
	_dive_left = DIVE_TIME
	Sfx.play_at(&"book_flap", global_position, 0.0, 0.2)


## A paper book takes fire double; a blow in the telegraph calls the dive
## off.
func take_damage(info: DamageInfo) -> void:
	if info != null and info.kind == DamageInfo.Kind.FIRE:
		info.amount *= 2.0
	super(info)


func _on_damaged(info: DamageInfo) -> void:
	if info.periodic:
		return
	PageFlutter.scatter(info.position, randi_range(PAGES_HIT.x, PAGES_HIT.y), info.direction * 1.5, info.kind == DamageInfo.Kind.FIRE)
	if brain.state == EnemyBrain.State.ATTACK and not brain.has_struck():
		brain.interrupt()


func _destroy(info: DamageInfo, finisher: bool, overkill: float) -> void:
	var at := global_position
	PageFlutter.scatter(at, randi_range(PAGES_DEATH.x, PAGES_DEATH.y), info.direction * 2.0, info.kind == DamageInfo.Kind.FIRE)
	if flock != null:
		var pushes := flock.scatter_from(at, self)
		for book: FlyingBook in pushes:
			book.shove(pushes[book])
		flock.leave(self)
	if _flock_sound != null:
		_flock_sound.stop()
	super(info, finisher, overkill)


func freeze() -> void:
	super()
	if _flock_sound != null:
		_flock_sound.stop()


## On its shelf it faces the wall (its spine, +Z, to the room): it watches
## the room over its spine, at a sleeper's reach.
func _can_see_target() -> bool:
	if not _perched:
		return super()
	var to := target.global_position - global_position
	if sound_asleep > 0.0:
		return to.length() <= SOUND_SLEEP_SENSE and _has_line_of_sight()
	var reach := sight_reach()
	if to.length_squared() > reach * reach:
		return false
	if not PerceptionRules.sees(global_transform.basis.z, to, sight_cone_deg, reach, close_sense * PerceptionRules.DORMANT_SCALE):
		return false
	return _has_line_of_sight()


# --- the shelf -----------------------------------------------------------------------

## The first look: a sleeping book takes its place on the flock's shelf
## (its post from now on).
func _settle_on_perch() -> void:
	_perch_ready = true
	if brain.state != EnemyBrain.State.DORMANT:
		return
	var space := get_world_3d().direct_space_state
	var cast := func(from: Vector3, to: Vector3) -> Dictionary:
		var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
		return space.intersect_ray(query)
	if flock == null:
		flock = BookFlock.new()
		flock.center = global_position - Vector3.UP * BookFlock.START_HEIGHT
		flock.join(self)
	_perch = flock.perch_of(self, cast)
	_has_perch = true
	_perched = true
	_collider.disabled = true
	global_transform = Transform3D(_perch.basis, _perch.origin)
	reset_physics_interpolation()
	home = _perch.origin
	home_yaw = _world_yaw()
	brain.home = home


## Woken on its shelf: it slides out and takes off.
func _take_off() -> void:
	Sfx.play_at(&"book_flap", global_position, -4.0, 0.25)
	if not _perched:
		return
	_perched = false
	_landing = 0.0
	_launch = LAUNCH_TIME


func _tick_shelf(delta: float) -> void:
	if _launch > 0.0:
		_launch = maxf(_launch - delta, 0.0)
		var out := MotionClip.eased(MotionClip.OUT, 1.0 - _launch / LAUNCH_TIME)
		global_position = _perch.origin + _perch.basis.z * LAUNCH_OUT * out + Vector3.UP * 0.12 * out
		if _launch <= 0.0:
			_collider.disabled = false
	elif _landing > 0.0:
		_landing = maxf(_landing - delta, 0.0)
		var settle := MotionClip.eased(MotionClip.IN_OUT, 1.0 - _landing / LAND_TIME)
		# rotations slerped as quaternions: a shelf perch's basis may carry a
		# hair of scale (0.99998), which Basis.slerp refuses
		var turn := _land_from.basis.get_rotation_quaternion().slerp(_perch.basis.get_rotation_quaternion(), settle)
		global_transform = Transform3D(Basis(turn).scaled(_perch.basis.get_scale()), _land_from.origin.lerp(_perch.origin, settle))
		if _landing <= 0.0:
			_perched = true
			velocity = Vector3.ZERO


## The flock wakes with it: the others one after another, nearest first
## (a guard it saw: they hunt; a noise: they come to look).
func _wake_flock() -> void:
	if flock == null:
		return
	var sleeping: Array = []
	for book in flock.alive():
		var other := book as FlyingBook
		if other != self and other.is_inside_tree() and other.brain.state == EnemyBrain.State.DORMANT and other._wake_delay < 0.0:
			sleeping.append(other)
	if sleeping.is_empty():
		return
	var delays := flock.wake_delays(self, sleeping)
	for other: FlyingBook in delays:
		other.end_doze()   # (its sleep caught up before its turn starts counting)
		other._wake_delay = delays[other]
		other._wake_spotted = brain.spotted()
		other._wake_point = brain.last_known


func _tick_wake(delta: float) -> void:
	if _wake_delay < 0.0:
		return
	_wake_delay -= delta
	if _wake_delay > 0.0:
		return
	_wake_delay = -1.0
	if brain.state != EnemyBrain.State.DORMANT:
		return
	sound_asleep = 0.0
	brain.quiet = true
	if _wake_spotted:
		brain.wake()
	else:
		brain.hear(_wake_point)
	if brain.state == EnemyBrain.State.DORMANT:
		brain.quiet = false


# --- the dive ------------------------------------------------------------------------

func _tick_dive(delta: float) -> void:
	if _pulling > 0.0:
		_pulling = maxf(_pulling - delta, 0.0)
	if not _diving:
		return
	_dive_left -= delta
	if not _dive_hit and _target_alive() and global_position.distance_to(_chest()) <= DIVE_CONTACT:
		_dive_hit = true
		_bite()
		_begin_pull()
		return
	var passed := (_dive_aim - global_position).dot(_dive_dir) < 0.0
	if passed or _dive_left <= 0.0 or is_on_wall() or is_on_floor() or is_on_ceiling():
		_begin_pull()


func _begin_pull() -> void:
	_diving = false
	var forward := Vector3(_dive_dir.x, 0.0, _dive_dir.z)
	if forward.length() < 0.01:
		forward = -global_basis.z
	_pull = forward.normalized() * PULL_FORWARD + Vector3.UP * PULL_UP
	_pulling = DIVE_RECOVERY


## The bite: once, on the guard's chest.
func _bite() -> void:
	if not is_instance_valid(target) or not target.has_method(&"take_damage") or Haven.shelters(target.global_position):
		return
	var info := DamageInfo.make(attack_damage, DamageInfo.Kind.BLUNT, self)
	var push := Vector3(_dive_dir.x, 0.0, _dive_dir.z)
	info.direction = push.normalized() if push.length() > 0.01 else -global_basis.z
	info.knockback = DIVE_KNOCKBACK
	info.position = global_position
	target.take_damage(info)
	Sfx.play_at(&"hit_canvas", global_position, -2.0)


## The guard's chest (where a dive aims and bites).
func _chest() -> Vector3:
	return target.global_position + Vector3.UP * AIM_HEIGHT


func _aim_point() -> Vector3:
	return _chest()


## True when it is in front of the guard (within VIEW_HALF_ARC of where
## he looks): a dive he can see coming.
func _in_guard_view() -> bool:
	var to := global_position - target.global_position
	to.y = 0.0
	if to.length() < 0.01:
		return true
	var look := _guard_forward()
	look.y = 0.0
	if look.length() < 0.01:
		return true
	return look.normalized().dot(to.normalized()) >= cos(deg_to_rad(VIEW_HALF_ARC))


## Where the guard looks (his head's front; any other target's -Z).
func _guard_forward() -> Vector3:
	var guard := target as Player
	if guard != null and guard.head != null:
		return -guard.head.global_basis.z
	return -target.global_basis.z


## The floor under it and the ceiling over it (level geometry).
func _probe_room() -> void:
	var space := get_world_3d().direct_space_state
	var from := global_position
	var down := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 14.0, Layers.WORLD)
	var hit := space.intersect_ray(down)
	if not hit.is_empty():
		_floor_y = (hit["position"] as Vector3).y
	elif is_nan(_floor_y):
		_floor_y = global_position.y - hover_height
	var up := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 4.0, Layers.WORLD)
	var over := space.intersect_ray(up)
	_ceiling_y = (over["position"] as Vector3).y if not over.is_empty() else INF


# --- the flock's sound ----------------------------------------------------------------

## The lead carries the flock's beating covers (a loop) while the flock is
## up; the others are silent but for their own flaps.
func _update_flock_sound() -> void:
	var leading := flock == null or flock.is_lead(self)
	var up := leading and brain.is_awake() and not resting() and not brain.is_stunned()
	if up and _flock_sound == null:
		_flock_sound = AudioStreamPlayer3D.new()
		_flock_sound.name = "FlockSound"
		_flock_sound.stream = Sfx.stream_of(&"book_flock")
		_flock_sound.bus = Sfx.BUS
		_flock_sound.unit_size = 5.0
		_flock_sound.max_distance = 35.0
		_flock_sound.volume_db = -6.0
		add_child(_flock_sound)
	if _flock_sound == null or _flock_sound.stream == null:
		return
	if up and not _flock_sound.playing:
		_flock_sound.play()
	elif not up and _flock_sound.playing:
		_flock_sound.stop()
