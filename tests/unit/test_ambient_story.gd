extends TestCase
## The ambient story's scheduler as pure logic (plan
## 2026-10-21-akustyka-ambient, data/audio/ambient_story.json): how often by
## the night's phase, what may play where and when, the windows of
## deliberate silence (havens, sleeping guardians, dead air, after a line of
## the voice) and its determinism.

const MINUTES := 60.0
const STEP := 0.25


func _story(zone: StringName, phase: int, night: int = 3, data: Dictionary = {}) -> AmbientStory:
	var story := AmbientStory.new(data)
	story.start_night(night, &"none", 1234)
	story.zone = zone
	story.phase = phase
	return story


## Runs [param story] for [param seconds]; returns [[time, id], ...].
func _run(story: AmbientStory, seconds: float) -> Array:
	var played := []
	var t := 0.0
	while t < seconds:
		var due := story.advance(STEP)
		if not due.is_empty():
			played.append([t, String(due["id"])])
		t += STEP
	return played


func test_the_night_gets_busier_phase_by_phase() -> void:
	var calm := _run(_story(&"egypt", AmbientStory.CALM), 30.0 * MINUTES).size()
	var uneasy := _run(_story(&"egypt", AmbientStory.UNEASY), 30.0 * MINUTES).size()
	var predawn := _run(_story(&"egypt", AmbientStory.PREDAWN), 30.0 * MINUTES).size()
	var gaps: Array = AmbientStory.data()["gaps"]
	assert_gt(calm, 30.0 * MINUTES / float(gaps[0][1]) - 4.0, "calm: sparse but alive (%d)" % calm)
	assert_lt(calm, 30.0 * MINUTES / float(gaps[0][0]) + 4.0, "calm: never busy (%d)" % calm)
	assert_gt(uneasy, calm, "1:00-3:00 stirs more (%d > %d)" % [uneasy, calm])
	assert_gt(predawn, calm * 1.4, "before dawn the museum is restless (%d)" % predawn)


func test_the_first_night_is_sparser() -> void:
	var first := _run(_story(&"court", AmbientStory.CALM, 1), 30.0 * MINUTES).size()
	var third := _run(_story(&"court", AmbientStory.CALM, 3), 30.0 * MINUTES).size()
	assert_lt(first, third, "night 1 learns the building (%d < %d)" % [first, third])


func test_a_story_never_plays_again_within_its_cooldown_nor_past_its_nightly_limit() -> void:
	var story := _story(&"egypt", AmbientStory.WITCHING)
	var played := _run(story, 40.0 * MINUTES)
	var last := {}
	var counts := {}
	for entry: Array in played:
		var id: String = entry[1]
		var spec := story.story(StringName(id))
		if last.has(id):
			assert_gt(float(entry[0]) - float(last[id]) + 0.001, float(spec.get("cooldown", 0.0)), "%s waits its cooldown" % id)
		last[id] = entry[0]
		counts[id] = int(counts.get(id, 0)) + 1
	for id: String in counts:
		var limit := int(story.story(StringName(id)).get("per_night", 0))
		if limit > 0:
			assert_true(int(counts[id]) <= limit, "%s at most %d a night" % [id, limit])
	assert_true(counts.has("whispers"), "Egypt whispers in the witching hour")


func test_stories_keep_to_their_zones_phases_and_nights() -> void:
	for entry: Array in _run(_story(&"egypt", AmbientStory.CALM), 30.0 * MINUTES):
		assert_ne(entry[1], "whispers", "no whispers before 1:00")
		assert_ne(entry[1], "phantom_steps")
		assert_ne(entry[1], "clock_chime", "no clocks in Egypt")
	for entry: Array in _run(_story(&"egypt", AmbientStory.WITCHING, 1), 30.0 * MINUTES):
		assert_ne(entry[1], "whispers", "not on the first night")
	var tomb := _run(_story(&"egypt_tomb", AmbientStory.WITCHING), 30.0 * MINUTES)
	assert_true(tomb.any(func(e: Array) -> bool: return e[1] == "whispers"), "a sub-zone belongs to its zone")
	for entry: Array in _run(_story(&"roof", AmbientStory.CALM), 30.0 * MINUTES):
		assert_ne(entry[1], "settle", "the roof has no ceiling to settle")
		assert_ne(entry[1], "thunder", "no thunder on a dry night")


func test_thunder_on_rainy_nights_and_no_fans_without_power() -> void:
	var story := _story(&"court", AmbientStory.CALM)
	story.raining = true
	assert_true(_run(story, 30.0 * MINUTES).any(func(e: Array) -> bool: return e[1] == "thunder"))
	var dark := _story(&"basement", AmbientStory.CALM)
	dark.dark = true
	for entry: Array in _run(dark, 30.0 * MINUTES):
		assert_ne(entry[1], "vent_surge", "the fans need power")


func test_a_haven_hears_only_its_radio() -> void:
	var story := _story(&"booth", AmbientStory.UNEASY)
	story.in_haven = true
	assert_true(story.silent(), "no distant sounds in a haven")
	assert_almost_eq(story.bed_dip_db(), float(AmbientStory.data()["silence"]["haven_beds_db"]), 0.001)
	var played := _run(story, 20.0 * MINUTES)
	assert_gt(played.size(), 0, "the radio on the desk")
	for entry: Array in played:
		assert_eq(entry[1], "radio")


func test_silence_before_a_sleeping_guardian() -> void:
	var story := _story(&"assyria", AmbientStory.WITCHING)
	story.guardian = AmbientStory.GUARDIAN_NEAR
	assert_true(story.silent())
	assert_almost_eq(story.bed_dip_db(), float(AmbientStory.data()["silence"]["guardian_near_beds_db"]), 0.001)
	assert_eq(_run(story, 10.0 * MINUTES).size(), 0, "next to its arena nothing plays")
	story.guardian = AmbientStory.GUARDIAN_ARENA
	assert_almost_eq(story.bed_dip_db(), float(AmbientStory.data()["silence"]["guardian_arena_beds_db"]), 0.001)
	assert_lt(story.bed_dip_db(), float(AmbientStory.data()["silence"]["guardian_near_beds_db"]), "deeper in the arena")
	assert_eq(_run(story, 10.0 * MINUTES).size(), 0)
	story.guardian = AmbientStory.GUARDIAN_NONE
	assert_false(story.silent())
	assert_eq(story.bed_dip_db(), 0.0)


func test_no_story_in_a_fight() -> void:
	var story := _story(&"greece", AmbientStory.PREDAWN)
	story.fighting = true
	assert_eq(_run(story, 10.0 * MINUTES).size(), 0)
	assert_false(story.silent(), "a fight is loud enough: the far sounds of the zone may go on")


func test_the_voice_holds_everything_and_a_little_after() -> void:
	var story := _story(&"egypt", AmbientStory.PREDAWN)
	story.voice = true
	assert_true(story.silent(), "nothing starts under a line")
	assert_eq(_run(story, 5.0 * MINUTES).size(), 0)
	story.voice = false
	story.advance(STEP)
	assert_true(story.silent(), "and a breath after it")
	var after := float(AmbientStory.data()["voice_after"])
	for i in int(after / STEP) + 1:
		story.advance(STEP)
	assert_false(story.silent())


func test_a_hush_keeps_the_story_quiet() -> void:
	var story := _story(&"court", AmbientStory.PREDAWN)
	story.hush(25.0)
	assert_true(story.silent())
	assert_eq(_run(story, 24.0).size(), 0)
	assert_true(story.silent())
	_run(story, 1.25)
	assert_false(story.silent(), "over after 25 s")


func test_dead_air_then_something_walks_next_door() -> void:
	var data := AmbientStory.data().duplicate(true)
	data["dead_air"]["chance"] = 1.0
	var story := _story(&"north_hall", AmbientStory.UNEASY, 3, data)
	var t := 0.0
	var dipped := false
	var first := {}
	while t < 10.0 * MINUTES and first.is_empty():
		first = story.advance(STEP)
		if story.bed_dip_db() <= float(data["dead_air"]["beds_db"]) + 0.001:
			dipped = true
			assert_true(story.silent(), "the building holds its breath")
		t += STEP
	assert_true(dipped, "a dead air came first")
	assert_false(first.is_empty())
	assert_eq(first.get("id"), &"phantom_steps", "...and the silence broke with steps")
	assert_eq(story.bed_dip_db(), 0.0)


func test_the_same_seed_tells_the_same_night() -> void:
	var a := _run(_story(&"enlightenment", AmbientStory.WITCHING), 20.0 * MINUTES)
	var b := _run(_story(&"enlightenment", AmbientStory.WITCHING), 20.0 * MINUTES)
	assert_eq(a, b)
	assert_true(a.any(func(e: Array) -> bool: return e[1] == "clock_wind" or e[1] == "clock_chime"), "clocks in the Enlightenment")


func test_rain_falls_on_some_nights() -> void:
	var rainy := 0
	for seed in 400:
		if AmbientStory.rain_tonight(3, &"none", seed):
			rainy += 1
		assert_false(AmbientStory.rain_tonight(1, &"none", seed), "never the first night")
		assert_false(AmbientStory.rain_tonight(3, &"blackout", seed), "a blackout night is dry")
	var chance := float(AmbientStory.data()["rain"]["chance"])
	assert_almost_eq(rainy / 400.0, chance, 0.08)
	assert_eq(AmbientStory.rain_tonight(4, &"none", 77), AmbientStory.rain_tonight(4, &"none", 77), "decided once per night")


func test_zones_match_their_sub_zones() -> void:
	assert_true(AmbientStory.zone_in(&"egypt_tomb", ["egypt"]))
	assert_true(AmbientStory.zone_in(&"egypt", ["egypt"]))
	assert_false(AmbientStory.zone_in(&"egyptian", ["egypt"]))
	assert_false(AmbientStory.zone_in(&"court", ["egypt"]))
	assert_true(AmbientStory.zone_in(&"court", []), "no list: everywhere")
