extends Node
## The Great Court's set-piece in the real game with the art (plan
## 2026-10-22-set-piece; not part of the headless suite): five wax figures
## asleep round the guard south of the drum at 1:30, the game started, four
## shots - from high over the entrance arch the warning, the first dark and the
## first light (they came closer), then the guard's own view turned round
## when the light is back after the one that reached him.
##   bash tools/agents/with_window.sh bash tools/run_set_piece.sh
##       silent 1920x1080 window -> tests/_out/set-piece/*.png
## Silent (Dummy audio). Only through the window lock.

const OUT_DIR := "res://tests/_out/set-piece/"
const WATCHDOG_SECONDS := 240.0
const SPOT := Vector3(0.0, 0.0, 16.5)
const FIGURES: Array[Vector3] = [Vector3(-24.0, 0.0, 18.0), Vector3(-19.0, 0.0, 25.0), Vector3(19.0, 0.0, 25.5),
	Vector3(25.0, 0.0, 17.0), Vector3(-11.0, 0.0, 27.0)]
## The view from high over the entrance arch down the south of the hall:
## the guard's spot, the figures round it, the drum beyond.
const HIGH_FROM := Vector3(0.0, 13.0, 29.5)
const HIGH_AT := Vector3(0.0, 0.0, 13.0)

var museum: Museum
var director: UncannyDirector
var camera: Camera3D
var _failures := 0


func _ready() -> void:
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(_on_watchdog)
	Museum.level_id = &"floor1"
	MuseumFloorLevel.dress_default = true
	GameInput.capture_allowed = false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Settings.set_value(&"graphics_quality", GraphicsQuality.Quality.HIGH, false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ignore := FileAccess.open(ProjectSettings.globalize_path("res://tests/_out/.gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.05
	camera.far = 300.0
	add_child(camera)
	await _open()
	await _play()
	Sfx.quit_cleanly(1 if _failures > 0 else 0)


func _on_watchdog() -> void:
	print("MISSED: the set-piece shots did not finish in time")
	Sfx.quit_cleanly(1)


func _open() -> void:
	GameState.new_game()
	GameState.seed_base = 7
	GameState.night = 2
	GameState.see_uncanny(&"court_eyes")
	RunState.reset()
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	museum.player.health.max_health = 1000000.0
	museum.player.health.heal(1000000.0)
	await _frames(2)
	director = museum.floor_game.uncanny
	director._next_ambient = INF
	for exhibit in museum.exhibits():
		exhibit.free()
	for at in FIGURES:
		var figure := WaxFigure.new()
		figure.position = at
		figure.target = museum.player
		museum.enemies_root.add_child(figure)
		figure.face(at + Vector3(0.0, 0.0, -1.0))
	museum.watch.clock.elapsed = 2.5 * NightClock.SECONDS_PER_HOUR
	# the guard waits in the entrance hall while the court's view warms up
	# (shaders, fog history, probes; the night's card gone), then walks in
	_stand(&"entrance_hall")
	camera.global_position = HIGH_FROM
	camera.look_at(HIGH_AT, Vector3.UP)
	camera.current = true
	await _seconds(6.0)
	museum.player.global_position = SPOT
	_look(Vector3(0.0, 1.6, -10.0))
	museum.floor_game.rooms.check()
	await _seconds(2.5)   # the room's card gone


func _stand(room: StringName) -> void:
	var at := UncannyRules.room_point(museum.floor_level.layout, room)
	museum.player.global_position = Vector3(at.x, at.y - 1.1, at.z)
	museum.floor_game.rooms.check()


## The guard looks at [param at] (his head; the body stays).
func _look(at: Vector3) -> void:
	var eye := museum.player.global_position + Vector3.UP * museum.player.eye_height
	var aim := at - eye
	museum.player.head.rotation = Vector3(atan2(aim.y, Vector2(aim.x, aim.z).length()), atan2(-aim.x, -aim.z), 0.0)


func _play() -> void:
	museum.player.weapons.visible = false
	if not director.fire_now(CourtGame.ID):
		print("MISSED: the game did not start")
		_failures += 1
		return
	var game := director.set_piece
	camera.global_position = HIGH_FROM
	camera.look_at(HIGH_AT, Vector3.UP)
	camera.current = true
	# 1. the warning: the lamps stutter, the thought on the HUD
	await _until(game, 0.6)
	await _capture("1_warning")
	museum.hud.visible = false
	# 2. the first dark: the lamps out, the moon and the red lamps left; they step
	await _until(game, CourtGame.WARN_TIME + 1.2)
	await _capture("2_first_dark")
	# 3. the first light: they stand closer, all looking at him
	await _until(game, CourtGame.WARN_TIME + CourtGame.DARK_TIME + 0.6)
	await _capture("3_first_light_closer")
	# 4. the light back after the one that reached him: he turns round
	while is_instance_valid(game) and not game.is_over() and game.winner == null:
		await get_tree().process_frame
	if not is_instance_valid(game) or game.winner == null:
		print("MISSED: nobody reached him")
		_failures += 1
		return
	var winner := game.winner
	while is_instance_valid(game) and not game.is_over() and _last_beat(game) != &"light":
		await get_tree().process_frame
	await _frames(8)
	museum.player.camera.current = true
	if is_instance_valid(winner):
		_look(winner.global_position + Vector3.UP * 1.5)
	await _frames(6)
	await _capture("4_right_behind_him")
	print("beats: %s" % [director.pieces[-1]["beats"] if not director.pieces.is_empty() else (game.beats if is_instance_valid(game) else [])])


func _last_beat(game: CourtGame) -> StringName:
	return game.beats[-1][0] if not game.beats.is_empty() else &""


## Waits until [param game] has played [param seconds].
func _until(game: CourtGame, seconds: float) -> void:
	while is_instance_valid(game) and not game.is_over() and game.time < seconds:
		museum.player.health.heal(1000000.0)
		await get_tree().process_frame


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OUT_DIR.path_join("%s.png" % label)
	image.save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))


func _seconds(time: float) -> void:
	await get_tree().create_timer(time, false).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
