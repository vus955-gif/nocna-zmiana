extends TestCase
## The marble hoplite (design pietro-1-projekt 5.3): its shield arc, the
## spear thrust from 3 m, the taser dropping the shield, and the phalanx
## (a line with overlapping shields that closes ranks).

var target: TargetDummy


func before_each() -> void:
	GameInput.capture_allowed = false
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color.GRAY)
	target = TargetDummy.new()
	target.position = Vector3(0, 0, -12)
	add_child(target)


func after_each() -> void:
	GameInput.capture_allowed = true


func _hoplite(at: Vector3, awake: bool = true) -> Hoplite:
	var hoplite := Hoplite.new()
	hoplite.position = at
	hoplite.target = target
	add_child(hoplite)
	hoplite.face(at + Vector3(0, 0, -5))
	if awake:
		hoplite.summoned = true
		hoplite.brain.wake()
	return hoplite


## A hit on [param hoplite] from [param degrees] off its front (positive:
## from its right). True when its shield stopped it.
func _blocked(hoplite: Hoplite, degrees: float, kind: DamageInfo.Kind = DamageInfo.Kind.BALLISTIC) -> bool:
	var toward := (-hoplite.global_basis.z).rotated(Vector3.UP, -deg_to_rad(degrees))
	var info := DamageInfo.make(10.0, kind)
	info.direction = -toward
	info.position = hoplite.global_position + Vector3.UP * 1.2
	var before := hoplite.health.current
	hoplite.take_damage(info)
	return is_equal_approx(hoplite.health.current, before)


func test_is_a_140_health_marble_hoplite() -> void:
	var hoplite := _hoplite(Vector3.ZERO, false)
	assert_eq(Hoplite.KIND, &"hoplite")
	assert_eq(hoplite.health.max_health, 140.0)
	assert_eq(hoplite.dust_value, 7)
	assert_eq(hoplite.material_kind, ExhibitMaterial.Kind.MARBLE)
	assert_true(hoplite.rig is HopliteRig, "the Blender model is on")
	var made := NightSpawner.make(&"hoplite")
	assert_true(made is Hoplite)
	made.free()
	var kinds: Array[StringName] = [&"knight", &"hoplite"]
	assert_eq(NightSpawner.preferred(kinds, &"knight"), &"hoplite", "Greece's slots now get hoplites")


func test_alone_its_shield_covers_sixty_degrees() -> void:
	var hoplite := _hoplite(Vector3.ZERO, false)
	await physics_frames(2)
	assert_true(_blocked(hoplite, 0.0))
	assert_true(_blocked(hoplite, 50.0))
	assert_true(_blocked(hoplite, -50.0))
	assert_false(_blocked(hoplite, 70.0), "past the rim of its shield")
	assert_false(_blocked(hoplite, -70.0))
	assert_false(_blocked(hoplite, 0.0, DamageInfo.Kind.ELECTRIC), "the current goes through bronze")


func test_the_taser_drops_its_shield() -> void:
	var hoplite := _hoplite(Vector3.ZERO, false)
	await physics_frames(2)
	var stun := DamageInfo.make(2.0, DamageInfo.Kind.ELECTRIC)
	stun.stun_time = 3.0
	stun.direction = Vector3.BACK
	hoplite.take_damage(stun)
	assert_true(hoplite.brain.is_stunned())
	assert_false(_blocked(hoplite, 0.0), "a stunned hoplite is open from the front")


func test_the_spear_thrust_reaches_three_metres_after_its_telegraph() -> void:
	target.position = Vector3(0, 0, -2.8)
	var hoplite := _hoplite(Vector3.ZERO)
	var started := -1
	for i in 240:
		await get_tree().physics_frame
		if hoplite.brain.state == EnemyBrain.State.ATTACK and started < 0:
			started = i
		if not target.hits.is_empty():
			assert_almost_eq((i - started) / 60.0, 0.7, 0.04, "0.7 s of telegraph")
			break
	assert_eq(target.hits.size(), 1)
	if not target.hits.is_empty():
		assert_eq(target.hits[0].amount, 18.0)


func test_a_guard_who_backs_out_of_reach_is_missed() -> void:
	target.position = Vector3(0, 0, -2.8)
	var hoplite := _hoplite(Vector3.ZERO)
	for i in 240:
		await get_tree().physics_frame
		if hoplite.brain.state == EnemyBrain.State.ATTACK and hoplite.brain.windup_progress() > 0.8:
			break
	target.position = Vector3(0, 0, -4.6)
	await physics_frames(20)
	assert_eq(target.hits.size(), 0, "out of the spear's reach")


func test_side_by_side_they_form_a_phalanx_with_overlapping_shields() -> void:
	var left := _hoplite(Vector3(-0.45, 0, 0))
	var right := _hoplite(Vector3(0.45, 0, 0))
	await physics_frames(90)
	var pack := left.phalanx()
	assert_not_null(pack, "a phalanx formed")
	assert_eq(right.phalanx(), pack, "both in it")
	if pack == null:
		return
	assert_eq(pack.members[0], left, "left to right")
	# from the right, 70 degrees off its front, the left man is covered by his neighbour's shield
	assert_true(_blocked(left, 70.0), "covered toward its neighbour")
	assert_false(_blocked(left, -70.0), "open on the end of the line")
	# a shot aimed between them strikes a shield
	await physics_frames(30)
	var middle := (left.global_position + right.global_position) * 0.5 + Vector3.UP * 1.2
	var front := pack.front
	var space := get_viewport().find_world_3d().direct_space_state
	var hit := Hitscan.ray(space, middle + front * 5.0, middle - front * 2.0)
	assert_false(hit.is_empty(), "the shot hits something")
	if not hit.is_empty():
		var zone: Hurtbox = hit["hurtbox"]
		assert_not_null(zone, "a hit zone, not the floor or the wall behind")
		if zone != null:
			assert_true(zone.receiver is Hoplite)
			var info := DamageInfo.make(10.0, DamageInfo.Kind.BALLISTIC)
			info.direction = -front
			info.position = hit["position"]
			var before: float = (zone.receiver as Hoplite).health.current
			(zone.receiver as Hoplite).take_damage(info)
			assert_eq((zone.receiver as Hoplite).health.current, before, "the shield wall stops it")


func test_three_hold_a_line_and_advance() -> void:
	var men: Array[Hoplite] = [_hoplite(Vector3(-1.6, 0, 0.3)), _hoplite(Vector3(0.1, 0, -0.4)), _hoplite(Vector3(1.5, 0, 0.5))]
	var start := Vector3.ZERO
	for man in men:
		start += man.global_position / 3.0
	await physics_frames(180)
	var pack := men[0].phalanx()
	assert_not_null(pack)
	if pack == null:
		return
	assert_eq(pack.members.size(), 3)
	for i in 2:
		var gap := pack.members[i].global_position.distance_to(pack.members[i + 1].global_position)
		assert_almost_eq(gap, Phalanx.SPACING, 0.2, "shoulder to shoulder")
	for man in men:
		var facing := -man.global_basis.z
		assert_lt(rad_to_deg(facing.angle_to(pack.front)), 15.0, "all face the same way")
	var now := Vector3.ZERO
	for man in men:
		now += man.global_position / 3.0
	assert_lt(now.z, start.z - 1.0, "the line advances on the guard")


func test_a_stunned_man_drops_out_and_the_line_closes() -> void:
	var men: Array[Hoplite] = [_hoplite(Vector3(-0.85, 0, 0)), _hoplite(Vector3(0, 0, 0)), _hoplite(Vector3(0.85, 0, 0))]
	await physics_frames(90)
	var pack := men[1].phalanx()
	assert_not_null(pack)
	var stun := DamageInfo.make(1.0, DamageInfo.Kind.ELECTRIC)
	stun.stun_time = 5.0
	men[1].take_damage(stun)
	await physics_frames(150)
	assert_null_phalanx(men[1])
	var outer := men[0].phalanx()
	assert_not_null(outer, "the two others stand together")
	if outer != null:
		assert_eq(men[2].phalanx(), outer)
		assert_almost_eq(men[0].global_position.distance_to(men[2].global_position), Phalanx.SPACING, 0.25, "ranks closed")


func assert_null_phalanx(man: Hoplite) -> void:
	assert_true(man.phalanx() == null, "the stunned man is out of the line")


func test_its_face_over_the_shield_rim_is_the_weak_point() -> void:
	var hoplite := _hoplite(Vector3.ZERO, false)
	await physics_frames(5)
	var space := get_viewport().find_world_3d().direct_space_state
	var face := hoplite.global_position + Vector3(0, 1.715, 0)
	var hit := Hitscan.ray(space, face + Vector3(0, 0, -4), face + Vector3(0, 0, 1))
	assert_false(hit.is_empty())
	if not hit.is_empty():
		assert_not_null(hit["hurtbox"])
		if hit["hurtbox"] != null:
			assert_true((hit["hurtbox"] as Hurtbox).weak_point, "the eye openings of the helmet")
	var low := hoplite.global_position + Vector3(0, 1.1, 0)
	var blocked := Hitscan.ray(space, low + Vector3(0, 0, -4), low + Vector3(0, 0, 1))
	assert_false(blocked.is_empty())
	if not blocked.is_empty() and blocked["hurtbox"] != null:
		assert_false((blocked["hurtbox"] as Hurtbox).weak_point, "the shield in front of the chest")


func test_hard_hits_knock_off_its_crest_and_greaves() -> void:
	var hoplite := _hoplite(Vector3.ZERO, false)
	await physics_frames(5)
	var rig := hoplite.rig as HopliteRig
	var head := DamageInfo.make(25.0, DamageInfo.Kind.BALLISTIC)
	head.direction = Vector3.FORWARD
	head.weak_point = true
	head.position = hoplite.global_position + Vector3(0, 1.72, 0)
	hoplite.take_damage(head)
	assert_false(rig.has_plate("plate_crest"), "the crest flew off")
	var shin := DamageInfo.make(25.0, DamageInfo.Kind.BALLISTIC)
	shin.direction = Vector3.LEFT
	shin.position = hoplite.global_position + Vector3(0.12, 0.35, 0)
	hoplite.take_damage(shin)
	assert_false(rig.has_plate("plate_greave_r"), "the right greave")
	assert_true(rig.has_plate("plate_greave_l"), "the left one stays")


func test_asleep_its_spear_stands_upright_and_the_telegraph_draws_it_back() -> void:
	target.position = Vector3(0, 0, 12)   # behind it: it sleeps
	var hoplite := _hoplite(Vector3.ZERO, false)
	await physics_frames(40)
	var rig := hoplite.rig as HopliteRig
	assert_gt(rig.spear_tip().y, 2.4, "the spear upright")
	target.position = Vector3(0, 0, -2.8)
	hoplite.summoned = true
	hoplite.brain.wake()
	var rest_tip := INF
	for i in 240:
		await get_tree().physics_frame
		if hoplite.brain.state == EnemyBrain.State.HUNT:
			rest_tip = rig.spear_tip().z
		if hoplite.brain.state == EnemyBrain.State.ATTACK and hoplite.brain.windup_progress() > 0.9:
			break
	assert_eq(hoplite.brain.state, EnemyBrain.State.ATTACK)
	assert_gt(rig.spear_tip().z, rest_tip + 0.2, "drawn back")
	assert_almost_eq(rig.spear_tip().y, 1.15, 0.2, "kept level")
	var glint := rig.find_child("TipGlint", true, false) as OmniLight3D
	assert_not_null(glint)
	if glint != null:
		assert_true(glint.visible and glint.light_energy > 1.0, "the bronze tip glints")


# --- the line goes to look together (ecology) --------------------------------------------

func test_a_line_of_hoplites_investigates_together() -> void:
	target.position = Vector3(0, 0, 50)   # out of sight
	var line: Array[Hoplite] = []
	for i in 3:
		var man := Hoplite.new()
		man.position = Vector3(-2 + 2 * i, 0, 0)
		man.target = target
		man.starts_awake = true
		man.brain.rng.seed = 30 + i
		add_child(man)
		man.face(Vector3(-2 + 2 * i, 0, -5))
		line.append(man)
	await physics_frames(3)
	for man in line:
		assert_eq(man.brain.state, EnemyBrain.State.PATROL, "standing at its post")
	PerceptionWorld.noise(Vector3(0, 0, -12), 18.0, &"pistol")
	await physics_frames(60)
	for man in line:
		assert_eq(man.brain.state, EnemyBrain.State.INVESTIGATE, "the whole line goes to look")
		assert_lt(man.brain.goal.distance_to(Vector3(0, 0, -12)), 0.5)
		assert_false(man.brain.is_hunting())


## Review 19.10: the line's followers took their own neighbours along in
## turn, so a long row of hoplites all went to look at one noise. A line is
## the one that heard it and the LINE_MAX nearest comrades - no more.
func test_a_long_row_of_hoplites_sends_one_line_of_three() -> void:
	target.position = Vector3(0, 0, 50)   # out of sight
	var row: Array[Hoplite] = []
	for i in 6:
		var man := Hoplite.new()
		man.position = Vector3(3.0 * i, 0, 0)
		man.target = target
		man.starts_awake = true
		man.brain.rng.seed = 40 + i
		add_child(man)
		man.face(Vector3(3.0 * i, 0, -5))
		row.append(man)
	await physics_frames(3)
	PerceptionWorld.noise(Vector3(-2, 0, 0), 4.0, &"pistol")   # only the first man hears it
	assert_ne(row[0].brain.state, EnemyBrain.State.PATROL, "(it heard it)")
	assert_eq(row[1].brain.state, EnemyBrain.State.SUSPICIOUS, "(a comrade of its line)")
	for second in 4:
		await physics_frames(60)
		var going := row.filter(func(m: Hoplite) -> bool: return m.brain.state != EnemyBrain.State.PATROL).size()
		assert_eq(going, 1 + Hoplite.LINE_MAX, "second %d: the one who heard it and its line of %d, not the whole row" % [second + 1, Hoplite.LINE_MAX])
	assert_eq(row[5].brain.state, EnemyBrain.State.PATROL, "the far end of the row never moved")
