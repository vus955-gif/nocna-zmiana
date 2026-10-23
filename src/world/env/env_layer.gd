class_name EnvLayer
extends Node3D
## The museum's reactive environment and its tools on one built level (plan
## docs/superpowers/plans/2026-10-21-srodowisko-walka.md, backlog #22, #23,
## #39), installed by FloorGame with one call:
## [code]EnvLayer.install(level, museum)[/code].
## It builds the tagged tools of EnvCatalog (taking over the pieces they
## use), then puts a reactive EnvProp next to every piece, fixture and
## painting a kind of prop answers for (_scan(): glass cases, hanging
## lamps, busts, paintings, banners, shelves of books, jars) - none in a
## haven or a guardian's arena (skips()). Then it breaks again what broke
## earlier tonight (RunState.used).
## Budget (EnvRules): at most ACTIVE_CAP props move at once - the oldest
## swing settles to make room, a warning or a fall always plays out; an
## idle prop has no process at all. It keeps the tags' red glow pulsing
## (one shared material) and gives the hint about the tags once a night,
## the first time the guard aims at one.

## Its group (the performance overlay finds it there: PerfStats.environment).
const GROUP := &"env_layer"
const HINT_EVERY := 0.25
const HINT_REACH := 32.0
## The light index's cell (m).
const LIGHT_CELL := 2.0

var level: Node3D
var museum: Node
var run: NightState
## Every prop (tools included), in build order.
var props: Array[EnvProp] = []
## The tools (EnvTool), in catalog order.
var tools: Array[EnvProp] = []
## Pieces and fixtures a tool took over (no reactive prop for them).
var owned: Dictionary = {}
## The hint about the tags was given this night.
var hinted: bool = false

var _active: Array[EnvProp] = []
var _by_id: Dictionary = {}
var _lights: Dictionary = {}
## The guardians' arenas: room id -> true (filled on the first is_arena()).
var _arenas: Dictionary = {}
var _hint_left: float = 0.0
var _clock: float = 0.0


## Builds the layer for [param built] (already built) under [param host]
## (the Museum, or a test's stand-in with a [code]player[/code]) and
## returns it; [param parent] holds it (the host when null).
static func install(built: Node3D, host: Node, parent: Node = null) -> EnvLayer:
	var layer := EnvLayer.new()
	layer.name = "EnvLayer"
	layer.level = built
	layer.museum = host
	(parent if parent != null else host).add_child(layer)
	return layer


## A prop's id: its kind, its room and its place (to the decimetre).
static func make_id(kind: StringName, room_id: StringName, at: Vector3) -> StringName:
	return StringName("%s@%s:%d,%d,%d" % [kind, room_id, roundi(at.x * 10.0), roundi(at.y * 10.0), roundi(at.z * 10.0)])


func _ready() -> void:
	add_to_group(GROUP)
	top_level = true
	global_transform = Transform3D.IDENTITY
	if run == null:
		var host_run: Variant = museum.get(&"run") if is_instance_valid(museum) else null
		run = host_run if host_run is NightState else RunState
	build()


func build() -> void:
	_index_lights()
	_build_tools()
	_scan()
	restore()


## Adds [param prop] (placed, not yet in the tree) to the layer.
func add_prop(prop: EnvProp) -> EnvProp:
	prop.layer = self
	props.append(prop)
	_by_id[prop.id] = prop
	add_child(prop)
	return prop


## The prop of [param prop_id] (null when none).
func prop(prop_id: StringName) -> EnvProp:
	return _by_id.get(prop_id)


## The layer of the running level (null when there is none).
static func of(tree: SceneTree) -> EnvLayer:
	for node in tree.get_nodes_in_group(GROUP):
		if node is EnvLayer and not node.is_queued_for_deletion():
			return node
	return null


## The props that answer for [param node] (a piece, a fixture, a painting;
## a tool's taken-over piece included).
func props_of(node: Node) -> Array[EnvProp]:
	var out: Array[EnvProp] = []
	if not is_instance_valid(node):
		return out
	for each in props:
		if is_instance_valid(each.target) and each.target == node:
			out.append(each)
		elif each is EnvTool and is_instance_valid(each.get(&"load_node")) and each.get(&"load_node") == node:
			out.append(each)
	return out


## True when the environment answers for [param node]. Whatever else turns,
## hides or swaps the museum's pieces (the night's uncanny turns) should
## leave such a piece alone - or tell the layer: rebind(), set_present(),
## recapture().
func claims(node: Node) -> bool:
	return is_instance_valid(node) and (owned.has(node) or not props_of(node).is_empty())


## [param fresh] took [param old]'s place (a painting swapped for another in
## the same frame): its props follow the fresh one. Best called before
## [param old] is freed; once it is, the props whose piece is gone and that
## stand where [param fresh] stands follow it.
func rebind(old: Variant, fresh: Node3D) -> void:
	var found: Array[EnvProp] = []
	if is_instance_valid(old):
		found = props_of(old as Node)
	if found.is_empty() and fresh != null:
		for each in props:
			if each.lost_target() and each.global_position.distance_to(fresh.global_position) < 0.05:
				found.append(each)
	for each in found:
		each.rebind(fresh)


## [param node] is hidden (false) or back (true): its props answer only
## while it is there.
func set_present(node: Node, present: bool) -> void:
	for each in props_of(node):
		each.set_present(present)


## [param node] was turned or moved: its props take its new pose as rest.
func recapture(node: Node) -> void:
	for each in props_of(node):
		each.recapture()


## Breaks again what broke earlier tonight.
func restore() -> void:
	for each in props:
		if run != null and run.is_used(EnvRules.used_id(each.id)):
			each.restore_down()


## [param prop] broke: remembered for the night.
func remember(prop_: EnvProp) -> void:
	if run != null:
		run.mark_used(EnvRules.used_id(prop_.id))


func guard() -> Player:
	var host_player: Variant = museum.get(&"player") if is_instance_valid(museum) else null
	if is_instance_valid(host_player) and host_player is Player:
		return host_player
	if is_inside_tree():
		for node in get_tree().get_nodes_in_group(&"player"):
			if node is Player:
				return node
	return null


## [param prop] starts to move: it processes, within the budget.
func activate(prop_: EnvProp) -> void:
	prop_.set_physics_process(true)
	if _active.has(prop_):
		return
	_active.append(prop_)
	if _active.size() <= EnvRules.ACTIVE_CAP:
		return
	for other in _active:
		if other != prop_ and other.phase == EnvProp.Phase.MOVING:
			other.settle()
			deactivate(other)
			return


func deactivate(prop_: EnvProp) -> void:
	_active.erase(prop_)
	if is_instance_valid(prop_):
		prop_.set_physics_process(false)


## How many props move now.
func active_count() -> int:
	return _active.size()


## The pieces under the level's roots that hold its kit pieces (walkable
## and the rest; havens left out).
func piece_roots() -> Array[Node]:
	var roots: Array[Node] = []
	for key: StringName in [&"walk_static", &"structure"]:
		var root: Variant = level.get(key) if is_instance_valid(level) else null
		if root is Node:
			roots.append(root)
	return roots


## The node holding the level's lamps and fixtures (null when none).
func lights_root() -> Node3D:
	return NightModifiers.lights_of(level as Level) if level is Level else null


## True when [param room_id] is a haven (no prop there: a safe place stays calm).
func is_haven(room_id: StringName) -> bool:
	var layout: Variant = level.get(&"layout") if is_instance_valid(level) else null
	if not layout is LevelLayout:
		return false
	var spec := (layout as LevelLayout).room(room_id)
	return spec != null and spec.haven


## True when [param room_id] is a guardian's arena (a room with a
## "guardian_" marker): its fight is designed on its own, so no prop there.
func is_arena(room_id: StringName) -> bool:
	if _arenas.is_empty():
		_arenas[&""] = false   # (the cache is filled: no arena under no room)
		var layout: Variant = level.get(&"layout") if is_instance_valid(level) else null
		if layout is LevelLayout:
			for marker: StringName in (layout as LevelLayout).markers:
				if String(marker).begins_with("guardian_"):
					_arenas[(layout as LevelLayout).marker_rooms.get(marker, &"")] = true
	return bool(_arenas.get(room_id, false)) and room_id != &""


## True when no reactive prop goes into [param room_id]: a haven or a
## guardian's arena.
func skips(room_id: StringName) -> bool:
	return is_haven(room_id) or is_arena(room_id)


## The room spec of [param room_id] (null when unknown).
func room_spec(room_id: StringName) -> RoomSpec:
	var layout: Variant = level.get(&"layout") if is_instance_valid(level) else null
	return (layout as LevelLayout).room(room_id) if layout is LevelLayout else null


## The lamp (Light3D under the lights root) closest to [param point] within
## [param reach] m, or null.
func light_near(point: Vector3, reach: float = 0.6) -> Light3D:
	var best: Light3D = null
	var best_d := reach
	var cell := _cell(point)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for lamp: Light3D in _lights.get(cell + Vector2i(dx, dz), []):
				if not is_instance_valid(lamp):
					continue
				var d := lamp.global_position.distance_to(point)
				if d <= best_d:
					best = lamp
					best_d = d
	return best


## Puts [param lamp] out for the night: dark, left dark by every switch of
## its group (NightModifiers.set_lights) and by the exhibits' light model.
func put_out(lamp: Light3D) -> void:
	if lamp == null or not is_instance_valid(lamp):
		return
	lamp.visible = false
	lamp.set_meta(&"env_broken", true)
	var model := PerceptionWorld.light_model()
	if model != null and model.has_method(&"put_out"):
		model.call(&"put_out", lamp.position)


## [param body] (a standing tool's solid body, in the tree) is an obstacle
## the exhibits path round: a source of the level's walkable navigation
## (MuseumFloorLevel.add_walk_source, like the Lamassu's plinth), rebaked
## round it. Without a navigation it stays where it is.
func add_obstacle(body: Node3D) -> void:
	if _navigation() != null and level.has_method(&"add_walk_source"):
		level.call(&"add_walk_source", body)


## [param body] blocks nobody any more (its tool moved): the navigation
## round it is rebaked.
func clear_obstacle(body: Node3D) -> void:
	var navigation := _navigation()
	if navigation != null and level.has_method(&"add_walk_source") and is_instance_valid(body):
		navigation.request_rebake(LevelNavigation.source_area(body))


func _navigation() -> LevelNavigation:
	var found: Variant = level.get(&"navigation") if is_instance_valid(level) else null
	return found as LevelNavigation if is_instance_valid(found) and found is LevelNavigation else null


## Counts for tests, performance runs and the F3 overlay (PerfStats): props
## by kind, tools, hit zones on, props moving, props broken.
func stats() -> Dictionary:
	var kinds := {}
	var zones := 0
	var down := 0
	for each in props:
		if each.is_down:
			down += 1
		var kind := String(each.id).get_slice("@", 0)
		kinds[kind] = int(kinds.get(kind, 0)) + 1
		for zone in each.zones:
			if is_instance_valid(zone) and zone.collision_layer != 0:
				zones += 1
	return {"kinds": kinds, "props": props.size(), "tools": tools.size(), "zones": zones, "active": _active.size(), "down": down}


func _process(delta: float) -> void:
	_clock += delta
	if tools.is_empty():
		return
	EnvTag.pulse(_clock)
	if hinted:
		return
	_hint_left -= delta
	if _hint_left > 0.0:
		return
	_hint_left = HINT_EVERY
	_check_hint()


## The first time the guard aims at a tag (within HINT_REACH): the hint.
func _check_hint() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return
	var from := camera.global_position
	var hit := Hitscan.ray(get_world_3d().direct_space_state, from, from - camera.global_basis.z * HINT_REACH)
	var zone: Hurtbox = hit.get("hurtbox") if not hit.is_empty() else null
	# (a zone can outlive its owner for a frame: a falling guardian's)
	if zone != null and is_instance_valid(zone.receiver) and zone.receiver is EnvTag and not (zone.receiver as EnvTag).spent:
		hinted = true
		Events.hint_requested.emit(tr("HINT_ENV_TAG"))


## Every kind of reactive prop looks for its pieces (each: static scan(layer)).
func _scan() -> void:
	EnvGlass.scan(self)
	EnvCeramic.scan(self)
	EnvLamp.scan(self)
	EnvBust.scan(self)
	EnvStatue.scan(self)
	EnvPainting.scan(self)
	EnvBanner.scan(self)
	EnvShelf.scan(self)


func _build_tools() -> void:
	for entry: Dictionary in EnvCatalog.tools():
		var tool := EnvCatalog.make_tool(entry, self)
		if tool == null:
			continue
		tools.append(tool)
		add_prop(tool)


func _index_lights() -> void:
	_lights.clear()
	var root := lights_root()
	if root == null:
		return
	for node in root.get_children():
		var lamp := node as Light3D
		if lamp == null:
			continue
		var cell := _cell(lamp.global_position)
		if not _lights.has(cell):
			_lights[cell] = []
		(_lights[cell] as Array).append(lamp)


static func _cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / LIGHT_CELL), floori(point.z / LIGHT_CELL))
