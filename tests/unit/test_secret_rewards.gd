extends TestCase
## The reward table of Floor I's secrets (plan 2026-10-10-nagrody-sekretow):
## every secret has one, the tiers are spread, a secret that costs resources
## to open pays back more than it costs, the bonuses stay modest, every text
## exists in both languages and says what the constants say, and the claimed
## rewards reach the guard as extra keys next to his upgrade levels.

## What opening a gate costs the guard, on the haven terminal's scale (Dust
## he would pay for the like). Rough, but it puts the rare things where they
## belong: a cracked wall eats three of the four flares a night starts with,
## a rope one rifle round, a chain or boards (and a bolt) only fists.
const GATE_COST := {
	GateSpec.Kind.CHAIN: 0.0,
	GateSpec.Kind.BOARDS: 0.0,
	GateSpec.Kind.BOLT: 0.0,
	GateSpec.Kind.ROPE: 3.0,
	GateSpec.Kind.HOOK: 5.0,
	GateSpec.Kind.CRACKED: 8.0,
}
## What a finish or a mod is worth on the same scale: more than any one step.
const GREAT_VALUE := 25.0
## The upgrade of the catalog each bonus is a step of.
const BONUS_UPGRADE := {&"health": &"health", &"stamina": &"stamina", &"battery": &"battery", &"pockets": &"pockets", &"magnet": &"dust_magnet"}

var game: PersistentState
var layout: LevelLayout


func before_each() -> void:
	game = PersistentState.new()
	add_child(game)
	layout = Floor1Layout.create()


func _secret_markers() -> Array[StringName]:
	var ids: Array[StringName] = []
	for marker: StringName in layout.markers:
		if String(marker).begins_with(WorldFeatures.SECRET_PREFIX):
			ids.append(marker)
	return ids


## The kinds of every gate on the secret's room (the ways in and the ways
## on: the pottery store has two, its own wall and the cellar's ring). Empty
## in an open room (a loose stone).
func _gate_kinds(secret: StringName) -> Array[int]:
	var kinds: Array[int] = []
	var room: StringName = layout.marker_rooms.get(secret, &"")
	if not layout.room(room).secret:
		return kinds
	for opening in layout.openings:
		if opening.room_a != room and opening.room_b != room:
			continue
		var gate := layout.gate_of_opening(opening.id)
		if gate != null:
			kinds.append(gate.kind)
	return kinds


func _cost(secret: StringName) -> float:
	var cost := 0.0
	for kind in _gate_kinds(secret):
		cost = maxf(cost, GATE_COST.get(kind, 0.0))
	return cost


## One level's effect of a catalog upgrade, from UpgradeEffects (what a
## bought level gives) or from the bonus keys (what one step gives).
func _effect(bonus: StringName, levels: Dictionary) -> float:
	match bonus:
		&"health":
			return UpgradeEffects.max_health(levels)
		&"stamina":
			return UpgradeEffects.stamina_max(levels)
		&"battery":
			return UpgradeEffects.battery_capacity(levels)
		&"pockets":
			return UpgradeEffects.reserve_factor(levels)
		&"magnet":
			return UpgradeEffects.dust_magnet_radius(levels)
	return 0.0


## The Dust the terminal asks for the same amount: the price of the
## upgrade's first level by what that level gives, times what the step gives.
func _value(entry: SecretRewards.Entry) -> float:
	match entry.tier:
		SecretRewards.Tier.SMALL:
			return float(SecretRewards.POUCH_DUST)
		SecretRewards.Tier.GREAT:
			return GREAT_VALUE
	var upgrade: StringName = BONUS_UPGRADE[entry.param]
	var per_level := _effect(entry.param, {upgrade: 1}) - _effect(entry.param, {})
	var per_step := _effect(entry.param, {SecretRewards.bonus_key(entry.param): 1}) - _effect(entry.param, {})
	return float(UpgradeCatalog.find(upgrade).prices[0]) * per_step / per_level


func test_every_secret_of_floor_one_has_a_reward_and_no_reward_is_stale() -> void:
	var markers := _secret_markers()
	assert_gt(markers.size(), 20, "Floor I has its secrets")
	for id in markers:
		assert_not_null(SecretRewards.entry(id), "%s has a reward" % id)
	for id in SecretRewards.ids():
		assert_true(markers.has(id), "%s is a secret of the floor" % id)
	assert_eq(SecretRewards.total(), markers.size())


func test_the_tiers_are_spread_and_the_great_ones_are_looks_and_mods() -> void:
	var counts := {SecretRewards.Tier.SMALL: 0, SecretRewards.Tier.MEDIUM: 0, SecretRewards.Tier.GREAT: 0}
	var looks := 0
	var mods := 0
	var weapons_with_a_look: Array[StringName] = []
	for entry in SecretRewards.entries():
		counts[entry.tier] += 1
		match entry.kind:
			SecretRewards.Kind.LOOK:
				looks += 1
				assert_eq(entry.tier, SecretRewards.Tier.GREAT, "%s: a look is a great reward" % entry.id)
				assert_false(weapons_with_a_look.has(entry.weapon), "one look per weapon (%s)" % entry.weapon)
				weapons_with_a_look.append(entry.weapon)
			SecretRewards.Kind.MOD:
				mods += 1
				assert_eq(entry.tier, SecretRewards.Tier.GREAT, "%s: a mod is a great reward" % entry.id)
			SecretRewards.Kind.BONUS:
				assert_eq(entry.tier, SecretRewards.Tier.MEDIUM, "%s: a bonus is a medium reward" % entry.id)
			SecretRewards.Kind.POUCH:
				assert_eq(entry.tier, SecretRewards.Tier.SMALL, "%s: a pouch is a small reward" % entry.id)
	for tier: int in counts:
		assert_gt(counts[tier], 2, "at least three of tier %d" % tier)
	assert_eq(looks, 8, "one finish for every firearm and the taser")
	assert_eq(mods, 3, "three behaviour mods")


func test_looks_and_mods_name_weapons_the_build_knows() -> void:
	for entry in SecretRewards.entries():
		if entry.kind == SecretRewards.Kind.LOOK or entry.kind == SecretRewards.Kind.MOD:
			assert_true(Loadout.WEAPON_PATHS.has(entry.weapon), "%s: %s is a weapon" % [entry.id, entry.weapon])
			assert_ne(entry.param, &"", "%s names its look or mod" % entry.id)
		if entry.kind == SecretRewards.Kind.BONUS:
			assert_true(SecretRewards.BONUSES.has(entry.param), "%s: %s is a bonus" % [entry.id, entry.param])


func test_a_secret_that_costs_resources_pays_back_a_permanent_reward() -> void:
	var costly := [GateSpec.Kind.CRACKED, GateSpec.Kind.HOOK]
	var checked := 0
	for id in _secret_markers():
		for kind in _gate_kinds(id):
			if kind in costly:
				checked += 1
				assert_true(SecretRewards.tier_of(id) >= SecretRewards.Tier.MEDIUM, "%s costs flares or a harpoon: at least a medium reward" % id)
				break
	assert_gt(checked, 8, "the cracked walls and the iron rings were found")


func test_no_secret_pays_less_than_its_gate_costs() -> void:
	var checked := 0
	var priciest := 0.0
	for id in _secret_markers():
		var cost := _cost(id)
		var value := _value(SecretRewards.entry(id))
		priciest = maxf(priciest, cost)
		checked += 1
		assert_true(value >= cost, "%s: worth %.1f behind a gate that costs %.1f" % [id, value, cost])
	assert_eq(checked, SecretRewards.total())
	assert_eq(priciest, GATE_COST[GateSpec.Kind.CRACKED], "the cracked walls are the dearest gates")


func test_a_stash_lies_only_in_a_secret_room() -> void:
	var stashes := 0
	for entry in SecretRewards.entries():
		if entry.stash.is_empty():
			continue
		stashes += 1
		assert_eq(entry.tier, SecretRewards.Tier.SMALL, "%s: only small rewards restock" % entry.id)
		var room := layout.room(layout.marker_rooms.get(entry.id, &""))
		assert_true(room != null and room.secret, "%s: the stash lies out of sight" % entry.id)
		for item in entry.stash:
			assert_true(Museum.LOOT_AMOUNTS.has(item), "%s: %s is loot" % [entry.id, item])
	assert_gt(stashes, 3)
	assert_true(SecretRewards.entry(&"secret_court_1").stash.is_empty(), "the court's drawer is in the open: no stash")


func test_all_bonuses_together_stay_modest() -> void:
	var steps := {}
	for entry in SecretRewards.entries():
		if entry.kind == SecretRewards.Kind.BONUS:
			steps[entry.param] = int(steps.get(entry.param, 0)) + 1
	assert_eq(steps.size(), SecretRewards.BONUSES.size(), "every bonus is found somewhere")
	for id in SecretRewards.ids():
		game.claim_reward(id)
	var bonuses := SecretRewards.bonuses(game)
	var levels := SecretRewards.effective_levels(game)
	for bonus: StringName in steps:
		assert_eq(bonuses[SecretRewards.bonus_key(bonus)], steps[bonus], "%s: every step claimed counts" % bonus)
		var total := _effect(bonus, levels) - _effect(bonus, {})
		var one_level := _effect(bonus, {BONUS_UPGRADE[bonus]: 1}) - _effect(bonus, {})
		var most := 2.0 if bonus == &"health" or bonus == &"stamina" else 1.0
		assert_lt(total, most * one_level, "%s: all its steps together stay under %.0f catalog level(s)" % [bonus, most])


func test_a_reward_is_claimed_once_and_counted() -> void:
	assert_eq(SecretRewards.claimed(game), 0)
	assert_true(game.claim_reward(&"secret_egypt_2"))
	assert_false(game.claim_reward(&"secret_egypt_2"), "claimed before")
	assert_true(SecretRewards.is_claimed(game, &"secret_egypt_2"))
	assert_false(SecretRewards.is_claimed(game, &"secret_egypt_3"))
	game.claim_reward(&"not_a_secret")
	assert_eq(SecretRewards.claimed(game), 1, "only rewards of the table count")


func test_claimed_rewards_join_the_upgrade_levels_without_touching_them() -> void:
	game.upgrades = {&"health": 1}
	game.claim_reward(&"secret_egypt_2")   # health bonus
	game.claim_reward(&"secret_egypt_3")   # the shotgun's faience finish
	game.claim_reward(&"secret_greece_3")   # the rifle's peep sight
	var levels := SecretRewards.effective_levels(game)
	assert_eq(levels[&"health"], 1)
	assert_eq(levels[SecretRewards.bonus_key(&"health")], 1)
	assert_eq(levels[SecretRewards.look_key(&"shotgun", &"faience")], 1)
	assert_eq(levels[SecretRewards.mod_key(&"rifle_peep")], 1)
	assert_false(levels.has(SecretRewards.bonus_key(&"stamina")), "nothing claimed, no key")
	assert_eq(game.upgrades, {&"health": 1}, "the bought levels stay as they were")
	var fresh := PersistentState.new()
	assert_eq(SecretRewards.effective_levels(fresh), {}, "a fresh game: nothing")
	fresh.free()


func test_every_text_exists_in_both_languages() -> void:
	for language in ["pl", "en"]:
		Settings.set_value(&"language", language, false)
		for entry in SecretRewards.entries():
			assert_ne(tr(entry.name_key()), entry.name_key(), "%s in %s" % [entry.name_key(), language])
			assert_ne(tr(entry.desc_key()), entry.desc_key(), "%s in %s" % [entry.desc_key(), language])
		for tier in [SecretRewards.Tier.SMALL, SecretRewards.Tier.MEDIUM, SecretRewards.Tier.GREAT]:
			var key := SecretRewards.tier_key(tier)
			assert_ne(tr(key), key, "%s in %s" % [key, language])
		for key in ["REWARD_CAPTION", "SECRET_TIER_HINT"]:
			assert_ne(tr(key), key, "%s in %s" % [key, language])
			assert_true(tr(key).contains("%s"), "%s takes the tier's name" % key)
	Settings.set_value(&"language", "pl", false)
	assert_eq(tr(SecretRewards.tier_key(SecretRewards.Tier.GREAT)), "Skarb muzeum")


## The amount and the unit a reward's description must state, from the
## constants the numbers come from: [amount, what follows it].
func _stated(entry: SecretRewards.Entry) -> Array:
	if entry.kind == SecretRewards.Kind.POUCH:
		return [float(SecretRewards.POUCH_DUST), ""]
	match entry.param:
		&"health":
			return [SecretRewards.HEALTH_STEP, ""]
		&"stamina":
			return [SecretRewards.STAMINA_STEP, ""]
		&"battery":
			return [SecretRewards.BATTERY_STEP, " s"]
		&"pockets":
			return [SecretRewards.POCKETS_STEP * 100.0, "%"]
		&"magnet":
			return [SecretRewards.MAGNET_STEP, " m"]
	return []


func test_the_texts_state_the_numbers_the_constants_give() -> void:
	var numbers := RegEx.create_from_string("[0-9]+(?:[.,][0-9]+)?")
	var checked := 0
	var treasures := 0
	for entry in SecretRewards.entries():
		if entry.tier == SecretRewards.Tier.GREAT:
			treasures += 1
	for language in ["pl", "en"]:
		Settings.set_value(&"language", language, false)
		for entry in SecretRewards.entries():
			var stated := _stated(entry)
			if stated.is_empty():
				continue
			checked += 1
			var text := tr(entry.desc_key())
			var found := numbers.search(text)
			assert_not_null(found, "%s (%s) names its amount" % [entry.desc_key(), language])
			if found == null:
				continue
			assert_almost_eq(found.get_string().replace(",", ".").to_float(), stated[0], 0.001, "%s (%s): %s" % [entry.desc_key(), language, text])
			assert_true(text.substr(found.get_end()).begins_with(stated[1]), "%s (%s) gives the amount in the right unit: %s" % [entry.desc_key(), language, text])
	Settings.set_value(&"language", "pl", false)
	assert_eq(checked, 2 * (SecretRewards.total() - treasures), "every pouch and bonus text, both languages (a treasure states no number)")


func test_the_stash_texts_name_what_the_stash_holds() -> void:
	var words := {&"bullets": ["naboje", "bullets"], &"shells": ["śrut", "shells"], &"medkit": ["apteczka", "medkit"]}
	var checked := 0
	for language_index in 2:
		Settings.set_value(&"language", ["pl", "en"][language_index], false)
		for entry in SecretRewards.entries():
			if entry.tier != SecretRewards.Tier.SMALL:
				continue
			var text := tr(entry.desc_key())
			if entry.stash.is_empty():
				assert_false(text.contains("Co noc") or text.contains("every night"), "%s: no stash, none promised" % entry.id)
				continue
			checked += 1
			assert_true(text.contains("Co noc") or text.contains("every night"), "%s: the stash is promised" % entry.id)
			for item in words:
				assert_eq(text.contains(words[item][language_index]), entry.stash.has(item), "%s (%s): %s in the stash and in the text" % [entry.id, language_index, item])
	Settings.set_value(&"language", "pl", false)
	assert_gt(checked, 6)


func test_rewards_survive_a_save_and_an_old_save_has_none() -> void:
	game.file_path = SavePaths.save_file()
	game.claim_reward(&"secret_asia_1")
	game.claim_reward(&"secret_americas_2")
	game.save_game()
	var loaded := PersistentState.new()
	loaded.file_path = game.file_path
	add_child(loaded)
	assert_true(loaded.load_game())
	assert_eq(loaded.secret_rewards, [&"secret_asia_1", &"secret_americas_2"] as Array[StringName])
	var old := game.to_dict()
	old.erase("secret_rewards")
	loaded.from_dict(old)
	assert_eq(loaded.secret_rewards.size(), 0, "a save from before the rewards loads with none")
	loaded.from_dict({"version": 2, "secret_rewards": [1, "secret_roof_2", "secret_roof_2"]})
	assert_eq(loaded.secret_rewards, [&"secret_roof_2"] as Array[StringName], "junk and doubles dropped")
