extends TestCase
## The Music autoload on Floor I: a zone's wing crossfades the walk without
## restarting it, guardians play their wing's theme, progress stings lie
## over the music and duck it. Automation is off in test runs; each test
## switches it on and leaves it silent.

const S := MusicDirector.State


class _FakeGuardian:
	extends Node
	signal phase_changed(phase: int)


func before_each() -> void:
	Music.reset()
	Music.enabled = true


func after_each() -> void:
	Music.reset()
	Music.enabled = false
	get_tree().paused = false


func _advance(seconds: float, step: float = 0.05) -> void:
	var left := seconds
	while left > 0.0001:
		var dt := minf(step, left)
		Music.director.update(dt, 0, 0, false)
		Music.advance(dt)
		left -= dt


func _player(track: StringName) -> AudioStreamPlayer:
	return Music.players[track] as AudioStreamPlayer


## A night walk that has played long enough for zones to settle.
func _walk() -> void:
	Music.set_scene_kind(AudioContext.GAME)
	_advance(Music.FADE_IN[&"explore"] + 0.1)


func test_every_wing_track_and_sting_has_its_file() -> void:
	for family: StringName in Music.FAMILIES:
		for track: StringName in Music.FAMILIES[family]:
			assert_not_null(_player(track), String(track))
			if _player(track) != null:
				assert_not_null(_player(track).stream, String(track) + " has its file")
				assert_eq(_player(track).bus, &"Music")
	for sting in Music.STINGS:
		assert_not_null((Music.stings[sting] as AudioStreamPlayer).stream, String(sting))
	for wing in MusicDirector.WINGS:
		for layer: StringName in [&"explore", &"explore_tension", &"guardian", &"guardian_hi"]:
			assert_true(Music.players.has(Music.track(layer, wing)), "%s in %s" % [layer, wing])
		assert_true(Music.OVERLAYS.has(StringName("wing_sting_" + String(wing))), String(wing))


func test_tracks_map_back_to_their_layers() -> void:
	assert_eq(Music.track(&"explore", &""), &"explore")
	assert_eq(Music.track(&"explore_tension", &"asia"), &"explore_asia_tension")
	assert_eq(Music.track(&"guardian_hi", &"greece"), &"guardian_greece_hi")
	assert_eq(Music.layer_of(&"explore_asia_tension"), &"explore_tension")
	assert_eq(Music.layer_of(&"explore_asia"), &"explore")
	assert_eq(Music.layer_of(&"guardian_greece_hi"), &"guardian_hi")
	assert_eq(Music.layer_of(&"combat_hi"), &"combat_hi")
	assert_true(Music.resumes(&"explore_egypt"))
	assert_false(Music.resumes(&"guardian_egypt"))


func test_a_wing_crossfades_the_walk_without_a_gap() -> void:
	_walk()
	assert_almost_eq(Music.levels[&"explore"], 1.0, 0.001)
	Events.room_entered.emit(&"rosetta", &"egypt", false)
	_advance(MusicDirector.VARIANT_SETTLE + 0.1)
	assert_eq(Music.director.variant, &"egypt")
	_advance(Music.CROSSFADE * 0.5)
	var old: float = Music.levels[&"explore"]
	var new: float = Music.levels[&"explore_egypt"]
	assert_gt(old, 0.2, "the lobby's walk is still going")
	assert_gt(new, 0.2, "while Egypt's comes in")
	assert_gt(sin(old * PI * 0.5) ** 2 + sin(new * PI * 0.5) ** 2, 0.8, "equal power: no hole in the middle")
	assert_true(_player(&"explore_egypt_tension").playing, "the wing's tension stem runs in sync")
	_advance(Music.CROSSFADE)
	assert_almost_eq(Music.levels[&"explore_egypt"], 1.0, 0.001)
	assert_eq(Music.levels[&"explore"], 0.0)
	assert_false(Music.is_family_playing(&"explore"), "the old walk stops once silent")
	assert_eq(Music.state(), S.EXPLORE)


func test_coming_back_to_a_wing_resumes_its_walk() -> void:
	_walk()
	Events.room_entered.emit(&"gallery", &"greece", false)
	_advance(MusicDirector.VARIANT_SETTLE + Music.CROSSFADE + 0.2)
	assert_true(Music.is_family_playing(&"explore_greece"))
	Events.room_entered.emit(&"court", &"court", false)
	_advance(MusicDirector.VARIANT_SETTLE + Music.CROSSFADE + 0.2)
	assert_false(Music.is_family_playing(&"explore_greece"))
	assert_true(Music._positions.has(&"explore_greece"), "its place is kept")
	Events.room_entered.emit(&"gallery", &"greece", false)
	_advance(MusicDirector.VARIANT_SETTLE + 0.1)
	assert_true(Music.is_family_playing(&"explore_greece"), "and it comes back from there")


func test_a_quick_return_never_restarts_the_walk() -> void:
	_walk()
	Events.room_entered.emit(&"lions", &"assyria", false)
	_advance(MusicDirector.VARIANT_SETTLE + Music.CROSSFADE + 0.2)
	Events.room_entered.emit(&"door", &"north_hall", false)
	_advance(0.5)
	Events.room_entered.emit(&"lions", &"assyria", false)
	_advance(2.0)
	assert_true(_player(&"explore_assyria").playing)
	assert_almost_eq(Music.levels[&"explore_assyria"], 1.0, 0.001, "never left")
	assert_eq(Music.levels[&"explore"], 0.0, "the lobby's walk never came back")


func test_combat_keeps_the_wing_for_the_walk_after_it() -> void:
	_walk()
	Events.room_entered.emit(&"tea", &"asia", false)
	_advance(MusicDirector.VARIANT_SETTLE + Music.CROSSFADE + 0.2)
	Music.director.on_combat(MusicDirector.HIT_HEAT)
	_advance(0.5)
	assert_true(Music.is_family_playing(&"combat"), "the fight track is shared by all wings")
	_advance(MusicDirector.COMBAT_HOLD + Music.FADE_OUT[&"combat"] + 0.5)
	assert_eq(Music.state(), S.TENSION)
	assert_gt(Music.levels[&"explore_asia_tension"], 0.5, "the wing's own tension stem")
	assert_eq(Music.levels[&"explore_tension"], 0.0)


func test_a_guardian_plays_its_wings_theme_and_falls_with_its_sting() -> void:
	_walk()
	var serpent := _FakeGuardian.new()
	add_child(serpent)
	Events.guardian_awakened.emit(serpent, &"serpent")
	assert_eq(Music.state(), S.GUARDIAN)
	_advance(Music.FADE_IN[&"guardian"] + 0.1)
	assert_almost_eq(Music.levels[&"guardian_americas"], 1.0, 0.001)
	assert_true(_player(&"guardian_americas_hi").playing, "the hi stem runs in sync")
	assert_almost_eq(Music.levels[&"guardian_americas_hi"], 0.0, 0.001)
	serpent.phase_changed.emit(2)
	_advance(Music.FADE_IN[&"guardian_hi"] + 0.1)
	assert_almost_eq(Music.levels[&"guardian_americas_hi"], 1.0, 0.001, "phase 2")
	Events.guardian_defeated.emit(&"serpent")
	assert_eq(Music.state(), S.VICTORY)
	assert_true((Music.stings[&"guardian_sting"] as AudioStreamPlayer).playing, "the guardian's fall")
	assert_false((Music.stings[&"victory_sting"] as AudioStreamPlayer).playing, "not the T-Rex's")
	_advance(MusicDirector.GUARDIAN_VICTORY_TIME + 0.2)
	assert_eq(Music.state(), S.EXPLORE)
	serpent.queue_free()


func test_a_guardian_on_the_boss_bar_keeps_its_own_theme() -> void:
	_walk()
	var lamassu := _FakeGuardian.new()
	add_child(lamassu)
	Events.boss_awakened.emit(lamassu)
	Events.guardian_awakened.emit(lamassu, &"lamassu")
	assert_eq(Music.state(), S.GUARDIAN, "announced as the boss first")
	Events.boss_defeated.emit(lamassu)
	assert_eq(Music.state(), S.GUARDIAN, "its boss-bar fall is not the T-Rex's")
	Events.boss_awakened.emit(lamassu)
	assert_eq(Music.state(), S.GUARDIAN, "announced as the boss after")
	lamassu.queue_free()
	await get_tree().process_frame
	assert_eq(Music.state(), S.EXPLORE, "gone undefeated: back to the walk")


func test_a_seal_lays_its_sting_over_the_ducked_music() -> void:
	_walk()
	Events.seal_collected.emit(&"sun")
	var seal := Music.stings[&"seal_sting"] as AudioStreamPlayer
	assert_true(seal.playing)
	assert_eq(Music.state(), S.EXPLORE, "an overlay is no state")
	_advance(Music.DUCK_ATTACK + 0.05)
	assert_almost_eq(Music.duck_db(), Music.DUCK_DB, 0.01)
	assert_almost_eq(_player(&"explore").volume_db, Music.DUCK_DB, 0.05, "the walk ducks under it")
	Events.shard_collected.emit(&"shard_egypt", 1)
	assert_true(seal.playing, "picked up together: one sting")
	_advance(seal.stream.get_length() - Music.DUCK_TAIL + Music.DUCK_RELEASE + 0.1)
	assert_almost_eq(Music.duck_db(), 0.0, 0.01, "the walk comes back up")


func test_gates_and_new_wings_have_their_stings() -> void:
	_walk()
	Events.gate_opened.emit(&"khorsabad")
	assert_true((Music.stings[&"gate_sting"] as AudioStreamPlayer).playing)
	Events.room_entered.emit(&"garden", &"asia_garden", true)
	_advance(0.1)
	assert_true((Music.stings[&"wing_sting_asia"] as AudioStreamPlayer).playing, "Asia met for the first time")


func test_overlays_wait_for_a_guardians_fall() -> void:
	_walk()
	Events.guardian_awakened.emit(null, &"colossus")
	Events.guardian_defeated.emit(&"colossus")
	Events.seal_collected.emit(&"sun")
	var seal := Music.stings[&"seal_sting"] as AudioStreamPlayer
	assert_false(seal.playing, "waits for the guardian sting")
	(Music.stings[&"guardian_sting"] as AudioStreamPlayer).stop()
	_advance(0.05)
	assert_true(seal.playing, "then plays")


func test_no_overlay_outside_the_night() -> void:
	Music.set_scene_kind(AudioContext.MENU)
	assert_false(Music.play_overlay(&"seal_sting"))
	Music.set_scene_kind(AudioContext.GAME)
	Music.director.on_player_died()
	assert_false(Music.play_overlay(&"gate_sting"), "not for the fallen guard")


func test_a_scene_swap_forgets_a_zone_it_did_not_announce() -> void:
	_walk()
	Events.room_entered.emit(&"rosetta", &"egypt", false)
	assert_eq(Music.director.zone, &"egypt")
	Music._on_scene_changed()
	assert_eq(Music.director.zone, &"egypt", "announced in the same frame: kept")
	await get_tree().process_frame
	await get_tree().process_frame
	Music._on_scene_changed()
	assert_eq(Music.director.zone, &"", "a later scene without Floor I")
	assert_eq(Music.director.variant, &"")
