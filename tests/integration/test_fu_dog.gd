extends TestCase
## The bronze Fu dog (design pietro-1-projekt 5.5) in a sandbox: 160 HP of
## bronze, a charge telegraphed by two scrapes that hits a guard who stands
## still, a wall that stuns it, the roar that staggers a guard in front
## after the pearl lights up, a shot on the lit pearl choking the roar, the
## paw up close, a pair that never charges together (the lioness a mirror
## image), the ball left on its plinth when the lion walks.

var target: TargetDummy


func before_each() -> void:
	GameInput.capture_allowed = false
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color.GRAY)
	target = TargetDummy.new()
	target.position = Vector3(0, 0, -8)
	add_child(target)


func after_each() -> void:
	GameInput.capture_allowed = true


func _dog(at: Vector3 = Vector3.ZERO, awake: bool = true) -> FuDog:
	var dog := FuDog.new()
	dog.position = at
	dog.target = target
	add_child(dog)
	dog.face(target.global_position)
	if awake:
		dog.brain.wake()
	return dog


func test_is_a_bronze_lion_of_160_hp() -> void:
	var dog := _dog(Vector3.ZERO, false)
	assert_eq(FuDog.KIND, &"fu_dog")
	assert_eq(dog.health.max_health, 160.0)
	assert_eq(dog.dust_value, 8)
	assert_eq(dog.material_kind, ExhibitMaterial.Kind.METAL)
	assert_true(dog.rig is FuDogRig, "the Blender model is on")
	assert_true(dog.paw_on_ball(), "asleep with its paw on the ball")
	var made := NightSpawner.make(&"fu_dog")
	assert_true(made is FuDog)
	made.free()
	var kinds: Array[StringName] = [&"wolf", &"fu_dog"]
	assert_eq(NightSpawner.preferred(kinds, &"wolf"), &"fu_dog", "Asia's slots now get Fu dogs")


func test_the_charge_scrapes_twice_then_hits_a_guard_who_stands_still() -> void:
	var dog := _dog()
	var strikes := watch(dog.brain.strike)
	var attack_frame := -1
	var strike_frame := -1
	var scrapes_before_run := 0
	for frame in 360:
		await get_tree().physics_frame
		if attack_frame < 0 and dog.brain.state == EnemyBrain.State.ATTACK:
			attack_frame = frame
		if strike_frame < 0 and not strikes.is_empty():
			strike_frame = frame
			scrapes_before_run = dog.scrapes()
		if not target.hits.is_empty():
			break
	assert_eq(dog.move, FuDogMoves.Move.CHARGE, "from 8 m: the charge")
	assert_gt(attack_frame, -1, "it wound up")
	assert_gt(strike_frame, -1, "it set off")
	if attack_frame >= 0 and strike_frame >= 0:
		assert_gt(strike_frame - attack_frame, 45, "a telegraph of at least 0.75 s (%d frames)" % (strike_frame - attack_frame))
	assert_eq(scrapes_before_run, 2, "two scrapes of the paw before the run")
	assert_eq(target.hits.size(), 1, "one hit")
	if not target.hits.is_empty():
		assert_eq(target.hits[0].amount, FuDogMoves.CHARGE_DAMAGE)
		assert_eq(target.hits[0].knockback, FuDogMoves.CHARGE_KNOCKBACK)
	assert_false(dog.charging(), "the run is over at the hit")


func test_a_charge_into_a_wall_stuns_it() -> void:
	var dog := _dog()
	for frame in 300:
		await get_tree().physics_frame
		if dog.charging():
			break
	assert_true(dog.charging(), "it runs")
	# the guard steps well aside; a wall rises across the committed line
	target.position = Vector3(9, 0, -2)
	Greybox.box(self, Vector3(0, 1.5, -5.5), Vector3(8, 3, 0.4), Color.GRAY)
	for frame in 150:
		await get_tree().physics_frame
		if dog.brain.is_stunned():
			break
	assert_true(dog.brain.is_stunned(), "stunned against the wall")
	assert_false(dog.charging())
	assert_eq(target.hits.size(), 0)
	assert_lt(dog.global_position.z, -3.0, "it got as far as the wall")


func test_the_roar_lights_the_pearl_then_staggers_a_guard_in_front() -> void:
	target.position = Vector3(0, 0, -3.5)   # too close for a charge, in the roar's cone
	var dog := _dog()
	var glow_frame := -1
	var stagger_frame := -1
	for frame in 300:
		await get_tree().physics_frame
		if glow_frame < 0 and dog.pearl_glow() > 0.3:
			glow_frame = frame
		if not target.staggers.is_empty():
			stagger_frame = frame
			break
	assert_eq(dog.move, FuDogMoves.Move.ROAR, "the roar")
	assert_gt(glow_frame, -1, "the pearl lit up")
	assert_gt(stagger_frame, -1, "the roar reached him")
	if glow_frame >= 0 and stagger_frame >= 0:
		assert_gt(stagger_frame - glow_frame, 35, "the pearl glows at least 0.6 s before the roar (%d frames)" % (stagger_frame - glow_frame))
	if not target.staggers.is_empty():
		assert_almost_eq(target.staggers[0], FuDogMoves.ROAR_STAGGER, 0.001)
	assert_eq(target.hits.size(), 0, "the roar does no damage")
	# the roar needs ROAR_COOLDOWN: within the next two seconds no second one
	await physics_frames(120)
	assert_eq(target.staggers.size(), 1, "one roar")


func test_the_roar_misses_a_guard_behind_a_wall() -> void:
	target.position = Vector3(0, 0, -3.5)
	var dog := _dog()
	for frame in 200:
		await get_tree().physics_frame
		if dog.brain.state == EnemyBrain.State.ATTACK and dog.move == FuDogMoves.Move.ROAR:
			break
	assert_eq(dog.move, FuDogMoves.Move.ROAR)
	Greybox.box(self, Vector3(0, 1.5, -2.5), Vector3(6, 3, 0.3), Color.GRAY)   # he ducks behind a case
	await physics_frames(90)
	assert_eq(target.staggers.size(), 0, "no roar through a wall")


func test_a_shot_on_the_lit_pearl_chokes_the_roar() -> void:
	target.position = Vector3(0, 0, -3.5)
	var dog := _dog()
	for frame in 200:
		await get_tree().physics_frame
		if dog.brain.state == EnemyBrain.State.ATTACK and dog.move == FuDogMoves.Move.ROAR and dog.pearl_glow() > 0.3:
			break
	assert_eq(dog.move, FuDogMoves.Move.ROAR)
	assert_gt(dog.pearl_glow(), 0.3, "the pearl is lit")
	var shot := DamageInfo.make(20.0, DamageInfo.Kind.BALLISTIC, target)
	shot.weak_point = true
	shot.direction = Vector3(0, 0, 1)
	shot.position = dog.mouth()
	dog.take_damage(shot)
	assert_true(dog.brain.is_stunned(), "choked")
	await physics_frames(90)
	assert_eq(target.staggers.size(), 0, "no roar came")
	assert_eq(dog.health.current, 140.0)


func test_the_paw_up_close() -> void:
	target.position = Vector3(0, 0, -2.0)
	var dog := _dog()
	var attack_frame := -1
	var hit_frame := -1
	for frame in 240:
		await get_tree().physics_frame
		if attack_frame < 0 and dog.brain.state == EnemyBrain.State.ATTACK:
			attack_frame = frame
		if not target.hits.is_empty():
			hit_frame = frame
			break
	assert_eq(dog.move, FuDogMoves.Move.PAW)
	assert_eq(target.hits.size(), 1)
	if not target.hits.is_empty():
		assert_eq(target.hits[0].amount, FuDogMoves.PAW_DAMAGE)
	if attack_frame >= 0 and hit_frame >= 0:
		assert_gt(hit_frame - attack_frame, 34, "a telegraph of 0.6 s")


func test_a_pair_never_charges_together_and_the_lioness_is_a_mirror_image() -> void:
	var lion := _dog(Vector3(-3, 0, 0), false)
	var lioness := _dog(Vector3(3, 0, 0), false)
	lion.brain.wake()
	lioness.brain.wake()
	var both := 0
	var charges := 0
	var was := false
	for frame in 420:
		await get_tree().physics_frame
		var running := int(lion.charging()) + int(lioness.charging())
		if running == 2:
			both += 1
		if running > 0 and not was:
			charges += 1
		was = running > 0
	assert_not_null(lion.pair, "they paired up")
	assert_eq(lioness.pair, lion.pair)
	assert_true(lioness.lioness, "the second is the lioness")
	assert_false(lion.lioness)
	if lioness.rig != null:
		assert_true((lioness.rig as FuDogRig).mirrored(), "the lioness is the model's mirror image")
		assert_lt((lioness.rig as FuDogRig).model.scale.x, 0.0)
	assert_almost_eq(lioness.roar_bias, FuDogMoves.LIONESS_ROAR_BIAS, 0.001)
	assert_eq(both, 0, "never both charging")
	assert_gt(charges, 0, "a charge came")


func test_the_ball_stays_on_its_plinth_when_the_lion_walks() -> void:
	target.position = Vector3(0, 0, -30)
	var dog := _dog(Vector3.ZERO, false)
	await physics_frames(3)
	var rig := dog.rig as FuDogRig
	if rig == null:
		return
	var ball := rig.part("ball")
	assert_not_null(ball, "the model carries the ball")
	var at := ball.global_position
	assert_true(dog.paw_on_ball())
	dog.hear(Vector3(0, 0, -8))
	await physics_frames(150)
	assert_false(dog.paw_on_ball())
	assert_gt(dog.global_position.distance_to(Vector3.ZERO), 1.0, "it went to look")
	assert_not_null(dog.ball(), "the ball left the paw")
	if dog.ball() != null:
		assert_eq(dog.ball().get_parent(), self, "on the plinth (the level), not on the lion")
		assert_lt(dog.ball().global_position.distance_to(at), 0.02, "where it was")


func test_a_charge_that_misses_skids_and_the_run_ends_early() -> void:
	var dog := _dog()
	for frame in 300:
		await get_tree().physics_frame
		if dog.charging():
			break
	assert_true(dog.charging())
	target.position = Vector3(8, 0, -8)   # steps out of its line
	var changes := watch(dog.brain.state_changed)
	for frame in 240:
		await get_tree().physics_frame
		if not dog.charging() and dog.skidding() <= 0.0 and dog.brain.state != EnemyBrain.State.ATTACK:
			break
	assert_eq(target.hits.size(), 0)
	var recovered := changes.any(func(c: Array) -> bool: return c[0] == EnemyBrain.State.ATTACK and c[1] == EnemyBrain.State.HUNT)
	assert_true(recovered, "the run ended and it came round within the time")


## The night's tuning (difficulty, full moon, witching hour) scales attack_damage,
## and the charge with it: it is the paw's 14 grown to 22.
func test_the_charge_scales_with_the_night_tuning() -> void:
	var dog := FuDog.new()
	dog.target = target
	DifficultyRules.tune(dog, &"double")
	add_child(dog)
	dog.face(target.global_position)
	dog.brain.wake()
	var scale := DifficultyRules.DAMAGE[DifficultyRules.index(&"double")]
	assert_almost_eq(dog.charge_damage(), FuDogMoves.CHARGE_DAMAGE * scale, 0.001)
	for frame in 360:
		await get_tree().physics_frame
		if not target.hits.is_empty():
			break
	assert_eq(target.hits.size(), 1, "the charge landed")
	if not target.hits.is_empty():
		assert_almost_eq(target.hits[0].amount, FuDogMoves.CHARGE_DAMAGE * scale, 0.001, "22 on the night shift, more on the double one")


func test_an_untuned_charge_is_twenty_two() -> void:
	var dog := _dog(Vector3.ZERO, false)
	assert_almost_eq(dog.charge_damage(), FuDogMoves.CHARGE_DAMAGE, 0.001)


## The witching hour (NightWatch.boost on a live exhibit) hurries the charge as
## it hurries the walk, and the charge hits harder with it.
func test_the_witching_hour_hurries_the_charge() -> void:
	var dog := _dog()
	NightWatch.boost(dog)
	var fastest := 0.0
	for frame in 360:
		await get_tree().physics_frame
		if dog.charging():
			fastest = maxf(fastest, Vector2(dog.velocity.x, dog.velocity.z).length())
		if not target.hits.is_empty():
			break
	assert_almost_eq(fastest, FuDogMoves.CHARGE_SPEED * NightWatch.WITCHING_BOOST, 0.1, "the run is 20% faster")
	assert_almost_eq(dog.move_speed, FuDog.WALK * NightWatch.WITCHING_BOOST, 0.001, "and its walk stays boosted")
	assert_eq(target.hits.size(), 1)
	if not target.hits.is_empty():
		assert_almost_eq(target.hits[0].amount, FuDogMoves.CHARGE_DAMAGE * NightWatch.WITCHING_BOOST, 0.001, "and hits 20% harder")


## The charge wants a clear line at knee height: a case the dog could see over
## is a case it would run into.
func test_a_dog_does_not_charge_over_a_low_case() -> void:
	Greybox.box(self, Vector3(0, 0.4, -4), Vector3(14, 0.8, 0.6), Color.GRAY)   # 0.8 m high
	var dog := _dog()
	var charged := false
	for frame in 300:
		await get_tree().physics_frame
		if dog.brain.state == EnemyBrain.State.ATTACK and dog.move == FuDogMoves.Move.CHARGE:
			charged = true
			break
	assert_false(charged, "no charge into the case")
	assert_eq(target.hits.size(), 0)


## The lioness is a mirror image from the day she is set on her plinth, not from
## the day the lion wakes (that flipped her where she stood).
func test_the_sleeping_lioness_is_a_mirror_image_before_anything_wakes() -> void:
	target.position = Vector3(0, 0, -60)   # nothing to wake them
	var lion := _dog(Vector3(-3, 0, 0), false)
	var lioness := _dog(Vector3(3, 0, 0), false)
	await physics_frames(2)
	assert_eq(lioness.brain.state, EnemyBrain.State.DORMANT)
	assert_not_null(lion.pair, "paired when set down")
	assert_eq(lioness.pair, lion.pair)
	assert_true(lioness.lioness)
	assert_false(lion.lioness)
	var rig := lioness.rig as FuDogRig
	if rig == null:
		return
	assert_true(rig.mirrored(), "mirrored asleep")
	assert_lt(rig.model.scale.x, 0.0)
	assert_gt((lion.rig as FuDogRig).model.scale.x, 0.0)
	lion.brain.wake()
	await physics_frames(60)
	assert_lt(rig.model.scale.x, 0.0, "and she stays as she was when he wakes")


## A dying lioness' pieces fly as bodies with a proper turn; the mirror stays on
## the visible mesh (a body with a negative scale is no body).
func test_a_dying_lioness_throws_no_mirrored_body() -> void:
	var lion := _dog(Vector3(-3, 0, 0), false)
	var lioness := _dog(Vector3(3, 0, 0), false)
	await physics_frames(2)
	assert_true(lioness.lioness)
	assert_not_null(lion.pair)
	Fx.clear()
	await physics_frames(1)
	var blow := DamageInfo.make(1000.0, DamageInfo.Kind.BALLISTIC, target)
	blow.direction = Vector3(0, 0, 1)
	blow.position = lioness.global_position + Vector3.UP * 1.2
	lioness.take_damage(blow)
	var bodies := 0
	var mirrored_views := 0
	for child in Fx.get_children():
		var body := child as RigidBody3D
		if body == null:
			continue
		bodies += 1
		assert_gt(body.transform.basis.determinant(), 0.0, "a body with a mirrored turn: %s" % str(body.transform.basis))
		for view in body.find_children("*", "MeshInstance3D", false, false):
			if (view as MeshInstance3D).transform.basis.determinant() < 0.0:
				mirrored_views += 1
	if lioness.rig != null:
		assert_gt(bodies, 3, "the model flew apart")
		assert_gt(mirrored_views, 0, "the mirror went to the mesh")
	Fx.clear()


## The ball a lion leaves on its plinth is a prop of the room: in the group dawn
## greys with the exhibits, and it outlives the dog.
func test_the_ball_left_on_the_plinth_is_a_prop_that_outlives_the_dog() -> void:
	var dog := _dog(Vector3.ZERO, false)
	await physics_frames(3)
	if dog.rig == null:
		return
	dog.hear(Vector3(0, 0, -8))
	await physics_frames(30)
	var ball := dog.ball()
	assert_not_null(ball, "the paw came off the ball")
	if ball == null:
		return
	assert_true(ball.is_in_group(Enemy.PROP_GROUP), "dawn will turn it to stone with the rest")
	var blow := DamageInfo.make(1000.0, DamageInfo.Kind.BALLISTIC, target)
	blow.direction = Vector3(0, 0, 1)
	blow.position = dog.global_position + Vector3.UP * 1.0
	dog.take_damage(blow)
	await physics_frames(3)
	assert_true(is_instance_valid(ball) and ball.is_inside_tree(), "the ball stays when the dog goes")
	Enemy.turn_to_stone(ball)
	var grey := 0
	for view in ball.find_children("*", "GeometryInstance3D", true, false):
		if (view as GeometryInstance3D).material_override != null:
			grey += 1
	if ball is GeometryInstance3D and (ball as GeometryInstance3D).material_override != null:
		grey += 1
	assert_gt(grey, 0, "stone")
