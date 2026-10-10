class_name Pickup
extends Area3D
## Ammo box or medkit. Touching it applies it if the guard can use it (also
## while he keeps standing on it); in the sandbox it comes back after
## [member respawn_time] seconds.

## RIFLE: a belt for the gatling; FLARES: flare cartridges; HUNT_ROUNDS:
## cartridges for the hunting rifle; HARPOONS; ROCKETS: fire-arrow volleys
## for the hwacha.
enum Type { BULLETS, SHELLS, MEDKIT, RIFLE, FLARES, HUNT_ROUNDS, HARPOONS, ROCKETS }

## The guard took it (the night remembers taken loot).
signal taken

## Ammo type each box refills.
const AMMO := {Type.BULLETS: &"bullets", Type.SHELLS: &"shells", Type.RIFLE: &"rifle", Type.FLARES: &"flares",
		Type.HUNT_ROUNDS: &"hunt_rounds", Type.HARPOONS: &"harpoons", Type.ROCKETS: &"rockets"}
## Model of each type (ArtLibrary ids).
const MODELS := {Type.BULLETS: &"ammo_pistol", Type.SHELLS: &"ammo_shells", Type.MEDKIT: &"medkit",
		Type.RIFLE: &"ammo_rifle", Type.FLARES: &"ammo_flares", Type.HUNT_ROUNDS: &"ammo_rifle_hunt",
		Type.HARPOONS: &"ammo_harpoon", Type.ROCKETS: &"ammo_hwacha"}

@export var type: Type = Type.BULLETS
@export var amount: int = 12
## Seconds until it comes back; 0 or less = never.
@export var respawn_time: float = 15.0

var active: bool = true
var _model: Node3D
var _time: float = 0.0


func _ready() -> void:
	collision_layer = Layers.PICKUP
	collision_mask = Layers.PLAYER
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	_model = _build_model()
	_model.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_model)


## Applies the pickup to [param player]. False when it would be wasted.
## Ammo boxes give more with deep pockets (UpgradeEffects.spare_ammo).
func apply_to(player: Player) -> bool:
	if type == Type.MEDKIT:
		return player.heal(amount) > 0.0
	var ammo: StringName = AMMO.get(type, &"")
	return ammo != &"" and player.weapons.add_ammo(ammo, UpgradeEffects.spare_ammo(amount, player.weapons.upgrade_levels)) > 0


func _process(delta: float) -> void:
	_time += delta
	_model.rotation.y = _time * 1.5
	_model.position.y = sin(_time * 2.0) * 0.08


func _physics_process(_delta: float) -> void:
	# checked every frame rather than on entry, so a guard standing on it gets
	# it as soon as he can use it (or as soon as it comes back)
	if not active or not has_overlapping_bodies():
		return
	for body in get_overlapping_bodies():
		_try_apply(body as Player)


func _try_apply(player: Player) -> void:
	if not active or player == null or not player.alive:
		return
	if apply_to(player):
		active = false
		_model.visible = false
		Sfx.play(&"pickup", -3.0)
		taken.emit()
		if respawn_time > 0.0:
			get_tree().create_timer(respawn_time, false).timeout.connect(_respawn)


func _respawn() -> void:
	active = true
	_model.visible = true


## The Blender model (with a warm rim that finds it in the dark), else a
## greybox box.
func _build_model() -> Node3D:
	var model := ArtLibrary.pickup(MODELS[type])
	if model != null:
		return model
	var root := Node3D.new()
	match type:
		Type.BULLETS:
			_part(root, Vector3(0.32, 0.2, 0.22), Vector3.ZERO, Color(0.85, 0.68, 0.2))
		Type.SHELLS:
			_part(root, Vector3(0.32, 0.2, 0.22), Vector3.ZERO, Color(0.75, 0.15, 0.12))
		Type.MEDKIT:
			_part(root, Vector3(0.42, 0.3, 0.28), Vector3.ZERO, Color(0.92, 0.92, 0.9))
			_part(root, Vector3(0.2, 0.06, 0.02), Vector3(0, 0, -0.145), Color(0.8, 0.1, 0.1))
			_part(root, Vector3(0.06, 0.2, 0.02), Vector3(0, 0, -0.145), Color(0.8, 0.1, 0.1))
		Type.RIFLE, Type.FLARES:
			_content_model(root, type)
		Type.HUNT_ROUNDS, Type.HARPOONS, Type.ROCKETS:
			_floor1_model(root, type)
	return root


## Greybox of the content pass's ammo (ArtLibrary ids ammo_rifle and
## ammo_flares later): an olive belt box with brass rounds on top, a
## bundle of three red flare cartridges.
static func _content_model(root: Node3D, kind: Type) -> void:
	if kind == Type.RIFLE:
		_part(root, Vector3(0.36, 0.2, 0.2), Vector3.ZERO, Color(0.28, 0.32, 0.2))
		for i in 6:
			_part(root, Vector3(0.025, 0.07, 0.025), Vector3(-0.1 + i * 0.04, 0.13, 0.0), Color(0.85, 0.66, 0.25))
		return
	for i in 3:
		_part(root, Vector3(0.07, 0.24, 0.07), Vector3(-0.08 + i * 0.08, 0.0, 0.0), Color(0.85, 0.12, 0.08))
		_part(root, Vector3(0.075, 0.03, 0.075), Vector3(-0.08 + i * 0.08, -0.11, 0.0), Color(0.8, 0.62, 0.25))


## Greybox of the Floor I ammo (ArtLibrary ids ammo_rifle_hunt,
## ammo_harpoon, ammo_hwacha when the models are there): a green box of
## rifle cartridges, two harpoons, a bundle of red fire-arrows.
static func _floor1_model(root: Node3D, kind: Type) -> void:
	match kind:
		Type.HUNT_ROUNDS:
			_part(root, Vector3(0.22, 0.12, 0.14), Vector3.ZERO, Color(0.24, 0.34, 0.22))
			for i in 5:
				_part(root, Vector3(0.022, 0.08, 0.022), Vector3(-0.08 + i * 0.04, 0.1, 0.0), Color(0.86, 0.66, 0.26))
		Type.HARPOONS:
			for i in 2:
				_part(root, Vector3(0.03, 0.03, 0.46), Vector3(-0.03 + i * 0.06, 0.0, 0.0), Color(0.3, 0.3, 0.32))
				_part(root, Vector3(0.06, 0.05, 0.08), Vector3(-0.03 + i * 0.06, 0.0, -0.25), Color(0.5, 0.5, 0.52))
		Type.ROCKETS:
			for i in 6:
				_part(root, Vector3(0.03, 0.36, 0.03), Vector3(-0.06 + (i % 3) * 0.06, 0.0, -0.03 + floori(i / 3.0) * 0.06), Color(0.72, 0.14, 0.1))


static func _part(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.35
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = mat
	view.position = pos
	parent.add_child(view)
