extends TestCase
## Shots on the level (plan 2026-10-19-gun-feel): every surface throws off
## and keeps its own mark, as big as the weapon.

var user: Node3D
var holder: WeaponHolder


func before_each() -> void:
	user = Node3D.new()
	add_child(user)
	holder = WeaponHolder.new()
	holder.user = user
	holder.position = Vector3(0, 1.0, 0)
	user.add_child(holder)


## A wall 4 m ahead, tagged [param surface] (&"" untagged).
func _wall(surface: StringName) -> StaticBody3D:
	var wall := Greybox.box(self, Vector3(0, 1.0, -4.0), Vector3(6, 4, 0.2), Color.GRAY)
	if surface != &"":
		wall.set_meta(&"surface", surface)
	return wall


## The marks Fx holds now (not on their way out).
func _marks() -> Array[Decal]:
	var out: Array[Decal] = []
	for child in Fx.get_children():
		if child is Decal and not child.is_queued_for_deletion():
			out.append(child)
	return out


func test_every_surface_has_a_mark_of_its_own() -> void:
	var seen: Array = []
	for surface in Surface.ALL + [Fx.SCORCH]:
		var texture := Fx.mark_texture(surface)
		assert_not_null(texture, "%s has a mark" % surface)
		assert_false(seen.has(texture), "%s's is its own" % surface)
		seen.append(texture)
	assert_eq(Fx.mark_texture(&"lava"), Fx.mark_texture(Surface.STONE), "anything else marks like stone")


func test_a_point_blank_hit_leaves_no_mark() -> void:
	assert_eq(Fx.mark(Vector3.ZERO, Vector3.ZERO, Surface.STONE, 0.1), null)


func test_a_floor_is_what_the_footsteps_hear_a_wall_only_what_it_is_tagged() -> void:
	var floor_body := Greybox.box(self, Vector3(0, -0.5, 0), Vector3(4, 1, 4), Color.GRAY)
	floor_body.set_meta(&"surface", &"parquet")
	assert_eq(Surface.of_hit(floor_body, Vector3.ZERO, Vector3.UP), Surface.WOOD)
	var wall := _wall(&"")
	assert_eq(Surface.of_hit(wall, Vector3(0, 1, -3.9), Vector3.BACK, get_tree()), Surface.STONE, "an untagged wall is stone")
	wall.set_meta(&"surface", &"steel")
	assert_eq(Surface.of_hit(wall, Vector3(0, 1, -3.9), Vector3.BACK, get_tree()), Surface.METAL)


func test_a_bullet_marks_the_wall_with_its_surfaces_mark() -> void:
	_wall(&"wood")
	holder.give(load("res://src/weapons/data/pistol.tres"))
	await physics_frames(2)
	holder.try_fire()
	var marks := _marks()
	assert_eq(marks.size(), 1)
	if marks.size() == 1:
		assert_eq(marks[0].texture_albedo, Fx.mark_texture(Surface.WOOD), "a splintered hole in the boards")
		assert_almost_eq(marks[0].size.z, FeelProfile.of(&"pistol").decal_size, 0.0001)


func test_the_rifle_leaves_a_bigger_hole_than_the_pistol() -> void:
	_wall(&"")
	holder.give(load("res://src/weapons/data/pistol.tres"))
	holder.give(load("res://src/weapons/data/rifle_hunt.tres"))
	await physics_frames(2)
	holder.select_id(&"pistol")
	holder.try_fire()
	holder.select_id(&"rifle_hunt")
	holder.try_fire()
	var marks := _marks()
	assert_eq(marks.size(), 2)
	if marks.size() == 2:
		assert_gt(marks[1].size.z, marks[0].size.z * 1.3, "the rifle's hole")
		assert_eq(marks[0].texture_albedo, Fx.mark_texture(Surface.STONE))


func test_a_taser_arc_leaves_a_burn() -> void:
	var wall := Greybox.box(self, Vector3(0, 1.0, -3.0), Vector3(6, 4, 0.2), Color.GRAY)
	assert_not_null(wall)
	holder.give(load("res://src/weapons/data/taser.tres"))
	await physics_frames(2)
	holder.try_fire()
	var marks := _marks()
	assert_eq(marks.size(), 1)
	if marks.size() == 1:
		assert_eq(marks[0].texture_albedo, Fx.mark_texture(Fx.SCORCH))


## The particle bursts Fx holds now (not on their way out).
func _bursts() -> int:
	var count := 0
	for child in Fx.get_children():
		if child is GPUParticles3D and not child.is_queued_for_deletion():
			count += 1
	return count


func test_only_a_strong_hit_throws_the_second_puff_of_dust() -> void:
	for surface in [Surface.STONE, Surface.WOOD]:
		Fx.clear()
		Fx.surface_impact(Vector3.ZERO, Vector3.UP, surface, 0.46)
		assert_eq(_bursts(), 1, "%s, a pellet's share: grit only" % surface)
		Fx.clear()
		Fx.surface_impact(Vector3.ZERO, Vector3.UP, surface, Fx.DUST_MIN_STRENGTH)
		assert_eq(_bursts(), 2, "%s, a hard enough hit: grit and dust" % surface)
		Fx.clear()
		Fx.surface_impact(Vector3.ZERO, Vector3.UP, surface, 1.0)
		assert_eq(_bursts(), 2, "%s, a rifle round: grit and dust" % surface)


func test_a_run_of_shotgun_blasts_never_holds_more_than_the_cap_of_bursts() -> void:
	_wall(&"")
	var data: WeaponData = load("res://src/weapons/data/shotgun.tres").duplicate()
	data.cooldown = 0.0
	data.magazine_size = 999
	holder.give(data)
	await physics_frames(2)
	Fx.clear()
	var blasts := 0
	var most := 0
	for i in 30:
		if holder.try_fire():
			blasts += 1
		most = maxi(most, _bursts())
		assert_true(_bursts() <= Fx.MAX_IMPACT_BURSTS, "blast %d: %d bursts" % [i, _bursts()])
		await get_tree().process_frame
	assert_gt(blasts, 20, "a run of blasts")
	assert_eq(most, Fx.MAX_IMPACT_BURSTS, "and the wall did throw that many, the oldest making room")


func test_the_oldest_burst_makes_room_and_a_cleared_scene_starts_over() -> void:
	Fx.clear()
	var first := Fx.get_child_count()
	for i in Fx.MAX_IMPACT_BURSTS + 5:
		Fx.surface_impact(Vector3(i, 0, 0), Vector3.UP, Surface.METAL, 1.0)
	assert_eq(_bursts(), Fx.MAX_IMPACT_BURSTS)
	var newest := Fx.get_child(Fx.get_child_count() - 1) as GPUParticles3D
	assert_true(newest.position.is_equal_approx(Vector3(Fx.MAX_IMPACT_BURSTS + 4, 0, 0)), "the newest stays")
	assert_true(Fx.get_child(first).is_queued_for_deletion(), "the first went")
	Fx.clear()
	Fx.surface_impact(Vector3.ZERO, Vector3.UP, Surface.METAL, 1.0)
	assert_eq(_bursts(), 1)
