extends TestCase
## The three Floor I weapons on their Blender models, animated in code:
## the rifle's bolt cycles after a shot and a clip goes in on the reload,
## the harpoon leaves the muzzle and slides back in, the chest's arrows go
## one by one and come back one by one.

var holder: WeaponHolder


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color.GRAY)
	var user := Node3D.new()
	add_child(user)
	holder = WeaponHolder.new()
	holder.user = user
	holder.position = Vector3(0, 1.5, 0)
	user.add_child(holder)


func _rig(id: StringName) -> ViewmodelRig:
	holder.give(load("res://src/weapons/data/%s.tres" % id))
	holder.select_id(id)
	var rig := holder.view_of(id) as ViewmodelRig
	assert_not_null(rig, "vm_%s is a model rig" % id)
	return rig


func _moved(rig: ViewmodelRig, part: StringName) -> float:
	var node := rig.part_node(part)
	var rest: Transform3D = rig.rest[String(part)]
	return node.transform.origin.distance_to(rest.origin) + (node.transform.basis.get_euler() - rest.basis.get_euler()).length()


func test_the_rifle_bolt_cycles_after_a_shot() -> void:
	var rig := _rig(&"rifle_hunt")
	if rig == null:
		return
	await physics_frames(3)
	assert_almost_eq(_moved(rig, &"bolt"), 0.0, 0.001, "closed at rest")
	holder.try_fire()
	await physics_frames(24)
	assert_gt(_moved(rig, &"bolt"), 0.05, "working the bolt")
	await physics_frames(45)
	assert_almost_eq(_moved(rig, &"bolt"), 0.0, 0.01, "closed again")


func test_the_rifle_takes_a_clip_on_the_reload() -> void:
	var rig := _rig(&"rifle_hunt")
	if rig == null:
		return
	var clip := rig.part_node(&"clip")
	await physics_frames(3)
	assert_false(clip.visible, "no clip at rest")
	holder.current_state().magazine = 0
	holder.try_reload()
	await physics_frames(roundi(2.2 * 60.0 * 0.5))
	assert_true(clip.visible, "the clip goes in")
	await physics_frames(roundi(2.2 * 60.0 * 0.5) + 5)
	assert_false(clip.visible)


func test_the_harpoon_leaves_the_muzzle_and_comes_back() -> void:
	var rig := _rig(&"harpoon")
	if rig == null:
		return
	var head := rig.part_node(&"head")
	await physics_frames(3)
	assert_true(head.visible, "loaded")
	holder.try_fire()
	await physics_frames(2)
	assert_false(head.visible, "fired")
	await physics_frames(roundi(1.2 * 60.0 * 0.6))
	assert_true(head.visible, "sliding back in")
	assert_gt(_moved(rig, &"head"), 0.01, "still on its way")
	await physics_frames(roundi(1.2 * 60.0 * 0.4) + 5)
	assert_almost_eq(_moved(rig, &"head"), 0.0, 0.005, "home")


func test_the_chests_arrows_go_one_by_one_and_come_back() -> void:
	var rig := _rig(&"hwacha")
	if rig == null:
		return
	await physics_frames(3)
	for i in 6:
		assert_true(rig.part_node(StringName("rocket_%d" % (i + 1))).visible, "arrow %d loaded" % (i + 1))
	assert_false(rig.part_node(&"rocket_7").visible, "the third row needs the upgrade")
	holder.try_fire()
	await physics_frames(2)
	assert_false(rig.part_node(&"rocket_1").visible, "the first one is gone")
	assert_true(rig.part_node(&"rocket_6").visible, "the last one still waits")
	await physics_frames(30)
	for i in 6:
		assert_false(rig.part_node(StringName("rocket_%d" % (i + 1))).visible, "arrow %d gone" % (i + 1))
	await physics_frames(roundi(2.2 * 60.0))
	for i in 6:
		assert_true(rig.part_node(StringName("rocket_%d" % (i + 1))).visible, "arrow %d back" % (i + 1))


func test_the_bigger_volley_fills_the_third_row() -> void:
	holder.apply_upgrades({&"hwacha_volley": 1})
	var rig := _rig(&"hwacha")
	if rig == null:
		return
	await physics_frames(3)
	assert_true(rig.part_node(&"upg_box9").visible)
	for i in 9:
		assert_true(rig.part_node(StringName("rocket_%d" % (i + 1))).visible, "arrow %d" % (i + 1))
