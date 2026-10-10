class_name PaintingArt
## The gallery's portraits: TEN painted people (procedural canvases in the
## game's pixel style: 48 x 64 texels, nearest filtering), a gilded frame,
## and the eyes and mouth as separate little meshes on the canvas, so a
## living Portrait can move them while a harmless WallPainting keeps them
## still. Both are built by build() and look exactly the same asleep.
##
## Layout (local space): the origin is the middle of the canvas on the wall
## surface, -Z points out of the wall into the room, +Y up.
##
## With the Blender "portrait" model (ArtLibrary; see model()) a painting
## is that model instead: a carved gilt frame, one of six painted faces
## (CANVASES: the ten ids share them, so a sleeping Portrait and a plain
## painting of the same id look the same) and the eyes as a patch whose
## irises slide (material "portrait_eyes"). Plain paintings may also hang
## one of the SCENE_IDS (landscape, sea, still lifes: no eyes). The greybox
## built here stays the fallback when the model is off or missing.

const CANVAS_SIZE := Vector2(0.9, 1.15)
const TEXELS := Vector2i(48, 64)
const FRAME_WIDTH := 0.11
const DEPTH := 0.08
## Distance of the canvas face from the wall.
const CANVAS_Z := -0.055
## Where the painted face's features are, in texels.
const EYE_TEXEL_L := Vector2(20.5, 24.0)
const EYE_TEXEL_R := Vector2(27.5, 24.0)
const MOUTH_TEXEL := Vector2(24.0, 31.5)
const GILT := Color(0.74, 0.56, 0.22)

## hair: 0 powdered wig, 1 dark parted, 2 hat, 3 bald with sides, 4 long curls.
const VARIANTS: Array[Dictionary] = [
	{"id": &"countess", "bg": Color(0.2, 0.26, 0.22), "coat": Color(0.45, 0.12, 0.16), "skin": Color(0.93, 0.8, 0.7), "hair": Color(0.88, 0.86, 0.82), "style": 0, "paint": Color(0.75, 0.1, 0.18)},
	{"id": &"admiral", "bg": Color(0.14, 0.17, 0.3), "coat": Color(0.1, 0.14, 0.32), "skin": Color(0.86, 0.68, 0.56), "hair": Color(0.82, 0.8, 0.78), "style": 3, "paint": Color(0.2, 0.3, 0.85)},
	{"id": &"merchant", "bg": Color(0.3, 0.22, 0.12), "coat": Color(0.12, 0.1, 0.09), "skin": Color(0.9, 0.74, 0.62), "hair": Color(0.2, 0.13, 0.08), "style": 2, "paint": Color(0.9, 0.62, 0.12)},
	{"id": &"lady_in_green", "bg": Color(0.28, 0.24, 0.2), "coat": Color(0.16, 0.4, 0.22), "skin": Color(0.95, 0.84, 0.76), "hair": Color(0.45, 0.24, 0.1), "style": 4, "paint": Color(0.2, 0.7, 0.3)},
	{"id": &"bishop", "bg": Color(0.12, 0.1, 0.1), "coat": Color(0.52, 0.08, 0.3), "skin": Color(0.88, 0.72, 0.62), "hair": Color(0.6, 0.6, 0.58), "style": 3, "paint": Color(0.65, 0.12, 0.55)},
	{"id": &"young_heir", "bg": Color(0.36, 0.3, 0.2), "coat": Color(0.62, 0.56, 0.4), "skin": Color(0.96, 0.86, 0.78), "hair": Color(0.8, 0.62, 0.3), "style": 1, "paint": Color(0.95, 0.8, 0.2)},
	{"id": &"general", "bg": Color(0.22, 0.12, 0.1), "coat": Color(0.2, 0.28, 0.18), "skin": Color(0.84, 0.64, 0.52), "hair": Color(0.15, 0.12, 0.1), "style": 1, "paint": Color(0.4, 0.55, 0.15)},
	{"id": &"widow", "bg": Color(0.18, 0.18, 0.2), "coat": Color(0.06, 0.06, 0.07), "skin": Color(0.9, 0.82, 0.78), "hair": Color(0.1, 0.09, 0.09), "style": 2, "paint": Color(0.3, 0.3, 0.35)},
	{"id": &"scholar", "bg": Color(0.3, 0.28, 0.24), "coat": Color(0.3, 0.2, 0.12), "skin": Color(0.9, 0.76, 0.66), "hair": Color(0.9, 0.9, 0.88), "style": 0, "paint": Color(0.55, 0.35, 0.15)},
	{"id": &"duchess", "bg": Color(0.1, 0.16, 0.2), "coat": Color(0.62, 0.5, 0.2), "skin": Color(0.97, 0.88, 0.82), "hair": Color(0.3, 0.16, 0.08), "style": 4, "paint": Color(0.1, 0.55, 0.6)},
]

## The model's painted face for each portrait id.
const CANVASES := {
	&"countess": "canvas_lady_fan", &"admiral": "canvas_general", &"merchant": "canvas_merchant",
	&"widow": "canvas_merchant", &"lady_in_green": "canvas_aristocrat", &"scholar": "canvas_aristocrat",
	&"bishop": "canvas_bishop", &"general": "canvas_bishop", &"young_heir": "canvas_child_dog",
	&"duchess": "canvas_child_dog",
}
## Pictures without a face, for plain paintings only (canvas_<id>).
const SCENE_IDS: Array[StringName] = [&"landscape", &"seascape", &"still_life", &"flowers"]
## The paint a portrait with each face spits (its dominant colour).
const CANVAS_PAINT := {
	"canvas_aristocrat": Color(0.22, 0.62, 0.3), "canvas_lady_fan": Color(0.25, 0.45, 0.92),
	"canvas_general": Color(0.85, 0.15, 0.1), "canvas_child_dog": Color(0.95, 0.72, 0.2),
	"canvas_bishop": Color(0.82, 0.1, 0.22), "canvas_merchant": Color(0.62, 0.42, 0.2),
}
## The model's layout in painting space (-Z into the room): outer frame
## size, depth off the wall, the eyes (centre, half the distance between
## them), the painted mouth, the canvas face, the canvas size, the cheeks
## (the colour of shut lids).
const MODEL_OUTER := Vector2(1.0, 1.19)
const MODEL_DEPTH := 0.145
const MODEL_EYES := Vector2(0.0, 0.195)
const MODEL_EYE_SPREAD := 0.034
const MODEL_MOUTH := Vector2(0.0, 0.12)
const MODEL_CANVAS_Z := -0.03
const MODEL_CANVAS_SIZE := Vector2(0.72, 0.9)
const MODEL_CHEEK := Vector2(0.034, 0.172)

static var _textures: Dictionary = {}
static var _materials: Dictionary = {}
static var _skins: Dictionary = {}


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry in VARIANTS:
		out.append(entry["id"])
	return out


## The variant with [param id] (the first one for an unknown id).
static func variant(id: StringName) -> Dictionary:
	for entry in VARIANTS:
		if entry["id"] == id:
			return entry
	return VARIANTS[0]


## The paint this portrait spits (its signature colour: the model's face's,
## or the greybox variant's).
static func paint_color(id: StringName) -> Color:
	if has_model():
		return CANVAS_PAINT.get(canvas_for(id), variant(id)["paint"])
	return variant(id)["paint"]


## True when paintings are the Blender model (see [method model]).
static func has_model() -> bool:
	return ArtLibrary.has_model(&"portrait")


## The model's canvas for painting [param id]: a face for the portrait ids,
## the picture itself for SCENE_IDS.
static func canvas_for(id: StringName) -> String:
	if SCENE_IDS.has(id):
		return "canvas_" + String(id)
	return CANVASES.get(id, CANVASES[&"countess"])


## True when painting [param id] shows a face (the model's eyes show).
static func has_face(id: StringName) -> bool:
	return ArtLibrary.PORTRAIT_FACES.has(canvas_for(id))


## The painting model for [param id], turned to face the room (-Z), or null
## (greybox). With [param exhibit] it wears the exhibit shader (a Portrait:
## rim, telegraph, hit flash). On a scene the eyes are hidden.
static func model(id: StringName, exhibit: bool = false) -> Node3D:
	if not has_model():
		return null
	var swap := {"canvas_aristocrat": canvas_for(id)}
	var root := ArtLibrary.exhibit(&"portrait", swap) if exhibit else ArtLibrary.model("portrait", swap)
	root.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var eyes := root.find_child("eyes", true, false) as Node3D
	if eyes != null:
		eyes.visible = has_face(id)
	return root


## Painting-space point of the model's eye on [param side] (+1 = +X, the
## viewer's left), on the canvas.
static func model_eye(side: float) -> Vector3:
	return Vector3(MODEL_EYES.x + side * MODEL_EYE_SPREAD, MODEL_EYES.y, MODEL_CANVAS_Z)


## The colour of the painted face round the eyes (for shut lids).
static func skin_color(canvas: String) -> Color:
	if _skins.has(canvas):
		return _skins[canvas]
	var skin := Color(0.85, 0.72, 0.6)
	var texture := ArtLibrary.texture(canvas, "albedo")
	var image: Image = null
	if texture != null:
		image = texture.get_image()
	if image != null and not image.is_empty():
		if image.is_compressed():
			image.decompress()
		var sum := Color(0.0, 0.0, 0.0)
		for side: float in [-1.0, 1.0]:
			var u := 0.5 + side * MODEL_CHEEK.x / MODEL_CANVAS_SIZE.x
			var v := 0.5 - MODEL_CHEEK.y / MODEL_CANVAS_SIZE.y
			var x := clampi(int(u * image.get_width()), 0, image.get_width() - 1)
			var y := clampi(int(v * image.get_height()), 0, image.get_height() - 1)
			var c := image.get_pixel(x, y)
			sum = Color(sum.r + c.r * 0.5, sum.g + c.g * 0.5, sum.b + c.b * 0.5)
		skin = sum
	_skins[canvas] = skin
	return skin


## Local point (x, y; metres from the canvas centre) of a texel. Seen from
## the room (looking along +Z) the texture's right is the painting's -X.
static func canvas_point(texel: Vector2) -> Vector2:
	return Vector2(-(texel.x / TEXELS.x - 0.5) * CANVAS_SIZE.x, (0.5 - texel.y / TEXELS.y) * CANVAS_SIZE.y)


## Builds the painting under [param parent]; the frame gets
## [param frame_material] (a Portrait passes one that can glow). Returns its
## parts by name: canvas, frame, eye_l, eye_r, pupil_l, pupil_r, lid_l,
## lid_r, mouth.
static func build(parent: Node3D, id: StringName, frame_material: Material = null) -> Dictionary:
	var parts := {}
	var look := variant(id)
	var gilt := frame_material if frame_material != null else _flat(GILT, 0.35, 0.6)
	var frame := Node3D.new()
	frame.name = "frame"
	parent.add_child(frame)
	parts["frame"] = frame
	var outer := CANVAS_SIZE + Vector2.ONE * FRAME_WIDTH * 2.0
	# four gilded bars with a darker inner lip, and the backing board
	for side in [-1.0, 1.0]:
		_box(frame, Vector3(outer.x, FRAME_WIDTH, DEPTH), Vector3(0.0, side * (CANVAS_SIZE.y + FRAME_WIDTH) * 0.5, -DEPTH * 0.5), gilt)
		_box(frame, Vector3(FRAME_WIDTH, CANVAS_SIZE.y, DEPTH), Vector3(side * (CANVAS_SIZE.x + FRAME_WIDTH) * 0.5, 0.0, -DEPTH * 0.5), gilt)
		_box(frame, Vector3(CANVAS_SIZE.x + 0.02, 0.02, 0.02), Vector3(0.0, side * (CANVAS_SIZE.y * 0.5 + 0.005), CANVAS_Z - 0.01), _flat(GILT.darkened(0.45), 0.5, 0.3))
		_box(frame, Vector3(0.02, CANVAS_SIZE.y, 0.02), Vector3(side * (CANVAS_SIZE.x * 0.5 + 0.005), 0.0, CANVAS_Z - 0.01), _flat(GILT.darkened(0.45), 0.5, 0.3))
	# ornaments in the corners
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			_box(frame, Vector3(0.09, 0.09, 0.03), Vector3(x * (outer.x - FRAME_WIDTH) * 0.5, y * (outer.y - FRAME_WIDTH) * 0.5, -DEPTH - 0.012), gilt)
	_box(frame, Vector3(CANVAS_SIZE.x, CANVAS_SIZE.y, 0.02), Vector3(0.0, 0.0, -0.02), _flat(Color(0.12, 0.09, 0.07), 0.9, 0.0))
	var canvas := MeshInstance3D.new()
	canvas.name = "canvas"
	var quad := QuadMesh.new()
	quad.size = CANVAS_SIZE
	canvas.mesh = quad
	canvas.position = Vector3(0.0, 0.0, CANVAS_Z)
	canvas.rotation.y = PI   # the quad faces +Z; the painting faces -Z
	canvas.material_override = canvas_material(id)
	parent.add_child(canvas)
	parts["canvas"] = canvas
	# eyes: whites, pupils (a Portrait moves them), lids (shut when stunned)
	var skin: Color = look["skin"]
	for side in ["l", "r"]:
		var at := canvas_point(EYE_TEXEL_L if side == "l" else EYE_TEXEL_R)
		var white := _box(parent, Vector3(0.042, 0.022, 0.004), Vector3(at.x, at.y, CANVAS_Z - 0.003), _flat(Color(0.86, 0.83, 0.74), 0.6, 0.0))
		white.name = "eye_" + side
		parts["eye_" + side] = white
		var pupil := _box(parent, Vector3(0.017, 0.017, 0.004), Vector3(at.x, at.y, CANVAS_Z - 0.006), _flat(Color(0.08, 0.06, 0.05), 0.4, 0.0))
		pupil.name = "pupil_" + side
		parts["pupil_" + side] = pupil
		var lid := _box(parent, Vector3(0.046, 0.026, 0.004), Vector3(at.x, at.y, CANVAS_Z - 0.009), _flat(skin.darkened(0.12), 0.7, 0.0))
		lid.name = "lid_" + side
		lid.visible = false
		parts["lid_" + side] = lid
	var mouth_at := canvas_point(MOUTH_TEXEL)
	var mouth := _box(parent, Vector3(0.05, 0.012, 0.004), Vector3(mouth_at.x, mouth_at.y, CANVAS_Z - 0.003), mouth_material(id))
	mouth.name = "mouth"
	parts["mouth"] = mouth
	return parts


## Shared unshaded-looking canvas material of a variant (lit by the scene;
## nearest texels like every baked texture).
static func canvas_material(id: StringName) -> StandardMaterial3D:
	var key := "canvas_%s" % id
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_texture = canvas_texture(id)
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		material.roughness = 0.75
		_materials[key] = material
	return _materials[key]


## A dark mouth; a Portrait gets its own copy that glows with its paint.
static func mouth_material(id: StringName) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.05, 0.05)
	material.emission_enabled = true
	material.emission = paint_color(id)
	material.emission_energy_multiplier = 0.0
	return material


static func canvas_texture(id: StringName) -> ImageTexture:
	if not _textures.has(id):
		_textures[id] = ImageTexture.create_from_image(_paint(variant(id)))
	return _textures[id]


## Paints one portrait: background, shoulders and coat, collar, neck, face
## with shading, hair by style, painted eyes and lips, varnish and cracks.
static func _paint(look: Dictionary) -> Image:
	var w := TEXELS.x
	var h := TEXELS.y
	var image := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(look["id"]))
	var bg: Color = look["bg"]
	var coat: Color = look["coat"]
	var skin: Color = look["skin"]
	var hair: Color = look["hair"]
	var style: int = look["style"]
	for y in h:
		for x in w:
			var c := bg.lightened(0.12).lerp(bg.darkened(0.45), float(y) / h)
			# a lighter glow behind the sitter's head
			var glow := 1.0 - clampf(Vector2(x - 24, y - 24).length() / 26.0, 0.0, 1.0)
			c = c.lerp(bg.lightened(0.3), glow * 0.35)
			image.set_pixel(x, y, _brush(c, rng, 0.05))
	# shoulders and coat
	for y in range(40, h):
		var half := 10.0 + (y - 40) * 0.9
		for x in w:
			if absf(x - 23.5) <= half:
				var shade := 0.25 * absf(x - 23.5) / half
				image.set_pixel(x, y, _brush(coat.darkened(shade), rng, 0.06))
	# collar or lace at the throat
	for y in range(39, 46):
		for x in range(20, 28):
			if absf(x - 23.5) <= (45 - y) * 0.6:
				image.set_pixel(x, y, _brush(Color(0.9, 0.88, 0.82), rng, 0.05))
	# neck
	for y in range(33, 40):
		for x in range(21, 27):
			image.set_pixel(x, y, _brush(skin.darkened(0.15), rng, 0.04))
	# face: an oval, lit from the left
	for y in range(14, 36):
		for x in range(14, 34):
			var d := Vector2((x - 24.0) / 8.0, (y - 25.5) / 10.0)
			if d.length() <= 1.0:
				var shade := clampf((x - 20.0) / 14.0, 0.0, 1.0) * 0.28
				image.set_pixel(x, y, _brush(skin.darkened(shade), rng, 0.03))
	_hair(image, rng, style, hair)
	# painted eye sockets, brows and lips (the real eyes sit on top)
	for eye in [EYE_TEXEL_L, EYE_TEXEL_R]:
		for dx in range(-2, 2):
			image.set_pixel(int(eye.x) + dx, int(eye.y) - 2, hair.darkened(0.3))
			image.set_pixel(int(eye.x) + dx, int(eye.y) + 1, skin.darkened(0.25))
	for dx in range(-2, 2):
		image.set_pixel(int(MOUTH_TEXEL.x) + dx, int(MOUTH_TEXEL.y), Color(0.55, 0.2, 0.2))
	image.set_pixel(24, 28, skin.darkened(0.3))   # the nose's shadow
	image.set_pixel(24, 29, skin.darkened(0.3))
	# old varnish: darker corners, a few craquelure lines
	for y in h:
		for x in w:
			var edge := Vector2((x - w * 0.5) / (w * 0.5), (y - h * 0.5) / (h * 0.5)).length()
			var c := image.get_pixel(x, y).darkened(clampf((edge - 0.7) * 0.6, 0.0, 0.35))
			image.set_pixel(x, y, c.lerp(Color(0.55, 0.42, 0.2), 0.08))
	for i in 5:
		var x := rng.randi_range(2, w - 3)
		var y := rng.randi_range(2, h - 3)
		for step in 6:
			x = clampi(x + rng.randi_range(-1, 1), 0, w - 1)
			y = clampi(y + 1, 0, h - 1)
			image.set_pixel(x, y, image.get_pixel(x, y).darkened(0.25))
	return image


static func _hair(image: Image, rng: RandomNumberGenerator, style: int, hair: Color) -> void:
	for y in range(6, 44):
		for x in range(8, 40):
			var on := false
			match style:
				0:   # powdered wig: a big pale mass with side rolls
					on = (Vector2((x - 24.0) / 10.5, (y - 21.0) / 9.0).length() <= 1.0 and y < 21) \
						or (absf(x - 24.0) > 7.5 and absf(x - 24.0) < 11.0 and y >= 18 and y < 32)
				1:   # short dark hair with a parting
					on = Vector2((x - 24.0) / 8.8, (y - 18.0) / 5.5).length() <= 1.0 and y < 19 and x != 21
				2:   # a dark hat with a brim
					on = (y >= 8 and y < 16 and absf(x - 24.0) <= 7.0) or (y >= 15 and y < 18 and absf(x - 24.0) <= 12.0)
				3:   # bald crown, grey hair at the sides
					on = absf(x - 24.0) > 7.0 and absf(x - 24.0) < 9.5 and y >= 20 and y < 29
				4:   # long curls over the shoulders
					on = (Vector2((x - 24.0) / 9.5, (y - 19.0) / 6.5).length() <= 1.0 and y < 20) \
						or (absf(x - 24.0) > 7.0 and absf(x - 24.0) < 12.0 and y >= 18 and y < 43 and (x + y) % 3 != 0)
			if on:
				image.set_pixel(x, y, _brush(hair.darkened(0.1 * float((x + y) % 2)), rng, 0.05))


static func _brush(c: Color, rng: RandomNumberGenerator, amount: float) -> Color:
	var n := rng.randf_range(-amount, amount)
	return Color(clampf(c.r + n, 0.0, 1.0), clampf(c.g + n, 0.0, 1.0), clampf(c.b + n * 0.8, 0.0, 1.0))


static func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	view.position = at
	parent.add_child(view)
	return view


static func _flat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f" % [color.to_html(), roughness, metallic]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		material.metallic = metallic
		_materials[key] = material
	return _materials[key]
