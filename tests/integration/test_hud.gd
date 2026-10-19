extends TestCase

var player: Player
var hud: Hud


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(20, 1, 20), Color.GRAY)
	player = Player.new()
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	hud = Hud.new()
	hud.player = player
	add_child(hud)


func test_shows_full_health_on_start() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(hud._health_label.text.contains("100"), hud._health_label.text)


func test_own_weak_point_hit_shows_a_gold_marker() -> void:
	var info := DamageInfo.make(20.0, DamageInfo.Kind.BALLISTIC, player)
	info.weak_point = true
	Events.hit_landed.emit(null, info, false)
	assert_gt(hud._crosshair.marker_time, 0.0)
	assert_eq(hud._crosshair.marker_color, Hud.WEAK_POINT_COLOR)


func test_hits_by_others_show_no_marker() -> void:
	Events.hit_landed.emit(null, DamageInfo.make(5.0, DamageInfo.Kind.BLUNT, null), false)
	assert_eq(hud._crosshair.marker_time, 0.0)


func test_damage_flashes_the_vignette() -> void:
	Events.player_damaged.emit(20.0, Vector3.ZERO)
	assert_gt(hud._vignette.modulate.a, 0.3)


func test_keeps_running_after_the_guard_is_freed() -> void:
	player.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	Events.hit_landed.emit(null, DamageInfo.make(5.0, DamageInfo.Kind.BLUNT, null), false)
	assert_eq(hud._crosshair.marker_time, 0.0)


func test_ammo_shows_magazine_and_reserve() -> void:
	player.weapons.give(load("res://src/weapons/data/pistol.tres"))
	await get_tree().process_frame
	assert_eq(hud._ammo_label.text, "12 | 36")


func test_the_slot_row_lights_the_weapons_found_and_the_one_in_hand() -> void:
	player.weapons.give(load("res://src/weapons/data/pistol.tres"))
	player.weapons.give(load("res://src/weapons/data/harpoon.tres"))
	player.weapons.select_id(&"harpoon")
	await get_tree().process_frame
	assert_eq(hud.slots_text(), "(1) 2 (3) (4) (5) (6) [7] (8)")


## The slot in hand is lit in its weapon's own colour: the colour its ammo
## boxes wear on the floor (WeaponPalette), so the two are learnt together.
func test_the_slot_in_hand_wears_the_weapons_colour() -> void:
	player.weapons.give(load("res://src/weapons/data/pistol.tres"))
	player.weapons.give(load("res://src/weapons/data/harpoon.tres"))
	player.weapons.select_id(&"harpoon")
	await get_tree().process_frame
	assert_eq(hud._slot_labels[6].label_settings.font_color, WeaponPalette.color(&"harpoon"))
	assert_eq(hud._slot_labels[6].label_settings.font_color, Pickup.color_of(Pickup.Type.HARPOONS))
	assert_eq(hud._slot_labels[1].label_settings.font_color, Hud.SLOT_OWNED, "the pistol: found, not in hand")
	player.weapons.select_id(&"pistol")
	await get_tree().process_frame
	assert_eq(hud._slot_labels[1].label_settings.font_color, WeaponPalette.color(&"pistol"))
	assert_eq(hud.slots_text(), "(1) [2] (3) (4) (5) (6) 7 (8)")


func test_the_fire_arrow_chest_shows_its_volley() -> void:
	player.weapons.give(load("res://src/weapons/data/hwacha.tres"))
	await get_tree().process_frame
	assert_true(hud._weapon_label.text.contains(tr("HUD_VOLLEY") % 6), hud._weapon_label.text)
	assert_eq(hud._ammo_label.text, "1 | 6")


# --- the guardians' bar follows the guardian that owns it ----------------------

## A guardian of the floor's plan #[param index], in the scene (not woken).
func _guardian(index: int) -> GuardianStub:
	var plan := Floor1Plan.guardians()[index]
	var guardian := GuardianStub.new()
	guardian.plan = plan
	guardian.guardian_id = plan.id
	add_child(guardian)
	return guardian


## Lets the bar's fade (0.6 s after a calm, 2 s after a fall) run out.
func _let_the_bar_fade() -> void:
	await get_tree().create_timer(2.5).timeout


func test_a_guardian_calmed_on_its_leash_takes_its_own_bar_away() -> void:
	hud.enable_floor()
	var colossus := _guardian(0)
	colossus.wake()
	assert_true(hud.boss_bar_shown())
	colossus.reset_fight()
	await _let_the_bar_fade()
	assert_false(hud.boss_bar_shown(), "the guardian went back to its post: no bar")


func test_a_guardian_calming_after_another_took_the_bar_leaves_the_bar_up() -> void:
	hud.enable_floor()
	var colossus := _guardian(0)
	var lamassu := _guardian(1)
	colossus.wake()
	lamassu.wake()
	lamassu.health.apply_damage(lamassu.max_health * 0.5)
	assert_true(hud.boss_name_text().contains(tr("GUARDIAN_LAMASSU").to_upper()), hud.boss_name_text())
	colossus.reset_fight()   # still on its leash from before: it calms down now
	await _let_the_bar_fade()
	assert_true(hud.boss_bar_shown(), "the Lamassu's bar stays")
	assert_true(hud.boss_name_text().contains(tr("GUARDIAN_LAMASSU").to_upper()), hud.boss_name_text())
	assert_almost_eq(hud.boss_fraction(), 0.5, 0.001, "and shows the Lamassu's health, not the Colossus's refilled")
	lamassu.reset_fight()
	await _let_the_bar_fade()
	assert_false(hud.boss_bar_shown(), "the guardian that owns the bar can still take it away")


func test_another_guardians_fall_does_not_empty_the_bar() -> void:
	hud.enable_floor()
	var colossus := _guardian(0)
	var lamassu := _guardian(1)
	colossus.wake()
	lamassu.wake()
	colossus.defeated.emit()
	await _let_the_bar_fade()
	assert_true(hud.boss_bar_shown(), "the Lamassu's bar stays")
	assert_almost_eq(hud.boss_fraction(), 1.0, 0.001)
	lamassu.defeated.emit()
	assert_almost_eq(hud.boss_fraction(), 0.0, 0.001, "its own fall empties it")


func test_a_guardian_woken_again_gets_its_bar_back_once() -> void:
	hud.enable_floor()
	var colossus := _guardian(0)
	colossus.wake()
	colossus.reset_fight()
	colossus.wake()
	assert_eq(colossus.calmed.get_connections().size(), 1, "one link to the bar, not one per waking")
	assert_eq(colossus.health.changed.get_connections().size(), 1)
	await _let_the_bar_fade()
	assert_true(hud.boss_bar_shown(), "awake again: the bar is up")


# --- fatigue (plan 2026-10-10-kawiarnia-zmeczenie) ------------------------------

func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _color_gap(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


func test_fatigue_eats_the_stamina_bar_from_the_right() -> void:
	await _frames(2)
	assert_eq(hud._stamina_bar.tired_fraction(), 0.0, "fresh: the whole bar")
	assert_almost_eq(hud._stamina_bar.value, 1.0, 0.001)
	player.fatigue.level = 1.0
	await physics_frames(2)
	await _frames(1)
	assert_almost_eq(hud._stamina_bar.tired_fraction(), Fatigue.CAPACITY_LOSS, 0.001, "30% eaten from the right")
	assert_almost_eq(hud._stamina_bar.value, 1.0 - Fatigue.CAPACITY_LOSS, 0.01, "the stamina fell to the cap")
	assert_eq(hud._stamina_bar.fill_color(), Hud.StaminaBar.FILL, "no caffeine: the plain yellow")


func test_caffeine_turns_the_fill_to_cream_and_exhaustion_stays_red() -> void:
	await _frames(2)
	var plain := hud._stamina_bar.fill_color()
	player.fatigue.drink(&"espresso")
	await physics_frames(60)
	await _frames(1)
	var cream := hud._stamina_bar.fill_color()
	assert_lt(_color_gap(cream, Hud.StaminaBar.CAFFEINE), 0.35, "the crema tone now")
	assert_gt(_color_gap(cream, plain), 0.3, "clearly not the yellow")
	player.stamina.current = 1.0
	player.stamina.exhausted = true
	await _frames(1)
	assert_eq(hud._stamina_bar.fill_color(), Hud.StaminaBar.EXHAUSTED, "exhaustion is the more urgent news")


## Exhaustion has to read at a glance on the 8 px bar: caffeine, at every
## moment of its pulse, differs from the exhausted red by colour AND by
## brightness (a colour-blind eye has only the second), and from the yellow.
func test_caffeine_never_looks_like_exhaustion_on_the_bar() -> void:
	var bar := Hud.StaminaBar.new()
	add_child(bar)
	var nearest_red := INF
	var nearest_yellow := INF
	var darkest := INF
	for i in 150:   # 7.5 s: three pulses, the first half second the colour still turns
		bar.show_state(1.0, 1.0, false, true, 0.05)
		if i < 15:
			continue
		var tone := bar.fill_color()
		nearest_red = minf(nearest_red, _color_gap(tone, Hud.StaminaBar.EXHAUSTED))
		nearest_yellow = minf(nearest_yellow, _color_gap(tone, Hud.StaminaBar.FILL))
		darkest = minf(darkest, tone.get_luminance())
	assert_gt(nearest_red, 0.6, "caffeine vs the exhausted red (%.2f)" % nearest_red)
	assert_gt(darkest - Hud.StaminaBar.EXHAUSTED.get_luminance(), 0.2, "and by brightness (%.2f)" % (darkest - Hud.StaminaBar.EXHAUSTED.get_luminance()))
	assert_gt(nearest_yellow, 0.3, "and from the plain yellow (%.2f)" % nearest_yellow)
	bar.free()


func test_the_stamina_bar_redraws_only_when_something_changed() -> void:
	var bar := Hud.StaminaBar.new()
	add_child(bar)
	await _frames(3)
	assert_gt(bar.draws, 0, "the first draw is done")
	var settled := bar.draws
	for i in 5:
		bar.show_state(1.0, 1.0, false, false, 0.016)
		await _frames(1)
	assert_eq(bar.draws, settled, "nothing changed: no redraw")
	# one change at a time: each is drawn once
	for step in [[0.5, 1.0, false], [0.5, 0.7, false], [0.5, 0.7, true]]:
		var before := bar.draws
		bar.show_state(step[0], step[1], step[2], false, 0.016)
		await _frames(2)
		assert_eq(bar.draws, before + 1, "changed: %s" % str(step))
	# the caffeinated fill turns for half a second, then pulses every frame
	var started := bar.draws
	for i in 8:
		bar.show_state(0.5, 0.7, false, true, 0.1)
		await _frames(1)
	assert_gt(bar.draws, started + 4, "the fill turns and pulses: drawn along")
	# exhausted, its red does not pulse
	bar.show_state(0.5, 0.7, true, true, 0.1)
	await _frames(2)
	var red := bar.draws
	for i in 5:
		bar.show_state(0.5, 0.7, true, true, 0.1)
		await _frames(1)
	assert_eq(bar.draws, red, "exhausted red stands still")
	bar.free()


func test_the_cool_vignette_follows_the_fatigue_above_the_threshold() -> void:
	await _frames(2)
	assert_eq(hud.fatigue_shade(), 0.0)
	player.fatigue.level = Fatigue.THRESHOLD
	await physics_frames(1)
	await _frames(1)
	assert_eq(hud.fatigue_shade(), 0.0, "nothing at the threshold")
	player.fatigue.level = 1.0
	await physics_frames(1)
	await _frames(1)
	assert_almost_eq(hud.fatigue_shade(), Hud.FATIGUE_VIGNETTE, 0.001)
	assert_lt(hud._vignette.modulate.a, 0.01, "the red damage vignette stays clear")


func test_a_tired_guard_blinks_now_and_then_a_fresh_one_never() -> void:
	await _frames(2)
	player.fatigue.level = 1.0
	var blinked := false
	var longest := 0.0
	# the first blink waits a whole BLINK_PERIOD_MAX after the threshold
	for i in roundi((Hud.BLINK_PERIOD_MAX + Hud.BLINK_TIME + 1.0) * 60.0):
		await get_tree().process_frame
		if hud.blink_phase() > 0.0:
			blinked = true
			longest = maxf(longest, hud._lid_top.modulate.a)
	assert_true(blinked, "a blink after the first period at the worst of the night")
	assert_gt(longest, 0.9, "the lids close")
	assert_eq(hud._lid_top.modulate.a, hud._lid_bottom.modulate.a)
	player.fatigue.level = 0.0
	await physics_frames(1)
	await _frames(60)
	for i in roundi(Hud.BLINK_PERIOD_MAX * 60.0):
		await get_tree().process_frame
		if hud.blink_phase() > 0.0:
			fail("fresh: no blink")
			break
