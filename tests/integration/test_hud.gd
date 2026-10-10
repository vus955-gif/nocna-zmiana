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


func test_the_fire_arrow_chest_shows_its_volley() -> void:
	player.weapons.give(load("res://src/weapons/data/hwacha.tres"))
	await get_tree().process_frame
	assert_true(hud._weapon_label.text.contains(tr("HUD_VOLLEY") % 6), hud._weapon_label.text)
	assert_eq(hud._ammo_label.text, "1 | 6")
