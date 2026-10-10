extends TestCase
## First-night tips: one at a time, when they matter, once ever.

const OUTSIDE := Vector3(0, 0.1, 50)

var museum: Museum


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _museum() -> Museum:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	return museum


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


## Looks at the booth's upgrade terminal until it is in focus.
func _look_at_the_terminal() -> void:
	var terminal := museum.find_child("Terminal_security", true, false) as Node3D
	var front := -terminal.global_transform.basis.z
	museum.player.global_position = terminal.global_position + front * 1.3 + Vector3.UP * 0.1
	museum.player.head.rotation = Vector3(-0.45, atan2(front.x, front.z), 0.0)
	for i in 30:
		await physics_frames(1)
		if museum.player.interactor.focus != null:
			return


func test_the_tips_come_one_at_a_time_when_they_matter() -> void:
	GameState.new_game()
	_museum()
	museum.player.head.rotation = Vector3(0.6, 0.0, 0.0)   # at the ceiling: nothing in view
	await _seconds(1.0)
	assert_eq(museum.hud.hint_text(), "", "nothing at first")
	await _look_at_the_terminal()
	await physics_frames(2)
	var interact := tr("HUD_HINT_INTERACT") % GameInput.key_label(&"interact")
	assert_eq(museum.hud.hint_text(), interact, "something usable in view")
	museum.player.global_position = OUTSIDE
	museum.player.head.rotation = Vector3(0.6, 0.0, 0.0)
	await _seconds(1.0)
	assert_eq(museum.hud.hint_text(), interact, "one at a time")
	await _seconds(Onboarding.SHOW_TIME + 0.5)
	assert_eq(museum.hud.hint_text(), tr("HUD_HINT_FLASHLIGHT") % GameInput.key_label(&"flashlight"), "out of the lit booth")
	await _seconds(Onboarding.SHOW_TIME + 1.0)
	assert_eq(museum.hud.hint_text(), tr("HUD_HINT_FUSES"), "and then the goal")
	assert_true(museum.onboarding.done())
	var on_disk := Onboarding.load_seen()
	assert_eq(on_disk.size(), 3, "remembered")


func test_tips_are_shown_once_ever() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	museum.onboarding.seen = Onboarding.ORDER.duplicate()
	museum.onboarding._save_seen()
	museum.free()
	_museum()
	await physics_frames(2)
	assert_true(museum.onboarding.done())
	museum.player.global_position = OUTSIDE
	await _look_at_the_terminal()
	await _seconds(2.0)
	assert_eq(museum.hud.hint_text(), "")


func test_a_guard_who_finds_the_flashlight_himself_gets_no_tip_for_it() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	museum.player.set_flashlight(true)
	museum.player.head.rotation = Vector3(0.6, 0.0, 0.0)
	museum.player.global_position = OUTSIDE
	await _seconds(1.0)
	assert_true(museum.onboarding.seen.has(Onboarding.FLASHLIGHT))
	assert_ne(museum.hud.hint_text(), tr("HUD_HINT_FLASHLIGHT") % GameInput.key_label(&"flashlight"))
