extends TestCase
## Every voice line has its text (PL + EN), its rule, its recording, and the
## recording is up to date (manifest hash = the hash of today's text and settings).

const MANIFEST := "res://assets/voice/manifest.json"
var catalog: VoiceCatalog
var texts: Dictionary = {}


func before_each() -> void:
	catalog = VoiceCatalog.load_default()
	texts = _csv()


func test_there_are_lines_and_speakers() -> void:
	assert_gt(catalog.lines.size(), 3)
	for speaker in [&"heniek", &"system"]:
		assert_true(catalog.speakers.has(String(speaker)), String(speaker))


func test_every_line_has_polish_and_english_text_on_one_row() -> void:
	for key in catalog.lines:
		assert_true(texts.has(key), key + " is in locale/strings.csv")
		if not texts.has(key):
			continue
		var pl: String = texts[key][0]
		var en: String = texts[key][1]
		assert_true(pl != "" and en != "", key)
		assert_false(pl.contains("\n") or en.contains("\n"), key + " is one row")
		assert_true(en.length() >= 20, key + ": Kokoro is weak on very short lines")


func test_every_rule_is_well_formed() -> void:
	for key in catalog.lines:
		var line: Dictionary = catalog.lines[key]
		assert_true(catalog.speakers.has(String(line.get("speaker", ""))), key + ": known speaker")
		if line.has("station"):
			assert_true(String(line.get("variant", "")) in ["a", "b"], key + ": variant a or b")
			continue
		var event := StringName(line.get("event", ""))
		assert_true(event in VoiceCatalog.EVENTS, "%s: event %s" % [key, event])
		if not event in VoiceCatalog.PSEUDO_EVENTS:
			assert_true(Events.has_signal(event), "%s: Events.%s exists" % [key, event])


func test_every_guide_station_has_a_day_recording() -> void:
	for key in catalog.lines:
		var line: Dictionary = catalog.lines[key]
		if line.has("station"):
			assert_ne(catalog.guide_key(StringName(line.station), &"a"), &"", String(line.station))


func test_the_channel_follows_the_speaker_and_the_station() -> void:
	assert_eq(catalog.channel_of(&"VO_HENIEK_NIGHT_1"), &"radio")
	assert_eq(catalog.channel_of(&"VO_SYSTEM_CLOSING_1"), &"pa")
	assert_eq(catalog.channel_of(&"VO_GUIDE_ROSETTA_A"), &"guide")
	var night := catalog.keys_for_event(&"night_started")
	assert_eq(night[0], &"VO_HENIEK_NIGHT_1", "Heniek opens the night (file order)")
	assert_true(night.has(&"VO_SYSTEM_CLOSING_1"))


func test_the_hash_matches_the_python_tools() -> void:
	# tools/tts/test_voice_data.py hashes the same string
	assert_eq(VoiceCatalog.hash_of("af_heart", 1.0, 0, 1, "Hello there, museum."),
			"af_heart|1.000|0|1|Hello there, museum.".sha256_text())


func test_every_line_has_an_up_to_date_recording() -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	assert_true(manifest is Dictionary, "assets/voice/manifest.json (bash tools/tts/build_voice.sh)")
	if not manifest is Dictionary:
		return
	for key in catalog.lines:
		var entry: Dictionary = manifest.get(key, {})
		var voice: Dictionary = catalog.speakers[String(catalog.lines[key].speaker)]
		var line: Dictionary = catalog.lines[key]
		var wanted := VoiceCatalog.hash_of(String(voice.voice), float(line.get("speed", voice.speed)),
				int(line.get("level", 0)), catalog.fx_version, texts.get(key, ["", ""])[1])
		assert_eq(entry.get("hash", ""), wanted, key + ": text or settings changed — run tools/tts/build_voice.sh")
		assert_true(ResourceLoader.exists(catalog.stream_path(key)), key + ": recording exists")
		var stream := catalog.stream(key)
		if stream != null:
			assert_almost_eq(float(entry.get("seconds", 0.0)), stream.get_length(), 0.05, key + ": manifest length")
	for key in manifest:
		assert_true(catalog.lines.has(key), key + ": manifest entry without a line")


func test_the_speaker_labels_exist() -> void:
	for key in ["VOICE_SPEAKER_HENIEK", "VOICE_SPEAKER_SYSTEM", "VOICE_SPEAKER_GUIDE"]:
		assert_true(texts.has(key), key)


## locale/strings.csv read raw (the same bytes the voice tools hash).
static func _csv() -> Dictionary:
	var out := {}
	var file := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() >= 3:
			out[row[0]] = [row[1], row[2]]
	return out


func test_rules_use_only_known_fields_in_range() -> void:
	for key in catalog.lines:
		var line: Dictionary = catalog.lines[key]
		for field in line:
			assert_true(field in VoiceCatalog.RULE_FIELDS, "%s: unknown rule field %s" % [key, field])
		assert_true(int(line.get("level", 0)) in [0, 1, 2], key + ": level 0-2")
		assert_true(int(line.get("priority", 1)) in [0, 1, 2], key + ": priority 0-2")
		if line.has("variant"):
			assert_true(line.has("station"), key + ": variant needs a station")


func test_the_cafe_events_are_known_and_a_rule_can_name_the_coffee() -> void:
	for event in [&"cafe_entered", &"coffee_drunk", &"cafe_haywire"]:
		assert_true(event in VoiceCatalog.EVENTS, "%s is an event rules may name" % event)
		assert_true(Events.has_signal(event), "Events.%s exists" % event)
	assert_true("kind" in VoiceCatalog.RULE_FIELDS)
	assert_true(VoiceRules.matches({"kind": "large"}, {"kind": &"large"}))
	assert_false(VoiceRules.matches({"kind": "large"}, {"kind": &"espresso"}))
	assert_false(VoiceRules.matches({"kind": "large"}, {}), "a payload without a kind fails a rule that asks for one")
	assert_true(VoiceRules.matches({}, {"kind": &"special"}), "a rule without a kind fits any cup")


func test_the_g2_events_and_fields_are_known() -> void:
	for event in [&"secret_found", &"fatigue_rose", &"hour_struck"]:
		assert_true(event in VoiceCatalog.EVENTS, "%s is an event rules may name" % event)
		assert_true(Events.has_signal(event), "Events.%s exists" % event)
	assert_true(&"idle" in VoiceCatalog.EVENTS and &"idle" in VoiceCatalog.PSEUDO_EVENTS, "the director's idle")
	for field in ["room", "gate", "modifier", "hour"]:
		assert_true(field in VoiceCatalog.RULE_FIELDS, field)
	assert_true(VoiceRules.matches({"hour": 4}, {"hour": 4}))
	assert_false(VoiceRules.matches({"hour": 0}, {}), "a payload without an hour fails a rule that asks for one")
	assert_false(VoiceRules.matches({"gate": "gate_north"}, {"gate": &"seal_khorsabad"}))
	assert_true(VoiceRules.matches({"room": "court_reading"}, {"room": &"court_reading", "zone": &"court"}))
	assert_false(VoiceRules.matches({"modifier": "calm"}, {"modifier": &"none"}))


# --- G2: the whole catalog (plan 2026-10-19-glos-g2-kwestie) ---------------------

const STOP_WORDS := ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"]
const STOP_ORDINALS := ["pierwsze", "drugie", "trzecie", "czwarte", "piąte", "szóste", "siódme", "ósme", "dziewiąte",
		"dziesiąte", "jedenaste", "dwunaste"]


func _guardian_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for guardian: Array in Floor1Plan.GUARDIANS:
		ids.append(guardian[0])
	return ids


func _gate_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for gate: Array in Floor1Plan.GATES:
		ids.append(gate[0])
	return ids


func test_every_rule_names_something_that_exists() -> void:
	var layout := Floor1Layout.create()
	var kinds := {"coffee_drunk": Fatigue.COFFEES.keys().map(func(k: StringName) -> String: return String(k)),
			"room_entered": ["haven"], "secret_found": ["small", "medium", "great"]}
	for key in catalog.lines:
		var rule: Dictionary = catalog.lines[key]
		if rule.has("zone"):
			assert_true(StringName(rule.zone) in Floor1Plan.ZONES, "%s: zone %s" % [key, rule.zone])
		for field in ["guardian", "after_guardian"]:
			if rule.has(field):
				assert_true(StringName(rule[field]) in _guardian_ids(), "%s: guardian %s" % [key, rule[field]])
		if rule.has("goal"):
			assert_true(texts.has(String(rule.goal)) and String(rule.goal).begins_with("GOAL_"), "%s: goal %s" % [key, rule.goal])
		if rule.has("gate"):
			assert_true(StringName(rule.gate) in _gate_ids(), "%s: gate %s" % [key, rule.gate])
		if rule.has("room"):
			assert_not_null(layout.room(StringName(rule.room)), "%s: room %s" % [key, rule.room])
		if rule.has("modifier"):
			assert_true(StringName(rule.modifier) in NightModifiers.MODIFIERS, "%s: modifier %s" % [key, rule.modifier])
		if rule.has("kind"):
			assert_true(String(rule.kind) in kinds.get(String(rule.get("event", "")), []), "%s: kind %s for %s" % [key, rule.kind, rule.get("event", "")])
		if rule.has("hour"):
			assert_true(int(rule.hour) in [0, 1, 2, 4, 5], "%s: an hour with no event of its own" % key)


func test_every_stop_has_a_day_and_a_night_recording_a_stand_and_its_number() -> void:
	var layout := Floor1Layout.create()
	var stations: Array[StringName] = []
	for key in catalog.lines:
		if catalog.lines[key].has("station") and not StringName(catalog.lines[key].station) in stations:
			stations.append(StringName(catalog.lines[key].station))
	assert_eq(stations.size(), AudioguideStand.STOPS.size(), "every stop of the tour is voiced")
	for station in stations:
		assert_true(layout.markers.has(StringName("audioguide_" + station)), "%s has a stand on Floor I" % station)
		assert_true(AudioguideStand.STOPS.has(station), "%s has a stop number" % station)
		var stop := int(AudioguideStand.STOPS.get(station, 0))
		for variant in [&"a", &"b"]:
			var key := String(catalog.guide_key(station, variant))
			assert_ne(key, "", "%s has its %s recording" % [station, variant])
			if key == "" or stop < 1 or stop > STOP_WORDS.size():
				continue
			assert_true(texts[key][1].begins_with("Stop %s." % STOP_WORDS[stop - 1]), "%s says its stop number" % key)
			assert_true(texts[key][0].begins_with("Stanowisko %s." % STOP_ORDINALS[stop - 1]), "%s: napis z numerem" % key)
		var night: Dictionary = catalog.line(catalog.guide_key(station, &"b"))
		assert_true(night.has("after_guardian") or night.get("after_witching", false), "%s: when the night version plays" % station)
	for id: StringName in layout.markers:
		if String(id).begins_with("audioguide_"):
			assert_true(StringName(String(id).trim_prefix("audioguide_")) in stations, "the stand %s has recordings" % id)


func test_both_speakers_comment_a_death() -> void:
	for speaker in ["heniek", "system"]:
		var lines := catalog.keys_for_event(&"death").filter(func(k: StringName) -> bool: return String(catalog.speaker_of(k)) == speaker)
		assert_gt(lines.size(), 1, speaker + " has death comments")
		assert_false(catalog.line(lines[0]).has("night_min") and int(catalog.line(lines[0]).night_min) > 2, speaker + ": the first fits night 2")


func test_heniek_never_cuts_into_a_fight() -> void:
	# a priority-2 line waits for calm at most 10 s (VoiceQueue.EVENT_MAX_WAIT); Heniek waits for calm
	# except at the night's start and at dawn (both in a haven or with everything frozen)
	for key in catalog.lines:
		var rule: Dictionary = catalog.lines[key]
		if rule.get("speaker", "") == "heniek" and int(rule.get("priority", 1)) >= VoiceQueue.EVENT:
			assert_true(rule.get("event", "") in ["night_started", "dawn_broke"], "%s waits for calm" % key)


func test_a_dawn_line_fits_before_the_next_night() -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var dawn := catalog.keys_for_event(&"dawn_broke")
	assert_gt(dawn.size(), 1)
	for key in dawn:
		var seconds := float((manifest as Dictionary).get(String(key), {}).get("seconds", 99.0)) if manifest is Dictionary else 99.0
		assert_lt(seconds, VoiceDirector.DAWN_AIR, "%s: %.1f s" % [key, seconds])


func test_the_goal_hints_come_before_the_general_one() -> void:
	var stall := catalog.keys_for_event(&"stall")
	var general := stall.filter(func(k: StringName) -> bool: return not catalog.line(k).has("goal"))
	assert_eq(general.size(), 1, "one general hint")
	if general.size() == 1:
		assert_eq(stall.back(), general[0], "the general hint is the last resort")


func test_voice_texts_keep_the_text_rules() -> void:
	for key in catalog.lines:
		for text: String in texts.get(key, ["", ""]):
			assert_false(text.contains("\"") or text.contains("%"), key + ": no straight quotes, no percent sign")
