extends TestCase
## MusicDirector: which music plays when (pure logic).

const S := MusicDirector.State

var director: MusicDirector


func before_each() -> void:
	director = MusicDirector.new()


func _run(seconds: float, nearby: int = 0, engaged: int = 0, haven: bool = false, step: float = 0.1) -> void:
	var left := seconds
	while left > 0.0001:
		var dt := minf(step, left)
		director.update(dt, nearby, engaged, haven)
		left -= dt


func test_scene_kinds_choose_the_base_state() -> void:
	assert_eq(director.state, S.SILENT)
	director.set_mode(AudioContext.MENU)
	assert_eq(director.state, S.MENU)
	director.set_mode(AudioContext.END)
	assert_eq(director.state, S.MENU, "the end screen plays the menu theme")
	director.set_mode(AudioContext.GAME)
	assert_eq(director.state, S.EXPLORE)
	director.set_mode(AudioContext.OFF)
	assert_eq(director.state, S.SILENT)


func test_a_fight_decays_to_tension_then_to_exploration() -> void:
	director.set_mode(AudioContext.GAME)
	director.on_combat(MusicDirector.HIT_HEAT)
	assert_eq(director.state, S.COMBAT)
	_run(MusicDirector.COMBAT_HOLD - 0.5)
	assert_eq(director.state, S.COMBAT, "still fighting before the hold runs out")
	_run(1.0)
	assert_eq(director.state, S.TENSION, "no combat for COMBAT_HOLD s")
	_run(MusicDirector.TENSION_HOLD + 0.5)
	assert_eq(director.state, S.EXPLORE, "calm again")


func test_every_combat_event_restarts_the_hold() -> void:
	director.set_mode(AudioContext.GAME)
	director.on_combat(MusicDirector.HIT_HEAT)
	for i in 4:
		_run(MusicDirector.COMBAT_HOLD * 0.75)
		director.on_combat(MusicDirector.HURT_HEAT)
	assert_eq(director.state, S.COMBAT)


func test_awake_exhibits_nearby_mean_tension_and_melee_means_a_fight() -> void:
	director.set_mode(AudioContext.GAME)
	_run(1.0, 2, 0)
	assert_eq(director.state, S.TENSION, "hunted")
	_run(0.2, 2, 1)
	assert_eq(director.state, S.COMBAT, "an exhibit in melee range starts a fight")
	_run(MusicDirector.COMBAT_HOLD + 0.5, 2, 0)
	assert_eq(director.state, S.TENSION, "still hunted after the fight")
	_run(MusicDirector.TENSION_HOLD + 0.5, 0, 0)
	assert_eq(director.state, S.EXPLORE)


func test_a_haven_ignores_hunters_and_winds_a_fight_down_twice_as_fast() -> void:
	director.set_mode(AudioContext.GAME)
	director.on_combat(MusicDirector.HIT_HEAT)
	_run(MusicDirector.COMBAT_HOLD * 0.5 + 0.2, 3, 3, true)
	assert_ne(director.state, S.COMBAT, "half the hold is enough in a haven")
	assert_eq(director.threats, 0, "hunters outside do not count")
	_run(10.0, 3, 3, true)
	assert_eq(director.state, S.EXPLORE)


func test_intensity_rises_with_events_and_decays_after_a_while() -> void:
	director.set_mode(AudioContext.GAME)
	for i in 5:
		director.on_combat(MusicDirector.KILL_HEAT)
	var hot := director.intensity
	assert_almost_eq(hot, 5 * MusicDirector.KILL_HEAT, 0.001)
	assert_gt(director.hi_level(), 0.9, "a hot fight brings the hi stem in")
	_run(MusicDirector.INTENSITY_HOLD - 0.2)
	assert_almost_eq(director.intensity, hot, 0.001, "held for a moment")
	_run(3.0)
	assert_lt(director.intensity, hot, "then it cools")
	assert_true(director.intensity >= 0.0)


func test_hunters_keep_a_floor_of_intensity_in_combat() -> void:
	director.set_mode(AudioContext.GAME)
	director.on_combat(0.0)
	_run(0.5, 4, 1)
	assert_almost_eq(director.intensity, minf(4 * MusicDirector.THREAT_HEAT, MusicDirector.THREAT_FLOOR), 0.001)


func test_layer_targets_follow_the_state() -> void:
	director.set_mode(AudioContext.GAME)
	var calm := director.layer_targets()
	assert_eq(calm[&"explore"], 1.0)
	assert_eq(calm[&"explore_tension"], 0.0)
	_run(0.5, 1, 0)
	var tense := director.layer_targets()
	assert_eq(tense[&"explore"], 1.0, "tension is layered on the walk")
	assert_eq(tense[&"explore_tension"], 1.0)
	director.on_combat(0.0)
	var fight := director.layer_targets()
	assert_eq(fight[&"explore"], 0.0)
	assert_eq(fight[&"combat"], 1.0)
	assert_eq(fight[&"combat_hi"], 0.0, "a cold fight has no hi stem")
	for layer in MusicDirector.LAYERS:
		assert_true(fight.has(layer), "target for " + layer)


func test_boss_phases_victory_and_back_to_the_walk() -> void:
	director.set_mode(AudioContext.GAME)
	director.on_boss_awakened()
	assert_eq(director.state, S.BOSS)
	assert_eq(director.layer_targets()[&"boss_hi"], 0.0, "phase 1: base only")
	director.on_boss_phase(2)
	assert_eq(director.layer_targets()[&"boss_hi"], 1.0, "phase 2 brings the hi stem")
	director.on_combat(MusicDirector.HIT_HEAT)
	assert_eq(director.state, S.BOSS, "hits do not leave the boss track")
	director.on_boss_defeated()
	assert_eq(director.state, S.VICTORY)
	_run(MusicDirector.VICTORY_TIME + 0.2)
	assert_eq(director.state, S.EXPLORE)


func test_a_new_boss_starts_in_phase_one_and_a_vanished_one_ends_the_boss_music() -> void:
	director.set_mode(AudioContext.GAME)
	director.on_boss_awakened()
	director.on_boss_phase(3)
	director.on_boss_gone()
	assert_eq(director.state, S.EXPLORE, "removed undefeated: no victory, no boss music")
	director.on_boss_awakened()
	assert_eq(director.boss_phase, 1, "a fresh boss")
	assert_eq(director.layer_targets()[&"boss_hi"], 0.0)
	director.on_boss_defeated()
	director.on_boss_gone()
	assert_eq(director.state, S.VICTORY, "freeing a defeated boss does not cut the victory")


func test_death_silences_the_night_and_ignores_later_events() -> void:
	director.set_mode(AudioContext.GAME)
	director.on_combat(MusicDirector.HIT_HEAT)
	var changes := watch(director.state_changed)
	director.on_player_died()
	assert_eq(director.state, S.SILENT)
	assert_eq(changes.size(), 1)
	director.on_combat(MusicDirector.HURT_HEAT)
	director.on_boss_awakened()
	assert_eq(director.state, S.SILENT)
	director.set_mode(AudioContext.GAME)
	assert_eq(director.state, S.EXPLORE, "the next night starts fresh")


func test_a_guard_respawned_in_place_brings_the_music_back() -> void:
	director.set_mode(AudioContext.GAME)
	director.on_combat(MusicDirector.KILL_HEAT)
	director.on_player_died()
	assert_eq(director.state, S.SILENT)
	director.on_player_revived()
	assert_eq(director.state, S.EXPLORE, "the sandbox and the dev viewers respawn without a scene change")
	assert_eq(director.intensity, 0.0)


func test_events_outside_a_game_scene_do_nothing() -> void:
	director.set_mode(AudioContext.MENU)
	director.on_combat(MusicDirector.KILL_HEAT)
	director.on_boss_awakened()
	director.on_player_died()
	assert_eq(director.state, S.MENU)
	assert_eq(director.intensity, 0.0)


func test_hold_forces_a_state_until_release() -> void:
	director.set_mode(AudioContext.GAME)
	director.hold(S.TENSION)
	assert_eq(director.state, S.TENSION)
	director.on_combat(MusicDirector.HIT_HEAT)
	assert_eq(director.state, S.TENSION, "held")
	director.release()
	assert_eq(director.state, S.COMBAT)


# --- the night in the lobby -------------------------------------------------

const STAGE := NightObjective.Stage


func _targets() -> Dictionary:
	return director.layer_targets()


func test_the_first_night_and_a_calm_one_walk_quieter() -> void:
	director.set_mode(AudioContext.GAME)
	director.on_night_started(1, &"none")
	director.on_objective(STAGE.FUSES)
	assert_eq(director.state, S.EXPLORE)
	assert_eq(_targets()[&"explore"], MusicDirector.QUIET_WALK, "night 1")
	assert_eq(_targets()[&"explore_tension"], 0.0)
	director.on_night_started(2, &"none")
	assert_eq(_targets()[&"explore"], 1.0, "night 2")
	director.on_night_started(5, &"calm")
	assert_eq(_targets()[&"explore"], MusicDirector.QUIET_WALK, "a calm night")
	_run(0.5, 1, 0)
	assert_eq(_targets()[&"explore"], 1.0, "hunted: the walk is full again")


func test_a_full_moon_and_the_witching_hour_keep_tension_under_the_walk() -> void:
	director.set_mode(AudioContext.GAME)
	director.on_night_started(3, &"full_moon")
	assert_eq(director.state, S.EXPLORE)
	assert_eq(_targets()[&"explore_tension"], MusicDirector.MOON_TENSION, "a little tension under the moon")
	director.on_witching_hour()
	assert_eq(director.state, S.EXPLORE, "still a walk")
	assert_eq(_targets()[&"explore_tension"], MusicDirector.WITCHING_TENSION, "the denser layer from 3:00")
	_run(30.0)
	assert_eq(_targets()[&"explore_tension"], MusicDirector.WITCHING_TENSION, "for the rest of the night")
	await get_tree().process_frame
	director.on_night_started(4, &"none")
	assert_eq(_targets()[&"explore_tension"], 0.0, "a new night starts clean")


func test_the_power_cut_hushes_the_music_then_brings_tension() -> void:
	director.set_mode(AudioContext.GAME)
	director.on_night_started(2, &"none")
	director.on_objective(STAGE.FUSES)
	director.on_objective(STAGE.PULSING)
	director.on_power_cut()
	assert_true(director.hushed())
	assert_eq(director.state, S.TENSION)
	assert_eq(_targets()[&"explore"], MusicDirector.HUSH_LEVEL, "near silence")
	assert_eq(_targets()[&"explore_tension"], MusicDirector.HUSH_LEVEL)
	_run(MusicDirector.HUSH_TIME - 0.2)
	assert_true(director.hushed())
	_run(0.3)
	assert_false(director.hushed())
	assert_eq(director.state, S.TENSION, "the crystal beats: tension")
	assert_eq(_targets()[&"explore"], 1.0)
	assert_eq(_targets()[&"explore_tension"], MusicDirector.POWER_TENSION)
	_run(MusicDirector.TENSION_HOLD * 3.0)
	assert_eq(director.state, S.TENSION, "for as long as the power is out")


func test_a_fight_in_the_hush_is_not_hushed() -> void:
	director.set_mode(AudioContext.GAME)
	director.on_objective(STAGE.PULSING)
	director.on_power_cut()
	director.on_combat(MusicDirector.HIT_HEAT)
	assert_eq(director.state, S.COMBAT)
	assert_eq(_targets()[&"combat"], 1.0)


func test_the_crystal_flight_brings_the_tension_stem_in_full() -> void:
	director.set_mode(AudioContext.GAME)
	director.on_night_started(1, &"none")
	director.on_objective(STAGE.PULSING)
	assert_eq(_targets()[&"explore_tension"], MusicDirector.POWER_TENSION)
	director.on_objective(STAGE.FLIGHT)
	assert_eq(director.state, S.TENSION)
	assert_eq(_targets()[&"explore_tension"], 1.0, "tension rises")
	assert_eq(_targets()[&"explore"], MusicDirector.QUIET_WALK, "the first night's walk stays soft under it")


func test_the_boss_then_victory_then_a_quiet_walk_without_tension() -> void:
	director.set_mode(AudioContext.GAME)
	director.on_night_started(3, &"full_moon")
	director.on_witching_hour()
	director.on_objective(STAGE.FLIGHT)
	director.on_boss_awakened()
	director.on_objective(STAGE.BOSS)
	assert_eq(director.state, S.BOSS)
	director.on_boss_phase(2)
	assert_eq(_targets()[&"boss_hi"], 1.0)
	director.on_objective(STAGE.DESCEND)
	director.on_boss_defeated()
	assert_eq(director.state, S.VICTORY)
	_run(MusicDirector.VICTORY_TIME + 0.2)
	assert_eq(director.state, S.EXPLORE, "the goal is done: no more alert")
	assert_eq(_targets()[&"explore"], MusicDirector.QUIET_WALK, "a quiet walk to the stairs")
	assert_eq(_targets()[&"explore_tension"], 0.0, "no moon, no witching layer any more")


func test_dawn_silences_everything_even_the_boss() -> void:
	director.set_mode(AudioContext.GAME)
	director.on_night_started(2, &"none")
	director.on_boss_awakened()
	var changes := watch(director.state_changed)
	director.on_dawn()
	assert_eq(director.state, S.SILENT)
	assert_eq(changes.size(), 1)
	for layer: StringName in MusicDirector.LAYERS:
		assert_eq(_targets()[layer], 0.0, String(layer))
	director.on_combat(MusicDirector.KILL_HEAT)
	assert_eq(director.state, S.SILENT, "the exhibits stood still at 6:00")
	await get_tree().process_frame
	director.on_night_started(3, &"none")
	director.set_mode(AudioContext.GAME)
	assert_eq(director.state, S.EXPLORE, "the next night")


func test_a_new_scene_keeps_the_night_it_announced() -> void:
	director.on_night_started(1, &"none")
	director.on_objective(STAGE.PULSING)
	director.set_mode(AudioContext.GAME)
	assert_eq(director.state, S.TENSION, "a resumed night with the power out starts tense")
	assert_false(director.hushed(), "no hush without the moment of the cut")
