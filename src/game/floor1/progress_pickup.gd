class_name ProgressPickup
extends Interactable
## Something of Floor I's progress lying in the world, taken with E and the
## guard's for good (design 3.2): a guardian's seal or key, a crystal
## shard, a key item (a fuse), a Lewis chess piece. Taking it records it
## (GameState), announces it (Events.seal_collected / shard_collected with
## the count), saves at once, and it is gone. A turning object with a soft
## light of its own colour, easy to spot in the dark.

signal taken(kind: Kind, pickup_id: StringName)

enum Kind { SEAL, SHARD, ITEM, CHESS }

const COLORS := {Kind.SEAL: Color(1.0, 0.78, 0.35), Kind.SHARD: Color(1.0, 0.16, 0.1), Kind.ITEM: Color(1.0, 0.7, 0.35),
		Kind.CHESS: Color(0.92, 0.88, 0.78)}
const HOVER := 0.6
const SPIN := 1.1

var kind: Kind = Kind.ITEM
var pickup_id: StringName = &""
## The game and night it belongs to (the autoloads when unset).
var game: PersistentState = null
var run: NightState = null

var _model: Node3D
var _time: float = 0.0


static func make(pickup_kind: Kind, id: StringName, at: Vector3) -> ProgressPickup:
	var pickup := ProgressPickup.new()
	pickup.kind = pickup_kind
	pickup.pickup_id = id
	pickup.position = at
	pickup.name = "Progress_" + String(id)
	return pickup


## The translated name of what it is ("Pieczęć Słońca", "Odłamek kryształu").
static func name_of(pickup_kind: Kind, id: StringName) -> String:
	match pickup_kind:
		Kind.SEAL:
			return TranslationServer.translate(Floor1Plan.SEALS.get(id, id))
		Kind.SHARD:
			return TranslationServer.translate(&"ITEM_SHARD")
		Kind.CHESS:
			return TranslationServer.translate(&"CHESS_PIECE")
	return TranslationServer.translate(&"ITEM_FUSE") if String(id).begins_with("fuse") else String(id)


func _ready() -> void:
	if game == null:
		game = GameState
	if run == null:
		run = RunState
	add_box(Vector3(1.0, 1.2, 1.0), Vector3(0.0, HOVER, 0.0))
	_model = Node3D.new()
	_model.position = Vector3(0.0, HOVER, 0.0)
	add_child(_model)
	_build_model()
	var glint := OmniLight3D.new()
	glint.light_color = COLORS[kind]
	glint.light_energy = 0.9
	glint.omni_range = 3.0
	glint.position = Vector3(0.0, HOVER + 0.3, 0.0)
	add_child(glint)


func _process(delta: float) -> void:
	_time += delta
	_model.rotation.y = _time * SPIN
	_model.position.y = HOVER + sin(_time * 2.0) * 0.06


func prompt() -> String:
	return tr("PROMPT_TAKE_ITEM") % name_of(kind, pickup_id)


func interact(by: Node) -> void:
	var guard := by as Player
	if guard != null and not guard.alive:
		return
	match kind:
		Kind.SEAL:
			if game.add_seal(pickup_id):
				Events.seal_collected.emit(pickup_id)
		Kind.SHARD:
			if game.add_shard(pickup_id):
				Events.shard_collected.emit(pickup_id, game.shards.size())
		Kind.CHESS:
			game.find_chess(pickup_id)
		_:
			game.add_item(pickup_id)
	NightRules.save_progress(game, run)
	Sfx.play(&"fuse_take" if kind == Kind.ITEM else &"pickup")
	super(by)
	taken.emit(kind, pickup_id)
	queue_free()


func _build_model() -> void:
	if kind == Kind.ITEM:
		FusePickup.build_fuse(_model)
		return
	var color: Color = COLORS[kind]
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.35)
	material.metallic = 0.6
	material.roughness = 0.35
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.8
	var view := MeshInstance3D.new()
	match kind:
		Kind.SEAL:
			var disc := CylinderMesh.new()
			disc.top_radius = 0.2
			disc.bottom_radius = 0.2
			disc.height = 0.05
			view.mesh = disc
			view.rotation.x = PI * 0.5
		Kind.SHARD:
			view.mesh = CrystalRelic.gem_mesh(Vector3(0.14, 0.32, 0.14))
		Kind.CHESS:
			var piece := CylinderMesh.new()
			piece.top_radius = 0.05
			piece.bottom_radius = 0.09
			piece.height = 0.24
			view.mesh = piece
	view.material_override = material
	_model.add_child(view)
