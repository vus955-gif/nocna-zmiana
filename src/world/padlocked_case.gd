class_name PadlockedCase
extends Interactable
## The locked display case under the east balcony (secret 4): a brass
## padlock on an iron hasp keeps its lid shut. Any hit breaks the padlock
## (its Hurtbox takes shots, pellets and punches); the janitor's key opens
## it. Either way [signal unlocked] frees what lies inside. Yanking it by
## hand only rattles it ([signal rattled]).
## Origin in the middle of the case's front at lid height, -Z pointing out.

signal unlocked(by_key: bool)
signal rattled

const LOCK_AT := Vector3(0.0, -0.1, -0.03)
const FALL_TIME := 0.5

static var _materials: Dictionary = {}

var is_locked: bool = true
## Returns true while the guard holds the janitor's key.
var has_key: Callable = func() -> bool: return false
## Width of the case front (the use-zone covers it).
var width: float = 1.4

var hurtbox: Hurtbox
var _padlock: Node3D
var _shackle: Node3D
var _hasp: Node3D
var _floor_drop: float = 0.9


static func make(frame: Transform3D, case_width: float, lid_height: float) -> PadlockedCase:
	var lock := PadlockedCase.new()
	lock.name = "PadlockedCase"
	lock.transform = frame
	lock.width = case_width
	lock._floor_drop = lid_height
	return lock


func _init() -> void:
	super()
	prompt_key = "PROMPT_PADLOCK"


func _ready() -> void:
	add_box(Vector3(width, 0.9, 0.3), Vector3(0.0, 0.1, -0.15))
	_build()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.14, 0.2, 0.1)
	hurtbox = Hurtbox.make(self, shape, LOCK_AT + Vector3(0.0, -0.02, -0.03))
	hurtbox.name = "PadlockHurtbox"
	add_child(hurtbox)


func prompt() -> String:
	return tr("PROMPT_PADLOCK_KEY" if has_key.call() else prompt_key)


## Open at once, no padlock (found on an earlier night).
func set_unlocked() -> void:
	is_locked = false
	_padlock.visible = false
	_hasp.rotation.x = 1.4
	_retire()


func interact(by: Node) -> void:
	if not is_locked or not enabled:
		return
	super(by)
	if not has_key.call():
		Sfx.play(&"deny", -6.0)
		var tween := create_tween()
		for angle in [0.25, -0.2, 0.12, 0.0]:
			tween.tween_property(_padlock, ^"rotation:z", angle, 0.05)
		rattled.emit()
		return
	WorldSounds.cue_at(&"keys", global_position)
	_open(true)


## A hit on the padlock breaks it off.
func take_damage(info: DamageInfo) -> void:
	if not is_locked:
		return
	var at := _padlock.global_position
	Fx.impact(at, info.normal if info.normal != Vector3.ZERO else -info.direction, ExhibitMaterial.Kind.METAL, 1.2)
	WorldSounds.cue_at(&"padlock", at)
	Events.hit_landed.emit(self, info, false)   # a hit that lands; nothing was destroyed (no kill marker, no kill music)
	_open(false)


func _open(by_key: bool) -> void:
	is_locked = false
	_retire()
	var tween := create_tween().set_parallel(true)
	if by_key:
		tween.tween_property(_shackle, ^"position:y", _shackle.position.y + 0.03, 0.2)
		tween.chain().tween_property(_padlock, ^"position:y", _padlock.position.y - _floor_drop + 0.03, FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		tween.tween_property(_padlock, ^"position", _padlock.position + Vector3(0.12, -_floor_drop + 0.03, -0.25), FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(_padlock, ^"rotation", Vector3(1.2, 2.5, 1.6), FALL_TIME)
	tween.chain().tween_property(_hasp, ^"rotation:x", 1.4, 0.3).set_trans(Tween.TRANS_BACK)
	unlocked.emit(by_key)


func _retire() -> void:
	enabled = false
	collision_layer = 0
	if is_instance_valid(hurtbox):
		hurtbox.collision_layer = 0


func _build() -> void:
	var iron := _mat(&"iron", Color(0.22, 0.21, 0.2), 0.6, 0.7)
	var brass := _mat(&"brass", Color(0.86, 0.67, 0.32), 0.25, 0.85)
	# the hasp: a strap from the lid down over the staple
	_hasp = Node3D.new()
	_hasp.name = "Hasp"
	_hasp.position = Vector3(0.0, 0.06, -0.012)
	add_child(_hasp)
	_box(_hasp, Vector3(0.05, 0.14, 0.008), Vector3(0.0, -0.07, 0.0), iron)
	_box(self, Vector3(0.03, 0.03, 0.02), Vector3(0.0, -0.1, -0.012), iron)
	_padlock = Node3D.new()
	_padlock.name = "Padlock"
	_padlock.position = LOCK_AT
	_padlock.scale = Vector3.ONE * 1.5
	add_child(_padlock)
	_box(_padlock, Vector3(0.07, 0.07, 0.03), Vector3(0.0, -0.05, 0.0), brass)
	_box(_padlock, Vector3(0.012, 0.022, 0.004), Vector3(0.0, -0.055, -0.016), _mat(&"hole", Color(0.05, 0.04, 0.03), 0.9, 0.0))
	_shackle = Node3D.new()
	_shackle.position = Vector3(0.0, -0.015, 0.0)
	_padlock.add_child(_shackle)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.02
	ring.outer_radius = 0.028
	ring.rings = 16
	ring.ring_segments = 6
	var bow := MeshInstance3D.new()
	bow.mesh = ring
	bow.material_override = _mat(&"steel", Color(0.6, 0.62, 0.64), 0.35, 0.9)
	bow.rotation.x = PI * 0.5
	bow.position = Vector3(0.0, 0.012, 0.0)
	_shackle.add_child(bow)


static func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = at
	view.material_override = material
	parent.add_child(view)
	return view


static func _mat(key: StringName, color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		material.metallic = metallic
		_materials[key] = material
	return _materials[key]
