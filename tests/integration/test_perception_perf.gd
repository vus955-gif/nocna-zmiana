extends TestCase
## Perception stays cheap with a full museum: 120 sleeping exhibits and 10
## patrols in the lobby while the guard walks through it (design 7.2:
## sight checks every 0.2 s spread over the exhibits, sleepers far from the
## guard every 0.6 s). Prints the numbers of the run (headless, so physics
## and scripts only).

const SLEEPERS := 120
const PATROLS := 10
const SECONDS := 10.0
## Average time spent looking (all exhibits together) per physics frame.
const LOOK_BUDGET_USEC := 1500.0


func test_120_exhibits_look_cheaply() -> void:
	var level := LobbyLevel.new()
	add_child(level)
	level.build()
	LevelPerception.configure_lobby(level)
	var guard := Player.new()
	guard.position = Vector3(0, 0.1, 20)
	add_child(guard)
	await physics_frames(6)
	var kinds: Array[GDScript] = [WaxFigure, Knight, Wolf, WaxFigure, Bust]
	var slots := level.spawn_slots
	for i in SLEEPERS + PATROLS:
		var slot := slots[i % slots.size()]
		var exhibit: Enemy = kinds[i % kinds.size()].new()
		var ring := float(i / slots.size())
		exhibit.position = slot.position + Vector3(ring * 0.9, 0.05, ring * 0.7)
		exhibit.target = guard
		exhibit.home_room = slot.room
		exhibit.starts_awake = i >= SLEEPERS
		if exhibit.starts_awake:
			exhibit.patrol_route = PerceptionRules.patrol_route(exhibit.position, slot.room, PerceptionWorld.room_at)
		add_child(exhibit)
	await physics_frames(2)
	PerceptionWorld.profiling = true
	PerceptionWorld.stats = {"looks": 0, "rays": 0, "look_usec": 0, "noises": 0}
	var path: Array[Vector3] = [Vector3(0, 0.1, 20), Vector3(0, 0.1, -10), Vector3(-15, 0.1, -10), Vector3(-15, 0.1, 10), Vector3(10, 0.1, 10)]
	var leg := 0
	var at := path[0]
	var step := guard.walk_speed / Engine.physics_ticks_per_second
	var frames := roundi(SECONDS * Engine.physics_ticks_per_second)
	var started := Time.get_ticks_usec()
	for frame in frames:
		var to := path[leg] - at
		if to.length() <= step:
			leg = (leg + 1) % path.size()
		else:
			at += to.normalized() * step
		guard.global_position = at
		await get_tree().physics_frame
	var wall_usec := Time.get_ticks_usec() - started
	PerceptionWorld.profiling = false
	var looks := int(PerceptionWorld.stats["looks"])
	var rays := int(PerceptionWorld.stats["rays"])
	var look_usec := float(PerceptionWorld.stats["look_usec"])
	var awake := 0
	for exhibit in PerceptionWorld.exhibits():
		if exhibit.brain.is_awake():
			awake += 1
	print("  perception, %d exhibits, %.0f s: %.0f looks/s, %.0f rays/s, %.0f us looking per frame (%.1f us a look), %.2f ms per frame all in, %d awake at the end" % [
		SLEEPERS + PATROLS, SECONDS, looks / SECONDS, rays / SECONDS, look_usec / frames, look_usec / maxf(looks, 1.0), wall_usec / 1000.0 / frames, awake])
	assert_lt(looks / SECONDS, (SLEEPERS + PATROLS) * 5.0 + 1.0, "never more than one look per exhibit per 0.2 s")
	assert_lt(look_usec / frames, LOOK_BUDGET_USEC * time_slack(), "looking stays cheap")
