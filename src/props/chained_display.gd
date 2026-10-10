class_name ChainedDisplay
extends Interactable
## The armory's exhibit "Kartaczownica, 1871": a crank gatling on its
## carriage, up on a plinth the guard cannot jump onto, wrapped in a chain
## with a padlock. The chain speaks the language of every chain in the
## museum (LockRules, GateLock.Kind.CHAIN): the shotgun's hits summed
## within 0.4 s (one blast's pellets, both barrels from afar) reaching
## SHOTGUN_MIN, or PUNCHES_TO_BREAK punches; bullets and everything else
## only strike sparks and show the same line, "Chain - break it with
## something heavy (shotgun, fists)". Then E takes the gatling for good. A
## gatling already found leaves the carriage empty.
##
## Place with create(transform): the origin stands on the floor in the
## middle of the plinth, -Z (the plaque) faces the room. Signals:
## chain_broken, taken. The chain stays broken for the rest of the night
## (RunState.used, survives "Continue").
##
## It is the Blender "gatling_display" (the gun on its tripod on a walnut
## base, the engraved plaque, the chain with its padlock) when there is
## one: the chain breaks off as falling pieces of itself, the gun is hidden
## once taken. Else the greybox carriage built here.

signal chain_broken
signal taken(by: Node)

enum State { LOCKED, OPEN, EMPTY }

const WEAPON := &"gatling"
const USED_ID := &"gatling_chain"
const SHOTGUN_MIN := LockRules.CHAIN_SUM
const PUNCHES_TO_BREAK := LockRules.CHAIN_PUNCHES
const PLINTH := Vector3(1.9, 0.9, 1.1)
## The gun and its chain above the plinth (the chain's hit zone).
const CHAIN_ZONE := Vector3(1.3, 0.9, 1.0)
const CHAIN_CENTER := Vector3(0.0, 1.45, 0.0)
const WOOD := Color(0.36, 0.24, 0.15)
const IRON := Color(0.36, 0.35, 0.34)
const BRASS := Color(0.78, 0.6, 0.28)
## The model (ArtLibrary id) and its numbers: the base and the gun up on
## its tripod as one solid block, the chain's hit zone round the gun (it
## reaches past the block, so shots find the chain first; its centre sits
## above the block, so a punch's line to it stays clear), pieces the chain
## falls apart into.
const MODEL := &"gatling_display"
const MODEL_BLOCK := Vector3(1.23, 1.12, 1.0)
const MODEL_ZONE := Vector3(1.4, 1.5, 1.15)
const MODEL_ZONE_CENTER := Vector3(0.0, 1.2, 0.0)
const CHAIN_PIECES := 6

static var _materials: Dictionary = {}

var state: State = State.LOCKED
var punches: int = 0
## Hits summed and blows counted (the chain's rule).
var tally: LockTally = LockRules.tally_for(GateLock.Kind.CHAIN)
var _clock: float = 0.0
var _hint_wait: float = 0.0
## False in dev arenas: taking the gun records and saves nothing, and a
## gun found earlier does not empty the display.
var persistent: bool = true

var _chain: Node3D
var _gun: Node3D
var _zone: Hurtbox
var _shake: float = 0.0
## The Blender display (null: greybox).
var _model: Node3D = null
var _chain_rest := Vector3.ZERO


static func create(at: Transform3D) -> ChainedDisplay:
	var display := ChainedDisplay.new()
	display.transform = at
	display.name = "ChainedDisplay"
	return display


func _ready() -> void:
	_model = ArtLibrary.try_instance(MODEL)
	if _model != null:
		add_box(Vector3(MODEL_BLOCK.x + 0.2, 2.0, MODEL_BLOCK.z + 0.3), Vector3(0.0, 1.0, 0.0))
		_build_model()
	else:
		add_box(Vector3(PLINTH.x + 0.2, 2.0, PLINTH.z + 0.3), Vector3(0.0, 1.0, 0.0))
		_build()
	if persistent and GameState.has_weapon(WEAPON):
		_set_state(State.EMPTY)
	elif persistent and RunState.is_used(USED_ID):
		_set_state(State.OPEN)
	else:
		_set_state(State.LOCKED)


func can_interact(_by: Node) -> bool:
	return enabled and state != State.EMPTY


func interact(by: Node) -> void:
	match state:
		State.LOCKED:
			_rattle(1.0)   # it will not come off by hand
			_hint(true)
		State.OPEN:
			if FoundWeapon.give(by as Player, WEAPON, persistent):
				_set_state(State.EMPTY)
				super(by)
				taken.emit(by)


## A weapon hit the gun or its chain (the chain's rule: LockRules).
func take_damage(info: DamageInfo) -> void:
	if state != State.LOCKED:
		return
	match LockRules.verdict(GateLock.Kind.CHAIN, info):
		LockRules.Verdict.SUM:
			if tally.feed(info.amount, _clock):
				break_chain()
			else:
				Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.METAL, 1.0)
				_rattle(0.8)
		LockRules.Verdict.STRIKE:
			punches += 1
			_rattle(1.0)
			if tally.strike():
				break_chain()
			else:
				Events.hint_requested.emit(tr("LOCK_CREAKS") % [tally.strikes, tally.need_strikes])
		_:
			Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.METAL, 0.8)
			Sfx.play_at(&"hit_metal", info.position, -3.0)
			_rattle(0.4)
			_hint(false)


func _physics_process(delta: float) -> void:
	_clock += delta
	_hint_wait = maxf(_hint_wait - delta, 0.0)


## The chain's line under the crosshair (at most every few seconds unless
## [param force]).
func _hint(force: bool) -> void:
	if _hint_wait > 0.0 and not force:
		return
	_hint_wait = GateLock.HINT_COOLDOWN
	Events.hint_requested.emit(tr("LOCK_CHAIN_PROMPT"))


## The chain gives way: links and padlock fall, the gatling can be taken.
func break_chain() -> void:
	if state != State.LOCKED:
		return
	var center := global_transform * (MODEL_ZONE_CENTER if _model != null else CHAIN_CENTER)
	if _model != null:
		_drop_chain()
	else:
		for i in 8:
			var at := center + Vector3(randf_range(-0.5, 0.5), randf_range(-0.2, 0.4), randf_range(-0.4, 0.4))
			Fx.chunk(at, IRON, 0.07, Vector3(randf_range(-2.0, 2.0), randf_range(0.5, 2.5), randf_range(-2.0, 2.0)))
	Fx.impact(center, Vector3.UP, ExhibitMaterial.Kind.METAL, 2.0)
	Sfx.play_at(&"chain_break", center, 2.0)
	Events.shake_requested.emit(0.2)
	RunState.mark_used(USED_ID)
	_set_state(State.OPEN)
	chain_broken.emit()


func _process(delta: float) -> void:
	if _shake > 0.0 and _chain != null:
		_shake = maxf(_shake - delta * 3.0, 0.0)
		_chain.position = _chain_rest + Vector3(sin(_shake * 60.0) * 0.015 * _shake, 0.0, 0.0)


func _set_state(next: State) -> void:
	state = next
	_chain.visible = next == State.LOCKED
	_gun.visible = next != State.EMPTY
	_zone.collision_layer = Layers.HURTBOX if next == State.LOCKED else 0
	prompt_key = "PROMPT_TAKE_GATLING" if next == State.OPEN else "LOCK_CHAIN_PROMPT"


func _rattle(strength: float) -> void:
	_shake = maxf(_shake, strength)
	Sfx.play_at(&"chain_clank", global_transform * CHAIN_CENTER, -2.0 if strength >= 1.0 else -8.0)


## The Blender display, turned to face the room (-Z), one solid block for
## the base and the gun, the chain's hit zone round the gun, a small lamp.
func _build_model() -> void:
	_model.name = "Model"
	_model.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	add_child(_model)
	var model_parts := ArtLibrary.parts(_model)
	_gun = model_parts.get("gun") as Node3D
	_chain = model_parts.get("chain") as Node3D
	if _gun == null:
		_gun = Node3D.new()
		_model.add_child(_gun)
	if _chain == null:
		_chain = Node3D.new()
		_model.add_child(_chain)
	_chain_rest = _chain.position
	var chain_mesh := _chain as MeshInstance3D
	if chain_mesh != null:
		MeshShards.warm_slices(chain_mesh.mesh, CHAIN_PIECES)
	var body := StaticBody3D.new()
	body.name = "Plinth"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	add_child(body)
	var collider := CollisionShape3D.new()
	collider.shape = _shape(MODEL_BLOCK)
	collider.position = Vector3(0.0, MODEL_BLOCK.y * 0.5, 0.0)
	body.add_child(collider)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.86, 0.66)
	lamp.light_energy = 0.9
	lamp.omni_range = 3.2
	lamp.shadow_enabled = false
	lamp.position = Vector3(0.0, 2.1, -0.9)
	add_child(lamp)
	_zone = Hurtbox.make(self, _shape(MODEL_ZONE), MODEL_ZONE_CENTER)
	add_child(_zone)


## The model's chain falls off the gun in pieces of itself.
func _drop_chain() -> void:
	var chain_mesh := _chain as MeshInstance3D
	if chain_mesh == null or not chain_mesh.is_visible_in_tree():
		return
	var xform := chain_mesh.global_transform
	var materials: Array = []
	for i in chain_mesh.mesh.get_surface_count():
		materials.append(chain_mesh.get_active_material(i))
	var center := xform * chain_mesh.get_aabb().get_center()
	for shard: MeshShards.Piece in MeshShards.slices(chain_mesh.mesh, CHAIN_PIECES):
		var at := xform * shard.center
		var away := Vector3(at.x - center.x, 0.0, at.z - center.z)
		away = away.normalized() if away.length_squared() > 0.0001 else Vector3.ZERO
		var fling := away * randf_range(0.6, 1.6) + Vector3(randf_range(-0.4, 0.4), randf_range(0.4, 1.4), randf_range(-0.4, 0.4))
		Fx.piece(shard, MeshShards.materials_for(shard, materials), xform, fling, 7.0)


func _build() -> void:
	var body := StaticBody3D.new()
	body.name = "Plinth"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	add_child(body)
	var shape := BoxShape3D.new()
	shape.size = PLINTH
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0.0, PLINTH.y * 0.5, 0.0)
	body.add_child(collider)
	_box(body, PLINTH, Vector3(0.0, PLINTH.y * 0.5, 0.0), WOOD)
	_box(body, Vector3(PLINTH.x + 0.1, 0.08, PLINTH.z + 0.1), Vector3(0.0, PLINTH.y - 0.04, 0.0), WOOD.darkened(0.3))
	_box(body, Vector3(PLINTH.x + 0.1, 0.12, PLINTH.z + 0.1), Vector3(0.0, 0.06, 0.0), WOOD.darkened(0.3))
	# the brass plaque on the front
	_box(body, Vector3(0.7, 0.18, 0.02), Vector3(0.0, 0.5, -PLINTH.z * 0.5 - 0.01), BRASS)
	var plaque := Label3D.new()
	plaque.text = tr("EXHIBIT_GATLING_PLAQUE")
	plaque.font_size = 40
	plaque.outline_size = 0
	plaque.pixel_size = 0.0022
	plaque.modulate = Color(0.12, 0.08, 0.04)
	plaque.position = Vector3(0.0, 0.5, -PLINTH.z * 0.5 - 0.025)
	plaque.rotation.y = PI   # faces -Z, the room
	plaque.shaded = true
	add_child(plaque)
	# the carriage: two spoked wheels on an axle, a trail to the ground
	_gun = Node3D.new()
	_gun.name = "Gun"
	add_child(_gun)
	for side in [-1.0, 1.0]:
		var wheel := _cylinder(_gun, 0.4, 0.07, Vector3(side * 0.55, PLINTH.y + 0.4, 0.15), WOOD.lightened(0.1), Vector3(0.0, 0.0, 90.0))
		wheel.name = "Wheel"
		_cylinder(_gun, 0.08, 0.1, Vector3(side * 0.55, PLINTH.y + 0.4, 0.15), IRON, Vector3(0.0, 0.0, 90.0))
	_cylinder(_gun, 0.04, 1.2, Vector3(0.0, PLINTH.y + 0.4, 0.15), IRON, Vector3(0.0, 0.0, 90.0))
	_box(_gun, Vector3(0.16, 0.1, 0.8), Vector3(0.0, PLINTH.y + 0.25, 0.45), WOOD.lightened(0.1), Vector3(-20.0, 0.0, 0.0))
	var model := FoundWeapon.display_model(WEAPON, 3.1)
	model.position = Vector3(0.0, PLINTH.y + 0.78, 0.05)
	_gun.add_child(model)
	# the exhibit's own small lamp: the find reads in a dark armory
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.86, 0.66)
	lamp.light_energy = 0.9
	lamp.omni_range = 3.2
	lamp.shadow_enabled = false
	lamp.position = Vector3(0.0, PLINTH.y + 1.9, -0.9)
	add_child(lamp)
	# the chain: two loops over the breech and the barrels, down to rings
	# in the plinth, and a padlock where they cross in front
	_chain = Node3D.new()
	_chain.name = "Chain"
	add_child(_chain)
	for z in [-0.35, 0.2]:
		_chain_run(Vector3(-0.5, PLINTH.y, z), Vector3(0.0, PLINTH.y + 0.95, z), 9)
		_chain_run(Vector3(0.0, PLINTH.y + 0.95, z), Vector3(0.5, PLINTH.y, z), 9)
	_chain_run(Vector3(0.0, PLINTH.y + 0.95, -0.35), Vector3(0.0, PLINTH.y + 0.95, 0.2), 5)
	var lock := _box(_chain, Vector3(0.12, 0.14, 0.06), Vector3(0.18, PLINTH.y + 0.5, -0.42), BRASS.darkened(0.2))
	lock.name = "Padlock"
	var shackle := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.035
	ring.outer_radius = 0.05
	shackle.mesh = ring
	shackle.material_override = _material(IRON)
	shackle.position = Vector3(0.18, PLINTH.y + 0.6, -0.42)
	shackle.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_chain.add_child(shackle)
	_zone = Hurtbox.make(self, _shape(CHAIN_ZONE), CHAIN_CENTER)
	add_child(_zone)


## A line of [param count] links from [param from] to [param to], every
## other one turned a quarter.
func _chain_run(from: Vector3, to: Vector3, count: int) -> void:
	var run := to - from
	var along := run.normalized()
	var up := Vector3.UP if absf(along.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var basis := Basis.looking_at(along, up)
	for i in count:
		var link := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.028
		torus.outer_radius = 0.055
		torus.rings = 8
		torus.ring_segments = 6
		link.mesh = torus
		link.material_override = _material(IRON)
		link.transform = Transform3D(basis * Basis(Vector3.BACK, PI * 0.5 * (i % 2)) * Basis(Vector3.RIGHT, PI * 0.5),
				from + run * (i + 0.5) / count)
		_chain.add_child(link)


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = _material(color)
	view.position = at
	view.rotation_degrees = rot_deg
	parent.add_child(view)
	return view


func _cylinder(parent: Node3D, radius: float, height: float, at: Vector3, color: Color, rot_deg: Vector3) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = _material(color)
	view.position = at
	view.rotation_degrees = rot_deg
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
		material.roughness = 0.55
		material.metallic = 0.4 if color == IRON or color == BRASS else 0.0
		_materials[color] = material
	return _materials[color]
