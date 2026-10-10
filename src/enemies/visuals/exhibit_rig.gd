class_name ExhibitRig
extends Node3D
## The Blender model of an awakened exhibit (ArtLibrary.exhibit), animated
## in code: no skeletons, the jointed parts of the model turn about their
## pivots. Each subclass poses its parts from the enemy's state in
## [method _pose] (walk cycle from the distance covered, windup, strike,
## stun...). The base
## - keeps the weak point on its part: a tracked hurtbox follows the head
##   however it bobs, leans or sags;
## - lights the model through per-instance shader uniforms: on waking a
##   faint cool rim and brighter eyes (readable in a dark corner), the
##   attack telegraph (warm glow from inside), a white flash per hit;
## - breaks it apart on death: the parts fly as debris, or, on heavy
##   overkill, torn into smaller slices of themselves.
## Enemy subclasses make one in _build_body() (null = the model is off or
## missing: they keep their greybox). It lives under Enemy.visual, so the
## base lean and a wax figure's melt sag carry the model too.

## Seconds a hit flash lasts.
const FLASH_TIME := 0.12
## Seconds the wake rim takes to come up.
const WAKE_TIME := 0.7
## Torn (gibbed) parts: slices per metre of the part's longest side.
const GIB_SLICES_PER_METRE := 4.0
const GIB_MAX_SLICES := 4
## Physics frames a dormant exhibit keeps easing to its rest pose before
## the rig stops posing it.
const DORMANT_SETTLE_FRAMES := 90

var enemy: Enemy
var model: Node3D
## Part name -> node (MeshInstance3D, or a marker).
var parts: Dictionary = {}
## Part name -> its rest transform (local); poses are applied on top.
var rest: Dictionary = {}
var meshes: Array[MeshInstance3D] = []
## Animation clock (s).
var time: float = 0.0
## Walk cycle angle (rad): advances with the ground covered.
var walk_phase: float = 0.0
## 0 standing .. 1 walking at full speed (eased).
var gait: float = 0.0
## Seconds since the strike of the current attack (-1 outside one).
var since_strike: float = -1.0
## Slices per metre when torn apart (brittle marble breaks finer).
var gib_density: float = GIB_SLICES_PER_METRE
## Metres of ground per full walk cycle.
var cycle_length: float = 1.6
## Speed (m/s) counted as a full walk.
var full_speed: float = 2.5

## [hurtbox, part, offset in the part's space]
var _tracked: Array = []
## Part mesh -> how many slices it tears into (fixed at attach, so the cut
## prepared ahead is the cut a heavy kill uses, whatever the pose).
var _slices: Dictionary = {}
var _awake: float = 0.0
var _flash: float = 0.0
var _last_health: float = -1.0
var _shading := Vector3(-1.0, -1.0, -1.0)
var _last_position := Vector3.ZERO
var _placed := false
var _still_frames: int = 0

## Merged part meshes (merge_into), shared by every instance: "base+extra"
## mesh ids -> ArrayMesh.
static var _merged: Dictionary = {}


## Puts [param rig] (a new subclass instance) with model [param id] under
## [param owner_enemy]'s visual. Returns null (and frees the rig) when the
## model is off or missing.
static func attach(owner_enemy: Enemy, rig: ExhibitRig, id: StringName, offset: Transform3D = Transform3D.IDENTITY) -> ExhibitRig:
	return attach_model(owner_enemy, rig, ArtLibrary.exhibit(id), offset)


## [method attach] with a model already dressed (ArtLibrary.exhibit, e.g.
## with swapped materials); null [param loaded] frees the rig.
static func attach_model(owner_enemy: Enemy, rig: ExhibitRig, loaded: Node3D, offset: Transform3D = Transform3D.IDENTITY) -> ExhibitRig:
	if loaded == null:
		rig.free()
		return null
	rig.name = "Rig"
	rig.enemy = owner_enemy
	rig.model = loaded
	loaded.transform = offset
	rig.add_child(loaded)
	rig._arrange()
	for node in loaded.find_children("*", "Node3D", true, false):
		rig.parts[String(node.name)] = node
		rig.rest[String(node.name)] = (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			rig.meshes.append(node as MeshInstance3D)   # (a part merged into its parent keeps only its pivot)
	owner_enemy.visual.add_child(rig)
	for view in rig.meshes:
		rig._slices[view] = rig._gib_slices(rig._to_enemy(view).basis.get_scale(), view.mesh)
	rig._setup()
	# the pieces a heavy kill tears it into are cut in the background
	rig._warm_pieces()
	return rig


## Keeps [param hurtbox] (a child of the enemy) on part [param part_name]
## wherever it moves (with [param turn] it also turns with it; never
## scaled); the offset is taken now, in the rest pose.
func track(hurtbox: Hurtbox, part_name: StringName, turn: bool = false) -> void:
	var part := parts.get(String(part_name)) as Node3D
	if part == null or hurtbox == null:
		return
	var offset := _to_enemy(part).affine_inverse() * hurtbox.transform
	_tracked.append([hurtbox, part, offset, turn])


func part(part_name: String) -> Node3D:
	return parts.get(part_name) as Node3D


## Where part (or marker) [param part_name] is now, in the enemy's space
## (identity when there is no such part).
func part_transform(part_name: String) -> Transform3D:
	var node := part(part_name)
	return _to_enemy(node) if node != null else Transform3D.IDENTITY


## Poses part [param part_name]: [param euler] (radians) on top of its rest
## rotation, [param shift] on top of its rest position.
func pose_part(part_name: String, euler: Vector3, shift: Vector3 = Vector3.ZERO) -> void:
	var node := parts.get(part_name) as Node3D
	if node == null:
		return
	var base: Transform3D = rest[part_name]
	node.transform = Transform3D(base.basis * Basis.from_euler(euler), base.origin + shift)


## Where tracked [param hurtbox] belongs now (enemy space), for tests.
func tracked_position(hurtbox: Hurtbox) -> Vector3:
	for entry: Array in _tracked:
		if entry[0] == hurtbox:
			return (_to_enemy(entry[1]) * (entry[2] as Transform3D)).origin
	return hurtbox.position


## Current shader uniforms (awake, glow, flash), for tests.
func shading() -> Vector3:
	return _shading


## Called by Enemy._destroy(): particles, then every part of the model as
## debris flying mostly along [param push]; a gibbing plan tears the parts
## into slices first.
func shatter(center: Vector3, plan: GibPlanner.Plan, push: Vector3) -> void:
	Fx.shatter(center, enemy.material_kind, plan, push, false)
	var flat := Vector3(push.x, 0.0, push.z)
	flat = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.ZERO
	var carried := Vector3(enemy.velocity.x, 0.0, enemy.velocity.z) * 0.5
	# every part still on the model (a hidden parent hides its children, so
	# pick them all before any is hidden)
	var shown: Array[MeshInstance3D] = []
	for view in meshes:
		if is_instance_valid(view) and view.is_visible_in_tree():
			shown.append(view)
	for view in shown:
		var xform := view.global_transform
		var materials: Array = []
		for i in view.mesh.get_surface_count():
			materials.append(ArtLibrary.debris_material(view.get_active_material(i)))
		var pieces: Array = [MeshShards.whole(view.mesh)]
		if plan.gibbed:
			pieces = MeshShards.slices(view.mesh, slice_count(view))
		for shard: MeshShards.Piece in pieces:
			var at := xform * shard.center
			var out := at - center
			out.y = 0.0
			out = out.normalized() if out.length_squared() > 0.0001 else Vector3.ZERO
			var lift := Vector3.UP * randf_range(0.5, 1.2)
			var velocity := carried + (flat * 0.9 + out * 0.7 + lift).normalized() * plan.impulse * randf_range(0.6, 1.15)
			Fx.piece(shard, MeshShards.materials_for(shard, materials), xform, velocity, 10.0 if plan.gibbed else 5.0)
	model.visible = false


## How many slices part [param view] is torn into by a heavy kill (1 =
## it flies whole).
func slice_count(view: MeshInstance3D) -> int:
	return _slices.get(view, 1)


## How many slices a part of [param mesh] with [param scale] (its rest
## scale in the enemy's space: never its turn, so neither the pose nor a
## wax figure's sag changes it) is torn into.
func _gib_slices(scale: Vector3, mesh: Mesh) -> int:
	var size := mesh.get_aabb().size * scale.abs()
	return clampi(int(maxf(size.x, maxf(size.y, size.z)) * gib_density), 1, GIB_MAX_SLICES)


## Queues the cuts a death needs (MeshShards, cut in the background; see
## Fx.warm_up for the night start). Rigs that break apart their own way
## (PortraitRig) warm their own cuts.
func _warm_pieces() -> void:
	for view in meshes:
		MeshShards.warm_slices(view.mesh, slice_count(view))


# --- subclass hooks ---------------------------------------------------------

## Rearranges the loaded model (e.g. nests flat parts) before rest poses are
## recorded.
func _arrange() -> void:
	pass


## After attach: extra nodes, first pose.
func _setup() -> void:
	pass


## Poses the parts for this physics frame.
func _pose(_delta: float) -> void:
	pass


# --- per frame ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if enemy == null or enemy.brain.state == EnemyBrain.State.DESTROYED or enemy.is_frozen():
		return   # (turned to stone at dawn: Enemy.freeze() also stops this)
	# asleep it is a museum piece: posed once (eased to rest), then left
	# alone until it wakes
	if enemy.brain.state == EnemyBrain.State.DORMANT:
		_still_frames += 1
		if _still_frames > DORMANT_SETTLE_FRAMES:
			return
	else:
		_still_frames = 0
	time += delta
	_advance_walk(delta)
	if enemy.brain.has_struck():
		since_strike = 0.0 if since_strike < 0.0 else since_strike + delta
	else:
		since_strike = -1.0
	_pose(delta)
	_follow_parts()
	_update_shading(delta)


func _advance_walk(delta: float) -> void:
	var at := enemy.global_position
	if not _placed:
		_placed = true
		_last_position = at
	var step := Vector2(at.x - _last_position.x, at.z - _last_position.z).length()
	_last_position = at
	if step > 1.0:
		step = 0.0   # teleported (spawned, respawned)
	walk_phase = fmod(walk_phase + step / cycle_length * TAU, TAU * 64.0)
	var speed := step / maxf(delta, 0.0001)
	var target := clampf(speed / full_speed, 0.0, 1.5) if enemy.is_on_floor() else gait
	gait = lerpf(gait, target, 1.0 - exp(-8.0 * delta))


func _follow_parts() -> void:
	for entry: Array in _tracked:
		var hurtbox: Hurtbox = entry[0]
		if not is_instance_valid(hurtbox):
			continue
		var now := _to_enemy(entry[1]) * (entry[2] as Transform3D)
		if entry[3]:
			hurtbox.transform = Transform3D(now.basis.orthonormalized(), now.origin)
		else:
			hurtbox.position = now.origin


func _update_shading(delta: float) -> void:
	var goal := _awake_goal()
	# a suspicious flare (goal over 1) comes up within its short suspicion
	_awake = move_toward(_awake, goal, delta / WAKE_TIME * (2.0 if goal > 1.0 else 1.0))
	var health := enemy.health.current if enemy.health != null else 0.0
	if _last_health >= 0.0 and health < _last_health:
		_flash = 1.0
	_last_health = health
	_flash = maxf(_flash - delta / FLASH_TIME, 0.0)
	var now := Vector3(_awake, _glow_amount(), _flash)
	if now.is_equal_approx(_shading):
		return
	_shading = now
	for view in meshes:
		if is_instance_valid(view):
			view.set_instance_shader_parameter(&"awake", now.x)
			view.set_instance_shader_parameter(&"glow", now.y)
			view.set_instance_shader_parameter(&"flash", now.z)


## Telegraph strength 0..1 (the windup by default).
func _glow_amount() -> float:
	return enemy.brain.windup_progress()


## Where the wake rim is heading: 0 asleep, 1 awake, brighter while it is
## suspicious (the eyes flare when it notices something).
func _awake_goal() -> float:
	return enemy.eye_glow()


## [param node]'s transform in the enemy's space.
func _to_enemy(node: Node3D) -> Transform3D:
	var xform := node.transform
	var parent := node.get_parent() as Node3D
	while parent != null and parent != enemy:
		xform = parent.transform * xform
		parent = parent.get_parent() as Node3D
	return xform


# --- helpers for subclasses ---------------------------------------------

## Eases [param from] toward [param to] at [param rate] per second.
static func ease_to(from: float, to: float, rate: float, delta: float) -> float:
	return lerpf(from, to, 1.0 - exp(-rate * delta))


## Moves [param node] (and its subtree) under [param new_parent] keeping
## where it is (both under the same root, before anything moves).
static func nest(node: Node3D, new_parent: Node3D) -> void:
	var local := _relative(node, new_parent)
	node.owner = null
	node.get_parent().remove_child(node)
	new_parent.add_child(node)
	node.transform = local


## Merges part [param child]'s mesh into [param parent]'s (one draw call
## for both; the child keeps its node as a pivot, without a mesh). Both
## single-surface with the same material; call it from _arrange(), in the
## rest pose. Merged meshes are shared by every instance of the model.
static func merge_into(child: MeshInstance3D, parent: MeshInstance3D) -> void:
	if child == null or parent == null or child.mesh == null or parent.mesh == null:
		return
	if child.mesh.get_surface_count() != 1 or parent.mesh.get_surface_count() != 1:
		return
	var key := "%d+%d" % [parent.mesh.get_instance_id(), child.mesh.get_instance_id()]
	var merged: Mesh = _merged.get(key)
	if merged == null:
		merged = _merge_meshes(parent.mesh, child.mesh, _relative(child, parent))
		_merged[key] = merged
	var material := parent.get_surface_override_material(0)
	parent.mesh = merged
	parent.set_surface_override_material(0, material)
	child.mesh = null


static func _merge_meshes(base: Mesh, extra: Mesh, xform: Transform3D) -> ArrayMesh:
	var a := base.surface_get_arrays(0)
	var b := extra.surface_get_arrays(0)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	var va: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var vb: PackedVector3Array = b[Mesh.ARRAY_VERTEX]
	var verts := va.duplicate()
	for v in vb:
		verts.append(xform * v)
	out[Mesh.ARRAY_VERTEX] = verts
	var turn := xform.basis.orthonormalized()
	if a[Mesh.ARRAY_NORMAL] != null and b[Mesh.ARRAY_NORMAL] != null:
		var normals := (a[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
		for n in (b[Mesh.ARRAY_NORMAL] as PackedVector3Array):
			normals.append(turn * n)
		out[Mesh.ARRAY_NORMAL] = normals
	if a[Mesh.ARRAY_TANGENT] != null and b[Mesh.ARRAY_TANGENT] != null:
		var tangents := (a[Mesh.ARRAY_TANGENT] as PackedFloat32Array).duplicate()
		var tb: PackedFloat32Array = b[Mesh.ARRAY_TANGENT]
		for i in tb.size() / 4:
			var t := turn * Vector3(tb[i * 4], tb[i * 4 + 1], tb[i * 4 + 2])
			tangents.append_array(PackedFloat32Array([t.x, t.y, t.z, tb[i * 4 + 3]]))
		out[Mesh.ARRAY_TANGENT] = tangents
	for channel in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		if a[channel] != null and b[channel] != null:
			var uvs := (a[channel] as PackedVector2Array).duplicate()
			uvs.append_array(b[channel] as PackedVector2Array)
			out[channel] = uvs
	var ia := PackedInt32Array()
	if a[Mesh.ARRAY_INDEX] != null:
		ia = a[Mesh.ARRAY_INDEX]
	else:
		ia = PackedInt32Array(range(va.size()))
	var ib := PackedInt32Array()
	if b[Mesh.ARRAY_INDEX] != null:
		ib = b[Mesh.ARRAY_INDEX]
	else:
		ib = PackedInt32Array(range(vb.size()))
	var index := ia.duplicate()
	for i in ib:
		index.append(i + va.size())
	out[Mesh.ARRAY_INDEX] = index
	var built := ArrayMesh.new()
	built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	var source := base.surface_get_material(0)
	if source != null:
		built.surface_set_material(0, source)
	return built


static func _relative(node: Node3D, to: Node3D) -> Transform3D:
	return _model_space(to).affine_inverse() * _model_space(node)


static func _model_space(node: Node3D) -> Transform3D:
	var xform := node.transform
	var parent := node.get_parent() as Node3D
	while parent != null and not parent is ExhibitRig:
		xform = parent.transform * xform
		parent = parent.get_parent() as Node3D
	return xform
