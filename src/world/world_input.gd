class_name WorldInput
## Input rules shared by the world's screens (the note reader, the camera
## console): which events put a screen away. A screen that closes lets go
## of the input through GameInput.pop_ui_on_release(): the guard gets it
## back only once the keys are up again, so the E that closed it never
## reaches the guard as a fresh press (it would open the same note again)
## and a click never fires.


## True for an event that puts a world screen away (E, Esc).
static func closes(event: InputEvent) -> bool:
	return event.is_action_pressed(&"interact") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel")
