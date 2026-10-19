class_name SealGate
extends Node3D
## A sealed gate of Floor I (design 4.2) with the GateLock contract
## ([member gate_id], [member size], [signal opened], open_instantly(),
## open(), blocks_passage(), [member is_open]):
## - SEAL: stone doors with a hollow in the shape of the seal's symbol on
##   both faces. Without the seal the line under the crosshair names what
##   it needs ("Brama zapieczętowana - potrzebna: Pieczęć Słońca"); with it
##   the hollow glows and E sets the seal in: a heavy click, a hum, the
##   leaves grind apart into the walls.
## - EVENT: a gate the game opens itself (the grate to the crypt after the
##   T-Rex): the Door's bars are its look, E only reads its line.
## The Door of the passage stays the solid part (collision, navigation);
## a SEAL gate's leaves replace its look (replaces_door_look()).
## Origin on the floor in the middle of the opening, -Z toward the room the
## guard comes from.

signal opened

## The leaves' thickness and how long they take to grind aside.
const LEAF_DEPTH := 0.3
const INSERT_TIME := 0.9
const GRIND_TIME := 2.4
## Seconds between checks whether the guard holds the seal.
const KEY_CHECK := 0.5
## Symbol colour of each seal (the hollow's glow).
const SEAL_COLORS := {
	&"seal_sun": Color(1.0, 0.72, 0.25), &"seal_wing": Color(0.45, 0.62, 1.0),
	&"seal_owl": Color(0.85, 0.88, 0.95), &"star_key": Color(0.55, 0.85, 1.0),
}
const STONE := Color(0.5, 0.48, 0.44)
## Floor I art leaves by seal: [left model, right model, native leaf size,
## yaw that turns the decorated face to the guard's side (-Z)].
const ART_LEAVES := {
	&"seal_sun": ["egypt_seal_door_l", "egypt_seal_door_r", Vector2(3.0, 7.5), PI],
	&"seal_owl": ["door_grand_leaf_l", "door_grand_leaf_r", Vector2(2.0, 4.5), 0.0],
	&"star_key": ["door_grand_leaf_l", "door_grand_leaf_r", Vector2(2.0, 4.5), 0.0],
	# the Balawat Gates (Pieczęć Skrzydła): cedar leaves with bronze bands,
	# their decorated face +Z toward the Assyrian room
	&"seal_wing": ["asy_balawat_leaf_l", "asy_balawat_leaf_r", Vector2(2.26, 5.17), 0.0],
}

var gate_id: StringName = &""
## Opening width x height (m).
var size := Vector2(4.0, 5.0)
var kind: GateSpec.Kind = GateSpec.Kind.SEAL
## The seal or key it takes (GateSpec.requirement).
var requirement: StringName = &""
var label_key: StringName = &""
var is_open: bool = false
## () -> bool: the guard holds what opens it (the GateController's check).
var has_key: Callable = Callable()
var prompt_area: Interactable = null

var _leaves: Array[Node3D] = []
var _sockets: Array[MeshInstance3D] = []
var _check_left: float = 0.0
var _keyed: bool = false


class Prompt extends Interactable:
	var gate: SealGate = null

	func prompt() -> String:
		return gate.prompt_text() if gate != null else ""

	func can_interact(_by: Node) -> bool:
		return enabled and gate != null and not gate.is_open

	func interact(by: Node) -> void:
		if gate != null:
			gate.use(by)
		super(by)


static func make(gate_kind: GateSpec.Kind) -> SealGate:
	var gate := SealGate.new()
	gate.kind = gate_kind
	gate.name = "SealGate"
	return gate


func _ready() -> void:
	if kind == GateSpec.Kind.SEAL:
		_build_leaves()
	prompt_area = Prompt.new()
	prompt_area.name = "Prompt"
	prompt_area.gate = self
	prompt_area.add_box(Vector3(size.x, size.y, 1.4), Vector3(0.0, size.y * 0.5, 0.0))
	add_child(prompt_area)
	if is_open:
		_show_open(false)
	_refresh_key()


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left <= 0.0 and not is_open:
		_check_left = KEY_CHECK
		_refresh_key()


## A SEAL gate's stone leaves stand in for the Door's bars.
func replaces_door_look() -> bool:
	return kind == GateSpec.Kind.SEAL


## The Door of the passage is the solid part.
func blocks_passage() -> bool:
	return false


func open_instantly() -> void:
	is_open = true
	if is_inside_tree():
		_show_open(false)


func open() -> void:
	if is_open:
		return
	is_open = true
	if is_inside_tree():
		if kind == GateSpec.Kind.SEAL:
			Sfx.play_at(&"lock_seal_insert", global_position + Vector3.UP * 1.5)
			_glow(2.6)
		else:
			Sfx.play_at(&"gate_open", global_position + Vector3.UP * size.y * 0.5)
		_show_open(true)
	opened.emit()


## True while the guard holds what opens it.
func keyed() -> bool:
	return has_key.is_valid() and bool(has_key.call())


func prompt_text() -> String:
	if is_open:
		return ""
	if kind == GateSpec.Kind.SEAL and keyed():
		return tr("PROMPT_SEAL_PLACE") % tr(Floor1Plan.SEALS.get(requirement, requirement))
	return tr(label_key)


## E: a seal the guard holds goes in; otherwise the gate only shows what it
## needs (and an EVENT gate never opens by hand).
func use(_by: Node) -> void:
	if is_open:
		return
	if kind == GateSpec.Kind.SEAL and keyed():
		open()
		return
	Sfx.play_at(&"hit_metal", global_position + Vector3.UP * 1.4, -8.0)
	if Events.has_signal(&"hint_requested"):
		Events.emit_signal(&"hint_requested", tr(label_key))


func _refresh_key() -> void:
	var now := keyed()
	if now == _keyed and _check_left > 0.0:
		return
	_keyed = now
	_glow(1.4 if now else 0.25)


func _glow(energy: float) -> void:
	for socket in _sockets:
		(socket.material_override as StandardMaterial3D).emission_energy_multiplier = energy


func _show_open(animated: bool) -> void:
	if prompt_area != null:
		prompt_area.collision_layer = 0
	for i in _leaves.size():
		var leaf := _leaves[i]
		var aside := Vector3((-1.0 if i == 0 else 1.0) * size.x * 0.5, 0.0, 0.0)
		if not animated:
			leaf.position += aside
			leaf.visible = false
			continue
		var tween := create_tween()
		tween.tween_interval(INSERT_TIME)
		if i == 0:
			tween.tween_callback(func() -> void:
				Sfx.play_at(&"lock_seal_grind", global_position + Vector3.UP * size.y * 0.5)
				Events.shake_requested.emit(0.15))
		tween.tween_property(leaf, "position", leaf.position + aside, GRIND_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(leaf.hide)


## Two stone leaves meeting in the middle, a socket with the seal's symbol
## on each face (no collision: the Door is the solid part). With Floor I's
## art (stage P2) the leaves are the kit's: the Khorsabad Gate's cedar and
## bronze doors with the winged sun (Pieczęć Słońca), bronze grand doors at
## the Reading Room and the North Gate (ART_LEAVES).
func _build_leaves() -> void:
	var color: Color = SEAL_COLORS.get(requirement, Color(1.0, 0.8, 0.5))
	var stone := StandardMaterial3D.new()
	stone.albedo_color = STONE
	stone.roughness = 0.9
	var art: Array = ART_LEAVES.get(requirement, []) if Floor1Art.enabled() else []
	var socket_z := LEAF_DEPTH * 0.5 + 0.01
	for side: float in [-1.0, 1.0]:
		var leaf := Node3D.new()
		leaf.name = "LeafL" if side < 0.0 else "LeafR"
		add_child(leaf)
		_leaves.append(leaf)
		if not art.is_empty() and ArtLibrary.has_model(StringName(art[0])):
			# [left model, right model, native leaf (w, h), turn to the guard]
			var native: Vector2 = art[2]
			var look := ArtKit.model(String(art[0] if side < 0.0 else art[1]))
			look.transform = Transform3D(Basis(Vector3.UP, float(art[3])).scaled(Vector3(size.x * 0.5 / native.x, size.y / native.y, 1.0)), Vector3(side * size.x * 0.25, 0.0, 0.0))
			leaf.add_child(look)
			socket_z = 0.35
		else:
			var slab := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(size.x * 0.5 - 0.02, size.y - 0.02, LEAF_DEPTH)
			slab.mesh = mesh
			slab.material_override = stone
			slab.position = Vector3(side * size.x * 0.25, size.y * 0.5, 0.0)
			leaf.add_child(slab)
		# half of the socket on each leaf's edge, on both faces
		for face: float in [-1.0, 1.0]:
			var socket := MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.top_radius = 0.32
			disc.bottom_radius = 0.32
			disc.height = 0.04
			socket.mesh = disc
			socket.rotation.x = PI * 0.5
			socket.position = Vector3(side * 0.17, minf(1.6, size.y * 0.5), face * socket_z)
			socket.scale = Vector3(0.5, 1.0, 1.0)
			var glow := StandardMaterial3D.new()
			glow.albedo_color = color.darkened(0.6)
			glow.emission_enabled = true
			glow.emission = color
			glow.emission_energy_multiplier = 0.25
			socket.material_override = glow
			leaf.add_child(socket)
			_sockets.append(socket)
