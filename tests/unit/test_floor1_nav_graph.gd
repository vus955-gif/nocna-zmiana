extends TestCase
## Floor1NavGraph (W7) on a made-up navmesh: two slabs side by side with
## their own copies of the shared edge's corners (the second one a hair
## off, in the same map cell) and an island over the first slab (a prop's
## top: sealed off from the floor).


func _mesh() -> NavigationMesh:
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([
		Vector3(0, 0, 0), Vector3(4, 0, 0), Vector3(4, 0, 4), Vector3(0, 0, 4),
		Vector3(4.01, 0, 0.02), Vector3(8, 0, 0), Vector3(8, 0, 4), Vector3(4.02, 0, 4.01),
		Vector3(1, 1, 1), Vector3(3, 1, 1), Vector3(2, 1, 3),
	])
	for poly: Array in [[0, 1, 2], [0, 2, 3], [4, 5, 6], [4, 6, 7], [8, 9, 10]]:
		mesh.add_polygon(PackedInt32Array(poly))
	return mesh


func test_slabs_join_across_their_shared_edge_and_the_island_stays_apart() -> void:
	var graph := Floor1NavGraph.from_mesh(_mesh())
	assert_eq(graph.polygons.size(), 5)
	assert_eq(graph.component_count, 2, "the floor and the island")
	assert_eq(graph.component[0], graph.component[3], "the corners a hair apart share a map cell")
	assert_ne(graph.component[0], graph.component[4], "the island is sealed off")
	assert_true(graph.neighbours[1].has(0), "the halves of one slab share their diagonal")
	assert_eq(graph.crowded_edges, 0)
	assert_almost_eq(graph.area_of(graph.component[0]), 32.0, 0.1, "two 4 x 4 slabs")
	assert_almost_eq(graph.area_of(graph.component[4]), 2.0, 0.01)


func test_points_find_their_component_and_the_floor_under_an_island() -> void:
	var graph := Floor1NavGraph.from_mesh(_mesh())
	var floor_comp := graph.component[0]
	var island := graph.component[4]
	assert_eq(graph.component_at(Vector3(6, 0.05, 2)), floor_comp)
	assert_eq(graph.component_at(Vector3(2, 1.05, 2), 0.3), island, "standing on the prop")
	assert_eq(graph.component_at(Vector3(20, 0, 20)), -1, "off the mesh")
	var under := graph.closest(Vector3(2, 1.05, 2), floor_comp, 2.0)
	assert_almost_eq(under.y, 0.0, 0.001, "the floor's closest point lies on the floor")
	assert_almost_eq(Vector2(under.x, under.z).distance_to(Vector2(2, 2)), 0.0, 0.001)
	assert_eq(graph.closest(Vector3(2, 9, 2), floor_comp, 2.0), Vector3.INF, "nothing within reach")
	var edge := graph.closest(Vector3(9, 0, 2), floor_comp, 2.0)
	assert_almost_eq(edge.x, 8.0, 0.001, "beyond the slab: its edge")


func test_stand_points_lie_on_the_component_closest_first() -> void:
	var graph := Floor1NavGraph.from_mesh(_mesh())
	var floor_comp := graph.component[0]
	var center := Vector3(2, 0, 2)
	var points := graph.stand_points(floor_comp, center, 3.0)
	assert_gt(points.size(), 4.0)
	var last := 0.0
	for at in points:
		assert_almost_eq(at.y, 0.0, 0.001, "on the floor, never on the island")
		assert_true(Vector2(at.x, at.z).distance_to(Vector2(2, 2)) <= 3.0)
		var distance := at.distance_to(center)
		assert_true(distance >= last - 0.0001, "closest first")
		last = distance
	assert_eq(graph.stand_points(graph.component[4], Vector3(30, 0, 30), 2.0).size(), 0)


func test_closest_point_on_a_triangle() -> void:
	var a := Vector3(0, 0, 0)
	var b := Vector3(2, 0, 0)
	var c := Vector3(0, 0, 2)
	assert_eq(Floor1NavGraph.closest_on_triangle(Vector3(0.5, 3, 0.5), a, b, c), Vector3(0.5, 0, 0.5), "straight below")
	assert_eq(Floor1NavGraph.closest_on_triangle(Vector3(-1, 0, -1), a, b, c), a, "a corner")
	assert_eq(Floor1NavGraph.closest_on_triangle(Vector3(1, 0, -1), a, b, c), Vector3(1, 0, 0), "an edge")
	var far := Floor1NavGraph.closest_on_triangle(Vector3(2, 0, 2), a, b, c)
	assert_almost_eq(far.x, 1.0, 0.001, "the long edge")
	assert_almost_eq(far.z, 1.0, 0.001)


func test_regions_join_across_the_edge_connection_margin() -> void:
	var left := NavigationMesh.new()
	left.vertices = PackedVector3Array([Vector3(0, 0, 0), Vector3(4, 0, 0), Vector3(4, 0, 4), Vector3(0, 0, 4)])
	left.add_polygon(PackedInt32Array([0, 1, 2]))
	left.add_polygon(PackedInt32Array([0, 2, 3]))
	# 0.1 m beyond the left slab, its own corners half way along the edge
	var right := NavigationMesh.new()
	right.vertices = PackedVector3Array([Vector3(4.1, 0, 1), Vector3(8, 0, 1), Vector3(8, 0, 3), Vector3(4.1, 0, 3)])
	right.add_polygon(PackedInt32Array([0, 1, 2]))
	right.add_polygon(PackedInt32Array([0, 2, 3]))
	var joined := Floor1NavGraph.from_meshes([left, right], 0.25)
	assert_eq(joined.component_count, 1, "within the margin")
	assert_gt(float(joined.margin_links), 0.0)
	assert_eq(Floor1NavGraph.from_meshes([left, right], 0.05).component_count, 2, "beyond a tighter margin")
	# one region never joins its own free edges
	var points := PackedVector3Array(left.vertices)
	points.append_array(right.vertices)
	var polys: Array[PackedInt32Array] = [PackedInt32Array([0, 1, 2]), PackedInt32Array([0, 2, 3]), PackedInt32Array([4, 5, 6]), PackedInt32Array([4, 6, 7])]
	assert_eq(Floor1NavGraph.from_data(points, polys, PackedInt32Array([0, 0, 0, 0]), 0.25).component_count, 2, "one region: no margin joins")
	assert_true(Floor1NavGraph.margin_joins(Vector3(0, 0, 0), Vector3(4, 0, 0), Vector3(1, 0, 0.1), Vector3(3, 0, 0.1), 0.0625))
	assert_false(Floor1NavGraph.margin_joins(Vector3(0, 0, 0), Vector3(4, 0, 0), Vector3(5, 0, 0.1), Vector3(6, 0, 0.1), 0.0625), "no overlap")

