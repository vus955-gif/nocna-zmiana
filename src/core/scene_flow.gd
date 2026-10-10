extends Node
## Scene changes with a short fade through black (autoload "SceneFlow").
## Before a swap it silences the game's sounds, clears effects, lets go of
## the cursor, closes every menu's hold on the input and unpauses, so each
## scene starts clean (the old scene and everything under it is freed by
## the engine). Quitting goes through Sfx.quit_cleanly() so no sound is
## left playing.
## One change at a time: while one runs ([member busy]) goto() and quit()
## refuse (false) and every input event is swallowed. A scene that cannot
## be loaded is reported and the old one stays (the fade comes back).
## Screens only swap scenes when they are the running scene; otherwise (in
## tests) they emit a signal of their own instead (see is_running()).
## A night (the museum) starts under the loading screen: the night's number
## and a tip while its heavy data is made (Museum.prepare_level: the shell
## read from its cache or carved), then the museum builds behind it.

signal changed(path: String)
## goto() could not load [param path]; the current scene stays.
signal failed(path: String)

const MAIN_MENU := "res://src/ui/main_menu.tscn"
const MUSEUM := "res://src/game/museum.tscn"
const SANDBOX := "res://src/arena/sandbox.tscn"
const DEMO_END := "res://src/ui/demo_end.tscn"
## Seconds of each half of the fade.
const FADE := 0.25

var busy: bool = false
var loading: LoadingScreen
var _black: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	_black = ColorRect.new()
	_black.color = Color(0.0, 0.0, 0.0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.modulate.a = 0.0
	layer.add_child(_black)
	loading = LoadingScreen.new()
	loading.name = "LoadingScreen"
	layer.add_child(loading)


func _input(_event: InputEvent) -> void:
	if busy:
		get_viewport().set_input_as_handled()


## Fades out, swaps to [param path], fades in. False (nothing happens) while
## another change runs or when [param path] is no scene.
func goto(path: String) -> bool:
	if busy:
		return false
	if not ResourceLoader.exists(path, "PackedScene"):
		push_warning("SceneFlow: no scene at " + path)
		return false
	_run_goto(path)
	return true


## Fades out and quits (sounds stopped cleanly first). False while another
## change runs.
func quit() -> bool:
	if busy:
		return false
	_run_quit()
	return true


## True when [param screen] is the scene the game runs (not one built by a
## test inside the test runner).
func is_running(screen: Node) -> bool:
	return screen != null and screen == get_tree().current_scene


## The fade overlay's opacity (0 = clear).
func fade_level() -> float:
	return _black.modulate.a


func _run_goto(path: String) -> void:
	_begin()
	await _fade(1.0)
	var night_start := path == MUSEUM
	if night_start:
		loading.open(GameState.night)
		await _prepare()
	var packed := load(path) as PackedScene
	var scene: Node = packed.instantiate() if packed != null else null
	if scene == null:
		push_warning("SceneFlow: could not load " + path)
		failed.emit(path)
		loading.close()
		await _fade(0.0)
		_end()
		return
	Sfx.stop_gameplay()
	Fx.clear()
	# the cursor first, so it does not flash captured between the menus
	GameInput.set_gameplay_scene(false)
	GameInput.clear_ui()
	get_tree().paused = false
	await _swap(scene)
	loading.close()
	changed.emit(path)
	await _fade(0.0)
	_end()


## The night's heavy data (the shell, read from its cache - or carved when
## the floor changed since), once the loading screen is on the screen; one
## more frame, and the screen stands while the museum builds.
func _prepare() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	Museum.prepare_level()
	await get_tree().process_frame


## Puts [param scene] in place of the running scene (a test replaces this).
func _swap(scene: Node) -> void:
	get_tree().change_scene_to_node(scene)
	await get_tree().scene_changed


func _run_quit() -> void:
	_begin()
	await _fade(1.0)
	Sfx.quit_cleanly()


func _begin() -> void:
	busy = true
	_black.mouse_filter = Control.MOUSE_FILTER_STOP


func _end() -> void:
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false


func _fade(to: float) -> void:
	var tween := create_tween()
	tween.tween_property(_black, "modulate:a", to, FADE)
	await tween.finished
