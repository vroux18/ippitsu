shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

// Traînée au pinceau (sillage de lame, ruée) : couleur des sommets, poils qui s'effilochent avec l'âge.
// UV.x : coordonnée fixe le long du trait (les poils ne glissent pas), UV.y : travers du ruban,
// UV2.x : âge du point (0 = frais, 1 = sur le point de disparaître).

uniform float dry = 0.8;

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
	float n = vnoise(vec2(UV.x, UV.y * 24.0));
	float n2 = vnoise(vec2(UV.x * 2.3 + 7.0, UV.y * 57.0));
	float hair = n * 0.7 + n2 * 0.3;
	float d = clamp(UV2.x, 0.0, 1.0) * dry;
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * mix(1.0, smoothstep(0.32, 0.6, hair), d);
}
