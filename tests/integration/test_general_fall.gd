extends TestCase
## The General's fall in the real garden: his last hit kneels him, he
## plants the nodachi, the armour falls apart from the helmet down into
## pieces that lie there; the shard of Asia drops on the arena's reward
## marker and he is recorded defeated for good (on the next night the
## kneeling armour stands on his post and the shard waits); the tea house
## next door gives no rest until he falls, then it does.

const ROOM := &"asia_garden"
const START := Vector3(8.0, 0.0, -65.5)

var museum: Museum


func before_each() -> void:
	Museum.level_id = &"floor1"


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _museum(fresh: bool = true) -> Museum:
	if fresh:
		GameState.new_game()
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	return museum


func _general() -> General:
	return museum.floor_game.guardians.guardians.get(&"general") as General


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _put_guard(at: Vector3) -> void:
	var guard := museum.player
	guard.global_position = at + Vector3.UP * 0.05
	guard.velocity = Vector3.ZERO


func _front(general: General, ahead: float) -> Vector3:
	return general.home.origin - general.home.basis.z * ahead


func _awake(general: General) -> void:
	_put_guard(START)
	await _seconds(0.3)
	await _seconds(GeneralBrain.WAKE_TIME + 0.15)


## His last hit: in the back, from behind.
func _slay(general: General) -> void:
	var info := DamageInfo.make((general.health.current + 1.0) / General.BACK, DamageInfo.Kind.BALLISTIC, museum.player)
	info.direction = -general.global_basis.z
	info.position = general.rig.part("back").global_position
	general.take_zone_damage(info, &"back")


func test_his_fall_kneels_him_plants_the_sword_and_the_armour_falls_apart_for_good() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	await _awake(general)
	_put_guard(_front(general, 7.0))
	var at := general.global_position
	var fell := watch(Events.guardian_defeated)
	_slay(general)
	await physics_frames(2)
	assert_false(is_instance_valid(general), "the guardian is gone")
	assert_eq(fell.size(), 1)
	assert_true(GameState.is_guardian_defeated(&"general"), "recorded for good")
	var falls := museum.floor_game.guardians.find_children("*", "GeneralFall", false, false)
	assert_eq(falls.size(), 1, "his fall")
	if falls.is_empty():
		return
	var fall := falls[0] as GeneralFall
	await _seconds(GeneralFall.TREMBLE + GeneralFall.KNEEL + 0.1)
	var rig: GeneralRig = fall._rig
	assert_lt(rig.part("pelvis").global_position.y, at.y + 0.9, "on his knee (%.2f)" % rig.part("pelvis").global_position.y)
	assert_lt(rig.tip_point().y, at.y + 0.25, "the nodachi planted (%.2f)" % rig.tip_point().y)
	var model_at := rig.model.global_transform
	for side in 2:
		var hilt := rig.hilt_segment(fall._pose)
		var fist := rig.fist_point(side)
		assert_lt(fist.distance_to(Geometry3D.get_closest_point_to_segment(fist, model_at * hilt[0], model_at * hilt[1])), 0.03, "fist %d on the planted hilt" % side)
	assert_true(fall._pose.eyes < -0.5, "the eyes dead")
	await _seconds(GeneralFall.SHED_GAP * (GeneralFall.SHED_ORDER.size() + 3))
	assert_true(fall.done, "the armour came apart")
	assert_true(fall.pieces.size() >= 20, "pieces of armour lie there (%d)" % fall.pieces.size())
	for body in fall.pieces:
		assert_eq(body.collision_layer, Layers.DEBRIS)
	assert_not_null(rig.part("sword"))
	assert_true((rig.part("sword") as MeshInstance3D).mesh != null, "the sword stays planted")
	await _seconds(1.0)
	assert_true(fall.pieces.size() >= 20 and is_instance_valid(fall.pieces[0]), "they stay for the night")
	# the shard of Asia on the reward marker
	var reward: Vector3 = (museum.floor_level.markers[&"arena_general_reward"] as Transform3D).origin
	var shards: Array = museum.floor_game.guardians.find_children("*", "ProgressPickup", false, false)
	assert_eq(shards.size(), 1, "the shard (no seal for Asia)")
	if not shards.is_empty():
		assert_lt((shards[0] as Node3D).global_position.distance_to(reward), 1.5, "on the reward marker")


func test_the_tea_house_gives_no_rest_until_he_falls() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	museum.player.health.apply_damage(40.0)
	var hurt := museum.player.health.current
	museum._on_haven_entered(museum.player, &"teahouse")
	assert_eq(museum.hud.toast_text(), tr("HUD_NO_REST_GUARDIAN").to_upper(), museum.hud.toast_text())
	assert_almost_eq(museum.player.health.current, hurt, 0.01, "no healing while he stands")
	assert_false(museum.game.havens.has(&"teahouse"), "not a haven yet")
	# another haven rests as ever (not the booth: the night began there)
	museum._on_haven_entered(museum.player, &"conservator")
	assert_almost_eq(museum.player.health.current, museum.player.health.max_health, 0.01, "the conservator's room heals")
	museum.player.health.apply_damage(40.0)
	hurt = museum.player.health.current
	await _awake(general)
	_put_guard(_front(general, 7.0))
	_slay(general)
	await physics_frames(2)
	assert_true(GameState.is_guardian_defeated(&"general"))
	museum._on_haven_entered(museum.player, &"teahouse")
	assert_almost_eq(museum.player.health.current, museum.player.health.max_health, 0.01, "the tea house heals once he fell")
	assert_true(museum.game.havens.has(&"teahouse"), "and saves")


func test_on_the_next_night_the_kneeling_armour_stands_on_his_post_and_the_shard_waits() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	await _awake(general)
	_put_guard(_front(general, 7.0))
	_slay(general)
	await physics_frames(2)
	museum.free()
	_museum(false)
	await physics_frames(2)
	assert_true(_general() == null, "no General tonight")
	var fallen := get_tree().get_nodes_in_group(&"general_fallen")
	assert_eq(fallen.size(), 1, "the kneeling armour")
	if not fallen.is_empty():
		var post: Transform3D = museum.floor_level.markers[&"guardian_general"]
		var node := fallen[0] as Node3D
		assert_lt(node.global_position.distance_to(post.origin), 0.1, "on his post")
		var rig: GeneralRig = node.get_meta(&"rig")
		assert_lt(rig.tip_point().y, 0.25, "the nodachi planted")
		assert_lt(rig.part("pelvis").global_position.y, 0.9, "kneeling")
	assert_eq(get_tree().get_nodes_in_group(&"general_stand").size(), 1, "the empty stand still there")
	var shards: Array = museum.floor_game.guardians.find_children("*", "ProgressPickup", false, false)
	assert_eq(shards.size(), 1, "the shard waits")
	museum._on_haven_entered(museum.player, &"teahouse")
	assert_ne(museum.hud.toast_text(), tr("HUD_NO_REST_GUARDIAN").to_upper(), "the tea house rests")
