shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Occlusion ambiante feinte (scripts/ombres_contact.gd) : disques d'ombre doux posés au sol au pied des props
// (le renderer Compatibility n'a pas de SSAO). Un MultiMesh par lot de décor, en multiplication : assombrit ce qui
// est dessous sans jamais éclaircir. Par instance (INSTANCE_CUSTOM.r) : densité du disque.
// Le cœur garde un peu de la teinte d'encre du monde (jamais un gris neutre).

uniform vec4 ink : source_color = vec4(0.1, 0.09, 0.13, 1.0);
uniform float gain = 1.0;

varying float v_k;

void vertex() {
	v_k = INSTANCE_CUSTOM.r * gain;
}

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float f = max(1.0 - dot(d, d), 0.0);
	f = f * f * (0.6 + 0.4 * f);  // dense au centre, bord qui s'évanouit sans ligne
	float k = clamp(f * v_k, 0.0, 0.85);
	ALBEDO = mix(vec3(1.0), ink.rgb, k);
}
