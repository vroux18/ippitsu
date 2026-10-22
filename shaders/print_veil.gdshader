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
// perspective atmosphérique : la caméra plonge à angle fixe, le haut de l'image est le plus loin. Une brume
// teintée (couleur du lointain du monde) monte vers le haut, nulle sur la moitié basse : profondeur sans
// passe de plus (ce voile est déjà dessiné) ; le cœur de l'arène et les zones d'attaque restent nets.
uniform vec4 haze_col : source_color = vec4(0.5, 0.55, 0.7, 1.0);
uniform float haze_k = 0.0;
uniform float haze_from = 0.62;  // hauteur (UV.y) où la brume commence (0 : haut de l'écran)

// Hachage sur les BITS des flottants (arithmétique entière 32 bits, exacte) : le même résultat sur bureau et sur
// GPU de téléphone, quelle que soit la précision flottante (l'ancien hachage par fract de grands produits se
// dégrade en blocs ou en zéros dès que le pilote calcule en 16 bits).
float hash12(vec2 p) {
	uvec2 b = floatBitsToUint(p + vec2(0.5));
	uint h = (b.x * 1597334677u) ^ (b.y * 3812015801u + 2654435769u);
	h ^= h >> 16u;
	h *= 2146121005u;
	h ^= h >> 15u;
	h *= 2221713035u;
	h ^= h >> 16u;
	return float(h >> 8u) * (1.0 / 16777216.0);
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
	float hz = haze_k * pow(1.0 - smoothstep(0.0, haze_from, UV.y), 1.6);
	hz *= 1.0 - clamp(dark + bk, 0.0, 1.0);
	COLOR = vec4(ink.rgb * v + lift + band_col.rgb * bk + haze_col.rgb * hz, clamp(dark + bk + hz, 0.0, 1.0));
}
