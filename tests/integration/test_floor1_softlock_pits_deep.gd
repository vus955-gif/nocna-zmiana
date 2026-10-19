extends "res://tests/integration/test_floor1_softlock_pits.gd"
## The deep variant of test_floor1_softlock_pits: the HUD's order and many
## random play orders (bash tools/run_tests.sh --filter=deep).

const DEEP_SEEDS: Array[int] = [3, 8, 11, 17, 23, 29]


func _orders() -> Array:
	var orders: Array = [[Floor1Route.hud_order(), "hud"]]
	for seed_value in DEEP_SEEDS:
		orders.append([Floor1Route.random_order(seed_value), "seed %d" % seed_value])
	return orders
