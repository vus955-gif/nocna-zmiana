extends TestCase
## The first night on Floor I teaches like the lobby's: the flashlight as
## the guard steps out of the booth, then (in the entrance hall) the way to
## a weapon and where the goal is shown; nothing once he is armed.

var museum: Museum


func before_each() -> void:
	Museum.level_id = &"floor1"


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _museum() -> Museum:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	return museum


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _put_guard(at: Vector3) -> void:
	museum.player.global_position = at + Vector3.UP * 0.1
	museum.player.velocity = Vector3.ZERO
	museum.player.head.rotation = Vector3(0.6, 0.0, 0.0)   # at the ceiling: nothing usable in view


## Waits up to [param seconds] for the hint line to read [param text].
func _hint_shows(text: String, seconds: float) -> bool:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		if museum.hud.hint_text() == text:
			return true
		await get_tree().physics_frame
	return museum.hud.hint_text() == text


func test_out_of_the_booth_the_flashlight_then_the_way_to_a_weapon() -> void:
	GameState.new_game()
	_museum()
	assert_not_null(museum.onboarding, "tips on Floor I too")
	museum.onboarding.seen.clear()
	assert_eq(museum.onboarding.order(), Onboarding.FLOOR_ORDER)
	museum.player.head.rotation = Vector3(0.6, 0.0, 0.0)
	await _seconds(1.0)
	assert_eq(museum.hud.hint_text(), "", "nothing in the booth")
	_put_guard(Vector3(22, 0, 42))   # the staff corridor
	var flashlight := tr("HUD_HINT_FLASHLIGHT") % GameInput.key_label(&"flashlight")
	assert_true(await _hint_shows(flashlight, 2.0), "the flashlight out of the lit booth")
	_put_guard(Vector3(0, 0, 45))   # the entrance hall
	assert_true(await _hint_shows(tr("HUD_HINT_FLOOR1_GOAL"), Onboarding.SHOW_TIME + 3.0), "then the way to a weapon")
	assert_true(museum.onboarding.seen.has(Onboarding.FLOOR_GOAL))
	assert_true(Onboarding.load_seen().has(Onboarding.FLOOR_GOAL), "once ever")


func test_an_armed_guard_needs_no_goal_tip() -> void:
	GameState.new_game()
	GameState.add_weapon(&"pistol")
	_museum()
	museum.onboarding.seen = [Onboarding.FLASHLIGHT, Onboarding.INTERACT] as Array[StringName]
	_put_guard(Vector3(0, 0, 45))
	await _seconds(2.0)
	assert_ne(museum.hud.hint_text(), tr("HUD_HINT_FLOOR1_GOAL"))
	assert_true(museum.onboarding.done())
