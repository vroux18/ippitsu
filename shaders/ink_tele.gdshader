shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Annonces d'attaque (vfx.gd : tele_disc, tele_rect, tele_fan, tele_dot) EN UN SEUL APPEL DE DESSIN : un quad
// partagé (PlaneMesh 2 × 2) posé sur la boîte de la forme, une matière partagée ; la forme, la boîte, l'avancée et
// le flash en paramètres d'instance. L'ancienne annonce demandait quatre maillages et quatre appels de dessin
// (fond + contour, remplissage, liseré) empilés sur la même surface (trois couches de transparence).
// Langage (le même partout) : fond vermillon pâle hachuré en diagonale (« danger » lisible sur tous les sols),
// remplissage vermillon qui avance jusqu'au bord avec un front plus sombre, liseré vermillon qui pulse juste
// dedans, contour d'encre au pinceau ; les dernières 0,15 s, tout flashe en blanc papier.
// Distances en mètres, dans le repère de l'annonce (p.x, p.y = x, z locaux).

instance uniform vec4 tl_shape = vec4(0.0, 1.0, 1.0, 0.0);  // x : sorte (0 disque, 1 rectangle, 2 éventail, 3 marque), y, z : tailles
instance uniform vec4 tl_box = vec4(1.0, 1.0, 0.0, 0.0);  // demi-tailles (x, z) et centre (x, z) du quad
instance uniform vec4 tl_state = vec4(0.0, 0.0, 0.0, 0.0);  // x : avancée 0..1, y : flash, z : pulsation 0..1
instance uniform vec4 tl_grow = vec4(0.0, 0.0, 0.0, 0.0);  // côté d'où part le remplissage (rectangle)

const float INK_W = 0.09;  // contour d'encre (à cheval sur le bord, surtout dehors) : vfx.TELE_INK
const float RIM_W = 0.07;  // liseré : vfx.TELE_RIM

varying vec2 p;

float hash12(vec2 q) {
	vec3 p3 = fract(vec3(q.x, q.y, q.x) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 q) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	// le nœud est posé sur la boîte (échelle = demi-tailles, position = centre) : p en mètres de l'annonce
	p = VERTEX.xz * tl_box.xy + tl_box.zw;
}

float sd_box(vec2 q, vec2 h) {
	vec2 d = abs(q) - h;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// secteur de demi-angle a (axe +z), rayon r
float sd_pie(vec2 q, float a, float r) {
	vec2 c = vec2(sin(a), cos(a));
	q.x = abs(q.x);
	float l = length(q) - r;
	float m = length(q - c * clamp(dot(q, c), 0.0, r));
	return max(l, m * sign(c.y * q.x - c.x * q.y));
}

// distance au bord de la forme, à l'avancée k (1 : forme entière)
float shape_d(float k) {
	float mode = tl_shape.x;
	if (mode < 0.5 || mode > 2.5) {
		return length(p) - tl_shape.y * k;
	} else if (mode < 1.5) {
		vec2 h = tl_shape.yz;
		vec2 g = tl_grow.xy;
		vec2 hk = vec2(g.y != 0.0 ? h.x : h.x * k, g.x != 0.0 ? h.y : h.y * k);
		vec2 c = vec2(g.x * h.x * (1.0 - k), g.y * h.y * (1.0 - k));
		return sd_box(p - c, hk);
	}
	return sd_pie(p, tl_shape.y, tl_shape.z * k);
}

vec4 over(vec4 dst, vec4 src) {
	float a = src.a + dst.a * (1.0 - src.a);
	vec3 c = (src.rgb * src.a + dst.rgb * dst.a * (1.0 - src.a)) / max(a, 0.0001);
	return vec4(c, a);
}

void fragment() {
	float k = clamp(tl_state.x, 0.01, 1.0);
	bool flash = tl_state.y > 0.5;
	float d = shape_d(1.0);
	float aa = max(fwidth(d), 0.004);
	float size = tl_shape.x > 2.5 ? tl_shape.y : max(tl_shape.y, tl_shape.z);
	vec4 col = vec4(0.0);
	if (tl_shape.x > 2.5) {
		// marque de chemin : pastille vermillon cernée d'encre
		float r = tl_shape.y;
		float ind = 1.0 - smoothstep(-aa, aa, d);
		float ink = (1.0 - smoothstep(-aa, aa, d - r * 0.45)) * (1.0 - ind);
		vec4 fc = flash ? vec4(1.0, 0.95, 0.86, 0.92) : vec4(0.92, 0.22, 0.14, 0.9);
		vec4 ic = flash ? fc : vec4(0.1, 0.1, 0.12, 0.9);
		col = over(col, vec4(fc.rgb, fc.a * ind));
		col = over(col, vec4(ic.rgb, ic.a * ink));
	} else {
		float inside = 1.0 - smoothstep(-aa, aa, d);
		// fond : vermillon pâle, hachures diagonales (lisibles même sur un sol rouge ou sombre)
		float hat = smoothstep(0.35, 0.5, abs(fract((p.x + p.y) * 3.2) - 0.5));
		col = over(col, vec4(0.9, 0.24, 0.15, (0.15 + 0.17 * hat) * inside));
		// remplissage qui avance, front plus sombre
		float fd = shape_d(k);
		float fill = (1.0 - smoothstep(-aa, aa, fd)) * inside;
		vec4 fc = flash ? vec4(1.0, 0.95, 0.86, 0.92) : vec4(0.88, 0.2, 0.13, 0.58);
		col = over(col, vec4(fc.rgb, fc.a * fill));
		if (!flash && k < 0.995) {
			float front = (1.0 - smoothstep(0.02, 0.07, abs(fd + 0.04))) * inside;
			col = over(col, vec4(0.5, 0.06, 0.04, 0.85 * front));
		}
		// liseré qui pulse juste dedans (il rentre un peu à l'approche du coup)
		if (!flash) {
			float sh = (0.01 + 0.035 * k) * tl_state.z * size;
			float dr = d + sh;
			float rim = (1.0 - smoothstep(-aa, aa, dr + 0.02)) * smoothstep(-aa, aa, dr + 0.02 + RIM_W);
			col = over(col, vec4(0.95, 0.24, 0.15, 0.95 * rim));
		}
		// contour d'encre au pinceau : épaisseur qui respire le long du bord
		float wob = (vnoise(p * 5.0) - 0.5) * 0.035;
		float ink = smoothstep(-aa, aa, d + 0.02) * (1.0 - smoothstep(-aa, aa, d - INK_W - wob));
		col = over(col, vec4(0.1, 0.1, 0.12, 0.9 * ink));
	}
	ALBEDO = col.rgb;
	ALPHA = clamp(col.a, 0.0, 1.0);
}
