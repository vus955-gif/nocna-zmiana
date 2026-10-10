extends TestCase
## The dash's lane leads a running guard: a guard who keeps strafing at a
## walk through the telegraph and the lunge is cut (the lane led him), one
## who turns back at the lock is missed - the fair reading of the lane.

const A := GeneralBrain.Attack
const S := GeneralBrain.State
const T := GeneralBrain.Stage
const START := Vector3(8.0, 0.0, -65.5)
## The guard's strafe (m/s; he walks 5.5).
const STRAFE := 4.0

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


func _awake(general: General) -> void:
	_put_guard(START)
	await _seconds(0.3)
	await _seconds(GeneralBrain.WAKE_TIME + 0.15)


func _guarding(general: General, at: Vector3) -> void:
	for i in 60 * 8:
		if general.brain.state == S.GUARD:
			return
		_put_guard(at)
		museum.player.heal(100000.0)
		await get_tree().physics_frame


## A dash with the guard strafing from [param from] along [param across]
## at STRAFE, turning back at the lock when [param reverse]; true when
## the blade found him.
func _strafed_dash(general: General, from: Vector3, across: Vector3, reverse: bool) -> bool:
	await _guarding(general, from)
	museum.player.heal(100000.0)
	var health := museum.player.health.current
	var at := from
	var direction := across
	general.brain.force_attack(A.DASH)
	var step := 1.0 / Engine.physics_ticks_per_second
	while general.brain.state == S.ATTACK and general.brain.stage != T.RECOVER:
		if reverse and general.dash_locked:
			direction = -across
		at += direction * STRAFE * step
		_put_guard(at)
		await get_tree().physics_frame
	return museum.player.health.current < health - 1.0


func test_a_guard_who_keeps_strafing_is_cut_one_who_turns_back_at_the_lock_is_missed() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	await _awake(general)
	var from := general.home.origin - general.home.basis.z * 8.0 + general.home.basis.x * 2.5
	var across := -general.home.basis.x
	assert_true(await _strafed_dash(general, from, across, false), "strafing on: the lane led him, the blade found him")
	assert_true(general.brain.landed)
	var again := general.global_position - general.global_basis.z * 8.0 + general.global_basis.x * 2.5
	assert_false(await _strafed_dash(general, again, -general.global_basis.x, true), "turning back at the lock: missed")
	assert_true(general.brain.back_open(), "and his back is open")
