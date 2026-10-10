extends TestCase
## Review fixes of the art rigs (1.10): dawn stops the models too, the
## debris cut prepared ahead is the cut a heavy kill uses, exhibits are
## dressed straight with their shader (debris variant made with them),
## hidden first-person rigs do not animate, and the night start's warm-up
## cuts every queued piece and puts its copies in front of the camera for
## a few frames only.

var target: TargetDummy


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	target = TargetDummy.new()
	target.position = Vector3(0, 0, -30)
	add_child(target)


func after_each() -> void:
	Fx.clear()


func _spawn(exhibit: Enemy, at: Vector3 = Vector3.ZERO) -> Enemy:
	exhibit.target = target
	exhibit.position = at
	add_child(exhibit)
	return exhibit


func _poses(rig: ExhibitRig) -> Dictionary:
	var out := {}
	for part_name: String in rig.parts:
		out[part_name] = (rig.parts[part_name] as Node3D).transform
	return out


func test_a_frozen_exhibit_stops_its_model_mid_pose() -> void:
	var wolf := _spawn(NightSpawner.make(&"wolf"))
	await physics_frames(20)
	assert_not_null(wolf.rig, "the wolf runs on its model")
	if wolf.rig == null:
		return
	wolf.brain.wake()
	target.position = Vector3(0, 0, -12)
	await physics_frames(40)
	wolf.freeze()
	var frozen := _poses(wolf.rig)
	await physics_frames(60)
	var moved := 0
	for part_name: String in frozen:
		if not (wolf.rig.parts[part_name] as Node3D).transform.is_equal_approx(frozen[part_name]):
			moved += 1
	assert_eq(moved, 0, "not a part moves after dawn")
	assert_false(wolf.rig.is_physics_processing(), "the rig stops with the exhibit")


func test_the_cut_made_ahead_is_the_cut_a_heavy_kill_uses() -> void:
	var wax := _spawn(WaxFigure.new()) as WaxFigure
	await physics_frames(2)
	assert_not_null(wax.rig)
	if wax.rig == null:
		return
	MeshShards.drain()
	var counts := {}
	for view in wax.rig.meshes:
		counts[view] = wax.rig.slice_count(view)
		assert_true(MeshShards.has_slices(view.mesh, counts[view]), "%s is cut ahead" % view.name)
	# turned, sagging (melted) and posed: the same cuts
	wax.rotation.y = 0.8
	wax.visual.scale = Vector3(1.1, 0.8, 1.1)
	wax.brain.wake()
	await physics_frames(10)
	var torn := 0
	for view in wax.rig.meshes:
		assert_eq(wax.rig.slice_count(view), counts[view], "%s keeps its count" % view.name)
		if counts[view] > 1:
			torn += 1
	assert_gt(torn, 0, "some parts tear into slices")


func test_a_portrait_has_its_splinters_cut_ahead() -> void:
	var portrait := Portrait.create_on_wall(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 2.0, 0)), PaintingArt.ids()[0])
	portrait.target = target
	add_child(portrait)
	await physics_frames(2)
	var rig := portrait.rig as PortraitRig
	if rig == null:
		return   # greybox painting: nothing to cut
	MeshShards.drain()
	var frame := rig.part("frame") as MeshInstance3D
	assert_true(MeshShards.has_slices(frame.mesh, PortraitRig.FRAME_SPLINTERS))
	assert_true(MeshShards.has_slices(frame.mesh, PortraitRig.FRAME_SPLINTERS + PortraitRig.GIBBED_SPLINTERS))


func test_exhibits_wear_their_shader_and_bring_their_debris_variant() -> void:
	var model := ArtLibrary.exhibit(&"raptor")
	assert_not_null(model)
	if model == null:
		return
	add_child(model)
	var before := ArtLibrary.cached_materials().size()
	var surfaces := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var view := node as MeshInstance3D
		for i in view.mesh.get_surface_count():
			var worn := view.get_surface_override_material(i) as ShaderMaterial
			assert_not_null(worn, "%s wears a shader" % view.name)
			if worn == null:
				continue
			surfaces += 1
			assert_true(worn.shader in [ArtLibrary.EXHIBIT_SHADER, ArtLibrary.EXHIBIT_WAX_SHADER])
			var debris := ArtLibrary.debris_material(worn) as ShaderMaterial
			assert_eq(debris.shader, ArtLibrary.EXHIBIT_DEBRIS_SHADER)
	assert_gt(surfaces, 0)
	assert_eq(ArtLibrary.cached_materials().size(), before, "the debris variants were made with the model")


func _holder() -> WeaponHolder:
	var user := Node3D.new()
	add_child(user)
	var holder := WeaponHolder.new()
	holder.user = user
	user.add_child(holder)
	return holder


func test_only_the_weapon_in_hand_animates() -> void:
	var holder := _holder()
	holder.give(load("res://src/weapons/data/pistol.tres"))
	holder.give(load("res://src/weapons/data/shotgun.tres"))
	await get_tree().process_frame
	var pistol := holder.find_child("pistol", false, false) as ViewmodelRig
	var shotgun := holder.find_child("shotgun", false, false) as ViewmodelRig
	if pistol == null or shotgun == null:
		return   # greybox viewmodels
	assert_true(pistol.is_processing(), "in hand")
	assert_false(shotgun.is_processing(), "put away")
	holder.select_id(&"shotgun")
	await get_tree().process_frame
	assert_false(pistol.is_processing())
	assert_true(shotgun.is_processing())


## Every first-person mesh, flash and puff of smoke is on render layer 20
## only (the guard's camera sees it, the CCTV feeds do not).
func test_first_person_views_live_on_their_own_layer_only() -> void:
	var holder := _holder()
	for id in [&"pistol", &"shotgun", &"taser", &"gatling", &"flare"]:
		holder.give(load("res://src/weapons/data/%s.tres" % id))
	await get_tree().process_frame
	var checked := 0
	for node in holder.find_children("*", "GeometryInstance3D", true, false):
		checked += 1
		assert_eq((node as GeometryInstance3D).layers, ArtLibrary.VIEWMODEL_LAYER, "%s on layer 20 only" % node.name)
	assert_gt(checked, 10)


func test_the_warm_up_cuts_every_queued_piece() -> void:
	for i in 3:
		_spawn(WaxFigure.new(), Vector3(i * 2.0, 0, 0))
	_spawn(NightSpawner.make(&"wolf"), Vector3(0, 0, 4))
	await physics_frames(1)
	var camera := Camera3D.new()
	add_child(camera)
	Fx.warm_up(self, camera)
	assert_eq(MeshShards.pending(), 0, "nothing left to cut mid-fight")
	Fx.warm_up(self, camera)   # twice is harmless
	assert_eq(MeshShards.pending(), 0)


func test_the_warm_up_shows_its_copies_for_a_few_frames_then_goes() -> void:
	var wolf := _spawn(NightSpawner.make(&"wolf"))
	await physics_frames(1)
	var camera := Camera3D.new()
	add_child(camera)
	var warm := ShaderWarmUp.start(self, camera)
	assert_gt(warm.item_count(), ArtLibrary.cached_materials().size() - 1, "a copy per material and the effects")
	var again := ShaderWarmUp.start(self, camera)
	assert_false(is_instance_valid(warm) and warm.get_parent() == camera, "a second start replaces the first")
	assert_eq(camera.get_children().filter(func(n: Node) -> bool: return n is ShaderWarmUp).size(), 1)
	for i in ShaderWarmUp.FRAMES + 2:
		await get_tree().process_frame
	assert_false(is_instance_valid(again), "gone after a few frames")
	assert_true(is_instance_valid(wolf), "the scene's own models stay")
