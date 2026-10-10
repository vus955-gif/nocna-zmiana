extends TestCase
## Upgrades show on the first-person models (design 7.1a): the bought
## levels switch their parts on (and the parts they replace off), the
## master finish polishes the weapon and lights its signature part, a new
## look is inspected when the weapon is next drawn, and a weapon lying in
## the world shows none of it.

var holder: WeaponHolder


func before_each() -> void:
	holder = WeaponHolder.new()
	add_child(holder)


func _give(id: StringName) -> ViewmodelRig:
	holder.give(load("res://src/weapons/data/%s.tres" % id))
	return holder.view_of(id) as ViewmodelRig


func _top_levels(weapon: StringName) -> Dictionary:
	var levels := {}
	for id in WeaponLook.upgrades_of(weapon):
		levels[id] = UpgradeCatalog.max_level(id)
	return levels


func test_parts_follow_the_bought_levels_on_every_model() -> void:
	var found := 0
	for id in WeaponHolder.SLOT_ORDER:
		var rig := _give(id)
		if rig == null:
			continue   # no model: the greybox has no upgrade parts
		for part in WeaponLook.all_parts(id):
			var node := rig.part_node(StringName(part))
			if node == null:
				continue
			found += 1
			assert_false(node.visible, "%s hidden before it is bought" % part)
	holder.apply_upgrades(_all_top())
	for id in WeaponHolder.SLOT_ORDER:
		var rig := holder.view_of(id) as ViewmodelRig
		if rig == null:
			continue
		for part in WeaponLook.all_parts(id):
			var node := rig.part_node(StringName(part))
			if node != null:
				assert_true(node.visible, "%s shown once bought" % part)
		for part in WeaponLook.replaceable_parts(id):
			var node := rig.part_node(StringName(part))
			if node != null:
				assert_false(node.visible, "%s replaced" % part)
	assert_gt(found, 0, "the models carry upgrade parts")


func test_the_master_finish_polishes_and_lights_the_signature() -> void:
	var rig := _give(&"shotgun")
	if rig == null:
		return
	var body := rig.part_node(&"shotgun") as MeshInstance3D
	var plain := body.get_surface_override_material(0)
	holder.apply_upgrades({&"shotgun_spread": 1})
	assert_false(rig.mastered(), "one of two")
	holder.apply_upgrades(_top_levels(&"shotgun"))
	assert_true(rig.mastered())
	var polished := body.get_surface_override_material(0) as BaseMaterial3D
	assert_ne(polished, plain, "a new finish")
	assert_true(polished.clearcoat_enabled, "a warm sheen")
	var choke := rig.part_node(&"upg_choke") as MeshInstance3D
	if choke != null:
		var glow := choke.get_surface_override_material(0) as BaseMaterial3D
		assert_true(glow.emission_enabled, "the signature part glows")
	var hand := rig.part_node(&"hand_r") as MeshInstance3D
	if hand != null:
		assert_false((hand.get_surface_override_material(0) as BaseMaterial3D).clearcoat_enabled, "hands stay as they are")
	holder.apply_upgrades({})
	assert_false(rig.mastered())
	assert_eq(body.get_surface_override_material(0), plain, "back to the plain finish")


func test_a_new_look_is_inspected_when_the_weapon_is_drawn() -> void:
	_give(&"pistol")
	var rig := _give(&"shotgun")
	if rig == null:
		return
	holder.select_id(&"pistol")
	await physics_frames(2)
	holder.apply_upgrades({&"shotgun_spread": 1})
	assert_true(rig.inspect_pending(), "waits for the next draw")
	await physics_frames(5)
	assert_true(rig.inspect_pending(), "still waiting in the holster")
	holder.select_id(&"shotgun")
	assert_gt(rig.inspecting(), 1.0, "looked over at once")
	assert_false(rig.inspect_pending())
	await physics_frames(roundi(ViewmodelRig.INSPECT_TIME * 60.0) + 5)
	assert_eq(rig.inspecting(), 0.0, "and back to work")


func test_the_same_levels_again_are_no_news() -> void:
	var rig := _give(&"shotgun")
	if rig == null:
		return
	holder.apply_upgrades({&"shotgun_spread": 1})
	await physics_frames(roundi(ViewmodelRig.INSPECT_TIME * 60.0) + 5)
	holder.apply_upgrades({&"shotgun_spread": 1, &"health": 2})
	assert_false(rig.inspect_pending(), "nothing new on this weapon")
	assert_eq(rig.inspecting(), 0.0)


func test_a_weapon_in_the_world_shows_no_upgrade_parts() -> void:
	for id in [&"shotgun", &"rifle_hunt", &"harpoon", &"hwacha"]:
		var view := Viewmodels.world(id)
		if view == null:
			continue
		add_child(view)
		for node in view.find_children(WeaponLook.PART_PREFIX + "*", "Node3D", true, false):
			assert_false((node as Node3D).visible, "%s on the %s in the world" % [node.name, id])
		view.queue_free()


func _all_top() -> Dictionary:
	var levels := {}
	for entry in UpgradeCatalog.all():
		levels[entry.id] = entry.max_level()
	return levels


func test_a_purchase_flashes_the_terminal() -> void:
	var terminal := UpgradeTerminal.new()
	add_child(terminal)
	await physics_frames(1)
	assert_eq(terminal.flash_left(), 0.0)
	Events.upgrade_bought.emit(&"rifle_bolt", 1)
	assert_eq(terminal.flash_left(), 1.0, "a gold flash")
	await physics_frames(60)
	assert_eq(terminal.flash_left(), 0.0, "gone in a moment")
