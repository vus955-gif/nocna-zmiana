extends Node
## The night visual QA (plan 2026-10-19-qa-wizualne; not part of the
## headless suite): the views no other scenario stages, in the real Floor I
## museum at night - the first-person weapons through the guard's own eyes
## (two-handed idles, the rifle's reload frame by frame, the shotgun's break,
## the gatling's crank, the secrets' finishes and mods), the east wings'
## enemies (totem, jaguar, Fu dog, samurai armour) asleep, waking, hunting,
## striking and breaking, the pickups at 5 / 10 / 15 m in the three light
## temperatures, the secrets' reward displays, the HUD's top edge (the
## longest guardian bars beside the longest goal at 1920x1080 and
## 1280x1024), the fire-arrow chest's sparks at the lens, the subtitle bar
## and the voice props.
##   bash tools/run_visual_qa.sh dry [--only=viewmodel,east]
##       no window (--headless --fixed-fps 60): stages every view, checks it
##       ("MISSED" when a moment did not happen, a camera stands outside the
##       rooms or in a wall, its subject is hidden), captures nothing
##       -> tests/_out/visual_qa/dry.json
##   bash tools/run_visual_qa.sh shots [--only=...] [--lang=pl]
##       silent 1920x1080 window: the same, each view saved as
##       tests/_out/visual_qa/<group>/<name>.png with its brightness
## Groups: viewmodel, looks, east, pickups, secrets, hud, voice, night (the
## window review of 22.10: the uncanny lamps of two rooms in every mode, a
## portrait's gaze, every env tool's tag from 10 and 20 m, its warning and
## its wreck, the biomes' devices before and after they act).

const OUT_DIR := "res://tests/_out/visual_qa/"
const WATCHDOG_SECONDS := 560.0
const Tour := preload("res://tests/scenarios/tour_scenario.gd")
const GROUPS: Array[String] = ["viewmodel", "looks", "east", "east_lit", "pickups", "secrets", "hud", "voice", "night"]
const HEAL := 1000000.0
## The security booth: out of every arena.
const BOOTH := Vector3(33.0, 0.0, 45.5)
const TWO_HANDED: Array[StringName] = [&"rifle_hunt", &"shotgun", &"harpoon", &"gatling", &"hwacha"]
## The rifle's reload sampled at these shares of its length.
const RIFLE_RELOAD: Array[float] = [0.08, 0.16, 0.24, 0.32, 0.42, 0.5, 0.56, 0.62, 0.68, 0.74, 0.8, 0.9]
## The three light temperatures of the pickups: [guard, look direction
## (flat), name]. Moon: the Great Court's west side under the glass roof;
## lamps: the King's Library's long axis; red: the basement's north ring
## corridor (red emergency lamps).
const LIGHTS := {
	"moon": [[Vector3(-24.0, 0.0, 26.0), Vector3(0.0, 0.0, -1.0)], [Vector3(-20.0, 0.0, 27.0), Vector3(0.0, 0.0, -1.0)],
		[Vector3(-27.0, 0.0, 22.0), Vector3(0.0, 0.0, -1.0)], [Vector3(-26.0, 0.0, 27.0), Vector3(1.0, 0.0, 0.0)]],
	"lamps": [[Vector3(44.0, 0.0, 20.0), Vector3(0.0, 0.0, -1.0)], [Vector3(43.0, 0.0, -20.0), Vector3(0.0, 0.0, 1.0)],
		[Vector3(12.0, 0.0, 27.0), Vector3(1.0, 0.0, 0.0)], [Vector3(38.0, 0.0, -20.5), Vector3(0.0, 0.0, 1.0)]],
	"red": [[Vector3(-8.0, -6.0, -36.25), Vector3(1.0, 0.0, 0.0)]],
}
const DISTANCES: Array[float] = [5.0, 10.0, 15.0]
const PICKUP_ORDER: Array[Pickup.Type] = [Pickup.Type.BULLETS, Pickup.Type.SHELLS, Pickup.Type.RIFLE, Pickup.Type.FLARES,
	Pickup.Type.HUNT_ROUNDS, Pickup.Type.HARPOONS, Pickup.Type.ROCKETS, Pickup.Type.MEDKIT]
## The east enemies' stages: label -> [kind, enemy spot, its yaw, guard far
## (hunting), guard near (striking), the room it must stand in]. The side
## camera is found round the spot (_side_camera). Group "east": in their
## own halls; "east_lit": the same four on the Great Court's moonlit floor
## (the Americas are greybox and the Asian halls dark: the models read
## there).
const EAST := {
	&"totem": [&"totem", Vector3(-19.5, 0.0, -46.5), PI, Vector3(-15.0, 0.0, -40.0), Vector3(-18.5, 0.0, -43.2), &"americas_north"],
	&"jaguar": [&"jaguar", Vector3(-17.5, 0.0, -54.0), PI, Vector3(-10.0, 0.0, -42.0), Vector3(-16.0, 0.0, -51.0), &"americas_north"],
	&"fu_dog": [&"fu_dog", Vector3(9.0, 0.0, -51.5), -PI * 0.75, Vector3(19.0, 0.0, -42.0), Vector3(11.5, 0.0, -49.0), &"asia_china"],
	&"samurai_armor": [&"samurai_armor", Vector3(33.5, 0.0, -66.0), -PI * 0.5, Vector3(45.0, 0.0, -66.0), Vector3(36.0, 0.0, -66.0), &"asia_armor"],
}
const EAST_LIT := {
	&"lit_totem": [&"totem", Vector3(-22.0, 0.0, 8.0), PI, Vector3(-22.0, 0.0, 20.0), Vector3(-22.0, 0.0, 12.0), &"court"],
	&"lit_jaguar": [&"jaguar", Vector3(-22.0, 0.0, 6.0), PI, Vector3(-22.0, 0.0, 20.0), Vector3(-22.0, 0.0, 10.5), &"court"],
	&"lit_fu_dog": [&"fu_dog", Vector3(-22.0, 0.0, 6.0), PI, Vector3(-22.0, 0.0, 20.0), Vector3(-22.0, 0.0, 10.5), &"court"],
	&"lit_samurai_armor": [&"samurai_armor", Vector3(-22.0, 0.0, 8.0), PI, Vector3(-22.0, 0.0, 20.0), Vector3(-22.0, 0.0, 11.0), &"court"],
}

var museum: Museum
var camera: Camera3D
var _mode := "shots"
var _dry := false
var _lang := "en"
var _only: PackedStringArray = []
var _group := ""
var _log: Array = []
var _missed: int = 0
var _build_ms: int = 0
## The night group: the free camera stays current between its views (the
## room culling follows the current camera: back in the guard's, far off in
## the booth, the rooms watched would go dark).
var _keep_free_camera := false


func _ready() -> void:
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(_on_watchdog)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",", false)
		elif arg.begins_with("--lang="):
			_lang = arg.trim_prefix("--lang=")
	_dry = DisplayServer.get_name() == "headless"
	if _dry:
		_mode = "dry"
	GameInput.capture_allowed = false
	if not _dry:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
	Settings.set_value(&"graphics_quality", GraphicsQuality.Quality.HIGH, false)
	Settings.set_value(&"language", _lang, false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ignore := FileAccess.open(ProjectSettings.globalize_path("res://tests/_out/.gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.05
	camera.far = 300.0
	add_child(camera)
	await _open()
	for group in GROUPS:
		if not _wanted(group) and not (group == "night" and _night_part("")):
			continue
		_group = group
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR.path_join(group)))
		match group:
			"viewmodel":
				await _viewmodels()
			"looks":
				await _looks()
			"east":
				await _east(EAST)
			"east_lit":
				await _east(EAST_LIT)
			"pickups":
				await _pickups()
			"secrets":
				await _secrets()
			"hud":
				await _hud()
			"voice":
				await _voice()
			"night":
				await _night()
	var file := FileAccess.open(OUT_DIR.path_join("dry.json" if _dry else "metrics.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"build_ms": _build_ms, "lang": _lang, "shots": _log}, "  "))
		file.close()
	print("visual qa %s: %d views, %d missed, museum built in %d ms" % [_mode, _log.size(), _missed, _build_ms])
	Sfx.quit_cleanly(1 if _missed > 0 else 0)


func _on_watchdog() -> void:
	print("MISSED: the visual QA scenario did not finish in time")
	Sfx.quit_cleanly(1)


func _wanted(group: String) -> bool:
	return _only.is_empty() or _only.has(group)


## A new game on night 1 in Floor I with the art; the guard armed with every
## weapon, pockets full; the exhibits asleep and held (no wandering into the
## views) until a group wakes its own.
func _open() -> void:
	Museum.level_id = &"floor1"
	MuseumFloorLevel.dress_default = true
	GameState.new_game()
	GameState.night = 1
	RunState.reset()
	var started := Time.get_ticks_msec()
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	_build_ms = Time.get_ticks_msec() - started
	print("museum built in %d ms" % _build_ms)
	var guard := museum.player
	for id in WeaponHolder.SLOT_ORDER:
		var data := load("res://src/weapons/data/%s.tres" % id) as WeaponData
		if data != null:
			guard.weapons.give(data)
	_fill_pockets()
	guard.weapons.select_id(&"pistol")
	guard.health.heal(HEAL)
	if museum.onboarding != null:
		museum.onboarding.process_mode = Node.PROCESS_MODE_DISABLED
	museum.enemies_root.process_mode = Node.PROCESS_MODE_DISABLED
	await _seconds(2.5)   # shaders, SDFGI, fog history, probes
	await _clear_cards()


func _fill_pockets() -> void:
	for state in museum.player.weapons.owned:
		state.magazine = state.data.magazine_size
		state.reserve = state.data.max_reserve


# --- 1. the first-person weapons -------------------------------------------------------

## The court's west side looking north across the moonlit floor: a calm,
## mid-grey background for the hands.
const VM_STAND := Vector3(-20.0, 0.0, 22.0)
const VM_LOOK := Vector3(-20.0, 1.2, 0.0)


func _viewmodels() -> void:
	var guard := museum.player
	_put_guard(VM_STAND, VM_LOOK)
	await _clear_cards()
	for id in TWO_HANDED:
		await _draw(id)
		await _shot("vm_%s_idle" % id, _rig(id) != null)
	# the rifle's reload, frame by frame (the owner: "a floating clip")
	await _draw(&"rifle_hunt")
	var rifle := guard.weapons.state_of(&"rifle_hunt")
	rifle.magazine = 0
	var reloading := guard.weapons.try_reload()
	for share in RIFLE_RELOAD:
		await _until(func() -> bool: return not rifle.is_reloading() or rifle.reload_progress() >= share, 3.0)
		var rig := _rig(&"rifle_hunt")
		await _shot("vm_rifle_reload_%02d" % roundi(share * 100.0), reloading and rifle.is_reloading(),
				{"progress": snappedf(rifle.reload_progress(), 0.01), "clip_held": rig.clip_held() if rig != null else false})
	await _until(func() -> bool: return not rifle.is_reloading(), 3.0)
	await _seconds(0.12)
	await _shot("vm_rifle_reload_bolt_home", not rifle.is_reloading())
	await _seconds(0.5)
	await _shot("vm_rifle_after_reload", not rifle.is_reloading())
	# the rifle's bolt cycle after a shot
	_look_at(VM_LOOK + Vector3.UP * 2.0)
	var fired := await _fire(&"rifle_hunt")
	await _seconds(0.25)
	await _shot("vm_rifle_bolt_cycle", fired)
	# the shotgun's break
	await _draw(&"shotgun")
	var shotgun := guard.weapons.state_of(&"shotgun")
	await _fire(&"shotgun")
	await _seconds(0.35)
	await _fire(&"shotgun")
	await _seconds(0.3)
	var broke := guard.weapons.try_reload() or shotgun.is_reloading()
	for share: float in [0.25, 0.5, 0.8]:
		await _until(func() -> bool: return not shotgun.is_reloading() or shotgun.reload_progress() >= share, 3.0)
		await _shot("vm_shotgun_break_%02d" % roundi(share * 100.0), broke and shotgun.is_reloading(), {"progress": snappedf(shotgun.reload_progress(), 0.01)})
	await _until(func() -> bool: return not shotgun.is_reloading(), 3.0)
	# the harpoon gun's reload
	await _draw(&"harpoon")
	var harpoon := guard.weapons.state_of(&"harpoon")
	await _fire(&"harpoon")
	await _seconds(0.4)
	var loading := guard.weapons.try_reload() or harpoon.is_reloading()
	for share: float in [0.3, 0.7]:
		await _until(func() -> bool: return not harpoon.is_reloading() or harpoon.reload_progress() >= share, 4.0)
		await _shot("vm_harpoon_reload_%02d" % roundi(share * 100.0), loading and harpoon.is_reloading(), {"progress": snappedf(harpoon.reload_progress(), 0.01)})
	await _until(func() -> bool: return not harpoon.is_reloading(), 4.0)
	# the gatling's crank turning (two moments of a burst)
	await _draw(&"gatling")
	await _hold_fire(&"gatling", 0.9)
	await _shot("vm_gatling_crank_a", true, {"spun_up": guard.weapons.state_of(&"gatling").spun_up()})
	await _hold_fire(&"gatling", 0.13)
	await _shot("vm_gatling_crank_b", true)
	await _seconds(1.2)
	# the fire-arrow chest reloading its tubes
	await _draw(&"hwacha")
	var chest := guard.weapons.state_of(&"hwacha")
	await _fire(&"hwacha")
	await _seconds(1.0)
	var refilling := guard.weapons.try_reload() or chest.is_reloading()
	await _until(func() -> bool: return not chest.is_reloading() or chest.reload_progress() >= 0.5, 5.0)
	await _shot("vm_hwacha_reload_50", refilling and chest.is_reloading(), {"progress": snappedf(chest.reload_progress(), 0.01)})
	await _until(func() -> bool: return not chest.is_reloading(), 6.0)
	# the widest field of view the options allow: the frame's edges
	Settings.set_value(&"fov", SettingsData.FOV_MAX, false)
	await _seconds(0.3)
	for id: StringName in [&"rifle_hunt", &"shotgun"]:
		await _draw(id)
		await _shot("vm_%s_idle_fov_max" % id, _rig(id) != null, {"fov": guard.camera.fov})
	await _draw(&"rifle_hunt")
	rifle.magazine = 0
	reloading = guard.weapons.try_reload() or rifle.is_reloading()
	for share: float in [0.24, 0.62]:
		await _until(func() -> bool: return not rifle.is_reloading() or rifle.reload_progress() >= share, 3.0)
		await _shot("vm_rifle_reload_%02d_fov_max" % roundi(share * 100.0), reloading and rifle.is_reloading())
	await _until(func() -> bool: return not rifle.is_reloading(), 3.0)
	Settings.set_value(&"fov", SettingsData.new().fov, false)
	await _seconds(0.3)
	_fill_pockets()


## The secrets' finishes and mods on the first-person models: every weapon in
## its finish under the moon and under the lamps; the three mods' parts in
## idle and mid-reload.
func _looks() -> void:
	var guard := museum.player
	var levels := {}
	for look: StringName in WeaponLook.LOOKS:
		levels[WeaponLook.look_key((WeaponLook.LOOKS[look] as Dictionary)["weapon"], look)] = 1
	for mod: StringName in WeaponLook.MODS:
		levels[WeaponLook.mod_key(mod)] = 1
	guard.apply_upgrades(levels)
	var stands := {"moon": [VM_STAND, VM_LOOK], "lamps": [Vector3(38.0, 0.0, -16.0), Vector3(38.0, 1.4, 6.0)]}
	for light: String in stands:
		_put_guard(stands[light][0], stands[light][1])
		await _clear_cards()
		for look: StringName in WeaponLook.LOOKS:
			var id: StringName = (WeaponLook.LOOKS[look] as Dictionary)["weapon"]
			await _draw(id, ViewmodelRig.INSPECT_TIME + 0.4)
			var rig := _rig(id)
			await _shot("look_%s_%s_%s" % [light, look, id], rig != null and rig.look() == look, {"look": String(rig.look()) if rig != null else ""})
	_put_guard(VM_STAND, VM_LOOK)
	for mod: StringName in WeaponLook.MODS:
		var id: StringName = (WeaponLook.MODS[mod] as Dictionary)["weapon"]
		await _draw(id, ViewmodelRig.INSPECT_TIME + 0.4)
		var rig := _rig(id)
		var part := rig.part_node(StringName((WeaponLook.MODS[mod] as Dictionary)["part"])) if rig != null else null
		await _shot("mod_%s_idle" % mod, part != null and part.is_visible_in_tree())
		var state := guard.weapons.state_of(id)
		if id != &"rifle_hunt":
			await _fire(id)
			await _seconds(0.45)
		else:
			state.magazine = 0
		var reloading := guard.weapons.try_reload() or state.is_reloading()
		await _until(func() -> bool: return not state.is_reloading() or state.reload_progress() >= 0.55, 4.0)
		await _shot("mod_%s_reload" % mod, reloading and state.is_reloading() and part != null and part.is_visible_in_tree())
		await _until(func() -> bool: return not state.is_reloading(), 4.0)
	# the inspection's glint on a freshly bought part (the peep sight)
	guard.apply_upgrades({})
	await _draw(&"pistol")
	guard.apply_upgrades(levels)
	await _draw(&"rifle_hunt", ViewmodelRig.GLINT_AT * ViewmodelRig.INSPECT_TIME)
	var inspecting := _rig(&"rifle_hunt")
	await _shot("mod_rifle_peep_inspect_glint", inspecting != null and inspecting.inspecting() > 0.0)
	await _seconds(1.5)
	guard.apply_upgrades({})
	_fill_pockets()


func _rig(id: StringName) -> ViewmodelRig:
	return museum.player.weapons.view_of(id) as ViewmodelRig


## Weapon [param id] in hand and settled (the draw over).
func _draw(id: StringName, settle: float = 0.75) -> void:
	museum.player.weapons.select_id(id)
	await _seconds(settle)


func _hold_fire(id: StringName, seconds: float) -> void:
	var weapons := museum.player.weapons
	if weapons.current_state() == null or weapons.current_state().data.id != id:
		await _draw(id)
	var left := seconds
	while left > 0.0:
		weapons.try_fire()
		await get_tree().physics_frame
		left -= 1.0 / Engine.physics_ticks_per_second


# --- 2. the east wings' enemies ---------------------------------------------------------

func _east(stages: Dictionary) -> void:
	var guard := museum.player
	museum.enemies_root.process_mode = Node.PROCESS_MODE_INHERIT
	guard.weapons.visible = false
	for label: StringName in stages:
		var stage: Array = stages[label]
		var kind: StringName = stage[0]
		var at: Vector3 = stage[1]
		var far: Vector3 = stage[3]
		var near: Vector3 = stage[4]
		var room: StringName = stage[5]
		# the room's own sleepers (and anything left of the last stage) out of the views
		for exhibit in museum.exhibits():
			if exhibit.global_position.distance_to(at) < 16.0:
				exhibit.queue_free()
		Fx.clear()
		await _frames(2)
		_put_guard(far, at + Vector3.UP * 1.2)
		var enemy := NightSpawner.make(kind)
		enemy.position = at + Vector3.UP * 0.05
		enemy.rotation.y = stage[2]
		enemy.target = guard
		museum._tune_exhibit(enemy)
		museum.enemies_root.add_child(enemy)
		await _seconds(0.6)
		var subject := func() -> Vector3: return enemy.global_position + Vector3.UP * 1.1 if is_instance_valid(enemy) else at
		var in_room: bool = museum.floor_level.room_at(at + Vector3.UP * 0.5) == room
		var side := _side_camera(at, far, room)
		await _view("%s_asleep" % label, _eye(far), subject.call(), in_room, _east_state(enemy))
		await _view("%s_asleep_side" % label, side, subject.call(), in_room, _east_state(enemy))
		enemy.summoned = true
		enemy.brain.wake()
		await _seconds(0.3)
		await _view("%s_waking" % label, side, subject.call(), enemy.brain.is_awake(), _east_state(enemy))
		await _seconds(1.0)
		await _view("%s_awake" % label, side, subject.call(), enemy.brain.is_awake(), _east_state(enemy))
		# hunting him from across the hall: four looks a quarter second apart
		for i in 4:
			_put_guard(far, subject.call())
			await _seconds(0.3)
			var hunting: Vector3 = subject.call()
			await _view("%s_hunt_%d" % [label, i], _side_camera(hunting - Vector3.UP * 1.1, far, room), hunting.lerp(_eye(far), 0.25), is_instance_valid(enemy), _east_state(enemy))
			# the jaguar on all fours from its side, at its height: its paws on the floor
			if enemy is Jaguar and is_instance_valid(enemy) and (enemy as Jaguar).sprinting():
				var body := enemy.global_position
				var beside := _beside(body, Vector3(enemy.velocity.x, 0.0, enemy.velocity.z))
				if beside != Vector3.INF:
					await _view("%s_sprint_side_%d" % [label, i], beside, body + Vector3.UP * 0.4, true, _east_state(enemy))
		# up close: its attack, frame by frame (the guard put there once, then
		# only turned to it: put every frame he would stand inside it)
		var struck := false
		_put_guard(near, subject.call())
		for i in 8:
			_look_at(subject.call())
			await _seconds(0.22)
			if is_instance_valid(enemy) and enemy.brain.state == EnemyBrain.State.ATTACK:
				struck = true
			var striking: Vector3 = subject.call()
			if i == 0:
				side = _side_camera(striking - Vector3.UP * 1.1, near, room)
			await _view("%s_attack_%d" % [label, i], side, striking.lerp(_eye(near), 0.4), is_instance_valid(enemy), _east_state(enemy))
		if not struck:
			print("note: %s did not attack in its close frames" % kind)
		# from the guard's eyes: what he sees of its telegraph
		museum.player.weapons.visible = true
		guard.weapons.select_id(&"shotgun")
		await _seconds(0.5)
		_look_at(subject.call())
		await _shot("%s_guard_view" % label, is_instance_valid(enemy), _east_state(enemy))
		museum.player.weapons.visible = false
		# broken: the lethal blow and its pieces
		var spot: Vector3 = enemy.global_position if is_instance_valid(enemy) else at
		var hits := 0
		while is_instance_valid(enemy) and not enemy.health.is_dead() and hits < 8:
			var blow := DamageInfo.make(enemy.health.current + 1.0, DamageInfo.Kind.BALLISTIC, guard)
			blow.position = enemy.global_position + Vector3.UP * 1.0
			blow.direction = (enemy.global_position - guard.global_position).normalized()
			enemy.take_damage(blow)
			hits += 1
			await _frames(1)
		side = _side_camera(spot, guard.global_position, room, 0.4)
		await _seconds(0.12)
		await _view("%s_break_a" % label, side, spot + Vector3.UP * 0.9, hits > 0)
		await _seconds(0.7)
		await _view("%s_break_b" % label, side, spot + Vector3.UP * 0.5, hits > 0)
		await _seconds(1.5)
		await _view("%s_break_c" % label, side, spot + Vector3.UP * 0.4, hits > 0)
		if is_instance_valid(enemy):
			enemy.queue_free()
		_put_guard(BOOTH, BOOTH + Vector3(-5.0, 1.5, 0.0))
		await _seconds(0.3)
	guard.weapons.visible = true
	museum.enemies_root.process_mode = Node.PROCESS_MODE_DISABLED


## A free camera beside the line from [param at] to [param guard] (to its
## left or right, 6 to 3 m out, a step toward the guard), out of the walls,
## the spot in its sight, in [param room] if any such place is (else in
## any room): the first that is.
func _side_camera(at: Vector3, guard: Vector3, room: StringName = &"", height: float = 1.1) -> Vector3:
	var space := get_viewport().find_world_3d().direct_space_state
	var toward := guard - at
	toward.y = 0.0
	toward = toward.normalized()
	var across := toward.cross(Vector3.UP)
	var subject := at + Vector3.UP * height
	for same_room: bool in [true, false]:
		for reach: float in [6.0, 5.0, 4.0, 3.2]:
			for side: float in [1.0, -1.0]:
				for lead: float in [1.5, 3.0, 0.0]:
					var eye := at + across * side * reach + toward * lead + Vector3.UP * 1.6
					var in_room := museum.floor_level.room_at(eye)
					if in_room == &"" or (same_room and room != &"" and in_room != room):
						continue
					var point := PhysicsPointQueryParameters3D.new()
					point.position = eye
					point.collision_mask = Layers.WORLD
					if not space.intersect_point(point).is_empty():
						continue
					if space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, subject, Layers.WORLD)).is_empty():
						return eye
	return _eye(guard)


## A free camera 2.4-3.2 m to the side of [param body] (moving along
## [param heading]), 0.8 m up, out of the walls, the body in its sight;
## Vector3.INF when neither side has room.
func _beside(body: Vector3, heading: Vector3) -> Vector3:
	var space := get_viewport().find_world_3d().direct_space_state
	var across := heading.normalized().cross(Vector3.UP) if heading.length() > 0.1 else Vector3.RIGHT
	for reach: float in [2.4, 3.2]:
		for side: float in [1.0, -1.0]:
			var eye := body + across * side * reach + heading.normalized() * 0.6 + Vector3.UP * 0.8
			if museum.floor_level.room_at(eye) == &"":
				continue
			var point := PhysicsPointQueryParameters3D.new()
			point.position = eye
			point.collision_mask = Layers.WORLD
			if not space.intersect_point(point).is_empty():
				continue
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, body + Vector3.UP * 0.4, Layers.WORLD)).is_empty():
				return eye
	return Vector3.INF


func _east_state(enemy: Enemy) -> Dictionary:
	if not is_instance_valid(enemy):
		return {"enemy": "gone"}
	var out := {"state": EnemyBrain.State.keys()[enemy.brain.state], "health": snappedf(enemy.health.current, 1.0),
		"distance": snappedf(enemy.global_position.distance_to(museum.player.global_position), 0.1),
		"windup": snappedf(enemy.brain.windup_progress(), 0.01)}
	if enemy is Jaguar:
		out["sprinting"] = (enemy as Jaguar).sprinting()
		out["leaping"] = (enemy as Jaguar).leaping()
	elif enemy is FuDog:
		out["charging"] = (enemy as FuDog).charging()
		out["pearl"] = snappedf((enemy as FuDog).pearl_glow(), 0.01)
	elif enemy is Totem:
		out["faces"] = (enemy as Totem).faces_now()
		out["firing"] = (enemy as Totem).firing_face()
	return out


# --- 3. the pickups at 5 / 10 / 15 m in the three lights ---------------------------------

func _pickups() -> void:
	var guard := museum.player
	guard.weapons.select_id(&"pistol")
	for light: String in LIGHTS:
		var place: Array = _row_place(LIGHTS[light])
		var stand: Vector3 = place[0]
		var ahead: Vector3 = (place[1] as Vector3).normalized()
		var across := ahead.cross(Vector3.UP).normalized()
		_put_guard(stand, stand + ahead * 10.0 + Vector3.UP * 1.0)
		await _clear_cards()
		for distance in DISTANCES:
			var centre := stand + ahead * distance
			var spacing := _row_spacing(centre, across)
			var row: Array[Pickup] = []
			var floor_ok := true
			for i in PICKUP_ORDER.size():
				var spot := centre + across * spacing * (i - (PICKUP_ORDER.size() - 1) * 0.5)
				var y := _floor_at(spot)
				if is_nan(y):
					floor_ok = false
					y = spot.y
				var pickup := Pickup.new()
				pickup.type = PICKUP_ORDER[i]
				pickup.respawn_time = 0.0
				pickup.position = Vector3(spot.x, y, spot.z)
				museum.add_child(pickup)
				row.append(pickup)
			_put_guard(stand, centre + Vector3.UP * 0.3)
			await _seconds(0.4)
			var sights: Array[Vector3] = [row[0].global_position + Vector3.UP * 0.25, row[row.size() - 1].global_position + Vector3.UP * 0.25]
			# the row with the gun out of the picture (it hides the right half),
			# then once as he sees it, the pistol in hand
			guard.weapons.visible = false
			await _shot("pickups_%s_%02dm" % [light, roundi(distance)], floor_ok and _all_active(row),
					{"spacing": snappedf(spacing, 0.01), "room": String(museum.floor_level.room_at(centre + Vector3.UP * 0.5))}, sights)
			guard.weapons.visible = true
			if distance == DISTANCES[1]:
				await _shot("pickups_%s_%02dm_in_hand" % [light, roundi(distance)], _all_active(row))
			if distance == DISTANCES[0]:
				# the slot digits and the inventory tags from two and a half metres
				_put_guard(centre - ahead * 2.5 + across * spacing * 1.5, centre + across * spacing * 1.5 + Vector3.UP * 0.1)
				await _seconds(0.3)
				guard.weapons.visible = false
				await _shot("pickups_%s_close_left" % light, _all_active(row))
				_put_guard(centre - ahead * 2.5 - across * spacing * 1.5, centre - across * spacing * 1.5 + Vector3.UP * 0.1)
				await _seconds(0.3)
				await _shot("pickups_%s_close_right" % light, _all_active(row))
				guard.weapons.visible = true
			for pickup in row:
				pickup.queue_free()
			await _frames(2)
		if light == "red":
			pass


## The first of [param places] ([guard, ahead]) from which the rows at every
## distance stand in the guard's clear sight end to end (the last if none).
func _row_place(places: Array) -> Array:
	var space := get_viewport().find_world_3d().direct_space_state
	for place: Array in places:
		var stand: Vector3 = place[0]
		var ahead: Vector3 = (place[1] as Vector3).normalized()
		var across := ahead.cross(Vector3.UP).normalized()
		var eye := stand + Vector3.UP * museum.player.eye_height
		var clear := museum.floor_level.room_at(eye) != &""
		for distance in DISTANCES:
			var centre := stand + ahead * distance
			var spacing := _row_spacing(centre, across)
			for end: float in [-1.0, 1.0]:
				var spot := centre + across * spacing * (PICKUP_ORDER.size() - 1) * 0.5 * end
				var y := _floor_at(spot)
				if is_nan(y) or absf(y - stand.y) > 0.3:
					clear = false
					continue
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, Vector3(spot.x, y + 0.25, spot.z), Layers.WORLD))
				if not hit.is_empty():
					clear = false
		if clear:
			return place
	return places[places.size() - 1]


## The spacing of a row of the eight across [param across] at [param centre]
## that fits the room there, centred on it (rays to the nearer wall at knee
## height), 0.45-0.9 m.
func _row_spacing(centre: Vector3, across: Vector3) -> float:
	var space := get_viewport().find_world_3d().direct_space_state
	var from := centre + Vector3.UP * (0.5 + (0.0 if is_nan(_floor_at(centre)) else _floor_at(centre) - centre.y))
	var half := 6.0
	for direction: Vector3 in [across, -across]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + direction * 6.0, Layers.WORLD))
		if not hit.is_empty():
			half = minf(half, from.distance_to(hit["position"]))
	return clampf((half * 2.0 - 1.0) / float(PICKUP_ORDER.size() - 1), 0.45, 0.9)


func _all_active(row: Array[Pickup]) -> bool:
	for pickup in row:
		if not is_instance_valid(pickup) or not pickup.active:
			return false
	return true


## The floor's height under [param at] (a ray down from 1.5 m over it), or NAN.
func _floor_at(at: Vector3) -> float:
	var space := get_viewport().find_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.5, at + Vector3.DOWN * 3.0, Layers.WORLD))
	return NAN if hit.is_empty() else (hit["position"] as Vector3).y


# --- 4. the secrets' reward displays -------------------------------------------------------

func _secrets() -> void:
	var world := museum.floor_game.world
	museum.player.weapons.visible = false
	var shown_tiers := {}
	var ids: Array = world.rewards.keys()
	ids.sort()
	for id: StringName in ids:
		var display := world.rewards[id] as SecretRewardDisplay
		if display == null:
			continue
		world.discover_secret(id)
		if not display.lit:
			display.reveal(true)
		var at := display.global_transform
		var front := -at.basis.z
		front.y = 0.0
		front = front.normalized()
		var subject := at.origin + Vector3.UP * (0.35 if display.tier == SecretRewards.Tier.SMALL else 1.0)
		# from the threshold side: as far out as the room allows, up to 3.2 m
		var ground := at.origin.y
		var eye := _clear_point(subject, ground, front, 3.2, 1.65)
		await _seconds(0.05)
		var ok: bool = display.visible and display.lit and museum.floor_level.room_at(eye) != &""
		var extra := {"tier": SecretRewards.Tier.keys()[display.tier], "room": String(museum.floor_level.room_at(at.origin + Vector3.UP * 0.5)),
			"back_off_m": snappedf(eye.distance_to(subject), 0.1)}
		if not shown_tiers.has(display.tier):
			await _seconds(SecretRewardDisplay.REVEAL_TIME + 0.2)   # the lid up, the reflector on
		await _view("secret_%s" % id, eye, subject, ok, extra)
		if not shown_tiers.has(display.tier):
			shown_tiers[display.tier] = true
			# up close: the plaque from 1.4 m, the strongbox's lid from its side
			await _view("secret_%s_close" % id, _clear_point(subject, ground, front, 1.4, 1.35), subject, ok)
			await _view("secret_%s_side" % id, _clear_point(subject, ground, at.basis.x.normalized(), 1.6, 1.2), subject, ok)
			display.interact(museum.player)
			await _seconds(0.2)
			await _view("secret_%s_taken" % id, eye, subject, display.is_taken)
	museum.player.weapons.visible = true


## A point [param reach] m from [param subject] along [param direction]
## (eye at [param height] over [param ground], lower under a low ceiling),
## drawn in so no wall stands between: a camera that keeps in the room.
func _clear_point(subject: Vector3, ground: float, direction: Vector3, reach: float, height: float) -> Vector3:
	var space := get_viewport().find_world_3d().direct_space_state
	var from := Vector3(subject.x, ground + height, subject.z)
	for h: float in [height, 1.25, 0.95]:
		from = Vector3(subject.x, ground + h, subject.z)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + direction * reach, Layers.WORLD))
		var length := reach if hit.is_empty() else maxf(from.distance_to(hit["position"]) - 0.3, 0.6)
		var eye := from + direction * length
		if museum.floor_level.room_at(eye) != &"":
			return eye
	return from + direction * 0.6


# --- 5. the HUD's top edge, the fire-arrow sparks at the lens --------------------------------

func _hud() -> void:
	var guard := museum.player
	var keeper := museum.floor_game.guardians
	guard.weapons.select_id(&"pistol")
	_put_guard(Vector3(-12.0, 0.0, 26.0), Vector3(-12.0, 3.0, 0.0))
	await _clear_cards()
	var goal := _longest_goal()
	for size: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 1024)]:
		if not _dry:
			DisplayServer.window_set_size(size)
		await _frames(6)
		var tag := "%dx%d" % [size.x, size.y]
		museum.hud.set_objective(goal)
		museum.hud.set_fuses(1, 2)
		museum.hud.set_shards(3, Floor1Plan.SHARD_COUNT)
		await _frames(3)
		await _shot("hud_goal_no_bar_%s" % tag, not museum.hud.boss_bar_shown())
		for id: StringName in _longest_guardians(keeper):
			var guardian := keeper.guardians[id] as Guardian
			Events.guardian_awakened.emit(guardian, id)
			museum.hud.set_objective(goal)
			await _frames(4)
			var goals := museum.hud._night_box.get_global_rect()
			var bar := museum.hud._boss_box.get_global_rect()
			await _shot("hud_bar_%s_%s" % [id, tag], museum.hud.boss_bar_shown() and not goals.intersects(bar),
					{"bar": museum.hud.boss_name_text(), "goal_lines": museum.hud._objective_label.get_line_count()})
			museum.hud._boss_box.visible = false
			museum.hud._release_boss()
	if not _dry:
		DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _frames(6)
	# the fire-arrow chest's volley leaving at the lens: four frames of it
	guard.weapons.select_id(&"hwacha")
	_put_guard(Vector3(-20.0, 0.0, 20.0), Vector3(-20.0, 2.0, 5.0))
	await _seconds(0.8)
	var fired := await _fire(&"hwacha")
	var since := 0.0
	for at: float in [0.05, 0.1, 0.2, 0.35]:
		await _seconds(at - since)
		since = at
		await _shot("hud_firechest_sparks_%03d" % roundi(at * 1000.0), fired, {"rockets": _all("HwachaRocket").size()})
	await _seconds(2.0)
	_fill_pockets()


## The Floor I / night goal with the widest text in the language now.
func _longest_goal() -> String:
	var font := UiTheme.strong_font()
	var best := ""
	var best_w := 0.0
	var file := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	file.get_csv_line()
	while not file.eof_reached():
		var key := file.get_csv_line()[0]
		if key.begins_with("GOAL_") or key.begins_with("NIGHT_OBJ_"):
			var text := tr(key)
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			if not text.contains("%") and width > best_w:
				best_w = width
				best = text
	return best


## The two guardians whose "NAME - TITLE" runs longest in the language now.
func _longest_guardians(keeper: Node) -> Array[StringName]:
	var font := UiTheme.strong_font()
	var widths := {}
	for id: StringName in keeper.guardians:
		var guardian: Node = keeper.guardians[id]
		var shown := String(guardian.call(&"display_name")) if guardian.has_method(&"display_name") else String(id)
		var title := String(guardian.call(&"title")) if guardian.has_method(&"title") else ""
		widths[id] = font.get_string_size((shown + "  —  " + title).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	var ids: Array[StringName] = []
	for id: StringName in widths:
		ids.append(id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return widths[a] > widths[b])
	return ids.slice(0, 2)


# --- 6. the subtitle bar and the voice props ------------------------------------------------

func _voice() -> void:
	var guard := museum.player
	guard.weapons.select_id(&"pistol")
	_put_guard(Vector3(-12.0, 0.0, 26.0), Vector3(-12.0, 3.0, 0.0))
	await _clear_cards()
	var bar: SubtitleBar = null
	for child in VoiceDirector.get_children():
		if child is SubtitleBar:
			bar = child
	if bar != null:
		bar.show_line(&"VO_HENIEK_NIGHT_1", &"radio", 30.0)
		museum.hud.show_hint(tr("HUD_HINT_FLASHLIGHT") % "F", 30.0)
	await _frames(4)
	await _shot("voice_subtitles_radio", bar != null and bar.is_showing(), {"text": bar.current_text() if bar != null else ""})
	if bar != null:
		bar.show_line(&"VO_GUIDE_ROSETTA_A", &"guide", 30.0)
	await _frames(4)
	await _shot("voice_subtitles_guide", bar != null and bar.is_showing(), {"text": bar.current_text() if bar != null else ""})
	if bar != null:
		bar.clear_line(&"")
	museum.hud._hint_left = 0.0
	museum.player.weapons.visible = false
	var markers: Dictionary = museum.floor_level.markers
	for id: StringName in [&"loudspeaker_court_1", &"loudspeaker_court_2", &"loudspeaker_egypt_1"]:
		if not markers.has(id):
			await _view("voice_%s" % id, Vector3.ZERO, Vector3.ONE, false)
			continue
		var at: Transform3D = markers[id]
		var out := -at.basis.z
		out.y = 0.0
		var eye := at.origin + out.normalized() * 5.0
		eye.y = _floor_at(eye) + 1.7 if not is_nan(_floor_at(eye)) else at.origin.y - 1.5
		await _view("voice_%s" % id, eye, at.origin, true)
		await _view("voice_%s_wide" % id, at.origin + out.normalized() * 10.0 + Vector3(0.0, -1.5, 0.0) + at.basis.x * 3.0, at.origin, true)
	if markers.has(&"audioguide_rosetta"):
		var stand: Transform3D = markers[&"audioguide_rosetta"]
		var out := -stand.basis.z
		await _view("voice_audioguide_rosetta", stand.origin + out * 2.4 + Vector3.UP * 1.6 + stand.basis.x * 0.8, stand.origin + Vector3.UP * 0.9, true)
		# the passage it stands beside, from the vestibule
		await _view("voice_audioguide_passage", Vector3(-33.5, 1.7, 27.5), stand.origin + Vector3.UP * 0.9, true)
	museum.player.weapons.visible = true


# --- 6. the night's new systems (window review 22.10) --------------------------------------

## The uncanny lamps: room -> the tour view it is watched from.
const NIGHT_LAMP_ROOMS := {&"egypt_gallery": "egypt_gallery_long", &"enlightenment_library": "library_gallery_walk",
	&"enlightenment_portraits": "library_gallery_walk", &"north_hall": "court_from_entrance"}
## Each lamp mode and the moments (s after it starts) it is shot at.
const NIGHT_LAMP_MODES: Array = [[&"brownout", [1.4]], [&"out", [0.6]], [&"flicker", [0.3, 0.55, 0.8]], [&"sweep", [0.8, 1.6]]]
## How far a tool's tag is watched from before it is set going.
const TOOL_REACHES: Array[float] = [10.0, 20.0]


func _night() -> void:
	var game := museum.floor_game
	museum.player.weapons.visible = false
	_put_guard(BOOTH, BOOTH + Vector3(0.0, 1.6, -5.0))
	if game.uncanny != null:
		game.uncanny.set_process(false)   # its own events out of the views (its lamps still play)
	await _clear_cards()
	_keep_free_camera = true
	if _night_part("lamps"):
		await _night_lamps()
	if _night_part("gaze"):
		await _night_gaze()
	if _night_part("tools"):
		await _night_tools()
	if _night_part("devices"):
		await _night_devices()
	_keep_free_camera = false
	museum.player.camera.current = true
	if game.uncanny != null:
		game.uncanny.set_process(true)
	museum.player.weapons.visible = true


## A part of the night group asked for (--only=night_lamps,night_tools...;
## "night" or nothing: every part; [param part] "": any part asked).
func _night_part(part: String) -> bool:
	if _only.is_empty() or _only.has("night"):
		return true
	for asked in _only:
		if asked.begins_with("night_") and (part == "" or asked == "night_" + part):
			return true
	return false


func _night_lamps() -> void:
	var lamps: RoomLamps = museum.floor_game.uncanny.lamps if museum.floor_game.uncanny != null else null
	for room: StringName in NIGHT_LAMP_ROOMS:
		# inside the room, aimed at the middle of its own main lamps (the
		# tour's view as a fallback); the lamps' summed energy logged per shot
		var view: Array = Tour.VIEWS[NIGHT_LAMP_ROOMS[room]]
		var from: Vector3 = view[0]
		var at: Vector3 = view[1]
		var own: Array[Light3D] = lamps.lit(room) if lamps != null else []
		if not own.is_empty():
			var middle := Vector3.ZERO
			for lamp in own:
				middle += lamp.global_position
			middle /= own.size()
			var ground := _ground_below(middle)
			var eye := _spot_camera(Vector3(middle.x, ground + 2.0, middle.z), ground, 9.0, room)
			if eye != Vector3.INF:
				from = eye
				at = Vector3(middle.x, lerpf(ground + 1.2, middle.y, 0.5), middle.z)
		await _settle_camera(from, at)
		await _view("lamps_%s_steady" % room, from, at, not own.is_empty(), {"lamps": own.size(), "energy": _energy(own), "culler": PerfStats.lights(get_tree())})
		await _seconds(2.0)
		await _view("lamps_%s_steady_2s" % room, from, at, not own.is_empty(), {"energy": _energy(own), "culler": PerfStats.lights(get_tree())})
		for stage: Array in NIGHT_LAMP_MODES:
			var mode: StringName = stage[0]
			var played := lamps != null and lamps.play(room, mode, 4.0, from)
			var waited := 0.0
			for moment: float in stage[1]:
				await _seconds(moment - waited)
				waited = moment
				await _view("lamps_%s_%s_%02d" % [room, mode, roundi(moment * 10.0)], from, at, played, {"energy": _energy(own)})
			if lamps != null:
				lamps.stop(room)
			await _seconds(0.5)
		await _seconds(2.0)
		await _view("lamps_%s_after" % room, from, at, lamps != null and not lamps.busy(room), {"energy": _energy(own), "culler": PerfStats.lights(get_tree())})


static func _energy(lamps: Array[Light3D]) -> float:
	var total := 0.0
	for lamp in lamps:
		if is_instance_valid(lamp):
			total += lamp.light_energy
	return snappedf(total, 0.01)


## A portrait with eyes in the portrait gallery: the guard 6 m in front of
## it, then 2.5 m to its side while it follows him; a close look at the eyes.
func _night_gaze() -> void:
	var painting: WallPainting = null
	for node in museum.paintings_root.get_children():
		if node is WallPainting and PaintingGaze.has_eyes(node) and museum.floor_level.room_at(node.global_position) == &"enlightenment_portraits":
			painting = node
			break
	if painting == null:
		await _view("gaze_none", Vector3.ZERO, Vector3.ONE, false)
		return
	var front := -painting.global_basis.z
	front.y = 0.0
	front = front.normalized()
	var side := front.cross(Vector3.UP)
	var face := painting.global_transform * PaintingGaze._eyes_local(painting)
	var ground := _floor_at(face + front * 6.0 + Vector3.DOWN * 1.2)
	ground = ground if not is_nan(ground) else face.y - 1.6
	museum.player.weapons.visible = true
	museum.player.weapons.select_id(&"pistol")
	_put_guard(Vector3(face.x, ground, face.z) + front * 6.0, face)
	await _seconds(0.6)
	await _shot("gaze_before", true, {"look": str(PaintingGaze.look_of(painting))}, [face])
	PaintingGaze.follow(painting, museum.player, 8.0)
	_put_guard(Vector3(face.x, ground, face.z) + front * 6.0 + side * 2.5, face)
	await _seconds(1.5)
	await _shot("gaze_follow_6m", true, {"look": str(PaintingGaze.look_of(painting))}, [face])
	museum.player.weapons.visible = false
	await _settle_camera(face + front * 1.6 - side * 0.4 + Vector3.DOWN * 0.15, face)
	await _view("gaze_follow_close", face + front * 1.6 - side * 0.4 + Vector3.DOWN * 0.15, face, true, {"look": str(PaintingGaze.look_of(painting))})
	_put_guard(BOOTH, BOOTH + Vector3(0.0, 1.6, -5.0))
	await _seconds(0.3)


## Every env tool: its red tag from 10 and 20 m, set going: its warning
## (the floor marked, the mount shedding dust), then its wreck.
func _night_tools() -> void:
	var env := museum.floor_game.env
	if env == null:
		await _view("tools_none", Vector3.ZERO, Vector3.ONE, false)
		return
	for prop in env.tools.duplicate():
		var tool := prop as EnvTool
		if tool == null or not is_instance_valid(tool) or tool.is_down:
			continue
		var id := String(tool.entry.get("id", tool.name))
		var room: StringName = tool.entry.get("room", &"")
		var tag_at := tool.tag.global_position if tool.tag != null else tool.global_position + Vector3.UP
		# watched from beyond where it strikes, looking back at it (the tag,
		# the mark and the wreck in one line)
		var strike_at: Vector3 = (tool.call(&"_mark_frame") as Transform3D).origin
		var prefer := strike_at - tool.global_position
		prefer.y = 0.0
		if prefer.length() < 0.5:
			prefer = Vector3.ZERO
		var near := Vector3.INF
		for reach: float in TOOL_REACHES:
			var eye := _spot_camera(tag_at, tool.floor_y, reach, room, prefer)
			if near == Vector3.INF:
				near = eye
				if eye != Vector3.INF:
					await _settle_camera(eye, tag_at)
			await _view("tool_%s_tag_%dm" % [id, roundi(reach)], eye if eye != Vector3.INF else tag_at + Vector3.ONE, tag_at, eye != Vector3.INF,
					{"distance": snappedf(eye.distance_to(tag_at), 0.1) if eye != Vector3.INF else 0.0})
		if near == Vector3.INF:
			continue
		var warn_eye := _spot_camera(strike_at.lerp(tag_at, 0.5), tool.floor_y, 8.0, room, prefer)
		if warn_eye == Vector3.INF:
			warn_eye = near
		var close := _spot_camera(strike_at, tool.floor_y, 4.5, room, prefer)
		if close == Vector3.INF:
			close = warn_eye
		tool.trigger()
		await _seconds(0.5)
		var mark: Node3D = tool.get("_mark")
		if mark != null and is_instance_valid(mark):
			strike_at = mark.global_position
		await _view("tool_%s_warning" % id, warn_eye, strike_at.lerp(tag_at, 0.35), tool.phase == EnvProp.Phase.WARNING, {"phase": tool.phase})
		# the floor mark from above (high over the spot, under the ceiling)
		var above := _above(strike_at, prefer, 5.0)
		await _view("tool_%s_warning_above" % id, above, strike_at, tool.phase == EnvProp.Phase.WARNING, {"phase": tool.phase})
		await _until(func() -> bool: return tool.is_down, 8.0)
		await _seconds(0.7)
		await _view("tool_%s_down" % id, warn_eye, strike_at + Vector3.UP * 0.4, tool.is_down, {"phase": tool.phase, "load": _load_state(tool)})
		await _seconds(1.5)
		await _view("tool_%s_down_close" % id, close, strike_at + Vector3.UP * 0.2, tool.is_down)
		await _view("tool_%s_down_above" % id, above, strike_at, tool.is_down)


## The biomes' devices: the first of each kind, before and after it acts.
func _night_devices() -> void:
	var biomes := museum.floor_game.biomes
	if biomes == null:
		await _view("devices_none", Vector3.ZERO, Vector3.ONE, false)
		return
	for kind: Script in [HeliosLamp, TempleBell, SteamVent, HuntingNet, SacredFire, TombTrap, Regulator, BronzeMirror]:
		var found := biomes.of_kind(kind)
		if found.is_empty():
			continue
		var device: BiomeDevice = found[0]
		var label := String(kind.get_global_name()).to_snake_case()
		var subject := device.global_position
		if device is HeliosLamp:
			subject = (device as HeliosLamp).origin()
		elif device is TempleBell:
			subject = (device as TempleBell).center()
		elif device is SteamVent:
			subject = (device as SteamVent).jet_point()
		elif device is HuntingNet:
			subject = (device as HuntingNet).knot().lerp((device as HuntingNet).landing(), 0.5)
		elif device is Regulator:
			subject = (device as Regulator).pendulum_point()
		elif device is SacredFire and (device as SacredFire).flame != null:
			subject = (device as SacredFire).flame.global_position
		elif device is TombTrap and device.get("_plate_view") != null:
			subject = (device.get("_plate_view") as Node3D).global_position + Vector3.UP * 0.3
		elif device is BronzeMirror and device.get("_disc") != null:
			subject = (device.get("_disc") as Node3D).global_position
		var ground := _ground_below(subject)
		var eye := _spot_camera(subject, ground, 7.0, device.room)
		var ok := eye != Vector3.INF
		if not ok:
			eye = subject + Vector3(1.0, 1.0, 1.0)
		await _settle_camera(eye, subject)
		await _view("device_%s_idle" % label, eye, subject, ok, {"room": String(device.room)})
		var acted := false
		if device is HeliosLamp:
			acted = (device as HeliosLamp).strike()
		elif device is TempleBell:
			acted = (device as TempleBell).ring()
		elif device is SteamVent:
			acted = await _until(func() -> bool: return (device as SteamVent).until_burst() <= 0.05, 12.0)
		elif device is HuntingNet:
			acted = (device as HuntingNet).drop()
		elif device is SacredFire:
			acted = (device as SacredFire).douse()
		else:
			continue
		for moment: float in [0.4, 1.2]:
			await _seconds(moment if moment < 1.0 else 0.8)
			await _view("device_%s_act_%02d" % [label, roundi(moment * 10.0)], eye, subject, acted)


## What a tool moved looks like now (its load's up axis and its visual's
## drawn meshes): a fallen bookcase must lie where it fell.
static func _load_state(tool: EnvTool) -> String:
	var node: Variant = tool.get("load_node")
	if not node is Node3D or not is_instance_valid(node):
		return ""
	var load := node as Node3D
	var meshes := 0
	var shown := 0
	var box := AABB()
	for mesh: Node in load.find_children("*", "VisualInstance3D", true, false):
		meshes += 1
		var visual := mesh as VisualInstance3D
		if visual.is_visible_in_tree():
			shown += 1
			var world := visual.global_transform * visual.get_aabb()
			box = world if box.size == Vector3.ZERO else box.merge(world)
	return "up %s, meshes %d (%d shown), drawn box %s" % [str(load.global_basis.y.snappedf(0.01)), meshes, shown, str(box)]


## A camera [param height] m over [param spot] (lower under a ceiling),
## [param back] m behind it against [param prefer]'s direction.
func _above(spot: Vector3, prefer: Vector3, height: float, back: float = 2.5) -> Vector3:
	var space := get_viewport().find_world_3d().direct_space_state
	var behind := -prefer.normalized() if prefer.length() > 0.01 else Vector3.BACK
	var base := spot + Vector3.UP * 0.5
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(base, base + Vector3.UP * height, Layers.WORLD))
	var up := height if hit.is_empty() else maxf(base.distance_to(hit["position"]) - 0.4, 1.2)
	var eye := base + Vector3.UP * up
	var side := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + behind * back, Layers.WORLD))
	var reach := back if side.is_empty() else maxf(eye.distance_to(side["position"]) - 0.4, 0.0)
	return eye + behind * maxf(reach, 0.3)   # (never straight down: look_at needs a direction off the up axis)


## The free camera at [param from] looking at [param at], current, left
## there long enough for the room culling to light the rooms round it.
func _settle_camera(from: Vector3, at: Vector3) -> void:
	camera.global_position = from
	if from.distance_to(at) > 0.05:
		camera.look_at(at, Vector3.UP)
	camera.reset_physics_interpolation()
	camera.current = true
	await _seconds(0.8)


## The first floor under [param point] (a ray 15 m down), or 1.6 m under it.
func _ground_below(point: Vector3) -> float:
	var space := get_viewport().find_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point, point + Vector3.DOWN * 15.0, Layers.WORLD))
	return point.y - 1.6 if hit.is_empty() else (hit["position"] as Vector3).y


## A free camera [param reach] m (or less) from [param subject] across the
## floor at [param ground], at eye height, inside a room (its own
## [param room] first), out of the walls, the subject in clear sight
## ([param prefer]: the direction tried first); Vector3.INF when none of 8
## directions has one.
func _spot_camera(subject: Vector3, ground: float, reach: float, room: StringName = &"", prefer: Vector3 = Vector3.ZERO) -> Vector3:
	var space := get_viewport().find_world_3d().direct_space_state
	var first := prefer.normalized() if prefer.length() > 0.01 else Vector3.FORWARD
	for same_room: bool in [true, false]:
		for share: float in [1.0, 0.8, 0.6]:
			for i in 8:
				# the preferred direction first, then turning away from it both ways
				var turn := ceili(i / 2.0) * (1.0 if i % 2 == 1 else -1.0) * PI / 4.0
				var direction := first.rotated(Vector3.UP, turn)
				var eye := Vector3(subject.x, ground + 1.6, subject.z) + direction * reach * share
				var floor_y := _floor_at(eye)
				if not is_nan(floor_y) and absf(floor_y - ground) < 1.0:
					eye.y = floor_y + 1.6
				var in_room := museum.floor_level.room_at(eye)
				if in_room == &"" or (same_room and room != &"" and in_room != room):
					continue
				var point := PhysicsPointQueryParameters3D.new()
				point.position = eye
				point.collision_mask = Layers.WORLD
				if not space.intersect_point(point).is_empty():
					continue
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, subject, Layers.WORLD))
				if hit.is_empty() or eye.distance_to(hit["position"]) > eye.distance_to(subject) - 0.35:
					return eye
	return Vector3.INF


# --- staging --------------------------------------------------------------------------

func _eye(at: Vector3) -> Vector3:
	return at + Vector3.UP * museum.player.eye_height


func _all(type: String) -> Array[Node]:
	return get_tree().root.find_children("*", type, true, false)


## The guard stands at [param at] looking at [param look].
func _put_guard(at: Vector3, look: Vector3) -> void:
	var guard := museum.player
	guard.global_position = at + Vector3.UP * 0.05
	guard.velocity = Vector3.ZERO
	guard.reset_physics_interpolation()
	guard.health.heal(HEAL)
	_look_at(look)
	guard.head.global_position = guard.global_position + Vector3.UP * guard.eye_height


func _look_at(point: Vector3) -> void:
	var guard := museum.player
	var eye := guard.global_position + Vector3.UP * guard.eye_height
	var aim := point - eye
	guard.head.rotation = Vector3(atan2(aim.y, Vector2(aim.x, aim.z).length()), atan2(-aim.x, -aim.z), 0.0)


func _fire(id: StringName) -> bool:
	var weapons := museum.player.weapons
	if weapons.current_state() == null or weapons.current_state().data.id != id:
		weapons.select_id(id)
		await _seconds(0.5)
	var state := weapons.state_of(id)
	if not state.can_fire():
		await _until(func() -> bool: return state.can_fire(), 2.5)
	return weapons.try_fire()


func _clear_cards() -> void:
	await _seconds(0.6)
	await _until(func() -> bool:
		return museum.hud.card_text() == "" and museum.hud.room_card_text() == "" and museum.hud.hint_text() == "", 11.0)


## A view through the guard's eyes, HUD up: logged, checked ([param ok], and
## every point of [param sights] in his clear sight), captured in a window.
func _shot(label: String, ok: bool, extra: Dictionary = {}, sights: Array[Vector3] = []) -> void:
	museum.player.camera.current = true
	await _record(label, ok, extra, museum.player.camera.global_position, sights, true)


## A view from a free camera at [param from] looking at [param at], HUD
## hidden: the camera must stand in a room, out of the walls, its subject in
## sight.
func _view(label: String, from: Vector3, at: Vector3, ok: bool, extra: Dictionary = {}) -> void:
	var problems := PackedStringArray()
	if museum.floor_level.room_at(from) == &"":
		problems.append("camera outside every room")
	var space := get_viewport().find_world_3d().direct_space_state
	var point := PhysicsPointQueryParameters3D.new()
	point.position = from
	point.collision_mask = Layers.WORLD
	if not space.intersect_point(point).is_empty():
		problems.append("camera inside a wall")
	if not problems.is_empty():
		extra["problems"] = ", ".join(problems)
		ok = false
	if from.distance_to(at) > 0.05:
		camera.global_position = from
		camera.look_at(at, Vector3.UP)
		camera.reset_physics_interpolation()
	camera.current = true
	var sights: Array[Vector3] = [at]
	await _record(label, ok, extra, from, sights, false)
	if not _keep_free_camera:
		museum.player.camera.current = true


func _record(label: String, ok: bool, extra: Dictionary, eye: Vector3, sights: Array[Vector3], hud: bool) -> void:
	var entry := {"group": _group, "view": label, "ok": ok, "room": String(museum.floor_level.room_at(eye))}
	entry.merge(extra)
	if not sights.is_empty():
		var blocked := _blocked_sight(eye, sights)
		entry["sight"] = "clear" if blocked == "" else blocked
		if blocked != "":
			ok = false
	entry["ok"] = ok
	if not ok:
		_missed += 1
		print("MISSED: %s %s" % [label, str(entry)])
	else:
		print("%s: %s %s" % ["dry" if _dry else "shot", label, str(entry)])
	_log.append(entry)
	if _dry:
		return
	museum.hud.visible = hud
	museum.hud._vignette.modulate.a = 0.0
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OUT_DIR.path_join(_group).path_join("%s.png" % label)
	image.save_png(path)
	museum.hud.visible = true
	var metrics: Dictionary = Tour.brightness(image)
	entry["mean"] = metrics["mean"]
	entry["near_black"] = metrics["near_black"]
	print("saved %s  mean %.3f  near-black %.0f%%" % [ProjectSettings.globalize_path(path), metrics["mean"], float(metrics["near_black"]) * 100.0])


func _blocked_sight(eye: Vector3, points: Array[Vector3]) -> String:
	var space := get_viewport().find_world_3d().direct_space_state
	for point in points:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, point, Layers.WORLD))
		if not hit.is_empty() and eye.distance_to(hit["position"]) < eye.distance_to(point) - 0.35:
			var collider: Object = hit["collider"]
			var what := String((collider as Node).name) if collider is Node else "world"
			return "blocked by %s %.1f m out (target %.1f m)" % [what, eye.distance_to(hit["position"]), eye.distance_to(point)]
	return ""


func _until(condition: Callable, limit: float) -> bool:
	var left := limit
	while left > 0.0:
		if condition.call():
			return true
		if is_instance_valid(museum):
			museum.player.health.heal(HEAL)
		await get_tree().physics_frame
		left -= 1.0 / Engine.physics_ticks_per_second
	return condition.call()


func _seconds(time: float) -> void:
	for i in roundi(time * Engine.physics_ticks_per_second):
		if is_instance_valid(museum):
			museum.player.health.heal(HEAL)
		await get_tree().physics_frame


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
