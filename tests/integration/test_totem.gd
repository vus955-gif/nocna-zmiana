extends TestCase
## The Totem (design pietro-1-projekt 5.6) in a sandbox: 30 HP a face,
## shot off from the top (a lower face only dents), its eyes glow before it
## spits, a hit shard hurts the guard, fewer faces spit faster, the last
## face takes the pole down with its dust, it never counts as a hunter, and
## waking its faces turn one after another toward the guard.

var target: TargetDummy


func before_each() -> void:
	GameInput.capture_allowed = false
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color.GRAY)
	target = TargetDummy.new()
	target.position = Vector3(0, 0, -8)
	add_child(target)


func after_each() -> void:
	GameInput.capture_allowed = true


func _totem(faces: int, at: Vector3 = Vector3.ZERO, who: Node3D = null) -> Totem:
	var totem := Totem.new()
	totem.faces = faces
	totem.position = at
	totem.target = who if who != null else target
	add_child(totem)
	return totem


## A 30-damage pistol-like hit from the front on face [param face] (0 = the
## stump) of [param totem].
func _hit_face(totem: Totem, face: int, amount: float = 30.0) -> DamageInfo:
	var info := DamageInfo.make(amount, DamageInfo.Kind.BALLISTIC, target)
	info.direction = Vector3(0, 0, 1)
	info.position = totem.global_position + Vector3(0.0, TotemFaces.face_height(face), -0.48)
	totem.take_damage(info)
	return info


func _shards() -> Array[Projectile]:
	var found: Array[Projectile] = []
	for child in get_children():
		var shot := child as Projectile
		if shot != null and not shot.is_queued_for_deletion():
			found.append(shot)
	return found


func test_is_a_cedar_pole_of_thirty_hp_faces() -> void:
	var totem := _totem(5)
	assert_eq(Totem.KIND, &"totem")
	assert_eq(totem.health.max_health, 150.0)
	assert_eq(totem.faces_now(), 5)
	assert_eq(totem.dust_value, 15)
	assert_eq(totem.material_kind, ExhibitMaterial.Kind.WOOD)
	assert_false(totem.counts_as_hunter(), "a pole does not chase: no place in the hunter cap")
	assert_true(totem.rig is TotemRig, "the Blender model is on")
	var placed := _totem(0, Vector3(6, 0, 3))
	assert_true(placed.faces >= 3 and placed.faces <= 5, "faces from its place: %d" % placed.faces)
	assert_eq(placed.health.max_health, 30.0 * placed.faces)
	assert_eq(placed.faces, TotemFaces.count_for(placed.global_position), "the same place, the same pole")
	var made := NightSpawner.make(&"totem")
	assert_true(made is Totem)
	made.free()
	var kinds: Array[StringName] = [&"bust", &"totem"]
	assert_eq(NightSpawner.preferred(kinds, &"bust"), &"totem", "the Americas' slots now get totems")


func test_shot_from_the_top_the_faces_fall_one_by_one() -> void:
	var totem := _totem(5)
	await physics_frames(2)
	_hit_face(totem, 5)
	assert_eq(totem.faces_now(), 4, "the eagle is gone")
	assert_eq(totem.health.current, 120.0)
	var rig := totem.rig as TotemRig
	if rig != null:
		assert_false(rig.part("block_5").visible, "the top block fell off the model")
		assert_true(rig.part("block_4").visible)
	_hit_face(totem, 2)
	assert_eq(totem.faces_now(), 4, "a lower face is dead wood")
	assert_almost_eq(totem.health.current, 120.0 - 30.0 * TotemFaces.LOWER_FACTOR, 0.01)
	_hit_face(totem, 0)
	assert_almost_eq(totem.health.current, 120.0 - 60.0 * TotemFaces.LOWER_FACTOR, 0.01, "the stump too")
	await physics_frames(100)
	if rig != null:
		assert_almost_eq(rig.cap_height(), TotemFaces.top_of(4), 0.12, "the hat came down onto the fourth face")


func test_the_top_face_is_the_weak_point_and_it_moves_down() -> void:
	var totem := _totem(5)
	await physics_frames(2)
	var space := totem.get_world_3d().direct_space_state
	var top := TotemFaces.face_height(5)
	var hit := Hitscan.ray(space, Vector3(0, top, -5), Vector3(0, top, 5))
	assert_not_null(hit.get("hurtbox"), "the eagle's face is a zone")
	if hit.get("hurtbox") != null:
		assert_true((hit["hurtbox"] as Hurtbox).weak_point, "the top face is the weak point")
	var third := TotemFaces.face_height(3)
	var lower := Hitscan.ray(space, Vector3(0, third, -5), Vector3(0, third, 5))
	assert_not_null(lower.get("hurtbox"))
	if lower.get("hurtbox") != null:
		assert_false((lower["hurtbox"] as Hurtbox).weak_point, "a lower face is not")
	_hit_face(totem, 5)
	await physics_frames(2)
	var fourth := TotemFaces.face_height(4)
	var next := Hitscan.ray(space, Vector3(0, fourth, -5), Vector3(0, fourth, 5))
	assert_not_null(next.get("hurtbox"))
	if next.get("hurtbox") != null:
		assert_true((next["hurtbox"] as Hurtbox).weak_point, "the weak point moved down to the ancestor")
	var gone := Hitscan.ray(space, Vector3(0, top, -5), Vector3(0, top, 5))
	assert_true(gone.is_empty() or gone.get("hurtbox") == null, "nothing left to hit where the eagle was")


func test_its_eyes_glow_before_it_spits_and_the_shard_hurts_the_guard() -> void:
	target.queue_free()
	var guard := Player.new()
	guard.position = Vector3(0, 0.05, -8)
	add_child(guard)
	var totem := _totem(5, Vector3.ZERO, guard)
	await physics_frames(2)
	totem.brain.wake()
	var glow_frame := -1
	var shot_frame := -1
	for frame in 300:
		await get_tree().physics_frame
		if glow_frame < 0:
			for face in range(1, 6):
				if totem.face_glow(face) > 0.3:
					glow_frame = frame
					break
		if not _shards().is_empty():
			shot_frame = frame
			break
	assert_gt(shot_frame, -1, "it spat")
	assert_gt(glow_frame, -1, "its eyes lit up")
	if shot_frame >= 0 and glow_frame >= 0:
		assert_gt(shot_frame - glow_frame, 35, "eyes glow at least 0.6 s before the shot (%d frames)" % (shot_frame - glow_frame))
	var shards := _shards()
	if not shards.is_empty():
		assert_almost_eq(shards[0].velocity.length(), Totem.SPIT_SPEED, 0.01)
		assert_eq(shards[0].material_kind, ExhibitMaterial.Kind.WOOD)
	for frame in 120:
		await get_tree().physics_frame
		if guard.health.current < guard.health.max_health:
			break
	assert_eq(guard.health.current, guard.health.max_health - Totem.SPIT_DAMAGE, "the shard found his chest")


func test_only_a_face_aimed_at_the_guard_spits() -> void:
	# a wall between the pole and the guard: no face has a clear line
	Greybox.box(self, Vector3(0, 3, -4), Vector3(8, 6, 0.3), Color.GRAY)
	var totem := _totem(5)
	await physics_frames(2)
	totem.brain.wake()
	await physics_frames(200)
	assert_eq(_shards().size(), 0, "no shard through a wall")


## Seconds between the first two shots of a pole of [param faces] faces.
func _shot_gap(faces: int) -> float:
	var totem := _totem(faces)
	await physics_frames(2)
	totem.brain.wake()
	var seen: Dictionary = {}
	var frames: Array[int] = []
	for frame in 420:
		await get_tree().physics_frame
		for shot in _shards():
			if not seen.has(shot):
				seen[shot] = true
				frames.append(frame)
		if frames.size() >= 2:
			break
	totem.queue_free()
	for shot in _shards():
		shot.queue_free()
	await physics_frames(2)
	if frames.size() < 2:
		fail("a pole of %d faces spat %d times in 7 s" % [faces, frames.size()])
		return INF
	return (frames[1] - frames[0]) / 60.0


func test_fewer_faces_spit_faster() -> void:
	var five := await _shot_gap(5)
	var two := await _shot_gap(2)
	assert_almost_eq(five, TotemFaces.interval(5), 0.15, "five faces: a shot every 2 s")
	assert_almost_eq(two, TotemFaces.interval(2), 0.15, "two faces: every 1.1 s")
	assert_gt(five - two, 0.6)


func test_a_hit_in_the_telegraph_on_the_spitting_face_calls_the_shot_off() -> void:
	var totem := _totem(5)
	await physics_frames(2)
	totem.brain.wake()
	for frame in 150:
		await get_tree().physics_frame
		if totem.brain.state == EnemyBrain.State.ATTACK:
			break
	assert_eq(totem.brain.state, EnemyBrain.State.ATTACK, "it winds up a shot")
	var face := totem.firing_face()
	assert_eq(face, 5, "the top face has the guard in its sights")
	_hit_face(totem, face)
	assert_eq(totem.faces_now(), 4)
	assert_ne(totem.brain.state, EnemyBrain.State.ATTACK, "the shooting face is gone: the shot with it")
	await physics_frames(10)
	assert_eq(_shards().size(), 0)


func test_the_last_face_takes_the_pole_down_with_its_dust() -> void:
	var totem := _totem(3)
	await physics_frames(2)
	assert_eq(totem.dust_value, 9)
	var destroyed := watch(Events.enemy_destroyed)
	_hit_face(totem, 3)
	_hit_face(totem, 2)
	assert_eq(totem.faces_now(), 1)
	assert_eq(destroyed.size(), 0, "one face still stands")
	_hit_face(totem, 1)
	assert_eq(destroyed.size(), 1, "the pole comes down")


func test_waking_its_faces_turn_one_after_another_toward_the_guard() -> void:
	target.position = Vector3(8, 0, 0)   # off to its right
	var totem := _totem(5)
	await physics_frames(2)
	for face in range(1, 6):
		assert_almost_eq(totem.face_yaw(face), 0.0, 0.001, "asleep every face looks out front")
	totem.brain.wake()
	await physics_frames(12)   # 0.2 s: the bear has begun, the ancestor (0.54 s) has not
	assert_gt(absf(totem.face_yaw(1)), 0.05, "the lowest face turns first")
	assert_lt(absf(totem.face_yaw(4)), 0.001, "the fourth waits its turn")
	await physics_frames(180)
	var toward := totem.yaw_to(target.global_position)
	for face in range(1, 6):
		assert_lt(absf(angle_difference(totem.face_yaw(face) + totem.home_yaw, toward)), 0.15, "face %d on the guard" % face)


## A pole that fell asleep again turned its faces home at half rate; its model
## has to follow them all the way (the rig used to stop posing 1.5 s after the
## brain went dormant, leaving a block frozen mid-turn).
func test_a_pole_that_falls_asleep_again_has_its_blocks_home() -> void:
	target.position = Vector3(8, 0, 0)   # off to its right
	var totem := _totem(5)
	await physics_frames(2)
	totem.brain.wake()
	await physics_frames(180)
	assert_gt(absf(totem.face_yaw(1)), 1.0, "every face has turned toward the guard")
	target.position = Vector3(0, 0, 60)   # he is gone, behind it: it searches there, goes home, sleeps
	for frame in 2400:
		await get_tree().physics_frame
		if totem.brain.state == EnemyBrain.State.DORMANT:
			break
	assert_eq(totem.brain.state, EnemyBrain.State.DORMANT, "it fell asleep again")
	var away := 0.0
	for face in range(1, 6):
		away = maxf(away, absf(totem.face_yaw(face)))
	assert_gt(away, 0.5, "some face was still turned away when it dropped off (%.2f rad)" % away)
	await physics_frames(300)
	for face in range(1, 6):
		assert_almost_eq(totem.face_yaw(face), 0.0, 0.01, "face %d looks out front" % face)
	var rig := totem.rig as TotemRig
	if rig != null:
		for face in range(1, 6):
			var forward := rig.part_transform("block_%d" % face).basis * Vector3.FORWARD
			assert_lt(absf(atan2(-forward.x, -forward.z)), 0.05, "block %d is home on the model" % face)


## Fire eats the whole pole: a burn tick sits where the flames are (low), but
## it is not a hit on a lower face.
func test_burning_hurts_the_pole_whatever_the_height_of_the_flames() -> void:
	var totem := _totem(5)
	await physics_frames(2)
	var tick := DamageInfo.make(10.0, DamageInfo.Kind.FIRE, target)
	tick.periodic = true
	tick.direction = Vector3.DOWN
	tick.position = totem.global_position + Vector3(0.0, 0.9, 0.0)
	totem.take_damage(tick)
	assert_almost_eq(totem.health.current, 140.0, 0.01, "the full tick, not dead wood")
	var hit := DamageInfo.make(10.0, DamageInfo.Kind.FIRE, target)
	hit.position = totem.global_position + Vector3(0.0, 0.9, 0.0)
	totem.take_damage(hit)
	assert_almost_eq(totem.health.current, 140.0 - 10.0 * TotemFaces.LOWER_FACTOR, 0.01, "a blow low on the pole is still dead wood")


## A patrolling pole that has seen and heard nothing has no point to watch
## (its brain remembers the world origin by default).
func test_an_awake_pole_that_noticed_nothing_keeps_its_faces_to_the_front() -> void:
	target.position = Vector3(0, 0, -60)   # beyond sight
	var totem := Totem.new()
	totem.faces = 4
	totem.starts_awake = true
	totem.position = Vector3(5, 0, 5)   # the world origin is off to its left-front
	totem.target = target
	add_child(totem)
	await physics_frames(240)
	assert_ne(totem.brain.state, EnemyBrain.State.DORMANT, "it is up and about")
	for face in range(1, 5):
		assert_almost_eq(totem.face_yaw(face), 0.0, 0.01, "face %d has nothing to look at" % face)


## A caller that sets the Dust (the guardians' called exhibits are worth one)
## keeps it; the default follows the faces.
func test_a_dust_value_set_by_the_caller_is_kept() -> void:
	var called := Totem.new()
	called.faces = 3
	called.dust_value = 1
	add_child(called)
	assert_eq(called.dust_value, 1)
	var plain := Totem.new()
	plain.faces = 3
	add_child(plain)
	assert_eq(plain.dust_value, 9)


## The face that comes off and the pole that dies with it break once, not twice.
func test_a_killing_blow_breaks_the_wood_once() -> void:
	var totem := _totem(1)
	await physics_frames(2)
	Sfx.stop_all()
	_hit_face(totem, 1)
	assert_eq(_voices(&"break_wood"), 1, "one crack for the last face")
	var two := _totem(5)
	await physics_frames(2)
	Sfx.stop_all()
	_hit_face(two, 5, 70.0)
	assert_eq(two.faces_now(), 3, "two faces at once")
	assert_eq(_voices(&"break_wood"), 1, "one crack for the blow")


## How many voices of [param sound] Sfx plays now.
func _voices(sound: StringName) -> int:
	var count := 0
	for voice in Sfx.get_children():
		if voice.get_meta(&"sound", &"") == sound and not voice.is_queued_for_deletion():
			count += 1
	return count
