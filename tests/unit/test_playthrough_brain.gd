extends TestCase
## The playthrough bot's decisions (plan
## docs/superpowers/plans/2026-10-21-przejscie-bota.md, task 2): the way
## through the areas and their gates, the tool for each lock, the weapon
## for a fight, when to break off for a haven, what to buy.

const B := preload("res://tests/support/playthrough_brain.gd")


func _progress(weapons: Array = [], gates: Array = [], seals: Array = [], items: Array = [], flags: Array = []) -> FloorProgress:
	var p := FloorProgress.new()
	p.weapons.assign(weapons)
	p.gates_open.assign(gates)
	p.seals.assign(seals)
	p.items.assign(items)
	p.flags.assign(flags)
	return p


func _gates(route: Array[Dictionary]) -> Array[StringName]:
	var found: Array[StringName] = []
	for hop in route:
		if hop["gate"] != &"":
			found.append(hop["gate"])
	return found


func _areas(route: Array[Dictionary]) -> Array[StringName]:
	var found: Array[StringName] = []
	for hop in route:
		found.append(hop["area"])
	return found


# --- the way through the areas ------------------------------------------------------------

func test_the_way_from_the_booth_to_egypt_needs_no_gate() -> void:
	var route := B.area_route(_progress(), &"booth", &"egypt")
	assert_eq(_areas(route), [&"entrance", &"court", &"egypt"] as Array[StringName])
	assert_eq(_gates(route), [] as Array[StringName])


func test_the_way_to_the_same_area_is_empty() -> void:
	assert_eq(B.area_route(_progress(), &"court", &"court").size(), 0)


func test_a_seal_gate_is_on_the_way_once_its_seal_is_held() -> void:
	assert_eq(B.area_route(_progress(), &"egypt", &"assyria").size(), 0, "no seal: no way")
	var route := B.area_route(_progress([], [], [&"seal_sun"]), &"egypt", &"assyria")
	assert_eq(_gates(route), [&"seal_khorsabad"] as Array[StringName])
	assert_eq(route[0]["from"], &"egypt", "opened from Egypt's side")


func test_an_open_gate_is_no_work_on_the_way() -> void:
	var route := B.area_route(_progress([], [&"seal_khorsabad"]), &"egypt", &"assyria")
	assert_eq(_areas(route), [&"assyria"] as Array[StringName])
	assert_true(route[0]["open"], "the gate is open already")
	assert_eq(B.gates_to_open(route), [] as Array[StringName])


func test_a_bolt_opens_only_from_its_side() -> void:
	# the basement's bolts are drawn from the wings: from the basement there is no way up
	var down := _progress([], [&"boards_staff_stairs"])
	var route := B.area_route(down, &"basement", &"egypt")
	assert_false(_gates(route).has(&"bolt_basement_egypt"), "not from the basement side")
	assert_false(_areas(route).is_empty(), "round by the staff stairs")
	var up := B.area_route(_progress(), &"egypt", &"basement")
	assert_eq(_gates(up), [&"bolt_basement_egypt"] as Array[StringName], "from Egypt it opens: the short way down")


func test_boards_open_by_hand() -> void:
	var route := B.area_route(_progress(), &"egypt", &"greece")
	assert_eq(_gates(route), [&"boards_tomb"] as Array[StringName], "fists always break boards")


func test_the_cheapest_way_prefers_open_gates() -> void:
	# Greece from the entrance: the bolt on the landing opens only from Greece,
	# so the way goes round through Egypt's tomb boards
	var route := B.area_route(_progress(), &"entrance", &"greece")
	assert_eq(_gates(route), [&"boards_tomb"] as Array[StringName])
	var opened := B.area_route(_progress([], [&"bolt_greece_entrance"]), &"entrance", &"greece")
	assert_eq(_areas(opened), [&"greece"] as Array[StringName], "the open landing door is the short way")


func test_the_way_into_a_sub_area_takes_its_gate() -> void:
	var route := B.area_route(_progress([], [], [&"seal_owl"]), &"booth", &"reading_room")
	assert_eq(_gates(route), [&"gate_reading_room"] as Array[StringName])


# --- the tool for a lock ----------------------------------------------------------------------

func test_a_chain_takes_the_shotgun_or_the_fists() -> void:
	var with_shells := B.gate_tool(GateSpec.Kind.CHAIN, GateSpec.HEAVY, {&"shotgun": 4})
	assert_eq(with_shells["how"], &"shoot")
	assert_eq(with_shells["weapon"], &"shotgun")
	assert_lt(float(with_shells["range"]), 4.0, "the pellets must all land")
	var bare := B.gate_tool(GateSpec.Kind.CHAIN, GateSpec.HEAVY, {&"shotgun": 0})
	assert_eq(bare["how"], &"punch")
	assert_eq(bare["shots"], LockRules.CHAIN_PUNCHES)


func test_boards_take_five_punches_without_a_shotgun() -> void:
	var tool := B.gate_tool(GateSpec.Kind.BOARDS, GateSpec.HEAVY, {&"pistol": 30})
	assert_eq(tool["how"], &"punch")
	assert_eq(tool["shots"], LockRules.BOARDS_PUNCHES)


func test_a_cracked_wall_takes_the_hwacha_or_three_flares_up_close() -> void:
	var hwacha := B.gate_tool(GateSpec.Kind.CRACKED, GateSpec.EXPLOSIVE, {&"hwacha": 2, &"flare": 5})
	assert_eq(hwacha["weapon"], &"hwacha")
	var flares := B.gate_tool(GateSpec.Kind.CRACKED, GateSpec.EXPLOSIVE, {&"flare": 5})
	assert_eq(flares["weapon"], &"flare")
	assert_lt(float(flares["range"]), LockRules.FLARE_POINT_BLANK + 0.01)
	assert_eq(flares["shots"], LockRules.CRACKED_FLARES)
	assert_eq(B.gate_tool(GateSpec.Kind.CRACKED, GateSpec.EXPLOSIVE, {&"flare": 2})["how"], &"none", "too few flares")


func test_a_rope_takes_the_rifle_or_the_pistol_close_enough() -> void:
	var rifle := B.gate_tool(GateSpec.Kind.ROPE, &"rifle_hunt", {&"rifle_hunt": 3, &"pistol": 20})
	assert_eq(rifle["weapon"], &"rifle_hunt")
	assert_eq(B.gate_tool(GateSpec.Kind.ROPE, &"rifle_hunt", {&"pistol": 20})["how"], &"none", "the Planetarium's rope needs the rifle")
	var pistol := B.gate_tool(GateSpec.Kind.ROPE, GateSpec.PRECISE, {&"pistol": 20})
	assert_eq(pistol["weapon"], &"pistol")
	assert_lt(float(pistol["range"]), LockRules.ROPE_PISTOL_RANGE)


func test_bolts_and_seals_are_used_hooks_harpooned_shutters_wait() -> void:
	assert_eq(B.gate_tool(GateSpec.Kind.BOLT, GateSpec.NONE, {})["how"], &"use")
	assert_eq(B.gate_tool(GateSpec.Kind.SEAL, &"seal_sun", {})["how"], &"use")
	assert_eq(B.gate_tool(GateSpec.Kind.HOOK, &"harpoon", {&"harpoon": 1})["weapon"], &"harpoon")
	assert_eq(B.gate_tool(GateSpec.Kind.HOOK, &"harpoon", {&"harpoon": 0})["how"], &"none")
	assert_eq(B.gate_tool(GateSpec.Kind.POWER, &"power_north", {})["how"], &"none")


# --- the weapon for a fight -----------------------------------------------------------------

func test_close_up_the_shotgun_far_off_the_pistol() -> void:
	var rounds := {&"pistol": 30, &"shotgun": 6}
	assert_eq(B.combat_weapon(rounds, 3.0, false), &"shotgun")
	assert_eq(B.combat_weapon(rounds, 18.0, false), &"pistol")


func test_a_guardian_gets_the_rifle_first() -> void:
	assert_eq(B.combat_weapon({&"pistol": 30, &"rifle_hunt": 10, &"shotgun": 6}, 12.0, true), &"rifle_hunt")


func test_empty_guns_leave_the_taser_then_the_fists() -> void:
	assert_eq(B.combat_weapon({&"pistol": 0, &"taser": 1}, 3.0, false), &"taser")
	assert_eq(B.combat_weapon({&"pistol": 0}, 3.0, false), &"fists")


func test_ammo_kept_for_a_lock_is_not_fired_at_exhibits() -> void:
	var rounds := {&"flare": 3, &"pistol": 0, &"taser": 1}
	assert_eq(B.combat_weapon(rounds, 6.0, false, {&"flare": 3}), &"taser", "three flares wait for the cracked wall")
	assert_eq(B.combat_weapon({&"flare": 5, &"pistol": 0}, 6.0, false, {&"flare": 3}), &"flare", "two to spare")


func test_rounds_to_keep_for_the_locks_ahead() -> void:
	var keep := B.ammo_to_keep(_progress([&"flare", &"pistol"]))
	assert_eq(int(keep.get(&"flare", 0)), LockRules.CRACKED_FLARES, "the garden wall is still cracked")
	var later := B.ammo_to_keep(_progress([&"flare", &"pistol", &"hwacha"], [&"cracked_garden"]))
	assert_eq(int(later.get(&"flare", 0)), 0, "the wall is down")


# --- breaking off -------------------------------------------------------------------------------

func test_low_health_sends_him_to_a_haven_unless_cornered() -> void:
	assert_true(B.wants_rest(0.3, 0, 60.0))
	assert_false(B.wants_rest(0.8, 0, 60.0))
	assert_false(B.wants_rest(0.3, 2, 60.0), "fight first when they are on him")
	assert_false(B.wants_rest(0.3, 0, INF), "no haven to go to")


func test_he_heads_for_a_haven_before_dawn() -> void:
	var walk := 80.0 / B.WALK_SPEED
	assert_false(B.dawn_retreat(600.0, 80.0))
	assert_true(B.dawn_retreat(walk + B.DAWN_SLACK - 1.0, 80.0))
	assert_false(B.dawn_retreat(30.0, INF), "no haven in reach: play on")


# --- the terminal ----------------------------------------------------------------------------------

func test_shopping_follows_the_wish_list_within_the_dust() -> void:
	var bought := B.shopping({}, [&"pistol"], 60)
	assert_eq(bought, [&"health", &"pockets"] as Array[StringName], "25 + 30 of 60")
	assert_eq(B.shopping({}, [&"pistol"], 10).size(), 0)


func test_shopping_skips_upgrades_of_guns_he_does_not_have_and_maxed_ones() -> void:
	var bought := B.shopping({&"health": 3, &"pockets": 2}, [], 50)
	for id in bought:
		var entry := UpgradeCatalog.find(id)
		assert_true(entry.weapon() == &"" , "%s needs a gun he does not have" % id)
	assert_false(bought.has(&"health"), "health is maxed")


# --- choosing a target --------------------------------------------------------------------------------

func test_the_nearest_awake_exhibit_in_sight_comes_first() -> void:
	var picked := B.pick_target([
		{"distance": 5.0, "awake": false, "in_sight": true},
		{"distance": 14.0, "awake": true, "in_sight": true},
		{"distance": 9.0, "awake": true, "in_sight": false},
	])
	assert_eq(picked, 1)


func test_a_sleeper_right_by_the_way_is_dealt_with_far_ones_left() -> void:
	assert_eq(B.pick_target([{"distance": 4.0, "awake": false, "in_sight": true}]), 0)
	assert_eq(B.pick_target([{"distance": 20.0, "awake": false, "in_sight": true}]), -1)
	assert_eq(B.pick_target([{"distance": 40.0, "awake": true, "in_sight": true}]), -1, "out of range")


func test_bare_handed_he_takes_on_only_what_comes_close() -> void:
	var far_hunter := [{"distance": 20.0, "awake": true, "hunting": true, "in_sight": true}]
	assert_eq(B.pick_target(far_hunter, B.MELEE_ENGAGE), -1, "fists: let it come")
	assert_eq(B.pick_target([{"distance": 6.0, "awake": true, "hunting": true, "in_sight": true}], B.MELEE_ENGAGE), 0)


func test_a_wanderer_is_left_alone_until_it_is_near() -> void:
	var patrol := {"distance": 22.0, "awake": true, "hunting": false, "in_sight": true}
	assert_eq(B.pick_target([patrol]), -1, "patrolling far off: not worth the walk")
	patrol["distance"] = 10.0
	assert_eq(B.pick_target([patrol]), 0)


func test_badly_hurt_he_runs_for_a_haven_even_with_them_on_him() -> void:
	assert_true(B.wants_rest(B.FLEE_BELOW - 0.05, 3, 80.0), "nearly dead: run for the door")
	assert_false(B.wants_rest(B.FLEE_BELOW - 0.05, 3, B.FLEE_REACH + 10.0), "too far to run: fight it out")


func test_a_tough_exhibit_gets_the_rifle_a_weak_one_the_pistol() -> void:
	var rounds := {&"pistol": 30, &"rifle_hunt": 12, &"shotgun": 6}
	assert_eq(B.combat_weapon(rounds, 10.0, false, {}, true), &"rifle_hunt", "a hoplite's face: one rifle round")
	assert_eq(B.combat_weapon(rounds, 10.0, false, {}, false), &"pistol", "a wax figure: the pistol")
	assert_eq(B.combat_weapon(rounds, 3.0, false, {}, true), &"shotgun", "on top of him: the shotgun")
