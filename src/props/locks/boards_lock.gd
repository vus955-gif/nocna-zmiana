class_name BoardsLock
extends GateLock
## A doorway boarded up "under repair" (design 4.2): rough planks nailed
## across the opening, one diagonal, a stencilled sign. It gives way to the
## shotgun (25 summed within 0.4 s), five punches or any blast (a flare's,
## a fire-arrow's); other hits only knock splinters off. Broken, every
## plank flies off as a piece of debris.

const PLANK := Vector2(0.24, 0.045)
const PLANKS := 5
const SIGN_KEY := "LOCK_BOARDS_SIGN"

var _planks: Array[MeshInstance3D] = []
var _boards: Node3D
var _sign: Label3D


func _init() -> void:
	kind = Kind.BOARDS


func _build_body() -> void:
	_boards = Node3D.new()
	_boards.name = "Boards"
	add_child(_boards)
	var wood := LockArt.tile("timber", 1.2, Color(0.45, 0.33, 0.2), Color(0.95, 0.9, 0.85))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(gate_id)) if gate_id != &"" else 77
	var length := size.x + 0.3
	for i in PLANKS:
		var y := size.y * (0.18 + 0.66 * float(i) / float(PLANKS - 1))
		var tilt := rng.randf_range(-6.0, 6.0)
		var z := -0.09 - 0.012 * (i % 2)
		_planks.append(LockArt.box(_boards, Vector3(length, PLANK.x, PLANK.y), Vector3(rng.randf_range(-0.05, 0.05), y, z),
				wood, Vector3(0.0, 0.0, tilt)))
	var diagonal := Vector2(size.x, size.y * 0.62)
	var angle := rad_to_deg(atan2(diagonal.y, diagonal.x))
	_planks.append(LockArt.box(_boards, Vector3(diagonal.length() + 0.1, PLANK.x, PLANK.y), Vector3(0.0, size.y * 0.5, -0.135),
			wood, Vector3(0.0, 0.0, angle)))
	# nail heads at the ends of the planks
	var nail := LockArt.metal(LockArt.IRON.lightened(0.15), 0.6)
	for plank in _planks:
		for end: float in [-1.0, 1.0]:
			var at := Vector3(end * (plank.mesh as BoxMesh).size.x * 0.44, 0.0, -PLANK.y * 0.5 - 0.004)
			LockArt.box(plank, Vector3(0.018, 0.018, 0.008), at, nail)
	_sign = Label3D.new()
	_sign.name = "Sign"
	_sign.text = tr(SIGN_KEY)
	_sign.font_size = 96
	_sign.pixel_size = 0.0028
	_sign.outline_size = 0
	_sign.modulate = Color(0.75, 0.12, 0.08)
	_sign.shaded = true
	_sign.position = _planks[2].position + Vector3(0.0, 0.0, -PLANK.y * 0.5 - 0.02)
	_sign.rotation = Vector3(0.0, PI, deg_to_rad(-_planks[2].rotation_degrees.z))
	_boards.add_child(_sign)
	_add_blocker(Vector3(size.x, size.y, 0.1), Vector3(0.0, size.y * 0.5, 0.0))
	_add_face_zones(Vector3(size.x, size.y, 0.3), Vector3(0.0, size.y * 0.5, -0.05))
	_add_prompt(Vector3(size.x, size.y, 0.3), Vector3(0.0, size.y * 0.5, -0.05))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _sign != null:
		_sign.text = tr(SIGN_KEY)


func _break() -> void:
	var away := global_basis.z
	for plank in _planks:
		if plank.visible:
			var fling := away * randf_range(2.0, 4.5) + Vector3(randf_range(-1.2, 1.2), randf_range(1.0, 3.0), 0.0)
			LockArt.throw_piece(plank, fling, 7.0)
	var center := global_transform * Vector3(0.0, size.y * 0.5, -0.1)
	for i in 8:
		var at := center + global_basis * Vector3(randf_range(-size.x * 0.4, size.x * 0.4), randf_range(-1.0, 1.0), 0.0)
		Fx.chunk(at, Color(0.5, 0.37, 0.22), 0.05, away * randf_range(1.0, 3.0) + Vector3(0.0, randf_range(0.5, 2.0), 0.0))
	Fx.impact(center, -away, -1, 2.5)
	Sfx.play_at(&"lock_boards_splinter", center, 2.0)
	Events.shake_requested.emit(0.3)


func _show_open(animated: bool) -> void:
	super(animated)
	for plank in _planks:
		plank.visible = false
	_sign.visible = false


func _wrong_effect(info: DamageInfo, counts: bool) -> void:
	Fx.impact(info.position, info.normal, -1, 1.0 if counts else 0.7)
	Fx.chunk(info.position + info.normal * 0.05, Color(0.5, 0.37, 0.22), 0.035, info.normal * 1.5 + Vector3.UP)
	Sfx.play_at(&"lock_boards_hit", info.position, -1.0 if counts else -4.0)


func _play_rattle() -> void:
	Sfx.play_at(&"lock_boards_hit", global_position + Vector3.UP, -3.0)


func _animate_jolt(amount: float) -> void:
	_boards.position = Vector3(0.0, 0.0, sin(amount * 40.0) * 0.01 * amount)
