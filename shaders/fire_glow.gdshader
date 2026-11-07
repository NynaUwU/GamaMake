shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
// Chamas, brasas e faíscas: sem luz, com a cor (sRGB) puxada acima de 1 para o
// brilho (glow) pegar.
uniform vec3 tint : source_color = vec3(1.0);
uniform float boost = 1.8;

// No Compatibility (OpenGL) a cor por vértice já chega linear; no Forward+ chega
// como foi escrita (sRGB) e precisa converter.
vec3 srgb_to_linear(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return c;
#else
	return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878);
#endif
}

void fragment() {
	ALBEDO = srgb_to_linear(COLOR.rgb) * tint * boost;
}
