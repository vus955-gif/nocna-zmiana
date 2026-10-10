extends TestCase
## Floor I's art fits its greybox (stage P2): below head height a piece's
## look stays within its collision box (nobody walks into a statue's knee
## or through a counter that is not there), and the hero pieces without
## collision stand overhead, against walls or inside a greybox box. Checked
## in each piece's own frame, so turned pieces are measured true.

## How far (m) a look may reach past its box below head height.
const SLACK := 0.3
## Pieces whose look reaches out by design: [kit, why].
const REACHES := {
	&"desk": "the Reading Room's desks carry their chairs; a writing desk its chair",
	&"cafe_table": "three chairs round each table",
	&"totem": "the Thunderbird's wings, high up",
	&"railing": "parapets and balustrades a little wider than the rail",
	&"balcony": "slab fascia",
	&"steam_banner": "stands on the floor behind the gatling (no box)",
	&"door_leaf": "the leaves' mouldings",
	&"plinth": "a sarcophagus a little longer and wider than its plinth",
	&"crate": "the tent's guy ropes and flaps",
	&"cloakroom_counter": "the rails and coats behind the counter",
	&"shop_front": "the shop front's sign",
	&"pedestal": "the astrolabe's lowest step",
	&"court_lamp_post": "the side lanterns",
	&"bench": "bench ends",
	&"sculpture": "a statue's stride and arms",
	&"court_map_board": "the board's feet",
	&"signpost": "the sign's arms",
}
const HEAD := 1.9

var level: MuseumFloorLevel


func before_each() -> void:
	MuseumFloorLevel.dress_default = true
	level = MuseumFloorLevel.new()
	level.bake_navigation = false
	add_child(level)
	level.build()


func after_each() -> void:
	MuseumFloorLevel.dress_default = false


func test_looks_stay_within_their_boxes_below_head_height() -> void:
	var worst := {}
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if not level.is_ancestor_of(node) or not node is StaticBody3D:
			continue
		var room: StringName = node.get_meta(&"kit_room", &"")
		if not Floor1Art.ROOM_STYLES.has(room):
			continue
		var kit: StringName = node.get_meta(&"kit", &"")
		if LevelKit.role(kit) in [&"wall", &"floor", &"ceiling", &"trim", &"fixture"] or kit == &"stair_ramp":
			continue
		var look := (node as Node).get_node_or_null(^"Visual") as Node3D
		if look == null:
			continue
		var size: Vector3 = node.get_meta(&"kit_size", Vector3.ZERO)
		var reach := _reach(node as Node3D, look, size)
		if reach > float(worst.get(kit, [0.0])[0]):
			worst[kit] = [reach, room, (node as Node3D).global_position.snapped(Vector3.ONE * 0.1)]
	for kit: StringName in worst:
		var entry: Array = worst[kit]
		if float(entry[0]) > SLACK and not REACHES.has(kit):
			fail("%s in %s at %s reaches %.2f m past its box below head height" % [kit, entry[1], entry[2], entry[0]])
		elif float(entry[0]) > 1.2 and kit != &"totem":   # one mesh: its wings are 9 m up
			fail("%s in %s at %s reaches %.2f m past its box (too far even by design)" % [kit, entry[1], entry[2], entry[0]])
	print("  worst reach per kit: ", worst)


## How far [param look]'s meshes reach past the box of [param size] (base
## centre at the piece's origin) below HEAD, in the piece's own frame.
func _reach(piece: Node3D, look: Node3D, size: Vector3) -> float:
	var to_local := piece.global_transform.affine_inverse()
	var reach := 0.0
	for child in look.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		if not view.visible or view.mesh == null:
			continue
		var box := to_local * view.global_transform * view.get_aabb()
		if box.position.y > HEAD:
			continue
		reach = maxf(reach, maxf(-size.x * 0.5 - box.position.x, box.end.x - size.x * 0.5))
		reach = maxf(reach, maxf(-size.z * 0.5 - box.position.z, box.end.z - size.z * 0.5))
	return reach


func test_hero_pieces_stand_out_of_the_way() -> void:
	# below head height a hero (no collision) must stand inside the drum's
	# walls and bookcases, on the astrolabe's pedestal, on the floor (the
	# mosaic) or in a doorway's frame; stage P3: the Nereid temple on its
	# podium (its cella and columns in the greybox's), the library's
	# bookcases in the greybox's shelves (the 0.5 m gaps between the boxes
	# are closed: nobody fits in them), a ladder in an alcove under a bridge,
	# the clock walls and small pictures flat on walls
	var allowed := ["rr_drum_wall", "rr_drum_door", "rr_bookcase", "rr_bookcase_door", "rr_catalogue_arc", "astrolabe",
		"entrance_mosaic", "hall_arch_4m", "egypt_portal_great", "rr_oculus", "rr_dome_sector", "court_roof_q",
		"court_balcony_seg", "egypt_clerestory_3m", "egypt_beam_4m",
		"nereid_temple", "lib_bookcase_a_2m", "lib_bookcase_b_2m", "lib_bookcase_c_2m", "lib_bookcase_1m",
		"lib_bookcase_up_a_2m", "lib_bookcase_up_b_2m", "lib_bookcase_up_1m", "lib_bookcase_pilaster_low",
		"lib_bookcase_pilaster_up", "lib_ladder", "lib_clock_wall", "frame_1_2x0_9", "frame_0_6x0_8", "frame_3x2",
		"lib_walkway_bracket"]   # (under the gallery's slab: 2.8 m over the library's floor)
	var heroes := level.structure.get_node(^"Dressing/Floor1Heroes")
	for node in heroes.find_children("*", "Node3D", true, false):
		var path := String(node.scene_file_path)
		if not path.begins_with("res://assets/models/"):
			continue
		var id := path.get_file().trim_suffix(".glb")
		var low := INF
		for child in (node as Node).find_children("*", "MeshInstance3D", true, false):
			var view := child as MeshInstance3D
			low = minf(low, (view.global_transform * view.get_aabb()).position.y)
		var floor_y := 0.0
		var room := level.layout.room(level.layout.room_at((node as Node3D).global_position + Vector3.UP * 0.5))
		if room != null:
			floor_y = room.floor_y
		if low < floor_y + HEAD:
			assert_true(id in allowed, "%s at %s comes down into the walkway" % [id, (node as Node3D).global_position])
