extends TestCase
## The secrets' rewards in the world (plan 2026-10-10-nagrody-sekretow): a
## display at every secret marker (a strongbox, a pedestal, a case) that
## the secret's discovery lights up; E takes the reward - a pouch of Dust,
## a permanent bonus applied at once and saved, a finish or a mod the
## weapon shows; claimed on an earlier night, the display stands empty and
## the bonus holds from the start; a small secret's stash restocks every
## night but not within one.

var museum: Museum


func before_each() -> void:
	Museum.level_id = &"floor1"


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _museum() -> Museum:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	return museum


func _world() -> WorldFeatures:
	return museum.floor_game.world


func _display(id: StringName) -> SecretRewardDisplay:
	return _world().rewards.get(id) as SecretRewardDisplay


func test_every_secret_has_its_display_at_its_marker_dark_until_found() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var world := _world()
	assert_eq(world.rewards.size(), SecretRewards.total(), "one display per reward")
	for id in SecretRewards.ids():
		var display := _display(id)
		assert_not_null(display, String(id))
		if display == null:
			continue
		var marker: Transform3D = museum.floor_level.markers[id]
		var layout: LevelLayout = museum.floor_level.layout
		var aside := Vector2(display.global_position.x - marker.origin.x, display.global_position.z - marker.origin.z)
		assert_lt(aside.length(), 0.6, "%s stands at its marker" % id)
		assert_almost_eq(display.global_position.y, layout.room(layout.marker_rooms[id]).floor_y, 0.001, "%s on its room's floor" % id)
		assert_true(display.global_transform.is_equal_approx(RewardSpot.place(layout, id, marker, display.tier)), "%s where RewardSpot puts it (clear of the pieces, plaque to the way in)" % id)
		assert_eq(display.tier, SecretRewards.tier_of(id), String(id))
		assert_false(display.is_taken, String(id))
		assert_false(display.lit, "%s dark until the secret is found" % id)
		assert_true(display.has_node(^"Plaque"), "%s carries its label" % id)
	assert_false(_display(&"secret_court_1").visible, "the court's drawer stays shut until the stone is out")
	assert_true(_display(&"secret_egypt_2").visible, "a display in a secret room stands there from the start")


func test_discovering_a_secret_lights_its_display_and_names_the_tier() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var world := _world()
	assert_true(world.discover_secret(&"secret_egypt_2"))
	assert_true(_display(&"secret_egypt_2").lit, "the reflector comes on")
	assert_eq(world.found_tonight, 1)
	var banner := world.hud.current()
	assert_eq(banner[0], tr("SECRET_FOUND") % [1, world.secrets_total()])
	assert_eq(banner[2], "W środku czeka: Znalezisko")
	assert_eq(world.secrets_total(), SecretRewards.total())


func test_the_courts_drawer_shows_its_strongbox_once_the_stone_is_out() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var world := _world()
	var cache := world.secrets[&"secret_court_1"][0] as SecretCache
	assert_not_null(cache, "a loose stone in the open hub")
	if cache == null:
		return
	var display := _display(&"secret_court_1")
	assert_eq(display.collision_layer, 0, "nothing to use through the counter before the stone is out")
	cache.interact(museum.player)
	await physics_frames(1)
	assert_true(display.visible, "the strongbox shows")
	assert_true(display.lit)
	assert_eq(display.collision_layer, Layers.INTERACT, "and can be used")
	assert_eq(display.tier, SecretRewards.Tier.SMALL)


func test_a_display_stays_still_until_its_secret_is_found_and_again_once_it_is_taken() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var world := _world()
	var display := _display(&"secret_egypt_2")
	assert_false(display.is_processing(), "dark: nothing to turn or flicker")
	world.discover_secret(&"secret_egypt_2")
	assert_true(display.is_processing(), "lit: the exhibit turns")
	display.interact(museum.player)
	assert_false(display.is_processing(), "taken: the cushion is empty")


func test_a_found_secrets_display_turns_from_the_start_of_the_night() -> void:
	GameState.new_game()
	GameState.secrets = [&"secret_egypt_2", &"secret_booth_1"] as Array[StringName]
	GameState.claim_reward(&"secret_booth_1")
	_museum()
	await physics_frames(2)
	assert_true(_display(&"secret_egypt_2").is_processing(), "found and not taken")
	assert_false(_display(&"secret_booth_1").is_processing(), "found and taken on an earlier night")


func test_an_opened_strongbox_lid_stands_up_it_does_not_fall_into_the_box() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var display := _display(&"secret_egypt_1")
	var lid := display.get_node(^"Lid") as Node3D
	var plate := lid.get_child(0) as Node3D
	var shut := plate.global_position.y - lid.global_position.y
	assert_lt(shut, 0.05, "shut: the plate lies on the hinge")
	display.reveal(true)
	var open := plate.global_position.y - lid.global_position.y
	assert_gt(open, 0.1, "open: the plate is up over the hinge")
	assert_gt(open, shut + 0.1)


func test_a_find_raises_the_guards_numbers_at_once_announces_and_saves() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var world := _world()
	var claimed := watch(world.reward_claimed)
	assert_eq(museum.player.health.max_health, 100.0)
	var display := _display(&"secret_egypt_2")
	assert_eq(display.prompt(), "Weź: Amulet skarabeusza")
	display.interact(museum.player)
	assert_true(GameState.secret_rewards.has(&"secret_egypt_2"))
	assert_eq(museum.player.health.max_health, 110.0, "+10 at once")
	assert_true(display.is_taken)
	assert_eq(display.collision_layer, 0, "no use-zone left")
	assert_true(GameState.has_save(), "saved at once")
	assert_eq(claimed, [[&"secret_egypt_2", null, null, null]])
	assert_eq(world.rewards_claimed(), 1)
	var banner := world.hud.current()
	assert_eq(banner[0], "Nagroda sekretu · Znalezisko")
	assert_eq(banner[1], "Amulet skarabeusza")
	assert_eq(banner[2], "+10 do maksymalnego zdrowia.")
	display.interact(museum.player)
	assert_eq(claimed.size(), 1, "claimed once")
	assert_eq(museum.player.health.max_health, 110.0)


func test_a_pouch_adds_dust_and_a_treasure_dresses_the_weapon() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var world := _world()
	var dust := RunState.dust
	var earned := int(GameState.stats["dust_earned"])
	_display(&"secret_egypt_1").interact(museum.player)
	assert_eq(RunState.dust, dust + SecretRewards.POUCH_DUST)
	assert_eq(int(GameState.stats["dust_earned"]), earned + SecretRewards.POUCH_DUST, "counted with the Dust gathered")
	var weapons := museum.player.weapons
	weapons.give(load("res://src/weapons/data/shotgun.tres"))
	weapons.give(load("res://src/weapons/data/rifle_hunt.tres"))
	weapons.select_id(&"taser")
	_display(&"secret_egypt_3").interact(museum.player)
	var rig := weapons.view_of(&"shotgun") as ViewmodelRig
	assert_not_null(rig, "the shotgun has its first-person model")
	if rig != null:
		assert_eq(rig.look(), &"faience", "the faience finish is on")
		assert_true(rig.inspect_pending(), "to be looked over when drawn")
	_display(&"secret_greece_3").interact(museum.player)
	assert_true(weapons.state_of(&"rifle_hunt").data.lock_breaker, "the peep sight works at once")
	var rifle := weapons.view_of(&"rifle_hunt") as ViewmodelRig
	assert_not_null(rifle, "the rifle has its first-person model")
	if rifle != null:
		var peep := rifle.part_node(&"mod_rifle_peep")
		assert_not_null(peep, "the peep sight is on the rifle")
		assert_true(peep != null and peep.visible, "and shows")
	assert_eq(world.rewards_claimed(), 3)


func test_rewards_claimed_earlier_stand_empty_and_their_bonus_holds_from_the_start() -> void:
	GameState.new_game()
	GameState.claim_reward(&"secret_egypt_2")
	GameState.claim_reward(&"secret_booth_1")
	GameState.secrets = [&"secret_egypt_2", &"secret_booth_1"] as Array[StringName]
	_museum()
	await physics_frames(2)
	var display := _display(&"secret_egypt_2")
	assert_true(display.is_taken, "the cushion is empty")
	assert_true(display.lit, "the reflector stays on over a found secret")
	assert_eq(display.collision_layer, 0)
	assert_eq(museum.player.health.max_health, 110.0, "the amulet's step from the night's start")
	assert_eq(museum.player.stamina.maximum, 110.0, "the canteen's step too")
	assert_false(_world().hud.is_busy(), "nothing announced again")


func test_the_stash_restocks_each_night_but_not_within_one() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var world := _world()
	var stash: Array = world.stashes[&"secret_egypt_1"]
	assert_eq(stash.size(), 2, "shells and a medkit")
	var kinds := stash.map(func(p: Pickup) -> Pickup.Type: return p.type)
	assert_true(kinds.has(Pickup.Type.SHELLS) and kinds.has(Pickup.Type.MEDKIT))
	var display := _display(&"secret_egypt_1")
	for pickup: Pickup in stash:
		assert_lt(pickup.global_position.distance_to(display.global_position), 1.5, "beside the strongbox")
		assert_eq(pickup.respawn_time, 0.0)
	assert_false(world.stashes.has(&"secret_court_1"), "no stash in the open hub")
	_assert_stashes_in_the_clear(world)
	(stash[0] as Pickup).taken.emit()
	assert_true(RunState.is_used(&"stash_secret_egypt_1_0"), "the night remembers")
	GameState.save_game()   # the night's progress goes into the save ("Continue")
	museum.free()
	_museum()
	await physics_frames(2)
	assert_eq((_world().stashes[&"secret_egypt_1"] as Array).size(), 1, "within the night: one left")
	NightRules.on_dawn(GameState, RunState)
	museum.free()
	_museum()
	await physics_frames(2)
	assert_eq((_world().stashes[&"secret_egypt_1"] as Array).size(), 2, "the next night restocks")


## Every stash lies in its room and in no piece (the displays are turned to
## their room's way in, so the stashes beside them turn with them).
func _assert_stashes_in_the_clear(world: WorldFeatures) -> void:
	var layout: LevelLayout = museum.floor_level.layout
	var checked := 0
	for id: StringName in world.stashes:
		var room := layout.room(layout.marker_rooms[id])
		for pickup: Pickup in world.stashes[id]:
			checked += 1
			assert_true(room.covers(Vector2(pickup.global_position.x, pickup.global_position.z)), "%s: the stash lies in its room" % id)
			for piece in layout.pieces:
				if not piece.collide or LevelKit.role(piece.kit) == &"floor":
					continue
				if piece.position.y > pickup.global_position.y or piece.position.y + piece.size.y < pickup.global_position.y:
					continue
				var local := piece.transform().affine_inverse() * pickup.global_position
				assert_false(absf(local.x) < piece.size.x * 0.5 and absf(local.z) < piece.size.z * 0.5, "%s: the stash is not in a %s" % [id, piece.kit])
	assert_gt(checked, 3, "the small secrets' stashes were looked at")


## (plan 2026-10-19-glos-g2-kwestie: Heniek and the System comment the finds)
func test_discovering_a_secret_tells_the_voice_its_tier() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var told := watch(Events.secret_found)
	_world().discover_secret(&"secret_egypt_3")
	assert_eq(told.size(), 1)
	if told.size() > 0:
		assert_eq(told[0][0], &"secret_egypt_3")
		assert_eq(told[0][1], SecretRewards.Tier.GREAT)
		assert_eq(told[0][2], 1, "the first secret found")
