extends TestCase
## Floor I props modelled in Blender in place of the art modules' procedural
## solids (plan docs/superpowers/plans/2026-10-21-modele-blender.md): every
## model of ArtLibrary.KIT_PROPS loads dressed with its parts and markers at
## its native size within its triangle budget; on the dressed floor each
## stands in its greybox box (the box the collision was drawn for) and
## nothing of it reaches out of it. (Godot axes: models face -Z.)

## The greybox pieces now drawn by a model: "kit@room" -> [the model, the
## least length (m, along z) of the pieces it draws there: 0 = all of them].
const PIECES := {
	"bison@americas_north": ["bison", 0.0],
	"tipi@americas_north": ["tipi", 0.0],
	"pedestal@americas_north": ["kayak_stand", 5.0],
	"kayak@americas_north": ["kayak", 0.0],
	"whaleboat@americas_pacific": ["whaleboat", 0.0],
	"chariot@assyria_lions": ["asy_chariot", 0.0],
	"cage@assyria_lions": ["asy_cage", 0.0],
	"water_tank@roof_plant": ["roof_water_tank", 0.0],
	"plant_unit@roof_plant": ["roof_air_handler", 0.0],
	"chimney@roof_plant": ["roof_chimney_tall", 0.0],
	"chimney@roof_catwalks": ["roof_chimney_short", 0.0],
	"pigeon_cages@roof_loft": ["roof_pigeon_loft", 0.0],
	"scaffold@assyria_nimrud": ["asy_scaffold", 0.0],
}
## Models whose origin is their root, not the middle of their footprint:
## the garden's plants (rooted behind the coping, leaning out over the gravel).
const ROOTED: Array[StringName] = [&"garden_pine", &"garden_bamboo"]
## How far (m) a model may reach past its box on any side (and under its base).
const SLACK := 0.05


func _xf(node: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n := node
	while n != root and n != null:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _bounds(root: Node) -> AABB:
	var out := AABB()
	var first := true
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var box := _xf(mesh, root) * mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


func _triangles(node: Node) -> int:
	var count := 0
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := (child as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var index: PackedInt32Array = mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX]
			count += index.size() / 3
	return count


func test_every_prop_loads_at_its_size_within_budget() -> void:
	assert_gt(ArtLibrary.KIT_PROPS.size(), 0, "the modelled props")
	for id: StringName in ArtLibrary.KIT_PROPS:
		assert_true(ArtLibrary.KIT.has(id), "%s registered in KIT" % id)
		assert_true(ArtLibrary.has_model(id), "%s has a model file" % id)
		if not ArtLibrary.has_model(id):
			continue
		var node := ArtKit.model(String(id))
		var entry: Array = ArtLibrary.KIT_PROPS[id]
		var native: Vector3 = entry[0]
		var box := _bounds(node)
		for axis in 3:
			assert_almost_eq(box.size[axis], native[axis], 0.05 + native[axis] * 0.02, "%s size on axis %d" % [id, axis])
		if not ROOTED.has(id):
			assert_lt(absf(box.get_center().x), 0.05 + native.x * 0.02, "%s: its footprint centred on x" % id)
		assert_lt(absf(box.position.y), 0.03, "%s: its base on the floor" % id)
		assert_lt(_triangles(node), int(entry[1]) + 1, "%s within its budget" % id)
		for child in node.find_children("*", "MeshInstance3D", true, false):
			var view := child as MeshInstance3D
			for i in view.mesh.get_surface_count():
				assert_not_null(view.get_surface_override_material(i), "%s/%s dressed" % [id, view.name])
		var found := ArtLibrary.parts(node)
		for part: String in ArtLibrary.KIT[id]:
			assert_true(found.has(part), "%s has %s" % [id, part])
		node.free()


func test_the_props_stand_in_their_greybox_boxes() -> void:
	MuseumFloorLevel.dress_default = true
	var level := MuseumFloorLevel.new()
	level.bake_navigation = false
	add_child(level)
	level.build()
	var seen := {}
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if not level.is_ancestor_of(node):
			continue
		var key := "%s@%s" % [node.get_meta(&"kit", &""), node.get_meta(&"kit_room", &"")]
		if not PIECES.has(key):
			continue
		var model: String = PIECES[key][0]
		var size: Vector3 = node.get_meta(&"kit_size", Vector3.ZERO)
		if size.z < float(PIECES[key][1]):
			continue
		var look := (node as Node).get_node_or_null(^"Visual") as Node3D
		assert_not_null(look, "%s has a look" % key)
		if look == null:
			continue
		var found := false
		for child in look.find_children("*", "Node3D", true, false):
			found = found or String(child.scene_file_path).get_file() == model + ".glb"
		assert_true(found, "%s is drawn by %s" % [key, model])
		var box := _xf(look, node) * _bounds(look)
		var at := (node as Node3D).global_position.snapped(Vector3.ONE * 0.1)
		assert_gt(box.position.x, -size.x * 0.5 - SLACK, "%s at %s within its box (-x %.2f)" % [key, at, box.position.x])
		assert_lt(box.end.x, size.x * 0.5 + SLACK, "%s at %s within its box (+x %.2f)" % [key, at, box.end.x])
		assert_gt(box.position.z, -size.z * 0.5 - SLACK, "%s at %s within its box (-z %.2f)" % [key, at, box.position.z])
		assert_lt(box.end.z, size.z * 0.5 + SLACK, "%s at %s within its box (+z %.2f)" % [key, at, box.end.z])
		assert_gt(box.position.y, -SLACK, "%s at %s on its base (%.2f)" % [key, at, box.position.y])
		assert_lt(box.end.y, size.y + SLACK, "%s at %s under its top (%.2f)" % [key, at, box.end.y])
		# it fills its box (a model fitted, not a toy in a crate)
		assert_gt(maxf(box.size.y / size.y, maxf(box.size.x / size.x, box.size.z / size.z)), 0.9, "%s at %s fills its box (%s in %s)" % [key, at, box.size, size])
		seen[key] = true
	for key: String in PIECES:
		assert_true(seen.has(key), "%s placed on the floor" % key)
	MuseumFloorLevel.dress_default = false
	level.free()
