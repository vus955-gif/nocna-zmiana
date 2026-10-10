class_name PistolLocker
extends Interactable
## The gun locker in the security booth: the art's wall cabinet
## (ArtLibrary "pistol_locker": a hinged door, the pistol on felt at its
## "Pistol" spot) bolted to the staff lockers, or - without the model - one
## steel door of the staff lockers with a stencilled label. A keyhole lamp
## is red while the guard has no key and green once he has. Without the key
## E only rattles the door ([signal refused]); with it the door swings open
## ([signal opened_with_key]) and stays open for the night. On later nights
## the key is his: the lamp is green, the door shut until he opens it.
## Origin in the middle of the locker's face on the lockers, -Z pointing
## out of the locker.

signal opened_with_key
signal refused

const DOOR := Vector3(0.46, 1.88, 0.03)
const SWING := -1.75
const OPEN_TIME := 0.55
const LOCKED_LAMP := Color(1.0, 0.16, 0.1)
const OPEN_LAMP := Color(0.3, 1.0, 0.45)
const MODEL := &"pistol_locker"
## The cabinet model: its back on the lockers (the origin is 3.5 cm in
## front of them), its middle at the origin's height; size of the model.
const CABINET := Vector3(0.53, 0.42, 0.27)
const CABINET_BACK := 0.035

static var _materials: Dictionary = {}

## The guard holds the key (GameState.pistol_key).
var unlocked: bool = false
var is_open: bool = false
## The art's cabinet (null: the greybox locker door).
var model: Node3D = null

var _hinge: Node3D
var _lamp: MeshInstance3D
var _tween: Tween = null
var _stencil: Label3D = null
## The pistol lying on the cabinet's felt (art cabinet only).
var _pistol_view: Node3D = null
var _opened: float = 0.0


static func make(frame: Transform3D) -> PistolLocker:
	var locker := PistolLocker.new()
	locker.name = "PistolLocker"
	locker.transform = frame
	return locker


func _init() -> void:
	super()
	prompt_key = "PROMPT_LOCKER"


func _ready() -> void:
	model = ArtLibrary.try_instance(MODEL)
	if model != null:
		_build_cabinet()
	else:
		add_box(Vector3(DOOR.x + 0.14, DOOR.y, 0.32), Vector3(0.0, 0.0, -0.16))
		_build()
	set_unlocked(unlocked)
	if is_open:
		set_open()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _stencil != null:
		_stencil.text = tr("LOCKER_LABEL")


## Where the pistol waits for the guard (global): on the cabinet's felt, or
## floating in front of the greybox locker's open door.
func pistol_spot() -> Vector3:
	if model != null:
		return PropArt.locker_spot(model).global_position
	var out := (global_transform.basis * Vector3.FORWARD).normalized()
	var floor_y := global_position.y - DOOR.y * 0.5
	return global_position + out * 0.55 + Vector3.UP * (floor_y + 0.5 - global_position.y)


## True when the pistol is shown lying in the cabinet (its pickup is then
## only the use-zone).
func holds_pistol_view() -> bool:
	return model != null


## Shows (or takes away) the pistol on the cabinet's felt.
func show_pistol(on: bool) -> void:
	if model == null:
		return
	if on and _pistol_view == null:
		_pistol_view = Node3D.new()
		_pistol_view.name = "PistolOnFelt"
		var gun := Viewmodels.world(&"pistol")
		if gun == null:
			gun = Viewmodels.greybox(&"pistol")
			WeaponPickup._world_materials(gun)
		# on its side, the barrel along the cabinet
		gun.rotation_degrees = Vector3(0.0, 90.0, 90.0)
		_pistol_view.add_child(gun)
		# a small warm light inside, so the black gun reads in the dark box
		var glint := OmniLight3D.new()
		glint.name = "Glint"
		glint.light_color = Color(1.0, 0.86, 0.66)
		glint.light_energy = 0.5
		glint.omni_range = 0.6
		glint.position = Vector3(0.0, 0.25, 0.0)
		_pistol_view.add_child(glint)
		PropArt.locker_spot(model).add_child(_pistol_view)
	if _pistol_view != null:
		_pistol_view.visible = on


func set_unlocked(has_key: bool) -> void:
	unlocked = has_key
	prompt_key = "PROMPT_LOCKER_KEY" if has_key else "PROMPT_LOCKER"
	if _lamp != null:
		_lamp.material_override = _glow(OPEN_LAMP if has_key else LOCKED_LAMP)


## Open at once (the locker was opened earlier tonight).
func set_open() -> void:
	is_open = true
	if not is_inside_tree():
		return
	if model != null:
		_set_opened(1.0)
	else:
		_hinge.rotation.y = SWING
	_retire_zone()


func interact(by: Node) -> void:
	if is_open or not enabled:
		return
	super(by)
	if not unlocked:
		Sfx.play(&"deny", -4.0)
		_rattle()
		refused.emit()
		return
	is_open = true
	_retire_zone()
	WorldSounds.cue_at(&"locker", global_position)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(0.25)   # the key turns first
	if model != null:
		_tween.tween_method(_set_opened, 0.0, 1.0, OPEN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_tween.tween_property(_hinge, ^"rotation:y", SWING, OPEN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	opened_with_key.emit()


func _set_opened(amount: float) -> void:
	_opened = amount
	PropArt.set_locker_open(model, amount)


func _rattle() -> void:
	if _tween != null and _tween.is_running():
		return
	_tween = create_tween()
	if model != null:
		for amount in [0.025, -0.01, 0.015, 0.0]:
			_tween.tween_method(_set_opened, _opened, amount, 0.05)
		return
	for angle in [-0.04, 0.02, -0.03, 0.0]:
		_tween.tween_property(_hinge, ^"rotation:y", angle, 0.05)


func _retire_zone() -> void:
	enabled = false
	collision_layer = 0


## The art's cabinet: turned to face out (the model looks along +Z), its
## back on the lockers; the keyhole lamp on its door's lock side.
func _build_cabinet() -> void:
	model.name = "Cabinet"
	model.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, -CABINET.y * 0.5, CABINET_BACK))
	add_child(model)
	var front := CABINET_BACK - CABINET.z
	add_box(Vector3(CABINET.x + 0.1, CABINET.y + 0.1, 0.32), Vector3(0.0, 0.0, front - 0.1))
	# the lamp sits by the lock (the door hinges on the model's left: seen
	# from the front, on the right), just proud of the door
	_lamp = _box(self, Vector3(0.025, 0.025, 0.012), Vector3(-CABINET.x * 0.5 + 0.06, 0.06, front - 0.008), _glow(LOCKED_LAMP))
	_lamp.reparent(model.find_child("door", true, false) as Node3D if model.find_child("door", true, false) != null else self, true)


func _build() -> void:
	var steel := _solid(&"steel", Color(0.5, 0.53, 0.56), 0.45, 0.6)
	var dark := _solid(&"dark", Color(0.06, 0.06, 0.07), 0.9, 0.0)
	var brass := _solid(&"brass", Color(0.78, 0.6, 0.3), 0.35, 0.8)
	# the dark inside, seen once the door is open
	_box(self, Vector3(DOOR.x - 0.02, DOOR.y - 0.04, 0.01), Vector3(0.0, 0.0, 0.006), dark)
	# the door turns about its left edge (seen from the front: +X)
	_hinge = Node3D.new()
	_hinge.name = "Hinge"
	_hinge.position = Vector3(DOOR.x * 0.5, 0.0, -DOOR.z * 0.5)
	add_child(_hinge)
	_box(_hinge, DOOR, Vector3(-DOOR.x * 0.5, 0.0, 0.0), steel)
	for i in 3:
		_box(_hinge, Vector3(DOOR.x * 0.6, 0.012, 0.012), Vector3(-DOOR.x * 0.5, DOOR.y * 0.5 - 0.12 - i * 0.04, -DOOR.z * 0.5 - 0.004), dark)
	_box(_hinge, Vector3(0.05, 0.08, 0.012), Vector3(-DOOR.x + 0.07, 0.0, -DOOR.z * 0.5 - 0.006), brass)
	_box(_hinge, Vector3(0.012, 0.028, 0.014), Vector3(-DOOR.x + 0.07, 0.0, -DOOR.z * 0.5 - 0.011), dark)
	_lamp = _box(_hinge, Vector3(0.025, 0.025, 0.012), Vector3(-DOOR.x + 0.07, 0.08, -DOOR.z * 0.5 - 0.006), _glow(LOCKED_LAMP))
	var label := Label3D.new()
	_stencil = label
	label.name = "Stencil"
	label.text = tr("LOCKER_LABEL")
	label.font = UiTheme.strong_font()
	label.font_size = 64
	label.pixel_size = 0.0016
	label.outline_size = 0
	label.modulate = Color(0.78, 0.2, 0.14, 0.85)
	label.shaded = true
	label.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(-DOOR.x * 0.5, 0.42, -DOOR.z * 0.5 - 0.004))
	_hinge.add_child(label)


static func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = at
	view.material_override = material
	parent.add_child(view)
	return view


static func _solid(key: StringName, color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		material.metallic = metallic
		_materials[key] = material
	return _materials[key]


static func _glow(color: Color) -> StandardMaterial3D:
	var key := StringName("glow_" + color.to_html())
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.5
		_materials[key] = material
	return _materials[key]
