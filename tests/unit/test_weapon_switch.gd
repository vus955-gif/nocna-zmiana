extends TestCase
## Switching weapons (owner's note 45, plan 2026-10-21-animacje-fpp): the
## weapon in hand is put away (down out of the frame) before the next one
## comes up, each at its own weight; a quick change of mind brings a weapon
## back from wherever it was, a shot during the switch hurries it. Every
## weapon's "lower" (0 up .. 1 down) moves without a jump.

const DT := 1.0 / 60.0


## Steps [param switch] for [param seconds]; returns [the ids hidden on the
## way, the widest per-step change of any lower].
func _run(switch: WeaponSwitch, seconds: float, ids: Array) -> Array:
	var hidden: Array[StringName] = []
	var widest := 0.0
	var last := {}
	for id in ids:
		last[id] = switch.lower(id)
	for i in roundi(seconds / DT):
		hidden.append_array(switch.step(DT))
		for id in ids:
			var now := switch.lower(id)
			if not hidden.has(id):
				widest = maxf(widest, absf(now - float(last[id])))
			last[id] = now
	return [hidden, widest]


func test_the_first_weapon_comes_up_and_settles() -> void:
	var switch := WeaponSwitch.new()
	switch.begin(&"", &"pistol")
	assert_almost_eq(switch.lower(&"pistol"), 1.0, 0.001, "it starts out of the frame")
	assert_true(switch.busy())
	var lowest := 1.0
	var t := 0.0
	while switch.busy() and t < 2.0:
		switch.step(DT)
		t += DT
		lowest = minf(lowest, switch.lower(&"pistol"))
	assert_false(switch.busy(), "settled")
	assert_almost_eq(switch.lower(&"pistol"), 0.0, 0.0001)
	var draw := ViewmodelMotion.draw_time(&"pistol")
	assert_lt(t, draw * 1.25, "up in about its draw time (%.2f s)" % t)
	assert_gt(t, draw * 0.7, "not snapped up (%.2f s)" % t)
	assert_lt(lowest, -0.005, "a light piece comes up a touch past its rest and settles")
	assert_gt(lowest, -0.07, "only a touch (%.3f)" % lowest)


func test_the_old_weapon_goes_down_before_the_new_one_comes_up() -> void:
	var switch := WeaponSwitch.new()
	switch.begin(&"pistol", &"shotgun")
	assert_eq(switch.holstering(), [&"pistol"] as Array[StringName])
	var hidden_at := -1.0
	var t := 0.0
	while t < 1.5:
		var gone := switch.step(DT)
		t += DT
		if gone.has(&"pistol"):
			hidden_at = t
		if hidden_at < 0.0:
			assert_almost_eq(switch.lower(&"shotgun"), 1.0, 0.0001, "the shotgun waits below while the pistol goes")
	assert_almost_eq(hidden_at, ViewmodelMotion.holster_time(&"pistol"), DT * 1.5, "the pistol is out of sight in its holster time")
	assert_false(switch.busy())
	assert_almost_eq(switch.lower(&"shotgun"), 0.0, 0.0001)


func test_a_heavy_switch_takes_longer_than_a_light_one() -> void:
	var light := WeaponSwitch.new()
	light.begin(&"shotgun", &"pistol")
	var heavy := WeaponSwitch.new()
	heavy.begin(&"pistol", &"gatling")
	var t_light := 0.0
	while light.busy():
		light.step(DT)
		t_light += DT
	var t_heavy := 0.0
	while heavy.busy():
		heavy.step(DT)
		t_heavy += DT
	assert_gt(t_heavy, t_light + 0.1, "gatling %.2f s vs pistol %.2f s" % [t_heavy, t_light])
	assert_lt(t_heavy, 0.75, "still a quick switch")


func test_every_lower_moves_without_a_jump() -> void:
	for pair in [[&"pistol", &"shotgun"], [&"shotgun", &"gatling"], [&"gatling", &"taser"], [&"", &"hwacha"]]:
		var switch := WeaponSwitch.new()
		switch.begin(pair[0], pair[1])
		var run := _run(switch, 1.0, [pair[0], pair[1]] if pair[0] != &"" else [pair[1]])
		assert_lt(float(run[1]), 0.32, "%s -> %s: widest step %.3f" % [pair[0], pair[1], run[1]])


func test_a_change_of_mind_brings_the_weapon_back_from_where_it_was() -> void:
	var switch := WeaponSwitch.new()
	switch.begin(&"pistol", &"shotgun")
	for i in 4:
		switch.step(DT)
	var down := switch.lower(&"pistol")
	assert_gt(down, 0.05, "the pistol on its way down")
	assert_lt(down, WeaponSwitch.HIDE_AT)
	switch.begin(&"shotgun", &"pistol")
	assert_almost_eq(switch.lower(&"pistol"), down, 0.0001, "no jump")
	var hidden := switch.step(DT)
	assert_true(hidden.has(&"shotgun"), "the shotgun never showed: gone at once")
	var run := _run(switch, 1.0, [&"pistol"])
	assert_lt(float(run[1]), 0.3, "the pistol comes back up smoothly (%.3f)" % run[1])
	assert_false(switch.busy())
	assert_almost_eq(switch.lower(&"pistol"), 0.0, 0.0001)


func test_a_change_of_mind_during_the_draw_puts_that_weapon_away_from_where_it_was() -> void:
	var switch := WeaponSwitch.new()
	switch.begin(&"pistol", &"shotgun")
	_run(switch, ViewmodelMotion.holster_time(&"pistol") + 0.05, [&"shotgun"])
	var half := switch.lower(&"shotgun")
	assert_true(half > 0.1 and half < 0.9, "the shotgun half way up (%.2f)" % half)
	switch.begin(&"shotgun", &"taser")
	assert_eq(switch.holstering(), [&"shotgun"] as Array[StringName])
	var run := _run(switch, 1.0, [&"shotgun", &"taser"])
	assert_true((run[0] as Array).has(&"shotgun"))
	assert_lt(float(run[1]), 0.32)
	assert_almost_eq(switch.lower(&"taser"), 0.0, 0.0001)


func test_a_shot_during_the_switch_hurries_it() -> void:
	var calm := WeaponSwitch.new()
	calm.begin(&"pistol", &"shotgun")
	var t_calm := 0.0
	while calm.busy():
		calm.step(DT)
		t_calm += DT
	var hurried := WeaponSwitch.new()
	hurried.begin(&"pistol", &"shotgun")
	hurried.step(DT)
	var gone := hurried.hurry()
	assert_eq(gone, [&"pistol"] as Array[StringName], "the old weapon is out of the way at once")
	var t_hurried := DT
	var widest := 0.0
	var last := hurried.lower(&"shotgun")
	while hurried.busy():
		hurried.step(DT)
		t_hurried += DT
		widest = maxf(widest, absf(hurried.lower(&"shotgun") - last))
		last = hurried.lower(&"shotgun")
	assert_lt(t_hurried, t_calm * 0.6, "up much sooner (%.2f vs %.2f s)" % [t_hurried, t_calm])
	assert_lt(widest, 0.6, "still a motion, not a pop (%.2f)" % widest)


func test_a_settled_or_unknown_weapon_is_up() -> void:
	var switch := WeaponSwitch.new()
	assert_eq(switch.lower(&"pistol"), 0.0)
	assert_false(switch.busy())
	assert_eq(switch.step(DT).size(), 0)
