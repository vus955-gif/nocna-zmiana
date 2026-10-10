shader_type spatial;
// A CRT security monitor showing a camera feed: washed-out phosphor
// colour, scanlines, grain, a slow rolling interference band, a slight
// bulge and dark corners. Without a signal (signal_strength 0) it shows
// snow. Unshaded: the screen is its own light.
render_mode unshaded, cull_back, shadows_disabled;

uniform sampler2D feed : source_color, filter_linear, repeat_disable;
uniform float signal_strength : hint_range(0.0, 1.0) = 1.0;
uniform float brightness = 1.35;
uniform vec3 tint : source_color = vec3(0.8, 1.0, 0.93);
uniform float colour_kept : hint_range(0.0, 1.0) = 0.3;
uniform float seed = 0.0;
uniform float lines = 240.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 centred = UV - 0.5;
	vec2 uv = 0.5 + centred * (1.0 + 0.08 * dot(centred, centred));
	// the band: a soft brighter stripe drifting up, nudging lines sideways
	float roll = fract(uv.y * 0.6 + TIME * 0.07 + seed);
	float band = smoothstep(0.0, 0.08, roll) * smoothstep(0.16, 0.08, roll);
	uv.x += band * 0.004 * sin(uv.y * 900.0 + TIME * 40.0);
	vec3 colour = texture(feed, uv).rgb;
	float luma = dot(colour, vec3(0.299, 0.587, 0.114));
	vec3 picture = mix(vec3(luma), colour, colour_kept) * tint;
	float grain = hash(floor(uv * vec2(320.0, 240.0)) + vec2(floor(TIME * 24.0) * 1.37 + seed, 0.0));
	float scan = 0.8 + 0.2 * sin(uv.y * lines * 3.14159);
	picture = picture * scan * brightness * (1.0 + band * 0.25) + (grain - 0.5) * 0.07;
	vec3 snow = vec3(grain * 0.6 + 0.05);
	vec3 result = mix(snow, picture, signal_strength);
	float corners = smoothstep(0.78, 0.3, length(centred * vec2(1.0, 1.1)));
	bool outside = uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0;
	ALBEDO = outside ? vec3(0.0) : result * (0.35 + 0.65 * corners);
}
