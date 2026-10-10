extends TestCase
## The Great Orrery in the real Planetarium rotunda of Floor I: it stands
## still on its post, wakes when the guard steps in, announces every attack
## at least 0.6 s ahead (a tier's drive changes only after its warning),
## takes damage only through its planets and, once they are all gone, its
## bared sun; a planet shot off rolls away as a hazard and two of them
## bring phase 2 (the tiers turn round; the sun's flares land on their
## marks); the guard's own capsule jumps the low arm and stands in the gap
## under the high one; its fall leaves the Star Key and the shard for
## good and the still orrery on later nights; fleeing calms it whole, and
## a shot from the observers' gallery glances off.

const A := OrreryBrain.Attack
const S := OrreryBrain.State
const G := preload("res://src/game/floor1/guardians/orrery_geometry.gd")

var museum: Museum


func before_each() -> void:
	Museum.level_id = &"floor1"


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _museum() -> Museum:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	return museum


func _orrery() -> Planetarium:
	return museum.floor_game.guardians.guardians.get(&"planetarium") as Planetarium


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


## The guard (tough enough for any test) with his feet at [param at].
func _put_guard(at: Vector3) -> void:
	var guard := museum.player
	if guard.health.max_health < 10000.0:
		guard.health.max_health = 100000.0
		guard.health.reset()
	guard.global_position = at + Vector3.UP * 0.05
	guard.velocity = Vector3.ZERO


## A floor point [param radius] m from the orrery's axis at world bearing
## [param angle] (rad from +X toward +Z).
func _around(orrery: Planetarium, radius: float, angle: float) -> Vector3:
	return orrery.home.origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


## Wakes it with the guard at the start line and waits out the waking.
func _awake(orrery: Planetarium) -> void:
	_put_guard(_around(orrery, 7.5, PI))
	await _seconds(0.3)
	assert_true(orrery.is_fighting(), "awake")
	await _seconds(OrreryBrain.WAKE_TIME + 0.1)


## A hit of [param amount] through its zone [param zone].
func _hit(orrery: Planetarium, zone: StringName, amount: float) -> DamageInfo:
	var info := DamageInfo.make(amount, DamageInfo.Kind.BALLISTIC, museum.player)
	info.weapon = &"pistol"
	info.position = orrery.global_position + Vector3.UP * 3.0
	info.direction = Vector3.FORWARD
	orrery.take_zone_damage(info, zone)
	return info


## Shoots planet [param planet] (0..5) off.
func _shoot_off(orrery: Planetarium, planet: int) -> void:
	_hit(orrery, StringName("planet_%d" % (planet + 1)), orrery.planet_health[planet] + 1.0)


## The guard's own capsule (radius, height).
func _capsule() -> Vector2:
	for node in museum.player.find_children("*", "CollisionShape3D", false, false):
		var capsule := (node as CollisionShape3D).shape as CapsuleShape3D
		if capsule != null:
			return Vector2(capsule.radius, capsule.height)
	return Vector2.ZERO


func test_it_stands_on_its_post_still_and_whole() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var orrery := _orrery()
	assert_not_null(orrery, "the real orrery, not the stand-in")
	if orrery == null:
		return
	assert_eq(GuardianKeeper.script_for(&"planetarium"), load("res://src/game/floor1/guardians/planetarium.gd"))
	var post: Transform3D = museum.floor_level.markers[&"guardian_planetarium"]
	assert_lt(orrery.global_position.distance_to(post.origin), 0.05, "on its post")
	assert_eq(orrery.state, Guardian.State.DORMANT)
	assert_eq(orrery.arena_room, &"enlightenment_planetarium")
	assert_false(orrery.rig.greybox, "the brass model")
	assert_eq(orrery.rig.moons.size(), 10)
	var total := orrery.core_health
	for k in 6:
		total += orrery.planet_health[k]
	assert_almost_eq(total, orrery.max_health, 0.5, "its planets and core make its health")
	assert_eq(get_tree().get_nodes_in_group(&"guardians").size(), Floor1Plan.GUARDIANS.size())
	assert_true(museum.floor_level.markers.has(&"arena_planetarium_reward"))
	var yaw := orrery.rig.tiers[G.LOW].rotation.y
	await _seconds(1.5)
	assert_lt(orrery.global_position.distance_to(post.origin), 0.05, "it does not slide off")
	assert_almost_eq(orrery.rig.tiers[G.LOW].rotation.y, yaw, 0.0001, "asleep, still")


func test_it_wakes_as_the_guard_steps_in_and_warns_of_every_attack() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var orrery := _orrery()
	var woke := watch(Events.guardian_awakened)
	_put_guard(Vector3(40.5, 0.0, -26.5))   # the library: not yet
	await _seconds(0.5)
	assert_eq(woke.size(), 0, "asleep while the guard is outside its rotunda")
	_put_guard(_around(orrery, 7.5, PI))
	await _seconds(0.3)
	assert_eq(woke.size(), 1, "awake past the start line")
	assert_true(museum.hud.boss_name_text().contains(tr("GUARDIAN_PLANETARIUM").to_upper()), museum.hud.boss_name_text())
	assert_eq(orrery.brain.state, S.WAKING)
	var clock := [0.0]
	var started := {}
	var gaps: Array = []
	var seen := {}
	var surge := [-1, 0.0, 0.0, -1.0]   # tier, warned at, its cruise, changed at
	orrery.telegraphed.connect(func(kind: StringName) -> void:
		started[kind] = clock[0]
		seen[kind] = true
		if kind == &"surge" and int(surge[0]) < 0:
			surge[0] = orrery.brain.surge_tier
			surge[1] = clock[0]
			surge[2] = orrery.drives[orrery.brain.surge_tier].target)
	orrery.struck.connect(func(kind: StringName) -> void:
		if started.has(kind):
			gaps.append([kind, clock[0] - float(started[kind])]))
	var spots: Array[Vector3] = [_around(orrery, 7.5, PI), _around(orrery, 4.0, 2.0), _around(orrery, 8.0, -1.2), _around(orrery, 6.0, 0.4)]
	for i in 60 * 45:
		clock[0] += 1.0 / 60.0
		if i % 300 == 0:
			_put_guard(spots[(i / 300) % spots.size()])
		museum.player.heal(1000.0)
		if int(surge[0]) >= 0 and float(surge[3]) < 0.0 and not is_equal_approx(orrery.drives[int(surge[0])].target, float(surge[2])):
			surge[3] = clock[0]
		await get_tree().physics_frame
	assert_gt(gaps.size(), 3, "it attacked (slowly: a teacher): %s" % str(gaps))
	for gap: Array in gaps:
		assert_true(float(gap[1]) >= Guardian.MIN_TELEGRAPH - 0.02, "%s announced %.2f s ahead" % [gap[0], gap[1]])
	for kind: StringName in [&"surge", &"launch"]:
		assert_true(seen.has(kind), "%s in phase 1: %s" % [kind, str(seen.keys())])
	assert_false(seen.has(&"flare"), "no flares while the sun is shut")
	assert_gt(float(surge[3]), 0.0, "a surge changed its tier's drive")
	assert_true(float(surge[3]) - float(surge[1]) >= Guardian.MIN_TELEGRAPH - 0.02, "the drive changed %.2f s after the warning" % (float(surge[3]) - float(surge[1])))


func test_only_its_planets_and_its_bared_sun_hurt_it() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var orrery := _orrery()
	await _awake(orrery)
	var full := orrery.health.current
	var brass := _hit(orrery, &"brass", 100.0)
	assert_almost_eq(orrery.health.current, full - 10.0, 0.01, "brass: a tenth")
	assert_true(brass.blocked, "a grey marker")
	var venus := _hit(orrery, &"planet_2", 40.0)
	assert_almost_eq(orrery.health.current, full - 50.0, 0.01, "a planet: all of it")
	assert_true(venus.weak_point, "a gold marker")
	assert_almost_eq(orrery.planet_health[1], orrery.max_health * Planetarium.PLANET_SHARE[1] - 40.0, 0.01, "off Venus's share")
	_hit(orrery, &"core", 100.0)
	assert_almost_eq(orrery.health.current, full - 60.0, 0.01, "the sun shut: brass")
	# brass never wears the core past its floor
	for i in 100:
		_hit(orrery, &"brass", 400.0)
	assert_almost_eq(orrery.core_health, orrery.core_max * Planetarium.CORE_FLOOR, 0.01)
	# the weapons' own path: a ray from the guard's eye finds a planet as a weak point
	_put_guard(_around(orrery, 8.0, PI))
	await physics_frames(2)
	var space := orrery.get_world_3d().direct_space_state
	var found := false
	for k in 6:
		var eye := museum.player.global_position + Vector3.UP * museum.player.eye_height
		var aim := orrery.rig.planets[k].global_position
		var hit := Hitscan.ray(space, eye, eye + (aim - eye) * 1.3)
		var hurtbox := hit.get("hurtbox") as Hurtbox if not hit.is_empty() else null
		if hurtbox != null and hurtbox.receiver is GuardianZone and (hurtbox.receiver as GuardianZone).zone == StringName("planet_%d" % (k + 1)):
			assert_true(hurtbox.weak_point, "planet %d is a weak point for the weapons" % (k + 1))
			found = true
	assert_true(found, "some planet in plain view")


func test_a_planet_shot_off_rolls_away_and_two_bring_phase_two() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var orrery := _orrery()
	await _awake(orrery)
	var shot := watch(orrery.planet_shot)
	_shoot_off(orrery, 0)
	assert_eq(shot.size(), 1)
	assert_true(orrery.rig.gone[0], "Mercury is off her rod")
	assert_false(orrery.rig.planets[0].visible)
	assert_false(orrery.brain.planets_on[0])
	assert_true(orrery.brain.planets_on[1], "the others stay")
	assert_eq(orrery.phase, 1, "one planet: still phase 1")
	var rolling := orrery.hazards.filter(func(n: Variant) -> bool: return is_instance_valid(n) and n is RollingPlanet)
	assert_eq(rolling.size(), 1, "she rolls")
	var start := (rolling[0] as Node3D).global_position
	await _seconds(1.0)
	if is_instance_valid(rolling[0]):
		var now := (rolling[0] as Node3D).global_position
		assert_gt(Vector2(now.x - start.x, now.z - start.z).length(), 0.8, "across the floor")
		assert_lt(now.y, 0.6, "on the floor")
	var cruise := orrery.brain.tier_target(G.LOW)
	_shoot_off(orrery, 5)
	assert_eq(orrery.phase, 2, "two planets: phase 2")
	assert_eq(orrery.hazards.filter(func(n: Variant) -> bool: return is_instance_valid(n) and n is RollingPlanet).size(), 2 + 1, "Saturn and her rings roll apart")
	var shifted := false
	for i in 60 * 12:
		museum.player.heal(1000.0)
		await get_tree().physics_frame
		if orrery.brain.state == S.SHIFT:
			shifted = true
		if shifted and orrery.brain.state != S.SHIFT:
			break
	assert_true(shifted, "it shifts its gears")
	assert_true(signf(orrery.brain.tier_target(G.LOW)) != signf(cruise), "the low tier turns the other way")


func test_the_guards_capsule_jumps_the_low_arm_and_stands_under_the_high_one() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var orrery := _orrery()
	await _awake(orrery)
	var capsule := _capsule()
	assert_almost_eq(capsule.x, 0.4, 0.001, "the guard's own capsule")
	var center := orrery.global_position
	# right on each tier's arm now (the nodes where they are: moons swinging)
	var high := orrery.rig.tiers[G.HIGH].global_basis * G.arm_direction(G.HIGH, 0)
	var low := orrery.rig.tiers[G.LOW].global_basis * G.arm_direction(G.LOW, 1)
	var mid := orrery.rig.tiers[G.MID].global_basis * G.arm_direction(G.MID, 0)
	high = Vector3(high.x, 0.0, high.z).normalized()
	low = Vector3(low.x, 0.0, low.z).normalized()
	mid = Vector3(mid.x, 0.0, mid.z).normalized()
	assert_false(orrery.tier_touches(G.HIGH, center + high * 4.15, capsule.x, capsule.y), "in the gap under the high arm")
	assert_true(orrery.tier_touches(G.HIGH, center + high * 3.3, capsule.x, capsule.y), "a hanging moon at 3.3 m")
	assert_true(orrery.tier_touches(G.HIGH, center + high * 5.0, capsule.x, capsule.y), "the last moon")
	assert_true(orrery.tier_touches(G.LOW, center + low * 3.5, capsule.x, capsule.y), "standing in the low arm's way")
	assert_false(orrery.tier_touches(G.LOW, center + low * 3.5 + Vector3.UP * 0.65, capsule.x, capsule.y), "jumping it")
	assert_true(orrery.tier_touches(G.MID, center + mid * 3.4, capsule.x, capsule.y), "the middle arm")
	assert_false(orrery.tier_touches(G.MID, center + mid * 4.2, capsule.x, capsule.y), "kept away from")
	# and in the fight: the high arm passes over a guard in its gap, hits one by a moon
	assert_eq(await _passes(orrery, G.HIGH, 4.15, 0.0), 0, "no harm in the gap")
	assert_gt(await _passes(orrery, G.HIGH, 3.3, 0.0), 0, "a moon hits who stands by it")
	assert_gt(await _passes(orrery, G.LOW, 3.5, 0.0), 0, "the low arm hits who stands")
	assert_eq(await _passes(orrery, G.LOW, 3.5, 0.66), 0, "and not who jumps")


## Surges [param tier] for a few seconds with the guard kept at
## [param radius] m (feet [param up] m over the floor); returns how often
## that tier's arm hit him.
func _passes(orrery: Planetarium, tier: int, radius: float, up: float) -> int:
	while orrery.brain.state != S.IDLE:
		museum.player.heal(1000000.0)
		await get_tree().physics_frame
	var hits := [0]
	var count := func(swept: int) -> void:
		if swept == tier:
			hits[0] += 1
	orrery.swept.connect(count)
	orrery.brain.force_attack(A.SURGE)
	orrery.brain.surge_tier = tier
	var spot := _around(orrery, radius, 2.4) + Vector3.UP * up
	while orrery.brain.attack == A.SURGE:
		_put_guard(spot)
		museum.player.heal(1000000.0)
		await get_tree().physics_frame
	orrery.swept.disconnect(count)
	return hits[0]


func test_in_phase_two_the_suns_flares_land_on_their_marks() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var orrery := _orrery()
	await _awake(orrery)
	_shoot_off(orrery, 0)
	_shoot_off(orrery, 1)
	for i in 60 * 10:
		museum.player.heal(1000.0)
		await get_tree().physics_frame
		if orrery.brain.state == S.IDLE and orrery.brain.level() == 1:
			break
	var spot := _around(orrery, 8.0, 0.5)
	_put_guard(spot)
	await physics_frames(2)
	museum.player.heal(1000000.0)
	var before := museum.player.health.current
	orrery.brain.force_attack(A.FLARE)
	var flare: SolarFlare = null
	for i in 60 * 3:
		_put_guard(spot)
		await get_tree().physics_frame
		for node: Variant in orrery.hazards:
			if is_instance_valid(node) and node is SolarFlare:
				flare = node
		if flare != null:
			break
	assert_not_null(flare, "the sun threw a flare")
	if flare == null:
		return
	await physics_frames(2)
	assert_true(is_instance_valid(flare.mark) and flare.mark.is_inside_tree(), "its mark on the floor")
	assert_lt(Vector2(flare.landing.x - spot.x, flare.landing.z - spot.z).length(), 0.8, "where the guard stands")
	for i in 60 * 3:
		_put_guard(spot)
		await get_tree().physics_frame
	assert_lt(museum.player.health.current, before - SolarFlare.DAMAGE * 0.9, "it burned who stayed")


func test_its_bared_sun_falls_and_leaves_the_star_key_for_good() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var keeper := museum.floor_game.guardians
	var orrery := _orrery()
	await _awake(orrery)
	_put_guard(_around(orrery, 8.0, PI))
	for k in 6:
		_shoot_off(orrery, k)
	assert_eq(orrery.brain.planets_left(), 0)
	var unveiled := false
	for i in 60 * 10:
		museum.player.heal(1000000.0)
		await get_tree().physics_frame
		if orrery.brain.state == S.UNVEIL:
			unveiled = true
			break
	assert_true(unveiled, "the sixth planet gone: the sun opens")
	assert_true(orrery.brain.exposed)
	var health := orrery.health.current
	var core := _hit(orrery, &"core", 50.0)
	assert_true(core.weak_point, "the core is a weak point now")
	assert_almost_eq(orrery.health.current, health - 50.0, 0.01)
	var fell := watch(Events.guardian_defeated)
	_hit(orrery, &"core", orrery.health.current + 1.0)
	await physics_frames(2)
	assert_eq(fell.size(), 1)
	assert_true(GameState.is_guardian_defeated(&"planetarium"))
	var falls := keeper.find_children("*", "OrreryFall", false, false)
	assert_eq(falls.size(), 1, "its fall plays out")
	await _seconds(OrreryFall.DONE + 0.3)
	if falls.size() == 1:
		assert_gt((falls[0] as OrreryFall).pieces.size(), 10, "petals and moons fell as brass")
	var spot: Vector3 = (museum.floor_level.markers[&"arena_planetarium_reward"] as Transform3D).origin
	var rewards := keeper.get_children().filter(func(n: Node) -> bool: return n is ProgressPickup)
	assert_eq(rewards.size(), 2, "the Star Key and the shard")
	for pickup: ProgressPickup in rewards:
		assert_lt(Vector2(pickup.global_position.x - spot.x, pickup.global_position.z - spot.z).length(), 1.5)
		pickup.interact(museum.player)
	assert_true(GameState.seals.has(&"star_key"))
	assert_true(GameState.shards.has(&"shard_enlightenment"))
	museum.free()
	RunState.reset()
	GameState.night += 1
	_museum()
	await physics_frames(2)
	assert_false(museum.floor_game.guardians.guardians.has(&"planetarium"), "it stays fallen")
	var still := museum.floor_game.guardians.find_children("SilentOrrery", "", true, false)
	assert_eq(still.size(), 1, "the still orrery in its rotunda")


func test_fleeing_calms_it_whole_and_a_shot_from_the_gallery_glances_off() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var orrery := _orrery()
	# from the observers' gallery: outside its arena, nothing counts
	var lookout := Vector3(49.0, Enlightenment.LOOKOUT_Y, -16.5)
	_put_guard(lookout)
	await physics_frames(2)
	_hit(orrery, &"planet_5", 300.0)
	await _seconds(0.3)
	assert_eq(orrery.state, Guardian.State.DORMANT, "a shot from the gallery wakes nothing")
	assert_almost_eq(orrery.health.fraction(), 1.0, 0.0001)
	assert_true(orrery.brain.planets_on[4])
	# a real fight, then the guard runs
	await _awake(orrery)
	_shoot_off(orrery, 0)
	_shoot_off(orrery, 3)
	orrery.brain.force_attack(A.LAUNCH)
	await _seconds(2.5)
	var calmed := watch(orrery.calmed)
	_put_guard(Vector3(40.5, 0.0, -26.5))
	await _seconds(Guardian.LEASH_TIME + 0.5)
	assert_eq(calmed.size(), 1)
	assert_eq(orrery.state, Guardian.State.DORMANT)
	assert_almost_eq(orrery.health.fraction(), 1.0, 0.001)
	for k in 6:
		assert_true(orrery.brain.planets_on[k], "planet %d back" % (k + 1))
		assert_false(orrery.rig.gone[k] or orrery.rig.flying[k])
		assert_true(orrery.rig.planets[k].visible)
		assert_lt(orrery.rig.planets[k].global_position.distance_to(orrery.rig.socket_world(k)), 0.05, "on its socket")
	await physics_frames(2)
	assert_eq(orrery.hazards.size(), 0, "nothing loose in the hall")
	assert_eq(orrery.phase, 0)
	var yaw := orrery.rig.tiers[G.HIGH].rotation.y
	await _seconds(1.0)
	assert_almost_eq(orrery.rig.tiers[G.HIGH].rotation.y, yaw, 0.0001, "still again")


const Enlightenment := preload("res://src/level/floor1/zones/enlightenment.gd")
