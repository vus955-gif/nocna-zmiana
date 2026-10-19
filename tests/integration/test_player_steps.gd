extends TestCase
## The guard walks up a low ledge instead of stopping at it (QA #49: "the
## player must not stop on a centimetre ledge"): a step up to
## Player.STEP_HEIGHT (a stair's open side, a dais's step, a lip) is taken
## in his stride at his walking speed, a higher one stops him as before (a
## plinth, a bench: jump), an exhibit is never a step, nothing happens in
## the air, and his eyes rise smoothly rather than popping up.

var player: Player
var ground: StaticBody3D


func before_each() -> void:
	ground = Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	player = Player.new()
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	await physics_frames(5)


## A ledge [param height] m high whose near face is 2 m ahead (-Z), 4 m deep.
func _ledge(height: float, depth: float = 4.0) -> void:
	Greybox.box(self, Vector3(0, height * 0.5, -2.0 - depth * 0.5), Vector3(6, height, depth), Color.DIM_GRAY)


## Walks forward for [param seconds]; returns the highest per-frame rise of
## his eyes on the way.
func _walk(seconds: float) -> float:
	Input.action_press(&"move_forward")
	var steepest := 0.0
	var eye := player.head.global_position.y
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		await get_tree().process_frame
		steepest = maxf(steepest, player.head.global_position.y - eye)
		eye = player.head.global_position.y
	Input.action_release(&"move_forward")
	return steepest


func test_he_walks_up_a_low_step_at_his_walking_speed() -> void:
	_ledge(0.2)
	await physics_frames(2)
	await _walk(1.0)
	assert_almost_eq(player.global_position.y, 0.2, 0.03, "on the step")
	# 1 s at 5.5 m/s from z = 0: well past the face at -2 m, hardly slowed
	assert_lt(player.global_position.z, -4.5, "not held up at the face")


func test_he_steps_up_onto_the_highest_step() -> void:
	_ledge(Player.STEP_HEIGHT - 0.02)
	await physics_frames(2)
	await _walk(1.0)
	assert_almost_eq(player.global_position.y, Player.STEP_HEIGHT - 0.02, 0.03, "on the step")


func test_a_higher_ledge_stops_him() -> void:
	_ledge(Player.STEP_HEIGHT + 0.1)
	await physics_frames(2)
	await _walk(1.0)
	assert_lt(player.global_position.y, 0.05, "still on the floor")
	assert_gt(player.global_position.z, -2.0, "stopped at the face")


func test_a_lip_does_not_slow_him() -> void:
	# a strip 8 cm high and 30 cm deep across his way
	_ledge(0.08, 0.3)
	await physics_frames(2)
	await _walk(1.0)
	assert_lt(player.global_position.z, -4.5, "over the lip at his walking speed")
	assert_lt(player.global_position.y, 0.05, "and down on the floor beyond")


func test_his_eyes_rise_smoothly() -> void:
	_ledge(0.3)
	await physics_frames(2)
	var steepest := await _walk(1.0)
	assert_almost_eq(player.global_position.y, 0.3, 0.03, "on the step")
	assert_lt(steepest, 0.12, "no pop of the whole step in one frame")


## A flight of [param steps] solid steps (each [param rise] m up and
## [param tread] m deep) from 2 m ahead (-Z), a landing 4 m deep on top.
func _stepped_flight(rise: float, tread: float, steps: int) -> void:
	for i in steps:
		var top := (i + 1) * rise
		Greybox.box(self, Vector3(0, top * 0.5, -2.0 - (i + 0.5) * tread), Vector3(6, top, tread), Color.DIM_GRAY)
	var height := steps * rise
	Greybox.box(self, Vector3(0, height * 0.5, -2.0 - steps * tread - 2.0), Vector3(6, height, 4.0), Color.DIM_GRAY)


## Walks forward for [param seconds] (turned to [param yaw]); returns his
## eyes' height every frame.
func _eye_path(seconds: float, yaw: float = 0.0) -> PackedFloat32Array:
	player.head.rotation.y = yaw
	Input.action_press(&"move_forward")
	var path := PackedFloat32Array()
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		await get_tree().process_frame
		path.append(player.head.global_position.y)
	Input.action_release(&"move_forward")
	return path


## The largest drop (going up) or rise (going down) of [param path]
## between two frames against its way: a bob of the view.
static func _bob(path: PackedFloat32Array, up: bool) -> float:
	var worst := 0.0
	for i in range(1, path.size()):
		var change := path[i] - path[i - 1]
		worst = maxf(worst, -change if up else change)
	return worst


static func _jolt(path: PackedFloat32Array) -> float:
	var worst := 0.0
	for i in range(1, path.size()):
		worst = maxf(worst, absf(path[i] - path[i - 1]))
	return worst


func test_his_eyes_climb_a_flight_of_solid_steps_without_a_bob() -> void:
	# (the floor's flights are ramps under drawn steps - test_floor1_collision
	# follows his view up and down every one; a flight of solid steps is the
	# worst case: a step up every few frames. Its treads are as deep as his
	# stride's look-ahead, Player.STEP_PROBE, and more: a shallower tread is
	# no step he takes, only a ramp is)
	_stepped_flight(0.18, 0.5, 8)
	await physics_frames(2)
	# 8 m to the landing's middle at his walking speed, then a breath
	var path := await _eye_path(8.0 / player.walk_speed)
	path.append_array(await _eye_path(0.4, PI * 0.5))
	assert_almost_eq(player.global_position.y, 1.44, 0.03, "up on the landing")
	assert_lt(_bob(path, true), 0.005, "his view never dips on the way up")
	assert_lt(_jolt(path), 0.12, "nor jumps a step in one frame")
	assert_almost_eq(path[path.size() - 1], 1.44 + player.eye_height, 0.01, "his eyes at their height once up")


func test_his_eyes_go_down_a_flight_of_solid_steps_without_a_bob() -> void:
	_stepped_flight(0.18, 0.5, 8)
	player.global_position = Vector3(0, 1.49, -2.0 - 8 * 0.5 - 2.0)
	player.reset_physics_interpolation()
	await physics_frames(5)
	var path := await _eye_path(8.0 / player.walk_speed + 0.3, PI)
	assert_lt(player.global_position.y, 0.05, "down on the floor")
	assert_lt(_bob(path, false), 0.005, "his view never rises on the way down")
	assert_lt(_jolt(path), 0.12, "nor drops a step in one frame")


func test_an_exhibit_is_no_step() -> void:
	var exhibit := StaticBody3D.new()
	exhibit.collision_layer = Layers.ENEMY
	var shape := BoxShape3D.new()
	shape.size = Vector3(6, 0.25, 4)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.125
	exhibit.add_child(collider)
	exhibit.position = Vector3(0, 0, -4.0)
	add_child(exhibit)
	await physics_frames(2)
	await _walk(1.0)
	assert_lt(player.global_position.y, 0.05, "he does not climb an exhibit")
	assert_gt(player.global_position.z, -2.0)


func test_no_step_in_the_air() -> void:
	_ledge(0.3)
	await physics_frames(2)
	player.global_position = Vector3(0, 0.4, -1.2)
	player.velocity = Vector3(0, -1.0, 0)
	Input.action_press(&"move_forward")
	await physics_frames(1)
	var stepped := player.global_position.y > 0.4
	Input.action_release(&"move_forward")
	assert_false(stepped, "falling, he is not lifted")


func test_a_jump_takes_him_onto_a_ledge_80_cm_high() -> void:
	_ledge(0.8)
	await physics_frames(2)
	Input.action_press(&"move_forward")
	await physics_frames(16)   # at the face
	Input.action_press(&"jump")
	await physics_frames(1)
	Input.action_release(&"jump")
	await physics_frames(50)
	Input.action_release(&"move_forward")
	assert_almost_eq(player.global_position.y, 0.8, 0.05, "up on the ledge")
