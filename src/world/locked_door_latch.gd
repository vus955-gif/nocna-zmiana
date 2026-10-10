class_name LockedDoorLatch
extends Interactable
## The use-zone on one face of tonight's locked door (NightConfig
## .locked_door). Without the janitor's key E only tries the handle (the
## door refuses: Door.try_open() -> open_refused, [signal refused]); with
## the key the door unlocks and opens ([signal unlocked_with_key]).
## Origin in the middle of the door face at floor level, -Z into the door.

signal refused
signal unlocked_with_key

var door: Door = null
## Returns true while the guard holds the janitor's key.
var has_key: Callable = func() -> bool: return false
## Held shut by something stronger than the lock (the hall sealed for the
## boss fight): the key does not turn meanwhile.
var held: bool = false


static func make(locked: Door, face: Transform3D) -> LockedDoorLatch:
	var latch := LockedDoorLatch.new()
	latch.name = "Latch_" + String(locked.id)
	latch.door = locked
	latch.transform = face
	latch.add_box(Vector3(locked.width * 0.9, minf(locked.height, 3.0) * 0.8, 0.3), Vector3(0.0, minf(locked.height, 3.0) * 0.4 + 0.05, 0.15))
	return latch


func _init() -> void:
	super()
	prompt_key = "PROMPT_DOOR_LOCKED"


func prompt() -> String:
	return tr("PROMPT_DOOR_KEY" if has_key.call() and not held else prompt_key)


func can_interact(by: Node) -> bool:
	return super(by) and is_instance_valid(door) and door.locked


## Holds the door shut whatever the key ([param on]), or lets it go again.
func set_held(on: bool) -> void:
	held = on


func interact(by: Node) -> void:
	if not can_interact(by):
		return
	super(by)
	if held or not has_key.call():
		door.try_open()
		Sfx.play(&"deny", -6.0)
		refused.emit()
		return
	WorldSounds.cue_at(&"keys", global_position + Vector3.UP * 1.2)
	door.unlock()
	door.open()
	unlocked_with_key.emit()


func retire() -> void:
	enabled = false
	collision_layer = 0
	queue_free()
