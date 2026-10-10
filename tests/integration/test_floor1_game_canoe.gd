extends TestCase
## The canoe over the Americas' collapsed floor (gate hook_canoe, W4): with
## the real HookLock in the build the greybox deck (piece canoe_bridge) is
## left out, so the temple cannot be walked to before the harpoon; the
## canoe stands in the doorway, long enough for the gap, and once it is
## pulled down its wide deck is baked into the navigation: the temple is
## reached over it. A save with the canoe down has the deck from the start.

const REACH := 1.5
## On the Pacific gallery's floor, 3 m before the gap.
const GALLERY := Vector3(-34.0, 0.0, -79.0)
## On the temple's floor beside the doorway.
const TEMPLE := Vector3(-22.0, 0.0, -82.0)
## Over the middle of the gap.
const MID_GAP := Vector3(-27.75, 1.0, -79.0)

var museum: Museum


func before_each() -> void:
	Museum.level_id = &"floor1"


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _museum() -> Museum:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	return museum


func _path_length(from: Vector3, to: Vector3) -> float:
	var map := museum.floor_level.walk_region.get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map, from)
	var path := NavigationServer3D.map_get_path(map, start, to, true, LevelNavigation.WALK_LAYER)
	if path.is_empty() or path[path.size() - 1].distance_to(to) > REACH or start.distance_to(from) > REACH:
		return INF
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length


## Height of the first solid surface under [param at] (-INF: none).
func _ground_under(at: Vector3) -> float:
	var ray := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 20.0, Layers.WORLD)
	var hit := museum.get_world_3d().direct_space_state.intersect_ray(ray)
	return (hit["position"] as Vector3).y if not hit.is_empty() else -INF


## Waits (up to [param seconds]) until the gallery reaches the temple.
func _wait_for_way(seconds: float) -> float:
	var length := INF
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		if museum.floor_level.navigation.is_baking():
			continue
		length = _path_length(GALLERY, TEMPLE)
		if length < INF:
			break
	return length


func test_the_temple_lies_beyond_the_canoe_until_the_harpoon_pulls_it_down() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(4)
	var level := museum.floor_level
	assert_true(level.skip_kits.has(&"canoe_bridge"), "the real lock replaces the greybox deck")
	for node in level.find_children("*", "Node3D", true, false):
		if node.get_meta(&"kit", &"") == &"canoe_bridge":
			fail("the stand-in deck is built")
			break
	var canoe := museum.floor_game.gates.lock_of(&"hook_canoe") as HookLock
	assert_not_null(canoe, "a HookLock on the canoe gate")
	if canoe == null:
		return
	assert_eq(canoe.mode, HookLock.Mode.SWING, "the canoe, not a grate")
	assert_almost_eq(canoe.size.y, 6.5, 0.01, "long enough for the 5.5 m gap and its walls")
	assert_eq(canoe.bridge.get_parent(), level.walk_dynamic, "its deck is a source of the walkable navigation")
	assert_eq(canoe.bridge.collision_layer, 0)
	assert_lt(_ground_under(MID_GAP), -5.0, "nothing to walk on over the gap")
	assert_lt(_path_length(GALLERY, GALLERY + Vector3(-4.0, 0.0, 0.0)), INF, "the gallery's floor is walkable")
	assert_eq(_path_length(GALLERY, TEMPLE), INF, "the temple cannot be walked to")
	var opened := watch(Events.gate_opened)
	museum.floor_game.gates.open_gate(&"hook_canoe")
	assert_eq(opened.size(), 1)
	assert_true(GameState.is_gate_open(&"hook_canoe"))
	assert_almost_eq(_ground_under(MID_GAP), HookLock.DECK_TOP, 0.02, "the canoe's deck spans the gap")
	var length := await _wait_for_way(6.0)
	assert_lt(length, 25.0, "over the canoe into the temple")


func test_a_canoe_pulled_down_on_an_earlier_night_is_a_bridge_from_the_start() -> void:
	GameState.new_game()
	GameState.open_gate(&"hook_canoe")
	_museum()
	await physics_frames(4)
	var canoe := museum.floor_game.gates.lock_of(&"hook_canoe") as HookLock
	assert_true(canoe.is_open)
	assert_eq(canoe.bridge.collision_layer, Layers.WORLD)
	var length := await _wait_for_way(3.0)
	assert_lt(length, 25.0, "the deck is in the navigation")
