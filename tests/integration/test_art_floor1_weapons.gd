extends TestCase
## The Floor I weapon art (Blender, design 7.1 / 7.1a / 10.2): the three new
## viewmodels with the parts and markers the game animates, their master
## finish texture sets, the projectiles and the ammo pickups; every weapon
## model carries the upgrade parts of its upgrades.

const VIEWMODELS: Array[StringName] = [&"vm_rifle_hunt", &"vm_harpoon", &"vm_hwacha"]
const ALL_VIEWMODELS := {&"vm_fists": &"fist", &"vm_taser": &"taser", &"vm_pistol": &"pistol",
	&"vm_shotgun": &"shotgun", &"vm_gatling": &"gatling", &"vm_flare": &"flare",
	&"vm_rifle_hunt": &"rifle_hunt", &"vm_harpoon": &"harpoon", &"vm_hwacha": &"hwacha"}
const PICKUPS: Array[StringName] = [&"ammo_rifle_hunt", &"ammo_harpoon", &"ammo_hwacha"]


func _spawn(id: StringName) -> Node3D:
	var node := ArtLibrary.instance(id)
	add_child(node)
	return node


func test_the_new_viewmodels_carry_their_parts_and_markers() -> void:
	for id in VIEWMODELS:
		assert_true(ArtLibrary.has_model(id), String(id))
		if not ArtLibrary.has_model(id):
			continue
		var node := _spawn(id)
		var parts := ArtLibrary.parts(node)
		for part in ArtLibrary.REGISTRY[id]:
			assert_true(parts.has(part), "%s has %s" % [id, part])
		var muzzle := node.get_node_or_null(^"Muzzle") as Node3D
		assert_not_null(muzzle, "%s: Muzzle is a child of the root" % id)
		if muzzle != null:
			assert_lt(muzzle.position.z, -0.2, "%s: the muzzle is ahead" % id)
		node.queue_free()


func test_every_weapon_model_has_the_parts_of_its_upgrades_and_a_master_finish() -> void:
	for id in ALL_VIEWMODELS:
		if not ArtLibrary.has_model(id):
			fail("%s missing" % id)
			continue
		var node := _spawn(id)
		var parts := ArtLibrary.parts(node)
		for part in WeaponLook.all_parts(ALL_VIEWMODELS[id]):
			assert_true(parts.has(part), "%s has upgrade part %s" % [id, part])
		for part in WeaponLook.replaceable_parts(ALL_VIEWMODELS[id]):
			assert_true(parts.has(part), "%s has %s" % [id, part])
		assert_not_null(ArtLibrary.texture(String(id) + "_master", "albedo"), "%s_master texture set" % id)
		node.queue_free()


func test_the_projectiles_have_their_markers() -> void:
	var harpoon := _spawn(&"harpoon_bolt")
	var parts := ArtLibrary.parts(harpoon)
	for part in ["harpoon_bolt", "barbs", "Tail", "Tip"]:
		assert_true(parts.has(part), "harpoon_bolt has " + part)
	if parts.has("Tip") and parts.has("Tail"):
		assert_lt((parts["Tip"] as Node3D).position.z, (parts["Tail"] as Node3D).position.z, "the tip flies ahead (-Z)")
	var rocket := _spawn(&"hwacha_rocket")
	assert_true(ArtLibrary.parts(rocket).has("Exhaust"))


func test_the_ammo_pickups_glow_like_the_others() -> void:
	for id in PICKUPS:
		var pickup := ArtLibrary.pickup(id)
		assert_not_null(pickup, String(id))
		if pickup == null:
			continue
		add_child(pickup)
		var mesh := pickup.find_child(String(id), true, false) as MeshInstance3D
		assert_not_null(mesh, "%s mesh" % id)
		pickup.queue_free()
