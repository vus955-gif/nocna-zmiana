extends TestCase

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
	body.size = Vector3(0.8, 1.2, 0.8)
	dummy.add_child(Hurtbox.make(dummy, body, Vector3(0, 0.9, 0)))
	var head := SphereShape3D.new()
	head.radius = 0.25
	dummy.add_child(Hurtbox.make(dummy, head, Vector3(0, 1.8, 0), true))


func _weapon(id: StringName) -> WeaponData:
	return load("res://src/weapons/data/%s.tres" % id)


func test_pistol_shot_hits_the_body_for_base_damage() -> void:
	holder.give(_weapon(&"pistol"))
	await physics_frames(2)
	assert_true(holder.try_fire())
	assert_eq(dummy.hits.size(), 1)
	if dummy.hits.size() == 1:
		assert_eq(dummy.hits[0].amount, 20.0)
		assert_eq(dummy.hits[0].kind, DamageInfo.Kind.BALLISTIC)
		assert_eq(dummy.hits[0].source, user)
		assert_false(dummy.hits[0].weak_point)


func test_pistol_headshot_doubles_damage() -> void:
	holder.position = Vector3(0, 1.8, 0)
	holder.give(_weapon(&"pistol"))
	await physics_frames(2)
	holder.try_fire()
	assert_eq(dummy.hits.size(), 1)
	if dummy.hits.size() == 1:
		assert_eq(dummy.hits[0].amount, 40.0)
		assert_true(dummy.hits[0].weak_point)


func test_shotgun_pellets_merge_into_one_hit() -> void:
	dummy.position = Vector3(0, 0, -2.5)
	holder.give(_weapon(&"shotgun"))
	await physics_frames(2)
	holder.try_fire()
	assert_eq(dummy.hits.size(), 1)
	if dummy.hits.size() == 1:
		assert_eq(dummy.hits[0].amount, 90.0)
		assert_almost_eq(dummy.hits[0].knockback, 12.0)


func test_taser_hit_is_electric_and_stuns() -> void:
	holder.give(_weapon(&"taser"))
	await physics_frames(2)
	holder.try_fire()
	assert_eq(dummy.hits.size(), 1)
	if dummy.hits.size() == 1:
		assert_eq(dummy.hits[0].kind, DamageInfo.Kind.ELECTRIC)
		assert_eq(dummy.hits[0].stun_time, 3.0)


func test_taser_does_not_reach_far() -> void:
	dummy.position = Vector3(0, 0, -12)
	holder.give(_weapon(&"taser"))
	await physics_frames(2)
	holder.try_fire()
	assert_eq(dummy.hits.size(), 0)


func test_fists_hit_close_and_can_finish() -> void:
	dummy.position = Vector3(0, 0, -1.3)
	await physics_frames(2)
	assert_true(holder.try_punch())
	assert_eq(dummy.hits.size(), 1)
	if dummy.hits.size() == 1:
		assert_true(dummy.hits[0].can_finish)
		assert_eq(dummy.hits[0].kind, DamageInfo.Kind.BLUNT)


func test_fists_do_not_hit_through_walls() -> void:
	dummy.position = Vector3(0, 0, -1.3)
	Greybox.box(self, Vector3(0, 1.0, -0.6), Vector3(4, 3, 0.1), Color.GRAY)
	await physics_frames(2)
	assert_true(holder.try_punch(), "the punch is thrown")
	assert_eq(dummy.hits.size(), 0, "the wall takes it")


func test_point_blank_shot_from_inside_the_target_hits() -> void:
	dummy.position = Vector3(0, 0, -0.2)   # the eye is inside the body hurtbox
	holder.give(_weapon(&"pistol"))
	await physics_frames(2)
	holder.try_fire()
	assert_eq(dummy.hits.size(), 1)
	if dummy.hits.size() == 1:
		var hit := dummy.hits[0]
		assert_lt(hit.position.z, -0.3, "the hit shows in front of the gun, not at the eye")
		assert_true(hit.normal.is_equal_approx(Vector3(0, 0, 1)), "facing the guard: %s" % hit.normal)
	for child in Fx.get_children():
		assert_false(child is MeshInstance3D and not child.is_queued_for_deletion(), "no trail back to the eye")


func test_fists_do_not_reach_far() -> void:
	dummy.position = Vector3(0, 0, -4)
	await physics_frames(2)
	holder.try_punch()
	assert_eq(dummy.hits.size(), 0)


func test_emptying_the_magazine_starts_a_reload() -> void:
	var data: WeaponData = _weapon(&"pistol").duplicate()
	data.cooldown = 0.0
	var state := holder.give(data)
	await physics_frames(2)
	for i in 12:
		holder.try_fire()
	assert_eq(state.magazine, 0)
	assert_true(state.is_reloading())
	assert_false(holder.try_fire())
	state.tick(1.2)
	assert_eq(state.magazine, 12)
	assert_eq(state.reserve, 24)


func test_switching_weapons_cancels_reload() -> void:
	var pistol := holder.give(_weapon(&"pistol"))
	holder.give(_weapon(&"shotgun"))
	pistol.magazine = 5
	assert_true(holder.try_reload())
	holder.select_id(&"shotgun")
	assert_false(pistol.is_reloading())
	assert_eq(holder.current_state().data.id, &"shotgun")


func test_slot_order_is_taser_pistol_shotgun() -> void:
	holder.give(_weapon(&"shotgun"))
	holder.give(_weapon(&"taser"))
	holder.give(_weapon(&"pistol"))
	var ids := []
	for state in holder.owned:
		ids.append(state.data.id)
	assert_eq(ids, [&"taser", &"pistol", &"shotgun"])
	assert_eq(holder.current_state().data.id, &"shotgun", "first weapon stays selected")


func test_ammo_pickup_goes_to_the_matching_weapon() -> void:
	var pistol := holder.give(_weapon(&"pistol"))
	assert_eq(holder.add_ammo(&"bullets", 10), 10)
	assert_eq(pistol.reserve, 46)
	assert_eq(holder.add_ammo(&"shells", 5), 0, "no shotgun yet")


func test_cycle_wraps_around() -> void:
	holder.give(_weapon(&"taser"))
	holder.give(_weapon(&"pistol"))
	holder.cycle(-1)
	assert_eq(holder.current_state().data.id, &"pistol")
	holder.cycle(1)
	assert_eq(holder.current_state().data.id, &"taser")


func test_disabled_holder_does_not_attack() -> void:
	holder.give(_weapon(&"pistol"))
	holder.enabled = false
	await physics_frames(2)
	assert_false(holder.try_fire())
	assert_false(holder.try_punch())
	assert_eq(dummy.hits.size(), 0)


# --- fatigue's sway (plan 2026-10-10-kawiarnia-zmeczenie) ---------------------

func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## A real guard on a floor with a pistol in hand (the holder reads his fatigue).
func _guard() -> Player:
	Greybox.box(self, Vector3(0, -0.5, 20), Vector3(40, 1, 80), Color.GRAY)
	var guard := Player.new()
	guard.position = Vector3(0, 0.05, 20)
	add_child(guard)
	guard.weapons.give(_weapon(&"pistol"))
	return guard


## The widest the view strays from its rest sideways while walking [param frames] frames.
func _walking_amplitude(guard: Player, frames: int) -> float:
	var view := guard.weapons.view_of(&"pistol")
	var widest := 0.0
	Input.action_press(&"move_forward")
	for i in frames:
		await get_tree().physics_frame
		widest = maxf(widest, absf(view.position.x - WeaponHolder.REST.x))
	Input.action_release(&"move_forward")
	await physics_frames(20)
	return widest


func test_tired_hands_bob_more_and_drift_at_rest() -> void:
	var guard := _guard()
	await physics_frames(5)
	await _frames(20)
	var view := guard.weapons.view_of(&"pistol")
	assert_lt((view.position - WeaponHolder.REST).length(), 0.0005, "fresh and still: the view rests")
	var fresh := await _walking_amplitude(guard, 60)
	assert_gt(fresh, 0.003, "the walking bob")
	guard.fatigue.level = 1.0
	await physics_frames(2)
	await _frames(30)
	var drift := (view.position - WeaponHolder.REST).length()
	assert_gt(drift, 0.001, "tired hands drift even at rest")
	assert_lt(drift, 0.012, "but only a little")
	var tired := await _walking_amplitude(guard, 60)
	assert_gt(tired, fresh * 1.6, "twice the bob at the worst of the night (%.4f vs %.4f)" % [tired, fresh])


## Frame to frame over [param frames] frames (process frames): the widest jump
## of the view (m) and how often its sideways motion turns round.
func _tremor(view: Node3D, frames: int) -> Dictionary:
	var last := view.position
	var widest := 0.0
	var turns := 0
	var heading := 0.0
	for i in frames:
		await get_tree().process_frame
		widest = maxf(widest, (view.position - last).length())
		var step := view.position.x - last.x
		if absf(step) > 0.00005:
			if heading != 0.0 and signf(step) != heading:
				turns += 1
			heading = signf(step)
		last = view.position
	return {"widest": widest, "turns": turns}


func test_the_witching_special_shakes_the_hands_for_a_moment() -> void:
	var guard := _guard()
	await physics_frames(5)
	await _frames(40)
	var view := guard.weapons.view_of(&"pistol")
	# a guard who drank nothing: the view stands still once the switch has settled
	var calm := await _tremor(view, 60)
	assert_lt(calm["widest"], 0.0002, "fresh hands rest (%.5f)" % calm["widest"])
	guard.fatigue.drink(&"special")
	await physics_frames(1)
	await _frames(40)
	var shaking := await _tremor(view, 60)
	assert_gt(shaking["widest"], 0.0008, "the view jumps frame to frame (%.5f)" % shaking["widest"])
	assert_gt(shaking["widest"], calm["widest"] * 4.0, "and not like a guard who drank nothing")
	# a tremor of some 10 Hz, not a slow wander: it turns round many times a second
	assert_gt(shaking["turns"], 8, "a fast tremor (%d turns in a second)" % shaking["turns"])
	await physics_frames(roundi(Fatigue.JITTER_TIME * 60.0) + 30)
	var steady := await _tremor(view, 20)
	assert_lt(steady["widest"], 0.0002, "12 s later the hands are steady")
