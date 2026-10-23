extends TestCase
## A room's lamps as an uncanny event plays them (plan
## 2026-10-21-eskalacja-nocy): only the lamps' energy and the glow of
## their fittings change, never whether a lamp is on (the exhibits' light
## model reads that); every mode ends with each lamp exactly as bright as
## it was; lamps already dark (a blackout) and the basement's flickering
## tubes are left alone.

var root: Node3D
var lamps: RoomLamps


func before_each() -> void:
	root = Node3D.new()
	add_child(root)


func after_each() -> void:
	if is_instance_valid(root):
		root.free()
	Settings.reset_to_defaults(false)


func _lamp(room: StringName, at: Vector3, energy: float, group: StringName = LightSpec.MAIN) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.light_energy = energy
	lamp.position = at
	lamp.set_meta(&"room", room)
	lamp.add_to_group(group)
	root.add_child(lamp)
	return lamp


func _fixture(room: StringName, at: Vector3, group: StringName = LightSpec.MAIN) -> Node3D:
	var fixture := Node3D.new()
	fixture.position = at
	fixture.set_meta(&"room", room)
	fixture.add_to_group(StringName("%s_fixtures" % group))
	root.add_child(fixture)
	return fixture


func _install() -> RoomLamps:
	lamps = RoomLamps.new()
	root.add_child(lamps)
	lamps.setup(root)
	return lamps


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second) + 2)


func _hall() -> Array[OmniLight3D]:
	var made: Array[OmniLight3D] = []
	for i in 6:
		made.append(_lamp(&"hall", Vector3(i * 4.0, 3.0, 0.0), 1.0 + i * 0.25))
	return made


func test_every_mode_ends_with_each_lamp_as_bright_as_it_was() -> void:
	var hall := _hall()
	_install()
	for mode in RoomLamps.MODES:
		if mode == &"exit":
			continue
		assert_true(lamps.play(&"hall", mode, 2.0, Vector3.ZERO), "%s plays" % mode)
		assert_true(lamps.busy(&"hall"))
		await _seconds(lamps.length_of(&"hall") + 0.2)
		assert_false(lamps.busy(&"hall"), "%s is over" % mode)
		for i in hall.size():
			assert_almost_eq(hall[i].light_energy, 1.0 + i * 0.25, 0.0001, "%s: lamp %d back" % [mode, i])
			assert_true(hall[i].visible, "%s never switches a lamp off" % mode)


func test_a_flicker_dips_the_lamps_while_it_lasts() -> void:
	var hall := _hall()
	_install()
	lamps.play(&"hall", &"flicker", 2.0)
	var dipped := 0
	for frame in 100:
		await get_tree().process_frame
		for lamp in hall:
			if lamp.light_energy < lamps.base_energy(lamp) - 0.01:
				dipped += 1
	assert_gt(dipped, 10, "the lamps stutter")


func test_a_flicker_never_flashes_faster_than_four_times_a_second() -> void:
	# photosensitivity: a lamp's dip and its rest between two dips never add up to less than a quarter of a second
	assert_true(RoomLamps.STEADY.x >= 0.15, "a real rest between two dips")
	assert_true(1.0 / (RoomLamps.DIP_TIME.x + RoomLamps.STEADY.x) <= 4.0 + 0.001, "the fastest flicker the constants allow")
	_hall()
	_install()
	var fastest := INF
	var dips := 0
	for round in 8:
		assert_true(lamps.play(&"hall", &"flicker", 20.0))
		var effect: RoomLamps.Effect = lamps._active[&"hall"]
		for lamp: Light3D in effect.plan:
			var plan: Array = effect.plan[lamp]
			dips += plan.size()
			for i in range(1, plan.size()):
				fastest = minf(fastest, (plan[i] as Vector3).x - (plan[i - 1] as Vector3).x)
		lamps.stop(&"hall")
	assert_gt(dips, 100, "plenty of dips looked at")
	assert_true(fastest >= 0.25 - 0.001, "no lamp dips more than 4 times a second (fastest %.3f s apart)" % fastest)


func test_an_outage_darkens_the_lamps_and_their_fittings_and_brings_them_back() -> void:
	var hall := _hall()
	var fitting := _fixture(&"hall", Vector3(0.0, 3.0, 0.0))
	var red := _lamp(&"hall", Vector3(2.0, 2.5, 0.0), 0.9, LightSpec.EMERGENCY)
	_install()
	lamps.play(&"hall", &"out", 3.0)
	await _seconds(0.5)
	for lamp in hall:
		assert_almost_eq(lamp.light_energy, 0.0, 0.0001, "out")
	assert_true(RoomLamps.is_dark(fitting), "its fitting goes dark too")
	assert_almost_eq(red.light_energy, 0.9, 0.0001, "the emergency lamp stays")
	await _seconds(lamps.length_of(&"hall"))
	assert_false(RoomLamps.is_dark(fitting), "the fitting glows again")


func test_a_sweep_goes_out_from_the_far_end_toward_the_guard() -> void:
	var hall := _hall()
	_install()
	lamps.play(&"hall", &"sweep", 0.0, Vector3(-2.0, 1.0, 0.0))
	assert_almost_eq(lamps.length_of(&"hall"), hall.size() * RoomLamps.SWEEP_STEP + RoomLamps.SWEEP_DARK, 0.001, "a lamp at a time, then the last one's dark")
	var first_out: Array[float] = []
	first_out.resize(hall.size())
	first_out.fill(-1.0)
	var t := 0.0
	for frame in 400:
		await get_tree().process_frame
		t += get_process_delta_time()
		for i in hall.size():
			if first_out[i] < 0.0 and hall[i].light_energy < 0.01:
				first_out[i] = t
		if not lamps.busy(&"hall"):
			break
	for i in hall.size():
		assert_gt(first_out[i], -0.5, "lamp %d went out" % i)
	for i in range(hall.size() - 1):
		assert_gt(first_out[i], first_out[i + 1], "lamp %d (nearer) after lamp %d" % [i, i + 1])


func test_exit_signs_blink_and_only_the_emergency_lamps() -> void:
	var hall := _hall()
	var red := _lamp(&"hall", Vector3(2.0, 2.5, 0.0), 0.9, LightSpec.EMERGENCY)
	var sign := _fixture(&"hall", Vector3(30.0, 2.5, 0.0), LightSpec.EMERGENCY)
	sign.set_meta(&"light", red)   # the level's own link, however far apart
	_install()
	assert_true(lamps.play(&"hall", &"exit", 2.0))
	var dark := 0
	for frame in 90:
		await get_tree().process_frame
		if red.light_energy < 0.05:
			dark += 1
		for lamp in hall:
			assert_almost_eq(lamp.light_energy, lamps.base_energy(lamp), 0.0001, "the main lamps do not take part")
	assert_gt(dark, 10, "the exit sign blinks")
	await _seconds(2.2)
	assert_almost_eq(red.light_energy, 0.9, 0.0001)
	assert_false(RoomLamps.is_dark(sign), "its sign glows again")
	assert_true(sign.has_meta(&"uncanny_lit"), "and it did blink")


func test_dark_and_flickering_lamps_are_left_alone() -> void:
	var dead := _lamp(&"hall", Vector3.ZERO, 1.0)
	dead.visible = false
	var tube := _lamp(&"hall", Vector3(4.0, 3.0, 0.0), 1.4, LightSpec.FLICKER)
	_install()
	assert_false(lamps.play(&"hall", &"flicker", 1.0), "no lamp to play: a blackout room")
	assert_eq(lamps.count(&"hall"), 0, "neither the dark lamp nor the tube is one of the room's lamps")
	assert_false(dead.visible)
	assert_almost_eq(tube.light_energy, 1.4, 0.0001)


func test_one_effect_at_a_time_per_room_and_rooms_apart() -> void:
	_hall()
	var other := _lamp(&"office", Vector3(40.0, 3.0, 0.0), 2.0)
	_install()
	assert_true(lamps.play(&"hall", &"brownout", 3.0))
	assert_false(lamps.play(&"hall", &"flicker", 1.0), "the hall is busy")
	assert_true(lamps.play(&"office", &"flicker", 1.0), "another room is not")
	assert_false(lamps.play(&"cellar", &"flicker", 1.0), "a room without lamps")
	assert_false(lamps.play(&"hall", &"disco", 1.0), "an unknown mode")
	lamps.stop_all()
	assert_almost_eq(other.light_energy, 2.0, 0.0001, "stopped: back at once")
	assert_false(lamps.busy(&"hall"))


func test_a_lamp_put_out_meanwhile_stays_out_and_its_fitting_dark() -> void:
	var hall := _hall()
	var fitting := _fixture(&"hall", Vector3(0.0, 3.0, 0.0))
	_install()
	lamps.play(&"hall", &"out", 1.0)
	await _seconds(0.3)
	for lamp in hall:
		lamp.visible = false   # the power cut, meanwhile
	await _seconds(1.5)
	assert_false(hall[0].visible, "nobody switches it back on")
	assert_true(RoomLamps.is_dark(fitting), "nor lights its fitting")


func test_freed_mid_effect_the_lamps_are_restored() -> void:
	var hall := _hall()
	_install()
	lamps.play(&"hall", &"out", 5.0)
	await _seconds(0.3)
	lamps.free()
	for i in hall.size():
		assert_almost_eq(hall[i].light_energy, 1.0 + i * 0.25, 0.0001)


## Photosensitivity (option "reduce_flashing", Flashing): the room's lamps
## stepped by hand at STEP s; [param watched] are the lamps to look at.
## Answers {starts: dip starts of the room (any lamp leaving its light),
## lowest: the least share of its light a lamp showed outside
## [param free_until] s (the outage itself), fittings_dark: a fitting went
## dark meanwhile}.
const STEP := 0.005

func _watch(room: StringName, mode: StringName, duration: float, watched: Array, fittings: Array = [], free_until: float = 0.0) -> Dictionary:
	assert_true(lamps.play(room, mode, duration, Vector3(-2.0, 1.0, 0.0)), "%s plays" % mode)
	var length := lamps.length_of(room)
	var starts: Array[float] = []
	var dipped := {}
	var lowest := 1.0
	var fittings_dark := false
	var t := 0.0
	while lamps.busy(room) and t < length + 1.0:
		lamps._process(STEP)
		t += STEP
		var any_new := false
		for lamp: Light3D in watched:
			var share := lamp.light_energy / lamps.base_energy(lamp)
			var low := share < 0.99
			if low and not dipped.get(lamp, false):
				any_new = true
			dipped[lamp] = low
			if t > free_until:
				lowest = minf(lowest, share)
		if any_new:
			starts.append(t)
		for fitting: Node in fittings:
			fittings_dark = fittings_dark or RoomLamps.is_dark(fitting)
	return {"starts": starts, "lowest": lowest, "fittings_dark": fittings_dark}


## The most of [param starts] (ascending) in any one second, and the least gap.
static func _rate(starts: Array[float]) -> Vector2:
	var most := 0
	var gap := INF
	for i in starts.size():
		if i > 0:
			gap = minf(gap, starts[i] - starts[i - 1])
		var count := 0
		for j in range(i, starts.size()):
			if starts[j] - starts[i] < 1.0:
				count += 1
		most = maxi(most, count)
	return Vector2(most, gap)


func test_with_reduce_flashing_a_room_flashes_at_most_three_times_a_second() -> void:
	Settings.set_value(&"reduce_flashing", true, false)
	var hall := _hall()
	var reds: Array[OmniLight3D] = []
	for i in 3:
		reds.append(_lamp(&"hall", Vector3(i * 6.0, 2.5, 1.0), 0.9, LightSpec.EMERGENCY))
	_install()
	for mode in [&"flicker", &"blink", &"out", &"sweep", &"exit", &"brownout"]:
		var watched: Array = reds if mode == &"exit" else hall
		var duration := 20.0 if mode == &"flicker" else 4.0
		var free_until := 0.0
		if mode == &"out":
			free_until = duration - RoomLamps._comeback_length()   # the outage is the event, not a flash
		var seen := _watch(&"hall", mode, duration, watched, [], free_until)
		var rate := _rate(seen["starts"])
		assert_gt((seen["starts"] as Array).size(), 0, "%s still plays" % mode)
		assert_true(rate.x <= Flashing.MAX_PER_SECOND, "%s: %d dips of the room in one second" % [mode, rate.x])
		assert_true(rate.y >= Flashing.MIN_GAP - STEP - 0.001, "%s: dips %.3f s apart" % [mode, rate.y])
		if mode != &"brownout":
			assert_true(seen["lowest"] >= Flashing.DIP_FLOOR - 0.001, "%s: a dip keeps half the light (%.2f)" % [mode, seen["lowest"]])
		for i in hall.size():
			assert_almost_eq(hall[i].light_energy, 1.0 + i * 0.25, 0.0001, "%s: lamp %d back" % [mode, i])


func test_with_reduce_flashing_the_fittings_keep_their_glow_through_a_dip() -> void:
	Settings.set_value(&"reduce_flashing", true, false)
	var hall := _hall()
	var fitting := _fixture(&"hall", Vector3(0.0, 3.0, 0.0))
	var red := _lamp(&"hall", Vector3(2.0, 2.5, 0.0), 0.9, LightSpec.EMERGENCY)
	var sign := _fixture(&"hall", Vector3(30.0, 2.5, 0.0), LightSpec.EMERGENCY)
	sign.set_meta(&"light", red)
	_install()
	assert_false(_watch(&"hall", &"sweep", 0.0, hall, [fitting])["fittings_dark"], "the sweep dims the lamps, the fittings stay lit")
	var exit := _watch(&"hall", &"exit", 3.0, [red], [sign])
	assert_false(exit["fittings_dark"], "the exit sign glows on")
	assert_gt((exit["starts"] as Array).size(), 2, "its lamp still blinks")
	# the outage itself still puts the fittings out: it is the event, not a flash
	var outage := _watch(&"hall", &"out", 3.0, hall, [fitting], 3.0)
	assert_true(outage["fittings_dark"], "an outage darkens its fittings")
	assert_false(RoomLamps.is_dark(fitting), "and lights them again")


func test_without_the_option_the_room_flickers_as_designed() -> void:
	var hall := _hall()
	var exit_red := _lamp(&"hall", Vector3(2.0, 2.5, 0.0), 0.9, LightSpec.EMERGENCY)
	_install()
	var seen := _watch(&"hall", &"flicker", 20.0, hall)
	assert_gt(_rate(seen["starts"]).x, Flashing.MAX_PER_SECOND, "six lamps flickering on their own stutter faster than three a second together")
	assert_lt(seen["lowest"], Flashing.DIP_FLOOR, "and dip deep")
	assert_gt(_rate(_watch(&"hall", &"exit", 2.0, [exit_red])["starts"]).x, Flashing.MAX_PER_SECOND, "the exit sign blinks four times a second")
