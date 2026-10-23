extends TestCase
## The playthrough bot's legs across a gap the navmesh does not cross but
## the guard's body does (PlaythroughNav._bridged): the mesh keeps its
## agent's 0.5 m off every piece, so a 1.1 m gap between two pieces is
## sealed for it, while the guard is 0.8 m across - the card catalogue's
## arcs round the Reading Room's astrolabe on the dressed floor leave such
## gaps, and the bot found no way to the astrolabe (runs of 22.10). A wall
## with no gap stays no way; out of a pocket of the mesh the way he came
## in (or, knocked in, by the gap he finds).

const Pilot := preload("res://tests/support/playthrough_pilot.gd")
const GAP := 1.1

var root: Node3D
var guard: Player
var region: NavigationRegion3D
var driver: Driver


class Driver:
	extends Node
	var pilot: PlaythroughPilot
	var nav: PlaythroughNav = null

	func _ready() -> void:
		process_physics_priority = -100

	func _physics_process(delta: float) -> void:
		if nav != null:
			nav.update(delta)
		pilot.apply(delta)


func before_each() -> void:
	root = Node3D.new()
	add_child(root)
	region = NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.agent_radius = 0.5
	mesh.agent_height = 2.0
	mesh.cell_size = NavigationServer3D.map_get_cell_size(root.get_world_3d().navigation_map)
	mesh.cell_height = NavigationServer3D.map_get_cell_height(root.get_world_3d().navigation_map)
	mesh.agent_max_climb = mesh.cell_height
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = Layers.WORLD
	region.navigation_mesh = mesh
	root.add_child(region)
	_box(Vector3(0.0, -0.1, 0.0), Vector3(20.0, 0.2, 20.0))


func after_each() -> void:
	if driver != null and driver.pilot != null:
		driver.pilot.release_all()
	if is_instance_valid(root):
		root.free()


func _box(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	region.add_child(body)


## A wall across z = 0 with a gap of [param gap] m round x = 0 (none: 0;
## no wall: below 0).
func _wall(gap: float) -> void:
	var half := gap * 0.5
	if gap < 0.0:
		return
	if gap <= 0.0:
		_box(Vector3(0.0, 1.0, 0.0), Vector3(20.0, 2.0, 0.6))
		return
	_box(Vector3(-(half + 10.0) * 0.5, 1.0, 0.0), Vector3(10.0 - half, 2.0, 0.6))
	_box(Vector3((half + 10.0) * 0.5, 1.0, 0.0), Vector3(10.0 - half, 2.0, 0.6))


func _set_up(gap: float) -> PlaythroughNav:
	_wall(gap)
	region.bake_navigation_mesh(false)
	guard = Player.new()
	guard.name = "Guard"
	root.add_child(guard)
	guard.respawn(Vector3(0.0, 0.05, -6.0), 0.0)
	driver = Driver.new()
	driver.pilot = Pilot.new(guard)
	root.add_child(driver)
	await physics_frames(3)
	return PlaythroughNav.new(guard, driver.pilot, null)


func test_through_a_gap_the_mesh_seals_but_he_fits() -> void:
	var nav := await _set_up(GAP)
	var goal := Vector3(0.0, 0.0, 6.0)
	var raw := nav._query_back(nav.snap(goal), nav.snap(guard.global_position))
	assert_false(raw.is_empty())
	assert_gt(raw[raw.size() - 1].distance_to(nav.snap(guard.global_position)), PlaythroughNav.BACK, "the mesh itself has no way through the %.1f m gap" % GAP)
	var way := nav.path_to(goal)
	assert_false(way.is_empty(), "a way across the gap")
	var crossed := false
	for i in range(1, way.size()):
		if signf(way[i].z) != signf(way[i - 1].z) and absf(lerpf(way[i - 1].x, way[i].x, 0.5)) < GAP * 0.5:
			crossed = true
	assert_true(crossed, "it goes through the gap: %s" % [way])
	driver.nav = nav
	assert_true(nav.go(goal, 0.5))
	var frames := 0
	while nav.status == PlaythroughNav.Status.RUNNING and frames < 60 * 10:
		await physics_frames(1)
		frames += 1
	assert_eq(nav.status, PlaythroughNav.Status.ARRIVED, "walked through it (%s at %s)" % [nav.failure, guard.global_position])
	assert_gt(guard.global_position.z, 5.0)


func test_a_wall_without_a_gap_stays_no_way() -> void:
	var nav := await _set_up(0.0)
	assert_true(nav.path_to(Vector3(0.0, 0.0, 6.0)).is_empty(), "no way through a wall")
	assert_false(nav.go(Vector3(0.0, 0.0, 6.0)))


func test_a_gap_too_narrow_for_him_stays_no_way() -> void:
	var nav := await _set_up(0.7)
	assert_true(nav.path_to(Vector3(0.0, 0.0, 6.0)).is_empty(), "the guard (0.8 m) does not fit through 0.7 m")


## A pocket 3 m across (walls round it, one way in from the south through
## a 1.1 m gap): a sealed island of the mesh.
func _pocket() -> void:
	_box(Vector3(0.0, 1.0, 1.8), Vector3(4.2, 2.0, 0.6))
	_box(Vector3(1.8, 1.0, 0.0), Vector3(0.6, 2.0, 4.2))
	_box(Vector3(-1.8, 1.0, 0.0), Vector3(0.6, 2.0, 4.2))
	var half := GAP * 0.5
	_box(Vector3(-(half + 2.1) * 0.5, 1.0, -1.8), Vector3(2.1 - half, 2.0, 0.6))
	_box(Vector3((half + 2.1) * 0.5, 1.0, -1.8), Vector3(2.1 - half, 2.0, 0.6))


func test_out_of_a_pocket_the_way_he_came_in() -> void:
	_pocket()
	var nav := await _set_up(-1.0)
	driver.nav = nav
	assert_true(nav.go(Vector3(0.0, 0.0, 0.8), 0.3), "a way into the pocket through its gap (to its north end)")
	var frames := 0
	while nav.status == PlaythroughNav.Status.RUNNING and frames < 60 * 10:
		await physics_frames(1)
		frames += 1
	assert_eq(nav.status, PlaythroughNav.Status.ARRIVED, "in the pocket (%s at %s)" % [nav.failure, guard.global_position])
	# the mesh beyond the pocket's north wall is nearest to him, but that
	# side is shut: out the way he came in, then round
	assert_eq(nav.bridges.size(), 1, "the gap he came in by is remembered")
	var start := nav.snap(guard.global_position)
	var end := nav.snap(Vector3(0.0, 0.0, 6.0))
	var back := nav._query_back(end, start)
	assert_true(nav._bridged(start, end, back).is_empty(), "no gap toward the goal's nearest side")
	assert_false(nav._via_known_bridge(start, end).is_empty(), "out through the gap he came in by")
	# knocked in (no gap known): he finds it all the same
	var fresh := PlaythroughNav.new(guard, driver.pilot, null)
	assert_false(fresh.path_to(Vector3(0.0, 0.0, 6.0)).is_empty(), "out of a pocket he did not walk into")
	assert_false(nav.path_to(Vector3(0.0, 0.0, 6.0)).is_empty())
	assert_true(nav.go(Vector3(0.0, 0.0, 6.0), 0.5))
	frames = 0
	while nav.status == PlaythroughNav.Status.RUNNING and frames < 60 * 15:
		await physics_frames(1)
		frames += 1
	assert_eq(nav.status, PlaythroughNav.Status.ARRIVED, "out and round (%s at %s)" % [nav.failure, guard.global_position])
