extends Floor1ReachCase
## The deep variant of test_floor1_reachability (P1 / W7): many random
## valid play orders, each state checked from every known haven (every
## step's target confirmed on the map from each haven's door) with
## tonight's lockable doors. Slow (a bake per new set of open gates), so the
## runner leaves it out unless asked: bash tools/run_tests.sh --filter=deep

## Seeds of the random orders walked here (the fast variant walks 3 and 8).
const SEEDS := 24


func test_many_random_play_orders_never_soft_lock() -> void:
	await _survey()
	var started := Time.get_ticks_msec()
	var walked := {}
	for seed_value in SEEDS:
		var order := Floor1Route.random_order(1000 + seed_value)
		if walked.has(str(order)):
			continue
		walked[str(order)] = true
		await walk_order(order, "deep seed %d" % (1000 + seed_value), true)
	print("W7 deep: %d distinct orders, %d bakes (%d ms), %d ms in all" % [walked.size(), survey.bakes, survey.bake_msec, Time.get_ticks_msec() - started])
	assert_gt(float(walked.size()), SEEDS * 0.75, "the orders differ")
