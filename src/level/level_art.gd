class_name LevelArt
extends RefCounted
## The lobby kit on a built level: the looks LevelBuilder gives its pieces
## instead of the greybox, and the dressing that has no greybox piece at all
## (wall bands and pilasters, coffers and beams, floor inlays, the balcony
## fascia). Pure factories of Node3D trees; collisions stay LevelKit's.
## ArtKit holds the placement rules per kit id and room (see
## docs/art/styl-przewodnik.html, "Zestaw modułowy holu"); LevelLighting
## lights the result with LobbyLightRecipe.
## Every look comes back as a "Visual" node in the piece's own frame
## (origin = centre of the base), so game code that finds a piece's
## "Visual" (the CCTV wall, the crooked plaque) keeps working.

## False: every piece keeps its greybox look (perf comparisons, the old
## greybox tests).
static var enabled: bool = true

## Kit ids with no art on purpose: pure collision.
const NO_ART: Array[StringName] = [&"stair_ramp"]
## Small furniture that is not drawn beyond SMALL_RANGE (an HLOD of sorts:
## from further away it is a few pixels, and the lobby's longest views run
## down corridors through two rooms).
const SMALL_PROPS: Array[StringName] = [&"crate", &"chair", &"desk", &"plaque", &"bench", &"lockers", &"shelf", &"case"]
const SMALL_RANGE := 60.0


## Starts loading every model on background threads. The main menu can call
## it: the first night then builds in about a tenth of a second instead of
## waiting a few seconds for the disk (behind the scene change's fade).
static func warm_up() -> void:
	for file in DirAccess.get_files_at("res://assets/models"):
		var model := file.trim_suffix(".remap").trim_suffix(".import")
		if model.ends_with(".glb"):
			ResourceLoader.load_threaded_request("res://assets/models/" + model)


# --- shell ------------------------------------------------------------------------

## Look of a carved shell box ([param aabb], world) of [param kit] (floor,
## threshold, slab, ceiling, lintel, wall): the box in the room's tile
## field, walls split at the hall's storey line. [param room] gives the
## look, [param walk_room] the floor of a box somebody walks on.
static func shell_look(kit: StringName, aabb: AABB, room: StringName, walk_room: StringName) -> Node3D:
	var root := _visual()
	var base := aabb.position + Vector3(aabb.size.x * 0.5, 0.0, aabb.size.z * 0.5)
	if kit == &"wall" or kit == &"lintel":
		for layer: Array in ArtKit.wall_layers(room, aabb):
			_box(root, layer[0], layer[1], base)
	else:
		var role := ArtKit.shell_role(kit)
		var owner := walk_room if (role == &"floor" or role == &"threshold") and walk_room != &"" else room
		_box(root, aabb, ArtKit.field(owner, role), base)
	return root


## A plain box of [param aabb] (world) with [param mat], placed relative to
## [param origin] (the owner's origin in world space).
static func _box(parent: Node3D, aabb: AABB, mat: Material, origin: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = aabb.size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = mat
	view.position = aabb.get_center() - origin
	parent.add_child(view)
	return view


static func _visual() -> Node3D:
	var n := Node3D.new()
	n.name = "Visual"
	return n


## [param look] (an ArtKit result named anything) as a piece's "Visual".
static func as_visual(look: Node3D) -> Node3D:
	if look == null:
		return null
	if look.name == "Visual":
		return look
	var root := _visual()
	root.add_child(look)
	return root


# --- pieces -----------------------------------------------------------------------

## Look of a layout piece in its own frame, or null (keep the greybox).
## [param index] varies canvases and rocks. With [param layout] a statue
## turns to its room's main doorway and a bust to the middle of its room.
## Small furniture is not drawn beyond SMALL_RANGE metres.
## True when [param spec]'s collision is drawn from its look
## (CollisionFit; Floor1Art.FIT_COLLISION) rather than its box.
static func fits_collision(spec: PieceSpec) -> bool:
	return Floor1Art.ROOM_STYLES.has(spec.room) and Floor1Art.fits_collision(spec)


## True when [param spec]'s collision is drawn from the hero pieces in its
## box (LevelBuilder._fit_to_heroes; Floor1Art.HERO_FIT).
static func fits_to_heroes(spec: PieceSpec) -> bool:
	return Floor1Art.ROOM_STYLES.has(spec.room) and Floor1Art.HERO_FIT.has("%s@%s" % [spec.kit, spec.room])


## Columns of [param spec]'s fitted collision (CollisionFit.fit).
static func fit_columns(spec: PieceSpec) -> int:
	return Floor1Art.fit_columns(spec)


static func piece_look(spec: PieceSpec, index: int, layout: LevelLayout = null) -> Node3D:
	var look := _piece_look(spec, index, layout)
	if look != null and SMALL_PROPS.has(spec.kit):
		for view in look.find_children("*", "GeometryInstance3D", true, false):
			(view as GeometryInstance3D).visibility_range_end = SMALL_RANGE
			(view as GeometryInstance3D).visibility_range_end_margin = 4.0
	return look


static func _piece_look(spec: PieceSpec, index: int, layout: LevelLayout) -> Node3D:
	if NO_ART.has(spec.kit):
		return null
	# Floor I's own fits (the court, the Reading Room, Egypt...): a look, an
	# empty Visual where a hero piece stands instead, or null (the kit rules)
	if Floor1Art.ROOM_STYLES.has(spec.room):
		var own := Floor1Art.piece_look(spec, index, layout)
		if own != null:
			return as_visual(own)
	if layout != null and (spec.kit == &"sculpture" or spec.kit == &"bust_plinth"):
		var look := as_visual(ArtKit.piece(spec.kit, spec.size, spec.room, index))
		var target: Variant = _main_door(layout, spec.room) if spec.kit == &"sculpture" else _room_middle(layout, spec.room)
		if look != null and target != null:
			var d: Vector3 = (target as Vector3) - spec.position
			if Vector2(d.x, d.z).length() > 0.5:
				look.rotation.y = atan2(-d.x, -d.z) - spec.yaw
		return look
	match spec.kit:
		&"balcony":
			# the stone slab; its fascia is wall dressing ([method dress])
			var slab := _visual()
			var slab_room := spec.room if Floor1Art.ROOM_STYLES.has(spec.room) else &"hall"
			_box(slab, AABB(Vector3(-spec.size.x * 0.5, 0.0, -spec.size.z * 0.5), spec.size), ArtKit.field(slab_room, &"slab"), Vector3.ZERO)
			return slab
		&"trex":
			var skeleton := ArtLibrary.exhibit(&"trex")
			if skeleton == null:
				return null
			skeleton.basis = Basis(Vector3.UP, -PI * 0.5)
			return as_visual(skeleton)
		&"grass":
			return grass_look(spec.size, spec.position)
		&"fuse_box":
			var cabinet := ArtKit.piece(spec.kit, spec.size, spec.room, index)
			if cabinet == null:
				return null
			var driven := FuseBoxArt.new()
			driven.name = "Visual"
			driven.add_child(cabinet)
			return driven
		&"landing":
			var block := _visual()
			_box(block, AABB(Vector3(-spec.size.x * 0.5, 0.0, -spec.size.z * 0.5), spec.size), ArtKit.field(spec.room, &"wall"), Vector3.ZERO)
			return block
	return as_visual(ArtKit.piece(spec.kit, spec.size, spec.room, index))


## Middle of the floor of the widest doorway into [param room], or null.
static func _main_door(layout: LevelLayout, room: StringName) -> Variant:
	var best: OpeningSpec = null
	for passage in layout.openings:
		if (passage.room_a == room or passage.room_b == room) and passage.door_style != OpeningSpec.DoorStyle.PANEL:
			if best == null or passage.width() > best.width():
				best = passage
	return best.center() if best != null else null


## Middle of [param room]'s first part, on its floor, or null.
static func _room_middle(layout: LevelLayout, room: StringName) -> Variant:
	var spec := layout.room(room)
	if spec == null or spec.parts.is_empty():
		return null
	var c := spec.parts[0].get_center()
	return Vector3(c.x, spec.floor_y, c.y)


## A patch of fake grass: the flocked mat plus tufts (about 1.3 per m²,
## one MultiMesh). [param at] seeds the scatter.
static func grass_look(size: Vector3, at: Vector3) -> Node3D:
	var root := _visual()
	_box(root, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size), ArtLibrary.arch_tile("grass_fake"), Vector3.ZERO)
	var tuft := ArtKit.model("grass_tuft")
	var source := tuft.find_children("*", "MeshInstance3D", true, false)
	if source.is_empty():
		tuft.free()
		return root
	var view := source[0] as MeshInstance3D
	var mesh := ArtKit.baked_mesh(view)
	var local := _relative(tuft, view)
	tuft.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x * 100.0) ^ int(at.z * 37.0)
	var count := int(size.x * size.z * 1.3)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = count
	for k in count:
		var p := Vector3(rng.randf_range(-size.x * 0.5 + 0.3, size.x * 0.5 - 0.3), size.y, rng.randf_range(-size.z * 0.5 + 0.3, size.z * 0.5 - 0.3))
		var s := rng.randf_range(0.7, 1.3)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s))
		multi.set_instance_transform(k, Transform3D(basis, p) * local)
	var tufts := MultiMeshInstance3D.new()
	tufts.name = "Tufts"
	tufts.multimesh = multi
	tufts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tufts.visibility_range_end = 40.0
	tufts.visibility_range_end_margin = 4.0
	root.add_child(tufts)
	return root


## Transform of [param node] relative to [param ancestor] (outside a tree).
static func _relative(ancestor: Node3D, node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != ancestor:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## The grand stairs' look for the stairs piece, whose frame is
## Transform3D(flight.frame().basis, middle of the flight): ArtKit.stairs
## is built in the flight frame (origin at the foot).
static func stairs_look(flight: StairsSpec) -> Node3D:
	var kit: String = ArtKit.style(flight.room_low).get("stairs_kit", "")
	if kit == "court" or kit == "library" or kit == "temple":
		var own: Node3D
		match kit:
			"court":
				own = Floor1Art.court_stairs(flight)
			"library":
				own = Floor1ArtEnlightenment.library_stairs(flight)
			_:
				own = Floor1ArtAmericas.temple_stairs(flight)
		own.position = Vector3(0.0, 0.0, flight.run() * 0.5)
		return as_visual(own)
	if BasementArt.is_basement(flight.room_low):
		# the boiler hall's gantry stairs: open steel treads (drawn from the
		# foot like the others, the look stands in the flight's middle)
		var steel := BasementArt.stairs(flight)
		steel.position = Vector3(0.0, 0.0, flight.run() * 0.5)
		return as_visual(steel)
	var hall := flight.room_low == &"hall" or ArtKit.style_name(flight.room_low) == &"entrance"
	hall = hall or ArtKit.style(flight.room_low).get("stair_rails", false)
	# balustrades only where the flight stands free in a hall; elsewhere the
	# walls close its sides (the invisible railings stay for collision)
	var node := ArtKit.stairs(flight.width(), flight.top_y - flight.bottom_y, flight.run(), flight.step_count(),
		flight.rail_left and hall, flight.rail_right and hall, flight.room_low)
	node.position = Vector3(0.0, 0.0, flight.run() * 0.5)
	return as_visual(node)


## Roof lantern over a skylight well: the piece of [param size] stands on
## the well's top (origin = centre of its base).
static func skylight_look(size: Vector3, room: StringName) -> Node3D:
	# Floor I: the court's wells lie under the hero glass roof, Egypt's carry
	# stone lattices (Floor1Art.dress) - no lanterns on top
	if Floor1Art.ROOM_STYLES.has(room):
		return hidden_look()
	return as_visual(ArtKit.piece(&"skylight", size, room))


## A pane of clear glass of [param size] (base centre at the origin) that
## casts no shadow: the roof's glass over the Great Court (the moon goes
## through it; the truss under it draws the lattice).
static func clear_glass_look(size: Vector3) -> Node3D:
	var root := _visual()
	var pane := _box(root, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size), LevelKit.glass(), Vector3.ZERO)
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


## An empty look: the piece is collision only (stair railings under the
## drawn balustrades).
static func hidden_look() -> Node3D:
	return _visual()


# --- dressing ---------------------------------------------------------------------

## Everything without a greybox piece, in world space under [param parent]:
## wall bands and pilasters of every carved room, ceilings (coffers, beams)
## and floors (the hall's border and medallion), the balcony fascia and the
## coffers under the balcony.
static func dress(layout: LevelLayout, parent: Node3D, rooms: Dictionary = {}) -> void:
	var walls := _group(parent, "Walls")
	for face in wall_faces(layout):
		if not rooms.is_empty() and not rooms.has(face["room"]):
			continue
		var holder := ArtKit.dress_wall(face)
		if holder.get_child_count() == 0:
			holder.free()
			continue
		holder.transform = face["xform"]
		walls.add_child(holder)
	var ceilings := _group(parent, "Ceilings")
	ceilings.set_meta(&"kit", &"ceiling")   # hidden with the roofs (dev view)
	var floors := _group(parent, "Floors")
	for room in layout.rooms:
		if not room.carved or (not rooms.is_empty() and not rooms.has(room.id)):
			continue
		for part in room.parts:
			for rect in minus(part, room.skylights):
				var node := ArtKit.dress_ceiling(room.id, rect.size)
				if node.get_child_count() == 0:
					node.free()
					continue
				node.position = Vector3(rect.get_center().x, room.ceiling_y, rect.get_center().y)
				ceilings.add_child(node)
		if ArtKit.style(room.id).has("border") and room.parts.size() == 1:
			var inlay := ArtKit.dress_floor(room.id, room.parts[0], Vector3(0, 0, 0) if room.id == &"hall" else null)
			inlay.position.y = room.floor_y
			floors.add_child(inlay)
	var balconies := _group(parent, "Balconies")
	for spec in layout.pieces:
		if spec.kit != &"balcony" or (not rooms.is_empty() and not rooms.has(spec.room)):
			continue
		if Floor1Art.ROOM_STYLES.has(spec.room) and not Floor1Art.wants_fascia(spec):
			continue
		var fp := spec.footprint()
		var coffer_room := spec.room if Floor1Art.ROOM_STYLES.has(spec.room) else &"hall"
		var coffers := ArtKit.dress_ceiling(coffer_room, fp.size)
		coffers.position = Vector3(fp.get_center().x, spec.position.y, fp.get_center().y)
		ceilings.add_child(coffers)
		_balcony_fascia(layout, spec, balconies)
	# coffers, beams and floor inlays shade nothing worth a shadow pass
	for group in [ceilings, floors]:
		for view in (group as Node).find_children("*", "GeometryInstance3D", true, false):
			(view as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (MultiMesh batches of the modules were measured slower: Forward+ already
	# instances equal meshes, while a batch per floor cell culls coarsely)
	for group in [walls, ceilings, floors, balconies]:
		if (group as Node).get_child_count() == 0:
			(group as Node).free()
	# Floor I: the hero pieces no greybox box stands for (the glass roof, the
	# drum and its dome, Egypt's beams and lattices...)
	if Floor1Art.is_floor1(layout):
		Floor1Art.dress(layout, parent, rooms)





static func _group(parent: Node3D, label: String) -> Node3D:
	var n := Node3D.new()
	n.name = label
	parent.add_child(n)
	return n


## Wall face records of every carved room (see [method ArtKit.dress_wall]):
## the edges of its parts where no part of the same room continues, cut
## into faces with the openings through them and, in the hall, the balcony
## slabs against them. Each record also has "xform" (the face frame in
## world space, on the room's floor). [param only]: that room's faces alone.
static func wall_faces(layout: LevelLayout, only: StringName = &"") -> Array:
	var balconies: Array[PieceSpec] = []
	for spec in layout.pieces:
		if spec.kit == &"balcony":
			balconies.append(spec)
	var out: Array = []
	for room in layout.rooms:
		if not room.carved or (only != &"" and room.id != only):
			continue
		for part in room.parts:
			var edges := [
				[Vector3(part.position.x, 0, part.position.y), Vector3(part.position.x, 0, part.end.y), Vector3.RIGHT],
				[Vector3(part.end.x, 0, part.position.y), Vector3(part.end.x, 0, part.end.y), Vector3.LEFT],
				[Vector3(part.position.x, 0, part.position.y), Vector3(part.end.x, 0, part.position.y), Vector3.BACK],
				[Vector3(part.position.x, 0, part.end.y), Vector3(part.end.x, 0, part.end.y), Vector3.FORWARD],
			]
			for e: Array in edges:
				out.append_array(_faces_on_edge(layout, room, e[0], e[1], e[2], balconies))
	return out


static func _faces_on_edge(layout: LevelLayout, room: RoomSpec, a: Vector3, b: Vector3, inward: Vector3, balconies: Array[PieceSpec]) -> Array:
	var xf := ArtKit.face_transform(a, b, inward)
	var along := xf.basis.x
	var length := a.distance_to(b)
	var cells := int(round(length / 0.5))
	# 0.5 m cells just outside the edge: open (the same room goes on) or wall
	var wall := PackedByteArray()
	wall.resize(cells)
	for i in cells:
		var p := xf.origin + along * (i + 0.5) * 0.5 - inward * 0.25
		wall[i] = 0 if room.covers(Vector2(p.x, p.z)) else 1
	var out: Array = []
	var i := 0
	while i < cells:
		if wall[i] == 0:
			i += 1
			continue
		var j := i
		while j < cells and wall[j] == 1:
			j += 1
		var x0 := i * 0.5
		var x1 := j * 0.5
		var start := xf.origin + along * x0
		var face := {
			"room": room.id, "length": x1 - x0, "height": room.ceiling_y - room.floor_y,
			"openings": [], "holes": [], "soffits": [], "balcony": [],
			"xform": Transform3D(xf.basis, start + Vector3(0, room.floor_y, 0)),
		}
		for passage in layout.openings:
			var r := passage.rect.grow(0.01)
			var hit0 := INF
			var hit1 := -INF
			for k in range(i, j):
				var p := xf.origin + along * (k + 0.5) * 0.5 - inward * 0.25
				if r.has_point(Vector2(p.x, p.z)):
					hit0 = minf(hit0, k * 0.5 - x0)
					hit1 = maxf(hit1, (k + 1) * 0.5 - x0)
			if hit0 < INF and passage.top_y > room.floor_y and passage.floor_y < room.ceiling_y:
				var top := passage.top_y - room.floor_y
				# the hole itself, before the portals' margins (wall skins)
				face["holes"].append([hit0, hit1, passage.floor_y - room.floor_y, top])
				# Floor I's portals stand wider and taller than their opening:
				# the bands and pilasters stop at the portal, not the hole
				var extent := Floor1Art.frame_extent(passage, room.id) if Floor1Art.ROOM_STYLES.has(room.id) else Vector2.ZERO
				if extent != Vector2.ZERO:
					hit0 -= extent.x
					hit1 += extent.x
					top = maxf(top, passage.floor_y - room.floor_y + extent.y)
				face["openings"].append([hit0, hit1, passage.floor_y - room.floor_y, top])
		if ArtKit.style(room.id).has("upper_from"):
			for slab in balconies:
				var fp := slab.footprint().grow(0.05)
				var s0 := INF
				var s1 := -INF
				for k in range(i, j):
					var p := xf.origin + along * (k + 0.5) * 0.5 + inward * 0.25
					if fp.has_point(Vector2(p.x, p.z)):
						s0 = minf(s0, k * 0.5 - x0)
						s1 = maxf(s1, (k + 1) * 0.5 - x0)
				if s0 < INF:
					face["soffits"].append([s0, s1, slab.position.y - room.floor_y])
					face["balcony"].append([s0, s1])
		out.append(face)
		i = j
	return out


## The moulded fascia along a balcony slab's free edges (not against a hall
## wall, not against another slab), with a return where it ends in the air
## at the stairs.
static func _balcony_fascia(layout: LevelLayout, spec: PieceSpec, parent: Node3D) -> void:
	# the hall's moulded fascia, or the room style's own (the library's walkway)
	var own := ArtKit.style(spec.room) if Floor1Art.ROOM_STYLES.has(spec.room) else {}
	var fascia: String = own.get("fascia", "balcony_fascia_")
	var fascia_end: String = own.get("fascia_end", "" if own.has("fascia") else "balcony_fascia_end")
	var fp := spec.footprint()
	# the room the slab stands in (the hall): no fascia along its walls
	var hall := Rect2()
	for room in layout.rooms:
		for part in room.parts:
			if room.carved and part.has_point(fp.get_center()):
				hall = part
	var others: Array[Rect2] = []
	for s in layout.pieces:
		if s.kit == &"balcony" and s != spec:
			others.append(s.footprint())
	var top := spec.position.y + spec.size.y
	var edges := [
		[Vector3(fp.position.x, top, fp.position.y), Vector3(fp.position.x, top, fp.end.y), Vector3.LEFT],
		[Vector3(fp.end.x, top, fp.position.y), Vector3(fp.end.x, top, fp.end.y), Vector3.RIGHT],
		[Vector3(fp.position.x, top, fp.position.y), Vector3(fp.end.x, top, fp.position.y), Vector3.FORWARD],
		[Vector3(fp.position.x, top, fp.end.y), Vector3(fp.end.x, top, fp.end.y), Vector3.BACK],
	]
	for e: Array in edges:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var out: Vector3 = e[2]
		var mid := (a + b) * 0.5
		if absf(mid.x - hall.position.x) < 0.1 or absf(mid.x - hall.end.x) < 0.1 or absf(mid.z - hall.position.y) < 0.1 or absf(mid.z - hall.end.y) < 0.1:
			continue
		var xf := ArtKit.face_transform(a, b, out)
		var length := a.distance_to(b)
		var blocked: Array = []
		var cells := int(round(length / 0.5))
		for o in others:
			var g := o.grow(0.05)
			var k0 := INF
			var k1 := -INF
			for k in cells:
				var p := xf.origin + xf.basis.x * (k + 0.5) * 0.5 - out * 0.25
				if g.has_point(Vector2(p.x, p.z)):
					k0 = minf(k0, k * 0.5)
					k1 = maxf(k1, (k + 1) * 0.5)
			if k0 < INF:
				blocked.append([k0, k1])
		var holder := Node3D.new()
		holder.name = "Fascia"
		holder.transform = xf
		parent.add_child(holder)
		var spans := ArtKit.free_spans(length, blocked)
		for s: Array in spans:
			ArtKit.run(holder, fascia, s[0], s[1], 0.0)
		# the long side runs end where the stairs arrive: close them
		if spans.size() > 0 and fascia_end != "" and (out == Vector3.LEFT or out == Vector3.RIGHT):
			var last: Array = spans[-1]
			var cap := ArtKit.model(fascia_end)
			cap.transform = Transform3D(Basis.IDENTITY, Vector3(float(last[1]) - 0.125, 0, 0))
			holder.add_child(cap)


## [param part] minus [param holes] (axis-aligned), as rectangles.
static func minus(part: Rect2, holes: Array[Rect2]) -> Array[Rect2]:
	var xs: Array[float] = [part.position.x, part.end.x]
	for h in holes:
		if h.intersects(part):
			xs.append(clampf(h.position.x, part.position.x, part.end.x))
			xs.append(clampf(h.end.x, part.position.x, part.end.x))
	xs.sort()
	var out: Array[Rect2] = []
	for k in xs.size() - 1:
		var x0 := xs[k]
		var x1 := xs[k + 1]
		if x1 - x0 < 0.01:
			continue
		var zs: Array = [[part.position.y, part.end.y]]
		for h in holes:
			if h.position.x < x1 - 0.01 and h.end.x > x0 + 0.01:
				zs = ArtKit.free_spans(part.size.y, [[h.position.y - part.position.y, h.end.y - part.position.y]]).map(
					func(s: Array) -> Array: return [s[0] + part.position.y, s[1] + part.position.y])
		for z: Array in zs:
			out.append(Rect2(x0, z[0], x1 - x0, z[1] - z[0]))
	return out
