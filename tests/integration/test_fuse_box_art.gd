extends TestCase
## The hall cabinet's look (FuseBoxArt) follows the game's fuse box in front
## of it, found among the fuse boxes (FuseBoxArt.BOX_GROUP) rather than in
## the whole level kit (plan 2026-10-21-wydajnosc-cpu: that scan, every 2 s
## in the cabinets with no box in front, was a 6-14 ms spike on Floor I);
## a cabinet with none in front looks again now and then.


func _cabinet(at: Vector3) -> FuseBoxArt:
	var art := FuseBoxArt.new()
	art.position = at
	add_child(art)
	return art


func _box(at: Vector3) -> FuseBox:
	var box := FuseBox.new()
	box.position = at
	add_child(box)
	return box


func test_the_lamps_follow_the_fuse_box_in_front() -> void:
	var box := _box(Vector3(0, 1, 0))
	var art := _cabinet(Vector3(0, 1, 0.3))
	assert_true(box.is_in_group(FuseBoxArt.BOX_GROUP), "the game's fuse box is in the group")
	await physics_frames(2)
	box.set_inserted(1)
	await physics_frames(ceili(FuseBoxArt.POLL * 60.0) + 3)
	assert_eq(art.fuses, 1, "one fuse in")
	assert_true(art.power_on)
	box.set_inserted(2)
	await physics_frames(ceili(FuseBoxArt.POLL * 60.0) + 3)
	assert_eq(art.fuses, 2, "both in")
	assert_false(art.power_on, "both fuses in: the relay tripped, the switch drops")


func test_a_cabinet_with_no_box_in_front_finds_one_put_there_later() -> void:
	var far := _box(Vector3(10, 1, 0))   # another room's box
	var art := _cabinet(Vector3(0, 1, 0))
	far.set_inserted(1)
	await physics_frames(30)
	assert_eq(art.fuses, 0, "a box 10 m off is not its own")
	var near := _box(Vector3(0, 1, -0.3))
	near.set_inserted(2)
	await physics_frames(ceili(FuseBoxArt.POLL * 8.0 * 60.0) + 20)
	assert_eq(art.fuses, 2, "it looked again and found the one in front of it")
