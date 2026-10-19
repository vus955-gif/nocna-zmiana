// Shared body of the exhibit shaders (exhibit, exhibit_wax, exhibit_debris).
// The same baked pixel textures as ArtLibrary's ORM materials (nearest
// texels, mipmaps, anisotropy; AO is already painted into the albedo), plus
// what an awakened exhibit needs to read in a dark museum:
// - awake: the glass eyes / visor / cracks (emission map) brighten and a
//   faint cool rim light traces the silhouette, but only from a few metres
//   away (up close the lamps and the flashlight do the work);
// - glow: the attack telegraph, a warm light from inside, strongest at the
//   edges and in the emission map;
// - flash: a short white flash when a hit lands.
// All three are per-instance uniforms: one material per texture set, every
// exhibit lights up on its own.

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D emit_tex : source_color, hint_default_black, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform float normal_scale = 1.0;
uniform float metallic_scale = 0.0;
uniform float emit_energy = 1.0;
uniform vec3 rim_color : source_color = vec3(0.55, 0.7, 1.0);
uniform float rim_strength = 0.3;
uniform float rim_power = 2.6;
// The rim fades in between these distances (m).
uniform vec2 rim_fade = vec2(2.5, 9.0);
// Read from afar (pickups; the light pass of 19.10): from far_fade.x on
// (full at far_fade.y) the rim grows by far_rim, the whole body takes on a
// faint glow of the rim's colour (far_body) and the emission map brightens
// by far_emit (the medkit's red cross) - a box of shells still reads as its
// colour at 15 m in a dark room, the medkit as a white box with a red
// cross; nearer nothing changes. Exhibits keep the defaults (never).
uniform vec2 far_fade = vec2(1000.0, 1001.0);
uniform float far_rim = 0.0;
uniform float far_body = 0.0;
uniform float far_emit = 0.0;
uniform vec3 glow_color : source_color = vec3(1.0, 0.5, 0.25);
#ifdef WAX
uniform sampler2D sss_tex : hint_default_white, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform float sss_strength = 0.35;
#endif

instance uniform float awake = 0.0;
instance uniform float glow = 0.0;
instance uniform float flash = 0.0;

void fragment() {
	vec3 albedo = texture(albedo_tex, UV).rgb;
	vec3 orm = texture(orm_tex, UV).rgb;
	// (two-sided debris: NORMAL already faces the viewer on a back face)
	vec3 normal = NORMAL;
#ifdef DEBRIS
	// broken pieces are open shells: their inside is dark
	if (!FRONT_FACING) {
		albedo *= 0.3;
	}
#endif
	ALBEDO = albedo;
	ROUGHNESS = orm.g;
	METALLIC = orm.b * metallic_scale;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
#ifdef WAX
	SSS_STRENGTH = texture(sss_tex, UV).r * sss_strength;
#endif
	float facing = clamp(dot(normal, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, rim_power);
	float distance_fade = smoothstep(rim_fade.x, rim_fade.y, length(VERTEX));
	float far = smoothstep(far_fade.x, far_fade.y, length(VERTEX));
	vec3 emit = texture(emit_tex, UV).rgb;
	vec3 light = emit * emit_energy * (0.45 + 0.75 * awake + 4.0 * glow * glow + far_emit * far * awake);
	light += rim_color * (fresnel * rim_strength * distance_fade * (1.0 + far_rim * far) + far_body * far) * awake;
	// the telegraph: a thin hot edge and a faint warmth, the eyes flare
	float edge = pow(1.0 - facing, 6.0);
	light += glow_color * glow * glow * (0.008 + 0.45 * edge);
	light += vec3(1.0, 0.93, 0.85) * flash * (0.2 + 0.7 * edge);
	EMISSION = light;
}
