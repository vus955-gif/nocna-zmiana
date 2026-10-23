extends TestCase
## The option "reduce_flashing" (plan 2026-10-21-dostepnosc, class Flashing):
## with it on, no source of light or screen flashing goes over three flashes
## a second (WCAG 2.3.1) and each flash is shallower - the flickering tubes,
## the muzzle's light and star, a model's hit flash, the red edges of a
## hit, the low-health pulse, the torch's low blink, the weak flashlight,
## the main menu's lamp. With it off every one behaves as before.

const FRAME := 1.0 / 60.0


func after_each() -> void:
	Settings.reset_to_defaults(false)


func _reduce(on: bool) -> void:
	Settings.set_value(&"reduce_flashing", on, false)


## The most events (their start times, ascending) in any window of one second.
func _most_in_a_second(starts: Array[float]) -> int:
	var most := 0
	for i in starts.size():
		var count := 0
		for j in range(i, starts.size()):
			if starts[j] - starts[i] < 1.0:
				count += 1
			else:
				break
		most = maxi(most, count)
	return most


func test_the_helpers_change_nothing_while_the_option_is_off() -> void:
	assert_false(Flashing.on())
	assert_eq(Flashing.light_energy(3.0), 3.0)
	assert_eq(Flashing.lamp_level(0.1), 0.1)
	assert_eq(Flashing.hit_flash(1.0), 1.0)
	assert_eq(Flashing.vignette(0.9), 0.9)
	assert_eq(Flashing.pulse(1.0), 1.0)
	assert_eq(Flashing.gap(0.05), 0.05)


func test_the_helpers_soften_while_the_option_is_on() -> void:
	_reduce(true)
	assert_true(Flashing.on())
	assert_eq(Flashing.light_energy(3.0), 3.0 * Flashing.LIGHT_SHARE)
	assert_eq(Flashing.lamp_level(0.0), Flashing.DIP_FLOOR, "no lamp goes out")
	assert_eq(Flashing.lamp_level(0.8), 0.8, "a shallow dip stays as it was")
	assert_eq(Flashing.hit_flash(1.0), Flashing.HIT_FLASH_CAP)
	assert_eq(Flashing.hit_flash(0.1), 0.1)
	assert_eq(Flashing.vignette(0.9), Flashing.VIGNETTE_CAP)
	assert_eq(Flashing.pulse(1.0), Flashing.PULSE_SHARE)
	assert_gt(Flashing.gap(0.05), 1.0 / (Flashing.MAX_PER_SECOND + 1) - 0.001, "flashes are spaced to three a second")
	assert_lt(Flashing.DIP_FLOOR, 1.0)
	assert_gt(1.0 / Flashing.MIN_GAP, 2.5, "the gap leaves room for the three")
	assert_lt(1.0 / Flashing.MIN_GAP, Flashing.MAX_PER_SECOND + 0.001, "and no more")


func test_the_gate_lets_three_a_second_through_and_everything_when_off() -> void:
	var gate := Flashing.Gate.new()
	var allowed_off := 0
	for i in 600:
		if gate.allow(i * FRAME):
			allowed_off += 1
	assert_eq(allowed_off, 600, "off: every flash")
	_reduce(true)
	gate.reset()
	var starts: Array[float] = []
	for i in 600:
		if gate.allow(i * FRAME):
			starts.append(i * FRAME)
	assert_lt(starts.size(), 31, "on: ten seconds of asking give at most three a second")
	assert_gt(starts.size(), 25, "but not fewer than that")
	assert_true(_most_in_a_second(starts) <= Flashing.MAX_PER_SECOND, "no second holds more than three")


# --- the basement's tubes ------------------------------------------------------------

## A group of flickering tubes ticked by hand for [param seconds] of game
## time: the starts of their dips, and the deepest dip (share of the light).
func _tubes(seconds: float, count: int = 6) -> Dictionary:
	var parent := Node3D.new()
	add_child(parent)
	var lamps: Array[OmniLight3D] = []
	for i in count:
		var lamp := OmniLight3D.new()
		lamp.light_energy = 1.2
		lamp.add_to_group(LightSpec.FLICKER)
		parent.add_child(lamp)
		lamps.append(lamp)
	var flicker := LampFlicker.attach(parent)
	var down := {}   # lamp -> true while dipped
	var starts: Array[float] = []
	var deepest := 1.0
	var t := 0.0
	while t < seconds:
		flicker._process(FRAME)
		t += FRAME
		for lamp in lamps:
			var share := lamp.light_energy / 1.2
			deepest = minf(deepest, share)
			var dipped := share < 0.99
			if dipped and not down.get(lamp, false):
				starts.append(t)
			down[lamp] = dipped
	parent.queue_free()
	return {"starts": starts, "deepest": deepest}


func test_the_tubes_stutter_hard_by_default() -> void:
	var seen := _tubes(60.0)
	assert_gt(_most_in_a_second(seen["starts"]), Flashing.MAX_PER_SECOND, "the default bursts go over three a second (so the cap below means something)")
	assert_lt(seen["deepest"], Flashing.DIP_FLOOR, "and drop out nearly dark")


func test_reduced_the_tubes_dip_at_most_three_times_a_second_and_never_below_half() -> void:
	_reduce(true)
	var seen := _tubes(120.0)
	var starts: Array[float] = seen["starts"]
	assert_gt(starts.size(), 10, "they still stutter")
	assert_true(_most_in_a_second(starts) <= Flashing.MAX_PER_SECOND, "at most three dips in any second, among all six lamps: %d" % _most_in_a_second(starts))
	assert_true(seen["deepest"] >= Flashing.DIP_FLOOR - 0.001, "no deeper than half: %.2f" % seen["deepest"])


# --- point lights (the muzzle, a zap, a blast) ----------------------------------------

## The point lights Fx gets in [param frames] frames when [param make] is
## called every frame; their energies come back too.
func _lights_made(frames: int, make: Callable) -> Array[float]:
	var energies: Array[float] = []
	var count := func(node: Node) -> void:
		if node is OmniLight3D:
			energies.append((node as OmniLight3D).light_energy)
	Fx.child_entered_tree.connect(count)
	for i in frames:
		make.call()
		await get_tree().process_frame
	Fx.child_entered_tree.disconnect(count)
	return energies


func test_quick_flashes_of_light_are_halved_and_spaced_when_reduced() -> void:
	var quick := func() -> void: Fx.flash(Vector3.ZERO, Color.WHITE, 3.0, 7.0, 0.06)
	var plenty: Array[float] = await _lights_made(120, quick)
	assert_eq(plenty.size(), 120, "off: every shot lights the room")
	assert_almost_eq(plenty[0], 3.0, 0.001)
	_reduce(true)
	var few: Array[float] = await _lights_made(120, quick)
	assert_gt(few.size(), 3, "on: it still flashes")
	assert_lt(few.size(), 8, "but 2 s of fire gives at most three a second: %d" % few.size())
	for energy in few:
		assert_almost_eq(energy, 3.0 * Flashing.LIGHT_SHARE, 0.001, "at half the light")


## Every weapon's muzzle light is a quick flash, so the gate spaces it - the
## gatling's, at ten rounds a second, most of all.
func test_every_muzzle_light_counts_as_a_quick_flash() -> void:
	for id in WeaponHolder.SLOT_ORDER:
		var feel := FeelProfile.of(id)
		assert_lt(feel.light_time, Fx.QUICK_FLASH, "%s's muzzle light lasts %.2f s" % [id, feel.light_time])


func test_a_long_flash_is_halved_but_never_dropped() -> void:
	_reduce(true)
	var long := func() -> void: Fx.flash(Vector3.ZERO, Color.RED, 8.0, 14.0, 0.5)
	var seen: Array[float] = await _lights_made(5, long)
	assert_eq(seen.size(), 5, "a blast or a boss's cue is always shown")
	assert_almost_eq(seen[0], 4.0, 0.001)


## A first-person weapon's muzzle: the star shown by fire().
func _muzzle(weapon: StringName) -> MuzzleFx:
	var holder := Node3D.new()
	add_child(holder)
	var view := Node3D.new()
	view.add_child(Node3D.new())
	view.get_child(0).name = "Muzzle"
	holder.add_child(view)
	return MuzzleFx.attach(holder, view, FeelProfile.of(weapon))


func test_the_muzzle_star_is_dimmed_and_spaced_when_reduced() -> void:
	var fx := _muzzle(&"pistol")
	await get_tree().process_frame
	assert_not_null(fx._star, "the pistol has a muzzle star")
	if fx._star == null:
		return
	for i in 120:
		fx.fire()
		fx._process(FRAME)
	assert_eq(fx.flashes, 120, "off: a star for every round")
	assert_almost_eq(fx._star.transparency, 0.0, 0.001, "at full strength")
	_reduce(true)
	fx.flashes = 0
	for i in 120:
		fx.fire()
		fx._process(FRAME)
	assert_gt(fx.flashes, 3)
	assert_lt(fx.flashes, 8, "two seconds of fire show at most three stars a second: %d" % fx.flashes)
	assert_almost_eq(fx._star.transparency, 1.0 - Flashing.PULSE_SHARE, 0.001, "and dimmer")


# --- a model's hit flash ----------------------------------------------------------------

func test_a_models_white_hit_flash_is_capped_when_reduced() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	var dummy := TargetDummy.new()
	dummy.position = Vector3(0, 0, -30)
	add_child(dummy)
	var peaks: Array[float] = []
	for on in [false, true]:
		_reduce(on)
		var wolf := NightSpawner.make(&"wolf")
		wolf.target = dummy
		add_child(wolf)
		await physics_frames(2)
		wolf.take_damage(DamageInfo.make(5.0, DamageInfo.Kind.BALLISTIC, dummy))
		var peak := 0.0
		for i in 8:
			await physics_frames(1)
			for view in wolf.rig.meshes:
				if is_instance_valid(view):
					peak = maxf(peak, float(view.get_instance_shader_parameter(&"flash")))
		peaks.append(peak)
		wolf.queue_free()
	assert_gt(peaks[0], 0.7, "off: the flash is strong (%.2f)" % peaks[0])
	assert_gt(peaks[1], 0.2, "on: still a flash")
	assert_true(peaks[1] <= Flashing.HIT_FLASH_CAP + 0.001, "but no stronger than the cap (%.2f)" % peaks[1])


# --- the HUD ---------------------------------------------------------------------------

func test_the_red_edges_of_a_hit_stop_at_the_cap_when_reduced() -> void:
	var hud := Hud.new()
	add_child(hud)
	Events.player_damaged.emit(100.0, Vector3.ZERO)
	assert_almost_eq(hud._vignette.modulate.a, 0.9, 0.001, "off: nearly opaque red edges for a hard hit")
	_reduce(true)
	Events.player_damaged.emit(100.0, Vector3.ZERO)
	assert_almost_eq(hud._vignette.modulate.a, Flashing.VIGNETTE_CAP, 0.001, "on: half")
	Events.player_damaged.emit(2.0, Vector3.ZERO)
	assert_lt(hud._vignette.modulate.a, Flashing.VIGNETTE_CAP + 0.001, "a light hit is under the cap anyway")
	hud.free()


func test_the_low_health_pulse_swings_half_as_far_when_reduced() -> void:
	var gauge := HudGauge.make(Vector2(300, 18), UiTheme.EMERGENCY, 10)
	gauge.low_pulse = 0.3
	gauge.value = 0.1
	add_child(gauge)
	var strongest := func() -> float:
		var most := 0.0
		for i in 120:
			gauge._pulse = i * FRAME   # two seconds
			most = maxf(most, gauge.pulse())
		return most
	assert_gt(strongest.call(), 0.99, "off: the mount pulses to full")
	_reduce(true)
	assert_almost_eq(strongest.call(), Flashing.PULSE_SHARE, 0.01, "on: to half")
	assert_lt(0.9, float(Flashing.MAX_PER_SECOND), "and it was always slower than three a second")
	gauge.free()


func test_the_low_torch_stops_blinking_when_reduced() -> void:
	var hud := Hud.new()
	add_child(hud)
	var blinks := PackedByteArray()
	for step in 40:
		blinks.append(1 if hud.torch_alert(true, step * 0.05) else 0)
	assert_true(1 in blinks and 0 in blinks, "off: it blinks")
	assert_false(hud.torch_alert(false, 0.1), "a charged torch never alerts")
	_reduce(true)
	for step in 40:
		assert_true(hud.torch_alert(true, step * 0.05), "on: a steady red alert at %.2f s" % (step * 0.05))
	hud.free()


# --- the guard's flashlight and the menu's lamp ---------------------------------------

## The flashlight's light over [param seconds] of a weak battery: [deepest
## share of its light, most reversals in a second].
func _weak_flashlight(seconds: float) -> Array[float]:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	var player := Player.new()
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	await physics_frames(3)
	player.battery.charge = player.battery.capacity * 0.14
	player.battery.on = true
	var deepest := 1.0
	var turns: Array[float] = []
	var last := -1.0
	var rising := true
	var t := 0.0
	for i in int(seconds * 60.0):
		player.battery.charge = player.battery.capacity * 0.14   # (kept lit and weak)
		await get_tree().process_frame
		t += FRAME
		player._update_flashlight_light()
		var energy := player.flashlight.light_energy
		deepest = minf(deepest, energy / Player.FLASHLIGHT_ENERGY)
		if last >= 0.0 and absf(energy - last) > 0.02:
			var now_rising := energy > last
			if now_rising != rising:
				turns.append(t)
				rising = now_rising
		last = energy
	player.queue_free()
	return [deepest, float(_most_in_a_second(turns))]


func test_a_weak_flashlight_wobbles_gently_when_reduced() -> void:
	var plain: Array[float] = await _weak_flashlight(12.0)
	assert_lt(plain[0], Flashing.DIP_FLOOR, "off: it nearly dies (%.2f of its light)" % plain[0])
	_reduce(true)
	var gentle: Array[float] = await _weak_flashlight(12.0)
	assert_true(gentle[0] >= Flashing.DIP_FLOOR - 0.001, "on: never under half (%.2f)" % gentle[0])
	assert_true(gentle[1] <= 2.0 * Flashing.MAX_PER_SECOND, "and changes direction at most six times a second (%d)" % int(gentle[1]))


func test_the_menus_lamp_dips_once_and_softly_when_reduced() -> void:
	var stage := MenuStage.new()
	var plain := stage.beats()
	assert_gt(plain.size(), 4, "off: a burst of drop-outs")
	var darkest := 1.0
	for beat in plain:
		darkest = minf(darkest, beat.x)
	assert_lt(darkest, 0.2)
	_reduce(true)
	var soft := stage.beats()
	assert_eq(soft.size(), 2, "on: one dip and back")
	assert_true(soft[0].x >= Flashing.DIP_FLOOR - 0.001, "not below half")
	assert_gt(soft[0].y, Flashing.MIN_GAP - 0.001, "and slow, not a blink")
	assert_eq(soft[soft.size() - 1].x, 1.0, "back to full strength")
	stage.free()
