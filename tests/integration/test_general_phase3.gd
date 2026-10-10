extends TestCase
## The General's phase 3 in the real garden: under a third of his health he
## transforms (the sword planted, a gust of petals, the cherry sheds petals
## from then on), and his dashes come as feints: a whirl hides him, two
## figures step out - the double with its own lane, no hit zones and no
## glint - the double lunges early and bursts into petals, the real blade
## glints and cuts; fleeing calms everything.

const A := GeneralBrain.Attack
const S := GeneralBrain.State
const T := GeneralBrain.Stage
const START := Vector3(8.0, 0.0, -65.5)

var museum: Museum


func before_each() -> void:
	Museum.level_id = &"floor1"


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _museum() -> Museum:
	GameState.new_game()
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	return museum


func _general() -> General:
	return museum.floor_game.guardians.guardians.get(&"general") as General


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _put_guard(at: Vector3) -> void:
	var guard := museum.player
	if guard.health.max_health < 10000.0:
		guard.health.max_health = 100000.0
		guard.health.reset()
	guard.global_position = at + Vector3.UP * 0.05
	guard.velocity = Vector3.ZERO


func _front(general: General, ahead: float, aside: float = 0.0) -> Vector3:
	return general.home.origin - general.home.basis.z * ahead - general.home.basis.x * aside


func _awake(general: General) -> void:
	_put_guard(START)
	await _seconds(0.3)
	await _seconds(GeneralBrain.WAKE_TIME + 0.15)


func _wound(general: General, fraction: float) -> void:
	var amount := (general.health.current - general.max_health * fraction + 1.0) / General.BACK
	var info := DamageInfo.make(amount, DamageInfo.Kind.BALLISTIC, museum.player)
	info.direction = -general.global_basis.z
	info.position = general.rig.part("back").global_position
	general.take_zone_damage(info, &"back")


func _until(condition: Callable, at: Vector3, limit: float) -> bool:
	for i in roundi(limit * 60.0):
		if condition.call():
			return true
		_put_guard(at)
		museum.player.heal(100000.0)
		await get_tree().physics_frame
	return condition.call()


## Keeps the guard at [param at] (no healing: the damage shows) until
## [param condition] holds (or [param limit] s pass).
func _stand(condition: Callable, at: Vector3, limit: float) -> bool:
	for i in roundi(limit * 60.0):
		if condition.call():
			return true
		_put_guard(at)
		await get_tree().physics_frame
	return condition.call()


## Into phase 3 with the roof visit skipped (no perch for this fight) and
## the transformation over.
func _phase_three(general: General, at: Vector3) -> void:
	general.brain.can_roof = false
	_wound(general, 0.3)
	assert_true(await _until(func() -> bool: return general.brain.state == S.TRANSFORM, at, 10.0), "he transforms")
	assert_true(await _until(func() -> bool: return general.brain.state == S.GUARD, at, 4.0), "and stands in his guard again")


func test_under_a_third_he_plants_the_sword_and_the_cherry_sheds_its_petals() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	await _awake(general)
	var spot := _front(general, 7.0)
	general.brain.can_roof = false
	_wound(general, 0.3)
	assert_eq(general.phase, 3)
	assert_true(await _until(func() -> bool: return general.brain.state == S.TRANSFORM, spot, 10.0), "the transformation")
	assert_true(await _until(func() -> bool: return general.brain.state_progress() >= General.PLANT_AT + 0.03, spot, 3.0))
	assert_lt(general.rig.tip_point().y, 0.3, "the point in the gravel (%.2f)" % general.rig.tip_point().y)
	assert_true(await _until(func() -> bool: return general.brain.state_progress() >= General.GUST_AT + 0.05, spot, 3.0))
	assert_not_null(general.storm, "the petals")
	assert_true(general.storm.falling, "the cherry sheds petals")
	assert_gt(general.storm.bursts_alive(), 0, "the gust")
	assert_not_null(general.phantom, "the double waits, hidden")
	assert_false(general.phantom.visible)
	assert_true(await _until(func() -> bool: return general.brain.state == S.GUARD, spot, 4.0), "chudan again")
	assert_true(general.storm.falling, "petals through the rest of the fight")


func test_the_feint_puts_a_double_beside_him_that_lunges_first_and_bursts_only_the_real_blade_glints_and_cuts() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	await _awake(general)
	var spot := _front(general, 8.0)
	await _phase_three(general, spot)
	museum.player.heal(100000.0)
	var health := museum.player.health.current
	var phantom := general.phantom
	general.brain.force_attack(A.FEINT)
	await physics_frames(2)
	assert_true(phantom.visible and phantom.active, "the double steps out of the whirl")
	assert_eq(phantom.find_children("*", "Hurtbox", true, false).size(), 0, "no hit zones on the double")
	assert_lt(phantom.global_position.distance_to(general.global_position), 0.3, "out of the same whirl")
	assert_true(general.dash_lane() == null, "no lane yet: the whirl")
	# they step apart; both get lanes; the real blade glints from its moment
	var first_glint := -1.0
	var phantom_glint := 0.0
	while general.brain.stage_time() < GeneralBrain.FEINT_APART + 0.05:
		_put_guard(spot)
		await get_tree().physics_frame
		if general.moves.glint > 0.3 and first_glint < 0.0:
			first_glint = general.brain.stage_time()
		phantom_glint = maxf(phantom_glint, phantom.moves.pose.glint)
	assert_gt(phantom.global_position.distance_to(general.global_position), 1.0, "the figures apart (%.2f m)" % phantom.global_position.distance_to(general.global_position))
	assert_not_null(general.dash_lane(), "his lane")
	assert_not_null(phantom.lane, "the double's lane")
	assert_gt(first_glint, 0.0, "the real blade glints")
	var lead := GeneralBrain.stage_length(A.FEINT, T.TELEGRAPH, 3) - first_glint
	assert_true(lead >= 0.7 - 0.05, "glinting %.2f s before the cut" % lead)
	assert_almost_eq(phantom_glint, 0.0, 0.001, "the double never glints")
	# the double lunges before him: the guard beside the double's lane start,
	# off the real lane (locked by now), is untouched
	assert_true(await _until(func() -> bool: return general.dash_locked, spot, 1.0), "the lanes locked")
	var phantom_at := phantom.global_position
	var safe := phantom_at + (general.dash_target - phantom_at).normalized() * 1.5
	assert_true(await _stand(func() -> bool: return phantom.dashing, safe, 2.0), "the double lunges")
	assert_eq(general.brain.stage, T.TELEGRAPH, "while the real blade is still raised")
	assert_true(await _stand(func() -> bool: return phantom.burst, safe, 1.0), "and bursts into petals")
	assert_false(phantom.visible)
	assert_true(await _stand(func() -> bool: return general.brain.stage == T.RECOVER, safe, 2.0), "the real cut passed")
	assert_almost_eq(museum.player.health.current, health, 0.01, "the double cuts nothing; off the real lane the guard is untouched")
	# a second feint: the guard who stays in the real lane is cut
	assert_true(await _until(func() -> bool: return general.brain.state == S.GUARD, spot, 4.0))
	museum.player.heal(100000.0)
	health = museum.player.health.current
	general.brain.force_attack(A.FEINT)
	while general.brain.stage == T.TELEGRAPH and not general.dash_locked:
		_put_guard(spot)
		await get_tree().physics_frame
	var locked := general.dash_target
	assert_true(await _stand(func() -> bool: return general.brain.stage == T.RECOVER, locked, 3.0))
	assert_lt(museum.player.health.current, health - GeneralBrain.DASH_DAMAGE + 1.0, "the real blade cuts (%.0f)" % (health - museum.player.health.current))
	assert_true(general.brain.landed)
	assert_false(phantom.visible, "the double is gone")


func test_fleeing_in_phase_three_calms_the_petals_and_the_double() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	await _awake(general)
	var spot := _front(general, 8.0)
	await _phase_three(general, spot)
	general.brain.force_attack(A.FEINT)
	await _seconds(0.3)
	assert_true(general.phantom.visible)
	var calmed := watch(general.calmed)
	_put_guard(Vector3(13.5, 0.0, -50.0))   # the China hall
	await _seconds(Guardian.LEASH_TIME + 0.5)
	assert_eq(calmed.size(), 1)
	assert_false(general.storm.falling, "the petals stop")
	assert_false(general.phantom.visible, "the double is gone")
	assert_false(general.kinematic)
