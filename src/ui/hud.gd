class_name Hud
extends CanvasLayer
## Guard HUD built in code, every piece on a museum plaque (UiTheme, design
## 2026-10-19-styl-hud): health, stamina and the torch as brass instruments
## on one plaque (bottom left), the weapon's plaque with its slots, name and
## ammo (bottom right), crosshair with hit markers, damage vignette, death
## notice, FPS counter and the F1 help panel. In the museum also: the
## night's card at its start (number, modifier), the night's plaque in the
## top left (number, clock, the goal with the fuse icons under it), a hint
## strip near the bottom (a note read, a first-time tip) and the boss's bar
## at the top (bound through Events.boss_awakened). Above the weapon's name
## a row of slot numbers 1-8: the weapons found so far, the one in hand lit
## in its own colour. Hints from the world (a lock hit with the wrong tool)
## come in through Events.hint_requested.
## On Floor I (enable_floor()): a small card with the room's name in its
## wing's colour on a first visit, the crystal shards under the goal, and a
## wing guardian's bar with its name and title (Events.guardian_awakened).
## The night's plaque (top left) and the boss's block (top middle) share
## the top edge: the boss's block never takes more than half the canvas (a
## long "NAME - TITLE" wraps), and the goal wraps in the room left beside
## it. Under the boss's block the top middle stacks the toast and the
## room's card (each slides down below what stands above it), and the
## night's card keeps clear of a discovery's banner (below_source).

const HIT_COLOR := Color(1.0, 1.0, 1.0)
const WEAK_POINT_COLOR := Color(1.0, 0.8, 0.2)
const KILL_COLOR := Color(1.0, 0.25, 0.2)
const BLOCKED_COLOR := Color(0.6, 0.6, 0.6)
const DUST_COLOR := Color(1.0, 0.84, 0.5)
## Seconds the "+n" of a Dust gain stays up (it fades in the last half).
const GAIN_TIME := 1.6
const TOAST_COLOR := Color(0.93, 0.9, 0.84)
## Seconds a toast / a warning stays up (both fade in the last 0.6 s).
const TOAST_TIME := 2.2
const WARNING_TIME := 4.0
## The card at a night's start: seconds on screen, fading in and out.
const CARD_TIME := 5.0
const CARD_FADE_IN := 0.6
const CARD_FADE_OUT := 1.2
## Seconds a hint line stays up by default (it fades in the last 0.6 s).
const HINT_TIME := 6.0
const OBJECTIVE_COLOR := Color(0.93, 0.9, 0.84, 0.95)
const BOSS_COLOR := UiTheme.EMERGENCY
## Health fractions where the boss's phases change (notches on its bar).
const BOSS_PHASES: Array[float] = [0.66, 0.33]
## The boss's bar and name are at most this much of the canvas's width (a
## longer name wraps); the bar itself is BOSS_BAR_WIDTH wide, or narrower on
## a canvas too narrow for it.
const BOSS_BLOCK_SHARE := 0.5
const BOSS_BAR_WIDTH := 720.0
## Air kept between the goal's plaque and the boss's block, and the least
## width the goal is wrapped to.
const TOP_GAP := 28.0
const GOAL_MIN_WIDTH := 200.0
## Seconds a world hint (a lock's) stays under the crosshair.
const WORLD_HINT_TIME := 3.5
## Slot numbers: owned, in hand, not found yet.
const SLOT_OWNED := Color(0.93, 0.9, 0.84, 0.8)
const SLOT_EMPTY := Color(0.93, 0.9, 0.84, 0.2)
## Fatigue's cues (plan 2026-10-10-kawiarnia-zmeczenie): the cool vignette
## at the worst of the night, and a blink (both lids, LID_SHARE of the
## screen each, BLINK_TIME s) every BLINK_PERIOD_MAX..MIN s once the effect
## passes BLINK_FROM.
const FATIGUE_VIGNETTE := 0.22
const BLINK_FROM := 0.4
const BLINK_PERIOD_MAX := 14.0
const BLINK_PERIOD_MIN := 7.0
const BLINK_TIME := 0.4
const LID_SHARE := 0.12
## Distance of the corner plaques from the screen's edges.
const MARGIN := 32.0
## The top middle: the boss block's top, the least tops of the toast and
## of the room's card, the air between them.
const BOSS_TOP := 30.0
const TOAST_TOP := 100.0
const ROOM_TOP := 150.0
const STACK_GAP := 10.0
## The night's card: its centre this far above the screen's, and the air
## kept under a discovery's banner.
const CARD_RISE := 120.0
const CARD_GAP := 18.0
## The hint strip's bottom edge above the screen's bottom.
const HINT_BOTTOM := 170.0
## No text of the HUD is smaller (canvas units: 13 px in a 1280x1024 window).
const MIN_TEXT := 20
## Health under this share pulses its bar's mount.
const LOW_HEALTH := 0.3
## Width of the instrument bars.
const BAR_WIDTH := 300.0
## The group of the HUD (the subtitles keep above its hint strip).
const GROUP := &"hud"

var player: Player
## Translation keys of the F1 help panel, one paragraph each (the sandbox
## adds its spawn keys).
var help_keys: PackedStringArray = ["HUD_HELP_CONTROLS_P1", "HUD_HELP_TIPS"]
## The night's carried Dust (top right); the sandbox has none.
var show_dust: bool = false
## FPS counter regardless of the option (dev scenes).
var always_show_fps: bool = false
## Night number shown top left (0 = none, the sandbox).
var night: int = 0
## Returns the bottom edge (canvas units) of what the world shows under
## the top edge (WorldHud.banner_bottom; 0 when nothing): the night's card
## keeps under it.
var below_source: Callable = Callable()

var _health_label: Label
var _health_bar: HudGauge
var _stamina_bar: StaminaBar
## The vitals' plaque and its state icons (caffeine, fatigue).
var _vitals: PanelContainer
var _caffeine_icon: UiIcons
var _tired_icon: UiIcons
## Flashlight battery (under the stamina bar).
var _torch_bar: HudGauge
var _torch_icon: UiIcons
var _arms: PanelContainer
var _weapon_label: Label
var _ammo_row: HBoxContainer
var _ammo_label: Label
## Slot numbers 1-8 above the weapon's name.
var _slots: HBoxContainer
var _slot_labels: Array[Label] = []
## Index of the slot lit in its weapon's colour (-1: nothing in hand).
var _slot_in_hand: int = -1
var _battery_bar: HudGauge
var _crosshair: Crosshair
var _vignette: TextureRect
## Fatigue: a cool shade round the edges and, rarely, a slow blink.
var _tired_vignette: TextureRect
var _lid_top: ColorRect
var _lid_bottom: ColorRect
var _blink_wait: float = BLINK_PERIOD_MAX
var _blink_phase: float = 0.0
var _death_label: Label
var _fps_label: Label
var _help: PanelContainer
var _help_label: Label
var _prompt: PanelContainer
var _prompt_key: Label
var _prompt_label: Label
var _dust_box: VBoxContainer
var _dust_row: HBoxContainer
var _dust_label: Label
var _dust_gain: Label
var _gain_amount: int = 0
var _gain_left: float = 0.0
var _bump: float = 0.0
## The night's plaque (top left) round the night, clock, goal and help line.
var _night_plate: PanelContainer
var _night_box: VBoxContainer
var _night_label: Label
var _clock_label: Label
var _objective_row: HBoxContainer
var _objective_label: Label
var _fuse_icons: FuseIcons
var _help_hint: Label
var _boss_row: HBoxContainer
var _boss_box: VBoxContainer
var _boss_plate: PanelContainer
var _boss_name: Label
var _boss_bar: HudGauge
var _boss: Node = null
var _boss_fade: float = 0.0
var _toast_plate: PanelContainer
var _toast: Label
var _toast_left: float = 0.0
var _card: VBoxContainer
var _card_shade: TextureRect
var _card_title: Label
var _card_subtitle: Label
var _card_detail: Label
var _card_time: float = INF
var _hint: PanelContainer
var _hint_label: Label
var _hint_left: float = 0.0
## Floor I (built by enable_floor()).
var _room_card: RoomCard = null
var _shards_label: Label = null


## Two small fuses under the night's goal: outlined while missing, amber
## in the guard's pocket, glowing green once in the fuse box.
class FuseIcons extends Control:
	const SIZE := Vector2(12, 26)
	const GAP := 8.0
	var carried: int = 0
	var inserted: int = 0

	func _init() -> void:
		custom_minimum_size = Vector2(SIZE.x * 2.0 + GAP, SIZE.y)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_counts(in_pocket: int, in_box: int) -> void:
		carried = in_pocket
		inserted = in_box
		queue_redraw()

	func _draw() -> void:
		for i in 2:
			var rect := Rect2(Vector2(i * (SIZE.x + GAP), (size.y - SIZE.y) * 0.5), SIZE)
			var body := rect.grow_individual(0, -4, 0, -4)
			if i < inserted:
				draw_rect(body, Color(0.35, 1.0, 0.5, 0.95))
			elif i < inserted + carried:
				draw_rect(body, Color(1.0, 0.72, 0.35, 0.95))
			else:
				draw_rect(body, Color(0.0, 0.0, 0.0, 0.35))
				draw_rect(body, Color(0.93, 0.9, 0.84, 0.55), false, 1.5)
			for cap in [rect.position.y, rect.end.y - 4.0]:
				draw_rect(Rect2(rect.position.x + 2.0, cap, SIZE.x - 4.0, 4.0), Color(0.78, 0.62, 0.3, 0.9))


## The stamina bar, an instrument of the HUD's family (HudGauge's mount):
## stamina from the left in the bar's yellow (red while exhausted), the
## share fatigue took eaten from the right (a hatched slate segment:
## blocked, not empty), the fill in a pulsing crema cream while caffeine
## lasts - pale and bright against the exhausted red (an orange copper was
## the red's twin at 8 px, and as bright).
class StaminaBar extends Control:
	const FILL := Color(0.95, 0.8, 0.3)
	const EXHAUSTED := Color(1.0, 0.43, 0.33)
	## The pulse of the caffeinated fill runs between these two.
	const CAFFEINE := Color(0.96, 0.89, 0.72)
	const CAFFEINE_PEAK := Color(1.0, 0.97, 0.88)
	const TIRED := Color(0.42, 0.38, 0.5, 0.85)
	const HATCH := Color(0.08, 0.07, 0.1, 0.55)
	const BACKGROUND := Color(0.0, 0.0, 0.0, 0.5)
	const HATCH_STEP := 6.0
	## Stamina (of the full maximum), the usable share, the state.
	var value: float = 1.0
	var cap: float = 1.0
	var exhausted: bool = false
	## 0..1: how far the fill has turned to cream.
	var caffeine: float = 0.0
	## How many times the bar has been drawn (a test reads it).
	var draws: int = 0
	var _pulse: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(Hud.BAR_WIDTH, 13)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	## Redraws only when something shows: a changed value, cap, state or
	## turning of the fill, and every frame while the caffeinated fill pulses.
	func show_state(stamina_fraction: float, cap_fraction: float, is_exhausted: bool, caffeinated: bool, delta: float) -> void:
		var new_value := clampf(stamina_fraction, 0.0, 1.0)
		var new_cap := clampf(cap_fraction, 0.0, 1.0)
		var new_caffeine := move_toward(caffeine, 1.0 if caffeinated else 0.0, delta * 2.0)
		var changed := new_value != value or new_cap != cap or is_exhausted != exhausted or new_caffeine != caffeine
		changed = changed or (new_caffeine > 0.0 and not is_exhausted)
		value = new_value
		cap = new_cap
		exhausted = is_exhausted
		caffeine = new_caffeine
		_pulse += delta
		if changed:
			queue_redraw()

	## Share of the bar fatigue took (0 fresh).
	func tired_fraction() -> float:
		return 1.0 - cap

	func fill_color() -> Color:
		if exhausted:
			return EXHAUSTED
		var cream := CAFFEINE.lerp(CAFFEINE_PEAK, 0.5 + 0.5 * sin(_pulse * 2.4))
		return FILL.lerp(cream, caffeine)

	func _draw() -> void:
		draws += 1
		var channel := HudGauge.draw_mount(self, Rect2(Vector2.ZERO, size))
		var w := channel.size.x
		var h := channel.size.y
		var origin := channel.position
		HudGauge.draw_fill(self, Rect2(origin, Vector2(w * value, h)), fill_color())
		HudGauge.draw_scale(self, channel, 4)
		if cap >= 0.999:
			return
		var usable := w * cap
		draw_rect(Rect2(origin + Vector2(usable, 0.0), Vector2(w - usable, h)), TIRED)
		var right := origin.x + w
		var x := origin.x + usable
		while x < right:
			var to := Vector2(x + h, origin.y)
			if to.x > right:
				to = Vector2(right, origin.y + (to.x - right))
			draw_line(Vector2(x, origin.y + h), to, HATCH, 1.0, true)
			x += HATCH_STEP
		draw_rect(Rect2(origin.x + usable - 1.0, origin.y, 1.0, h), Color(0.0, 0.0, 0.0, 0.7))


class Crosshair extends Control:
	const MARKER_TIME := 0.2
	var marker_time: float = 0.0
	var marker_color: Color = Color.WHITE

	func show_marker(color: Color) -> void:
		marker_color = color
		marker_time = MARKER_TIME
		queue_redraw()

	func _process(delta: float) -> void:
		if marker_time > 0.0:
			marker_time = maxf(marker_time - delta, 0.0)
			queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		draw_circle(center, 3.5, Color(0.0, 0.0, 0.0, 0.6))   # outline: readable on pale walls
		draw_circle(center, 2.5, Color(1.0, 1.0, 1.0, 0.9))
		if marker_time <= 0.0:
			return
		var color := Color(marker_color, marker_time / MARKER_TIME)
		for corner in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(center + corner * 7.0, center + corner * 15.0, color, 3.0, true)


func _ready() -> void:
	layer = 10
	add_to_group(GROUP)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_vignette = _make_vignette()
	root.add_child(_vignette)
	_tired_vignette = _make_vignette(Color(0.02, 0.03, 0.06), 0.45)
	root.add_child(_tired_vignette)
	_lid_top = _lid(root, true)
	_lid_bottom = _lid(root, false)
	_crosshair = Crosshair.new()
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_crosshair)
	_build_vitals(root)
	_build_arms(root)

	_death_label = _label(60, UiTheme.DANGER, UiTheme.spaced_title_font(10))
	_death_label.label_settings.outline_size = 8
	_death_label.label_settings.outline_color = Color(0.0, 0.0, 0.0, 0.85)
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.visible = false
	_pin(root, _death_label, Control.PRESET_CENTER)

	_fps_label = _label(MIN_TEXT, Color(1.0, 1.0, 1.0, 0.65))
	_pin(root, _fps_label, Control.PRESET_CENTER_TOP)
	_fps_label.offset_top = 6.0
	_fps_label.offset_bottom = 6.0

	_build_dust(root)
	_build_night(root)
	_build_boss(root)

	_toast_plate = PanelContainer.new()
	_toast_plate.add_theme_stylebox_override("panel", UiTheme.plaque(UiTheme.Plaque.CHIP))
	_toast = _label(22, TOAST_COLOR, UiTheme.spaced_font(4))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_plate.add_child(_toast)
	_toast_plate.modulate.a = 0.0
	_toast_plate.visible = false
	_pin(root, _toast_plate, Control.PRESET_CENTER_TOP)
	RunState.dust_changed.connect(_on_dust_changed)

	_build_card(root)
	_build_hint(root)
	_build_prompt(root)

	_help = PanelContainer.new()
	var help_style := UiTheme.plaque(UiTheme.Plaque.LABEL)
	help_style.content_margin_left = 30.0
	help_style.content_margin_right = 30.0
	_help.add_theme_stylebox_override("panel", help_style)
	_help_label = _label(21, UiTheme.TEXT, UiTheme.body_font())
	_help.add_child(_help_label)
	_pin(root, _help, Control.PRESET_TOP_LEFT)
	_refresh_texts()

	Events.player_damaged.connect(_on_player_damaged)
	Events.hit_landed.connect(_on_hit_landed)
	Events.hint_requested.connect(_on_hint_requested)


## The vitals' plaque: the heart and the health number (the state icons
## of caffeine and fatigue at the right), the health bar, the stamina bar,
## the torch's battery.
func _build_vitals(root: Control) -> void:
	_vitals = PanelContainer.new()
	_vitals.name = "Vitals"
	_vitals.add_theme_stylebox_override("panel", UiTheme.plaque(UiTheme.Plaque.HUD))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	_vitals.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(UiIcons.make(UiIcons.Kind.HEART, UiTheme.EMERGENCY.lightened(0.12), 1.15))
	_health_label = _label(40, UiTheme.TEXT, UiTheme.number_font())
	_health_label.custom_minimum_size.y = 44.0
	_health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_health_label)
	var spring := Control.new()
	spring.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(spring)
	_caffeine_icon = UiIcons.make(UiIcons.Kind.CUP, StaminaBar.CAFFEINE, 1.3)
	_caffeine_icon.modulate.a = 0.0
	head.add_child(_caffeine_icon)
	_tired_icon = UiIcons.make(UiIcons.Kind.TIRED, StaminaBar.TIRED.lightened(0.45), 1.3)
	_tired_icon.modulate.a = 0.0
	head.add_child(_tired_icon)
	column.add_child(head)
	_health_bar = HudGauge.make(Vector2(BAR_WIDTH, 18), UiTheme.EMERGENCY, 10)
	_health_bar.low_pulse = LOW_HEALTH
	column.add_child(_health_bar)
	_stamina_bar = StaminaBar.new()
	column.add_child(_stamina_bar)
	var torch_row := HBoxContainer.new()
	torch_row.add_theme_constant_override("separation", 6)
	_torch_icon = UiIcons.make(UiIcons.Kind.TORCH, UiTheme.MOON.lightened(0.2), 1.2)
	torch_row.add_child(_torch_icon)
	_torch_bar = HudGauge.make(Vector2(BAR_WIDTH - UiIcons.BOX * 1.2 - 6.0, 12), Color(0.88, 0.93, 0.98), 0)
	_torch_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	torch_row.add_child(_torch_bar)
	column.add_child(torch_row)
	_pin(root, _vitals, Control.PRESET_BOTTOM_LEFT)


## The weapon's plaque: the slot numbers, the weapon's name, the ammo (or
## its battery).
func _build_arms(root: Control) -> void:
	_arms = PanelContainer.new()
	_arms.name = "Arms"
	_arms.add_theme_stylebox_override("panel", UiTheme.plaque(UiTheme.Plaque.HUD))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	_arms.add_child(column)
	_slots = HBoxContainer.new()
	_slots.alignment = BoxContainer.ALIGNMENT_END
	_slots.size_flags_horizontal = Control.SIZE_SHRINK_END
	_slots.add_theme_constant_override("separation", 9)
	for i in WeaponHolder.SLOT_ORDER.size():
		var slot := _label(MIN_TEXT, SLOT_EMPTY, UiTheme.number_font())
		slot.text = str(i + 1)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.custom_minimum_size.x = 14.0
		_slots.add_child(slot)
		_slot_labels.append(slot)
	_slots.draw.connect(_draw_slot_mark)
	column.add_child(_slots)
	_weapon_label = _label(22, UiTheme.TEXT, UiTheme.spaced_font(3))
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weapon_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(_weapon_label)
	_ammo_row = HBoxContainer.new()
	_ammo_row.alignment = BoxContainer.ALIGNMENT_END
	_ammo_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	_ammo_row.add_theme_constant_override("separation", 8)
	_ammo_row.add_child(UiIcons.make(UiIcons.Kind.CARTRIDGE, UiTheme.BRASS, 1.5))
	_ammo_label = _label(46, UiTheme.TEXT, UiTheme.number_font())
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_row.add_child(_ammo_label)
	column.add_child(_ammo_row)
	_battery_bar = HudGauge.make(Vector2(220, 16), UiTheme.MOON, 5)
	_battery_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(_battery_bar)
	_pin(root, _arms, Control.PRESET_BOTTOM_RIGHT)


## The Dust: a small plaque with the diamond and the count, the "+n" under it.
func _build_dust(root: Control) -> void:
	_dust_box = VBoxContainer.new()
	_dust_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_dust_box.add_theme_constant_override("separation", 4)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiTheme.plaque(UiTheme.Plaque.CHIP))
	plate.size_flags_horizontal = Control.SIZE_SHRINK_END
	_dust_row = HBoxContainer.new()
	_dust_row.alignment = BoxContainer.ALIGNMENT_END
	_dust_row.add_theme_constant_override("separation", 10)
	_dust_row.add_child(DustIcon.make(1.1))
	_dust_label = _label(34, DUST_COLOR, UiTheme.number_font())
	_dust_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dust_row.add_child(_dust_label)
	plate.add_child(_dust_row)
	_dust_box.add_child(plate)
	_dust_gain = _label(24, Color(1.0, 0.95, 0.82), UiTheme.number_font())
	_dust_gain.label_settings.outline_size = 5
	_dust_gain.label_settings.outline_color = Color(0.0, 0.0, 0.0, 0.75)
	_dust_gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dust_gain.modulate.a = 0.0
	_dust_box.add_child(_dust_gain)
	_pin(root, _dust_box, Control.PRESET_TOP_RIGHT)
	_dust_label.text = str(RunState.dust)


## The night's plaque: "NIGHT 3 · 23:47", a brass hairline, the goal with
## the fuse icons, the shards, the help line.
func _build_night(root: Control) -> void:
	_night_plate = PanelContainer.new()
	_night_plate.name = "NightPlate"
	_night_plate.add_theme_stylebox_override("panel", UiTheme.plaque(UiTheme.Plaque.HUD))
	_night_box = VBoxContainer.new()
	_night_box.add_theme_constant_override("separation", 6)
	_night_plate.add_child(_night_box)
	var night_row := HBoxContainer.new()
	night_row.add_theme_constant_override("separation", 14)
	_night_label = _label(24, UiTheme.TEXT, UiTheme.spaced_font(6))
	night_row.add_child(_night_label)
	_clock_label = _label(24, UiTheme.ACCENT, UiTheme.spaced_font(3))
	_clock_label.visible = false
	night_row.add_child(_clock_label)
	_night_box.add_child(night_row)
	var hairline := UiTheme.ornament(0.0, false)
	hairline.custom_minimum_size = Vector2(0.0, 4.0)
	hairline.size_flags_horizontal = Control.SIZE_FILL
	_night_box.add_child(hairline)
	_objective_row = HBoxContainer.new()
	_objective_row.add_theme_constant_override("separation", 12)
	_fuse_icons = FuseIcons.new()
	_fuse_icons.visible = false
	_objective_row.add_child(_fuse_icons)
	_objective_label = _label(23, OBJECTIVE_COLOR, UiTheme.body_font())
	_objective_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_objective_row.add_child(_objective_label)
	_objective_row.visible = false
	_night_box.add_child(_objective_row)
	_help_hint = _label(MIN_TEXT, Color(UiTheme.MUTED, 0.95), UiTheme.body_font())
	_night_box.add_child(_help_hint)
	_pin(root, _night_plate, Control.PRESET_TOP_LEFT)
	_night_plate.visible = night > 0
	_night_box.visible = night > 0


## The boss's block, top middle: its name on a plaque, the bar under it
## with brass finials, notches at the phase changes and a trail of each fall.
func _build_boss(root: Control) -> void:
	_boss_box = VBoxContainer.new()
	_boss_box.add_theme_constant_override("separation", 5)
	_boss_plate = PanelContainer.new()
	_boss_plate.add_theme_stylebox_override("panel", UiTheme.plaque(UiTheme.Plaque.CHIP))
	_boss_plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_boss_name = _label(23, Color(0.97, 0.88, 0.82), UiTheme.spaced_font(7))
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_plate.add_child(_boss_name)
	_boss_box.add_child(_boss_plate)
	_boss_bar = HudGauge.make(Vector2(BOSS_BAR_WIDTH, 22), BOSS_COLOR, 0)
	_boss_bar.marks = BOSS_PHASES
	_boss_bar.finials = true
	_boss_bar.trail = true
	_boss_box.add_child(_boss_bar)
	_boss_box.visible = false
	# a row across the top keeps the block centred at whatever width its name gives it
	_boss_row = HBoxContainer.new()
	_boss_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_boss_row.add_child(_boss_box)
	_pin(root, _boss_row, Control.PRESET_TOP_WIDE)
	_boss_row.offset_top = BOSS_TOP
	_boss_row.offset_bottom = BOSS_TOP
	Events.boss_awakened.connect(_on_boss_awakened)


## The night's card: "NIGHT 3", a brass ornament, "BLACKOUT" in amber, the
## detail in italic - over a soft dark halo.
func _build_card(root: Control) -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(0.0, 0.0, 0.0, 0.62), Color(0.0, 0.0, 0.0, 0.38), Color(0.0, 0.0, 0.0, 0.0)])
	var halo := GradientTexture2D.new()
	halo.gradient = gradient
	halo.fill = GradientTexture2D.FILL_RADIAL
	halo.fill_from = Vector2(0.5, 0.5)
	halo.fill_to = Vector2(1.0, 0.5)
	halo.width = 128
	halo.height = 64
	_card_shade = TextureRect.new()
	_card_shade.texture = halo
	_card_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_card_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_shade.modulate.a = 0.0
	root.add_child(_card_shade)
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 8)
	_card_title = _label(60, TOAST_COLOR, UiTheme.spaced_title_font(12))
	_card_title.label_settings.outline_size = 6
	_card_title.label_settings.outline_color = Color(0.0, 0.0, 0.0, 0.7)
	_card_subtitle = _label(28, UiTheme.ACCENT, UiTheme.spaced_font(6))
	_card_detail = _label(25, Color(TOAST_COLOR, 0.92), UiTheme.italic_font())
	_card.add_child(_card_title)
	_card.add_child(UiTheme.ornament(300.0))
	_card.add_child(_card_subtitle)
	_card.add_child(_card_detail)
	for line in [_card_title, _card_subtitle, _card_detail]:
		(line as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.modulate.a = 0.0
	_pin(root, _card, Control.PRESET_CENTER)


## A hint or a note, low in the middle of the screen, on a plaque.
func _build_hint(root: Control) -> void:
	_hint = PanelContainer.new()
	var hint_style := UiTheme.plaque(UiTheme.Plaque.HUD)
	hint_style.content_margin_left = 28.0
	hint_style.content_margin_right = 28.0
	hint_style.content_margin_top = 12.0
	hint_style.content_margin_bottom = 13.0
	_hint.add_theme_stylebox_override("panel", hint_style)
	_hint_label = _label(24, UiTheme.TEXT, UiTheme.body_font())
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(420, 0)
	_hint.add_child(_hint_label)
	_hint.modulate.a = 0.0
	_pin(root, _hint, Control.PRESET_CENTER_BOTTOM)
	_place_hint()


## "[E] Upgrade terminal": a brass keycap and the action on a plaque.
func _build_prompt(root: Control) -> void:
	_prompt = PanelContainer.new()
	var prompt_style := UiTheme.plaque(UiTheme.Plaque.CHIP)
	prompt_style.content_margin_left = 9.0
	prompt_style.content_margin_right = 22.0
	_prompt.add_theme_stylebox_override("panel", prompt_style)
	var prompt_row := HBoxContainer.new()
	prompt_row.add_theme_constant_override("separation", 14)
	_prompt.add_child(prompt_row)
	var keycap := PanelContainer.new()
	keycap.add_theme_stylebox_override("panel", UiTheme.plaque(UiTheme.Plaque.KEYCAP))
	keycap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_prompt_key = _label(22, Color(0.12, 0.08, 0.03), UiTheme.strong_font())
	_prompt_key.label_settings.shadow_color = Color(1.0, 0.95, 0.8, 0.45)
	_prompt_key.label_settings.shadow_offset = Vector2(0.0, 1.0)
	_prompt_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_key.custom_minimum_size.x = 16.0
	keycap.add_child(_prompt_key)
	prompt_row.add_child(keycap)
	_prompt_label = _label(25, UiTheme.TEXT, UiTheme.body_font())
	_prompt_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prompt_row.add_child(_prompt_label)
	_prompt.visible = false
	_pin(root, _prompt, Control.PRESET_CENTER)
	_prompt.offset_top += 120.0
	_prompt.offset_bottom += 120.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _help_label != null:
		_refresh_texts()
	elif what == NOTIFICATION_PAUSED and _prompt != null:
		_prompt.visible = false   # the HUD stands still under a pausing menu


func hide_help() -> void:
	_help.visible = false


## Bottom edge (canvas units) of what stands in the top left corner right
## now: the night's plaque (night, clock, goal and help line), or the F1
## help over it (the world's row of artifacts goes under it).
func top_left_bottom() -> float:
	var bottom := 0.0
	for block: Control in [_night_plate, _help]:
		if block != null and block.is_visible_in_tree():
			bottom = maxf(bottom, block.position.y + block.get_combined_minimum_size().y)
	return bottom


## Bottom edge (canvas units) of the top middle's stack right now: the
## boss's block, the toast, the room's card (0 when none shows). A
## discovery's banner goes under it (WorldHud.top_source).
func top_middle_bottom() -> float:
	var bottom := 0.0
	if _boss_box.visible:
		bottom = _boss_row.offset_top + _height(_boss_box)
	if _toast_plate.visible:
		bottom = maxf(bottom, _toast_plate.offset_top + _height(_toast_plate))
	if _room_card != null and _room_card.visible:
		bottom = maxf(bottom, _room_card.offset_top + _height(_room_card))
	return bottom


## How far above the screen's bottom edge the hint strip reaches while it
## shows (0 when none): the subtitles keep above it.
func hint_clearance() -> float:
	if _hint_left <= 0.0:
		return 0.0
	return HINT_BOTTOM + _height(_hint)


## A piece's height as laid out (or as its content asks, before layout).
static func _height(control: Control) -> float:
	return maxf(control.size.y, control.get_combined_minimum_size().y)


## A short line at the top (e.g. "Game saved") that fades away.
func show_toast(text: String) -> void:
	_set_toast(text, TOAST_COLOR, UiTheme.BRASS, TOAST_TIME)


## The same line in red, a little longer (e.g. "The game could not be saved").
func show_warning(text: String) -> void:
	_set_toast(text, UiTheme.DANGER, UiTheme.EMERGENCY, WARNING_TIME)


func _set_toast(text: String, color: Color, rim: Color, seconds: float) -> void:
	_toast.label_settings.font_color = color
	(_toast_plate.get_theme_stylebox(&"panel") as PlaqueStyle).rim = Color(rim, 0.9)
	_toast_plate.queue_redraw()
	_toast.text = text.to_upper()
	_toast_left = seconds
	_toast_plate.visible = true
	_center_x(_toast_plate)


## The night's card: a big [param title] with an optional
## [param subtitle] (accent colour) and [param detail] line; it fades in,
## stays a few seconds and fades out.
func show_card(title: String, subtitle: String = "", detail: String = "") -> void:
	_card_title.text = title.to_upper()
	_card_subtitle.text = subtitle.to_upper()
	_card_subtitle.visible = subtitle != ""
	_card_detail.text = detail
	_card_detail.visible = detail != ""
	_card_time = 0.0
	_center_x(_card)


## The night's clock next to its number ("" hides it).
func set_clock(text: String) -> void:
	_clock_label.text = text
	_clock_label.visible = text != ""


func clock_text() -> String:
	return _clock_label.text if _clock_label.visible else ""


## The night's goal under the night number ("" hides it).
func set_objective(text: String) -> void:
	_objective_label.text = text
	_objective_row.visible = text != ""


func objective_text() -> String:
	return _objective_label.text if _objective_row.visible else ""


## The fuse icons beside the goal: [param carried] in the pocket,
## [param inserted] in the box; hidden when [param shown] is false.
func set_fuses(carried: int, inserted: int, shown: bool = true) -> void:
	_fuse_icons.visible = shown
	_fuse_icons.set_counts(carried, inserted)


## [carried, inserted] as the icons show them (-1s when hidden).
func fuse_counts() -> Array[int]:
	if not _fuse_icons.visible:
		return [-1, -1]
	return [_fuse_icons.carried, _fuse_icons.inserted]


## True while the boss's bar is up.
func boss_bar_shown() -> bool:
	return _boss_box.visible and _boss_box.modulate.a > 0.0


## The bar's fill (0-1).
func boss_fraction() -> float:
	return _boss_bar.value


## The bar goes to [param boss]; only the boss that owns it moves it
## (health), empties it (defeated) or takes it away (calmed).
func _on_boss_awakened(boss: Node) -> void:
	_release_boss()
	_boss = boss
	_boss_name.text = tr("HUD_BOSS_NAME").to_upper()
	var health: Health = boss.get(&"health")
	_boss_bar.trail = false   # a new owner's bar starts where its health stands
	if health != null:
		_boss_bar.value = health.fraction()
		health.changed.connect(_on_boss_health)
	_boss_bar.trail = true
	if boss.has_signal(&"defeated"):
		boss.connect(&"defeated", _on_boss_defeated)
	if boss.has_signal(&"calmed"):
		boss.connect(&"calmed", _on_guardian_calmed)
	_boss_fade = 0.0
	_boss_box.modulate.a = 1.0
	_boss_box.visible = true


## The bar's last owner (if it still stands) no longer moves it.
func _release_boss() -> void:
	if not is_instance_valid(_boss):
		return
	var health: Health = _boss.get(&"health")
	if health != null and health.changed.is_connected(_on_boss_health):
		health.changed.disconnect(_on_boss_health)
	if _boss.has_signal(&"defeated") and _boss.is_connected(&"defeated", _on_boss_defeated):
		_boss.disconnect(&"defeated", _on_boss_defeated)
	if _boss.has_signal(&"calmed") and _boss.is_connected(&"calmed", _on_guardian_calmed):
		_boss.disconnect(&"calmed", _on_guardian_calmed)
	_boss = null


func _on_boss_health(current: float, maximum: float) -> void:
	_boss_bar.value = current / maximum if maximum > 0.0 else 0.0


func _on_boss_defeated() -> void:
	_boss_bar.value = 0.0
	_boss_fade = 2.0   # the empty bar lingers a moment, then fades


func _update_boss(delta: float) -> void:
	if _boss_fade <= 0.0:
		return
	_boss_fade = maxf(_boss_fade - delta, 0.0)
	_boss_box.modulate.a = clampf(_boss_fade, 0.0, 1.0)
	if _boss_fade <= 0.0:
		_boss_box.visible = false


## Shares the top edge between the night's plaque and the boss's block:
## the block (its name wraps at BOSS_BLOCK_SHARE of the canvas) is sized
## first, then the goal wraps in what is left of the left half beside it
## (the whole left half while no bar is up), less the plaque's margins.
func _fit_top_edge() -> void:
	var canvas := get_viewport().get_visible_rect().size.x
	var block := canvas * BOSS_BLOCK_SHARE
	_boss_bar.custom_minimum_size.x = minf(BOSS_BAR_WIDTH, block)
	var name_plate := _boss_plate.get_theme_stylebox(&"panel")
	_wrap_to(_boss_name, block - name_plate.content_margin_left - name_plate.content_margin_right)
	var centre := _boss_box.get_combined_minimum_size().x if _boss_box.visible else 0.0
	var plate := _night_plate.get_theme_stylebox(&"panel")
	var room := (canvas - centre) * 0.5 - TOP_GAP - _night_plate.offset_left - plate.content_margin_left - plate.content_margin_right
	if _fuse_icons.visible:
		room -= _fuse_icons.get_combined_minimum_size().x + _objective_row.get_theme_constant(&"separation")
	_wrap_to(_objective_label, maxf(room, GOAL_MIN_WIDTH))


## The centred pieces at their own widths again (a text set this frame
## changes a plaque's minimum size only once its container has sorted).
func _recenter() -> void:
	for piece: Control in [_toast_plate, _prompt, _card]:
		if piece.visible:
			_center_x(piece)
	if _hint_left > 0.0:
		_place_hint()
	if _room_card != null and _room_card.visible:
		_center_x(_room_card)


## The top middle, top down: the boss's block, the toast under it, the
## room's card under both; each glides to its place (no jumps when one goes).
func _stack_top_middle(delta: float) -> void:
	var y := BOSS_TOP
	if _boss_box.visible:
		y += _height(_boss_box) + STACK_GAP
	var toast_top := maxf(TOAST_TOP, y)
	_glide_top(_toast_plate, toast_top, delta)
	if _toast_plate.visible:
		y = maxf(y, toast_top + _height(_toast_plate) + STACK_GAP)
	if _room_card != null:
		_glide_top(_room_card, maxf(ROOM_TOP, y), delta)


## Moves [param control] (pinned to the top) towards [param top]: at once
## while hidden, smoothly while it shows.
static func _glide_top(control: Control, top: float, delta: float) -> void:
	var height := control.offset_bottom - control.offset_top
	var at := top if not control.visible or control.modulate.a <= 0.01 else lerpf(control.offset_top, top, clampf(delta * 12.0, 0.0, 1.0))
	control.offset_top = at
	control.offset_bottom = at + height


## A hint or a note under the crosshair, for [param seconds] (fades out).
func show_hint(text: String, seconds: float = HINT_TIME) -> void:
	_hint_label.text = text
	# long notes wrap instead of running off the screen
	_hint_label.custom_minimum_size.x = clampf(text.length() * 11.5, 420.0, 1000.0)
	_hint_left = seconds
	_place_hint()


## The hint strip centred, its bottom edge HINT_BOTTOM above the screen's.
func _place_hint() -> void:
	_center_x(_hint)
	var height := _hint.get_combined_minimum_size().y
	if _hint.offset_bottom != -HINT_BOTTOM or not is_equal_approx(_hint.offset_top, -HINT_BOTTOM - height):
		_hint.offset_bottom = -HINT_BOTTOM
		_hint.offset_top = -HINT_BOTTOM - height


## The hint line while it shows ("" when gone).
func hint_text() -> String:
	return _hint_label.text if _hint_left > 0.0 else ""


func _update_hint(delta: float) -> void:
	_hint_left = maxf(_hint_left - delta, 0.0)
	_hint.modulate.a = clampf(_hint_left / 0.6, 0.0, 1.0)


## The card's lines while it shows ("" when gone), joined by " | ".
func card_text() -> String:
	if _card_time >= CARD_TIME:
		return ""
	var lines: PackedStringArray = [_card_title.text]
	if _card_subtitle.visible:
		lines.append(_card_subtitle.text)
	if _card_detail.visible:
		lines.append(_card_detail.text)
	return " | ".join(lines)


func _update_card(delta: float) -> void:
	if _card_time >= CARD_TIME:
		_card.modulate.a = 0.0
		_card_shade.modulate.a = 0.0
		return
	_card_time += delta
	var fade_in := clampf(_card_time / CARD_FADE_IN, 0.0, 1.0)
	var fade_out := clampf((CARD_TIME - _card_time) / CARD_FADE_OUT, 0.0, 1.0)
	_card.modulate.a = minf(fade_in, fade_out)
	_card_shade.modulate.a = _card.modulate.a
	# centred CARD_RISE above the middle, under a discovery's banner if one is up
	var screen := get_viewport().get_visible_rect().size
	var height := _card.get_combined_minimum_size().y
	var top := screen.y * 0.5 - CARD_RISE - height * 0.5
	if below_source.is_valid():
		var banner := float(below_source.call())
		if banner > 0.0:
			top = maxf(top, banner + CARD_GAP)
	_card.offset_top = top - screen.y * 0.5
	_card.offset_bottom = _card.offset_top + height
	var width := _card.get_combined_minimum_size().x
	_card_shade.position = Vector2((screen.x - width) * 0.5 - 140.0, top - 50.0)
	_card_shade.size = Vector2(width + 280.0, height + 100.0)


## The text of the top line while it shows ("" when gone).
func toast_text() -> String:
	return _toast.text if _toast_left > 0.0 else ""


## Fixed texts, again whenever the language changes.
func _refresh_texts() -> void:
	_death_label.text = tr("HUD_GUARD_DOWN")
	_night_label.text = (tr("HUD_NIGHT") % night).to_upper()
	_help_hint.text = tr("HUD_HELP_HINT") % GameInput.key_label(&"toggle_help")
	var paragraphs: PackedStringArray = []
	for key in help_keys:
		paragraphs.append(tr(key))
	_help_label.text = "\n\n".join(paragraphs)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_help"):
		_help.visible = not _help.visible


func _process(delta: float) -> void:
	_vignette.modulate.a = move_toward(_vignette.modulate.a, 0.0, 1.5 * delta)
	_fps_label.visible = always_show_fps or Settings.data.show_fps
	_fps_label.text = tr("HUD_FPS") % Engine.get_frames_per_second()
	_update_dust(delta)
	_update_toast(delta)
	_update_card(delta)
	_update_hint(delta)
	_update_boss(delta)
	_fit_top_edge()
	_stack_top_middle(delta)
	_recenter()
	var night_shown := night > 0 and not _help.visible
	_night_plate.visible = night_shown
	_night_box.visible = night_shown
	if not is_instance_valid(player):
		return
	_health_label.text = "%d" % ceili(player.health.current)
	_health_bar.value = player.health.fraction()
	_stamina_bar.show_state(player.stamina.fraction(), player.stamina.cap_fraction(), player.stamina.exhausted, player.fatigue.caffeinated(), delta)
	_update_states(delta)
	_update_fatigue(delta, player.fatigue.effect())
	_torch_bar.value = player.battery.fraction()
	var blink := player.battery.is_low() and fmod(Time.get_ticks_msec() / 1000.0, 0.6) < 0.3
	_torch_bar.modulate = Color(1.0, 0.35, 0.3) if blink else Color.WHITE
	_torch_icon.modulate = _torch_bar.modulate
	_death_label.visible = not player.alive
	_update_prompt()
	var state := player.weapons.current_state()
	_update_slots(state)
	_weapon_label.visible = state != null
	_ammo_label.visible = false
	_battery_bar.visible = false
	if state != null:
		_weapon_label.text = tr(state.data.display_name).to_upper()
		if state.data.volley_count > 1:
			_weapon_label.text += "  ·  " + tr("HUD_VOLLEY") % state.data.volley_count
		if state.has_alt():
			_weapon_label.text += "  ·  " + tr("HUD_AMMO_SLUG" if state.use_alt else "HUD_AMMO_BUCKSHOT")
		match state.data.ammo_mode:
			WeaponData.AmmoMode.MAGAZINE:
				_ammo_label.visible = true
				_ammo_label.text = tr("HUD_RELOADING") if state.is_reloading() else "%d | %d" % [state.magazine, state.reserve]
			WeaponData.AmmoMode.BATTERY:
				_battery_bar.visible = true
				_battery_bar.value = state.battery / state.data.battery_max
	_ammo_row.visible = _ammo_label.visible
	_reloading_size()


## The reloading word is smaller than the figures it stands in for.
func _reloading_size() -> void:
	var size := 26 if _ammo_label.text == tr("HUD_RELOADING") else 46
	if _ammo_label.label_settings.font_size != size:
		_ammo_label.label_settings.font_size = size
		_ammo_label.label_settings.font = UiTheme.spaced_font(3) if size == 26 else UiTheme.number_font()


## The state icons beside the health number: the cup while the caffeine
## lasts (pulsing with the cream fill), the drooping eye while fatigue
## eats the stamina bar.
func _update_states(delta: float) -> void:
	var cup := 0.0
	if _stamina_bar.caffeine > 0.0:
		cup = _stamina_bar.caffeine * (0.75 + 0.25 * sin(_stamina_bar._pulse * 2.4))
	_caffeine_icon.modulate.a = cup
	var tired := 1.0 if _stamina_bar.tired_fraction() > 0.01 else 0.0
	_tired_icon.modulate.a = move_toward(_tired_icon.modulate.a, tired, delta * 2.0)


## The slot numbers: weapons found lit, the one in hand in its weapon's own
## colour (WeaponPalette: the colour its ammo boxes wear on the floor) with
## a bar of that colour under it, the rest faint.
func _update_slots(current: WeaponState) -> void:
	var before := _slot_in_hand
	_slot_in_hand = -1
	for i in _slot_labels.size():
		var id: StringName = WeaponHolder.SLOT_ORDER[i]
		var color := SLOT_EMPTY
		if current != null and current.data.id == id:
			color = WeaponPalette.color(id)
			_slot_in_hand = i
		elif player.weapons.has_weapon(id):
			color = SLOT_OWNED
		_slot_labels[i].label_settings.font_color = color
	if before != _slot_in_hand:
		_slots.queue_redraw()


## The bar under the slot in hand, in its weapon's colour.
func _draw_slot_mark() -> void:
	if _slot_in_hand < 0 or _slot_in_hand >= _slot_labels.size():
		return
	var slot := _slot_labels[_slot_in_hand]
	var rect := slot.get_rect()
	var color := slot.label_settings.font_color
	var bar := Rect2(rect.position.x - 2.0, rect.end.y - 1.0, rect.size.x + 4.0, 3.0)
	_slots.draw_rect(bar.grow(1.0), Color(0.0, 0.0, 0.0, 0.6))
	_slots.draw_rect(bar, color)


## The slot numbers as shown: "1" lit, "(2)" faint, "[3]" in hand.
func slots_text() -> String:
	var out := PackedStringArray()
	for i in _slot_labels.size():
		var color := _slot_labels[i].label_settings.font_color
		if i == _slot_in_hand:
			out.append("[%d]" % (i + 1))
		elif color == SLOT_OWNED:
			out.append(str(i + 1))
		else:
			out.append("(%d)" % (i + 1))
	return " ".join(out)


func _on_hint_requested(text: String) -> void:
	show_hint(text, WORLD_HINT_TIME)


func _update_toast(delta: float) -> void:
	_toast_left = maxf(_toast_left - delta, 0.0)
	_toast_plate.modulate.a = clampf(_toast_left / 0.6, 0.0, 1.0)
	if _toast_left <= 0.0 and _toast_plate.visible:
		_toast_plate.visible = false


func _update_dust(delta: float) -> void:
	_dust_box.visible = show_dust
	_gain_left = maxf(_gain_left - delta, 0.0)
	_dust_gain.modulate.a = clampf(_gain_left / (GAIN_TIME * 0.5), 0.0, 1.0)
	if _gain_left <= 0.0:
		_gain_amount = 0
	_bump = move_toward(_bump, 0.0, 3.0 * delta)
	_dust_row.pivot_offset = Vector2(_dust_row.size.x, _dust_row.size.y * 0.5)
	_dust_row.scale = Vector2.ONE * (1.0 + 0.25 * _bump * _bump)


func _on_dust_changed(total: int, change: int) -> void:
	_dust_label.text = str(total)
	if change <= 0:
		return
	# gains close together add up into one "+n"
	_gain_amount += change
	_gain_left = GAIN_TIME
	_dust_gain.text = "+%d" % _gain_amount
	_bump = 1.0


## "[E] Use the terminal" under the crosshair while something usable is in focus.
func _update_prompt() -> void:
	var focus := player.interactor.focus
	var shown := player.alive and is_instance_valid(focus) and GameInput.top_ui() == null
	if shown:
		var key := GameInput.key_label(&"interact")
		var action := focus.prompt()
		if key != _prompt_key.text or action != _prompt_label.text or not _prompt.visible:
			_prompt_key.text = key
			_prompt_label.text = action
			_center_x(_prompt)
	_prompt.visible = shown


func _on_player_damaged(amount: float, _from: Vector3) -> void:
	_vignette.modulate.a = clampf(0.35 + amount / 40.0, 0.0, 0.9)


func _on_hit_landed(_target: Node, info: DamageInfo, killed: bool) -> void:
	if not is_instance_valid(player) or info == null or info.source != player:
		return
	var color := HIT_COLOR
	if info.blocked:
		color = BLOCKED_COLOR
	elif killed:
		color = KILL_COLOR
	elif info.weak_point:
		color = WEAK_POINT_COLOR
	_crosshair.show_marker(color)
	Sfx.play(&"kill" if killed else &"hit_marker", -8.0)


## A HUD label: [param font] (the semibold serif by default) at
## [param font_size] in [param color], with a soft dark shadow under the
## letters (an engraving's depth; the plaques give the contrast).
static func _label(font_size: int, color: Color = Color.WHITE, font: Font = null) -> Label:
	var settings := LabelSettings.new()
	settings.font = font if font != null else UiTheme.strong_font()
	settings.font_size = font_size
	settings.font_color = color
	settings.outline_size = 0
	settings.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
	settings.shadow_offset = Vector2(1.0, 2.0)
	settings.shadow_size = 1
	var label := Label.new()
	label.label_settings = settings
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## [param label] on one line, or wrapped at [param width] when its text is
## wider than that.
static func _wrap_to(label: Label, width: float) -> void:
	var settings := label.label_settings
	var natural := settings.font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, settings.font_size).x
	var wrap := natural > width
	var mode := TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	var least := width if wrap else 0.0
	if label.autowrap_mode != mode:
		label.autowrap_mode = mode
	if label.custom_minimum_size.x != least:
		label.custom_minimum_size.x = least


## Centres [param control] (anchored to the middle of the screen's width) at
## its own minimum width: it neither grows to one side nor keeps an old,
## wider text's width.
static func _center_x(control: Control) -> void:
	var width := control.get_combined_minimum_size().x
	if control.offset_left != -width * 0.5 or control.offset_right != width * 0.5:
		control.offset_left = -width * 0.5
		control.offset_right = width * 0.5


## Adds [param node] to [param root] anchored to a screen corner or centre.
static func _pin(root: Control, node: Control, preset: Control.LayoutPreset) -> void:
	root.add_child(node)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, int(MARGIN))
	match preset:
		Control.PRESET_BOTTOM_LEFT:
			node.grow_vertical = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_BOTTOM_RIGHT:
			node.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			node.grow_vertical = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_TOP_RIGHT:
			node.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER_TOP:
			node.grow_horizontal = Control.GROW_DIRECTION_BOTH
		Control.PRESET_CENTER_BOTTOM:
			node.grow_horizontal = Control.GROW_DIRECTION_BOTH
			node.grow_vertical = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER:
			node.grow_horizontal = Control.GROW_DIRECTION_BOTH
			node.grow_vertical = Control.GROW_DIRECTION_BOTH


## Fatigue's cues: the cool shade follows the effect; past BLINK_FROM the
## lids close for BLINK_TIME every so often (sooner the more tired).
func _update_fatigue(delta: float, effect: float) -> void:
	_tired_vignette.modulate.a = FATIGUE_VIGNETTE * effect
	var period := lerpf(BLINK_PERIOD_MAX, BLINK_PERIOD_MIN, effect)
	if _blink_phase > 0.0:
		_blink_phase += delta / BLINK_TIME
		if _blink_phase >= 1.0:
			_blink_phase = 0.0
	elif effect >= BLINK_FROM:
		_blink_wait -= delta
		if _blink_wait <= 0.0:
			_blink_phase = 0.001
			_blink_wait = period
	else:
		_blink_wait = period   # the first blink comes a whole period after the threshold
	var closed := sin(_blink_phase * PI) if _blink_phase > 0.0 else 0.0
	_lid_top.modulate.a = closed
	_lid_bottom.modulate.a = closed


## The fatigue vignette's alpha (0 fresh, FATIGUE_VIGNETTE at the worst).
func fatigue_shade() -> float:
	return _tired_vignette.modulate.a


## 0 between blinks, running 0..1 through one.
func blink_phase() -> float:
	return _blink_phase


## One eyelid: a black band along the top or bottom edge, invisible until a blink.
static func _lid(root: Control, top: bool) -> ColorRect:
	var lid := ColorRect.new()
	lid.color = Color(0.0, 0.0, 0.0, 0.92)
	lid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lid.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
	lid.anchor_top = 0.0 if top else 1.0 - LID_SHARE
	lid.anchor_bottom = LID_SHARE if top else 1.0
	lid.offset_top = 0.0
	lid.offset_bottom = 0.0
	lid.modulate = Color(1.0, 1.0, 1.0, 0.0)
	root.add_child(lid)
	return lid


## A radial shade round the edges in [param color], clear inside [param inner].
static func _make_vignette(color: Color = Color(0.6, 0.0, 0.0), inner: float = 0.55) -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([inner, 1.0])
	gradient.colors = PackedColorArray([Color(color, 0.0), Color(color, 1.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	return rect


# --- Floor I ---------------------------------------------------------------

## A room's name on its first visit: a plaque with a band in its wing's
## colour, the room's name and, smaller, the wing's; it fades in sliding a
## little to the right, stays, fades out.
class RoomCard extends PanelContainer:
	const TIME := 4.0
	const FADE_IN := 0.4
	const FADE_OUT := 1.0
	const SLIDE := 10.0
	var title: Label
	var zone: Label
	var time: float = INF
	var _style: PlaqueStyle
	var _lines: VBoxContainer

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_style = UiTheme.plaque(UiTheme.Plaque.HUD)
		_style.band_width = 7.0
		_style.content_margin_left = 30.0
		_style.content_margin_right = 28.0
		_style.content_margin_top = 10.0
		_style.content_margin_bottom = 11.0
		add_theme_stylebox_override("panel", _style)
		_lines = VBoxContainer.new()
		_lines.add_theme_constant_override("separation", 2)
		add_child(_lines)
		title = Hud._label(28, UiTheme.TEXT, UiTheme.spaced_font(4))
		_lines.add_child(title)
		zone = Hud._label(Hud.MIN_TEXT, Color(UiTheme.TEXT, 0.72), UiTheme.spaced_font(3))
		_lines.add_child(zone)
		modulate.a = 0.0
		visible = false

	func show_room(room_name: String, zone_name: String, color: Color) -> void:
		title.text = room_name.to_upper()
		zone.text = zone_name.to_upper()
		zone.visible = zone_name != "" and zone_name != room_name
		_style.band = color
		zone.label_settings.font_color = Color(color.lerp(UiTheme.TEXT, 0.45), 0.9)
		time = 0.0
		visible = true
		Hud._center_x(self)
		queue_redraw()

	## The band's colour (the wing's).
	func band_color() -> Color:
		return _style.band

	func shown_text() -> String:
		if time >= TIME:
			return ""
		return title.text + (" | " + zone.text if zone.visible else "")

	func _process(delta: float) -> void:
		if time >= TIME:
			modulate.a = 0.0
			if visible:
				visible = false
			return
		time += delta
		modulate.a = minf(clampf(time / FADE_IN, 0.0, 1.0), clampf((TIME - time) / FADE_OUT, 0.0, 1.0))
		var slide := 1.0 - pow(1.0 - clampf(time / FADE_IN, 0.0, 1.0), 3.0)
		_lines.position.x = get_theme_stylebox(&"panel").content_margin_left - SLIDE * (1.0 - slide)


## Builds the Floor I parts (once): the room card, the shard line under the
## goal, the guardians' bar.
func enable_floor() -> void:
	if _room_card != null:
		return
	var root := _night_plate.get_parent() as Control
	_room_card = RoomCard.new()
	_room_card.name = "RoomCard"
	_pin(root, _room_card, Control.PRESET_CENTER_TOP)
	_room_card.offset_top = ROOM_TOP
	_room_card.offset_bottom = ROOM_TOP
	_shards_label = _label(22, UiTheme.DANGER, UiTheme.body_font())
	_shards_label.visible = false
	_night_box.add_child(_shards_label)
	_night_box.move_child(_shards_label, _objective_row.get_index() + 1)
	Events.guardian_awakened.connect(_on_guardian_awakened)


## The card of a room entered for the first time.
func show_room_card(room_name: String, zone_name: String, color: Color) -> void:
	if _room_card == null:
		enable_floor()
	_room_card.show_room(room_name, zone_name, color)


## The card's lines while it shows ("" when gone), joined by " | ".
func room_card_text() -> String:
	return _room_card.shown_text() if _room_card != null else ""


## "Shards: 3/6" under the goal ([param count] <= 0 hides it).
func set_shards(count: int, total: int) -> void:
	if _shards_label == null:
		enable_floor()
	_shards_label.text = (tr("GOAL_SHARDS") % [count, total]) if count > 0 else ""
	_shards_label.visible = count > 0


func shards_text() -> String:
	return _shards_label.text if _shards_label != null and _shards_label.visible else ""


## The boss bar's title line while it shows ("" when gone).
func boss_name_text() -> String:
	return _boss_name.text if boss_bar_shown() else ""


## A wing guardian woke: its bar with "NAME — TITLE" (the T-Rex keeps
## Events.boss_awakened); it fades when the guardian falls or calms down.
func _on_guardian_awakened(guardian: Node, _guardian_id: StringName) -> void:
	_on_boss_awakened(guardian)
	var title := String(guardian.call(&"title")) if guardian.has_method(&"title") else ""
	var shown := String(guardian.call(&"display_name")) if guardian.has_method(&"display_name") else ""
	_boss_name.text = (shown + ("  —  " + title if title != "" else "")).to_upper()


## The guard fled the arena: the guardian that owns the bar is back on its
## post, the bar goes.
func _on_guardian_calmed() -> void:
	_boss_fade = 0.6
