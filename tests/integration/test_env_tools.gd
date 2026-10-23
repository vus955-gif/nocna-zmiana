extends TestCase
## The tagged tools of environmental combat (plan docs/superpowers/plans/
## 2026-10-21-srodowisko-walka.md, backlog #23, #39): the red tag sets a
## tool going (its body only after enough), it creaks for the warning with
## its strike marked on the floor and nothing lands before; then it drops,
## topples, fires or rolls onto the exhibits in its zone (and only those),
## the guard in the way taking what his own blast would; what moves loses
## its collision; it stays spent for the night and comes back so on Continue;
## the first look at a tag gives the hint.

var bed: EnvTestbed
const HALL := EnvTestbed.ROOM


func before_each() -> void:
	bed = EnvTestbed.new()
	add_child(bed)
	bed.setup()


func after_each() -> void:
	if is_instance_valid(bed):
		bed.free()


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _shoot_tag(tool: EnvTool, weapon: StringName = &"pistol", amount: float = 20.0) -> void:
	tool.tag.take_damage(bed.hit(amount, weapon, tool.tag.global_position, -tool.tag.global_basis.z))


func _lamp_entry() -> Dictionary:
	return {"id": &"lamp_test", "kind": &"drop", "build": &"storm_lamp", "room": HALL,
		"at": Vector3(0.0, 4.3, -6.0), "mount": Vector3(0.0, 8.0, -6.0), "radius": 0.9,
		"exhibit_damage": 40.0, "guard_damage": 15.0, "knockback": 3.0,
		"fire": {"radius": 1.5, "seconds": 3.0, "dps": 10.0, "guard": 4.0}}


func _column_entry() -> Dictionary:
	return {"id": &"column_test", "kind": &"topple", "build": &"column", "room": HALL,
		"at": Vector3(0.0, 0.0, -14.4), "yaw": PI, "height": 4.7, "width": 0.9, "depth": 0.9,
		"exhibit_damage": 140.0, "guard_damage": 35.0, "knockback": 8.0}


func test_a_tool_wears_the_red_tag_and_nothing_else_does() -> void:
	bed.piece(&"case", Vector3(4.0, 0.0, -6.0), Vector3(1.4, 1.6, 1.0))
	bed.lamp(&"ceiling_lamp", Vector3(-4.0, 6.0, -6.0))
	bed.install_env()
	var tool := bed.tool(_lamp_entry())
	assert_not_null(tool.tag, "the tool wears a tag")
	assert_true(tool.tag.zone.collision_layer == Layers.HURTBOX, "the tag can be shot")
	assert_eq(bed.find_children("*", "EnvTag", true, false).size(), 1, "only the tool wears one")
	var ring := tool.tag.get_node(^"Ring") as MeshInstance3D
	assert_true((ring.material_override as StandardMaterial3D).emission_enabled, "its ring glows")
	assert_true(EnvRules.TOOL_WARNING >= EnvRules.MIN_WARNING)


func test_the_tag_sets_it_going_and_nothing_lands_within_the_warning() -> void:
	var under := bed.dummy(Vector3(0.0, 0.0, -6.0))
	var aside := bed.dummy(Vector3(3.0, 0.0, -6.0))
	bed.install_env()
	var tool := bed.tool(_lamp_entry())
	var marks := watch(tool.triggered)
	_shoot_tag(tool, &"gatling", 7.0)
	assert_eq(marks.size(), 1, "any round on the tag")
	assert_eq(tool.phase, EnvProp.Phase.WARNING)
	assert_eq(tool.find_children("*", "GroundMark", true, false).size(), 1, "its strike marked on the floor")
	assert_true(tool.tag.spent, "the ring goes dark")
	await _seconds(EnvRules.MIN_WARNING - 0.05)
	assert_eq(under.hits.size(), 0, "nothing lands within the telegraph")
	await _seconds(2.0)
	assert_true(tool.is_down)
	assert_true(under.hits.size() >= 1, "it lands on the exhibit under it")
	if not under.hits.is_empty():
		assert_almost_eq(under.hits[0].amount, 40.0, 0.01)
		assert_eq(under.hits[0].source, bed.player, "credited to the guard")
	assert_eq(aside.hits.size(), 0, "nothing outside its disc")
	assert_eq(tool.tag.zone.collision_layer, 0, "spent: its tag is off")


func test_the_storm_lamp_sets_the_floor_alight_and_burns_what_walks_in() -> void:
	var under := bed.dummy(Vector3(0.0, 0.0, -6.0))
	var near := bed.dummy(Vector3(1.4, 0.0, -6.0))
	bed.install_env()
	var tool := bed.tool(_lamp_entry())
	_shoot_tag(tool)
	await _seconds(2.0)
	var fires := tool.find_children("*", "EnvFire", true, false)
	assert_eq(fires.size(), 1, "its oil burns")
	await _seconds(1.0)
	var burned := near.hits.filter(func(h: DamageInfo) -> bool: return h.kind == DamageInfo.Kind.FIRE)
	assert_gt(float(burned.size()), 0.0, "an exhibit in the burning oil takes fire")
	assert_eq(near.hits.filter(func(h: DamageInfo) -> bool: return h.kind == DamageInfo.Kind.BLUNT).size(), 0, "outside the lamp's own blow")
	assert_gt(float(under.hits.size()), 1.0)
	await _seconds(3.0)
	assert_eq(tool.find_children("*", "EnvFire", true, false).size(), 0, "it burns out")


func test_the_guard_under_his_own_tool_takes_what_his_own_blast_would() -> void:
	bed.lamp(&"chandelier", Vector3(0.0, 6.0, -6.0))
	bed.install_env()
	var tool := bed.tool({"id": &"chandelier_test", "kind": &"drop", "build": &"chandelier", "room": HALL,
		"near": Vector3(0.0, 6.0, -6.0), "radius": 2.0, "exhibit_damage": 150.0, "guard_damage": 35.0, "knockback": 10.0})
	assert_not_null(tool, "it takes over the hall's chandelier")
	bed.player.global_position = Vector3(0.5, 0.05, -6.0)
	await physics_frames(2)
	bed.player.health.apply_damage(40.0)
	_shoot_tag(tool)
	await _seconds(EnvRules.TOOL_WARNING + 1.2)
	assert_true(tool.is_down)
	assert_almost_eq(bed.player.health.current, bed.player.health.max_health * EnvRules.GUARD_FLOOR, 0.01, "never below half by his own doing")


func test_a_chandelier_comes_down_after_enough_rounds_in_its_body_and_the_hall_goes_dark() -> void:
	var light := bed.lamp(&"chandelier", Vector3(0.0, 6.0, -6.0))
	var under := bed.dummy(Vector3(0.0, 0.0, -6.0))
	LevelPerception.configure_layout(bed.layout, {}, bed.lights)
	var lit := PerceptionWorld.light_at(Vector3(0.0, 1.0, -6.0))
	bed.install_env()
	var tool := bed.tool({"id": &"chandelier_test", "kind": &"drop", "build": &"chandelier", "room": HALL,
		"near": Vector3(0.0, 6.0, -6.0), "radius": 2.0, "exhibit_damage": 150.0, "guard_damage": 35.0, "knockback": 10.0})
	for i in 2:
		tool.take_damage(bed.hit(20.0, &"pistol", Vector3(0.0, 6.5, -5.2), Vector3.FORWARD))
	assert_eq(tool.phase, EnvProp.Phase.IDLE, "two rounds in its body only rock it")
	tool.take_damage(bed.hit(20.0, &"pistol", Vector3(0.0, 6.5, -5.2), Vector3.FORWARD))
	assert_eq(tool.phase, EnvProp.Phase.WARNING, "the third brings it down")
	assert_true(light.visible, "lit while it creaks")
	await _seconds(EnvRules.TOOL_WARNING + 0.05)
	assert_false(light.visible, "the chain snaps: its lamp dies")
	assert_lt(PerceptionWorld.light_at(Vector3(0.0, 1.0, -6.0)), lit, "the exhibits see the hall darker")
	await _seconds(1.5)
	assert_true(under.hits.size() == 1)
	assert_lt(bed.fixture_of(light).global_position.y, 1.0, "the wreck on the floor")


func test_a_fallen_chandelier_stays_dark_through_every_switch_of_its_circuit() -> void:
	var light := bed.lamp(&"chandelier", Vector3(0.0, 6.0, -6.0))
	var fixture := bed.fixture_of(light)
	var hanging := fixture.global_transform
	# (the greybox fixture has no glow of its own: its candles, as the art's)
	var candles := MeshInstance3D.new()
	candles.mesh = SphereMesh.new()
	var flame := StandardMaterial3D.new()
	flame.emission_enabled = true
	flame.emission = Color(1.0, 0.8, 0.5)
	flame.emission_energy_multiplier = 2.0
	candles.material_override = flame
	fixture.add_child(candles)
	bed.install_env()
	var entry := {"id": &"chandelier_test", "kind": &"drop", "build": &"chandelier", "room": HALL,
		"near": Vector3(0.0, 6.0, -6.0), "radius": 2.0, "exhibit_damage": 150.0, "guard_damage": 35.0, "knockback": 10.0}
	var tool := bed.tool(entry)
	assert_true(LevelKit.is_lit(fixture), "(control) it glows while it hangs")
	_shoot_tag(tool)
	await _seconds(EnvRules.TOOL_WARNING + 1.5)
	assert_true(tool.is_down)
	assert_false(LevelKit.is_lit(fixture), "the wreck has no glow")
	NightModifiers.set_lights(bed, LightSpec.MAIN, false)
	NightModifiers.set_lights(bed, LightSpec.MAIN, true)
	assert_false(LevelKit.is_lit(fixture), "the circuit switched back on: the wreck on the floor stays dark")
	assert_false(light.visible, "and so does its lamp")
	# the night resumed: the wreck again, dark through the switches too
	bed.env.free()
	fixture.remove_meta(&"env_broken")
	light.remove_meta(&"env_broken")
	LevelKit.set_lit(fixture, true)
	fixture.global_transform = hanging   # (a resumed night builds the floor afresh)
	light.visible = true
	bed.install_env()
	var again := bed.tool(entry)
	bed.env.restore()   # (the testbed's tool came after the layer's own restore)
	assert_true(again.is_down, "(control) remembered for the night")
	NightModifiers.set_lights(bed, LightSpec.MAIN, true)
	assert_false(LevelKit.is_lit(fixture), "resumed: no switch lights the wreck")
	assert_false(light.visible)


func test_a_column_topples_along_its_lane_and_leaves_no_collision() -> void:
	var in_lane := bed.dummy(Vector3(0.0, 0.0, -11.0))
	var aside := bed.dummy(Vector3(2.5, 0.0, -11.0))
	bed.install_env()
	var tool := bed.tool(_column_entry()) as EnvToppleTool
	var bodies := tool.find_children("*", "StaticBody3D", true, false)
	assert_eq(bodies.size(), 1, "it stands solid")
	assert_eq((bodies[0] as StaticBody3D).collision_layer, Layers.WORLD)
	var lane: Array = tool.lane()
	assert_gt((lane[1] as Vector3).z, 4.0, "its lane is as long as it is tall")
	_shoot_tag(tool)
	await _seconds(EnvRules.TOOL_WARNING + EnvToppleTool.FALL_TIME + 0.3)
	assert_true(tool.is_down)
	assert_eq(in_lane.hits.size(), 1, "it falls on the exhibit in its lane")
	assert_eq(aside.hits.size(), 0)
	assert_eq((bodies[0] as StaticBody3D).collision_layer, 0, "lying down, it blocks nobody")


func test_a_wall_bookcase_falls_into_the_aisle_dazing_what_it_crushes() -> void:
	var shelf := bed.piece(&"shelf", Vector3(0.0, 0.0, -14.75), Vector3(3.0, 3.4, 0.5), PI)
	var in_front := bed.dummy(Vector3(0.0, 0.0, -12.5))
	bed.install_env()
	var tool := bed.tool({"id": &"bookcase_test", "kind": &"topple", "build": &"bookcase", "kit": &"shelf", "room": HALL,
		"near": Vector3(0.0, 0.0, -14.75), "exhibit_damage": 110.0, "guard_damage": 30.0, "stun": 1.5, "knockback": 6.0})
	assert_not_null(tool)
	assert_eq(bed.env.props.filter(func(p: EnvProp) -> bool: return p is EnvShelf).size(), 0, "a tool's shelf is no plain shelf")
	var pages := PageFlutter.count()
	_shoot_tag(tool)
	await _seconds(EnvRules.TOOL_WARNING + EnvToppleTool.FALL_TIME + 0.3)
	assert_eq(in_front.hits.size(), 1)
	if in_front.hits.size() == 1:
		assert_almost_eq(in_front.hits[0].stun_time, 1.5, 0.01, "dazed")
	assert_eq((shelf as StaticBody3D).collision_layer, 0, "it took its collision down with it")
	assert_gt(float(PageFlutter.count() - pages), 10.0, "books burst out")
	assert_lt(absf(shelf.global_basis.y.normalized().dot(Vector3.UP)), 0.2, "lying on its face")


func test_a_crate_of_fire_arrows_fires_its_volley_across_the_fan() -> void:
	var left := bed.dummy(Vector3(0.42, 0.0, -9.0))
	var right := bed.dummy(Vector3(-0.42, 0.0, -9.0))
	var behind := bed.dummy(Vector3(0.0, 0.0, 14.0))
	bed.install_env()
	var tool := bed.tool({"id": &"rockets_test", "kind": &"volley", "room": HALL,
		"at": Vector3(0.0, 0.0, -14.5), "yaw": PI, "rockets": 6, "spread_deg": 20.0, "reach": 14.0})
	var launched: Array = []
	tool.child_entered_tree.connect(func(child: Node) -> void:
		if child is HwachaRocket:
			launched.append(child))
	_shoot_tag(tool)
	await _seconds(EnvRules.MIN_WARNING - 0.05)
	assert_eq(launched.size(), 0, "nothing flies within the warning")
	await _seconds(EnvRules.TOOL_WARNING - EnvRules.MIN_WARNING + 0.8)
	assert_eq(launched.size(), 6, "six fire-arrows")
	await _seconds(1.5)
	assert_true(tool.is_down)
	assert_gt(float(left.hits.size() + right.hits.size()), 1.0, "the volley lands on the exhibits in its fan")
	assert_eq(behind.hits.size(), 0, "nothing behind the crate")


func test_a_stone_wheel_rolls_over_everything_in_its_path_once() -> void:
	var first := bed.dummy(Vector3(0.0, 0.0, -9.0))
	var second := bed.dummy(Vector3(0.0, 0.0, -6.5))
	var aside := bed.dummy(Vector3(3.0, 0.0, -8.0))
	bed.install_env()
	var tool := bed.tool({"id": &"wheel_test", "kind": &"roll", "room": HALL,
		"at": Vector3(0.0, 0.0, -13.0), "yaw": PI, "radius": 1.1, "thickness": 0.4, "distance": 9.0,
		"exhibit_damage": 160.0, "guard_damage": 40.0, "knockback": 10.0})
	bed.player.global_position = Vector3(0.0, 0.05, -5.0)
	await physics_frames(2)
	var health := bed.player.health.current
	_shoot_tag(tool)
	bed.player.global_position = Vector3(0.0, 0.05, -5.0)
	await _seconds(EnvRules.TOOL_WARNING + 3.0)
	assert_true(tool.is_down)
	assert_eq(first.hits.size(), 1, "each thing once")
	assert_eq(second.hits.size(), 1)
	assert_eq(aside.hits.size(), 0)
	assert_lt(bed.player.health.current, health, "the guard in its path is hit")
	assert_true(bed.player.health.current >= bed.player.health.max_health * EnvRules.GUARD_FLOOR - 0.01)


func test_a_spent_tool_comes_back_spent_on_a_resumed_night() -> void:
	bed.install_env()
	var tool := bed.tool(_column_entry())
	_shoot_tag(tool)
	await _seconds(EnvRules.TOOL_WARNING + EnvToppleTool.FALL_TIME + 0.3)
	assert_true(bed.run.is_used(EnvRules.used_id(&"column_test")))
	var used := bed.run.used.duplicate()
	bed.free()
	bed = EnvTestbed.new()
	add_child(bed)
	bed.setup()
	bed.run.used.assign(used)
	bed.install_env()
	var again := bed.tool(_column_entry()) as EnvToppleTool
	bed.env.restore()
	assert_true(again.is_down)
	assert_true(again.tag.spent)
	assert_eq(again.tag.zone.collision_layer, 0)
	var body := again.find_children("*", "StaticBody3D", true, false)[0] as StaticBody3D
	assert_eq(body.collision_layer, 0, "lying where it fell, blocking nobody")
	assert_lt(again.load_node.global_basis.y.normalized().dot(Vector3.UP), 0.2, "lying down")


func test_the_first_look_at_a_tag_gives_the_hint_once() -> void:
	bed.install_env()
	var tool := bed.tool(_lamp_entry())
	var hints := watch(Events.hint_requested)
	var eye := Vector3(0.0, bed.player.eye_height, 2.0)
	var to := tool.tag.global_position - eye
	bed.player.respawn(Vector3(0.0, 0.0, 2.0), atan2(-to.x, -to.z))
	bed.player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	await _seconds(0.6)
	assert_eq(hints.size(), 1, "the hint about the red tags")
	await _seconds(0.6)
	assert_eq(hints.size(), 1, "once")


func test_the_night_starts_warm_up_draws_the_tags_ring_and_the_broken_glass() -> void:
	var camera := Camera3D.new()
	bed.add_child(camera)
	var warm := ShaderWarmUp.start(bed, camera)
	var drawn := {}
	for node in warm.find_children("*", "MeshInstance3D", true, false):
		var view := node as MeshInstance3D
		for i in view.mesh.get_surface_count():
			drawn[view.get_surface_override_material(i)] = true
	assert_true(drawn.has(EnvTag.ring_material()), "the tag's glowing ring")
	assert_true(drawn.has(EnvTag._dark_material()), "its ring gone dark")
	assert_true(drawn.has(EnvBreak.invisible()), "a broken pane (the surface that draws nothing)")


func test_a_falling_load_finds_every_exhibit_even_beside_a_zone_of_many_shapes() -> void:
	# (a T-Rex's rib cage is one zone of many shapes: each overlaps on its own)
	var crowded := bed.dummy(Vector3(0.0, 0.0, -6.0))
	var zone := crowded.get_child(0) as Hurtbox
	for i in 150:
		var piece := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3.ONE * 0.1
		piece.shape = box
		piece.position = Vector3(randf_range(-0.3, 0.3), randf_range(-0.8, 0.8), randf_range(-0.3, 0.3))
		zone.add_child(piece)
	var beside: Array[TargetDummy] = []
	for x in [-1.6, -1.0, 1.0, 1.6]:
		beside.append(bed.dummy(Vector3(x, 0.0, -6.0)))
	await physics_frames(2)
	var found := EnvStrike.in_disc(bed, Vector3(0.0, 0.0, -6.0), 2.4, 2.2)
	assert_true(found.has(crowded), "the many-shaped one")
	for each in beside:
		assert_true(found.has(each), "and every exhibit beside it, at %s" % each.global_position)
	assert_eq(found.size(), 5, "each once")


## A harpoon fired from [param from] straight along -Z (stuck in what it
## hits a moment later).
func _harpoon_into(from: Vector3) -> Harpoon:
	var harpoon := Harpoon.launch(from, Vector3(0.0, 0.0, -40.0), load("res://src/weapons/data/harpoon.tres"), bed.player)
	bed.add_child(harpoon)
	await _seconds(0.4)
	return harpoon


## [param harpoon], stuck in [param tool], stays where it struck its load
## ([param carrier]) through the tool's whole fall.
func _rides_with(harpoon: Harpoon, tool: EnvTool, carrier: Node3D) -> void:
	assert_eq(harpoon.phase, Harpoon.Phase.STUCK, "(control) it sticks in %s" % tool.id)
	var held := carrier.global_transform.affine_inverse() * harpoon.global_position
	var start := harpoon.global_position
	tool.trigger()
	await _seconds(EnvRules.TOOL_WARNING + 3.5)
	assert_true(tool.is_down, "(control) %s went off" % tool.id)
	assert_true(is_instance_valid(harpoon) and harpoon.phase == Harpoon.Phase.STUCK, "%s: still stuck in it" % tool.id)
	if is_instance_valid(harpoon):
		assert_gt(harpoon.global_position.distance_to(start), 1.0, "%s: it moved with the load" % tool.id)
		var now := carrier.global_transform.affine_inverse() * harpoon.global_position
		assert_lt(now.distance_to(held), 0.05, "%s: where it struck the load" % tool.id)


func test_a_harpoon_in_a_relief_slab_comes_down_with_it() -> void:
	bed.install_env()
	var tool := bed.tool({"id": &"slab_test", "kind": &"drop", "build": &"relief_slab", "room": HALL,
		"at": Vector3(0.0, 3.4, -6.0), "mount": Vector3(0.0, 8.0, -6.0), "radius": 1.4,
		"exhibit_damage": 180.0, "guard_damage": 40.0, "knockback": 9.0})
	await physics_frames(2)
	var harpoon: Harpoon = await _harpoon_into(Vector3(0.0, 4.5, -2.0))
	assert_eq(tool.carrier(), (tool as EnvDropTool).load_node, "(control) the slab carries it")
	await _rides_with(harpoon, tool, tool.carrier())
	if is_instance_valid(harpoon):
		assert_lt(harpoon.global_position.y, 1.5, "down on the floor with the slab")


func test_a_harpoon_in_a_cracked_column_topples_with_it() -> void:
	bed.install_env()
	var tool := bed.tool(_column_entry())
	await physics_frames(2)
	var harpoon: Harpoon = await _harpoon_into(Vector3(0.0, 3.0, -9.0))
	assert_eq(tool.carrier(), (tool as EnvToppleTool).load_node, "(control) the column carries it")
	await _rides_with(harpoon, tool, tool.carrier())
	if is_instance_valid(harpoon):
		assert_lt(harpoon.global_position.y, 1.5, "down on the floor with the column")


func test_a_harpoon_in_a_stone_wheel_rolls_with_it() -> void:
	bed.install_env()
	var tool := bed.tool({"id": &"wheel_test", "kind": &"roll", "room": HALL,
		"at": Vector3(0.0, 0.0, -13.0), "yaw": PI, "radius": 1.1, "thickness": 0.4, "distance": 6.5,
		"exhibit_damage": 160.0, "guard_damage": 40.0, "knockback": 10.0})
	await physics_frames(2)
	var harpoon: Harpoon = await _harpoon_into(Vector3(0.0, 1.8, -6.0))
	assert_ne(tool.carrier(), tool as Node3D, "(control) the stone carries it, not the trestles")
	var start_z := harpoon.global_position.z
	await _rides_with(harpoon, tool, tool.carrier())
	if is_instance_valid(harpoon):
		assert_gt(harpoon.global_position.z - start_z, 4.0, "it rolled along with the stone")
