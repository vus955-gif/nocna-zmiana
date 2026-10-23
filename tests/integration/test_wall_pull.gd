extends TestCase
## The weapon near a wall (owner's note 46, plan 2026-10-21-animacje-fpp):
## the viewmodel is drawn with its depth squashed to the eye (it never
## sinks into a wall), but with a wall nearer than its muzzle it would look
## as if it went through: WallProbe casts from the eye straight ahead and
## toward where the gun shows on screen at the camera's field of view, and
## the weapon is pulled back toward the chest and tipped down, as far as
## the wall is near, eased in and out.

var camera: Camera3D
var holder: WeaponHolder
var wall: StaticBody3D = null


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color.GRAY)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.6, 0)
	camera.fov = 70.0
	add_child(camera)
	var user := Node3D.new()
	add_child(user)
	holder = WeaponHolder.new()
	holder.user = user
	camera.add_child(holder)


func _arm(id: StringName) -> Node3D:
	holder.give(load("res://src/weapons/data/%s.tres" % id))
	holder.select_id(id)
	return holder.view_of(id)


## A wall across the view, its face [param depth] m in front of the eye.
func _wall_at(depth: float) -> void:
	if wall != null:
		wall.free()
	wall = Greybox.box(self, Vector3(0, 1.5, -depth - 0.1), Vector3(6, 3, 0.2), Color.GRAY)


func _settle(frames: int = 40) -> void:
	for i in frames:
		await get_tree().physics_frame


func test_far_from_walls_the_weapon_stays_at_rest() -> void:
	var view := _arm(&"pistol")
	_wall_at(3.0)
	await _settle(60)
	assert_almost_eq(holder.wall_pull(), 0.0, 0.001)
	assert_lt((view.position - WeaponHolder.REST).length(), 0.0015, "at rest: %s" % view.position)


func test_a_wall_close_ahead_pulls_every_kind_of_weapon_back_and_down() -> void:
	for id in [&"pistol", &"shotgun", &"gatling"]:
		var view := _arm(id)
		_wall_at(3.0)
		await _settle(50)
		var rest := view.position
		_wall_at(0.48)
		await _settle(40)
		assert_gt(holder.wall_pull(), 0.6, "%s: a wall half a metre away pulls (%.2f)" % [id, holder.wall_pull()])
		assert_gt(view.position.z, rest.z + 0.05, "%s: back toward the chest" % id)
		assert_lt(view.position.y, rest.y - 0.015, "%s: and lower" % id)
		assert_lt(view.rotation.x, -0.12, "%s: muzzle tipped down off the wall" % id)
		_wall_at(3.0)
		await _settle(60)
		assert_lt(holder.wall_pull(), 0.01, "%s: away from the wall it comes back" % id)


func test_the_pull_grows_as_the_wall_comes_nearer() -> void:
	_arm(&"pistol")
	var pulls: Array[float] = []
	for depth in [0.95, 0.7, 0.6, 0.5, 0.44]:
		_wall_at(depth)
		await _settle(50)
		pulls.append(holder.wall_pull())
	assert_lt(pulls[0], 0.01, "a handgun clears a wall a metre off")
	for i in range(1, pulls.size()):
		assert_gt(pulls[i], pulls[i - 1], "nearer, further back: %s" % [pulls])
	assert_gt(pulls[pulls.size() - 1], 0.85, "pressed against it: all the way")


func test_a_long_gun_feels_a_wall_sooner_than_a_handgun() -> void:
	_arm(&"pistol")
	_wall_at(0.8)
	await _settle(50)
	var handgun := holder.wall_pull()
	_arm(&"rifle_hunt")
	await _settle(50)
	assert_almost_eq(handgun, 0.0, 0.01, "the pistol clears 0.8 m")
	assert_gt(holder.wall_pull(), 0.1, "the rifle's muzzle reaches it (%.2f)" % holder.wall_pull())


func test_straight_ahead_the_pull_is_the_same_at_any_field_of_view() -> void:
	_arm(&"shotgun")
	_wall_at(0.6)
	var pulls: Array[float] = []
	for fov in [70.0, 90.0, 110.0]:
		camera.fov = fov
		await _settle(50)
		pulls.append(holder.wall_pull())
	assert_gt(pulls[0], 0.3)
	assert_almost_eq(pulls[2], pulls[0], 0.05, "FOV 70 and 110: %s" % [pulls])


## A pillar's edge just right of the line of sight, half a metre off: at a
## wide view the gun's part of the screen shows the pillar right there (the
## gun would be drawn over it), at a narrow view it shows the open room
## beside it.
func test_at_a_wide_view_a_pillar_beside_the_gun_pulls_it_at_a_narrow_one_not() -> void:
	_arm(&"pistol")
	Greybox.box(self, Vector3(0.66, 1.5, -1.25), Vector3(1.0, 3.0, 1.6), Color.GRAY)
	camera.fov = 70.0
	await _settle(50)
	var narrow := holder.wall_pull()
	camera.fov = 110.0
	await _settle(50)
	var wide := holder.wall_pull()
	assert_lt(narrow, 0.02, "FOV 70: clear (%.2f)" % narrow)
	assert_gt(wide, 0.2, "FOV 110: the pillar is behind the gun (%.2f)" % wide)


func test_the_pull_eases_in_without_a_jump() -> void:
	var view := _arm(&"harpoon")
	_wall_at(3.0)
	await _settle(50)
	_wall_at(0.44)
	var last_pos := view.position
	var last_rot := view.rotation
	var widest := 0.0
	var widest_turn := 0.0
	for i in 40:
		await get_tree().process_frame
		widest = maxf(widest, view.position.distance_to(last_pos))
		widest_turn = maxf(widest_turn, (view.rotation - last_rot).length())
		last_pos = view.position
		last_rot = view.rotation
	assert_gt(holder.wall_pull(), 0.8)
	assert_lt(widest, 0.025, "no jump in position (%.3f m in a frame)" % widest)
	assert_lt(widest_turn, 0.08, "nor in the turn (%.3f rad in a frame)" % widest_turn)


func test_only_the_building_counts_not_an_exhibit_in_the_face() -> void:
	_arm(&"pistol")
	var body := StaticBody3D.new()
	body.collision_layer = Layers.ENEMY
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 3, 0.4)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, 1.5, -0.7)
	add_child(body)
	await _settle(50)
	assert_lt(holder.wall_pull(), 0.01, "an exhibit up close is a target, not a wall")
