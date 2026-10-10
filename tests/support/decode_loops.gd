extends SceneTree
## Decodes every looping music and ambience file through the engine - the
## imported AudioStreamOggVorbis, its own playback and loop logic, exactly
## as the game plays it - around the loop point, and writes the samples to
## build/audio_src/decoded/ for tools/music/analyze.py --seams, which
## compares them with the WAV intermediates.
## Per loop: <name>_wrap.f32 (PRE s before the loop end, then POST s after
## the wrap), <name>_head.f32 (the first POST s from a plain start) and
## <name>.json (length in s and frames as the stream reports it).
## Usage (tools/build_audio.sh runs it):
##   tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --audio-driver Dummy --path . -s res://tests/support/decode_loops.gd

const OUT := "res://build/audio_src/decoded/"
const DIRS: Array[String] = ["res://assets/music/", "res://assets/ambience/"]
const RATE := 44100
const PRE := 1.0
const POST := 1.0


func _initialize() -> void:
	await process_frame
	var out := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(out)
	var count := 0
	for dir in DIRS:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".ogg"):
				continue
			var stream := load(dir + file) as AudioStreamOggVorbis
			if stream == null or not stream.loop:
				continue
			var name := file.get_basename()
			var wrap := stream.instantiate_playback()
			wrap.start(stream.get_length() - PRE)
			_store(out.path_join(name + "_wrap.f32"), wrap.mix_audio(1.0, int(round((PRE + POST) * RATE))))
			wrap.stop()
			var head := stream.instantiate_playback()
			head.start(0.0)
			_store(out.path_join(name + "_head.f32"), head.mix_audio(1.0, int(round(POST * RATE))))
			head.stop()
			var info := FileAccess.open(out.path_join(name + ".json"), FileAccess.WRITE)
			info.store_string(JSON.stringify({"length": stream.get_length(), "frames": stream.get_length() * RATE,
				"loop_offset": stream.loop_offset, "pre": PRE, "post": POST}))
			info.close()
			count += 1
	print("decoded %d loops into %s" % [count, out])
	quit()


func _store(path: String, frames: PackedVector2Array) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(frames.to_byte_array())
	file.close()
