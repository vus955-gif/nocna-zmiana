extends TestCase

var health: Health


func before_each() -> void:
	health = Health.new()
	health.max_health = 100.0
	add_child(health)


func test_starts_full() -> void:
	assert_eq(health.current, 100.0)
	assert_false(health.is_dead())


func test_damage_reduces_and_reports_amount_taken() -> void:
	assert_eq(health.apply_damage(30.0), 30.0)
	assert_eq(health.current, 70.0)


func test_overkill_clamps_and_reports_only_what_was_left() -> void:
	health.apply_damage(80.0)
	assert_eq(health.apply_damage(50.0), 20.0)
	assert_eq(health.current, 0.0)
	assert_true(health.is_dead())


func test_depleted_is_emitted_once() -> void:
	var calls := watch(health.depleted)
	health.apply_damage(100.0)
	health.apply_damage(10.0)
	assert_eq(calls.size(), 1)


func test_heal_clamps_to_max() -> void:
	health.apply_damage(10.0)
	assert_eq(health.heal(50.0), 10.0)
	assert_eq(health.current, 100.0)


func test_the_dead_cannot_be_healed() -> void:
	health.apply_damage(100.0)
	assert_eq(health.heal(50.0), 0.0)
	assert_true(health.is_dead())


func test_fraction() -> void:
	health.apply_damage(25.0)
	assert_almost_eq(health.fraction(), 0.75)
