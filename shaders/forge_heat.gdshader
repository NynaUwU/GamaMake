shader_type spatial;
// Peça em brasa (bigorna da forja no mundo): a mesma cor por temperatura do
// minigame, brilhando sozinha (emissão) quanto mais quente.
#include "res://shaders/forge_heat.gdshaderinc"

uniform float temperature : hint_range(0.0, 1.0) = 0.0;
uniform vec3 cold_color = vec3(0.26, 0.25, 0.25);

void fragment() {
	float n = heat_hash(floor(UV * 18.0) + floor(TIME * 5.0));
	float t = clamp(temperature + (n - 0.5) * 0.04, 0.0, 1.0);
	vec3 c = pow(heat_color(t, cold_color), vec3(2.2));
	float hot = smoothstep(0.1, 0.35, t);
	ALBEDO = mix(pow(cold_color, vec3(2.2)), c * 0.35, hot);
	ROUGHNESS = 0.65;
	METALLIC = 0.4 * (1.0 - hot);
	EMISSION = c * heat_glow(t) * 2.6;
}
