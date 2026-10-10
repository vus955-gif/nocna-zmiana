extends TestCase
## What breaks which gate lock (design 4.2), for every lock and every
## weapon, and the tally that sums hits and counts blows.

const K := GateLock.Kind
const V := LockRules.Verdict


## A hit by [param weapon] landing at the origin, fired from
## [param distance] metres away; blasts (flare, fire-arrows) are explosive.
func _hit(weapon: StringName, amount: float = 20.0, distance: float = 5.0) -> DamageInfo:
	var info := DamageInfo.make(amount, DamageInfo.Kind.BALLISTIC)
	info.weapon = weapon
	info.explosive = weapon == &"flare" or weapon == &"hwacha"
	info.position = Vector3.ZERO
	info.origin = Vector3(0.0, 0.0, distance)
	return info


func _verdicts(kind: GateLock.Kind, distance: float = 5.0) -> Dictionary:
	var out := {}
	for weapon in [&"fists", &"taser", &"pistol", &"shotgun", &"gatling", &"flare", &"rifle_hunt", &"harpoon", &"hwacha"]:
		out[weapon] = LockRules.verdict(kind, _hit(weapon, 20.0, distance))
	return out


func test_a_chain_takes_the_shotgun_and_fists_only() -> void:
	var got := _verdicts(K.CHAIN)
	assert_eq(got[&"shotgun"], V.SUM)
	assert_eq(got[&"fists"], V.STRIKE)
	for weapon in [&"taser", &"pistol", &"gatling", &"flare", &"rifle_hunt", &"harpoon", &"hwacha"]:
		assert_eq(got[weapon], V.WRONG, str(weapon))


func test_boards_take_the_shotgun_fists_and_any_blast() -> void:
	var got := _verdicts(K.BOARDS)
	assert_eq(got[&"shotgun"], V.SUM)
	assert_eq(got[&"fists"], V.STRIKE)
	assert_eq(got[&"flare"], V.OPEN)
	assert_eq(got[&"hwacha"], V.OPEN)
	for weapon in [&"taser", &"pistol", &"gatling", &"rifle_hunt", &"harpoon"]:
		assert_eq(got[weapon], V.WRONG, str(weapon))


func test_a_cracked_wall_takes_blasts_and_close_flares() -> void:
	var far := _verdicts(K.CRACKED, 10.0)
	assert_eq(far[&"hwacha"], V.SUM)
	assert_eq(far[&"flare"], V.SUM, "a flare from afar only adds its blast")
	assert_eq(_verdicts(K.CRACKED, 3.0)[&"flare"], V.STRIKE, "a flare up close")
	for weapon in [&"fists", &"taser", &"pistol", &"shotgun", &"gatling", &"rifle_hunt", &"harpoon"]:
		assert_eq(far[weapon], V.WRONG, str(weapon))


func test_a_rope_takes_a_precise_shot() -> void:
	assert_eq(LockRules.verdict(K.ROPE, _hit(&"rifle_hunt", 85.0, 120.0)), V.OPEN, "the rifle from anywhere")
	assert_eq(LockRules.verdict(K.ROPE, _hit(&"pistol", 20.0, 14.0)), V.OPEN, "the pistol up close")
	assert_eq(LockRules.verdict(K.ROPE, _hit(&"pistol", 20.0, 16.0)), V.WRONG, "the pistol from too far")
	assert_eq(LockRules.wrong_hint_key(K.ROPE, _hit(&"pistol", 20.0, 16.0)), "LOCK_ROPE_FAR")
	for weapon in [&"fists", &"taser", &"shotgun", &"gatling", &"flare", &"harpoon", &"hwacha"]:
		assert_eq(LockRules.verdict(K.ROPE, _hit(weapon, 20.0, 5.0)), V.WRONG, str(weapon))


func test_a_hook_takes_the_harpoon_only() -> void:
	var got := _verdicts(K.HOOK)
	assert_eq(got[&"harpoon"], V.OPEN)
	for weapon in got:
		if weapon != &"harpoon":
			assert_eq(got[weapon], V.WRONG, str(weapon))


func test_no_weapon_opens_a_bolt_or_a_shutter() -> void:
	for kind in [K.BOLT, K.POWER]:
		var got := _verdicts(kind)
		for weapon in got:
			assert_eq(got[weapon], V.WRONG, "%s on %d" % [weapon, kind])
	assert_eq(LockRules.wrong_hint_key(K.POWER, _hit(&"pistol")), "LOCK_POWER_HINT")


func test_every_lock_has_its_line() -> void:
	for kind in K.values():
		var key := LockRules.prompt_key(kind)
		assert_ne(tr(key), key, "translated: " + key)


func test_hits_sum_within_the_window_only() -> void:
	var tally := LockRules.tally_for(K.CHAIN)
	assert_false(tally.feed(15.0, 0.0))
	assert_true(tally.feed(15.0, 0.3), "15 + 15 within 0.4 s")
	tally.reset()
	assert_false(tally.feed(15.0, 1.0))
	assert_false(tally.feed(15.0, 1.5), "too far apart")


func test_blows_count_up() -> void:
	var chain := LockRules.tally_for(K.CHAIN)
	assert_false(chain.strike())
	assert_false(chain.strike())
	assert_true(chain.strike(), "three punches")
	var boards := LockRules.tally_for(K.BOARDS)
	for i in 4:
		assert_false(boards.strike())
	assert_true(boards.strike(), "five punches")
	var wall := LockRules.tally_for(K.CRACKED)
	assert_eq(wall.need_strikes, 3, "three close flares")
	assert_eq(wall.need_sum, 40.0)
	assert_eq(wall.window, 0.3)
