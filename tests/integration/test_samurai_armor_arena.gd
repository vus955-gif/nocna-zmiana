extends TestCase
## The samurai armour (design pietro-1-projekt 5.5) in a sandbox: the
## knight's shield rule on its sode (a frontal shot blocked, a flank hit
## lands, the taser drops the guard), kamae when it hunts (the yari comes
## down level, the sode up) against the armour stand asleep (the yari
## upright), the yari thrust that reaches 2.8 m after its telegraph and
## passes a guard 2 m to the side, its dust.

var target: TargetDummy


func before_each() -> void:
	GameInput.capture_allowed = false
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color.GRAY)
	target = TargetDummy.new()
	target.position = Vector3(0, 0, -12)
	add_child(target)


func after_each() -> void:
	GameInput.capture_allowed = true


func _armour(at: Vector3 = Vector3.ZERO, awake: bool = true) -> SamuraiArmor:
	var armour := SamuraiArmor.new()
	armour.position = at
	armour.target = target
	add_child(armour)
	armour.face(at + Vector3(0, 0, -5))
	if awake:
		armour.summoned = true
		armour.brain.wake()
	return armour


## A hit on [param armour] from [param degrees] off its front (positive:
## from its right). True when its sode stopped it.
func _blocked(armour: SamuraiArmor, degrees: float, kind: DamageInfo.Kind = DamageInfo.Kind.BALLISTIC) -> bool:
	var toward := (-armour.global_basis.z).rotated(Vector3.UP, -deg_to_rad(degrees))
	var info := DamageInfo.make(10.0, kind)
	info.direction = -toward
	info.position = armour.global_position + Vector3.UP * 1.2
	var before := armour.health.current
	armour.take_damage(info)
	return is_equal_approx(armour.health.current, before)


func test_is_an_empty_suit_of_180_hp_on_the_knight_rules() -> void:
	var armour := _armour(Vector3.ZERO, false)
	assert_eq(SamuraiArmor.KIND, &"samurai_armor")
	assert_true(armour is Knight, "built on the knight")
	assert_eq(armour.health.max_health, 180.0)
	assert_eq(armour.dust_value, 8)
	assert_eq(armour.material_kind, ExhibitMaterial.Kind.METAL)
	assert_true(armour.rig is SamuraiRig, "the Blender model is on")
	assert_true(armour.rig is KnightRig, "with the knight's plates")
	if armour.rig != null:
		assert_eq((armour.rig as KnightRig).plates_left(), 5, "five plates: the left pauldron is the sode")
	var made := NightSpawner.make(&"samurai_armor")
	assert_true(made is SamuraiArmor)
	made.free()
	var kinds: Array[StringName] = [&"knight", &"samurai_armor"]
	assert_eq(NightSpawner.preferred(kinds, &"knight"), &"samurai_armor", "Asia's slots now get samurai armour")


func test_the_sode_blocks_the_front_and_the_taser_drops_it() -> void:
	var armour := _armour(Vector3.ZERO, false)
	await physics_frames(2)
	assert_true(_blocked(armour, 0.0))
	assert_true(_blocked(armour, 60.0))
	assert_false(_blocked(armour, 80.0), "past the sode")
	assert_false(_blocked(armour, 180.0), "from behind")
	assert_false(_blocked(armour, 0.0, DamageInfo.Kind.ELECTRIC), "the current goes through the lacquered iron")
	var stun := DamageInfo.make(2.0, DamageInfo.Kind.ELECTRIC)
	stun.stun_time = 3.0
	stun.direction = Vector3.BACK
	armour.take_damage(stun)
	assert_true(armour.brain.is_stunned())
	assert_false(_blocked(armour, 0.0), "stunned, the sode is down")
	if armour.rig != null:
		await physics_frames(40)
		assert_lt((armour.rig as SamuraiRig).sode_angle(), -0.3, "the sode arm dropped")


func test_asleep_the_yari_stands_upright_and_hunting_it_takes_kamae() -> void:
	target.position = Vector3(0, 0, 30)   # behind it: nothing to notice
	var armour := _armour(Vector3.ZERO, false)
	await physics_frames(40)
	var rig := armour.rig as SamuraiRig
	if rig == null:
		return
	assert_eq(armour.brain.state, EnemyBrain.State.DORMANT, "asleep on its stand")
	assert_gt(rig.yari_angle(), 1.0, "the armour stand: the yari upright (%.2f rad)" % rig.yari_angle())
	assert_lt(rig.sode_angle(), -0.2, "the sode down at its side")
	assert_lt(rig.ember_energy(), 0.05, "the embers out")
	target.position = Vector3(0, 0, -12)
	armour.summoned = true
	armour.brain.wake()
	await physics_frames(90)
	assert_lt(absf(rig.yari_angle()), 0.3, "kamae: the yari level at the guard (%.2f rad)" % rig.yari_angle())
	assert_gt(rig.sode_angle(), 0.3, "the sode up before the chest")
	assert_gt(rig.ember_energy(), 0.2, "the embers smoulder")


func test_the_thrust_reaches_a_guard_at_two_point_eight_metres_after_its_telegraph() -> void:
	target.position = Vector3(0, 0, -2.8)
	var armour := _armour()
	var started := -1
	var glints := 0
	for i in 240:
		await get_tree().physics_frame
		if armour.brain.state == EnemyBrain.State.ATTACK and started < 0:
			started = i
		if not target.hits.is_empty():
			assert_almost_eq((i - started) / 60.0, SamuraiArmor.THRUST_WINDUP, 0.05, "0.8 s of telegraph")
			break
	assert_eq(target.hits.size(), 1)
	if not target.hits.is_empty():
		assert_eq(target.hits[0].amount, SamuraiArmor.THRUST_DAMAGE)
		assert_eq(target.hits[0].knockback, SamuraiArmor.THRUST_KNOCKBACK)
	assert_gt(armour.global_position.z, -1.4, "the lunge carried it about half a metre (plus its step in)")
	assert_lt(armour.global_position.z, -0.3)


func test_the_yari_passes_a_guard_two_metres_to_the_side() -> void:
	target.position = Vector3(0, 0, -2.8)
	var armour := _armour()
	for i in 240:
		await get_tree().physics_frame
		if armour.brain.state == EnemyBrain.State.ATTACK and armour.brain.windup_progress() > 0.85:
			break
	assert_eq(armour.brain.state, EnemyBrain.State.ATTACK)
	target.position = Vector3(2.0, 0, -2.8)   # steps 2 m to the side at the last moment
	await physics_frames(30)
	assert_eq(target.hits.size(), 0, "the thrust is narrow: it passes him")


func test_the_embers_flare_and_the_tip_glints_in_the_telegraph() -> void:
	target.position = Vector3(0, 0, -2.8)
	var armour := _armour()
	var rig := armour.rig as SamuraiRig
	var calm := -1.0
	var peak := 0.0
	for i in 240:
		await get_tree().physics_frame
		if armour.brain.state == EnemyBrain.State.HUNT and rig != null:
			calm = rig.ember_energy()   # the last calm reading before the telegraph
		if armour.brain.state == EnemyBrain.State.ATTACK and rig != null:
			peak = maxf(peak, rig.ember_energy())
		if not target.hits.is_empty():
			break
	if rig != null:
		assert_gt(peak, calm + 0.8, "the embers flare in the telegraph (%.2f over %.2f)" % [peak, calm])
	assert_true(armour._glinted, "the tip glinted")
