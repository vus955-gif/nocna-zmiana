class_name VoiceCatalog
extends RefCounted
## Voice lines as data: data/voice/lines.json (who says it, when) and
## data/voice/speakers.json (which Kokoro voice); the text itself is in
## locale/strings.csv under the same key. Recordings: assets/voice/<speaker>/<key>.ogg
## (tools/tts/build_voice.sh). Spec: docs/superpowers/specs/2026-10-08-glos-projekt.md.

const LINES_PATH := "res://data/voice/lines.json"
const SPEAKERS_PATH := "res://data/voice/speakers.json"
const AUDIO_DIR := "res://assets/voice"
## Events the rules may name: Events signals plus the director's own.
const PSEUDO_EVENTS: Array[StringName] = [&"death", &"destroyed", &"stall", &"night_time"]
const EVENTS: Array[StringName] = [&"night_started", &"power_cut", &"witching_hour", &"dawn_broke",
		&"room_entered", &"guardian_awakened", &"guardian_defeated", &"shard_collected", &"seal_collected",
		&"gate_opened", &"boss_awakened", &"boss_defeated", &"death", &"destroyed", &"stall", &"night_time"]
## Every field a rule may have (test_voice_data rejects the rest).
const RULE_FIELDS: Array[String] = ["speaker", "event", "night", "night_min", "zone", "guardian", "count", "goal",
		"at", "delay", "priority", "once", "level", "speed", "station", "variant", "after_guardian", "after_witching"]

var lines: Dictionary = {}      ## String key -> Dictionary (the rule)
var speakers: Dictionary = {}   ## String speaker -> {voice, speed}
var fx_version := 1
## Lines were added after loading (tests): VoiceDirector.reset() reloads the data then.
var modified := false

var _by_event: Dictionary = {}  ## event -> Array[StringName], built on first use


static func load_default() -> VoiceCatalog:
	var catalog := VoiceCatalog.new()
	catalog.lines = _read(LINES_PATH).get("lines", {})
	var data := _read(SPEAKERS_PATH)
	catalog.speakers = data.get("speakers", {})
	catalog.fx_version = int(data.get("fx_version", 1))
	return catalog


static func _read(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


## SHA-256 of "<voice>|<speed:.3f>|<level>|<fx_version>|<text>" — the same as
## tools/tts/voice_data.py line_hash().
static func hash_of(voice: String, speed: float, level: int, version: int, text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(("%s|%.3f|%d|%d|%s" % [voice, speed, level, version, text]).to_utf8_buffer())
	return context.finish().hex_encode()


func line(key: StringName) -> Dictionary:
	return lines.get(String(key), {})


## Adds (or replaces) a rule at run time — for tests of rules the shipped
## data does not use yet.
func add_line(key: StringName, rule: Dictionary) -> void:
	lines[String(key)] = rule
	modified = true
	_by_event.clear()


func speaker_of(key: StringName) -> StringName:
	return StringName(line(key).get("speaker", ""))


## &"radio" (Heniek), &"guide" (an audio-guide stand) or &"pa" (the loudspeakers).
func channel_of(key: StringName) -> StringName:
	var rule := line(key)
	if rule.get("speaker", "") == "heniek":
		return &"radio"
	return &"guide" if rule.has("station") else &"pa"


func stream_path(key: StringName) -> String:
	return "%s/%s/%s.ogg" % [AUDIO_DIR, speaker_of(key), key]


func stream(key: StringName) -> AudioStream:
	var path := stream_path(key)
	return load(path) as AudioStream if ResourceLoader.exists(path) else null


## Keys of the lines listening to [param event], in file order (cached: the
## director asks every frame; do not modify the returned array).
func keys_for_event(event: StringName) -> Array[StringName]:
	if not _by_event.has(event):
		var out: Array[StringName] = []
		for key in lines:
			if StringName(lines[key].get("event", "")) == event:
				out.append(StringName(key))
		_by_event[event] = out
	return _by_event[event]


## The recording of [param station] in [param variant] (&"a" day, &"b" night), or &"".
func guide_key(station: StringName, variant: StringName) -> StringName:
	for key in lines:
		var rule: Dictionary = lines[key]
		if StringName(rule.get("station", "")) == station and StringName(rule.get("variant", "")) == variant:
			return StringName(key)
	return &""
