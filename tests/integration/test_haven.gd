extends TestCase
## Havens: the safe zone, the exhibit-only walls and exhibits leaving a
## sheltered guard alone.

const ZONE := AABB(Vector3(-4, 0, -4), Vector3(8, 3, 8))

var haven: Haven
var player: Player


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	haven = Haven.make(&"security", ZONE)
	add_child(haven)
	player = Player.new()
	player.position = Vector3(0, 0.05, -12)
	add_child(player)


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func test_haven_shelters_points_inside_only() -> void:
	assert_true(Haven.shelters(Vector3(0, 0, 0)), "feet on the floor count")
	assert_true(Haven.shelters(Vector3(3.9, 1.0, -3.9)))
	assert_false(Haven.shelters(Vector3(4.5, 0, 0)))
	assert_false(Haven.shelters(Vector3(0, 0, 9)))
	assert_eq(Haven.at(Vector3(1, 1, 1)), haven)


func test_guard_entering_emits_guard_entered() -> void:
	var entered := watch(haven.guard_entered)
	await physics_frames(3)
	assert_eq(entered.size(), 0)
	player.global_position = Vector3(0, 0.05, 0)
	await physics_frames(3)
	assert_eq(entered.size(), 1)
	if entered.size() == 1:
		assert_eq(entered[0][0], player)


func test_enemies_cannot_walk_into_the_haven() -> void:
	# the straight way from the wax figure to the guard runs through the haven
	var wax := WaxFigure.new()
	wax.position = Vector3(0, 0.05, 9)
	add_child(wax)
	wax.target = player
	wax.brain.wake()
	var entered := false
	for i in 240:
		await physics_frames(1)
		if haven.contains(wax.global_position):
			entered = true
			break
	assert_false(entered, "the exhibit stayed out")


## Design 7.2: a hunter searches at the haven's door for 8 s, then goes
## home; the guard stepping out later draws nobody back.
func test_enemies_search_at_the_door_then_leave_a_sheltered_guard_alone() -> void:
	var wax := WaxFigure.new()
	wax.position = Vector3(0, 0.05, 14)
	add_child(wax)
	wax.target = player
	wax.face(Vector3(0, 0.05, 30))   # its post faces away from the haven
	await physics_frames(2)
	player.global_position = Vector3(0, 0.05, 3.2)
	wax.global_position = Vector3(0, 0.05, 5.0)
	wax.brain.wake()
	await _seconds(3.5)
	assert_eq(player.health.current, 100.0, "no hits into the haven")
	assert_eq(wax.brain.state, EnemyBrain.State.SEARCH, "it searches at the door")
	assert_lt(wax.global_position.z, 7.0, "by the door")
	await _seconds(5.0)
	assert_ne(wax.brain.state, EnemyBrain.State.SEARCH, "8 s at the door, no more")
	await _seconds(9.0)
	assert_gt(wax.global_position.z, 12.5, "it walked back home")
	assert_eq(wax.brain.state, EnemyBrain.State.DORMANT, "and sleeps there")
	player.global_position = Vector3(0, 0.05, 7.0)
	await _seconds(3.0)
	assert_eq(wax.brain.state, EnemyBrain.State.DORMANT, "stepping out draws nobody back")
	assert_gt(wax.global_position.z, 12.5)


func test_bullets_and_the_guard_pass_the_enemy_walls() -> void:
	var dummy := TargetDummy.new()
	dummy.position = Vector3(0, 0, 0)
	add_child(dummy)
	var body := BoxShape3D.new()
	body.size = Vector3(0.8, 1.6, 0.8)
	var hurtbox := Hurtbox.make(dummy, body, Vector3(0, 1.0, 0))
	dummy.add_child(hurtbox)
	await physics_frames(2)
	var space := dummy.get_world_3d().direct_space_state
	var hit := Hitscan.ray(space, Vector3(0, 1.0, 10), Vector3(0, 1.0, -10))
	assert_eq(hit.get("hurtbox"), hurtbox, "shots go through the exhibit walls")
	player.global_position = Vector3(0, 0.05, 8)
	await physics_frames(2)
	Input.action_press(&"move_forward")
	await _seconds(1.5)
	Input.action_release(&"move_forward")
	assert_true(haven.contains(player.global_position), "the guard walks in")
