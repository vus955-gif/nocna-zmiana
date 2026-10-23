class_name SerpentRig
extends RefCounted
## The Two-headed Serpent's body on screen: the Blender model "serpent"
## (ArtLibrary; docs/art/kit-pietro1-ameryki.md §10: 14 segments chained
## along +Z, each with its mosaic plating tiles_k and its seg_k marker, head
## A on the first segment looking -Z, head B on the last looking +Z, a jaw
## hinged in each skull) stretched to SerpentBody.SEGMENTS segments: the
## chain is flattened (every segment a child of the rig's root, placed in
## the world by SerpentBody.segment_transform()), the first and last seven
## segments are the model's own, the middle copies the fattest two. A
## greybox of the same names stands in when the model is off.
## apply() places the segments, turns the skulls onto their looks, opens
## the jaws, and drives the exhibit shader's instance uniforms: "awake"
## (the eyes), "glow" (a head's mouth as it spits, the cracks of a segment
## whose plate is gone, phase 2's light running down the body), "flash" (a
## hit). drop_plate() hides a segment's mosaic (flung as debris) and bares
## its glowing core.

const MODEL := &"serpent"
## A jaw fully open (rad).
const JAW_OPEN := 0.75
## The travelling light of phase 2 spans this many segments.
const LIGHT_SPAN := 4.0
## The model's rest offsets (the greybox copies them).
const SKULL_A_REST := Vector3(0.0, 0.38, 0.0)
const SKULL_B_REST := Vector3(0.0, 0.338, 0.75)
const JAW_REST := Vector3(0.0, -0.114, 0.228)
const HEAD_MARK := Vector3(0.0, 0.152, 0.855)
const MOUTH_MARK := Vector3(0.0, -0.19, 1.938)
const TURQUOISE := Color(0.18, 0.62, 0.6)
const CORE_WOOD := Color(0.26, 0.16, 0.1)


## What the rig shows this frame (world space).
class Pose:
	extends RefCounted
	## Each head's look (unit) - the heads sit where the body's end joints
	## are; a jaw's opening 0..1; a head's mouth glow 0..1.
	var head_look: Array[Vector3] = [Vector3.FORWARD, Vector3.BACK]
	var jaw: Array[float] = [0.0, 0.0]
	var head_glow: Array[float] = [0.0, 0.0]
	## 0 asleep .. 1 awake (the eyes).
	var eyes: float = 0.0
	## The bared cores' cracks (0..2).
	var cracks: float = 1.0
	## Phase 2's light along the body, 0 (end A) .. 1 (end B); < 0 = none.
	var light_s: float = -1.0
	## The tail's plates shiver (0..1) at [member rattle_end].
	var rattle: float = 0.0
	var rattle_end: SerpentBody.End = SerpentBody.End.B


var model: Node3D
var count: int = SerpentBody.SEGMENTS
var segments: Array[Node3D] = []
var cores: Array[MeshInstance3D] = []
var tiles: Array[MeshInstance3D] = []
var skulls: Array[Node3D] = []
var jaws: Array[Node3D] = []
var head_marks: Array[Node3D] = []
var mouth_marks: Array[Node3D] = []
var plates_on: Array[bool] = []
var greybox := false

var _jaw_rest: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]
var _mid_of: Dictionary = {}
var _skull_rest: Array[Vector3] = [SKULL_A_REST, SKULL_B_REST]
var _head_meshes: Array = [[], []]
var _flash: float = 0.0
## The shader uniforms last sent, by view slot (cores, then tiles, then the
## heads' meshes): -1 = nothing yet. The eyes' and the flash's last values
## overall: unchanged, no view is looked at for them.
var _sent_glow := PackedFloat32Array()
var _sent_awake := PackedFloat32Array()
var _sent_flash := PackedFloat32Array()
var _awake_now: float = -1.0
var _flash_now: float = -1.0
var _rattling := false
var _noise := FastNoiseLite.new()
var _time: float = 0.0


## The rig under [param parent] (the model, or the greybox when the model
## is off or missing), of [param segment_count] segments, in world space
## (the root is top-level: its children's transforms are world).
static func create(parent: Node3D, segment_count: int = SerpentBody.SEGMENTS) -> SerpentRig:
	var rig := SerpentRig.new()
	rig.count = segment_count
	rig.model = ArtLibrary.exhibit(MODEL)
	if rig.model == null:
		rig.model = _make_greybox()
		rig.greybox = true
	rig.model.name = "Serpent"
	rig.model.top_level = true
	parent.add_child(rig.model)
	rig.model.global_transform = Transform3D.IDENTITY
	rig._setup()
	return rig


func _setup() -> void:
	_noise.seed = 31
	_noise.frequency = 0.8
	# flatten the model's chain and stretch it to the body's length
	var originals: Array[Node3D] = []
	for k in range(1, SerpentBody.MODEL_SEGMENTS + 1):
		var node := model.find_child("segment_%d" % k, true, false) as Node3D
		originals.append(node)
	for node in originals:
		if node.get_parent() != model:
			node.reparent(model, false)
	segments.resize(count)
	cores.resize(count)
	tiles.resize(count)
	plates_on.resize(count)
	var used := {}
	for k in count:
		var original := SerpentBody.model_segment(k, count)
		var source := originals[original - 1]
		var node: Node3D
		if used.has(original):
			node = source.duplicate() as Node3D
			# (a copy of the model's 7 or 8: no skull rides those)
			model.add_child(node)
		else:
			node = source
			used[original] = true
		# (names in two passes: Godot renumbers a name a sibling still holds)
		node.name = "link_%d" % k
		segments[k] = node
		plates_on[k] = true
		for child in node.get_children():
			var child_name := String(child.name)
			if child is MeshInstance3D and not child_name.begins_with("skull"):
				tiles[k] = child as MeshInstance3D
			elif not child_name.begins_with("skull") and not child_name.begins_with("segment"):
				_mid_of[k] = child
		cores[k] = node as MeshInstance3D
	for k in count:
		segments[k].name = "segment_%d" % (k + 1)
		if tiles[k] != null:
			tiles[k].name = "tiles_%d" % (k + 1)
		if _mid_of.has(k):
			(_mid_of[k] as Node).name = "seg_%d" % (k + 1)
	# the heads: on the first and the last segment
	for end in 2:
		var suffix := "a" if end == 0 else "b"
		var skull := model.find_child("skull_" + suffix, true, false) as Node3D
		var jaw := model.find_child("jaw_" + suffix, true, false) as Node3D
		skulls.append(skull)
		jaws.append(jaw)
		head_marks.append(model.find_child("head_" + suffix, true, false) as Node3D)
		mouth_marks.append(model.find_child("mouth_" + suffix, true, false) as Node3D)
		_skull_rest[end] = skull.position
		_jaw_rest[end] = jaw.transform
		var meshes: Array = []
		if skull is MeshInstance3D:
			meshes.append(skull)
		if jaw is MeshInstance3D:
			meshes.append(jaw)
		for child in skull.find_children("*", "MeshInstance3D", true, false):
			if not meshes.has(child):
				meshes.append(child)
		_head_meshes[end] = meshes
	var views := 2 * count + (_head_meshes[0] as Array).size() + (_head_meshes[1] as Array).size()
	_sent_glow.resize(views)
	_sent_glow.fill(-1.0)
	_sent_awake = _sent_glow.duplicate()
	_sent_flash = _sent_glow.duplicate()
	# the segment with head B is the last: the skull rides its far end
	if skulls[1].get_parent() != segments[count - 1]:
		skulls[1].reparent(segments[count - 1], false)
		skulls[1].position = _skull_rest[1]
	if skulls[0].get_parent() != segments[0]:
		skulls[0].reparent(segments[0], false)
		skulls[0].position = _skull_rest[0]
	# the plates break off as debris: cut them in the background
	if not greybox:
		var warmed := {}
		for plate in tiles:
			if plate != null and plate.mesh != null and not warmed.has(plate.mesh):
				warmed[plate.mesh] = true
				MeshShards.warm_slices(plate.mesh, 2)


# --- reading -----------------------------------------------------------------------

func skull(end: SerpentBody.End) -> Node3D:
	return skulls[end]


## The weak point inside head [param end] (world).
func head_point(end: SerpentBody.End) -> Vector3:
	return head_marks[end].global_position


## The mouth of head [param end] (world): where shards leave, where it bites.
func mouth_point(end: SerpentBody.End) -> Vector3:
	return mouth_marks[end].global_position


## Head [param end]'s look now (world, unit).
func head_forward(end: SerpentBody.End) -> Vector3:
	var basis := skulls[end].global_basis
	return (-basis.z if end == SerpentBody.End.A else basis.z).normalized()


## The plate of segment [param k] still on.
func plate_on(k: int) -> bool:
	return plates_on[k]


## How many plates are still on.
func plates_left() -> int:
	var n := 0
	for on in plates_on:
		if on:
			n += 1
	return n


# --- posing --------------------------------------------------------------------------

## Places the body from [param body]'s joints and shows [param pose].
func apply(body: SerpentBody, pose: Pose, delta: float = 0.0) -> void:
	_time += delta
	for k in count:
		segments[k].transform = body.segment_transform(k)
	for end in 2:
		var seg := segments[0 if end == 0 else count - 1]
		var look := pose.head_look[end]
		if look.length() < 0.001:
			look = Vector3.FORWARD
		look = look.normalized()
		var up := Vector3.UP if absf(look.dot(Vector3.UP)) < 0.98 else seg.basis.y
		var wanted := Basis.looking_at(look if end == 0 else -look, up)
		var local := (seg.basis.orthonormalized().inverse() * wanted).orthonormalized()
		skulls[end].transform = Transform3D(local, _skull_rest[end])
		var opening := clampf(pose.jaw[end], 0.0, 1.0) * JAW_OPEN
		var rest := _jaw_rest[end]
		jaws[end].transform = Transform3D(rest.basis * Basis(Vector3.RIGHT, -opening if end == 0 else opening), rest.origin)
	_rattle(pose)
	_glow(pose, delta)


## Gives every part a short white flash (a hit landing).
func flash(amount: float = 1.0) -> void:
	_flash = maxf(_flash, amount)


## Segment [param k]'s mosaic comes off: hidden, flung as debris along
## [param push], the core bared.
func drop_plate(k: int, push: Vector3 = Vector3.UP) -> void:
	if k < 0 or k >= count or not plates_on[k]:
		return
	plates_on[k] = false
	var plate := tiles[k]
	if plate == null:
		return
	if plate.is_inside_tree() and plate.visible and plate.mesh != null and not greybox:
		var materials: Array[Material] = []
		for i in plate.mesh.get_surface_count():
			var source := plate.get_active_material(i)
			materials.append(ArtLibrary.debris_material(source) if source != null else null)
		var pieces: Array = MeshShards.slices(plate.mesh, 2) if MeshShards.has_slices(plate.mesh, 2) else [MeshShards.whole(plate.mesh)]
		for piece: MeshShards.Piece in pieces:
			var fling := push * randf_range(1.5, 3.0) + Vector3(randf_range(-1.0, 1.0), randf_range(1.5, 3.0), randf_range(-1.0, 1.0))
			Fx.piece(piece, materials, plate.global_transform, fling, 6.0)
	plate.visible = false


## Every plate back on (the guard fled).
func restore_plates() -> void:
	for k in count:
		plates_on[k] = true
		if tiles[k] != null:
			tiles[k].visible = true


# --- looks ---------------------------------------------------------------------------

## The trailing tail's plates shiver.
func _rattle(pose: Pose) -> void:
	var amount := clampf(pose.rattle, 0.0, 1.0)
	if amount <= 0.001 and not _rattling:
		return
	# (one more pass once it stops: the plates straighten)
	_rattling = amount > 0.001
	var from := count - SerpentBody.SWEEP_JOINTS if pose.rattle_end == SerpentBody.End.B else 0
	var to := count if pose.rattle_end == SerpentBody.End.B else SerpentBody.SWEEP_JOINTS
	for k in count:
		var plate := tiles[k]
		if plate == null:
			continue
		if amount > 0.001 and k >= from and k < to:
			plate.rotation = Vector3(0.0, 0.0, _noise.get_noise_2d(_time * 60.0, float(k) * 7.0) * 0.08 * amount)
		elif plate.rotation != Vector3.ZERO:
			plate.rotation = Vector3.ZERO


func _glow(pose: Pose, delta: float) -> void:
	_flash = move_toward(_flash, 0.0, 6.0 * delta)
	if greybox:
		return
	var awake := clampf(pose.eyes, 0.0, 1.0)
	var eyes_changed := absf(_awake_now - awake) >= 0.005
	var flash_changed := absf(_flash_now - _flash) >= 0.005
	if eyes_changed:
		_awake_now = awake
	if flash_changed:
		_flash_now = _flash
	var spread := pose.light_s >= 0.0
	for k in count:
		var light := 0.0
		if spread:
			var s := (float(k) + 0.5) / float(count)
			light = 2.0 * maxf(0.0, 1.0 - absf(s - pose.light_s) * float(count) / LIGHT_SPAN)
		var core_glow := light + (pose.cracks if not plates_on[k] else 0.0)
		_uniforms(cores[k], k, core_glow, awake, eyes_changed, flash_changed)
		if tiles[k] != null:
			_uniforms(tiles[k], count + k, light, awake, eyes_changed, flash_changed)
	var slot := 2 * count
	for end in 2:
		var mouth := clampf(pose.head_glow[end], 0.0, 2.0)
		for view: MeshInstance3D in _head_meshes[end]:
			_uniforms(view, slot, mouth, awake, eyes_changed, flash_changed)
			slot += 1


## Sends the glow, and the eyes and the flash when they changed, to the
## view in [param slot] - the values that moved only.
func _uniforms(view: MeshInstance3D, slot: int, glow: float, awake: float, eyes_changed: bool, flash_changed: bool) -> void:
	if absf(_sent_glow[slot] - glow) >= 0.005:
		_sent_glow[slot] = glow
		view.set_instance_shader_parameter(&"glow", glow)
	if eyes_changed or _sent_awake[slot] < 0.0:
		if absf(_sent_awake[slot] - awake) >= 0.005:
			_sent_awake[slot] = awake
			view.set_instance_shader_parameter(&"awake", awake)
	if flash_changed or _sent_flash[slot] < 0.0:
		if absf(_sent_flash[slot] - _flash) >= 0.005:
			_sent_flash[slot] = _flash
			view.set_instance_shader_parameter(&"flash", Flashing.hit_flash(_flash))


# --- the greybox ---------------------------------------------------------------------

## A greybox body of the model's names (its 14 segments; _setup stretches
## it like the model): cylinders for the segments and their plating, boxes
## for the skulls and jaws, the markers in the model's places.
static func _make_greybox() -> Node3D:
	var root := Node3D.new()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = CORE_WOOD
	var mosaic := StandardMaterial3D.new()
	mosaic.albedo_color = TURQUOISE
	mosaic.roughness = 0.4
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.92, 0.9, 0.84)
	var previous: Node3D = root
	for k in SerpentBody.MODEL_SEGMENTS:
		var r := SerpentBody.model_radius(k + 1)
		var seg := MeshInstance3D.new()
		seg.name = "segment_%d" % (k + 1)
		seg.mesh = _tube(r - 0.035, 0.785)
		seg.material_override = wood
		seg.position = Vector3(0.0, r, -5.25 + 0.75 * k) if k == 0 else Vector3(0.0, SerpentBody.model_radius(k + 1) - SerpentBody.model_radius(k), 0.75)
		previous.add_child(seg)
		var plate := MeshInstance3D.new()
		plate.name = "tiles_%d" % (k + 1)
		plate.mesh = _tube(r, 0.74)
		plate.material_override = mosaic
		plate.position = Vector3(0.0, 0.0, 0.01)
		seg.add_child(plate)
		var mark := Node3D.new()
		mark.name = "seg_%d" % (k + 1)
		mark.position = Vector3(0.0, 0.0, 0.375)
		seg.add_child(mark)
		if k == 0 or k == SerpentBody.MODEL_SEGMENTS - 1:
			var end := 0 if k == 0 else 1
			var flip := 1.0 if end == 1 else -1.0
			var skull := MeshInstance3D.new()
			skull.name = "skull_a" if end == 0 else "skull_b"
			var box := BoxMesh.new()
			box.size = Vector3(0.8, 0.6, 1.8)
			skull.mesh = box
			skull.material_override = bone
			skull.position = SKULL_A_REST if end == 0 else SKULL_B_REST
			# the box ahead of the pivot
			var shifted := ArrayMesh.new()
			var arrays := box.get_mesh_arrays()
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in verts.size():
				verts[i] += Vector3(0.0, 0.05, flip * 0.75)
			arrays[Mesh.ARRAY_VERTEX] = verts
			shifted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			skull.mesh = shifted
			seg.add_child(skull)
			var jaw := MeshInstance3D.new()
			jaw.name = "jaw_a" if end == 0 else "jaw_b"
			var jaw_box := BoxMesh.new()
			jaw_box.size = Vector3(0.7, 0.16, 1.5)
			var jaw_mesh := ArrayMesh.new()
			var jaw_arrays := jaw_box.get_mesh_arrays()
			var jaw_verts: PackedVector3Array = jaw_arrays[Mesh.ARRAY_VERTEX]
			for i in jaw_verts.size():
				jaw_verts[i] += Vector3(0.0, -0.1, flip * 0.75)
			jaw_arrays[Mesh.ARRAY_VERTEX] = jaw_verts
			jaw_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, jaw_arrays)
			jaw.mesh = jaw_mesh
			jaw.material_override = bone
			jaw.position = Vector3(JAW_REST.x, JAW_REST.y, flip * JAW_REST.z)
			skull.add_child(jaw)
			for marker: Array in [["head_", HEAD_MARK], ["mouth_", MOUTH_MARK]]:
				var node := Node3D.new()
				node.name = String(marker[0]) + ("a" if end == 0 else "b")
				var at: Vector3 = marker[1]
				node.position = Vector3(at.x, at.y, flip * at.z)
				skull.add_child(node)
		previous = seg
	return root


## A cylinder of [param radius] along +Z from z = 0 to [param length].
static func _tube(radius: float, length: float) -> ArrayMesh:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = length
	cylinder.radial_segments = 12
	var mesh := ArrayMesh.new()
	var arrays := cylinder.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var turn := Basis(Vector3.RIGHT, PI * 0.5)
	for i in verts.size():
		verts[i] = turn * verts[i] + Vector3(0.0, 0.0, length * 0.5)
		normals[i] = turn * normals[i]
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
