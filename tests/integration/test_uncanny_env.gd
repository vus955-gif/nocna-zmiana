extends TestCase
## The night's uncanny turns tell the reactive environment (plan
## docs/superpowers/plans/2026-10-21-srodowisko-walka.md and
## 2026-10-21-eskalacja-nocy, 9): a painting swapped for another hands its
## prop to the fresh one, a hidden piece cannot be shot, a turned bust rests
## in its new pose - on a plain test hall and on the real Floor I.

const SEED := 7

var bed: EnvTestbed
var museum: Museum


func after_each() -> void:
	if is_instance_valid(bed):
		bed.free()
	if is_instance_valid(museum):
		museum.free()


func _bed() -> void:
	bed = EnvTestbed.new()
	add_child(bed)
	bed.setup()


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _of(type: Variant) -> Array[EnvProp]:
	var out: Array[EnvProp] = []
	for each in bed.env.props:
		if is_instance_of(each, type):
			out.append(each)
	return out


func test_a_painting_swapped_by_the_uncanny_keeps_its_prop() -> void:
	_bed()
	var old := bed.painting(Vector3(0.0, 2.2, -14.95))
	bed.install_env()
	var prop := _of(EnvPainting)[0] as EnvPainting
	var fresh := UncannyEffects.swap_painting(old, UncannyEffects.empty_picture(&"spot"))
	assert_ne(fresh, old)
	assert_eq(prop.target, fresh, "the prop follows the fresh painting")
	await physics_frames(2)
	assert_true(is_instance_valid(prop.target) and prop.target == fresh, "and the old one's going changes nothing")
	prop.take_damage(bed.hit(85.0, &"rifle_hunt", fresh.global_position, Vector3.FORWARD))
	await _seconds(1.0)
	assert_true(prop.is_down, "the new picture falls from the wall as the old one would")
	assert_eq(fresh.collision_layer, 0, "with its collision")


func test_a_piece_hidden_by_the_uncanny_cannot_be_shot() -> void:
	_bed()
	bed.piece(&"pedestal", Vector3(0.0, 0.0, -6.0), Vector3(1.2, 0.8, 1.2))
	var statue := bed.piece(&"sculpture", Vector3(0.0, 0.8, -6.0), Vector3(0.9, 2.0, 0.9))
	bed.install_env()
	var prop := _of(EnvStatue)[0] as EnvStatue
	assert_false(prop.absent)
	UncannyEffects.hide_piece(statue)
	await physics_frames(2)
	assert_true(prop.absent, "its hit zones went with it")
	assert_eq(prop.hurtbox.collision_layer, 0, "nothing to shoot where it stood")
	prop.take_damage(bed.hit(85.0, &"rifle_hunt", Vector3(0.0, 1.8, -5.6), Vector3.FORWARD))
	assert_eq(prop.phase, EnvProp.Phase.IDLE, "a hidden statue does not teeter")


func test_a_bust_turned_by_the_uncanny_rests_in_its_new_pose() -> void:
	_bed()
	var plinth := bed.piece(&"bust_plinth", Vector3(0.0, 0.0, -6.0), Vector3(0.7, 1.9, 0.7))
	bed.install_env()
	var bust := _of(EnvBust)[0] as EnvBust
	UncannyEffects.turn_piece(plinth, PI * 0.5)
	var turned: Array[Transform3D] = []
	for part in bust.parts:
		turned.append(part.global_transform)
	bust.take_damage(bed.hit(20.0, &"pistol", Vector3(0.0, 1.6, -5.75), Vector3.FORWARD))
	await _seconds(1.0)
	assert_false(bust.is_down)
	for i in bust.parts.size():
		assert_true(bust.parts[i].global_transform.is_equal_approx(turned[i]), "it rocks and comes to rest turned, not back where it stood")


# --- the real Floor I ----------------------------------------------------------------

func _floor() -> void:
	Museum.level_id = &"floor1"
	GameState.new_game()
	GameState.seed_base = SEED
	GameState.night = 2
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	await physics_frames(2)


func test_the_floors_hidden_statue_and_swapped_portrait_tell_the_environment() -> void:
	await _floor()
	var director := museum.floor_game.uncanny
	var env := museum.floor_game.env
	assert_not_null(env, "Floor I has its environment")
	var layout := museum.floor_level.layout
	# a statue the environment answers for goes missing
	var statue: Node3D = null
	for index in UncannyRules.fair_pieces(layout, director.catalog.event(&"gone_statue")):
		var piece := UncannyEffects.find_piece(museum.floor_level, layout.pieces[index])
		if piece != null and env.claims(piece):
			statue = piece
			assert_true(director.apply_change(&"gone_statue", "%d:2" % index))
			break
	assert_not_null(statue, "some fair statue is a prop of the environment")
	if statue != null:
		for prop in env.props_of(statue):
			assert_true(prop.absent, "%s: hidden with the statue" % prop.id)
	# a portrait hung in a frame the environment answers for walks out of it
	var swapped := false
	for spot in UncannyRules.painting_spots(layout, [] as Array[StringName]):
		var painting := UncannyEffects.painting_at(museum.paintings_root, (layout.markers[spot] as Transform3D).origin)
		if painting == null or not env.claims(painting):
			continue
		var props := env.props_of(painting)
		assert_true(director.apply_change(&"sitter_gone", String(spot)))
		var fresh := UncannyEffects.painting_at(museum.paintings_root, (layout.markers[spot] as Transform3D).origin)
		assert_ne(fresh, painting)
		for prop in props:
			assert_eq(prop.target, fresh, "%s: follows the new picture" % prop.id)
		swapped = true
		break
	assert_true(swapped, "some painting spot is a prop of the environment")
