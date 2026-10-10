class_name SecondWindFx
extends CanvasLayer
## The second wind: for a moment the world loses its colour and darkens at
## the edges in time with a heartbeat, then colour comes back. Drawn under
## the HUD (layer 5), it removes itself when done and pauses with the game.

const HOLD := 1.0
const FADE := 1.4
const BEAT := 1.18   # heartbeats a second

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 washed = mix(c, vec3(grey), amount * 0.92);
	float edge = smoothstep(0.3, 0.95, length(SCREEN_UV - vec2(0.5)) * 1.45);
	washed *= 1.0 - edge * (0.45 + 0.3 * pulse) * amount;
	washed += vec3(0.22, 0.0, 0.0) * edge * pulse * amount;
	COLOR = vec4(washed, 1.0);
}
"""

static var _shader: Shader = null

var _material: ShaderMaterial
var _time: float = 0.0


## Starts the effect under [param parent] (the guard).
static func play(parent: Node) -> SecondWindFx:
	var fx := SecondWindFx.new()
	parent.add_child(fx)
	return fx


## 1 while the world is grey, fading to 0.
func amount() -> float:
	return 1.0 if _time < HOLD else clampf(1.0 - (_time - HOLD) / FADE, 0.0, 1.0)


func _ready() -> void:
	layer = 5
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = _shader
	var rect := ColorRect.new()
	rect.material = _material
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	_update()


func _process(delta: float) -> void:
	_time += delta
	if _time >= HOLD + FADE:
		queue_free()
		return
	_update()


func _update() -> void:
	var beat := fmod(_time * BEAT, 1.0)
	var pulse := exp(-beat * 9.0) + 0.6 * exp(-absf(beat - 0.22) * 14.0)
	_material.set_shader_parameter(&"amount", amount())
	_material.set_shader_parameter(&"pulse", clampf(pulse, 0.0, 1.0))
