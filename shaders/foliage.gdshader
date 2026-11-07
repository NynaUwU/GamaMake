shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;
// Tufos de grama e arbustos de planos cruzados com textura recortada.
#include "res://shaders/foliage.gdshaderinc"
uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_disable;

void vertex() {
	sway_vertex(VERTEX, MODEL_MATRIX, CAMERA_POSITION_WORLD, TIME);
	tip = 1.0 - UV.y;
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	ALBEDO = srgb_to_linear(COLOR.rgb) * t.rgb * mix(base_dark, 1.08, tip);
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
}
