extends TestCase
## The gatling in the guard's hands: slot 4, crank before the first round,
## real hits, the walking penalty, capped camera shake.

var user: Node3D
var holder: WeaponHolder
var dummy: TargetDummy


func before_each() -> void:
	user = Node3D.new()
	add_child(user)
	holder = WeaponHolder.new()
	holder.user = user
	holder.position = Vector3(0, 1.0, 0)
	user.add_child(holder)
	dummy = TargetDummy.new()
	dummy.position = Vector3(0, 0, -6)
	add_child(dummy)
	var body := BoxShape3D.new()
	body.size = Vector3(1.2, 1.4, 0.8)
	dummy.add_child(Hurtbox.make(dummy, body, Vector3(0, 0.9, 0)))


func _gatling() -> WeaponData:
	return load("res://src/weapons/data/gatling.tres")


func test_gatling_takes_slot_four_after_the_shotgun() -> void:
	for id in [&"gatling", &"pistol", &"taser", &"shotgun"]:
		holder.give(load("res://src/weapons/data/%s.tres" % id))
	var order: Array = holder.owned.map(func(s: WeaponState) -> StringName: return s.data.id)
	assert_eq(order, [&"taser", &"pistol", &"shotgun", &"gatling"])
	var key := InputEventKey.new()
	key.physical_keycode = KEY_4
	key.pressed = true
	holder.select_id(&"taser")
	Input.parse_input_event(key)
	await physics_frames(2)
	assert_eq(holder.current_state().data.id, &"gatling", "key 4")


func test_first_round_after_the_crank_then_fourteen_a_second() -> void:
	holder.give(_gatling())
	await physics_frames(2)
	var frames := 0
	while dummy.hits.is_empty() and frames < 60:
		holder.try_fire()
		await get_tree().physics_frame
		frames += 1
	assert_almost_eq(frames / 60.0, 0.45, 2.5 / 60.0, "nothing before the barrels are up to speed")
	var before := dummy.hits.size()
	for i in 60:
		holder.try_fire()
		await get_tree().physics_frame
	var rounds := dummy.hits.size() - before
	assert_true(rounds >= 13 and rounds <= 15, "rounds in a second: %d" % rounds)
	var hit := dummy.hits[-1]
	assert_eq(hit.amount, 7.0)
	assert_eq(hit.weapon, &"gatling")
	assert_eq(hit.kind, DamageInfo.Kind.BALLISTIC)


func test_no_reload_on_the_belt() -> void:
	var state := holder.give(_gatling())
	state.magazine = 50
	assert_false(holder.try_reload())
	assert_false(state.is_reloading())


func test_long_burst_shakes_only_up_to_the_cap() -> void:
	var camera := ShakeCamera.new()
	add_child(camera)
	camera.current = true
	holder.give(_gatling())
	for i in 120:
		holder.try_fire()
		await get_tree().physics_frame
	assert_gt(camera.trauma.value, 0.25, "a steady rumble")
	assert_lt(camera.trauma.value, 0.41, "never the full shake")


func test_guard_walks_slower_and_cannot_sprint_while_cranking() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color.GRAY)
	var player := Player.new()
	player.position = Vector3(0, 0.05, 20)
	add_child(player)
	player.weapons.give(_gatling())
	await physics_frames(5)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	Input.action_press(&"fire")
	await physics_frames(40)
	var slow := Vector2(player.velocity.x, player.velocity.z).length()
	assert_almost_eq(slow, player.walk_speed * 0.65, 0.05, "walk -35%, no sprint")
	assert_false(player.sprinting)
	assert_gt(player.stamina.current, player.stamina.maximum - 0.35, "at most one frame of sprint (the press itself)")
	Input.action_release(&"fire")
	Input.action_release(&"sprint")
	await physics_frames(20)
	var normal := Vector2(player.velocity.x, player.velocity.z).length()
	assert_almost_eq(normal, player.walk_speed, 0.05, "full speed once the trigger is let go")
	Input.action_release(&"move_forward")


## The Blender model's rig: the barrel cluster spins about its own axis
## (rotation.z), the crank turns (rotation.x), the right hand rides the
## crank's knob, the muzzle stays put.
func test_view_turns_the_barrels_while_spinning() -> void:
	holder.give(_gatling())
	var view := holder.get_node(^"gatling") as ViewmodelRig
	assert_not_null(view, "the gatling is the Blender model on its rig")
	if view == null:
		return
	var barrels := view.part_node(&"barrels")
	var crank := view.part_node(&"crank")
	var hand := view.part_node(&"hand_r")
	var knob := view.part_node(&"CrankKnob")
	var muzzle := view.get_node(^"Muzzle") as Node3D
	var muzzle_rest := muzzle.position
	var knob_to_hand := hand.global_position - knob.global_position
	var before_z := barrels.rotation.z
	var before_x := crank.rotation.x
	for i in 20:
		holder.try_fire()
		await get_tree().process_frame
		await get_tree().physics_frame
	assert_gt(absf(angle_difference(barrels.rotation.z, before_z)), 0.3, "the barrels turn about their axis")
	assert_almost_eq(barrels.rotation.x, 0.0, 0.001, "only about their axis")
	assert_gt(absf(angle_difference(crank.rotation.x, before_x)), 0.2, "the crank turns")
	assert_lt((hand.global_position - knob.global_position).distance_to(knob_to_hand), 0.002, "the hand rides the knob")
	assert_lt(muzzle.position.distance_to(muzzle_rest), 0.03, "the muzzle does not spin with the barrels")
	assert_not_null(view.gatling_driver(), "sounds and smoke on the rig")


## A long burst heats the rig's barrels to a glow (their own material),
## which cools off once the trigger is let go.
func test_long_burst_makes_the_barrels_glow() -> void:
	holder.give(_gatling())
	var view := holder.get_node(^"gatling") as ViewmodelRig
	if view == null:
		fail("no rig")
		return
	var barrels := view.part_node(&"barrels") as MeshInstance3D
	var body := view.part_node(&"gatling") as MeshInstance3D
	assert_ne(barrels.get_surface_override_material(0), body.get_surface_override_material(0), "the barrels glow alone")
	for i in 240:
		holder.try_fire()
		await get_tree().process_frame
		await get_tree().physics_frame
	assert_gt(view.barrel_heat(), 0.5, "hot after a long burst")
	for i in 400:
		await get_tree().process_frame
	assert_lt(view.barrel_heat(), 0.05, "cooled off")


## Without the model the greybox view still turns its barrels.
func test_greybox_gatling_when_the_model_is_off() -> void:
	ArtLibrary.models_enabled = false
	holder.give(_gatling())
	ArtLibrary.models_enabled = true
	var view := holder.get_node(^"gatling") as Node3D
	assert_true(view is GatlingView, "greybox view")
	var barrels := view.find_child("barrels", true, false) as Node3D
	var before := barrels.transform.basis
	for i in 20:
		holder.try_fire()
		await get_tree().process_frame
		await get_tree().physics_frame
	assert_false(barrels.transform.basis.is_equal_approx(before), "the barrels turn")


## An empty gatling is just carried: cranking it does not slow the guard.
func test_an_empty_gatling_held_does_not_slow_the_guard() -> void:
	var state := holder.give(_gatling())
	for i in 5:
		holder.try_fire()
		await get_tree().physics_frame
	assert_lt(holder.move_factor(), 1.0, "cranking a loaded gun")
	state.magazine = 0
	state.reserve = 0
	for i in 5:
		holder.try_fire()
		await get_tree().physics_frame
	assert_eq(holder.move_factor(), 1.0, "nothing to fire: full speed")
	assert_true(holder.allows_sprint())


## Slows never stack below half speed (a gatling firing in a paint
## puddle), and a dash while cranking goes at full dash speed.
func test_slows_stop_at_half_speed_and_a_dash_ignores_them() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color.GRAY)
	var player := Player.new()
	player.position = Vector3(0, 0.05, 20)
	add_child(player)
	player.weapons.give(_gatling())
	await physics_frames(5)
	Input.action_press(&"fire")
	await physics_frames(10)
	player.slow(0.6, 1.0)
	assert_almost_eq(player.speed_factor(), Player.MIN_SPEED_FACTOR, 0.0001, "0.65 x 0.6 is floored at 0.5")
	assert_true(player.dash(Vector3(1, 0, 0)), "a dash while cranking")
	await physics_frames(2)
	assert_almost_eq(Vector2(player.velocity.x, player.velocity.z).length(), player.dash_speed, 0.01, "at full dash speed")
	Input.action_release(&"fire")


## Fourteen rounds a second: only every other one brings its sparks, its
## bullet hole and its muzzle light (the hit itself always lands).
func test_only_every_other_round_brings_its_impact_effects() -> void:
	Greybox.box(self, Vector3(0, 1.0, -10), Vector3(6, 4, 0.5), Color.GRAY)
	dummy.position = Vector3(30, 0, 0)   # out of the line of fire
	holder.give(_gatling())
	Fx.clear()
	await physics_frames(2)
	var rounds := 0
	var state := holder.current_state()
	while rounds < 12:
		var before := state.magazine
		holder.try_fire()
		await get_tree().physics_frame
		rounds += before - state.magazine
	var holes := Fx.get_children().filter(func(n: Node) -> bool: return n is Decal and not n.is_queued_for_deletion()).size()
	assert_eq(holes, 6, "a hole for every other round")
	Fx.clear()
	dummy.position = Vector3(0, 0, -6)
	var effects: Array[bool] = []
	var start := dummy.hits.size()
	for i in 30:
		holder.try_fire()
		await get_tree().physics_frame
	for k in range(start, dummy.hits.size()):
		effects.append(dummy.hits[k].effects)
	assert_gt(effects.size(), 4)
	assert_gt(effects.count(true), 0)
	assert_gt(effects.count(false), 0, "every other hit lands without sparks")
