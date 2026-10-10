class_name ArtifactPickup
extends Interactable
## One of the night's artifacts where NightDirector put it: in a display
## case, on the secret chamber's plinth. A small object turning slowly in
## a soft light of its own colour; E takes it ([signal taken]). The use-zone
## reaches past the case's glass, so the probe meets it before the case.
## A locked pickup (the padlocked case) shows but cannot be taken.

signal taken(id: StringName)

## The use-zone: wider than a display case (1.4 x 1.0) and taller than it.
const ZONE := Vector3(1.8, 1.7, 1.8)
const SPIN := 0.6
const SCALE := 2.5
## Rest height of the model above the pickup's origin (the loot spot).
const HOVER := 0.03
## The cushion sits on a display case's wooden top, 0.1 m under the spot
## (on the chamber's plinth it stays hidden in the plinth).
const CUSHION := Vector3(0.3, 0.03, 0.3)

static var _materials: Dictionary = {}

var artifact_id: StringName = &""
var locked: bool = false

var _model: Node3D
var _light: OmniLight3D
var _flame: Node3D = null
var _time: float = 0.0


static func make(id: StringName, at: Vector3) -> ArtifactPickup:
	var pickup := ArtifactPickup.new()
	pickup.artifact_id = id
	pickup.position = at
	pickup.name = "Artifact_" + String(id)
	return pickup


func _init() -> void:
	super()
	prompt_key = "PROMPT_TAKE_ARTIFACT"


func _ready() -> void:
	add_box(ZONE, Vector3(0.0, 0.05, 0.0))
	_model = Node3D.new()
	_model.name = "Model"
	_model.scale = Vector3.ONE * SCALE
	_model.position = Vector3(0.0, HOVER, 0.0)
	add_child(_model)
	_build_model()
	var cushion := MeshInstance3D.new()
	cushion.name = "Cushion"
	var pad := BoxMesh.new()
	pad.size = CUSHION
	cushion.mesh = pad
	cushion.material_override = _mat(&"velvet", Color(0.34, 0.06, 0.08), 0.95, 0.0)
	cushion.position = Vector3(0.0, -0.1 + CUSHION.y * 0.5, 0.0)
	add_child(cushion)
	_light = OmniLight3D.new()
	_light.light_color = ArtifactCatalog.color(artifact_id)
	_light.light_energy = 0.9
	_light.omni_range = 1.8
	_light.omni_attenuation = 1.6
	_light.light_volumetric_fog_energy = 0.3
	_light.position = Vector3(0.0, 0.35, 0.0)
	add_child(_light)
	_time = randf() * TAU
	set_locked(locked)


func prompt() -> String:
	return tr(prompt_key) % tr(ArtifactCatalog.name_key(artifact_id))


func can_interact(by: Node) -> bool:
	return super(by) and not locked


## A locked pickup is not a use-zone at all (it would hide the padlock).
func set_locked(on: bool) -> void:
	locked = on
	collision_layer = 0 if on else Layers.INTERACT


func interact(by: Node) -> void:
	if locked or not enabled:
		return
	enabled = false
	collision_layer = 0
	super(by)
	taken.emit(artifact_id)
	queue_free()


func _process(delta: float) -> void:
	_time += delta
	_model.rotation.y = _time * SPIN
	_model.position.y = HOVER + (sin(_time * 1.7) * 0.5 + 0.5) * 0.03
	var flicker := 1.0
	if _flame != null:
		flicker = 0.8 + 0.2 * sin(_time * 23.0) * sin(_time * 7.0)
		_flame.scale = Vector3(1.0, 0.85 + 0.25 * flicker, 1.0)
	_light.light_energy = (0.9 + 0.12 * sin(_time * 2.3)) * flicker


func _build_model() -> void:
	match artifact_id:
		ArtifactCatalog.SCARAB:
			var faience := _mat(&"faience", Color(0.16, 0.55, 0.55), 0.35, 0.1)
			var gold := _mat(&"gold", Color(0.85, 0.66, 0.28), 0.3, 0.9)
			_oval(Vector3(0.036, 0.018, 0.046), Vector3(0, 0.018, 0.005), faience)
			_oval(Vector3(0.018, 0.012, 0.014), Vector3(0, 0.014, -0.045), gold)
			_shape(_cube(Vector3(0.004, 0.004, 0.08)), Vector3(0, 0.035, 0.005), gold)
			for side in [-1.0, 1.0]:
				for z in [-0.02, 0.005, 0.03]:
					_shape(_cube(Vector3(0.022, 0.004, 0.004)), Vector3(side * 0.04, 0.006, z), gold).rotation.y = side * z * 8.0
		ArtifactCatalog.MONOCLE:
			var brass := _mat(&"brass", Color(0.8, 0.62, 0.3), 0.3, 0.85)
			var lens := _glass()
			var ring := TorusMesh.new()
			ring.inner_radius = 0.026
			ring.outer_radius = 0.032
			ring.rings = 24
			ring.ring_segments = 8
			_shape(ring, Vector3(0, 0.045, 0), brass).rotation.x = PI * 0.5
			var disc := CylinderMesh.new()
			disc.top_radius = 0.027
			disc.bottom_radius = 0.027
			disc.height = 0.003
			disc.radial_segments = 24
			_shape(disc, Vector3(0, 0.045, 0), lens).rotation.x = PI * 0.5
			for i in 6:
				_shape(_cube(Vector3(0.005, 0.009, 0.005)), Vector3(0.03 + i * 0.006, 0.035 - i * 0.008, 0), brass)
		ArtifactCatalog.FOUNTAIN_COIN:
			var silver := _mat(&"coin", Color(0.62, 0.68, 0.6), 0.35, 0.85)
			var coin := CylinderMesh.new()
			coin.top_radius = 0.034
			coin.bottom_radius = 0.034
			coin.height = 0.006
			coin.radial_segments = 24
			_shape(coin, Vector3(0, 0.045, 0), silver).rotation.x = PI * 0.5
			var rim := TorusMesh.new()
			rim.inner_radius = 0.026
			rim.outer_radius = 0.03
			rim.rings = 24
			rim.ring_segments = 6
			_shape(rim, Vector3(0, 0.045, 0), _mat(&"coin_rim", Color(0.45, 0.55, 0.45), 0.5, 0.7)).rotation.x = PI * 0.5
		ArtifactCatalog.CANDLE_STUB:
			var wax := _mat(&"wax", Color(0.92, 0.86, 0.7), 0.6, 0.0)
			var candle := CylinderMesh.new()
			candle.top_radius = 0.022
			candle.bottom_radius = 0.026
			candle.height = 0.05
			candle.radial_segments = 16
			_shape(candle, Vector3(0, 0.025, 0), wax)
			_oval(Vector3(0.012, 0.018, 0.012), Vector3(0.02, 0.03, 0.005), wax)
			_shape(_cube(Vector3(0.003, 0.012, 0.003)), Vector3(0, 0.056, 0), _mat(&"wick", Color(0.08, 0.07, 0.06), 0.9, 0.0))
			_flame = Node3D.new()
			_flame.position = Vector3(0, 0.062, 0)
			_model.add_child(_flame)
			var flame := MeshInstance3D.new()
			flame.mesh = _unit_sphere()
			flame.scale = Vector3(0.007, 0.016, 0.007)
			flame.position = Vector3(0, 0.012, 0)
			flame.material_override = _glow(Color(1.0, 0.62, 0.22), 6.0)
			flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_flame.add_child(flame)
		ArtifactCatalog.WOLF_TOOTH:
			var bone := _mat(&"tooth", Color(0.9, 0.86, 0.74), 0.45, 0.0)
			var fang := CylinderMesh.new()
			fang.top_radius = 0.0
			fang.bottom_radius = 0.012
			fang.height = 0.075
			fang.radial_segments = 12
			var tooth := _shape(fang, Vector3(0, 0.035, 0), bone)
			tooth.rotation = Vector3(0.0, 0.0, 0.35)
			var cord := TorusMesh.new()
			cord.inner_radius = 0.022
			cord.outer_radius = 0.026
			cord.rings = 20
			cord.ring_segments = 6
			_shape(cord, Vector3(0.012, 0.085, 0), _mat(&"leather", Color(0.32, 0.2, 0.12), 0.8, 0.0)).rotation.x = PI * 0.5
		ArtifactCatalog.JANITOR_KEY:
			var iron := _mat(&"iron", Color(0.36, 0.34, 0.32), 0.5, 0.8)
			var brass := _mat(&"brass", Color(0.8, 0.62, 0.3), 0.3, 0.85)
			var bow := TorusMesh.new()
			bow.inner_radius = 0.016
			bow.outer_radius = 0.024
			bow.rings = 20
			bow.ring_segments = 8
			_shape(bow, Vector3(-0.055, 0.045, 0), brass).rotation.x = PI * 0.5
			_shape(_cube(Vector3(0.09, 0.009, 0.009)), Vector3(0.01, 0.045, 0), iron)
			_shape(_cube(Vector3(0.012, 0.022, 0.009)), Vector3(0.048, 0.033, 0), iron)
			_shape(_cube(Vector3(0.008, 0.012, 0.009)), Vector3(0.034, 0.036, 0), iron)
			_shape(_cube(Vector3(0.028, 0.018, 0.002)), Vector3(-0.055, 0.012, 0.004), _mat(&"tag", Color(0.9, 0.84, 0.7), 0.9, 0.0))
		_:
			_oval(Vector3(0.03, 0.03, 0.03), Vector3(0, 0.03, 0), _glow(ArtifactCatalog.color(artifact_id), 2.0))


## An ellipsoid with the given radii.
func _oval(radii: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var view := _shape(_unit_sphere(), at, material)
	view.scale = radii
	return view


func _shape(mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = at
	view.material_override = material
	_model.add_child(view)
	return view


static func _cube(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


## A sphere of radius 1; nodes scale it into ellipsoids.
static func _unit_sphere() -> SphereMesh:
	if not _materials.has(&"unit_sphere_mesh"):
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 16
		mesh.rings = 8
		_materials[&"unit_sphere_mesh"] = mesh
	return _materials[&"unit_sphere_mesh"]


static func _mat(key: StringName, color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		material.metallic = metallic
		_materials[key] = material
	return _materials[key]


static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var key := StringName("glow_%s_%.1f" % [color.to_html(), energy])
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color * energy
		_materials[key] = material
	return _materials[key]


static func _glass() -> StandardMaterial3D:
	if not _materials.has(&"lens"):
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.8, 0.9, 1.0, 0.25)
		material.roughness = 0.05
		material.metallic_specular = 1.0
		_materials[&"lens"] = material
	return _materials[&"lens"]
