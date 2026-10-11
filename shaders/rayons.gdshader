shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Rayons de soleil (worlds.gd build_rays) : longs quads additifs tendus dans le sens de la lumière du soleil,
// bords et bouts fondus, qui respirent lentement chacun à son rythme (graine : INSTANCE_CUSTOM.a).
// Un seul MultiMesh par monde (1 draw call) ; très discrets : ils ne doivent jamais masquer le jeu.

uniform vec4 tint : source_color = vec4(1.0, 0.92, 0.75, 1.0);
uniform float strength = 0.08;

varying float v_k;

void vertex() {
	float seed = INSTANCE_CUSTOM.a;
	float t = TIME;
	v_k = strength * INSTANCE_CUSTOM.r * (0.62 + 0.38 * sin(t * (0.21 + 0.13 * seed) + seed * 23.0)) * (0.85 + 0.15 * sin(t * 0.9 + seed * 7.0));
}

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	across = across * across * (3.0 - 2.0 * across);
	// fondu aux deux bouts, plus long vers le sol (le rayon s'évanouit avant de toucher les dalles)
	float along = smoothstep(0.0, 0.25, UV.y) * (1.0 - smoothstep(0.55, 1.0, UV.y));
	ALBEDO = tint.rgb * v_k * across * along;
}
