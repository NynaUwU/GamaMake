shader_type sky;
// Céu do jogo (DayNight e BiomeAtmosphere mexem nos uniforms):
// degradê topo → horizonte que encosta na cor da neblina (o terreno longe some
// dentro do céu sem faixa), sol com halo, lua, estrelas de pixel à noite e
// nuvens de baixa resolução andando com o vento.

uniform vec3 top_color : source_color = vec3(0.33, 0.42, 0.55);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.62, 0.52);
uniform vec3 ground_color : source_color = vec3(0.1, 0.09, 0.08);
uniform vec3 fog_color : source_color = vec3(0.55, 0.5, 0.45);
uniform float haze = 0.3; // 0 = céu limpo, 1 = só neblina (nevasca, debaixo d'água)
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.88, 0.72);
uniform float sun_power = 1.0;
uniform vec3 moon_dir = vec3(0.0, 1.0, 0.0);
uniform float night = 0.0;
uniform sampler2D cloud_tex : filter_linear, repeat_enable;
uniform vec2 cloud_offset = vec2(0.0);
uniform float cloud_cover = 0.35;
uniform vec3 cloud_color : source_color = vec3(0.95, 0.93, 0.9);

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		// Faixa larga do horizonte (até ~20°) e topo mais fundo.
		float t = smoothstep(0.0, 0.55, pow(h, 0.75));
		col = mix(horizon_color, top_color, t);
		col = mix(fog_color, col, smoothstep(0.0, 0.16, h));
	} else {
		col = mix(fog_color, ground_color, smoothstep(0.0, -0.25, h));
	}
	// Sol: halo largo (cor do sol) e disco firme.
	float sd = dot(d, normalize(sun_dir));
	float day = 1.0 - night;
	col += sun_color * pow(max(sd, 0.0), 12.0) * 0.35 * sun_power * day;
	col += sun_color * pow(max(sd, 0.0), 200.0) * 0.6 * sun_power * day;
	if (!AT_CUBEMAP_PASS) {
		col += sun_color * smoothstep(0.9993, 0.9996, sd) * 6.0 * sun_power * day * (1.0 - haze * 0.8);
		// Lua e estrelas.
		float md = dot(d, normalize(moon_dir));
		col += vec3(0.75, 0.8, 0.95) * smoothstep(0.9988, 0.9992, md) * 1.6 * night;
		col += vec3(0.4, 0.45, 0.6) * pow(max(md, 0.0), 60.0) * 0.12 * night;
		if (h > 0.03 && night > 0.05) {
			vec3 cell = floor(d * 220.0);
			float s = hash13(cell);
			float star = step(0.9965, s) * (0.5 + 0.5 * hash13(cell + 7.0));
			col += vec3(0.8, 0.85, 1.0) * star * night * smoothstep(0.03, 0.25, h) * (1.0 - haze);
		}
	}
	// Nuvens: plano no alto, projetado (mais apertadas perto do horizonte).
	if (h > 0.0) {
		vec2 p = d.xz / (h + 0.12) * 0.22 + cloud_offset;
		float n = texture(cloud_tex, p).r * 0.7 + texture(cloud_tex, p * 2.3 + 0.37).r * 0.3;
		float c = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.28, n) * smoothstep(0.0, 0.18, h);
		vec3 lit = cloud_color * mix(vec3(1.0), sun_color, 0.35 * day) * (0.06 + 0.94 * day);
		lit += vec3(0.05, 0.06, 0.09) * night; // de noite: nuvem escura, levemente azulada pela lua
		lit += sun_color * pow(max(sd, 0.0), 6.0) * 0.25 * day; // borda acesa perto do sol
		col = mix(col, mix(lit, lit * 0.62, n * c), c * 0.85);
	}
	// Neblina forte encobre tudo (nevasca, chuva, debaixo d'água).
	col = mix(col, fog_color, haze);
	COLOR = col;
}
