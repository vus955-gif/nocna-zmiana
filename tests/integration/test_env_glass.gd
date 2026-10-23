extends TestCase
## Glass cases and ceramics of the reactive layer (plan docs/superpowers/
## plans/2026-10-21-srodowisko-walka.md): any real hit breaks them at once
## (a taser's arc does not), with shards, a noise the exhibits hear, cuts for
## exhibits right beside; a rifle round goes on through the glass; a punch
## thrown at an exhibit never lands on the case beside it instead; broken
## for the night.

var bed: EnvTestbed
var holder: WeaponHolder


func before_each() -> void:
	bed = EnvTestbed.new()
	add_child(bed)
	bed.setup()


func after_each() -> void:
	if is_instance_valid(bed):
		bed.free()


func _weapon(id: StringName) -> WeaponData:
	return load("res://src/weapons/data/%s.tres" % id)


## A weapon holder at [param eye] looking down -Z (its user a plain node).
func _gun(eye: Vector3) -> WeaponHolder:
	var user := Node3D.new()
	bed.add_child(user)
	holder = WeaponHolder.new()
	holder.user = user
	holder.position = eye
	user.add_child(holder)
	return holder


func _glass() -> Array[EnvGlass]:
	var out: Array[EnvGlass] = []
	for each in bed.env.props:
		if each is EnvGlass:
			out.append(each)
	return out


func test_every_case_with_glass_gets_a_glass_prop_and_nothing_else_does() -> void:
	bed.piece(&"case", Vector3(0.0, 0.0, -5.0), Vector3(1.4, 1.6, 1.0))
	bed.piece(&"bench", Vector3(4.0, 0.0, -5.0), Vector3(2.0, 0.5, 0.6))
	bed.piece(&"case", Vector3(-4.0, 0.0, -5.0), Vector3(2.2, 2.0, 1.0), 0.0, true, &"lobby_haven")
	bed.layout.add_room(&"lobby_haven", [Rect2(-6.0, -6.0, 3.0, 3.0)] as Array[Rect2], 0.0, 3.0, Color.GRAY).haven = true
	bed.install_env()
	var glass := _glass()
	assert_eq(glass.size(), 1, "one case outside the haven")
	assert_eq(glass[0].id, EnvLayer.make_id(&"glass", EnvTestbed.ROOM, Vector3(0.0, 0.0, -5.0)))
	assert_gt(glass[0].box.size.y, 0.4, "its zone covers the glass")
	assert_lt(glass[0].box.position.y, 1.2)
	assert_gt(glass[0].box.end.y, 1.3)


func test_a_pistol_round_shatters_the_glass_heard_by_exhibits_and_cutting_those_beside() -> void:
	bed.piece(&"case", Vector3(0.0, 0.0, -5.0), Vector3(1.4, 1.6, 1.0))
	var beside := bed.dummy(Vector3(1.1, 0.0, -5.0))
	var far := bed.dummy(Vector3(6.0, 0.0, -5.0))
	bed.install_env()
	var glass := _glass()[0]
	var pane := glass.panes[0][0] as MeshInstance3D
	assert_true(pane.visible)
	var noises := watch(Events.noise_made)
	var chunks_before := Fx.chunk_count()
	_gun(Vector3(0.0, 1.25, 0.0)).give(_weapon(&"pistol"))
	await physics_frames(2)
	assert_true(holder.try_fire())
	assert_true(glass.is_down, "one round breaks it")
	assert_false(pane.visible, "the pane is gone")
	assert_gt(float(Fx.chunk_count() - chunks_before), 3.0, "shards fly")
	assert_eq(glass.hurtbox.collision_layer, 0, "shots meet the case's body again")
	var heard := noises.filter(func(call: Array) -> bool: return call[2] == &"glass")
	assert_eq(heard.size(), 1, "a crash the exhibits hear")
	if heard.size() == 1:
		assert_almost_eq(float(heard[0][1]), EnvRules.NOISE_GLASS, 0.01)
	assert_eq(beside.hits.size(), 1, "the exhibit beside it is cut")
	if beside.hits.size() == 1:
		assert_almost_eq(beside.hits[0].amount, EnvGlass.CUT_DAMAGE, 0.01)
	assert_eq(far.hits.size(), 0)
	assert_true(bed.run.is_used(EnvRules.used_id(glass.id)), "broken for the night")


func test_a_rifle_round_goes_on_through_the_glass_into_the_exhibit_behind() -> void:
	bed.piece(&"case", Vector3(0.0, 0.0, -5.0), Vector3(1.4, 1.6, 1.0))
	var behind := bed.dummy(Vector3(0.0, 0.0, -8.0))
	bed.install_env()
	_gun(Vector3(0.0, 1.25, 0.0)).give(_weapon(&"rifle_hunt"))
	await physics_frames(2)
	assert_true(holder.try_fire())
	assert_true(_glass()[0].is_down)
	assert_eq(behind.hits.size(), 1, "the round pierces the glass")


func test_the_museums_props_do_not_count_against_the_rifles_three_exhibits() -> void:
	bed.piece(&"case", Vector3(0.0, 0.0, -3.0), Vector3(1.4, 1.6, 1.0))
	bed.lamp(&"bulb", Vector3(0.0, 1.3, -4.0))   # (its zone is in the line of fire too)
	var rows: Array[TargetDummy] = []
	for z in [-6.0, -8.0, -10.0, -12.0]:
		rows.append(bed.dummy(Vector3(0.0, 0.0, z)))
	bed.install_env()
	_gun(Vector3(0.0, 1.25, 0.0)).give(_weapon(&"rifle_hunt"))
	await physics_frames(2)
	assert_true(holder.try_fire())
	assert_true(_glass()[0].is_down, "the case breaks")
	for i in 3:
		assert_eq(rows[i].hits.size(), 1, "exhibit %d of the three is pierced" % (i + 1))
	assert_eq(rows[3].hits.size(), 0, "the fourth is one too many")


func test_a_pierce_through_props_still_ends_on_the_wall() -> void:
	bed.piece(&"case", Vector3(0.0, 0.0, -3.0), Vector3(1.4, 1.6, 1.0))
	bed.install_env()
	await physics_frames(2)
	var space := bed.get_world_3d().direct_space_state
	var found := Hitscan.pierce(space, Vector3(0.0, 1.25, 0.0), Vector3(0.0, 1.25, -30.0), 3)
	assert_gt(float(found.size()), 1.0, "the glass, then the wall")
	assert_true(found[found.size() - 1]["hurtbox"] == null, "the wall ends the shot")


func test_a_taser_arc_only_crackles_on_glass() -> void:
	bed.piece(&"case", Vector3(0.0, 0.0, -3.0), Vector3(1.4, 1.6, 1.0))
	bed.install_env()
	_gun(Vector3(0.0, 1.25, 0.0)).give(_weapon(&"taser"))
	await physics_frames(2)
	holder.try_fire()
	assert_false(_glass()[0].is_down)


func test_a_blast_beside_a_case_breaks_it() -> void:
	bed.piece(&"case", Vector3(0.0, 0.0, -5.0), Vector3(1.4, 1.6, 1.0))
	bed.install_env()
	await physics_frames(2)
	Blast.explode(bed, Vector3(0.0, 1.0, -3.6), 2.5, 20.0, 4.0, DamageInfo.Kind.FIRE, bed.player, Vector3.FORWARD, &"flare")
	assert_true(_glass()[0].is_down)


func test_a_punch_at_an_exhibit_never_lands_on_the_case_beside_it() -> void:
	var target := bed.dummy(Vector3(0.5, 0.0, -1.0))
	bed.piece(&"case", Vector3(-0.35, 0.0, -1.0), Vector3(0.4, 1.6, 0.4))
	bed.install_env()
	_gun(Vector3(0.0, 1.0, 0.0))
	await physics_frames(2)
	assert_true(holder.try_punch())
	assert_eq(target.hits.size(), 1, "the blow lands on the exhibit")
	assert_false(_glass()[0].is_down, "not on the glass beside it")


func test_an_aimed_punch_breaks_the_glass() -> void:
	bed.piece(&"case", Vector3(0.0, 0.0, -1.2), Vector3(0.8, 1.6, 0.6))
	bed.install_env()
	_gun(Vector3(0.0, 1.25, 0.0))
	await physics_frames(2)
	holder.try_punch()
	assert_true(_glass()[0].is_down)


func test_a_punch_aimed_at_a_case_still_lands_on_an_exhibit_in_reach() -> void:
	bed.piece(&"case", Vector3(0.0, 0.0, -1.2), Vector3(0.8, 1.6, 0.6))
	var beside := bed.dummy(Vector3(0.6, 0.0, -0.9))
	var far := bed.dummy(Vector3(5.0, 0.0, -1.0))
	bed.install_env()
	_gun(Vector3(0.0, 1.0, 0.0))
	await physics_frames(2)
	assert_true(holder.try_punch())
	assert_true(_glass()[0].is_down, "the glass under the crosshair breaks")
	# (the glass's shards cut it too: only the fists' own blow counts here)
	var blows := beside.hits.filter(func(hit: DamageInfo) -> bool: return hit.weapon == &"fists")
	assert_eq(blows.size(), 1, "and the exhibit in reach takes the blow too")
	assert_eq(far.hits.size(), 0)


func test_a_jar_on_a_plinth_smashes_and_a_statue_does_not() -> void:
	bed.piece(&"plinth", Vector3(0.0, 0.0, -4.0), Vector3(0.9, 1.0, 0.9))
	var jar := bed.piece(&"sculpture", Vector3(0.0, 1.0, -4.0), Vector3(0.6, 0.7, 0.6), 0.0, false)
	bed.piece(&"sculpture", Vector3(4.0, 0.0, -4.0), Vector3(1.2, 4.0, 1.2))
	bed.install_env()
	var jars: Array[EnvCeramic] = []
	for each in bed.env.props:
		if each is EnvCeramic:
			jars.append(each)
	assert_eq(jars.size(), 1, "only the small piece set on something")
	var noises := watch(Events.noise_made)
	jars[0].take_damage(bed.hit(7.0, &"gatling", Vector3(0.0, 1.3, -4.0)))
	assert_true(jars[0].is_down)
	assert_false(jar.visible, "the jar is gone")
	assert_eq(noises.size(), 1)
	# a resumed night: the jar is gone again, quietly
	bed.env.free()
	jar.visible = true
	bed.install_env()
	for each in bed.env.props:
		if each is EnvCeramic:
			assert_true(each.is_down)
	assert_false(jar.visible)
