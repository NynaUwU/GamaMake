shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
// Respingo de chuva animado só no shader: cada instância guarda a hora em que
// nasceu (INSTANCE_CUSTOM.x). O anel abre e as gotinhas pulam para fora.
// COLOR.r: 0 = anel, 1 = gotinha (UV2 = direção, COLOR.g = força do pulo).

uniform float now = 0.0;
uniform float life = 0.34;
uniform vec4 tint : source_color = vec4(0.78, 0.84, 0.95, 0.55);

varying float fade;

void vertex() {
	float age = (now - INSTANCE_CUSTOM.x) / life;
	if (age < 0.0 || age > 1.0) {
		VERTEX = vec3(0.0);
		fade = 0.0;
	} else {
		if (COLOR.r < 0.5) {
			VERTEX.xz *= 0.35 + age * 1.8;
		} else {
			VERTEX.xz += UV2 * age * 0.3;
			VERTEX.y += (COLOR.g * age - 1.1 * age * age) * 0.32;
		}
		fade = 1.0 - age;
	}
}

void fragment() {
	ALBEDO = tint.rgb;
	ALPHA = tint.a * fade;
}
