extends TestCase
## What the dev overlay reads: engine monitors, the awake AI, the lamps the
## room culling leaves on.


func test_the_monitors_have_every_reading_the_overlay_shows() -> void:
	var readings := PerfStats.monitors()
	for key in ["fps", "script_ms", "physics_ms", "navigation_ms", "draw_calls", "objects", "primitives", "video_memory",
			"texture_memory", "buffer_memory", "memory", "memory_peak", "nodes", "orphans", "bodies", "pairs", "islands", "pipelines"]:
		assert_true(readings.has(key), key)
		assert_true(readings[key] >= 0, "%s is not negative" % key)
	await get_tree().process_frame
	assert_gt(PerfStats.monitors()["memory"], 1000000.0, "the game holds some memory")
	assert_gt(PerfStats.monitors()["nodes"], 10.0, "and some nodes")


func test_nothing_renders_headless_and_the_times_are_zero() -> void:
	assert_false(PerfStats.renders())
	assert_eq(PerfStats.render_times(get_viewport()), Vector2.ZERO)
	PerfStats.measure_render(get_viewport(), true)   # harmless on the dummy renderer
	PerfStats.measure_render(get_viewport(), false)


func test_the_ai_is_counted_by_what_it_does() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	var target := TargetDummy.new()
	target.position = Vector3(0, 0, -8)
	add_child(target)
	var figures: Array[WaxFigure] = []
	for i in 6:
		var wax := WaxFigure.new()
		wax.target = target
		wax.position = Vector3(i * 2.0, 0, 10)
		add_child(wax)
		figures.append(wax)
	var empty := PerfStats.ai(get_tree())
	assert_eq(empty["exhibits"], 6)
	assert_eq(empty["sleeping"], 6)
	assert_eq(empty["awake"], 0)
	figures[0].brain.state = EnemyBrain.State.HUNT
	figures[1].brain.state = EnemyBrain.State.ATTACK
	figures[2].brain.state = EnemyBrain.State.SUSPICIOUS
	figures[3].brain.state = EnemyBrain.State.PATROL
	figures[4].brain.state = EnemyBrain.State.STUNNED
	var counted := PerfStats.ai(get_tree())
	assert_eq(counted["hunting"], 2)
	assert_eq(counted["alert"], 1)
	assert_eq(counted["other"], 1)
	assert_eq(counted["stunned"], 1)
	assert_eq(counted["sleeping"], 1)
	assert_eq(counted["awake"], 5)
	assert_eq(counted["exhibits"], 6)
	figures[0].brain.state = EnemyBrain.State.DESTROYED
	assert_eq(PerfStats.ai(get_tree())["exhibits"], 5, "a wreck is no AI")
	assert_eq(PerfStats.ai(null)["exhibits"], 0)


func test_the_guardians_in_a_fight_are_counted() -> void:
	var calm := Guardian.new()
	var angry := Guardian.new()
	add_child(calm)
	add_child(angry)
	angry.state = Guardian.State.FIGHT
	var counted := PerfStats.ai(get_tree())
	assert_eq(counted["guardians"], 2)
	assert_eq(counted["guardians_fighting"], 1)


func test_the_lamps_left_on_by_the_culling_are_counted() -> void:
	MuseumFloorLevel.dress_default = true
	var level := MuseumFloorLevel.new()
	level.bake_navigation = false
	add_child(level)
	level.build()
	var culler := level.culler
	assert_not_null(culler)
	culler.depth = 2
	culler.update_from(Vector3(0, 1.7, 22))
	var near := culler.light_stats()
	assert_gt(near["lamps"], 20.0, "a dressed floor has lamps")
	assert_gt(near["lamps_on"], 0.0)
	assert_lt(near["lamps_on"], near["lamps"], "the far rooms are culled")
	assert_lt(near["rooms_on"], near["rooms"])
	assert_true(near["shadows_on"] <= near["lamps_on"])
	culler.depth = 99
	culler.refresh()
	culler.set_room(&"court", true)
	for room: StringName in culler._by_room:
		culler.set_room(room, true)
	var all := culler.light_stats()
	assert_eq(all["rooms_on"], all["rooms"], "everything on")
	assert_gt(all["lamps_on"], near["lamps_on"])
	# a lamp the power cut turned off is not on
	var lamp: Light3D = null
	for node in level.lights.get_children():
		if node is OmniLight3D and node.visible:
			lamp = node
			break
	assert_not_null(lamp)
	lamp.visible = false
	assert_eq(culler.light_stats()["lamps_on"], all["lamps_on"] - 1)
	MuseumFloorLevel.dress_default = false


func test_the_level_is_found_for_the_lights() -> void:
	assert_eq(PerfStats.lights(get_tree()), {}, "no level, no lamps")


func test_megabytes() -> void:
	assert_eq(PerfStats.megabytes(412 * 1048576), "412 MB")
	assert_eq(PerfStats.megabytes(int(1.8 * 1024 * 1048576)), "1.8 GB")
