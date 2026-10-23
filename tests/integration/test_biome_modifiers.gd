extends TestCase
## The biome devices that change an exhibit's pace or sight (the regulator's
## "tock", the Helios beam's stiffness, the steam's blindness, the totems'
## night sight) do it as FACTORS that come off again by themselves, so that
## ending one never cancels another modifier on the same exhibit, whatever
## the order: the witching hour's x1.2 pace (NightWatch.boost) survives each
## of them (before, after or in the middle), and so does any other change of
## the exhibit's sight made while a device holds it (plan 2026-10-21-
## mechaniki-biomow, "Poprawki po przeglądzie" 1).

const CLOCK := Vector3(-6.0, 0.0, 0.0)
const LAMP := Vector3(-9.8, 3.0, 0.0)
const MIRROR := Vector3(9.8, 1.5, 0.0)
const MARKS: Array[Vector3] = [Vector3(-9.0, 1.3, 6.0), Vector3(4.0, 1.3, -12.0)]
const VENT := Vector3(0.0, 0.0, 0.0)
const WITCHING := NightWatch.WITCHING_BOOST

var host: BiomeMechanics
var player: Player


func before_each() -> void:
	GameInput.capture_allowed = false
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	player = Player.new()
	player.position = Vector3(6, 0.05, 6)
	add_child(player)
	host = BiomeMechanics.new()
	host.guard_source = func() -> Player: return player
	add_child(host)
	await physics_frames(2)


func after_each() -> void:
	GameInput.capture_allowed = true


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _wax(at: Vector3) -> WaxFigure:
	var wax := WaxFigure.new()
	wax.target = player
	wax.position = at
	wax.attack_damage = 0.0   # (the guard must outlive the waits)
	add_child(wax)
	return wax


# --- the regulator ------------------------------------------------------------------

func _regulator() -> Regulator:
	Greybox.box(self, Vector3(-6.5, 3.0, 0), Vector3(1, 6, 20), Color.GRAY)
	var regulator := Regulator.create({"at": CLOCK, "face": Vector3(1, 0, 0)})
	host.adopt(regulator, &"modifiers_test_regulator", &"")
	await physics_frames(2)
	return regulator


## A wax figure fighting the guard (a moment's stun: then it hunts).
func _fighter(at: Vector3) -> WaxFigure:
	var wax := _wax(at)
	wax.brain.stun(0.05)
	await physics_frames(10)
	return wax


func test_the_witching_hour_before_the_regulator_survives_its_tock() -> void:
	var regulator := await _regulator()
	var wax := await _fighter(Vector3(2, 0.05, 2))
	var pace := wax.move_speed
	NightWatch.boost(wax)
	assert_almost_eq(wax.move_speed, pace * WITCHING, 0.001)
	await _seconds(maxf(regulator.until_strike() - 0.2, 0.0))
	await _seconds(0.3 + Regulator.TICK + 0.1)
	assert_almost_eq(wax.move_speed, pace * WITCHING * Regulator.HASTE, 0.01, "tock on top of the witching hour")
	await _seconds(Regulator.HASTE_TIME)
	assert_almost_eq(wax.move_speed, pace * WITCHING, 0.01, "the tock ends, the witching hour does not")


func test_the_witching_hour_in_the_middle_of_the_tock_survives_it() -> void:
	var regulator := await _regulator()
	var wax := await _fighter(Vector3(2, 0.05, 2))
	var pace := wax.move_speed
	await _seconds(maxf(regulator.until_strike() - 0.2, 0.0))
	await _seconds(0.3 + Regulator.TICK + 0.1)
	assert_almost_eq(wax.move_speed, pace * Regulator.HASTE, 0.01, "tock")
	NightWatch.boost(wax)
	await _seconds(Regulator.HASTE_TIME)
	assert_almost_eq(wax.move_speed, pace * WITCHING, 0.01, "the bell of 3:00 struck in the middle of it stays")


# --- the Helios beam ----------------------------------------------------------------

func _lamp() -> HeliosLamp:
	Greybox.box(self, Vector3(10.5, 3.0, 0), Vector3(1, 6, 30), Color.GRAY)
	Greybox.box(self, Vector3(-10.5, 3.0, 0), Vector3(1, 6, 30), Color.GRAY)
	Greybox.box(self, Vector3(0, 3.0, -15.5), Vector3(22, 6, 1), Color.GRAY)
	var mirror := BronzeMirror.create({"at": MIRROR, "face": Vector3(-1, 0, 0), "marks": MARKS})
	host.adopt(mirror, &"modifiers_test_mirror", &"")
	var lamp := HeliosLamp.create({"at": LAMP, "face": Vector3(1, 0, 0), "aim": MIRROR}, [mirror])
	host.adopt(lamp, &"modifiers_test_lamp", &"")
	await physics_frames(2)
	return lamp


## An exhibit standing in the beam (stands still for the measure).
func _in_the_beam() -> WaxFigure:
	var lane := MIRROR.lerp(MARKS[0], 0.5)
	var wax := _wax(Vector3(lane.x, 0.05, lane.z))
	await physics_frames(3)
	wax.set_physics_process(false)
	return wax


func test_the_witching_hour_before_the_beam_survives_it() -> void:
	var lamp := await _lamp()
	var wax := await _in_the_beam()
	var pace := wax.move_speed
	NightWatch.boost(wax)
	lamp.lever.interact(player)
	await _seconds(1.0)
	assert_almost_eq(wax.move_speed, pace * WITCHING * HeliosLamp.SLOW, 0.01, "stiff and hastened both")
	var lane := MIRROR.lerp(MARKS[0], 0.5)
	wax.global_position = Vector3(lane.x, 0.05, lane.z - 4.0)
	await _seconds(HeliosLamp.SLOW_HOLD + 0.3)
	assert_almost_eq(wax.move_speed, pace * WITCHING, 0.01, "out of the beam: the witching hour is still on it")


func test_the_witching_hour_in_the_middle_of_the_beam_survives_it() -> void:
	var lamp := await _lamp()
	var wax := await _in_the_beam()
	var pace := wax.move_speed
	lamp.lever.interact(player)
	await _seconds(1.0)
	assert_almost_eq(wax.move_speed, pace * HeliosLamp.SLOW, 0.01, "stiff")
	NightWatch.boost(wax)
	var lane := MIRROR.lerp(MARKS[0], 0.5)
	wax.global_position = Vector3(lane.x, 0.05, lane.z - 4.0)
	await _seconds(HeliosLamp.SLOW_HOLD + 0.3)
	assert_almost_eq(wax.move_speed, pace * WITCHING, 0.01, "the bell struck while it burned: it is not cancelled")


func test_dawn_in_the_beam_gives_back_the_witching_pace_only() -> void:
	var lamp := await _lamp()
	var wax := await _in_the_beam()
	var pace := wax.move_speed
	NightWatch.boost(wax)
	lamp.lever.interact(player)
	await _seconds(0.6)
	host.freeze()
	assert_almost_eq(wax.move_speed, pace * WITCHING, 0.01, "frozen: only the witching hour is left")


# --- the steam ----------------------------------------------------------------------

func _vent() -> SteamVent:
	var vent := SteamVent.create({"at": VENT, "dir": Vector3(0, 0, 1), "across": 3.5, "height": 3.5, "valve": Vector3(2.5, 0.0, 0.0), "offset": 0.0})
	host.adopt(vent, &"modifiers_test_vent", &"")
	await physics_frames(2)
	return vent


func test_a_change_of_sight_made_while_the_steam_blinds_it_survives_the_steam() -> void:
	var vent := await _vent()
	var hurried := _wax(Vector3(0.0, 0.05, 2.0))
	await physics_frames(3)
	hurried.set_physics_process(false)
	hurried.brain.alarm(player.global_position)
	var sight := hurried.sight_range
	await _seconds(maxf(vent.until_burst(), 0.0))
	await _seconds(1.0)
	assert_almost_eq(hurried.sight_range, SteamVent.BLIND_RANGE, 0.01, "blind in the steam")
	hurried.sight_range *= 1.5   # something else sharpens its eyes meanwhile
	await _seconds(SteamVent.BURST + SteamVent.BLIND_HOLD)
	assert_almost_eq(hurried.sight_range, sight * 1.5, 0.01, "the steam gives back what it took, not what it saw")


# --- the totems' night sight --------------------------------------------------------

func test_a_change_of_sight_made_while_the_totem_is_blind_survives_the_light() -> void:
	var sight := TotemSight.create([])
	host.adopt(sight, &"modifiers_test_sight", &"")
	var totem := Totem.new()
	totem.faces = 3
	totem.target = player
	totem.position = Vector3(0, 0, -8)
	add_child(totem)
	var full := totem.sight_range
	await _seconds(0.5)
	assert_almost_eq(totem.sight_range, TotemSight.BLIND_RANGE, 0.01, "no fire, no torch: blind but for its close sense")
	totem.sight_range *= 1.5   # something else sharpens its eyes meanwhile
	player.set_flashlight(true)
	await _seconds(0.5)
	assert_almost_eq(totem.sight_range, full * 1.5, 0.01, "his torch gives him away: it sees as far as it ever did")


# --- the table of factors itself ----------------------------------------------------

func test_pace_factors_multiply_and_come_off_in_any_order() -> void:
	var wax := _wax(Vector3(-20, 0.05, 20))
	var pace := wax.move_speed
	ExhibitMods.scale_pace(wax, 1, 0.4)
	ExhibitMods.scale_pace(wax, 2, 1.35)
	assert_almost_eq(wax.move_speed, pace * 0.4 * 1.35, 0.001, "both at once")
	NightWatch.boost(wax)
	ExhibitMods.clear_pace(wax, 1)
	assert_almost_eq(wax.move_speed, pace * 1.35 * WITCHING, 0.001, "the first one off: the others stay")
	ExhibitMods.clear_pace(wax, 2)
	assert_almost_eq(wax.move_speed, pace * WITCHING, 0.001, "and the second: only the witching hour is left")
	assert_false(ExhibitMods.any(wax), "nothing held, no trace")
	ExhibitMods.clear_pace(wax, 2)
	assert_almost_eq(wax.move_speed, pace * WITCHING, 0.001, "taking off what is not there changes nothing")


func test_a_factor_put_twice_under_one_key_counts_once() -> void:
	var wax := _wax(Vector3(-20, 0.05, 20))
	var pace := wax.move_speed
	ExhibitMods.scale_pace(wax, 7, 0.4)
	ExhibitMods.scale_pace(wax, 7, 0.4)
	assert_almost_eq(wax.move_speed, pace * 0.4, 0.001)
	ExhibitMods.clear_pace(wax, 7)
	assert_almost_eq(wax.move_speed, pace, 0.001)


func test_sight_caps_overlap_the_sharper_rules_and_either_can_go_first() -> void:
	var wax := _wax(Vector3(-20, 0.05, 20))
	var sight := wax.sight_range
	ExhibitMods.cap_sight(wax, 1, 2.5)
	ExhibitMods.cap_sight(wax, 2, 1.5)
	assert_almost_eq(wax.sight_range, 1.5, 0.001, "the sharper cap rules")
	ExhibitMods.clear_sight(wax, 2)
	assert_almost_eq(wax.sight_range, 2.5, 0.001, "it goes: the other cap holds")
	ExhibitMods.cap_sight(wax, 2, 1.5)
	ExhibitMods.clear_sight(wax, 1)
	assert_almost_eq(wax.sight_range, 1.5, 0.001, "the other way round: the sharper one still holds")
	ExhibitMods.clear_sight(wax, 2)
	assert_almost_eq(wax.sight_range, sight, 0.001, "all off: its own sight")
	assert_false(ExhibitMods.any(wax))


func test_a_cap_never_sharpens_a_short_sighted_exhibit() -> void:
	var wax := _wax(Vector3(-20, 0.05, 20))
	wax.sight_range = 1.0
	ExhibitMods.cap_sight(wax, 1, 2.5)
	assert_almost_eq(wax.sight_range, 1.0, 0.001, "it sees less than the cap already")
	ExhibitMods.clear_sight(wax, 1)
	assert_almost_eq(wax.sight_range, 1.0, 0.001)
