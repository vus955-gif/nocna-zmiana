class_name ControlsHelp
extends RefCounted
## The F1 help's paragraphs that name keys, written from the keys the
## player has now (plan 2026-10-21-sterowanie-nakladka): the controls
## ("WASD — move   Shift — sprint ...") and the map's line. Every other help
## key is a plain translation.

## The controls' entries, four lines: [action(s)...]; &"move" and &"weapons"
## are the groups written as one entry.
const LINES := [
	[&"move", &"sprint", &"dash"],
	[&"jump", &"fire", &"punch"],
	[&"reload", &"weapons", &"flashlight", &"interact"],
	[&"toggle_help", &"toggle_fullscreen", &"pause"],
]
const MOVE_ACTIONS := {"f": &"move_forward", "b": &"move_back", "l": &"move_left", "r": &"move_right"}
const GAP := "     "


## The text of the help paragraph [param key] (a translation key).
static func paragraph(key: String) -> String:
	match key:
		"HUD_HELP_CONTROLS_P1":
			return controls()
		"HUD_HELP_MAP":
			return TranslationServer.translate(key) % GameInput.key_label(&"map")
	return TranslationServer.translate(key)


## The title and the four lines of controls.
static func controls() -> String:
	var out := PackedStringArray([TranslationServer.translate("HUD_HELP_CONTROLS_P1")])
	for line: Array in LINES:
		var entries := PackedStringArray()
		for item: StringName in line:
			entries.append(entry(item))
		out.append(GAP.join(entries))
	return "\n".join(out)


## "keys — what they do" for an action (or &"move", &"weapons").
static func entry(item: StringName) -> String:
	match item:
		&"move":
			return "%s — %s" % [_move_keys(), TranslationServer.translate("HELP_MOVE")]
		&"weapons":
			return "%s — %s" % [_weapon_keys(), TranslationServer.translate("HELP_WEAPONS")]
	return "%s — %s" % [keys(item), KeyRow.action_name(item).to_lower()]


## All keys of an action, main first ("V / RMB").
static func keys(action: StringName) -> String:
	var names := GameInput.binding_labels(action)
	return " / ".join(names) if not names.is_empty() else "?"


## The four move keys written close together ("WASD") when each is one
## character, else apart; in the order the language's players say it.
static func _move_keys() -> String:
	var names: Array[String] = []
	for letter in String(TranslationServer.translate("BIND_MOVE_ORDER")):
		names.append(GameInput.key_label(MOVE_ACTIONS.get(letter, &"move_forward")))
	var tight := names.all(func(name: String) -> bool: return name.length() == 1)
	return ("" if tight else " ").join(names)


## "1–8, wheel": the weapon keys (their range when they are the digits in
## order), then the wheel (or whatever moves to the next and previous).
static func _weapon_keys() -> String:
	var names: Array[String] = []
	for slot in WeaponHolder.SLOT_ORDER.size():
		names.append(GameInput.key_label(StringName("weapon_%d" % (slot + 1))))
	var digits := names.size() > 1
	for i in names.size():
		digits = digits and names[i] == str(i + 1)
	var text := "%s–%s" % [names[0], names[-1]] if digits else " ".join(names)
	var next := GameInput.key_label(&"weapon_next")
	var previous := GameInput.key_label(&"weapon_prev")
	var wheel := [KeyBindings.label(-MOUSE_BUTTON_WHEEL_UP), KeyBindings.label(-MOUSE_BUTTON_WHEEL_DOWN)]
	if wheel.has(next) and wheel.has(previous) and next != previous:
		return "%s, %s" % [text, TranslationServer.translate("HELP_WHEEL")]
	return "%s, %s / %s" % [text, next, previous]
