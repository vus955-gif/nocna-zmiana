// Display-case / window glass. Almost clear face-on, reflective at grazing
// angles (Fresnel). Premultiplied alpha keeps reflections and highlights at
// full strength while the diffuse part fades with the (dust) opacity.
shader_type spatial;
render_mode blend_premul_alpha, depth_draw_never, cull_back, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(0.82, 0.93, 0.9);
uniform float clear_alpha = 0.04;
uniform float dust_alpha = 0.55;
uniform float fresnel_alpha = 0.5;

void fragment() {
	vec4 dust = texture(albedo_tex, UV);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 5.0);
	float a = clamp(clear_alpha + dust.a * dust_alpha + fresnel * fresnel_alpha, 0.0, 1.0);
	ALBEDO = tint * dust.rgb;
	ROUGHNESS = texture(orm_tex, UV).g;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = a;
	PREMUL_ALPHA_FACTOR = a;
}
