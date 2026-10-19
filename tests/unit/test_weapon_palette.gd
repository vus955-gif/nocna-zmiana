extends TestCase
## The pickups' colour and shape language (backlog #11, #43): one colour per
## weapon shared by the HUD slot row, the rim light and the baked accent of
## its ammo pickup; a silhouette class per ammo kind for the colour-blind;
## the slot digit on the box; the medkit white and unlike any ammo; the
## accents kept within limits so a box never blows out like a lamp.

const AMMO_TYPES: Array[Pickup.Type] = [Pickup.Type.BULLETS, Pickup.Type.SHELLS, Pickup.Type.RIFLE, Pickup.Type.FLARES,
	Pickup.Type.HUNT_ROUNDS, Pickup.Type.HARPOONS, Pickup.Type.ROCKETS]
## The texture sets ArtLibrary dresses pickups with.
const PICKUP_SETS: Array[String] = ["ammo_pistol", "ammo_shells", "ammo_rifle", "ammo_flares", "ammo_rifle_hunt",
	"ammo_harpoon", "ammo_hwacha", "medkit"]


func test_every_weapon_has_a_colour_and_every_ammo_feeds_a_weapon() -> void:
	for id in WeaponHolder.SLOT_ORDER:
		assert_true(WeaponPalette.COLORS.has(id), "%s has a colour" % id)
	for ammo: StringName in WeaponPalette.AMMO_WEAPONS:
		assert_true(WeaponPalette.COLORS.has(WeaponPalette.AMMO_WEAPONS[ammo]), "%s feeds a known weapon" % ammo)
	assert_eq(WeaponPalette.AMMO_WEAPONS, Museum.AMMO_WEAPONS, "the same ammo -> weapon map the loot uses")


func test_every_ammo_kind_has_its_own_colour_far_from_the_others() -> void:
	for i in AMMO_TYPES.size():
		for j in range(i + 1, AMMO_TYPES.size()):
			var a := Pickup.color_of(AMMO_TYPES[i])
			var b := Pickup.color_of(AMMO_TYPES[j])
			assert_ne(a, b, "%d vs %d" % [AMMO_TYPES[i], AMMO_TYPES[j]])
			assert_true(WeaponPalette.hue_gap(a, b) >= WeaponPalette.MIN_HUE_GAP,
					"%d vs %d: hues %.0f deg apart" % [AMMO_TYPES[i], AMMO_TYPES[j], WeaponPalette.hue_gap(a, b)])
			assert_gt(a.s, 0.55, "%d saturated (a hue to read)" % AMMO_TYPES[i])


func test_every_ammo_kind_has_its_own_silhouette() -> void:
	var seen := {}
	for type in AMMO_TYPES:
		var shape := Pickup.silhouette_of(type)
		assert_ne(shape, &"", "%d has a silhouette" % type)
		assert_false(seen.has(shape), "%s used twice" % shape)
		seen[shape] = true
	assert_false(seen.has(Pickup.silhouette_of(Pickup.Type.MEDKIT)), "the medkit's shape is no ammo's")


func test_the_pickup_wears_the_colour_of_the_weapon_it_feeds() -> void:
	for type in AMMO_TYPES:
		var ammo: StringName = Pickup.AMMO[type]
		var weapon: StringName = WeaponPalette.AMMO_WEAPONS[ammo]
		assert_eq(Pickup.color_of(type), WeaponPalette.color(weapon), "%s = HUD colour of %s" % [ammo, weapon])
		assert_eq(WeaponPalette.ammo_color(ammo), WeaponPalette.color(weapon))


func test_the_slot_digit_is_the_weapons_slot_in_the_hud_row() -> void:
	assert_eq(WeaponPalette.slot(&"taser"), 1)
	assert_eq(WeaponPalette.slot(&"pistol"), 2)
	assert_eq(WeaponPalette.slot(&"hwacha"), 8)
	assert_eq(WeaponPalette.digit(&"bullets"), "2")
	assert_eq(WeaponPalette.digit(&"shells"), "3")
	assert_eq(WeaponPalette.digit(&"rifle"), "4")
	assert_eq(WeaponPalette.digit(&"flares"), "5")
	assert_eq(WeaponPalette.digit(&"hunt_rounds"), "6")
	assert_eq(WeaponPalette.digit(&"harpoons"), "7")
	assert_eq(WeaponPalette.digit(&"rockets"), "8")
	assert_eq(WeaponPalette.digit(&"medkit"), "", "health carries no slot")


func test_the_medkit_is_white_and_unlike_any_ammo() -> void:
	var white := Pickup.color_of(Pickup.Type.MEDKIT)
	assert_lt(white.s, 0.15, "near white")
	assert_gt(white.v, 0.9)
	for type in AMMO_TYPES:
		var c := Pickup.color_of(type)
		var gap := absf(white.r - c.r) + absf(white.g - c.g) + absf(white.b - c.b)
		assert_gt(gap, 0.5, "%d far from white" % type)


func test_the_rim_of_every_pickup_model_is_its_kinds_colour() -> void:
	for type in Pickup.Type.values():
		var tex_name: String = Pickup.MODELS[type]
		assert_eq(ArtLibrary.pickup_rim_color(tex_name), Pickup.color_of(type), tex_name)
	assert_eq(ArtLibrary.pickup_rim_color("fuse"), ArtLibrary.PICKUP_RIM_COLOR, "the fuse keeps the warm rim")
	assert_eq(ArtLibrary.pickup_rim_color("crystal_loose"), ArtLibrary.PICKUP_RIM_COLOR)


func test_the_accents_stay_within_limits() -> void:
	for tex_name in PICKUP_SETS:
		assert_true(ArtLibrary.PICKUP_RIM.has(tex_name), "%s is a pickup set" % tex_name)
		assert_lt(float(ArtLibrary.PICKUP_RIM[tex_name]), 1.001, "%s rim strength" % tex_name)
		assert_gt(float(ArtLibrary.PICKUP_RIM[tex_name]), 0.5, "%s rim strong enough to read from afar" % tex_name)
		var extras: Dictionary = ArtLibrary.EXTRAS.get(tex_name, {})
		assert_true(extras.has("emission"), "%s sets its emission (the default 2.0 is for lamps)" % tex_name)
		assert_lt(float(extras.get("emission", 2.0)), WeaponPalette.MAX_PICKUP_EMISSION + 0.001, "%s emission" % tex_name)


## The Blender side (tools/art/models/_pickup_palette.py) paints the same
## numbers: the hex colour of every pickup model and its slot digit.
func test_the_blender_palette_matches_the_games() -> void:
	var file := FileAccess.open("res://tools/art/models/_pickup_palette.py", FileAccess.READ)
	assert_not_null(file, "the Blender palette module")
	if file == null:
		return
	var entries := {}
	var pattern := RegEx.create_from_string("\"(ammo_\\w+|medkit)\":\\s*\\(\"(#[0-9a-fA-F]{6})\",\\s*\"(\\d?)\"\\)")
	for found in pattern.search_all(file.get_as_text()):
		entries[found.get_string(1)] = [Color.html(found.get_string(2)), found.get_string(3)]
	for type in Pickup.Type.values():
		var tex_name: String = Pickup.MODELS[type]
		assert_true(entries.has(tex_name), "%s in the Blender palette" % tex_name)
		if not entries.has(tex_name):
			continue
		var expected := Pickup.color_of(type)
		var painted: Color = entries[tex_name][0]
		for channel in 3:
			assert_almost_eq(painted[channel], expected[channel], 1.0 / 255.0 + 0.0001, "%s channel %d" % [tex_name, channel])
		var ammo: StringName = Pickup.AMMO.get(type, &"medkit")
		assert_eq(entries[tex_name][1], WeaponPalette.digit(ammo), "%s digit" % tex_name)
	assert_eq(entries.size(), Pickup.Type.size(), "one entry per pickup kind")


## Every pickup bakes an emission map (the print, the stencil, the bands,
## the digit) whose colour is its kind's: a mean hue within HUE_TOLERANCE
## of the palette for ammo; the medkit's pale, never bright.
const HUE_TOLERANCE := 25.0

func test_every_pickup_bakes_an_emission_map_in_its_colour() -> void:
	for type in Pickup.Type.values():
		var tex_name: String = Pickup.MODELS[type]
		var texture := ArtLibrary.texture(tex_name, "emit")
		assert_not_null(texture, "%s_emit.png" % tex_name)
		if texture == null:
			continue
		var image := texture.get_image()
		if image.is_compressed():
			image.decompress()
		var sum := Color.BLACK
		var lit := 0
		var peak := 0.0
		for y in image.get_height():
			for x in image.get_width():
				var pixel := image.get_pixel(x, y)
				var top := maxf(pixel.r, maxf(pixel.g, pixel.b))
				peak = maxf(peak, top)
				if top > 0.08:
					sum += pixel
					lit += 1
		assert_gt(lit, 50, "%s: some texels glow" % tex_name)
		if lit == 0:
			continue
		var mean := sum / float(lit)
		var expected := Pickup.color_of(type)
		if type == Pickup.Type.MEDKIT:
			assert_lt(mean.s, 0.6, "medkit: pale (the cross on white)")
		else:
			assert_lt(WeaponPalette.hue_gap(mean, expected), HUE_TOLERANCE,
					"%s: mean hue %.0f vs the palette's %.0f" % [tex_name, mean.h * 360.0, expected.h * 360.0])
			assert_gt(mean.s, 0.3, "%s: a hue to read, not grey" % tex_name)
		assert_lt(peak, 0.75, "%s: the brightest texel stays under 0.75 (a mark, not a lamp)" % tex_name)


func test_hue_gap_wraps_round_the_wheel() -> void:
	assert_almost_eq(WeaponPalette.hue_gap(Color(1, 0, 0), Color(1, 0, 0.1)), 6.0, 1.0)
	assert_almost_eq(WeaponPalette.hue_gap(Color(1, 0, 0.1), Color(1, 0, 0)), 6.0, 1.0)
	assert_almost_eq(WeaponPalette.hue_gap(Color(1, 0, 0), Color(0, 1, 0)), 120.0, 1.0)


func test_the_greybox_pickup_wears_the_palette_too() -> void:
	ArtLibrary.models_enabled = false
	var pickup := Pickup.new()
	pickup.type = Pickup.Type.HARPOONS
	add_child(pickup)
	var views := pickup.find_children("*", "MeshInstance3D", true, false)
	assert_gt(views.size(), 0, "greybox parts")
	var tinted := false
	for view in views:
		var mat := (view as MeshInstance3D).material_override as StandardMaterial3D
		if mat != null and mat.albedo_color.is_equal_approx(Pickup.color_of(Pickup.Type.HARPOONS)):
			tinted = true
	assert_true(tinted, "one part in the harpoon's teal")
	pickup.queue_free()
	ArtLibrary.models_enabled = true
