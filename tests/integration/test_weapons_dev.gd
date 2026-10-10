extends TestCase
## The Floor I weapons dev arena: all eight weapons with full ammo, every
## gate lock in the gallery, fresh locks on K, every upgrade (the master
## finish) on U and none on J.

var dev: WeaponsDev


func before_each() -> void:
	GameInput.capture_allowed = false
	dev = (load("res://src/dev/weapons_dev.tscn") as PackedScene).instantiate() as WeaponsDev
	add_child(dev)


func after_each() -> void:
	GameInput.capture_allowed = true


func test_the_guard_carries_all_eight_with_full_ammo() -> void:
	await physics_frames(3)
	var ids: Array = dev.player.weapons.owned.map(func(s: WeaponState) -> StringName: return s.data.id)
	assert_eq(ids, Array(WeaponHolder.SLOT_ORDER))
	var hwacha := dev.player.weapons.state_of(&"hwacha")
	assert_eq(hwacha.reserve, hwacha.data.max_reserve)
	assert_eq(dev.player.weapons.current_state().data.id, &"rifle_hunt")


func test_every_kind_of_lock_stands_in_the_gallery() -> void:
	await physics_frames(3)
	var kinds := {}
	for lock in dev.locks:
		kinds[lock.kind] = true
		assert_false(lock.is_open, str(lock.gate_id))
	assert_eq(kinds.size(), GateLock.Kind.size())
	dev.locks[0].open()
	dev.build_locks()
	await physics_frames(2)
	assert_false(dev.locks[0].is_open, "K builds them fresh")


func test_every_upgrade_puts_the_master_finish_on_and_off() -> void:
	await physics_frames(3)
	dev.set_all_upgrades(true)
	for id in WeaponHolder.SLOT_ORDER:
		var view := dev.player.weapons.view_of(id)
		if view is ViewmodelRig:
			assert_true((view as ViewmodelRig).mastered(), str(id))
	assert_eq(dev.player.weapons.state_of(&"hwacha").data.volley_count, 9)
	dev.set_all_upgrades(false)
	for id in WeaponHolder.SLOT_ORDER:
		var view := dev.player.weapons.view_of(id)
		if view is ViewmodelRig:
			assert_false((view as ViewmodelRig).mastered(), str(id))
	assert_eq(dev.player.weapons.state_of(&"hwacha").data.volley_count, 6)
