extends TestCase
## MusicDirector on Floor I: zones pick the walk's wing, guardians bring
## their theme in their wing's colours, a wing met for the first time asks
## for its sting (pure logic).

const S := MusicDirector.State

var director: MusicDirector


func before_each() -> void:
	director = MusicDirector.new()


func _run(seconds: float, step: float = 0.1) -> void:
	var left := seconds
	while left > 0.0001:
		var dt := minf(step, left)
		director.update(dt, 0, 0, false)
		left -= dt


## A walk that has been playing for a while (a zone change then waits).
func _walking() -> void:
	director.set_mode(AudioContext.GAME)
	_run(MusicDirector.VARIANT_SETTLE + 1.0)


func test_every_zone_maps_to_its_wing_or_to_the_lobby_walk() -> void:
	for wing in MusicDirector.WINGS:
		assert_eq(MusicDirector.wing_of_zone(wing), wing)
	for zone: StringName in [&"court", &"entrance", &"booth", &"north_hall", &"basement", &"roof", &""]:
		assert_eq(MusicDirector.wing_of_zone(zone), &"", String(zone) + " plays the lobby's walk")
	assert_eq(MusicDirector.wing_of_zone(&"asia_garden"), &"asia", "a sub-zone belongs to its wing")
	assert_eq(MusicDirector.wing_of_zone(&"enlightenment_clocks"), &"enlightenment")
	assert_eq(MusicDirector.wing_of_zone(&"basement_boiler"), &"")
	assert_eq(MusicDirector.wing_of_zone(&"north_hall"), &"", "north is no wing")


func test_each_guardian_belongs_to_its_wing() -> void:
	var expected := {&"colossus": &"egypt", &"lamassu": &"assyria", &"centaur": &"greece", &"orrery": &"enlightenment",
		&"samurai": &"asia", &"serpent": &"americas"}
	for id: StringName in expected:
		assert_eq(MusicDirector.guardian_wing_of(id), expected[id], String(id))
	assert_eq(MusicDirector.guardian_wing_of(&"colossus_ramesses"), &"egypt", "an id with the guardian's prefix")
	assert_eq(MusicDirector.guardian_wing_of(&"greece"), &"greece", "an id naming a wing")
	assert_eq(MusicDirector.guardian_wing_of(&"egypt_guardian"), &"egypt", "an id starting with a wing")
	assert_eq(MusicDirector.guardian_wing_of(&"mystery", &"asia_garden"), &"asia", "unknown: the wing it fights in")
	assert_eq(MusicDirector.guardian_wing_of(&"mystery", &"court"), MusicDirector.WINGS[0], "unknown anywhere: a wing still")
	for wing: StringName in MusicDirector.GUARDIAN_WINGS.values():
		assert_true(MusicDirector.WINGS.has(wing))


func test_a_fresh_walk_takes_the_zone_at_once() -> void:
	director.set_mode(AudioContext.GAME)
	director.on_zone(&"egypt")
	assert_eq(director.variant, &"egypt", "no settling before the walk has been heard")
	assert_eq(director.zone, &"egypt")


func test_a_new_zone_must_hold_before_the_walk_changes() -> void:
	_walking()
	director.on_zone(&"egypt")
	assert_eq(director.variant, &"", "still the lobby's walk")
	_run(MusicDirector.VARIANT_SETTLE * 0.5)
	assert_eq(director.variant, &"")
	_run(MusicDirector.VARIANT_SETTLE * 0.5 + 0.1)
	assert_eq(director.variant, &"egypt", "the wing's walk after the settle time")
	assert_eq(director.state, S.EXPLORE, "a variant is no new state")


func test_flickering_on_a_threshold_keeps_the_walk() -> void:
	_walking()
	director.on_zone(&"greece")
	_run(MusicDirector.VARIANT_SETTLE + 0.1)
	assert_eq(director.variant, &"greece")
	for i in 5:
		director.on_zone(&"court")
		_run(0.2)
		director.on_zone(&"greece")
		_run(0.2)
	assert_eq(director.variant, &"greece", "a doorway is not a journey")
	_run(MusicDirector.VARIANT_SETTLE * 2.0)
	assert_eq(director.variant, &"greece")


func test_outside_the_walk_the_variant_switches_at_once() -> void:
	_walking()
	director.on_combat(MusicDirector.HIT_HEAT)
	assert_eq(director.state, S.COMBAT)
	director.on_zone(&"americas")
	assert_eq(director.variant, &"americas", "the walk that comes back after the fight is the new wing's")


func test_the_zone_survives_a_mode_change_until_forgotten() -> void:
	director.set_mode(AudioContext.GAME)
	director.on_zone(&"asia")
	director.set_mode(AudioContext.GAME)
	assert_eq(director.variant, &"asia")
	director.forget_zone()
	assert_eq(director.variant, &"")
	assert_eq(director.zone, &"")


func test_a_guardian_brings_its_theme_and_its_hi_stem_from_phase_two() -> void:
	_walking()
	director.on_zone(&"court")
	director.on_guardian_awakened(&"lamassu")
	assert_eq(director.state, S.GUARDIAN)
	assert_eq(director.guardian_wing, &"assyria")
	var targets := director.layer_targets()
	assert_eq(targets[&"guardian"], 1.0)
	assert_eq(targets[&"guardian_hi"], 0.0, "phase 1 calm: base only")
	assert_eq(targets[&"explore"], 0.0)
	director.on_guardian_phase(2)
	assert_eq(director.layer_targets()[&"guardian_hi"], 1.0)
	director.on_combat(MusicDirector.HIT_HEAT)
	assert_eq(director.state, S.GUARDIAN, "hits keep the guardian's theme, not the combat track")


func test_a_hot_fight_brings_the_hi_stem_in_phase_one() -> void:
	_walking()
	director.on_guardian_awakened(&"samurai")
	for i in 8:
		director.on_combat(MusicDirector.KILL_HEAT)
	assert_gt(director.layer_targets()[&"guardian_hi"], 0.5)


func test_a_guardian_falls_with_its_sting_then_the_walk_returns() -> void:
	_walking()
	director.on_zone(&"egypt")
	_run(MusicDirector.VARIANT_SETTLE + 0.5)
	director.on_guardian_awakened(&"colossus")
	director.on_guardian_defeated(&"colossus")
	assert_eq(director.state, S.VICTORY)
	assert_eq(director.victory_sting, MusicDirector.GUARDIAN_STING)
	_run(MusicDirector.GUARDIAN_VICTORY_TIME + 0.2)
	assert_eq(director.state, S.EXPLORE, "back to the walk")
	assert_eq(director.variant, &"egypt", "in the guardian's wing")


func test_another_guardians_fall_is_ignored() -> void:
	_walking()
	director.on_guardian_awakened(&"centaur")
	director.on_guardian_defeated(&"serpent")
	assert_eq(director.state, S.GUARDIAN)
	director.on_guardian_gone()
	assert_eq(director.state, S.EXPLORE, "removed undefeated: no sting")


func test_the_t_rex_beats_a_guardian_and_keeps_its_own_sting() -> void:
	_walking()
	director.on_guardian_awakened(&"orrery")
	director.on_boss_awakened()
	assert_eq(director.state, S.BOSS)
	director.on_boss_defeated()
	assert_eq(director.victory_sting, MusicDirector.BOSS_STING)


func test_no_guardian_theme_for_the_dead() -> void:
	_walking()
	director.on_player_died()
	director.on_guardian_awakened(&"serpent")
	assert_false(director.guardian_active)
	assert_eq(director.state, S.SILENT)


func test_a_wing_met_for_the_first_time_asks_for_its_sting_once() -> void:
	_walking()
	assert_eq(director.on_room_entered(&"egypt", true), &"wing_sting_egypt")
	assert_eq(director.on_room_entered(&"egypt", true), &"", "only the first room")
	assert_eq(director.on_room_entered(&"court", true), &"", "the court is no wing")
	assert_eq(director.on_room_entered(&"greece", false), &"", "known from an earlier night")
	assert_eq(director.on_room_entered(&"greece", true), &"", "and stays known")


func test_no_wing_sting_in_a_fight_but_the_wing_counts_as_met() -> void:
	_walking()
	director.on_combat(MusicDirector.HIT_HEAT)
	assert_eq(director.on_room_entered(&"asia", true), &"")
	_run(MusicDirector.COMBAT_HOLD + MusicDirector.TENSION_HOLD + 1.0)
	assert_eq(director.on_room_entered(&"asia", true), &"")


func test_wings_remembered_from_a_save_get_no_sting() -> void:
	_walking()
	director.remember_wings([&"americas", "enlightenment"])
	assert_eq(director.on_room_entered(&"americas", true), &"")
	assert_eq(director.on_room_entered(&"enlightenment_clocks", true), &"")
	assert_eq(director.on_room_entered(&"asia", true), &"wing_sting_asia")
