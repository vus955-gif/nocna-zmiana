class_name WeaponPickup
extends Interactable
## A weapon lying in the museum, taken with E. Once taken it is the guard's
## for good (the game's weapons, saved at once) and the pickup never appears
## again. In the lobby the pistol waits in the booth's locker and the
## shotgun in the niche behind the plaque; the stand-in level lays them out.

## &"pistol" or &"shotgun".
var weapon_id: StringName = &""
## The game and night it belongs to (the Museum's; the autoloads when unset).
var game: PersistentState = null
var run: NightState = null

var _model: Node3D
var _time: float = 0.0


static func make(id: StringName, at: Vector3) -> WeaponPickup:
	var pickup := WeaponPickup.new()
	pickup.weapon_id = id
	pickup.position = at
	pickup.name = "Weapon_" + String(id)
	return pickup


func _ready() -> void:
	prompt_key = "PROMPT_TAKE_%s" % String(weapon_id).to_upper()
	add_box(Vector3(1.2, 0.9, 1.2), Vector3(0.0, 0.45, 0.0))
	_model = Node3D.new()
	_model.position = Vector3(0.0, 0.35, 0.0)
	_model.scale = Vector3.ONE * 2.4
	add_child(_model)
	var view := Viewmodels.world(weapon_id)
	if view == null:
		view = Viewmodels.greybox(weapon_id)
		_world_materials(view)
	view.rotation_degrees = Vector3(0.0, 90.0, 90.0)
	_model.add_child(view)
	var glint := OmniLight3D.new()
	glint.light_color = Color(1.0, 0.9, 0.7)
	glint.light_energy = 0.7
	glint.omni_range = 2.5
	glint.position = Vector3(0.0, 0.8, 0.0)
	add_child(glint)


func _process(delta: float) -> void:
	_time += delta
	_model.rotation.y = _time * 0.8
	_model.position.y = 0.35 + sin(_time * 1.8) * 0.05


func interact(by: Node) -> void:
	var guard := by as Player
	if guard == null or not guard.alive:
		return
	var for_game := game if game != null else GameState
	var for_run := run if run != null else RunState
	for_game.add_weapon(weapon_id)
	var had := guard.weapons.has_weapon(weapon_id)
	var state := Loadout.grant(guard, weapon_id, for_game)
	if state != null:
		guard.weapons.select_id(weapon_id)
		if not had:
			guard.weapons.found(weapon_id)   # new: looked over at the first calm moment
	NightRules.save_progress(for_game, for_run)
	Sfx.play(&"pickup")
	super(by)
	queue_free()


## The viewmodel meshes carry first-person materials (own FOV); in the
## world they get plain ones of the same colour.
static func _world_materials(node: Node) -> void:
	for child in node.get_children():
		var mesh := child as MeshInstance3D
		if mesh != null and mesh.material_override is StandardMaterial3D:
			var plain := StandardMaterial3D.new()
			plain.albedo_color = (mesh.material_override as StandardMaterial3D).albedo_color
			plain.roughness = 0.45
			plain.metallic = 0.3
			mesh.material_override = plain
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_world_materials(child)
