shader_type spatial;
// The curator's monocle: a warm glowing rim around an exhibit's weak point.
// Added on top of the scene (no depth writes) but depth-tested, so it never
// shows through walls - only the rim of the weak point's shell glows.
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 glow : source_color = vec4(1.0, 0.74, 0.28, 1.0);
uniform float strength = 1.7;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
	float pulse = 0.72 + 0.28 * sin(TIME * 4.5);
	ALBEDO = glow.rgb * (0.05 + rim) * strength * pulse;
}
