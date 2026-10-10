class_name GreyboxArt
## Stand-ins for the relief figures' art when the models are off (the
## awakening slab, the thrown spear): primitive meshes wearing the exhibit
## shader (awake rim, telegraph glow, hit flash, two-sided debris) on small
## texture sets made here in code and registered with ArtLibrary
## (register_generated), so they read like the other exhibits:
## - "grey_alabaster": the Assyrian palace gypsum, blue-grey with chisel
##   strokes,
## - "grey_bronze": dark bronze with green patina.

const SIZE := 64


## The exhibit material of generated set [param set_name] (made on first use).
static func material(set_name: String) -> ShaderMaterial:
	if ArtLibrary.texture(set_name, "albedo") == null:
		_generate(set_name)
	return ArtLibrary.exhibit_material(set_name)


## A named part: [param mesh] at [param at] (turned [param rot_deg]) under
## [param parent], wearing [param mat].
static func part(parent: Node3D, part_name: String, mesh: Mesh, at: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.name = part_name
	view.mesh = mesh
	view.position = at
	view.rotation_degrees = rot_deg
	view.set_surface_override_material(0, mat)
	parent.add_child(view)
	return view


static func box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func cylinder(top: float, bottom: float, height: float, segments: int = 16) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


static func _generate(set_name: String) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = hash(set_name) & 0xffff
	noise.frequency = 0.06
	noise.fractal_octaves = 3
	var albedo := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			albedo.set_pixel(x, y, _texel(set_name, x, y, noise.get_noise_2d(x, y)))
	albedo.generate_mipmaps()
	var orm := Image.create_empty(4, 4, false, Image.FORMAT_RGB8)
	orm.fill(Color(1.0, 0.5 if set_name == "grey_bronze" else 0.72, 0.0))
	orm.generate_mipmaps()
	ArtLibrary.register_generated(set_name, {
		"albedo": ImageTexture.create_from_image(albedo),
		"orm": ImageTexture.create_from_image(orm),
	})


## One texel of [param set_name] at ([param x], [param y]) with noise
## [param n] (-1..1).
static func _texel(set_name: String, x: int, y: int, n: float) -> Color:
	if set_name == "grey_bronze":
		var bronze := Color(0.42, 0.28, 0.14).lerp(Color(0.62, 0.45, 0.24), 0.5 + 0.5 * n)
		return bronze.lerp(Color(0.26, 0.45, 0.38), smoothstep(0.25, 0.6, n))
	var base := Color(0.62, 0.66, 0.68).lerp(Color(0.74, 0.76, 0.76), 0.5 + 0.5 * n)
	var stroke := 0.06 * sin((x + y * 0.35) * 1.7 + n * 3.0)
	return Color(base.r + stroke, base.g + stroke, base.b + stroke)
