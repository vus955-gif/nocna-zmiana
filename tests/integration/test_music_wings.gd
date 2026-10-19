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
	Music.blocking_loads = true
	get_tree().paused = false


func _advance(seconds: float, step: float = 0.05) -> void:
	var left := seconds
	while left > 0.0001:
		var dt := minf(step, left)
		Music.director.update(dt, 0, 0, false)
		Music.advance(dt)
		left -= dt


func _player(track: StringName) -> AudioStreamPlayer:
	return Music.player_of(track)


## Waits (real time: a load runs on its own thread) until [param family] is
## loaded; false after a few seconds.
func _wait_loaded(family: StringName) -> bool:
	var deadline := Time.get_ticks_msec() + 15000
	while not Music.is_family_loaded(family) and Time.get_ticks_msec() < deadline:
		OS.delay_msec(5)
		await get_tree().process_frame
	return Music.is_family_loaded(family)


## A night walk that has played long enough for zones to settle.
func _walk() -> void:
	Music.set_scene_kind(AudioContext.GAME)
	_advance(Music.FADE_IN[&"explore"] + 0.1)


func test_every_wing_track_and_sting_has_its_file() -> void:
	for family: StringName in Music.FAMILIES:
		Music.request_family(family)
		assert_true(Music.is_family_loaded(family), String(family))
		for track: StringName in Music.FAMILIES[family]:
			assert_not_null(_player(track), String(track))
			if _player(track) != null:
				assert_true(Music.has_track(track), String(track) + " has its file")
				assert_eq(_player(track).bus, &"Music")
				assert_eq(Music.family_of(track), family)
	for sting in Music.STINGS:
		assert_not_null((Music.stings[sting] as AudioStreamPlayer).stream, String(sting))
	for zone in MusicDirector.MUSIC_ZONES:
		var family := Music.zone_family(zone)
		assert_true(Music.FAMILIES.has(family), String(zone) + " has its family")
		for layer in MusicDirector.ZONE_LAYERS:
			assert_true(Music.levels.has(Music.track(layer, zone)), "%s in %s" % [layer, zone])
			assert_true((Music.FAMILIES.get(family, []) as Array).has(Music.track(layer, zone)), "%s in one synced loop" % layer)
	for wing in MusicDirector.WINGS:
		for layer: StringName in [&"guardian", &"guardian_hi"]:
			assert_true((Music.FAMILIES[Music.guardian_family(wing)] as Array).has(Music.track(layer, wing)), "%s in %s" % [layer, wing])
		assert_true(Music.OVERLAYS.has(StringName("wing_sting_" + String(wing))), String(wing))


func test_tracks_map_back_to_their_layers() -> void:
	assert_eq(Music.track(&"explore", &""), &"explore")
	assert_eq(Music.track(&"explore_tension", &"asia"), &"explore_asia_tension")
	assert_eq(Music.track(&"guardian_hi", &"greece"), &"guardian_greece_hi")
	assert_eq(Music.layer_of(&"explore_asia_tension"), &"explore_tension")
	assert_eq(Music.layer_of(&"explore_asia"), &"explore")
	assert_eq(Music.layer_of(&"guardian_greece_hi"), &"guardian_hi")
	assert_eq(Music.layer_of(&"combat_hi"), &"combat_hi")
	assert_eq(Music.layer_of(&"combat"), &"combat")
	assert_eq(Music.track(&"combat", &"egypt"), &"combat_egypt")
	assert_eq(Music.track(&"combat_hi", &"roof"), &"combat_roof_hi")
	assert_eq(Music.track(&"combat", &""), &"combat", "the lobby keeps its own fight")
	assert_eq(Music.layer_of(&"combat_egypt"), &"combat")
	assert_eq(Music.layer_of(&"combat_roof_hi"), &"combat_hi")
	assert_true(Music.resumes(&"zone_egypt"), "a zone's loop (walk and fight) keeps its place")
	assert_true(Music.resumes(&"explore"))
	assert_true(Music.resumes(&"menu"))
	assert_false(Music.resumes(&"combat"))
	assert_false(Music.resumes(&"guardian_egypt"))
	assert_eq(Music.zone_family(&"egypt"), &"zone_egypt")
	assert_eq(Music.guardian_family(&"egypt"), &"guardian_egypt")


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
	assert_true(Music.is_family_playing(&"zone_greece"))
	Events.room_entered.emit(&"court", &"court", false)
	_advance(MusicDirector.VARIANT_SETTLE + Music.CROSSFADE + 0.2)
	assert_false(Music.is_family_playing(&"zone_greece"))
	assert_true(Music._positions.has(&"zone_greece"), "its place is kept")
	Events.room_entered.emit(&"gallery", &"greece", false)
	_advance(MusicDirector.VARIANT_SETTLE + 0.1)
	assert_true(Music.is_family_playing(&"zone_greece"), "and it comes back from there")


func test_a_quick_return_never_restarts_the_walk() -> void:
	_walk()
	Events.room_entered.emit(&"lions", &"assyria", false)
	_advance(MusicDirector.VARIANT_SETTLE + Music.CROSSFADE + 0.2)
	Events.room_entered.emit(&"door", &"north_hall", false)
	_advance(0.5)
	Events.room_entered.emit(&"lions", &"assyria", false)
	_advance(2.0)
	assert_true(Music.is_family_playing(&"zone_assyria"))
	assert_almost_eq(Music.levels[&"explore_assyria"], 1.0, 0.001, "never left")
	assert_eq(Music.levels[&"explore"], 0.0, "the lobby's walk never came back")


func test_a_fight_plays_the_zones_heavy_stem_in_sync_with_its_walk() -> void:
	_walk()
	Events.room_entered.emit(&"tea", &"asia", false)
	_advance(MusicDirector.VARIANT_SETTLE + Music.CROSSFADE + 0.2)
	var walk := _player(&"explore_asia")
	Music.director.on_combat(MusicDirector.HIT_HEAT)
	_advance(0.5)
	assert_gt(Music.levels[&"combat_asia"], 0.5, "the wing's own fight comes in fast")
	assert_true(_player(&"combat_asia").playing)
	assert_true(_player(&"combat_asia_hi").playing, "its hi stem runs in sync, silent")
	assert_eq(_player(&"combat_asia"), walk, "one loop: the same player, the same bar")
	assert_false(Music.is_family_playing(&"combat"), "not the lobby's fight")
	_advance(Music.FADE_OUT[&"explore"] + 0.1)
	assert_eq(Music.levels[&"explore_asia"], 0.0, "the walk gives way under the fight")
	assert_true(walk.playing, "but keeps its place in the loop")
	_advance(MusicDirector.COMBAT_HOLD + Music.FADE_OUT[&"combat"] - Music.FADE_OUT[&"explore"])
	assert_eq(Music.state(), S.TENSION)
	assert_gt(Music.levels[&"explore_asia_tension"], 0.5, "the wing's own tension stem")
	assert_eq(Music.levels[&"explore_tension"], 0.0)
	assert_eq(Music.levels[&"combat_asia"], 0.0)


func test_the_hub_the_basement_and_the_roof_have_their_own_music() -> void:
	_walk()
	for case: Array in [[&"court", &"court"], [&"booth", &"court"], [&"boiler", &"basement_boiler"], [&"catwalk", &"roof"]]:
		Events.room_entered.emit(case[0], case[1], false)
		_advance(MusicDirector.VARIANT_SETTLE + Music.CROSSFADE + 0.2)
		var zone := MusicDirector.music_zone_of(case[1])
		assert_almost_eq(Music.levels[Music.track(&"explore", zone)], 1.0, 0.001, String(case[1]))
	assert_eq(Music.levels[&"explore"], 0.0, "the lobby's walk is not the hub's")


func test_a_fight_through_a_doorway_moves_its_music_only_once_it_holds() -> void:
	_walk()
	Events.room_entered.emit(&"rosetta", &"egypt", false)
	_advance(MusicDirector.VARIANT_SETTLE + Music.CROSSFADE + 0.2)
	Music.director.on_combat(MusicDirector.HIT_HEAT)
	_advance(0.5)
	Events.room_entered.emit(&"gallery", &"greece", false)
	_advance(MusicDirector.FIGHT_SETTLE * 0.5)
	assert_gt(Music.levels[&"combat_egypt"], 0.99, "the fight keeps its music on the doorway")
	assert_eq(Music.levels[&"combat_greece"], 0.0)
	Music.director.on_combat(MusicDirector.HIT_HEAT)
	_advance(MusicDirector.FIGHT_SETTLE * 0.5 + Music.FIGHT_CROSSFADE * 0.5)
	var old: float = Music.levels[&"combat_egypt"]
	var new: float = Music.levels[&"combat_greece"]
	assert_gt(new, 0.2, "Greece's fight comes in")
	assert_gt(sin(old * PI * 0.5) ** 2 + sin(new * PI * 0.5) ** 2, 0.8, "equal power")
	_advance(Music.FIGHT_CROSSFADE * 0.5 + 0.1)
	assert_almost_eq(Music.levels[&"combat_greece"], 1.0, 0.001, "a short handover between two heavy mixes")
	assert_eq(Music.levels[&"combat_egypt"], 0.0)


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
	assert_almost_eq(Music.stem_db(&"explore"), Music.DUCK_DB, 0.05, "the walk ducks under it")
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


# --- Floor I's music loads with the floor ------------------------------------

func test_entering_a_wing_loads_its_zone_and_guardian_families() -> void:
	assert_false(Music.is_family_loaded(&"zone_egypt"), "nothing of Floor I before it")
	_walk()
	Events.room_entered.emit(&"rosetta", &"egypt", false)
	assert_true(Music.is_family_loaded(&"zone_egypt"))
	assert_true(Music.is_family_loaded(&"guardian_egypt"), "its guardian is ready before it wakes")
	assert_false(Music.is_family_loaded(&"zone_greece"), "other wings stay on disk")
	assert_false(Music.is_family_loaded(&"guardian_greece"))
	Events.room_entered.emit(&"court", &"court", false)
	assert_true(Music.is_family_loaded(&"zone_court"))
	assert_false(Music.is_family_loaded(&"guardian_court"), "the hub has no guardian")


func test_a_family_asked_for_by_the_director_loads_by_itself() -> void:
	_walk()
	Music.director.on_zone(&"roof")
	_advance(MusicDirector.VARIANT_SETTLE + 0.1)
	assert_true(Music.is_family_loaded(&"zone_roof"), "the music zone around the guard is always loaded")
	Events.guardian_awakened.emit(null, &"samurai")
	_advance(0.1)
	assert_true(Music.is_family_loaded(&"guardian_asia"), "and so is a waking guardian's theme")
	assert_eq(Music.playing_track(&"guardian"), &"guardian_asia", "not the T-Rex's fallback")


func test_leaving_floor_one_frees_its_music() -> void:
	_walk()
	Events.room_entered.emit(&"rosetta", &"egypt", false)
	_advance(MusicDirector.VARIANT_SETTLE + Music.CROSSFADE + 0.2)
	assert_true(Music.is_family_playing(&"zone_egypt"))
	var player := _player(&"explore_egypt")
	await get_tree().process_frame
	await get_tree().process_frame
	Music._on_scene_changed()   # a later scene that announced no zone
	for family: StringName in Music.FAMILIES:
		if not Music.EAGER.has(family):
			assert_false(Music.is_family_loaded(family), String(family))
	assert_false(is_instance_valid(player), "its player is gone, and the streams with it")
	assert_true(Music.get_node_or_null(^"zone_egypt") == null)
	assert_eq(Music.levels[&"explore_egypt"], 0.0)
	assert_true(Music.is_family_loaded(&"explore"), "the lobby's music stays")
	assert_true(Music.is_family_loaded(&"menu"))


func test_a_scene_that_announced_its_zone_keeps_the_floors_music() -> void:
	_walk()
	Events.room_entered.emit(&"rosetta", &"egypt", false)
	Music._on_scene_changed()   # a Floor I night restarting: announced in the same frame
	assert_true(Music.is_family_loaded(&"zone_egypt"))


func test_only_the_latest_floor_families_stay_loaded() -> void:
	_walk()
	for zone in MusicDirector.WINGS:
		Events.room_entered.emit(&"room", zone, false)
	var lazy := Music.loaded_floor_families()
	assert_true(lazy.size() <= Music.MAX_FLOOR_FAMILIES, "bounded: %d" % lazy.size())
	assert_true(lazy.has(Music.zone_family(&"americas")), "the newest stays")
	assert_true(lazy.has(Music.guardian_family(&"americas")))
	assert_false(lazy.has(Music.zone_family(&"egypt")), "the oldest was let go")
	# an audible family is never let go
	Music.reset()
	_walk()
	Events.room_entered.emit(&"rosetta", &"egypt", false)
	_advance(MusicDirector.VARIANT_SETTLE + Music.CROSSFADE + 0.2)
	for zone in [&"assyria", &"greece", &"enlightenment", &"asia"]:
		Events.room_entered.emit(&"room", zone, false)
	assert_true(Music.is_family_playing(&"zone_egypt"), "still playing: kept")
	assert_true(Music.is_family_loaded(&"zone_egypt"))


func test_a_night_starting_on_a_floor_waits_for_its_load_in_silence() -> void:
	Music.blocking_loads = false
	Music.set_scene_kind(AudioContext.GAME)
	Events.room_entered.emit(&"rosetta", &"egypt", false)
	assert_eq(Music.director.variant, &"egypt", "a fresh walk takes its zone at once")
	assert_true(Music.is_family_loading(&"zone_egypt"), "on its thread: no frame waits for it")
	assert_eq(Music.playing_track(&"explore"), &"", "nothing to play yet, and not the lobby's tune in its place")
	_advance(0.3)
	assert_eq(Music.levels[&"explore"], 0.0, "the lobby's walk never starts")
	assert_eq(Music.levels[&"explore_egypt"], 0.0)
	assert_true(await _wait_loaded(&"zone_egypt"), "loaded on its own thread")
	assert_false(Music.is_family_loading(&"zone_egypt"))
	_advance(Music.FADE_IN[&"explore"] + 0.1)
	assert_eq(Music.playing_track(&"explore"), &"explore_egypt")
	assert_almost_eq(Music.levels[&"explore_egypt"], 1.0, 0.001)
	assert_eq(Music.levels[&"explore"], 0.0)
	assert_true(Music.is_family_playing(&"zone_egypt"))


func test_the_walk_plays_on_while_the_next_zone_loads() -> void:
	Music.blocking_loads = false
	_walk()
	Events.room_entered.emit(&"rosetta", &"egypt", false)
	_advance(MusicDirector.VARIANT_SETTLE + 0.1)
	assert_eq(Music.director.variant, &"egypt")
	assert_true(Music.is_family_loading(&"zone_egypt"))
	assert_eq(Music.playing_track(&"explore"), &"explore", "the previous tune plays on")
	assert_almost_eq(Music.levels[&"explore"], 1.0, 0.001, "without a dip")
	assert_true(await _wait_loaded(&"zone_egypt"))
	_advance(Music.CROSSFADE + 0.1)
	assert_almost_eq(Music.levels[&"explore_egypt"], 1.0, 0.001, "then the usual handover")
	assert_eq(Music.levels[&"explore"], 0.0)


func test_a_load_let_go_of_before_it_ends_frees_what_it_found() -> void:
	Music.blocking_loads = false
	Music.request_family(&"zone_enlightenment")
	Music.release_floor_music()
	assert_false(Music.is_family_loaded(&"zone_enlightenment"))
	var deadline := Time.get_ticks_msec() + 15000
	while Music.is_family_loading(&"zone_enlightenment") and Time.get_ticks_msec() < deadline:
		OS.delay_msec(5)
		await get_tree().process_frame
	assert_false(Music.is_family_loading(&"zone_enlightenment"), "the request is drained")
	assert_false(Music.is_family_loaded(&"zone_enlightenment"), "and nothing is built from it")
	Music.blocking_loads = true


func test_a_guardian_clears_the_zones_fight_fast() -> void:
	_walk()
	Events.room_entered.emit(&"rosetta", &"egypt", false)
	_advance(MusicDirector.VARIANT_SETTLE + Music.CROSSFADE + 0.2)
	Music.director.on_combat(MusicDirector.HIT_HEAT)
	_advance(Music.FADE_IN[&"combat"] + 0.1)
	assert_almost_eq(Music.levels[&"combat_egypt"], 1.0, 0.001)
	assert_eq(Music.fade_out_time(), 0.0)
	var colossus := _FakeGuardian.new()
	add_child(colossus)
	Events.guardian_awakened.emit(colossus, &"colossus")
	assert_eq(Music.state(), S.GUARDIAN)
	assert_eq(Music.fade_out_time(), Music.BOSS_FADE, "the guardian's theme takes over in about a second")
	_advance(Music.BOSS_FADE + 0.1)
	assert_eq(Music.levels[&"combat_egypt"], 0.0, "the zone's fight does not linger under it")
	assert_eq(Music.levels[&"explore_egypt"], 0.0)
	assert_almost_eq(Music.levels[&"guardian_egypt"], 1.0, 0.001)
	colossus.queue_free()
