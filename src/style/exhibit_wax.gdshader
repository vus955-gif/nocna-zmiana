shader_type spatial;
// Wax figures: the exhibit shader with subsurface scattering (skin mode).
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, sss_mode_skin;

#define WAX
#include "res://src/style/exhibit.gdshaderinc"
