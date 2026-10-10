extends RefCounted
## Navmesh probes for the Floor I walk tests.
## - Sealed islands: Recast leaves islands of navmesh on the tops of solid
##   props (a desk, the astrolabe's dais, the T-Rex's pedestal, a counter).
##   Asking for a path from the walkable floor to a goal on such an island
##   makes Godot 4.7 print "It's not expect to not find the most reachable
##   polygons" (an engine ERROR line fails the run). Asked the other way
##   round - from the goal to the start - the query is quiet and simply
##   stops on the island. So a test first checks that the goal connects
##   back to its start, and only then asks for the real path.
## - The search budget: a path query stops after
##   NavigationPathQueryParameters3D.path_search_max_polygons (4096 by
##   default, also what map_get_path() uses) and returns the way to the
##   closest polygon it reached. The whole floor's walkable mesh is bigger
##   than that, and a long climb (the basement to the roof: the straight-
##   line estimate pulls the search under the roof, through the court,
##   before it takes the stair tower) runs out of budget although the way
##   exists. The probes search without a limit; a route test measures the
##   level, not the engine's default budget.
## Use: const NavProbe := preload("res://tests/support/nav_probe.gd").

## The path back must end this close to the start (m).
const BACK := 0.5


## True when the navmesh point [param goal] leads back to the navmesh point
## [param start] on [param layers] (both already snapped to the mesh).
static func connected(map: RID, start: Vector3, goal: Vector3, layers: int) -> bool:
	var back := path(map, goal, start, layers)
	return not back.is_empty() and back[back.size() - 1].distance_to(start) < BACK


## The navmesh path from [param start] to [param goal] on [param layers],
## searched without a polygon budget (empty when there is none at all).
static func path(map: RID, start: Vector3, goal: Vector3, layers: int) -> PackedVector3Array:
	var query := NavigationPathQueryParameters3D.new()
	query.map = map
	query.start_position = start
	query.target_position = goal
	query.navigation_layers = layers
	query.path_search_max_polygons = 0
	var result := NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(query, result)
	return result.path
