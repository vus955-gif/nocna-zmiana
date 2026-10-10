// Night sky seen through the gallery windows: deep blue gradient, a bright
// moon with a halo in the direction of the first DirectionalLight3D, crisp
// pixel stars (one texel-sized point per sky cell) and thin cloud streaks.
shader_type sky;

uniform vec3 zenith : source_color = vec3(0.012, 0.018, 0.045);
uniform vec3 horizon : source_color = vec3(0.06, 0.08, 0.15);
uniform vec3 ground : source_color = vec3(0.015, 0.016, 0.02);
uniform vec3 moon_color : source_color = vec3(0.8, 0.86, 1.0);
uniform float star_cells = 260.0;
uniform float star_chance = 0.02;

float hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(vec3(i, 1.0));
	float b = hash(vec3(i + vec2(1.0, 0.0), 1.0));
	float c = hash(vec3(i + vec2(0.0, 1.0), 1.0));
	float d = hash(vec3(i + vec2(1.0, 1.0), 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon, zenith, pow(clamp(h, 0.0, 1.0), 0.45));
	col = mix(col, ground, smoothstep(0.0, -0.08, h));
	float m = LIGHT0_ENABLED ? max(dot(d, LIGHT0_DIRECTION), 0.0) : 0.0;
	col += moon_color * (pow(m, 12.0) * 0.12 + pow(m, 90.0) * 0.35);
	// thin cloud streaks lit from the moon side
	vec2 cp = d.xz / max(h + 0.25, 0.05) * vec2(1.2, 3.0);
	float cl = smoothstep(0.55, 0.85, noise(cp * 1.5) * 0.65 + noise(cp * 4.0) * 0.35) * smoothstep(0.02, 0.25, h);
	col = mix(col, horizon * 1.6 + moon_color * pow(m, 6.0) * 0.25, cl * 0.6);
	// pixel stars: a star lights only the centre of its sky cell, so it stays
	// one or two screen pixels wide at any window size
	vec3 sd = d * star_cells;
	vec3 cell = floor(sd);
	float r = hash(cell);
	if (r > 1.0 - star_chance && h > 0.04) {
		vec3 off = fract(sd) - 0.5;
		float core = step(length(off), 0.22);
		float tw = hash(cell + 7.0);
		col += vec3(0.75, 0.82, 1.0) * core * (0.25 + tw * tw * 1.4) * (1.0 - cl);
	}
	// the moon disc
	col = mix(col, moon_color * 6.0, smoothstep(0.99965, 0.9998, m));
	COLOR = col;
}
