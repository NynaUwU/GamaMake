shader_type canvas_item;
// Tela debaixo d'água: tudo ondula, fica azul-esverdeado e escurece nas bordas,
// com faixas de luz (cáusticas) tremendo de leve.
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.12, 0.38, 0.42, 1.0);
uniform float depth = 0.0; // 0 = logo abaixo da superfície, 1 = fundo

void fragment() {
	vec2 uv = SCREEN_UV;
	uv.x += sin(uv.y * 22.0 + TIME * 2.2) * 0.0035;
	uv.y += cos(uv.x * 18.0 + TIME * 1.7) * 0.0035;
	vec3 color = textureLod(screen, uv, 1.2).rgb;
	float light = mix(1.05, 0.75, depth);
	color = mix(color, tint.rgb * light, 0.35 + depth * 0.15);
	float caustic = sin(uv.x * 40.0 + TIME * 1.5) * sin(uv.y * 34.0 - TIME * 1.1);
	color += vec3(0.05, 0.08, 0.07) * max(caustic, 0.0) * (1.0 - depth);
	float vignette = smoothstep(0.85, 0.25, length(SCREEN_UV - vec2(0.5)));
	COLOR = vec4(color * mix(0.75, 1.0, vignette), 1.0);
}
