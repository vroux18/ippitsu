shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Encre liquide au sol (taches, flaques, éclaboussures) : UNE matière partagée par toutes les taches, les
// réglages de chaque tache passent par des paramètres d'instance (pas de matière par tache).
// Quad unité (PlaneMesh 2 × 2, plan XZ) mis à l'échelle r × EXT par le nœud : `q` est en rayons de tache
// (1 = bord de la tache posée). Le +x local est le sens de l'impact (vfx.ink_stain oriente le nœud).
//
// Forme : champ de distance signé (SDF) d'un corps au bord bruité (FBM), de DIGITATIONS (segments effilés à
// tête ronde, surtout vers l'avant) et de GOUTTELETTES satellites, fusionnés par smooth-min (métaballes :
// une goutte proche se soude à la tache par un col d'encre).
// Vie (âge piloté par le script, jamais TIME : l'encre se fige avec le jeu) :
//   jaillissement 0 → 0,12 s : le corps déborde (×1,16) puis se rétracte en oscillant (tension de surface),
//   les digitations filent un peu après, les gouttes atterrissent selon leur distance ;
//   étalement lent ; reflet humide (croissant clair côté lumière) tant que c'est frais ;
//   SÉCHAGE : l'intérieur pâlit et se marbre, le bord fonce (auréole « coffee ring »), le bord boit le papier
//   (diffusion granuleuse) ; puis fondu par érosion (l'intérieur pâle part d'abord, l'auréole en dernier).

const float EXT = 2.2;  // demi-côté du quad, en rayons de tache (doigts et gouttes compris)

// couleur de l'encre (sumi, vermillon, couleur d'école) ; alpha : densité
instance uniform vec4 ink_color : source_color = vec4(0.1, 0.1, 0.12, 0.8);
// x : âge (s), y : vie (s, > 900 : ne sèche pas), z : graine, w : digitations (0 aucune .. 1 fortes)
instance uniform vec4 ink_state = vec4(0.0, 1.3, 0.0, 1.0);
// x : taille du corps (0 : pas de corps, couronne de gouttes seule), y : gouttes vers l'avant (0 tout autour .. 1),
// z : distance des gouttes (rayons), w : taille des gouttes
instance uniform vec4 ink_shape = vec4(1.0, 0.7, 1.55, 1.0);

varying vec2 q;
varying vec2 wxz;
varying vec2 lq;  // direction de la lumière (vers la lumière) dans le repère de la tache

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

float fbm2(vec2 p) {
	return vnoise(p) * 0.65 + vnoise(p * 2.13 + 17.3) * 0.35;
}

// union lisse (métaballes)
float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

// segment effilé : rayon ra en a, rb en b
float taper(vec2 p, vec2 a, vec2 b, float ra, float rb) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - mix(ra, rb, h);
}

void vertex() {
	q = VERTEX.xz * EXT;
	vec4 w = MODEL_MATRIX * vec4(VERTEX, 1.0);
	wxz = w.xz;
	// lumière venue du haut-gauche de l'écran (au loin, à gauche), ramenée dans le repère du nœud
	vec3 lw = normalize(vec3(-0.5, 0.0, -0.85));
	vec3 ll = transpose(mat3(MODEL_MATRIX)) * lw;
	lq = normalize(ll.xz + vec2(0.0001));
}

void fragment() {
	float age = ink_state.x;
	float life = ink_state.y;
	float seed = ink_state.z;
	float digit = ink_state.w;
	float core = ink_shape.x;

	// --- temps de vie
	float tj = clamp(age / 0.12, 0.0, 1.0);
	float burst = 1.0 - (1.0 - tj) * (1.0 - tj);
	float ta = max(age - 0.12, 0.0);
	float wob = 0.16 * exp(-ta * 7.0) * cos(ta * 24.0);  // déborde puis se rétracte (tension de surface)
	float spread = 1.0 + 0.06 * clamp(ta / 1.4, 0.0, 1.0);  // étalement lent
	float R = core * (0.2 + 0.8 * burst) * (1.0 + wob * burst) * spread;
	float drying = step(life, 900.0);
	float dry = drying * clamp((age - 0.22) / max(0.5 * life, 0.5), 0.0, 1.0);
	dry = dry * dry * (3.0 - 2.0 * dry);
	float fade = drying * smoothstep(0.76 * life, life, age);
	float wet = 1.0 - dry;

	// --- forme
	// léger gauchissement du domaine : rien n'est tout à fait rond
	vec2 p = q + (vec2(vnoise(q * 1.7 + seed * 13.1), vnoise(q * 1.7 + seed * 7.7 + 31.0)) - 0.5) * 0.22;
	float r = length(p);
	vec2 dir = p / max(r, 0.0001);
	// bord du corps : FBM sur la direction (pas de couture à l'angle ±π)
	float nb = fbm2(dir * 1.9 + seed * 3.7);
	float nh = vnoise(dir * 6.5 + seed * 5.3);
	float Rb = R * (0.8 + 0.34 * nb + 0.07 * nh);
	float d = core > 0.001 ? (r - Rb) * 0.85 : 10.0;

	// digitations : vers l'avant (+x), elles filent juste après le jaillissement
	float fl = smoothstep(0.0, 0.08, age) * (1.0 + 0.45 * exp(-ta * 6.0) + 0.5 * wob);
	if (digit > 0.001 && core > 0.001) {
		for (int k = 0; k < 6; k++) {
			float fk = float(k);
			float h1 = hash12(vec2(fk * 3.17 + 1.0, seed * 1.31 + 2.0));
			float h2 = hash12(vec2(fk * 5.41 + 7.0, seed * 0.77 + 9.0));
			float h3 = hash12(vec2(fk * 1.93 + 4.0, seed * 2.11 + 5.0));
			float ang = (k < 4) ? (h1 - 0.5) * 2.4 : (h1 * 6.2832);
			float fwd = 0.3 + 0.7 * max(cos(ang), 0.0);
			float len = (0.25 + 0.75 * h2) * digit * fwd * fl * core;
			vec2 ad = vec2(cos(ang), sin(ang));
			vec2 a = ad * R * 0.55;
			vec2 b = ad * (R * 0.85 + len);
			float rw = (0.08 + 0.1 * h3) * core;
			float fd = taper(p, a, b, rw * 1.3, rw * 0.45);
			// tête ronde au bout (l'encre s'accumule au bout du doigt)
			fd = min(fd, length(p - b) - rw * (0.75 + 0.5 * h3));
			d = smin(d, fd, 0.12 * core);
		}
	}
	// gouttelettes satellites (soudées à la tache quand elles sont proches)
	float dd = 10.0;
	for (int k = 0; k < 7; k++) {
		float fk = float(k);
		float h1 = hash12(vec2(fk * 2.71 + 3.0, seed * 1.73 + 1.0));
		float h2 = hash12(vec2(fk * 4.13 + 5.0, seed * 0.59 + 3.0));
		float h3 = hash12(vec2(fk * 6.07 + 2.0, seed * 1.17 + 8.0));
		float ang = mix(h1 * 6.2832, (h1 - 0.5) * 2.2, ink_shape.y);
		float dist = ink_shape.z * (0.72 + 0.5 * h2) * mix(1.0, 0.75 + 0.35 * max(cos(ang), 0.0), ink_shape.y);
		float land = smoothstep(dist * 0.045, dist * 0.045 + 0.06, age);  // elles atterrissent après le corps
		float rad = (0.035 + 0.075 * h3 * h3) * ink_shape.w * land;
		vec2 ad = vec2(cos(ang), sin(ang));
		vec2 c = ad * dist;
		vec2 rel = p - c;
		// goutte étirée dans le sens de sa course (larme)
		vec2 lr = vec2(dot(rel, ad) / (1.0 + 0.9 * h2), dot(rel, vec2(-ad.y, ad.x)));
		float g = length(lr) - rad;
		dd = smin(dd, g, 0.05);
	}
	d = smin(d, dd, 0.09 * max(core, 0.35));

	// --- le papier boit l'encre : bord granuleux qui diffuse en séchant
	float fib = vnoise(wxz * 26.0 + seed);
	float fib2 = vnoise(wxz * 9.0 - seed);
	d += (fib - 0.5) * (0.025 + 0.07 * dry) + (fib2 - 0.5) * 0.04 * dry - 0.035 * dry;
	float aa = max(fwidth(d), 0.002);
	float soft = aa * 0.8 + 0.02 * dry;
	float cov = 1.0 - smoothstep(-soft, soft, d);

	// --- auréole du séchage (coffee ring) et marbrure de l'intérieur
	float ringw = 0.075 + 0.05 * fib2;
	float rim = 1.0 - smoothstep(0.0, ringw, -d);
	float mott = fbm2(wxz * 3.1 + seed * 2.0) * 0.75 + vnoise(wxz * 15.0 - seed) * 0.25;  // marbrure + granulation
	float a_in = mix(1.0, 0.3 + 0.45 * mott * mott, dry);
	float dens = ink_color.a;
	float alpha = clamp(dens * 1.45, 0.0, 1.0) * mix(a_in, 1.0, rim * dry);

	vec3 ink = ink_color.rgb;
	vec3 wet_col = ink * 0.78;  // encre fraîche, plus profonde
	vec3 pale = mix(ink, vec3(dot(ink, vec3(0.333))), 0.25) * 1.25 + 0.03;  // intérieur sec, plus pâle
	vec3 dark = ink * 0.45;  // auréole
	vec3 col = mix(wet_col, mix(pale, dark, rim), dry);

	// --- reflet humide : ménisque clair au bord tourné vers la lumière, quelques reflets au cœur
	float facing = dot(dir, lq);
	float band = smoothstep(0.02, 0.07, -d) * (1.0 - smoothstep(0.1, 0.22, -d));
	float glint = band * smoothstep(0.15, 0.75, facing);
	float spot = smoothstep(0.42, 0.0, length(p - lq * R * 0.42)) * smoothstep(0.08, 0.25, -d) * 0.45;
	float hl = clamp(glint + spot * core, 0.0, 1.0) * wet * wet * smoothstep(0.02, 0.1, age);
	// jaillissement : l'encre neuve est la plus sombre et la plus brillante
	col = mix(col, vec3(0.86, 0.89, 0.95), hl * 0.5);
	alpha = max(alpha, hl * 0.85 * cov);
	// contre-jour du ménisque : liseré plus sombre côté ombre tant que c'est mouillé
	col *= 1.0 - 0.25 * wet * band * smoothstep(0.1, 0.8, -facing);

	// --- fondu final : érosion, l'intérieur pâle s'en va d'abord, l'auréole en dernier
	float keep = mott * 0.55 + rim * 0.45 + fib * 0.15;
	float er = smoothstep(fade * 1.2 - 0.12, fade * 1.2 + 0.08, keep);
	alpha *= cov * er * (1.0 - fade * 0.35);
	ALBEDO = col;
	ALPHA = alpha;
}
