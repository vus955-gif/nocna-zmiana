extends Node
## Windowed check of the art integration (not part of the headless suite):
## the animated exhibit models, the T-Rex, the first-person weapons and the
## pickups inside the real lobby, rendered 1920x1080 offscreen (a small
## silent window mirrors it) to tests/_out/artint/. Exhibits are staged in
## a pose (their state set by hand, the rig posed frame by frame) so every
## shot is repeatable; kills and the T-Rex collapse run live.
## Usage: bash tools/run_artint.sh [--shots=exhibits,dark,gibs,trex,weapons,props] [--perf]
## (--shots=fp: the first-person animation poses, frozen at their moments;
## not in the default groups)
## --perf: ~30 exhibits chase a stand-in guard across the hall, measured
## with the models and again with the greybox (uncapped: --disable-vsync).

const OUT_DIR := "res://tests/_out/artint/"
const SIZE := Vector2i(1920, 1080)
const GROUPS: Array[String] = ["exhibits", "dark", "gibs", "trex", "weapons", "props"]
const NIGHT_SEED := 7
const DT := 1.0 / 60.0
## Lit lineup between the info desk and the south benches; the camera looks
## north from the entrance side.
const LIT_SPOTS: Array[Vector3] = [Vector3(-3.3, 0, 11.0), Vector3(-1.2, 0, 11.4), Vector3(1.0, 0, 11.0), Vector3(3.3, 0, 11.2)]
const LIT_CAMERA := [Vector3(0.2, 1.65, 16.2), Vector3(0.0, 1.05, 11.0)]
## Under the west balcony by the gallery door, seen across the hall from
## 11 and 15 m (clear of the columns and the info desk).
const DARK_SPOTS: Array[Vector3] = [Vector3(-13.9, 0, 5.4), Vector3(-13.2, 0, 4.1), Vector3(-12.6, 0, 2.7), Vector3(-12.0, 0, 1.2)]
const DARK_CENTRE := Vector3(-13.0, 0.9, 3.4)
const DARK_NEAR := Vector3(-3.0, 1.65, 8.6)
const DARK_FAR := Vector3(0.5, 1.65, 12.0)

var view: SubViewport
var level: LobbyLevel
var camera: Camera3D
var flashlight: SpotLight3D
var player: Player
var dummy: TargetDummy
var _mirror: TextureRect
var _groups: Array[String] = []
var _perf := false
var _stage: Node3D
var _log: Array = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_groups.assign(arg.trim_prefix("--shots=").split(",", false))
		elif arg == "--perf":
			_perf = true
	if _groups.is_empty() and not _perf:
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
	_hide_kit(&"trex")
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
	if _perf:
		await _measure()
	_write_log()
	_mirror.texture = null
	view.queue_free()
	await _frames(5)
	Sfx.quit_cleanly(0)


# --- exhibits ---------------------------------------------------------------

func _shots_exhibits() -> void:
	var lineup: Array[Enemy] = await _lineup(LIT_SPOTS)
	_aim(LIT_CAMERA[0], LIT_CAMERA[1])
	for enemy in lineup:
		_pose(enemy, "idle")
	await _shot("exhibits_idle")
	for i in lineup.size():
		_pose(lineup[i], "walk", 0.8 + i * 1.3)
	await _shot("exhibits_walk")
	for enemy in lineup:
		_pose(enemy, "windup", 0.85)
	await _shot("exhibits_windup")
	for enemy in lineup:
		_pose(enemy, "strike")
	await _shot("exhibits_strike")
	for enemy in lineup:
		_pose(enemy, "stunned")
	await _shot("exhibits_stunned")
	# close-ups: the wolf's pounce and the knight's cut
	var wolf := lineup[1]
	_pose(wolf, "pounce")
	_aim(Vector3(-0.2, 1.1, 13.4), Vector3(-1.2, 0.9, 11.4))
	await _shot("wolf_pounce")
	var knight := lineup[2]
	_pose(knight, "windup", 1.0)
	_aim(Vector3(2.2, 1.6, 13.6), Vector3(1.0, 1.4, 11.0))
	await _shot("knight_windup_close")
	_pose(lineup[0], "windup", 0.9)
	_aim(Vector3(-2.3, 1.6, 13.0), Vector3(-3.3, 1.35, 11.0))
	await _shot("wax_windup_close")
	_pose(lineup[3], "windup", 0.9)
	_aim(Vector3(3.0, 1.7, 12.9), Vector3(3.3, 2.0, 11.2))
	await _shot("bust_windup_close")
	_log_weak_points(lineup)


## The lineup in a dark corner of the hall, seen from 12-15 m: lamps on,
## then the blackout with only the flashlight.
func _shots_dark() -> void:
	var lineup: Array[Enemy] = await _lineup(DARK_SPOTS, DARK_FAR)
	for enemy in lineup:
		_pose(enemy, "idle")
	_aim(DARK_FAR, DARK_CENTRE)
	await _shot("dark_lamps_15m")
	_blackout(true)
	await _shot("blackout_15m")
	for enemy in lineup:
		enemy.rig._awake = 0.0
		_pose(enemy, "dormant")
	await _shot("blackout_15m_dormant")
	for enemy in lineup:
		_pose(enemy, "idle")
	await _shot("blackout_15m_again")
	flashlight.visible = true
	await _shot("blackout_15m_flashlight")
	_aim(DARK_NEAR, DARK_CENTRE)
	await _shot("blackout_11m_flashlight")
	_aim(DARK_NEAR, DARK_CENTRE + Vector3(3.5, 0.0, 3.0))
	await _shot("blackout_11m_flashlight_aside")
	_blackout(false)
	flashlight.visible = false


## Normal kills (the parts fall off) and heavy overkill (torn to chunks).
func _shots_gibs() -> void:
	_aim(LIT_CAMERA[0], LIT_CAMERA[1])
	for gibbed in [false, true]:
		var lineup: Array[Enemy] = await _lineup(LIT_SPOTS)
		for enemy in lineup:
			_pose(enemy, "idle")
		await _frames(2)
		for enemy in lineup:
			# shot from behind (the knight's shield would stop it), so the
			# pieces fly toward the camera
			var info := DamageInfo.make(enemy.health.current * (3.0 if gibbed else 1.0), DamageInfo.Kind.BALLISTIC, dummy)
			info.direction = Vector3(0.2, 0.0, 1.0).normalized()
			info.position = enemy.global_position + Vector3.UP
			enemy.take_damage(info)
		await _seconds(0.3)
		await _shot("gibs_%s_flying" % ("torn" if gibbed else "parts"))
		await _seconds(1.6)
		await _shot("gibs_%s_floor" % ("torn" if gibbed else "parts"))
		Fx.clear()
		await _frames(3)


# --- T-Rex ------------------------------------------------------------------

func _shots_trex() -> void:
	var rex := TRex.new()
	rex.position = Vector3(0, 1.25, -11)
	rex.rotation.y = -PI * 0.5
	rex.target = dummy
	_stage.add_child(rex)
	await _frames(30)
	_aim(Vector3(4.0, 1.7, 3.0), Vector3(0.0, 3.4, -11.0))
	await _shot("trex_dormant")
	_aim(Vector3(-6.5, 1.7, -2.0), Vector3(0.0, 3.6, -11.0))
	await _shot("trex_dormant_side")
	_blackout(true)
	flashlight.visible = true
	await _shot("trex_dormant_blackout")
	_blackout(false)
	flashlight.visible = false
	rex.wake()
	await _seconds(0.9)
	_aim(Vector3(4.0, 1.7, 3.0), Vector3(0.0, 4.0, -11.0))
	await _shot("trex_wake_roar")
	rex.queue_free()
	# on the hall floor: staged poses (no steering)
	var boss := TRex.new()
	boss.position = Vector3(0, 0.05, 2)
	boss.target = dummy
	_stage.add_child(boss)
	await _frames(20)
	boss.wake()
	boss.set_physics_process(false)
	var poses := [["trex_charge_windup", TRexBrain.State.CHARGE_WINDUP, Vector3(3.5, 1.7, -7.0)],
		["trex_charge", TRexBrain.State.CHARGE, Vector3(5.0, 1.7, -6.0)],
		["trex_stunned", TRexBrain.State.STUNNED, Vector3(4.5, 1.6, -3.0)],
		["trex_tail_windup", TRexBrain.State.TAIL_WINDUP, Vector3(-6.0, 1.7, 9.0)],
		["trex_tail_swipe", TRexBrain.State.TAIL_SWIPE, Vector3(-6.0, 1.7, 9.0)],
		["trex_roar", TRexBrain.State.ROAR, Vector3(4.0, 1.7, -6.0)]]
	for entry: Array in poses:
		boss.brain.force(entry[1])
		for i in 50:
			boss.skeleton.walk_phase += 0.05 if entry[1] == TRexBrain.State.CHARGE else 0.0
			boss._pose(DT, 0.0)
			await get_tree().physics_frame
		_aim(entry[2], boss.global_position + Vector3(0, 2.6, 0))
		await _shot(entry[0])
	# walking: the legs plant the feet
	boss.brain.force(TRexBrain.State.STALK)
	for i in 40:
		boss._walk_distance += 0.06
		boss.velocity = Vector3(0, 0, -3.5)
		boss._pose(DT, 0.0)
		await get_tree().physics_frame
	_aim(Vector3(7.0, 1.4, 2.5), boss.global_position + Vector3(0, 2.0, 0))
	await _shot("trex_walk")
	# the kill: the crystal bursts, the skeleton collapses into its bones
	boss.set_physics_process(true)
	var info := DamageInfo.make(5000.0, DamageInfo.Kind.BALLISTIC, dummy)
	info.position = boss.skeleton.crystal_position()
	info.direction = Vector3(0, 0, -1)
	boss.take_zone_damage(info, TRexBrain.Zone.CRYSTAL)
	_aim(Vector3(6.0, 2.2, 8.5), Vector3(0.0, 1.2, 1.0))
	await _seconds(0.5)
	await _shot("trex_dying")
	await _seconds(2.5)
	await _shot("trex_collapsed")
	var remains := _stage.get_node_or_null(^"TRexRemains")
	_log.append({"trex_remains_bodies": remains.get_child_count() if remains != null else 0})


# --- weapons ------------------------------------------------------------------

func _shots_weapons() -> void:
	player = Player.new()
	_stage.add_child(player)
	player.respawn(Vector3(0.5, 0.05, 12.5), 0.15)
	for id in [&"taser", &"pistol", &"shotgun"]:
		player.weapons.give(load("res://src/weapons/data/%s.tres" % id))
	player.camera.current = true
	await _frames(20)
	for id in [&"pistol", &"taser", &"shotgun"]:
		player.weapons.select_id(id)
		await _seconds(0.6)
		await _shot("vm_%s_idle" % id)
		player.weapons.try_fire()
		await _frames(2)
		await _shot("vm_%s_fire" % id)
		await _seconds(0.5)
		if id == &"taser":
			player.weapons.try_fire()
			await _seconds(0.6)
			await _shot("vm_taser_battery_low")
		else:
			player.weapons.state_of(id).magazine = 0
			player.weapons.try_reload()
			await _seconds(0.45)
			await _shot("vm_%s_reload" % id)
			await _seconds(1.5)
	player.weapons.select_id(&"pistol")
	await _seconds(0.6)
	player.weapons.try_punch()
	await _seconds(0.06)
	await _shot("vm_fists_punch")
	await _seconds(0.5)
	player.weapons.select_id(&"shotgun")
	_blackout(true)
	player.set_flashlight(true)
	await _seconds(0.6)
	await _shot("vm_shotgun_blackout")
	player.set_flashlight(false)
	_blackout(false)
	player.queue_free()
	player = null
	camera.current = true


# --- first-person animation poses (plan 2026-10-21-animacje-fpp) ------------
# Not in the default groups: --shots=fp. Each pose is caught at its moment
# and frozen (Engine.time_scale 0) for the shot.

func _shots_fp() -> void:
	player = Player.new()
	_stage.add_child(player)
	player.respawn(Vector3(0.5, 0.05, 12.5), 0.15)
	var holder := player.weapons
	for id in [&"pistol", &"shotgun", &"gatling", &"flare", &"rifle_hunt"]:
		holder.give(load("res://src/weapons/data/%s.tres" % id))
	player.camera.current = true
	holder.select_id(&"pistol")
	await _seconds(0.8)
	await _frozen_shot("fp_idle_pistol")
	# the switch: the pistol going down, the shotgun coming up
	holder.select_id(&"shotgun")
	await _until(func() -> bool: return holder._switch.lower(&"pistol") >= 0.5)
	await _frozen_shot("fp_switch_pistol_down")
	await _until(func() -> bool: return holder._switch.holstering().is_empty() and holder._switch.lower(&"shotgun") <= 0.45)
	await _frozen_shot("fp_switch_shotgun_up")
	await _seconds(0.6)
	# the run's carry per grip class
	for id in [&"pistol", &"shotgun", &"gatling"]:
		holder.select_id(id)
		await _seconds(0.9)
		Engine.time_scale = 0.0
		holder._sprint_pose = 1.0
		holder._sprint_pose_v = 0.0
		holder._bob_time = PI * 0.5
		await _shot("fp_sprint_%s" % id)
		holder._sprint_pose = 0.0
		Engine.time_scale = 1.0
	# reloads at their keyed moments
	for entry in [[&"pistol", 0.24, "tipped"], [&"pistol", 0.6, "seat"], [&"shotgun", 0.5, "open"], [&"shotgun", 0.84, "flick"], [&"flare", 0.5, "open"]]:
		var id: StringName = entry[0]
		holder.select_id(id)
		await _seconds(0.9)
		var state := holder.current_state()
		state.magazine = 0
		state.reserve = maxi(state.reserve, state.data.magazine_size * 2)
		holder.try_reload()
		var at: float = entry[1]
		await _until(func() -> bool: return state.is_reloading() and state.reload_progress() >= at)
		await _frozen_shot("fp_reload_%s_%s" % [id, entry[2]])
		await _until(func() -> bool: return not state.is_reloading())
	# blows at the hit, reaches at the hold
	for entry in [[&"pistol", "jab", ViewmodelGesture.JAB_HIT_AT], [&"shotgun", "bash", 0.17], [&"gatling", "shove", 0.17]]:
		holder.select_id(entry[0])
		await _seconds(0.9)
		holder.fists._cooldown = 0.0
		holder.try_punch()
		var hit: float = entry[2]
		await _until(func() -> bool: return holder._gesture.t >= hit)
		await _frozen_shot("fp_%s_%s" % [entry[1], entry[0]])
		await _seconds(0.5)
	for entry in [[&"pistol", 0.27], [&"shotgun", ViewmodelGesture.TWO_HAND_AT + 0.27]]:
		holder.select_id(entry[0])
		await _seconds(0.9)
		holder.reach()
		var hold: float = entry[1]
		await _until(func() -> bool: return holder._gesture.t >= hold)
		await _frozen_shot("fp_reach_%s" % entry[0])
		await _seconds(1.0)
	# the first look's two beats
	for id in [&"pistol", &"shotgun", &"gatling"]:
		holder.select_id(id)
		await _seconds(0.9)
		var rig := holder.view_of(id) as ViewmodelRig
		rig.look_over()
		var whole := rig.first_look_time()
		for beat in [0.4, 0.8]:
			await _until(func() -> bool: return rig.looking_over() <= whole * (1.0 - beat))
			await _frozen_shot("fp_look_%s_%d" % [id, roundi(beat * 10.0)])
		await _seconds(0.6)
	player.queue_free()
	player = null
	camera.current = true


## Steps frames until [param cond] holds (at most [param limit] s).
func _until(cond: Callable, limit: float = 4.0) -> void:
	var waited := 0.0
	while not cond.call() and waited < limit:
		await get_tree().process_frame
		waited += get_process_delta_time()


## A shot of the moment now, the game frozen for it.
func _frozen_shot(shot_name: String) -> void:
	Engine.time_scale = 0.0
	await _shot(shot_name)
	Engine.time_scale = 1.0


# --- props --------------------------------------------------------------------

func _shots_props() -> void:
	var base := Vector3(-1.5, 0.0, 10.8)
	var types := [Pickup.Type.BULLETS, Pickup.Type.SHELLS, Pickup.Type.MEDKIT]
	for i in types.size():
		var pickup := Pickup.new()
		pickup.type = types[i]
		pickup.position = base + Vector3(i * 0.9, 0.45, 0.0)
		_stage.add_child(pickup)
	var lantern := DroppedLantern.new()
	lantern.position = base + Vector3(3.0, 0.0, 0.3)
	_stage.add_child(lantern)
	for id in [&"pistol", &"shotgun"]:
		var weapon := WeaponPickup.make(id, base + Vector3(-1.8 if id == &"pistol" else 4.6, 0.0, -1.2))
		_stage.add_child(weapon)
	var values: Array[int] = [1, 1, 1, 1, 1, 1]
	DustMote.burst(_stage, base + Vector3(1.0, 1.0, 1.4), values, null)
	var terminal := UpgradeTerminal.new()
	terminal.position = Vector3(-3.2, 0.0, 9.0)
	terminal.rotation.y = PI * 0.8
	_stage.add_child(terminal)
	var bank := ArtLibrary.try_instance(&"cctv_bank")
	bank.position = Vector3(3.6, 0.0, 8.9)
	bank.rotation.y = -0.4
	_stage.add_child(bank)
	var locker := ArtLibrary.try_instance(&"pistol_locker")
	locker.position = Vector3(2.0, 0.9, 9.2)
	_stage.add_child(locker)
	PropArt.set_locker_open(locker, 0.8)
	var gun := Viewmodels.world(&"pistol")
	gun.rotation_degrees = Vector3(0, 90, 90)
	PropArt.locker_spot(locker).add_child(gun)
	for entry in [[&"fuse", Vector3(0.9, 0.3, 12.2)], [&"crystal_loose", Vector3(-0.5, 0.35, 12.3)]]:
		var item := ArtLibrary.pickup(entry[0])
		item.position = entry[1]
		_stage.add_child(item)
	await _seconds(1.2)
	_aim(Vector3(0.6, 1.5, 14.6), Vector3(0.6, 0.5, 10.4))
	await _shot("props_lit")
	_aim(Vector3(0.6, 1.2, 12.9), Vector3(0.2, 0.4, 10.8))
	await _shot("props_close")
	_blackout(true)
	flashlight.visible = true
	_aim(Vector3(0.6, 1.5, 14.6), Vector3(0.6, 0.5, 10.4))
	await _shot("props_blackout")
	_aim(Vector3(0.6, 1.6, 20.0), Vector3(0.6, 0.5, 10.4))
	flashlight.visible = false
	await _shot("props_blackout_far_dark")


# --- performance --------------------------------------------------------------

func _measure() -> void:
	Engine.max_fps = 0
	var results := {}
	# the first pass only warms up (shader and pipeline compilation)
	for run in [["warmup", true], ["greybox", false], ["models", true]]:
		var models: bool = run[1]
		ArtLibrary.models_enabled = models
		var crowd := Node3D.new()
		view.add_child(crowd)
		var guard := TargetDummy.new()
		guard.add_to_group(&"player")
		crowd.add_child(guard)
		var count := 0
		for ring in 3:
			for i in 10:
				var angle := TAU * i / 10.0 + ring * 0.3
				var enemy := NightSpawner.make([&"wax", &"wolf", &"knight"][(i + ring) % 3])
				enemy.position = Vector3(cos(angle) * (8.0 + ring * 3.0), 0.05, 4.0 + sin(angle) * (6.0 + ring * 2.0))
				enemy.target = guard
				crowd.add_child(enemy)
				count += 1
		await _frames(30)
		for enemy in crowd.get_children():
			if enemy is Enemy:
				(enemy as Enemy).brain.wake()
		_aim(Vector3(0, 1.7, 20.5), Vector3(0, 3.0, -6))
		await _frames(120)
		var start := Time.get_ticks_usec()
		var frames := 0
		var slowest := 0.0
		var last := start
		while Time.get_ticks_usec() - start < (2000000 if run[0] == "warmup" else 6000000):
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			slowest = maxf(slowest, (now - last) / 1000.0)
			last = now
			frames += 1
		var seconds := (Time.get_ticks_usec() - start) / 1000000.0
		var key: String = run[0]
		results[key] = {
			"exhibits": count,
			"average_fps": snappedf(frames / seconds, 0.1),
			"slowest_frame_ms": snappedf(slowest, 0.01),
			"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		}
		print("artint perf %s: %s" % [key, JSON.stringify(results[key])])
		await _shot("perf_%s" % key)
		crowd.queue_free()
		await _frames(10)
	ArtLibrary.models_enabled = true
	results["resolution"] = str(SIZE)
	results["vsync"] = DisplayServer.window_get_vsync_mode()
	var file := FileAccess.open(OUT_DIR.path_join("perf.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  "))
	file.close()


# --- staging helpers ----------------------------------------------------------

## Wax figure, wolf, knight and bust at [param spots], facing the camera
## side (+Z), awake, frozen for posing.
func _lineup(spots: Array[Vector3], look_at: Vector3 = Vector3.INF) -> Array[Enemy]:
	var out: Array[Enemy] = []
	var kinds := [&"wax", &"wolf", &"knight", &"bust"]
	for i in kinds.size():
		var enemy: Enemy = NightSpawner.make(kinds[i]) if kinds[i] != &"bust" else Bust.new()
		enemy.target = dummy
		enemy.position = spots[i]
		_stage.add_child(enemy)
		enemy.rotation.y = PI
		if look_at != Vector3.INF:
			enemy.face(look_at)
		out.append(enemy)
	await _frames(2)
	for enemy in out:
		enemy.set_physics_process(false)
		if enemy.rig != null:
			enemy.rig.set_physics_process(false)
		if enemy is Bust:
			enemy.global_position.y = spots[3].y + 1.6
	return out


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
		"windup":
			brain.state = EnemyBrain.State.ATTACK
			brain._timer = brain.windup * (1.0 - amount)
		"strike", "pounce":
			brain.state = EnemyBrain.State.ATTACK
			brain._struck = true
			brain._timer = brain.recovery
		"stunned":
			brain.state = EnemyBrain.State.STUNNED
	if pose == "pounce":
		enemy.global_position.y += 0.55
		enemy.velocity = Vector3(0, 1.5, 0)
		enemy.move_and_slide()
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


func _log_weak_points(lineup: Array[Enemy]) -> void:
	for enemy in lineup:
		if enemy.rig == null:
			continue
		for child in enemy.get_children():
			var zone := child as Hurtbox
			if zone != null and zone.weak_point:
				_log.append({"enemy": enemy.get_class(), "weak_point": str(zone.position), "tracked": str(enemy.rig.tracked_position(zone))})


func _blackout(on: bool) -> void:
	for group in [LightSpec.MAIN, StringName("%s_fixtures" % LightSpec.MAIN)]:
		for node in get_tree().get_nodes_in_group(group):
			(node as Node3D).visible = not on


## Removes the level's greybox pieces of [param kit] (the T-Rex stand-in).
func _hide_kit(kit: StringName) -> void:
	for child in level.find_children("*", "Node3D", true, false):
		if child.get_meta(&"kit", &"") == kit:
			child.queue_free()


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
