shader_type canvas_item;
// The camera console's full-screen picture: the monitor look of
// cctv_screen.gdshader for a flat TextureRect, plus a burst of snow while
// the channel switches (switch_static 1 -> 0).

uniform float switch_static : hint_range(0.0, 1.0) = 0.0;
uniform float brightness = 1.25;
uniform vec3 tint : source_color = vec3(0.82, 1.0, 0.94);
uniform float colour_kept : hint_range(0.0, 1.0) = 0.3;
uniform float lines = 360.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 centred = UV - 0.5;
	vec2 uv = 0.5 + centred * (1.0 + 0.05 * dot(centred, centred));
	float roll = fract(uv.y * 0.5 + TIME * 0.05);
	float band = smoothstep(0.0, 0.06, roll) * smoothstep(0.12, 0.06, roll);
	uv.x += band * 0.003 * sin(uv.y * 1200.0 + TIME * 50.0);
	uv.x += switch_static * 0.02 * sin(uv.y * 80.0 + TIME * 90.0);
	vec3 colour = texture(TEXTURE, uv).rgb;
	float luma = dot(colour, vec3(0.299, 0.587, 0.114));
	vec3 picture = mix(vec3(luma), colour, colour_kept) * tint;
	float grain = hash(floor(uv * vec2(640.0, 480.0)) + vec2(floor(TIME * 30.0) * 1.37, 0.0));
	float scan = 0.84 + 0.16 * sin(uv.y * lines * 3.14159);
	picture = picture * scan * brightness * (1.0 + band * 0.2) + (grain - 0.5) * 0.06;
	vec3 snow = vec3(grain * 0.7 + 0.04);
	vec3 result = mix(picture, snow, switch_static);
	float corners = smoothstep(0.8, 0.35, length(centred * vec2(1.0, 1.15)));
	bool outside = uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0;
	COLOR = vec4(outside ? vec3(0.0) : result * (0.4 + 0.6 * corners), 1.0);
}
