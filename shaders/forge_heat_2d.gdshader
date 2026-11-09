shader_type canvas_item;
// Peça na forja (minigame): cor pela temperatura, bordas um pouco mais frias,
// cintilado da carepa e as rachaduras (cracks = 0..3) desenhadas por cima.
// chart = 1: vira a tabela de cores (temperatura = UV.x).
#include "res://shaders/forge_heat.gdshaderinc"

uniform float temperature : hint_range(0.0, 1.0) = 0.0;
uniform vec3 cold_color = vec3(0.26, 0.25, 0.25);
uniform float cracks = 0.0;
uniform float chart = 0.0;
uniform float flicker = 0.0;

float crack_line(vec2 uv, float x, float seed) {
	float wobble = (heat_hash(vec2(floor(uv.y * 14.0), seed)) - 0.5) * 0.05;
	return 1.0 - smoothstep(0.004, 0.014, abs(uv.x - x - wobble - uv.y * 0.04));
}

void fragment() {
	if (chart > 0.5) {
		COLOR.rgb = heat_color(UV.x, cold_color);
		COLOR.a = 1.0;
	} else {
		float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
		float n = heat_hash(floor(UV * vec2(40.0, 10.0)) + floor(TIME * 6.0) * flicker);
		float t = clamp(temperature - (1.0 - smoothstep(0.0, 0.18, edge)) * 0.07 + (n - 0.5) * 0.03, 0.0, 1.0);
		vec3 c = heat_color(t, cold_color);
		float scale = step(0.82, heat_hash(floor(UV * vec2(30.0, 8.0)))) * (1.0 - smoothstep(0.3, 0.6, t));
		c *= 1.0 - scale * 0.35;
		float crack = 0.0;
		if (cracks > 0.5) crack = max(crack, crack_line(UV, 0.3, 1.0));
		if (cracks > 1.5) crack = max(crack, crack_line(UV, 0.62, 2.0));
		if (cracks > 2.5) crack = max(crack, crack_line(UV, 0.47, 3.0));
		c = mix(c, vec3(0.05, 0.02, 0.01), crack * 0.9);
		COLOR.rgb = c;
	}
}
