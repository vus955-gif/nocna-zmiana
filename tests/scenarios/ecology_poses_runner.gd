extends Node
## Windowed check of the ecology's poses (not part of the headless suite):
## live exhibits in the style sample room, under the real lighting, put in
## the moments the ecology added and shot offscreen at 1920x1080 to
## tests/_out/ecology_poses/: the knight asleep and come to the ready (its
## wake), a wolf on the scent (nose to the floor), a mummy lying back in
## its coffin after a hunt (its rest).
## Usage: bash tools/run_ecology_poses.sh [--shots=knight_ready,wolf_sniff]

const OUT_DIR := "res://tests/_out/ecology_poses/"
const SIZE := Vector2i(1920, 1080)
## name: [camera position, look-at point, vertical fov]
const SHOTS := {
	"knight_rest": [Vector3(0.2, 1.5, 3.6), Vector3(-0.9, 1.1, 0.4), 45.0],
	"knight_ready": [Vector3(0.2, 1.5, 3.6), Vector3(-0.9, 1.1, 0.4), 45.0],
	"wolf_sniff": [Vector3(1.9, 1.0, 3.4), Vector3(1.1, 0.45, 1.2), 45.0],
	"mummy_rest": [Vector3(0.9, 1.5, -2.9), Vector3(0.0, 1.0, -1.15), 60.0],
	"mummy_asleep": [Vector3(0.9, 1.5, -2.9), Vector3(0.0, 1.0, -1.15), 60.0],
	"mummy_back": [Vector3(0.6, 1.4, 0.45), Vector3(0.0, 1.1, -0.9), 60.0],
	"mummy_back_low": [Vector3(-0.5, 0.7, 0.2), Vector3(0.0, 0.8, -0.9), 60.0],
}

var sample: StyleSample
var view: SubViewport
var camera: Camera3D
var dummy: TargetDummy
var knight: Knight
var wolf: Wolf
var mummy: Mummy
var _shots: PackedStringArray = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=").split(",", false)
	if _shots.is_empty():
		_shots = PackedStringArray(SHOTS.keys())
	GameInput.capture_allowed = false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(640, 360))
	get_viewport().disable_3d = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	FileAccess.open(ProjectSettings.globalize_path("res://tests/_out/.gdignore"), FileAccess.WRITE).close()
	view = SubViewport.new()
	view.size = SIZE
	view.msaa_3d = Viewport.MSAA_4X
	view.positional_shadow_atlas_size = 4096
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	sample = (load("res://src/style/style_sample.tscn") as PackedScene).instantiate() as StyleSample
	sample.with_player = false
	view.add_child(sample)
	if sample.figure != null:
		sample.figure.visible = false
	camera = Camera3D.new()
	camera.near = 0.03
	view.add_child(camera)
	camera.current = true
	var mirror := TextureRect.new()
	mirror.texture = view.get_texture()
	mirror.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mirror.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mirror.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mirror)
	dummy = TargetDummy.new()
	dummy.position = Vector3(0, 0, 40)   # far off, out of everyone's sight
	sample.add_child(dummy)
	knight = Knight.new()
	knight.position = Vector3(-0.9, 0.05, 0.4)
	knight.target = dummy
	sample.add_child(knight)
	knight.face(Vector3(-0.6, 0, 4.0))   # toward the camera
	wolf = Wolf.new()
	wolf.position = Vector3(1.1, 0.05, 1.2)
	wolf.target = dummy
	sample.add_child(wolf)
	wolf.face(Vector3(-2.0, 0, 2.2))   # side on to the camera
	mummy = Mummy.new()
	mummy.entombed = true
	mummy.position = Vector3(0.0, 0.05, -1.2)
	mummy.target = dummy
	sample.add_child(mummy)
	await _physics(90)
	for shot_name in _shots:
		if not SHOTS.has(shot_name):
			print("unknown shot: ", shot_name)
			continue
		await call("_stage_" + shot_name)
		_place(SHOTS[shot_name])
		await _frames(3)
		await _save(shot_name)
	mirror.texture = null
	view.queue_free()
	await _frames(5)
	get_tree().quit(0)


func _stage_knight_rest() -> void:
	pass


func _stage_knight_ready() -> void:
	knight.hear(knight.global_position + Vector3(0, 0, 3))
	await _physics(20)   # a third of a second into its suspicion: up and ready


func _stage_wolf_sniff() -> void:
	wolf.brain.quiet = true
	wolf.set("_sniffing", true)
	wolf.brain.hear(wolf.global_position + Vector3(-6.0, 0, 2.0), true)
	await _physics(15)   # on the scent, before it sets off
	print("wolf sniffing: ", wolf.sniffing(), " state ", EnemyBrain.State.keys()[wolf.brain.state])


func _stage_mummy_asleep() -> void:
	_lamp()


## The coffin seen from behind (the back wall, where the bandages showed).
func _stage_mummy_back() -> void:
	_lamp()


func _stage_mummy_back_low() -> void:
	_lamp()


## A work lamp over the coffin (the sample room leaves it in the dark).
func _lamp() -> void:
	if sample.has_node("CoffinLamp"):
		return
	var lamp := OmniLight3D.new()
	lamp.name = "CoffinLamp"
	lamp.position = Vector3(0.6, 2.2, -0.4)
	lamp.light_color = Color(1.0, 0.8, 0.6)
	lamp.light_energy = 2.0
	lamp.omni_range = 5.0
	lamp.shadow_enabled = true
	sample.add_child(lamp)


func _stage_mummy_rest() -> void:
	_lamp()
	mummy.brain.wake()
	print("mummy woken: state ", EnemyBrain.State.keys()[mummy.brain.state], " rising ", mummy.rising(), " tomb ", mummy.tomb)
	for i in 900:
		await get_tree().physics_frame
		if not mummy.in_tomb():
			break
	print("mummy out after the rise: ", not mummy.in_tomb(), " state ", EnemyBrain.State.keys()[mummy.brain.state])
	await _physics(30)
	mummy.brain.call("_rest")   # the hunt over and home again: it lies down to rest
	await _physics(60)
	print("mummy: state ", EnemyBrain.State.keys()[mummy.brain.state], " in tomb ", mummy.in_tomb(), " at ", mummy.global_position)


func _place(shot: Array) -> void:
	camera.position = shot[0]
	camera.look_at(shot[1], Vector3.UP)
	camera.fov = shot[2]


func _save(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	var path := OUT_DIR.path_join("%s.png" % shot_name)
	image.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _physics(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
