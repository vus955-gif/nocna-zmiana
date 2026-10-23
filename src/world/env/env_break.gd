class_name EnvBreak
## Helpers the environment's props share (plan docs/superpowers/plans/
## 2026-10-21-srodowisko-walka.md): the bounds of a look, its glass, a look
## breaking into debris of its own mesh (MeshShards, Fx.piece) or into
## plain chunks (Fx.chunk) - never more than EnvRules.MAX_PIECES_PER_BREAK
## at once; Fx keeps the total and clears them away.

const GLASS_COLOR := Color(0.82, 0.93, 1.0)

static var _invisible: ShaderMaterial = null


## Every MeshInstance3D under [param node] (itself included) that draws.
static func views(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node)
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		if view.mesh != null:
			out.append(view)
	return out


## The box (in [param frame]'s space) round [param list] of views (in the
## tree); an empty AABB when there are none.
static func bounds(list: Array, frame: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	var inverse := frame.affine_inverse()
	for each: MeshInstance3D in list:
		var placed := inverse * each.global_transform * each.get_aabb()
		box = placed if first else box.merge(placed)
		first = false
	return box


## True for a see-through material: the art library's "glass", the
## greybox's glass, any other alpha-blended material that is mostly clear.
static func is_glass(mat: Material) -> bool:
	if mat == null:
		return false
	if mat == LevelKit.glass() or mat.resource_name == "glass":
		return true
	var base := mat as BaseMaterial3D
	return base != null and base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and base.albedo_color.a <= 0.5


## The glass of [param look]: [view, surface] pairs (surface -1: the whole
## view is glass).
static func glass_of(look: Node) -> Array:
	var out: Array = []
	for view in views(look):
		var count := view.mesh.get_surface_count()
		var found: Array[int] = []
		for i in count:
			if is_glass(view.get_active_material(i)):
				found.append(i)
		if found.is_empty():
			continue
		if found.size() == count:
			out.append([view, -1])
		else:
			for i in found:
				out.append([view, i])
	return out


## Hides the glass [param panes] (glass_of()).
static func hide_panes(panes: Array) -> void:
	for pane: Array in panes:
		var view := pane[0] as MeshInstance3D
		if not is_instance_valid(view):
			continue
		if int(pane[1]) < 0:
			view.visible = false
		else:
			view.set_surface_override_material(int(pane[1]), invisible())


## A material that draws nothing (one surface of a model gone: its glass).
static func invisible() -> ShaderMaterial:
	if _invisible == null:
		var shader := Shader.new()
		shader.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled, shadows_disabled;\nvoid fragment() { discard; }\n"
		_invisible = ShaderMaterial.new()
		_invisible.shader = shader
	return _invisible


## [param count] chunks of glass flying from [param at] along [param push].
static func glass_chunks(at: Vector3, box: AABB, frame: Transform3D, push: Vector3, count: int) -> void:
	for i in mini(count, EnvRules.MAX_PIECES_PER_BREAK):
		var local := box.position + Vector3(randf(), randf(), randf()) * box.size
		var from := frame * local
		var fling := push * randf_range(1.0, 2.6) + Vector3(randf_range(-1.2, 1.2), randf_range(0.2, 1.8), randf_range(-1.2, 1.2))
		Fx.chunk(from if box.size != Vector3.ZERO else at, GLASS_COLOR, randf_range(0.04, 0.09), fling)


## [param view] breaks into up to [param count] pieces of its own mesh,
## flung along [param push] (debris of its own look). Returns how many.
static func shards(view: MeshInstance3D, count: int, push: Vector3, spin: float = 6.0) -> int:
	if view == null or view.mesh == null or not view.is_inside_tree():
		return 0
	var materials: Array = []
	for i in view.mesh.get_surface_count():
		materials.append(view.get_active_material(i))
	var made := 0
	for piece: MeshShards.Piece in MeshShards.slices(view.mesh, clampi(count, 1, EnvRules.MAX_PIECES_PER_BREAK)):
		if piece == null or piece.mesh == null:
			continue
		var fling := push * randf_range(0.6, 1.2) + Vector3(randf_range(-1.0, 1.0), randf_range(0.5, 1.6), randf_range(-1.0, 1.0))
		Fx.piece(piece, MeshShards.materials_for(piece, materials), view.global_transform, fling, spin)
		made += 1
	return made


## Plain chunks of [param color] at [param at] (a look without a mesh of
## its own to break).
static func chunks(at: Vector3, color: Color, count: int, size: float, push: Vector3) -> void:
	for i in mini(count, EnvRules.MAX_PIECES_PER_BREAK):
		var fling := push + Vector3(randf_range(-1.4, 1.4), randf_range(0.6, 2.2), randf_range(-1.4, 1.4))
		Fx.chunk(at + Vector3(randf_range(-0.15, 0.15), randf_range(0.0, 0.2), randf_range(-0.15, 0.15)), color, size * randf_range(0.7, 1.3), fling)


## The hit's travel, flat and normalised (FORWARD when it has none).
static func flat_push(info: DamageInfo) -> Vector3:
	var push := Vector3(info.direction.x, 0.0, info.direction.z) if info != null else Vector3.ZERO
	return push.normalized() if push.length() > 0.01 else Vector3.FORWARD


## The exhibits whose hit zones lie within [param radius] of [param at]
## (each once): receivers in the exhibits' group.
static func exhibits_near(world: Node3D, at: Vector3, radius: float) -> Array[Node]:
	var out: Array[Node] = []
	if not world.is_inside_tree():
		return out
	for zone in Hitscan.sphere_hurtboxes(world.get_world_3d().direct_space_state, at, radius):
		var receiver := zone.receiver
		if receiver != null and receiver.is_in_group(&"enemies") and not out.has(receiver) and receiver.has_method(&"take_damage"):
			out.append(receiver)
	return out
