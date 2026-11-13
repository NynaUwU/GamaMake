// Superfície "PS2" de tudo que é desenhado com cor por vértice (construções,
// máquinas, cidade, árvores, rochas, terreno). Incluído por ps2_surface*.gdshader.
//
// - A cor por vértice é sRGB (como foi escolhida no código): converte para linear.
//   Sem isso, no Forward+ tudo ficava pálido/lavado.
// - Textura de detalhe 64x64 pixelada (filtro nearest), projetada nos 3 eixos
//   (sem UV): R = veio de madeira, G = grão de pedra, B = grão fino, A = manchas.
//   O tipo sai da própria cor: marrom = madeira, cinza = pedra/metal, verde = folha.
// - mode 1 = terreno (coordenadas do mundo, textura maior).
// - sway > 0 = balança no vento o que estiver acima de 1,4 m (copas das árvores).

uniform sampler2D detail_tex : filter_nearest_mipmap, repeat_enable;
uniform float detail_strength = 1.0;
uniform float texel_scale = 1.0; // repetições da textura por metro
uniform int mode = 0;
uniform float roughness_value = 0.95;
uniform float metallic_value = 0.0;
uniform float specular_value = 0.3;
uniform float sway = 0.0;
uniform float wind = 0.3;
uniform float grain_up = 0.0; // 1 = veio da madeira na vertical (material do pilar em pé)
uniform float srgb_fix = 1.0; // 0 = cores lavadas de antes da atualização gráfica (menu de gráficos)
uniform float grid_lines = 0.0; // terreno: risca os blocos de 0,4 m do chão

varying vec3 tri_pos;
varying vec3 tri_nrm;

// No Compatibility (OpenGL) a cor por vértice já chega linear; no Forward+ chega
// como foi escrita (sRGB) e precisa converter.
vec3 srgb_to_linear(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return c;
#else
	return mix(c, c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878), srgb_fix);
#endif
}

vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1.0e-10)), d / (q.x + 1.0e-10), q.x);
}

void vertex() {
	if (sway > 0.0) {
		vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float up = max(VERTEX.y - 1.4, 0.0);
		float phase = TIME * 1.3 + w.x * 0.21 + w.z * 0.17;
		float gust = 0.6 + 0.4 * sin(TIME * 0.37 + w.x * 0.05);
		VERTEX.x += sin(phase) * up * 0.018 * sway * (0.3 + wind) * gust;
		VERTEX.z += cos(phase * 0.8) * up * 0.012 * sway * (0.3 + wind) * gust;
	}
	if (mode == 1) {
		tri_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		tri_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	} else {
		tri_pos = VERTEX;
		tri_nrm = NORMAL;
	}
}

// Coordenada da textura no plano do eixo dominante da face (projeção "dura",
// cara de PS2, e uma leitura só por pixel). Madeira: o veio corre na horizontal.
vec2 detail_uv(vec3 p, vec3 n) {
	vec3 a = abs(n);
	vec2 uv;
	if (a.y >= a.x && a.y >= a.z) {
		return p.xz;
	} else if (a.x >= a.z) {
		uv = p.zy;
	} else {
		uv = p.xy;
	}
	return grain_up > 0.5 ? uv.yx : uv;
}

void fragment() {
	vec3 authored = COLOR.rgb;
	vec3 hsv = rgb_to_hsv(authored);
	float scale = texel_scale * (mode == 1 ? 0.5 : 1.0);
	vec2 uv = detail_uv(tri_pos, tri_nrm);
	vec4 d = texture(detail_tex, uv * scale);
	// Manchas grandes (sujeira/desbotado), 8x mais espaçadas.
	float blotch = texture(detail_tex, uv * scale * 0.125).a;
	// Que tipo de superfície é, pela cor.
	float wood = smoothstep(0.02, 0.05, hsv.x) * (1.0 - smoothstep(0.12, 0.15, hsv.x))
		* smoothstep(0.2, 0.3, hsv.y) * (1.0 - smoothstep(0.62, 0.72, hsv.z));
	float grey = 1.0 - smoothstep(0.12, 0.24, hsv.y);
	float green = smoothstep(0.16, 0.2, hsv.x) * (1.0 - smoothstep(0.45, 0.5, hsv.x)) * smoothstep(0.15, 0.25, hsv.y);
	float other = clamp(1.0 - wood - grey - green, 0.0, 1.0);
	float v;
	if (mode == 1) {
		// Terreno: grão de pedra nas encostas cinzas, grão fino no resto (grama, areia, terra).
		v = mix(d.b, d.g, grey) - 0.5;
		v *= 0.55;
	} else {
		v = (d.r - 0.5) * 0.55 * wood + (d.g - 0.5) * 0.45 * grey + (d.b - 0.5) * 0.3 * (green + other);
	}
	float k = 1.0 + v * detail_strength + (blotch - 0.5) * 0.22 * detail_strength;
	vec3 base = srgb_to_linear(authored);
	if (mode == 1) {
		// Grama: manchas puxam levemente para amarelo/verde-escuro (quebra o verde liso).
		float g = green * (blotch - 0.5);
		base *= vec3(1.0 + g * 0.25, 1.0 + g * 0.1, 1.0 - g * 0.2);
	}
	if (mode == 1 && grid_lines > 0.0) {
		// Grade dos blocos de 0,4 m (TerrainWorld.GRID): linha fina e escura nas bordas.
		vec2 g = fract(tri_pos.xz / 0.4);
		vec2 e = min(g, 1.0 - g);
		k *= 1.0 - (1.0 - smoothstep(0.0, 0.035, min(e.x, e.y))) * 0.22 * grid_lines;
	}
	ALBEDO = base * k;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value * grey;
	SPECULAR = specular_value;
}
