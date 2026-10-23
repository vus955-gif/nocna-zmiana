extends TestCase
## What the uncanny events do to the museum's own objects (plan
## 2026-10-21-eskalacja-nocy, 2.4): fair changes - a hidden piece takes its
## collision along, a turned piece keeps its footprint, a sleeper sleeps on,
## a tomb opens as ever after it stood ajar, the clocks come back, a slammed
## door opens again, a noise goes through the perception's own bus.

var root: Node3D
var guard: Node3D


func before_each() -> void:
	root = Node3D.new()
	add_child(root)
	guard = Node3D.new()
	guard.position = Vector3(0, 0, 12)
	root.add_child(guard)


func after_each() -> void:
	if is_instance_valid(root):
		root.free()


func _piece(kit: StringName, at: Vector3, size: Vector3, yaw: float = 0.0) -> PieceSpec:
	var spec := PieceSpec.make(kit, at, size, &"hall", yaw)
	var piece := LevelKit.make(spec.kit, spec.size, spec.transform(), Color.GRAY, true)
	piece.set_meta(&"kit_room", spec.room)
	root.add_child(piece)
	return spec


func test_a_hidden_piece_takes_its_collision_along() -> void:
	var spec := _piece(&"sculpture", Vector3(2, 0, -3), Vector3(1.0, 2.2, 1.0))
	var piece := UncannyEffects.find_piece(root, spec)
	assert_not_null(piece, "the built piece is found by its spec")
	UncannyEffects.hide_piece(piece)
	await physics_frames(2)
	assert_false(piece.visible)
	assert_true(UncannyEffects.is_hidden(piece))
	var shapes := piece.find_children("*", "CollisionShape3D", true, false)
	assert_gt(shapes.size(), 0, "it had a collision")
	for shape: CollisionShape3D in shapes:
		assert_true(shape.disabled, "no invisible wall where it stood")
	var other := PieceSpec.make(&"bench", Vector3(2, 0, -3), Vector3.ONE, &"hall")
	assert_eq(UncannyEffects.find_piece(root, other), null, "another kit is not it")


func test_a_turned_piece_keeps_its_footprint_and_its_collision() -> void:
	var spec := _piece(&"bench", Vector3(-3, 0, 1), Vector3(2.0, 0.5, 0.6), 0.3)
	var piece := UncannyEffects.find_piece(root, spec)
	var before := piece.global_transform
	var angle := UncannyEffects.turn_angle(spec, guard.position)
	assert_almost_eq(angle, PI, 0.0001, "a long bench only turns half round")
	UncannyEffects.turn_piece(piece, angle)
	assert_almost_eq(UncannyEffects.turned_by(piece), PI, 0.0001)
	assert_true(piece.global_position.is_equal_approx(before.origin), "about its own base")
	var after_front := -piece.global_basis.z
	assert_almost_eq(after_front.dot(-before.basis.z), -1.0, 0.0001, "it faces the other way")
	var footprint := spec.footprint()
	var turned := UncannyEffects.turned_footprint(spec, angle)
	assert_true(turned.position.is_equal_approx(footprint.position) and turned.size.is_equal_approx(footprint.size), "the same footprint")
	UncannyEffects.turn_piece(piece, angle)
	assert_almost_eq((-piece.global_basis.z).dot(after_front), 1.0, 0.0001, "turned once only")


func test_a_square_base_turns_by_quarters_to_face_a_point() -> void:
	var spec := PieceSpec.make(&"sculpture", Vector3.ZERO, Vector3(1.0, 2.0, 1.0), &"hall", 0.0)
	var angle := UncannyEffects.turn_angle(spec, Vector3(10, 0, 0))
	assert_almost_eq(angle / (PI * 0.5), roundf(angle / (PI * 0.5)), 0.0001, "quarter turns")
	var front := Basis(Vector3.UP, spec.yaw + angle) * Vector3.FORWARD
	assert_gt(front.dot(Vector3.RIGHT), 0.99, "it faces the point")
	var footprint := spec.footprint()
	var turned := UncannyEffects.turned_footprint(spec, angle)
	assert_true(turned.size.is_equal_approx(footprint.size) and turned.position.is_equal_approx(footprint.position), "a square keeps its footprint")


func test_a_painting_changes_in_its_own_frame() -> void:
	var at := Transform3D(Basis.IDENTITY, Vector3(0, 1.6, -5))
	var old := WallPainting.create(at, &"admiral")
	root.add_child(old)
	assert_eq(UncannyEffects.painting_at(root, at.origin), old)
	var sitter := UncannyEffects.other_sitter(&"admiral")
	assert_ne(PaintingArt.canvas_for(sitter), PaintingArt.canvas_for(&"admiral"), "a face the model paints differently")
	var fresh := UncannyEffects.swap_painting(old, sitter)
	await physics_frames(1)
	assert_false(is_instance_valid(old), "the old one is gone")
	assert_eq(fresh.painting_id, sitter)
	assert_true(fresh.transform.is_equal_approx(at), "the same frame on the wall")
	assert_eq(UncannyEffects.painting_at(root, at.origin), fresh)
	var empty := UncannyEffects.empty_picture(&"portrait_court_2")
	assert_true(PaintingArt.SCENE_IDS.has(empty), "the sitter walked out: a picture without a face")
	assert_eq(UncannyEffects.empty_picture(&"portrait_court_2"), empty, "the same for the same spot")


func test_a_paintings_eyes_look_aside_on_its_own_copy() -> void:
	var painting := WallPainting.create(Transform3D(Basis.IDENTITY, Vector3(0, 1.6, -5)), &"countess")
	root.add_child(painting)
	var plain := WallPainting.create(Transform3D(Basis.IDENTITY, Vector3(3, 1.6, -5)), &"countess")
	root.add_child(plain)
	assert_true(PaintingGaze.has_eyes(painting))
	var look := UncannyEffects.aside(&"portrait_north_hall_1")
	assert_true(PaintingGaze.set_look(painting, look))
	assert_true(PaintingGaze.look_of(painting).is_equal_approx(look))
	if painting.model != null:
		var eyes := painting.model.find_child("eyes", true, false) as MeshInstance3D
		var own := eyes.get_surface_override_material(0) as BaseMaterial3D
		assert_not_null(own, "its own material")
		assert_ne(Vector2(own.uv1_offset.x, own.uv1_offset.y), Vector2.ZERO, "the irises moved")
		var shared := ArtLibrary.material(ArtLibrary.PORTRAIT_EYES_MATERIAL) as BaseMaterial3D
		assert_eq(Vector2(shared.uv1_offset.x, shared.uv1_offset.y), Vector2.ZERO, "the shared material untouched")
		var other := plain.model.find_child("eyes", true, false) as MeshInstance3D
		assert_ne(other.get_surface_override_material(0), own, "the other painting's eyes are its own")
	else:
		var pupil: Node3D = painting.parts["pupil_l"]
		var eye: Node3D = painting.parts["eye_l"]
		assert_gt(absf(pupil.position.x - eye.position.x), 0.005, "the pupils moved")
		var still: Node3D = plain.parts["pupil_l"]
		assert_almost_eq(still.position.x, (plain.parts["eye_l"] as Node3D).position.x, 0.0001, "the other painting still looks out")
	var scene := WallPainting.create(Transform3D.IDENTITY, PaintingArt.SCENE_IDS[0])
	root.add_child(scene)
	assert_false(PaintingGaze.set_look(scene, look), "a landscape has no eyes")


func test_a_gaze_follows_the_guard_and_settles_back() -> void:
	var painting := WallPainting.create(Transform3D(Basis.IDENTITY, Vector3(0, 1.6, -5)), &"merchant")
	root.add_child(painting)
	guard.position = Vector3(4, 0, -12)   # in front of it (a painting faces -Z)
	var gaze := PaintingGaze.follow(painting, guard, 1.0)
	assert_not_null(gaze)
	await physics_frames(30)
	var look := PaintingGaze.look_of(painting)
	assert_gt(look.x, 0.2, "the eyes went toward him (his side: the painting's +X)")
	await physics_frames(roundi((1.0 + PaintingGaze.SETTLE) * 60.0) + 10)
	assert_false(is_instance_valid(gaze), "done")
	assert_true(PaintingGaze.look_of(painting).is_equal_approx(Vector2.ZERO), "straight out again")
	guard.position = Vector3(0, 0, 9)
	assert_false(PaintingGaze.in_front(painting, guard.position), "behind the wall is not in front")


func test_a_sleeper_turns_to_face_the_door_and_sleeps_on() -> void:
	var figure := WaxFigure.new()
	figure.position = Vector3(0, 0, -4)
	figure.target = guard
	root.add_child(figure)
	await physics_frames(2)
	assert_eq(figure.brain.state, EnemyBrain.State.DORMANT)
	assert_true(UncannyEffects.turn_sleeper(figure, Vector3(6, 0, -4)))
	var front := -figure.global_basis.z
	assert_gt(front.dot(Vector3.RIGHT), 0.95, "it faces the door")
	await physics_frames(5)
	assert_eq(figure.brain.state, EnemyBrain.State.DORMANT, "and sleeps on")
	figure.brain.wake()
	assert_false(UncannyEffects.turn_sleeper(figure, Vector3.ZERO), "an awake one is no sleeper")


func test_a_tomb_stands_ajar_and_still_opens() -> void:
	for style in [MummyMoves.Tomb.COFFIN, MummyMoves.Tomb.SARCOPHAGUS]:
		var tomb := MummyTomb.build(style, Transform3D(Basis.IDENTITY, Vector3(float(style) * 4.0, 0, -6)))
		root.add_child(tomb)
		await physics_frames(1)
		var rest := tomb.lid.transform
		assert_true(UncannyEffects.set_ajar(tomb), "ajar")
		assert_true(UncannyEffects.is_ajar(tomb))
		var moved := tomb.lid.transform
		assert_false(moved.is_equal_approx(rest), "the lid moved")
		assert_lt(moved.origin.distance_to(rest.origin), 0.1, "by a finger")
		assert_false(UncannyEffects.set_ajar(tomb), "once")
		tomb.open()
		await physics_frames(60)
		assert_gt(tomb.lid.transform.origin.distance_to(rest.origin) + absf(tomb.lid.transform.basis.get_euler().x - rest.basis.get_euler().x), 0.3, "it opens as ever")
		assert_false(UncannyEffects.set_ajar(tomb), "an open tomb is not set ajar")


func test_the_clocks_run_backwards_and_come_back() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var hand := Node3D.new()
	holder.add_child(hand)
	var pendulum := Node3D.new()
	holder.add_child(pendulum)
	var spinner := DecorSpinner.new()
	spinner.name = UncannyEffects.CLOCK_SPINNER
	spinner.add(hand, Vector3.BACK, TAU / 600.0)
	spinner.swing(pendulum, Vector3.BACK, 0.12, 2.0)
	spinner.set_meta(&"kit_room", &"enlightenment_clocks")
	holder.add_child(spinner)
	var found := UncannyEffects.clockworks(root, &"enlightenment_clocks")
	assert_eq(found.size(), 1)
	assert_eq(UncannyEffects.clockworks(root, &"court").size(), 0, "another room's are not")
	UncannyEffects.reverse_clock(spinner, true)
	assert_lt(float(spinner.targets[0][2]), -0.5, "the hands race backwards")
	assert_eq(float(spinner.swings[0][2]), 0.0, "the pendulum stops")
	UncannyEffects.reverse_clock(spinner, true)
	assert_lt(float(spinner.targets[0][2]), -0.5, "twice is once")
	UncannyEffects.reverse_clock(spinner, false)
	assert_almost_eq(float(spinner.targets[0][2]), TAU / 600.0, 0.000001, "back as it was")
	assert_almost_eq(float(spinner.swings[0][2]), 0.12, 0.000001)
	assert_false(UncannyEffects.clock_reversed(spinner))


func test_a_door_slams_and_swings_open_again() -> void:
	var spec := OpeningSpec.make(&"slam_door", Rect2(-1, -0.25, 2, 0.5), 0.0, 2.5, &"a", &"b", OpeningSpec.DoorStyle.SWING, RoomGraph.Kind.OPEN)
	var door := Door.make(spec, Transform3D.IDENTITY, Color(0.5, 0.45, 0.4))
	root.add_child(door)
	await physics_frames(2)
	assert_true(door.is_open)
	var shut := watch(door.closed)
	assert_true(UncannyEffects.slam(door))
	await physics_frames(roundi((Door.TIMES[OpeningSpec.DoorStyle.SWING] + 0.1) * 60.0))
	assert_eq(shut.size(), 1, "it slammed shut")
	await physics_frames(roundi((UncannyEffects.SLAM_HOLD + Door.TIMES[OpeningSpec.DoorStyle.SWING] + 0.3) * 60.0))
	assert_true(door.is_open, "and swung open again")
	assert_false(door.is_moving())
	door.lock(true)
	assert_false(UncannyEffects.slam(door), "a locked door is no door to slam")


func test_a_noise_goes_through_the_perceptions_bus() -> void:
	var heard := watch(Events.noise_made)
	UncannyEffects.sound(&"weight_thud", Vector3(5, 1, 5), -6.0, 1.0, 16.0)
	assert_eq(heard.size(), 1)
	assert_eq(heard[0][1], 16.0)
	assert_eq(heard[0][2], ReactionRules.SOURCE_FALL, "something fell")
	UncannyEffects.sound(&"relay", Vector3.ZERO, -10.0)
	assert_eq(heard.size(), 1, "a sound alone is no noise")
