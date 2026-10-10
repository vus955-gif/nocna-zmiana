class_name LockArt
## Shared looks of the gate locks: the game's tile textures (boards, brick,
## timber, brass...) mapped in the piece's own space, so a plank flying off
## keeps its grain; forged iron; chain runs of torus links; a procedural
## crack decal; the debris helper that throws a box piece with its own
## material. Everything is cached and shared.

const IRON := Color(0.2, 0.2, 0.21)
const RUST := Color(0.36, 0.2, 0.12)
const BRASS := Color(0.78, 0.6, 0.28)
const ROPE := Color(0.5, 0.38, 0.22)
const STEEL := Color(0.42, 0.44, 0.46)
const LINK_RADIUS := 0.045
const LINK_THICKNESS := 0.016

static var _materials: Dictionary = {}
static var _crack_texture: Texture2D = null


## A tile texture set ([param tex_name], e.g. "boards", "brick", "timber")
## mapped in object space, one repeat per [param metres]; [param tint]
## multiplies it. A flat [param fallback] colour when the textures are
## missing.
static func tile(tex_name: String, metres: float, fallback: Color, tint: Color = Color.WHITE) -> BaseMaterial3D:
	var key := "tile:%s:%.2f:%s" % [tex_name, metres, tint.to_html()]
	if _materials.has(key):
		return _materials[key]
	var albedo := ArtLibrary.texture(tex_name, "albedo") if ArtLibrary.models_enabled else null
	var mat: BaseMaterial3D
	if albedo == null:
		mat = StandardMaterial3D.new()
		mat.albedo_color = fallback * tint
		mat.roughness = 0.8
	else:
		var orm := ORMMaterial3D.new()
		orm.texture_filter = ArtLibrary.FILTER
		orm.albedo_texture = albedo
		orm.albedo_color = tint
		orm.orm_texture = ArtLibrary.texture(tex_name, "orm")
		var normal := ArtLibrary.texture(tex_name, "normal")
		if normal != null:
			orm.normal_enabled = true
			orm.normal_texture = normal
		orm.uv1_triplanar = true
		orm.uv1_world_triplanar = false
		orm.uv1_triplanar_sharpness = 40.0
		orm.uv1_scale = Vector3.ONE / metres
		mat = orm
	mat.resource_name = tex_name
	_materials[key] = mat
	return mat


## Forged metal in [param color] (iron, brass, steel).
static func metal(color: Color, roughness: float = 0.45) -> StandardMaterial3D:
	var key := "metal:%s:%.2f" % [color.to_html(), roughness]
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.metallic = 0.85
		mat.roughness = roughness
		_materials[key] = mat
	return _materials[key]


## A matte material in [param color] (rope, paint).
static func matte(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var key := "matte:%s:%.2f" % [color.to_html(), roughness]
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = roughness
		_materials[key] = mat
	return _materials[key]


## A self-lit lamp glass (the shutter's red / green lamp).
static func lamp(color: Color) -> StandardMaterial3D:
	var key := "lamp:%s" % color.to_html()
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color.darkened(0.5)
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 3.0
		_materials[key] = mat
	return _materials[key]


static func box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = mat
	view.position = at
	view.rotation_degrees = rot_deg
	parent.add_child(view)
	return view


## A cylinder of [param radius] from [param from] to [param to].
static func rod(parent: Node3D, radius: float, from: Vector3, to: Vector3, mat: Material, sides: int = 8) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = maxf(from.distance_to(to), 0.001)
	mesh.radial_segments = sides
	mesh.rings = 1
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = mat
	var along := (to - from).normalized() if from.distance_to(to) > 0.0001 else Vector3.UP
	var side := along.cross(Vector3.FORWARD if absf(along.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	view.transform = Transform3D(Basis(side, along, side.cross(along)).orthonormalized(), (from + to) * 0.5)
	parent.add_child(view)
	return view


## A ring of [param radius] lying in the plane facing [param normal].
static func ring(parent: Node3D, radius: float, thickness: float, at: Vector3, normal: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 14
	mesh.ring_segments = 6
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = mat
	var up := normal.normalized()
	var side := up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.95 else Vector3.FORWARD).normalized()
	view.transform = Transform3D(Basis(side, up, side.cross(up)).orthonormalized(), at)
	parent.add_child(view)
	return view


## A run of chain links from [param from] to [param to] (every other link
## turned a quarter), under [param parent]; returns the links.
static func chain(parent: Node3D, from: Vector3, to: Vector3, mat: Material) -> Array[MeshInstance3D]:
	var links: Array[MeshInstance3D] = []
	var run := to - from
	var count := maxi(roundi(run.length() / (LINK_RADIUS * 1.55)), 2)
	var along := run.normalized()
	var up := Vector3.UP if absf(along.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var basis := Basis.looking_at(along, up)
	var torus := TorusMesh.new()
	torus.inner_radius = LINK_RADIUS - LINK_THICKNESS
	torus.outer_radius = LINK_RADIUS + LINK_THICKNESS
	torus.rings = 8
	torus.ring_segments = 5
	for i in count:
		var link := MeshInstance3D.new()
		link.mesh = torus
		link.material_override = mat
		var squash := Basis.from_scale(Vector3(1.0, 1.0, 1.45))
		link.transform = Transform3D(basis * Basis(Vector3.BACK, PI * 0.5 * (i % 2)) * Basis(Vector3.RIGHT, PI * 0.5) * squash,
				from + run * (i + 0.5) / count)
		parent.add_child(link)
		links.append(link)
	return links


## A padlock (body, shackle, keyhole) at [param at], facing -Z.
static func padlock(parent: Node3D, at: Vector3, scale_: float = 1.0) -> Node3D:
	var lock := Node3D.new()
	lock.name = "Padlock"
	lock.position = at
	lock.scale = Vector3.ONE * scale_
	parent.add_child(lock)
	box(lock, Vector3(0.12, 0.13, 0.05), Vector3(0.0, -0.03, 0.0), metal(BRASS.darkened(0.15), 0.38))
	ring(lock, 0.045, 0.012, Vector3(0.0, 0.05, 0.0), Vector3.BACK, metal(STEEL, 0.35))
	box(lock, Vector3(0.012, 0.03, 0.004), Vector3(0.0, -0.04, -0.026), matte(Color(0.05, 0.04, 0.03)))
	return lock


## Throws [param view] (a box-meshed MeshInstance3D in the tree) off as a
## physical piece of debris with its own material, moving at
## [param velocity]; the view itself is hidden.
static func throw_piece(view: MeshInstance3D, velocity: Vector3, spin: float = 6.0) -> void:
	var source := view.mesh
	if source == null or not view.is_inside_tree():
		return
	var shard := MeshShards.Piece.new()
	shard.mesh = source
	shard.surfaces = PackedInt32Array([0])
	shard.size = source.get_aabb().size
	shard.center = source.get_aabb().get_center()
	shard.offset = -shard.center
	var materials: Array[Material] = [view.material_override if view.material_override != null else view.get_active_material(0)]
	Fx.piece(shard, materials, view.global_transform, velocity, spin)
	view.visible = false


## A dark, jagged crack pattern (white lines on transparent, drawn once)
## for a Decal's albedo.
static func crack_texture() -> Texture2D:
	if _crack_texture != null:
		return _crack_texture
	var size := 256
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4519
	var center := Vector2(size * 0.5, size * 0.55)
	for branch in 9:
		var at := center + Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-10.0, 10.0))
		var heading := TAU * branch / 9.0 + rng.randf_range(-0.3, 0.3)
		var width := 3.0
		for step in 70:
			heading += rng.randf_range(-0.45, 0.45)
			at += Vector2(cos(heading), sin(heading)) * 2.2
			if at.x < 2.0 or at.y < 2.0 or at.x > size - 3.0 or at.y > size - 3.0:
				break
			_dot(image, at, width)
			width = maxf(width - 0.035, 0.8)
			if step % 23 == 22 and rng.randf() < 0.6:
				var twig := at
				var twig_heading := heading + rng.randf_range(-1.2, 1.2)
				for k in 18:
					twig_heading += rng.randf_range(-0.5, 0.5)
					twig += Vector2(cos(twig_heading), sin(twig_heading)) * 2.0
					if twig.x < 2.0 or twig.y < 2.0 or twig.x > size - 3.0 or twig.y > size - 3.0:
						break
					_dot(image, twig, 0.9)
	_crack_texture = ImageTexture.create_from_image(image)
	return _crack_texture


static func _dot(image: Image, at: Vector2, radius: float) -> void:
	var r := ceili(radius)
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var p := Vector2i(roundi(at.x) + x, roundi(at.y) + y)
			if Vector2(x, y).length() <= radius and p.x >= 0 and p.y >= 0 and p.x < image.get_width() and p.y < image.get_height():
				image.set_pixelv(p, Color(0.05, 0.04, 0.035, 0.95))
