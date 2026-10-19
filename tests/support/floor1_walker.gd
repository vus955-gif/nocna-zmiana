class_name Floor1Walker
extends RefCounted
## The real guard walked by a headless bot (QA #49, plan
## docs/superpowers/plans/2026-10-18-qa-kolizje-softlocki-zapis.md): the
## Player's own controller (its _physics_process: acceleration, gravity,
## floor snap, jump with coyote time), its 0.4 x 1.8 m capsule and
## move_and_slide on the level's colliders, driven step by step in a tight
## loop (one physics step = 1/60 s of game time, no engine frame between
## them: the static world does not change while he walks). Input comes in
## through the real actions (move_forward, jump), the direction through the
## head's yaw, as the mouse would turn it.
## What a walk tells: did he get there, and if not where and against what
## he stopped (the collider's kit, room and height above his feet), where
## his speed collapsed on the way, whether he fell.

const DT := 1.0 / 60.0
## Floor-plan distance (m) at which a point counts as reached.
const ARRIVE := 0.35
## Below this share of the walking speed (after the first ACCEL_TIME s of
## a leg) a step counts as slowed.
const SLOW_SHARE := 0.55
const ACCEL_TIME := 0.2
## Without this much progress toward the goal for STALL_TIME s he is stuck.
const STALL_PROGRESS := 0.08
const STALL_TIME := 0.6
## He fell when his feet are this far under the floor he walks toward.
const FALL_DROP := 1.2
## An obstacle whose top is at most this high over his feet is a ledge (a
## lip, a step, a low plinth) and not a wall.
const LEDGE_TOP := 0.9

var guard: Player
var steps: int = 0
## While true every step adds the height of his eyes (the view: his body
## less the lag of a step up, Player._step_lag) to [member eyes].
var record_eyes: bool = false
var eyes := PackedFloat32Array()
var _ray := PhysicsRayQueryParameters3D.new()
var _shape := PhysicsShapeQueryParameters3D.new()


func _init(player: Player) -> void:
	guard = player
	# the bot steps him itself; the engine's own steps leave him be
	guard.set_physics_process(false)
	_ray.collision_mask = Layers.WORLD
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	_shape.shape = capsule
	_shape.collision_mask = Layers.WORLD


func space() -> PhysicsDirectSpaceState3D:
	return guard.get_world_3d().direct_space_state


## Lets go of every key (call when done: the runner resets them too).
func release() -> void:
	Input.action_release(&"move_forward")
	Input.action_release(&"jump")
	Input.action_release(&"sprint")


func feet() -> Vector3:
	return guard.global_position


## The floor (WORLD) under [param point]: the first hit of a ray from
## [param up] m over it to [param down] m under it (Vector3.INF: none).
func floor_below(point: Vector3, up: float = 0.6, down: float = 1.5) -> Vector3:
	_ray.from = point + Vector3.UP * up
	_ray.to = point - Vector3.UP * down
	var hit := space().intersect_ray(_ray)
	return hit["position"] if not hit.is_empty() else Vector3.INF


## True when his capsule stands at [param feet_at] without touching
## anything solid, with [param room] m to spare round it (not over his
## head: a low landing over a stairwell's door is no trouble).
func capsule_fits(feet_at: Vector3, room: float = 0.0) -> bool:
	var capsule := _shape.shape as CapsuleShape3D
	capsule.radius = 0.4 + room
	capsule.height = maxf(1.8, capsule.radius * 2.0)
	_shape.transform = Transform3D(Basis.IDENTITY, feet_at + Vector3.UP * 0.9)
	var fits := space().intersect_shape(_shape, 1).is_empty()
	capsule.radius = 0.4
	capsule.height = 1.8
	return fits


## A spot he stands on squarely near [param at]: the floor under it (within
## [param within] m of its height), his capsule fitting with 5 cm to
## spare, floor under each side of his footprint (0.35 m out, at most
## 0.4 m off). Vector3.INF when there is none.
func standing_spot(at: Vector3, within: float = 0.3) -> Vector3:
	_ray.from = at + Vector3.UP * (within + 0.2)
	_ray.to = at - Vector3.UP * (within + 0.2)
	var hit := space().intersect_ray(_ray)
	if hit.is_empty():
		return Vector3.INF
	var ground: Vector3 = hit["position"]
	var up: float = (hit["normal"] as Vector3).y
	if absf(ground.y - at.y) > within or up < 0.7:
		return Vector3.INF
	# on a slope the round of the capsule comes down to the floor only
	# this much higher than its lowest point would
	var lift := 0.03 + 0.45 * (1.0 / up - 1.0)
	if not capsule_fits(ground + Vector3.UP * lift, 0.05):
		return Vector3.INF
	for offset: Vector3 in [Vector3(0.35, 0, 0), Vector3(-0.35, 0, 0), Vector3(0, 0, 0.35), Vector3(0, 0, -0.35)]:
		var under := floor_below(ground + offset, 0.45, 0.45)
		if under == Vector3.INF:
			return Vector3.INF
	return ground


## Puts him at [param feet_at] facing [param yaw], still, and lets him
## settle on the floor. False when his capsule does not fit there.
func place(feet_at: Vector3, yaw: float = 0.0) -> bool:
	release()
	guard.global_position = feet_at + Vector3.UP * 0.05
	guard.velocity = Vector3.ZERO
	guard.head.rotation = Vector3(0.0, yaw, 0.0)
	guard.reset_physics_interpolation()
	var fits := capsule_fits(feet_at + Vector3.UP * 0.05)
	for i in 4:
		step(Vector3.ZERO)
	return fits


## One physics step of the controller: walking toward [param direction]
## (horizontal, any length; zero = no key), jumping when [param jump] and
## he stands on the floor. (The jump is his own take-off - velocity.y =
## jump_velocity, what Player._update_jump does on a fresh press: a press
## in this tight loop would stay "just pressed" for every step of the
## engine's one physics frame.)
func step(direction: Vector3, jump: bool = false) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length() > 0.001:
		guard.head.rotation.y = atan2(-flat.x, -flat.z)
		Input.action_press(&"move_forward")
	else:
		Input.action_release(&"move_forward")
	if jump and guard.is_on_floor():
		guard.velocity.y = guard.jump_velocity
	guard.call(&"_physics_process", DT)
	steps += 1
	if record_eyes:
		eyes.append(guard.global_position.y + guard.eye_height - float(guard.get(&"_step_lag")))


## The worst bob of [member eyes] walking [param up] (or down): the largest
## change between two steps against the way ([0] m) and the largest change
## either way ([1] m: a step popping the view).
func eye_bob(up: bool) -> Vector2:
	var against := 0.0
	var jolt := 0.0
	for i in range(1, eyes.size()):
		var change := eyes[i] - eyes[i - 1]
		against = maxf(against, -change if up else change)
		jolt = maxf(jolt, absf(change))
	return Vector2(against, jolt)


## [param goal] as a point to walk to from [param from]: a goal on a floor
## lower down (a way out over an edge) lies a little further on, so that
## he steps off the edge rather than stop on it in reach of the goal.
static func past_edge(from: Vector3, goal: Vector3) -> Vector3:
	var way := _flat(goal - from)
	if goal.y > from.y - 0.4 or way.length() < 0.01:
		return goal
	return goal + way.normalized() * (ARRIVE + 0.4)


## Lets him come to rest on what is under him (no key pressed): a walk that
## got there in the air (off an edge) lands first. At most [param steps].
func settle(steps_most: int = 180) -> void:
	for i in steps_most:
		if guard.is_on_floor():
			return
		step(Vector3.ZERO)


## The slide collisions of his last step: [{collider, kit, room, point,
## normal, height}] (height = the contact over his feet).
func contacts() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for i in guard.get_slide_collision_count():
		var hit := guard.get_slide_collision(i)
		var body := hit.get_collider() as Node
		found.append({
			"collider": body,
			"kit": describe(body),
			"point": hit.get_position(),
			"normal": hit.get_normal(),
			"height": hit.get_position().y - guard.global_position.y,
		})
	return found


## A short name of a collider: its kit and room (level pieces), else its
## class and name.
static func describe(body: Node) -> String:
	if body == null:
		return "?"
	var node := body
	while node != null:
		if node.has_meta(&"kit"):
			return "%s@%s" % [node.get_meta(&"kit"), node.get_meta(&"kit_room", &"")]
		node = node.get_parent()
		if node is Level:
			break
	var script := body.get_script() as Script
	var kind := script.get_global_name() if script != null else StringName(body.get_class())
	return "%s:%s" % [kind, body.name]


## The top of whatever solid stands in front of him along [param direction]
## (a ray down from 2.2 m over his feet, [param ahead] m out): its height
## over his feet (INF when nothing is under the ray there or the obstacle
## reaches higher than the ray starts).
func obstacle_top(direction: Vector3, ahead: float = 0.55) -> float:
	var flat := Vector3(direction.x, 0.0, direction.z).normalized()
	return top_at(feet() + flat * ahead)


## The height over his feet of the first solid a ray finds going down from
## 2.2 m over his feet at [param at] (x, z); INF when the ray starts inside
## something (taller than that) or finds nothing down to 0.3 m under them.
func top_at(at: Vector3) -> float:
	var from := Vector3(at.x, feet().y + 2.2, at.z)
	_ray.from = from
	_ray.to = Vector3(at.x, feet().y - 0.3, at.z)
	_ray.hit_from_inside = true
	var hit := space().intersect_ray(_ray)
	_ray.hit_from_inside = false
	if hit.is_empty() or (hit["position"] as Vector3).distance_to(from) < 0.001:
		return INF
	return (hit["position"] as Vector3).y - feet().y


## The highest top (top_at) of the contacts that stop him walking along
## [param direction] (their normal against it), from just behind each
## contact point to STEP_DEPTH m further in (a sloping rock that climbs
## past a step within a stride is no step); INF for a wall, -INF when
## nothing stops him.
func blocking_top(blockers: Array, direction: Vector3) -> float:
	var flat := Vector3(direction.x, 0.0, direction.z).normalized()
	var highest := -INF
	for contact: Dictionary in blockers:
		var normal: Vector3 = contact["normal"]
		if Vector3(normal.x, 0.0, normal.z).dot(flat) > -0.3:
			continue
		var inward := -Vector3(normal.x, 0.0, normal.z).normalized()
		for depth: float in [0.03, STEP_DEPTH * 0.5, STEP_DEPTH]:
			highest = maxf(highest, top_at((contact["point"] as Vector3) + inward * depth))
	return highest


## Why he does not step up where he stands, walking along
## [param direction] (as Player._step_up tries it): "" when nothing keeps
## him from it, else what his raised capsule runs into ("kit@room") or
## "steep" (what is under it there is no floor) or "low ceiling".
func step_blocker(direction: Vector3) -> String:
	var flat := Vector3(direction.x, 0.0, direction.z).normalized()
	var hit := KinematicCollision3D.new()
	var start := guard.global_transform
	var mask := guard.collision_mask
	guard.collision_mask = Layers.WORLD
	var why := ""
	var lift := Vector3.UP * Player.STEP_HEIGHT
	if guard.test_move(start, lift, hit):
		why = "low ceiling"
	elif guard.test_move(start.translated(lift), flat * Player.STEP_PROBE, hit):
		why = describe(hit.get_collider() as Node)
	elif not guard.test_move(start.translated(lift + flat * Player.STEP_PROBE), -lift - Vector3.UP * 0.05, hit) or hit.get_normal().angle_to(Vector3.UP) > guard.floor_max_angle:
		why = "steep"
	guard.collision_mask = mask
	return why


## A step's top is looked at this far in from its face (m).
const STEP_DEPTH := 0.3


## True when his capsule, lifted [param lift] m (over lips and steps he
## should take in his stride), sweeps from [param a] to [param b] (feet)
## without touching anything.
func sweeps_clear(a: Vector3, b: Vector3, lift: float = 0.4) -> bool:
	var capsule := _shape.shape as CapsuleShape3D
	capsule.radius = 0.4
	capsule.height = 1.8
	_shape.transform = Transform3D(Basis.IDENTITY, a + Vector3.UP * (0.9 + lift))
	_shape.motion = b - a
	var fraction := space().cast_motion(_shape)
	_shape.motion = Vector3.ZERO
	return fraction.size() == 2 and fraction[0] >= 1.0


## Walks along [param points] (feet positions; the first is where he
## stands) at a walk, steering at the next point like a player would.
## Returns {ok, reason ("" / "stuck" / "fell" / "timeout"), at, index (the
## leg he stopped on), blockers (contacts when stuck), top (height of the
## obstacle in front when stuck), slow: [[position, speed]...] (where his
## speed collapsed on the way, merged within 0.5 m), seconds}.
func follow(points: PackedVector3Array, timeout_slack: float = 2.0, jump_ledges: bool = false) -> Dictionary:
	var result := {"ok": false, "reason": "", "at": feet(), "index": 0, "blockers": [], "top": INF, "slow": [], "seconds": 0.0, "jumped": false}
	if points.size() < 2:
		result["ok"] = true
		return result
	var length := 0.0
	for i in range(1, points.size()):
		length += _flat(points[i] - points[i - 1]).length()
	var budget := length / guard.walk_speed + timeout_slack
	var leg := 1
	var leg_time := 0.0
	var best := INF
	var since_best := 0.0
	var time := 0.0
	var previous := feet()
	var slow: Array = []
	while time < budget:
		var goal := points[leg]
		var to_goal := _flat(goal - feet())
		if to_goal.length() <= ARRIVE:
			if leg == points.size() - 1:
				result["ok"] = true
				break
			leg += 1
			leg_time = 0.0
			best = INF
			since_best = 0.0
			continue
		var jump := false
		if jump_ledges and since_best > 0.25 and guard.is_on_floor():
			var top := obstacle_top(to_goal)
			if top != INF and top > 0.05:
				jump = true
				result["jumped"] = true
		step(to_goal, jump)
		time += DT
		leg_time += DT
		var moved := _flat(feet() - previous)
		previous = feet()
		var along := moved.dot(to_goal.normalized()) / DT
		if leg_time > ACCEL_TIME and along < guard.walk_speed * SLOW_SHARE and guard.is_on_floor():
			_note_slow(slow, feet(), along)
		var left := _flat(goal - feet()).length()
		if left < best - STALL_PROGRESS:
			best = left
			since_best = 0.0
		else:
			since_best += DT
		if feet().y < minf(goal.y, points[leg - 1].y) - FALL_DROP:
			result["reason"] = "fell"
			break
		if since_best >= STALL_TIME:
			result["reason"] = "stuck"
			result["blockers"] = contacts()
			result["top"] = blocking_top(result["blockers"], to_goal)
			result["no_step"] = step_blocker(to_goal)
			break
	if not result["ok"] and result["reason"] == "":
		result["reason"] = "timeout"
		result["blockers"] = contacts()
	result["at"] = feet()
	result["index"] = leg
	result["slow"] = slow
	result["seconds"] = time
	release()
	return result


static func _note_slow(slow: Array, at: Vector3, speed: float) -> void:
	for entry: Array in slow:
		if (entry[0] as Vector3).distance_to(at) < 0.5:
			entry[1] = minf(float(entry[1]), speed)
			return
	slow.append([at, speed])


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
