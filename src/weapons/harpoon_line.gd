class_name HarpoonLine
extends MeshInstance3D
## The harpoon's tarred line: a ribbon turned to face the camera from the
## gun to the harpoon, sagging a little in the middle (more when slack).
## Rebuilt every frame from [method stretch]; top-level, so its parent's
## transform never moves it.

const SEGMENTS := 12
const WIDTH := 0.022
const COLOR := Color(0.25, 0.19, 0.12)

static var _material: StandardMaterial3D = null

var _mesh := ImmediateMesh.new()


func _init() -> void:
	top_level = true
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material_override = _line_material()
	extra_cull_margin = 64.0


## Draws the line from [param from] to [param to] with the middle hanging
## [param sag] metres below the straight run.
func stretch(from: Vector3, to: Vector3, sag: float) -> void:
	global_transform = Transform3D.IDENTITY
	_mesh.clear_surfaces()
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye := camera.global_position if camera != null else from + Vector3.UP
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		var at := from.lerp(to, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
		var along := (to - from).normalized()
		var side := along.cross(eye - at).normalized() * WIDTH * 0.5
		if side.length_squared() < 1e-8:
			side = Vector3.RIGHT * WIDTH * 0.5
		_mesh.surface_add_vertex(at - side)
		_mesh.surface_add_vertex(at + side)
	_mesh.surface_end()
	visible = true


static func _line_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = COLOR
		_material.roughness = 0.9
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material
