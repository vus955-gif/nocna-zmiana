extends TestCase
## Stage 3 art in the game: the raptor on its rig (few draw calls, the
## skull's hit zone on the WeakPoint marker, the crouch and the leap, bones
## flying apart), the portrait model (the canvas by id, eyes that follow
## within reach, the paint gob telegraph, the rim only once out of the
## wall, splinters and shreds), the chained Gatling exhibit and the fire
## cabinet on their models, the new ammo pickups, the flare round in
## flight and stuck, the flare gun's break-open reload, and the greybox
## fallbacks. Headless.

## The wall is the plane z = 0 facing +Z; portraits hang on it facing +Z.
const WALL_FACING := Basis(Vector3.UP, PI)

var target: TargetDummy


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	target = TargetDummy.new()
	target.position = Vector3(0, 0, 30)
	add_child(target)


func after_each() -> void:
	ArtLibrary.models_enabled = true
	Fx.clear()


func _raptor(at: Vector3) -> Raptor:
	var raptor := Raptor.new()
	raptor.position = at
	raptor.target = target
	add_child(raptor)
	return raptor


func _weak_zone(enemy: Enemy) -> Hurtbox:
	for child in enemy.get_children():
		var zone := child as Hurtbox
		if zone != null and zone.weak_point:
			return zone
	return null


## [mesh instances with a mesh, shadow casters] under [param node].
func _draws(node: Node) -> Vector2i:
	var out := Vector2i.ZERO
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		if view.mesh == null or not view.is_visible_in_tree():
			continue
		out.x += view.mesh.get_surface_count()
		if view.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			out.y += 1
	return out


# --- raptor ---------------------------------------------------------------------

func test_raptor_runs_on_its_model_with_few_draw_calls() -> void:
	ArtLibrary.models_enabled = false
	var grey := _raptor(Vector3(-4, 0.05, 0))
	var before := _draws(grey)
	ArtLibrary.models_enabled = true
	var raptor := _raptor(Vector3(4, 0.05, 0))
	await physics_frames(2)
	assert_true(raptor.rig is RaptorRig, "the raptor wears its model")
	var after := _draws(raptor)
	print("  raptor draw calls: greybox %d (%d shadow casters) -> model %d (%d shadow casters)" % [before.x, before.y, after.x, after.y])
	assert_lt(after.x, 19, "a few draw calls per raptor (joints only)")
	assert_lt(after.y, 9, "only the big bones cast shadows")
	assert_lt(after.x, before.x / 3, "far fewer than the greybox")
	for part in ["pelvis", "skull", "jaw", "thigh_l", "shin_r", "foot_l", "tail_1", "tail_5", "WeakPoint"]:
		assert_not_null(raptor.rig.part(part), "part %s" % part)
	for child in raptor.visual.get_children():
		assert_false(child is MeshInstance3D, "no greybox mesh %s next to the model" % child.name)
	var weak := raptor.rig.part("WeakPoint")
	var zone := _weak_zone(raptor)
	assert_lt(zone.global_position.distance_to(weak.global_position), 0.01, "the skull's hit zone sits on the WeakPoint")
	grey.free()


func test_raptor_weak_point_follows_the_skull_through_crouch_and_leap() -> void:
	var raptor := _raptor(Vector3(0, 0.05, -3.8))
	target.position = Vector3(0, 0, 0)
	await physics_frames(2)
	raptor.brain.wake()
	var zone := _weak_zone(raptor)
	var weak := raptor.rig.part("WeakPoint")
	var rest_hips := raptor.rig.part("pelvis").position.y
	var crouched := false
	var leapt := false
	var worst := 0.0
	for i in 90:
		await get_tree().physics_frame
		worst = maxf(worst, zone.global_position.distance_to(weak.global_position))
		if raptor.crouch() > 0.7 and raptor.rig.part("pelvis").position.y < rest_hips - 0.05:
			crouched = true
		if raptor.brain.has_struck() and not raptor.is_on_floor() and (raptor.rig.part("thigh_l") as Node3D).rotation.x > 0.4:
			leapt = true
	assert_true(crouched, "it crouches low in the telegraph")
	assert_true(leapt, "legs forward in the leap")
	assert_lt(worst, 0.05, "the weak point never leaves the skull: %.3f" % worst)
	assert_eq(target.hits.size(), 1, "and it still bites")


func test_raptor_eyes_glow_once_awake() -> void:
	var raptor := _raptor(Vector3(0, 0.05, -12))
	await physics_frames(2)
	var rig := raptor.rig as RaptorRig
	assert_almost_eq(rig.eye_glow(), 0.0, 0.001, "asleep: dark sockets")
	raptor.brain.wake()
	await physics_frames(10)
	assert_gt(rig.eye_glow(), 1.0, "awake: embers in the sockets")


func test_raptor_breaks_into_its_bones() -> void:
	var raptor := _raptor(Vector3(0, 0.05, -5))
	await physics_frames(2)
	var parts := raptor.rig.meshes.size()
	var before := Fx.chunk_count()
	raptor.take_damage(DamageInfo.make(30.0, DamageInfo.Kind.BALLISTIC, target))
	await physics_frames(1)
	assert_gt(Fx.chunk_count() - before, parts - 1, "every bone flies as a piece of the model")


# --- portraits ------------------------------------------------------------------

func _portrait(id: StringName = &"countess") -> Portrait:
	var portrait := Portrait.create_on_wall(Transform3D(WALL_FACING, Vector3(0, 2.2, 0)), id)
	portrait.target = target
	add_child(portrait)
	return portrait


func _canvas_name(node: Node) -> String:
	var canvas := node.find_child("canvas", true, false) as MeshInstance3D
	return canvas.get_active_material(0).resource_name if canvas != null else ""


func test_portrait_wears_the_painting_its_id_names() -> void:
	var portrait := _portrait(&"bishop")
	var plain := WallPainting.create(Transform3D(WALL_FACING, Vector3(3, 2.2, 0)), &"bishop")
	add_child(plain)
	var scene := WallPainting.create(Transform3D(WALL_FACING, Vector3(-3, 2.2, 0)), &"seascape")
	add_child(scene)
	await physics_frames(2)
	assert_true(portrait.rig is PortraitRig, "the portrait wears the model")
	assert_eq(_canvas_name(portrait), PaintingArt.canvas_for(&"bishop"))
	assert_eq(_canvas_name(plain), _canvas_name(portrait), "a plain painting of the same id is the same picture")
	assert_true(plain.find_child("eyes", true, false).visible, "a plain portrait has its eyes")
	assert_eq(_canvas_name(scene), "canvas_seascape")
	assert_false(scene.find_child("eyes", true, false).visible, "a seascape has no eyes")
	for id in PaintingArt.ids():
		assert_true(PaintingArt.has_face(id), "%s is a face (it can come alive)" % id)
	assert_false((portrait.visual.find_child("lid_l", true, false) as Node3D).visible, "eyes open")
	assert_lt(portrait.rig.shading().x, 0.01, "no rim asleep")


func test_portrait_eyes_follow_smoothly_within_reach() -> void:
	var portrait := _portrait()
	await physics_frames(2)
	var rig := portrait.rig as PortraitRig
	var eyes := rig.eye_material()
	assert_not_null(eyes, "its own eye material")
	target.position = Vector3(6, 0, 5)   # far to its left-hand side, the viewer's right
	# (its sight checks run every 0.2 s from a random start)
	for i in 60:
		await get_tree().physics_frame
		if portrait.eyes_tracking():
			break
	assert_true(portrait.eyes_tracking(), "it saw him")
	await physics_frames(1)
	var early := eyes.uv1_offset.x
	await physics_frames(40)
	var settled := eyes.uv1_offset.x
	assert_lt(settled, -0.05, "irises toward the viewer's right (the guard)")
	assert_gt(absf(settled), absf(early), "they slide over, not jump")
	assert_gt(settled, -ArtLibrary.PORTRAIT_EYES_REACH.x * PortraitRig.LOOK_LIMIT.x - 0.001, "within reach")
	assert_gt(portrait.pupil_shift().x, 0.003, "world +X")
	assert_eq(ArtLibrary.material(ArtLibrary.PORTRAIT_EYES_MATERIAL).get("uv1_offset"), Vector3.ZERO, "other paintings keep looking ahead")


func test_portrait_rim_only_once_out_and_a_gob_of_paint_as_the_telegraph() -> void:
	var portrait := _portrait()
	await physics_frames(2)
	target.position = Vector3(0, 0, 6)
	var rig := portrait.rig as PortraitRig
	var gob := rig.find_child("PaintGob", true, false) as MeshInstance3D
	var watched_dark := true
	var gob_seen := 0.0
	for i in 300:
		await get_tree().physics_frame
		if portrait.brain.state == EnemyBrain.State.SUSPICIOUS and rig.shading().x > 0.01:
			watched_dark = false
		if gob.visible:
			gob_seen = maxf(gob_seen, gob.scale.x)
	assert_true(watched_dark, "no rim while it only watches (the eyes' secret)")
	assert_gt(rig.shading().x, 0.5, "the rim once out of the wall")
	assert_gt(gob_seen, 0.4, "a gob of paint wells up before it spits")


func test_portrait_tears_into_splinters_and_shreds() -> void:
	var portrait := _portrait()
	await physics_frames(2)
	portrait._push_out()
	await physics_frames(30)
	var before := Fx.chunk_count()
	var info := DamageInfo.make(60.0, DamageInfo.Kind.BALLISTIC, target)
	info.direction = Vector3(0, 0, -1)
	portrait.take_damage(info)
	await physics_frames(1)
	var pieces := Fx.chunk_count() - before
	assert_gt(pieces, PortraitRig.FRAME_SPLINTERS + 8 - 1, "frame splinters and canvas shreds: %d" % pieces)


func test_panel_shards_keep_the_picture() -> void:
	var pic := ArtLibrary.model("portrait")
	var canvas := (pic.find_child("canvas", true, false) as MeshInstance3D).mesh
	var pieces := PanelShards.cut(canvas, 3, 3)
	assert_eq(pieces.size(), 9)
	var area := 0.0
	var lowest := Vector2.ONE
	var highest := Vector2.ZERO
	for shard: MeshShards.Piece in pieces:
		var arrays := shard.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for t in index.size() / 3:
			area += (verts[index[t * 3 + 1]] - verts[index[t * 3]]).cross(verts[index[t * 3 + 2]] - verts[index[t * 3]]).length() * 0.5
		for uv in uvs:
			lowest = Vector2(minf(lowest.x, uv.x), minf(lowest.y, uv.y))
			highest = Vector2(maxf(highest.x, uv.x), maxf(highest.y, uv.y))
	var size := canvas.get_aabb().size
	assert_almost_eq(area, size.x * size.y, 0.001, "the shreds cover the canvas")
	assert_lt(lowest.length(), 0.001, "the picture's corner")
	assert_lt((highest - Vector2.ONE).length(), 0.001, "the opposite corner")
	pic.free()


# --- props and pickups ------------------------------------------------------------

func test_chained_display_on_its_model() -> void:
	var display := ChainedDisplay.create(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -3)))
	display.persistent = false
	add_child(display)
	await physics_frames(1)
	var chain := display.find_child("chain", true, false) as Node3D
	var gun := display.find_child("gun", true, false) as Node3D
	assert_true(chain != null and chain.is_visible_in_tree(), "chained")
	assert_true(gun != null and gun.is_visible_in_tree(), "the gun on its tripod")
	_assert_missing(display.find_child("Chain", true, false), "no greybox chain")
	var before := Fx.chunk_count()
	display.break_chain()
	assert_false(chain.is_visible_in_tree(), "the chain came off")
	assert_gt(Fx.chunk_count() - before, ChainedDisplay.CHAIN_PIECES - 1, "falling in pieces of itself")
	display._set_state(ChainedDisplay.State.EMPTY)
	assert_false(gun.is_visible_in_tree(), "taken")
	assert_true(display.find_child("gatling_display", true, false).is_visible_in_tree(), "the tripod stays")


func test_fire_cabinet_on_its_model() -> void:
	var cabinet := EmergencyCabinet.create(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.4, -3)))
	cabinet.persistent = false
	add_child(cabinet)
	await physics_frames(1)
	var glass := cabinet.find_child("glass", true, false) as Node3D
	var gun := cabinet.find_child("flare_gun", true, false) as Node3D
	assert_true(glass.is_visible_in_tree() and gun.is_visible_in_tree())
	var box := AABB()
	var first := true
	for child in cabinet.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var bounds := mesh.global_transform * mesh.get_aabb()
		box = bounds if first else box.merge(bounds)
		first = false
	# (turned half round: its room side, local -Z, is world +Z here)
	assert_almost_eq(box.get_center().y, 1.4, 0.05, "centred on its origin")
	assert_gt(box.end.z, -2.9, "sticks out toward the room")
	assert_gt(box.position.z, -3.01, "nothing behind the wall")
	var before := Fx.chunk_count()
	cabinet.smash()
	assert_false(glass.is_visible_in_tree(), "smashed")
	assert_gt(Fx.chunk_count() - before, EmergencyCabinet.MODEL_SHARDS.x * EmergencyCabinet.MODEL_SHARDS.y - 1, "the pane in shards")
	cabinet._set_state(EmergencyCabinet.State.EMPTY)
	assert_false(gun.is_visible_in_tree(), "taken")


func test_new_ammo_pickups_wear_their_models() -> void:
	for type in [Pickup.Type.RIFLE, Pickup.Type.FLARES]:
		var pickup := Pickup.new()
		pickup.type = type
		add_child(pickup)
		var model_name: String = Pickup.MODELS[type]
		var mesh := pickup.find_child(model_name, true, false) as MeshInstance3D
		assert_not_null(mesh, "pickup %s model" % model_name)
		if mesh != null:
			var mat := mesh.get_surface_override_material(0) as ShaderMaterial
			assert_eq(mat.get_shader_parameter(&"rim_color"), ArtLibrary.PICKUP_RIM_COLOR, "%s warm rim in the dark" % model_name)
		pickup.queue_free()


# --- flares ---------------------------------------------------------------------

func test_flare_round_in_flight_and_stuck() -> void:
	var data := load("res://src/weapons/data/flare.tres") as WeaponData
	var flare := Flare.launch(Vector3(0, 1.5, 0), Vector3(0, 0, -28), data, null)
	add_child(flare)
	await physics_frames(1)
	var shell := flare.find_child("Round", true, false) as Node3D
	assert_not_null(shell, "the flare_round model flies")
	var tip := shell.find_child("Light", true, false) as Node3D
	var light: OmniLight3D = null
	for child in flare.get_children():
		if child is OmniLight3D:
			light = child
	assert_lt(light.global_position.distance_to(tip.global_position), 0.01, "its light burns at the tip")
	flare.queue_free()
	var stuck := FlareLight.stick(self, Vector3(0, 0, -4), Vector3.UP, null, data, null)
	await physics_frames(1)
	var round_node := stuck.find_child("Round", true, false) as Node3D
	assert_not_null(round_node, "the stuck flare is the model too")
	var marker := round_node.find_child("Light", true, false) as Node3D
	assert_gt(marker.global_position.y, 0.04, "tip out of the floor")
	assert_gt(stuck.light.global_position.y, marker.global_position.y, "the light over the tip")
	stuck.queue_free()


func test_flare_gun_breaks_open_for_the_reload() -> void:
	var user := Node3D.new()
	add_child(user)
	var holder := WeaponHolder.new()
	holder.user = user
	holder.position = Vector3(0, 1.5, 0)
	user.add_child(holder)
	holder.give(load("res://src/weapons/data/flare.tres"))
	var view := holder.get_node(^"flare") as ViewmodelRig
	assert_not_null(view, "the flare gun is its model on a rig")
	if view == null:
		return
	var barrel := view.part_node(&"barrel")
	holder.try_fire()
	for i in 30:
		await get_tree().process_frame
	assert_lt(barrel.rotation.x, -0.3, "broken open, muzzle down")
	for i in 90:
		await get_tree().process_frame
	assert_gt(barrel.rotation.x, -0.05, "closed again")


# --- greybox fallbacks --------------------------------------------------------------

func test_greybox_when_the_stage3_models_are_off() -> void:
	ArtLibrary.models_enabled = false
	var raptor := _raptor(Vector3(0, 0.05, -6))
	var portrait := _portrait()
	var display := ChainedDisplay.create(Transform3D(Basis.IDENTITY, Vector3(6, 0, -6)))
	display.persistent = false
	add_child(display)
	var cabinet := EmergencyCabinet.create(Transform3D(Basis.IDENTITY, Vector3(-6, 1.4, -6)))
	cabinet.persistent = false
	add_child(cabinet)
	var stuck := FlareLight.stick(self, Vector3(0, 0, -2), Vector3.UP, null, load("res://src/weapons/data/flare.tres"), null)
	await physics_frames(2)
	assert_eq(raptor.rig, null, "greybox raptor")
	assert_not_null(raptor.visual.find_child("pelvis", true, false))
	assert_eq(portrait.rig, null, "greybox portrait")
	assert_not_null(portrait.visual.find_child("pupil_l", true, false))
	assert_not_null(display.find_child("Chain", true, false), "greybox chain")
	assert_true(display.find_child("hand_r", true, false) == null, "no hands on the exhibit")
	assert_not_null(cabinet.find_child("FlareGun", true, false), "greybox cabinet")
	_assert_missing(stuck.find_child("Round", true, false), "greybox flare stick")
	stuck.queue_free()


func _assert_missing(value: Variant, message: String) -> void:
	assert_true(value == null, message)
