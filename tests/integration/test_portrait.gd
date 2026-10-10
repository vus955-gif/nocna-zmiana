extends TestCase
## The portrait ambusher: asleep it is an ordinary painting (untouchable),
## it wakes only by its own sight within 10 m, watches for 1.5 s, pushes
## out of the wall, spits paint (10) that leaves a slowing puddle, its eyes
## are the weak point, a taser shuts them for 3 s, it never moves.

## The wall is the plane z = 0 facing +Z; portraits hang on it facing +Z.
const WALL_FACING := Basis(Vector3.UP, PI)

var target: TargetDummy


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	Greybox.box(self, Vector3(0, 3, -0.25), Vector3(20, 6, 0.5), Color.GRAY)
	target = TargetDummy.new()
	target.position = Vector3(0, 0, 30)
	add_child(target)


func _portrait(id: StringName = &"countess") -> Portrait:
	var portrait := Portrait.create_on_wall(Transform3D(WALL_FACING, Vector3(0, 2.2, 0)), id)
	portrait.target = target
	add_child(portrait)
	return portrait


func _awake(portrait: Portrait) -> void:
	target.position = Vector3(0, 0, 6)
	for i in 200:
		await get_tree().physics_frame
		if portrait.vulnerable():
			break
	await physics_frames(30)   # the frame settles


func _holder(weapon: StringName, at: Vector3) -> WeaponHolder:
	var user := Node3D.new()
	add_child(user)
	var holder := WeaponHolder.new()
	holder.user = user
	holder.position = at
	user.add_child(holder)
	holder.give(load("res://src/weapons/data/%s.tres" % weapon))
	return holder


func test_ten_paintings_to_choose_from() -> void:
	var ids := PaintingArt.ids()
	assert_eq(ids.size(), 10)
	var pictures := {}
	for id in ids:
		var texture := PaintingArt.canvas_texture(id)
		assert_eq(texture.get_size(), Vector2(PaintingArt.TEXELS))
		pictures[texture.get_image().get_data()] = true
	assert_eq(pictures.size(), 10, "ten different canvases")


func test_asleep_it_looks_like_an_ordinary_painting() -> void:
	var portrait := _portrait()
	var plain := WallPainting.create(Transform3D(WALL_FACING, Vector3(4, 2.2, 0)), &"countess")
	add_child(plain)
	await physics_frames(2)
	var shared := ["canvas", "frame", "eyes"] if PaintingArt.has_model() else ["canvas", "frame", "eye_l", "eye_r", "pupil_l", "pupil_r", "mouth"]
	for part: String in shared:
		assert_not_null(portrait.visual.find_child(part, true, false), "portrait " + part)
		assert_not_null(plain.find_child(part, true, false), "painting " + part)
	var canvas_a := portrait.visual.find_child("canvas", true, false) as MeshInstance3D
	var canvas_b := plain.find_child("canvas", true, false) as MeshInstance3D
	var picture_a := canvas_a.get_active_material(0).resource_name if canvas_a.material_override == null else ""
	var picture_b := canvas_b.get_active_material(0).resource_name if canvas_b.material_override == null else ""
	assert_eq(picture_a, picture_b, "the same picture")
	assert_eq(portrait.pushed, 0.0, "flush with the wall")
	assert_eq(portrait.pupil_shift(), Vector3.ZERO, "looking straight out")


func test_asleep_it_cannot_be_hurt() -> void:
	var portrait := _portrait()
	var holder := _holder(&"pistol", Vector3(0, 2.2, 5))
	await physics_frames(2)
	holder.try_fire()
	assert_eq(portrait.health.current, 40.0)
	assert_false(portrait.vulnerable())


func test_eyes_follow_the_guard_then_the_frame_pushes_out() -> void:
	var portrait := _portrait()
	await physics_frames(2)
	target.position = Vector3(3, 0, 7)
	await physics_frames(20)
	assert_true(portrait.eyes_tracking(), "the eyes move first")
	assert_false(portrait.vulnerable(), "still flush and untouchable")
	await physics_frames(20)
	assert_gt(portrait.pupil_shift().x, 0.003, "looking toward the guard's side (world +X)")
	await physics_frames(45)   # 1.42 s since he came in view: still watching
	assert_false(portrait.vulnerable(), "it watches for 1.5 s first")
	await physics_frames(30)   # sight checks run every 0.2 s: out by 1.7 s
	assert_true(portrait.vulnerable(), "1.5 s later it comes out")
	await physics_frames(30)
	assert_almost_eq(portrait.pushed, Portrait.PUSH_OUT, 0.01)
	assert_almost_eq(portrait.global_position.z, 0.5, 0.01, "0.5 m out of the wall")


func test_it_sleeps_on_beyond_10_m_behind_a_wall_or_behind_it() -> void:
	var portrait := _portrait()
	await physics_frames(2)
	target.position = Vector3(0, 0, 11.5)
	await physics_frames(40)
	assert_eq(portrait.brain.state, EnemyBrain.State.DORMANT, "too far")
	Greybox.box(self, Vector3(0, 1.5, 3), Vector3(6, 3, 0.2), Color.GRAY)
	Greybox.box(self, Vector3(0, 3.2, 3), Vector3(6, 0.4, 0.2), Color.GRAY)
	target.position = Vector3(0, 0, 5)
	await physics_frames(40)
	assert_eq(portrait.brain.state, EnemyBrain.State.DORMANT, "behind a screen")
	target.position = Vector3(0, 0, -4)
	await physics_frames(40)
	assert_eq(portrait.brain.state, EnemyBrain.State.DORMANT, "behind the painting")


func test_noise_and_neighbours_do_not_wake_it() -> void:
	var portrait := _portrait()
	await physics_frames(2)
	EmergencyCabinet.wake_exhibits(Vector3(0, 1, 2), 16.0, get_tree())
	assert_eq(portrait.brain.state, EnemyBrain.State.DORMANT)


func test_spits_paint_that_hurts_and_leaves_a_slowing_puddle() -> void:
	var guard := Player.new()
	guard.position = Vector3(0, 0.05, 6)
	add_child(guard)
	var portrait := _portrait()
	portrait.target = guard
	var hurt := watch(Events.player_damaged)
	for i in 300:
		await get_tree().physics_frame
		if not hurt.is_empty():
			break
	assert_eq(hurt.size(), 1, "a gob hit him")
	assert_eq(guard.health.current, 90.0, "10 damage")
	await physics_frames(2)
	var puddle: PaintPuddle = null
	for child in get_children():
		if child is PaintPuddle:
			puddle = child
	assert_not_null(puddle, "a puddle on the floor")
	if puddle != null:
		assert_lt(Vector2(puddle.global_position.x - guard.global_position.x, puddle.global_position.z - guard.global_position.z).length(), 1.5, "at his feet")


func test_the_puddle_slows_by_40_percent_for_3_s() -> void:
	var guard := Player.new()
	guard.position = Vector3(0, 0.05, 10)
	add_child(guard)
	await physics_frames(3)
	var puddle := PaintPuddle.spill(self, Vector3(0, 0.5, 9.2), Color.RED)
	assert_not_null(puddle)
	Input.action_press(&"move_forward")
	await physics_frames(12)
	var speed := Vector2(guard.velocity.x, guard.velocity.z).length()
	Input.action_release(&"move_forward")
	assert_almost_eq(speed, guard.walk_speed * 0.6, 0.05, "40% slower in paint")
	await physics_frames(3 * 60)
	assert_false(is_instance_valid(puddle) and not puddle.is_queued_for_deletion(), "dried after 3 s")


func test_the_eyes_are_the_weak_point() -> void:
	var portrait := _portrait()
	await _awake(portrait)
	var holder := _holder(&"pistol", Vector3(0, 0, 6))
	var aim := portrait.eye_on_canvas(1.0)
	holder.look_at_from_position(Vector3(aim.x, aim.y, 6), aim)
	var destroyed := watch(Events.enemy_destroyed)
	await physics_frames(1)
	holder.try_fire()
	assert_eq(destroyed.size(), 1, "one pistol shot in the eye (x2) breaks its 40")


func test_a_body_shot_does_20() -> void:
	var portrait := _portrait()
	await _awake(portrait)
	var holder := _holder(&"pistol", Vector3(0.3, 1.8, 6))
	holder.look_at_from_position(Vector3(0.3, 1.8, 6), portrait.global_transform * Vector3(0.3, -0.4, 0.0))
	await physics_frames(1)
	holder.try_fire()
	assert_eq(portrait.health.current, 20.0)


func test_taser_shuts_its_eyes_for_3_s_and_it_never_moves() -> void:
	var portrait := _portrait()
	await _awake(portrait)
	var anchor := portrait.global_position
	var info := DamageInfo.make(4.0, DamageInfo.Kind.ELECTRIC, target)
	info.stun_time = 3.0
	info.knockback = 30.0
	info.direction = Vector3(0, 0, -1)
	portrait.take_damage(info)
	assert_true(portrait.brain.is_stunned())
	await physics_frames(2)
	assert_true((portrait.visual.find_child("lid_l", true, false) as Node3D).visible, "eyes shut")
	await physics_frames(170)
	assert_true(portrait.brain.is_stunned(), "2.9 s")
	await physics_frames(12)
	assert_false(portrait.brain.is_stunned(), "3 s")
	assert_true(portrait.global_position.is_equal_approx(anchor), "never moved an inch")


## A flare at a sleeping portrait meets the canvas like the wall: no
## burning, no blast damage, it sleeps on.
func test_a_flare_on_a_sleeping_portrait_does_not_hurt_it() -> void:
	var portrait := _portrait()
	await physics_frames(2)
	assert_eq(portrait.collision_layer, 0, "asleep it is no body")
	for x in [-0.3, 0.0, 0.3]:
		var holder := _holder(&"flare", Vector3(x, 2.0, 6.0))
		holder.look_at(Vector3(x * 0.3, 2.2, 0.0))
		await physics_frames(2)
		holder.try_fire()
		await physics_frames(20)
		for child in get_children():
			var light := child as FlareLight
			if light != null:
				assert_ne(light.host, portrait, "it sticks to the canvas as to the wall")
		holder.get_parent().queue_free()
	await physics_frames(120)
	assert_eq(portrait.health.current, 40.0, "untouched")
	assert_false(portrait.vulnerable())


## Out of the wall its frame is a body (flares stick, exhibits bump), but
## the guard walking along the wall under it is not stopped by it.
func test_awake_its_frame_does_not_stop_the_guard() -> void:
	var guard := Player.new()
	guard.position = Vector3(0, 0.05, 6)
	add_child(guard)
	var portrait := Portrait.create_on_wall(Transform3D(WALL_FACING, Vector3(0, 1.6, 0)), &"countess")
	portrait.target = guard
	add_child(portrait)
	for i in 200:
		await get_tree().physics_frame
		if portrait.vulnerable():
			break
	await physics_frames(30)
	assert_eq(portrait.collision_layer, Layers.ENEMY, "a body once out")
	assert_true(guard.get_collision_exceptions().has(portrait), "no bumping the guard's head")
	guard.global_position = Vector3(-2.0, 0.05, 0.6)
	guard.velocity = Vector3(4.0, 0, 0)
	for i in 30:
		guard.velocity.x = 4.0
		guard.move_and_slide()
		await get_tree().physics_frame
	assert_gt(guard.global_position.x, 1.0, "he walks on under the frame")
