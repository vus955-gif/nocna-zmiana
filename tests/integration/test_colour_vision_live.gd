extends TestCase
## The option "colour_vision" changes the game, at once (plan
## 2026-10-21-dostepnosc section 4): the weapon colours wherever they are
## read (the HUD slot in hand, the pickups' rims, the greybox), the HUD's
## roles (health and boss bars, stamina, fuses, hit markers), the rims of
## pickups already lying in the world; and the cues that do not need colour
## at all - each hit marker's shape, the exhausted stamina's hatching, the
## fuses' stripes and filament.

const AMMO_TYPES: Array[Pickup.Type] = [Pickup.Type.BULLETS, Pickup.Type.SHELLS, Pickup.Type.RIFLE, Pickup.Type.FLARES,
	Pickup.Type.HUNT_ROUNDS, Pickup.Type.HARPOONS, Pickup.Type.ROCKETS]

var player: Player
var hud: Hud


func after_each() -> void:
	Settings.reset_to_defaults(false)


func _mode(mode: int) -> void:
	Settings.set_value(&"colour_vision", mode, false)


func _hud() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(20, 1, 20), Color.GRAY)
	player = Player.new()
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	hud = Hud.new()
	hud.player = player
	add_child(hud)


func _rgb_close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.002 and absf(a.g - b.g) < 0.002 and absf(a.b - b.b) < 0.002


func test_the_option_swaps_the_weapon_colours_wherever_they_are_read() -> void:
	for mode in ColourVision.MODES:
		_mode(mode)
		assert_eq(ColourVision.current(), mode)
		for type in AMMO_TYPES:
			var ammo: StringName = Pickup.AMMO[type]
			var weapon: StringName = WeaponPalette.AMMO_WEAPONS[ammo]
			var expected := ColourVision.weapon(weapon, WeaponPalette.COLORS[weapon], mode)
			assert_eq(WeaponPalette.color(weapon), expected, "%d: HUD colour of %s" % [mode, weapon])
			assert_eq(Pickup.color_of(type), expected, "%d: %s's pickup" % [mode, ammo])
			assert_eq(ArtLibrary.pickup_rim_color(Pickup.MODELS[type]), expected, "%d: %s's rim" % [mode, ammo])
		assert_eq(Pickup.color_of(Pickup.Type.MEDKIT), WeaponPalette.MEDKIT_COLOR, "%d: the medkit stays white" % mode)
		assert_eq(ArtLibrary.pickup_rim_color("fuse"), ArtLibrary.PICKUP_RIM_COLOR, "%d: the fuse keeps the warm rim" % mode)
	_mode(ColourVision.PROTANOPIA)
	assert_ne(WeaponPalette.color(&"pistol"), WeaponPalette.COLORS[&"pistol"], "a protanope's pistol is not the standard blue")


func test_the_rims_of_pickups_already_in_the_world_change_at_once() -> void:
	if not ArtLibrary.has_model(&"ammo_shells"):
		return   # a checkout without the models: the greybox has no rim
	var box := ArtLibrary.pickup(&"ammo_shells")
	add_child(box)
	var whole := ArtLibrary.exhibit_material("ammo_shells")
	var broken := ArtLibrary.exhibit_material("ammo_shells", true)
	var worn := false
	for child in box.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		for i in view.mesh.get_surface_count():
			worn = worn or view.get_surface_override_material(i) == whole
	assert_true(worn, "the box wears the shared material")
	for mode in [ColourVision.DEUTERANOPIA, ColourVision.PROTANOPIA, ColourVision.TRITANOPIA, ColourVision.NORMAL]:
		_mode(mode)
		var expected := WeaponPalette.ammo_color(&"shells")
		assert_true(_rgb_close(whole.get_shader_parameter(&"rim_color"), expected), "%d: the rim of the box on the floor" % mode)
		assert_true(_rgb_close(broken.get_shader_parameter(&"rim_color"), expected), "%d: and of its broken pieces" % mode)
	var medkit := ArtLibrary.exhibit_material("medkit")
	_mode(ColourVision.TRITANOPIA)
	assert_true(_rgb_close(medkit.get_shader_parameter(&"rim_color"), WeaponPalette.MEDKIT_COLOR), "the medkit's rim stays white")
	box.free()


func test_the_hud_takes_the_palette_at_once() -> void:
	_hud()
	player.weapons.give(load("res://src/weapons/data/pistol.tres"))
	player.weapons.select_id(&"pistol")
	await get_tree().process_frame
	for mode in [ColourVision.PROTANOPIA, ColourVision.DEUTERANOPIA, ColourVision.TRITANOPIA, ColourVision.NORMAL]:
		_mode(mode)
		assert_eq(hud._health_bar.fill, ColourVision.role(&"health", mode), "%d: health bar" % mode)
		assert_eq(hud._boss_bar.fill, ColourVision.role(&"boss", mode), "%d: boss bar" % mode)
		assert_eq(hud._caffeine_icon.color, ColourVision.role(&"stamina_caffeine", mode), "%d: the cup" % mode)
		assert_eq(hud._stamina_bar.fill_color(), ColourVision.role(&"stamina_fill", mode), "%d: stamina" % mode)
		var slot := WeaponHolder.SLOT_ORDER.find(&"pistol")
		assert_eq(hud._slot_labels[slot].label_settings.font_color, ColourVision.weapon(&"pistol", WeaponPalette.COLORS[&"pistol"], mode),
				"%d: the slot in hand, without waiting a frame" % mode)
	_mode(ColourVision.PROTANOPIA)
	assert_ne(hud._health_bar.fill, UiTheme.EMERGENCY, "a protanope's health bar is a brighter red")
	hud._stamina_bar.exhausted = true
	assert_eq(hud._stamina_bar.fill_color(), ColourVision.role(&"stamina_exhausted", ColourVision.PROTANOPIA))


func test_each_kind_of_hit_has_its_colour_and_its_own_shape() -> void:
	_hud()
	_mode(ColourVision.TRITANOPIA)
	var cases := {&"hit": [false, false, false], &"weak_point": [true, false, false], &"kill": [false, true, false], &"blocked": [false, false, true]}
	for kind: StringName in cases:
		var flags: Array = cases[kind]
		var info := DamageInfo.make(10.0, DamageInfo.Kind.BALLISTIC, player)
		info.weak_point = flags[0]
		info.blocked = flags[2]
		Events.hit_landed.emit(null, info, flags[1])
		assert_eq(hud._crosshair.marker_kind, kind)
		var role := &"hit" if kind == &"hit" else StringName("hit_" + kind)
		assert_eq(hud._crosshair.marker_color, ColourVision.role(role, ColourVision.TRITANOPIA), "%s in the tritanope's colour" % kind)
	# the shapes alone tell them apart: count, slant, length, weight
	var looks := {}
	for kind: StringName in cases:
		var ticks := Hud.Crosshair.ticks(kind)
		var diagonal := 0
		var upright := 0
		var reach := 0.0
		var weight := 0.0
		for tick: Array in ticks:
			var dir: Vector2 = tick[0]
			if absf(dir.x) > 0.01 and absf(dir.y) > 0.01:
				diagonal += 1
			else:
				upright += 1
			reach = maxf(reach, float(tick[2]))
			weight = maxf(weight, float(tick[3]))
		looks[kind] = [diagonal, upright, reach, weight]
	assert_eq(looks[&"hit"].slice(0, 2), [4, 0], "a hit: four slanted ticks")
	assert_eq(looks[&"weak_point"].slice(0, 2), [4, 0], "a weak point: slanted too...")
	assert_gt(looks[&"weak_point"][2], looks[&"hit"][2] + 4.0, "...but longer")
	assert_gt(looks[&"weak_point"][3], looks[&"hit"][3] + 1.0, "...and heavier")
	assert_eq(looks[&"kill"].slice(0, 2), [4, 4], "a kill: slanted ticks and an upright cross")
	assert_eq(looks[&"blocked"].slice(0, 2), [0, 4], "blocked: the upright cross alone")


func test_exhaustion_and_the_fuses_read_without_their_colours() -> void:
	var bar := Hud.StaminaBar.new()
	add_child(bar)
	bar.show_state(0.5, 1.0, false, false, 0.016)
	assert_false(bar.hatched(), "plain stamina: a plain fill")
	bar.show_state(0.1, 1.0, true, false, 0.016)
	assert_true(bar.hatched(), "exhausted: the fill is hatched")
	bar.free()
	var fuses := Hud.FuseIcons.new()
	add_child(fuses)
	fuses.set_counts(0, 0)
	assert_eq([fuses.look(0), fuses.look(1)], [&"missing", &"missing"])
	fuses.set_counts(1, 1)
	assert_eq([fuses.look(0), fuses.look(1)], [&"inserted", &"carried"], "one in the box (solid, a filament), one in the pocket (striped)")
	fuses.set_counts(2, 0)
	assert_eq([fuses.look(0), fuses.look(1)], [&"carried", &"carried"])
	fuses.free()


## The heart icon and the bars of [param of_hud] in [param mode]'s colours.
func _assert_hud_in(of_hud: Hud, mode: int, why: String) -> void:
	assert_eq(of_hud._health_bar.fill, ColourVision.role(&"health", mode), "%s: health bar" % why)
	assert_eq(of_hud._heart_icon.color, ColourVision.role(&"health", mode).lightened(Hud.HEART_LIGHTEN), "%s: the heart" % why)
	assert_eq(of_hud._boss_bar.fill, ColourVision.role(&"boss", mode), "%s: boss bar" % why)
	assert_eq(of_hud._caffeine_icon.color, ColourVision.role(&"stamina_caffeine", mode), "%s: the cup" % why)


func test_the_heart_wears_the_health_bars_red() -> void:
	_hud()
	_assert_hud_in(hud, ColourVision.NORMAL, "standard")
	_mode(ColourVision.PROTANOPIA)
	_assert_hud_in(hud, ColourVision.PROTANOPIA, "switched to protanopia")


func test_a_hud_built_with_the_option_already_set_wears_it_from_the_start() -> void:
	_mode(ColourVision.PROTANOPIA)
	_hud()
	_assert_hud_in(hud, ColourVision.PROTANOPIA, "built for a protanope")
	_mode(ColourVision.TRITANOPIA)
	hud._stamina_bar.exhausted = false
	assert_eq(hud._stamina_bar.fill_color(), ColourVision.role(&"stamina_fill", ColourVision.TRITANOPIA))


func test_a_fuse_in_the_box_shows_its_filament_in_every_palette() -> void:
	for mode in ColourVision.MODES:
		var body := ColourVision.role(&"fuse_inserted", mode)
		var edge := body.lerp(Color(Hud.FuseIcons.FILAMENT_EDGE, 1.0), Hud.FuseIcons.FILAMENT_EDGE.a)
		assert_gt(ColourVision.contrast_seen(Hud.FuseIcons.FILAMENT_COLOR, edge, mode), 4.5, "%d: the filament on its dark edge" % mode)
		assert_gt(ColourVision.contrast_seen(edge, body, mode), 3.0, "%d: the edge on the fuse's body" % mode)
	assert_gt(Hud.FuseIcons.FILAMENT_EDGE_WIDTH, 0.5, "an edge to see")


func test_a_pickup_first_dressed_in_another_palette_wears_that_palette() -> void:
	if not ArtLibrary.has_model(&"ammo_flares"):
		return
	_mode(ColourVision.DEUTERANOPIA)
	ArtLibrary._materials.erase("exhibit:ammo_flares")   # as if no flare box had been dressed yet this game
	ArtLibrary._materials.erase("exhibit_debris:ammo_flares")
	var box := ArtLibrary.pickup(&"ammo_flares")
	add_child(box)
	var flare_deut := ColourVision.weapon(&"flare", WeaponPalette.COLORS[&"flare"], ColourVision.DEUTERANOPIA)
	assert_true(_rgb_close(ArtLibrary.exhibit_material("ammo_flares").get_shader_parameter(&"rim_color"), flare_deut), "made in deuteranopia")
	assert_true(_rgb_close(ArtLibrary.exhibit_material("ammo_flares", true).get_shader_parameter(&"rim_color"), flare_deut), "its broken pieces too")
	_mode(ColourVision.NORMAL)
	assert_true(_rgb_close(ArtLibrary.exhibit_material("ammo_flares").get_shader_parameter(&"rim_color"), WeaponPalette.COLORS[&"flare"]), "and back to standard")
	box.free()


## The rim colour the first ammo box under [param root] wears.
func _rim_in(root: Node, tex_name: String) -> Variant:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		for i in view.mesh.get_surface_count():
			var mat := view.get_surface_override_material(i) as ShaderMaterial
			if mat != null and mat.resource_name == tex_name:
				return mat.get_shader_parameter(&"rim_color")
	return null


func test_a_museum_freed_and_built_again_follows_the_option() -> void:
	if not ArtLibrary.has_model(&"ammo_shells"):
		return
	GameState.new_game()
	for mode in [ColourVision.TRITANOPIA, ColourVision.PROTANOPIA]:
		_mode(mode)
		var museum := (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
		add_child(museum)
		var box := Pickup.new()
		box.type = Pickup.Type.SHELLS
		museum.add_child(box)
		box.global_position = museum.player.global_position + Vector3(0.0, 0.0, -30.0)
		await physics_frames(2)
		_assert_hud_in(museum.hud, mode, "museum built in mode %d" % mode)
		var rim: Variant = _rim_in(box, "ammo_shells")
		assert_not_null(rim, "the box wears its model")
		if rim != null:
			assert_true(_rgb_close(rim, WeaponPalette.ammo_color(&"shells")), "mode %d: the box's rim" % mode)
		museum.free()
