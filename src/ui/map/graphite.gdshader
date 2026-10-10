// The guard's pencil on the paper map: graphite catches on the paper's
// tooth, so every line and letter of the pencil layer is broken up by a
// fine grain fixed to the sheet (it scales with the zoom, like the paper).
shader_type canvas_item;

uniform sampler2D grain : repeat_enable, filter_linear_mipmap;
// Sheet pixels per tile of the grain texture.
uniform float tile = 256.0;
// How much of a stroke survives where the tooth is lowest.
uniform float floor_alpha = 0.42;

varying vec2 sheet_position;

void vertex() {
	sheet_position = VERTEX;
}

void fragment() {
	float tooth = texture(grain, sheet_position / tile).r;
	COLOR.a *= mix(floor_alpha, 1.0, tooth);
}
