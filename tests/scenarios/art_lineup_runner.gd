extends Node
## Windowed art check (not part of the headless suite): the stage 2 models
## in the style sample room, under the real lighting recipe. Renders
## 1920x1080 shots offscreen to tests/_out/art_lineup/: the enemies (lamps
## on, and in a blackout with the flashlight), the T-Rex, the props, and
## each first-person weapon as the player sees it. The wolf, the knight's
## shield arm and the T-Rex are posed through their jointed parts, the
## same way gameplay will animate them.
## Usage: bash tools/run_art_lineup.sh [--shots=enemies,trex]

const OUT_DIR := "res://tests/_out/art_lineup/"
const SIZE := Vector2i(1920, 1080)
## name: [camera position, look-at point, vertical fov, blackout + flashlight, visible group]
const SHOTS := {
	"enemies": [Vector3(0.3, 1.45, 4.3), Vector3(0.0, 0.95, 0.6), 55.0, false, "enemies"],
	"enemies_dark": [Vector3(0.3, 1.45, 4.3), Vector3(0.0, 0.95, 0.6), 55.0, true, "enemies"],
	"knight_close": [Vector3(-0.6, 1.75, 2.3), Vector3(-1.2, 1.45, 0.7), 45.0, false, "enemies"],
	"wolf_close": [Vector3(1.2, 0.9, 2.9), Vector3(0.5, 0.6, 1.3), 45.0, false, "enemies"],
	"trex": [Vector3(-0.4, 1.7, 4.7), Vector3(0.0, 2.6, 0.0), 80.0, false, "trex"],
	"trex_dark": [Vector3(-0.4, 1.7, 4.7), Vector3(0.0, 2.6, 0.0), 80.0, true, "trex"],
	"props": [Vector3(0.0, 1.35, 3.6), Vector3(0.0, 0.55, 0.2), 55.0, false, "props"],
	"props_dark": [Vector3(0.0, 1.35, 3.6), Vector3(0.0, 0.55, 0.2), 55.0, true, "props"],
	"vm_pistol": [Vector3(1.8, 1.6, 4.0), Vector3(-1.0, 1.3, -2.0), 70.0, false, "vm_pistol"],
	"vm_taser": [Vector3(1.8, 1.6, 4.0), Vector3(-1.0, 1.3, -2.0), 70.0, false, "vm_taser"],
	"vm_shotgun": [Vector3(1.8, 1.6, 4.0), Vector3(-1.0, 1.3, -2.0), 70.0, false, "vm_shotgun"],
	"vm_shotgun_dark": [Vector3(1.8, 1.6, 4.0), Vector3(-1.0, 1.3, -2.0), 70.0, true, "vm_shotgun"],
	"vm_fists": [Vector3(1.8, 1.6, 4.0), Vector3(-1.0, 1.3, -2.0), 70.0, false, "vm_fists"],
	# stage 3 (expansion); a 6th entry true = blackout lit only by the burning flare
	"raptors": [Vector3(0.6, 1.45, 4.3), Vector3(-0.2, 0.7, 0.9), 55.0, false, "raptors"],
	"raptors_flare": [Vector3(0.6, 1.45, 4.3), Vector3(-0.2, 0.7, 0.9), 55.0, true, "raptors", true],
	"raptor_close": [Vector3(1.5, 1.15, 3.0), Vector3(0.3, 0.9, 1.5), 45.0, false, "raptors"],
	"portraits": [Vector3(-3.3, 1.8, 0.8), Vector3(-6.0, 2.0, 0.8), 70.0, false, "portraits"],
	"portraits_dark": [Vector3(-3.3, 1.8, 0.8), Vector3(-6.0, 2.0, 0.8), 70.0, true, "portraits"],
	"portrait_close": [Vector3(-4.7, 2.0, -1.1), Vector3(-6.0, 2.05, -1.2), 50.0, false, "portraits"],
	"armoury": [Vector3(0.9, 1.55, 3.6), Vector3(-0.6, 0.75, 0.4), 55.0, false, "stage3_props"],
	"armoury_dark": [Vector3(0.9, 1.55, 3.6), Vector3(-0.6, 0.75, 0.4), 55.0, true, "stage3_props"],
	"cabinet_close": [Vector3(4.55, 1.3, 1.0), Vector3(6.0, 1.25, 0.9), 50.0, false, "stage3_props"],
	"vm_gatling": [Vector3(1.8, 1.6, 4.0), Vector3(-1.0, 1.3, -2.0), 70.0, false, "vm_gatling"],
	"vm_gatling_crank": [Vector3(1.8, 1.6, 4.0), Vector3(-1.0, 1.3, -2.0), 70.0, false, "vm_gatling_crank"],
	"vm_gatling_dark": [Vector3(1.8, 1.6, 4.0), Vector3(-1.0, 1.3, -2.0), 70.0, true, "vm_gatling"],
	"vm_flare": [Vector3(1.8, 1.6, 4.0), Vector3(-1.0, 1.3, -2.0), 70.0, false, "vm_flare"],
}
## WeaponHolder.REST / AIM_YAW / FIST_HIT (src/weapons/weapon_holder.gd)
const REST := Vector3(0.17, -0.16, -0.55)
const AIM_YAW := 0.1
const FIST_HIT := Vector3(-0.05, -0.14, -0.62)

var flare_lights: Array[OmniLight3D] = []
var sample: StyleSample
var view: SubViewport
var camera: Camera3D
var flashlight: SpotLight3D
var groups := {}
var _mirror: TextureRect
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
	view.anisotropic_filtering_level = Viewport.ANISOTROPY_16X
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
	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0.15, -0.1, 0.0)
	flashlight.spot_range = 24.0
	flashlight.spot_angle = 24.0
	flashlight.light_energy = 3.0
	flashlight.shadow_enabled = true
	flashlight.visible = false
	camera.add_child(flashlight)
	_mirror = TextureRect.new()
	_mirror.texture = view.get_texture()
	_mirror.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mirror.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mirror.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_mirror)
	_build_enemies()
	_build_trex()
	_build_props()
	_build_viewmodels()
	_build_stage3()
	_place(SHOTS["enemies"])
	await _frames(120)
	for shot_name in _shots:
		if not SHOTS.has(shot_name):
			print("unknown shot: ", shot_name)
			continue
		_place(SHOTS[shot_name])
		await _frames(45)
		await _save(shot_name)
	_mirror.texture = null
	view.queue_free()
	await _frames(5)
	get_tree().quit(0)


func _group(group_name: String) -> Node3D:
	if not groups.has(group_name):
		var node := Node3D.new()
		node.name = group_name
		node.visible = false
		sample.add_child(node)
		groups[group_name] = node
	return groups[group_name]


func _add(group_name: String, id: StringName, at: Vector3, yaw_deg: float = 0.0) -> Node3D:
	var node := ArtLibrary.instance(id)
	node.position = at
	node.rotation_degrees.y = yaw_deg
	_group(group_name).add_child(node)
	return node


func _build_enemies() -> void:
	# enemies face -Z; turn them toward the camera (+Z)
	_add("enemies", &"knight", Vector3(-1.25, 0, 0.7), 165.0)
	_add("enemies", &"wolf", Vector3(0.45, 0, 1.3), 205.0)
	var leaping := _add("enemies", &"wolf", Vector3(-0.2, 0.55, -0.9), 160.0)
	var p := ArtLibrary.parts(leaping)
	(p["body"] as Node3D).rotation.x = 0.22
	(p["leg_fl"] as Node3D).rotation.x = 1.0
	(p["leg_fr"] as Node3D).rotation.x = 0.85
	(p["leg_bl"] as Node3D).rotation.x = -0.75
	(p["leg_br"] as Node3D).rotation.x = -0.9
	(p["jaw"] as Node3D).rotation.x = -0.4
	(p["tail"] as Node3D).rotation.x = -0.45
	_add("enemies", &"bust_enemy", Vector3(1.55, 1.6, 0.4), 195.0)


func _build_trex() -> void:
	var rex := _add("trex", &"trex", Vector3(0.4, 0, 0.3), -90.0)
	var p := ArtLibrary.parts(rex)
	(p["jaw"] as Node3D).rotation.x = -0.35
	(p["neck_1"] as Node3D).rotation.y = 0.12
	(p["neck_2"] as Node3D).rotation.y = 0.12
	for k in range(1, 9):
		(p["tail_%d" % k] as Node3D).rotation.y = -0.07
	var crystal := ArtLibrary.instance(&"crystal_loose")
	(p["CrystalSocket"] as Node3D).add_child(crystal)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.25, 0.18)
	glow.light_energy = 1.5
	glow.omni_range = 3.0
	(p["CrystalSocket"] as Node3D).add_child(glow)


func _build_props() -> void:
	_add("props", &"cctv_bank", Vector3(0.6, 0, -1.6))
	_add("props", &"terminal", Vector3(-1.35, 0, -1.2), 15.0)
	var locker := _add("props", &"pistol_locker", Vector3(-0.3, 0.9, -1.35))
	(ArtLibrary.parts(locker)["door"] as Node3D).rotation.y = deg_to_rad(-100.0)
	var pistol := ArtLibrary.instance(&"vm_pistol")
	pistol.find_child("hand_r", true, false).queue_free()
	pistol.rotation_degrees = Vector3(0, 90, 90)
	(ArtLibrary.parts(locker)["Pistol"] as Node3D).add_child(pistol)
	var row := [&"ammo_pistol", &"ammo_shells", &"medkit", &"fuse", &"lantern", &"crystal_loose"]
	for i in row.size():
		var id: StringName = row[i]
		var y := 0.0 if id == &"lantern" else 0.3
		var node := _add("props", id, Vector3(-1.5 + i * 0.6, y, 0.6), -15.0 + i * 8.0)
		if id == &"lantern":
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.72, 0.42)
			lamp.light_energy = 1.2
			lamp.omni_range = 3.5
			lamp.shadow_enabled = true
			(ArtLibrary.parts(node)["Light"] as Node3D).add_child(lamp)


func _build_viewmodels() -> void:
	for id in [&"vm_pistol", &"vm_taser", &"vm_shotgun", &"vm_fists"]:
		var holder := Node3D.new()
		holder.name = String(id)
		holder.visible = false
		camera.add_child(holder)
		groups[String(id)] = holder
		var view_model := ArtLibrary.instance(id)
		if id == &"vm_fists":
			view_model.position = FIST_HIT
		else:
			view_model.position = REST
			view_model.rotation = Vector3(0.0, AIM_YAW, 0.0)
		holder.add_child(view_model)
	for id in [&"vm_gatling", &"vm_flare", &"vm_gatling_crank"]:
		var holder := Node3D.new()
		holder.name = String(id)
		holder.visible = false
		camera.add_child(holder)
		groups[String(id)] = holder
		var view_model := ArtLibrary.instance(&"vm_gatling" if id == &"vm_gatling_crank" else id)
		view_model.position = REST
		view_model.rotation = Vector3(0.0, AIM_YAW, 0.0)
		holder.add_child(view_model)
		if id == &"vm_gatling_crank":
			var parts := ArtLibrary.parts(view_model)
			var crank := parts["crank"] as Node3D
			var knob := parts["CrankKnob"] as Node3D
			var rest := crank.transform * knob.position
			crank.rotation.x = PI * 0.85
			(parts["barrels"] as Node3D).rotation.z = 0.4
			(parts["hand_r"] as Node3D).position += crank.transform * knob.position - rest


## Stage 3: a raptor pack (posed through its joints) round a flare stuck
## in the floor, portraits on the left wall (one with its eyes turned to
## the camera through the eyes material's uv1_offset), the armoury props
## (Gatling exhibit, emergency cabinet on the back wall, pickups), and the
## two new viewmodels (the Gatling also with its crank turned up and the
## right hand moved with the CrankKnob marker, as gameplay will do it).
func _build_stage3() -> void:
	var a := _add("raptors", &"raptor", Vector3(-0.9, 0, 0.5), 160.0)
	var p := ArtLibrary.parts(a)
	(p["neck_1"] as Node3D).rotation.y = 0.25
	(p["skull"] as Node3D).rotation.y = 0.2
	(p["jaw"] as Node3D).rotation.x = -0.3
	(p["tail_2"] as Node3D).rotation.y = -0.12
	(p["tail_4"] as Node3D).rotation.y = -0.1
	var b := _add("raptors", &"raptor", Vector3(0.7, 0, 1.3), 205.0)
	p = ArtLibrary.parts(b)
	(p["pelvis"] as Node3D).rotation.x = 0.12
	(p["thigh_l"] as Node3D).rotation.x = 0.55
	(p["shin_l"] as Node3D).rotation.x = -0.9
	(p["thigh_r"] as Node3D).rotation.x = -0.25
	(p["arm_l"] as Node3D).rotation.x = -0.5
	(p["arm_r"] as Node3D).rotation.x = -0.4
	(p["jaw"] as Node3D).rotation.x = -0.45
	(p["neck_1"] as Node3D).rotation.x = 0.25
	var c := _add("raptors", &"raptor", Vector3(-0.1, 0, -1.1), 175.0)
	p = ArtLibrary.parts(c)
	(p["neck_1"] as Node3D).rotation.y = -0.3
	(p["tail_1"] as Node3D).rotation.y = 0.15
	var flare := _add("raptors", &"flare_round", Vector3(0.05, 0.04, 0.8), 30.0)
	flare.rotation_degrees.x = 60.0
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.32, 0.26)
	glow.light_energy = 3.0
	glow.omni_range = 8.0
	glow.shadow_enabled = true
	glow.visible = false
	(ArtLibrary.parts(flare)["Light"] as Node3D).add_child(glow)
	flare_lights.append(glow)
	# portraits on the left wall (x = -6, facing +X)
	var hang := [[-1.2, {}], [0.8, {"canvas_aristocrat": "canvas_lady_fan"}],
		[2.8, {"canvas_aristocrat": "canvas_general"}], [-3.1, {"canvas_aristocrat": "canvas_landscape"}]]
	for i in hang.size():
		var pic := ArtLibrary.instance(&"portrait", hang[i][1])
		pic.position = Vector3(-6.0, 2.05, hang[i][0])
		pic.rotation_degrees.y = 90.0
		_group("portraits").add_child(pic)
		if i == 3:
			(ArtLibrary.parts(pic)["eyes"] as Node3D).visible = false
		if i == 0:
			for mat in ArtLibrary.own_materials(pic):
				if mat.resource_name == ArtLibrary.PORTRAIT_EYES_MATERIAL:
					mat.uv1_offset = Vector3(ArtLibrary.PORTRAIT_EYES_REACH.x * 0.7, 0.02, 0.0)
	# armoury: the Gatling exhibit, the cabinet on the back wall, pickups
	_add("stage3_props", &"gatling_display", Vector3(-1.3, 0, 0.4), 25.0)
	_add("stage3_props", &"emergency_cabinet", Vector3(6.0, 0.95, 0.9), -90.0)
	var row := [&"ammo_rifle", &"ammo_flares", &"flare_round"]
	for i in row.size():
		_add("stage3_props", row[i], Vector3(0.1 + i * 0.45, 0.25, 1.5), -20.0 + i * 15.0)


func _place(shot: Array) -> void:
	camera.position = shot[0]
	camera.look_at(shot[1], Vector3.UP)
	camera.fov = shot[2]
	var dark: bool = shot[3]
	var flare_only: bool = shot.size() > 5 and shot[5]
	sample.set_main_lights(not dark)
	flashlight.visible = dark and not flare_only
	for lamp in flare_lights:
		lamp.visible = flare_only
	for group_name in groups:
		(groups[group_name] as Node3D).visible = group_name == shot[4]


func _save(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	var path := OUT_DIR.path_join("%s.png" % shot_name)
	image.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
