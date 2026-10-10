class_name SecretSwitch
extends Interactable
## The use-zone on the face of a false panel (the painting, a vent grille,
## the closet panel): the guard looking at it within reach sees its prompt
## and E sends [signal used]. The zone stands just in front of the panel,
## so the probe meets it before the panel's own collision. A used switch
## leaves at once (a spent zone left on the INTERACT layer would still stop
## the probe and hide what lies behind it).

signal used(switch: SecretSwitch)

## What the switch belongs to (a secret id); set by whoever makes it.
var tag: StringName = &""
## Opening id of the panel it opens, &"" for none.
var door_id: StringName = &""


## A switch at [param face] (origin on the floor in the middle of a panel
## face, -Z pointing into the panel) covering [param size] of it.
static func make(prompt: String, face: Transform3D, size: Vector3) -> SecretSwitch:
	var switch := SecretSwitch.new()
	switch.prompt_key = prompt
	switch.transform = face
	switch.add_box(size, Vector3(0.0, size.y * 0.5 + 0.05, size.z * 0.5))
	return switch


func interact(by: Node) -> void:
	if not enabled:
		return
	super(by)
	used.emit(self)


## Takes the switch out of the world (it has done its job).
func retire() -> void:
	enabled = false
	collision_layer = 0
	queue_free()
