shader_type spatial;
// Architecture fields of the lobby kit (walls, floors, ceilings, reveals,
// stair masses): a tileable 64 px/m texture set mapped by position, so any
// box, stretched piece or greybox shell face gets the exact texel density
// and the joints of neighbouring pieces line up on the world grid.
// One axis per face (the dominant normal axis), not a blend: texels stay
// crisp. Each axis has an upright, unmirrored frame (courses stay
// horizontal on every wall) and its own tangent frame for the normal map.
// Mip levels come from the position's screen derivatives, so face edges
// get no one-pixel seams. local_space maps in object space (false panels
// that slide keep their pattern). Tile size = texture size / 64 px per m.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform float texels_per_metre = 64.0;
// metres added to the mapped position (shift a floor pattern off the grid)
uniform vec3 tile_offset = vec3(0.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float normal_scale = 1.0;
uniform float roughness_scale = 1.0;
uniform bool local_space = false;

varying vec3 map_pos;
varying vec3 map_nrm;
varying vec3 world_x;
varying vec3 world_y;
varying vec3 world_z;

void vertex() {
	if (local_space) {
		map_pos = VERTEX;
		map_nrm = NORMAL;
		world_x = normalize(MODEL_NORMAL_MATRIX * vec3(1.0, 0.0, 0.0));
		world_y = normalize(MODEL_NORMAL_MATRIX * vec3(0.0, 1.0, 0.0));
		world_z = normalize(MODEL_NORMAL_MATRIX * vec3(0.0, 0.0, 1.0));
	} else {
		map_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		map_nrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
		world_x = vec3(1.0, 0.0, 0.0);
		world_y = vec3(0.0, 1.0, 0.0);
		world_z = vec3(0.0, 0.0, 1.0);
	}
}

void fragment() {
	vec3 p = map_pos + tile_offset;
	vec3 n = normalize(map_nrm);
	vec3 a = abs(n);
	vec3 t_axis;
	vec3 b_axis;
	vec3 n_axis;
	if (a.y >= a.x && a.y >= a.z) {
		// floors: image up = north (-Z); ceilings seen from below: image up = +Z
		float s = n.y >= 0.0 ? 1.0 : -1.0;
		n_axis = vec3(0.0, s, 0.0);
		t_axis = vec3(1.0, 0.0, 0.0);
		b_axis = vec3(0.0, 0.0, -s);
	} else if (a.x >= a.z) {
		float s = n.x >= 0.0 ? 1.0 : -1.0;
		n_axis = vec3(s, 0.0, 0.0);
		t_axis = vec3(0.0, 0.0, -s);
		b_axis = vec3(0.0, 1.0, 0.0);
	} else {
		float s = n.z >= 0.0 ? 1.0 : -1.0;
		n_axis = vec3(0.0, 0.0, s);
		t_axis = vec3(s, 0.0, 0.0);
		b_axis = vec3(0.0, 1.0, 0.0);
	}
	vec2 tile_m = vec2(textureSize(albedo_tex, 0)) / texels_per_metre;
	vec2 uv = vec2(dot(p, t_axis) / tile_m.x, -dot(p, b_axis) / tile_m.y);
	vec3 dpx = dFdx(p);
	vec3 dpy = dFdy(p);
	vec2 gx = vec2(dot(dpx, t_axis) / tile_m.x, -dot(dpx, b_axis) / tile_m.y);
	vec2 gy = vec2(dot(dpy, t_axis) / tile_m.x, -dot(dpy, b_axis) / tile_m.y);
	vec4 col = textureGrad(albedo_tex, uv, gx, gy);
	vec3 orm = textureGrad(orm_tex, uv, gx, gy).rgb;
	vec3 nm;
	nm.xy = textureGrad(normal_tex, uv, gx, gy).rg * 2.0 - 1.0;
	// rebuilt from red and green (a normal-map import may drop blue)
	nm.z = sqrt(max(0.0, 1.0 - dot(nm.xy, nm.xy)));
	nm.xy *= normal_scale;
	vec3 nn = normalize(t_axis * nm.x + b_axis * nm.y + n_axis * nm.z);
	if (local_space) {
		nn = normalize(world_x * nn.x + world_y * nn.y + world_z * nn.z);
	}
	ALBEDO = col.rgb * tint.rgb;
	AO = orm.r;
	ROUGHNESS = clamp(orm.g * roughness_scale, 0.0, 1.0);
	METALLIC = orm.b;
	NORMAL = normalize((VIEW_MATRIX * vec4(nn, 0.0)).xyz);
}
