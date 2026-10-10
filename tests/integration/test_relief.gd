extends TestCase
## The relief figures of Assyria (design pietro-1-projekt 5.2): asleep in
## a panel on the wall, untouchable until the panel has cracked and the
## figure stepped out; flat (edge hits half, the eye a weak point); the
## warrior's thrown spear, stab, sidestep and his trip through the wall;
## the lion's pounce.

## The wall's face: z = WALL_Z, facing -Z (into the room).
const WALL_Z := 0.0


func before_each() -> void:
	GameInput.capture_allowed = false
	Greybox.box(self, Vector3(0, -0.5, -10), Vector3(60, 1, 40), Color.GRAY)
	Greybox.box(self, Vector3(0, 2.0, WALL_Z + 0.5), Vector3(30, 4, 1), Color.DIM_GRAY)


func after_each() -> void:
	GameInput.capture_allowed = true


func _warrior(at: Vector3, target: Node3D) -> ReliefWarrior:
	var warrior := ReliefWarrior.new()
	warrior.position = at
	warrior.target = target
	add_child(warrior)
	warrior.face(at + Vector3(0, 0, -5))
	return warrior


func _dummy(at: Vector3) -> TargetDummy:
	var dummy := TargetDummy.new()
	dummy.position = at
	add_child(dummy)
	return dummy


func _wake(figure: Enemy) -> void:
	figure.summoned = true
	figure.brain.wake()


## Hits [param figure] with 20 travelling along [param direction]; the
## damage that landed.
func _hit(figure: Enemy, direction: Vector3) -> float:
	var info := DamageInfo.make(20.0, DamageInfo.Kind.BALLISTIC)
	info.direction = direction
	info.position = figure.global_position + Vector3.UP
	var before := figure.health.current
	figure.take_damage(info)
	return before - figure.health.current


func test_the_warrior_is_a_50_health_relief() -> void:
	var warrior := _warrior(Vector3(0, 0, -0.6), null)
	assert_eq(warrior.health.max_health, 50.0)
	assert_eq(warrior.dust_value, 5)
	assert_eq(warrior.material_kind, ExhibitMaterial.Kind.MARBLE)
	assert_true(warrior.rig is ReliefRig)
	for kind: StringName in [&"relief_warrior", &"relief_lion"]:
		var made := NightSpawner.make(kind)
		assert_true(made is ReliefWarrior if kind == &"relief_warrior" else made is ReliefLion, String(kind))
		made.free()


func test_asleep_it_is_part_of_a_panel_on_the_wall_and_cannot_be_hurt() -> void:
	var warrior := _warrior(Vector3(1, 0, -0.6), _dummy(Vector3(0, 0, 20)))
	await physics_frames(5)
	var panel := warrior.wall.panel
	assert_not_null(panel, "a panel on its wall")
	assert_false(warrior.wall.stele)
	assert_almost_eq(panel.global_position.z, WALL_Z, 0.05, "on the wall's face")
	assert_almost_eq(warrior.global_position.z, WALL_Z - ReliefMoves.FLUSH, 0.05, "flush in it")
	assert_lt((-warrior.global_basis.z).distance_to(Vector3.FORWARD), 0.05, "facing out")
	assert_eq(_hit(warrior, Vector3.BACK), 0.0, "stone of the wall")
	if panel.figure != null:
		assert_true(panel.shows_figure(), "the slab's carved figure is the warrior")
		assert_false(warrior.rig.model.visible, "its own model waits hidden")


func test_woken_the_panel_cracks_and_glows_then_it_steps_out() -> void:
	var warrior := _warrior(Vector3(1, 0, -0.6), _dummy(Vector3(0, 0, -20)))
	await physics_frames(5)
	_wake(warrior)
	await physics_frames(30)
	assert_eq(warrior.wall.state, ReliefMoves.Wall.CRACKING)
	assert_gt(warrior.wall.crack_level(), 0.4, "half cracked by 0.5 s")
	assert_eq(_hit(warrior, Vector3.BACK), 0.0, "still the wall")
	await physics_frames(50)
	assert_eq(warrior.wall.state, ReliefMoves.Wall.OUT)
	assert_almost_eq(warrior.global_position.z, WALL_Z - ReliefMoves.FLUSH - ReliefMoves.STEP_OUT, 0.15, "out in the room")
	assert_true(warrior.wall.panel.is_empty(), "an empty pocket where it stood")
	assert_true(warrior.rig.model.visible, "the warrior itself out in the room")
	assert_gt(_hit(warrior, Vector3.BACK), 0.0, "now it can be hurt")


func test_it_is_flat_its_edge_takes_half() -> void:
	var warrior := _warrior(Vector3(1, 0, -0.6), _dummy(Vector3(0, 0, -20)))
	await physics_frames(5)
	_wake(warrior)
	await physics_frames(90)
	var facing := warrior.carved_face()
	assert_almost_eq(_hit(warrior, -facing), 20.0, 0.01, "on its carved face")
	assert_almost_eq(_hit(warrior, facing.cross(Vector3.UP)), 10.0, 0.01, "on its edge")


func test_its_eye_is_the_weak_point() -> void:
	var warrior := _warrior(Vector3(1, 0, -0.6), _dummy(Vector3(0, 0, -20)))
	await physics_frames(5)
	_wake(warrior)
	await physics_frames(90)
	var eye := warrior.global_transform * warrior.rig.tracked_position(_eye_zone(warrior))
	var space := get_viewport().find_world_3d().direct_space_state
	var face := warrior.carved_face()
	var hit := Hitscan.ray(space, eye + face * 5.0, eye - face * 0.3)
	assert_false(hit.is_empty())
	if not hit.is_empty():
		assert_not_null(hit["hurtbox"])
		if hit["hurtbox"] != null:
			assert_true((hit["hurtbox"] as Hurtbox).weak_point)


func _eye_zone(figure: Enemy) -> Hurtbox:
	for child in figure.get_children():
		if child is Hurtbox and (child as Hurtbox).weak_point:
			return child
	return null


func test_it_throws_its_spear_in_an_arc() -> void:
	var guard := Player.new()
	guard.position = Vector3(1, 0.05, -10.6)
	add_child(guard)
	var warrior := _warrior(Vector3(1, 0, -0.6), guard)
	await physics_frames(5)
	_wake(warrior)
	var spear_seen := false
	var hurt := watch(Events.player_damaged)
	for i in 300:
		await get_tree().physics_frame
		for child in get_children():
			if child is ReliefSpear:
				spear_seen = true
		if not hurt.is_empty():
			break
	assert_true(spear_seen, "a spear flew")
	assert_eq(hurt.size(), 1, "and found him")
	if not hurt.is_empty():
		assert_eq(hurt[0][0], ReliefMoves.THROW_DAMAGE)


func test_pressed_against_its_wall_it_sinks_in_and_comes_out_six_metres_along() -> void:
	var dummy := _dummy(Vector3(1, 0, -20))
	var warrior := _warrior(Vector3(1, 0, -0.6), dummy)
	await physics_frames(5)
	_wake(warrior)
	await physics_frames(90)
	assert_eq(warrior.wall.state, ReliefMoves.Wall.OUT)
	dummy.position = warrior.global_position + Vector3(0, 0, -2.5)
	var sank_at := Vector3.INF
	for i in 30:
		await get_tree().physics_frame
		if warrior.wall.state == ReliefMoves.Wall.SINKING:
			sank_at = warrior.wall.wall_point
			break
	assert_true(sank_at != Vector3.INF, "it sinks into the wall")
	if sank_at == Vector3.INF:
		return
	var hidden := false
	for i in 150:
		await get_tree().physics_frame
		hidden = hidden or warrior.wall.hidden()
		if warrior.wall.state == ReliefMoves.Wall.OUT:
			break
	assert_true(hidden, "inside the wall for a moment")
	assert_eq(warrior.wall.state, ReliefMoves.Wall.OUT, "out again")
	assert_almost_eq(absf(warrior.global_position.x - sank_at.x), ReliefMoves.SLIDE, 0.5, "6 m along the wall")
	assert_almost_eq(warrior.global_position.z, WALL_Z - ReliefMoves.FLUSH - ReliefMoves.STEP_OUT, 0.3, "out of the same wall")
	assert_lt(warrior.global_position.distance_to(dummy.global_position), 6.0 + 2.6, "away from where he pressed it")


func test_with_no_wall_to_sink_into_it_stabs() -> void:
	var dummy := _dummy(Vector3(1, 0, -12.5))
	var warrior := _warrior(Vector3(1, 0, -11.0), dummy)   # far from the wall: a stele
	await physics_frames(5)
	assert_true(warrior.wall.stele)
	_wake(warrior)
	for i in 300:
		await get_tree().physics_frame
		if not dummy.hits.is_empty():
			break
	assert_false(dummy.hits.is_empty(), "a stab")
	if not dummy.hits.is_empty():
		assert_eq(dummy.hits[0].amount, ReliefMoves.STRIKE_DAMAGE)


func test_aimed_at_it_darts_aside() -> void:
	var guard := Player.new()
	guard.position = Vector3(1, 0.05, -9.0)
	add_child(guard)
	await physics_frames(2)
	var warrior := _warrior(Vector3(1, 0, -0.6), guard)
	await physics_frames(5)
	_wake(warrior)
	var furthest := 0.0
	for i in 200:
		# he keeps his sights on the warrior
		var d := warrior.global_position - guard.global_position
		guard.head.rotation = Vector3(0.0, atan2(-d.x, -d.z), 0.0)
		await get_tree().physics_frame
		if warrior.wall.state == ReliefMoves.Wall.OUT:
			furthest = maxf(furthest, absf(warrior.global_position.x - 1.0))
	assert_gt(furthest, 1.5, "a quick step aside out of his line")


func test_the_lion_steps_out_of_its_panel_and_pounces() -> void:
	var dummy := _dummy(Vector3(1, 0, -6))
	var lion := ReliefLion.new()
	lion.position = Vector3(1, 0, -0.6)
	lion.target = dummy
	add_child(lion)
	lion.face(Vector3(1, 0, -5))
	await physics_frames(5)
	assert_eq(lion.health.max_health, 40.0)
	assert_eq(lion.wall.panel.kind, ReliefPanel.Kind.LION)
	_wake(lion)
	await physics_frames(20)
	assert_true(lion.wall.busy(), "still tearing out of the wall")
	assert_eq(dummy.hits.size(), 0)
	for i in 240:
		await get_tree().physics_frame
		if not dummy.hits.is_empty():
			break
	assert_false(dummy.hits.is_empty(), "its pounce")
	var facing := lion.carved_face()
	assert_almost_eq(_hit(lion, facing.cross(Vector3.UP)), 10.0, 0.01, "flat: its edge takes half")


func test_it_turns_edge_on_to_attack_and_its_edge_takes_half_then() -> void:
	var dummy := _dummy(Vector3(1, 0, -10))
	var warrior := _warrior(Vector3(1, 0, -0.6), dummy)
	await physics_frames(5)
	_wake(warrior)
	for i in 300:
		await get_tree().physics_frame
		if warrior.brain.state == EnemyBrain.State.ATTACK and warrior.brain.windup_progress() > 0.8:
			break
	assert_eq(warrior.brain.state, EnemyBrain.State.ATTACK)
	var rig := warrior.rig as ReliefRig
	assert_gt(rig.profile(), 0.8, "the slab pivots edge-on: the telegraph")
	var toward := (dummy.global_position - warrior.global_position).normalized()
	assert_almost_eq(_hit(warrior, -toward), 10.0, 0.5, "from where the guard stands it is all edge")


func test_a_patrolling_warrior_has_no_slab_and_is_simply_out() -> void:
	var warrior := ReliefWarrior.new()
	warrior.position = Vector3(1, 0, -0.6)
	warrior.starts_awake = true
	warrior.target = _dummy(Vector3(0, 0, 20))
	add_child(warrior)
	await physics_frames(5)
	assert_eq(warrior.wall.state, ReliefMoves.Wall.OUT)
	assert_null(warrior.wall.panel)
	assert_true(warrior.rig.model.visible)


func assert_null(value: Variant) -> void:
	assert_true(value == null, "no slab")
