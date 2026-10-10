class_name LevelNavigation
extends Node
## Navigation of a built level: the walkable region (layer WALK, the one
## exhibits use) and the haven region (layer HAVEN, never used by exhibits,
## so they cannot path into a haven). Both are baked from their static
## colliders at build time with fine height cells (stairs are ramps, so a
## climb of 0.1 m is enough and the mesh never joins a floor to the top of
## a step or a ledge). Doors under the walkable region cut it while closed;
## when one changes, one asynchronous rebake runs (changes in the same
## frame, or during a bake, are merged into it).
## Zoned (Floor I, setup_zones()): the walkable navigation is one region
## per box (the zones' boxes): the level's static colliders are parsed
## once, the doors and other changing sources ([member dynamic_root]) at
## each bake; every box is baked from that geometry with the box as its
## baking bounds and a border of the agent's radius, so the boxes' edges
## meet and connect. The first bake runs the boxes in parallel; a door (or
## a new source) rebakes only the boxes round it, off the main thread.

signal rebaked

const WALK_LAYER := 1
const HAVEN_LAYER := 2
## A path search may look at this many polygons (the server's default,
## 4096, is less than the whole floor has: a path across it would stop
## half way).
const SEARCH_POLYGONS := 1 << 16
## An exhibit's own path search: the whole floor (with room to grow), but
## bounded - a guard out of reach (in a haven) is not searched for forever.
const AGENT_SEARCH_POLYGONS := 12000
## Boxes this far round a changed door (or source) are rebaked (m).
const DIRTY_MARGIN := 1.0
## The border baked round each box and cut off again (m, at least the
## agent's radius; on the 0.25 m cells).
const BOX_BORDER := 1.5
## A source without a collision shape counts as this big round its origin.
const SOURCE_REACH := 4.0

var walk_region: NavigationRegion3D
var haven_region: NavigationRegion3D
## Zoned: the static sources (parsed once) and the changing ones (doors,
## the canoe's deck...), parsed at each bake.
var static_root: Node3D = null
var dynamic_root: Node3D = null
## Zoned: the baking boxes and one region for each.
var boxes: Array[AABB] = []
var regions: Array[NavigationRegion3D] = []
## Milliseconds of the last full bake and of the last rebake (zoned).
var bake_msec: int = 0
var rebake_msec: int = 0
## Boxes the last rebake baked.
var rebaked_boxes: int = 0
var _queued := false
var _again := false
var _static_data: NavigationMeshSourceGeometryData3D = null
## Zoned: box indices waiting for a rebake, and bakes still running.
var _dirty: Dictionary = {}
var _pending: int = 0
var _rebake_started: int = 0


## Settings shared by every region (cell height must match
## navigation/3d/default_cell_height in project.godot).
static func navigation_mesh() -> NavigationMesh:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = Layers.WORLD
	mesh.agent_radius = 0.5
	mesh.agent_height = 2.0
	# cells must match the map (navigation/3d/default_cell_size, 0.25 m)
	mesh.cell_size = 0.25
	mesh.cell_height = 0.1
	mesh.agent_max_climb = 0.1
	mesh.agent_max_slope = 40.0
	return mesh


## A path on [param map] from [param from] to [param to] over
## [param layers], searching the whole map if need be (map_get_path stops
## after 4096 polygons).
static func find_path(map: RID, from: Vector3, to: Vector3, layers: int = WALK_LAYER) -> PackedVector3Array:
	var query := NavigationPathQueryParameters3D.new()
	query.map = map
	query.start_position = from
	query.target_position = to
	query.navigation_layers = layers
	query.path_search_max_polygons = SEARCH_POLYGONS
	var result := NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(query, result)
	return result.path


## One box's settings: baked over [param box] and a BOX_BORDER m border
## round it, which Recast cuts off again, so the mesh ends on the box's
## faces unshrunk (the agent's radius is kept from the walls beyond, not
## from the face) and meets the next box's edge to edge.
static func box_mesh(box: AABB) -> NavigationMesh:
	var mesh := navigation_mesh()
	mesh.filter_baking_aabb = AABB(box.position - Vector3(BOX_BORDER, 0.0, BOX_BORDER), box.size + Vector3(BOX_BORDER, 0.0, BOX_BORDER) * 2.0)
	mesh.border_size = BOX_BORDER
	mesh.edge_max_error = 1.0
	return mesh


func setup(walkable: NavigationRegion3D, havens: NavigationRegion3D) -> void:
	walk_region = walkable
	haven_region = havens
	walk_region.navigation_layers = WALK_LAYER
	haven_region.navigation_layers = HAVEN_LAYER
	walk_region.navigation_mesh = navigation_mesh()
	haven_region.navigation_mesh = navigation_mesh()
	walk_region.bake_finished.connect(_on_bake_finished)


## Zoned navigation (see the class notes): [param walkable] holds
## [param static_sources] and [param dynamic_sources] and the regions, one
## per box of [param baking_boxes].
func setup_zones(walkable: NavigationRegion3D, static_sources: Node3D, dynamic_sources: Node3D, havens: NavigationRegion3D, baking_boxes: Array[AABB]) -> void:
	walk_region = walkable
	haven_region = havens
	static_root = static_sources
	dynamic_root = dynamic_sources
	boxes = baking_boxes
	walk_region.navigation_layers = WALK_LAYER
	walk_region.enabled = false   # a holder: its boxes' regions carry the mesh
	haven_region.navigation_layers = HAVEN_LAYER
	haven_region.navigation_mesh = navigation_mesh()
	for i in boxes.size():
		var region := NavigationRegion3D.new()
		region.name = "Box_%d" % i
		region.navigation_layers = WALK_LAYER
		walk_region.add_child(region)
		regions.append(region)


func is_zoned() -> bool:
	return not boxes.is_empty()


## Rebakes whenever one of [param doors] (id -> Door) comes to rest open or
## shut.
func watch_doors(doors: Dictionary) -> void:
	for door: Door in doors.values():
		door.nav_blocking_changed.connect(_on_door_changed)


## Bakes both regions now, on this thread (zoned: every box, in parallel).
func bake_now() -> void:
	var started := Time.get_ticks_msec()
	if is_zoned():
		var data := _source_data()
		var meshes: Array[NavigationMesh] = []
		for box in boxes:
			meshes.append(box_mesh(box))
		var task := WorkerThreadPool.add_group_task(func(i: int) -> void: NavigationServer3D.bake_from_source_geometry_data(meshes[i], data), meshes.size(), -1, true, "navigation boxes")
		WorkerThreadPool.wait_for_group_task_completion(task)
		for i in meshes.size():
			regions[i].navigation_mesh = meshes[i]
		_dirty.clear()
	else:
		walk_region.bake_navigation_mesh(false)
	haven_region.bake_navigation_mesh(false)
	bake_msec = Time.get_ticks_msec() - started


## Asks for one walkable rebake at the end of this frame (zoned: of the
## boxes round [param area], every box when it is empty).
func request_rebake(area: AABB = AABB()) -> void:
	if is_zoned():
		for i in boxes.size():
			if area.size == Vector3.ZERO or boxes[i].intersects(area.grow(DIRTY_MARGIN)):
				_dirty[i] = true
	if _queued:
		return
	_queued = true
	_rebake.call_deferred()


func is_baking() -> bool:
	if is_zoned():
		return _queued or _pending > 0
	return _queued or walk_region.is_baking()


## Walkable polygons over all regions.
func polygon_count() -> int:
	if not is_zoned():
		return walk_region.navigation_mesh.get_polygon_count() if walk_region.navigation_mesh != null else 0
	var count := 0
	for region in regions:
		if region.navigation_mesh != null:
			count += region.navigation_mesh.get_polygon_count()
	return count


## Zoned: puts [param node] (a collider the exhibits should walk on or
## round: the canoe's deck, a display's plinth) among the changing sources
## and rebakes round it.
func add_source(node: Node3D) -> void:
	if not is_zoned():
		if node.get_parent() != walk_region:
			if node.is_inside_tree():
				node.reparent(walk_region)
			else:
				walk_region.add_child(node)
		request_rebake()
		return
	if node.is_inside_tree():
		node.reparent(dynamic_root)
	else:
		dynamic_root.add_child(node)
	request_rebake(source_area(node))


## The space [param node]'s collision shapes take (SOURCE_REACH round its
## origin when it has none).
static func source_area(node: Node3D) -> AABB:
	var area := AABB()
	var found := false
	for shape_node in node.find_children("*", "CollisionShape3D", true, false):
		var holder := shape_node as CollisionShape3D
		if holder.shape == null:
			continue
		var local := holder.shape.get_debug_mesh().get_aabb()
		var placed := holder.global_transform * local
		area = placed if not found else area.merge(placed)
		found = true
	if not found:
		var reach := Vector3.ONE * SOURCE_REACH
		area = AABB(node.global_position - reach, reach * 2.0)
	return area


static func door_area(door: Door) -> AABB:
	var half := Vector3(door.width, 0.0, door.depth) * 0.5
	var corners := AABB(-half, Vector3(door.width, door.height, door.depth))
	return door.global_transform * corners


func _on_door_changed(door: Door) -> void:
	request_rebake(door_area(door) if is_zoned() else AABB())


func _rebake() -> void:
	_queued = false
	if not is_instance_valid(walk_region) or not walk_region.is_inside_tree():
		return
	if is_zoned():
		_rebake_boxes()
		return
	if walk_region.is_baking():
		_again = true
		return
	walk_region.bake_navigation_mesh(true)


func _on_bake_finished() -> void:
	if _again:
		_again = false
		request_rebake()
		return
	rebaked.emit()


# --- zoned -----------------------------------------------------------------------

## The static sources (parsed once) with the changing ones of now.
func _source_data() -> NavigationMeshSourceGeometryData3D:
	var settings := navigation_mesh()
	if _static_data == null:
		_static_data = NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(settings, _static_data, static_root)
	var changing := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(settings, changing, dynamic_root)
	var data := NavigationMeshSourceGeometryData3D.new()
	data.set_vertices(_static_data.get_vertices())
	data.set_indices(_static_data.get_indices())
	data.merge(changing)
	return data


func _rebake_boxes() -> void:
	if _pending > 0:
		_again = true   # after the running bakes, with what changed since
		return
	if _dirty.is_empty():
		rebaked.emit()
		return
	_rebake_started = Time.get_ticks_msec()
	var data := _source_data()
	var dirty := _dirty.keys()
	_dirty.clear()
	_pending = dirty.size()
	rebaked_boxes = dirty.size()
	for i: int in dirty:
		var mesh := box_mesh(boxes[i])
		NavigationServer3D.bake_from_source_geometry_data_async(mesh, data, func() -> void: _box_baked.call_deferred(i, mesh))


func _box_baked(i: int, mesh: NavigationMesh) -> void:
	if i < regions.size() and is_instance_valid(regions[i]):
		regions[i].navigation_mesh = mesh
	_pending -= 1
	if _pending > 0:
		return
	rebake_msec = Time.get_ticks_msec() - _rebake_started
	_again = false
	if not _dirty.is_empty():
		_requeue()   # what changed while these baked
		return
	rebaked.emit()


func _requeue() -> void:
	if _queued:
		return
	_queued = true
	_rebake.call_deferred()
