extends TestCase
## The Serpent's tracks through its temple (SerpentCourse) built from the
## Americas zone's markers: the floor loop between the fire bowls and the
## walls, the lower terrace's loop, the two flights joining them, the
## summit track over the upper terrace and the ring round the altar's
## terrace with its gate over the north flight; routes through the graph
## without U-turns; the leader's line with rounded corners and a lateral
## wave that starts and ends flat.

const ROOM := &"americas_temple"
## Body radius + the wave's amplitude: what must stay clear of things.
const CLEARANCE := 0.52 + 0.25

var layout: LevelLayout
var course: SerpentCourse


func before_each() -> void:
	layout = Floor1Layout.create()
	course = SerpentCourse.new()
	course.build(_points(&"serpent"))


## The keeper's grouping of a guardian's markers (<id>_<name>_<n>).
func _points(guardian_id: StringName) -> Dictionary:
	var prefix := String(guardian_id) + "_"
	var found := {}
	var ids: Array = layout.markers.keys().filter(func(id: StringName) -> bool: return String(id).begins_with(prefix))
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a).naturalnocasecmp_to(String(b)) < 0)
	for id: StringName in ids:
		var stem := String(id).substr(prefix.length())
		var cut := stem.rfind("_")
		if cut > 0 and stem.substr(cut + 1).is_valid_int():
			stem = stem.substr(0, cut)
		if not found.has(StringName(stem)):
			found[StringName(stem)] = []
		(found[StringName(stem)] as Array).append(layout.markers[id])
	return found


func _pieces(kit: StringName) -> Array[PieceSpec]:
	var out: Array[PieceSpec] = []
	for piece in layout.pieces:
		if piece.kit == kit and piece.room == ROOM:
			out.append(piece)
	return out


func _flight(id: StringName) -> StairsSpec:
	for flight in layout.stairs:
		if flight.id == id:
			return flight
	return null


## Distance from flat point [param at] to the rectangle [param rect] (0 inside).
static func _gap(at: Vector3, rect: Rect2) -> float:
	var p := Vector2(at.x, at.z)
	var dx := maxf(maxf(rect.position.x - p.x, p.x - rect.end.x), 0.0)
	var dy := maxf(maxf(rect.position.y - p.y, p.y - rect.end.y), 0.0)
	return Vector2(dx, dy).length()


static func _inside_by(at: Vector3, rect: Rect2) -> float:
	var p := Vector2(at.x, at.z)
	return minf(minf(p.x - rect.position.x, rect.end.x - p.x), minf(p.y - rect.position.y, rect.end.y - p.y))


func _line_length(line: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, line.size()):
		total += line[i].distance_to(line[i - 1])
	return total


func test_the_temples_markers_make_a_connected_course_in_the_arena() -> void:
	assert_gt(course.nodes.size(), 20, "a graph of some size")
	for i in course.nodes.size():
		var at := course.nodes[i]
		assert_eq(layout.room_at(Vector3(at.x, at.y + 0.5, at.z)), ROOM, "node %d at %s lies in the temple" % [i, at])
		assert_gt((course.links[i] as PackedInt32Array).size(), 0, "node %d is linked" % i)
	# everything reachable from everything
	for i in course.nodes.size():
		assert_gt(course.route(0, i).size(), 0, "node %d reachable from node 0" % i)
	# the fire bowls and the walls stay clear of the body on the floor loop
	var bowls := _pieces(&"brazier")
	assert_eq(bowls.size(), 4, "four fire bowls at the corners")
	var room := layout.room(ROOM)
	var floor_loop := course.group_line(&"path")
	assert_gt(floor_loop.size(), 8, "the floor loop as a rounded line")
	for at in floor_loop:
		for bowl in bowls:
			assert_gt(_gap(at, bowl.footprint()), CLEARANCE, "the floor loop clears the bowl at %s (%s)" % [bowl.position, at])
		assert_gt(_inside_by(at, room.parts[0]), CLEARANCE, "the floor loop keeps off the walls at %s" % at)
	assert_gt(_line_length(floor_loop), 60.0, "a long loop round the temple")


func test_the_flights_join_the_floor_to_the_lower_terrace_and_the_summit_crosses_the_upper() -> void:
	var t1 := Rect2(-20, -79, 11.5, 13.5)
	var t2 := Rect2(-18, -75, 7.5, 5.5)
	var n1 := _flight(&"americas_temple_n1")
	var s1 := _flight(&"americas_temple_s1")
	assert_not_null(n1)
	assert_not_null(s1)
	var stairs := course.group_pairs(&"stair")
	assert_eq(stairs.size(), 4, "two flights to climb, and the gate's two ways down")
	var climbed := {}
	for pair: Vector2i in stairs.slice(0, 2):
		var foot := course.nodes[pair.x]
		var top := course.nodes[pair.y]
		for flight: StairsSpec in [n1, s1]:
			if flight.rect.has_point(Vector2(foot.x, foot.z)) or _gap(foot, flight.rect) < 1.5:
				climbed[flight.id] = true
				assert_lt(absf(foot.x - flight.rect.get_center().x), 0.3, "%s: the foot in the flight's middle" % flight.id)
				assert_lt(absf(top.x - flight.rect.get_center().x), 0.3, "%s: the top in the flight's middle" % flight.id)
		assert_lt(foot.y, 0.1, "the foot on the floor")
		assert_gt(_inside_by(top, t1), 0.5, "the top on the lower terrace")
		assert_true(course.links[pair.x].has(pair.y), "the pair is linked")
	assert_eq(climbed.size(), 2, "both flights")
	# the gate's posts link down to the north flight's foot on the terrace
	var n2_foot := course.nearest(Vector3(n1.rect.get_center().x, 1.5, -78.3))
	for pair: Vector2i in stairs.slice(2):
		assert_eq(pair.y, n2_foot, "down to the north flight's foot")
		assert_true(course.ring.has(pair.x), "from a gate post")
		assert_true(course.links[pair.x].has(n2_foot))
	# the lower terrace's loop keeps off its edges
	for at in course.group_line(&"loop"):
		assert_gt(_inside_by(at, t1), 0.52, "the terrace loop stays on the terrace at %s" % at)
	# the summit: on the upper terrace, clear of the altar house, through
	# the moon's shaft, from the north flight's top to the south flight's
	var summit := course.group_line(&"summit")
	var shrine := _pieces(&"shrine")[0]
	var moon := Vector3(-14.5, 3.0, -72.25)
	var nearest_moon := INF
	for at in summit:
		if _inside_by(at, t2) > 0.0:
			# (the terrace's edge is open where the flights arrive)
			if absf(at.x - n1.rect.get_center().x) > 1.5 or (at.z > t2.position.y + 0.5 and at.z < t2.end.y - 0.5):
				assert_gt(_inside_by(at, t2), 0.5, "the summit track keeps off the upper terrace's edge at %s" % at)
			assert_gt(_gap(at, shrine.footprint()), 0.6, "and clear of the altar house at %s" % at)
			nearest_moon = minf(nearest_moon, Vector2(at.x - moon.x, at.z - moon.z).length())
	assert_lt(nearest_moon, 1.6, "it passes through the moon's shaft")
	var ends := course.group_nodes(&"summit")
	var first := course.nodes[ends[0]]
	var last := course.nodes[ends[ends.size() - 1]]
	assert_lt(first.y, 2.0, "it starts on the lower terrace (the north flight's foot)")
	assert_lt(last.y, 2.0, "and ends there (the south flight's foot)")
	assert_lt(first.z, -77.0)
	assert_gt(last.z, -67.5)
	assert_true(layout.markers.has(&"arena_serpent_reward"), "the reward lies on the summit")
	var reward: Vector3 = (layout.markers[&"arena_serpent_reward"] as Transform3D).origin
	assert_lt(reward.distance_to(moon), 0.5, "in the moon's shaft")


func test_the_ring_rounds_the_altars_terrace_with_its_gate_over_the_north_flight() -> void:
	var t1 := Rect2(-20, -79, 11.5, 13.5)
	var t2 := Rect2(-18, -75, 7.5, 5.5)
	var n2 := _flight(&"americas_temple_n2")
	var s2 := _flight(&"americas_temple_s2")
	assert_eq(course.ring.size(), 7, "the ring: the two gate posts and five corners")
	var posts := course.gate_posts()
	assert_lt(posts[0].x, n2.rect.position.x - 0.5, "the west post clear of the flight's west side")
	assert_gt(posts[1].x, n2.rect.end.x + 0.5, "the east post clear of its east side")
	assert_lt(posts[1].x - posts[0].x, 5.0, "a gate of about four metres")
	var gate := course.gate_center()
	assert_true(n2.rect.has_point(Vector2(gate.x, gate.z)), "the gate stands over the north flight")
	var ring := course.ring_path()
	assert_gt(ring.size(), 20)
	assert_lt(ring[0].distance_to(posts[1]), 0.01, "it runs from the east post")
	assert_lt(ring[ring.size() - 1].distance_to(posts[0]), 0.01, "round to the west post")
	var length := _line_length(ring)
	var lying := SerpentBody.new().lying_length()
	assert_gt(length, lying, "long enough for the lying body (%.1f m for %.2f m)" % [length, lying])
	assert_lt(length - lying, 3.0, "and not much longer: the body closes it but for the gate")
	var over_s2 := false
	for at in ring:
		assert_gt(_inside_by(at, t1), 0.3, "the ring stays on the lower terrace at %s" % at)
		assert_gt(_gap(at, t2), 0.5, "and off the upper terrace's face at %s" % at)
		assert_false(n2.rect.has_point(Vector2(at.x, at.z)), "never over the north flight (the gate) at %s" % at)
		if s2.rect.has_point(Vector2(at.x, at.z)):
			over_s2 = true
	assert_true(over_s2, "it crosses the south flight (the hump)")
	# every loop is longer than the body: it never lies over itself
	for group: StringName in [&"path", &"loop"]:
		assert_gt(_line_length(course.group_line(group)) - lying, 3.0, "%s longer than the body" % group)


func test_routes_through_the_graph_never_turn_back_on_themselves() -> void:
	var stairs := course.group_pairs(&"stair")
	var foot: int = stairs[0].x
	var top: int = stairs[0].y
	var far := course.ring[3]
	var route := course.route(foot, far)
	assert_gt(route.size(), 2)
	assert_eq(route[0], foot)
	assert_eq(route[route.size() - 1], far)
	assert_true(route.has(top), "up the flight on the way to the ring")
	for i in range(1, route.size()):
		assert_true(course.links[route[i - 1]].has(route[i]), "step %d follows a link" % i)
	# coming from the top, a route to the ring never steps back to the foot
	var onward := course.route(top, far, foot)
	assert_false(onward.has(foot), "no U-turn through the node it came from")
	var nearest := course.nearest(course.nodes[far] + Vector3(0.2, 0.0, 0.1))
	assert_eq(nearest, far)


func test_the_leader_follows_a_rounded_waved_line_to_its_goal() -> void:
	var stairs := course.group_pairs(&"stair")
	var foot: int = stairs[0].x
	var start := course.nodes[foot]
	course.start_at(start, foot)
	var goal := course.ring[3]
	course.head_for(goal)
	var straight := PackedVector3Array()
	for node in course.route_nodes:
		straight.append(course.nodes[node])
	straight.insert(0, start)
	var previous := course.position()
	assert_lt(previous.distance_to(start), 0.01, "the wave starts flat")
	var heading := Vector3.ZERO
	var steps := 0
	var wobbled := false
	while not course.arrived() and steps < 4000:
		var at := course.advance(0.05)
		var off := INF
		for i in range(1, straight.size()):
			off = minf(off, Geometry3D.get_closest_point_to_segment(Vector3(at.x, 0.0, at.z), Vector3(straight[i - 1].x, 0.0, straight[i - 1].z), Vector3(straight[i].x, 0.0, straight[i].z)).distance_to(Vector3(at.x, 0.0, at.z)))
		assert_lt(off, SerpentCourse.CORNER * 0.5 + course.amplitude + 0.05, "within the corridor of its route (%.2f m off at step %d)" % [off, steps])
		var step := at - previous
		if step.length() > 0.001:
			var now := step.normalized()
			if heading != Vector3.ZERO:
				assert_gt(now.dot(heading), 0.9, "it turns gradually (step %d)" % steps)
			heading = now
		if absf(course.wave_offset()) > 0.15:
			wobbled = true
		previous = at
		steps += 1
	assert_true(course.arrived(), "it got there")
	var end := course.position()
	assert_lt(Vector2(end.x - course.nodes[goal].x, end.z - course.nodes[goal].z).length(), 0.05, "and ends flat on the goal")
	assert_true(wobbled, "the lateral wave showed on the way")
	assert_gt(course.travelled, 10.0)
	# re-routing midway keeps the leader where it is
	course.start_at(start, foot)
	course.head_for(goal)
	for i in 40:
		course.advance(0.05)
	var midway := course.position()
	course.head_for(course.ring[5])
	assert_lt(course.position().distance_to(midway), 0.001, "a new goal does not move the leader")
	assert_eq(course.route_nodes[0], course.next_node(), "it still heads for the node it was heading for")


func test_it_peeks_along_its_line_ahead_of_the_leader() -> void:
	var stairs := course.group_pairs(&"stair")
	var foot: int = stairs[0].x
	course.start_at(course.nodes[foot], foot)
	course.head_for(course.ring[3])
	for i in 40:
		course.advance(0.05)
	var here := course.peek(0.0)
	assert_lt(here.distance_to(Vector3(course.position().x, 0.0, course.position().z)), course.amplitude + 0.01, "peek(0) is the leader without the wave")
	var on := course.peek(1.0)
	assert_lt(on.distance_to(here), 1.01, "a metre on along the line at most")
	assert_gt(on.distance_to(here), 0.8, "and nearly that far (a corner shortens the chord)")
	var far := course.peek(1000.0)
	var goal := course.nodes[course.ring[3]]
	assert_lt(Vector2(far.x - goal.x, far.z - goal.z).length(), 0.01, "no further than the line's end")


func test_a_node_is_passed_where_the_route_reaches_it_not_where_it_once_passed_close_by() -> void:
	# a route that doubles back across its own first leg: node D lies 0.2 m off
	# that leg, but the route reaches it only at the end of its third (a sharp
	# corner rounds 0.5 m off D - further than the first pass)
	var small := SerpentCourse.new()
	var spots: Array = []
	for at: Vector3 in [Vector3(0, 0, 0), Vector3(20, 0, 0), Vector3(20, 0, 10), Vector3(10, 0, 0.2), Vector3(19.8, 0, -9.8)]:
		spots.append(Transform3D(Basis.IDENTITY, at))
	small.build({&"summit": spots})
	assert_eq(small.nodes.size(), 5)
	small.start_at(small.nodes[0], 0)
	small.head_along(PackedInt32Array([1, 2, 3, 4]))
	assert_eq(small._node_at.size(), 4)
	for i in range(1, small._node_at.size()):
		assert_gt(small._node_at[i], small._node_at[i - 1], "node %d is passed after node %d (%.1f m, %.1f m)" % [i + 1, i, small._node_at[i], small._node_at[i - 1]])
	var total := small._line_len[small._line_len.size() - 1]
	assert_gt(small._node_at[2], total * 0.6, "D comes late in the route (%.1f of %.1f m)" % [small._node_at[2], total])
	# half way down the third leg: B and C are behind, D is next
	small.advance(small._node_at[2] - 3.0)
	assert_eq(small.previous_node(), 2, "last passed C")
	assert_eq(small.next_node(), 3, "heading for D")
