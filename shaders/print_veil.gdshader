shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

// Voile d'estampe par-dessus la 3D (sous l'interface) : vignette d'encre douce, grain de papier fixe et
// ichimonji bokashi (bande de bleu de Prusse dégradée en haut de l'image, comme en tête des estampes).
// Prémultiplié : rgb s'ajoute, alpha assombrit ce qui est dessous.

uniform vec4 ink : source_color = vec4(0.07, 0.06, 0.08, 1.0);
uniform vec4 paper : source_color = vec4(0.94, 0.9, 0.82, 1.0);
uniform float vignette = 0.3;
uniform float grain = 0.035;
uniform vec4 band_col : source_color = vec4(0.12, 0.23, 0.37, 1.0);
uniform float band_k = 0.2;  // force de la bande du haut (0 : aucune)
uniform float band_h = 0.07;  // hauteur de la bande (fraction de l'écran)
uniform bool fine = true;

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
	vec2 dv = UV - vec2(0.5);
	dv.y *= 1.15;
	float v = smoothstep(0.34, 0.85, length(dv)) * vignette;
	float dark = v;
	vec3 lift = vec3(0.0);
	if (fine) {
		vec2 fc = FRAGCOORD.xy;
		float fib = vnoise(fc * vec2(0.09, 0.022)) * 0.6 + vnoise(fc * 0.21) * 0.4;
		float px = hash12(floor(fc * 0.5));
		float g = (fib - 0.5) * 0.7 + (px - 0.5) * 0.3;
		dark += max(-g, 0.0) * grain * 2.0 * (1.0 - v);
		lift = paper.rgb * max(g, 0.0) * grain;
	}
	// bande du haut : se fond dans l'image, n'empiète jamais sur le cœur de l'arène
	float bk = band_k * (1.0 - smoothstep(0.0, band_h, UV.y));
	COLOR = vec4(ink.rgb * v + lift + band_col.rgb * bk, clamp(dark + bk, 0.0, 1.0));
}
