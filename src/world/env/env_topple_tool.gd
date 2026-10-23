class_name EnvToppleTool
extends EnvTool
## Something tall the guard can bring down across the floor (plan
## docs/superpowers/plans/2026-10-21-srodowisko-walka.md, backlog #23):
## - &"bookcase": one of the Enlightenment library's tall wall bookcases
##   (the level's own shelf, taken over): its tag on the top bolt that
##   anchors it to the wall; it falls forward into the aisle, books burst out
##   along it, whatever stands there is crushed and dazed;
## - &"column": a cracked column on the conservators' cradle - three drums
##   and a capital, held up by a timber shore whose wedge wears the tag;
##   the wedge goes, the shore is knocked flat, the column falls along the
##   floor and its top drum bursts.
## It topples about its front foot (the piece's -Z side) through a lane as
## long as it is tall (GroundMark.lane while it creaks); the moment it moves
## it has no collision left, and it lies where it fell without any.

const FALL_TIME := 0.75
const LEAN := 0.06
## A fallen bookcase's depth, crushed (its look's scale).
const FLAT := 0.55

var build: StringName = &"bookcase"
## Its height (the lane's length) and width (the lane's width).
var height: float = 3.4
var width: float = 2.0
var depth: float = 0.5

## What falls (the shelf taken over, or the tool's own column).
var load_node: Node3D = null
var _rest := Transform3D.IDENTITY
var _shore: Node3D = null
var _drums: Array[Node3D] = []


static func make(data: Dictionary, layer: EnvLayer) -> EnvToppleTool:
	var spec := layer.room_spec(data["room"])
	if spec == null:
		return null
	var tool := EnvToppleTool.new()
	tool.entry = data
	tool.id = StringName(data["id"])
	tool.room = data["room"]
	tool.build = data.get("build", &"bookcase")
	tool.floor_y = spec.floor_y
	tool.exhibit_damage = float(data.get("exhibit_damage", 110.0))
	tool.guard_damage = float(data.get("guard_damage", 30.0))
	tool.knockback = float(data.get("knockback", 6.0))
	tool.stun = float(data.get("stun", 0.0))
	if tool.build == &"bookcase":
		var piece := _piece_near(layer, data.get("kit", &"shelf"), data["near"])
		if piece == null:
			tool.free()
			return null
		layer.owned[piece] = true
		tool.load_node = piece
		var size: Vector3 = piece.get_meta(&"kit_size", Vector3(5.0, 3.4, 0.5))
		tool.height = size.y
		tool.width = size.x
		tool.depth = size.z
		tool.transform = piece.global_transform
	else:
		tool.height = float(data.get("height", 4.7))
		tool.width = float(data.get("width", 1.0))
		tool.depth = float(data.get("depth", 1.0))
		tool.transform = Transform3D(Basis(Vector3.UP, float(data.get("yaw", 0.0))), data["at"])
	return tool


static func _piece_near(layer: EnvLayer, kit: StringName, near: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := 1.0
	for root in layer.piece_roots():
		for node in root.get_children():
			if node.get_meta(&"kit", &"") != kit or not node is Node3D:
				continue
			var d := (node as Node3D).global_position.distance_to(near)
			if d < best_d:
				best = node
				best_d = d
	return best


func _ready() -> void:
	super()
	if build == &"bookcase":
		put_tag(Vector3(width * 0.4, height - 0.12, -depth * 0.5 - 0.03), Vector3(0.0, -0.35, -1.0), float(entry.get("tag_scale", 1.3)))
		var body := BoxShape3D.new()
		body.size = Vector3(width, height * 0.9, 0.1)
		add_zone(body, Transform3D(Basis.IDENTITY, Vector3(0.0, height * 0.5, -depth * 0.5 - 0.06)))
	else:
		_build_column()
	if is_instance_valid(load_node):
		_rest = load_node.global_transform


func _build_column() -> void:
	load_node = Node3D.new()
	load_node.name = "Column"
	add_child(load_node)
	var cradle := 0.2
	EnvLooks.box(load_node, Vector3(width + 0.15, cradle, depth + 0.15), Vector3(0.0, cradle * 0.5, 0.0), EnvLooks.TIMBER, 0.9)
	var drum_h := (height - cradle - 0.6) / 3.0
	for i in 3:
		var drum := Node3D.new()
		drum.name = "Drum%d" % i
		drum.position = Vector3(0.0, cradle + drum_h * i, 0.0)
		load_node.add_child(drum)
		var look := EnvLooks.fit(&"gr_drum", Vector3(width * 0.9, drum_h, width * 0.9), false)
		if look != null:
			drum.add_child(look)
		else:
			EnvLooks.cylinder(drum, width * 0.45, drum_h - 0.02, Vector3(0.0, drum_h * 0.5, 0.0), EnvLooks.MARBLE, 20, 0.6)
		_drums.append(drum)
	var capital := Node3D.new()
	capital.name = "Capital"
	capital.position = Vector3(0.0, cradle + drum_h * 3.0, 0.0)
	load_node.add_child(capital)
	var top := EnvLooks.fit(&"gr_capital_doric", Vector3(width * 1.2, 0.6, width * 1.2), false)
	if top != null:
		capital.add_child(top)
	else:
		EnvLooks.box(capital, Vector3(width * 1.15, 0.25, width * 1.15), Vector3(0.0, 0.47, 0.0), EnvLooks.MARBLE, 0.6)
		EnvLooks.cylinder(capital, width * 0.5, 0.35, Vector3(0.0, 0.17, 0.0), EnvLooks.MARBLE, 20, 0.6)
	_drums.append(capital)
	# the iron band round the cracked drum
	EnvLooks.cylinder(_drums[1], width * 0.47, 0.06, Vector3(0.0, drum_h * 0.5, 0.0), EnvLooks.IRON, 20, 0.5, 0.6)
	# the shore in front, its foot on a wedge (the tag)
	_shore = Node3D.new()
	_shore.name = "Shore"
	add_child(_shore)
	var foot := Vector3(0.0, 0.0, -depth * 0.5 - 1.5)
	var brace := Vector3(0.0, height * 0.55, -width * 0.48)
	EnvLooks.rod(_shore, foot + Vector3.UP * 0.08, brace, 0.07, EnvLooks.TIMBER, 0.9)
	EnvLooks.box(_shore, Vector3(0.3, 0.14, 0.34), foot + Vector3.UP * 0.07, EnvLooks.TIMBER.darkened(0.2), 0.9)
	put_tag(foot + Vector3(0.0, 0.22, -0.18), Vector3(0.0, -0.2, -1.0), float(entry.get("tag_scale", 1.2)))
	# it stands: the column holds its place (not the shore: a timber to step
	# past), an obstacle the exhibits path round until it falls
	var shape := CylinderShape3D.new()
	shape.radius = width * 0.5
	shape.height = height
	make_solid(shape, Transform3D(Basis.IDENTITY, Vector3(0.0, height * 0.5, 0.0)))
	var zone := CylinderShape3D.new()
	zone.radius = width * 0.5 + 0.05
	zone.height = height
	add_zone_round(zone, Transform3D(Basis.IDENTITY, Vector3(0.0, height * 0.5, 0.0)), AABB(Vector3(-width * 0.5, 0.0, -width * 0.5), Vector3(width, height, width)))


func carrier() -> Node3D:
	return load_node if is_instance_valid(load_node) else self


## The front foot it topples about (world) and the way it falls.
func _pivot() -> Vector3:
	return _rest * Vector3(0.0, 0.0, -depth * 0.5)


func _forward() -> Vector3:
	var ahead := -_rest.basis.z
	return Vector3(ahead.x, 0.0, ahead.z).normalized()


func _make_mark() -> GroundMark:
	return GroundMark.lane(width + 0.4, height)


func _mark_frame() -> Transform3D:
	var at := _pivot()
	return Transform3D(Basis.looking_at(_forward(), Vector3.UP), Vector3(at.x, floor_y + 0.02, at.z))


func _travel_time() -> float:
	return FALL_TIME


## The lane it falls through: [frame, size] (world).
func lane() -> Array:
	var center := _pivot() + _forward() * height * 0.5
	var frame := Transform3D(Basis.looking_at(_forward(), Vector3.UP), Vector3(center.x, floor_y + 0.8, center.z))
	return [frame, Vector3(width + 0.4, 1.6, height)]


func _warn_start() -> void:
	Sfx.play_at(&"bust_grind" if build == &"column" else &"portrait_creak", global_position + Vector3.UP * height * 0.6, -2.0, 0.08, 0.8)
	Fx.puff(global_position + Vector3.UP * height, Color(0.8, 0.76, 0.68), 12, 0.6)


func _warn_tick(_delta: float, progress: float) -> void:
	_tilt(-LEAN * progress + sin(progress * 60.0) * 0.006)


func _strike() -> void:
	if is_instance_valid(load_node):
		EnvProp.drop_collision(load_node)
	drop_solids()
	if _shore != null:
		var tween_shore := create_tween()
		tween_shore.tween_property(_shore, ^"rotation:z", -PI * 0.5, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	Sfx.play_at(&"lock_boards_splinter" if build == &"column" else &"break_wood", global_position + Vector3.UP * 0.4, -2.0)
	var tween := create_tween()
	tween.tween_method(_tilt, -LEAN, -PI * 0.5, FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_landed)


## The load turned by [param angle] about its front foot (negative: forward).
func _tilt(angle: float) -> void:
	if not is_instance_valid(load_node):
		return
	var pivot := _pivot()
	var axis := _rest.basis.x.normalized()
	load_node.global_transform = Transform3D(Basis.IDENTITY, pivot) * Transform3D(Basis(axis, angle), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot) * _rest


func _landed() -> void:
	var box: Array = lane()
	var frame: Transform3D = box[0]
	var size: Vector3 = box[1]
	var ahead := _forward()
	for receiver in EnvStrike.in_box(self, frame, size, [self, tag]):
		EnvStrike.hit(receiver, exhibit_damage, DamageInfo.Kind.BLUNT, credited(), _pivot(), ahead, knockback, stun)
	var player := guard()
	if EnvStrike.guard_in_box(player, frame, size):
		EnvStrike.hurt_guard(player, guard_damage, by_guard(), frame.origin, ahead, knockback, DamageInfo.Kind.BLUNT, credited())
	var mid := Vector3(frame.origin.x, floor_y, frame.origin.z)
	if build == &"bookcase":
		for k in 3:
			var along := _pivot() + ahead * height * (0.25 + 0.3 * k) + Vector3.UP * 0.4
			PageFlutter.scatter(along, 12, ahead * 1.2 + Vector3.UP * 1.5)
		EnvBreak.chunks(mid + Vector3.UP * 0.3, EnvLooks.TIMBER, 6, 0.12, ahead)
		Sfx.play_at(&"break_wood", mid, 3.0)
		_flatten()
	else:
		var top := _drums[_drums.size() - 1] if not _drums.is_empty() else null
		if top != null:
			for view in EnvBreak.views(top):
				EnvBreak.shards(view, 5, ahead * 2.0 + Vector3.UP)
			top.visible = false
		Fx.shatter(mid + Vector3.UP * 0.5, ExhibitMaterial.Kind.MARBLE, GibPlanner.plan(ExhibitMaterial.Kind.MARBLE, 0.0, 100.0, false, 0.6), ahead, false)
		_spread_drums(true)
		Sfx.play_at(&"break_marble", mid, 3.0)
		Sfx.play_at(&"rubble", mid, 0.0)
	Sfx.play_at(&"weight_thud", mid, 2.0)
	for k in 3:
		Fx.puff(_pivot() + ahead * height * (0.2 + 0.3 * k) + Vector3.UP * 0.2, Color(0.8, 0.76, 0.68), 14, 0.9)
	_feel(mid, height)
	noise(mid, EnvRules.NOISE_CRASH, ReactionRules.SOURCE_BLAST)
	_struck()


## The bookcase lies face down, crushed flatter (its look only), its front
## still on the floor.
func _flatten() -> void:
	var look := load_node.get_node_or_null(^"Visual") as Node3D if is_instance_valid(load_node) else null
	if look != null:
		look.scale = Vector3(1.0, 1.0, FLAT)
		look.position.z = -depth * 0.5 * (1.0 - FLAT)


## The column's drums part a little along the floor (the top one is gone).
func _spread_drums(animate: bool) -> void:
	for i in _drums.size() - 1:
		var drum := _drums[i]
		var shift := Vector3(0.0, 0.08 * i, 0.12 + 0.18 * i)
		if animate:
			create_tween().tween_property(drum, ^"position", drum.position + shift, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			drum.position += shift


func _rest_down() -> void:
	if is_instance_valid(load_node):
		if _rest == Transform3D.IDENTITY:
			_rest = load_node.global_transform
		EnvProp.drop_collision(load_node)
		_tilt(-PI * 0.5)
	drop_solids()
	if _shore != null:
		_shore.rotation.z = -PI * 0.5
	if build == &"bookcase":
		_flatten()
	elif not _drums.is_empty():
		_drums[_drums.size() - 1].visible = false
		_spread_drums(false)
