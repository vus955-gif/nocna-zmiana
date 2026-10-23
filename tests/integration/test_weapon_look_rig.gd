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
	# once it is up in the hands (WeaponSwitch), not under the frame
	await physics_frames(roundi((ViewmodelMotion.holster_time(&"pistol") + ViewmodelMotion.draw_time(&"shotgun")) * 60.0))
	assert_gt(rig.inspecting(), 1.0, "looked over as it comes up")
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


func test_a_finish_tints_the_weapon_lights_its_signature_and_comes_off_again() -> void:
	var rig := _give(&"shotgun")
	assert_not_null(rig, "the shotgun has its first-person model")
	if rig == null:
		return
	var body := rig.part_node(&"shotgun") as MeshInstance3D
	var plain := body.get_surface_override_material(0) as BaseMaterial3D
	var spec: Dictionary = WeaponLook.LOOKS[&"faience"]
	holder.apply_upgrades({&"look_shotgun_faience": 1})
	assert_eq(rig.look(), &"faience")
	assert_false(rig.mastered(), "a finish is no mastery")
	var glazed := body.get_surface_override_material(0) as BaseMaterial3D
	assert_ne(glazed, plain, "a new material")
	assert_true(glazed.albedo_color.is_equal_approx(spec["tint"]), "the glaze over the texture")
	assert_eq(glazed.albedo_texture, plain.albedo_texture, "the same texture under it")
	assert_true(glazed.use_fov_override, "still a viewmodel material")
	var checked := 0
	var choke := rig.part_node(&"upg_choke") as MeshInstance3D
	if choke != null:
		checked += 1
		var glow := choke.get_surface_override_material(0) as BaseMaterial3D
		assert_true(glow.emission_enabled, "the signature part glows")
		assert_true(glow.emission.is_equal_approx(spec["accent"]), "in the finish's accent")
	var hand := rig.part_node(&"hand_r") as MeshInstance3D
	if hand != null:
		checked += 1
		assert_true((hand.get_surface_override_material(0) as BaseMaterial3D).albedo_color.is_equal_approx(Color.WHITE), "the gloves keep their look")
	assert_eq(checked, 2, "the signature part and the hand were both on the model")
	# mastery and the finish together: the master sheen under the glaze
	var levels := _top_levels(&"shotgun")
	levels[&"look_shotgun_faience"] = 1
	holder.apply_upgrades(levels)
	assert_true(rig.mastered())
	assert_eq(rig.look(), &"faience")
	var both := body.get_surface_override_material(0) as BaseMaterial3D
	assert_true(both.clearcoat_enabled, "the master sheen")
	assert_true(both.albedo_color.is_equal_approx(spec["tint"]), "and the glaze")
	holder.apply_upgrades(_top_levels(&"shotgun"))
	assert_eq(rig.look(), &"")
	assert_true((body.get_surface_override_material(0) as BaseMaterial3D).albedo_color.is_equal_approx(Color.WHITE), "the master finish alone")
	holder.apply_upgrades({})
	assert_eq(body.get_surface_override_material(0), plain, "back to the plain finish")


func test_a_finish_is_news_the_weapon_looks_over() -> void:
	_give(&"pistol")
	var rig := _give(&"shotgun")
	assert_not_null(rig, "the shotgun has its first-person model")
	if rig == null:
		return
	holder.select_id(&"pistol")
	await physics_frames(2)
	holder.apply_upgrades({&"look_shotgun_faience": 1})
	assert_true(rig.inspect_pending(), "a new finish is looked over on the next draw")


func test_a_mod_puts_its_part_on_the_model_and_takes_it_off_again() -> void:
	var checked := 0
	for mod: StringName in WeaponLook.MODS:
		var spec: Dictionary = WeaponLook.MODS[mod]
		var rig := _give(spec["weapon"])
		if rig == null:
			continue
		checked += 1
		var part_name := StringName(spec["part"])
		var before := rig.part_node(part_name)
		assert_true(before == null or not before.visible, "%s off before it is found" % mod)
		holder.apply_upgrades({WeaponLook.mod_key(mod): 1})
		var part := rig.part_node(part_name)
		assert_not_null(part, "%s: its part is on the model" % mod)
		if part == null:
			continue
		assert_true(part.visible)
		assert_true(part is MeshInstance3D and (part as MeshInstance3D).mesh != null, "%s: a real piece" % mod)
		assert_eq((part as VisualInstance3D).layers, ArtLibrary.VIEWMODEL_LAYER, "%s: on the first-person layer" % mod)
		assert_lt(part.position.length(), 0.8, "%s: on the weapon, not floating off it" % mod)
		assert_true(rig.inspect_pending(), "%s: looked over" % mod)
		holder.apply_upgrades({})
		assert_false(part.visible, "%s: taken off" % mod)
	assert_gt(checked, 0, "the models were there")


func test_the_choke_sits_on_the_barrels_the_peep_sight_behind_the_bolt_the_spool_by_the_reel() -> void:
	var shotgun := _give(&"shotgun")
	var rifle := _give(&"rifle_hunt")
	var harpoon := _give(&"harpoon")
	assert_not_null(shotgun, "the shotgun's model")
	assert_not_null(rifle, "the rifle's model")
	assert_not_null(harpoon, "the harpoon gun's model")
	if shotgun == null or rifle == null or harpoon == null:
		return
	holder.apply_upgrades({&"mod_shotgun_choke": 1, &"mod_rifle_peep": 1, &"mod_harpoon_line": 1})
	var choke := shotgun.part_node(&"mod_shotgun_choke") as Node3D
	var muzzle := shotgun.model.get_node(^"Muzzle") as Node3D
	var upgrade := shotgun.part_node(&"upg_choke") as MeshInstance3D
	var peep := rifle.part_node(&"mod_rifle_peep") as Node3D
	var bolt := rifle.part_node(&"bolt") as MeshInstance3D
	var spool := harpoon.part_node(&"mod_harpoon_line") as Node3D
	var reel := harpoon.part_node(&"upg_reel") as Node3D
	var found := 0
	for part in [choke, muzzle, upgrade, peep, bolt, spool, reel]:
		if part != null:
			found += 1
	assert_eq(found, 7, "the fittings and the parts they sit by were all on the models")
	if found < 7:
		return
	var to_model := shotgun.model.global_transform.affine_inverse()
	var choke_at := to_model * choke.global_position
	var upgrade_at := to_model * upgrade.global_position
	assert_lt(choke_at.distance_to(muzzle.position), 0.08, "the collar at the muzzle end of the barrels")
	assert_gt(choke_at.z, upgrade_at.z + 0.02, "behind the spread upgrade's choke, never through it")
	assert_gt(peep.position.z, bolt.position.z + 0.05, "behind the bolt (the hand runs the knob in front)")
	assert_gt(peep.position.y, 0.02, "up on the tang")
	assert_gt(spool.position.x, 0.05, "on the reel's side")
	assert_lt(spool.position.z, reel.position.z - 0.06, "ahead of the reel, not through it")


## (The night's QA, 19.10, in the window: the collar was a solid round
## disc 10 cm across round the side-by-side barrels - a gold plate over the
## muzzle end - and it stayed where it was when the barrels broke open for a
## reload, floating in front of the guard.)
func test_the_choke_collar_rides_the_barrels_and_fits_round_them() -> void:
	var shotgun := _give(&"shotgun")
	assert_not_null(shotgun, "the shotgun's model")
	if shotgun == null:
		return
	holder.select_id(&"shotgun")
	holder.apply_upgrades({&"mod_shotgun_choke": 1})
	var collar := shotgun.part_node(&"mod_shotgun_choke") as MeshInstance3D
	var barrels := shotgun.part_node(&"barrels")
	var choke := shotgun.part_node(&"upg_choke") as MeshInstance3D
	assert_not_null(collar, "the collar")
	if collar == null or barrels == null or choke == null:
		return
	assert_eq(collar.get_parent(), barrels, "on the barrels: it breaks open with them")
	# round the barrels' cross-section (the spread choke's), a few mm proud
	var muzzle := choke.get_aabb().size
	var band := collar.get_aabb().size
	assert_true(band.x > muzzle.x and band.x < muzzle.x + 0.015, "as wide as the pair of barrels and a little (%.3f for %.3f)" % [band.x, muzzle.x])
	assert_true(band.y > muzzle.y and band.y < muzzle.y + 0.015, "as high as a barrel and a little (%.3f for %.3f)" % [band.y, muzzle.y])
	assert_lt(band.z, 0.04, "a band, not a sleeve")
	# through the break it keeps its place on the barrels
	var gap := choke.global_transform.affine_inverse() * collar.global_position
	var state := holder.current_state()
	holder.try_fire()
	await physics_frames(20)
	holder.try_fire()
	await physics_frames(20)
	holder.try_reload()
	await physics_frames(roundi(state.data.reload_time * 60.0 * 0.5))
	assert_true(state.is_reloading(), "broken open")
	var now := choke.global_transform.affine_inverse() * collar.global_position
	assert_lt(now.distance_to(gap), 0.001, "the collar went with the barrels")


func test_a_finish_multiplies_a_coloured_part_it_does_not_repaint_it() -> void:
	var source := StandardMaterial3D.new()
	source.resource_name = "coloured_part_for_the_finish_test"
	source.albedo_color = Color(0.5, 0.25, 0.9)
	source.roughness = 0.5
	var spec: Dictionary = WeaponLook.LOOKS[&"faience"]
	var finished := ViewmodelRig.look_material(source, &"faience")
	assert_true(finished.albedo_color.is_equal_approx(source.albedo_color * (spec["tint"] as Color)), "the part's own colour under the glaze")
	assert_false(finished.albedo_color.is_equal_approx(spec["tint"]), "not the glaze alone")
	assert_true(source.albedo_color.is_equal_approx(Color(0.5, 0.25, 0.9)), "the source material is left as it was")
