extends TestCase
## The six security cameras and the night clock on their pictures.


func test_six_cameras_watch_the_six_rooms() -> void:
	var cameras := CctvCatalog.cameras()
	assert_eq(cameras.size(), 6)
	var rooms: Array[StringName] = []
	for i in cameras.size():
		assert_eq(cameras[i].number, i + 1)
		rooms.append(cameras[i].room)
	assert_eq(rooms, [&"hall", &"gallery", &"armory", &"diorama", &"balcony", &"staff_corridor"] as Array[StringName])


func test_every_camera_hangs_in_its_room() -> void:
	var layout := LobbyLayout.create()
	for camera in CctvCatalog.cameras():
		assert_eq(layout.room_at(camera.position), camera.room, "camera %d" % camera.number)
		var room := layout.room(camera.room)
		assert_lt(camera.position.y, room.ceiling_y - 0.2, "under the ceiling: %d" % camera.number)
		assert_eq(layout.room_at(camera.target + Vector3.UP * 0.3), camera.room, "looks into its room: %d" % camera.number)


func test_every_camera_has_a_name() -> void:
	for camera in CctvCatalog.cameras():
		assert_ne(tr(camera.name_key()), camera.name_key())
	assert_eq(tr(CctvCatalog.cameras()[0].name_key()), "Hol główny")


func test_the_lens_looks_at_its_target() -> void:
	for camera in CctvCatalog.cameras():
		var forward := -camera.transform().basis.z
		assert_almost_eq(forward.dot((camera.target - camera.position).normalized()), 1.0, 0.001)


func test_the_night_clock_runs_from_eleven_to_six() -> void:
	assert_eq(CctvCatalog.clock_text(0.0), "23:00:00")
	assert_eq(CctvCatalog.clock_text(90.5), "23:30:10")
	assert_eq(CctvCatalog.clock_text(180.0), "00:00:00")
	assert_eq(CctvCatalog.clock_text(21.0 * 60.0), "06:00:00")
	assert_eq(CctvCatalog.clock_text(5000.0), "06:00:00", "the night ends at six")
	assert_eq(CctvCatalog.clock_text(-3.0), "23:00:00")
