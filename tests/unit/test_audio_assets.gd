extends TestCase
## The generated music, ambience and foley: music and ambience are Ogg
## Vorbis (loops marked loop=true from 0, exact lengths, stems of a family
## equally long, a click-free and sample-exact wrap through the engine's own
## decoder), one-shots and stings do not loop, footsteps are mono WAVs.

const RATE := 44100
## Frame count of every music loop (bars x beats x samples per beat); the
## wings' walks and the guardians' theme are added in _frames().
const MUSIC_FRAMES := {&"menu": 5733000, &"explore": 5644800, &"explore_tension": 5644800, &"combat": 4838400,
	&"combat_hi": 4838400, &"boss": 5644800, &"boss_hi": 5644800}
## Floor I: a music zone's loop (its four stems: walk, tension, fight, hi;
## 96 s, Asia's 100 s) and each wing's guardian theme (in the wing's tempo,
## whole seconds: lengths the engine reports exactly).
const ZONE_FRAMES := {&"court": 4233600, &"egypt": 4233600, &"assyria": 4233600, &"greece": 4233600,
	&"enlightenment": 4233600, &"asia": 4410000, &"americas": 4233600, &"basement": 4233600, &"roof": 4233600}
const GUARDIAN_FRAMES := {&"egypt": 2822400, &"assyria": 2822400, &"greece": 2822400, &"enlightenment": 3175200,
	&"asia": 2646000, &"americas": 3175200}
const BED_FRAMES := 1764000
## Seconds decoded on each side of a loop's wrap.
const AROUND := 0.25


func _ogg(path: String) -> AudioStreamOggVorbis:
	assert_true(ResourceLoader.exists(path), "missing " + path)
	return load(path) as AudioStreamOggVorbis if ResourceLoader.exists(path) else null


func _check_loop(path: String, frames: int) -> void:
	var stream := _ogg(path)
	if stream == null:
		return
	assert_true(stream.loop, path + " loops")
	assert_eq(stream.loop_offset, 0.0, path + " loops from the start")
	assert_eq(int(round(stream.get_length() * RATE)), frames, path + " keeps every frame (no encoder padding)")
	_check_wrap(stream, path)


## Decodes across the loop point the way the game plays it: after the wrap
## the samples must equal a fresh decode from the start (the first two
## carry the resampler's history across the seam), and the step over the
## seam must not stand out from the loop's own steps (no click).
func _check_wrap(stream: AudioStreamOggVorbis, path: String) -> void:
	var span := int(AROUND * RATE)
	var wrap := stream.instantiate_playback()
	wrap.start(stream.get_length() - AROUND)
	var across := wrap.mix_audio(1.0, span * 2)
	wrap.stop()
	var fresh := stream.instantiate_playback()
	fresh.start(0.0)
	var start := fresh.mix_audio(1.0, span)
	fresh.stop()
	var worst := 0.0
	for i in range(4, span):
		worst = maxf(worst, maxf(absf(across[span + i].x - start[i].x), absf(across[span + i].y - start[i].y)))
	assert_lt(worst, 0.0001, "%s restarts sample-exactly after the wrap" % path)
	var steps: PackedFloat32Array = []
	for i in range(1, across.size()):
		steps.append(maxf(absf(across[i].x - across[i - 1].x), absf(across[i].y - across[i - 1].y)))
	var seam := 0.0
	for i in range(span - 2, span + 3):
		seam = maxf(seam, steps[i - 1])
	var sorted := steps.duplicate()
	sorted.sort()
	var typical := sorted[int(sorted.size() * 0.999)]
	assert_true(seam <= maxf(typical * 1.5, 0.002), "%s: step over the seam %.4f vs %.4f in the loop" % [path, seam, typical])


## Every looping track and its frame count.
func _frames() -> Dictionary:
	var frames := MUSIC_FRAMES.duplicate()
	for zone: StringName in ZONE_FRAMES:
		for layer in MusicDirector.ZONE_LAYERS:
			frames[Music.track(layer, zone)] = ZONE_FRAMES[zone]
	for wing: StringName in GUARDIAN_FRAMES:
		frames[Music.track(&"guardian", wing)] = GUARDIAN_FRAMES[wing]
		frames[Music.track(&"guardian_hi", wing)] = GUARDIAN_FRAMES[wing]
	return frames


func test_music_loops_are_marked_and_seamless() -> void:
	var frames := _frames()
	for layer: StringName in frames:
		_check_loop("res://assets/music/%s.ogg" % layer, frames[layer])


func test_every_music_track_is_known_to_the_test() -> void:
	var frames := _frames()
	for family: StringName in Music.FAMILIES:
		for layer: StringName in Music.FAMILIES[family]:
			assert_true(frames.has(layer), String(layer))
	for zone in MusicDirector.MUSIC_ZONES:
		assert_true(ZONE_FRAMES.has(zone), String(zone))
	for wing in MusicDirector.WINGS:
		assert_true(GUARDIAN_FRAMES.has(wing), String(wing))


func test_stems_of_a_family_have_the_same_length() -> void:
	for family: StringName in Music.FAMILIES:
		var layers: Array = Music.FAMILIES[family]
		var first := _ogg("res://assets/music/%s.ogg" % layers[0])
		for layer: StringName in layers:
			var other := _ogg("res://assets/music/%s.ogg" % layer)
			if first != null and other != null:
				assert_eq(int(round(other.get_length() * RATE)), int(round(first.get_length() * RATE)),
					"%s in sync with %s" % [layer, layers[0]])


func test_stings_play_once() -> void:
	for sting in Music.STINGS:
		var stream := _ogg("res://assets/music/%s.ogg" % sting)
		if stream != null:
			assert_false(stream.loop, String(sting) + " does not loop")
			assert_lt(stream.get_length(), 10.0)


func test_ambience_beds_loop_and_one_shots_do_not() -> void:
	for layer in Ambience.LAYERS:
		_check_loop("res://assets/ambience/bed_%s.ogg" % layer, BED_FRAMES)
	for kind: StringName in Ambience.SHOTS:
		for n in range(1, int(Ambience.SHOTS[kind]) + 1):
			var stream := _ogg("res://assets/ambience/oneshots/shot_%s_%d.ogg" % [kind, n])
			if stream != null:
				assert_false(stream.loop, "one-shots play once")


func test_every_zone_layer_and_shot_kind_exists() -> void:
	for zone: StringName in Ambience.ZONES:
		for layer: StringName in Ambience.ZONES[zone]:
			assert_true(Ambience.LAYERS.has(layer), "%s uses unknown layer %s" % [zone, layer])
		for kind: StringName in Ambience.ZONE_SHOTS.get(zone, {}):
			assert_true(Ambience.SHOTS.has(kind), "%s uses unknown shot %s" % [zone, kind])
	for room: StringName in Ambience.ROOM_ZONES:
		assert_true(Ambience.ZONES.has(Ambience.ROOM_ZONES[room]), "room %s maps to a zone" % room)


## zlib's CRC-32 of [param text] (what tools/music/ogg_serial.py uses).
static func _crc32(text: String) -> int:
	var crc := 0xFFFFFFFF
	for byte in text.to_utf8_buffer():
		crc ^= byte
		for i in 8:
			crc = (crc >> 1) ^ (0xEDB88320 if crc & 1 else 0)
	return crc ^ 0xFFFFFFFF


func test_every_ogg_has_its_fixed_stream_serial() -> void:
	var files: PackedStringArray = []
	for dir_path in ["res://assets/music", "res://assets/ambience", "res://assets/ambience/oneshots", "res://assets/ambience/tails",
			"res://assets/voice/heniek", "res://assets/voice/system"]:
		for file in DirAccess.get_files_at(dir_path):
			if file.ends_with(".ogg"):
				files.append(dir_path.path_join(file))
	assert_gt(files.size(), 30, "the scan finds the music and the ambience")
	for path in files:
		var data := FileAccess.get_file_as_bytes(path)
		var wanted := _crc32(path.trim_prefix("res://assets/"))
		var at := 0
		var pages := 0
		var same := true
		while at + 27 <= data.size() and data.slice(at, at + 4).get_string_from_ascii() == "OggS":
			same = same and data.decode_u32(at + 14) == wanted
			var segments := data[at + 26]
			var body := 0
			for i in segments:
				body += data[at + 27 + i]
			at += 27 + segments + body
			pages += 1
		assert_eq(at, data.size(), path + " is whole Ogg pages")
		assert_true(pages > 0 and same, "%s: serial of its name (tools/music/ogg_serial.py)" % path)


func test_every_footstep_set_has_several_takes() -> void:
	var sets: Array[StringName] = [&"jump", &"gear"]
	for surface in Surface.ALL:
		sets.append(StringName("step_" + String(surface)))
		sets.append(StringName("land_" + String(surface)))
	for profile: StringName in Footsteps.PROFILES:
		var data: Dictionary = Footsteps.PROFILES[profile]
		for key in ["set", "soft_set"]:
			if data.has(key):
				sets.append(data[key])
	for set_name in sets:
		var takes := Footsteps.takes_of(set_name)
		assert_true(takes.size() >= 2, "%s has %d takes" % [set_name, takes.size()])
		for take in takes:
			var wav := take as AudioStreamWAV
			if wav != null:
				assert_false(wav.stereo, String(set_name) + " is mono")
				assert_ne(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD)
