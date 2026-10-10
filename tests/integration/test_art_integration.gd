extends TestCase
## Stage 2 art in the game: the exhibits wear their animated models
## (weak points ride on the head, the telegraph glows per instance, deaths
## throw the model's parts), the T-Rex runs on its model, the first-person
## weapons animate their parts and keep valid muzzles, pickups and props
## show their models, and everything falls back to the greybox when a model
## is off. All headless: the models must load without a window.

const EXHIBITS := [&"wax", &"wolf", &"knight", &"bust"]

var target: TargetDummy


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	target = TargetDummy.new()
	target.position = Vector3(0, 0, -30)
	add_child(target)


func after_each() -> void:
	ArtLibrary.models_enabled = true
	Fx.clear()


func _make(kind: StringName) -> Enemy:
	if kind == &"bust":
		return Bust.new()
	return NightSpawner.make(kind)


func _spawn(kind: StringName, at: Vector3 = Vector3.ZERO) -> Enemy:
	var enemy := _make(kind)
	enemy.target = target
	enemy.position = at
	add_child(enemy)
	return enemy


func _weak_zone(enemy: Enemy) -> Hurtbox:
	for child in enemy.get_children():
		var zone := child as Hurtbox
		if zone != null and zone.weak_point:
			return zone
	return null


## World centre of the mesh of [param part] (its box).
func _centre(enemy: Enemy, part: String) -> Vector3:
	var view := enemy.rig.part(part) as MeshInstance3D
	return view.global_transform * view.get_aabb().get_center()


func test_every_registered_model_loads_headless() -> void:
	for id in ArtLibrary.REGISTRY:
		assert_true(ArtLibrary.has_model(id), "%s is available" % id)
	for id in [&"wax_figure", &"wolf", &"knight", &"bust_enemy", &"trex"]:
		var model := ArtLibrary.exhibit(id)
		assert_not_null(model, "%s dressed as an exhibit" % id)
		if model == null:
			continue
		for child in model.find_children("*", "MeshInstance3D", true, false):
			var mat := (child as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial
			assert_true(mat != null and mat.shader != null, "%s/%s uses the exhibit shader" % [id, child.name])
		model.free()


func test_exhibits_wear_their_animated_models() -> void:
	var parts := {&"wax": ["torso", "head", "hat", "arm_l", "arm_r", "leg_l", "leg_r"],
		&"wolf": ArtLibrary.REGISTRY[&"wolf"], &"knight": ArtLibrary.REGISTRY[&"knight"],
		&"bust": ArtLibrary.REGISTRY[&"bust_enemy"]}
	for kind in EXHIBITS:
		var enemy := _spawn(kind)
		assert_not_null(enemy.rig, "%s has a rig" % kind)
		if enemy.rig == null:
			continue
		for part in parts[kind]:
			assert_not_null(enemy.rig.part(part), "%s part %s" % [kind, part])
		# no greybox meshes next to the model
		for child in enemy.visual.get_children():
			assert_false(child is MeshInstance3D, "%s: no greybox mesh %s" % [kind, child.name])
		enemy.queue_free()


func test_greybox_when_models_are_off() -> void:
	ArtLibrary.models_enabled = false
	for kind in EXHIBITS:
		var enemy := _spawn(kind)
		assert_eq(enemy.rig, null, "%s falls back" % kind)
		var meshes := 0
		for child in enemy.visual.get_children():
			if child is MeshInstance3D:
				meshes += 1
		assert_gt(meshes, 2, "%s greybox meshes" % kind)
		enemy.queue_free()
	var rex := TRex.new()
	add_child(rex)
	assert_eq(rex.skeleton.model_rig, null, "greybox T-Rex")
	assert_gt(rex.skeleton.tail.size(), 10, "greybox tail")
	rex.queue_free()
	var holder := _holder()
	holder.give(load("res://src/weapons/data/pistol.tres"))
	var view := holder.get_child(holder.get_child_count() - 1)
	assert_false(view is ViewmodelRig, "greybox viewmodel")
	assert_not_null(view.get_node_or_null(^"Muzzle"), "greybox muzzle")
	holder.queue_free()


## The weak point stays on the head through a real fight: waking, the
## walk, the windup lean, the strike, and for the wolf the pounce.
func test_weak_point_follows_the_head_while_it_fights() -> void:
	var heads := {&"wax": "head", &"wolf": "head", &"knight": "head", &"bust": "bust"}
	var ranges := {&"wax": 1.2, &"wolf": 4.5, &"knight": 1.6, &"bust": 9.0}
	for kind in EXHIBITS:
		var enemy := _spawn(kind, Vector3(0, 0.05, 0))
		var zone := _weak_zone(enemy)
		assert_not_null(zone, "%s weak point" % kind)
		if zone == null or enemy.rig == null:
			continue
		var dummy := TargetDummy.new()
		dummy.position = Vector3(0, 0, -ranges[kind])
		add_child(dummy)
		enemy.target = dummy
		await physics_frames(2)
		var offset := zone.global_position - _centre(enemy, heads[kind])
		var worst := 0.0
		var saw_windup := false
		enemy.brain.wake()
		for i in 150:
			await get_tree().physics_frame
			saw_windup = saw_windup or enemy.brain.windup_progress() > 0.5
			var now := zone.global_position - _centre(enemy, heads[kind])
			worst = maxf(worst, now.distance_to(offset))
		assert_true(saw_windup, "%s attacked" % kind)
		assert_lt(worst, 0.12, "%s: the weak point kept to the head (worst drift %.3f m)" % [kind, worst])
		enemy.queue_free()
		dummy.queue_free()


func test_melting_still_sags_the_model_and_its_head_zone() -> void:
	var wax := _spawn(&"wax")
	await physics_frames(2)
	var zone := _weak_zone(wax)
	var head_before := _centre(wax, "head").y
	var info := DamageInfo.make(45.0, DamageInfo.Kind.BALLISTIC, target)
	wax.take_damage(info)
	await physics_frames(3)
	assert_lt(_centre(wax, "head").y, head_before - 0.1, "the model's head sagged")
	assert_almost_eq(zone.global_position.y, wax.rig.tracked_position(zone).y + wax.global_position.y, 0.001)
	assert_lt(absf(zone.global_position.y - _centre(wax, "head").y), 0.15, "zone on the sagged head")


func test_telegraph_glows_only_on_the_exhibit_winding_up() -> void:
	var near := _spawn(&"knight", Vector3(0, 0.05, 0))
	var far := _spawn(&"knight", Vector3(0, 0.05, 28))   # beyond sight and wake range
	var dummy := TargetDummy.new()
	dummy.position = Vector3(0, 0, -1.6)
	add_child(dummy)
	near.target = dummy
	far.target = dummy
	await physics_frames(2)
	near.brain.wake()
	var glowed := 0.0
	for i in 120:
		await get_tree().physics_frame
		glowed = maxf(glowed, near.rig.shading().y)
		assert_almost_eq(far.rig.shading().y, 0.0, 0.0001, "the other knight stays dark")
	assert_gt(glowed, 0.5, "the attacker glowed")
	assert_gt(near.rig.shading().x, 0.9, "awake: the rim is up")
	assert_almost_eq(far.rig.shading().x, 0.0, 0.0001, "asleep: no rim")


func test_a_hit_flashes_the_model() -> void:
	var wolf := _spawn(&"wolf")
	await physics_frames(2)
	wolf.take_damage(DamageInfo.make(5.0, DamageInfo.Kind.BALLISTIC, target))
	await physics_frames(1)
	assert_gt(wolf.rig.shading().z, 0.5, "flash")
	await physics_frames(15)
	assert_almost_eq(wolf.rig.shading().z, 0.0, 0.0001, "and it fades")


func _pieces() -> Array[RigidBody3D]:
	var out: Array[RigidBody3D] = []
	for child in Fx.get_children():
		var body := child as RigidBody3D
		if body != null and body.find_children("*", "MeshInstance3D", false, false).size() > 0:
			var view := body.find_children("*", "MeshInstance3D", false, false)[0] as MeshInstance3D
			if view.mesh is ArrayMesh:
				out.append(body)
	return out


func test_a_kill_throws_the_model_parts_and_overkill_tears_them() -> void:
	Fx.clear()
	await physics_frames(1)
	var wolf := _spawn(&"wolf")
	await physics_frames(2)
	var parts := wolf.rig.meshes.size()
	var info := DamageInfo.make(wolf.health.current, DamageInfo.Kind.BALLISTIC, target)
	info.direction = Vector3(0, 0, -1)
	wolf.take_damage(info)
	var whole := _pieces().size()
	assert_eq(whole, parts, "one piece per model part")
	Fx.clear()
	await physics_frames(1)
	var wax := _spawn(&"wax")
	await physics_frames(2)
	var wax_parts := wax.rig.meshes.size()
	var overkill := DamageInfo.make(wax.health.current * 4.0, DamageInfo.Kind.BALLISTIC, target)
	overkill.direction = Vector3(0, 0, -1)
	wax.take_damage(overkill)
	var torn := _pieces()
	assert_gt(torn.size(), wax_parts + 4, "torn into more pieces than parts")
	var textured := 0
	for body in torn:
		var view := body.find_children("*", "MeshInstance3D", false, false)[0] as MeshInstance3D
		if view.get_surface_override_material(0) is ShaderMaterial:
			textured += 1
	assert_eq(textured, torn.size(), "pieces keep the model's textures")
	await physics_frames(30)
	var moving := 0
	for body in torn:
		if is_instance_valid(body) and body.linear_velocity.length() > 0.05 or is_instance_valid(body) and body.global_position.y < 1.0:
			moving += 1
	assert_gt(moving, 0, "pieces fly and fall")


func test_hard_hits_knock_off_the_knights_plates() -> void:
	var knight := _spawn(&"knight")
	await physics_frames(2)
	var rig := knight.rig as KnightRig
	assert_eq(rig.plates_left(), 6)
	Fx.clear()
	await physics_frames(1)
	for i in 3:
		var info := DamageInfo.make(20.0, DamageInfo.Kind.ELECTRIC, target)
		info.direction = Vector3(0, 0, -1)
		info.position = knight.global_position + Vector3(0.2, 1.3, 0)
		knight.take_damage(info)
	assert_eq(rig.plates_left(), 3, "three plates gone")
	assert_eq(_pieces().size(), 3, "flying as debris")


func test_the_trex_runs_on_its_model() -> void:
	var rex := TRex.new()
	rex.target = target
	add_child(rex)
	var model := rex.skeleton.model_rig
	assert_not_null(model, "model rig")
	if model == null:
		return
	assert_eq(rex.skeleton.tail.size(), 8)
	assert_eq(rex.skeleton.neck.size(), 3)
	assert_eq(rex.skeleton.hurtboxes.size(), model.meshes.size(), "a hit zone per bone part")
	assert_eq(rex.skeleton.crystal_pivot.get_parent(), model.part("ribs"), "the crystal sits in the rib cage")
	var socket := model.part("CrystalSocket")
	rex.wake()
	await physics_frames(2)
	assert_lt(rex.skeleton.crystal_position().distance_to(socket.global_position), 0.05, "at the CrystalSocket")
	# the crouch of a stun keeps the feet on the floor (leg IK)
	rex.brain.force(TRexBrain.State.STUNNED)
	await physics_frames(60)
	for leg in rex.skeleton.legs:
		var toes: Node3D = leg[3]
		assert_lt(toes.global_position.y - rex.global_position.y, 0.35, "toes stay down")
	assert_lt(rex.skeleton.crystal_position().y - rex.global_position.y, 2.2, "the crystal sags within reach")


func _holder() -> WeaponHolder:
	var user := Node3D.new()
	add_child(user)
	var holder := WeaponHolder.new()
	holder.user = user
	user.add_child(holder)
	return holder


func test_viewmodels_are_rigs_with_valid_muzzles() -> void:
	var holder := _holder()
	var expected := {&"taser": Vector3(0.0, 0.012, -0.13), &"pistol": Vector3(0.0, 0.012, -0.12), &"shotgun": Vector3(0.0, 0.0, -0.48)}
	for id in [&"taser", &"pistol", &"shotgun"]:
		holder.give(load("res://src/weapons/data/%s.tres" % id))
	await get_tree().process_frame
	for id in expected:
		var view := holder._views[id] as ViewmodelRig
		assert_not_null(view, "%s is a rig" % id)
		if view == null:
			continue
		var muzzle := view.get_node_or_null(^"Muzzle") as Node3D
		assert_not_null(muzzle, "%s muzzle is a direct child" % id)
		var marker := view.model.get_node(^"Muzzle") as Node3D
		assert_lt(muzzle.global_position.distance_to(marker.global_position), 0.001, "%s muzzle on the model's barrel" % id)
		var framing: Array = ViewmodelRig.FRAMING[view.model_id]
		var placed := Transform3D(Basis.from_euler((framing[2] as Vector3) * PI / 180.0).scaled(Vector3.ONE * float(framing[1])),
				framing[0])
		var local := placed * (expected[id] as Vector3)
		assert_lt(muzzle.position.distance_to(local), 0.01, "%s muzzle in front of the gun" % id)
		assert_lt(muzzle.position.z, -0.1, "%s muzzle ahead" % id)
		for child in view.find_children("*", "MeshInstance3D", true, false):
			assert_true((child as MeshInstance3D).layers & ArtLibrary.VIEWMODEL_LAYER != 0, "%s lit by its fill light" % id)
	holder.queue_free()


func test_weapon_parts_move() -> void:
	var holder := _holder()
	for id in [&"taser", &"pistol", &"shotgun"]:
		holder.give(load("res://src/weapons/data/%s.tres" % id))
	# pistol: the slide kicks back
	holder.select_id(&"pistol")
	await get_tree().process_frame
	var pistol := holder._views[&"pistol"] as ViewmodelRig
	var slide := pistol.part_node(&"slide")
	var rest_z := slide.position.z
	holder.try_fire()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(slide.position.z, rest_z + 0.01, "slide back")
	# shotgun: the barrels break open for the reload
	holder.select_id(&"shotgun")
	holder.state_of(&"shotgun").magazine = 0
	holder.try_reload()
	for i in 20:
		await get_tree().process_frame
	var barrels := (holder._views[&"shotgun"] as ViewmodelRig).part_node(&"barrels")
	assert_lt(barrels.rotation.x, -0.3, "barrels broken open")
	# taser: one LED per charge
	holder.select_id(&"taser")
	var taser := holder._views[&"taser"] as ViewmodelRig
	await get_tree().process_frame
	assert_true(taser.part_node(&"led_3").visible, "full battery: third LED on")
	holder.state_of(&"taser").battery = 34.0
	await get_tree().process_frame
	assert_true(taser.part_node(&"led_1").visible, "one charge: first LED on")
	assert_false(taser.part_node(&"led_3").visible, "third LED off")
	holder.queue_free()


func test_punch_shows_one_fist() -> void:
	var holder := _holder()
	var fist := holder._fist_view as ViewmodelRig
	assert_not_null(fist, "fist rig")
	if fist == null:
		return
	assert_eq(fist.model_id, &"vm_fists")
	assert_false(fist.part_node(&"fist_r").visible, "the gun hand stays out")
	assert_true(fist.part_node(&"fist_l").visible)
	holder.queue_free()


func test_pickups_and_props_show_their_models() -> void:
	for type in [Pickup.Type.BULLETS, Pickup.Type.SHELLS, Pickup.Type.MEDKIT]:
		var pickup := Pickup.new()
		pickup.type = type
		add_child(pickup)
		var model_name: String = Pickup.MODELS[type]
		assert_not_null(pickup.find_child(model_name, true, false), "pickup %s model" % model_name)
		pickup.queue_free()
	var mote := DustMote.new()
	add_child(mote)
	assert_eq(mote.find_children("*", "Sprite3D", true, false).size(), 1, "dust mote sprite")
	mote.queue_free()
	var lantern := DroppedLantern.new()
	add_child(lantern)
	assert_not_null(lantern.find_child("lantern", true, false), "lantern model")
	assert_eq(lantern.find_children("*", "OmniLight3D", true, false).size(), 1, "keeps its warm light")
	lantern.queue_free()
	var terminal := UpgradeTerminal.new()
	add_child(terminal)
	assert_not_null(terminal.find_child("terminal", true, false), "terminal model")
	terminal.queue_free()
	var weapon := WeaponPickup.make(&"shotgun", Vector3.ZERO)
	add_child(weapon)
	assert_not_null(weapon.find_child("barrels", true, false), "shotgun model on the floor")
	assert_true(weapon.find_child("hand_r", true, false) == null, "without the guard's hands")
	weapon.queue_free()
	var locker := ArtLibrary.try_instance(&"pistol_locker")
	add_child(locker)
	PropArt.set_locker_open(locker, 1.0)
	assert_lt((locker.find_child("door", true, false) as Node3D).rotation.y, -1.5, "door swings open")
	assert_not_null(PropArt.locker_spot(locker))
	locker.queue_free()
	var bank := ArtLibrary.try_instance(&"cctv_bank")
	var other := ArtLibrary.try_instance(&"cctv_bank")
	add_child(bank)
	add_child(other)
	var screen := PropArt.screen(bank, "cctv_screen_2")
	assert_not_null(screen)
	assert_ne(screen, PropArt.screen(other, "cctv_screen_2"), "each bank's screen is its own")
	bank.queue_free()
	other.queue_free()


func test_mesh_shards_keep_every_triangle() -> void:
	var rex := ArtLibrary.model("trex")
	var ribs := (rex.find_child("ribs", true, false) as MeshInstance3D).mesh
	var total := 0
	for s in ribs.get_surface_count():
		total += (ribs.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	var islands := MeshShards.islands(ribs, 60)
	assert_gt(islands.size(), 10, "the ribs come apart rib by rib")
	var sum := 0
	for piece: MeshShards.Piece in islands:
		sum += piece.triangles
		assert_lt(piece.mesh.get_aabb().get_center().length(), 0.01, "centred")
	assert_eq(sum, total, "no triangle lost")
	var slices := MeshShards.slices(ribs, 4)
	assert_eq(slices.size(), 4)
	rex.free()
