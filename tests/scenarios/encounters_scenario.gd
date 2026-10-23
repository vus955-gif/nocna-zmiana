extends Node
## The three gold rooms' fight scenarios (plan 2026-10-22-projekt-starc)
## played live in the dressed Floor I: the guard (who cannot die here)
## walks into each room on a night that casts every beat, the scenario
## plays by itself, and the guard's view is shot at its beats. Not part of
## the headless suite.
##   bash tools/agents/with_window.sh bash tools/run_encounters.sh shots
##       1600x900 window -> tests/_out/encounters/<room>_<moment>.png
##   bash tools/run_encounters.sh dry
##       headless: the same walk without shots (the beats must play)
## Silent (Dummy audio).

const OUT_DIR := "res://tests/_out/encounters/"
const WATCHDOG_SECONDS := 480.0
const NIGHT := 2
## room -> [the guard's place, what he looks at, [[seconds in, moment, look at]...]]
const VISITS := {
	&"greece_nereid": [Vector3(-66.5, 0.05, 12.0), Vector3(-80.0, 4.0, 12.0),
		[[1.2, "contact", Vector3(-77.0, 1.2, 12.0)], [6.6, "porch", Vector3(-81.0, 5.8, 12.0)], [15.4, "flank", Vector3(-72.0, 1.2, 26.0)]]],
	&"assyria_nimrud": [Vector3(-77.0, 0.05, -44.0), Vector3(-98.0, 1.5, -44.0),
		[[1.2, "contact", Vector3(-98.0, 1.5, -44.0)], [8.4, "behind", Vector3(-66.0, 1.2, -44.0)]]],
	&"asia_armor": [Vector3(38.0, 0.05, -64.5), Vector3(40.5, 3.0, -74.0),
		[[1.2, "contact", Vector3(36.0, 1.2, -70.0)], [7.4, "bell", Vector3(40.5, 4.0, -74.0)], [17.0, "vault", Vector3(47.5, 1.2, -81.0)]]],
}

var museum: Museum
var _mode := "shots"
var _played: Array = []
var _failures := 0


func _ready() -> void:
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(_on_watchdog)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
	Museum.level_id = &"floor1"
	MuseumFloorLevel.dress_default = true
	GameInput.capture_allowed = false
	if _mode != "dry":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1600, 900))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ignore := FileAccess.open(ProjectSettings.globalize_path("res://tests/_out/.gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	for room: StringName in VISITS:
		await _visit(room)
	print("encounters: %d beats played, %d problems" % [_played.size(), _failures])
	Sfx.quit_cleanly(1 if _failures > 0 else 0)


func _on_watchdog() -> void:
	print("MISSED: the encounters walk did not finish in time")
	Sfx.quit_cleanly(1)


## The first seed whose night NIGHT casts every beat of [param id].
func _seed_for(id: StringName) -> int:
	var layout := Floor1Layout.create()
	var catalog := ScenarioCatalog.active()
	var spec := catalog.find(id)
	for night_seed in range(1, 400):
		GameState.new_game()
		GameState.seed_base = night_seed
		GameState.night = NIGHT
		var cast := ScenarioCast.plan(FloorNight.plan(GameState, layout), layout, catalog)
		var beats: Array = spec["beats"]
		var full := true
		for b in beats.size():
			var slots := cast.slots_of(id, b)
			if slots.is_empty() or (beats[b]["from"] != &"" and not cast.staged.has(slots[0])):
				full = false
		if full:
			return night_seed
	return 1


func _visit(room: StringName) -> void:
	var visit: Array = VISITS[room]
	GameState.new_game()
	GameState.seed_base = _seed_for(room)
	GameState.night = NIGHT
	RunState.reset()
	if is_instance_valid(museum):
		museum.free()
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	museum.player.health.max_health = 1000000.0
	museum.player.health.heal(1000000.0)
	museum.hud.visible = false
	museum.player.weapons.visible = false
	museum.player.set_flashlight(true)   # as a guard walks these dark rooms
	museum.floor_game.scenarios.beat_played.connect(func(id: StringName, beat: StringName) -> void:
		_played.append([id, beat])
		print("  %s: %s at %.1f s" % [id, beat, _clock]))
	await _frames(4)
	_look(visit[0], visit[1])
	_clock = 0.0
	for moment: Array in visit[2]:
		while _clock < float(moment[0]):
			museum.player.health.heal(1000000.0)
			_look(visit[0], moment[2])
			await get_tree().process_frame
			_clock += get_process_delta_time()
		if _mode != "dry":
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			var path := OUT_DIR.path_join("%s_%s.png" % [room, moment[1]])
			image.save_png(path)
			print("saved %s" % ProjectSettings.globalize_path(path))
	var beats: Array = ScenarioCatalog.active().find(room)["beats"]
	var got := _played.filter(func(p: Array) -> bool: return p[0] == room).size()
	# the Nimrud's last beat waits for the fuse: not taken on this walk
	var wanted := beats.size() - (1 if room == &"assyria_nimrud" else 0)
	if got < wanted:
		print("PROBLEM: %s played %d of %d beats" % [room, got, wanted])
		_failures += 1


var _clock := 0.0


## The guard at [param from] (on the floor) looking at [param at].
func _look(from: Vector3, at: Vector3) -> void:
	museum.player.global_position = from
	museum.player.velocity = Vector3.ZERO
	var eye := from + Vector3.UP * museum.player.eye_height
	var aim := at - eye
	museum.player.head.rotation = Vector3(atan2(aim.y, Vector2(aim.x, aim.z).length()), atan2(-aim.x, -aim.z), 0.0)
	museum.player.camera.current = true


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
