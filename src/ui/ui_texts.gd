class_name UiTexts
extends RefCounted
## Keeps a menu's fixed texts in the current language: bind() sets a
## control's text from a translation key and remembers it, refresh() sets
## them all again (call it on NOTIFICATION_TRANSLATION_CHANGED).

var _bound: Array = []


## Sets [param control].text to tr([param key]) (upper-cased if asked).
func bind(control: Control, key: String, upper: bool = false) -> Control:
	_bound.append([control, key, upper])
	_apply(control, key, upper)
	return control


func refresh() -> void:
	for entry in _bound:
		if is_instance_valid(entry[0]):
			_apply(entry[0], entry[1], entry[2])


static func _apply(control: Control, key: String, upper: bool) -> void:
	var text := TranslationServer.translate(key)
	control.set(&"text", text.to_upper() if upper else text)
