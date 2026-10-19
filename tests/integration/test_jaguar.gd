extends TestCase
## The jaguar warrior (design pietro-1-projekt 5.6) in a sandbox: 70 HP of
## carved wood, a pounce from 6 m that ends in a club blow after landing
## (never in the air), the club from up close, a step aside during the leap
## dodging the blow, a low sprint on all fours, four pistol shots and its
## dust, a statue asleep.

var target: TargetDummy


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color.GRAY)
	target = TargetDummy.new()
	target.position = Vector3(0, 0, -6)
	add_child(target)


func _jaguar(at: Vector3 = Vector3.ZERO) -> Jaguar:
	var jaguar := Jaguar.new()
	jaguar.position = at
	jaguar.target = target
	add_child(jaguar)
	jaguar.face(target.global_position)
	return jaguar


## Frames until the target is hit (or [param limit]); the frame of the
## brain's strike (the leap / the raise's end) is left in [param marks].
func _until_hit(jaguar: Jaguar, limit: int, marks: Dictionary) -> int:
	var strikes := watch(jaguar.brain.strike)
	for frame in limit:
		await get_tree().physics_frame
		if not strikes.is_empty() and not marks.has("strike"):
			marks["strike"] = frame
		if not target.hits.is_empty():
			marks["phase"] = jaguar.phase()
			marks["floor"] = jaguar.is_on_floor()
			return frame
	return limit


func test_is_a_carved_warrior_of_seventy_hp() -> void:
	var jaguar := _jaguar()
	assert_eq(Jaguar.KIND, &"jaguar")
	assert_eq(jaguar.health.max_health, 70.0)
	assert_eq(jaguar.dust_value, 5)
	assert_eq(jaguar.material_kind, ExhibitMaterial.Kind.WOOD)
	assert_true(jaguar.rig is JaguarRig, "the Blender model is on")
	var made := NightSpawner.make(&"jaguar")
	assert_true(made is Jaguar)
	made.free()
	var kinds: Array[StringName] = [&"wolf", &"jaguar"]
	assert_eq(NightSpawner.preferred(kinds, &"wolf"), &"jaguar", "the Americas' slots now get jaguar warriors")


func test_a_pounce_from_six_metres_ends_in_a_club_blow_after_landing() -> void:
	var jaguar := _jaguar()
	await physics_frames(2)
	jaguar.brain.wake()
	var marks := {}
	var hit_frame := await _until_hit(jaguar, 300, marks)
	assert_eq(target.hits.size(), 1, "one blow")
	if target.hits.is_empty():
		return
	assert_eq(target.hits[0].amount, JaguarMoves.CLUB_DAMAGE)
	assert_eq(target.hits[0].knockback, JaguarMoves.CLUB_KNOCKBACK)
	assert_true(marks.has("strike"), "it leapt")
	var after_leap := (hit_frame - int(marks.get("strike", 0))) / 60.0
	var earliest := JaguarMoves.airtime(JaguarMoves.LIFT, Enemy.GRAVITY) + JaguarMoves.swing_time() - 0.05
	assert_gt(after_leap, earliest, "the blow comes after the flight, the settle and the swing (%.2f s)" % after_leap)
	assert_true(marks.get("floor", false), "on the floor when it strikes")
	assert_eq(marks.get("phase"), JaguarMoves.Phase.STUCK, "the club is in the floor the moment it lands its blow")
	assert_lt(jaguar.global_position.distance_to(target.global_position), JaguarMoves.SWING_REACH + 0.1, "it landed within the club's reach")
	assert_gt(jaguar.global_position.distance_to(target.global_position), 0.8, "and short of him")


func test_the_club_from_up_close() -> void:
	target.position = Vector3(0, 0, -2)
	var jaguar := _jaguar()
	await physics_frames(2)
	jaguar.brain.wake()
	var marks := {}
	var hit_frame := await _until_hit(jaguar, 240, marks)
	assert_eq(target.hits.size(), 1, "one blow")
	if target.hits.is_empty():
		return
	assert_eq(target.hits[0].amount, JaguarMoves.CLUB_DAMAGE)
	var swing := (hit_frame - int(marks.get("strike", 0))) / 60.0
	assert_almost_eq(swing, JaguarMoves.SWING, 0.06, "the raise ends, the club comes down in %.2f s" % swing)
	assert_true(jaguar.global_position.y < 0.3, "no leap")


func test_a_step_aside_during_the_leap_dodges_the_club() -> void:
	var jaguar := _jaguar()
	await physics_frames(2)
	jaguar.brain.wake()
	for frame in 240:
		await get_tree().physics_frame
		if jaguar.leaping():
			break
	assert_true(jaguar.leaping(), "it is in the air")
	var changes := watch(jaguar.brain.state_changed)
	target.position = Vector3(3.5, 0, -4.6)   # steps aside as it flies
	await physics_frames(150)
	assert_eq(target.hits.size(), 0, "the club finds only the floor")
	var recovered := changes.any(func(c: Array) -> bool: return c[0] == EnemyBrain.State.ATTACK and c[1] == EnemyBrain.State.HUNT)
	assert_true(recovered, "it pulled the club out of the floor and hunted on")


func test_hunting_it_runs_low_on_all_fours() -> void:
	target.position = Vector3(0, 0, -30)
	var jaguar := _jaguar()
	await physics_frames(2)
	var standing := jaguar.rig.tracked_position(jaguar.head_zone).y if jaguar.rig != null else Jaguar.HEAD_AT.y
	assert_gt(standing, 1.5, "the helmet at about 1.7 m standing")
	jaguar.summoned = true
	jaguar.brain.wake()
	await physics_frames(90)
	assert_true(jaguar.sprinting(), "sprinting (%.1f m/s)" % Vector2(jaguar.velocity.x, jaguar.velocity.z).length())
	assert_gt(Vector2(jaguar.velocity.x, jaguar.velocity.z).length(), 5.5)
	if jaguar.rig != null:
		var low := jaguar.rig.tracked_position(jaguar.head_zone).y
		assert_lt(low, 1.2, "the helmet rides down to %.2f m" % low)
		assert_lt(jaguar.head_zone.position.y, 1.2, "the hit zone followed")


## On all fours its fore paws reach the floor (the model's arms are short:
## the hips drop and tip, the spine pitches past the horizontal, the
## shoulders slide down) and nothing of it sinks into the floor: over two
## strides each paw (the club hand on its knuckles) touches it in turn, the
## hind feet plant, the shins, the tail, the club and the shield stay over it.
func test_sprinting_its_paws_reach_the_floor_and_nothing_sinks() -> void:
	target.position = Vector3(0, 0, -40)
	var jaguar := _jaguar()
	await physics_frames(2)
	if jaguar.rig == null:
		return
	jaguar.summoned = true
	jaguar.brain.wake()
	await physics_frames(90)
	assert_true(jaguar.sprinting(), "sprinting")
	var lowest := {}
	for frame in 50:
		await get_tree().physics_frame
		if not jaguar.sprinting():
			continue
		for part: String in ["forearm_l", "forearm_r", "foot_l", "foot_r", "shin_l", "shin_r", "tail_2", "club", "shield"]:
			lowest[part] = minf(lowest.get(part, INF), _lowest(jaguar.rig.part(part) as MeshInstance3D))
	for paw: String in ["forearm_l", "forearm_r"]:
		assert_lt(lowest.get(paw, INF), 0.06, "%s reaches the floor (its lowest %.3f m)" % [paw, lowest.get(paw, INF)])
		assert_gt(lowest.get(paw, -INF), -0.03, "%s stays on it (%.3f m)" % [paw, lowest.get(paw, -INF)])
	for foot: String in ["foot_l", "foot_r"]:
		assert_lt(lowest.get(foot, INF), 0.04, "%s plants (%.3f m)" % [foot, lowest.get(foot, INF)])
		assert_gt(lowest.get(foot, -INF), -0.03, "%s does not sink (%.3f m)" % [foot, lowest.get(foot, -INF)])
	for part: String in ["shin_l", "shin_r", "tail_2", "club", "shield"]:
		assert_gt(lowest.get(part, -INF), -0.04, "%s stays over the floor (%.3f m)" % [part, lowest.get(part, -INF)])


## The lowest point (world y) of [param view]'s mesh.
func _lowest(view: MeshInstance3D) -> float:
	if view == null or view.mesh == null:
		return INF
	var xf := view.global_transform
	var low := INF
	for s in view.mesh.get_surface_count():
		for v: Vector3 in view.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			low = minf(low, (xf * v).y)
	return low


func test_four_pistol_shots_bring_it_down_with_its_dust() -> void:
	var jaguar := _jaguar()
	await physics_frames(2)
	var destroyed := watch(Events.enemy_destroyed)
	for i in 3:
		var shot := DamageInfo.make(20.0, DamageInfo.Kind.BALLISTIC, target)
		shot.direction = Vector3(0, 0, 1)
		shot.position = jaguar.global_position + Vector3.UP * 1.3
		jaguar.take_damage(shot)
	assert_eq(destroyed.size(), 0, "ten hit points left")
	assert_eq(jaguar.health.current, 10.0)
	var last := DamageInfo.make(20.0, DamageInfo.Kind.BALLISTIC, target)
	last.direction = Vector3(0, 0, 1)
	last.position = jaguar.global_position + Vector3.UP * 1.3
	jaguar.take_damage(last)
	assert_eq(destroyed.size(), 1, "the fourth shot")


func test_asleep_it_is_a_statue_that_wakes_with_weight() -> void:
	target.position = Vector3(0, 0, -30)
	var jaguar := _jaguar()
	await physics_frames(30)
	var rig := jaguar.rig as JaguarRig
	if rig == null:
		return
	assert_gt(rig.statue(), 0.95, "a statue on its post")
	assert_eq(jaguar.brain.state, EnemyBrain.State.DORMANT)
	jaguar.hear(Vector3(4, 0, -4))
	await physics_frames(60)
	assert_lt(rig.statue(), 0.1, "alive within a second")
	assert_ne(jaguar.brain.state, EnemyBrain.State.DORMANT)


## The witching hour (NightWatch.boost on a live exhibit) multiplies move_speed;
## the sprint is its walk times SPRINT / WALK, so the boost reaches the sprint
## and is not written over each frame.
func test_the_witching_hour_hurries_the_walk_and_the_sprint() -> void:
	target.position = Vector3(0, 0, -30)
	var jaguar := _jaguar()
	await physics_frames(2)
	NightWatch.boost(jaguar)
	jaguar.summoned = true
	jaguar.brain.wake()
	await physics_frames(90)
	assert_true(jaguar.sprinting())
	var run := Vector2(jaguar.velocity.x, jaguar.velocity.z).length()
	assert_almost_eq(run, Jaguar.SPRINT * NightWatch.WITCHING_BOOST, 0.3, "sprinting 20 %% faster (%.1f m/s)" % run)
	assert_almost_eq(jaguar.move_speed, Jaguar.WALK * NightWatch.WITCHING_BOOST, 0.001, "the boost is still on its walk")
