extends TestCase
## The crystal's flight from each candidate case to the T-Rex: through the
## right doors, above the exhibits, never through a wall or a figure.

const SOCKET := Vector3(-1.25, 4.05, -11.0)

var layout: LevelLayout
var description: LevelDescription


func before_each() -> void:
	layout = LobbyLayout.create()
	description = LobbyLayout.describe(layout)


func _route(case_marker: StringName, closed: Array[StringName] = []) -> PackedVector3Array:
	var start: Vector3 = (layout.markers[case_marker] as Transform3D).origin
	return CrystalRoute.build(layout, start, description.room_of(case_marker), &"hall", SOCKET, closed)


func _passes_near(points: PackedVector3Array, door: StringName) -> bool:
	var passage := layout.opening(door)
	var middle := passage.center()
	for i in range(1, points.size()):
		var closest := Geometry3D.get_closest_point_to_segment(Vector3(middle.x, points[i].y, middle.z), points[i - 1], points[i])
		if Vector2(closest.x - middle.x, closest.z - middle.z).length() < 0.3 and closest.y > passage.floor_y + 1.0 and closest.y < passage.top_y - 0.5:
			return true
	return false


func test_each_case_flies_through_its_doors_to_the_ribs() -> void:
	var expected := {
		&"crystal_case_gallery": [&"door_hall_gallery"],
		&"crystal_case_armory": [&"door_hall_armory"],
		&"crystal_case_diorama": [&"door_hall_diorama"],
		&"crystal_case_hall": [],
	}
	for case_marker: StringName in expected:
		var points := _route(case_marker)
		var start: Vector3 = (layout.markers[case_marker] as Transform3D).origin
		assert_almost_eq(points[0].distance_to(start + Vector3.UP * CrystalRoute.LIFT), 0.0, 0.001, "%s lifts straight up" % case_marker)
		assert_eq(points[points.size() - 1], SOCKET, "ends between the ribs")
		for door: StringName in expected[case_marker]:
			assert_true(_passes_near(points, door), "%s goes through %s" % [case_marker, door])
		assert_lt(CrystalRoute.length(points), 90.0, "%s: a short flight" % case_marker)


func test_the_flight_goes_round_a_locked_door() -> void:
	var points := _route(&"crystal_case_gallery", [&"door_hall_gallery"] as Array[StringName])
	assert_false(_passes_near(points, &"door_hall_gallery"))
	assert_true(_passes_near(points, &"door_gallery_corridor"), "round by the west corridor")
	assert_true(_passes_near(points, &"door_hall_diorama"))


func test_no_leg_of_any_flight_cuts_through_the_building() -> void:
	var level := LobbyLevel.new()
	level.boss_stand_in = false
	add_child(level)
	level.build()
	await physics_frames(2)
	var space := level.get_world_3d().direct_space_state
	for case_marker in LobbyLayout.CRYSTAL_CASES:
		var points := _route(case_marker)
		# the case itself and the last metre into the ribs are allowed to touch
		for i in range(1, points.size() - 1):
			var query := PhysicsRayQueryParameters3D.create(points[i - 1], points[i], Layers.WORLD)
			var hit := space.intersect_ray(query)
			if i == 1:
				continue   # rising out of its own case
			assert_true(hit.is_empty(), "%s leg %d %s -> %s hits %s at %s" % [case_marker, i, points[i - 1], points[i], (hit.get("collider") as Node).name if not hit.is_empty() else "", hit.get("position")])
	level.free()
