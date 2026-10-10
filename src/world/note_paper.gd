class_name NotePaper
extends Interactable
## A note in the world: a sheet lying on a desk or pinned to a wall, with a
## few lines of scribble on it and a faint glow of paper in the dark (easy
## to spot with the torch, never a beacon). E asks to read it
## ([signal read_requested]); LobbyFeatures opens the NoteReader.
## Lying: origin on the surface, the sheet flat. Pinned: origin on the wall,
## the written side facing -Z (into the room).

signal read_requested(id: StringName)

const SIZES := {
	NoteCatalog.Paper.LINED: Vector2(0.21, 0.28),
	NoteCatalog.Paper.STICKY: Vector2(0.09, 0.09),
	NoteCatalog.Paper.TYPED: Vector2(0.2, 0.26),
	NoteCatalog.Paper.LETTER: Vector2(0.19, 0.25),
	NoteCatalog.Paper.FORM: Vector2(0.21, 0.29),
}
const COLORS := {
	NoteCatalog.Paper.LINED: Color(0.9, 0.88, 0.8),
	NoteCatalog.Paper.STICKY: Color(0.97, 0.84, 0.3),
	NoteCatalog.Paper.TYPED: Color(0.84, 0.77, 0.62),
	NoteCatalog.Paper.LETTER: Color(0.92, 0.87, 0.76),
	NoteCatalog.Paper.FORM: Color(0.82, 0.87, 0.9),
}
const INK := Color(0.12, 0.14, 0.3)
const THICKNESS := 0.002

static var _materials: Dictionary = {}

var note_id: StringName = &""
var pinned: bool = false


static func make(id: StringName, xform: Transform3D, on_wall: bool = false) -> NotePaper:
	var note := NotePaper.new()
	note.note_id = id
	note.pinned = on_wall
	note.transform = xform
	note.name = "Note_" + String(id)
	return note


func _init() -> void:
	super()
	prompt_key = "PROMPT_READ_NOTE"


func _ready() -> void:
	var kind := NoteCatalog.paper(note_id)
	var size: Vector2 = SIZES[kind]
	if pinned:
		add_box(Vector3(size.x + 0.25, size.y + 0.25, 0.16), Vector3(0.0, 0.0, -0.08))
	else:
		add_box(Vector3(size.x + 0.25, 0.14, size.y + 0.25), Vector3(0.0, 0.06, 0.0))
	_build(kind, size)


func interact(by: Node) -> void:
	super(by)
	read_requested.emit(note_id)


## The sheet, its scribbled lines and (pinned) a drawing pin. Built in the
## lying frame (sheet in XZ, written side up) and turned upright for a wall.
func _build(kind: NoteCatalog.Paper, size: Vector2) -> void:
	var holder := Node3D.new()
	holder.name = "Sheet"
	if pinned:
		# lying frame -> wall frame: the written side (+Y) turns to -Z, the
		# top edge (-Z) up, and the text still reads left to right
		holder.transform = Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.0, -THICKNESS))
	add_child(holder)
	_box(holder, Vector3(size.x, THICKNESS, size.y), Vector3(0.0, THICKNESS * 0.5, 0.0), _paper(COLORS[kind]))
	var ink := _ink(Color(0.05, 0.05, 0.06) if kind == NoteCatalog.Paper.TYPED else INK)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(note_id))
	var lines := 3 if kind == NoteCatalog.Paper.STICKY else 9
	var margin := size.x * 0.12
	var step := (size.y - margin * 2.0) / (lines + 1)
	for i in lines:
		var length := (size.x - margin * 2.0) * rng.randf_range(0.55, 1.0)
		var z := -size.y * 0.5 + margin + step * (i + 1)
		var x := -size.x * 0.5 + margin + length * 0.5
		_box(holder, Vector3(length, 0.0006, 0.0035), Vector3(x, THICKNESS + 0.0003, z), ink)
	if pinned:
		var pin := MeshInstance3D.new()
		var head := SphereMesh.new()
		head.radius = 0.009
		head.height = 0.018
		head.radial_segments = 8
		head.rings = 4
		pin.mesh = head
		pin.material_override = _ink(Color(0.75, 0.1, 0.08))
		pin.position = Vector3(0.0, size.y * 0.5 - 0.02, -0.01)
		add_child(pin)


static func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = at
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(view)


## Paper: matte, with a faint glow so a torch finds it in the dark.
static func _paper(color: Color) -> StandardMaterial3D:
	var key := "paper_" + color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.95
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.08
		_materials[key] = material
	return _materials[key]


static func _ink(color: Color) -> StandardMaterial3D:
	var key := "ink_" + color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.6
		_materials[key] = material
	return _materials[key]
