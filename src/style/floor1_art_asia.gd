class_name Floor1ArtAsia
extends RefCounted
## Floor I's Asian wing dressed, stage P4 (plan docs/superpowers/plans/
## 2026-10-10-p4-oprawa-asyria-azja.md section 4; catalogue
## docs/art/kit-pietro1-azja.md): red lacquer, patinated bronze, porcelain,
## paper lanterns, the moon over the Japanese garden. Pure factories of
## Node3D trees of ArtLibrary models, no collision (the greybox keeps it);
## Floor1Art asks this module for every room whose id starts with "asia_":
## - [method piece_look]: the Buddha on his dais, the bronze Fu dogs, the
##   lacquered posts, the cases with their bronzes and porcelain, lanterns on
##   their cords, the hwacha display under its marker, the bell pavilion,
##   armour stands, hanging scrolls, the garden's rocks, stone lanterns and
##   pond, the shrine's bell;
## - [method dress]: the hero pieces - the cherry tree (the General's
##   petals), the tea house's facades fitted to the garden's faces (his
##   perch kept on the eave: roof_perch), its interior, the garden's walls
##   (the tsuiji to its coping, the museum's court front over it, a pine
##   and bamboo over the coping), the armour hall's shoji, Korea's lattice
##   windows;
## - [method fixture]: andons; the tea house's paper lamp is in its model;
## - [method door_leaf]: the tea house's door is a shoji.

const Asia := preload("res://src/level/floor1/zones/asia.gd")

## Every model this module places (the art tests check each is registered,
## on disk and placed).
const MODELS: Array[String] = [
	"buddha_seated", "bronze_ding", "bronze_gu", "vase_blue_white", "vase_celadon", "moon_jar", "scroll_hanging",
	"temple_bell", "hwacha_display", "samurai_armor_stand", "fu_dog", "garden_rock_a", "garden_rock_c", "garden_pond",
	"toro_kasuga", "cherry_tree", "cherry_petals_ground", "teahouse", "teahouse_interior", "asia_lantern_red",
	"asia_lantern_floor", "asia_case_tall", "asia_plinth", "asia_post_base", "asia_post_shaft", "asia_post_capital",
	"asia_shoji_2m", "asia_lattice_window", "asia_dado_4m", "hall_pilaster_base", "hall_pilaster_shaft",
	"hall_pilaster_capital",
]
## The exhibits that stand in the open (the live Fu dogs and samurai
## armours, dormant until they wake) get a display mat under their slots: a
## lacquered floor panel with a brass plaque (the armours), a slab of stone
## (the bronze lions). Flat (no collision, no raised step: the slots'
## heights are the enemies' branch's), sized to the exhibit.
const MAT_LIFT := 0.015
const DOG_MAT := Vector2(1.6, 3.8)
const DOG_MAT_BACK := -0.22
const ARMOUR_MAT := Vector2(1.3, 1.3)
## The tea house model's frame: its origin is the centre of the room it was
## drawn for (6 x 8, east wall at x 10.5), the greybox room is 8 m wide
## (east wall 12.5) and 8 m long like the model's: scaled in x only (its east
## facade a hair before the garden's wall face at 12.5, its west face inside
## the museum's wall), 3 cm south of the room's centre (its south facade a
## hair before the wall face at -77.5), sunk so its veranda lies flush with
## the gravel. Its doorway is the greybox hole (z -83..-81, 2.6 m high) to
## the centimetre: jamb posts just outside, nothing in between.
const TEAHOUSE_AT := Vector3(8.215, -0.4, -81.97)
const TEAHOUSE_SCALE := Vector3(1.2329, 1.0, 1.0)
## Its tsukubai basin (a part of the model of its own, pivot on the ground
## under its middle) shrunk to a hand-basin round again (the house's x scale
## would make it oval) and lifted back out of the gravel the house is sunk
## in: a shallow stone ring 12 cm over the floor, its water a few cm up, the
## bamboo spout under knee height (nothing of it has collision: no wall, no
## post, nothing a guard could be stopped by in the General's arena).
const BASIN_SCALE := 0.7
const BASIN_LIFT := 0.25
## Its interior, stretched to the room's 8 m.
const INTERIOR_AT := Vector3(8.0, 0.0, -82.0)
const INTERIOR_SCALE := Vector3(1.3333, 1.0, 1.0)
## The model's own perch nodes are renamed: its ridge lies in the shell's
## mass over the tea house room (the garden's wall rises to 14 m there), so
## the General keeps the greybox perch on the eave's corner (a roof_perch
## node of this module there).
const PERCH_RENAMED := ["roof_perch", "roof_perch_eave"]
## The cherry tree stands in the greybox trunk's box.
const CHERRY_AT := Vector3(23.0, 0.0, -76.5)
const CHERRY_YAW := 0.4
## The hwacha display: its stand's cushion under the weapon marker, the cart
## behind it, its front to the porcelain arch (west).
const HWACHA_AT := Vector3(47.4, 0.0, -51.0)
const HWACHA_YAW := PI * 0.5
## Lit shoji flat on the armour hall's walls: [point of the wall face at the
## panel's foot, yaw turning its face into the room].
const SHOJI := [
	[Vector3(56.0, 0.0, -65.0), PI * 0.5], [Vector3(56.0, 0.0, -69.0), PI * 0.5], [Vector3(56.0, 0.0, -73.0), PI * 0.5],
	[Vector3(42.5, 0.0, -62.5), PI], [Vector3(49.5, 0.0, -62.5), PI],
	[Vector3(30.5, 0.0, -67.0), -PI * 0.5], [Vector3(30.5, 0.0, -81.0), -PI * 0.5],
]
## Lit lattice windows high in the Korea hall's south wall.
const LATTICE := [[Vector3(42.0, 3.6, -39.0), 0.0], [Vector3(46.5, 3.6, -39.0), 0.0], [Vector3(51.0, 3.6, -39.0), 0.0]]
## Wall-mounted heroes stand this far before the wall face.
const ON_WALL := 0.012
## The lantern's cord (the model's) ends this far over its light; a rod
## carries on to the ceiling.
const CORD_TOP := 1.03
## What the cases hold (model, scale), in turn, by room.
const CASE_ITEMS := {
	&"asia_china": [["bronze_gu", 1.6], ["vase_blue_white", 1.3], ["bronze_ding", 0.65], ["moon_jar", 1.0], ["vase_celadon", 1.3]],
	&"asia_porcelain": [["vase_blue_white", 1.25], ["vase_celadon", 1.25], ["moon_jar", 1.0], ["bronze_gu", 1.5], ["vase_blue_white", 1.25]],
	&"asia_korea": [["vase_celadon", 1.3], ["moon_jar", 1.0], ["vase_celadon", 1.3], ["bronze_gu", 1.6], ["moon_jar", 1.0]],
}
const SCROLL_SETS: Array[String] = ["", "scroll_hanging_water", "scroll_hanging_moon", "scroll_hanging_enso"]
const ARMOUR_SETS: Array[String] = ["", "samurai_armor_stand_blue", "samurai_armor_stand_white"]
const FU_DOG_SCALE := 0.77
## The bell tower's striking log reaches this far from the bell's axis at
## most (the platform's edge is 1.85 m out).
const STRIKER_REACH := 1.7
## The statues' texture set (see [method stone_dog]).
const STONE_DOG := "fu_dog_stone"

static var _lacquer_black: Material = null
static var _lacquer_red: Material = null
static var _stone: Material = null
static var _thatch: Material = null
static var _boards: Material = null
static var _cord: StandardMaterial3D = null


# --- pieces --------------------------------------------------------------------

## The look of [param spec] (a piece of an Asian room) in its own frame, or
## null (the common rules).
static func piece_look(spec: PieceSpec, index: int, layout: LevelLayout) -> Variant:
	var size := spec.size
	match spec.kit:
		&"pedestal":
			match spec.room:
				&"asia_china":
					return _dais(size) if size.x > 5.0 else _stone_block(size)
				&"asia_korea":
					if size.x > 3.0 and size.z > 3.0:
						return _bell_pavilion(spec)
					return _hwacha(spec)
				&"asia_armor":
					return _lacquer_block(size)
				&"asia_garden":
					return _stone_lantern()
			return _stone_block(size)
		&"sculpture":
			match spec.room:
				&"asia_china":
					return _buddha() if size.y > 5.0 else _fu_dog(spec)
				&"asia_porcelain", &"asia_korea":
					return _jar(size, index)
				&"asia_garden_shrine":
					return _shrine_bell()
		&"plinth":
			match spec.room:
				&"asia_china":
					return _stone_block(size) if size.x > 1.0 else _fit("asia_plinth", size / Vector3(0.7, 0.9, 0.7))
				&"asia_porcelain", &"asia_korea":
					return _fit("asia_plinth", size / Vector3(0.7, 0.9, 0.7))
				&"asia_armor", &"asia_garden_shrine":
					return _lacquer_block(size)
		&"column":
			if spec.room == &"asia_china":
				return _post(size)
			if spec.room == &"asia_garden":
				return _holder("Visual")   # the cherry tree ([method dress])
		&"tree_crown":
			if spec.room == &"asia_garden":
				return _holder("Visual")   # the cherry's crown is the tree's
		&"balcony":
			if spec.room == &"asia_garden":
				return _eave(size)
		&"case":
			return _cases(spec, index, layout)
		&"lantern":
			return _lantern(spec, layout)
		&"painting":
			if spec.room == &"asia_korea":
				return _screen(size)
		&"banner":
			return _scroll_banner(size, index)
		&"armor_rack":
			return _armour_stand(index)
		&"floor":
			match spec.room:
				&"asia_garden":
					return _pond(size) if size.x < 8.0 else _holder("Visual")   # the raked gravel is the room's floor
				&"asia_teahouse":
					return _holder("Visual")   # the tatami are the room's floor
		&"rock":
			return _rock(size)
		&"desk":
			if spec.room == &"asia_teahouse":
				return _lacquer_block(size)
		&"crate":
			if spec.room == &"asia_armory_vault":
				return _lacquer_chest(size)
	return null


static func _holder(label: String) -> Node3D:
	var n := Node3D.new()
	n.name = label
	return n


## [param root] with model [param id] scaled by [param scale] at its origin.
static func _fit(id: String, scale: Vector3) -> Node3D:
	var root := _holder("Visual")
	ArtKit._add(root, id, Transform3D(Basis.from_scale(scale), Vector3.ZERO))
	return root


## A box of [param box] in [param material].
static func _solid(parent: Node3D, box: AABB, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box.size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	view.position = box.get_center()
	parent.add_child(view)
	return view


## A cylinder of radius [param radius] from [param a] to [param b].
static func _rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 10
	mesh.rings = 1
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	view.transform = Transform3D(Basis(side, up, side.cross(up)), (a + b) * 0.5)
	parent.add_child(view)
	return view


static func lacquer_black() -> Material:
	if _lacquer_black == null:
		_lacquer_black = ArtLibrary.arch_tile("asia_lacquer_black")
	return _lacquer_black


static func lacquer_red() -> Material:
	if _lacquer_red == null:
		_lacquer_red = ArtLibrary.arch_tile("asia_lacquer")
	return _lacquer_red


## Polished grey stone (the China hall's "golden bricks").
static func stone() -> Material:
	if _stone == null:
		_stone = ArtLibrary.arch_tile("tiles_golden")
	return _stone


static func thatch() -> Material:
	if _thatch == null:
		_thatch = ArtLibrary.arch_tile("thatch")
	return _thatch


static func boards() -> Material:
	if _boards == null:
		_boards = ArtLibrary.arch_tile("boards_dark")
	return _boards


static func cord() -> StandardMaterial3D:
	if _cord == null:
		_cord = StandardMaterial3D.new()
		_cord.resource_name = "asia_cord"
		_cord.albedo_color = Color(0.12, 0.08, 0.06)
		_cord.roughness = 0.8
	return _cord


## A block of polished stone filling [param size], a thin cap a hair wider.
static func _stone_block(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var cap := 0.05
	_solid(root, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), Vector3(size.x, size.y - cap, size.z)), stone())
	_solid(root, AABB(Vector3(-size.x * 0.5 - 0.03, size.y - cap, -size.z * 0.5 - 0.03), Vector3(size.x + 0.06, cap, size.z + 0.06)), stone())
	return root


## A block of black lacquer filling [param size] with a cinnabar edge.
static func _lacquer_block(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var edge := minf(0.03, size.y * 0.1)
	_solid(root, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), Vector3(size.x, size.y - edge, size.z)), lacquer_black())
	_solid(root, AABB(Vector3(-size.x * 0.5, size.y - edge, -size.z * 0.5), Vector3(size.x, edge, size.z)), lacquer_red())
	return root


## The armourer's chest: black lacquer with two bands of red.
static func _lacquer_chest(size: Vector3) -> Node3D:
	var root := _lacquer_block(size)
	for x in [-0.3, 0.3]:
		_solid(root, AABB(Vector3(x * size.x - 0.03, 0.0, -size.z * 0.5 - 0.005), Vector3(0.06, size.y, size.z + 0.01)), lacquer_red())
	return root


## The Buddha's dais filling the greybox pedestal: stone with a band of
## lacquered panelling (the kit's dado) round its foot.
static func _dais(size: Vector3) -> Node3D:
	var root := _stone_block(size)
	var h := Vector3(size.x * 0.5, 0.0, size.z * 0.5)
	var corners := [Vector3(-h.x, 0.0, -h.z), Vector3(h.x, 0.0, -h.z), Vector3(h.x, 0.0, h.z), Vector3(-h.x, 0.0, h.z)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var out := Vector3((a.x + b.x) * 0.5, 0.0, (a.z + b.z) * 0.5).normalized()
		var face := _holder("Dado")
		face.transform = ArtKit.face_transform(a, b, out)
		root.add_child(face)
		ArtKit.run(face, "asia_dado_", 0.0, a.distance_to(b), 0.0)
	return root


## The great Buddha in his own scale (the piece's yaw turns him to the
## shutter), a bronze ding on his offering step.
static func _buddha() -> Node3D:
	var root := _holder("Visual")
	var buddha := ArtKit._add(root, "buddha_seated", Transform3D.IDENTITY)
	var offering := ArtLibrary.parts(buddha).get("Offering") as Node3D
	var at := offering.position if offering != null else Vector3(0.0, 0.4, -1.95)
	ArtKit._add(root, "bronze_ding", Transform3D(Basis.from_scale(Vector3.ONE * 1.2), at))
	return root


## A guardian Fu dog carved of grey stone (the exhibit's model, so the
## statue stands as the sleeping live dog does - paw on the ball - but in
## stone: no verdigris, no glowing eyes, so a guard tells the decor from the
## enemy 1.5-2.5 m away) sized to its box, the east one mirrored: the lion
## and the lioness.
static func _fu_dog(spec: PieceSpec) -> Node3D:
	var root := _holder("Visual")
	if not ArtLibrary.has_model(&"fu_dog"):
		return root
	var body := ArtKit.model("fu_dog", stone_dog())
	var mirror := -1.0 if spec.position.x > Asia.BUDDHA.x else 1.0
	var basis := Basis.from_scale(Vector3(mirror * FU_DOG_SCALE, FU_DOG_SCALE, FU_DOG_SCALE))
	# (its snout to its tail is 2.5 m: centred over its pedestal, whose length is the box's)
	var middle := _local_bounds(body).get_center()
	body.transform = Transform3D(basis, -(basis * Vector3(middle.x, 0.0, middle.z)))
	root.add_child(body)
	return root


## The bounds of [param model]'s meshes in its own frame.
static func _local_bounds(model: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var node: Node = view
		while node != null and node != model:
			xf = (node as Node3D).transform * xf
			node = node.get_parent()
		var box := xf * view.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


## The texture set of the stone guardian dogs: the live dog's own albedo
## (its UVs, its weathering) turned to grey, lifted and warmed to a pale
## weathered stone, a flat rough ORM (no metal), its carved normal map; no
## emission. Made once (the images are processed natively, no pixel loops).
## "" (the model's own set) when the dog's textures are missing.
static func stone_dog() -> String:
	if ArtLibrary.texture(STONE_DOG, "albedo") != null:
		return STONE_DOG
	var source := ArtLibrary.texture("fu_dog", "albedo")
	if source == null:
		return ""
	var albedo := Image.new()
	albedo.copy_from(source.get_image())   # (a copy: a headless renderer hands out the texture's own image)
	albedo.decompress()
	albedo.convert(Image.FORMAT_RGBA8)
	albedo.adjust_bcs(1.5, 1.05, 0.0)
	var warmth := Image.create_empty(albedo.get_width(), albedo.get_height(), false, Image.FORMAT_RGBA8)
	warmth.fill(Color(0.66, 0.6, 0.5, 0.4))
	albedo.blend_rect(warmth, Rect2i(Vector2i.ZERO, albedo.get_size()), Vector2i.ZERO)
	albedo.generate_mipmaps()
	var orm := Image.create_empty(4, 4, false, Image.FORMAT_RGB8)
	orm.fill(Color(1.0, 0.86, 0.0))
	orm.generate_mipmaps()
	ArtLibrary.register_generated(STONE_DOG, {
		"albedo": ImageTexture.create_from_image(albedo),
		"orm": ImageTexture.create_from_image(orm),
		"normal": ArtLibrary.texture("fu_dog", "normal"),
	})
	return STONE_DOG


## A lacquered post filling its box: the granite base, the shaft of lacquer
## (the kit's tile) and the bracket capital under the ceiling.
static func _post(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var base := 0.4
	var k := size.x / 0.9
	ArtKit._add(root, "asia_post_base", Transform3D(Basis.from_scale(Vector3(k, 1.0, k)), Vector3.ZERO))
	var girth := size.x * 0.66 / 0.5
	ArtKit._add(root, "asia_post_shaft", Transform3D(Basis.from_scale(Vector3(girth, size.y - base - 1.2, girth)), Vector3(0.0, base, 0.0)))
	ArtKit._add(root, "asia_post_capital", Transform3D(Basis.IDENTITY, Vector3(0.0, size.y, 0.0)))
	return root


## Tall lacquered cases filling a greybox case run (1 m modules), their
## shelves with the room's bronzes and porcelain in turn (a case the night
## may fill with loot stays empty).
static func _cases(spec: PieceSpec, index: int, layout: LevelLayout) -> Node3D:
	var root := _holder("Visual")
	var size := spec.size
	var n := maxi(1, int(round(size.x / 1.0)))
	var w := size.x / n
	var k := Vector3(w / 0.97, size.y / 1.89, size.z / 0.77)
	var items: Array = CASE_ITEMS.get(spec.room, CASE_ITEMS[&"asia_china"])
	var loot := _holds_loot(spec, layout)
	for i in n:
		var x := -size.x * 0.5 + (i + 0.5) * w
		var case := ArtKit._add(root, "asia_case_tall", Transform3D(Basis.from_scale(k), Vector3(x, 0.0, 0.0)))
		ArtKit._solid_glass(case)
		if loot:
			continue
		var item: Array = items[posmod(index + i, items.size())]
		var spot := ArtLibrary.parts(case).get("ItemSpot") as Node3D
		var at := Vector3(x, 0.89 * k.y, 0.0) if spot == null else Vector3(x, spot.position.y * k.y, spot.position.z * k.z)
		ArtKit._add(root, String(item[0]), Transform3D(Basis(Vector3.UP, 0.3 * i).scaled(Vector3.ONE * float(item[1])), at))
	return root


## True when a container loot spot lies in [param spec]'s footprint.
static func _holds_loot(spec: PieceSpec, layout: LevelLayout) -> bool:
	if layout == null:
		return false
	var area := spec.footprint().grow(0.05)
	for spot in layout.loot_spots:
		if spot.room == spec.room and spot.container and area.has_point(Vector2(spot.position.x, spot.position.z)):
			return true
	return false


## A red silk lantern hanging where the layout's lamp burns (0.4 m up the
## piece, 0.3 in the low porcelain gallery), its cord carried on up to the
## ceiling by a rod.
static func _lantern(spec: PieceSpec, layout: LevelLayout) -> Node3D:
	var root := _holder("Visual")
	var size := spec.size
	var light_y := 0.4 if size.y > 0.85 else 0.3
	var k := minf(1.0, size.x / 0.62)
	ArtKit._add(root, "asia_lantern_red", Transform3D(Basis.from_scale(Vector3.ONE * k), Vector3(0.0, light_y, 0.0)))
	var room := layout.room(spec.room) if layout != null else null
	if room != null:
		var top := room.ceiling_y - spec.position.y
		var cord_top := light_y + CORD_TOP * k
		if top > cord_top + 0.05:
			_rod(root, Vector3(0.0, cord_top - 0.02, 0.0), Vector3(0.0, top, 0.0), 0.012, cord())
	return root


## The Korea hall's folding screen: four hanging scrolls (mountain, water,
## moon, enso) side by side in the painting's box, on hooks at its top.
static func _screen(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var n := 4
	var pitch := size.x / n
	for i in n:
		var x := -size.x * 0.5 + (i + 0.5) * pitch
		ArtKit._add(root, "scroll_hanging", Transform3D(Basis.IDENTITY, Vector3(x, size.y, size.z * 0.5 - 0.05)), SCROLL_SETS[i % SCROLL_SETS.size()])
	return root


## A great hanging scroll filling a banner's box (mountain to the west, moon
## to the east), on a hook at its top.
static func _scroll_banner(size: Vector3, index: int) -> Node3D:
	var root := _holder("Visual")
	var set_id := "" if index % 2 == 0 else "scroll_hanging_moon"
	ArtKit._add(root, "scroll_hanging", Transform3D(Basis.from_scale(Vector3(size.x / 0.75, size.y / 2.04, 1.0)), Vector3(0.0, size.y, size.z * 0.5 - 0.05)), set_id)
	return root


## A samurai armour on its stand (the lacing's colour by turn).
static func _armour_stand(index: int) -> Node3D:
	var root := _holder("Visual")
	ArtKit._add(root, "samurai_armor_stand", Transform3D.IDENTITY, ARMOUR_SETS[posmod(index, ARMOUR_SETS.size())])
	return root


## The tea house's upper eave: the greybox eave (the General's perch, the
## roof his arrows respect) as a slab of thatch on a boarded soffit with a
## cedar fascia, over the model's own low skirt roof (its thatch edge hangs
## at 1.9 m): a two-tier eave, as temple roofs have.
static func _eave(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var soffit := 0.03
	_solid(root, AABB(Vector3(-size.x * 0.5, soffit, -size.z * 0.5), Vector3(size.x, size.y - soffit, size.z)), thatch())
	_solid(root, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), Vector3(size.x, soffit, size.z)), boards())
	# the fascia along the long outer edge (the thinner side of the L's arms)
	var along_x := size.x > size.z
	var length := size.x if along_x else size.z
	var a := Vector3(-length * 0.5, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, -length * 0.5)
	var b := Vector3(length * 0.5, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, length * 0.5)
	var out := Vector3(0.0, 0.0, size.z * 0.5) if along_x else Vector3(size.x * 0.5, 0.0, 0.0)
	_rod(root, a + out + Vector3.UP * 0.06, b + out + Vector3.UP * 0.06, 0.05, lacquer_black())
	return root


## The garden's pond filling its bed: the kit's pond (stones round dark
## water with koi), its rim flattened to a step nobody trips on.
static func _pond(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var k := Vector3(size.x / 6.69, 0.5, size.z / 4.38)
	ArtKit._add(root, "garden_pond", Transform3D(Basis.from_scale(k), Vector3(-0.195 * k.x, 0.0, -0.07 * k.z)))
	return root


## A garden rock filling its box (the General's cover: the box is the rock
## his arrows meet, LevelKit's boulder): the standing rock for the tall
## boxes, the mossy one for the low. The kit's rock is one mesh with its
## ring of raked sand round it, the rock a third of the model's width
## (QA Q5): the two are drawn apart (rock_parts()) - the rock stretched
## to the box, the sand flat round it, RING_REACH times as wide.
static func _rock(size: Vector3) -> Node3D:
	var id := "garden_rock_a" if size.y > 1.6 else "garden_rock_c"
	var parts := rock_parts(id)
	if parts.is_empty():
		return _fit(id, size / (Vector3(2.86, 1.72, 2.34) if size.y > 1.6 else Vector3(2.6, 0.83, 2.6)))
	var root := _holder("Visual")
	var bounds: AABB = parts[2]
	var k := size / bounds.size
	var middle := bounds.get_center()
	# the kit's model, drawing only its rock
	var model := ArtKit._add(root, id, Transform3D(Basis.from_scale(k), Vector3(-middle.x * k.x, -bounds.position.y * k.y, -middle.z * k.z)))
	for view in model.find_children("*", "MeshInstance3D", true, false):
		(view as MeshInstance3D).mesh = parts[0]
	var sand_bounds: AABB = parts[3]
	var s := size.x * RING_REACH / sand_bounds.size.x
	var sand := MeshInstance3D.new()
	sand.name = "RakedSand"
	sand.mesh = parts[1]
	sand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sand.transform = Transform3D(Basis.from_scale(Vector3(s, 1.0, s)), Vector3(-middle.x * s, RING_LIFT, -middle.z * s))
	root.add_child(sand)
	return root


## The raked sand round a garden rock reaches this many times the rock's
## box out (across its width), lying RING_LIFT m over the floor (over the
## raked gravel bed's top).
const RING_REACH := 1.5
const RING_LIFT := 0.022
## A triangle of the kit's garden rock whose corners all lie this low
## (m) is its ring of sand, the rest is the rock.
const SAND_TOP := 0.03

## Model id -> [rock mesh, sand mesh, the rock's bounds, the sand's bounds]
## (model space; built once).
static var _rock_parts: Dictionary = {}


## The kit's garden rock [param id] drawn apart into the rock and the flat
## ring of raked sand round it (one mesh in the kit): [rock mesh, sand
## mesh, rock AABB, sand AABB], both meshes wearing the model's material;
## [] when the model is not there.
static func rock_parts(id: String) -> Array:
	if _rock_parts.has(id):
		return _rock_parts[id]
	var parts: Array = []
	if ArtLibrary.has_model(StringName(id)):
		var model := ArtKit.model(id)
		var views := model.find_children("*", "MeshInstance3D", true, false)
		var view := views[0] as MeshInstance3D if not views.is_empty() else null
		if view != null and view.mesh != null and view.mesh.get_surface_count() > 0:
			var arrays := view.mesh.surface_get_arrays(0)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if order.is_empty():
				for i in points.size():
					order.append(i)
			var rock := PackedInt32Array()
			var sand := PackedInt32Array()
			var rock_box := AABB()
			var sand_box := AABB()
			var rock_any := false
			var sand_any := false
			for t in range(0, order.size() - 2, 3):
				var corners := [points[order[t]], points[order[t + 1]], points[order[t + 2]]]
				var flat: bool = corners.all(func(p: Vector3) -> bool: return p.y <= SAND_TOP)
				for p: Vector3 in corners:
					if flat:
						sand_box = sand_box.expand(p) if sand_any else AABB(p, Vector3.ZERO)
						sand_any = true
					else:
						rock_box = rock_box.expand(p) if rock_any else AABB(p, Vector3.ZERO)
						rock_any = true
				(sand if flat else rock).append_array(PackedInt32Array([order[t], order[t + 1], order[t + 2]]))
			if rock_any and sand_any:
				var material := view.get_active_material(0)
				parts = [_surface_of(arrays, rock, material), _surface_of(arrays, sand, material), rock_box, sand_box]
		model.free()
	_rock_parts[id] = parts
	return parts


## A one-surface mesh of the triangles [param order] of [param arrays]
## (only the vertices they use) in [param material].
static func _surface_of(arrays: Array, order: PackedInt32Array, material: Material) -> ArrayMesh:
	var remap := {}
	var kept := PackedInt32Array()
	var indices := PackedInt32Array()
	for i in order:
		if not remap.has(i):
			remap[i] = kept.size()
			kept.append(i)
		indices.append(remap[i])
	var copy := []
	copy.resize(Mesh.ARRAY_MAX)
	for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		var source: Variant = arrays[slot]
		if source == null or source.size() == 0:
			continue
		copy[slot] = _picked(source, kept, 4 if slot == Mesh.ARRAY_TANGENT else 1)
	copy[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, copy)
	mesh.surface_set_material(0, material)
	return mesh


## The entries [param kept] of the per-vertex array [param source]
## ([param width] values a vertex: a tangent has four floats).
static func _picked(source: Variant, kept: PackedInt32Array, width: int) -> Variant:
	if source is PackedVector3Array:
		var out := PackedVector3Array()
		for i in kept:
			out.append(source[i])
		return out
	if source is PackedVector2Array:
		var out2 := PackedVector2Array()
		for i in kept:
			out2.append(source[i])
		return out2
	if source is PackedColorArray:
		var out3 := PackedColorArray()
		for i in kept:
			out3.append(source[i])
		return out3
	if source is PackedFloat32Array:
		var out4 := PackedFloat32Array()
		for i in kept:
			for w in width:
				out4.append(source[i * width + w])
		return out4
	return null


## A Kasuga stone lantern (its own size: a hand over the greybox pedestal).
static func _stone_lantern() -> Node3D:
	var root := _holder("Visual")
	ArtKit._add(root, "toro_kasuga", Transform3D.IDENTITY)
	return root


## The hwacha display on its greybox pedestal: a lacquer platform under all,
## the display turned to the porcelain arch with its cushion under the
## weapon marker, a lacquer plinth filling the box between the stand and
## the cart.
static func _hwacha(spec: PieceSpec) -> Node3D:
	var root := _holder("Visual")
	var size := spec.size
	var platform := 0.1
	_solid(root, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), Vector3(size.x, platform, size.z)), lacquer_black())
	var local := Transform3D(Basis(Vector3.UP, -spec.yaw), -spec.position) * Transform3D(Basis(Vector3.UP, HWACHA_YAW), HWACHA_AT)
	var display := ArtKit._add(root, "hwacha_display", local)
	# the box between the stand (model z -1.34..-0.46) and the cart (0.21..):
	# the piece's x runs along the model's z
	var gap_from := local.origin.x - 0.46
	var gap_to := local.origin.x + 0.21
	_solid(root, AABB(Vector3(gap_from, platform, -size.z * 0.5), Vector3(gap_to - gap_from, size.y - platform, size.z)), lacquer_black())
	display.set_meta(&"hwacha_display", true)
	return root


## The bell pavilion on the Korea hall's platform, its bell swaying a
## little (a decor process: culled by room).
static func _bell_pavilion(spec: PieceSpec) -> Node3D:
	var root := _holder("Visual")
	var pavilion := ArtKit._add(root, "temple_bell", Transform3D.IDENTITY)
	_shorten_striker(pavilion)
	var spinner := DecorSpinner.new()
	spinner.name = "BellSway"
	spinner.swing(ArtLibrary.parts(pavilion).get("bell") as Node3D, Vector3.RIGHT, 0.015, 7.0)
	Floor1Art.decor(root, spinner, spec.room)
	return root


## The striking log hangs on its ropes from the bell outward to the front;
## the model's reaches 2.25 m from the bell's axis, 0.4 m past the platform's
## edge: at a guard's eye height, over the alley between the platform and the
## cases, with no collision to say so. Drawn shorter - its back end by the
## bell where it was, its tip [constant STRIKER_REACH] from the axis at most
## (ropes and all come along).
static func _shorten_striker(pavilion: Node3D) -> void:
	var log := ArtLibrary.parts(pavilion).get("striker") as MeshInstance3D
	if log == null or log.mesh == null:
		return
	var box := log.transform * log.get_aabb()
	if box.position.z >= -STRIKER_REACH:
		return
	var along := (STRIKER_REACH + box.end.z) / (box.end.z - box.position.z)
	var shrink := Basis.from_scale(Vector3(1.0, 1.0, along))
	var anchor := Vector3(0.0, 0.0, box.end.z)
	log.transform = Transform3D(shrink, anchor - shrink * anchor) * log.transform


## The shrine's bell: the pavilion model's bell alone (the pavilion and the
## striker drawn no more), hanging from a cedar beam on two posts, in the
## greybox sculpture's box.
static func _shrine_bell() -> Node3D:
	var root := _holder("Visual")
	var k := 0.7
	var drop := -0.55
	var model := ArtKit._add(root, "temple_bell", Transform3D(Basis.from_scale(Vector3.ONE * k), Vector3(0.0, drop, 0.0)))
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		if String(view.name) != "bell":
			view.mesh = null
	var beam_y := 3.0 * k + drop + 0.17
	for x in [-0.42, 0.42]:
		_rod(root, Vector3(x, 0.0, 0.0), Vector3(x, beam_y + 0.05, 0.0), 0.06, lacquer_red())
	_rod(root, Vector3(-0.5, beam_y, 0.0), Vector3(0.5, beam_y, 0.0), 0.06, lacquer_red())
	return root


## A jar on a plinth: the moon jar or the celadon maebyeong, sized to the
## sculpture's box.
static func _jar(size: Vector3, index: int) -> Node3D:
	var root := _holder("Visual")
	if posmod(index, 2) == 0:
		ArtKit._add(root, "moon_jar", Transform3D(Basis.from_scale(Vector3.ONE * minf(size.y / 0.44, 1.6)), Vector3.ZERO))
	else:
		ArtKit._add(root, "vase_celadon", Transform3D(Basis.from_scale(Vector3.ONE * minf(size.y / 0.41, 1.9)), Vector3.ZERO))
	return root


# --- fittings, gates, portals, leaves -------------------------------------------------

## The wing's light fittings (origin = the light): an andon on the floor
## under the recipe's paper lamps; the tea house's bulb is its model's paper
## lamp; null = the lobby's.
static func fixture(kit: StringName, room: StringName) -> Variant:
	match kit:
		&"andon":
			var andon := _holder("Visual")
			ArtKit._add(andon, "asia_lantern_floor", Transform3D(Basis.IDENTITY, Vector3(0.0, -0.42, 0.0)))
			return andon
		&"bulb":
			if room == &"asia_teahouse":
				return _holder("Visual")
	return null


## No gates in disguise.
static func gate_leaf(_opening_id: StringName, _size: Vector3, _side: float) -> Variant:
	return null


## The leaf of a swinging door in Door's leaf frame: the tea house's door is
## a shoji; null = the kit's.
static func door_leaf(face_room: StringName, size: Vector3, style_id: int, _side: float) -> Variant:
	if style_id != OpeningSpec.DoorStyle.SWING or (face_room != &"asia_garden" and face_room != &"asia_teahouse"):
		return null
	var root := _holder("Visual")
	ArtKit._add(root, "asia_shoji_2m", Transform3D(Basis.from_scale(Vector3(size.x / 2.06, size.y / 2.09, size.z / 0.12)), Vector3(0.0, 0.0, size.z * 0.5)))
	return root


## The wing's own portals (Floor1Art.PORTALS' form): the porcelain gallery's
## faces bare (its style has no 4 m frame), no frames round the cracked
## walls.
static func portals() -> Dictionary:
	return {
		&"asia_china_porcelain": {&"asia_china": ["asia_moon_gate_4m", Vector2(4.0, 4.5)], &"asia_porcelain": ["", Vector2.ZERO]},
		&"asia_porcelain_korea": {&"asia_porcelain": ["", Vector2.ZERO], &"asia_korea": ["asia_moon_gate_4m", Vector2(4.0, 4.5)]},
		&"asia_garden_wall": {&"asia_china": ["", Vector2.ZERO], &"asia_garden": ["", Vector2.ZERO]},
		&"asia_stairs_crates": {&"asia_service_stairs": ["", Vector2.ZERO], &"asia_crate_store": ["", Vector2.ZERO]},
	}


## Gates of the wing that wear leaves of their own: none.
static func disguised_gates() -> Array[StringName]:
	return []


# --- hero pieces ------------------------------------------------------------------

## The wing's hero pieces for the dressed rooms ([param rooms] empty: all)
## under [param parent] (world space).
static func dress(layout: LevelLayout, parent: Node3D, rooms: Dictionary = {}) -> void:
	if layout.room(&"asia_garden") == null:
		return
	if Floor1Art.wants(rooms, &"asia_garden"):
		var garden := Floor1Art.group(parent, "Garden", &"asia_garden")
		_garden(layout, garden)
		_garden_walls(layout, garden)
		_garden_plants(garden)
	if Floor1Art.wants(rooms, &"asia_teahouse"):
		var inside := Floor1Art.group(parent, "TeaHouse", &"asia_teahouse")
		ArtKit._add(inside, "teahouse_interior", Transform3D(Basis.from_scale(INTERIOR_SCALE), INTERIOR_AT))
	if Floor1Art.wants(rooms, &"asia_armor"):
		var hall := Floor1Art.group(parent, "ArmourShoji", &"asia_armor")
		for panel: Array in SHOJI:
			_on_wall(hall, "asia_shoji_2m", panel[0], float(panel[1]), "asia_shoji_2m_lit")
	if Floor1Art.wants(rooms, &"asia_korea"):
		var korea := Floor1Art.group(parent, "KoreaWindows", &"asia_korea")
		for window: Array in LATTICE:
			_on_wall(korea, "asia_lattice_window", window[0], float(window[1]), "asia_lattice_window_lit")
	_slot_mats(layout, parent, rooms)


## A display mat under every slot of the wing where a Fu dog or a samurai
## armour keeps its post in the open (not the walkers): the exhibit's
## context until it wakes.
static func _slot_mats(layout: LevelLayout, parent: Node3D, rooms: Dictionary) -> void:
	var groups := {}
	for i in layout.spawn_slots.size():
		var slot: SpawnSlot = layout.spawn_slots[i]
		if not String(slot.room).begins_with("asia_") or slot.patrol != &"" or not slot.dormant:
			continue
		if not Floor1Art.wants(rooms, slot.room):
			continue
		var lion := slot.kinds.has(&"fu_dog")
		if not lion and not slot.kinds.has(&"samurai_armor"):
			continue
		if not groups.has(slot.room):
			groups[slot.room] = Floor1Art.group(parent, "ExhibitMats_%s" % slot.room, slot.room)
		var mat := _mat(lion)
		mat.name = "ExhibitMat_%d" % i   # (the slot's index: siblings of one name would be renamed)
		mat.transform = Transform3D(Basis(Vector3.UP, slot.yaw), slot.position)
		(groups[slot.room] as Node3D).add_child(mat)


## The mat in the slot's frame (-Z the exhibit's front): a stone slab for a
## lion, a lacquered panel with a cinnabar rim and a brass plaque at its
## front for an armour.
static func _mat(lion: bool) -> Node3D:
	var root := _holder("ExhibitMat")
	var size := DOG_MAT if lion else ARMOUR_MAT
	var back := DOG_MAT_BACK if lion else 0.0
	if lion:
		_solid(root, AABB(Vector3(-size.x * 0.5, 0.0, -size.y * 0.5 + back), Vector3(size.x, MAT_LIFT, size.y)), stone())
	else:
		_solid(root, AABB(Vector3(-size.x * 0.5 - 0.04, 0.0, -size.y * 0.5 - 0.04), Vector3(size.x + 0.08, MAT_LIFT * 0.8, size.y + 0.08)), lacquer_red())
		_solid(root, AABB(Vector3(-size.x * 0.5, 0.0, -size.y * 0.5), Vector3(size.x, MAT_LIFT, size.y)), lacquer_black())
	# the plaque lying flat at the mat's front (its face up, its foot to the front)
	ArtKit._add(root, "plaque_brass", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, MAT_LIFT + 0.004, -size.y * 0.5 + back + 0.06)))
	return root


## A wall-mounted model (its back on z = 0, its face -Z) at the wall-face
## point [param at], turned by [param yaw] to face the room, a hair before
## the wall.
static func _on_wall(parent: Node3D, id: String, at: Vector3, yaw: float, texture_set: String = "") -> Node3D:
	var basis := Basis(Vector3.UP, yaw)
	return ArtKit._add(parent, id, Transform3D(basis, at + basis * Vector3(0.0, 0.0, -ON_WALL)), texture_set)


## The garden's heroes: the cherry tree in the greybox trunk's box (its
## Petals_* for the General's storm) with fallen petals round it, the tea
## house's facades fitted to the garden's faces (its own perch nodes
## renamed), the General's perch on the eave's corner.
static func _garden(layout: LevelLayout, root: Node3D) -> void:
	ArtKit._add(root, "cherry_tree", Transform3D(Basis(Vector3.UP, CHERRY_YAW), CHERRY_AT))
	ArtKit._add(root, "cherry_petals_ground", Transform3D(Basis(Vector3.UP, CHERRY_YAW), CHERRY_AT + Vector3.UP * 0.004))
	var house := ArtKit._add(root, "teahouse", Transform3D(Basis.from_scale(TEAHOUSE_SCALE), TEAHOUSE_AT))
	var parts := ArtLibrary.parts(house)
	for id in PERCH_RENAMED:
		var node := parts.get(id) as Node
		if node != null:
			node.name = id + "_model"
	house.set_meta(&"teahouse", true)
	var basin := parts.get("basin") as Node3D
	if basin != null:
		basin.scale = Vector3(BASIN_SCALE / TEAHOUSE_SCALE.x, BASIN_SCALE, BASIN_SCALE / TEAHOUSE_SCALE.z)
		basin.position.y += BASIN_LIFT
	var perch := Node3D.new()
	perch.name = "roof_perch"
	var perch_at: Transform3D = layout.markers.get(&"arena_general_perch", Transform3D(Basis.IDENTITY, Asia.PERCH))
	perch.transform = perch_at
	root.add_child(perch)


# --- the garden's walls -----------------------------------------------------------

## The garden's walls (the General's arena) were 14 m of bare stone over the
## coping. Visual only - no collision: his dash lanes, his perch on the eave
## and the lines of his volleys are the greybox's:
## - along every face the guard walks by, a temple garden's tsuiji-bei to
##   its tiled coping (the style's band at 3 m): a footing of stone blocks,
##   the clay between cedar posts, a cedar beam under the tiles;
## - over it the museum's own court front, the hall's upper storey: the
##   string course at 4.5 m and the cornice under the sky (the style's
##   bands), the hall's pilasters between the bays, in each bay a tall sash
##   window in a limestone architrave with a sill and a hood and an attic
##   window over it, most of them dark (the moon in the glass), a few lit
##   from the galleries behind, their blinds drawn to different heights.
## The tea house's faces (its own facades and the eave to 3.9 m) get only
## the front over the eave.
const FOOTING := Vector2(0.42, 0.05)
const POST := Vector2(0.2, 0.08)
const POST_STEP := 2.4
## The beam under the tiles (height, how far it stands out) and the coping.
const KASAGI := Vector2(0.14, 0.1)
const COPING_AT := 3.0
## The court front: from the string course's top to the cornice's foot,
## bays of about BAY m between pilasters.
const FRONT_FROM := 4.5
const FRONT_TO := 12.5
const BAY := 4.6
## The windows' openings round a bay's middle: x, bottom, width, height.
const SASH := Rect2(-0.8, 5.55, 1.6, 3.0)
const ATTIC := Rect2(-0.6, 10.05, 1.2, 1.35)
## Their stone: the architrave (width, out), the sill (overhang past the
## architrave, height, out), the hood (overhang, the frieze's height, the
## cornice's height, out).
const ARCHITRAVE := Vector2(0.18, 0.09)
const SILL := Vector3(0.12, 0.12, 0.15)
const HOOD := Vector4(0.15, 0.2, 0.14, 0.2)
## The glass this far out of the wall, the sash bars over it.
const GLASS_OUT := 0.03
const SASH_OUT := 0.055
const SASH_FRAME := 0.06
const SASH_BAR := 0.03
## Lit windows' glow and their blinds' share of the glass, in turn.
const WINDOW_LIGHT := Color(1.0, 0.74, 0.46)
const BLINDS: Array[float] = [0.22, 0.5, 0.34, 0.0, 0.42]

static var _garden_mats: Dictionary = {}
static var _unit_box: Array = []
static var _unit_tube: Array = []


## The garden's wall faces joined into runs (collinear neighbours as one
## front, so the bays keep one rhythm along the south wall): [{"xform"
## (face frame, see ArtKit.face_transform), "length", "openings" ([x0, x1,
## y0, y1] along the run), "tsuiji" ([x0, x1] spans wearing it: not the tea
## house's faces)}].
static func garden_runs(layout: LevelLayout) -> Array:
	var faces := LevelArt.wall_faces(layout, &"asia_garden")
	faces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var xa: Transform3D = a["xform"]
		var xb: Transform3D = b["xform"]
		return xa.origin.dot(xa.basis.x) < xb.origin.dot(xb.basis.x))
	var runs: Array = []
	for face: Dictionary in faces:
		var xf: Transform3D = face["xform"]
		var length: float = face["length"]
		var behind := layout.room_at(xf.origin + xf.basis.x * length * 0.5 + xf.basis.z * 0.75 + Vector3.UP)
		var run: Dictionary = {}
		for other: Dictionary in runs:
			var rx: Transform3D = other["xform"]
			var local := rx.affine_inverse() * xf.origin
			if rx.basis.x.dot(xf.basis.x) > 0.99 and absf(local.z) < 0.01 and absf(local.y) < 0.01 and absf(local.x - float(other["length"])) < 0.01:
				run = other
		if run.is_empty():
			run = {"xform": xf, "length": 0.0, "openings": [], "tsuiji": []}
			runs.append(run)
		var shift: float = run["length"]
		for o: Array in face["openings"]:
			(run["openings"] as Array).append([float(o[0]) + shift, float(o[1]) + shift, o[2], o[3]])
		if behind != &"asia_teahouse":
			(run["tsuiji"] as Array).append([shift, shift + length])
		run["length"] = shift + length
	return runs


static func _garden_walls(layout: LevelLayout, root: Node3D) -> void:
	var walls := _holder("GardenWalls")
	walls.set_meta(&"garden_walls", true)
	root.add_child(walls)
	var index := 0
	for run: Dictionary in garden_runs(layout):
		var front := _holder("Front_%d" % index)
		front.transform = run["xform"]
		walls.add_child(front)
		_tsuiji(front, run)
		_court_front(front, run, index)
		index += 1


## [a, b] less the [x0, x1, ...] intervals of [param cuts].
static func _spans(a: float, b: float, cuts: Array) -> Array:
	var spans: Array = [[a, b]]
	for cut: Array in cuts:
		var next: Array = []
		for s: Array in spans:
			if float(cut[1]) <= float(s[0]) or float(cut[0]) >= float(s[1]):
				next.append(s)
				continue
			if float(cut[0]) > float(s[0]) + 0.05:
				next.append([s[0], cut[0]])
			if float(cut[1]) < float(s[1]) - 0.05:
				next.append([cut[1], s[1]])
		spans = next
	return spans


## The tsuiji along a run's spans (face frame: -Z out of the wall): the
## footing and the posts stop at the doorways (a post each side), the beam
## under the tiles runs on over the doors lower than it.
static func _tsuiji(front: Node3D, run: Dictionary) -> void:
	var footing: Array = []
	var timber: Array = []
	var doors: Array = []
	var through: Array = []
	for o: Array in run["openings"]:
		if float(o[2]) < 0.05:
			doors.append(o)
		if float(o[3]) > COPING_AT - KASAGI.x:
			through.append(o)
	for span: Array in run["tsuiji"]:
		for part: Array in _spans(span[0], span[1], doors):
			var a: float = part[0]
			var b: float = part[1]
			footing.append(AABB(Vector3(a, 0.0, -FOOTING.y), Vector3(b - a, FOOTING.x, FOOTING.y + 0.01)))
			var n := maxi(1, int(round((b - a) / POST_STEP)))
			for k in n + 1:
				var x := lerpf(a + POST.x * 0.5, b - POST.x * 0.5, float(k) / n)
				timber.append(AABB(Vector3(x - POST.x * 0.5, FOOTING.x, -POST.y), Vector3(POST.x, COPING_AT - KASAGI.x - FOOTING.x, POST.y + 0.01)))
		for part: Array in _spans(span[0], span[1], through):
			timber.append(AABB(Vector3(part[0], COPING_AT - KASAGI.x, -KASAGI.y), Vector3(float(part[1]) - float(part[0]), KASAGI.x, KASAGI.y + 0.01)))
	_merged_view(front, "TsuijiFooting", footing, garden_material(&"footing"))
	_merged_view(front, "TsuijiTimber", timber, garden_material(&"timber"))


## The court front of a run: the hall's pilasters between its bays, a sash
## window and an attic window in each bay.
static func _court_front(front: Node3D, run: Dictionary, index: int) -> void:
	var length: float = run["length"]
	var n := maxi(1, int(round(length / BAY)))
	var bay := length / n
	var shaft := FRONT_TO - FRONT_FROM - 0.45 - 0.6
	for k in range(1, n):
		var x := k * bay
		ArtKit._add(front, "hall_pilaster_base", Transform3D(Basis.IDENTITY, Vector3(x, FRONT_FROM, 0.0)))
		ArtKit._add(front, "hall_pilaster_shaft", Transform3D(Basis.from_scale(Vector3(1.0, shaft, 1.0)), Vector3(x, FRONT_FROM + 0.45, 0.0)))
		ArtKit._add(front, "hall_pilaster_capital", Transform3D(Basis.IDENTITY, Vector3(x, FRONT_TO - 0.6, 0.0)))
	var parts := {&"stone": [], &"glass": [], &"lit": [], &"sash": [], &"blind": []}
	for i in n:
		var x := (i + 0.5) * bay
		var turn := index * 3 + i
		_window(parts, SASH, x, posmod(turn, 4) == 1, BLINDS[posmod(turn, BLINDS.size())], true)
		_window(parts, ATTIC, x, posmod(index * 5 + i * 2, 7) == 3, 0.0, false)
	for key: StringName in parts:
		var view := _merged_view(front, "Windows_%s" % key, parts[key], garden_material(key))
		if view != null and key != &"stone":
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## One window of opening [param box] (round the bay's middle [param x]) into
## [param parts]: the architrave, the sill, the hood over a tall one; the
## glass (lit or dark), the sash's frame, meeting rail and bars (six panes
## a sash, two an attic's), a lit one's blind drawn [param blind] down.
static func _window(parts: Dictionary, box: Rect2, x: float, lit: bool, blind: float, hood: bool) -> void:
	var x0 := x + box.position.x
	var y0 := box.position.y
	var w := box.size.x
	var h := box.size.y
	var a := ARCHITRAVE.x
	var stone: Array = parts[&"stone"]
	stone.append(AABB(Vector3(x0 - a, y0, -ARCHITRAVE.y), Vector3(a, h, ARCHITRAVE.y + 0.01)))
	stone.append(AABB(Vector3(x0 + w, y0, -ARCHITRAVE.y), Vector3(a, h, ARCHITRAVE.y + 0.01)))
	stone.append(AABB(Vector3(x0 - a, y0 + h, -ARCHITRAVE.y), Vector3(w + 2.0 * a, a, ARCHITRAVE.y + 0.01)))
	stone.append(AABB(Vector3(x0 - a - SILL.x, y0 - SILL.y, -SILL.z), Vector3(w + 2.0 * (a + SILL.x), SILL.y, SILL.z + 0.01)))
	if hood:
		var top := y0 + h + a
		stone.append(AABB(Vector3(x0 - a, top, -ARCHITRAVE.y * 0.7), Vector3(w + 2.0 * a, HOOD.y, ARCHITRAVE.y * 0.7 + 0.01)))
		stone.append(AABB(Vector3(x0 - a - HOOD.x, top + HOOD.y, -HOOD.w), Vector3(w + 2.0 * (a + HOOD.x), HOOD.z, HOOD.w + 0.01)))
	(parts[&"lit" if lit else &"glass"] as Array).append(AABB(Vector3(x0, y0, -GLASS_OUT - 0.01), Vector3(w, h, 0.012)))
	if lit and blind > 0.0:
		(parts[&"blind"] as Array).append(AABB(Vector3(x0, y0 + h * (1.0 - blind), -GLASS_OUT - 0.018), Vector3(w, h * blind, 0.006)))
	var sash: Array = parts[&"sash"]
	var f := SASH_FRAME
	var d := SASH_OUT - GLASS_OUT
	var z := -SASH_OUT
	sash.append(AABB(Vector3(x0, y0, z), Vector3(f, h, d)))
	sash.append(AABB(Vector3(x0 + w - f, y0, z), Vector3(f, h, d)))
	sash.append(AABB(Vector3(x0, y0, z), Vector3(w, f, d)))
	sash.append(AABB(Vector3(x0, y0 + h - f, z), Vector3(w, f, d)))
	var b := SASH_BAR
	if hood:
		sash.append(AABB(Vector3(x0, y0 + h * 0.5 - f * 0.6, z - 0.01), Vector3(w, f * 1.2, d + 0.01)))   # the meeting rail
		for k in [1, 2]:
			sash.append(AABB(Vector3(x0 + w * k / 3.0 - b * 0.5, y0, z), Vector3(b, h, d)))
		for k in [1, 3]:
			sash.append(AABB(Vector3(x0, y0 + h * k / 4.0 - b * 0.5, z), Vector3(w, b, d)))
	else:
		sash.append(AABB(Vector3(x0 + w * 0.5 - b * 0.5, y0, z), Vector3(b, h, d)))


## A MeshInstance3D "name" of [param boxes] merged (null for none).
static func _merged_view(parent: Node3D, label: String, boxes: Array, material: Material) -> MeshInstance3D:
	if boxes.is_empty():
		return null
	var view := MeshInstance3D.new()
	view.name = label
	view.mesh = boxes_mesh(boxes)
	view.material_override = material
	parent.add_child(view)
	return view


## One mesh of [param boxes] (AABBs), cut from one unit box: no UVs (the
## architecture's tiles map by position).
static func boxes_mesh(boxes: Array) -> ArrayMesh:
	if _unit_box.is_empty():
		var unit := BoxMesh.new()
		unit.size = Vector3.ONE
		_unit_box = unit.get_mesh_arrays()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var unit_vertices: PackedVector3Array = _unit_box[Mesh.ARRAY_VERTEX]
	var unit_normals: PackedVector3Array = _unit_box[Mesh.ARRAY_NORMAL]
	var unit_indices: PackedInt32Array = _unit_box[Mesh.ARRAY_INDEX]
	for box: AABB in boxes:
		var base := vertices.size()
		vertices.append_array(Transform3D(Basis.from_scale(box.size), box.get_center()) * unit_vertices)
		normals.append_array(unit_normals)
		for i in unit_indices:
			indices.append(base + i)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The garden walls' and plants' materials (shared): &"footing" (stone
## blocks), &"timber" (cedar), &"stone" (the windows' limestone), &"glass"
## (dark, the moon in it), &"lit" (a window lit from inside), &"sash"
## (painted bars), &"blind" (a lit window's blind), &"bark", &"needles",
## &"culm", &"leaves".
static func garden_material(key: StringName) -> Material:
	if _garden_mats.has(key):
		return _garden_mats[key]
	var mat: Material = null
	match key:
		&"footing":
			mat = ArtLibrary.arch_tile("flagstone")
		&"timber":
			mat = ArtLibrary.arch_tile("timber", false, Color(0.82, 0.74, 0.68))
		&"stone":
			mat = ArtLibrary.arch_tile("limestone")
		&"bark":
			mat = ArtLibrary.arch_tile("timber", false, Color(0.72, 0.6, 0.55))
		&"needles":
			mat = ArtLibrary.arch_tile("grass_fake", false, Color(0.85, 1.0, 0.85))
		_:
			var plain := StandardMaterial3D.new()
			plain.resource_name = "garden_" + String(key)
			match key:
				&"glass":
					plain.albedo_color = Color(0.03, 0.04, 0.055)
					plain.roughness = 0.08
					plain.metallic = 0.3
					plain.metallic_specular = 0.9
				&"lit":
					plain.albedo_color = WINDOW_LIGHT
					plain.emission_enabled = true
					plain.emission = WINDOW_LIGHT
					plain.emission_energy_multiplier = 1.1
				&"sash":
					plain.albedo_color = Color(0.7, 0.69, 0.64)
					plain.roughness = 0.6
				&"blind":
					plain.albedo_color = Color(0.42, 0.28, 0.16)
					plain.emission_enabled = true
					plain.emission = Color(0.55, 0.33, 0.16)
					plain.emission_energy_multiplier = 0.6
				&"culm", &"leaves":
					plain.vertex_color_use_as_albedo = true
					plain.roughness = 0.7 if key == &"culm" else 0.85
					if key == &"leaves":
						plain.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat = plain
	_garden_mats[key] = mat
	return mat


# --- the garden's plants ----------------------------------------------------------

## Plants over the coping, rooted behind its tiles (nothing of them under
## ROOT_Y - out of every guard's reach, no collision), leaning out over the
## gravel away from the perch: bamboo groves [the wall-face point at the
## grove's middle (y 0), the face's normal into the garden, the grove's
## length]; pines [the wall-face point, the normal into the garden].
const BAMBOO := [[Vector3(4.0, 0.0, -70.75), Vector3.RIGHT, 6.0], [Vector3(18.25, 0.0, -62.5), Vector3.FORWARD, 4.5],
	[Vector3(30.0, 0.0, -66.25), Vector3.LEFT, 3.5]]
const PINES := [[Vector3(30.0, 0.0, -73.25), Vector3.LEFT], [Vector3(19.75, 0.0, -86.0), Vector3.BACK]]
const ROOT_Y := 3.15
const PINE_SCALE := 1.25
const CULM_GREEN := Color(0.26, 0.38, 0.13)
const LEAF_GREEN := Color(0.18, 0.33, 0.11)


static func _garden_plants(root: Node3D) -> void:
	var plants := _holder("GardenPlants")
	plants.set_meta(&"garden_plants", true)
	root.add_child(plants)
	for i in BAMBOO.size():
		var grove: Array = BAMBOO[i]
		_bamboo(plants, grove[0], grove[1], float(grove[2]), 9173 + i * 31).name = "Bamboo_%d" % i
	for i in PINES.size():
		_pine(plants, PINES[i][0], PINES[i][1], 4421 + i * 17).name = "Pine_%d" % i


## The frame of a plant on the wall at [param at] (its foot), facing the
## garden ([param inward]): +X along the wall, -Z out over the gravel.
static func _plant_frame(at: Vector3, inward: Vector3) -> Transform3D:
	var z := -inward.normalized()
	return Transform3D(Basis(Vector3.UP.cross(z), Vector3.UP, z), at)


## A bamboo grove [param length] m along the wall: culms rising from behind
## the coping and leaning out over it (clear of the string course and the
## pilasters), their nodes ringed, sprays of leaves on their upper halves.
static func _bamboo(parent: Node3D, at: Vector3, inward: Vector3, length: float, seed: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var culms := _Strokes.new()
	var leaves := _Strokes.new()
	var count := int(length * 5.0)
	for i in count:
		var x := (float(i) + rng.randf_range(0.15, 0.85)) / count * length - length * 0.5
		var base := Vector3(x, ROOT_Y, rng.randf_range(-0.14, -0.08))
		var height := rng.randf_range(4.6, 8.2)
		var out := deg_to_rad(rng.randf_range(14.0, 20.0))
		var side := deg_to_rad(rng.randf_range(-6.0, 6.0))
		var radius := rng.randf_range(0.03, 0.046)
		var shade := CULM_GREEN.lerp(Color(0.46, 0.46, 0.24), rng.randf_range(0.0, 0.5))
		# three segments, the top one arching further out
		var points: Array[Vector3] = [base]
		var dir := Vector3(sin(side), cos(out), -sin(out)).normalized()
		for k in 3:
			var bend := deg_to_rad(4.0 * k)
			var d := Vector3(dir.x, dir.y * cos(bend), dir.z - sin(bend)).normalized()
			points.append(points[-1] + d * height / 3.0)
		var node_at := rng.randf_range(0.0, 0.3)
		var walked := 0.0
		for k in 3:
			var a: Vector3 = points[k]
			var b: Vector3 = points[k + 1]
			var r0 := radius * (1.0 - 0.18 * k)
			var r1 := radius * (1.0 - 0.18 * (k + 1))
			culms.tube(a, b, r0, r1, 6, shade)
			var span := a.distance_to(b)
			while node_at < walked + span:
				var t := (node_at - walked) / span
				var p := a.lerp(b, t)
				var r := lerpf(r0, r1, t)
				var up := (b - a).normalized()
				culms.tube(p - up * 0.01, p + up * 0.01, r * 1.25, r * 1.25, 6, shade.darkened(0.25))
				if node_at > height * 0.35:
					# a twig out from the node, a spray at its end and one at the node
					var yaw := rng.randf_range(0.0, TAU)
					var twig := Vector3(cos(yaw), rng.randf_range(0.1, 0.45), -absf(sin(yaw)) - 0.2).normalized()
					var tip := p + twig * rng.randf_range(0.25, 0.55)
					culms.tube(p, tip, 0.008, 0.005, 4, shade)
					_leaf_spray(leaves, rng, tip, twig)
					_leaf_spray(leaves, rng, p, up)
				node_at += rng.randf_range(0.3, 0.42)
			walked += span
		# a tuft at the tip
		_leaf_spray(leaves, rng, points[-1], (points[-1] - points[-2]).normalized())
		_leaf_spray(leaves, rng, points[-1], (points[-1] - points[-2]).normalized())
	var frame := _plant_frame(at, inward)
	var grove := _holder("Bamboo")
	grove.transform = frame
	parent.add_child(grove)
	_stroke_view(grove, "Culms", culms, garden_material(&"culm"))
	_stroke_view(grove, "Leaves", leaves, garden_material(&"leaves"))
	return grove


## Four to seven narrow leaves fanning from a node at [param at] (on a culm
## running [param up]), drooping, all out of the wall (z < 0).
static func _leaf_spray(leaves: _Strokes, rng: RandomNumberGenerator, at: Vector3, up: Vector3) -> void:
	var count := rng.randi_range(5, 9)
	var heading := rng.randf_range(0.0, TAU)
	for i in count:
		var yaw := heading + rng.randf_range(-1.1, 1.1)
		var flat := Vector3(cos(yaw), 0.0, -absf(sin(yaw)) - 0.15).normalized()
		var dir := (flat + Vector3.DOWN * rng.randf_range(0.25, 0.8) + up * 0.15).normalized()
		var length := rng.randf_range(0.3, 0.46)
		var width := rng.randf_range(0.05, 0.075)
		var shade := LEAF_GREEN.lerp(Color(0.36, 0.48, 0.18), rng.randf_range(0.0, 0.7))
		var start := at + flat * rng.randf_range(0.02, 0.12)
		leaves.leaf(start, dir, length, width, shade)


## A pine leaning over the coping: its trunk rising from behind the tiles in
## a slow S over the gravel, branches out to cloud-pruned pads of needles
## (the topmost under the cornice, the lowest well over a guard's head).
static func _pine(parent: Node3D, at: Vector3, inward: Vector3, seed: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var lean := rng.randf_range(-0.25, 0.25)
	# drawn at 1:1, grown by PINE_SCALE about its root
	var root := Vector3(0.0, ROOT_Y, -0.16)
	var grow := func(p: Vector3) -> Vector3: return root + (p - root) * PINE_SCALE
	var trunk: Array[Vector3] = [root, grow.call(Vector3(lean * 0.4, 4.0, -0.75)),
		grow.call(Vector3(lean + 0.25, 4.75, -1.45)), grow.call(Vector3(lean + 0.05, 5.45, -2.05)), grow.call(Vector3(lean - 0.2, 6.1, -2.35))]
	var wood := _Strokes.new()
	for k in trunk.size() - 1:
		wood.tube(trunk[k], trunk[k + 1], 0.19 - 0.035 * k, 0.19 - 0.035 * (k + 1), 8, Color.WHITE)
	# pads: [the trunk point the branch leaves from, the pad's middle, its size]
	var pads := [
		[1, Vector3(lean - 1.0, 4.55, -1.15), Vector3(0.95, 0.3, 0.75)],
		[2, Vector3(lean + 1.15, 4.95, -1.75), Vector3(1.0, 0.32, 0.8)],
		[2, Vector3(lean - 0.75, 5.4, -2.5), Vector3(0.85, 0.28, 0.7)],
		[3, Vector3(lean + 0.75, 5.95, -2.75), Vector3(0.8, 0.28, 0.65)],
		[4, Vector3(lean - 0.25, 6.55, -2.45), Vector3(0.75, 0.3, 0.7)],
	]
	var needles := _Strokes.new()
	for pad: Array in pads:
		var from: Vector3 = trunk[int(pad[0])]
		var middle: Vector3 = grow.call(pad[1])
		var size: Vector3 = (pad[2] as Vector3) * PINE_SCALE
		wood.tube(from, middle + Vector3.DOWN * size.y * 0.5, 0.065, 0.035, 6, Color.WHITE)
		for k in 5:
			var off := Vector3(rng.randf_range(-0.45, 0.45) * size.x, rng.randf_range(-0.05, 0.12), rng.randf_range(-0.4, 0.4) * size.z)
			var s := size * Vector3(rng.randf_range(0.5, 0.78), rng.randf_range(0.8, 1.0), rng.randf_range(0.5, 0.78))
			needles.blob(middle + off, s, Color.WHITE)
	var tree := _holder("Pine")
	tree.transform = _plant_frame(at, inward)
	parent.add_child(tree)
	_stroke_view(tree, "Trunk", wood, garden_material(&"bark"))
	_stroke_view(tree, "Needles", needles, garden_material(&"needles"))
	return tree


static func _stroke_view(parent: Node3D, label: String, strokes: _Strokes, material: Material) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.name = label
	view.mesh = strokes.mesh()
	view.material_override = material
	parent.add_child(view)
	return view


## Geometry of the plants gathered into one mesh: tubes (frusta without
## caps), leaves (narrow diamonds, two-sided) and blobs (low ellipsoids),
## each with a vertex colour.
class _Strokes:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	func tube(a: Vector3, b: Vector3, r0: float, r1: float, sides: int, color: Color) -> void:
		var up := (b - a).normalized()
		var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var other := up.cross(side)
		var base := vertices.size()
		for i in sides + 1:
			var angle := TAU * i / sides
			var radial := side * cos(angle) + other * sin(angle)
			vertices.append(a + radial * r0)
			vertices.append(b + radial * r1)
			normals.append(radial)
			normals.append(radial)
			colors.append(color)
			colors.append(color)
		for i in sides:
			var k := base + i * 2
			indices.append_array([k, k + 1, k + 2, k + 2, k + 1, k + 3])

	func leaf(start: Vector3, dir: Vector3, length: float, width: float, color: Color) -> void:
		var across := dir.cross(Vector3.UP)
		if across.length_squared() < 0.0001:
			across = Vector3.RIGHT
		across = across.normalized()
		var normal := across.cross(dir).normalized()
		var base := vertices.size()
		vertices.append_array([start, start + dir * length * 0.35 + across * width * 0.5,
			start + dir * length, start + dir * length * 0.35 - across * width * 0.5])
		for i in 4:
			normals.append(normal)
			colors.append(color)
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

	func blob(middle: Vector3, size: Vector3, color: Color) -> void:
		var rings := 5
		var sides := 9
		var base := vertices.size()
		for r in rings + 1:
			var phi := PI * r / rings
			for s in sides + 1:
				var theta := TAU * s / sides
				var n := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
				vertices.append(middle + n * size)
				normals.append((n / size).normalized())
				colors.append(color)
		for r in rings:
			for s in sides:
				var k := base + r * (sides + 1) + s
				indices.append_array([k, k + sides + 1, k + 1, k + 1, k + sides + 1, k + sides + 2])

	func mesh() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var out := ArrayMesh.new()
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return out


# --- light recipe extras -------------------------------------------------------------

const GOLD := Color(1.0, 0.8, 0.45)
const PAPER := Color(1.0, 0.86, 0.66)
const ANDON := Color(1.0, 0.8, 0.55)
## Fill lamps (wide, soft, no haze, no shadow): room -> [position, range, energy].
const FILLS := {
	&"asia_china": [[Vector3(13.5, 11.6, -50.5), 16.0, 0.6]],
	&"asia_korea": [[Vector3(46.5, 7.6, -50.0), 14.0, 0.6]],
	&"asia_armor": [[Vector3(40.5, 7.6, -74.0), 14.0, 0.5]],
}
## Andons on the armour hall's floor, in its corners.
const ANDONS: Array[Vector3] = [Vector3(30.8, 0.42, -85.7), Vector3(55.7, 0.42, -62.8)]


## The lamps the Asian wing's art asks for (Floor1LightRecipe extras), by
## the rooms of [param layout]: the glow of the Buddha's halo, the light in
## the bell pavilion, paper lamps behind the shoji and the lattice windows,
## the andons, the fills, a cold sky down each of the garden's wells (the
## moon's group: no fuse), a lamp by the tea house's door. None lights the
## floor much (the exhibits' light model reads the layout's lamps).
static func extra_lights(layout: LevelLayout) -> Array:
	var out: Array = []
	if layout.room(&"asia_china") != null:
		out.append({"room": &"asia_china", "position": Vector3(Asia.BUDDHA.x, 6.32, Asia.BUDDHA.z - 1.2), "color": GOLD, "energy": 0.6,
			"range": 3.5, "rule": &"paper"})
	if layout.room(&"asia_korea") != null:
		out.append({"room": &"asia_korea", "position": Vector3(52.0, 2.2, -57.3), "color": PAPER, "energy": 0.8, "range": 4.5, "rule": &"paper"})
		for window: Array in LATTICE:
			var at: Vector3 = window[0]
			out.append({"room": &"asia_korea", "position": at + Vector3(0.0, 0.9, 0.4), "color": PAPER, "energy": 0.5, "range": 3.5, "rule": &"paper"})
	if layout.room(&"asia_armor") != null:
		for panel: Array in SHOJI:
			var basis := Basis(Vector3.UP, float(panel[1]))
			var at: Vector3 = panel[0] + basis * Vector3(0.0, 1.1, -0.4)
			out.append({"room": &"asia_armor", "position": at, "color": PAPER, "energy": 0.45, "range": 3.5, "rule": &"paper"})
		for at in ANDONS:
			out.append({"room": &"asia_armor", "position": at, "color": ANDON, "energy": 0.5, "range": 4.0, "rule": &"andon", "fixture": &"andon"})
	for room: StringName in FILLS:
		if layout.room(room) == null:
			continue
		for fill: Array in FILLS[room]:
			out.append({"room": room, "position": fill[0], "direction": Vector3.DOWN, "color": Floor1LightRecipe.FILL,
				"energy": float(fill[2]), "range": float(fill[1]), "angle": 75.0, "rule": &"fill"})
	var garden := layout.room(&"asia_garden")
	if garden != null:
		for well in garden.skylights:
			var c := well.get_center()
			var reach := garden.ceiling_y - garden.floor_y + LevelLayout.SKYLIGHT_WELL + 1.0
			out.append({"room": garden.id, "group": LightSpec.MOON, "position": Vector3(c.x, garden.ceiling_y + LevelLayout.SKYLIGHT_WELL - 0.2, c.y),
				"direction": Vector3.DOWN, "color": Floor1LightRecipe.MOON_COLOR, "energy": 0.35 * sqrt(well.get_area() / 16.0),
				"range": reach, "angle": 60.0, "rule": &"cold_fill"})
		out.append({"room": garden.id, "position": Vector3(13.2, 2.0, -82.0), "color": PAPER, "energy": 0.4, "range": 3.0, "rule": &"paper"})
	return out
