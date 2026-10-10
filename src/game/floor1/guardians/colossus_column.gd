class_name ColossusColumn
extends StaticBody3D
## A papyrus column of the Colossus hall (the Karnak open-capital column,
## egypt_column_open, raised to the 14 m ceiling): cover from the sun beam
## that does not last. Each beam that burns on it counts once:
## 1. CHIPPED - stone dust bursts, flakes fall;
## 2. CRACKED - the cracked texture set (egypt_column_open_cracked), more
##    dust, a crack;
## 3. BROKEN  - it snaps: the stump (egypt_column_open_stump) stays, about
##    5 m of cover, the shaft above falls as heavy physical drums and the
##    rubble (egypt_column_drums) piles at its foot.
## Level geometry (layer WORLD): the beam, shots and the guard stop at it;
## a stump still does, lower. Raised by Colossus.dress_arena() on the
## colossus_column_<n> markers (group &"colossus_columns").

signal broke

enum Stage { INTACT, CHIPPED, CRACKED, BROKEN }

const GROUP := &"colossus_columns"
const MODEL := &"egypt_column_open"
const CRACKED_SET := "egypt_column_open_cracked"
const STUMP := &"egypt_column_open_stump"
const RUBBLE := &"egypt_column_drums"
## The model is 11 m; the hall is 14 m high.
const SCALE := Vector3(1.0, 14.0 / 11.0, 1.0)
const HEIGHT := 14.0
const RADIUS := 1.05
## The stump model (3.97 m) at the same scale.
const STUMP_HEIGHT := 3.97 * 14.0 / 11.0
## The shaft is cut into this many drums when it breaks.
const SLICES := 8
const STONE := Color(0.78, 0.66, 0.48)

var stage: Stage = Stage.INTACT
var hits: int = 0

var _shape: CylinderShape3D
var _collider: CollisionShape3D
var _visual: Node3D
var _look_set := ""
var _last_burst: int = -1


static func make(at: Transform3D) -> ColossusColumn:
	var column := ColossusColumn.new()
	column.transform = at
	return column


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = Layers.WORLD
	collision_mask = 0
	_shape = CylinderShape3D.new()
	_shape.radius = RADIUS
	_shape.height = HEIGHT
	_collider = CollisionShape3D.new()
	_collider.shape = _shape
	_collider.position.y = HEIGHT * 0.5
	add_child(_collider)
	_dress(MODEL, "")
	var shaft := _shaft_mesh()
	if shaft != null:
		MeshShards.warm_slices(shaft, SLICES)


## The beam [param burst] (one id per firing) burns on it at [param at]:
## counts once per burst. Returns true when it counted.
func beam_hit(burst: int, at: Vector3) -> bool:
	if stage == Stage.BROKEN or burst == _last_burst:
		return false
	_last_burst = burst
	hits += 1
	match hits:
		1:
			stage = Stage.CHIPPED
			_crumble(at, 1.6, 4)
			Sfx.play_at(&"lock_wall_crack", at, -6.0)
		2:
			stage = Stage.CRACKED
			_dress(MODEL, CRACKED_SET)
			_crumble(at, 2.6, 8)
			Sfx.play_at(&"lock_wall_crack", at, -1.0)
		_:
			_break(at)
	return true


## The texture set it shows ("" = the clean one).
func look_set() -> String:
	return _look_set


## Height of its collider now (14 m, or the stump's).
func cover_height() -> float:
	return _shape.height


func _break(at: Vector3) -> void:
	stage = Stage.BROKEN
	var shaft := _shaft_mesh()
	var shaft_xform := (_visual.find_child(String(MODEL), true, false) as Node3D).global_transform if shaft != null else Transform3D.IDENTITY
	var materials: Array[Material] = []
	if shaft != null:
		var view := _visual.find_child(String(MODEL), true, false) as MeshInstance3D
		for i in view.mesh.get_surface_count():
			materials.append(ArtLibrary.debris_material(view.get_active_material(i)))
	_shape.height = STUMP_HEIGHT
	_collider.position.y = STUMP_HEIGHT * 0.5
	_dress(STUMP, "")
	_rubble()
	# the shaft above the break topples away from the beam
	var away := global_position - at
	away.y = 0.0
	away = away.normalized() if away.length() > 0.05 else Vector3.FORWARD
	if shaft != null:
		for shard: MeshShards.Piece in MeshShards.slices(shaft, SLICES):
			var height := (shaft_xform * shard.center).y - global_position.y
			if height < STUMP_HEIGHT:
				continue
			var fling := away * randf_range(0.6, 1.6) * (height / HEIGHT) * 3.0 + Vector3(randf_range(-0.6, 0.6), randf_range(-0.5, 0.3), randf_range(-0.6, 0.6))
			Fx.piece(shard, materials, shaft_xform, fling, 1.6)
	else:
		for i in 6:
			Fx.chunk(global_position + Vector3(0.0, STUMP_HEIGHT + i * 1.4, 0.0), STONE, 1.2, away * 2.0 + Vector3.UP)
	for i in 3:
		Fx.impact(global_position + Vector3(randf_range(-1.0, 1.0), STUMP_HEIGHT * randf(), randf_range(-1.0, 1.0)), Vector3.UP, ExhibitMaterial.Kind.MARBLE, 4.0)
	Sfx.play_at(&"lock_wall_collapse", global_position + Vector3.UP * STUMP_HEIGHT, 2.0)
	Sfx.play_at(&"rubble", global_position + Vector3.UP, 0.0)
	_shake(0.45, 22.0)
	broke.emit()


## Dust and flakes where the beam burns.
func _crumble(at: Vector3, strength: float, flakes: int) -> void:
	var out := at - global_position
	out.y = 0.0
	out = out.normalized() if out.length() > 0.05 else Vector3.FORWARD
	Fx.impact(at, out, ExhibitMaterial.Kind.MARBLE, strength * 2.0)
	for i in flakes:
		Fx.chunk(at + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3)), STONE,
				randf_range(0.08, 0.22), out * randf_range(1.0, 3.0) + Vector3(0.0, randf_range(-0.5, 1.5), 0.0))


## The rubble at its foot (decoration, no collision: the stump is the cover).
func _rubble() -> void:
	var rubble := ArtLibrary.try_instance(RUBBLE)
	if rubble == null:
		return
	rubble.name = "Rubble"
	rubble.rotation.y = randf() * TAU
	rubble.scale = Vector3.ONE * 0.9
	add_child(rubble)


## Shows [param model] (with texture set [param texture_set] for its own
## material), or the greybox when there is no model.
func _dress(model: StringName, texture_set: String) -> void:
	if _visual != null:
		_visual.queue_free()
		remove_child(_visual)
	_look_set = texture_set
	var swap := {}
	if texture_set != "":
		swap[String(model)] = texture_set
	_visual = ArtLibrary.instance(model, swap) if ArtLibrary.has_model(model) else null
	if _visual == null:
		_visual = _greybox(STUMP_HEIGHT if model == STUMP else HEIGHT, texture_set != "")
	else:
		_visual.scale = SCALE
	_visual.name = "Visual"
	add_child(_visual)


func _greybox(height: float, cracked: bool) -> Node3D:
	var root := Node3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = RADIUS * 0.85
	mesh.bottom_radius = RADIUS
	mesh.height = height
	var view := MeshInstance3D.new()
	view.name = String(MODEL)
	view.mesh = mesh
	view.position.y = height * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = STONE.darkened(0.25 if cracked else 0.0)
	view.material_override = material
	root.add_child(view)
	return root


## The intact shaft's mesh (null without the model).
func _shaft_mesh() -> Mesh:
	if _visual == null:
		return null
	var view := _visual.find_child(String(MODEL), true, false) as MeshInstance3D
	return view.mesh if view != null and view.mesh is ArrayMesh else null


func _shake(trauma: float, reach: float) -> void:
	var guard := get_tree().get_first_node_in_group(&"player") as Node3D if is_inside_tree() else null
	if guard == null:
		return
	var distance := guard.global_position.distance_to(global_position)
	if distance < reach:
		Events.shake_requested.emit(trauma * (1.0 - distance / reach))
