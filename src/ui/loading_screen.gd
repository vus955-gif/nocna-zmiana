class_name LoadingScreen
extends Control
## The screen over a night's start (SceneFlow shows it while the museum is
## carved and built): the night's number, one of the loading tips
## (TIP_1..TIP_n, as many as the translations hold; one general line when
## there are none) and a "loading" line whose dots move between the steps.
## The last tip shown is not shown twice in a row.

## Tips are looked for up to this number.
const MAX_TIPS := 200
const DOT_TIME := 0.35

static var _last_tip: int = -1

var tip_key: String = ""
var _night: Label
var _tip_caption: Label
var _tip: Label
var _loading: Label
var _time: float = 0.0


## Translation keys of every tip there is (TIP_1, TIP_2... while they exist).
static func tip_keys() -> Array[String]:
	var keys: Array[String] = []
	for n in range(1, MAX_TIPS + 1):
		var key := "TIP_%d" % n
		if TranslationServer.translate(key) == key:
			break
		keys.append(key)
	return keys


## A tip other than the last one shown ("LOADING_TIP_NONE" without tips).
static func pick_tip(rng: RandomNumberGenerator = null) -> String:
	var keys := tip_keys()
	if keys.is_empty():
		return "LOADING_TIP_NONE"
	var roll := rng.randi_range(0, keys.size() - 1) if rng != null else randi_range(0, keys.size() - 1)
	if keys.size() > 1 and roll == _last_tip:
		roll = (roll + 1) % keys.size()
	_last_tip = roll
	return keys[roll]


func _ready() -> void:
	theme = UiTheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var back := ColorRect.new()
	back.color = Color(0.02, 0.02, 0.025)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 120)
	column.offset_left = 170.0
	column.offset_right = -170.0
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	_night = UiTheme.label("", 64, UiTheme.TEXT, UiTheme.spaced_title_font(8))
	column.add_child(_night)
	var rule := UiTheme.rule(420)
	rule.color = Color(UiTheme.ACCENT, 0.6)
	column.add_child(rule)
	_tip_caption = UiTheme.caption("", 20, UiTheme.ACCENT)
	column.add_child(_tip_caption)
	_tip = UiTheme.label("", 30, UiTheme.TEXT)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(900, 0)
	column.add_child(_tip)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	column.add_child(gap)
	_loading = UiTheme.caption("", 20, UiTheme.MUTED)
	column.add_child(_loading)


## Shows the screen for night [param night] (0: no number) with a new tip.
func open(night: int = 0) -> void:
	tip_key = pick_tip()
	_night.text = (tr("HUD_NIGHT") % night).to_upper() if night > 0 else ""
	_night.visible = night > 0
	_tip_caption.text = tr("LOADING_TIP_CAPTION").to_upper()
	_tip.text = tr(tip_key)
	_time = 0.0
	_show_dots()
	visible = true


func close() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_show_dots()


func _show_dots() -> void:
	var dots := int(_time / DOT_TIME) % 4
	_loading.text = tr("LOADING").to_upper() + ".".repeat(dots)
