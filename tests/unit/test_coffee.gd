extends TestCase
## The café's drinks (plan 2026-10-10-kawiarnia-zmeczenie, 2.2): the three
## kinds with the plan's numbers, what the machine pours by the night's state,
## the absurd labels of the machine gone haywire, and every text they need in
## both languages.


## What [param kind] does (Fatigue.COFFEES: relief, time, regen, block,
## jitter); {} for a drink the café does not serve.
func _facts(kind: StringName) -> Dictionary:
	return (Fatigue.COFFEES[kind] as Dictionary).duplicate() if Fatigue.COFFEES.has(kind) else {}


func test_the_three_kinds_carry_the_plans_numbers() -> void:
	var espresso := _facts(Coffee.ESPRESSO)
	assert_almost_eq(espresso["relief"], 0.30, 0.0001, "espresso: short and strong")
	assert_almost_eq(espresso["time"], 90.0, 0.0001)
	assert_almost_eq(espresso["regen"], 0.25, 0.0001)
	assert_false(espresso["block"])
	var large := _facts(Coffee.LARGE)
	assert_almost_eq(large["relief"], 0.15, 0.0001, "the large one: long and weak")
	assert_almost_eq(large["time"], 240.0, 0.0001)
	assert_almost_eq(large["regen"], 0.10, 0.0001)
	assert_true(large["block"], "the tiredness stands still while it lasts")
	var special := _facts(Coffee.SPECIAL)
	assert_almost_eq(special["relief"], 0.45, 0.0001)
	assert_almost_eq(special["time"], 60.0, 0.0001)
	assert_almost_eq(special["regen"], 0.40, 0.0001)
	assert_almost_eq(special["jitter"], 12.0, 0.0001, "twelve seconds of shaking hands")
	assert_eq(_facts(&"tea"), {}, "nothing else is served")


func test_the_machine_and_the_urn_ration_by_time() -> void:
	assert_eq(Coffee.MACHINE_WARMUP, 90.0)
	assert_eq(Coffee.URN_DRIP, 150.0)


func test_the_machine_pours_by_the_night() -> void:
	assert_eq(Coffee.machine_kind(false), Coffee.ESPRESSO)
	assert_eq(Coffee.machine_kind(true), Coffee.SPECIAL, "the machine pours what it likes")


func test_every_kind_the_counter_serves_is_one_the_guard_can_drink() -> void:
	var fatigue := Fatigue.new()
	for kind in Coffee.KINDS:
		assert_true(fatigue.drink(kind), String(kind))
	for kind in [Coffee.machine_kind(false), Coffee.machine_kind(true), Coffee.LARGE]:
		assert_true(Fatigue.COFFEES.has(kind), String(kind))


func test_the_absurd_labels_go_round() -> void:
	var seen: Dictionary = {}
	for i in Coffee.ABSURDS:
		seen[Coffee.absurd_label(i)] = true
	assert_eq(seen.size(), Coffee.ABSURDS, "five different labels")
	assert_eq(Coffee.absurd_label(Coffee.ABSURDS), Coffee.absurd_label(0), "then again")
	assert_eq(Coffee.absurd_label(-1), Coffee.absurd_label(Coffee.ABSURDS - 1), "no index breaks it")
	for i in Coffee.ABSURDS:
		assert_false(Coffee.absurd_label(i).begins_with("COFFEE_"), "translated: " + Coffee.absurd_label(i))


func test_every_text_exists_in_both_languages() -> void:
	for locale in ["pl", "en"]:
		TranslationServer.set_locale(locale)
		for key in Coffee.all_keys():
			assert_ne(TranslationServer.translate(key), key, "%s in %s" % [key, locale])
	TranslationServer.set_locale("pl")


func test_the_slate_changes_with_the_night() -> void:
	assert_eq(Coffee.slate_keys(false).size(), 3, "three chalk lines")
	assert_eq(Coffee.slate_keys(true).size(), 3)
	assert_ne(Coffee.slate_keys(false), Coffee.slate_keys(true))
