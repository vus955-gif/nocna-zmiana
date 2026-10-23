class_name ExhibitLabel
extends Interactable
## A museum label by an exhibit (ExhibitLabels): a brass plate with the
## exhibit's name engraved on it, on a wall or a pedestal (the marker on the
## face, -Z out of it), on a slanted museum stand on the floor (the marker on
## the floor, -Z toward the reader; the stand is solid), or the art kit's own
## plate (the T-Rex's: only a plain plate when the level is not dressed).
## E sends [signal read]; MuseumStory shows the card (ExhibitCard).

signal read(id: StringName)

const PLATE_MODEL := &"plaque_brass"
const STAND_MODEL := &"stanchion_post"
## The plate (the model's size: 0.5 x 0.3, 17 mm thick) and the T-Rex's.
const PLATE := Vector3(0.5, 0.3, 0.017)
const ART_PLATE := Vector3(1.6, 0.42, 0.021)
## The stand: the post's height, the plate's tilt back from upright.
const STAND_TOP := 0.97
const STAND_TILT := deg_to_rad(55.0)
const ENGRAVING := Color(0.22, 0.15, 0.07)

var id: StringName = &""
var mount: ExhibitLabels.Mount = ExhibitLabels.Mount.WALL
## False: the art kit already shows a plate here (a dressed level).
var plate: bool = true

var _engraving: Label3D = null


## A label for [param label_id] at [param at] (its marker).
static func create(label_id: StringName, at: Transform3D, with_plate: bool = true) -> ExhibitLabel:
	var label := ExhibitLabel.new()
	label.id = label_id
	label.mount = ExhibitLabels.mount(label_id)
	label.plate = with_plate
	label.transform = at
	label.name = "Label_" + String(label_id)
	return label


func _init() -> void:
	super()
	prompt_key = "PROMPT_READ_LABEL"


func _ready() -> void:
	match mount:
		ExhibitLabels.Mount.STAND:
			_build_stand()
			add_box(Vector3(0.6, 0.6, 0.7), Vector3(0.0, STAND_TOP, -0.15))
		ExhibitLabels.Mount.ART:
			if plate:
				add_child(_plate(ART_PLATE, Vector3(0.0, -ART_PLATE.y * 0.5, 0.0)))
			add_box(Vector3(ART_PLATE.x + 0.2, ART_PLATE.y + 0.3, 0.6), Vector3(0.0, 0.0, -0.3))
		_:
			var face := _plate(PLATE, Vector3(0.0, -PLATE.y * 0.5, 0.0))
			add_child(face)
			_engrave(face, PLATE)
			add_box(Vector3(0.8, 0.6, 0.6), Vector3(0.0, 0.0, -0.3))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _engraving != null:
		_engraving.text = tr(ExhibitLabels.title_key(id))


func interact(by: Node) -> void:
	if not enabled:
		return
	super(by)
	read.emit(id)


## A slanted museum stand: the post (the art's stanchion post, or a thin
## bronze post on a round foot), a bracket and the plate leaning back.
func _build_stand() -> void:
	var post := ArtLibrary.try_instance(STAND_MODEL)
	if post == null:
		post = Node3D.new()
		var bronze := LevelKit.flat(Color(0.2, 0.15, 0.1))
		var foot := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.16
		disc.bottom_radius = 0.17
		disc.height = 0.04
		foot.mesh = disc
		foot.material_override = bronze
		foot.position.y = 0.02
		post.add_child(foot)
		var pole := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.025
		tube.bottom_radius = 0.03
		tube.height = STAND_TOP
		pole.mesh = tube
		pole.material_override = bronze
		pole.position.y = STAND_TOP * 0.5
		post.add_child(pole)
	post.name = "Post"
	add_child(post)
	var holder := Node3D.new()
	holder.name = "Holder"
	# the plate leans back from the reader (-Z), its lower edge at the top of
	# the post: its face turns up toward him, its top edge away from him
	holder.transform = Transform3D(Basis(Vector3.RIGHT, STAND_TILT), Vector3(0.0, STAND_TOP + 0.02, -0.02))
	add_child(holder)
	var face := _plate(PLATE, Vector3.ZERO)
	holder.add_child(face)
	_engrave(face, PLATE)
	# solid to walk into (inside the use box, so the probe meets that first)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.32, STAND_TOP + 0.12, 0.32)
	shape.shape = box
	shape.position = Vector3(0.0, (STAND_TOP + 0.12) * 0.5, 0.0)
	body.add_child(shape)
	add_child(body)


## The brass plate [param size] with its back on z = 0 and its bottom edge
## at [param offset] (the model's own origin is the bottom edge's middle).
static func _plate(size: Vector3, offset: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "Plate"
	root.position = offset
	var model := ArtLibrary.try_instance(PLATE_MODEL) if size == PLATE else null
	if model != null:
		# (the model's back face is 6 mm behind its origin: onto the wall)
		model.position = Vector3(0.0, 0.0, -0.006)
		root.add_child(model)
		return root
	var view := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	view.mesh = mesh
	view.material_override = _brass()
	view.position = Vector3(0.0, size.y * 0.5, -size.z * 0.5)
	root.add_child(view)
	return root


static func _brass() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.72, 0.56, 0.28)
	material.metallic = 0.85
	material.roughness = 0.38
	return material


## The exhibit's name engraved on the plate's face.
func _engrave(face: Node3D, size: Vector3) -> void:
	var text := Label3D.new()
	_engraving = text
	text.name = "Engraving"
	text.text = tr(ExhibitLabels.title_key(id))
	text.font = UiTheme.title_font()
	text.font_size = 36
	text.pixel_size = 0.0006
	text.outline_size = 0
	text.modulate = ENGRAVING
	text.width = size.x / text.pixel_size * 0.86
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.shaded = true
	text.double_sided = false
	# Label3D reads from +Z; the plate's face is -Z
	text.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, size.y * 0.58, -size.z - 0.003))
	face.add_child(text)
