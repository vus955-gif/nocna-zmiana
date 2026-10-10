class_name AudioContext
extends RefCounted
## Shared answers for the audio autoloads (Music, Ambience, Foley): what
## kind of scene runs, where the listener is, which level (with rooms) is
## loaded. Audio automation is off in test and scenario runs, so the
## suites stay silent and leak-free; a test switches a system on itself.

## Scene kinds.
const OFF := &"off"
const MENU := &"menu"
const GAME := &"game"
## The demo's end screen (after the T-Rex).
const END := &"end"

## How deep under the scene root level() looks.
const LEVEL_DEPTH := 3

## Level found per scene (instance id of the scene -> the level node).
static var _level_cache: Dictionary = {}


## False in test and scenario runs (SavePaths.is_test_run()).
static func automatic() -> bool:
	return not SavePaths.is_test_run()


## What kind of screen [param scene] is: the main menu, the end screen, a
## scene with the guard in it (the museum, the dev viewers) or anything else.
static func scene_kind(scene: Node) -> StringName:
	if scene == null or not scene.is_inside_tree():
		return OFF
	if scene is MainMenu or scene.scene_file_path == SceneFlow.MAIN_MENU:
		return MENU
	if scene is DemoEnd or scene.scene_file_path == SceneFlow.DEMO_END:
		return END
	var guard := scene.get_tree().get_first_node_in_group(&"player")
	if guard != null and (guard == scene or scene.is_ancestor_of(guard)):
		return GAME
	return OFF


## The guard (group "player"), or null.
static func guard(tree: SceneTree) -> Node3D:
	return tree.get_first_node_in_group(&"player") as Node3D if tree != null else null


## Where the ears are: the active 3D camera, else the guard; null when
## neither exists.
static func listener_position(viewport: Viewport) -> Variant:
	if viewport == null:
		return null
	var camera := viewport.get_camera_3d()
	if camera != null and camera.is_inside_tree():
		return camera.global_position
	var body := guard(viewport.get_tree())
	return body.global_position if body != null and body.is_inside_tree() else null


## The level of the running scene: a node with room_at(point) (LobbyLevel)
## at most LEVEL_DEPTH levels below the scene root (the shallowest one), or
## null. The Museum holds it as its first child; a test or a tool may wrap
## the Museum once more.
static func level(tree: SceneTree) -> Node:
	if tree == null or tree.current_scene == null:
		return null
	var scene := tree.current_scene
	var cached: Variant = _level_cache.get(scene.get_instance_id())
	if is_instance_valid(cached) and (cached as Node).is_inside_tree():
		return cached
	_level_cache.clear()
	var found: Node = null
	var layer: Array[Node] = [scene]
	for depth in LEVEL_DEPTH:
		var below: Array[Node] = []
		for parent in layer:
			for child in parent.get_children():
				if child.has_method(&"room_at"):
					found = child
					break
				below.append(child)
			if found != null:
				break
		if found != null:
			break
		layer = below
	if found != null:
		_level_cache[scene.get_instance_id()] = found
	return found


## Id of the level room around [param point] (&"" without a level or
## outside every room).
static func room_at(tree: SceneTree, point: Vector3) -> StringName:
	var found := level(tree)
	return found.call(&"room_at", point) if found != null else &""


## True when [param point] lies inside one of the BoxShape3D children of
## [param area] (zones test the listener without the physics engine).
static func box_contains(area: Node3D, point: Vector3) -> bool:
	if not area.is_inside_tree():
		return false
	for child in area.get_children():
		var shape := child as CollisionShape3D
		if shape == null or shape.disabled or not shape.shape is BoxShape3D:
			continue
		var local := shape.global_transform.affine_inverse() * point
		var half := (shape.shape as BoxShape3D).size * 0.5
		if absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z:
			return true
	return false


## A box shape of [param size] whose base is centred on the parent's
## origin (the floor under the zone).
static func floor_box(size: Vector3) -> CollisionShape3D:
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = Vector3(0.0, size.y * 0.5, 0.0)
	return shape


static func has_box(area: Node) -> bool:
	for child in area.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			return true
	return false
