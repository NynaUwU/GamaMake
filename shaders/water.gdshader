shader_type spatial;
// Superfície dos lagos: ondinhas no vértice, cor mais clara na borda/rasa,
// reflexo mais forte olhando de lado (fresnel) e brilho do sol picotado.
render_mode blend_mix, cull_disabled, depth_draw_always, specular_schlick_ggx;

uniform vec4 shallow : source_color = vec4(0.45, 0.66, 0.66, 0.28);
uniform vec4 deep : source_color = vec4(0.24, 0.48, 0.55, 0.58);
uniform float wave_height = 0.04;
uniform float frozen = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(world_pos.x * 0.9 + TIME * 1.3) * cos(world_pos.z * 0.7 + TIME * 1.1);
	VERTEX.y += w * wave_height * (1.0 - frozen);
}

float ripple(vec2 p, float t) {
	return sin(p.x * 3.1 + t * 1.7) * sin(p.y * 2.7 - t * 1.3) + sin((p.x + p.y) * 4.3 + t * 2.1) * 0.5;
}

void fragment() {
	vec2 p = world_pos.xz;
	float r = ripple(p, TIME) * (1.0 - frozen);
	// UV.x = distância até a borda (1 no centro, 0 na margem): margem mais clara.
	float center = clamp(UV.x, 0.0, 1.0);
	vec4 water = mix(shallow, deep, smoothstep(0.0, 0.7, center));
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = water.rgb + vec3(0.08) * r * 0.25;
	// Um pouco de luz própria + céu refletido de lado: a água não fica preta
	// em cima do lodo do fundo.
	EMISSION = water.rgb * 0.2 + vec3(0.55, 0.6, 0.62) * fresnel * 0.2;
	ALPHA = clamp(water.a + fresnel * 0.3, 0.0, 0.85);
	ROUGHNESS = 0.12;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	NORMAL_MAP = normalize(vec3(0.5 + r * 0.06, 0.5 + ripple(p.yx * 1.3, TIME * 1.2) * 0.06, 1.0));
	if (frozen > 0.5) {
		ALBEDO = vec3(0.72, 0.82, 0.88) + vec3(r * 0.02);
		ALPHA = 0.96;
		ROUGHNESS = 0.35;
		EMISSION = vec3(0.2, 0.24, 0.26);
	}
}
