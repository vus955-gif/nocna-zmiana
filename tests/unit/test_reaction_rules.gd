extends TestCase
## ReactionRules: how an exhibit answers a noise it heard (backlog #24):
## graded by its kind's profile and by how close the noise was, with a cap
## on how many go to look at one event (the rest only turn their heads).

const R := ReactionRules.Reaction


func _wax() -> Dictionary:
	return EnemyRoles.profile(&"wax")


func test_a_curious_exhibit_close_to_a_shot_goes_to_look() -> void:
	assert_eq(ReactionRules.decide(&"pistol", _wax(), 1.0, 0.1), R.INVESTIGATE)


func test_far_from_the_shot_it_mostly_only_turns_its_head() -> void:
	assert_eq(ReactionRules.decide(&"pistol", _wax(), 0.05, 0.9), R.LOOK)
	assert_eq(ReactionRules.decide(&"pistol", _wax(), 0.05, 0.2), R.INVESTIGATE, "a low roll still brings it")


func test_a_totem_only_turns_its_faces() -> void:
	assert_eq(ReactionRules.decide(&"pistol", EnemyRoles.profile(&"totem"), 1.0, 0.0), R.LOOK)
	assert_eq(ReactionRules.decide(&"fall", EnemyRoles.profile(&"totem"), 1.0, 0.0), R.LOOK)


func test_skittish_kinds_flee_a_blast_close_by() -> void:
	assert_eq(ReactionRules.decide(&"blast", EnemyRoles.profile(&"scarabs"), 0.8, 0.2), R.FLEE)
	assert_ne(ReactionRules.decide(&"blast", _wax(), 0.8, 0.2), R.FLEE, "wax does not flee")
	assert_eq(ReactionRules.decide(&"blast", EnemyRoles.profile(&"scarabs"), 0.1, 0.95), R.LOOK, "far off, a high roll: it only looks")


func test_door_guards_answer_a_door_others_only_look() -> void:
	assert_eq(ReactionRules.decide(&"door", EnemyRoles.profile(&"knight"), 0.5, 0.3), R.INVESTIGATE)
	assert_eq(ReactionRules.decide(&"door", _wax(), 1.0, 0.0), R.LOOK)


func test_a_door_calls_a_guard_less_often_than_it_used_to() -> void:
	# the knight at 6 m of a 10 m creak (closeness 0.4): 0.6 x sqrt(0.4) = 0.38
	var knight := EnemyRoles.profile(&"knight")
	assert_eq(ReactionRules.decide(&"door", knight, 0.4, 0.35), R.INVESTIGATE)
	assert_eq(ReactionRules.decide(&"door", knight, 0.4, 0.45), R.LOOK, "a roll that would have sent it at 0.9")


func test_gathering_kinds_go_to_a_fallen_exhibit() -> void:
	assert_eq(ReactionRules.decide(&"fall", _wax(), 0.5, 0.6), R.INVESTIGATE, "p = 0.75")
	assert_eq(ReactionRules.decide(&"fall", EnemyRoles.profile(&"wolf"), 0.5, 0.6), R.LOOK, "a wolf does not gather")


func test_the_cap_lets_at_most_three_investigate_nearest_first() -> void:
	var decided: Array = [R.INVESTIGATE, R.INVESTIGATE, R.LOOK, R.INVESTIGATE, R.INVESTIGATE, R.INVESTIGATE]
	var curious: Array = [true, true, true, true, true, true]
	var out := ReactionRules.cap(decided, curious)
	assert_eq(out.count(R.INVESTIGATE), ReactionRules.INVESTIGATE_CAP)
	assert_eq(out[0], R.INVESTIGATE)
	assert_eq(out[1], R.INVESTIGATE)
	assert_eq(out[3], R.INVESTIGATE)
	assert_eq(out[4], R.LOOK, "over the cap: it only looks")
	assert_eq(out[5], R.LOOK)


func test_the_nearest_curious_one_always_goes() -> void:
	var out := ReactionRules.cap([R.LOOK, R.LOOK, R.LOOK], [false, true, true])
	assert_eq(out[0], R.LOOK, "the nearest is not curious (a totem): it stays")
	assert_eq(out[1], R.INVESTIGATE, "the nearest curious one goes whatever it rolled")
	assert_eq(out[2], R.LOOK)


func test_the_budget_counts_only_the_ones_it_gets_up() -> void:
	var decided: Array = [R.INVESTIGATE, R.INVESTIGATE, R.INVESTIGATE, R.INVESTIGATE]
	var curious: Array = [true, true, true, true]
	# the nearest two are already about (investigating): they follow for free
	var out := ReactionRules.cap(decided, curious, 1, [false, false, true, true])
	assert_eq(out, [R.INVESTIGATE, R.INVESTIGATE, R.INVESTIGATE, R.LOOK], "one place left: one more gets up")
	out = ReactionRules.cap([R.LOOK, R.LOOK], [true, true], 0, [true, true])
	assert_eq(out, [R.LOOK, R.LOOK], "no place left (a burst of fire): the nearest gets no free pass")
	out = ReactionRules.cap([R.LOOK, R.LOOK], [true, true], 0, [false, true])
	assert_eq(out[0], R.INVESTIGATE, "one already about still turns to the new noise")


func test_a_door_and_a_fall_force_nobody_to_come() -> void:
	# a door creaks, a neighbour falls: whoever is nearest keeps what it
	# rolled (a lone knight within 10 m of any door always walking over would
	# end the gentle first night)
	var out := ReactionRules.cap([R.LOOK, R.LOOK], [true, true], ReactionRules.INVESTIGATE_CAP, [], false)
	assert_eq(out, [R.LOOK, R.LOOK], "no free pass")
	out = ReactionRules.cap([R.LOOK, R.INVESTIGATE, R.INVESTIGATE], [true, true, true], 1, [], false)
	assert_eq(out, [R.LOOK, R.INVESTIGATE, R.LOOK], "what they rolled stands, the budget still holds")


func test_only_a_plain_noise_sends_a_visitor_whatever_the_dice() -> void:
	for source: StringName in [&"pistol", &"gatling", &"glass", &"sprint", ReactionRules.SOURCE_BLAST]:
		assert_true(ReactionRules.sends_a_visitor(source), "%s: the nearest curious one comes" % source)
	assert_false(ReactionRules.sends_a_visitor(ReactionRules.SOURCE_DOOR))
	assert_false(ReactionRules.sends_a_visitor(ReactionRules.SOURCE_FALL))


func test_soft_noises_are_the_ones_a_sound_sleeper_sleeps_through() -> void:
	for source: StringName in [ReactionRules.SOURCE_DOOR, ReactionRules.SOURCE_FALL, &"sprint", &"landing"]:
		assert_true(ReactionRules.is_soft(source), "%s is soft" % source)
	for source: StringName in [&"pistol", &"shotgun", &"gatling", &"glass", ReactionRules.SOURCE_BLAST, &"flare"]:
		assert_false(ReactionRules.is_soft(source), "%s wakes anyone" % source)


func test_fleeing_is_never_turned_into_investigating() -> void:
	var out := ReactionRules.cap([R.FLEE, R.LOOK], [true, true])
	assert_eq(out[0], R.FLEE)
	assert_eq(out[1], R.INVESTIGATE, "the guarantee passes to the next curious one")


func test_closeness_runs_from_the_edge_to_the_point() -> void:
	assert_almost_eq(ReactionRules.closeness(0.0, 10.0, 1.0), 1.0)
	assert_almost_eq(ReactionRules.closeness(10.0, 10.0, 1.0), 0.0)
	assert_almost_eq(ReactionRules.closeness(3.0, 10.0, 0.6), 0.5, 0.001, "through a door the noise reaches 6 m")
	assert_almost_eq(ReactionRules.closeness(20.0, 10.0, 1.0), 0.0, 0.001, "never below zero")
