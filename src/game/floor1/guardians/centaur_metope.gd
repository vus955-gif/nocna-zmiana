class_name CentaurMetope
extends StaticBody3D
## The metope the Centaur sleeps in (Centaur.dress_arena, on the
## guardian_centaur marker, every night): a great marble relief slab set up
## in the middle of the Parthenon gallery - a field painted Greek blue
## between two triglyph posts under a band - with the Centaur standing
## against it, his left flank on the stone, the way the sculptor left him.
## Waking, he strains (strain(): cracks of light run over the field), then
## rears and tears free (burst(): the slab above its lowest course breaks
## into heavy blocks flung away from him; the stump stays - low cover, a
## thing his charge can run into). After his fall it stays a stump (made
## broken); calmed (the guard fled), he stands in it whole again
## (restore()). Level geometry (layer WORLD).
## Own space = his post's: origin on the floor under his barrel, -Z his
## front, +X his right; the slab stands at his left (-X), its face toward
## him.

signal burst_open

const GROUP := &"centaur_metope"
## The slab's face (x), back (x), ends (z) and height (m).
const FACE_X := -0.47
const BACK_X := -0.83
const FROM_Z := -2.3
const TO_Z := 1.9
const BASE_HEIGHT := 0.3
const TOP := 3.75
## Rows of courses (y): the lowest stays as the stump.
const ROWS: Array[float] = [0.3, 1.2, 2.3, 3.3]
## The triglyph posts' width at both ends, the band's overhang.
const POST := 0.45
const BAND_OUT := 0.1
const PAINT := Color(0.32, 0.47, 0.86)
const CRACK_COLOR := Color(1.0, 0.86, 0.62)
## Broken blocks lie this long before they sink away (s).
const BLOCK_LIFE := 14.0

var broken := false
## 0..1: the cracks' light (he strains against the stone).
var strain_amount: float = 0.0

var _blocks: Array[MeshInstance3D] = []
var _stump: Array[MeshInstance3D] = []
var _shape: BoxShape3D
var _collider: CollisionShape3D
var _cracks: MeshInstance3D
var _crack_mat: StandardMaterial3D
var _light: OmniLight3D
var _flying: Array[RigidBody3D] = []


## The slab at [param at] (the Centaur's post), whole or (after his fall)
## [param already_broken].
static func make(at: Transform3D, already_broken: bool = false) -> CentaurMetope:
	var metope := CentaurMetope.new()
	metope.transform = at
	metope.broken = already_broken
	metope.name = "CentaurMetope"
	return metope


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = Layers.WORLD
	collision_mask = 0
	_shape = BoxShape3D.new()
	_collider = CollisionShape3D.new()
	_collider.shape = _shape
	add_child(_collider)
	_build()
	_show_whole(not broken)


## The cracks of light over the field (0 none .. 1 about to burst).
func strain(amount: float) -> void:
	strain_amount = clampf(amount, 0.0, 1.0)
	if _crack_mat == null:
		return
	_cracks.visible = strain_amount > 0.01 and not broken
	_crack_mat.albedo_color.a = strain_amount
	_light.visible = _cracks.visible
	_light.light_energy = 2.5 * strain_amount


## He tears free: the courses above the lowest burst into blocks flung along
## [param push] (world, away from him) and the stump stays.
func burst(push: Vector3 = Vector3.ZERO) -> void:
	if broken:
		return
	broken = true
	strain(0.0)
	var away := push if push.length() > 0.01 else global_basis * Vector3(-1.0, 0.0, 0.0)
	var center := global_transform * Vector3((FACE_X + BACK_X) * 0.5, 1.6, (FROM_Z + TO_Z) * 0.5)
	for view in _blocks:
		if _stump.has(view):
			continue
		_fling(view, center, away)
	_show_whole(false)
	for i in 6:
		var at := global_transform * Vector3(FACE_X, randf_range(1.4, 3.4), randf_range(FROM_Z + 0.5, TO_Z - 0.5))
		Fx.impact(at, global_basis.x, ExhibitMaterial.Kind.MARBLE, 3.0)
		Fx.impact(at, global_basis.x, -1, 2.5)
	burst_open.emit()


## Whole again (he was calmed back into it).
func restore() -> void:
	broken = false
	for body in _flying:
		if is_instance_valid(body):
			body.queue_free()
	_flying.clear()
	_show_whole(true)
	strain(0.0)


## Height of its collider now (the whole slab, or the stump).
func cover_height() -> float:
	return _shape.size.y


# --- building ------------------------------------------------------------------

func _build() -> void:
	var marble := ArtLibrary.arch_tile("marble_greek", true)
	var paint := ArtLibrary.arch_tile("marble_greek", true, PAINT)
	# the plinth the slab stands on
	_block(Vector3(BACK_X - 0.12, 0.0, FROM_Z - 0.12), Vector3(FACE_X + 0.03, BASE_HEIGHT, TO_Z + 0.12), marble, null, true)
	var field_from := FROM_Z + POST
	var field_to := TO_Z - POST
	var span := (field_to - field_from) / 3.0
	for row in range(ROWS.size() - 1):
		var low := ROWS[row]
		var high := ROWS[row + 1]
		var stays := row == 0
		# the triglyph posts stand a little proud of the field
		_block(Vector3(BACK_X, low, FROM_Z), Vector3(FACE_X + 0.06, high, field_from), marble, null, stays)
		_block(Vector3(BACK_X, low, field_to), Vector3(FACE_X + 0.06, high, TO_Z), marble, null, stays)
		for k in 3:
			var z0 := field_from + span * k
			_block(Vector3(BACK_X, low, z0), Vector3(FACE_X, high, z0 + span), marble, paint, stays)
	# the band across the top
	for k in 3:
		var z0 := lerpf(FROM_Z - 0.05, TO_Z + 0.05, k / 3.0)
		var z1 := lerpf(FROM_Z - 0.05, TO_Z + 0.05, (k + 1) / 3.0)
		_block(Vector3(BACK_X, ROWS[ROWS.size() - 1], z0), Vector3(FACE_X + BAND_OUT, TOP, z1), marble, null, false)
	_build_cracks()
	_light = OmniLight3D.new()
	_light.light_color = CRACK_COLOR
	_light.omni_range = 6.0
	_light.shadow_enabled = false
	_light.position = Vector3(FACE_X + 1.2, 2.2, -0.2)
	_light.visible = false
	add_child(_light)


## A course block from corner [param a] to [param b] (own space), with a
## painted face toward him when [param face] is given.
func _block(a: Vector3, b: Vector3, stone: Material, face: Material, stays: bool) -> MeshInstance3D:
	var size := (b - a).abs()
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = stone
	view.position = (a + b) * 0.5
	add_child(view)
	_blocks.append(view)
	if stays:
		_stump.append(view)
	if face != null:
		var skin := BoxMesh.new()
		skin.size = Vector3(0.02, size.y - 0.04, size.z - 0.04)
		var paint := MeshInstance3D.new()
		paint.name = "Paint"
		paint.mesh = skin
		paint.material_override = face
		paint.position = Vector3(size.x * 0.5 + 0.005, 0.0, 0.0)
		view.add_child(paint)
	return view


## Zigzag cracks over the field from where he presses on it, glowing.
func _build_cracks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.RIGHT)
	var x := FACE_X + 0.012
	for crack in 9:
		var at := Vector2(rng.randf_range(-0.9, 0.6), rng.randf_range(1.2, 2.2))
		var heading := rng.randf_range(0.0, TAU)
		for step in 7:
			heading += rng.randf_range(-0.7, 0.7)
			var length := rng.randf_range(0.18, 0.42)
			var next := at + Vector2(cos(heading), sin(heading)) * length
			next.x = clampf(next.x, FROM_Z + POST + 0.05, TO_Z - POST - 0.05)
			next.y = clampf(next.y, ROWS[0] + 0.1, ROWS[ROWS.size() - 1] - 0.05)
			var width := 0.035 * (1.0 - step / 8.0)
			var across := Vector2(-(next - at).y, (next - at).x).normalized() * width
			var p := [Vector3(x, at.y + across.y, at.x + across.x), Vector3(x, at.y - across.y, at.x - across.x),
				Vector3(x, next.y - across.y, next.x - across.x), Vector3(x, next.y + across.y, next.x + across.x)]
			for corner: Vector3 in [p[0], p[1], p[2], p[0], p[2], p[3]]:
				tool.add_vertex(corner)
			at = next
	_crack_mat = GuardianLooks.glow(CRACK_COLOR, 0.0, true)
	_cracks = MeshInstance3D.new()
	_cracks.name = "Cracks"
	_cracks.mesh = tool.commit()
	_cracks.material_override = _crack_mat
	_cracks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cracks.visible = false
	add_child(_cracks)


func _show_whole(whole: bool) -> void:
	for view in _blocks:
		view.visible = whole or _stump.has(view)
	var height := TOP if whole else ROWS[1]
	# (clear of his flank: he stands beside it, never in it)
	_shape.size = Vector3(FACE_X - BACK_X + 0.08, height, TO_Z - FROM_Z + 0.24)
	_collider.position = Vector3((FACE_X + BACK_X) * 0.5 - 0.02, height * 0.5, (FROM_Z + TO_Z) * 0.5)


## A block flung off as a physical piece (it lies a while, then sinks).
func _fling(view: MeshInstance3D, center: Vector3, away: Vector3) -> void:
	var size := (view.mesh as BoxMesh).size
	var body := RigidBody3D.new()
	body.collision_layer = Layers.DEBRIS
	body.collision_mask = Layers.WORLD | Layers.DEBRIS
	body.mass = clampf(size.x * size.y * size.z * 2600.0, 20.0, 900.0)
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var copy := view.duplicate() as MeshInstance3D
	copy.transform = Transform3D.IDENTITY
	copy.visible = true
	body.add_child(copy)
	get_parent().add_child(body)
	body.global_transform = view.global_transform
	body.reset_physics_interpolation()
	var out := body.global_position - center
	var flat_away := Vector3(away.x, 0.0, away.z).normalized()
	body.linear_velocity = flat_away * randf_range(2.5, 6.0) + Vector3(out.x, 0.0, out.z) * 0.8 + Vector3.UP * randf_range(1.0, 3.5) * clampf(out.y + 1.0, 0.4, 2.0)
	body.angular_velocity = Vector3(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0), randf_range(-3.0, 3.0))
	_flying.append(body)
	var fade := body.create_tween()
	fade.tween_interval(BLOCK_LIFE)
	fade.tween_property(copy, "scale", Vector3.ONE * 0.05, 1.5)
	fade.tween_callback(body.queue_free)
