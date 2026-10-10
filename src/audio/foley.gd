extends Node
## Gives every walker its footsteps (autoload "Foley"): when the guard or
## an exhibit enters the tree it gets a Footsteps child with the right
## profile (profile_for()), so no body script needs to know about sound.
## Busts hover, portraits hang on walls and the T-Rex has steps of its
## own: they get none. A body
## that already has a node named "Footsteps" is left alone (a level or a
## scene may attach its own). Off in test runs (enabled = false).

var enabled: bool = true


func _ready() -> void:
	enabled = AudioContext.automatic()
	get_tree().node_added.connect(_on_node_added)


## The footsteps profile of [param body] (&"" = none).
static func profile_for(body: Node) -> StringName:
	if body is Player or body.is_in_group(&"player"):
		return &"guard"
	if body is WaxFigure:
		return &"wax"
	if body is Wolf:
		return &"wolf"
	if body is Knight:
		return &"knight"
	if body is Raptor:
		return &"raptor"
	return &""   # busts hover, portraits hang on walls, the T-Rex has its own steps


## Attaches footsteps to [param body] if it walks and has none yet.
func attach(body: CharacterBody3D) -> Footsteps:
	if body == null or not body.is_inside_tree() or body.has_node(^"Footsteps"):
		return null
	var profile := profile_for(body)
	if profile == &"":
		return null
	return Footsteps.attach(body, profile)


func _on_node_added(node: Node) -> void:
	if enabled and node is CharacterBody3D:
		# after the body's own _ready (groups, children)
		_attach_later.call_deferred(node)


## Untyped: a body freed before this deferred call arrives as a freed
## object, which a typed parameter would reject with a script error.
func _attach_later(node: Variant) -> void:
	if is_instance_valid(node):
		attach(node as CharacterBody3D)
