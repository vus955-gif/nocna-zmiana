class_name SettingsData
extends RefCounted
## Every player option with its default and its valid range. Pure data: the
## Settings autoload applies it to the engine and stores it in settings.cfg.
## Values set through set_value() or read from a file are always sanitized,
## so a hand-edited or broken file can never put the game in a bad state.

enum WindowMode { WINDOWED, MAXIMIZED, FULLSCREEN, EXCLUSIVE }
enum Upscaler { BILINEAR, FSR, FSR2 }
## Accessibility (plan 2026-10-21-dostepnosc): the subtitle text size, and the
## colour-vision palette of the HUD and the pickups' rims (ColourVision).
enum SubtitleSize { SMALL, MEDIUM, LARGE }
enum ColourVisionMode { NORMAL, DEUTERANOPIA, PROTANOPIA, TRITANOPIA }

const FOV_MIN := 70.0
const FOV_MAX := 110.0
const SENSITIVITY_MIN := 0.1
const SENSITIVITY_MAX := 3.0
const RENDER_SCALE_MIN := 0.5
const RENDER_SCALE_MAX := 1.0
## The HUD's size (a share of its designed size, see Hud.apply_scale).
const HUD_SCALE_MIN := 0.75
const HUD_SCALE_MAX := 1.5
## Frame limits offered in the options (0 = no limit).
const FPS_CHOICES: Array[int] = [0, 30, 60, 120, 144, 165, 240]
const MAX_FPS_LIMIT := 1000
const LANGUAGES: Array[String] = ["pl", "en"]
## Volume setting -> the audio bus it drives.
const VOLUME_BUSES := {
	&"volume_master": &"Master",
	&"volume_sfx": &"SFX",
	&"volume_music": &"Music",
	&"volume_ambience": &"Ambience",
	&"volume_ui": &"UI",
	&"volume_voice": &"Voice",
}
const SECTION := "settings"

var mouse_sensitivity: float = 1.0
var invert_y: bool = false
## Vertical field of view of the guard's camera, in degrees.
var fov: float = 70.0
## Motion comfort (plan 2026-10-19-gun-feel), 0..1: screen shake (the
## shake itself, the weapons' kick of the view, a blast's push) and the
## view's head bob (walking bob, landing dip, the sprint's wider view).
var screen_shake: float = 1.0
var head_bob: float = 1.0
var volume_master: float = 1.0
var volume_sfx: float = 1.0
var volume_music: float = 1.0
var volume_ambience: float = 1.0
var volume_ui: float = 1.0
## The voice lines (Heniek's radio, the museum's System).
var volume_voice: float = 1.0
var window_mode: int = WindowMode.FULLSCREEN
var vsync: bool = true
var max_fps: int = 0
## Fraction of the window resolution the 3D view renders at.
var render_scale: float = 1.0
var upscaler: int = Upscaler.BILINEAR
var language: String = "pl"
var show_fps: bool = false
## Subtitles of the voice lines (the lines are English; Polish players read them).
var subtitles: bool = true
## Accessibility (plan 2026-10-21-dostepnosc). The HUD's size (0.75..1.5, 1.0
## as designed); the subtitles' text size and an optional dark band behind
## them (0 = none .. 1 = solid); flashing capped for photosensitive players
## (Flashing: lamps, muzzle light, hit flashes, the low-health pulse); the
## colour-blind palette of the HUD and the pickups' rims; sprint held (false)
## or switched on and off by its key (true).
var hud_scale: float = 1.0
var subtitle_size: int = SubtitleSize.MEDIUM
var subtitle_backing: float = 0.0
var reduce_flashing: bool = false
var colour_vision: int = ColourVisionMode.NORMAL
var sprint_toggle: bool = false
## The dev performance overlay (F3) in a build that is not a dev build.
var dev_tools: bool = false
## GraphicsQuality.Quality: Low, Medium, High, Ultra (the first start picks
## one for the machine, see GraphicsQuality.detect()).
var graphics_quality: int = GraphicsQuality.Quality.HIGH
## The player's keys and mouse buttons (own [bindings] section of the file;
## not one of keys(): the options menu edits it in its own panel).
var bindings := KeyBindings.new()


static func keys() -> Array[StringName]:
	return [
		&"mouse_sensitivity", &"invert_y", &"fov", &"screen_shake", &"head_bob",
		&"volume_master", &"volume_sfx", &"volume_music", &"volume_ambience", &"volume_voice", &"volume_ui",
		&"window_mode", &"vsync", &"max_fps", &"render_scale", &"upscaler",
		&"language", &"show_fps", &"subtitles", &"dev_tools", &"graphics_quality",
		&"hud_scale", &"subtitle_size", &"subtitle_backing", &"reduce_flashing", &"colour_vision", &"sprint_toggle",
	]


func get_value(key: StringName) -> Variant:
	return get(key) if keys().has(key) else null


## Sets one option. Returns false (and changes nothing) for an unknown key or
## a value of the wrong type; out-of-range values are clamped.
func set_value(key: StringName, value: Variant) -> bool:
	if not keys().has(key):
		return false
	var current: Variant = get(key)
	match typeof(current):
		TYPE_BOOL:
			if typeof(value) != TYPE_BOOL:
				return false
		TYPE_FLOAT, TYPE_INT:
			if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
				return false
			if typeof(value) == TYPE_FLOAT and not is_finite(value):
				return false   # NaN or infinity from a hand-edited file
			if typeof(current) == TYPE_INT:
				value = roundi(float(value))
			else:
				value = float(value)
		TYPE_STRING:
			if typeof(value) != TYPE_STRING and typeof(value) != TYPE_STRING_NAME:
				return false
			value = String(value)
	set(key, value)
	sanitize()
	return true


func sanitize() -> void:
	mouse_sensitivity = clampf(mouse_sensitivity, SENSITIVITY_MIN, SENSITIVITY_MAX)
	fov = clampf(fov, FOV_MIN, FOV_MAX)
	screen_shake = clampf(screen_shake, 0.0, 1.0)
	head_bob = clampf(head_bob, 0.0, 1.0)
	volume_master = clampf(volume_master, 0.0, 1.0)
	volume_sfx = clampf(volume_sfx, 0.0, 1.0)
	volume_music = clampf(volume_music, 0.0, 1.0)
	volume_ambience = clampf(volume_ambience, 0.0, 1.0)
	volume_ui = clampf(volume_ui, 0.0, 1.0)
	volume_voice = clampf(volume_voice, 0.0, 1.0)
	if window_mode < 0 or window_mode >= WindowMode.size():
		window_mode = WindowMode.FULLSCREEN
	max_fps = clampi(max_fps, 0, MAX_FPS_LIMIT)
	render_scale = clampf(snappedf(render_scale, 0.05), RENDER_SCALE_MIN, RENDER_SCALE_MAX)
	if upscaler < 0 or upscaler >= Upscaler.size():
		upscaler = Upscaler.BILINEAR
	if not LANGUAGES.has(language):
		language = LANGUAGES[0]
	graphics_quality = clampi(graphics_quality, 0, GraphicsQuality.Quality.size() - 1)
	hud_scale = clampf(snappedf(hud_scale, 0.05), HUD_SCALE_MIN, HUD_SCALE_MAX)
	if subtitle_size < 0 or subtitle_size >= SubtitleSize.size():
		subtitle_size = SubtitleSize.MEDIUM
	subtitle_backing = clampf(snappedf(subtitle_backing, 0.05), 0.0, 1.0)
	if colour_vision < 0 or colour_vision >= ColourVisionMode.size():
		colour_vision = ColourVisionMode.NORMAL


func to_config(config: ConfigFile) -> void:
	for key in keys():
		config.set_value(SECTION, key, get(key))
	bindings.to_config(config)


## Reads every known option from [param config]; missing or broken entries
## keep their current (default) value.
func from_config(config: ConfigFile) -> void:
	for key in keys():
		if config.has_section_key(SECTION, key):
			set_value(key, config.get_value(SECTION, key))
	bindings.from_config(config)
