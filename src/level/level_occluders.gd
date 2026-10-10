class_name LevelOccluders
extends RefCounted
## Occlusion culling of a built level (design 11.3): one OccluderInstance3D
## whose ArrayOccluder3D holds every big solid of the shell (walls, floors,
## slabs, ceilings of 4 m2 and more) plus the solid wall pieces (the Reading
## Room's drum), each box shrunk a little so the dressing on its faces is
## never hidden by the box it hangs on. Boxes with no look (the sky over
## the roof) occlude nothing. Needs the project setting
## rendering/occlusion_culling/use_occlusion_culling.

## Boxes shrink by this much on every side.
const INSET := 0.06
## Faces smaller than this (m2) are not worth an occluder.
const MIN_AREA := 4.0
## Piece kits that are solid walls.
const WALL_PIECES: Array[StringName] = [&"wall"]


## The occluder of the boxes under [param roots] (LevelKit pieces with
## kit roles wall / floor / ceiling, their "kit_size" and transforms),
## skipping pieces whose look is empty. Null when there is nothing.
static func build(roots: Array[Node]) -> OccluderInstance3D:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var count := 0
	for root in roots:
		if root == null:
			continue
		for node in root.get_children():
			var kit: StringName = node.get_meta(&"kit", &"")
			if kit == &"":
				continue
			var role := LevelKit.role(kit)
			if role != &"wall" and role != &"floor" and role != &"ceiling" and not WALL_PIECES.has(kit):
				continue
			if kit in [&"false_panel", &"painting_panel", &"vent_grille", &"skylight", &"grass"]:
				continue
			if node.get_meta(&"sky", false):
				continue   # the roof's sky: it hides nothing
			var size: Vector3 = node.get_meta(&"kit_size", Vector3.ZERO)
			var faces := [size.x * size.y, size.x * size.z, size.y * size.z]
			if faces.max() < MIN_AREA:
				continue
			_box(vertices, indices, (node as Node3D).global_transform if node.is_inside_tree() else (node as Node3D).transform, size)
			count += 1
	if count == 0:
		return null
	var shape := ArrayOccluder3D.new()
	shape.set_arrays(vertices, indices)
	var occluder := OccluderInstance3D.new()
	occluder.name = "Occluders"
	occluder.occluder = shape
	occluder.set_meta(&"boxes", count)
	return occluder


## A box of [param size] whose base centre is [param xform]'s origin
## (LevelKit's frame), shrunk by INSET.
static func _box(vertices: PackedVector3Array, indices: PackedInt32Array, xform: Transform3D, size: Vector3) -> void:
	var half := Vector3(maxf(size.x * 0.5 - INSET, 0.01), maxf(size.y * 0.5 - INSET, 0.01), maxf(size.z * 0.5 - INSET, 0.01))
	var centre := Vector3(0.0, size.y * 0.5, 0.0)
	var base := vertices.size()
	for i in 8:
		var corner := Vector3(half.x if i & 1 else -half.x, half.y if i & 2 else -half.y, half.z if i & 4 else -half.z)
		vertices.append(xform * (centre + corner))
	for quad: Array in [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]:
		indices.append_array(PackedInt32Array([base + quad[0], base + quad[1], base + quad[2], base + quad[0], base + quad[2], base + quad[3]]))
