extends TestCase
## The secret passages are walked, not teleported: the real guard holds
## move_forward and steers towards waypoints on the built lobby (his own
## collider, the real stairs, ramps and panels). Every passage both ways.

var bed: WorldTestbed


func before_each() -> void:
	bed = WorldTestbed.new()
	add_child(bed)
	bed.setup()
	await physics_frames(3)
	GameInput.clear_ui()
	for id in [&"panel_vent_in", &"panel_vent_out", &"panel_closet", &"panel_painting", &"panel_plaque"]:
		(bed.level.doors[id] as Door).open(true)
	await physics_frames(3)


func after_each() -> void:
	Input.action_release(&"move_forward")
	if is_instance_valid(bed):
		bed.free()


## Walks through [param points] with move_forward held, turning towards the
## next one. Returns how many were reached.
func _walk(start: Vector3, points: Array[Vector3], limit_s: float = 25.0) -> int:
	var player := bed.player
	player.respawn(start, 0.0)
	await physics_frames(3)
	var reached := 0
	Input.action_press(&"move_forward")
	for i in int(limit_s * Engine.physics_ticks_per_second):
		if reached >= points.size():
			break
		var to := points[reached] - player.global_position
		if Vector2(to.x, to.z).length() < 0.35 and absf(to.y) < 1.2:
			reached += 1
			continue
		player.head.rotation.y = atan2(-to.x, -to.z)
		await get_tree().physics_frame
	Input.action_release(&"move_forward")
	await physics_frames(2)
	return reached


func _route(start: Vector3, points: Array[Vector3], label: String) -> void:
	var reached := await _walk(start, points)
	assert_eq(reached, points.size(), "%s: stuck at %s (waypoint %d)" % [label, bed.player.global_position.snapped(Vector3.ONE * 0.01), reached])


func test_the_vent_shaft_climbs_from_the_diorama_to_the_balcony() -> void:
	await _route(Vector3(-12.75, 0.05, 26.0), [
		Vector3(-12.75, 0.0, 23.0),   # through the grille
		Vector3(-19.0, 0.0, 23.0),    # along the low duct
		Vector3(-19.0, 0.0, 22.8),    # the foot of the steps
		Vector3(-19.0, 6.0, 4.2),     # up the slot onto the landing
		Vector3(-16.0, 6.0, 3.75),    # out through the balcony grille
	] as Array[Vector3], "diorama -> balcony")


func test_the_vent_shaft_leads_back_down_to_the_diorama() -> void:
	await _route(Vector3(-16.0, 6.05, 3.75), [
		Vector3(-19.0, 6.0, 3.8),
		Vector3(-19.0, 6.0, 4.6),
		Vector3(-19.0, 0.0, 22.9),
		Vector3(-12.75, 0.0, 23.0),
		Vector3(-12.75, 0.0, 26.0),
	] as Array[Vector3], "balcony -> diorama")


func test_the_broom_closet_opens_off_the_balcony() -> void:
	await _route(Vector3(0.0, 6.05, -20.0), [Vector3(0.0, 6.0, -23.5), Vector3(-1.2, 6.0, -24.5)] as Array[Vector3], "balcony -> closet")
	await _route(Vector3(-1.2, 6.05, -24.5), [Vector3(0.0, 6.0, -23.2), Vector3(0.0, 6.0, -20.0)] as Array[Vector3], "closet -> balcony")


func test_the_painting_chamber_and_the_shotgun_niche_are_walked_into_and_out_of() -> void:
	await _route(Vector3(-37.0, 0.05, 6.5), [Vector3(-40.5, 0.0, 6.5), Vector3(-43.3, 0.0, 8.3)] as Array[Vector3], "gallery -> chamber")
	await _route(Vector3(-43.3, 0.05, 8.3), [Vector3(-41.5, 0.0, 6.5), Vector3(-37.0, 0.0, 6.5)] as Array[Vector3], "chamber -> gallery")
	await _route(Vector3(37.0, 0.05, 0.0), [Vector3(40.5, 0.0, 0.0), Vector3(41.8, 0.0, -1.6)] as Array[Vector3], "armory -> niche")
	await _route(Vector3(41.8, 0.05, -1.6), [Vector3(40.5, 0.0, 0.0), Vector3(37.0, 0.0, 0.0)] as Array[Vector3], "niche -> armory")
