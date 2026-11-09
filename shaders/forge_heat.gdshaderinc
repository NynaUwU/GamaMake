// Cor do metal pela temperatura (0 = frio, 1 = branco), como o ferreiro lê:
// frio (cor do metal) -> vermelho escuro -> cereja -> laranja -> amarelo -> branco.
// Usado no minigame da forja (2D) e na peça em brasa em cima da bigorna (3D).
// Cores em sRGB (o 3D converte para linear).

vec3 heat_color(float t, vec3 cold) {
	const vec3 DARK_RED = vec3(0.30, 0.035, 0.02);
	const vec3 CHERRY = vec3(0.72, 0.07, 0.03);
	const vec3 ORANGE_RED = vec3(0.95, 0.27, 0.05);
	const vec3 ORANGE = vec3(1.0, 0.52, 0.1);
	const vec3 YELLOW = vec3(1.0, 0.83, 0.3);
	const vec3 WHITE = vec3(1.0, 0.97, 0.88);
	vec3 c = mix(cold, DARK_RED, smoothstep(0.08, 0.24, t));
	c = mix(c, CHERRY, smoothstep(0.24, 0.38, t));
	c = mix(c, ORANGE_RED, smoothstep(0.38, 0.52, t));
	c = mix(c, ORANGE, smoothstep(0.52, 0.66, t));
	c = mix(c, YELLOW, smoothstep(0.66, 0.8, t));
	c = mix(c, WHITE, smoothstep(0.8, 0.95, t));
	return c;
}

// Quanto o metal brilha sozinho (0 frio, ~1 vermelho, mais no branco).
float heat_glow(float t) {
	return smoothstep(0.12, 0.45, t) + smoothstep(0.6, 1.0, t) * 1.5;
}

float heat_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
