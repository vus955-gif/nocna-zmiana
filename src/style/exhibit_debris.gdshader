shader_type spatial;
// Pieces of a broken exhibit: two-sided (torn pieces are open shells).
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

#define DEBRIS
#include "res://src/style/exhibit.gdshaderinc"
