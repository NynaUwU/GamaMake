// Vento da folhagem (tufos recortados e lâminas de grama). A cor vem da
// instância (sRGB). fade_far > 0: a grama encolhe até sumir perto desse raio
// (sem borda dura quando o jogador anda).
uniform float wind = 0.3;
uniform float fade_far = 0.0;
uniform float base_dark = 0.5;

varying float tip;

// No Compatibility (OpenGL) a cor por vértice já chega linear; no Forward+ chega
// como foi escrita (sRGB) e precisa converter.
vec3 srgb_to_linear(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return c;
#else
	return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878);
#endif
}

void sway_vertex(inout vec3 v, mat4 model, vec3 cam, float time) {
	vec3 w = (model * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float up = max(v.y, 0.0);
	float phase = time * 2.2 + w.x * 0.45 + w.z * 0.31;
	float gust = 0.55 + 0.45 * sin(time * 0.6 + w.x * 0.04 + w.z * 0.03);
	float amount = up * up * 0.35 * (0.2 + wind) * gust;
	v.x += sin(phase) * amount;
	v.z += cos(phase * 0.73) * amount * 0.6;
	if (fade_far > 0.0) {
		float dist = distance(w, cam);
		v.y *= 1.0 - smoothstep(fade_far * 0.65, fade_far, dist);
	}
}
