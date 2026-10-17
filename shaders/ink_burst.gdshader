shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Éclats face caméra peints à l'encre (vfx.gd : impact, kill_burst, _flare, _ink_pop) : UN quad partagé (QuadMesh
// 2 × 2, plan XY) tourné vers la caméra dans le shader (l'échelle du nœud est gardée : préchauffage en miniature),
// deux matières partagées (devant / derrière les lueurs), réglages par paramètres d'instance : un appel de dessin
// par éclat. `q` en rayons d'éclat (1 = bord). L'âge est posé par le script (jamais TIME).
//
// Sortes (fx_state.w) :
//   0 GICLÉE : mise à mort. Un cœur d'encre qui éclate en digitations effilées dans le sens du coup (+x), têtes
//     rondes, gouttes qui filent au-delà et retombent ; quelques gouttes de la seconde teinte (vermillon, couleur
//     du yōkai) ; l'encre se déchire en poils puis s'efface.
//   1 TRANCHANT : coup porté. Deux coups de pinceau croisés (un long dans le sens du coup, un court en travers),
//     cœur papier, contour d'encre, quelques éclats secs autour ; bref.
//   2 ÉCLAT : lueur d'un élément peinte : rayons de pinceau d'inégale longueur qui jaillissent puis se retirent,
//     poils secs au bout des rayons, cœur clair, contour de la teinte profonde.

instance uniform vec4 fx_col : source_color = vec4(0.1, 0.1, 0.12, 0.85);  // encre / teinte de l'éclat
instance uniform vec4 fx_col2 : source_color = vec4(0.9, 0.25, 0.15, 1.0);  // seconde teinte / cœur
// x : âge (s), y : vie (s), z : graine, w : sorte
instance uniform vec4 fx_state = vec4(0.0, 0.3, 0.0, 0.0);
// x : angle du coup à l'écran (rad), y : force (0..1)
instance uniform vec4 fx_dir = vec4(0.0, 0.5, 0.0, 0.0);

varying vec2 q;

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

float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

float taper(vec2 p, vec2 a, vec2 b, float ra, float rb) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - mix(ra, rb, h);
}

void vertex() {
	q = VERTEX.xy;
	// face caméra, échelle du nœud gardée
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	mat4 mw = mat4(INV_VIEW_MATRIX[0] * sc.x, INV_VIEW_MATRIX[1] * sc.y, INV_VIEW_MATRIX[2] * sc.z, MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * mw;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

mat2 rot(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat2(vec2(c, s), vec2(-s, c));
}

// --- 0 : giclée de mise à mort
vec4 splat(float age, float life, float seed) {
	float t = clamp(age / max(life, 0.01), 0.0, 1.0);
	vec2 p = rot(-fx_dir.x) * q;  // +x : sens du coup
	float burst = 1.0 - pow(1.0 - clamp(age / 0.07, 0.0, 1.0), 3.0);
	float fly = 1.0 - pow(1.0 - t, 2.0);
	// cœur : il éclate puis se rétracte en se déchirant
	float R = 0.3 * burst * (1.0 - 0.35 * t);
	vec2 pw = p + (vec2(vnoise(p * 4.0 + seed), vnoise(p * 4.0 + seed + 9.0)) - 0.5) * 0.12;
	float d = length(pw) - R * (0.85 + 0.3 * vnoise(normalize(pw + 0.0001) * 3.0 + seed));
	// digitations effilées, surtout vers l'avant
	for (int k = 0; k < 7; k++) {
		float fk = float(k);
		float h1 = hash12(vec2(fk * 3.1 + 1.0, seed + 2.0));
		float h2 = hash12(vec2(fk * 5.3 + 7.0, seed + 5.0));
		float ang = (k < 5) ? (h1 - 0.5) * 1.9 : 3.1416 + (h1 - 0.5) * 2.4;
		float len = (k < 5 ? 0.45 + 0.45 * h2 : 0.18 + 0.2 * h2) * (0.35 + 0.65 * fly) * (0.6 + 0.4 * fx_dir.y + 0.25);
		vec2 ad = vec2(cos(ang), sin(ang));
		vec2 b = ad * (R * 0.7 + len);
		float rw = 0.05 + 0.04 * h2;
		float fd = taper(p, ad * R * 0.4, b, rw * 1.2 * burst, rw * 0.35);
		fd = min(fd, length(p - b) - rw * 0.9 * burst);
		d = smin(d, fd, 0.06);
	}
	// gouttes qui filent au-delà (elles retombent un peu : -y à l'écran)
	float dd = 10.0;
	float d2 = 10.0;
	for (int k = 0; k < 9; k++) {
		float fk = float(k);
		float h1 = hash12(vec2(fk * 2.7 + 3.0, seed + 1.0));
		float h2 = hash12(vec2(fk * 4.1 + 5.0, seed + 3.0));
		float h3 = hash12(vec2(fk * 6.1 + 2.0, seed + 8.0));
		float ang = (h1 - 0.5) * (k < 6 ? 2.2 : 5.6);
		vec2 ad = vec2(cos(ang), sin(ang));
		vec2 c = ad * (0.35 + (0.55 + 0.35 * h2) * fly);
		c = rot(fx_dir.x) * c;
		c.y -= 0.35 * t * t;  // retombe
		c = rot(-fx_dir.x) * c;
		float rad = (0.035 + 0.05 * h3) * (1.0 - 0.6 * t) * smoothstep(0.0, 0.04, age);
		vec2 rel = p - c;
		vec2 lr = vec2(dot(rel, ad) * 0.6, dot(rel, vec2(-ad.y, ad.x)));  // larme étirée dans sa course
		float g = length(lr) - rad;
		if (k >= 7) {
			d2 = min(d2, g);
		} else {
			dd = min(dd, g);
		}
	}
	d = smin(d, dd, 0.035);
	float aa = max(fwidth(d), 0.003);
	float cov = 1.0 - smoothstep(-aa, aa, d);
	float cov2 = (1.0 - smoothstep(-aa, aa, d2)) * (1.0 - cov);
	// déchirure : l'encre se casse en poils en fin de vie (le centre d'abord)
	float hair = vnoise(p * 9.0 + seed) * 0.6 + vnoise(p * 23.0 - seed) * 0.4;
	float er = smoothstep(t * 1.1 - 0.15, t * 1.1 + 0.05, hair + 0.15 * smoothstep(0.0, 0.5, length(p)));
	// reflet humide : un croissant clair en haut à gauche du cœur
	float hl = (1.0 - smoothstep(0.0, 0.05, abs(length(p - vec2(-0.05, 0.06)) - R * 0.55))) * step(p.x + p.y * 0.3, 0.0);
	vec3 col = mix(fx_col.rgb, vec3(0.85, 0.88, 0.94), hl * 0.35 * (1.0 - t));
	vec3 outc = mix(col, fx_col2.rgb, cov2 / max(cov + cov2, 0.001));
	float a = (cov * fx_col.a + cov2 * fx_col2.a) * er;
	return vec4(outc, a);
}

// --- 1 : tranchant (coup porté)
vec4 cut(float age, float life, float seed) {
	float t = clamp(age / max(life, 0.01), 0.0, 1.0);
	vec2 p = rot(-fx_dir.x - 0.35 + (hash12(vec2(seed, 1.0)) - 0.5) * 0.5) * q;
	float g = 1.0 - pow(1.0 - clamp(t / 0.35, 0.0, 1.0), 2.0);
	float thin = 1.0 - 0.75 * smoothstep(0.3, 1.0, t);
	float strong = fx_dir.y;
	// trait long (sens du coup) : fuseau effilé aux deux bouts
	float L1 = (0.6 + 0.4 * g) * (0.85 + 0.15 * strong);
	float x1 = p.x / L1;
	float w1 = 0.12 * thin * (1.0 - x1 * x1) * (0.85 + 0.3 * strong);
	float d1 = abs(p.y + 0.04 * x1 * x1) - w1;
	d1 = max(d1, abs(x1) - 1.0);
	// trait court en travers
	vec2 p2 = rot(1.75) * p;
	float L2 = (0.32 + 0.22 * g) * (0.8 + 0.2 * strong);
	float x2 = p2.x / L2;
	float w2 = 0.085 * thin * (1.0 - x2 * x2);
	float d2 = max(abs(p2.y) - w2, abs(x2) - 1.0);
	float d = min(d1, d2);
	// éclats secs autour
	float fl = 10.0;
	for (int k = 0; k < 6; k++) {
		float fk = float(k);
		float h1 = hash12(vec2(fk * 3.3, seed + 4.0));
		float h2 = hash12(vec2(fk * 1.7, seed + 6.0));
		float ang = fk * 1.047 + h1 * 0.6;
		vec2 ad = vec2(cos(ang), sin(ang));
		float r0 = 0.35 + 0.5 * g * (0.6 + 0.4 * h2);
		fl = min(fl, taper(p, ad * r0, ad * (r0 + 0.18 * (1.0 - t)), 0.03 * thin, 0.004));
	}
	float aa = max(fwidth(d), 0.003);
	float rimw = 0.035;
	float body = 1.0 - smoothstep(-aa, aa, d + rimw);
	float ink = 1.0 - smoothstep(-aa, aa, d);
	float flc = 1.0 - smoothstep(-aa, aa, fl);
	// poils secs vers les bouts des traits
	float hair = vnoise(vec2(p.x * 3.0, p.y * 30.0) + seed);
	float dry = smoothstep(0.55, 1.0, abs(x1)) * 0.8 + t * 0.6;
	float keep = smoothstep(dry * 0.6, dry * 0.6 + 0.2, hair);
	vec3 col = mix(fx_col.rgb, fx_col2.rgb, body);
	float a = max(ink * keep, flc * 0.9) * (1.0 - smoothstep(0.7, 1.0, t));
	col = mix(col, fx_col.rgb, flc * (1.0 - ink));
	return vec4(col, a * mix(fx_col.a, fx_col2.a, body));
}

// --- 2 : éclat d'un élément
vec4 flare(float age, float life, float seed) {
	float t = clamp(age / max(life, 0.01), 0.0, 1.0);
	float r = length(q);
	float ang = atan(q.y, q.x) + seed * 6.2832;
	float grow = 1.0 - pow(1.0 - clamp(t / 0.3, 0.0, 1.0), 3.0);
	float back = 1.0 - 0.75 * smoothstep(0.45, 1.0, t);
	// rayons : chaque secteur a sa longueur (8 longs, 8 courts entre)
	float n = 9.0;
	float sec = ang / 6.2832 * n;
	float ci = floor(sec);
	float cf = fract(sec) - 0.5;
	float h = hash12(vec2(mod(ci, n), seed * 3.0));
	float len = (0.55 + 0.45 * h) * grow * back;
	float wid = (0.22 + 0.1 * h) * (1.0 - r / max(len, 0.001));
	float ray = 1.0 - smoothstep(wid - 0.06, wid, abs(cf));
	ray *= step(r, len);
	// cœur
	float Rc = 0.32 * grow * (1.0 - 0.5 * t);
	float core = 1.0 - smoothstep(Rc - 0.05, Rc, r + (vnoise(q * 5.0 + seed) - 0.5) * 0.08);
	float shape = max(ray, core);
	// contour : bande au bord de la forme (léger sous-échantillonnage du champ par décalage du rayon)
	float rimz = max((1.0 - smoothstep(wid - 0.06 - 0.1, wid - 0.1, abs(cf))) * step(r, len - 0.05), 1.0 - smoothstep(Rc - 0.13, Rc - 0.08, r));
	float inner = clamp(rimz, 0.0, 1.0);
	// poils secs au bout des rayons
	float hair = vnoise(vec2(r * 4.0, cf * 18.0) + seed * 5.0);
	float keep = smoothstep(0.0, 0.25, hair + 0.55 - r / max(len, 0.001) * 0.7 - t * 0.35);
	vec3 col = mix(fx_col.rgb, fx_col2.rgb, inner);
	float a = shape * keep * mix(fx_col.a, fx_col2.a, inner) * (1.0 - smoothstep(0.75, 1.0, t));
	return vec4(col, a);
}

void fragment() {
	float age = fx_state.x;
	float life = fx_state.y;
	float seed = fx_state.z;
	float mode = fx_state.w;
	vec4 c;
	if (mode < 0.5) {
		c = splat(age, life, seed);
	} else if (mode < 1.5) {
		c = cut(age, life, seed);
	} else {
		c = flare(age, life, seed);
	}
	ALBEDO = c.rgb;
	ALPHA = clamp(c.a, 0.0, 1.0);
}
