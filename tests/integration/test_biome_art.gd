extends TestCase
## The biome mechanics on the dressed Floor I (plan 2026-10-21-mechaniki-
## biomow): the Americas' fire bowls find their own flames, sparks and
## smoke on the art and a douse puts them all out; the Korea pavilion's
## bell is the dressing's own (a ring sways it hard); the hanging bells wear
## the temple bell's model. Built without navigation.

var level: MuseumFloorLevel
var player: Player
var biomes: BiomeMechanics


func before_each() -> void:
	MuseumFloorLevel.dress_default = true
	level = MuseumFloorLevel.new()
	level.bake_navigation = false
	add_child(level)
	level.build()
	player = Player.new()
	player.position = Vector3(0, 0.05, 20)
	add_child(player)
	biomes = BiomeMechanics.new()
	add_child(biomes)
	biomes.setup(level, func() -> Player: return player)
	await physics_frames(2)


func after_each() -> void:
	MuseumFloorLevel.dress_default = false
	if is_instance_valid(level):
		level.free()


func test_the_devices_wear_the_dressed_floors_own_fire_and_bells() -> void:
	var fires := biomes.of_kind(SacredFire)
	assert_eq(fires.size(), 5)
	for device in fires:
		var fire := device as SacredFire
		assert_not_null(fire.light, "%s: its lamp" % fire.name)
		assert_not_null(fire.flame, "%s: its flame model" % fire.name)
		assert_gt(fire.motes.size(), 0.0, "%s: its sparks and smoke" % fire.name)
		fire.douse()
		if fire.flame != null:
			assert_almost_eq((fire.flame as GeometryInstance3D).transparency, 1.0, 0.001, "%s: the flame goes out" % fire.name)
		for motes in fire.motes:
			assert_almost_eq(motes.amount_ratio, 0.0, 0.001, "%s: no more sparks" % fire.name)
	for device in biomes.of_kind(TempleBell):
		var bell := device as TempleBell
		if bell.pavilion:
			assert_false(bell._sway_entry.is_empty(), "the pavilion's own bell, swaying in the dressing")
			bell.ring()
			assert_almost_eq(float(bell._sway_entry[2]), TempleBell.SWING, 0.001, "a ring sways it hard")
		else:
			var shown := 0
			for node in bell.find_children("*", "MeshInstance3D", true, false):
				var view := node as MeshInstance3D
				if view.mesh != null and view.is_visible_in_tree() and String(view.get_parent().name) == "temple_bell":
					assert_eq(String(view.name), "bell", "%s: only the bell of the pavilion's model" % bell.name)
					shown += 1
			assert_eq(shown, 1, "%s: the temple bell's model, the bell alone" % bell.name)
