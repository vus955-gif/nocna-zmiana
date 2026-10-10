extends Node
## Windowed visual check of the lobby's world content (not part of the
## headless suite): secrets opening, the note reader, artifacts and the HUD
## row, the padlocked case, the gun locker and the till drawer, the CCTV
## wall and the camera view. Screenshots (1280x720) go to tests/_out/world/.
## Usage: bash tools/run_world.sh   (silent, windowed)
## Run with --headless it stages everything without capturing anything.

const OUT_DIR := "res://tests/_out/world/"
const NIGHT_SEED := 7
const NIGHT := 2
const WEST_HALL_CASE := Vector3(-16.5, 1.0, -8.0)

var bed: WorldTestbed
var features: LobbyFeatures
var player: Player
var exhibits: Node3D
var _dry: bool = false
var _count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # shots go on while a note pauses the game
	GameInput.capture_allowed = false
	_dry = DisplayServer.get_name() == "headless"
	if not _dry:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ignore := FileAccess.open(ProjectSettings.globalize_path("res://tests/_out/.gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	GameState.reset()
	GameState.night = NIGHT
	RunState.begin_night(NIGHT_SEED)
	var description := LobbyLayout.describe(LobbyLayout.create())
	var config := NightDirector.plan(NIGHT_SEED, NIGHT, description)
	for i in description.loot_spots.size():
		if description.loot_spots[i].position.distance_to(WEST_HALL_CASE) < 0.1:
			config.loot[i] = ArtifactCatalog.MONOCLE
	bed = WorldTestbed.new()
	bed.name = "World"
	add_child(bed)
	bed.setup(config, true)
	features = bed.features
	player = bed.player
	player.weapons.give(load("res://src/weapons/data/taser.tres"))
	exhibits = Node3D.new()
	exhibits.name = "Exhibits"
	bed.add_child(exhibits)
	_place_exhibits(config)
	var lantern := DroppedLantern.new()
	lantern.dust = 42
	lantern.position = Vector3(5.0, 0.02, 1.0)
	bed.add_child(lantern)
	await _frames(90)
	await _run()
	print("world scenario: %d shots" % _count)
	Sfx.quit_cleanly(0)


func _run() -> void:
	# 1. the passage behind the painting
	await _look(Vector3(-38.0, 0.05, 6.5), Vector3(-40, 1.4, 6.5))
	await _shot("01_painting_prompt")
	(features.switches[LobbySecrets.PAINTING][0] as SecretSwitch).interact(player)
	await _seconds(0.5)
	await _look(Vector3(-36.6, 0.05, 4.2), Vector3(-42.6, 1.2, 6.8))
	await _shot("02_painting_opening_banner")
	await _seconds(1.2)
	await _shot("03_painting_open")
	player.set_flashlight(true)
	await _look(Vector3(-41.3, 0.05, 4.6), Vector3(-43.6, 1.3, 7.3))
	await _shot("04_chamber")
	player.set_flashlight(false)
	# 2. the vent shaft
	await _look(Vector3(-12.75, 0.05, 26.4), Vector3(-12.75, 1.0, 23.8))
	await _shot("05_vent_grille")
	for switch: SecretSwitch in features.switches[LobbySecrets.VENT].duplicate():
		if switch.door_id == &"panel_vent_in":
			switch.interact(player)
			break
	await _seconds(1.4)
	player.set_flashlight(true)
	await _look(Vector3(-12.9, 0.05, 23.0), Vector3(-18.0, 1.4, 22.7))
	await _shot("06_vent_inside")
	await _look(Vector3(-19.0, 0.05, 21.8), Vector3(-19.0, 5.8, 6.0))
	await _shot("07_vent_climb")
	for switch: SecretSwitch in features.switches[LobbySecrets.VENT].duplicate():
		switch.interact(player)
		break
	await _seconds(1.4)
	await _look(Vector3(-19.05, 6.05, 3.75), Vector3(-8.0, 4.0, 1.0))
	await _shot("08_vent_exit")
	player.set_flashlight(false)
	# 3. the crooked plaque
	await _look(Vector3(38.7, 0.05, 1.2), Vector3(39.95, 1.55, 1.6))
	await _shot("09_plaque_crooked")
	features.plaque.interact(player)
	await _seconds(1.8)
	player.set_flashlight(true)
	await _look(Vector3(37.2, 0.05, -1.0), Vector3(42.4, 1.0, 0.2))
	await _shot("10_plaque_wall_open")
	player.set_flashlight(false)
	# 4. the note reader
	await _look(Vector3(0, 0.05, 59.2), Vector3(0.5, 0.8, 60.2))
	await _shot("11_security_desk")
	for id: StringName in [&"note_1", &"note_key", &"note_niche", &"note_vent", &"note_chamber", &"note_3"]:
		features.read_note(id)
		await _seconds(0.35)
		await _shot("12_note_%s" % id)
		features.reader.close()
		await _seconds(0.1)
	# 5. artifacts, the monocle and the icon row
	await _look(Vector3(-14.7, 0.05, -8.0), Vector3(-16.5, 1.15, -8.0))
	await _shot("13_artifact_in_case")
	for spot: int in features.artifacts.keys():
		var pickup := features.artifacts[spot] as ArtifactPickup
		if is_instance_valid(pickup) and not pickup.locked:
			pickup.interact(player)
	await _seconds(0.5)
	await _shot("14_artifacts_taken")
	for model: Enemy in [WaxFigure.new(), Knight.new()]:
		model.sight_range = 0.0   # asleep on their feet, for the picture
		model.wake_radius = 0.0
		model.position = Vector3(-9.5, 0.05, -4.5) if model is WaxFigure else Vector3(-7.0, 0.05, -5.0)
		exhibits.add_child(model)
	await _look(Vector3(-11.5, 0.05, 0.5), Vector3(-8.2, 1.5, -4.8))
	await _seconds(0.8)
	await _shot("15_monocle_weak_points")
	# 6. the padlocked case
	await _look(Vector3(14.6, 0.05, -14.0), Vector3(16.0, 0.85, -14.0))
	await _shot("16_padlock")
	var shot := DamageInfo.make(18.0, DamageInfo.Kind.BALLISTIC, player)
	shot.direction = Vector3.RIGHT
	shot.normal = Vector3.LEFT
	features.padlock.take_damage(shot)
	await _seconds(0.9)
	await _shot("17_padlock_broken_banner")
	# 7. the till drawer and the gun locker
	await _look(Vector3(-9.5, 0.05, 19.1), Vector3(-9.5, 0.95, 17.3))
	await _shot("18_till_drawer")
	features.drawer.interact(player)
	await _seconds(0.6)
	await _shot("19_till_drawer_key")
	await _look(Vector3(2.7, 0.05, 58.0), Vector3(4.3, 1.15, 58.0))
	await _shot("20_gun_locker")
	features.locker.interact(player)
	await _seconds(1.2)
	await _shot("21_gun_locker_open")
	# 8. the CCTV: an exhibit awake in the gallery shows as motion
	for exhibit in exhibits.get_children():
		if exhibit is Enemy and bed.level.room_at(exhibit.global_position + Vector3.UP * 0.5) == &"gallery":
			(exhibit as Enemy).brain.wake()
			break
	await _look(Vector3(0, 0.05, 59.0), Vector3(0, 1.62, 61.3))
	await _seconds(2.0)
	await _shot("22_cctv_wall")
	await _look(Vector3(-1.2, 0.05, 59.9), Vector3(0.6, 1.6, 61.3))
	await _seconds(0.5)
	await _shot("23_cctv_wall_close")
	features.cctv.open_view(0)
	await _seconds(1.0)
	await _shot("24_cctv_view_hall")
	features.cctv.view.select(1)
	await _seconds(1.0)
	await _shot("25_cctv_view_gallery")
	features.cctv.view.select(4)
	await _seconds(1.0)
	await _shot("26_cctv_view_balcony")
	features.cctv.view.select(5)
	await _seconds(0.12)
	await _shot("27_cctv_view_switching")
	features.cctv.view.close()
	await _seconds(0.3)


## Tonight's exhibits, all dormant (the scenario's guard must not be hunted).
func _place_exhibits(config: NightConfig) -> void:
	for entry in config.spawns:
		var slot := bed.level.spawn_slots[entry.slot]
		var exhibit := NightSpawner.make(entry.kind)
		if exhibit == null:
			continue
		exhibit.sight_range = 0.0   # asleep on their feet: the guard walks among them
		exhibit.wake_radius = 0.0
		exhibit.position = slot.position + Vector3.UP * 0.05
		exhibit.rotation.y = slot.yaw
		exhibits.add_child(exhibit)


func _look(at: Vector3, target: Vector3) -> void:
	bed.place_guard(at, target)
	await _frames(12)


func _shot(label: String) -> void:
	_count += 1
	if _dry:
		print("dry: staged ", label)
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OUT_DIR.path_join("%s.png" % label)
	image.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _seconds(time: float) -> void:
	var until := Time.get_ticks_msec() + int(time * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
