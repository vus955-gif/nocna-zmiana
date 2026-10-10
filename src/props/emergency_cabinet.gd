class_name EmergencyCabinet
extends Interactable
## A red fire cabinet on the diorama wall, "W razie pożaru zbić szybkę",
## with the flare gun behind its glass. E smashes the glass (so does a
## shot): a loud crash heard NOISE_RADIUS metres away (Events.noise_made:
## exhibits that hear it come to look); then E takes the flare gun for good. A
## flare gun already found leaves the cabinet open and empty.
##
## Place with create(transform): the origin is the middle of the cabinet's
## back on the wall surface, -Z faces the room. Signals: smashed, taken.
## The glass stays broken for the rest of the night (RunState.used).
##
## It is the Blender "emergency_cabinet" (the stencilled sign, the pistol
## on its hooks, spare flares, a hammer on a chain) when there is one: the
## pane bursts into shards of itself, the pistol is hidden once taken.
## Else the greybox built here.

signal smashed
signal taken(by: Node)

enum State { CLOSED, OPEN, EMPTY }

const WEAPON := &"flare"
const USED_ID := &"flare_cabinet"
const NOISE_RADIUS := 16.0
const SIZE := Vector3(0.56, 0.74, 0.22)
const RED := Color(0.72, 0.07, 0.05)
const GLASS := Color(0.75, 0.88, 0.95, 0.22)
## The model (ArtLibrary id): its size, where its bottom sits below the
## origin (it is modelled from the bottom of its back), the grid of shards
## its pane bursts into.
const MODEL := &"emergency_cabinet"
const MODEL_SIZE := Vector3(0.48, 0.64, 0.16)
const MODEL_SHARDS := Vector2i(3, 4)

static var _materials: Dictionary = {}

var state: State = State.CLOSED
## False in dev arenas: taking the gun records and saves nothing, and a
## gun found earlier does not empty the cabinet.
var persistent: bool = true

var _glass: MeshInstance3D
var _gun: Node3D
var _zone: Hurtbox
## The Blender cabinet (null: greybox).
var _model: Node3D = null


static func create(at: Transform3D) -> EmergencyCabinet:
	var cabinet := EmergencyCabinet.new()
	cabinet.transform = at
	cabinet.name = "EmergencyCabinet"
	return cabinet


func _ready() -> void:
	add_box(Vector3(SIZE.x + 0.1, SIZE.y + 0.1, SIZE.z + 0.2), Vector3(0.0, 0.0, -SIZE.z * 0.5 - 0.05))
	_model = ArtLibrary.try_instance(MODEL)
	if _model != null:
		_build_model()
	else:
		_build()
	if persistent and GameState.has_weapon(WEAPON):
		_set_state(State.EMPTY)
	elif persistent and RunState.is_used(USED_ID):
		_set_state(State.OPEN)
	else:
		_set_state(State.CLOSED)


func can_interact(_by: Node) -> bool:
	return enabled and state != State.EMPTY


func interact(by: Node) -> void:
	match state:
		State.CLOSED:
			smash()
		State.OPEN:
			if FoundWeapon.give(by as Player, WEAPON, persistent):
				_set_state(State.EMPTY)
				super(by)
				taken.emit(by)


## A shot through the glass breaks it as well.
func take_damage(_info: DamageInfo) -> void:
	smash()


## Breaks the glass: shards, a crash, the exhibits nearby wake up.
func smash() -> void:
	if state != State.CLOSED:
		return
	var front := global_transform * Vector3(0.0, 0.0, -(MODEL_SIZE.z if _model != null else SIZE.z))
	var out := -global_transform.basis.z
	if _model != null:
		_burst_pane(out)
		Fx.impact(front, out, -1, 0.6)
	else:
		for i in 7:
			var at := front + global_transform.basis * Vector3(randf_range(-0.22, 0.22), randf_range(-0.3, 0.3), 0.0)
			Fx.chunk(at, Color(0.8, 0.92, 1.0), 0.06, out * randf_range(1.0, 2.5) + Vector3(randf_range(-0.8, 0.8), randf_range(0.0, 1.5), randf_range(-0.8, 0.8)))
		Fx.impact(front, out, ExhibitMaterial.Kind.MARBLE, 1.5)
	Sfx.play_at(&"glass_break", front, 3.0, 0.03)
	wake_exhibits(global_position, NOISE_RADIUS, get_tree())
	RunState.mark_used(USED_ID)
	_set_state(State.OPEN)
	smashed.emit()


## A loud noise at [param at] carrying [param radius] metres
## (Events.noise_made; closed doors stop it, open ones muffle it). Returns
## how many exhibits heard it; those that only wake by sight (portraits)
## ignore it.
static func wake_exhibits(at: Vector3, radius: float, _tree: SceneTree = null) -> int:
	PerceptionWorld.listen()
	Events.noise_made.emit(at, radius, &"glass")
	return PerceptionWorld.last_heard


func _set_state(next: State) -> void:
	state = next
	_glass.visible = next == State.CLOSED
	_gun.visible = next != State.EMPTY
	_zone.collision_layer = Layers.HURTBOX if next == State.CLOSED else 0
	prompt_key = "PROMPT_SMASH_GLASS" if next == State.CLOSED else "PROMPT_TAKE_FLARE"


## The Blender cabinet, turned to face the room (-Z) and centred on the
## origin: its body is solid, its pane the glass, its pistol the gun.
func _build_model() -> void:
	_model.name = "Model"
	_model.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, -MODEL_SIZE.y * 0.5, 0.0))
	add_child(_model)
	var model_parts := ArtLibrary.parts(_model)
	_glass = model_parts.get("glass") as MeshInstance3D
	_gun = model_parts.get("flare_gun") as Node3D
	if _glass == null:
		_glass = MeshInstance3D.new()
		_model.add_child(_glass)
	if _gun == null:
		_gun = Node3D.new()
		_model.add_child(_gun)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	add_child(body)
	var collider := CollisionShape3D.new()
	collider.shape = _shape(MODEL_SIZE)
	collider.position = Vector3(0.0, 0.0, -MODEL_SIZE.z * 0.5)
	body.add_child(collider)
	var pane := _model.transform * _glass.position
	_zone = Hurtbox.make(self, _shape(Vector3(MODEL_SIZE.x - 0.06, MODEL_SIZE.y - 0.12, 0.08)), Vector3(0.0, pane.y, -MODEL_SIZE.z + 0.03))
	add_child(_zone)


## The model's pane bursts into shards of itself, out into the room.
func _burst_pane(out: Vector3) -> void:
	if _glass.mesh == null or not _glass.is_visible_in_tree():
		return
	var xform := _glass.global_transform
	var materials: Array = []
	for i in _glass.mesh.get_surface_count():
		materials.append(_glass.get_active_material(i))
	for shard: MeshShards.Piece in PanelShards.cut(_glass.mesh, MODEL_SHARDS.x, MODEL_SHARDS.y):
		var fling := out * randf_range(1.0, 2.6) + Vector3(randf_range(-0.8, 0.8), randf_range(0.0, 1.4), randf_range(-0.8, 0.8))
		Fx.piece(shard, MeshShards.materials_for(shard, materials), xform, fling, 12.0)


func _build() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	add_child(body)
	var shape := BoxShape3D.new()
	shape.size = SIZE
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0.0, 0.0, -SIZE.z * 0.5)
	body.add_child(collider)
	var red := _material(RED)
	var hx := SIZE.x * 0.5
	var hy := SIZE.y * 0.5
	# a hollow red box: back, sides, top and bottom, a frame round the glass
	_box(body, Vector3(SIZE.x, SIZE.y, 0.02), Vector3(0.0, 0.0, -0.01), _material(RED.darkened(0.45)))
	for side in [-1.0, 1.0]:
		_box(body, Vector3(0.03, SIZE.y, SIZE.z), Vector3(side * (hx - 0.015), 0.0, -SIZE.z * 0.5), red)
		_box(body, Vector3(SIZE.x, 0.03, SIZE.z), Vector3(0.0, side * (hy - 0.015), -SIZE.z * 0.5), red)
		_box(body, Vector3(0.05, SIZE.y, 0.02), Vector3(side * (hx - 0.025), 0.0, -SIZE.z + 0.01), red)
		_box(body, Vector3(SIZE.x, 0.06, 0.02), Vector3(0.0, side * (hy - 0.03), -SIZE.z + 0.01), red)
	_glass = _box(body, Vector3(SIZE.x - 0.08, SIZE.y - 0.1, 0.006), Vector3(0.0, 0.0, -SIZE.z + 0.012), _glass_material())
	_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the flare gun on two hooks
	_gun = Node3D.new()
	_gun.name = "FlareGun"
	body.add_child(_gun)
	for x in [-0.1, 0.1]:
		_box(_gun, Vector3(0.02, 0.02, 0.08), Vector3(x, -0.02, -0.05), _material(Color(0.3, 0.3, 0.32)))
	var model := FoundWeapon.display_model(WEAPON, 1.75)
	model.position = Vector3(0.0, 0.05, -0.1)
	model.rotation_degrees = Vector3(0.0, 90.0, 0.0)   # lying sideways, facing left
	_gun.add_child(model)
	# the sign above: white plate, red letters (they read in the dark too)
	_box(body, Vector3(SIZE.x + 0.1, 0.2, 0.015), Vector3(0.0, hy + 0.15, -0.008), _material(Color(0.92, 0.92, 0.88)))
	var sign := Label3D.new()
	sign.text = tr("EXHIBIT_FIRE_CABINET")
	sign.font_size = 34
	sign.outline_size = 0
	sign.pixel_size = 0.0018
	sign.modulate = Color(0.85, 0.05, 0.03)
	sign.position = Vector3(0.0, hy + 0.15, -0.018)
	sign.rotation.y = PI
	add_child(sign)
	_zone = Hurtbox.make(self, _shape(Vector3(SIZE.x - 0.06, SIZE.y - 0.08, 0.08)), Vector3(0.0, 0.0, -SIZE.z + 0.03))
	add_child(_zone)


func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	view.position = at
	parent.add_child(view)
	return view


static func _shape(size: Vector3) -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	return shape


static func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.4
		_materials[color] = material
	return _materials[color]


static func _glass_material() -> StandardMaterial3D:
	if not _materials.has(&"glass"):
		var material := StandardMaterial3D.new()
		material.albedo_color = GLASS
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.05
		material.metallic_specular = 1.0
		_materials[&"glass"] = material
	return _materials[&"glass"]
