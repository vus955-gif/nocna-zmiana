class_name Floor1ArtAmericas
extends RefCounted
## Floor I's Americas and Oceania wing dressed, stage P5 (plan docs/
## superpowers/plans/2026-10-10-p5-oprawa-ameryki-dach.md section 3;
## catalogue docs/art/kit-pietro1-ameryki.md): burnished deep red plaster,
## basalt, turquoise mosaic, obsidian and carved wood; the Pacific in dark
## boards, mats and bark cloth; theatrical light from below, fire. Pure
## factories of Node3D trees of ArtLibrary models and procedural solids, no
## collision (the greybox keeps it); Floor1Art asks this module for every
## room whose id starts with "americas_":
## - [method piece_look]: the Temple of the Serpent's terraces (carved faces
##   set into their stone, corners, gaps for the flights), the altar house,
##   the altars, the fire bowls, basalt plinths; the North America hall's
##   tipi, bison and kayak on its stand, the cases of masks,
##   feathers, ancestor figures, the turquoise serpent and bark cloth, the
##   totem poles, the moai on its plinth, the whaleboat, the whaling display
##   and the harpoon gun's stand, the war canoe hanging over the collapsed
##   floor on its rope, the rubble of the fallen fire display, the carvers'
##   unfinished pole;
## - [method temple_stairs]: the terraces' flights - stone steps, the
##   alfardas drawn on the invisible railings, serpent heads on the lowest
##   steps;
## - [method dress]: the Sun Disc high on the temple's east wall, the Pacific
##   gallery's ancestor posts and bark cloths on the walls, the stolen mask
##   in the hideout, display mats under the live exhibits' slots;
## - [method fixture]: fire on iron brackets for the sconces;
## - [method extra_lights]: the embers in the altar house, the uplight on the
##   disc, the fills, a cold fill in the Moai room, the cold sky down the
##   temple's well.
## The Temple is the Two-headed Serpent's arena: nothing new stands on its
## floor loop or its terraces, no new collision (its ground rays see every
## collider but the flights' railings), its markers stay where they are.

const Americas := preload("res://src/level/floor1/zones/americas.gd")

## Every model this module places (the art tests check each is registered,
## on disk and placed).
const MODELS: Array[String] = [
	"temple_tier_4m", "temple_tier_1m", "temple_tier_corner", "temple_stair", "temple_shrine",
	"temple_altar", "americas_brazier", "sun_stone", "americas_torch_lamp", "mask_case", "pacific_figures",
	"serpent_mosaic", "feather_case", "tapa_hanging", "totem_pole_memorial", "totem_pole_house",
	"totem_pole_welcome", "totem_log", "moai", "war_canoe", "harpoon_stand", "whaling_rack", "pacific_post",
	"turquoise_mask", "rock_a", "rock_b",
	# props modelled in Blender in place of the procedural solids (plan 2026-10-21-modele-blender.md)
	"bison", "kayak", "kayak_stand", "whaleboat", "tipi",
]
## The terraces' carved faces stand into their stone by this much (the
## talud's foot is 0.5 m deep: 0.26 m of it before the collision's face, so
## the Serpent's ring round the upper terrace stays clear of it); a corner
## piece's arms take this much of each face from the corner.
const TIER_INSET := 0.24
const TIER_ARM := 0.5
## The terrace's stone mass stops this far under its collision's top (the
## faces' caps lie on it).
const TIER_TOP_DROP := 0.01
## A flight's gap in the face it climbs is this much wider each side than the
## flight (the alfardas and the heads stand there).
const STAIR_GAP := 0.2
## The serpent heads of temple_stair (both in one part) set on the lowest
## steps: scaled to the railings' axes (model x +-1.72 -> the rail's +-1.44),
## laid along the flight's pitch, the foot of their snouts a hand over the
## nosing line a little up from the foot (their upper jaws reach forward to
## it), looking down the flight.
const HEAD_SCALE := Vector3(0.837, 0.7, 0.7)
const HEAD_SNOUT := Vector3(0.0, 0.006, 0.709)
const HEAD_SNOUT_AT := 0.18
const HEAD_LIFT := 0.02
## The alfardas: stone balustrades as thick as the railing (0.12) and a hair
## more, from a little under its foot line (down into the steps) to its top,
## a rounded crown along the top edge, all inside the railing's box.
const ALFARDA_WIDTH := 0.16
const ALFARDA_DOWN := 0.35
const ALFARDA_CROWN := 0.09
## The Sun Disc on the temple's east wall, high over everybody: its back
## (model z +0.37) on the wall's face at x -4, its face to the west, the disc
## 2.95-6.55 m over the floor; two bronze brackets under it.
const SUN_AT := Vector3(-4.37, 2.5, -78.0)
const SUN_YAW := PI * 0.5
const WALL_X := -4.0
const SUN_BRACKETS: Array[float] = [-0.8, 0.8]
const BRONZE := Color(0.5, 0.36, 0.2)
## The totem poles of the totem hall by their greybox box (x, z): [model,
## yaw of its front, mirrored, offset in the box]. The memorial pole faces
## the door from the Pacific, the welcome figure the arch from the Moai room,
## the mirrored memorial the door from the North America hall; the house
## frontal pole stands with its flat back on the east wall.
const POLES := {
	Vector2(-29.75, -69.5): ["totem_pole_memorial", PI, false, Vector3.ZERO],
	Vector2(-29.75, -62.5): ["totem_pole_welcome", PI * 0.5, false, Vector3.ZERO],
	Vector2(-28.5, -55.25): ["totem_pole_memorial", -PI * 0.5, true, Vector3.ZERO],
	Vector2(-25.6, -66.0): ["totem_pole_house", PI * 0.5, false, Vector3(0.25, 0.0, 0.0)],
}
## The moai on its plinth, a third over the model's size (the room is 9 m
## high, the greybox plinth 3.2 m wide: the model's plinth fills it).
const MOAI_SCALE := 1.3
## The war canoe hanging over the collapsed floor (its greybox box is its
## hull's stand-in): its 12 m hull shrunk to the pit's 8 m, a hair south.
const CANOE_SCALE := 0.55
const CANOE_SHIFT := 0.05
## Its rope reaches this far under the pit's ceiling.
const ROPE_GAP := 0.02
## Bark cloth in the Pacific gallery's tall cases: shrunk to the glass.
const CASE_TAPA := 0.25
const TAPA_SETS: Array[String] = ["", "tapa_hanging_b", "tapa_hanging_c"]
## Ancestor posts on the Pacific gallery's walls: the kit's wall post stood on
## the floor and stretched to the rafters (their undersides 9.57 m up), its
## back on the wall face, no deeper than a relief (0.3 m: nobody walks into
## a carving a guard cannot reach for the wall anyway): [point of the wall
## face at its foot, yaw turning its front into the room]. The two on the
## west wall carry the rafters' ends.
const POST_SCALE := Vector3(1.6, 2.39, 0.75)
const POSTS := [
	[Vector3(-46.0, 0.0, -82.375), -PI * 0.5], [Vector3(-46.0, 0.0, -76.125), -PI * 0.5],
	[Vector3(-44.0, 0.0, -85.5), PI], [Vector3(-32.5, 0.0, -85.5), PI], [Vector3(-44.0, 0.0, -73.0), 0.0],
]
## Bark cloth hung on the gallery's walls: [the rod's middle on the wall face,
## yaw, texture set]: over the whaleboat on the west wall, high between the
## doors on the south wall (over the fire bowl).
const TAPAS := [
	[Vector3(-46.0, 4.6, -79.25), -PI * 0.5, ""], [Vector3(-36.0, 5.2, -73.0), 0.0, "tapa_hanging_b"],
]
## Wall-mounted heroes stand this far before the wall face.
const ON_WALL := 0.012
## The turquoise mask taken from the North America hall's case, on the crate
## by the note in the hideout behind the moai, its face to the chamber.
const HIDEOUT_MASK := Vector3(-45.3, -2.5, -45.4)
## The exhibition rooms whose live exhibits (dormant totems and jaguar
## warriors, not the walkers) get a display mat under their slots; the
## stores, the pit's rubble and the secrets' lairs get none.
const MAT_ROOMS: Array[StringName] = [&"americas_north", &"americas_totems", &"americas_moai", &"americas_pacific"]
const MAT_LIFT := 0.012
const JAGUAR_MAT := 1.5
const TOTEM_MAT := 0.9
const TURQUOISE := Color(0.2, 0.65, 0.6)
## The greybox pedestal the kayak_stand model is built for (its cradles meet
## the kayak's keel over its top).
const KAYAK_STAND := Vector3(1.0, 0.9, 5.4)

static var _basalt: Material = null
static var _stone_local: Material = null
static var _bronze: StandardMaterial3D = null
static var _materials: Dictionary = {}
static var _tiles: Dictionary = {}


# --- pieces --------------------------------------------------------------------

## The look of [param spec] (a piece of an Americas room) in its own frame,
## or null (the common rules).
static func piece_look(spec: PieceSpec, index: int, layout: LevelLayout) -> Variant:
	var size := spec.size
	match spec.kit:
		&"temple_tier":
			return _tier(spec, layout)
		&"shrine":
			return _fit("temple_shrine", Vector3.ONE)
		&"altar":
			return _altar(spec)
		&"brazier":
			return _fit("americas_brazier", Vector3(0.92, 1.0, 0.88))
		&"plinth":
			if layout != null and layout.markers.has(&"weapon_harpoon") and spec.footprint().has_point(_xz((layout.markers[&"weapon_harpoon"] as Transform3D).origin)):
				return _harpoon_stand(spec, layout.markers[&"weapon_harpoon"])
			return _basalt_block(size)
		&"pedestal":
			if spec.room == &"americas_moai":
				return _moai(size)
			if spec.room == &"americas_north" and size.z > 5.0:
				return _kayak_stand(size)
			return _plaqued_block(size)
		&"moai":
			return _holder("Visual")   # the moai stands on the plinth's look (its model is one)
		&"tipi":
			return _tipi(size)
		&"bison":
			return _bison(size)
		&"kayak":
			return _kayak(size)
		&"case":
			return _case(spec, index, layout)
		&"totem_pole":
			return _totem_pole(spec)
		&"whaleboat":
			return _whaleboat(size)
		&"harpoon_rack":
			var rack := _holder("Visual")
			ArtKit._add(rack, "whaling_rack", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, size.z * 0.5)))
			return rack
		&"war_canoe":
			return _war_canoe(spec, layout)
		&"canoe_bridge":
			return _deck(spec)
		&"rubble":
			return _rubble(spec)
		&"totem_log":
			return _fit("totem_log", Vector3.ONE)
	return null


static func _xz(at: Vector3) -> Vector2:
	return Vector2(at.x, at.z)


static func _holder(label: String) -> Node3D:
	var n := Node3D.new()
	n.name = label
	return n


## [param root] with model [param id] scaled by [param scale] at its origin.
static func _fit(id: String, scale: Vector3) -> Node3D:
	var root := _holder("Visual")
	ArtKit._add(root, id, Transform3D(Basis.from_scale(scale), Vector3.ZERO))
	return root


## A box of [param box] (in the parent's frame) in [param material].
static func _solid(parent: Node3D, box: AABB, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box.size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	view.position = box.get_center()
	parent.add_child(view)
	return view


## A cylinder of radius [param radius] (tapering to [param radius_b]) from
## [param a] to [param b].
static func _rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material, radius_b: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if radius_b < 0.0 else radius_b
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 12
	mesh.rings = 1
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	view.transform = Transform3D(Basis(side, up, side.cross(up)), (a + b) * 0.5)
	parent.add_child(view)
	return view


## Polished basalt mapped in the piece's own frame.
static func basalt() -> Material:
	if _basalt == null:
		_basalt = ArtLibrary.arch_tile("basalt_americas", true)
	return _basalt


## The temple's andesite blocks mapped in the piece's own frame (pitched and
## turned solids).
static func stone_local() -> Material:
	if _stone_local == null:
		_stone_local = ArtLibrary.arch_tile("am_stone_blocks", true)
	return _stone_local


static func bronze() -> StandardMaterial3D:
	if _bronze == null:
		_bronze = StandardMaterial3D.new()
		_bronze.resource_name = "am_bronze"
		_bronze.albedo_color = BRONZE
		_bronze.metallic = 1.0
		_bronze.roughness = 0.42
	return _bronze


## A block of basalt filling [param size] with a cap a hair wider.
static func _basalt_block(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var cap := minf(0.06, size.y * 0.15)
	_solid(root, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), Vector3(size.x, size.y - cap, size.z)), basalt())
	_solid(root, AABB(Vector3(-size.x * 0.5 - 0.03, size.y - cap, -size.z * 0.5 - 0.03), Vector3(size.x + 0.06, cap, size.z + 0.06)), basalt())
	return root


## A plain material of [param color] (shared per colour and finish).
static func _plain(color: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "%s:%.2f:%.2f" % [color.to_html(), roughness, metallic]
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.resource_name = "am_plain"
		mat.albedo_color = color
		mat.roughness = roughness
		mat.metallic = metallic
		_materials[key] = mat
	return _materials[key]


## A tile field mapped in the piece's own frame, optionally tinted (shared).
static func _tile(id: String, tint: Color = Color.WHITE) -> Material:
	var key := "%s:%s" % [id, tint.to_html()]
	if not _tiles.has(key):
		_tiles[key] = ArtLibrary.arch_tile(id, true, tint)
	return _tiles[key]


## Cedar of the stands, poles and paddles.
static func _wood() -> Material:
	return _tile("asy_cedar")


## A block of basalt filling [param size] with a brass plaque on its front.
static func _plaqued_block(size: Vector3) -> Node3D:
	var root := _basalt_block(size)
	var k := minf(1.0, (size.y - 0.04) / 0.3)
	ArtKit._add(root, "plaque_brass", Transform3D(Basis.from_scale(Vector3.ONE * k), Vector3(0.0, 0.02, -size.z * 0.5 - 0.006)))
	return root


## The moai on its plinth (one model: the head turns on its plinth's
## turntable when the harpoon hooks the ring on its back), a third over its
## size: the plinth fills the greybox plinth, the statue stands in the
## greybox moai's box over it.
static func _moai(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	var k := minf(MOAI_SCALE, size.x / 2.46)
	var moai := ArtKit._add(root, "moai", Transform3D(Basis.from_scale(Vector3.ONE * k), Vector3.ZERO))
	moai.set_meta(&"moai", true)
	return root


## A Plains tipi filling its box, its door to the front (-Z): the tipi
## model (a painted cover of smoked hide on its lodgepoles, smoke flaps on
## their poles, the oval door, pegs round its foot).
static func _tipi(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	Floor1Art.fit_model(root, "tipi", size)
	return root


## A plains bison bull filling its box, an old museum mount (the bison
## model), turned to the hall's shutter (its head low to +Z).
static func _bison(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	Floor1Art.fit_model(root, "bison", size, PI)
	return root


## The kayak's stand filling its greybox pedestal: the kayak_stand model (a
## low basalt plinth, two driftwood cradles padded with felt under the
## kayak's keel, a label to the hall), built for the pedestal KAYAK_STAND.
static func _kayak_stand(size: Vector3) -> Node3D:
	return _fit("kayak_stand", size / KAYAK_STAND)


## An Arctic skin kayak filling its box on the stand (the kayak model: a
## sealskin hull, the cockpit's coaming, thongs and a paddle on its deck).
static func _kayak(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	Floor1Art.fit_model(root, "kayak", size)
	return root


## A New England whaleboat on two trestles filling its box (the whaleboat
## model: white lapstrake hull, thwarts, oars, line tubs, irons at the bow).
static func _whaleboat(size: Vector3) -> Node3D:
	var root := _holder("Visual")
	Floor1Art.fit_model(root, "whaleboat", size)
	return root


## The display cases by room: Mexican mosaic masks (the one the night may
## fill with loot is the case the turquoise mask was taken from: empty),
## ancestor figures of the islands and the turquoise serpent in the Moai
## room, a feather shield, bark cloth in tall cases in the Pacific gallery.
## Each turned to the room from its wall.
static func _case(spec: PieceSpec, _index: int, layout: LevelLayout) -> Variant:
	var root := _holder("Visual")
	var size := spec.size
	var loot := _holds_loot(spec, layout)
	var turn := Basis(Vector3.UP, _facing(spec, layout) - spec.yaw)
	match spec.room:
		&"americas_north":
			var case := ArtKit._add(root, "mask_case", Transform3D(turn.scaled(Vector3(size.x / 2.42, size.y / 1.6, size.z / 1.02)), Vector3.ZERO))
			ArtKit._solid_glass(case)
			if loot:
				var parts := ArtLibrary.parts(case)
				for id in ["mask_1", "mask_2", "mask_3"]:
					if parts.has(id):
						(parts[id] as Node3D).visible = false
			return root
		&"americas_moai":
			var mosaic := spec.position.x > Americas.MOAI.x
			var id := "serpent_mosaic" if mosaic else "pacific_figures"
			var k := size.y / 1.8
			# (the second case of figures mirrored: a pair either side of the head)
			var mirror := -1.0 if not mosaic and spec.position.z > Americas.MOAI.z - 6.0 else 1.0
			var case2 := ArtKit._add(root, id, Transform3D(turn * Basis.from_scale(Vector3(mirror * k, k, k)), Vector3.ZERO))
			ArtKit._solid_glass(case2)
			return root
		&"americas_pacific":
			if not loot:
				var feathers := ArtKit._add(root, "feather_case", Transform3D(turn.scaled(Vector3(size.x / 2.22, size.y / 1.8, 1.0)), Vector3.ZERO))
				ArtKit._solid_glass(feathers)
				return root
			# two tall cases side by side, a bark cloth hung in each on its back
			var n := maxi(1, int(round(size.x / 1.1)))
			var w := size.x / n
			for i in n:
				var x := -size.x * 0.5 + (i + 0.5) * w
				var at := turn * Vector3(x, 0.0, 0.0)
				var tall := ArtKit._add(root, "case_tall", Transform3D(turn.scaled(Vector3(w / 1.24, size.y / 1.8, size.z / 1.24)), at))
				ArtKit._solid_glass(tall)
				var back := turn * Vector3(x, 1.6, size.z * 0.4)
				ArtKit._add(root, "tapa_hanging", Transform3D(turn * Basis.from_scale(Vector3.ONE * CASE_TAPA), back), TAPA_SETS[(i + 1) % TAPA_SETS.size()])
			return root
	root.free()
	return null


## The yaw turning a case's front (-Z) away from the wall it stands by (the
## nearest face of its room's part), to the room.
static func _facing(spec: PieceSpec, layout: LevelLayout) -> float:
	var room := layout.room(spec.room) if layout != null else null
	if room == null or room.parts.is_empty():
		return spec.yaw
	var p := _xz(spec.position)
	var best := INF
	var out := Vector2(0.0, 1.0)
	for part in room.parts:
		if not part.grow(0.1).has_point(p):
			continue
		for wall: Array in [[p.x - part.position.x, Vector2(1, 0)], [part.end.x - p.x, Vector2(-1, 0)], [p.y - part.position.y, Vector2(0, 1)], [part.end.y - p.y, Vector2(0, -1)]]:
			if float(wall[0]) < best:
				best = float(wall[0])
				out = wall[1]
	# the front (-Z turned by yaw a) points (-sin a, -cos a): along the way out
	return atan2(-out.x, -out.y)


## True when a container loot spot lies in [param spec]'s footprint.
static func _holds_loot(spec: PieceSpec, layout: LevelLayout) -> bool:
	if layout == null:
		return false
	var area := spec.footprint().grow(0.05)
	for spot in layout.loot_spots:
		if spot.room == spec.room and spot.container and area.has_point(_xz(spot.position)):
			return true
	return false


## A totem pole of the hall in its greybox box (POLES), its front to its door.
static func _totem_pole(spec: PieceSpec) -> Node3D:
	var root := _holder("Visual")
	var entry: Array = ["totem_pole_memorial", 0.0, false, Vector3.ZERO]
	for at: Vector2 in POLES:
		if at.distance_to(_xz(spec.position)) < 0.2:
			entry = POLES[at]
	var basis := Basis(Vector3.UP, float(entry[1]) - spec.yaw)
	if entry[2]:
		basis = basis * Basis.from_scale(Vector3(-1.0, 1.0, 1.0))
	ArtKit._add(root, String(entry[0]), Transform3D(basis, entry[3]))
	return root


## The harpoon gun's teak stand on its greybox plinth: its forks (along X)
## right under the weapon's marker, where the pickup lies.
static func _harpoon_stand(spec: PieceSpec, marker: Transform3D) -> Node3D:
	var root := _holder("Visual")
	var at := spec.transform().affine_inverse() * marker.origin
	ArtKit._add(root, "harpoon_stand", Transform3D(Basis(Vector3.UP, -spec.yaw).scaled(Vector3(1.0, at.y / 1.06, 1.0)), Vector3(at.x, 0.0, at.z)))
	return root


## The war canoe hanging over the collapsed floor: the kit's canoe shrunk
## into the pit's length, its slings on, its rope run up to the ceiling.
static func _war_canoe(spec: PieceSpec, layout: LevelLayout) -> Node3D:
	var root := _holder("Visual")
	var canoe := ArtKit._add(root, "war_canoe", Transform3D(Basis.from_scale(Vector3.ONE * CANOE_SCALE), Vector3(0.0, 0.0, CANOE_SHIFT)))
	canoe.set_meta(&"war_canoe", true)
	var room := layout.room(spec.room) if layout != null else null
	var rope := ArtLibrary.parts(canoe).get("rope_main") as Node3D
	if room != null and rope != null:
		# (the rope's pivot at its bottom, 2.6 m up the model; 2 m of rope over it)
		var bottom := spec.position.y + CANOE_SCALE * 2.6
		rope.scale.y = maxf(0.1, (room.ceiling_y - ROPE_GAP - bottom) / (CANOE_SCALE * 2.0))
	return root


## The planks laid over the collapse (the level's stand-in for the canoe
## the harpoon pulls down): boards on two beams.
static func _deck(spec: PieceSpec) -> Node3D:
	var root := _holder("Visual")
	var size := spec.size
	_solid(root, AABB(Vector3(-size.x * 0.5, size.y - 0.06, -size.z * 0.5), Vector3(size.x, 0.06, size.z)), _tile("boards_pacific"))
	for z: float in [-size.z * 0.4, size.z * 0.4]:
		_solid(root, AABB(Vector3(-size.x * 0.5, 0.0, z - 0.1), Vector3(size.x, size.y - 0.06, 0.2)), _wood())
	return root


## The rubble of the fallen floor filling its box: a heap of broken stone
## with splintered boards over it; the big heap holds the fire display's
## bowl, fallen on its side (its fire out).
static func _rubble(spec: PieceSpec) -> Node3D:
	var root := _holder("Visual")
	var size := spec.size
	var big := size.x > 1.5
	var id := "rock_b" if big else "rock_a"
	var box := Floor1Art.bounds(id)
	var k := Vector3(size.x / box.size.x, size.y / box.size.y, size.z / box.size.z)
	var centre := Vector3(box.get_center().x * k.x, box.position.y * k.y, box.get_center().z * k.z)
	ArtKit._add(root, id, Transform3D(Basis.from_scale(k * 0.95), -centre * 0.95))
	var boards := _tile("boards_pacific")
	for i in 3:
		var a := 0.9 * i + 0.3
		var plank := _solid(root, AABB(Vector3(-size.x * 0.36, -0.02, -0.11), Vector3(size.x * 0.72, 0.04, 0.22)), boards)
		plank.transform = Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.FORWARD, 0.25 - 0.2 * i), Vector3(0.12 * (i - 1), size.y * (0.55 + 0.15 * i), 0.1 * (1 - i)))
	if big:
		var bowl := ArtKit._add(root, "americas_brazier", Transform3D(Basis(Vector3.FORWARD, deg_to_rad(75.0)).scaled(Vector3.ONE * 0.8), Vector3(-size.x * 0.15, 0.3, -size.z * 0.1)))
		var flame := ArtLibrary.parts(bowl).get("flame") as Node3D
		if flame != null:
			flame.visible = false
		bowl.set_meta(&"fallen_bowl", true)
	return root


## A low altar against a side wall, its carved front to the arena.
static func _altar(spec: PieceSpec) -> Node3D:
	var root := _holder("Visual")
	var west := spec.position.x < Americas.SERPENT.x
	var turn := Basis(Vector3.UP, (-PI * 0.5 if west else PI * 0.5) - spec.yaw)
	ArtKit._add(root, "temple_altar", Transform3D(turn.scaled(Vector3(spec.size.x / 1.6, spec.size.y / 1.24, spec.size.z / 1.6)), Vector3.ZERO))
	return root


## A terrace of the stepped platform filling its greybox box: the stone mass
## (its top a hair under the collision's, the walked surface), the carved
## faces round it set TIER_INSET into the stone (runs of temple_tier_4/2/1m,
## a corner piece on each corner, a gap where a flight climbs the face).
static func _tier(spec: PieceSpec, layout: LevelLayout) -> Node3D:
	var root := _holder("Visual")
	var size := spec.size
	var h := Vector3(size.x * 0.5, 0.0, size.z * 0.5)
	_solid(root, AABB(Vector3(-h.x, 0.0, -h.z), Vector3(size.x, size.y - TIER_TOP_DROP, size.z)), ArtKit.field(spec.room, &"slab"))
	# the flights that climb this terrace (their tops on its top), in its frame
	var to_local := spec.transform().affine_inverse()
	var flights: Array[Rect2] = []
	if layout != null:
		for flight in layout.stairs:
			if flight.room_low == spec.room and absf(flight.top_y - (spec.position.y + size.y)) < 0.01:
				var a := to_local * Vector3(flight.rect.position.x, 0.0, flight.rect.position.y)
				var b := to_local * Vector3(flight.rect.end.x, 0.0, flight.rect.end.y)
				flights.append(Rect2(Vector2(minf(a.x, b.x), minf(a.z, b.z)), Vector2(absf(b.x - a.x), absf(b.z - a.z))))
	var corners := [[Vector3(h.x, 0.0, -h.z), 0.0], [Vector3(h.x, 0.0, h.z), -PI * 0.5], [Vector3(-h.x, 0.0, h.z), PI], [Vector3(-h.x, 0.0, -h.z), PI * 0.5]]
	for c: Array in corners:
		var at: Vector3 = c[0]
		var origin := at - Vector3(signf(at.x), 0.0, signf(at.z)) * TIER_INSET
		ArtKit._add(root, "temple_tier_corner", Transform3D(Basis(Vector3.UP, float(c[1])), origin))
	var reach := TIER_ARM + TIER_INSET
	for i in 4:
		var a2: Vector3 = corners[i][0]
		var b2: Vector3 = corners[(i + 1) % 4][0]
		var out := Vector3((a2.x + b2.x) * 0.5, 0.0, (a2.z + b2.z) * 0.5).normalized()
		var frame := ArtKit.face_transform(a2, b2, out)
		var length := a2.distance_to(b2)
		var blocked: Array = [[0.0, reach], [length - reach, length]]
		for r in flights:
			# a flight against this face: its width (and a margin) left open
			if not _touches(r, a2, b2):
				continue
			var lo := INF
			var hi := -INF
			for p: Vector2 in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y)]:
				var x := (Vector3(p.x, 0.0, p.y) - frame.origin).dot(frame.basis.x)
				lo = minf(lo, x)
				hi = maxf(hi, x)
			blocked.append([lo - STAIR_GAP, hi + STAIR_GAP])
		var face := _holder("Face")
		face.transform = frame.translated_local(Vector3(0.0, 0.0, TIER_INSET))
		root.add_child(face)
		for span: Array in ArtKit.free_spans(length, blocked):
			ArtKit.run(face, "temple_tier_", float(span[0]), float(span[1]), 0.0)
	return root


## True when the flight [param r] (terrace frame) meets the face from
## [param a] to [param b]: the face line runs along one of its ends.
static func _touches(r: Rect2, a: Vector3, b: Vector3) -> bool:
	if absf(b.x - a.x) > absf(b.z - a.z):
		var at_end := absf(a.z - r.position.y) < 0.05 or absf(a.z - r.end.y) < 0.05
		return at_end and r.position.x < maxf(a.x, b.x) and r.end.x > minf(a.x, b.x)
	var at_side := absf(a.x - r.position.x) < 0.05 or absf(a.x - r.end.x) < 0.05
	return at_side and r.position.y < maxf(a.z, b.z) and r.end.y > minf(a.z, b.z)


# --- the temple's flights -------------------------------------------------------------

## A flight of the temple in the stairs frame (StairsSpec.frame(): origin in
## the middle of the bottom front edge, -Z up the flight): solid stone steps,
## the alfardas on the railings' boxes (LevelBuilder's invisible rails: the
## same line from just up the flight to its crest) with a rounded crown, the
## two serpent heads of temple_stair lying on the lowest steps along the
## pitch, their open jaws down the flight.
static func temple_stairs(flight: StairsSpec) -> Node3D:
	var root := _holder("Stairs")
	var width := flight.width()
	var rise := flight.top_y - flight.bottom_y
	var run_length := flight.run()
	var steps := flight.step_count()
	var r := rise / steps
	var t := run_length / steps
	var stone := ArtKit.field(flight.room_low, &"stair")
	for i in steps:
		# each step a block down to the flight's foot: a solid stepped mass
		_solid(root, AABB(Vector3(-width * 0.5, 0.0, -(i + 1) * t), Vector3(width, (i + 1) * r, t)), stone)
	for side: float in [-1.0, 1.0]:
		if (side < 0.0 and not flight.rail_left) or (side > 0.0 and not flight.rail_right):
			continue
		_alfarda(root, rail_frame(flight, side), rail_length(flight), "Alfarda_%s" % ("L" if side < 0.0 else "R"))
	# the heads: the model's flight hidden, its heads laid along the pitch with
	# the snout's foot on the nosing line a little up from the first nosing
	var pitch := atan2(r, t)
	var basis := Basis(Vector3.RIGHT, pitch) * Basis.from_scale(HEAD_SCALE)
	var target := Vector3(0.0, r + HEAD_SNOUT_AT * r / t + HEAD_LIFT, -HEAD_SNOUT_AT)
	var model := ArtKit._add(root, "temple_stair", Transform3D(basis, target - basis * HEAD_SNOUT))
	var body := ArtLibrary.parts(model).get("temple_stair") as MeshInstance3D
	if body != null:
		body.mesh = null
	model.set_meta(&"serpent_heads", true)
	return root


## The frame of the railing on [param side] of [param flight] in the stairs
## frame, as LevelBuilder lays it: origin in the middle of its foot line,
## pitched up the flight (-Z), the box +-0.06 across, 0..1 m up.
static func rail_frame(flight: StairsSpec, side: float) -> Transform3D:
	var run_length := flight.run()
	var steps := flight.step_count()
	var rise := flight.top_y - flight.bottom_y
	var tread := run_length / steps
	var crest := -(steps - 1) * tread
	var run_to_crest := tread - crest
	var start := minf(LevelBuilder.STAIR_RAIL_START, run_to_crest * 0.5) / run_to_crest
	var low := Vector3(0.0, rise * start, tread - run_to_crest * start)
	var slope := Vector3(0.0, rise, crest) - low
	var x := side * (flight.width() * 0.5 - LevelBuilder.STAIR_RAIL.x * 0.5)
	return Transform3D(Basis(Vector3.RIGHT, atan2(rise, run_to_crest)), Vector3(x, 0.0, 0.0) + low + slope * 0.5)


## The length of [param flight]'s railings (LevelBuilder's).
static func rail_length(flight: StairsSpec) -> float:
	var steps := flight.step_count()
	var tread := flight.run() / steps
	var crest := -(steps - 1) * tread
	var run_to_crest := tread - crest
	var rise := flight.top_y - flight.bottom_y
	var start := minf(LevelBuilder.STAIR_RAIL_START, run_to_crest * 0.5) / run_to_crest
	var low := Vector3(0.0, rise * start, tread - run_to_crest * start)
	return (Vector3(0.0, rise, crest) - low).length()


## A stone alfarda in a railing's frame [param frame] ([param length] long):
## a block down into the steps, its crown rounded, all in the rail's box.
static func _alfarda(parent: Node3D, frame: Transform3D, length: float, label: String) -> void:
	var holder := _holder(label)
	holder.set_meta(&"alfarda", true)
	holder.transform = frame
	parent.add_child(holder)
	var top := LevelBuilder.STAIR_RAIL.y
	var crown_y := top - ALFARDA_CROWN
	_solid(holder, AABB(Vector3(-ALFARDA_WIDTH * 0.5, -ALFARDA_DOWN, -length * 0.5), Vector3(ALFARDA_WIDTH, crown_y + ALFARDA_DOWN, length)), stone_local())
	_rod(holder, Vector3(0.0, crown_y, length * 0.5), Vector3(0.0, crown_y, -length * 0.5), ALFARDA_CROWN, stone_local())


# --- fittings, gates, portals -------------------------------------------------------

## The wing's light fittings (origin = the light): a fire bowl on an iron
## bracket (its mount runs back to the wall) for every sconce of the halls;
## the staff stairs and store keep the lobby's; null = the lobby's.
static func fixture(kit: StringName, room: StringName) -> Variant:
	if kit == &"sconce" and room != &"americas_service_stairs" and room != &"americas_undercroft":
		var torch := _holder("Visual")
		ArtKit._add(torch, "americas_torch_lamp", Transform3D.IDENTITY)
		return torch
	return null


## No gates in disguise.
static func gate_leaf(_opening_id: StringName, _size: Vector3, _side: float) -> Variant:
	return null


## The wing's own portals (Floor1Art.PORTALS' form): no frame round the
## cracked wall of the carvers' workshop or the boarded store's doors.
static func portals() -> Dictionary:
	return {
		&"americas_totems_workshop": {&"americas_totems": ["", Vector2.ZERO], &"americas_workshop": ["", Vector2.ZERO]},
		&"americas_undercroft_store": {&"americas_undercroft": ["", Vector2.ZERO], &"americas_store": ["", Vector2.ZERO]},
	}


## Gates of the wing that wear leaves of their own: none.
static func disguised_gates() -> Array[StringName]:
	return []


# --- hero pieces ------------------------------------------------------------------

## The wing's hero pieces for the dressed rooms ([param rooms] empty: all)
## under [param parent] (world space).
static func dress(layout: LevelLayout, parent: Node3D, rooms: Dictionary = {}) -> void:
	if layout.room(&"americas_temple") == null:
		return
	if Floor1Art.wants(rooms, &"americas_temple"):
		_sun_disc(Floor1Art.group(parent, "SunDisc", &"americas_temple"))
	if Floor1Art.wants(rooms, &"americas_pacific"):
		var gallery := Floor1Art.group(parent, "PacificWalls", &"americas_pacific")
		for post: Array in POSTS:
			var basis := Basis(Vector3.UP, float(post[1]))
			ArtKit._add(gallery, "pacific_post", Transform3D(basis * Basis.from_scale(POST_SCALE), post[0] + basis * Vector3(0.0, 0.0, -ON_WALL)))
		for tapa: Array in TAPAS:
			var turn := Basis(Vector3.UP, float(tapa[1]))
			ArtKit._add(gallery, "tapa_hanging", Transform3D(turn, tapa[0] + turn * Vector3(0.0, 0.0, -ON_WALL)), String(tapa[2]))
	if Floor1Art.wants(rooms, &"americas_moai_hideout"):
		var hideout := Floor1Art.group(parent, "HideoutMask", &"americas_moai_hideout")
		ArtKit._add(hideout, "turquoise_mask", Transform3D(Basis(Vector3.UP, -PI * 0.5), HIDEOUT_MASK))
	_slot_mats(layout, parent, rooms)


## A display mat under every slot of the halls where a totem or a jaguar
## warrior keeps its post in the open (not the walkers): the exhibit's
## context until it wakes. Flat (no collision, no raised step: the slots'
## heights are the enemies'), turned to the slot's yaw.
static func _slot_mats(layout: LevelLayout, parent: Node3D, rooms: Dictionary) -> void:
	var groups := {}
	for i in layout.spawn_slots.size():
		var slot: SpawnSlot = layout.spawn_slots[i]
		if not MAT_ROOMS.has(slot.room) or slot.patrol != &"" or not slot.dormant or not Floor1Art.wants(rooms, slot.room):
			continue
		var jaguar := slot.kinds.has(&"jaguar")
		if not jaguar and not slot.kinds.has(&"totem"):
			continue
		if not groups.has(slot.room):
			groups[slot.room] = Floor1Art.group(parent, "ExhibitMats_%s" % slot.room, slot.room)
		var mat := _mat(jaguar)
		mat.name = "ExhibitMat_%d" % i   # (the slot's index: siblings of one name would be renamed)
		mat.transform = Transform3D(Basis(Vector3.UP, slot.yaw), slot.position)
		(groups[slot.room] as Node3D).add_child(mat)


## The mat in the slot's frame (-Z the exhibit's front): a plaited pandanus
## mat on a basalt slab for a jaguar warrior, a basalt disc with a turquoise
## ring for a totem, a brass plaque lying at its front. (The slots' mats are
## all alike: they share their meshes.)
static func _mat(jaguar: bool) -> Node3D:
	var root := _holder("ExhibitMat")
	var front := 0.0
	if jaguar:
		var half := JAGUAR_MAT * 0.5
		var slab := _mat_mesh(&"slab", Vector3(JAGUAR_MAT, MAT_LIFT * 0.8, JAGUAR_MAT))
		_mat_view(root, slab, basalt(), Vector3(0.0, MAT_LIFT * 0.4, 0.0))
		var plait := _mat_mesh(&"plait", Vector3(JAGUAR_MAT - 0.1, MAT_LIFT, JAGUAR_MAT - 0.1))
		_mat_view(root, plait, _tile("am_woven_mat"), Vector3(0.0, MAT_LIFT * 0.5, 0.0))
		front = -half + 0.12
	else:
		_mat_view(root, _mat_mesh(&"disc", Vector3.ZERO), basalt(), Vector3(0.0, MAT_LIFT * 0.5, 0.0))
		var ring := _mat_view(root, _mat_mesh(&"ring", Vector3.ZERO), _plain(TURQUOISE, 0.4), Vector3(0.0, MAT_LIFT, 0.0))
		ring.basis = Basis.from_scale(Vector3(1.0, 0.25, 1.0))
		front = -TOTEM_MAT + 0.2
	# the plaque lying flat at the mat's front (its face up, its foot to the front)
	ArtKit._add(root, "plaque_brass", Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3.ONE * 0.6), Vector3(0.0, MAT_LIFT + 0.004, front)))
	return root


## The meshes of the slot mats, made once: [param kind] "slab" and "plait"
## (boxes of [param size]), "disc" (the totem's basalt) and "ring" (its
## turquoise band).
static var _mat_meshes: Dictionary = {}


static func _mat_mesh(kind: StringName, size: Vector3) -> Mesh:
	if not _mat_meshes.has(kind):
		var mesh: Mesh
		match kind:
			&"disc":
				var disc := CylinderMesh.new()
				disc.top_radius = TOTEM_MAT
				disc.bottom_radius = TOTEM_MAT
				disc.height = MAT_LIFT
				disc.radial_segments = 32
				disc.rings = 1
				mesh = disc
			&"ring":
				var band := TorusMesh.new()
				band.inner_radius = TOTEM_MAT - 0.08
				band.outer_radius = TOTEM_MAT - 0.04
				band.rings = 40
				band.ring_segments = 6
				mesh = band
			_:
				var box := BoxMesh.new()
				box.size = size
				mesh = box
		mesh.resource_name = "exhibit_mat_%s" % kind
		_mat_meshes[kind] = mesh
	return _mat_meshes[kind]


static func _mat_view(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	view.position = at
	parent.add_child(view)
	return view


## The Sun Disc on the temple's east wall (its cradle left out), on two
## bronze brackets with struts down to the wall.
static func _sun_disc(root: Node3D) -> void:
	var stone := ArtKit._add(root, "sun_stone", Transform3D(Basis(Vector3.UP, SUN_YAW), SUN_AT))
	var cradle := ArtLibrary.parts(stone).get("sun_stone") as MeshInstance3D
	if cradle != null:
		cradle.mesh = null
	stone.set_meta(&"sun_disc", true)
	# the disc (radius 1.8, centre 4.25 m up the model) rests on the brackets
	var centre_y := SUN_AT.y + 2.25
	for dz in SUN_BRACKETS:
		var y := centre_y - sqrt(1.8 * 1.8 - dz * dz) - 0.04
		var z := SUN_AT.z + dz
		_rod(root, Vector3(WALL_X, y, z), Vector3(WALL_X - 0.55, y, z), 0.05, bronze())
		_rod(root, Vector3(WALL_X, y - 0.5, z), Vector3(WALL_X - 0.5, y - 0.02, z), 0.035, bronze())


# --- light recipe extras -------------------------------------------------------------

const EMBER := Color(1.0, 0.45, 0.15)
const UPLIGHT := Color(1.0, 0.7, 0.45)
## A fire bowl's flame over its base (the model's Light: the layout's lamp).
const BOWL_FLAME := 1.3
## The embers of the fallen fire display in the collapsed floor's rubble
## (under the layout's ember lamp): sparks only, no smoke.
const PIT_EMBERS := Vector3(-27.75, -5.2, -79.0)
## The altar house's hearth (its model's Light on the upper terrace).
const SHRINE_EMBER := Vector3(-12.0, 3.6, -72.0)
## The uplight on the Sun Disc from the floor before the east wall.
const SUN_UPLIGHT := Vector3(-6.5, 0.3, -78.0)
## Fill lamps (wide, soft, no haze, no shadow: the bounce off the red
## plaster): room -> [position, range, energy].
## (Measured in the window, 19.10: with the plan's fills of 0.6-0.7 the halls
## averaged 0.01-0.06 in luminance - Egypt's colossi, the owner's "too dark",
## 0.035 - so the fills are three times as strong and the walls are washed
## from below.)
const FILLS := {
	&"americas_temple": [[Vector3(-14.25, 11.4, -79.0), 20.0, 1.8], [Vector3(-14.25, 11.4, -65.0), 20.0, 1.8]],
	&"americas_north": [[Vector3(-17.0, 6.6, -48.5), 16.0, 2.2], [Vector3(-9.0, 6.6, -48.5), 16.0, 2.2]],
	&"americas_totems": [[Vector3(-29.5, 11.4, -66.0), 18.0, 2.4], [Vector3(-28.0, 11.4, -55.5), 14.0, 1.6]],
	&"americas_pacific": [[Vector3(-38.5, 9.4, -79.0), 16.0, 2.2]],
	&"americas_pit": [[Vector3(-27.75, 9.4, -79.0), 18.0, 1.0]],
}
## Warm washes from the floor up the red walls and the carvings (theatrical
## light from below): room -> [[foot, aim, energy, range], ...].
const WASHES := {
	&"americas_temple": [[Vector3(-23.7, 0.3, -64.0), Vector3(-24.5, 7.5, -64.0), 1.6, 11.0],
		[Vector3(-23.7, 0.3, -82.0), Vector3(-24.5, 7.5, -82.0), 1.6, 11.0], [Vector3(-4.8, 0.3, -64.0), Vector3(-4.0, 7.5, -64.0), 1.6, 11.0]],
	&"americas_north": [[Vector3(-21.3, 0.3, -52.5), Vector3(-22.0, 5.5, -52.5), 1.4, 8.0],
		[Vector3(-4.7, 0.3, -53.0), Vector3(-4.0, 5.5, -53.0), 1.4, 8.0]],
	&"americas_totems": [[Vector3(-34.0, 0.3, -69.0), Vector3(-34.5, 9.0, -69.0), 1.6, 11.0],
		[Vector3(-25.0, 0.3, -53.0), Vector3(-25.0, 8.0, -52.5), 1.6, 11.0]],
	&"americas_moai": [[Vector3(-45.5, 0.3, -68.0), Vector3(-46.0, 6.0, -68.0), 1.8, 9.0],
		[Vector3(-35.5, 0.3, -68.0), Vector3(-35.0, 6.0, -68.0), 1.8, 9.0],
		# the side walls nearer the head (the east one beside its door to the
		# totems): the room's red plaster reads all the way down its length
		[Vector3(-45.5, 0.3, -60.0), Vector3(-46.0, 6.0, -60.0), 1.6, 9.0],
		[Vector3(-35.5, 0.3, -57.5), Vector3(-35.0, 6.0, -57.5), 1.6, 9.0],
		# the back wall behind the head, either side of the hidden door: the
		# moai's silhouette against warm stone
		[Vector3(-37.6, 0.3, -53.0), Vector3(-37.8, 7.0, -52.5), 2.0, 9.0],
		[Vector3(-43.4, 0.3, -53.0), Vector3(-43.2, 7.0, -52.5), 2.0, 9.0]],
	&"americas_pacific": [[Vector3(-45.5, 0.3, -79.25), Vector3(-46.0, 4.0, -79.25), 1.2, 8.0],
		[Vector3(-33.0, 0.3, -85.0), Vector3(-32.5, 6.0, -85.5), 1.2, 8.0]],
}
## The Moai room is dark by design (one head in its beam) but not black: two
## cold fills, one over each half of the room, so its walls and floor still
## read. (Windowed, 19.10: with a single 0.9 the head view measured 0.014 in
## luminance, a third of the Egypt gallery the owner called too dark.)
## [position, range, energy].
const MOAI_FILLS := [[Vector3(-40.5, 8.6, -67.0), 16.0, 3.0], [Vector3(-40.5, 8.6, -59.0), 14.0, 2.2]]
const COLD_FILL := Color(0.55, 0.62, 0.8)
## Warm bounce off the red plaster and the rafters: omni lamps under the
## ceiling on the room's axis (the walls' washes and the fills leave the
## upper walls and the roof black): [position, range, energy].
const MOAI_BOUNCE := [[Vector3(-40.5, 6.6, -68.0), 9.0, 1.8], [Vector3(-40.5, 6.6, -61.0), 9.0, 1.8], [Vector3(-40.5, 6.6, -55.5), 7.0, 1.2]]
const BOUNCE := Color(1.0, 0.62, 0.45)
## The secret's iron ring on the back of the head's turntable (the model's
## hook_ring: 0.28 m over the plinth's top, 0.17 m off its back edge): a warm
## lamp low behind the plinth on either side of the hidden door puts the
## ring and the plinth's back in a beam, so the guard who walks round the
## head finds it. [range, energy, half angle].
const MOAI_RING := Vector3(-40.5, 1.84, -55.43)
const RING_LAMPS := [Vector3(-43.6, 0.3, -53.5), Vector3(-37.4, 0.3, -53.5)]
const RING_BEAM := [6.5, 1.6, 24.0]


## The wing's fires for the recipe's particles: [room, flame, smokes] for
## every fire bowl of the layout in an Americas room (embers and smoke over
## it) and the pit's embers in the rubble (no smoke).
static func fire_bowls(layout: LevelLayout) -> Array:
	var out: Array = []
	for spec in layout.pieces:
		if spec.kit == &"brazier" and String(spec.room).begins_with("americas_"):
			out.append([spec.room, spec.position + Vector3.UP * BOWL_FLAME, true])
	if layout.room(&"americas_pit") != null:
		out.append([&"americas_pit", PIT_EMBERS, false])
	return out


## The lamps the wing's art asks for (Floor1LightRecipe extras), by the
## rooms of [param layout]: the embers glowing in the altar house's door, the
## uplight on the Sun Disc, the fills, a cold sky down the temple's well (the
## moon's group: no fuse). None lights the floor much (the exhibits' light
## model reads the layout's lamps).
static func extra_lights(layout: LevelLayout) -> Array:
	var out: Array = []
	var temple := layout.room(&"americas_temple")
	if temple != null:
		out.append({"room": temple.id, "position": SHRINE_EMBER, "color": EMBER, "energy": 0.6, "range": 3.5, "rule": &"ember"})
		var disc := SUN_AT + Vector3(-0.2, 2.25, 0.0)
		out.append({"room": temple.id, "position": SUN_UPLIGHT, "direction": (disc - SUN_UPLIGHT).normalized(), "color": UPLIGHT,
			"energy": 2.0, "range": 10.0, "angle": 26.0, "rule": &"uplight"})
		for well in temple.skylights:
			var c := well.get_center()
			var reach := temple.ceiling_y - temple.floor_y + LevelLayout.SKYLIGHT_WELL + 1.0
			out.append({"room": temple.id, "group": LightSpec.MOON, "position": Vector3(c.x, temple.ceiling_y + LevelLayout.SKYLIGHT_WELL - 0.2, c.y),
				"direction": Vector3.DOWN, "color": Floor1LightRecipe.MOON_COLOR, "energy": 0.35 * sqrt(well.get_area() / 16.0),
				"range": reach, "angle": 60.0, "rule": &"cold_fill"})
	for room: StringName in FILLS:
		if layout.room(room) == null:
			continue
		for fill: Array in FILLS[room]:
			out.append({"room": room, "position": fill[0], "direction": Vector3.DOWN, "color": Floor1LightRecipe.FILL,
				"energy": float(fill[2]), "range": float(fill[1]), "angle": 75.0, "rule": &"fill"})
	for room: StringName in WASHES:
		if layout.room(room) == null:
			continue
		for wash: Array in WASHES[room]:
			var foot: Vector3 = wash[0]
			out.append({"room": room, "position": foot, "direction": ((wash[1] as Vector3) - foot).normalized(), "color": UPLIGHT,
				"energy": float(wash[2]), "range": float(wash[3]), "angle": 32.0, "rule": &"uplight"})
	if layout.room(&"americas_moai") != null:
		for fill: Array in MOAI_FILLS:
			out.append({"room": &"americas_moai", "position": fill[0], "direction": Vector3.DOWN, "color": COLD_FILL,
				"energy": float(fill[2]), "range": float(fill[1]), "angle": 75.0, "rule": &"fill"})
		for bounce: Array in MOAI_BOUNCE:
			out.append({"room": &"americas_moai", "position": bounce[0], "color": BOUNCE,
				"energy": float(bounce[2]), "range": float(bounce[1]), "rule": &"fill"})
		for lamp: Vector3 in RING_LAMPS:
			out.append({"room": &"americas_moai", "position": lamp, "direction": (MOAI_RING - lamp).normalized(), "color": UPLIGHT,
				"energy": float(RING_BEAM[1]), "range": float(RING_BEAM[0]), "angle": float(RING_BEAM[2]), "rule": &"uplight"})
	return out
