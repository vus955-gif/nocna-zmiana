class_name PerfStats
extends RefCounted
## What the dev overlay (F3) reads, as plain dictionaries so a test or a
## tool can ask too: the engine's monitors, the render times of a viewport
## (CPU and GPU), the museum's awake exhibits and the lamps the room
## culling leaves on. Nothing here costs anything until it is asked.

## Brain states by what they mean for the player.
const HUNTING: Array[int] = [EnemyBrain.State.HUNT, EnemyBrain.State.ATTACK]
const ALERT: Array[int] = [EnemyBrain.State.SUSPICIOUS, EnemyBrain.State.INVESTIGATE, EnemyBrain.State.SEARCH]


## The engine's own counters (Performance monitors); times in ms, memory in bytes.
static func monitors() -> Dictionary:
	return {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"script_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"navigation_ms": Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0,
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"video_memory": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"texture_memory": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"buffer_memory": int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)),
		"memory": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"memory_peak": int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"bodies": int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
		"pairs": int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)),
		"islands": int(Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT)),
		"pipelines": int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)),
	}


## True when the game renders for real (the headless runner has a dummy renderer
## that measures nothing).
static func renders() -> bool:
	return DisplayServer.get_name() != "headless"


## Starts or stops the renderer's own timing of [param viewport] (it costs a
## little: only while the overlay is up).
static func measure_render(viewport: Viewport, on: bool) -> void:
	if viewport != null:
		RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), on)


## The renderer's CPU and GPU time for [param viewport]'s last frame, ms
## (x: CPU, y: GPU; 0 while not measured or when the driver gives no GPU
## timestamps).
static func render_times(viewport: Viewport) -> Vector2:
	if viewport == null or not renders():
		return Vector2.ZERO
	var rid := viewport.get_viewport_rid()
	return Vector2(RenderingServer.viewport_get_measured_render_time_cpu(rid), RenderingServer.viewport_get_measured_render_time_gpu(rid))


## The reactive environment (EnvLayer.stats(): props, tools, hit zones,
## props moving, props broken); empty without one (the lobby, the menus).
static func environment(tree: SceneTree) -> Dictionary:
	for node in tree.get_nodes_in_group(EnvLayer.GROUP):
		if node is EnvLayer and node.is_inside_tree():
			return (node as EnvLayer).stats()
	return {}


## The museum's AI: exhibits by what they do now, the guardians in a fight.
static func ai(tree: SceneTree) -> Dictionary:
	var out := {"exhibits": 0, "sleeping": 0, "alert": 0, "hunting": 0, "other": 0, "stunned": 0, "guardians": 0, "guardians_fighting": 0}
	if tree == null:
		return out
	for node in tree.get_nodes_in_group(&"enemies"):
		var brain: Variant = node.get("brain")
		if not brain is EnemyBrain:
			continue
		var state: int = (brain as EnemyBrain).state
		if state == EnemyBrain.State.DESTROYED:
			continue
		out["exhibits"] += 1
		if state == EnemyBrain.State.DORMANT:
			out["sleeping"] += 1
		elif HUNTING.has(state):
			out["hunting"] += 1
		elif ALERT.has(state):
			out["alert"] += 1
		elif state == EnemyBrain.State.STUNNED:
			out["stunned"] += 1
		else:
			out["other"] += 1   # patrolling, going home, fleeing
	for node in tree.get_nodes_in_group(&"guardians"):
		out["guardians"] += 1
		if node.get("state") == Guardian.State.FIGHT:
			out["guardians_fighting"] += 1
	out["awake"] = out["exhibits"] - out["sleeping"]
	return out


## The lamps, shadows and probes the room culling leaves on in the running
## level (empty when it has none: the lobby, the menus).
static func lights(tree: SceneTree) -> Dictionary:
	var level := AudioContext.level(tree)
	var culler: Variant = level.get("culler") if level != null else null
	return (culler as RoomCuller).light_stats() if culler is RoomCuller else {}


## Bytes as "412 MB" / "1.8 GB".
static func megabytes(bytes: int) -> String:
	var mb := bytes / 1048576.0
	return "%.1f GB" % (mb / 1024.0) if mb >= 1024.0 else "%d MB" % roundi(mb)
