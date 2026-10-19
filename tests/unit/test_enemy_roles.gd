extends TestCase
## EnemyRoles: every exhibit kind has a combat role and a reaction profile
## (backlog #25), looked up by kind or by the exhibit's class.


func test_every_kind_the_spawner_builds_has_a_profile() -> void:
	for kind in NightSpawner.BUILDS:
		assert_true(EnemyRoles.ROLES.has(kind), "no role for %s" % kind)
	assert_true(EnemyRoles.ROLES.has(&"portrait"))


func test_profiles_are_complete() -> void:
	for kind: StringName in EnemyRoles.ROLES:
		var profile: Dictionary = EnemyRoles.ROLES[kind]
		for key in ["role", "curiosity", "skittish", "door", "gathers", "sleep", "roam"]:
			assert_true(profile.has(key), "%s lacks %s" % [kind, key])


func test_kind_of_follows_the_class_and_its_subclasses() -> void:
	var expected := {WaxFigure: &"wax", Knight: &"knight", SamuraiArmor: &"samurai_armor", ReliefLion: &"relief_lion",
			Raptor: &"raptor", Totem: &"totem"}
	for kind: GDScript in expected:
		var exhibit: Enemy = kind.new()
		assert_eq(EnemyRoles.kind_of(exhibit), expected[kind], "%s (a samurai is not a knight, a relief lion not a wolf)" % kind.get_global_name())
		exhibit.free()
	assert_eq(EnemyRoles.kind_of(null), &"")


func test_roles_are_distinct_not_only_health() -> void:
	assert_eq(EnemyRoles.role(&"knight"), EnemyRoles.Role.TANK)
	assert_eq(EnemyRoles.role(&"raptor"), EnemyRoles.Role.FLANKER)
	assert_eq(EnemyRoles.role(&"bust"), EnemyRoles.Role.SUPPORT)
	assert_eq(EnemyRoles.role(&"scarabs"), EnemyRoles.Role.SWARM)
	assert_eq(EnemyRoles.role(&"totem"), EnemyRoles.Role.TURRET)
	assert_eq(EnemyRoles.role(&"wax"), EnemyRoles.Role.MELEE_PRESSURE)
	assert_eq(EnemyRoles.role(&"portrait"), EnemyRoles.Role.RANGED)


func test_an_unknown_kind_gets_the_plain_profile() -> void:
	var profile := EnemyRoles.profile(&"what")
	assert_eq(profile["role"], EnemyRoles.Role.MELEE_PRESSURE)
	assert_eq(profile["curiosity"], EnemyRoles.DEFAULT["curiosity"])


func test_totems_and_portraits_never_go_to_look() -> void:
	assert_eq(EnemyRoles.curiosity(&"totem"), 0.0)
	assert_eq(EnemyRoles.curiosity(&"portrait"), 0.0)
	assert_gt(EnemyRoles.curiosity(&"wolf"), 0.8, "a wolf is the most curious")


func test_door_guards_are_the_tanks() -> void:
	for kind: StringName in [&"knight", &"samurai_armor", &"hoplite", &"fu_dog"]:
		assert_gt(EnemyRoles.door_guard(kind), 0.0, "%s guards doors" % kind)
		assert_eq(EnemyRoles.role(kind), EnemyRoles.Role.TANK)
	assert_eq(EnemyRoles.door_guard(&"wax"), 0.0)
	assert_eq(EnemyRoles.door_guard(&"wolf"), 0.0)


## Review 19.10: a door in earshot of any sleeper called a knight every time;
## the guards answer it now about every other time at most.
func test_door_guards_answer_a_door_gently() -> void:
	assert_eq(EnemyRoles.door_guard(&"knight"), 0.6)
	assert_eq(EnemyRoles.door_guard(&"samurai_armor"), 0.6)
	assert_eq(EnemyRoles.door_guard(&"fu_dog"), 0.5)
	assert_eq(EnemyRoles.door_guard(&"hoplite"), 0.4)


func test_a_profile_carries_nothing_that_drives_nothing() -> void:
	# the "idle" routine of a kind was written down and read by no one
	assert_false(EnemyRoles.DEFAULT.has("idle"))
	for kind: StringName in EnemyRoles.ROLES:
		assert_false((EnemyRoles.ROLES[kind] as Dictionary).has("idle"), kind)
