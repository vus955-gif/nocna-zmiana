extends Node
## Visual check of stage 2c-1 (not part of the headless suite). Loads the
## boss dev arena, stages the key moments of the T-Rex fight and the bust
## attack, saves screenshots to tests/_out/boss/ and a JSON log.
##   --mode=shots  1280x720 window, screenshots (bash tools/run_boss.sh --shots)
##   --mode=perf   project window, a busy fight, average/worst frame rate
##   --mode=dry    run with --headless: stages everything, captures nothing,
##                 prints which states each moment reached (logic check);
##                 --headless with --mode=perf checks the perf staging only

const OUT_DIR := "res://tests/_out/boss/"
const S := TRexBrain.State
## A run that has not finished after this many seconds (unscaled) is stuck:
## it quits with an error instead of keeping a window open.
const WATCHDOG_SECONDS := 120.0

var dev: BossDev
var _mode := "shots"
var _camera: Camera3D
var _dummy: TargetDummy
## Guard-sized capsule on the dummy, shown for the tail moment.
var _stand_in: MeshInstance3D
var _log: Array = []


func _ready() -> void:
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(_on_watchdog)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
	if DisplayServer.get_name() == "headless" and _mode != "perf":
		_mode = "dry"
	GameInput.capture_allowed = false
	if _mode == "shots":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	var out := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out)
	var ignore := FileAccess.open(ProjectSettings.globalize_path("res://tests/_out/.gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	dev = (load("res://src/enemies/trex/boss_dev.tscn") as PackedScene).instantiate() as BossDev
	add_child(dev)
	_camera = Camera3D.new()
	_camera.fov = 70.0
	add_child(_camera)
	_dummy = TargetDummy.new()
	add_child(_dummy)
	_stand_in = _make_stand_in()
	_stand_in.visible = false
	_dummy.add_child(_stand_in)
	# the guard only holds the camera here: he must survive every attack
	dev.player.health.max_health = 1000000.0
	dev.player.health.reset()
	await _seconds(1.0)   # shaders compile, the boss settles on its pedestal
	if _mode == "perf":
		await _perf()
	else:
		await _boss_moments()
		await _bust_moments()
	_write_log()
	Sfx.quit_cleanly(0)


func _boss_moments() -> void:
	# 1. the exhibit: asleep on its pedestal, in profile
	_player_view(Vector3(3.0, 1.7, 3.0), Vector3(0.5, 2.8, -11.0))
	await _shot("dormant")
	_free_view(Vector3(-15.0, 9.0, 17.0), Vector3(0.0, 1.5, -6.0))
	await _shot("overview")
	# 2. the crystal wakes it: roar on the pedestal
	dev.boss.wake()
	_player_view(Vector3(3.0, 1.7, 3.0), Vector3(0.5, 3.4, -11.0))
	await _seconds(0.8)
	await _shot("wake_roar")
	# 3. charge telegraph, facing the camera: head low, paw scraping, glow
	var boss := _fresh_boss(Vector3(0.0, 0.05, -6.0), 0.0)
	boss.rotation.y = PI   # facing south, toward the camera
	_dummy.global_position = Vector3(0.0, 0.0, 14.0)   # far enough to reach the south wall
	boss.target = _dummy
	boss.wake()
	boss.brain.force(S.STALK)
	boss.brain.charge_cooldown = 0.0
	_player_view(Vector3(-2.5, 1.7, 7.0), Vector3(0.0, 2.6, -5.0))
	await _until(func() -> bool: return boss.brain.state == S.CHARGE_WINDUP, 2.0, "charge windup")
	await _seconds(0.65)
	await _shot("charge_telegraph")
	# 4. the run, seen from the side
	_free_view(Vector3(11.0, 2.2, 3.0), Vector3(0.0, 2.2, 0.0))
	await _until(func() -> bool: return boss.brain.state == S.CHARGE, 1.5, "charge")
	await _seconds(0.35)
	await _shot("charge_run")
	# 5. into the south wall: stunned, ribs open, crystal pushed out
	if not await _until(func() -> bool: return boss.brain.state == S.STUNNED, 2.5, "stunned by the wall"):
		boss.brain.force(S.STUNNED)
	await _seconds(0.7)
	var chest := boss.skeleton.crystal_position()
	_player_view(chest + Vector3(5.0, 0.5, -1.0), chest)
	await _shot("stunned")
	# 6. tail: the guard behind it
	boss = _fresh_boss(Vector3(0.0, 0.05, 2.0), 0.0)
	_dummy.global_position = Vector3(1.0, 0.0, 6.2)   # in the tail's band
	_stand_in.visible = true
	boss.target = _dummy
	boss.wake()
	boss.brain.force(S.STALK)
	boss.brain.charge_cooldown = 99.0
	_free_view(Vector3(10.0, 3.0, 12.0), Vector3(0.0, 2.2, 4.0))
	await _until(func() -> bool: return boss.brain.state == S.TAIL_WINDUP, 1.0, "tail windup")
	await _seconds(0.45)
	await _shot("tail_windup")
	await _until(func() -> bool: return boss.brain.state == S.TAIL_SWIPE, 1.0, "tail swipe")
	# the frame the whip registers on the guard: a tail bone must touch him
	var hits := _dummy.hits.size()
	await _until(func() -> bool: return _dummy.hits.size() > hits, 0.3, "tail hit")
	var mode := boss.process_mode
	boss.process_mode = Node.PROCESS_MODE_DISABLED   # hold that frame still
	await _settle()
	await _shot("tail_hit")
	_free_view(_dummy.global_position + Vector3(0.0, 9.0, 0.3), _dummy.global_position)
	await _settle()
	await _shot("tail_hit_top")
	_free_view(Vector3(10.0, 3.0, 12.0), Vector3(0.0, 2.2, 4.0))
	boss.process_mode = mode
	await _seconds(0.12)
	await _shot("tail_swipe")
	_stand_in.visible = false
	# 7. phase 3: the roar brings the ceiling down around the guard
	boss = _fresh_boss(Vector3(0.0, 0.05, -4.0), PI)
	_player_view(Vector3(0.0, 1.7, 10.0), Vector3(0.0, 2.5, -4.0))
	boss.target = dev.player
	boss.wake()
	boss.brain.force(S.STALK)
	boss.brain.charge_cooldown = 99.0
	_hurt_crystal(boss, boss.health.current - boss.max_health * 0.3)
	_free_view(Vector3(7.0, 7.5, 17.0), Vector3(0.0, 0.0, 10.0))
	await _until(func() -> bool: return _count(DebrisDrop) > 0, 2.0, "debris markers")
	await _seconds(0.55)
	await _shot("debris")
	await _seconds(0.6)
	await _shot("debris_landed")
	# 8. death: the crystal bursts, the skeleton falls apart
	boss = _fresh_boss(Vector3(0.0, 0.05, -2.0), PI * 0.5)
	boss.target = _dummy
	_dummy.global_position = Vector3(-12.0, 0.0, -2.0)
	boss.wake()
	boss.brain.force(S.STALK)
	boss.brain.charge_cooldown = 99.0
	await _seconds(0.5)
	_player_view(Vector3(4.0, 1.7, 9.0), Vector3(0.0, 2.3, -2.5))
	_hurt_crystal(boss, boss.health.current + 10.0)
	_note("defeated", boss.is_dead())
	await _seconds(0.08)
	await _shot("death_crystal")
	await _seconds(0.5)
	await _shot("death_tremble")
	await _seconds(1.3)
	await _shot("death_collapse")
	var remains := dev.get_node_or_null(^"TRexRemains")
	_note("bone debris", remains.get_child_count() if remains != null else 0)


func _bust_moments() -> void:
	dev.reset_boss()
	dev.clear_exhibits()
	_player_view(Vector3(0.0, 1.7, 14.0), Vector3(0.0, 2.4, 4.0))
	var bust := dev.spawn_bust(Vector3(0.0, 0.1, 4.0), true)
	await _until(func() -> bool: return is_instance_valid(bust) and bust.brain.windup_progress() > 0.75, 3.0, "bust windup")
	var head := bust.global_position + Vector3.UP * bust.eye_height
	_player_view(Vector3(0.0, 1.7, 14.0), head)
	await _shot("bust_telegraph")
	await _until(func() -> bool: return _count(Projectile) > 0, 1.0, "shard fired")
	await _seconds(0.35)
	var shard := _first(Projectile) as Node3D
	var mid := shard.global_position if shard != null else head + Vector3(0, -0.5, 3)
	_free_view(mid + Vector3(3.5, 0.6, -1.0), mid + Vector3(0.0, 0.0, -0.6))
	await _shot("bust_shard")
	_player_view(Vector3(0.0, 1.7, 14.0), mid)
	await _shot("bust_shard_pov")
	# a close look at the bust itself
	var at := bust.global_position if is_instance_valid(bust) else Vector3(0, 1.7, 4)
	_free_view(at + Vector3(1.3, 0.9, -1.8), at + Vector3(0.0, 0.5, 0.0))
	await _shot("bust_close")


## A busy fight for the frame counter: the boss hunts the (unkillable)
## guard, three busts shoot, four wax figures close in, debris falls.
func _perf() -> void:
	dev.boss.wake()
	await _seconds(TRexBrain.WAKE_TIME)
	_hurt_crystal(dev.boss, dev.boss.max_health * 0.7)   # phase 3: every attack in play
	for at in BossDev.BUST_POINTS:
		dev.spawn_bust(at, true)
	dev.summon_wax(4)
	_player_view(Vector3(0.0, 1.7, 12.0), Vector3(0.0, 2.5, -4.0))
	await _seconds(1.0)
	var start := Time.get_ticks_usec()
	var last := start
	var frames := 0
	var worst := 0.0
	while Time.get_ticks_usec() - start < 6000000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		frames += 1
	var average := frames / ((Time.get_ticks_usec() - start) / 1000000.0)
	print("boss fight at %s: average %.0f FPS, worst frame %.1f ms" % [DisplayServer.window_get_size(), average, worst])
	_note("fps_average", snappedf(average, 0.1))
	_note("worst_frame_ms", snappedf(worst, 0.1))
	_note("window", str(DisplayServer.window_get_size()))


func _on_watchdog() -> void:
	print("MISSED: the %s run did not finish within %d s (watchdog)" % [_mode, int(WATCHDOG_SECONDS)])
	Sfx.quit_cleanly(1)


# --- staging helpers ----------------------------------------------------

## A guard-sized capsule (0.4 m radius, 1.8 m) that shows where the dummy
## target stands in the shots.
func _make_stand_in() -> MeshInstance3D:
	var capsule := CapsuleMesh.new()
	capsule.radius = TRex.GUARD_RADIUS
	capsule.height = TRex.GUARD_HEIGHT
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.45, 0.95)
	var view := MeshInstance3D.new()
	view.mesh = capsule
	view.material_override = material
	view.position.y = TRex.GUARD_HEIGHT * 0.5
	return view


func _fresh_boss(at: Vector3, yaw: float) -> TRex:
	var boss := dev.reset_boss()
	boss.position = at
	boss.rotation.y = yaw
	boss.reset_physics_interpolation()
	return boss


func _hurt_crystal(boss: TRex, amount: float) -> void:
	var info := DamageInfo.make(amount, DamageInfo.Kind.BALLISTIC, null)
	info.position = boss.skeleton.crystal_position()
	info.direction = Vector3.FORWARD
	boss.take_zone_damage(info, TRexBrain.Zone.CRYSTAL)


## The guard's own eyes (HUD included) at [param eye], looking at [param look].
func _player_view(eye: Vector3, look: Vector3) -> void:
	var guard := dev.player
	guard.global_position = eye - Vector3.UP * guard.eye_height
	guard.velocity = Vector3.ZERO
	guard.reset_physics_interpolation()
	var dir := (look - eye).normalized()
	guard.head.rotation = Vector3(asin(dir.y), atan2(-dir.x, -dir.z), 0.0)
	guard.head.global_position = eye
	guard.camera.current = true


## A free camera (the guard stays where he is).
func _free_view(eye: Vector3, look: Vector3) -> void:
	_camera.global_position = eye
	_camera.look_at(look)
	_camera.current = true


func _until(condition: Callable, timeout: float, label: String) -> bool:
	var waited := 0.0
	while waited < timeout:
		if condition.call():
			_note(label, true)
			return true
		await get_tree().physics_frame
		waited += 1.0 / Engine.physics_ticks_per_second
	var ok: bool = condition.call()
	_note(label, ok)
	if not ok:
		print("MISSED: ", label)
	return ok


func _seconds(duration: float) -> void:
	await get_tree().create_timer(duration, true, true).timeout


func _count(type: Variant) -> int:
	var total := 0
	for node in dev.get_children():
		if is_instance_of(node, type):
			total += 1
	for node in dev.exhibits.get_children():
		if is_instance_of(node, type):
			total += 1
	return total


func _first(type: Variant) -> Node:
	for node in dev.get_children() + dev.exhibits.get_children():
		if is_instance_of(node, type):
			return node
	return null


## A few frames for physics interpolation and the camera to catch up with
## a scene held still.
func _settle() -> void:
	for i in 3:
		await get_tree().process_frame


func _shot(label: String) -> void:
	if _mode == "dry":
		_note("shot " + label, "skipped (headless)")
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OUT_DIR.path_join("%s.png" % label)
	image.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _note(key: String, value: Variant) -> void:
	_log.append([key, value])
	if _mode == "dry":
		print("  %s: %s" % [key, value])


func _write_log() -> void:
	var entries := {}
	for entry in _log:
		entries[entry[0]] = entry[1]
	var file := FileAccess.open(OUT_DIR.path_join("%s.json" % _mode), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(entries, "  "))
		file.close()
