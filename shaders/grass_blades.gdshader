shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled, shadows_disabled;
// Grama densa perto do jogador: lâminas sólidas (sem recorte = barato), pé escuro
// e ponta clara, balançando no vento e sumindo aos poucos na borda.
#include "res://shaders/foliage.gdshaderinc"

void vertex() {
	tip = clamp(VERTEX.y / 0.45, 0.0, 1.0);
	sway_vertex(VERTEX, MODEL_MATRIX, CAMERA_POSITION_WORLD, TIME);
}

void fragment() {
	// Dos dois lados iluminada como o chão (normal para cima, não a da lâmina).
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ALBEDO = srgb_to_linear(COLOR.rgb) * mix(base_dark, 1.1, tip);
	ROUGHNESS = 1.0;
}
