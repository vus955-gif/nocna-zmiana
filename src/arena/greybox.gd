class_name Greybox
## Blockout geometry: static boxes and ramps with a world-aligned 1 m grid
## texture, so distances are easy to judge while the level is grey.

static var _materials: Dictionary = {}
static var _grid: Texture2D = null


## Adds a static box centred at [param center].
static func box(parent: Node, center: Vector3, size: Vector3, color: Color, orientation: Basis = Basis.IDENTITY) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.transform = Transform3D(orientation, center)
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material(color)
	body.add_child(view)
	parent.add_child(body)
	return body


## A walkable slab whose top surface runs along its centre line from
## [param from] to [param to].
static func ramp(parent: Node, from: Vector3, to: Vector3, width: float, color: Color, thickness: float = 0.4) -> StaticBody3D:
	var run := to - from
	var orientation := Basis.looking_at(run.normalized(), Vector3.UP)
	var center := (from + to) * 0.5 - orientation.y * (thickness * 0.5)
	return box(parent, center, Vector3(width, thickness, run.length()), color, orientation)


static func material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.albedo_texture = _grid_texture()
		# keeps the grid crisp on floors seen at a grazing angle
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mat.roughness = 0.85
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		_materials[color] = mat
	return _materials[color]


static func _grid_texture() -> Texture2D:
	if _grid == null:
		var image := Image.create_empty(64, 64, false, Image.FORMAT_RGB8)
		image.fill(Color(0.92, 0.92, 0.92))
		for i in 64:
			for edge in [0, 63]:
				image.set_pixel(i, edge, Color(0.55, 0.55, 0.55))
				image.set_pixel(edge, i, Color(0.55, 0.55, 0.55))
		image.generate_mipmaps()
		_grid = ImageTexture.create_from_image(image)
	return _grid
