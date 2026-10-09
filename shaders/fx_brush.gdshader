shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

// Coups de pinceau des effets de pouvoir (anneaux, croissants, estocs, coupes) : teinte uniforme,
// poils qui sèchent et s'effilochent quand l'effet s'estompe (paliers de `fade`, matériaux partagés).
// UV.x : coordonnée le long du trait, UV.y : travers du ruban (0..1),
// UV2.x : position le long du trait (0 = attaque du pinceau, 1 = queue, plus sèche).

uniform vec4 tint : source_color = vec4(1.0);
uniform float fade = 0.0;
uniform float dry = 0.9;

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
	// poils : bruit qui varie vite en travers et lentement le long du trait
	float n = vnoise(vec2(UV.x * 1.3, UV.y * 9.0));
	float n2 = vnoise(vec2(UV.x * 3.1 + 7.0, UV.y * 23.0));
	float hair = n * 0.65 + n2 * 0.35;
	// les bords et la queue sèchent d'abord, puis tout le trait avec l'estompage
	float edge = abs(UV.y * 2.0 - 1.0);
	float d = clamp(fade * 1.15 + UV2.x * 0.45 + edge * edge * 0.3, 0.0, 1.0) * dry;
	float lo = mix(0.2, 0.62, d);
	float keep = smoothstep(lo, lo + 0.18, hair);
	float a = mix(1.0, keep, clamp(d * 1.6, 0.0, 1.0));
	ALBEDO = tint.rgb * COLOR.rgb;
	ALPHA = tint.a * COLOR.a * a * (1.0 - fade * fade * 0.5);
}
