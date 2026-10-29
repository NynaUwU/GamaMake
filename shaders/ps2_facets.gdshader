shader_type spatial;
render_mode cull_disabled;
// Material "PS2 facetado" para malhas do MeshBuilder:
//  - facet: mistura a normal suave com a normal da face (cada polígono
//    aparece como uma faceta, sem ficar quadrado demais);
//  - linhas: escurece perto das arestas reais dos polígonos (as diagonais
//    que dividem quadrados em triângulos ficam escondidas pelo MeshBuilder,
//    que grava em CUSTOM0 a distância "baricêntrica" até cada aresta).

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.6;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float facet : hint_range(0.0, 1.0) = 0.55;
uniform float edge_darkness : hint_range(0.0, 1.0) = 0.35;
uniform float edge_width = 1.2; // em pixels
uniform float emission_energy = 0.0;

varying vec3 edge_coords;

void vertex() {
	edge_coords = CUSTOM0.rgb;
}

void fragment() {
	vec3 normal = FRONT_FACING ? NORMAL : -NORMAL;
	vec3 flat_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(flat_normal, VERTEX) > 0.0) {
		flat_normal = -flat_normal; // sempre virada para a câmera
	}
	NORMAL = normalize(mix(normal, flat_normal, facet));

	float d = min(edge_coords.x, min(edge_coords.y, edge_coords.z));
	float line = 1.0 - smoothstep(0.0, fwidth(d) * edge_width, d);
	vec3 color = albedo.rgb * COLOR.rgb;
	ALBEDO = color * (1.0 - line * edge_darkness);
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = color * emission_energy;
}
