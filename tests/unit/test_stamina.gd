extends TestCase

var stamina: Stamina


func before_each() -> void:
	stamina = Stamina.new()


func test_sprint_drains_per_second() -> void:
	assert_true(stamina.spend_sprint(1.0))
	assert_almost_eq(stamina.current, 100.0 - stamina.sprint_cost_per_sec)


func test_regen_waits_for_the_delay() -> void:
	stamina.spend_sprint(1.0)          # 82, regen waits 0.7 s
	stamina.tick(0.5)
	assert_almost_eq(stamina.current, 82.0)
	stamina.tick(0.5)                  # 0.2 s of waiting left, then 0.3 s of regen
	assert_almost_eq(stamina.current, 82.0 + 0.3 * stamina.regen_per_sec)


func test_regen_stops_at_maximum() -> void:
	stamina.current = 95.0
	stamina.tick(5.0)
	assert_eq(stamina.current, 100.0)


func test_running_dry_exhausts_until_recovered() -> void:
	stamina.current = 10.0
	assert_false(stamina.spend_sprint(1.0))
	assert_true(stamina.exhausted)
	assert_false(stamina.can_sprint())
	stamina.tick(1.2)                  # 0.7 s wait + 0.5 s regen -> 15
	assert_true(stamina.exhausted)
	stamina.tick(0.6)                  # -> 33, above recover_at (30)
	assert_false(stamina.exhausted)
	assert_true(stamina.can_sprint())


func test_exhaustion_ends_at_full_even_if_recover_at_is_above_maximum() -> void:
	stamina.maximum = 20.0
	stamina.recover_at = 30.0
	stamina.current = 1.0
	stamina.spend_sprint(1.0)
	assert_true(stamina.exhausted)
	stamina.tick(5.0)
	assert_eq(stamina.current, 20.0)
	assert_false(stamina.exhausted)


func test_dash_costs_a_chunk_and_needs_enough() -> void:
	assert_true(stamina.try_dash())
	assert_eq(stamina.current, 70.0)
	stamina.current = 20.0
	assert_false(stamina.try_dash())
	assert_eq(stamina.current, 20.0)


# --- fatigue's hold on the bar (plan 2026-10-10-kawiarnia-zmeczenie) ---------

func test_the_capacity_factor_eats_the_top_of_the_bar() -> void:
	stamina.capacity_factor = 0.7
	assert_almost_eq(stamina.cap(), 70.0)
	assert_almost_eq(stamina.cap_fraction(), 0.7)
	stamina.current = 60.0
	stamina.tick(5.0)
	assert_almost_eq(stamina.current, 70.0, 0.0001, "regen stops at the cap")
	assert_almost_eq(stamina.fraction(), 0.7, 0.0001, "the bar reads against the full maximum")
	stamina.current = 95.0
	stamina.tick(0.0)
	assert_almost_eq(stamina.current, 70.0, 0.0001, "what the cap no longer holds drains at once")


func test_the_regen_factor_slows_the_recovery() -> void:
	stamina.regen_factor = 0.5
	stamina.current = 40.0
	stamina.tick(1.0)
	assert_almost_eq(stamina.current, 40.0 + 0.5 * stamina.regen_per_sec)


func test_exhaustion_ends_at_the_cap_when_that_is_below_recover_at() -> void:
	stamina.capacity_factor = 0.25   # cap 25, recover_at 30
	stamina.current = 1.0
	stamina.spend_sprint(1.0)
	assert_true(stamina.exhausted)
	stamina.tick(10.0)
	assert_almost_eq(stamina.current, 25.0)
	assert_false(stamina.exhausted, "a full (capped) bar ends the exhaustion")
