shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Encre des énigmes (puzzle_art.gd) : figure de la stèle qui se trace toute seule au pinceau,
// cercles en pointillés autour de l'esprit, chemin discret entre les lanternes.
// UV.x : abscisse normalisée le long du trait (0 = départ, 1 = arrivée), UV.y : travers du ruban (0..1),
// UV2.x : abscisse en mètres (pointillés, poils du pinceau).

uniform vec4 ink : source_color = vec4(0.106, 0.102, 0.118, 0.8);
uniform vec4 head_col : source_color = vec4(0.843, 0.216, 0.169, 0.0);  // pointe du pinceau (alpha 0 : aucune)
uniform float reveal = 1.0;  // part du trait déjà tracée (0..1)
uniform float fade = 1.0;  // opacité d'ensemble
uniform float dash = 0.0;  // période des pointillés en mètres (0 : trait plein)
uniform float dash_fill = 0.55;  // part pleine d'une période
uniform float scroll = 0.0;  // décalage des pointillés (m) : ils avancent le long du trait
uniform float dry = 0.7;  // bords secs du pinceau

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.x, p.y, p.x) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	// poils : stries le long du trait, plus marquées sur les bords
	float hair = vnoise(vec2(UV2.x * 3.0, UV.y * 22.0)) * 0.7 + vnoise(vec2(UV2.x * 7.0 + 5.0, UV.y * 51.0)) * 0.3;
	float a = ink.a * fade;
	a *= mix(1.0, smoothstep(0.22, 0.55, hair), dry * smoothstep(0.3, 1.0, across));
	a *= 1.0 - smoothstep(0.85, 1.0, across);
	// tracé progressif : rien au-delà de la pointe
	float edge = reveal - UV.x;
	a *= smoothstep(-0.004, 0.01, edge);
	vec3 c = ink.rgb;
	float headk = (1.0 - smoothstep(0.0, 0.07, edge)) * step(reveal, 0.995) * head_col.a;
	c = mix(c, head_col.rgb, headk);
	if (dash > 0.0) {
		float ph = fract((UV2.x + scroll) / dash);
		a *= smoothstep(0.0, 0.06, ph) * (1.0 - smoothstep(dash_fill - 0.06, dash_fill, ph));
	}
	ALBEDO = c;
	ALPHA = clamp(a, 0.0, 1.0);
}
