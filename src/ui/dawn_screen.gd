class_name DawnScreen
extends CanvasLayer
## The night outlasted: the picture fades to a pale morning light, "6:00"
## and "Dawn" come up with the night survived, the Dust still carried, on
## Floor I the secrets found (tonight and in all) with the rewards claimed,
## and a word that the fuses and the crystal went back to their places;
## then [signal finished] asks for the next night. Runs while paused, too.

signal finished

const LAYER := 90                 ## the card's CanvasLayer; the subtitle bar rises above it during dawn
const FADE_TIME := 1.6
## Seconds the dawn card stays up before the next night loads.
const CARD_TIME := 3.4
const DAWN_COLOR := Color(1.0, 0.8, 0.62)
const SKY := Color(0.2, 0.17, 0.2)

var _veil: Control
var _card: Control
var _title: Label
var _survived: Label
var _dust: Label
var _secrets: Label
var _lost: Label
var _playing: bool = false


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


## Starts the sequence: [param night] was outlasted with
## [param carried_dust] Dust still on the guard. [param secrets] (Floor I):
## {found, total, tonight, rewards, rewards_total}; a level without secrets
## (total 0, or nothing given) shows no line for them.
func play(night: int, carried_dust: int, secrets: Dictionary = {}) -> void:
	_survived.text = tr("NIGHT_DAWN_SURVIVED") % night
	_dust.text = tr("NIGHT_DAWN_DUST") % carried_dust
	var total := int(secrets.get("total", 0))
	_secrets.visible = total > 0
	_secrets.text = tr("NIGHT_DAWN_SECRETS") % [int(secrets.get("found", 0)), total, int(secrets.get("tonight", 0)),
			int(secrets.get("rewards", 0)), int(secrets.get("rewards_total", 0))] if total > 0 else ""
	_lost.text = tr("NIGHT_DAWN_LOST")
	_title.text = tr("NIGHT_DAWN").to_upper()   # in the language now, not the one the card was built in
	visible = true
	_playing = true
	_veil.modulate.a = 0.0
	_card.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_veil, "modulate:a", 1.0, FADE_TIME).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_card, "modulate:a", 1.0, 0.5)
	tween.tween_interval(CARD_TIME)
	tween.tween_callback(_finish)


func is_playing() -> bool:
	return _playing


## The card's lines (for tests), joined by " | ".
func text() -> String:
	var lines := [_title.text, _survived.text, _dust.text]
	if _secrets.visible:
		lines.append(_secrets.text)
	lines.append(_lost.text)
	return " | ".join(lines)


## The secrets line ("" when the card has none).
func secrets_text() -> String:
	return _secrets.text if _secrets.visible else ""


func _finish() -> void:
	_playing = false
	finished.emit()


func _build() -> void:
	var root := Control.new()
	root.theme = UiTheme.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	# a cold morning sky, warmer towards the bottom
	var gradient := Gradient.new()
	gradient.set_color(0, SKY)
	gradient.set_color(1, Color(0.62, 0.42, 0.36))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	var veil := TextureRect.new()
	veil.texture = texture
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil = veil
	root.add_child(_veil)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 20)
	center.add_child(column)
	_card = column
	var clock := UiTheme.label("6:00", 150, DAWN_COLOR, UiTheme.strong_font())
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(clock)
	_title = UiTheme.label(tr("NIGHT_DAWN").to_upper(), 40, UiTheme.TEXT, UiTheme.spaced_font(16))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	column.add_child(UiTheme.ornament(320.0))
	_survived = UiTheme.label("", 28, UiTheme.TEXT)
	_survived.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_survived)
	_dust = UiTheme.label("", 26, Color(1.0, 0.84, 0.5))
	_dust.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_dust)
	_secrets = UiTheme.label("", 24, UiTheme.TEXT)
	_secrets.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_secrets.visible = false
	column.add_child(_secrets)
	_lost = UiTheme.label("", 24, Color(UiTheme.TEXT, 0.82), UiTheme.italic_font())
	_lost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_lost)
