extends Node
## Windowed check of the stage 3 art in the game (not part of the headless
## suite): the Gatling and the flare gun in the guard's hands, the raptor
## pack on its rigs (lit, crouching, leaping, stunned, broken, and in the
## dark lit only by a stuck flare), the gallery's portraits (sleeping among
## plain paintings, eyes following, out of the wall, spitting, shut by the
## taser, torn apart), the chained Gatling exhibit, the fire cabinet and
## the new pickups, inside the real lobby. Rendered 1920x1080 offscreen (a
## small silent window mirrors it) to tests/_out/artint2/. Staged poses are
## set by hand (the rig posed frame by frame) so shots repeat; kills,
## smashes and the weapons run live.
## Usage: bash tools/run_artint2.sh [--shots=weapons,raptors,portraits,props]

const OUT_DIR := "res://tests/_out/artint2/"
const SIZE := Vector2i(1920, 1080)
const GROUPS: Array[String] = ["weapons", "raptors", "portraits", "props"]
const NIGHT_SEED := 7
const DT := 1.0 / 60.0
## The pack in the hall between the info desk and the south benches, the
## camera looking north from the entrance side.
const PACK_SPOTS: Array[Vector3] = [Vector3(-2.6, 0, 12.6), Vector3(-0.4, 0, 12.0), Vector3(1.9, 0, 13.0), Vector3(0.6, 0, 14.6)]
const PACK_CAMERA := [Vector3(0.9, 1.6, 19.4), Vector3(-0.2, 0.7, 13.0)]

var view: SubViewport
var level: LobbyLevel
var camera: Camera3D
var flashlight: SpotLight3D
var player: Player
var dummy: TargetDummy
var _mirror: TextureRect
var _groups: Array[String] = []
var _stage: Node3D
var _log: Array = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_groups.assign(arg.trim_prefix("--shots=").split(",", false))
	if _groups.is_empty():
		_groups = GROUPS.duplicate()
	GameInput.capture_allowed = false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(640, 360))
	get_viewport().disable_3d = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	FileAccess.open(ProjectSettings.globalize_path("res://tests/_out/.gdignore"), FileAccess.WRITE).close()
	view = SubViewport.new()
	view.size = SIZE
	view.msaa_3d = Viewport.MSAA_2X
	view.anisotropic_filtering_level = Viewport.ANISOTROPY_16X
	view.positional_shadow_atlas_size = 4096
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# one world with the window: Fx (debris, particles) lives in the root
	view.world_3d = get_viewport().find_world_3d()
	add_child(view)
	var config := NightDirector.plan(NIGHT_SEED, 1, LobbyLayout.describe(LobbyLayout.create()))
	level = LobbyLevel.new()
	level.night = config
	view.add_child(level)
	level.build()
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.05
	view.add_child(camera)
	camera.current = true
	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0.15, -0.1, 0.0)
	flashlight.spot_range = 24.0
	flashlight.spot_angle = 24.0
	flashlight.light_energy = Player.FLASHLIGHT_ENERGY
	flashlight.shadow_enabled = true
	flashlight.visible = false
	camera.add_child(flashlight)
	dummy = TargetDummy.new()
	dummy.position = Vector3(0, 0, 30)
	view.add_child(dummy)
	_mirror = TextureRect.new()
	_mirror.texture = view.get_texture()
	_mirror.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mirror.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mirror.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_mirror)
	await _frames(90)   # shaders, fog history
	for group in _groups:
		if not has_method("_shots_" + group):
			print("unknown group: ", group)
			continue
		_stage = Node3D.new()
		_stage.name = "Stage_" + group
		view.add_child(_stage)
		_blackout(false)
		flashlight.visible = false
		camera.current = true
		await call("_shots_" + group)
		_stage.queue_free()
		Fx.clear()
		await _frames(3)
	_write_log()
	_mirror.texture = null
	view.queue_free()
	await _frames(5)
	Sfx.quit_cleanly(0)


# --- weapons ------------------------------------------------------------------

func _shots_weapons() -> void:
	player = Player.new()
	_stage.add_child(player)
	player.respawn(Vector3(0.5, 0.05, 14.5), 0.0)
	for id in [&"gatling", &"flare"]:
		player.weapons.give(load("res://src/weapons/data/%s.tres" % id))
	player.camera.current = true
	var holder := player.weapons
	await _frames(20)
	holder.select_id(&"gatling")
	await _seconds(0.8)
	await _shot("vm_gatling_idle")
	# a burst: barrels up to speed, flashes and tracers at the muzzle
	var rig := holder._views[&"gatling"] as ViewmodelRig
	await _hold_fire(0.9)
	for i in 30:
		holder.try_fire()
		await get_tree().process_frame
		if rig == null or rig._flash.visible:
			break
	holder.set_process(false)   # freeze the view mid-burst, on a flash
	await _shot("vm_gatling_firing")
	holder.set_process(true)
	# the crank turned up: the right hand on its knob in the lower right
	for i in 240:
		holder.try_fire()
		await get_tree().physics_frame
		if rig != null and absf(angle_difference(rig._crank_angle, PI * 0.8)) < 0.12:
			break
	holder.set_process(false)
	await _shot("vm_gatling_crank")
	holder.set_process(true)
	# a long burst heats the barrels: they glow and smoke as they wind down
	await _hold_fire(3.0)
	await _seconds(0.5)
	holder.set_process(false)
	await _shot("vm_gatling_hot")
	holder.set_process(true)
	_log.append({"gatling_barrel_heat": rig.barrel_heat() if rig != null else -1.0})
	await _seconds(3.0)
	_blackout(true)
	player.set_flashlight(true)
	await _seconds(0.4)
	await _shot("vm_gatling_blackout")
	player.set_flashlight(false)
	_blackout(false)
	# the flare gun: idle, fired (the flare in flight), the break-open reload
	holder.select_id(&"flare")
	await _seconds(0.8)
	await _shot("vm_flare_idle")
	player.head.rotation.x = -0.28   # at the floor a few metres ahead
	await _frames(2)
	holder.try_fire()
	await _frames(4)
	holder.set_process(false)
	await _shot("vm_flare_fired")
	holder.set_process(true)
	await _seconds(0.5)
	holder.set_process(false)
	await _shot("vm_flare_reload")
	holder.set_process(true)
	await _seconds(1.5)
	# where it stuck: the flare burning in the floor, in the blackout
	var stuck: FlareLight = null
	for node in _stage.find_children("*", "FlareLight", true, false):
		stuck = node as FlareLight
	if stuck != null:
		_blackout(true)
		_aim(stuck.global_position + Vector3(1.2, 0.9, 1.6), stuck.global_position + Vector3(0.0, 0.1, 0.0))
		camera.current = true
		await _seconds(0.3)
		await _shot("flare_stuck_floor")
		_blackout(false)
	player.queue_free()
	player = null
	camera.current = true


func _hold_fire(duration: float) -> void:
	var frames := int(duration * 60.0)
	for i in frames:
		player.weapons.try_fire()
		await get_tree().physics_frame


# --- raptors ------------------------------------------------------------------

func _shots_raptors() -> void:
	var pack: Array[Raptor] = await _pack(PACK_SPOTS)
	_aim(PACK_CAMERA[0], PACK_CAMERA[1])
	for raptor in pack:
		_pose(raptor, "idle")
	await _shot("raptors_idle")
	for i in pack.size():
		_pose(pack[i], "walk", 0.7 + i * 1.6)
	await _shot("raptors_run")
	for raptor in pack:
		_pose(raptor, "windup", 0.9)
	await _shot("raptors_crouch")
	for raptor in pack:
		_pose(raptor, "pounce")
	await _shot("raptors_leap")
	for raptor in pack:
		_pose(raptor, "stunned")
	await _shot("raptors_stunned")
	# close-ups (the others out of the way): the crouch and hiss, the leap
	# and the run from the side, the screech
	for i in pack.size():
		pack[i].visible = i == 1
	var solo := pack[1]
	solo.rotation.y = PI
	_pose(solo, "windup", 1.0)
	_aim(solo.global_position + Vector3(-1.1, 0.8, 2.3), solo.global_position + Vector3(0, 0.55, 0.3))
	await _shot("raptor_crouch_close")
	solo.rotation.y = -PI * 0.5   # running to the camera's right, side on
	_pose(solo, "pounce")
	_aim(solo.global_position + Vector3(0.2, 1.0, 3.6), solo.global_position + Vector3(0, 0.9, 0))
	await _shot("raptor_leap_side")
	_pose(solo, "walk", 1.2)
	await _shot("raptor_run_side")
	_pose(solo, "walk", 1.2 + PI)
	await _shot("raptor_run_side_b")
	solo.rotation.y = PI * 0.8
	_pose(solo, "alert")
	_aim(solo.global_position + Vector3(0.9, 1.1, 2.4), solo.global_position + Vector3(0, 0.9, -0.3))
	await _shot("raptor_screech_close")
	for raptor in pack:
		raptor.visible = true
		raptor.rotation.y = PI
	_log_weak_points(pack)
	# the blackout: only a flare stuck in the floor among them
	for i in pack.size():
		_pose(pack[i], "idle" if i % 2 == 0 else "windup", 0.6)
	_blackout(true)
	var data := load("res://src/weapons/data/flare.tres") as WeaponData
	var burning := FlareLight.stick(_stage, Vector3(0.3, 0.0, 13.7), Vector3.UP, null, data, null)
	burning.light_time = 600.0
	await _seconds(0.6)
	_aim(PACK_CAMERA[0], PACK_CAMERA[1])
	await _shot("raptors_flare_dark")
	_aim(Vector3(3.6, 1.3, 16.4), Vector3(-0.3, 0.6, 12.8))
	await _shot("raptors_flare_dark_near")
	burning.queue_free()
	_blackout(false)
	# kills: the bones fly apart; then an overkill that tears them
	_aim(PACK_CAMERA[0], PACK_CAMERA[1])
	for raptor in pack:
		_kill(raptor, 1.0)
	await _seconds(0.25)
	await _shot("raptors_gibs_flying")
	await _seconds(1.6)
	await _shot("raptors_gibs_floor")
	Fx.clear()
	await _frames(3)
	# live: one raptor wakes 5 m from the stand-in and leaps at it
	var hunter := Raptor.new()
	hunter.position = Vector3(-2.5, 0.05, 13.5)
	hunter.target = dummy
	dummy.position = Vector3(2.4, 0.05, 13.5)
	_stage.add_child(hunter)
	hunter.face(dummy.global_position)
	await _frames(3)
	hunter.brain.wake()
	var struck := false
	for i in 180:
		await get_tree().physics_frame
		if hunter.brain.has_struck() and not hunter.is_on_floor() and hunter.velocity.y < 0.6:
			struck = true
			break
	_aim(hunter.global_position + Vector3(0.3, 0.6, 3.8), hunter.global_position + Vector3(0, 0.6, 0))
	hunter.set_physics_process(false)
	if hunter.rig != null:
		hunter.rig.set_physics_process(false)
	await _shot("raptor_leap_live")
	_log.append({"raptor_live_leap_caught": struck})
	dummy.position = Vector3(0, 0, 30)


func _pack(spots: Array[Vector3]) -> Array[Raptor]:
	var out: Array[Raptor] = []
	for i in spots.size():
		var raptor := Raptor.new()
		raptor.target = dummy
		raptor.position = spots[i]
		_stage.add_child(raptor)
		raptor.rotation.y = PI + (i - 1.5) * 0.35
		out.append(raptor)
	await _frames(2)
	for raptor in out:
		raptor.set_physics_process(false)
		if raptor.rig != null:
			raptor.rig.set_physics_process(false)
	return out


func _kill(enemy: Enemy, overkill: float) -> void:
	var info := DamageInfo.make(enemy.health.current * overkill, DamageInfo.Kind.BALLISTIC, dummy)
	info.direction = Vector3(0.2, 0.0, 1.0).normalized()
	info.position = enemy.global_position + Vector3.UP
	enemy.take_damage(info)


# --- portraits ----------------------------------------------------------------

func _shots_portraits() -> void:
	# the gallery's north wall: plain paintings (a landscape, faces) and a
	# live portrait; the south wall: a still life, a portrait and flowers
	var hang := [[&"portrait_1", &"landscape", false], [&"portrait_3", &"countess", true],
		[&"portrait_5", &"merchant", false], [&"portrait_2", &"still_life", false],
		[&"portrait_4", &"bishop", true], [&"portrait_6", &"flowers", false],
		[&"portrait_7", &"young_heir", false], [&"portrait_8", &"seascape", false]]
	var live: Array[Portrait] = []
	for entry: Array in hang:
		if not level.markers.has(entry[0]):
			continue
		var at: Transform3D = level.markers[entry[0]]
		if entry[2]:
			var portrait := Portrait.create_on_wall(at, entry[1])
			portrait.target = dummy
			_stage.add_child(portrait)
			live.append(portrait)
		else:
			_stage.add_child(WallPainting.create(at, entry[1]))
	await _frames(3)
	for portrait in live:
		portrait.set_physics_process(false)
		if portrait.rig != null:
			portrait.rig.set_physics_process(false)
	var north := live[0] if not live.is_empty() else null
	if north == null:
		return
	var wall := north.global_position
	var out := -north.global_basis.z
	var side_axis := Vector3.UP.cross(out)   # the viewer's right, facing the painting
	_aim(Vector3(-30.0, 1.75, -1.0), Vector3(-30.0, 2.0, -14.0))
	await _shot("portraits_gallery")
	_aim(wall + out * 3.2 + Vector3.DOWN * 0.3, wall)
	await _shot("portrait_asleep_close")
	# the eyes follow the guard (the stand-in) from one side to the other:
	# the camera stays in front of the face, lit by the flashlight
	var eyes := north.eye_on_canvas(1.0).lerp(north.eye_on_canvas(-1.0), 0.5)
	flashlight.visible = true
	for side in [-1.0, 0.0, 1.0]:
		dummy.global_position = wall + out * 4.0 + side_axis * side * 3.5 + Vector3.DOWN * 2.1
		_portrait_pose(north, "watch")
		_aim(eyes + out * 0.62 + Vector3.DOWN * 0.05, eyes + Vector3.DOWN * 0.05)
		await _shot("portrait_eyes_%s" % ["left", "ahead", "right"][int(side) + 1])
	flashlight.visible = false
	# out of the wall: the frame pushed out, the dark niche behind
	dummy.position = wall + Vector3(0.6, -2.1, 5.0)
	north._push_out()
	await _seconds(0.6)
	north.global_transform = Transform3D(north._wall.basis, north._wall.origin - north._wall.basis.z * north.pushed)
	_portrait_pose(north, "watch")
	_aim(wall + Vector3(-2.2, -0.3, 2.4), wall + Vector3(0.0, 0.0, 0.3))
	await _shot("portrait_awake")
	_portrait_pose(north, "windup", 0.9)
	_aim(wall + Vector3(0.6, -0.3, 2.2), wall + Vector3(0.0, 0.1, 0.4))
	await _shot("portrait_spit_telegraph")
	_portrait_pose(north, "stunned")
	await _shot("portrait_stunned")
	_blackout(true)
	flashlight.visible = true
	_portrait_pose(north, "windup", 0.9)
	_aim(Vector3(-28.5, 1.65, -8.0), wall + Vector3(0.0, 0.0, 0.4))
	await _shot("portrait_telegraph_dark")
	flashlight.visible = false
	_blackout(false)
	# torn apart: frame splinters and canvas shreds
	_aim(wall + Vector3(-1.8, -0.4, 3.4), wall + Vector3(0.0, -0.3, 0.6))
	_kill(north, 1.0)
	await _seconds(0.2)
	await _shot("portrait_gibs_flying")
	await _seconds(1.5)
	await _shot("portrait_gibs_floor")
	if live.size() > 1:
		_kill(live[1], 4.0)
	await _seconds(0.3)
	_aim(Vector3(-30.0, 1.75, 4.0), Vector3(-30.0, 1.4, 14.0))
	await _shot("portrait_gibs_torn")
	_blackout(true)
	flashlight.visible = true
	_aim(Vector3(-30.0, 1.75, -4.0), Vector3(-30.0, 2.0, -14.0))
	await _shot("portraits_gallery_blackout")
	flashlight.visible = false
	_blackout(false)
	dummy.position = Vector3(0, 0, 30)


## Holds [param portrait] in a state, its rig posed for a second.
func _portrait_pose(portrait: Portrait, pose: String, amount: float = 0.0) -> void:
	var brain := portrait.brain
	brain._struck = false
	brain._timer = 0.0
	match pose:
		"watch":
			brain.state = EnemyBrain.State.HUNT if portrait.vulnerable() else EnemyBrain.State.SUSPICIOUS
		"windup":
			brain.state = EnemyBrain.State.ATTACK
			brain._timer = brain.windup * (1.0 - amount)
		"stunned":
			brain.state = EnemyBrain.State.STUNNED
	portrait._stun_marker.visible = brain.state == EnemyBrain.State.STUNNED
	var rig := portrait.rig
	if rig == null:
		portrait._update_visuals(DT)
		return
	for i in 60:
		rig.time += DT
		portrait._update_visuals(DT)
		rig._pose(DT)
		rig._update_shading(DT)


# --- props --------------------------------------------------------------------

func _shots_props() -> void:
	var display := ChainedDisplay.create(level.markers.get(&"gatling_display", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(30, 0, 7))))
	display.persistent = false
	_stage.add_child(display)
	var cabinet := EmergencyCabinet.create(level.markers.get(&"flare_cabinet", Transform3D(Basis(Vector3.UP, PI), Vector3(5, 1.4, 24))))
	cabinet.persistent = false
	_stage.add_child(cabinet)
	var near := display.global_transform * Vector3(0.9, 0.0, -1.6)
	for i in 2:
		var pickup := Pickup.new()
		pickup.type = Pickup.Type.RIFLE if i == 0 else Pickup.Type.FLARES
		pickup.respawn_time = 0.0
		pickup.position = near + Vector3(0.0, 0.45, (i - 0.5) * 0.9)
		_stage.add_child(pickup)
	await _seconds(1.0)
	var front := display.global_transform * Vector3(0.0, 1.55, -3.2)
	var at := display.global_transform * Vector3(0.0, 0.8, 0.0)
	_aim(front, at)
	await _shot("display_intact")
	_aim(display.global_transform * Vector3(-1.3, 1.5, -2.0), at)
	await _shot("display_intact_side")
	display.break_chain()
	await _seconds(0.15)
	_aim(front, at)
	await _shot("display_chain_breaking")
	await _seconds(1.4)
	await _shot("display_broken")
	display._set_state(ChainedDisplay.State.EMPTY)
	await _frames(2)
	await _shot("display_taken")
	_aim(display.global_transform * Vector3(1.4, 1.2, -2.6), near + Vector3(0.0, 0.4, 0.0))
	await _shot("ammo_pickups")
	_blackout(true)
	await _shot("ammo_pickups_dark")
	_blackout(false)
	var face := cabinet.global_transform * Vector3(0.0, 0.1, -1.4)
	var middle := cabinet.global_transform * Vector3(0.0, 0.0, 0.0)
	_aim(face, middle)
	await _shot("cabinet_intact")
	_aim(cabinet.global_transform * Vector3(-1.2, 0.4, -2.6), middle)
	await _shot("cabinet_intact_wide")
	cabinet.smash()
	await _seconds(0.12)
	_aim(face, middle)
	await _shot("cabinet_smashing")
	await _seconds(1.4)
	await _shot("cabinet_smashed")
	cabinet._set_state(EmergencyCabinet.State.EMPTY)
	await _frames(2)
	await _shot("cabinet_empty")


# --- staging helpers ----------------------------------------------------------

## Holds [param enemy] in a pose: its brain state set by hand, the base
## visuals and the rig run for a while so the eased parts settle.
func _pose(enemy: Enemy, pose: String, amount: float = 0.0) -> void:
	var brain := enemy.brain
	var rig := enemy.rig
	brain._struck = false
	brain._timer = 0.0
	match pose:
		"dormant":
			brain.state = EnemyBrain.State.DORMANT
		"idle", "walk":
			brain.state = EnemyBrain.State.HUNT
		"alert":
			brain.state = EnemyBrain.State.SUSPICIOUS
		"windup":
			brain.state = EnemyBrain.State.ATTACK
			brain._timer = brain.windup * (1.0 - amount)
		"strike", "pounce":
			brain.state = EnemyBrain.State.ATTACK
			brain._struck = true
			brain._timer = brain.recovery
		"stunned":
			brain.state = EnemyBrain.State.STUNNED
	var base_y: float = enemy.get_meta(&"floor_y", enemy.global_position.y)
	enemy.set_meta(&"floor_y", base_y)
	enemy.global_position.y = base_y
	enemy.velocity = Vector3.ZERO
	if pose == "pounce":
		enemy.global_position.y = base_y + 0.7
		enemy.velocity = Vector3(0, 1.2, 0)
	enemy._stun_marker.visible = brain.state == EnemyBrain.State.STUNNED
	if rig == null:
		enemy._update_visuals(DT)
		return
	for i in 45:
		rig.time += DT
		rig.gait = 1.0 if pose == "walk" else 0.0
		rig.walk_phase = amount + i * 0.0 if pose == "walk" else rig.walk_phase
		rig.since_strike = 0.02 + i * DT * 0.2 if pose in ["strike", "pounce"] else -1.0
		enemy._update_visuals(DT)
		rig._pose(DT)
		rig._follow_parts()
		rig._update_shading(DT)


func _log_weak_points(enemies: Array) -> void:
	for enemy: Enemy in enemies:
		if enemy.rig == null:
			continue
		for child in enemy.get_children():
			var zone := child as Hurtbox
			if zone != null and zone.weak_point:
				var weak := enemy.rig.part("WeakPoint")
				_log.append({"enemy": enemy.name, "weak_zone": str(zone.global_position),
					"weak_marker": str(weak.global_position) if weak != null else "-"})


func _blackout(on: bool) -> void:
	for group in [LightSpec.MAIN, StringName("%s_fixtures" % LightSpec.MAIN)]:
		for node in get_tree().get_nodes_in_group(group):
			(node as Node3D).visible = not on


func _aim(from: Vector3, at: Vector3) -> void:
	camera.global_position = from
	camera.look_at(at, Vector3.UP)


func _shot(shot_name: String) -> void:
	await _frames(8)
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	var path := OUT_DIR.path_join("%s.png" % shot_name)
	image.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _write_log() -> void:
	var file := FileAccess.open(OUT_DIR.path_join("log.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_log, "  "))
	file.close()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _seconds(duration: float) -> void:
	await get_tree().create_timer(duration, true, false, true).timeout
