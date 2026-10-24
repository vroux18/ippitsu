shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled, fog_disabled;

// Passe d'encre partagée des matières toon (toon.gd outline_mat), dessinée par-dessus chaque pièce :
// - faces arrière gonflées le long de la normale : le trait de contour, d'épaisseur irrégulière (l'encre bave
//   un peu, comme au pinceau : bruit doux sur le gonflement) ;
// - faces avant (la coque gonflée recouvre la pièce) : hachures de gravure sur les faces à l'ombre du soleil,
//   croisées dans l'ombre profonde, et encre pleine aux arêtes rasantes (le trait s'épaissit vers la silhouette).
//   Tout ce qui n'est pas de l'encre est jeté (discard) : la passe reste opaque, sans tri ni fondu.
// Les hachures sont tracées dans le repère de l'objet (mis en mètres par son échelle) : elles tiennent à la pièce
// quand elle bouge, et s'effacent dès que leurs traits deviennent plus fins qu'un pixel (jamais de moirage au loin).

uniform float size = 0.035;  // gonflement (unités de l'objet, comme `grow` des matières standard)
uniform vec4 ink : source_color = vec4(0.106, 0.102, 0.118, 1.0);
uniform float wobble = 0.4;  // irrégularité de l'épaisseur (0 : trait régulier)
uniform float hatch_k = 1.0;  // force des hachures (0 : aucune)
uniform float hatch_scale = 13.0;  // traits par mètre
uniform float grazing = 0.16;  // encre pleine sous cet angle à la vue (N·V)
uniform vec3 sun_dir = vec3(0.47, -0.64, -0.6);  // sens de la lumière du soleil (main : rotation -40°, -38°)
uniform sampler2D noise : hint_default_white, filter_linear_mipmap, repeat_enable;  // bruit partagé (toon.gd)

varying vec3 v_obj;  // position dans l'objet, en mètres
varying vec3 v_nw;  // normale (monde)
varying float v_wob;

// Hachage sur les BITS des flottants (arithmétique entière 32 bits, exacte), le même sur bureau et téléphone.
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

void vertex() {
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	v_obj = VERTEX * sc;
	// épaisseur du trait : varie doucement le long de la pièce (bruit sur la position, échelle ~12 cm)
	float n = vnoise(v_obj.xz * 8.0 + vec2(v_obj.y * 6.0, v_obj.y * 3.0));
	v_wob = n;
	float k = 1.0 + wobble * (n * 2.0 - 1.0);
	VERTEX += NORMAL * size * k;
	v_nw = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	if (!FRONT_FACING) {
		ALBEDO = ink.rgb;
	} else {
		vec3 n = normalize(v_nw);
		vec3 ls = -normalize(sun_dir);
		float ndl = dot(n, ls);
		// côté ombre : hachures simples dès que la face tourne le dos au soleil, croisées dans l'ombre profonde
		float shade = (1.0 - smoothstep(-0.4, 0.22, ndl)) * hatch_k;
		// vue rasante : l'encre du contour déborde vers l'intérieur (trait plus gras aux silhouettes)
		vec3 vw = normalize(mat3(INV_VIEW_MATRIX) * VIEW);
		float ndv = abs(dot(n, vw));
		float rim = 1.0 - smoothstep(grazing * 0.6, grazing, ndv);
		float inkk = rim;
		if (shade > 0.02) {
			// traits : plans parallèles inclinés dans le repère de l'objet, coupés par un grain d'encre
			float u = dot(v_obj, vec3(0.64, 0.77, 0.0)) * hatch_scale;
			float fw = fwidth(u);
			float far_k = clamp(1.3 - fw * 2.2, 0.0, 1.0);  // s'efface quand les traits sont plus fins qu'un pixel
			float w = 0.12 + 0.1 * shade;
			float l1 = 1.0 - smoothstep(w - fw, w + fw, abs(fract(u) - 0.5));
			float u2 = dot(v_obj, vec3(-0.71, 0.7, 0.1)) * hatch_scale * 1.15;
			float fw2 = fwidth(u2);
			float l2 = 1.0 - smoothstep(0.1 - fw2, 0.1 + fw2, abs(fract(u2 + 0.3) - 0.5));
			l2 *= smoothstep(0.55, 0.9, shade);
			// grain : l'encre saute par endroits (traits de plume), plus souvent près de la lumière
			float g = texture(noise, v_obj.xy * 1.7 + v_obj.zx * 0.9).g;
			float cut = smoothstep(0.58 - shade * 0.45, 0.68 - shade * 0.45, g + v_wob * 0.2);
			float lines = max(l1 * smoothstep(0.08, 0.3, shade), l2) * cut * far_k;
			inkk = max(inkk, lines);
		}
		if (inkk < 0.5) {
			discard;
		}
		ALBEDO = ink.rgb;
	}
}
