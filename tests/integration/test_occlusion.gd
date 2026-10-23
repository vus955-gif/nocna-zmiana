extends TestCase
## Sounds behind walls (plan 2026-10-21-akustyka-ambient): three rooms in a
## row (a | b | c) with real walls and doorways; the camera stands in a. A
## positional sound in a is clear, one in b seen through the doorway is
## clear, one in b round the corner is obstructed (SFXObstructed, its room
## still rings), one in c is occluded (SFXOccluded, no room reverb); the
## exhibits' steps follow the same rule.

var camera: Camera3D
var level: _Level


class _Level:
	extends Node3D
	var layout := LevelLayout.new()

	func room_at(point: Vector3) -> StringName:
		return layout.room_at(point)


func before_each() -> void:
	Ambience.reset()
	Ambience.enabled = true
	level = _Level.new()
	for i in 3:
		level.layout.add_room(StringName("abc"[i]), [Rect2(i * 10.0, 0.0, 10.0, 10.0)] as Array[Rect2], 0.0, 4.0, Color.WHITE)
	level.layout.add_opening(&"ab", Rect2(9.8, 4.0, 0.4, 2.0), 0.0, 4.0, &"a", &"b")
	level.layout.add_opening(&"bc", Rect2(19.8, 4.0, 0.4, 2.0), 0.0, 4.0, &"b", &"c")
	add_child(level)
	# the walls at x = 10 and x = 20, each with a doorway at z 4..6
	for x in [10.0, 20.0]:
		for span: Vector2 in [Vector2(0.0, 4.0), Vector2(6.0, 10.0)]:
			_wall(Vector3(x, 2.0, (span.x + span.y) * 0.5), Vector3(0.4, 4.0, span.y - span.x))
	camera = Camera3D.new()
	add_child(camera)
	camera.global_position = Vector3(3.0, 1.6, 2.0)
	camera.current = true
	await physics_frames(2)


func after_each() -> void:
	Sfx.stop_all()
	Ambience.reset()
	Ambience.enabled = false


func _wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = size
	body.add_child(shape)
	level.add_child(body)
	body.global_position = center


func _voice(sound: StringName) -> AudioStreamPlayer3D:
	var found: AudioStreamPlayer3D = null
	for child in Sfx.get_children():
		if child is AudioStreamPlayer3D and child.get_meta(&"sound", &"") == sound and not child.is_queued_for_deletion():
			found = child
	return found


func test_walls_between_the_ears_and_a_sound() -> void:
	var ears := camera.global_position
	assert_eq(Ambience.acoustics.walls_between(ears, Vector3(7.0, 0.0, 8.0), level), 0, "the same room")
	assert_eq(Ambience.acoustics.walls_between(ears, Vector3(15.0, 0.0, 6.5), level), 0, "seen through the doorway")
	assert_eq(Ambience.acoustics.walls_between(ears, Vector3(15.0, 0.0, 1.0), level), 1, "next door, behind the wall")
	assert_eq(Ambience.acoustics.walls_between(ears, Vector3(25.0, 0.0, 1.0), level), 2, "two rooms away")
	assert_eq(Ambience.acoustics.walls_to(Vector3(25.0, 0.0, 1.0)), 2, "the camera's ears, the scene's level")


func test_the_ray_alone_decides_without_rooms() -> void:
	var ears := camera.global_position
	assert_eq(Ambience.acoustics.walls_between(ears, Vector3(25.0, 0.0, 1.0), null), 1, "blocked, rooms unknown")
	assert_eq(Ambience.acoustics.walls_between(ears, Vector3(7.0, 0.0, 8.0), null), 0)


func test_positional_sounds_take_their_occlusion_bus() -> void:
	Sfx.play_at(&"hit_marble", Vector3(7.0, 0.0, 8.0))
	var near := _voice(&"hit_marble")
	assert_not_null(near)
	if near != null:
		assert_eq(near.bus, &"SFX")
		assert_true(near.area_mask & Layers.REVERB_ZONE != 0, "the room's reverb")
	Sfx.play_at(&"hit_metal", Vector3(15.0, 0.0, 1.0))
	var next_door := _voice(&"hit_metal")
	assert_not_null(next_door)
	if next_door != null:
		assert_eq(next_door.bus, &"SFXObstructed")
		assert_true(next_door.area_mask & Layers.REVERB_ZONE != 0, "its room still rings through the doorway")
	Sfx.play_at(&"hit_wax", Vector3(25.0, 0.0, 1.0))
	var far := _voice(&"hit_wax")
	assert_not_null(far)
	if far != null:
		assert_eq(far.bus, &"SFXOccluded")
		assert_eq(far.area_mask & Layers.REVERB_ZONE, 0, "behind two walls its room is lost too")


func test_nothing_changes_while_ambience_is_off() -> void:
	Ambience.enabled = false
	Sfx.play_at(&"hit_wax", Vector3(25.0, 0.0, 1.0))
	var far := _voice(&"hit_wax")
	assert_not_null(far)
	if far != null:
		assert_eq(far.bus, &"SFX", "test runs stay as they were")


func test_an_exhibits_steps_are_muffled_behind_walls() -> void:
	var walker := CharacterBody3D.new()
	add_child(walker)
	walker.global_position = Vector3(25.0, 0.0, 1.0)
	var steps := Footsteps.attach(walker, &"wax")
	await get_tree().process_frame
	steps.step(1.0)
	var routed := 0
	for voice in steps.get_children():
		if voice is AudioStreamPlayer3D and (voice as AudioStreamPlayer3D).playing:
			assert_eq((voice as AudioStreamPlayer3D).bus, &"SFXOccluded")
			routed += 1
	assert_gt(routed, 0, "a step played")
	walker.global_position = Vector3(7.0, 0.0, 8.0)
	Ambience.advance(Acoustics.STEP_REUSE + 0.1)
	steps.step(1.0)
	var last := steps.get_child(0) as AudioStreamPlayer3D
	for voice in steps.get_children():
		if voice is AudioStreamPlayer3D and (voice as AudioStreamPlayer3D).playing:
			last = voice
	assert_eq(last.bus, &"SFX", "back in sight: clear again")
	walker.queue_free()
