extends TestCase
## The content dev arena: every weapon, the two finds (in dev mode, which
## saves nothing), the gallery wall, raptor packs, lights off.

var dev: ContentDev


func before_each() -> void:
	GameInput.capture_allowed = false
	dev = (load("res://src/dev/content_dev.tscn") as PackedScene).instantiate() as ContentDev
	add_child(dev)


func after_each() -> void:
	GameInput.capture_allowed = true


func test_the_guard_carries_all_five_weapons_with_full_ammo() -> void:
	await physics_frames(3)
	var ids: Array = dev.player.weapons.owned.map(func(s: WeaponState) -> StringName: return s.data.id)
	assert_eq(ids, [&"taser", &"pistol", &"shotgun", &"gatling", &"flare"])
	var gatling := dev.player.weapons.state_of(&"gatling")
	assert_eq(gatling.reserve, gatling.data.max_reserve)
	assert_eq(dev.player.weapons.current_state().data.id, &"gatling")


func test_the_gallery_mixes_live_portraits_among_paintings() -> void:
	await physics_frames(2)
	assert_eq(dev.portraits.size(), ContentDev.LIVE_PORTRAITS)
	assert_eq(dev.gallery.get_child_count(), ContentDev.GALLERY_SPOTS.size())
	dev.hang_gallery()
	await physics_frames(1)
	assert_eq(dev.gallery.get_child_count(), ContentDev.GALLERY_SPOTS.size(), "a fresh wall replaces the old one")


func test_a_pack_comes_on_key_6_and_the_lights_go_out_on_l() -> void:
	await physics_frames(2)
	var before := dev.enemies_root.get_child_count()
	var pack := dev.spawn_pack()
	assert_true(pack.size() >= 3 and pack.size() <= 4)
	assert_eq(dev.enemies_root.get_child_count(), before + pack.size())
	dev.set_lights(false)
	assert_false(dev.lights_on)
	dev.set_lights(true)
	assert_true(dev.lights_on)


func test_finds_in_the_dev_arena_save_nothing() -> void:
	await physics_frames(2)
	dev.display.break_chain()
	dev.display.interact(dev.player)
	dev.cabinet.interact(dev.player)
	dev.cabinet.interact(dev.player)
	assert_eq(dev.display.state, ChainedDisplay.State.EMPTY)
	assert_eq(dev.cabinet.state, EmergencyCabinet.State.EMPTY)
	assert_false(GameState.has_weapon(&"gatling"), "no record")
	assert_false(FileAccess.file_exists(GameState.path()), "no save written")
