extends TestCase
## The court café behind the counter (plan 2026-10-10-kawiarnia-zmeczenie,
## 2.3) on the built greybox floor: the barista's aisle is a pocket haven
## (calm, no heal, no save), the flap stops the guard until he lifts it and
## drops once he is clear, an awake exhibit stays out, the navmesh never
## leads in, the T-Rex fight shuts the pocket, stepping in is announced
## once a night. Coffee: the machine pours on the barista's side only and
## rations by time; the urn pours the large one; after the witching hour the
## machine goes haywire (the special, absurd labels, a new slate).

const NavProbe := preload("res://tests/support/nav_probe.gd")
const Court := preload("res://src/level/floor1/zones/court.gd")
## In the court, east of the flap, on the aisle's line; a point in the aisle.
const BEFORE_FLAP := Vector3(-22.0, 0.05, -28.84)
const IN_AISLE := Vector3(-27.0, 0.05, -28.84)
## In the court in front of the counter, on the machine's other side.
const COURT_SIDE := Vector3(-27.0, 0.05, -26.5)

var level: MuseumFloorLevel
var player: Player
var corner: CafeCorner
## Seconds of the night the café's clock shows (0 = a fresh night).
var night_seconds: float = 0.0


func before_each() -> void:
	level = MuseumFloorLevel.new()
	add_child(level)
	level.build()
	await physics_frames(4)
	player = Player.new()
	player.position = BEFORE_FLAP
	add_child(player)
	corner = CafeCorner.new()
	add_child(corner)
	corner.setup(level, func() -> Player: return player, null, func() -> float: return night_seconds)
	await physics_frames(2)


func after_each() -> void:
	if is_instance_valid(level):
		level.free()


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


## Walks the guard west (into the counter's end) for [param frames] frames.
func _walk_west(frames: int) -> void:
	player.head.rotation.y = PI * 0.5
	Input.action_press(&"move_forward")
	await physics_frames(frames)
	Input.action_release(&"move_forward")


## Walks the guard east (out of the aisle, to the flap) for [param frames] frames.
func _walk_east(frames: int) -> void:
	player.head.rotation.y = -PI * 0.5
	Input.action_press(&"move_forward")
	await physics_frames(frames)
	Input.action_release(&"move_forward")


func test_the_aisle_is_a_pocket_haven_and_the_court_is_not() -> void:
	assert_not_null(corner.haven)
	assert_eq(corner.haven.id, CafeCorner.HAVEN_ID)
	assert_true(Haven.shelters(IN_AISLE), "behind the counter")
	assert_true(Haven.shelters(Vector3(-24.6, 0.05, -28.84)), "the flap's own gap belongs to the pocket")
	assert_false(Haven.shelters(BEFORE_FLAP), "the court floor east of the flap")
	assert_false(Haven.shelters(Vector3(-27.0, 0.05, -26.5)), "in front of the counter")
	assert_false(Haven.shelters(Vector3(-27.0, 0.05, -29.7)), "the back bar")
	assert_false(level.haven_spots.has(CafeCorner.HAVEN_ID), "no terminal: nobody heals or saves here")
	assert_gt(corner.zone.size.z, 1.0, "room for the guard")


func test_the_flap_stops_the_guard_until_he_lifts_it_and_drops_behind_him() -> void:
	assert_not_null(corner.flap)
	assert_false(corner.flap.is_open())
	await _walk_west(90)
	assert_gt(player.global_position.x, -24.4, "stopped at the shut flap (x %.2f)" % player.global_position.x)
	assert_false(Haven.shelters(player.global_position))
	corner.flap.interact(player)
	await physics_frames(2)
	assert_true(corner.flap.is_open())
	assert_eq(corner.flap.body.collision_layer, 0, "the body lets him through")
	await _walk_west(90)
	assert_lt(player.global_position.x, -25.5, "behind the counter (x %.2f)" % player.global_position.x)
	assert_true(Haven.shelters(player.global_position), "and sheltered")
	assert_true(corner.flap.is_open(), "still open while he stands near it")
	await _walk_west(60)
	await _seconds(CafeCorner.CafeFlap.DROP_AFTER + 0.5)
	assert_false(corner.flap.is_open(), "dropped once he was clear")
	assert_eq(corner.flap.body.collision_layer, Layers.WORLD)
	assert_true(corner.flap.enabled, "and can be lifted again")


func test_the_closed_flap_holds_the_guard_in_until_he_lifts_it_from_inside() -> void:
	player.global_position = Vector3(-25.6, 0.05, -28.84)
	await physics_frames(2)
	assert_false(corner.flap.is_open())
	await _walk_east(90)
	assert_lt(player.global_position.x, -24.8, "held by the shut flap (x %.2f)" % player.global_position.x)
	assert_true(Haven.shelters(player.global_position), "still behind the counter")
	var eye := player.global_position + Vector3.UP * player.eye_height
	var aim := Vector3(-24.6, player.eye_height, -28.84)
	assert_eq(player.interactor.probe(player.get_world_3d().direct_space_state, eye, aim - eye, player), corner.flap, "he can aim at it from inside")
	corner.flap.interact(player)
	await physics_frames(2)
	assert_true(corner.flap.is_open())
	await _walk_east(90)
	assert_gt(player.global_position.x, -23.5, "out in the court (x %.2f)" % player.global_position.x)
	assert_false(Haven.shelters(player.global_position))


func test_an_awake_exhibit_stays_out_of_the_aisle() -> void:
	player.global_position = IN_AISLE
	var wax := WaxFigure.new()
	wax.position = Vector3(-20.0, 0.05, -28.84)
	add_child(wax)
	wax.target = player
	wax.face(IN_AISLE)
	wax.brain.wake()
	var entered := false
	for i in 240:
		await physics_frames(1)
		if corner.haven.contains(wax.global_position):
			entered = true
			break
	assert_false(entered, "the exhibit stayed out")
	assert_eq(player.health.current, 100.0, "no hits behind the counter")
	wax.free()


func test_an_awake_exhibit_stays_out_with_the_flap_open_too() -> void:
	# standing by the flap keeps it up for the whole test
	var by_flap := Vector3(-25.1, 0.05, -28.84)
	player.global_position = by_flap
	corner.flap.open()
	var wax := WaxFigure.new()
	wax.position = Vector3(-20.0, 0.05, -28.84)
	add_child(wax)
	wax.target = player
	wax.face(by_flap)
	wax.brain.wake()
	var entered := false
	for i in 240:
		await physics_frames(1)
		if corner.haven.contains(wax.global_position):
			entered = true
			break
	assert_true(corner.flap.is_open(), "the flap stood open all the while")
	assert_false(entered, "the exhibit stayed out of the open aisle")
	assert_eq(player.health.current, 100.0, "no hits behind the counter")
	wax.free()


func test_the_navmesh_never_leads_into_the_aisle() -> void:
	var map := level.walk_region.get_navigation_map()
	var court := NavigationServer3D.map_get_closest_point(map, BEFORE_FLAP)
	assert_lt(court.distance_to(BEFORE_FLAP), 0.3, "the court floor is walkable")
	var inside := NavigationServer3D.map_get_closest_point(map, IN_AISLE)
	if inside.distance_to(IN_AISLE) < 0.3:
		assert_false(NavProbe.connected(map, court, inside, LevelNavigation.WALK_LAYER), "a scrap of mesh in the aisle is an island")
	# (else: no mesh in the 1.14 m aisle at all - nothing to walk on)


func test_the_t_rex_fight_shuts_the_pocket() -> void:
	var boss := Node3D.new()
	add_child(boss)
	Events.boss_awakened.emit(boss)
	assert_false(Haven.shelters(IN_AISLE), "no shelter from the T-Rex")
	assert_false(corner.sheltering(player))
	Events.boss_defeated.emit(boss)
	assert_true(Haven.shelters(IN_AISLE), "open again after the fight")


func test_stepping_behind_the_counter_is_announced_once_a_night() -> void:
	var entered := watch(Events.cafe_entered)
	await _seconds(0.3)
	assert_eq(entered.size(), 0, "not yet")
	player.global_position = IN_AISLE
	await _seconds(0.3)
	assert_eq(entered.size(), 1)
	assert_true(RunState.is_used(CafeCorner.ENTERED), "kept through a resumed night")
	player.global_position = BEFORE_FLAP
	await _seconds(0.3)
	player.global_position = IN_AISLE
	await _seconds(0.3)
	assert_eq(entered.size(), 1, "once a night")


# --- coffee -----------------------------------------------------------------

func _tired(amount: float) -> void:
	player.fatigue.level = amount


## The spread of the lamp's energy over [param seconds] of frames.
func _lamp_range(seconds: float) -> float:
	var low := INF
	var high := -INF
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frames(1)
		var energy := corner.machine.lamp_energy()
		low = minf(low, energy)
		high = maxf(high, energy)
	return high - low


func test_the_machine_from_the_court_only_says_where_the_levers_are() -> void:
	assert_not_null(corner.machine)
	player.global_position = COURT_SIDE
	_tired(0.6)
	var hints := watch(Events.hint_requested)
	var drunk := watch(Events.coffee_drunk)
	corner.machine.interact(player)
	assert_eq(hints.size(), 1)
	assert_eq(hints[0][0], tr("HUD_COFFEE_OTHER_SIDE"))
	assert_eq(drunk.size(), 0, "no cup from the wrong side")
	assert_almost_eq(player.fatigue.level, 0.6, 0.001)
	assert_false(player.fatigue.caffeinated())
	assert_eq(corner.machine.cooldown_left, 0.0, "and the machine is not spent")


func test_the_machine_pours_an_espresso_behind_the_counter() -> void:
	player.global_position = IN_AISLE
	_tired(0.6)
	var drunk := watch(Events.coffee_drunk)
	corner.machine.interact(player)
	assert_almost_eq(player.fatigue.level, 0.30, 0.01, "the espresso takes 0.30 off")
	assert_true(player.fatigue.caffeinated())
	assert_eq(player.fatigue.buff, Coffee.ESPRESSO)
	assert_eq(drunk.size(), 1)
	assert_eq(drunk[0][0], Coffee.ESPRESSO)
	assert_eq(corner.poured, 1)
	assert_almost_eq(corner.machine.cooldown_left, Coffee.MACHINE_WARMUP, 0.01)


func test_the_machine_heats_between_cups() -> void:
	player.global_position = IN_AISLE
	_tired(0.9)
	var hints := watch(Events.hint_requested)
	var drunk := watch(Events.coffee_drunk)
	corner.machine.interact(player)
	var after_first := player.fatigue.level
	corner.machine.interact(player)
	assert_eq(drunk.size(), 1, "the second cup waits")
	assert_eq(hints.size(), 1)
	assert_eq(hints[0][0], tr("HUD_COFFEE_WARMING"))
	assert_almost_eq(player.fatigue.level, after_first, 0.01)
	corner.machine.advance(Coffee.MACHINE_WARMUP - 1.0)
	corner.machine.interact(player)
	assert_eq(drunk.size(), 1, "still warming a second before")
	corner.machine.advance(1.5)
	corner.machine.interact(player)
	assert_eq(drunk.size(), 2, "after 90 s it pours again")
	assert_lt(player.fatigue.level, after_first, "and takes more off")


func test_the_machines_heating_runs_with_the_game_by_itself() -> void:
	player.global_position = IN_AISLE
	corner.machine.interact(player)
	corner.machine.cooldown_left = 0.2
	await _seconds(0.5)
	assert_eq(corner.machine.cooldown_left, 0.0)


func test_the_lamp_shows_whether_the_machine_is_ready() -> void:
	var ready := corner.machine.lamp_energy()
	assert_gt(ready, 0.5, "a warm lamp")
	player.global_position = IN_AISLE
	corner.machine.interact(player)
	await _seconds(2.0)
	assert_lt(corner.machine.lamp_energy(), ready * 0.7, "dim while it heats")
	corner.machine.advance(Coffee.MACHINE_WARMUP + 1.0)
	await _seconds(2.0)
	assert_almost_eq(corner.machine.lamp_energy(), ready, 0.05, "and warm again")


func test_the_urn_pours_a_large_coffee_and_drips_for_a_while() -> void:
	assert_not_null(corner.urn)
	player.global_position = IN_AISLE
	_tired(0.6)
	var drunk := watch(Events.coffee_drunk)
	var hints := watch(Events.hint_requested)
	corner.urn.interact(player)
	assert_almost_eq(player.fatigue.level, 0.45, 0.01, "the large one takes 0.15 off")
	assert_eq(player.fatigue.buff, Coffee.LARGE)
	assert_almost_eq(player.fatigue.buff_left, 240.0, 0.5)
	assert_eq(drunk[0][0], Coffee.LARGE)
	corner.urn.interact(player)
	assert_eq(drunk.size(), 1, "it drips 150 s")
	assert_eq(hints[0][0], tr("HUD_COFFEE_DRIPPING"))
	corner.urn.advance(Coffee.URN_DRIP + 0.1)
	corner.urn.interact(player)
	assert_eq(drunk.size(), 2)


func test_a_shorter_cup_keeps_the_caffeine_of_the_longer_one() -> void:
	player.global_position = IN_AISLE
	_tired(0.9)
	corner.urn.interact(player)
	corner.machine.interact(player)
	assert_eq(player.fatigue.buff, Coffee.LARGE, "the large one's 240 s are not thrown away for 90")
	assert_almost_eq(player.fatigue.buff_left, 240.0, 0.5)
	assert_almost_eq(player.fatigue.level, 0.9 - 0.15 - 0.30, 0.01, "but the espresso still takes its 0.30 off")


func test_nobody_drinks_dead() -> void:
	player.global_position = IN_AISLE
	player.alive = false
	var drunk := watch(Events.coffee_drunk)
	corner.machine.interact(player)
	assert_eq(drunk.size(), 0)


func test_the_prompts_name_the_drink() -> void:
	assert_eq(corner.machine.prompt(), tr("PROMPT_COFFEE_ESPRESSO"))
	assert_eq(corner.urn.prompt(), tr("PROMPT_COFFEE_LARGE"))


func test_the_machine_urn_and_slate_stand_on_their_markers() -> void:
	for pair in [[corner.machine, &"cafe_machine"], [corner.urn, &"cafe_urn"], [corner.slate, &"cafe_slate"]]:
		var marker: Transform3D = level.markers[pair[1]]
		assert_lt((pair[0] as Node3D).global_position.distance_to(marker.origin), 0.01, str(pair[1]))
	assert_eq(corner.slate.lines(), PackedStringArray([tr("SLATE_NORMAL_1"), tr("SLATE_NORMAL_2"), tr("SLATE_NORMAL_3")]))


## What the guard's use-ray finds standing at [param from] (feet) and aiming
## at [param aim] (a point in the world).
func _probe(from: Vector3, aim: Vector3) -> Interactable:
	player.global_position = from
	var eye := from + Vector3.UP * player.eye_height
	var space := player.get_world_3d().direct_space_state
	return player.interactor.probe(space, eye, aim - eye, player)


func test_the_guard_can_aim_at_the_machine_and_the_urn_from_behind_the_counter() -> void:
	await physics_frames(2)
	var machine_at := (level.markers[&"cafe_machine"] as Transform3D).origin + Vector3(0.0, 0.5, 0.0)
	var urn_at := (level.markers[&"cafe_urn"] as Transform3D).origin + Vector3(0.0, 0.2, 0.0)
	for x in [-27.6, -27.0, -26.4, -25.8, -25.3]:
		var from := Vector3(x, 0.05, -28.84)
		assert_eq(_probe(from, machine_at), corner.machine, "the machine from x %.1f" % x)
		assert_eq(_probe(from, urn_at), corner.urn, "the urn from x %.1f" % x)


func test_from_the_court_the_machine_answers_and_the_urn_is_out_of_reach() -> void:
	await physics_frames(2)
	var machine_at := (level.markers[&"cafe_machine"] as Transform3D).origin + Vector3(0.0, 0.5, 0.0)
	var urn_at := (level.markers[&"cafe_urn"] as Transform3D).origin + Vector3(0.0, 0.2, 0.0)
	assert_eq(_probe(Vector3(-26.6, 0.05, -26.9), machine_at), corner.machine, "the levers are there to be refused")
	assert_eq(_probe(Vector3(-25.2, 0.05, -26.9), urn_at), null, "the urn is behind the counter and the bar")


## A flap wearing the dressed look of the cafe_flap piece (the greybox floor of
## these tests has only a block there; the slab and the panel are Floor1Art's).
func _dressed_flap() -> CafeCorner.CafeFlap:
	var spec: PieceSpec = null
	for piece in level.layout.pieces:
		if piece.kit == &"cafe_flap":
			spec = piece
	var body := StaticBody3D.new()
	body.set_meta(&"kit_size", spec.size)
	body.add_child(LevelArt.piece_look(spec, 0, level.layout))
	add_child(body)
	body.global_transform = Transform3D(Basis(Vector3.UP, spec.yaw), spec.position)
	return CafeCorner.CafeFlap.attach(body, func() -> Player: return player)


## The world-space boxes of every mesh of [param flap]'s looks (slab, hinge, panel...).
func _flap_boxes(flap: CafeCorner.CafeFlap) -> Array[AABB]:
	var boxes: Array[AABB] = []
	for node in flap.body.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		boxes.append(mesh.global_transform * mesh.get_aabb())
	return boxes


func _top_of(boxes: Array[AABB]) -> float:
	var top := 0.0
	for box in boxes:
		top = maxf(top, box.end.y)
	return top


func test_the_lifted_flap_leaves_the_eye_level_of_the_aisle_free() -> void:
	var flap := _dressed_flap()
	assert_not_null(flap._slab, "the dressed flap has its slab")
	assert_not_null(flap._panel, "and its panel")
	var closed_top := _top_of(_flap_boxes(flap))
	flap.open()
	await _seconds(CafeCorner.CafeFlap.LIFT_TIME + 0.3)
	var lifted := _flap_boxes(flap)
	assert_gt(_top_of(lifted), closed_top + 0.05, "it really is up (%.2f above %.2f)" % [_top_of(lifted), closed_top])
	# the camera's way: out of the court, through the flap, along the whole aisle,
	# a hand's breadth above and below the eye, over the aisle's whole width
	var band := 0.2
	var path := AABB(
		Vector3(corner.zone.position.x, player.eye_height - band, corner.zone.position.z),
		Vector3(corner.zone.size.x + 1.5, band * 2.0, corner.zone.size.z))
	for box in lifted:
		assert_false(box.intersects(path), "a piece of the flap at eye level: %s" % str(box))
	assert_lt(_top_of(lifted), player.eye_height - band, "the lifted slab stays below the eyes (%.2f)" % _top_of(lifted))


func test_a_level_gaze_at_the_flap_gets_the_prompt_from_the_court_and_from_the_aisle() -> void:
	await physics_frames(2)
	var at := Vector3(-24.6, player.eye_height, -28.84)
	assert_eq(_probe(Vector3(-22.6, 0.05, -28.84), at), corner.flap, "from the court, eye level")
	assert_eq(_probe(Vector3(-26.4, 0.05, -28.84), at), corner.flap, "from the aisle, eye level")
	assert_eq(_probe(Vector3(-22.6, 0.05, -28.84), Vector3(-24.6, 0.6, -28.84)), corner.flap, "and a look down at its panel")
	assert_eq(_probe(Vector3(-22.6, 0.05, -28.84), Vector3(-24.6, player.eye_height + 1.0, -28.84)), null, "but not at the ceiling")


func test_after_the_witching_hour_the_machine_goes_haywire() -> void:
	assert_false(corner.haywire)
	Events.witching_hour.emit()
	assert_true(corner.haywire)
	assert_true(corner.machine.is_haywire())
	assert_eq(corner.machine.prompt(), tr("PROMPT_COFFEE_HAYWIRE") % Coffee.absurd_label(0), "an absurd label")
	assert_eq(corner.urn.prompt(), tr("PROMPT_COFFEE_URN_HAYWIRE") % Coffee.absurd_label(2), "the urn has its own label")
	assert_eq(corner.slate.lines(), PackedStringArray([tr("SLATE_HAYWIRE_1"), tr("SLATE_HAYWIRE_2"), tr("SLATE_HAYWIRE_3")]), "the slate changes")


func test_the_haywire_machine_pours_the_special_and_the_hands_shake() -> void:
	Events.witching_hour.emit()
	player.global_position = IN_AISLE
	_tired(0.8)
	var drunk := watch(Events.coffee_drunk)
	var label := corner.machine.prompt()
	corner.machine.interact(player)
	assert_eq(drunk[0][0], Coffee.SPECIAL)
	assert_eq(player.fatigue.buff, Coffee.SPECIAL)
	assert_almost_eq(player.fatigue.level, 0.35, 0.01, "the special takes 0.45 off")
	assert_gt(player.fatigue.jitter(), 0.9, "shaking hands")
	assert_ne(corner.machine.prompt(), label, "and the next cup has another label")
	corner.urn.interact(player)
	assert_eq(drunk[1][0], Coffee.LARGE, "the urn pours the same large coffee (only its label is absurd)")


func test_the_haywire_lamp_flickers_and_the_calm_one_does_not() -> void:
	var calm := await _lamp_range(1.5)
	assert_lt(calm, 0.02, "a steady lamp")
	Events.witching_hour.emit()
	var wild := await _lamp_range(1.5)
	assert_gt(wild, 0.15, "a flicker you can see (%.2f)" % wild)


func test_the_haywire_is_announced_once_on_the_first_step_behind_the_counter() -> void:
	var haywire := watch(Events.cafe_haywire)
	Events.witching_hour.emit()
	await _seconds(0.3)
	assert_eq(haywire.size(), 0, "not from the court")
	player.global_position = IN_AISLE
	await _seconds(0.3)
	assert_eq(haywire.size(), 1)
	player.global_position = BEFORE_FLAP
	await _seconds(0.3)
	player.global_position = IN_AISLE
	await _seconds(0.3)
	assert_eq(haywire.size(), 1, "once a night")


func test_the_haywire_is_announced_at_once_to_a_guard_already_behind_the_counter() -> void:
	var haywire := watch(Events.cafe_haywire)
	player.global_position = IN_AISLE
	await _seconds(0.3)
	assert_eq(haywire.size(), 0, "not before 3:00")
	Events.witching_hour.emit()
	assert_eq(haywire.size(), 1, "3:00 strikes while he stands there: he sees it go wild")
	await _seconds(0.3)
	assert_eq(haywire.size(), 1, "once a night")
	assert_true(RunState.is_used(CafeCorner.HAYWIRE_SEEN))


func test_no_haywire_before_the_witching_hour() -> void:
	var haywire := watch(Events.cafe_haywire)
	player.global_position = IN_AISLE
	await _seconds(0.3)
	assert_eq(haywire.size(), 0)


func test_a_night_resumed_past_the_witching_hour_starts_haywire() -> void:
	corner.free()
	await physics_frames(1)
	night_seconds = NightClock.seconds_to_witching() + 30.0
	corner = CafeCorner.new()
	add_child(corner)
	corner.setup(level, func() -> Player: return player, null, func() -> float: return night_seconds)
	await physics_frames(2)
	assert_true(corner.haywire, "the machine is already wild")
	assert_eq(corner.slate.lines()[0], tr("SLATE_HAYWIRE_1"))
	assert_eq(Coffee.machine_kind(corner.haywire), Coffee.SPECIAL)


func test_a_cup_shows_a_line_on_the_hud() -> void:
	var hud := Hud.new()
	add_child(hud)
	corner.hud = hud
	player.global_position = IN_AISLE
	corner.machine.interact(player)
	assert_eq(hud._toast.text, tr("HUD_COFFEE_DRUNK_ESPRESSO").to_upper())
	hud.free()


func test_the_chalk_lines_fit_the_slate_in_both_languages() -> void:
	for locale in ["pl", "en"]:
		TranslationServer.set_locale(locale)
		for haywire in [false, true]:
			for key in Coffee.slate_keys(haywire):
				var width := CafeCorner.CafeSlate.text_width(TranslationServer.translate(key))
				assert_lt(width, CafeCorner.CafeSlate.SIZE.x - 0.06, "%s (%s): %.3f m" % [key, locale, width])
	TranslationServer.set_locale("pl")
