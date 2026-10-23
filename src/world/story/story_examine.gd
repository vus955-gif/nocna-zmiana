class_name StoryExamine
extends Interactable
## The one thing of a staff trail the guard can look at closely
## (StoryVignettes.KEY_PROPS): E sends [signal examined] and MuseumStory
## shows who left it, what it is and two short sentences (ExhibitCard).
## Its look is a StoryProps prop; the use box covers it (a thing on the
## floor: a knee-high box, so a look down finds it).

signal examined(wing: StringName)

var wing: StringName = &""
var kind: StringName = &""


static func create(wing_id: StringName, prop_kind: StringName, at: Transform3D, look: Node3D) -> StoryExamine:
	var thing := StoryExamine.new()
	thing.wing = wing_id
	thing.kind = prop_kind
	thing.transform = at
	thing.name = "Examine_" + String(wing_id)
	if look != null:
		thing.add_child(look)
	return thing


func _init() -> void:
	super()
	prompt_key = "PROMPT_EXAMINE"


func _ready() -> void:
	if StoryVignettes.on_wall(kind):
		add_box(Vector3(0.7, 0.8, 0.5), Vector3(0.0, -0.2, -0.25))
	else:
		add_box(Vector3(0.8, 0.6, 0.8), Vector3(0.0, 0.3, 0.0))


func interact(by: Node) -> void:
	if not enabled:
		return
	super(by)
	examined.emit(wing)
