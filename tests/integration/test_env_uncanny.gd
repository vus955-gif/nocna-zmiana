extends TestCase
## The reactive environment and whatever else changes the museum's pieces
## during a night - the night's uncanny turns (branch night-escalation:
## a painting swapped for another, a piece hidden, a piece turned; plan
## docs/superpowers/plans/2026-10-21-srodowisko-walka.md): EnvLayer.claims()
## says which pieces it answers for, rebind() hands a swapped painting's
## prop to the fresh one, set_present() takes a hidden piece's hit zones
## away and back, recapture() makes a turned bust rest in its new pose; a
## prop whose piece was freed without a word answers no more (no error).

var bed: EnvTestbed


func before_each() -> void:
	bed = EnvTestbed.new()
	add_child(bed)
	bed.setup()


func after_each() -> void:
	if is_instance_valid(bed):
		bed.free()


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _of(type: Variant) -> Array[EnvProp]:
	var out: Array[EnvProp] = []
	for each in bed.env.props:
		if is_instance_of(each, type):
			out.append(each)
	return out


## A painting freed and a fresh one hung in its frame (the uncanny swap).
func _swap(old: WallPainting) -> WallPainting:
	var frame := old.global_transform
	var faces := PaintingArt.ids()
	var fresh := WallPainting.create(frame, faces[1 % faces.size()])
	old.free()
	bed.paintings_root.add_child(fresh)
	return fresh


func test_the_layer_says_which_pieces_it_answers_for() -> void:
	var picture := bed.painting(Vector3(0.0, 2.2, -14.95))
	bed.piece(&"pedestal", Vector3(4.0, 0.0, -6.0), Vector3(1.2, 0.8, 1.2))
	var statue := bed.piece(&"sculpture", Vector3(4.0, 0.8, -6.0), Vector3(0.9, 2.0, 0.9))
	var crate := bed.piece(&"crate", Vector3(-4.0, 0.0, -6.0), Vector3(1.0, 1.0, 1.0))
	var shelf := bed.piece(&"shelf", Vector3(0.0, 0.0, -14.75), Vector3(3.0, 3.4, 0.5), PI)
	bed.install_env()
	bed.tool({"id": &"bookcase_test", "kind": &"topple", "build": &"bookcase", "kit": &"shelf", "room": EnvTestbed.ROOM,
		"near": Vector3(0.0, 0.0, -14.75)})
	assert_eq(EnvLayer.of(get_tree()), bed.env)
	assert_true(bed.env.claims(picture), "a painting")
	assert_true(bed.env.claims(statue), "a statue")
	assert_true(bed.env.claims(shelf), "a tool's piece")
	assert_false(bed.env.claims(crate), "a crate is no prop")
	assert_false(bed.env.claims(null))


func test_a_swapped_painting_is_handed_to_the_fresh_one_which_tilts_and_slips() -> void:
	var old := bed.painting(Vector3(0.0, 2.2, -14.95))
	bed.install_env()
	var prop := _of(EnvPainting)[0] as EnvPainting
	var fresh := _swap(old)
	bed.env.rebind(null, fresh)   # (old already freed: found by the frame it stood in)
	assert_eq(prop.target, fresh)
	var rest := fresh.global_transform
	prop.take_damage(bed.hit(20.0, &"pistol", fresh.global_position + Vector3(0.3, 0.0, 0.05), Vector3.FORWARD))
	await _seconds(1.0)
	assert_false(fresh.global_transform.is_equal_approx(rest), "the fresh painting goes crooked")
	prop.take_damage(bed.hit(85.0, &"rifle_hunt", fresh.global_position, Vector3.FORWARD))
	await _seconds(1.0)
	assert_true(prop.is_down)
	assert_eq(fresh.collision_layer, 0, "it slips down with its collision")


func test_rebinding_before_the_old_one_goes_works_too() -> void:
	var old := bed.painting(Vector3(0.0, 2.2, -14.95))
	bed.install_env()
	var prop := _of(EnvPainting)[0] as EnvPainting
	var fresh := WallPainting.create(old.global_transform, PaintingArt.ids()[0])
	bed.paintings_root.add_child(fresh)
	bed.env.rebind(old, fresh)
	old.free()
	assert_eq(prop.target, fresh)
	prop.take_damage(bed.hit(85.0, &"rifle_hunt", fresh.global_position, Vector3.FORWARD))
	await _seconds(1.0)
	assert_true(prop.is_down)


func test_a_prop_whose_piece_vanished_without_a_word_answers_no_more() -> void:
	var old := bed.painting(Vector3(0.0, 2.2, -14.95))
	bed.install_env()
	var prop := _of(EnvPainting)[0] as EnvPainting
	old.free()
	prop.take_damage(bed.hit(85.0, &"rifle_hunt", Vector3(0.0, 2.2, -14.9), Vector3.FORWARD))
	await _seconds(1.0)
	assert_true(prop.absent, "its piece is gone")
	assert_false(prop.is_down)
	assert_eq(prop.hurtbox.collision_layer, 0, "nothing to shoot where it hung")


func test_a_hidden_statue_cannot_be_shot_until_it_is_back() -> void:
	bed.piece(&"pedestal", Vector3(0.0, 0.0, -6.0), Vector3(1.2, 0.8, 1.2))
	var statue := bed.piece(&"sculpture", Vector3(0.0, 0.8, -6.0), Vector3(0.9, 2.0, 0.9))
	bed.install_env()
	var prop := _of(EnvStatue)[0] as EnvStatue
	await physics_frames(2)
	var space := bed.get_world_3d().direct_space_state
	var eye := Vector3(0.0, 1.8, 0.0)
	var aim := Vector3(0.0, 1.8, -12.0)
	var hit := Hitscan.ray(space, eye, aim)
	assert_true(not hit.is_empty() and hit["hurtbox"] != null and (hit["hurtbox"] as Hurtbox).receiver == prop, "the statue's zone takes the shot")
	# the uncanny hides it: its collision (theirs) and its zones (ours) go
	statue.visible = false
	for shape in statue.find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).disabled = true
	bed.env.set_present(statue, false)
	await physics_frames(2)
	hit = Hitscan.ray(space, eye, aim)
	assert_true(hit.is_empty() or hit["hurtbox"] == null or (hit["hurtbox"] as Hurtbox).receiver != prop, "no invisible shootable statue")
	prop.take_damage(bed.hit(85.0, &"rifle_hunt", Vector3(0.0, 1.8, -5.6), Vector3.FORWARD))
	assert_eq(prop.phase, EnvProp.Phase.IDLE, "a hidden statue does not teeter")
	# back again
	statue.visible = true
	for shape in statue.find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).disabled = false
	bed.env.set_present(statue, true)
	await physics_frames(2)
	hit = Hitscan.ray(space, eye, aim)
	assert_true(not hit.is_empty() and hit["hurtbox"] != null and (hit["hurtbox"] as Hurtbox).receiver == prop, "back, it can be shot again")


func test_a_statue_hidden_without_telling_the_layer_takes_no_hit() -> void:
	bed.piece(&"pedestal", Vector3(0.0, 0.0, -6.0), Vector3(1.2, 0.8, 1.2))
	var statue := bed.piece(&"sculpture", Vector3(0.0, 0.8, -6.0), Vector3(0.9, 2.0, 0.9))
	bed.install_env()
	var prop := _of(EnvStatue)[0] as EnvStatue
	statue.visible = false   # (set_present() is not called: the zone is still there)
	prop.take_damage(bed.hit(85.0, &"rifle_hunt", Vector3(0.0, 1.8, -5.6), Vector3.FORWARD))
	assert_eq(prop.phase, EnvProp.Phase.IDLE, "an invisible statue does not teeter")
	assert_almost_eq(prop.taken, 0.0, 0.001, "and takes no damage")
	statue.visible = true
	prop.take_damage(bed.hit(85.0, &"rifle_hunt", Vector3(0.0, 1.8, -5.6), Vector3.FORWARD))
	assert_eq(prop.phase, EnvProp.Phase.WARNING, "back in view, it answers again")


func test_a_turned_bust_rests_in_its_new_pose() -> void:
	var plinth := bed.piece(&"bust_plinth", Vector3(0.0, 0.0, -6.0), Vector3(0.7, 1.9, 0.7))
	bed.install_env()
	var bust := _of(EnvBust)[0] as EnvBust
	# the uncanny turns it to face the wall
	plinth.rotate_y(PI * 0.5)
	bed.env.recapture(plinth)
	var turned: Array[Transform3D] = []
	for part in bust.parts:
		turned.append(part.global_transform)
	bust.take_damage(bed.hit(20.0, &"pistol", Vector3(0.0, 1.6, -5.75), Vector3.FORWARD))
	await _seconds(1.0)
	assert_false(bust.is_down)
	for i in bust.parts.size():
		assert_true(bust.parts[i].global_transform.is_equal_approx(turned[i]), "it rocks and comes to rest turned, not back where it stood")
