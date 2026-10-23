extends TestCase
## EnvLayer (plan docs/superpowers/plans/2026-10-21-srodowisko-walka.md):
## stable ids, the activity budget (the oldest swing settles, a warning or
## a fall never), what broke is remembered for the night and rebuilt broken,
## and Floor I's game installs the layer.

var bed: EnvTestbed
var museum: Museum


## A prop that swings on every hit (a lamp's motion, nothing else).
class Swinger extends EnvProp:
	var settled := false

	func _hit(_info: DamageInfo) -> void:
		phase = Phase.MOVING
		wake()

	func settle() -> void:
		settled = true
		phase = Phase.IDLE


## A prop that breaks on any hit.
class Breaker extends EnvProp:
	var finished := false

	func _hit(_info: DamageInfo) -> void:
		mark_down()
		_finish_down()

	func _finish_down() -> void:
		finished = true


## A prop that starts a warning on any hit.
class Warner extends EnvProp:
	func _hit(_info: DamageInfo) -> void:
		phase = Phase.WARNING
		wake()


func before_each() -> void:
	bed = EnvTestbed.new()
	add_child(bed)
	bed.setup()


func after_each() -> void:
	if is_instance_valid(bed):
		bed.free()
	if is_instance_valid(museum):
		museum.free()


func _prop(prop: EnvProp, prop_id: String, at: Vector3 = Vector3.ZERO) -> EnvProp:
	prop.id = StringName(prop_id)
	prop.position = at
	prop.add_zone(SphereShape3D.new())
	bed.env.add_prop(prop)
	return prop


func test_an_id_names_the_kind_the_room_and_the_place() -> void:
	var id := EnvLayer.make_id(&"glass", &"egypt_vestibule", Vector3(-43.0, 0.0, 25.5))
	assert_eq(id, &"glass@egypt_vestibule:-430,0,255")
	assert_eq(EnvLayer.make_id(&"glass", &"egypt_vestibule", Vector3(-43.02, 0.01, 25.49)), id, "the same place to the decimetre")
	assert_ne(EnvLayer.make_id(&"lamp", &"egypt_vestibule", Vector3(-43.0, 0.0, 25.5)), id)


func test_an_idle_prop_has_no_process_and_a_hit_one_moves_within_the_budget() -> void:
	bed.install_env()
	var swingers: Array[Swinger] = []
	for i in EnvRules.ACTIVE_CAP + 4:
		swingers.append(_prop(Swinger.new(), "swing:%d" % i, Vector3(i, 2.0, 0.0)) as Swinger)
	await physics_frames(1)
	assert_false(swingers[0].is_physics_processing(), "an idle prop costs nothing")
	for each in swingers:
		each.take_damage(bed.hit(20.0, &"pistol", each.global_position))
	assert_true(bed.env.active_count() <= EnvRules.ACTIVE_CAP, "at most ACTIVE_CAP move at once")
	assert_true(swingers[0].settled and swingers[3].settled, "the oldest swings settle to make room")
	assert_false(swingers[0].is_physics_processing())
	assert_false(swingers[EnvRules.ACTIVE_CAP + 3].settled, "the newest swings on")
	assert_true(swingers[EnvRules.ACTIVE_CAP + 3].is_physics_processing())


func test_a_warning_always_plays_out_whatever_the_budget() -> void:
	bed.install_env()
	var warner := _prop(Warner.new(), "warn:0")
	warner.take_damage(bed.hit(20.0, &"pistol", Vector3.ZERO))
	for i in EnvRules.ACTIVE_CAP + 2:
		_prop(Swinger.new(), "swing:%d" % i, Vector3(i, 2.0, 0.0)).take_damage(bed.hit(20.0, &"pistol", Vector3.ZERO))
	assert_true(warner.is_physics_processing(), "a warning is never cut short")
	assert_eq(warner.phase, EnvProp.Phase.WARNING)


func test_what_broke_is_remembered_for_the_night_and_built_broken_again() -> void:
	bed.install_env()
	var breaker := _prop(Breaker.new(), "case@hall:0,0,0") as Breaker
	var downs := watch(breaker.knocked_down)
	breaker.take_damage(bed.hit(20.0, &"pistol", Vector3.ZERO))
	assert_true(breaker.is_down)
	assert_eq(downs.size(), 1)
	assert_true(bed.run.is_used(&"env:case@hall:0,0,0"), "RunState.used remembers it (saved with the night)")
	assert_eq(breaker.hurtbox.collision_layer, 0, "nothing to hit any more")
	breaker.take_damage(bed.hit(20.0, &"pistol", Vector3.ZERO))
	assert_eq(downs.size(), 1, "broken once")
	# the night resumed: the same prop built again comes back broken, quietly
	bed.env.free()
	bed.install_env()
	var again := _prop(Breaker.new(), "case@hall:0,0,0") as Breaker
	var again_downs := watch(again.knocked_down)
	bed.env.restore()
	assert_true(again.is_down)
	assert_true(again.finished, "in its broken look")
	assert_eq(again_downs.size(), 0, "no second break, no noise")
	assert_eq(again.hurtbox.collision_layer, 0)
	var fresh := _prop(Breaker.new(), "case@hall:10,0,0") as Breaker
	bed.env.restore()
	assert_false(fresh.is_down, "only what broke")


func test_a_new_night_is_whole_again() -> void:
	bed.install_env()
	_prop(Breaker.new(), "case@hall:0,0,0").take_damage(bed.hit(20.0, &"pistol", Vector3.ZERO))
	bed.run.reset()
	bed.env.free()
	bed.install_env()
	var again := _prop(Breaker.new(), "case@hall:0,0,0")
	bed.env.restore()
	assert_false(again.is_down, "next night: whole")


## One of everything the layer answers for, in [param room] around [param x].
func _dress(room: StringName, x: float) -> void:
	bed.piece(&"case", Vector3(x - 3.0, 0.0, -3.0), Vector3(1.4, 1.6, 1.0), 0.0, true, room)
	bed.lamp(&"ceiling_lamp", Vector3(x, 6.0, -3.0), 1.5, 8.0, room)
	bed.lamp(&"bulb", Vector3(x + 1.0, 3.0, -3.0), 1.5, 8.0, room)
	bed.piece(&"lantern", Vector3(x + 2.0, 5.0, -3.0), Vector3(0.6, 0.9, 0.6), 0.0, false, room)
	bed.lamp(&"", Vector3(x + 2.0, 5.4, -3.0), 1.5, 8.0, room)
	bed.piece(&"bust_plinth", Vector3(x + 3.0, 0.0, -3.0), Vector3(0.7, 1.9, 0.7), 0.0, true, room)
	bed.piece(&"banner", Vector3(x - 2.0, 1.5, -4.9), Vector3(1.4, 4.0, 0.1), 0.0, false, room)
	bed.piece(&"pedestal", Vector3(x - 3.0, 0.0, 1.0), Vector3(1.2, 0.8, 1.2), 0.0, true, room)
	bed.piece(&"sculpture", Vector3(x - 3.0, 0.8, 1.0), Vector3(0.9, 2.0, 0.9), 0.0, true, room)
	bed.piece(&"plinth", Vector3(x + 3.0, 0.0, 1.0), Vector3(0.9, 1.0, 0.9), 0.0, true, room)
	bed.piece(&"sculpture", Vector3(x + 3.0, 1.0, 1.0), Vector3(0.6, 0.7, 0.6), 0.0, false, room)
	bed.painting(Vector3(x, 2.2, -4.95))


func test_no_prop_stands_in_a_guardians_arena() -> void:
	var arena := &"arena"
	bed.layout.add_room(arena, [Rect2(20.0, -5.0, 8.0, 8.0)] as Array[Rect2], 0.0, 8.0, Color.GRAY)
	bed.layout.add_marker(&"guardian_centaur", Vector3(24.0, 0.0, -1.0), arena)
	_dress(EnvTestbed.ROOM, 0.0)
	_dress(arena, 24.0)
	bed.install_env()
	var outside := {}
	for each in bed.env.props:
		assert_ne(each.room, arena, "%s: none in the arena" % each.id)
		outside[String(each.id).get_slice("@", 0)] = true
	for kind in ["glass", "lamp", "bust", "statue", "ceramic", "banner", "painting"]:
		assert_true(outside.has(kind), "(control) a %s outside the arena" % kind)


## Window review 22.10: the falling Colossus left a hit zone whose owner was
## gone in the guard's sight, and the tag hint's look tested it with `is`
## (a script error every hint check).
func test_the_tag_hint_skips_a_hit_zone_whose_owner_is_gone() -> void:
	bed.install_env()
	var camera := Camera3D.new()
	bed.add_child(camera)
	camera.global_position = Vector3(0.0, 1.6, 6.0)
	camera.current = true
	var gone := Node3D.new()
	bed.add_child(gone)
	var zone := Hurtbox.make(gone, SphereShape3D.new(), Vector3(0.0, 1.6, 0.0))
	bed.add_child(zone)
	await physics_frames(2)
	gone.free()
	bed.env._check_hint()
	assert_false(bed.env.hinted, "no hint (and no error) from a zone whose owner is freed")
	camera.free()


func test_floor_ones_game_installs_the_layer() -> void:
	bed.free()
	Museum.level_id = &"floor1"
	GameState.new_game()
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	await physics_frames(2)
	var env := museum.floor_game.env
	assert_not_null(env, "FloorGame.env")
	assert_true(env is EnvLayer)
	assert_eq(env.guard(), museum.player)
	assert_eq(env.run, museum.run)


func test_the_performance_overlay_reads_the_environment() -> void:
	assert_true(PerfStats.environment(get_tree()).is_empty(), "no layer, no numbers")
	bed.install_env()
	var breaker := _prop(Breaker.new(), "case@hall:0,0,0")
	_prop(Swinger.new(), "swing:0", Vector3(2.0, 2.0, 0.0)).take_damage(bed.hit(20.0, &"pistol", Vector3.ZERO))
	breaker.take_damage(bed.hit(20.0, &"pistol", Vector3.ZERO))
	var numbers := PerfStats.environment(get_tree())
	assert_eq(int(numbers.get("props", -1)), 2)
	assert_eq(int(numbers.get("active", -1)), 1, "one swings")
	assert_eq(int(numbers.get("down", -1)), 1, "one broke")
	assert_true(MuseumSections.NAMES.has(&"environment"), "the systems view times the layer")
	assert_lt(float(MuseumSections.NAMES.find(&"environment")), float(MuseumSections.NAMES.find(&"floor_game")), "before the floor's logic that holds it")
	var keys := PackedStringArray()
	for row: Array in PerfOverlay.ROWS:
		keys.append(String(row[0]))
	assert_true(keys.has("environment"), "a row of the numbers")
