extends TestCase
## The "23:00" screen between nights.

var screen: DeathScreen


func before_each() -> void:
	screen = DeathScreen.new()
	add_child(screen)


func test_fades_in_then_shows_the_clock() -> void:
	assert_false(screen.visible)
	screen.play(3, 42)
	assert_true(screen.visible)
	assert_eq(screen._night.text, "NOC 3")
	assert_true(screen._note.text.contains("42"))
	await get_tree().create_timer(DeathScreen.FADE_TIME * 0.5).timeout
	assert_true(screen._black.modulate.a > 0.2 and screen._black.modulate.a < 0.95, "still fading")
	assert_lt(screen._clock.modulate.a, 0.01, "no clock yet")
	await get_tree().create_timer(DeathScreen.FADE_TIME * 0.5 + 0.4).timeout
	assert_almost_eq(screen._black.modulate.a, 1.0, 0.01)
	assert_gt(screen._clock.modulate.a, 0.9)


func test_finishes_after_the_alarm() -> void:
	var finished := watch(screen.finished)
	screen.play(2, 0)
	assert_eq(screen._note.text, tr("DEATH_NOTHING"))
	await get_tree().create_timer(DeathScreen.FADE_TIME + DeathScreen.CLOCK_TIME + 0.5).timeout
	assert_eq(finished.size(), 1)
	assert_false(screen.is_playing())


func test_runs_while_paused() -> void:
	get_tree().paused = true
	screen.play(2, 0)
	await get_tree().create_timer(DeathScreen.FADE_TIME + 0.3).timeout
	assert_almost_eq(screen._black.modulate.a, 1.0, 0.01)
	get_tree().paused = false


func test_alarm_rings() -> void:
	screen.play(2, 0)
	await get_tree().create_timer(DeathScreen.FADE_TIME + 0.2).timeout
	var ringing := false
	for voice in Sfx.get_children():
		if voice.get_meta(&"sound", &"") == &"alarm":
			ringing = true
			assert_eq(voice.get(&"bus"), &"UI")
	assert_true(ringing)
