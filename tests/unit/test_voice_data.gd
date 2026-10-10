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
	assert_eq(catalog.keys_for_event(&"night_started"), [&"VO_HENIEK_NIGHT_1", &"VO_SYSTEM_CLOSING_1"] as Array[StringName])


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
		assert_almost_eq(float(entry.get("seconds", 0.0)), catalog.stream(key).get_length(), 0.05, key + ": manifest length")
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
