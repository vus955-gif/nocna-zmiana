extends TestCase
## Busts, paintings, banners and shelves of the reactive layer (plan
## docs/superpowers/plans/2026-10-21-srodowisko-walka.md): a bust rocks,
## then topples off its plinth away from the shot and bursts on the floor;
## a painting goes crooked on its nail and slips down the wall past the
## limit; a banner sways and tears down; a shelf throws pages and keeps
## nothing broken. What falls takes its collision with it.

var bed: EnvTestbed


func before_each() -> void:
	bed = EnvTestbed.new()
	add_child(bed)
	bed.setup()


func after_each() -> void:
	if is_instance_valid(bed):
		bed.free()


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _of(type: Variant) -> Array[EnvProp]:
	var out: Array[EnvProp] = []
	for each in bed.env.props:
		if is_instance_of(each, type):
			out.append(each)
	return out


func test_a_bust_rocks_then_topples_away_from_the_shot_and_bursts_on_the_floor() -> void:
	var plinth := bed.piece(&"bust_plinth", Vector3(0.0, 0.0, -6.0), Vector3(0.7, 1.9, 0.7))
	var where := bed.dummy(Vector3(0.0, 0.0, -6.9))
	bed.install_env()
	var busts := _of(EnvBust)
	assert_eq(busts.size(), 1)
	var bust := busts[0] as EnvBust
	assert_false(bust.parts.is_empty(), "its top part is the bust")
	bust.take_damage(bed.hit(20.0, &"pistol", Vector3(0.0, 1.6, -5.75), Vector3.FORWARD))
	assert_false(bust.is_down, "one round rocks it")
	assert_eq(bust.phase, EnvProp.Phase.MOVING)
	await _seconds(1.0)
	bust.take_damage(bed.hit(20.0, &"pistol", Vector3(0.0, 1.6, -5.75), Vector3.FORWARD))
	assert_eq(bust.phase, EnvProp.Phase.FALLING, "the second knocks it off")
	await _seconds(1.5)
	assert_true(bust.is_down)
	for part in bust.parts:
		assert_false(part.visible, "burst on the floor")
	assert_eq(where.hits.size(), 1, "it lands on what stands where it falls (away from the shot)")
	assert_eq((plinth as StaticBody3D).collision_layer, Layers.WORLD, "the plinth stands as it was")


func test_a_punch_knocks_a_bust_off_at_once_and_a_resumed_night_shows_the_empty_plinth() -> void:
	bed.piece(&"bust_plinth", Vector3(0.0, 0.0, -6.0), Vector3(0.7, 1.9, 0.7))
	bed.install_env()
	var bust := _of(EnvBust)[0] as EnvBust
	bust.take_damage(bed.hit(15.0, &"fists", Vector3(0.0, 1.6, -5.75), Vector3.FORWARD, DamageInfo.Kind.BLUNT))
	assert_eq(bust.phase, EnvProp.Phase.FALLING)
	await _seconds(1.5)
	assert_true(bust.is_down)
	# the night resumed: the floor built afresh, the night's state kept
	var used := bed.run.used.duplicate()
	bed.free()
	bed = EnvTestbed.new()
	add_child(bed)
	bed.setup()
	bed.run.used.assign(used)
	bed.piece(&"bust_plinth", Vector3(0.0, 0.0, -6.0), Vector3(0.7, 1.9, 0.7))
	bed.install_env()
	var again := _of(EnvBust)[0] as EnvBust
	assert_true(again.is_down)
	for part in again.parts:
		assert_false(part.visible, "the plinth stands empty")


func test_a_painting_goes_crooked_then_slips_down_the_wall_without_its_collision() -> void:
	var picture := bed.painting(Vector3(0.0, 2.2, -14.95))
	bed.install_env()
	var paintings := _of(EnvPainting)
	assert_eq(paintings.size(), 1)
	var prop := paintings[0] as EnvPainting
	var rest := picture.global_transform
	prop.take_damage(bed.hit(20.0, &"pistol", picture.global_position + Vector3(0.3, 0.0, 0.05), Vector3.FORWARD))
	await _seconds(1.5)
	assert_false(prop.is_down)
	assert_gt(absf(prop.tilt), deg_to_rad(3.0), "crooked on its nail")
	assert_false(picture.global_transform.is_equal_approx(rest))
	assert_false(prop.is_physics_processing(), "still again")
	for i in 3:
		prop.take_damage(bed.hit(20.0, &"pistol", picture.global_position + Vector3(0.3, 0.0, 0.05), Vector3.FORWARD))
	await _seconds(1.0)
	assert_true(prop.is_down, "past the limit it slips off")
	assert_lt(picture.global_position.y, 1.0, "down on the floor")
	assert_gt(picture.global_position.z, -14.95, "leaning out from the wall")
	assert_eq(picture.collision_layer, 0, "it took its collision with it")


func test_a_rifle_round_knocks_a_painting_off_its_nail_at_once() -> void:
	bed.painting(Vector3(0.0, 2.2, -14.95))
	bed.install_env()
	var prop := _of(EnvPainting)[0]
	prop.take_damage(bed.hit(85.0, &"rifle_hunt", Vector3(0.0, 2.2, -14.9), Vector3.FORWARD))
	await _seconds(1.0)
	assert_true(prop.is_down)


func test_a_banner_sways_then_tears_down_and_fire_takes_it_at_once() -> void:
	var banner := bed.piece(&"banner", Vector3(0.0, 1.5, -14.9), Vector3(1.4, 5.5, 0.1), 0.0, false)
	var other := bed.piece(&"banner", Vector3(4.0, 1.5, -14.9), Vector3(1.4, 5.5, 0.1), 0.0, false)
	bed.install_env()
	var props := _of(EnvBanner)
	assert_eq(props.size(), 2)
	var first := props[0] as EnvBanner
	var look := banner.get_node(^"Visual") as Node3D
	var rest := look.transform
	first.take_damage(bed.hit(20.0, &"pistol", Vector3(0.0, 4.0, -14.85), Vector3.FORWARD))
	await _seconds(0.2)
	assert_false(look.transform.is_equal_approx(rest), "it sways")
	assert_false(first.is_down)
	for i in EnvRules.BANNER_HITS - 1:
		first.take_damage(bed.hit(20.0, &"pistol", Vector3(0.0, 4.0, -14.85), Vector3.FORWARD))
	await _seconds(1.0)
	assert_true(first.is_down, "torn off its rod")
	assert_lt((look.global_transform * Vector3(0.0, 5.5, 0.0)).y, 1.0, "crumpled at the foot of the wall")
	var flare := bed.hit(20.0, &"flare", Vector3(4.0, 4.0, -14.85), Vector3.FORWARD, DamageInfo.Kind.FIRE)
	(props[1] as EnvBanner).take_damage(flare)
	await _seconds(1.0)
	assert_true((props[1] as EnvBanner).is_down, "fire takes it at once")
	assert_not_null(other)


func test_a_shelf_of_books_throws_out_pages_and_keeps_nothing_broken() -> void:
	bed.piece(&"shelf", Vector3(0.0, 0.0, -14.5), Vector3(3.0, 3.4, 0.5), 0.0, true, &"enlightenment_library")
	bed.layout.add_room(&"enlightenment_library", [Rect2(-3.0, -15.0, 6.0, 2.0)] as Array[Rect2], 0.0, 8.0, Color.GRAY)
	bed.piece(&"shelf", Vector3(6.0, 0.0, -14.5), Vector3(3.0, 3.4, 0.5))
	bed.install_env()
	var shelves := _of(EnvShelf)
	assert_eq(shelves.size(), 1, "only a shelf of books")
	var pages := PageFlutter.count()
	shelves[0].take_damage(bed.hit(9.0, &"shotgun", Vector3(0.0, 1.5, -14.2), Vector3.FORWARD))
	assert_gt(float(PageFlutter.count() - pages), 4.0, "pages fly")
	assert_false(shelves[0].is_down)
	await _seconds(0.3)
	shelves[0].take_damage(bed.hit(20.0, &"pistol", Vector3(0.0, 1.5, -14.2), Vector3.FORWARD))
	assert_false(shelves[0].is_down, "a shelf stays a shelf")


func test_a_statue_rocks_to_a_punch_and_a_rifle_round_sends_it_over_onto_what_stands_in_its_way() -> void:
	bed.piece(&"pedestal", Vector3(0.0, 0.0, -6.0), Vector3(1.2, 0.8, 1.2))
	var statue := bed.piece(&"sculpture", Vector3(0.0, 0.8, -6.0), Vector3(0.9, 2.0, 0.9))
	bed.piece(&"sculpture", Vector3(5.0, 0.0, -6.0), Vector3(0.9, 2.0, 0.9))
	var in_its_way := bed.dummy(Vector3(0.0, 0.0, -8.0))
	var aside := bed.dummy(Vector3(2.5, 0.0, -8.0))
	bed.install_env()
	var statues := _of(EnvStatue)
	assert_eq(statues.size(), 1, "a statue up on a base (not one standing on the floor)")
	var prop := statues[0] as EnvStatue
	prop.take_damage(bed.hit(15.0, &"fists", Vector3(0.0, 1.8, -5.6), Vector3.FORWARD, DamageInfo.Kind.BLUNT))
	assert_eq(prop.phase, EnvProp.Phase.MOVING, "a punch rocks it")
	await _seconds(1.0)
	assert_false(prop.is_down)
	prop.take_damage(bed.hit(85.0, &"rifle_hunt", Vector3(0.0, 1.8, -5.6), Vector3.FORWARD))
	assert_eq(prop.phase, EnvProp.Phase.WARNING, "it teeters first: it can hurt")
	assert_eq(prop.find_children("*", "GroundMark", true, false).size(), 1, "its fall marked on the floor")
	await _seconds(EnvRules.MIN_WARNING - 0.05)
	assert_eq(in_its_way.hits.size(), 0, "nothing lands within the telegraph")
	await _seconds(1.5)
	assert_true(prop.is_down)
	assert_eq(in_its_way.hits.size(), 1, "it falls away from the shot onto the exhibit there")
	assert_eq(aside.hits.size(), 0)
	assert_eq((statue as StaticBody3D).collision_layer, 0, "lying down, it blocks nobody")
	assert_lt(statue.global_basis.y.normalized().dot(Vector3.UP), 0.2, "lying along the floor")


func test_a_round_aimed_at_a_bust_or_a_statue_lands_on_it_not_on_its_solid_body() -> void:
	bed.piece(&"bust_plinth", Vector3(0.0, 0.0, -6.0), Vector3(0.7, 1.9, 0.7))
	bed.piece(&"pedestal", Vector3(4.0, 0.0, -6.0), Vector3(1.2, 0.8, 1.2))
	bed.piece(&"sculpture", Vector3(4.0, 0.8, -6.0), Vector3(0.9, 2.0, 0.9))
	bed.install_env()
	await physics_frames(2)
	var space := bed.get_world_3d().direct_space_state
	var at_bust := Hitscan.ray(space, Vector3(0.0, 1.6, 0.0), Vector3(0.0, 1.6, -12.0))
	assert_true(not at_bust.is_empty() and at_bust["hurtbox"] != null and (at_bust["hurtbox"] as Hurtbox).receiver is EnvBust, "the bust takes the round")
	var at_statue := Hitscan.ray(space, Vector3(4.0, 2.0, 0.0), Vector3(4.0, 2.0, -12.0))
	assert_true(not at_statue.is_empty() and at_statue["hurtbox"] != null and (at_statue["hurtbox"] as Hurtbox).receiver is EnvStatue, "the statue takes the round")
