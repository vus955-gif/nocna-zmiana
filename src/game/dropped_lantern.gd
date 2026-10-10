class_name DroppedLantern
extends Area3D
## The guard's flashlight, dropped where he last stood on the level floor
## outside a haven (Player.last_floor_position), still glowing warm and
## holding all the Dust he carried. A strong light with a volumetric-fog
## halo, a faint column of light and a few orbiting specks make it easy to
## spot from afar. Touching it (alive) gives the Dust back through
## NightRules and removes it.

signal recovered(amount: int)

const COLOR := Color(1.0, 0.74, 0.42)
const TOUCH_RADIUS := 0.9
## The drop onto the floor looks this far above and below the saved spot.
const SETTLE_UP := 0.5
const SETTLE_DOWN := 8.0

var dust: int = 0
## Defaults to the GameState / RunState autoloads.
var game: PersistentState = null
var run: NightState = null

var _light: OmniLight3D
var _specks: Array[MeshInstance3D] = []
var _time: float = 0.0
var _taken: bool = false
var _settled: bool = false


## Places the lantern stored in [param game_state] (null when none).
static func from_save(game_state: PersistentState) -> DroppedLantern:
	if not bool(game_state.lantern.get("active", false)):
		return null
	var at: Array = game_state.lantern["position"]
	var lantern := DroppedLantern.new()
	lantern.dust = int(game_state.lantern["dust"])
	lantern.position = Vector3(float(at[0]), float(at[1]), float(at[2]))
	lantern.game = game_state
	return lantern


func _init() -> void:
	collision_layer = Layers.PICKUP
	collision_mask = Layers.PLAYER
	monitorable = false


func _ready() -> void:
	if game == null:
		game = GameState
	if run == null:
		run = RunState
	var sphere := SphereShape3D.new()
	sphere.radius = TOUCH_RADIUS
	var shape := CollisionShape3D.new()
	shape.shape = sphere
	shape.position = Vector3(0.0, 0.5, 0.0)
	add_child(shape)
	_build_model()


func _process(delta: float) -> void:
	_time += delta
	_light.light_energy = 2.6 + 0.25 * sin(_time * 2.1)
	for i in _specks.size():
		var angle := _time * (0.8 + 0.15 * i) + TAU * i / _specks.size()
		_specks[i].position = Vector3(cos(angle) * 0.45, 0.35 + 0.25 * sin(_time * 1.3 + i), sin(angle) * 0.45)


func _physics_process(_delta: float) -> void:
	if not _settled:
		_settled = true
		settle()
	if _taken or not has_overlapping_bodies():
		return
	for body in get_overlapping_bodies():
		var guard := body as Player
		if guard != null and guard.alive:
			_recover()
			return


## Drops the lantern onto the level floor under its spot (done once, in its
## first physics frame, when the level is in the physics world): a spot
## saved above the floor, on an exhibit or a bit into the ground still
## gives a lantern lying on the floor. Stays put when there is no floor.
func settle() -> void:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * SETTLE_UP, global_position + Vector3.DOWN * SETTLE_DOWN, Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit["position"]


func _recover() -> void:
	_taken = true
	var amount := NightRules.recover_lantern(game, run)
	Sfx.play(&"lantern")
	Events.lantern_recovered.emit(amount)
	recovered.emit(amount)
	queue_free()


func _build_model() -> void:
	var lantern := ArtLibrary.try_instance(&"lantern")
	if lantern != null:
		# the guard's lantern standing where he fell, its lens glowing
		lantern.rotation.y = deg_to_rad(25.0)
		add_child(lantern)
	else:
		_build_greybox()
	_light = OmniLight3D.new()
	_light.light_color = COLOR
	_light.light_energy = 2.6
	_light.omni_range = 7.0
	_light.omni_attenuation = 1.4
	_light.light_volumetric_fog_energy = 4.0
	_light.shadow_enabled = true
	_light.position = Vector3(0.0, 0.45, 0.0)
	add_child(_light)
	# a faint column of light, seen from across the hall
	var column := MeshInstance3D.new()
	var beam := CylinderMesh.new()
	beam.top_radius = 0.02
	beam.bottom_radius = 0.18
	beam.height = 3.0
	beam.cap_top = false
	beam.cap_bottom = false
	column.mesh = beam
	column.position = Vector3(0.0, 1.5, 0.0)
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var haze := StandardMaterial3D.new()
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	haze.cull_mode = BaseMaterial3D.CULL_DISABLED
	haze.albedo_color = Color(COLOR.r, COLOR.g, COLOR.b, 0.08)
	column.material_override = haze
	add_child(column)
	for i in 3:
		var speck := MeshInstance3D.new()
		var dot := SphereMesh.new()
		dot.radius = 0.025
		dot.height = 0.05
		dot.radial_segments = 6
		dot.rings = 3
		speck.mesh = dot
		speck.material_override = _glowing(4.0)
		speck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(speck)
		_specks.append(speck)


## The flashlight lying on the floor (when the model is off or missing).
func _build_greybox() -> void:
	var body := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.045
	tube.bottom_radius = 0.045
	tube.height = 0.3
	body.mesh = tube
	body.material_override = _solid(Color(0.13, 0.13, 0.14))
	body.rotation_degrees = Vector3(90.0, 25.0, 0.0)
	body.position = Vector3(0.0, 0.05, 0.0)
	add_child(body)
	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.075
	cone.bottom_radius = 0.05
	cone.height = 0.1
	head.mesh = cone
	head.material_override = _glowing(2.5)
	head.rotation_degrees = Vector3(90.0, 25.0, 0.0)
	head.position = Vector3(0.0, 0.07, 0.0) + Basis.from_euler(Vector3(0.0, deg_to_rad(25.0), 0.0)) * Vector3(0.0, 0.0, -0.19)
	add_child(head)


static func _solid(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.4
	material.metallic = 0.5
	return material


static func _glowing(strength: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(COLOR.r * strength, COLOR.g * strength, COLOR.b * strength)
	return material
