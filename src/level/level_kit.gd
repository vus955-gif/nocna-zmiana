class_name LevelKit
## The one factory for level pieces. Every floor, wall, column, case, bench
## and lamp of a level is made here from a kit id, a size and a transform.
## A piece is a StaticBody3D (layer WORLD) when it collides, else a Node3D;
## its look is a separate "Visual" child, so stage 3 can swap in Blender
## meshes by kit id ([member art_scenes]) without touching layout or
## collision. Convention: origin = centre of the base, +Y up, -Z = front.
## Pieces carry metadata "kit" (StringName), "kit_size" (Vector3), "kit_role"
## (the material family: floor, wall, ceiling, structure, trim, door,
## fixture or prop), "kit_tint" (Color, also when art replaces the look) and,
## where the builder knows it, "kit_room"; they belong to group "level_kit".

## Stage 3 art: kit id -> PackedScene, instanced as the piece's visual in
## place of the greybox (it may read "kit_size" from its parent piece).
static var art_scenes: Dictionary = {}

const WOOD := Color(0.36, 0.25, 0.17)
const BRASS := Color(0.72, 0.58, 0.3)
const MARBLE := Color(0.86, 0.85, 0.81)
const METAL := Color(0.52, 0.54, 0.58)
const DARK := Color(0.14, 0.14, 0.16)
const BONE := Color(0.84, 0.79, 0.66)
const GRASS := Color(0.24, 0.38, 0.17)
const ROCK := Color(0.42, 0.4, 0.36)
const WARM_GLOW := Color(1.0, 0.78, 0.5)
const RED_GLOW := Color(1.0, 0.12, 0.08)
const SCREEN_GLOW := Color(0.35, 0.8, 0.7)

## Material family of a kit id (stage 3 picks textures by it); anything
## not listed is a &"prop".
const ROLES := {
	&"floor": &"floor", &"threshold": &"floor", &"slab": &"floor", &"balcony": &"floor", &"grass": &"floor",
	&"wall": &"wall", &"false_panel": &"wall", &"painting_panel": &"wall", &"vent_grille": &"wall",
	&"ceiling": &"ceiling", &"lintel": &"ceiling", &"skylight": &"ceiling",
	&"column": &"structure", &"balcony_post": &"structure", &"railing": &"structure", &"stairs": &"structure",
	&"stair_ramp": &"structure", &"pedestal": &"structure", &"landing": &"structure",
	&"door_frame": &"trim", &"door": &"door", &"door_leaf": &"door", &"grate": &"door",
	&"sconce": &"fixture", &"column_lamp": &"fixture", &"ceiling_lamp": &"fixture", &"tube_lamp": &"fixture",
	&"bulb": &"fixture", &"desk_lamp": &"fixture", &"exit_sign": &"fixture", &"emergency_lamp": &"fixture",
	&"chandelier": &"fixture",
}
## Real extent of each light fixture (the greybox draws them at this size).
const FIXTURE_SIZES := {
	&"sconce": Vector3(0.22, 0.4, 0.3),
	&"column_lamp": Vector3(0.4, 0.4, 0.6),
	&"ceiling_lamp": Vector3(0.7, 1.0, 0.7),
	&"tube_lamp": Vector3(1.3, 0.1, 0.18),
	&"bulb": Vector3(0.12, 0.4, 0.12),
	&"desk_lamp": Vector3(0.2, 0.45, 0.25),
	&"exit_sign": Vector3(0.42, 0.3, 0.1),
	&"emergency_lamp": Vector3(0.24, 0.12, 0.12),
	&"chandelier": Vector3(2.0, 2.6, 1.9),
}
## Riser height the greybox stairs use when the caller gives no step count.
const DEFAULT_RISE := 0.2
## Bars of a 3 m grate leaf (the kit model's, one collider each).
const GRATE_BARS := 16

static var _glow: Dictionary = {}
static var _glass: StandardMaterial3D = null
static var _dark: Dictionary = {}


## Builds one piece. [param size] is the full extent (x width, y height,
## z depth); [param tint] colours shell pieces and room-tinted props.
## [param params]: extra shape data, e.g. {"steps": 40} for stairs (kept as
## metadata "kit_<name>"). [param look]: the piece's art (a node named
## "Visual" in the piece's frame, see LevelArt) instead of the greybox.
static func make(kit: StringName, size: Vector3, xform: Transform3D, tint: Color, collide: bool = true, params: Dictionary = {}, look: Node3D = null) -> Node3D:
	var root: Node3D
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = Layers.WORLD
		body.collision_mask = 0
		for shape in collision_shapes(kit, size):
			body.add_child(shape)
		root = body
	else:
		root = Node3D.new()
	root.name = String(kit)
	root.transform = xform
	tag(root, kit, size)
	root.set_meta(&"kit_tint", tint)
	for key: String in params:
		root.set_meta(StringName("kit_" + key), params[key])
	if look != null:
		look.name = "Visual"
		root.add_child(look)
	else:
		root.add_child(visual(kit, size, tint, params))
		root.set_meta(&"kit_greybox", true)
	return root


## Marks [param node] as a kit piece (of room [param room] when known).
static func tag(node: Node, kit: StringName, size: Vector3, room: StringName = &"") -> void:
	node.set_meta(&"kit", kit)
	node.set_meta(&"kit_size", size)
	node.set_meta(&"kit_role", role(kit))
	if room != &"":
		node.set_meta(&"kit_room", room)
	node.add_to_group(&"level_kit")


static func role(kit: StringName) -> StringName:
	return ROLES.get(kit, &"prop")


## Switches the glow of a light fixture on or off (a lamp whose light went
## out looks dark, not lit). Greybox glow boxes go grey; kit models keep
## their paint and lose only the emission of the materials that glow. A
## node with metadata "lit_targets" (an array of nodes) switches those too:
## the glowing parts of pieces that live elsewhere in the level (a stair
## newel's lamp, the ticket booth's lamp) on the same circuit.
static func set_lit(fixture: Node, lit: bool) -> void:
	var views: Array[Node] = fixture.find_children("*", "MeshInstance3D", true, false)
	for target: Variant in fixture.get_meta(&"lit_targets", []):
		if is_instance_valid(target):
			views.append_array((target as Node).find_children("*", "MeshInstance3D", true, false))
			if target is MeshInstance3D:
				views.append(target)
	for node in views:
		var view := node as MeshInstance3D
		if view.material_override != null or view.has_meta(&"lit_material"):
			_set_override_lit(view, lit)
		else:
			_set_surfaces_lit(view, lit)


## True while something of [param fixture] (or of its "lit_targets")
## glows.
static func is_lit(fixture: Node) -> bool:
	var views: Array[Node] = fixture.find_children("*", "MeshInstance3D", true, false)
	for target: Variant in fixture.get_meta(&"lit_targets", []):
		if is_instance_valid(target):
			views.append_array((target as Node).find_children("*", "MeshInstance3D", true, false))
	for node in views:
		var view := node as MeshInstance3D
		if view.mesh == null:
			continue
		for i in view.mesh.get_surface_count():
			var mat := view.get_active_material(i) as BaseMaterial3D
			if mat != null and mat.emission_enabled and mat.emission_energy_multiplier > 0.0:
				return true
	return false


static func _set_override_lit(view: MeshInstance3D, lit: bool) -> void:
	if not view.has_meta(&"lit_material"):
		var glowing := view.material_override as StandardMaterial3D
		if glowing == null or not glowing.emission_enabled:
			return
		view.set_meta(&"lit_material", glowing)
	var original: StandardMaterial3D = view.get_meta(&"lit_material")
	view.material_override = original if lit else _unlit(original)


## A kit model: every surface whose material glows gets an unlit copy.
static func _set_surfaces_lit(view: MeshInstance3D, lit: bool) -> void:
	if view.mesh == null:
		return
	if not view.has_meta(&"lit_surfaces"):
		var glowing := {}
		for i in view.mesh.get_surface_count():
			var mat := view.get_active_material(i) as BaseMaterial3D
			if mat != null and mat.emission_enabled:
				glowing[i] = [view.get_surface_override_material(i), mat]
		view.set_meta(&"lit_surfaces", glowing)
	var surfaces: Dictionary = view.get_meta(&"lit_surfaces")
	for i: int in surfaces:
		var entry: Array = surfaces[i]
		view.set_surface_override_material(i, entry[0] if lit else _unlit_kit(entry[1]))


static func _unlit(glowing: StandardMaterial3D) -> StandardMaterial3D:
	var key := glowing.get_instance_id()
	if not _dark.has(key):
		var dark := glowing.duplicate() as StandardMaterial3D
		dark.emission_enabled = false
		dark.albedo_color = glowing.albedo_color.darkened(0.55)
		_dark[key] = dark
	return _dark[key]


## A kit material without its glow (the paint stays: a lamp shade, a lit
## sign, a booth whose atlas has a small lamp in it).
static func _unlit_kit(glowing: BaseMaterial3D) -> BaseMaterial3D:
	var key := glowing.get_instance_id()
	if not _dark.has(key):
		var dark := glowing.duplicate() as BaseMaterial3D
		dark.emission_energy_multiplier = 0.0
		_dark[key] = dark
	return _dark[key]


## Collision of a piece, relative to its base centre.
static func collision_shapes(kit: StringName, size: Vector3) -> Array[CollisionShape3D]:
	var shapes: Array[CollisionShape3D] = []
	match kit:
		&"column":
			# the drawn shaft, its base and its capital
			var cylinder := CylinderShape3D.new()
			cylinder.radius = size.x * 0.45
			cylinder.height = size.y
			shapes.append(_shape(cylinder, Vector3(0, size.y * 0.5, 0)))
			shapes.append(_box_shape(Vector3(size.x * 1.3, 0.6, size.z * 1.3), Vector3(0, 0.3, 0)))
			shapes.append(_box_shape(Vector3(size.x * 1.35, 0.8, size.z * 1.35), Vector3(0, size.y - 0.4, 0)))
		&"grate" when absf(size.x - 3.0) < 0.3:
			# the kit's leaf (grate_leaf_3m, fitted to the size): each of its 16
			# bars on its own, 0.13 m clear between them - shots fly through
			var sx := size.x / 3.0
			var sy := size.y / 5.0
			for k in GRATE_BARS:
				shapes.append(_box_shape(Vector3(0.05, size.y, 0.05), Vector3((-1.35 + 0.18 * k) * sx, size.y * 0.5, 0)))
			for x in [-1.46, 1.46]:
				shapes.append(_box_shape(Vector3(0.08, size.y, 0.08), Vector3(x * sx, size.y * 0.5, 0)))
			for y in [0.35, 2.5, 4.65]:
				shapes.append(_box_shape(Vector3(size.x, 0.08 * sy, 0.075), Vector3(0, y * sy, 0)))
			shapes.append(_box_shape(Vector3(size.x, 0.12 * sy, 0.075), Vector3(0, size.y - 0.06 * sy, 0)))
		&"grate":
			# every bar and rail on its own: shots fly between the bars
			var bars := maxi(int(size.x / 0.22), 2)
			for i in bars + 1:
				shapes.append(_box_shape(Vector3(0.06, size.y, 0.06), Vector3(-size.x * 0.5 + i * size.x / bars, size.y * 0.5, 0)))
			for y in [0.15, size.y * 0.5, size.y - 0.15]:
				shapes.append(_box_shape(Vector3(size.x, 0.1, 0.1), Vector3(0, y, 0)))
		&"dead_tree":
			# only the trunk stops anybody; the crown hangs over the grass
			shapes.append(_box_shape(Vector3(0.5, size.y * 0.55, 0.5), Vector3(0, size.y * 0.275, 0)))
		&"trex":
			# torso and hips, the two legs; neck, skull and tail stay out of reach
			shapes.append(_box_shape(Vector3(size.x * 0.36, size.y * 0.3, size.z * 0.6), Vector3(0, size.y * 0.62, 0)))
			for side in [-1.0, 1.0]:
				shapes.append(_box_shape(Vector3(size.x * 0.08, size.y * 0.48, size.z * 0.18), Vector3(size.x * 0.03, size.y * 0.24, side * size.z * 0.3)))
		_:
			shapes.append(_box_shape(size, Vector3(0, size.y * 0.5, 0)))
	return shapes


## The greybox look of a piece (door leaves and panels reuse it inside
## their own moving bodies).
static func visual(kit: StringName, size: Vector3, tint: Color, params: Dictionary = {}) -> Node3D:
	var look := _Look.new()
	if art_scenes.has(kit):
		var holder := Node3D.new()
		holder.name = "Visual"
		# the art keeps what the greybox knew (size, room tint, step count)
		holder.set_meta(&"kit_size", size)
		holder.set_meta(&"kit_tint", tint)
		for key: String in params:
			holder.set_meta(StringName("kit_" + key), params[key])
		holder.add_child((art_scenes[kit] as PackedScene).instantiate())
		return holder
	var h := size.y
	match kit:
		&"floor", &"threshold", &"slab":
			look.box(size, Vector3(0, h * 0.5, 0), flat(tint.darkened(0.3)))
		&"ceiling", &"lintel":
			look.box(size, Vector3(0, h * 0.5, 0), flat(tint.lightened(0.08)))
		&"column":
			var shaft_mat := flat(tint.lightened(0.12))
			look.box(Vector3(size.x * 1.3, 0.6, size.z * 1.3), Vector3(0, 0.3, 0), flat(tint))
			look.cylinder(size.x * 0.45, h - 1.4, Vector3(0, 0.6 + (h - 1.4) * 0.5, 0), shaft_mat)
			look.box(Vector3(size.x * 1.35, 0.8, size.z * 1.35), Vector3(0, h - 0.4, 0), flat(tint))
		&"balcony_post":
			look.box(Vector3(size.x, h - 0.3, size.z), Vector3(0, (h - 0.3) * 0.5, 0), flat(tint.lightened(0.1)))
			look.box(Vector3(size.x * 1.4, 0.3, size.z * 1.4), Vector3(0, h - 0.15, 0), flat(tint))
		&"railing":
			look.box(Vector3(size.x, h - 0.1, size.z), Vector3(0, (h - 0.1) * 0.5, 0), flat(tint.lightened(0.05)))
			look.box(Vector3(size.x + 0.04, 0.1, size.z + 0.14), Vector3(0, h - 0.05, 0), flat(tint.darkened(0.2)))
		&"stairs":
			var steps := int(params.get("steps", maxi(int(round(size.y / DEFAULT_RISE)), 1)))
			_stairs(look, size, flat(tint.darkened(0.15)), steps)
		&"stair_ramp":
			pass
		&"pedestal":
			look.box(Vector3(size.x, h - 0.15, size.z), Vector3(0, (h - 0.15) * 0.5, 0), flat(tint.darkened(0.25)))
			look.box(Vector3(size.x + 0.2, 0.15, size.z + 0.2), Vector3(0, h - 0.075, 0), flat(MARBLE))
		&"plinth":
			look.box(size, Vector3(0, h * 0.5, 0), flat(MARBLE.darkened(0.08)))
		&"bust_plinth":
			look.box(Vector3(size.x, h - 0.6, size.z), Vector3(0, (h - 0.6) * 0.5, 0), flat(MARBLE.darkened(0.1)))
			look.box(Vector3(size.x * 0.75, 0.22, size.z * 0.5), Vector3(0, h - 0.49, 0), flat(MARBLE))
			look.sphere(0.17, Vector3(0, h - 0.2, 0), flat(MARBLE))
		&"sculpture":
			look.box(Vector3(size.x, 1.0, size.z), Vector3(0, 0.5, 0), flat(MARBLE.darkened(0.1)))
			look.box(Vector3(size.x * 0.35, (h - 1.0) * 0.55, size.z * 0.3), Vector3(0, 1.0 + (h - 1.0) * 0.275, 0), flat(MARBLE))
			look.box(Vector3(size.x * 0.5, (h - 1.0) * 0.3, size.z * 0.32), Vector3(0, 1.0 + (h - 1.0) * 0.7, 0), flat(MARBLE))
			look.sphere(size.x * 0.12, Vector3(0, h - size.x * 0.12, 0), flat(MARBLE))
		&"case", &"crystal_case":
			look.box(Vector3(size.x, 0.9, size.z), Vector3(0, 0.45, 0), flat(WOOD))
			look.box(Vector3(size.x - 0.06, h - 0.95, size.z - 0.06), Vector3(0, 0.9 + (h - 0.95) * 0.5, 0), glass())
			look.box(Vector3(size.x, 0.05, size.z), Vector3(0, h - 0.025, 0), flat(BRASS))
		&"bench":
			look.box(Vector3(size.x, 0.1, size.z), Vector3(0, h - 0.05, 0), flat(WOOD))
			for side in [-1.0, 1.0]:
				look.box(Vector3(0.12, h - 0.1, size.z * 0.85), Vector3(side * (size.x * 0.5 - 0.2), (h - 0.1) * 0.5, 0), flat(DARK))
		&"ticket_booth":
			look.box(Vector3(size.x, 1.1, size.z), Vector3(0, 0.55, 0), flat(WOOD))
			look.box(Vector3(size.x - 0.1, h - 1.4, size.z - 0.1), Vector3(0, 1.1 + (h - 1.4) * 0.5, 0), glass())
			look.box(Vector3(size.x + 0.3, 0.3, size.z + 0.3), Vector3(0, h - 0.15, 0), flat(WOOD.darkened(0.2)))
			for cx in [-1.0, 1.0]:
				for cz in [-1.0, 1.0]:
					look.box(Vector3(0.12, h - 1.4, 0.12), Vector3(cx * (size.x * 0.5 - 0.06), 1.1 + (h - 1.4) * 0.5, cz * (size.z * 0.5 - 0.06)), flat(WOOD.darkened(0.2)))
			look.box(Vector3(size.x * 0.5, 0.06, 0.4), Vector3(0, 1.13, -size.z * 0.5 - 0.1), flat(BRASS))
		&"info_desk":
			look.box(Vector3(size.x, h - 0.06, size.z), Vector3(0, (h - 0.06) * 0.5, 0), flat(WOOD))
			look.box(Vector3(size.x + 0.1, 0.06, size.z + 0.1), Vector3(0, h - 0.03, 0), flat(MARBLE))
		&"desk":
			look.box(Vector3(size.x, 0.06, size.z), Vector3(0, h - 0.03, 0), flat(WOOD))
			for side in [-1.0, 1.0]:
				look.box(Vector3(0.06, h - 0.06, size.z), Vector3(side * (size.x * 0.5 - 0.03), (h - 0.06) * 0.5, 0), flat(WOOD.darkened(0.2)))
		&"chair":
			look.box(Vector3(size.x, 0.08, size.z), Vector3(0, 0.46, 0), flat(DARK))
			look.box(Vector3(size.x, h - 0.5, 0.08), Vector3(0, 0.5 + (h - 0.5) * 0.5, size.z * 0.5 - 0.04), flat(DARK))
			look.box(Vector3(0.06, 0.42, 0.06), Vector3(0, 0.21, 0), flat(METAL))
		&"lockers":
			look.box(size, Vector3(0, h * 0.5, 0), flat(METAL.darkened(0.15)))
			var doors := maxi(int(size.x / 0.5), 1)
			for i in doors:
				var x := -size.x * 0.5 + (i + 0.5) * size.x / doors
				look.box(Vector3(size.x / doors - 0.04, h - 0.1, 0.02), Vector3(x, h * 0.5, -size.z * 0.5 - 0.01), flat(METAL))
		&"cctv_wall":
			look.box(size, Vector3(0, h * 0.5, 0), flat(DARK))
			for row in 3:
				for col in 3:
					var screen := Vector3((col - 1) * size.x / 3.0, h * (0.3 + row * 0.25), -size.z * 0.5 - 0.02)
					look.box(Vector3(size.x / 3.0 - 0.12, h * 0.2, 0.04), screen, emissive(SCREEN_GLOW, 0.6))
		&"terminal":
			look.box(Vector3(size.x, h, size.z), Vector3(0, h * 0.5, 0), flat(DARK.lightened(0.1)))
			look.box(Vector3(size.x * 0.8, h * 0.3, 0.04), Vector3(0, h * 0.7, -size.z * 0.5 - 0.02), emissive(WARM_GLOW, 0.8))
		&"armor_rack":
			look.box(Vector3(size.x, 0.25, size.z), Vector3(0, 0.125, 0), flat(WOOD.darkened(0.2)))
			look.box(Vector3(0.18, 0.75, 0.2), Vector3(-0.12, 0.62, 0), flat(METAL))
			look.box(Vector3(0.18, 0.75, 0.2), Vector3(0.12, 0.62, 0), flat(METAL))
			look.box(Vector3(0.6, 0.75, 0.38), Vector3(0, 1.38, 0), flat(METAL.lightened(0.1)))
			look.box(Vector3(0.3, 0.34, 0.32), Vector3(0, 1.93, 0), flat(METAL.lightened(0.1)))
		&"rock":
			look.box(Vector3(size.x, h * 0.7, size.z), Vector3(0, h * 0.35, 0), flat(ROCK))
			look.box(Vector3(size.x * 0.6, h * 0.45, size.z * 0.7), Vector3(size.x * 0.12, h * 0.77, -size.z * 0.05), flat(ROCK.lightened(0.08)))
		&"grass":
			look.box(size, Vector3(0, h * 0.5, 0), flat(GRASS))
		&"fence":
			look.box(Vector3(size.x, 0.08, size.z), Vector3(0, h - 0.04, 0), flat(WOOD))
			look.box(Vector3(size.x, 0.06, size.z), Vector3(0, h * 0.45, 0), flat(WOOD))
			for side in [-1.0, 1.0]:
				look.box(Vector3(0.1, h, maxf(size.z, 0.1)), Vector3(side * (size.x * 0.5 - 0.05), h * 0.5, 0), flat(WOOD.darkened(0.2)))
		&"painting":
			look.box(size, Vector3(0, h * 0.5, 0), flat(BRASS.darkened(0.3)))
			look.box(Vector3(size.x - 0.2, h - 0.2, 0.02), Vector3(0, h * 0.5, -size.z * 0.5 - 0.01), flat(tint))
		&"plaque":
			look.box(size, Vector3(0, h * 0.5, 0), flat(BRASS))
		&"fuse_box":
			look.box(size, Vector3(0, h * 0.5, 0), flat(Color(0.3, 0.36, 0.3)))
			look.box(Vector3(size.x - 0.08, h - 0.08, 0.02), Vector3(0, h * 0.5, -size.z * 0.5 - 0.01), flat(Color(0.4, 0.46, 0.38)))
			look.box(Vector3(0.05, 0.05, 0.03), Vector3(size.x * 0.3, h * 0.8, -size.z * 0.5 - 0.02), emissive(RED_GLOW, 2.0))
		&"shelf":
			for i in 4:
				look.box(Vector3(size.x, 0.04, size.z), Vector3(0, 0.1 + i * (h - 0.2) / 3.0, 0), flat(WOOD))
			for side in [-1.0, 1.0]:
				look.box(Vector3(0.04, h, size.z), Vector3(side * (size.x * 0.5 - 0.02), h * 0.5, 0), flat(WOOD.darkened(0.2)))
		&"door_leaf":
			look.box(size, Vector3(0, h * 0.5, 0), flat(tint))
			look.box(Vector3(size.x - 0.3, h - 0.5, size.z + 0.04), Vector3(0, h * 0.5, 0), flat(tint.lightened(0.12)))
		&"false_panel":
			look.box(size, Vector3(0, h * 0.5, 0), flat(tint))
			# faint seams: readable only up close, like a real service panel
			for side in [-1.0, 1.0]:
				look.box(Vector3(0.015, h, size.z + 0.01), Vector3(side * (size.x * 0.5 - 0.01), h * 0.5, 0), flat(tint.darkened(0.35)))
		&"painting_panel":
			# a wall panel carrying a big framed painting (hides a passage)
			look.box(size, Vector3(0, h * 0.5, 0), flat(tint))
			for face in [-1.0, 1.0]:
				var z: float = face * (size.z * 0.5 + 0.03)
				look.box(Vector3(size.x * 0.8, h * 0.6, 0.06), Vector3(0, h * 0.55, z), flat(BRASS.darkened(0.3)))
				look.box(Vector3(size.x * 0.7, h * 0.5, 0.08), Vector3(0, h * 0.55, z), flat(Color(0.35, 0.22, 0.2)))
		&"vent_grille":
			look.box(size, Vector3(0, h * 0.5, 0), flat(DARK.lightened(0.15)))
			var slats := maxi(int(h / 0.12), 2)
			for i in slats:
				for face in [-1.0, 1.0]:
					look.box(Vector3(size.x - 0.1, 0.03, 0.03), Vector3(0, 0.08 + i * (h - 0.16) / (slats - 1), face * (size.z * 0.5 + 0.015)), flat(METAL))
		&"crate":
			look.box(size, Vector3(0, h * 0.5, 0), flat(WOOD.lightened(0.1)))
			look.box(Vector3(size.x + 0.02, 0.08, size.z + 0.02), Vector3(0, h - 0.04, 0), flat(WOOD.darkened(0.2)))
		&"grate":
			var bars := maxi(int(size.x / 0.22), 2)
			for i in bars + 1:
				look.box(Vector3(0.06, h, 0.06), Vector3(-size.x * 0.5 + i * size.x / bars, h * 0.5, 0), flat(DARK.lightened(0.2)))
			for y in [0.15, h * 0.5, h - 0.15]:
				look.box(Vector3(size.x, 0.1, 0.1), Vector3(0, y, 0), flat(DARK.lightened(0.2)))
		&"door_frame":
			# trim around the opening on both faces; size = opening (w, h, depth)
			var trim := flat(tint.darkened(0.35))
			for face in [-1.0, 1.0]:
				var z: float = face * (size.z * 0.5 + 0.05)
				for side in [-1.0, 1.0]:
					# the jamb trim laps 6 cm over the opening: it hides the slit
					# between a shut leaf and its jamb
					look.box(Vector3(0.26, h + 0.2, 0.1), Vector3(side * (size.x * 0.5 + 0.07), (h + 0.2) * 0.5, z), trim)
				look.box(Vector3(size.x + 0.6, 0.25, 0.12), Vector3(0, h + 0.125, z), trim)
		&"skylight":
			_skylight(look, size)
		&"trex":
			_trex(look, size)
		# light fixtures: the origin is where the light itself sits, the
		# mount runs back along +Z (towards the wall) or up
		&"sconce":
			look.box(Vector3(0.2, 0.34, 0.05), Vector3(0, -0.05, 0.16), flat(BRASS))
			look.box(Vector3(0.05, 0.05, 0.14), Vector3(0, -0.12, 0.08), flat(BRASS))
			look.box(Vector3(0.22, 0.2, 0.22), Vector3(0, 0, 0), emissive(WARM_GLOW, 3.0))
		&"column_lamp":
			look.box(Vector3(0.08, 0.08, 0.55), Vector3(0, 0.1, 0.3), flat(BRASS))
			look.sphere(0.2, Vector3.ZERO, emissive(WARM_GLOW, 3.5))
		&"ceiling_lamp":
			look.box(Vector3(0.04, 0.8, 0.04), Vector3(0, 0.55, 0), flat(DARK))
			look.cylinder(0.35, 0.18, Vector3(0, 0.1, 0), flat(BRASS.darkened(0.3)))
			look.box(Vector3(0.45, 0.03, 0.45), Vector3(0, 0.0, 0), emissive(WARM_GLOW, 3.0))
		&"tube_lamp":
			look.box(Vector3(1.3, 0.05, 0.18), Vector3(0, 0.05, 0), flat(METAL))
			look.box(Vector3(1.2, 0.05, 0.08), Vector3(0, 0, 0), emissive(Color(0.85, 1.0, 0.9), 2.5))
		&"bulb":
			look.box(Vector3(0.015, 0.3, 0.015), Vector3(0, 0.2, 0), flat(DARK))
			look.sphere(0.06, Vector3.ZERO, emissive(WARM_GLOW, 4.0))
		&"desk_lamp":
			look.box(Vector3(0.16, 0.03, 0.16), Vector3(0, -0.37, 0.06), flat(DARK))
			look.box(Vector3(0.03, 0.35, 0.03), Vector3(0, -0.19, 0.06), flat(DARK))
			look.box(Vector3(0.2, 0.1, 0.16), Vector3(0, 0, 0), emissive(WARM_GLOW, 2.0))
		&"exit_sign":
			look.box(Vector3(0.42, 0.18, 0.06), Vector3(0, 0.09, 0), emissive(Color(0.15, 1.0, 0.35), 1.6))
			look.box(Vector3(0.14, 0.1, 0.1), Vector3(0, -0.07, -0.04), emissive(RED_GLOW, 3.0))
		&"emergency_lamp":
			look.box(Vector3(0.24, 0.12, 0.12), Vector3(0, 0.06, 0), emissive(RED_GLOW, 3.0))
		_:
			look.box(size, Vector3(0, h * 0.5, 0), flat(tint))
	return look.finish()


## World-aligned grid material (like the 1a greybox), one per colour.
static func flat(color: Color) -> StandardMaterial3D:
	return Greybox.material(color)


static func emissive(color: Color, energy: float) -> StandardMaterial3D:
	var key := "%s_%.2f" % [color.to_html(), energy]
	if not _glow.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = energy
		_glow[key] = mat
	return _glow[key]


static func glass() -> StandardMaterial3D:
	if _glass == null:
		_glass = StandardMaterial3D.new()
		_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass.albedo_color = Color(0.7, 0.85, 0.9, 0.16)
		_glass.roughness = 0.05
		_glass.metallic_specular = 0.9
		_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _glass


static func _shape(shape: Shape3D, at: Vector3) -> CollisionShape3D:
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = at
	return collider


static func _box_shape(size: Vector3, at: Vector3) -> CollisionShape3D:
	var box := BoxShape3D.new()
	box.size = size
	return _shape(box, at)


## One stepped block of [param steps] steps: x = width, y = rise, z = run
## (steps climb towards -Z from the front edge at z = +size.z / 2).
static func _stairs(look: _Look, size: Vector3, mat: Material, steps: int) -> void:
	steps = maxi(steps, 1)
	var rise := size.y / steps
	var tread := size.z / steps
	for i in steps:
		var height := rise * (i + 1)
		var z := size.z * 0.5 - tread * (i + 0.5)
		look.box(Vector3(size.x, height, tread), Vector3(0, height * 0.5, z), mat)


static func _skylight(look: _Look, size: Vector3) -> void:
	var frame := flat(DARK.lightened(0.15))
	look.box(Vector3(size.x, size.y, 0.2), Vector3(0, size.y * 0.5, -size.z * 0.5 + 0.1), frame)
	look.box(Vector3(size.x, size.y, 0.2), Vector3(0, size.y * 0.5, size.z * 0.5 - 0.1), frame)
	look.box(Vector3(0.2, size.y, size.z), Vector3(-size.x * 0.5 + 0.1, size.y * 0.5, 0), frame)
	look.box(Vector3(0.2, size.y, size.z), Vector3(size.x * 0.5 - 0.1, size.y * 0.5, 0), frame)
	# mullions every ~1.5 m along the long side: they stripe the moonlight
	var along_x := size.x >= size.z
	var length := size.x if along_x else size.z
	var bars := maxi(int(length / 1.5), 1)
	for i in range(1, bars):
		var offset := -length * 0.5 + i * length / bars
		if along_x:
			look.box(Vector3(0.1, size.y, size.z), Vector3(offset, size.y * 0.5, 0), frame)
		else:
			look.box(Vector3(size.x, size.y, 0.1), Vector3(0, size.y * 0.5, offset), frame)
	var pane := look.box(Vector3(size.x, 0.02, size.z), Vector3(0, size.y, 0), glass())
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Placeholder T-Rex skeleton lying along X with the skull at +X
## (x = length ~11 m, y = height ~5 m, z = width ~3 m). Bone-coloured boxes.
static func _trex(look: _Look, size: Vector3) -> void:
	var bone := flat(BONE)
	var dark := flat(BONE.darkened(0.25))
	var l := size.x
	var hgt := size.y
	# legs (thigh + shin + foot) at the hips
	for side in [-1.0, 1.0]:
		var z: float = side * size.z * 0.3
		look.box(Vector3(l * 0.07, hgt * 0.28, 0.35), Vector3(l * 0.02, hgt * 0.5, z), bone)
		look.box(Vector3(l * 0.05, hgt * 0.3, 0.28), Vector3(l * 0.05, hgt * 0.2, z), bone)
		look.box(Vector3(l * 0.1, 0.12, 0.45), Vector3(l * 0.08, 0.06, z), dark)
	# spine from tail tip to neck, rising towards the hips
	var spine := 11
	for i in spine:
		var t := float(i) / (spine - 1)
		var x := lerpf(-l * 0.5, l * 0.22, t)
		var y := hgt * (0.35 + 0.35 * sin(t * PI * 0.9))
		look.box(Vector3(l * 0.07, 0.22, 0.22), Vector3(x, y, 0), bone)
	# ribs hang under the chest
	for i in 6:
		var x := lerpf(-l * 0.08, l * 0.16, i / 5.0)
		look.box(Vector3(0.1, hgt * 0.26, size.z * 0.55), Vector3(x, hgt * 0.52, 0), dark)
	# neck and skull
	look.box(Vector3(l * 0.12, 0.3, 0.3), Vector3(l * 0.3, hgt * 0.78, 0), bone)
	look.box(Vector3(l * 0.13, hgt * 0.17, size.z * 0.3), Vector3(l * 0.42, hgt * 0.85, 0), bone)
	look.box(Vector3(l * 0.11, hgt * 0.06, size.z * 0.26), Vector3(l * 0.42, hgt * 0.72, 0), dark)
	# small arms
	for side in [-1.0, 1.0]:
		look.box(Vector3(0.1, hgt * 0.12, 0.1), Vector3(l * 0.24, hgt * 0.56, side * size.z * 0.18), bone)


## Collects the parts of one greybox look, then merges them into one mesh
## per material (a column is 2 draw calls, not 3; a stair flight is 1).
class _Look:
	var _parts: Dictionary = {}   # Material -> Array of [Mesh, Transform3D]
	var _loose: Array[MeshInstance3D] = []

	func box(size: Vector3, center: Vector3, mat: Material) -> MeshInstance3D:
		var mesh := BoxMesh.new()
		mesh.size = size
		return _add(mesh, Transform3D(Basis.IDENTITY, center), mat)

	func cylinder(radius: float, height: float, center: Vector3, mat: Material) -> MeshInstance3D:
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = 16
		mesh.rings = 1
		return _add(mesh, Transform3D(Basis.IDENTITY, center), mat)

	func sphere(radius: float, center: Vector3, mat: Material) -> MeshInstance3D:
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = 12
		mesh.rings = 6
		return _add(mesh, Transform3D(Basis.IDENTITY, center), mat)

	## Glass and other see-through parts stay separate instances (returned,
	## so shadows can be switched off); opaque parts are merged later.
	func _add(mesh: Mesh, xform: Transform3D, mat: Material) -> MeshInstance3D:
		var base := mat as BaseMaterial3D
		if base != null and base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			var view := MeshInstance3D.new()
			view.mesh = mesh
			view.transform = xform
			view.material_override = mat
			_loose.append(view)
			return view
		if not _parts.has(mat):
			_parts[mat] = []
		(_parts[mat] as Array).append([mesh, xform])
		return null

	func finish() -> Node3D:
		var holder := Node3D.new()
		holder.name = "Visual"
		for mat: Material in _parts:
			var list: Array = _parts[mat]
			var view := MeshInstance3D.new()
			if list.size() == 1 and (list[0][1] as Transform3D).origin == Vector3.ZERO:
				view.mesh = list[0][0]
			elif list.size() == 1:
				view.mesh = list[0][0]
				view.transform = list[0][1]
			else:
				var tool := SurfaceTool.new()
				for entry: Array in list:
					tool.append_from(entry[0], 0, entry[1])
				view.mesh = tool.commit()
			view.material_override = mat
			holder.add_child(view)
		for view in _loose:
			holder.add_child(view)
		return holder
