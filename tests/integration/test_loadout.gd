extends TestCase
## The guard's kit at the start of a night.

var player: Player
var game: PersistentState


func before_each() -> void:
	game = PersistentState.new()
	add_child(game)
	player = Player.new()
	add_child(player)


func test_new_guard_has_fists_and_taser_only() -> void:
	Loadout.equip_night_start(player, game)
	assert_eq(player.weapons.owned.size(), 1)
	assert_eq(player.weapons.current_state().data.id, &"taser")
	assert_not_null(player.weapons.fists)


func test_found_weapons_start_with_design_ammo() -> void:
	game.add_weapon(&"pistol")
	game.add_weapon(&"shotgun")
	Loadout.equip_night_start(player, game)
	var pistol := player.weapons.state_of(&"pistol")
	var shotgun := player.weapons.state_of(&"shotgun")
	assert_eq([pistol.magazine, pistol.reserve], [12, 24])
	assert_eq([shotgun.magazine, shotgun.reserve], [2, 6])
	assert_eq(player.weapons.current_state().data.id, &"pistol", "the pistol comes out first")


func test_magazine_upgrade_starts_full_at_18() -> void:
	game.add_weapon(&"pistol")
	game.upgrades = {&"pistol_mag": 1, &"health": 1}
	Loadout.equip_night_start(player, game)
	var pistol := player.weapons.state_of(&"pistol")
	assert_eq([pistol.magazine, pistol.reserve], [18, 24])
	assert_eq(player.health.current, 120.0, "full health with the upgrade")


## Balance (1.10 review): a box and a half belts for the gatling, a flare
## in the barrel and four spare.
func test_the_expansion_weapons_start_with_their_balance() -> void:
	game.add_weapon(&"gatling")
	game.add_weapon(&"flare")
	Loadout.equip_night_start(player, game)
	var gatling := player.weapons.state_of(&"gatling")
	var flare := player.weapons.state_of(&"flare")
	assert_eq([gatling.magazine, gatling.reserve], [120, 60])
	assert_eq([flare.magazine, flare.reserve], [1, 4])


## Deep pockets fill the bigger pockets too: the night's spare ammo grows
## with them (rounded, never past the cap).
func test_deep_pockets_start_the_night_with_more_spare_ammo() -> void:
	for id in [&"pistol", &"shotgun", &"gatling", &"flare"]:
		game.add_weapon(id)
	game.upgrades = {&"pockets": 2}
	Loadout.equip_night_start(player, game)
	var expected := {&"pistol": 36, &"shotgun": 9, &"gatling": 90, &"flare": 6}
	for id: StringName in expected:
		assert_eq(player.weapons.state_of(id).reserve, expected[id], "%s with two levels of pockets" % id)


## ... and every ammo box picked up gives that much more.
func test_deep_pockets_get_more_out_of_every_box() -> void:
	game.add_weapon(&"pistol")
	game.add_weapon(&"gatling")
	game.upgrades = {&"pockets": 1}
	Loadout.equip_night_start(player, game)
	var pistol := player.weapons.state_of(&"pistol")
	var gatling := player.weapons.state_of(&"gatling")
	pistol.reserve = 0
	gatling.reserve = 0
	var bullets := Pickup.new()
	bullets.type = Pickup.Type.BULLETS
	bullets.amount = 12
	add_child(bullets)
	var belt := Pickup.new()
	belt.type = Pickup.Type.RIFLE
	belt.amount = 50
	add_child(belt)
	assert_true(bullets.apply_to(player))
	assert_true(belt.apply_to(player))
	assert_eq(pistol.reserve, 15, "12 x 1.25")
	assert_eq(gatling.reserve, 63, "50 x 1.25, rounded")
