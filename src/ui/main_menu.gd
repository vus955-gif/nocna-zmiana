class_name MainMenu
extends Control
## The title screen (the project's main scene): NOCNA ZMIANA over a live
## scene - the dressed Great Court of Floor I in moonlight with a camera
## drifting over it (MenuStage; the scene builds a moment after the screen
## appears, behind the static backdrop, which then fades away). Continue
## (only with a save), New game (asks before overwriting a save, then which
## shift: DifficultyDialog), Options, Quit. A broken save is set aside by
## GameState and reported here.
## The static backdrop - a dark hall with drifting Dust and a shaft of
## moonlight - is the fallback: it stays when the live scene cannot be
## built, takes too long to build or runs too slowly.
## When it is not the running scene (tests) it emits [signal navigate]
## instead of changing scenes.

signal navigate(target: String)
## The live scene's fate is decided: it is showing (true), or the static
## backdrop stays (false).
signal stage_settled(live: bool)

const QUIT := "quit"
## GameState.last_load_error -> the notice shown under the menu.
const NOTICES := {
	"corrupt": "MENU_SAVE_CORRUPT",
	"corrupt_kept": "MENU_SAVE_CORRUPT_KEPT",
	"unreadable": "MENU_SAVE_UNREADABLE",
	"newer": "MENU_SAVE_NEWER",
}
## Width of the rising Dust beyond the screen on each side (canvas px).
const DUST_MARGIN := 140.0
## Dust specks on a 16:9 view (more on a wider one).
const DUST_AMOUNT := 70
## Seconds the static backdrop takes to fade out (and back in).
const REVEAL_TIME := 2.2
const FALLBACK_TIME := 0.8
## Width (canvas px) of the soft shade behind the menu, and its height at the foot.
const SHADE_WIDTH := 1300.0
const SHADE_FOOT := 320.0

var continue_button: Button
var new_game_button: Button
var options_button: Button
var quit_button: Button
var confirm: ConfirmDialog
var difficulty: DifficultyDialog
var options: OptionsMenu

## The live scene behind the menu (null until it is built, and after it was given up).
var stage: MenuStage = null
## Whether to build the live scene (false: the static backdrop only). Off in
## test and scenario runs, which switch it on where they look at it.
var live_scene: bool = not SavePaths.is_test_run()

var _texts := UiTexts.new()
var _menu: Control
var _backdrop: Control
var _continue_info: Label
var _notice: Label
var _dust: CPUParticles2D
var _fade: Tween = null


func _ready() -> void:
	theme = UiTheme.theme()
	# anchors and offsets: added to a parent that has its size already
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameInput.set_gameplay_scene(false)
	RunState.reset()
	_build()
	var loaded := GameState.load_game()
	continue_button.visible = loaded
	_continue_info.visible = loaded
	if loaded:
		_continue_info.text = (tr("MENU_CONTINUE_INFO") % [GameState.night, GameState.run_dust]).to_upper()
	var notice: String = NOTICES.get(GameState.last_load_error, "")
	_notice.visible = notice != ""
	if notice != "":
		_texts.bind(_notice, notice)
	(continue_button if loaded else new_game_button).grab_focus()
	get_viewport().size_changed.connect(_fit_dust)
	_fit_dust()
	if live_scene:
		_start_stage.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _menu != null:
		_texts.refresh()
		if continue_button.visible:
			_continue_info.text = (tr("MENU_CONTINUE_INFO") % [GameState.night, GameState.run_dust]).to_upper()


## Builds the live scene once the screen has been drawn (the build takes a
## few seconds and holds the frames), lets it draw a few frames behind the
## backdrop, then fades the backdrop away. Any trouble leaves the backdrop.
func _start_stage() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or stage != null:
		return
	var built := MenuStage.new()
	built.name = "MenuStage"
	built.dressed = MuseumFloorLevel.dress_default
	built.failed.connect(_on_stage_failed.bind(built))
	stage = built
	add_child(built)
	move_child(built, 0)
	if not built.build():
		return
	await built.prepare_view()
	if not is_inside_tree() or stage != built:
		return
	built.start()
	_fade_backdrop(0.0, REVEAL_TIME)
	stage_settled.emit(true)


## The live scene is given up: it is freed and the backdrop comes back.
func _on_stage_failed(_reason: String, given_up: MenuStage) -> void:
	if stage == given_up:
		stage = null
	given_up.queue_free()
	_fade_backdrop(1.0, FALLBACK_TIME)
	stage_settled.emit(false)


## The static backdrop to [param opacity] over [param seconds].
func _fade_backdrop(opacity: float, seconds: float) -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_backdrop.visible = true
	_fade = create_tween()
	_fade.tween_property(_backdrop, "modulate:a", opacity, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if opacity <= 0.0:
		# nothing to draw (and no dust to move) once it is gone
		_fade.tween_callback(func() -> void: _backdrop.visible = false)


## A new game on [param shift] (DifficultyRules id), written, and off.
func start_new_game(shift: StringName = PersistentState.DEFAULT_DIFFICULTY) -> void:
	if SceneFlow.busy:
		return
	GameState.new_game()
	GameState.difficulty = shift
	GameState.save_game()
	_go(SceneFlow.MUSEUM)


func _on_continue() -> void:
	if SceneFlow.busy:
		return
	Sfx.play_ui(&"ui_confirm")
	_go(SceneFlow.MUSEUM)


func _on_new_game() -> void:
	if SceneFlow.busy:
		return
	_menu.visible = false
	if GameState.has_save():
		confirm.ask("CONFIRM_NEW_GAME", "CONFIRM_NEW_GAME_DETAIL", "CONFIRM_NEW_GAME_YES", "CONFIRM_NO")
	else:
		Sfx.play_ui(&"ui_confirm")
		difficulty.ask()


func _on_confirm_answered(yes: bool) -> void:
	if yes:
		difficulty.ask()
	else:
		_menu.visible = true
		new_game_button.grab_focus()


func _on_difficulty_chosen(shift: StringName) -> void:
	_menu.visible = true
	start_new_game(shift)


func _on_difficulty_cancelled() -> void:
	_menu.visible = true
	new_game_button.grab_focus()


func _on_options() -> void:
	Sfx.play_ui(&"ui_confirm", -4.0)
	_menu.visible = false
	options.open()


func _on_options_closed() -> void:
	_menu.visible = true
	options_button.grab_focus()


func _on_quit() -> void:
	if SceneFlow.busy:
		return
	Sfx.play_ui(&"ui_back")
	_go(QUIT)


func _go(target: String) -> void:
	if not SceneFlow.is_running(self):
		navigate.emit(target)
	elif target == QUIT:
		SceneFlow.quit()
	else:
		SceneFlow.goto(target)


func _build() -> void:
	_build_backdrop()
	_build_shade()
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu)
	var column := VBoxContainer.new()
	column.position = Vector2(170, 230)
	column.add_theme_constant_override("separation", 0)
	_menu.add_child(column)
	var title := UiTheme.label("NOCNA ZMIANA", 124, UiTheme.TEXT, UiTheme.spaced_title_font(14))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_constant_override("shadow_outline_size", 10)
	column.add_child(title)
	var rule := UiTheme.rule(560)
	rule.color = Color(UiTheme.ACCENT, 0.7)
	column.add_child(rule)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	column.add_child(gap)
	var subtitle := UiTheme.caption("", 22, UiTheme.ACCENT)
	subtitle.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	subtitle.add_theme_constant_override("shadow_outline_size", 6)
	column.add_child(_texts.bind(subtitle, "MENU_SUBTITLE", true))
	var tagline := UiTheme.label("", 30, UiTheme.MUTED, _italic_title())
	tagline.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	tagline.add_theme_constant_override("shadow_outline_size", 6)
	var tagline_margin := MarginContainer.new()
	tagline_margin.add_theme_constant_override("margin_top", 10)
	tagline_margin.add_child(_texts.bind(tagline, "MENU_TAGLINE"))
	column.add_child(tagline_margin)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 80)
	column.add_child(spacer)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	buttons.custom_minimum_size = Vector2(520, 0)
	column.add_child(buttons)
	continue_button = _menu_button(buttons, "MENU_CONTINUE", _on_continue)
	_continue_info = UiTheme.caption("", 18, UiTheme.MUTED)
	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 26)
	info_margin.add_theme_constant_override("margin_bottom", 10)
	info_margin.add_child(_continue_info)
	buttons.add_child(info_margin)
	new_game_button = _menu_button(buttons, "MENU_NEW_GAME", _on_new_game)
	options_button = _menu_button(buttons, "MENU_OPTIONS", _on_options)
	quit_button = _menu_button(buttons, "MENU_QUIT", _on_quit)
	info_margin.visible = true
	_continue_info.visibility_changed.connect(func() -> void: info_margin.visible = _continue_info.visible)
	_build_footer()
	confirm = ConfirmDialog.new()
	confirm.answered.connect(_on_confirm_answered)
	add_child(confirm)
	difficulty = DifficultyDialog.new()
	difficulty.chosen.connect(_on_difficulty_chosen)
	difficulty.cancelled.connect(_on_difficulty_cancelled)
	add_child(difficulty)
	options = OptionsMenu.new()
	options.closed.connect(_on_options_closed)
	add_child(options)


func _menu_button(parent: VBoxContainer, key: String, action: Callable) -> Button:
	var button := UiTheme.menu_button("", 40)
	button.custom_minimum_size = Vector2(0, 70)
	_texts.bind(button, key)
	button.pressed.connect(action)
	button.focus_entered.connect(func() -> void: Sfx.play_ui(&"ui_move", -8.0))
	parent.add_child(button)
	return button


func _build_footer() -> void:
	var version := UiTheme.caption("", 18, UiTheme.DISABLED)
	_texts.bind(version, "MENU_VERSION_FLOOR1", true)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 48)
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_menu.add_child(version)
	var hints := UiTheme.caption("", 18, UiTheme.MUTED)
	_texts.bind(hints, "MENU_HINTS", true)
	hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 48)
	hints.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hints.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_menu.add_child(hints)
	_notice = UiTheme.label("", 24, UiTheme.DANGER)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.custom_minimum_size = Vector2(820, 0)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 110)
	_notice.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_notice.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_menu.add_child(_notice)


## The static backdrop, the fallback of the live scene: a night sky - a dark
## gradient, a soft shaft of moonlight and slowly rising Dust - over the
## whole screen. It covers the live scene until that is ready.
func _build_backdrop() -> void:
	_backdrop = Control.new()
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	var sky := Gradient.new()
	sky.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	sky.colors = PackedColorArray([Color(0.03, 0.035, 0.05), Color(0.045, 0.04, 0.045), Color(0.075, 0.055, 0.04)])
	var sky_texture := GradientTexture2D.new()
	sky_texture.gradient = sky
	sky_texture.fill_from = Vector2(0.5, 0.0)
	sky_texture.fill_to = Vector2(0.5, 1.0)
	_backdrop.add_child(_fullscreen(sky_texture))
	var moon := Gradient.new()
	moon.offsets = PackedFloat32Array([0.0, 1.0])
	moon.colors = PackedColorArray([Color(0.62, 0.7, 0.95, 0.2), Color(0.62, 0.7, 0.95, 0.0)])
	var moon_texture := GradientTexture2D.new()
	moon_texture.gradient = moon
	moon_texture.fill = GradientTexture2D.FILL_RADIAL
	moon_texture.fill_from = Vector2(0.78, 0.05)
	moon_texture.fill_to = Vector2(0.35, 0.95)
	_backdrop.add_child(_fullscreen(moon_texture))
	var edge := Gradient.new()
	edge.offsets = PackedFloat32Array([0.45, 1.0])
	edge.colors = PackedColorArray([Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.75)])
	var edge_texture := GradientTexture2D.new()
	edge_texture.gradient = edge
	edge_texture.fill = GradientTexture2D.FILL_RADIAL
	edge_texture.fill_from = Vector2(0.5, 0.5)
	edge_texture.fill_to = Vector2(1.05, 0.5)
	_backdrop.add_child(_fullscreen(edge_texture))
	var dust := CPUParticles2D.new()
	dust.amount = DUST_AMOUNT
	dust.lifetime = 16.0
	dust.preprocess = 16.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.direction = Vector2(0.15, -1.0)
	dust.spread = 25.0
	dust.gravity = Vector2(0.0, -2.0)
	dust.initial_velocity_min = 25.0
	dust.initial_velocity_max = 70.0
	dust.scale_amount_min = 0.25
	dust.scale_amount_max = 0.7
	dust.texture = _speck()
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(UiTheme.DUST, 0.0), Color(UiTheme.DUST, 0.55), Color(UiTheme.DUST, 0.35), Color(UiTheme.DUST, 0.0)])
	dust.color_ramp = fade
	_backdrop.add_child(dust)
	_dust = dust


## What keeps the menu readable over the live scene: a deep shade down the
## left edge (where the title and the entries stand), a darker foot (the
## footer), a light vignette round the rest.
func _build_shade() -> void:
	var left := Gradient.new()
	left.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	left.colors = PackedColorArray([Color(0.01, 0.012, 0.02, 0.84), Color(0.01, 0.012, 0.02, 0.5), Color(0.01, 0.012, 0.02, 0.0)])
	var left_texture := GradientTexture2D.new()
	left_texture.gradient = left
	left_texture.fill_from = Vector2(0.0, 0.5)
	left_texture.fill_to = Vector2(1.0, 0.5)
	var left_rect := _fullscreen(left_texture)
	left_rect.name = "ShadeLeft"
	left_rect.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left_rect.offset_right = SHADE_WIDTH
	add_child(left_rect)
	var foot := Gradient.new()
	foot.offsets = PackedFloat32Array([0.0, 1.0])
	foot.colors = PackedColorArray([Color(0.01, 0.012, 0.02, 0.0), Color(0.01, 0.012, 0.02, 0.72)])
	var foot_texture := GradientTexture2D.new()
	foot_texture.gradient = foot
	foot_texture.fill_from = Vector2(0.5, 0.0)
	foot_texture.fill_to = Vector2(0.5, 1.0)
	var foot_rect := _fullscreen(foot_texture)
	foot_rect.name = "ShadeFoot"
	foot_rect.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	foot_rect.offset_top = -SHADE_FOOT
	add_child(foot_rect)
	var rim := Gradient.new()
	rim.offsets = PackedFloat32Array([0.55, 1.0])
	rim.colors = PackedColorArray([Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.5)])
	var rim_texture := GradientTexture2D.new()
	rim_texture.gradient = rim
	rim_texture.fill = GradientTexture2D.FILL_RADIAL
	rim_texture.fill_from = Vector2(0.5, 0.5)
	rim_texture.fill_to = Vector2(1.1, 0.5)
	var rim_rect := _fullscreen(rim_texture)
	rim_rect.name = "ShadeRim"
	add_child(rim_rect)


## The rising Dust spans the whole width of the view (wider than 16:9 on an
## ultrawide screen: the canvas stretch widens the view instead of adding
## bars), with the same density.
func _fit_dust() -> void:
	var view := get_viewport_rect().size
	_dust.position = Vector2(view.x * 0.5, view.y + 60.0)
	_dust.emission_rect_extents = Vector2(view.x * 0.5 + DUST_MARGIN, 40.0)
	var amount := maxi(roundi(DUST_AMOUNT * view.x / 1920.0), DUST_AMOUNT)
	if _dust.amount != amount:
		_dust.amount = amount


static func _fullscreen(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func _speck() -> Texture2D:
	var glow := Gradient.new()
	glow.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	glow.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = glow
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 24
	texture.height = 24
	return texture


static func _italic_title() -> Font:
	var font := SystemFont.new()
	font.font_names = UiTheme.title_font().font_names
	font.font_italic = true
	return font
