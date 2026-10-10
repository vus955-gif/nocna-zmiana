extends TestCase
## The CCTV: cameras in the lobby, the monitor wall (live only while the
## guard is in the security booth) and the console's full-screen view.

const CHAIR := Vector3(0, 0.05, 59.2)
const CONSOLE := Vector3(0.18, 0.86, 60.38)
const DIORAMA := Vector3(0, 0.05, 34)

var bed: WorldTestbed
var cctv: Cctv


func _setup() -> void:
	bed = WorldTestbed.new()
	add_child(bed)
	bed.setup()
	cctv = bed.features.cctv
	await physics_frames(2)


func _event(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


## Presses and releases an action; waits until the view has seen it.
func _tap(action: StringName) -> void:
	_event(action, true)
	_event(action, false)
	await physics_frames(1)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
	await physics_frames(1)


func _renders() -> int:
	var total := 0
	for feed in cctv.feeds:
		total += feed.renders
	return total


func test_every_camera_hangs_free_and_sees_its_room() -> void:
	await _setup()
	var space := bed.get_world_3d().direct_space_state
	for camera in cctv.cameras:
		var inside := PhysicsPointQueryParameters3D.new()
		inside.position = camera.position
		inside.collision_mask = Layers.WORLD
		assert_true(space.intersect_point(inside).is_empty(), "camera %d not in a wall" % camera.number)
		var ray := PhysicsRayQueryParameters3D.create(camera.position, camera.target, Layers.WORLD)
		var hit := space.intersect_ray(ray)
		var reach := camera.position.distance_to(camera.target)
		var seen := camera.position.distance_to(hit["position"]) if not hit.is_empty() else reach
		assert_gt(seen, reach * 0.6, "camera %d looks into its room" % camera.number)


func test_the_wall_is_the_arts_monitor_bank_showing_six_feeds() -> void:
	await _setup()
	assert_eq(cctv.feeds.size(), 6)
	assert_not_null(cctv.bank, "the art's cctv_bank")
	assert_eq(cctv.bank_screens.size(), 6)
	assert_eq(cctv.screens.size(), 0, "no greybox monitors")
	assert_eq(bed.level.room_at(cctv.bank.global_position + Vector3.UP), &"security")
	for i in 6:
		for j in range(i + 1, 6):
			assert_ne(cctv.bank_screens[i], cctv.bank_screens[j], "each screen its own material")
	bed.player.respawn(CHAIR, PI)
	await physics_frames(90)
	for i in cctv.bank_screens.size():
		assert_eq(cctv.bank_screens[i].albedo_texture, cctv.feeds[i].get_texture(), "screen %d shows its camera" % (i + 1))
		assert_eq(cctv.bank_screens[i].emission_texture, cctv.feeds[i].get_texture())
		assert_gt(cctv.bank_screens[i].emission_energy_multiplier, Cctv.BANK_STANDBY)
	for feed in cctv.feeds:
		assert_eq(feed.size, CctvFeed.SIZE)
		assert_eq(feed.msaa_3d, Viewport.MSAA_DISABLED)
		assert_eq(feed.positional_shadow_atlas_size, 0)
		assert_false(feed.camera.environment.volumetric_fog_enabled)
	assert_not_null(cctv.get_node_or_null(^"MonitorWall"))
	# the moon's shadow cascades are not drawn again for every camera
	var moons := NightModifiers.moons(bed.level)
	assert_gt(moons.size(), 0)
	for moon in moons:
		assert_eq(moon.layers, CctvFeed.MOON_LAYER)
		assert_eq(cctv.feeds[0].camera.cull_mask & moon.layers, 0, "the feeds leave the moon out")
		assert_eq(cctv.view.lens.cull_mask & moon.layers, 0, "and so does the full-screen view")
		assert_ne(bed.player.camera.cull_mask & moon.layers, 0, "the guard still sees it")


func test_without_the_model_the_wall_is_six_greybox_monitors() -> void:
	ArtLibrary.models_enabled = false
	await _setup()
	ArtLibrary.models_enabled = true
	assert_null_bank()
	assert_eq(cctv.screens.size(), 6)
	for i in cctv.screens.size():
		var material := cctv.screens[i].material_override as ShaderMaterial
		assert_eq(material.get_shader_parameter(&"feed"), cctv.feeds[i].get_texture())
		assert_eq(bed.level.room_at(cctv.screens[i].global_position), &"security")


func assert_null_bank() -> void:
	assert_true(cctv.bank == null, "no bank without the models")


func test_the_status_screen_folds_a_long_list_of_rooms() -> void:
	await _setup()
	for locale in ["pl", "en"]:
		Settings.set_value(&"language", locale, false)
		for spec in cctv.cameras:
			cctv.motion_rooms[spec.room] = true
		cctv._update_status()
		await get_tree().process_frame
		var label: Label = cctv._status_lines
		assert_lt(label.get_combined_minimum_size().y + label.position.y, float(Cctv.STATUS_SIZE.y), "%s: six rooms fit the screen" % locale)
		assert_true(label.text.contains("+"), "%s: the rest folded: %s" % [locale, label.text])
		assert_lt(label.get_combined_minimum_size().x + label.position.x, float(Cctv.STATUS_SIZE.x), "%s: no line runs off" % locale)
		cctv.motion_rooms.clear()
	Settings.set_value(&"language", "pl", false)


func test_the_feeds_sleep_until_the_guard_is_in_the_booth() -> void:
	await _setup()
	bed.player.respawn(DIORAMA, 0.0)
	await physics_frames(20)
	assert_false(cctv.active)
	var idle := _renders()
	await physics_frames(60)
	assert_eq(_renders(), idle, "no camera renders while nobody watches")
	bed.player.respawn(CHAIR, PI)
	await physics_frames(90)
	assert_true(cctv.active)
	var watched := _renders() - idle
	assert_gt(watched, 38, "six cameras, about six pictures a second each")
	assert_lt(watched, 56)
	for feed in cctv.feeds:
		assert_gt(feed.renders, 2, "every camera in turn")
	bed.player.respawn(DIORAMA, 0.0)
	await physics_frames(30)
	var after := _renders()
	await physics_frames(60)
	assert_eq(_renders(), after, "asleep again")


func test_the_console_opens_the_camera_view() -> void:
	await _setup()
	bed.place_guard(CHAIR, CONSOLE)
	await physics_frames(3)
	assert_eq(bed.player.interactor.focus.prompt() if bed.player.interactor.focus != null else "", "Przeglądaj kamery")
	var opened := watch(cctv.view_opened)
	Input.action_press(&"interact")
	await physics_frames(1)
	Input.action_release(&"interact")
	await physics_frames(2)
	var view := cctv.view
	assert_true(view.is_open)
	assert_eq(opened.size(), 1)
	assert_eq(GameInput.top_ui(), view)
	assert_false(get_tree().paused, "the night goes on")
	assert_true(get_viewport().disable_3d, "the main view rests")
	await physics_frames(20)
	assert_false(cctv.active, "the wall rests too")
	assert_gt(view.renders, 3)


func test_the_view_switches_between_the_six_cameras() -> void:
	await _setup()
	var view := cctv.view
	cctv.open_view(0)
	assert_eq(view.index, 0)
	assert_eq(view._title.text, "KAM 1   HOL GŁÓWNY")
	await _key(KEY_3)
	assert_eq(view.index, 2)
	assert_eq(view._title.text, "KAM 3   ZBROJOWNIA")
	assert_true(view.lens.global_transform.origin.is_equal_approx(cctv.cameras[2].position))
	await _tap(&"ui_right")
	assert_eq(view.index, 3)
	await _tap(&"weapon_next")
	assert_eq(view.index, 4)
	await _tap(&"ui_left")
	assert_eq(view.index, 3)
	await _key(KEY_6)
	await _tap(&"ui_right")
	assert_eq(view.index, 0, "wraps around")


func test_e_leaves_the_view_and_never_reopens_it() -> void:
	await _setup()
	bed.place_guard(CHAIR, CONSOLE)
	await physics_frames(3)
	var view := cctv.view
	var opened := watch(view.opened)
	cctv.open_view()
	_event(&"interact", true)
	await physics_frames(1)
	assert_false(view.is_open)
	assert_false(get_viewport().disable_3d, "the main view is back")
	assert_true(view.is_holding_input())
	await physics_frames(5)
	assert_false(view.is_open, "held E does not reach the console")
	_event(&"interact", false)
	await physics_frames(3)
	assert_true(GameInput.gameplay_input())
	await physics_frames(3)
	assert_eq(opened.size(), 1)


func test_escape_leaves_the_view() -> void:
	await _setup()
	var pause_menu := PauseMenu.new()
	bed.add_child(pause_menu)   # after the view: it hears Esc first
	cctv.open_view(1)
	_event(&"pause", true)
	await physics_frames(1)
	assert_false(cctv.view.is_open)
	assert_false(pause_menu.is_open, "the Esc that left the view opens no pause menu")
	assert_false(get_tree().paused)
	_event(&"pause", false)
	await physics_frames(2)
	assert_false(pause_menu.is_open)
	assert_true(GameInput.gameplay_input(), "the key is up: input back, no extra step")


func test_an_awake_exhibit_shows_motion_on_its_camera() -> void:
	await _setup()
	var wax := WaxFigure.new()
	wax.position = Vector3(-30, 0.05, -3)
	bed.add_child(wax)
	var sleeper := WaxFigure.new()
	sleeper.position = Vector3(30, 0.05, -3)
	bed.add_child(sleeper)
	await physics_frames(2)
	wax.brain.wake()
	await physics_frames(60)
	assert_true(cctv.motion_rooms.get(&"gallery", false), "awake in the gallery")
	assert_false(cctv.motion_rooms.get(&"armory", false), "dormant exhibits do not count")
	await physics_frames(20)
	assert_true(cctv.feeds[1].motion)
	assert_false(cctv.feeds[2].motion)
	assert_true(cctv._status_lines.text.contains("GALERIA RZEŹBY"))


func test_the_view_snaps_shut_when_the_guard_is_hurt_dies_or_dawn_breaks() -> void:
	await _setup()
	var view := cctv.view
	for reason in ["hurt", "died", "dawn"]:
		cctv.open_view(0)
		assert_true(view.is_open)
		match reason:
			"hurt":
				bed.player.take_damage(DamageInfo.make(5.0, DamageInfo.Kind.BALLISTIC, null))
			"died":
				Events.player_died.emit()
			"dawn":
				Events.dawn_broke.emit()
		await physics_frames(1)
		assert_false(view.is_open, "shut when " + reason)
		assert_false(view.is_holding_input(), "the input is back at once (%s)" % reason)
		assert_false(get_viewport().disable_3d, "the main view is back (%s)" % reason)


func test_a_lost_focus_shuts_the_view_and_asks_for_the_pause_menu() -> void:
	await _setup()
	var view := cctv.view
	var asked := watch(bed.features.pause_requested)
	cctv.open_view(2)
	GameInput.pause_on_focus_loss = true
	view.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	GameInput.pause_on_focus_loss = false
	assert_false(view.is_open)
	assert_eq(asked.size(), 1)
	assert_eq(GameInput.top_ui(), null, "nothing holds the input: a pause menu may open")
	# with the option off (tests, scenarios) the view stays
	cctv.open_view(2)
	view.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(view.is_open)
	assert_eq(asked.size(), 1)
	view.snap_shut()


func test_the_awake_t_rex_shows_motion_in_the_hall() -> void:
	await _setup()
	var boss := TRex.new()
	boss.position = Vector3(0.0, 1.25, -11.0)
	bed.add_child(boss)
	await physics_frames(2)
	cctv._scan_motion()
	assert_false(cctv.motion_rooms.get(&"hall", false), "asleep on its pedestal")
	boss.wake()
	cctv._scan_motion()
	assert_true(cctv.motion_rooms.get(&"hall", false))


func test_the_guards_own_weapons_stay_out_of_the_pictures() -> void:
	await _setup()
	bed.player.respawn(DIORAMA, 0.0)   # far from the booth: nothing is re-layered for the feeds
	bed.player.weapons.give(load("res://src/weapons/data/pistol.tres"))
	bed.player.weapons.select_id(&"pistol")
	await physics_frames(30)
	var models := bed.player.camera.find_children("*", "GeometryInstance3D", true, false)
	assert_gt(models.size(), 0)
	for model in models:
		assert_eq((model as GeometryInstance3D).layers, CctvFeed.VIEWMODEL_LAYER)
		assert_eq(cctv.feeds[0].camera.cull_mask & (model as GeometryInstance3D).layers, 0)
	assert_ne(bed.player.camera.cull_mask & CctvFeed.VIEWMODEL_LAYER, 0, "the guard still sees them")
