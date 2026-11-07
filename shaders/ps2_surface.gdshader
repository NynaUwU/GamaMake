shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;
// Superfície PS2 com faces de trás descartadas. Corpo em ps2_surface.gdshaderinc.
#include "res://shaders/ps2_surface.gdshaderinc"
