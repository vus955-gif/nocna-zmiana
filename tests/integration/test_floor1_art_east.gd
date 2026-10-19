extends TestCase
## Floor I's Assyrian and Asian wings dressed (stage P4; plan
## docs/superpowers/plans/2026-10-10-p4-oprawa-asyria-azja.md): every room
## wears its kit and has its light recipe; the Khorsabad Gate stands on the
## greybox's lamassu boxes, the Lamassu's cover looks like cover and the
## awakening slabs wait on the courtyard's walls, torches on every sconce,
## thresholds in the doorways, merlons round the courtyard's sky, the fires
## out in a blackout. Built without navigation.

const Assyria := preload("res://src/level/floor1/zones/assyria.gd")
const Asia := preload("res://src/level/floor1/zones/asia.gd")
const WINGS: Array[StringName] = [&"assyria", &"asia"]

## The live exhibits' bodies in the slot's frame (-Z the front): [radius,
## height, centre, lying along Z, name]. A Fu dog: the enemy's own collider
## (FuDog.COLLIDER_*, the capsule lying along its length) and the model's
## reach (the muzzle to the plume); an armour: the enemy's upright capsule (a
## hand over the floor, so the floor itself does not count).
const BODIES := {
	&"fu_dog": [[0.55, 2.4, Vector3(0.0, 0.56, 0.1), true, "body"], [0.68, 3.3, Vector3(0.0, 0.85, -0.22), true, "visual-reach"]],
	&"samurai_armor": [[0.42, 2.0, Vector3(0.0, 1.05, 0.0), false, "body"]],
}
## The physics layer of the stand-in bodies for the props' looks.
const LOOK_LAYER := 1 << 17

var level: MuseumFloorLevel


func before_each() -> void:
	MuseumFloorLevel.dress_default = true
	level = MuseumFloorLevel.new()
	level.bake_navigation = false
	add_child(level)
	level.build()


func after_each() -> void:
	MuseumFloorLevel.dress_default = false


## The rooms of both wings.
func _rooms() -> Array[RoomSpec]:
	var out: Array[RoomSpec] = []
	for room in level.layout.rooms:
		if WINGS.has(room.zone):
			out.append(room)
	return out


## Model id -> nodes of it under [param root].
func _models(root: Node) -> Dictionary:
	var out := {}
	for node in root.find_children("*", "Node3D", true, false):
		var path := String(node.scene_file_path)
		if path.begins_with("res://assets/models/"):
			var id := path.get_file().trim_suffix(".glb")
			if not out.has(id):
				out[id] = []
			(out[id] as Array).append(node)
	return out


func _heroes() -> Node:
	return level.structure.get_node(^"Dressing/Floor1Heroes")


## World bounds of [param node]'s visible meshes.
func _bounds(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		if not view.visible:
			continue
		var box := view.global_transform * view.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


## No piece of [param zone] keeps the greybox look; every model of
## [param models] is registered, on disk and placed.
func _wears_its_kit(zone: StringName, models: Array[String]) -> void:
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if not level.is_ancestor_of(node) or not node.get_meta(&"kit_greybox", false):
			continue
		var spec := level.layout.room(node.get_meta(&"kit_room", &""))
		if spec != null and spec.zone == zone:
			fail("%s in %s still wears the greybox" % [node.get_meta(&"kit"), spec.id])
	var used := _models(level)
	for id in models:
		assert_true(ArtLibrary.KIT.has(StringName(id)) or ArtLibrary.REGISTRY.has(StringName(id)), "%s is registered" % id)
		assert_true(ArtLibrary.has_model(StringName(id)), "%s has its file" % id)
		assert_true(used.has(id), "%s is placed somewhere" % id)


func test_the_assyrian_wing_wears_its_kit() -> void:
	_wears_its_kit(&"assyria", Floor1ArtAssyria.MODELS)


func test_the_khorsabad_gate_stands_on_the_greybox_lamassu() -> void:
	var gates: Array = _models(_heroes()).get("khorsabad_gate", [])
	assert_eq(gates.size(), 1, "one Khorsabad Gate")
	if gates.is_empty():
		return
	var gate: Node3D = gates[0]
	assert_lt(gate.global_position.distance_to(Floor1ArtAssyria.GATE_AT), 0.01, "on the hall's face of the wall to Egypt")
	var parts := ArtLibrary.parts(gate)
	for id in ["door_l", "door_r"]:
		assert_false((parts[id] as Node3D).visible, "%s hidden: Egypt's seal doors close the passage" % id)
	# the greybox lamassu boxes hold the statues (their footprints; the crowns
	# stand a hand over the 4.5 m boxes); their own looks are empty
	var boxes: Array[Rect2] = []
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if level.is_ancestor_of(node) and node.get_meta(&"kit", &"") == &"lamassu":
			var size: Vector3 = node.get_meta(&"kit_size")
			var at := (node as Node3D).global_position
			boxes.append(Rect2(at.x - size.x * 0.5, at.z - size.z * 0.5, size.x, size.z))
			assert_eq((node as Node).get_node(^"Visual").find_children("*", "MeshInstance3D", true, false).size(), 0, "the greybox lamassu draws nothing")
	assert_eq(boxes.size(), 2, "two lamassu boxes")
	for id in ["lamassu_l", "lamassu_r"]:
		var statue := parts[id] as MeshInstance3D
		var box := statue.global_transform * statue.get_aabb()
		var footprint := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
		var inside := boxes.any(func(b: Rect2) -> bool: return b.grow(0.15).encloses(footprint))
		assert_true(inside, "%s stands in a greybox lamassu box (%s)" % [id, box])


func test_the_courtyard_cover_is_solid_and_the_awakening_slabs_wait_on_the_walls() -> void:
	var markers := level.layout.markers
	var views: Array[MeshInstance3D] = []
	for node in level.find_children("*", "MeshInstance3D", true, false):
		var view := node as MeshInstance3D
		if view.is_visible_in_tree() and view.mesh != null:
			views.append(view)
	for i in 6:
		var at: Vector3 = (markers[StringName("lamassu_cover_%d" % (i + 1))] as Transform3D).origin
		var found := false
		for view in views:
			var box := view.global_transform * view.get_aabb()
			if box.position.y <= 1.0 and box.end.y >= 1.0:
				var nearest := Vector2(clampf(at.x, box.position.x, box.end.x), clampf(at.z, box.position.z, box.end.z))
				if nearest.distance_to(Vector2(at.x, at.z)) < 0.2:
					found = true
					break
		assert_true(found, "cover %d at %s looks like cover (a mesh stands over it at 1 m)" % [i + 1, at])
	var slabs: Array = _models(level).get("asy_relief_wake", [])
	assert_eq(slabs.size(), 6, "six awakening slabs")
	for slab: Node3D in slabs:
		var p := slab.global_position
		var near := false
		for i in 6:
			var m: Vector3 = (markers[StringName("lamassu_relief_%d" % (i + 1))] as Transform3D).origin
			if Vector2(p.x - m.x, p.z - m.z).length() < 1.0:
				near = true
		assert_true(near, "the slab at %s stands behind a relief marker" % p)
		var on_wall := absf(p.x + 94.0) < 0.35 or absf(p.x + 63.5) < 0.35 or absf(p.z + 80.0) < 0.35
		assert_true(on_wall, "and flat on a wall (%s)" % p)
	var lions: Array = _models(_heroes()).get("asy_relief_wake_lion", [])
	assert_eq(lions.size(), 2, "two sleeping lions in the pit's walls")
	for lion: Node3D in lions:
		var before := lion.global_position + Vector3.UP * 0.5 + lion.global_basis * Vector3(0.0, 0.0, -0.5)
		assert_eq(level.layout.room_at(before), &"assyria_lions", "the lion faces into the pit")
	# nothing of the dressing stands on the arena's floor away from its walls
	var court := level.layout.room(&"assyria_courtyard").parts[0]
	var inset := court.grow(-0.7)
	for node in _heroes().find_children("*", "MeshInstance3D", true, false):
		var view := node as MeshInstance3D
		if not view.is_visible_in_tree() or view.mesh == null:
			continue
		var box := view.global_transform * view.get_aabb()
		var c := box.get_center()
		if box.position.y > 2.4 or level.layout.room_at(Vector3(c.x, 1.0, c.z)) != &"assyria_courtyard":
			continue
		assert_false(inset.has_point(Vector2(c.x, c.z)), "%s stands on the arena's floor" % view.get_path())


func test_torches_thresholds_and_merlons() -> void:
	var sconces := 0
	for light in level.layout.lights:
		if String(light.room).begins_with("assyria_") and light.fixture == &"sconce":
			sconces += 1
	var torches := 0
	var braziers := 0
	for node in level.lights.get_children():
		if not String(node.get_meta(&"kit_room", &"")).begins_with("assyria_"):
			continue
		var ids := _models(node)
		if node.get_meta(&"kit", &"") == &"sconce" and ids.has("asy_torch"):
			torches += 1
		if node.get_meta(&"kit", &"") == &"brazier" and ids.has("asy_brazier"):
			braziers += 1
	assert_eq(torches, sconces + 2, "a torch on every sconce and two on the gate's towers")
	assert_eq(braziers, 4, "four fire tripods")
	var thresholds: Array = _models(_heroes()).get("asy_threshold_4m", [])
	var doorways := 0
	for passage in level.layout.openings:
		if String(passage.room_a).begins_with("assyria_") and String(passage.room_b).begins_with("assyria_") and level.layout.gate_of_opening(passage.id) == null:
			doorways += 1
	assert_eq(thresholds.size(), doorways, "a carved threshold in every doorway of the wing")
	assert_gt(doorways, 5)
	for threshold: Node3D in thresholds:
		var lift := threshold.global_position.y - Floor1ArtAssyria.THRESHOLD_LIFT
		assert_true(absf(lift) < 0.01 or absf(lift + 3.0) < 0.01, "flat on a floor of the wing (%.2f)" % threshold.global_position.y)
	var sky := 0
	var rails := 0
	for merlon: Node3D in _models(level).get("asy_parapet_2m", []):
		if absf(merlon.global_position.y - 16.0) < 0.05:
			sky += 1
		elif level.layout.room_at(merlon.global_position + Vector3.UP * 0.3) == &"assyria_lions_gallery":
			rails += 1
	assert_gt(sky, 20, "merlons round the courtyard's sky")
	assert_gt(rails, 8, "merlons for the gallery's rails")


## World positions of every vertex of [param node]'s meshes.
func _world_vertices(node: Node) -> PackedVector3Array:
	var out := PackedVector3Array()
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		if view.mesh == null:
			continue
		var xf := view.global_transform
		for s in view.mesh.get_surface_count():
			for v in (view.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				out.append(xf * v)
	return out


func test_the_asian_wing_wears_its_kit() -> void:
	_wears_its_kit(&"asia", Floor1ArtAsia.MODELS)


func test_the_buddha_the_hwacha_and_the_bell_sit_on_their_greybox() -> void:
	var used := _models(level)
	var buddhas: Array = used.get("buddha_seated", [])
	assert_eq(buddhas.size(), 1, "one great Buddha")
	if not buddhas.is_empty():
		var box := _bounds(buddhas[0])
		assert_true(box.end.y <= 12.0, "under the hall's ceiling (%.2f)" % box.end.y)
		var sculpture := Rect2(Asia.BUDDHA.x - 2.5, -57.5 - 2.0, 5.0, 4.0).grow(0.3)
		assert_true(sculpture.encloses(Rect2(box.position.x, box.position.z, box.size.x, box.size.z)), "in the greybox sculpture's footprint (%s)" % box)
		assert_eq(level.layout.room_at(Vector3(box.get_center().x, 1.0, box.end.z + 0.5)), &"asia_china", "facing the hall")
	var displays: Array = used.get("hwacha_display", [])
	assert_eq(displays.size(), 1, "one hwacha display")
	if not displays.is_empty():
		var spot := ArtLibrary.parts(displays[0]).get("weapon_spot") as Node3D
		var marker: Transform3D = level.layout.markers[&"weapon_hwacha"]
		assert_lt(Vector2(spot.global_position.x - marker.origin.x, spot.global_position.z - marker.origin.z).length(), 0.15, "the cushion under the fire chest")
		assert_lt(absf(spot.global_position.y - marker.origin.y), 0.1, "at the marker's height")
		var cart := _bounds(displays[0])
		var pedestal := Rect2()
		for spec in level.layout.pieces:
			if spec.kit == &"pedestal" and spec.room == &"asia_korea" and spec.size.x > 3.4 and spec.size.z < 2.0:
				pedestal = spec.footprint()
		assert_true(pedestal.grow(0.1).encloses(Rect2(cart.position.x, cart.position.z, cart.size.x, cart.size.z)), "the whole display on its pedestal (%s in %s)" % [cart, pedestal])
	var bells: Array = used.get("temple_bell", [])
	assert_eq(bells.size(), 2, "the pavilion in Korea and the shrine's bell")
	for bell: Node3D in bells:
		if level.layout.room_at(bell.global_position + Vector3.UP) != &"asia_korea":
			continue
		# the tower's stone base (the roof and the striker's beam overhang it)
		var base := Rect2()
		var first := true
		for v in _world_vertices(bell):
			if v.y > 1.2:
				continue
			base = Rect2(v.x, v.z, 0.0, 0.0) if first else base.expand(Vector2(v.x, v.z))
			first = false
		var platform := Rect2()
		for spec in level.layout.pieces:
			if spec.kit == &"pedestal" and spec.room == &"asia_korea" and spec.size.z > 3.0:
				platform = spec.footprint()
		assert_true(platform.grow(0.05).encloses(base), "the bell tower's base on its platform (%s in %s)" % [base, platform])
		assert_gt(base.size.x, 3.0, "and fills it")
		var sways := 0
		for node in get_tree().get_nodes_in_group(Floor1Art.DECOR_GROUP):
			if level.is_ancestor_of(node) and node.get_meta(&"kit_room", &"") == &"asia_korea":
				sways += 1
		assert_eq(sways, 1, "the bell sways (a decor process of the hall)")


func test_the_bells_striker_stays_over_its_platform() -> void:
	# (the platform's north edge is a 0.85 m alley from the cases: the log of the
	# striker, at the height of a guard's eyes, must not hang out over it)
	var bells := 0
	for bell: Node3D in _models(level).get("temple_bell", []):
		if level.layout.room_at(bell.global_position + Vector3.UP) != &"asia_korea":
			continue
		bells += 1
		var platform := Rect2()
		for spec in level.layout.pieces:
			if spec.kit == &"pedestal" and spec.room == &"asia_korea" and spec.size.z > 3.0:
				platform = spec.footprint()
		var out := 0.0
		for v in _world_vertices(bell):
			if v.y > 0.5 and v.y < 2.6:
				var at := Vector2(v.x, v.z)
				out = maxf(out, maxf(platform.position.x - at.x, maxf(at.x - platform.end.x, maxf(platform.position.y - at.y, at.y - platform.end.y))))
		assert_lt(out, 0.06, "nothing of the bell tower between knee and head stands out over its platform (%.2f)" % out)
	assert_eq(bells, 1, "the pavilion in the Korea hall")


func test_the_fire_tripods_stop_the_guard() -> void:
	await physics_frames(2)
	var space := level.get_world_3d().direct_space_state
	var flames := 0
	for room: StringName in Floor1ArtAssyria.BRAZIERS:
		for flame: Vector3 in Floor1ArtAssyria.BRAZIERS[room]:
			flames += 1
			var point := PhysicsPointQueryParameters3D.new()
			point.collision_mask = Layers.WORLD
			for height in [0.4, 0.9, 1.3]:
				point.position = Vector3(flame.x, height, flame.z)
				assert_false(space.intersect_point(point, 1).is_empty(), "a tripod at %s is solid at %.1f m (nothing walks through the legs of a fire)" % [flame, height])
	assert_eq(flames, 4, "four tripods")


func test_the_fu_dog_statues_fit_their_pedestals() -> void:
	var statues: Array = _models(level).get("fu_dog", [])
	assert_eq(statues.size(), 2, "the lion and the lioness")
	for statue: Node3D in statues:
		var box := _bounds(statue)
		var feet := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
		var found_pedestal := false
		var found_body := false
		for spec in level.layout.pieces:
			if spec.room != &"asia_china" or not spec.footprint().has_point(feet.get_center()):
				continue
			if spec.kit == &"pedestal":
				found_pedestal = true
				assert_true(spec.footprint().grow(0.03).encloses(feet), "the statue stands on its pedestal, snout and tail over stone (%s in %s)" % [feet, spec.footprint()])
			elif spec.kit == &"sculpture":
				found_body = true
				assert_true(spec.footprint().grow(0.05).encloses(feet), "and in its collision box, so nobody walks through its snout (%s in %s)" % [feet, spec.footprint()])
		assert_true(found_pedestal and found_body, "a pedestal and a box under the statue at %s" % statue.global_position)


func test_the_garden_keeps_the_generals_perch_and_the_cherrys_petals() -> void:
	var post: Vector3 = (level.layout.markers[&"guardian_general"] as Transform3D).origin
	var points := PetalStorm.emitters_for(level, post, General.CHERRY_CROWN)
	assert_eq(points.size(), 10, "the dressed cherry's ten petal emitters")
	for p in points:
		assert_eq(level.layout.room_at(Vector3(p.x, 1.0, p.z)), &"asia_garden", "an emitter over the garden")
		assert_true(p.y > 2.5 and p.y < 6.0, "in the crown (%s)" % p)
	var perches := level.find_children("roof_perch", "Node3D", true, false)
	assert_eq(perches.size(), 1, "exactly one roof_perch node in the level")
	var perch: Transform3D = level.layout.markers[&"arena_general_perch"]
	if not perches.is_empty():
		assert_lt((perches[0] as Node3D).global_position.distance_to(perch.origin), 0.05, "on the eave's corner")
	var space := level.get_world_3d().direct_space_state
	var point := PhysicsPointQueryParameters3D.new()
	point.position = perch.origin + Vector3.UP * 0.1
	point.collision_mask = Layers.WORLD
	assert_true(space.intersect_point(point).is_empty(), "the perch stands in the open")
	var houses: Array = _models(_heroes()).get("teahouse", [])
	assert_eq(houses.size(), 1, "the tea house's facades")
	if houses.is_empty():
		return
	var house: Node3D = houses[0]
	assert_eq(house.find_children("roof_perch", "Node3D", true, false).size(), 0, "the model's ridge perch is not the General's")
	var arena := 0
	var eave_edge := -INF
	var facade := 0
	var south := 0
	for v in _world_vertices(house):
		if v.y > 0.3 and (v.x > 14.45 or v.z > -75.5) and level.layout.room_at(Vector3(v.x, 1.0, v.z)) == &"asia_garden":
			arena += 1
		# (a straight thatch edge has vertices only at its hip corners)
		if v.y > 1.5 and v.y < 4.5 and v.z > -87.0 and v.z < -75.0:
			eave_edge = maxf(eave_edge, v.x)
		if absf(v.x - 12.53) < 0.05 and v.y > 0.5 and v.y < 2.5:
			facade += 1
		if absf(v.z + 77.47) < 0.05 and v.y > 0.5 and v.y < 2.5:
			south += 1
	assert_eq(arena, 0, "nothing of the tea house stands in the arena over knee height")
	assert_true(eave_edge > 13.9 and eave_edge < 14.35, "its low skirt roof reaches to the greybox eave's edge (%.2f)" % eave_edge)
	# the greybox eave (the perch, the roof the arrows respect) wears thatch
	var eaves := 0
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if level.is_ancestor_of(node) and node.get_meta(&"kit", &"") == &"balcony" and node.get_meta(&"kit_room", &"") == &"asia_garden":
			eaves += 1
			assert_gt((node as Node).get_node(^"Visual").find_children("*", "MeshInstance3D", true, false).size(), 1, "the upper eave is thatched")
	assert_eq(eaves, 2, "the two arms of the eave")
	assert_gt(facade, 20, "its east facade on the garden's wall face")
	assert_gt(south, 20, "its south facade on the garden's wall face")
	var interiors: Array = _models(_heroes()).get("teahouse_interior", [])
	assert_eq(interiors.size(), 1, "the interior")
	if not interiors.is_empty():
		var terminal := ArtLibrary.parts(interiors[0]).get("terminal_spot") as Node3D
		var haven: Transform3D = level.layout.haven_spots[&"teahouse"]
		assert_lt(Vector2(terminal.global_position.x - haven.origin.x, terminal.global_position.z - haven.origin.z).length(), 0.3, "the model's terminal spot at the haven's")


## The garden's walls (the General's arena) wear the tsuiji to the coping
## and the museum's court front over it (the hall's string course, pilasters
## and cornice, sash and attic windows, a few lit), a pine and bamboo over
## the coping - all of it a look: no collision anywhere in it, nothing under
## the coping further out of its wall than the tsuiji's beam, every plant
## over the coping and far from the perch, nothing in a doorway.
func test_the_garden_walls_wear_a_tsuiji_and_the_museums_court_front() -> void:
	var walls := level.find_children("GardenWalls", "Node3D", true, false)
	var plants := level.find_children("GardenPlants", "Node3D", true, false)
	assert_eq(walls.size(), 1, "the garden's walls dressed once")
	assert_eq(plants.size(), 1, "its plants once")
	if walls.is_empty() or plants.is_empty():
		return
	var runs := Floor1ArtAsia.garden_runs(level.layout)
	assert_eq(runs.size(), 8, "eight fronts (the south wall one front of 26 m)")
	var south := 0.0
	for run: Dictionary in runs:
		south = maxf(south, float(run["length"]))
	assert_almost_eq(south, 26.0, 0.01, "the south wall's faces joined")
	for root: Node in [walls[0], plants[0]]:
		assert_eq(root.find_children("*", "CollisionObject3D", true, false).size(), 0, "%s: no bodies" % root.name)
		assert_eq(root.find_children("*", "CollisionShape3D", true, false).size(), 0, "%s: no shapes" % root.name)
	# boxes of each merged part (a box is 24 vertices)
	var boxes := {}
	for view: MeshInstance3D in walls[0].find_children("*", "MeshInstance3D", true, false):
		var label := String(view.name)
		if view.mesh is ArrayMesh and (label.begins_with("Tsuiji") or label.begins_with("Windows")):
			boxes[label] = int(boxes.get(label, 0)) + view.mesh.surface_get_array_len(0) / 24
	assert_gt(boxes.get("TsuijiTimber", 0), 40, "cedar posts and beams along the tsuiji (%d)" % boxes.get("TsuijiTimber", 0))
	assert_gt(boxes.get("TsuijiFooting", 0), 7, "its stone footing (%d)" % boxes.get("TsuijiFooting", 0))
	assert_gt(boxes.get("Windows_glass", 0), 24, "dark windows (%d)" % boxes.get("Windows_glass", 0))
	assert_gt(boxes.get("Windows_lit", 0), 3, "a few lit (%d)" % boxes.get("Windows_lit", 0))
	assert_lt(boxes.get("Windows_lit", 0), boxes.get("Windows_glass", 0) / 2, "most dark")
	var used := _models(walls[0])
	assert_gt((used.get("hall_pilaster_base", []) as Array).size(), 8, "the hall's pilasters between the bays")
	# the style's bands round the garden: the string course and the cornice under the sky
	var bands := {"hall_string": 0, "hall_cornice": 0}
	var everything := _models(level)
	for id: String in everything:
		for prefix: String in bands:
			if id.begins_with(prefix):
				for node: Node3D in everything[id]:
					var p := node.global_position
					if level.layout.room_at(p + (Vector3.DOWN * 1.0 if prefix == "hall_cornice" else Vector3.ZERO) + node.global_basis.z * -0.5) == &"asia_garden":
						bands[prefix] += 1
	assert_gt(bands["hall_string"], 20, "the string course over the coping (%d modules)" % bands["hall_string"])
	assert_gt(bands["hall_cornice"], 20, "the cornice under the sky (%d modules)" % bands["hall_cornice"])
	# under the coping the tsuiji stands at most its beam out of the wall
	for front: Node3D in walls[0].get_children():
		var to_face := front.global_transform.affine_inverse()
		for v in _world_vertices(front):
			var local := to_face * v
			if local.y < Floor1ArtAsia.COPING_AT - 0.01:
				assert_gt(local.z, -Floor1ArtAsia.KASAGI.y - 0.005, "%s: %s stands out of the wall under the coping" % [front.name, local])
				if local.z < -Floor1ArtAsia.KASAGI.y - 0.005:
					return
	# the plants: over the coping, in the garden, far from the perch
	var perch: Transform3D = level.layout.markers[&"arena_general_perch"]
	var lowest := INF
	var nearest := INF
	var outside := 0
	for v in _world_vertices(plants[0]):
		lowest = minf(lowest, v.y)
		nearest = minf(nearest, v.distance_to(perch.origin))
		if level.layout.room_at(Vector3(v.x, 1.0, v.z)) != &"asia_garden":
			outside += 1
	assert_gt(lowest, Floor1ArtAsia.COPING_AT, "nothing of the plants under the coping (%.2f)" % lowest)
	assert_gt(nearest, 6.0, "no plant near the General's perch (%.2f m)" % nearest)
	assert_lt(outside, 20, "the plants stand over the garden, not in the walls (%d vertices outside)" % outside)
	assert_gt((plants[0] as Node).find_children("Pine_*", "Node3D", true, false).size(), 1, "pines over the coping")
	assert_gt((plants[0] as Node).find_children("Bamboo_*", "Node3D", true, false).size(), 2, "bamboo groves over the coping")
	# nothing in the doorways (the broken wall, the tea house's, the shrine's)
	for opening in level.layout.openings:
		if opening.room_a != &"asia_garden" and opening.room_b != &"asia_garden":
			continue
		# the hole and a metre of the way on either side of it
		var hole := AABB(Vector3(opening.rect.position.x + 0.02, opening.floor_y + 0.05, opening.rect.position.y + 0.02),
			Vector3(opening.rect.size.x - 0.04, opening.top_y - opening.floor_y - 0.1, opening.rect.size.y - 0.04))
		var across := Vector3(1.0, 0.0, 0.0) if opening.rect.size.x < opening.rect.size.y else Vector3(0.0, 0.0, 1.0)
		hole = hole.expand(hole.position - across).expand(hole.end + across)
		for root: Node in [walls[0], plants[0]]:
			var inside := 0
			for box in _world_triangles(root):
				if box.intersects(hole):
					inside += 1
			assert_eq(inside, 0, "%s: %d triangles in the doorway %s" % [root.name, inside, opening.id])


## The triangles of [param node]'s visible meshes as world boxes.
func _world_triangles(node: Node) -> Array[AABB]:
	var out: Array[AABB] = []
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		if view.mesh == null or not view.visible:
			continue
		var xf := view.global_transform
		for surface in view.mesh.get_surface_count():
			var arrays := view.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for t in index.size() / 3:
				var a := xf * verts[index[t * 3]]
				var b := xf * verts[index[t * 3 + 1]]
				var c := xf * verts[index[t * 3 + 2]]
				var low := Vector3(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y)), minf(a.z, minf(b.z, c.z)))
				out.append(AABB(low, Vector3(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y)), maxf(a.z, maxf(b.z, c.z))) - low))
	return out


func test_the_tea_houses_doorway_is_the_greybox_hole_and_stays_clear() -> void:
	var hole: OpeningSpec = null
	for opening in level.layout.openings:
		if opening.id == &"asia_garden_teahouse":
			hole = opening
	assert_not_null(hole, "the tea house's door")
	if hole == null:
		return
	var houses: Array = _models(_heroes()).get("teahouse", [])
	var interiors: Array = _models(_heroes()).get("teahouse_interior", [])
	assert_eq(houses.size() + interiors.size(), 2, "the facades and the interior")
	if houses.is_empty() or interiors.is_empty():
		return
	# the walk through the doorway: from the room's floor out over the veranda
	# (the hole's own thickness, 1.5 m of the room and of the veranda beyond),
	# as wide as the hole and as high as its door (a hair in all round)
	var walk := AABB(Vector3(hole.rect.position.x - 1.5, hole.floor_y + 0.1, hole.rect.position.y + 0.01),
		Vector3(hole.rect.size.x + 3.0, hole.top_y - hole.floor_y - 0.15, hole.rect.size.y - 0.02))
	var jambs := {-1.0: -INF, 1.0: INF}   # the nearest facade geometry on either side of the hole
	for model: Node3D in [houses[0], interiors[0]]:
		var inside: Array[AABB] = []
		for box in _world_triangles(model):
			if box.intersects(walk):
				inside.append(box)
		assert_eq(inside.size(), 0, "%s has %d triangles in the doorway (walk %s), among them %s" % [model.scene_file_path.get_file(), inside.size(), walk, inside.slice(0, 3)])
	for box in _world_triangles(houses[0]):
		if box.position.x < hole.rect.end.x - 0.05 or box.position.x > hole.rect.end.x + 0.1 or box.position.y > hole.top_y or box.end.y < 1.0:
			continue
		if box.end.z <= walk.position.z + 0.01:
			jambs[-1.0] = maxf(jambs[-1.0], box.end.z)
		elif box.position.z >= walk.end.z - 0.01:
			jambs[1.0] = minf(jambs[1.0], box.position.z)
	# the posts of the facade flank the hole closely, one each side
	assert_lt(walk.position.z - jambs[-1.0], 0.25, "a post on the north side of the hole (%.2f)" % jambs[-1.0])
	assert_lt(jambs[1.0] - walk.end.z, 0.25, "a post on the south side of the hole (%.2f)" % jambs[1.0])


func test_the_tea_house_basin_is_a_flat_part_of_its_own() -> void:
	var houses: Array = _models(_heroes()).get("teahouse", [])
	if houses.is_empty():
		fail("no tea house")
		return
	var basin := ArtLibrary.parts(houses[0]).get("basin") as MeshInstance3D
	assert_not_null(basin, "the tsukubai basin is a part of the model of its own (to hide, lower or make solid)")
	if basin == null:
		return
	var top := basin.global_transform * basin.get_aabb()
	assert_lt(top.end.y, 0.3, "no stone or bamboo over knee height stands in the arena: nothing of it has collision (%.2f)" % top.end.y)
	assert_gt(top.end.y, 0.1, "but it shows over the gravel (%.2f)" % top.end.y)
	assert_eq(level.layout.room_at(basin.global_position + Vector3.UP * 0.5), &"asia_garden", "in the garden")


func test_lanterns_hang_on_their_lights_and_the_asian_fires_go_out_in_a_blackout() -> void:
	var lanterns: Array = _models(level).get("asia_lantern_red", [])
	assert_gt(lanterns.size(), 12, "red lanterns over the halls")
	var lights: Array[Vector3] = []
	for node in level.lights.get_children():
		if node is OmniLight3D and node.is_in_group(LightSpec.MAIN):
			lights.append((node as Node3D).global_position)
	for lantern: Node3D in lanterns:
		var light := (ArtLibrary.parts(lantern).get("Light") as Node3D).global_position
		assert_true(lights.any(func(p: Vector3) -> bool: return p.distance_to(light) < 0.15), "a lamp burns in the lantern at %s" % light)
	var shoji: Array = _models(_heroes()).get("asia_shoji_2m", [])
	assert_eq(shoji.size(), Floor1ArtAsia.SHOJI.size(), "lit shoji on the armour hall's walls")
	var door: Door = level.doors.get(&"asia_garden_teahouse")
	assert_not_null(door)
	if door != null:
		assert_eq((_models(door).get("asia_shoji_2m", []) as Array).size(), 1, "the tea house's door is a shoji")
	NightModifiers.apply(level, &"blackout", RunState)
	var circuit := level.lights.get_node_or_null(^"Glow_asia_armor_heroes")
	assert_not_null(circuit, "the shoji glow on the armour hall's mains")
	if circuit != null:
		assert_false(LevelKit.is_lit(circuit), "and go dark")
	for node in get_tree().get_nodes_in_group(StringName("%s_fixtures" % LightSpec.MAIN)):
		if level.is_ancestor_of(node) and String(node.get_meta(&"kit_room", &"")).begins_with("asia_") and node.has_meta(&"light"):
			assert_false(LevelKit.is_lit(node), "%s goes dark" % node.get_meta(&"kit_room"))
	var skies := 0
	for node in level.lights.get_children():
		if node is Light3D and node.is_in_group(LightSpec.MOON) and node.get_meta(&"room", &"") == &"asia_garden":
			assert_true((node as Light3D).visible, "the moon over the garden has no fuse")
			if node.get_meta(&"recipe_extra", false):
				skies += 1
	assert_eq(skies, 3, "a cold sky down each of the garden's wells")


func test_live_slots_stand_on_their_mats_clear_of_the_props() -> void:
	var mats: Array[Node3D] = []
	for node in _heroes().find_children("ExhibitMat_*", "Node3D", true, false):
		# (the Americas' mats are theirs: test_floor1_art_americas)
		if String(node.get_parent().get_meta(&"kit_room", &"")).begins_with("asia_"):
			mats.append(node as Node3D)
	# the props' looks (pieces: statues, pedestals, cases...) with their world
	# boxes: they have no collision of their own, so a stand-in body per box on
	# a layer of its own lets the exhibits' capsules be queried against them
	var stand_ins := StaticBody3D.new()
	stand_ins.collision_layer = LOOK_LAYER
	stand_ins.collision_mask = 0
	add_child(stand_ins)
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if not level.is_ancestor_of(node) or node.get_meta(&"kit_role", &"") != &"prop":
			continue
		if not String(node.get_meta(&"kit_room", &"")).begins_with("asia_"):
			continue
		var look := (node as Node).get_node_or_null(^"Visual")
		if look == null:
			continue
		for child in look.find_children("*", "MeshInstance3D", true, false):
			var view := child as MeshInstance3D
			if not view.visible or view.mesh == null:
				continue
			var box := view.global_transform * view.get_aabb()
			var form := BoxShape3D.new()
			form.size = box.size.max(Vector3.ONE * 0.01)
			var shape := CollisionShape3D.new()
			shape.shape = form
			shape.position = box.get_center()
			stand_ins.add_child(shape)
	await physics_frames(2)
	var space := level.get_world_3d().direct_space_state
	var standing := 0
	for slot in level.layout.spawn_slots:
		if not String(slot.room).begins_with("asia_") or slot.patrol != &"" or not slot.dormant:
			continue
		var kind := &"fu_dog" if slot.kinds.has(&"fu_dog") else (&"samurai_armor" if slot.kinds.has(&"samurai_armor") else &"")
		if kind == &"":
			continue
		standing += 1
		var at := slot.position
		assert_true(mats.any(func(m: Node3D) -> bool: return m.global_position.distance_to(at) < 0.05), "a display mat under the slot at %s" % at)
		# nothing solid and nothing static to look at stands in the exhibit's
		# body: its capsules, turned to the slot's yaw, against the greybox's
		# collision and the props' looks
		var slot_frame := Transform3D(Basis(Vector3.UP, slot.yaw), at)
		for body: Array in BODIES[kind]:
			var capsule := CapsuleShape3D.new()
			capsule.radius = float(body[0])
			capsule.height = float(body[1])
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.collision_mask = Layers.WORLD | LOOK_LAYER
			var lying := Basis(Vector3.RIGHT, PI * 0.5) if body[3] else Basis.IDENTITY   # (a capsule stands along Y; a dog's lies along its length, Z)
			query.transform = slot_frame * Transform3D(lying, body[2])
			for hit in space.intersect_shape(query, 4):
				var what: Object = hit["collider"]
				var label: String = "a prop's look" if what == stand_ins else String(what.get_meta(&"kit", what.name))
				fail("the %s at %s (yaw %.2f) has %s in its %s capsule (r %.2f)" % [kind, at, slot.yaw, label, body[4], capsule.radius])
	assert_gt(standing, 20, "the wing's standing exhibits")
	assert_eq(mats.size(), standing, "one mat per standing exhibit")


## Mean saturation of the lit texels of [param texture] (what colour it reads as).
func _chroma(texture: Texture2D) -> float:
	var image := Image.new()
	image.copy_from(texture.get_image())   # (a copy: a headless renderer hands out the texture's own image)
	image.decompress()
	image.resize(48, 48, Image.INTERPOLATE_BILINEAR)
	var total := 0.0
	var count := 0
	for y in 48:
		for x in 48:
			var texel := image.get_pixel(x, y)
			if texel.v > 0.12:
				total += texel.s
				count += 1
	return total / maxf(1.0, count)


func test_the_fu_dog_statues_are_stone_not_the_live_dogs_green_bronze() -> void:
	# (the live dog's exhibit model and material stand 1.5-2.5 m from each
	# statue: a guard must tell the decor from the enemy)
	var statues: Array = _models(level).get("fu_dog", [])
	assert_eq(statues.size(), 2, "the lion and the lioness on their pedestals")
	var live := ArtLibrary.exhibit_material("fu_dog")
	var live_chroma := _chroma(live.get_shader_parameter(&"albedo_tex"))
	assert_gt(live_chroma, 0.3, "the live dog is green bronze")
	for statue: Node3D in statues:
		var surfaces := 0
		var plain := true
		var glowing := false
		var greenest := 0.0
		for child in statue.find_children("*", "MeshInstance3D", true, false):
			var view := child as MeshInstance3D
			for i in view.mesh.get_surface_count():
				surfaces += 1
				var material := view.get_surface_override_material(i) as BaseMaterial3D
				if material == null:
					plain = false
					continue
				glowing = glowing or material.emission_enabled
				greenest = maxf(greenest, _chroma(material.albedo_texture))
		assert_gt(surfaces, 0, "the statue has surfaces")
		assert_true(plain, "the statue wears plain materials of its own, not the exhibit's shader")
		assert_false(glowing, "no eyes or pearl glowing: it is no enemy")
		assert_lt(greenest, 0.25, "grey stone, not the exhibit's green bronze (%.2f against %.2f)" % [greenest, live_chroma])


func test_a_wings_door_leaf_is_an_optional_hook() -> void:
	var size := Vector3(1.9, 2.6, 0.1)
	for room in [&"asia_garden", &"asia_teahouse"]:
		var leaf: Variant = Floor1Art.door_leaf(room, size, OpeningSpec.DoorStyle.SWING, 1.0)
		assert_true(leaf is Node3D, "the %s's swinging door has the Asian wing's leaf" % room)
		if leaf is Node3D:
			(leaf as Node3D).free()
	assert_true(Floor1Art.door_leaf(&"asia_garden", size, OpeningSpec.DoorStyle.DOUBLE_SWING, 1.0) == null, "only the swinging doors")
	# a wing without the hook, and a room of no wing, fall back to the kit's leaves
	assert_true(Floor1Art.door_leaf(&"assyria_gate", size, OpeningSpec.DoorStyle.SWING, 1.0) == null, "no leaf of its own in Assyria")
	assert_true(Floor1Art.door_leaf(&"court", size, OpeningSpec.DoorStyle.SWING, 1.0) == null, "none in a room of no wing")


func test_dust_embers_and_petals_in_the_east_wings() -> void:
	var embers := 0
	var petals := 0
	var dust := {}
	for node in level.lights.get_children():
		if not node is GPUParticles3D:
			continue
		var room: StringName = node.get_meta(&"room", &"")
		var spec := level.layout.room(room)
		if spec == null or not WINGS.has(spec.zone):
			continue
		assert_true(node.is_in_group(GraphicsQuality.PARTICLES), "%s follows the presets" % node.name)
		if node.get_meta(&"embers", false):
			embers += 1
			assert_true(String(room).begins_with("assyria_"), "embers over an Assyrian fire")
			var flames: Array = Floor1ArtAssyria.BRAZIERS[room]
			var at := (node as Node3D).global_position
			assert_true(flames.any(func(f: Vector3) -> bool: return f.distance_to(at) < 0.05), "over a tripod's flame")
		elif node.get_meta(&"petals", false):
			petals += 1
			assert_eq(room, &"asia_garden", "petals fall in the garden")
		else:
			dust[room] = true
	assert_eq(embers, 4, "embers over each fire tripod")
	assert_eq(petals, 2, "petals drift down over both arms of the garden")
	for room in [&"assyria_courtyard", &"assyria_nimrud", &"assyria_lions", &"assyria_gate", &"asia_china", &"asia_korea"]:
		assert_true(dust.has(room), "dust floats in %s" % room)
	# far from the garden the petals stop (the room-graph culling)
	level.culler.set_room(&"asia_garden", false)
	for node in level.lights.get_children():
		if node is GPUParticles3D and node.get_meta(&"petals", false):
			assert_false((node as GPUParticles3D).emitting, "culled petals stop")


func test_the_assyrian_fires_go_out_in_a_blackout_and_the_moon_stays() -> void:
	var tripods := 0
	for node in get_tree().get_nodes_in_group(StringName("%s_fixtures" % LightSpec.MAIN)):
		if level.is_ancestor_of(node) and node.get_meta(&"kit", &"") == &"brazier":
			tripods += 1
			assert_true(LevelKit.is_lit(node), "a tripod burns at night")
	assert_eq(tripods, 4)
	NightModifiers.apply(level, &"blackout", RunState)
	for node in get_tree().get_nodes_in_group(StringName("%s_fixtures" % LightSpec.MAIN)):
		if level.is_ancestor_of(node) and String(node.get_meta(&"kit_room", &"")).begins_with("assyria_") and node.has_meta(&"light"):
			assert_false(LevelKit.is_lit(node), "%s goes dark" % node.get_meta(&"kit_room"))
	var skies := 0
	for node in level.lights.get_children():
		if node is Light3D and node.is_in_group(LightSpec.MOON) and node.get_meta(&"room", &"") == &"assyria_courtyard":
			assert_true((node as Light3D).visible, "the moon over the courtyard has no fuse")
			if node.get_meta(&"recipe_extra", false):
				skies += 1
	assert_eq(skies, 1, "a cold sky down the courtyard's well")


func test_every_room_of_both_wings_has_a_style_and_a_light_recipe() -> void:
	var rooms := _rooms()
	assert_eq(rooms.size(), 21, "eleven Assyrian rooms and ten Asian ones")
	var recipe := Floor1LightRecipe.create(level.layout)
	for room in rooms:
		assert_true(ArtKit.has_style(room.id), "%s has a style of its own" % room.id)
		assert_true(Floor1Art.ROOM_STYLES.has(room.id), "%s is a Floor I room the art knows" % room.id)
		assert_true(recipe.rooms.has(recipe.key(room.id)), "%s has its light recipe" % room.id)
		if WINGS.has(room.zone) and not String(room.id).ends_with("_stairs") and room.id != &"asia_teahouse":
			var entry: Dictionary = recipe.rooms[recipe.key(room.id)]
			assert_true(float(entry.get("lamp_energy", 1.0)) >= 1.2, "%s's lamps burn brighter than the plan (not too dark)" % room.id)
	var egypt_darkest := 0.0
	for key: StringName in Floor1LightRecipe.ROOMS:
		if String(key).begins_with("egypt_"):
			egypt_darkest = maxf(egypt_darkest, float(Floor1LightRecipe.ROOMS[key]["fog"]))
	for key in [&"assyria_gate", &"assyria_nimrud", &"assyria_courtyard", &"assyria_lions", &"asia_china", &"asia_garden"]:
		assert_lt(float(Floor1LightRecipe.ROOMS[key]["fog"]), egypt_darkest, "%s's air is thinner than Egypt's tombs" % key)
