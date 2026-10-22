shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Coup de pinceau à trois couches EN UN SEUL APPEL DE DESSIN (vfx.gd : _layers, éclairs, coupes, kunai) :
// les couches (contour d'encre, corps, cœur) sont les triangles successifs d'une seule surface, dans l'ordre où
// elles se peignent ; la couleur de sommet dit la couche (COLOR.r : 0, 0.5, 1), si elle est au pinceau ou en
// aplat (COLOR.g : 1 pinceau, 0 aplat) et son séchage d'avance (COLOR.b : palier minimal, éclair au pinceau sec).
// Teintes et estompage par paramètres d'instance : UNE matière partagée par priorité de rendu, là où l'ancienne
// version demandait trois surfaces, trois matières et trois appels de dessin par effet.
// Même pinceau que fx_brush.gdshader : UV.x le long du trait, UV.y en travers (0..1), UV2.x position le long du
// trait (0 attaque, 1 queue plus sèche).

instance uniform vec4 bf_c0 : source_color = vec4(0.1, 0.1, 0.12, 0.9);  // contour d'encre
instance uniform vec4 bf_c1 : source_color = vec4(0.1, 0.1, 0.12, 1.0);  // corps
instance uniform vec4 bf_c2 : source_color = vec4(1.0, 1.0, 1.0, 0.9);  // cœur
instance uniform float bf_fade = 0.0;  // 0 plein .. 1 presque effacé (paliers de l'_anim)
uniform float dry = 0.9;

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
	float layer = COLOR.r * 2.0;
	vec4 tint = layer < 0.5 ? bf_c0 : (layer < 1.5 ? bf_c1 : bf_c2);
	float fade = max(bf_fade, COLOR.b);
	float a;
	if (COLOR.g > 0.5) {
		// poils : bruit qui varie vite en travers et lentement le long du trait ; les bords et la queue sèchent
		// d'abord, puis tout le trait avec l'estompage
		float n = vnoise(vec2(UV.x * 1.3, UV.y * 9.0));
		float n2 = vnoise(vec2(UV.x * 3.1 + 7.0, UV.y * 23.0));
		float hair = n * 0.65 + n2 * 0.35;
		float edge = abs(UV.y * 2.0 - 1.0);
		float d = clamp(fade * 1.15 + UV2.x * 0.45 + edge * edge * 0.3, 0.0, 1.0) * dry;
		float lo = mix(0.2, 0.62, d);
		float keep = smoothstep(lo, lo + 0.18, hair);
		a = mix(1.0, keep, clamp(d * 1.6, 0.0, 1.0)) * (1.0 - fade * fade * 0.5);
	} else {
		// aplat (cœur clair) : il pâlit simplement
		a = 1.0 - fade;
	}
	ALBEDO = tint.rgb;
	ALPHA = clamp(tint.a * a, 0.0, 1.0);
}
