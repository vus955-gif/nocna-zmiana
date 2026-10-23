extends TestCase
## The reactive environment and the tools on the built Floor I (plan
## docs/superpowers/plans/2026-10-21-srodowisko-walka.md): every tool of
## the catalog is built, in its room, its strike inside that room and clear
## of its passages, stairs and the things the guard must reach, never in a
## guardian's arena, its load over the guard's head, its tag seen from the
## floor; the floor's props within the budget and asleep; and nothing the
## environment does - every tool set off, every prop broken - adds or moves
## a collider that blocks anyone (the softlock rule: what moves leaves no
## collision; standing tools keep theirs where they always stood).

## A stand-in for the Museum: the layer reads its guard and night.
class Host extends Node3D:
	var player: Player = null
	var run: NightState = null

const PASSAGE_CLEARANCE := 1.25
const MARKER_CLEARANCE := 1.0
## A standing tool keeps this far from where an exhibit may start the night.
const SLOT_CLEARANCE := 1.25
const MARKERS := ["weapon_", "note_", "secret_", "chess_", "fuse_", "seal_", "shard_", "loudspeaker_", "audioguide_", "museum_map_", "switchboard", "ticket_drawer", "flare_cabinet", "rosetta"]
## A hanging load clears the guard's head by this much (his eye 1.6 m).
const HEADROOM := 2.4

var host: Host
var level: MuseumFloorLevel
var env: EnvLayer
## Every blocking collision shape of the built floor before the layer came.
var bare: Dictionary = {}


func after_each() -> void:
	if is_instance_valid(host):
		host.free()


func _build() -> void:
	host = Host.new()
	host.name = "Host"
	add_child(host)
	host.run = NightState.new()
	host.add_child(host.run)
	level = MuseumFloorLevel.new()
	level.skip_kits = GateLocks.replaced_kits()
	level.bake_navigation = false
	host.add_child(level)
	level.build()
	bare = _blocking(host)
	var started := Time.get_ticks_usec()
	env = EnvLayer.install(level, host)
	print("env: %d props (%s), %d tools, %d zones, installed in %.1f ms" % [env.props.size(), env.stats()["kinds"], env.tools.size(), env.stats()["zones"], (Time.get_ticks_usec() - started) / 1000.0])
	await physics_frames(2)


func _tool(tool_id: StringName) -> EnvTool:
	for each in env.tools:
		if each.id == tool_id:
			return each as EnvTool
	return null


## The tool's strike on the floor as points (its disc's rim, its lane's
## corners) and as a rectangle (x, z).
func _strike(tool: EnvTool) -> Array:
	var points: Array[Vector3] = []
	if tool is EnvDropTool:
		var drop := tool as EnvDropTool
		var reach := drop.radius
		if not drop.fire.is_empty():
			reach = maxf(reach, float(drop.fire.get("radius", 0.0)))
		for k in 8:
			var angle := TAU * k / 8.0
			points.append(Vector3(drop.global_position.x, drop.floor_y, drop.global_position.z) + Vector3(cos(angle), 0.0, sin(angle)) * reach)
	elif tool is EnvToppleTool:
		var lane: Array = (tool as EnvToppleTool).lane()
		points = _corners(lane[0], lane[1])
	elif tool is EnvRollTool:
		var roll := tool as EnvRollTool
		var ahead := -roll.global_basis.z
		var length := roll.distance + roll.radius
		var center := roll.global_position + ahead * length * 0.5
		points = _corners(Transform3D(Basis.looking_at(ahead, Vector3.UP), center), Vector3(roll.thickness + 1.2, 1.0, length))
	else:
		var volley := tool as EnvVolleyTool
		for k in 5:
			var bearing := deg_to_rad(lerpf(-volley.spread_deg, volley.spread_deg, k / 4.0))
			points.append(volley.global_transform * (Basis(Vector3.UP, bearing) * Vector3(0.0, 0.0, -minf(volley.reach, 6.0))))
	var rect := Rect2(Vector2(points[0].x, points[0].z), Vector2.ZERO)
	for p in points:
		rect = rect.expand(Vector2(p.x, p.z))
	return [points, rect]


func _corners(frame: Transform3D, size: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			out.append(frame * Vector3(sx * size.x, 0.0, sz * size.z))
	return out


## The standing tool's footprint (x, z), or an empty rect for a hanging one.
func _footprint(tool: EnvTool) -> Rect2:
	var rect := Rect2()
	var first := true
	for body in tool.solids:
		for shape_node in body.find_children("*", "CollisionShape3D", true, false):
			var holder := shape_node as CollisionShape3D
			var box := holder.global_transform * holder.shape.get_debug_mesh().get_aabb()
			var flat := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
			rect = flat if first else rect.merge(flat)
			first = false
	return rect


func test_every_tool_stands_in_its_room_clear_of_the_ways_and_the_arenas() -> void:
	await _build()
	var layout := level.layout
	assert_eq(env.tools.size(), EnvCatalog.tools().size(), "every tool of the catalog is built")
	var arenas := []
	for marker: StringName in layout.markers:
		if String(marker).begins_with("guardian_"):
			arenas.append(layout.marker_rooms.get(marker))
	for each in env.tools:
		var tool := each as EnvTool
		var room := layout.room(tool.room)
		assert_not_null(room, "%s: its room" % tool.id)
		if room == null:
			continue
		assert_false(arenas.has(tool.room), "%s: not in a guardian's arena" % tool.id)
		assert_false(room.haven or room.secret, "%s: not in a haven or a secret room" % tool.id)
		var strike: Array = _strike(tool)
		for p: Vector3 in strike[0]:
			assert_eq(layout.room_at(Vector3(p.x, room.floor_y + 0.5, p.z)), tool.room, "%s: its strike stays in its room (%s)" % [tool.id, p])
		var zone: Rect2 = strike[1]
		var standing := _footprint(tool)
		for opening in layout.openings:
			if opening.room_a != tool.room and opening.room_b != tool.room:
				continue
			if absf(opening.floor_y - room.floor_y) > 1.0:
				continue
			var way := opening.rect.grow(PASSAGE_CLEARANCE)
			assert_false(way.intersects(zone), "%s: its strike clear of passage %s" % [tool.id, opening.id])
			if standing.has_area():
				assert_false(way.intersects(standing), "%s: it stands clear of passage %s" % [tool.id, opening.id])
		for flight in layout.stairs:
			if flight.room_low == tool.room or flight.room_high == tool.room:
				assert_false(flight.rect.grow(0.5).intersects(zone), "%s: its strike clear of stairs %s" % [tool.id, flight.id])
		for marker: StringName in layout.markers:
			if not MARKERS.any(func(prefix: String) -> bool: return String(marker).begins_with(prefix)):
				continue
			var at := (layout.markers[marker] as Transform3D).origin
			if standing.has_area():
				assert_false(standing.grow(MARKER_CLEARANCE).has_point(Vector2(at.x, at.z)), "%s: it stands clear of %s" % [tool.id, marker])
		if standing.has_area():
			for slot in layout.spawn_slots:
				assert_false(standing.grow(SLOT_CLEARANCE).has_point(Vector2(slot.position.x, slot.position.z)), "%s: it stands clear of the exhibits' slot in %s at %s" % [tool.id, slot.room, slot.position])
		if tool is EnvDropTool:
			var low := (tool as EnvDropTool).load_node.global_position.y - room.floor_y
			assert_gt(low, HEADROOM, "%s: its load hangs over the guard's head" % tool.id)
		if standing.has_area():
			for corner in [standing.position, standing.end, Vector2(standing.position.x, standing.end.y), Vector2(standing.end.x, standing.position.y)]:
				assert_eq(layout.room_at(Vector3(corner.x, room.floor_y + 0.5, corner.y)), tool.room, "%s: it stands inside its room" % tool.id)


func test_a_rolled_wheel_lies_clear_of_the_exhibits_slots_and_the_markers() -> void:
	await _build()
	var layout := level.layout
	var checked := 0
	for each in env.tools:
		if not each is EnvRollTool:
			continue
		var roll := each as EnvRollTool
		roll.trigger()
		await physics_frames(roundi((EnvRules.TOOL_WARNING + 3.0) * Engine.physics_ticks_per_second))
		assert_true(roll.is_down, "(control) %s rolled" % roll.id)
		# where it lies: flat, as wide as the stone
		var at := roll.carrier().global_position
		var lying := Rect2(at.x - roll.radius, at.z - roll.radius, roll.radius * 2.0, roll.radius * 2.0)
		assert_gt(Vector2(at.x - roll.global_position.x, at.z - roll.global_position.z).length(), roll.distance - 0.1, "(control) at the end of its run")
		for slot in layout.spawn_slots:
			assert_false(lying.grow(SLOT_CLEARANCE).has_point(Vector2(slot.position.x, slot.position.z)), "%s lies clear of the exhibits' slot in %s at %s" % [roll.id, slot.room, slot.position])
		for marker: StringName in layout.markers:
			if not MARKERS.any(func(prefix: String) -> bool: return String(marker).begins_with(prefix)):
				continue
			var spot := (layout.markers[marker] as Transform3D).origin
			assert_false(lying.grow(SLOT_CLEARANCE).has_point(Vector2(spot.x, spot.z)), "%s lies clear of %s" % [roll.id, marker])
		checked += 1
	assert_eq(checked, 1, "(control) the floor's wheel")


func test_every_tag_is_seen_from_the_floor_of_its_room() -> void:
	await _build()
	var space := level.get_world_3d().direct_space_state
	for each in env.tools:
		var tool := each as EnvTool
		var room := level.layout.room(tool.room)
		var tag_at := tool.tag.global_position
		var seen := 0
		var tried := 0
		for part in room.parts:
			var x := part.position.x + 0.75
			while x < part.end.x:
				var z := part.position.y + 0.75
				while z < part.end.y:
					var feet := Vector3(x, room.floor_y, z)
					z += 1.5
					var eye := feet + Vector3.UP * 1.6
					var distance := eye.distance_to(tag_at)
					if distance < 3.0 or distance > 25.0 or _inside_solid(space, eye):
						continue
					tried += 1
					var query := PhysicsRayQueryParameters3D.create(eye, tag_at, Layers.WORLD)
					if space.intersect_ray(query).is_empty():
						seen += 1
				x += 1.5
		print("env: %s's tag seen from %d of %d places on its floor" % [tool.id, seen, tried])
		assert_gt(float(seen), tried * 0.2, "%s: its tag is in sight from much of its room" % tool.id)


func test_the_floor_wears_its_props_within_the_budget_all_asleep() -> void:
	await _build()
	var stats := env.stats()
	var kinds: Dictionary = stats["kinds"]
	for kind in ["glass", "lamp", "bust", "statue", "banner", "shelf", "ceramic"]:
		assert_gt(float(kinds.get(kind, 0)), 0.0, "%s props on the floor" % kind)
	assert_true(int(stats["props"]) <= EnvRules.MAX_PROPS, "props within the budget: %d" % stats["props"])
	assert_true(int(stats["zones"]) <= EnvRules.MAX_ZONES, "hit zones within the budget: %d" % stats["zones"])
	assert_eq(int(stats["active"]), 0, "nothing moves")
	for each in env.props:
		assert_false(each.is_physics_processing(), "%s sleeps" % each.id)
		assert_false(each.is_processing(), "%s has no process" % each.id)


func test_the_layer_adds_only_the_standing_tools_solid_bodies_to_the_floor() -> void:
	await _build()
	var installed := _blocking(host)
	var tools_own := {}
	var standing := 0
	for each in env.tools:
		var solids := (each as EnvTool).solids
		standing += 1 if not solids.is_empty() else 0
		for body in solids:
			for shape in body.find_children("*", "CollisionShape3D", true, false):
				tools_own[shape.get_instance_id()] = true
	assert_eq(standing, 3, "the column, the crate and the wheel stand solid")
	for key: int in installed:
		if not bare.has(key):
			assert_true(tools_own.has(key), "only a standing tool adds a blocker: %s" % installed[key][0])
	for key: int in bare:
		assert_true(installed.has(key), "the floor's own blockers stay: %s" % bare[key][0])
		if installed.has(key):
			assert_true((installed[key][1] as Transform3D).is_equal_approx(bare[key][1]), "and where they were: %s" % bare[key][0])
	assert_eq(installed.size() - bare.size(), tools_own.size(), "no other blocker came with the layer")


func test_no_prop_or_tool_stands_in_a_guardians_arena() -> void:
	await _build()
	var arenas := []
	for marker: StringName in level.layout.markers:
		if String(marker).begins_with("guardian_"):
			arenas.append(level.layout.marker_rooms.get(marker))
	assert_gt(float(arenas.size()), 4.0, "(control) the floor has its arenas")
	var checked := 0
	for each in env.props:
		checked += 1
		assert_false(arenas.has(each.room), "%s: not in a guardian's arena" % each.id)
	assert_gt(float(checked), 100.0, "(control) and a good many props elsewhere")


func test_nothing_the_environment_does_adds_or_moves_a_blocking_collider() -> void:
	await _build()
	var before := _blocking(host)
	for each in env.tools:
		(each as EnvTool).trigger()
	var count := 0
	for each in env.props:
		count += 1
		if count % 8 == 0:
			await physics_frames(1)   # (a few at a time: Fx's debris, not the physics server, is what is tested)
		if each is EnvGlass:
			(each as EnvGlass).shatter()
		elif each is EnvCeramic:
			(each as EnvCeramic).smash()
		elif each is EnvLamp:
			if EnvRules.lamp_bursts((each as EnvLamp).kind):
				(each as EnvLamp).burst()
			else:
				(each as EnvLamp).come_down()
		elif each is EnvBust:
			(each as EnvBust).topple()
		elif each is EnvStatue:
			(each as EnvStatue).teeter()
		elif each is EnvBanner:
			(each as EnvBanner).tear_down()
		elif each is EnvPainting:
			(each as EnvPainting).slip()
	await physics_frames(roundi(6.0 * Engine.physics_ticks_per_second))
	for each in env.props:
		if not each is EnvShelf:
			assert_true(each.is_down, "%s is down" % each.id)
	var after := _blocking(host)
	for key: int in after:
		assert_true(before.has(key), "nothing blocking is added: %s" % after[key][0])
		if before.has(key):
			assert_true((after[key][1] as Transform3D).is_equal_approx(before[key][1]), "nothing blocking moves: %s" % after[key][0])
	print("env: %d blocking shapes before, %d after everything fell" % [before.size(), after.size()])


## The length of the way across the floor's navigation from [param from] to
## [param to] (INF: none).
func _way(from: Vector3, to: Vector3) -> float:
	var map := level.walk_region.get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map, from)
	var path := NavigationServer3D.map_get_path(map, start, to, true, LevelNavigation.WALK_LAYER)
	if path.is_empty() or path[path.size() - 1].distance_to(to) > 1.0:
		return INF
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length


func test_a_standing_tool_is_an_obstacle_the_exhibits_path_around_until_it_falls() -> void:
	host = Host.new()
	host.name = "Host"
	add_child(host)
	host.run = NightState.new()
	host.add_child(host.run)
	level = MuseumFloorLevel.new()
	level.skip_kits = GateLocks.replaced_kits()
	host.add_child(level)
	level.build()   # (with its navigation)
	var column_at := Vector3(-105.4, 0.0, 26.25)
	var north := column_at + Vector3(0.0, 0.0, -2.2)
	var south := column_at + Vector3(0.0, 0.0, 2.2)
	await physics_frames(2)
	var open_way := _way(north, south)
	assert_lt(open_way, 6.0, "(control) the way past the column's spot is open before the layer")
	env = EnvLayer.install(level, host)
	for each in env.tools:
		for body in (each as EnvTool).solids:
			assert_eq(body.get_parent(), level.walk_dynamic, "%s: its body is a source of the walkable navigation" % each.id)
	for i in 600:
		await get_tree().physics_frame
		if i > 3 and not level.navigation.is_baking():
			break
	await physics_frames(3)
	var round_it := _way(north, south)
	assert_gt(round_it, open_way + 0.25, "the column stands in the way: the path goes round it")
	_tool(&"column_greece").trigger()
	await physics_frames(roundi(4.0 * Engine.physics_ticks_per_second))
	assert_true(_tool(&"column_greece").is_down, "it fell")
	for i in 600:
		await get_tree().physics_frame
		if not level.navigation.is_baking():
			break
	await physics_frames(3)
	assert_almost_eq(_way(north, south), open_way, 0.3, "fallen, it blocks nobody: the way is straight again")


## Every collision shape that blocks the guard or the exhibits (WORLD or
## ENEMY layer) under [param root]: instance id -> [path, global transform].
func _blocking(root: Node) -> Dictionary:
	var out := {}
	for node in root.find_children("*", "CollisionShape3D", true, false):
		var shape := node as CollisionShape3D
		var body := shape.get_parent() as CollisionObject3D
		if body == null or body is Area3D or shape.disabled:
			continue
		if body.collision_layer & (Layers.WORLD | Layers.ENEMY) == 0:
			continue
		out[shape.get_instance_id()] = [String(body.get_path()), shape.global_transform]
	return out


static func _inside_solid(space: PhysicsDirectSpaceState3D, point: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = point
	query.collision_mask = Layers.WORLD
	query.collide_with_areas = false
	return not space.intersect_point(query, 1).is_empty()
