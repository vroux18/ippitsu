shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Effets au sol peints à l'encre (vfx.gd : ring, _shock, _decal, scorch) : UN quad partagé (PlaneMesh 2 × 2, plan
// XZ, le même que les taches d'encre liquide) et deux matières partagées (sous les annonces d'attaque / sous tout),
// les réglages de chaque effet en paramètres d'instance. Un seul appel de dessin par effet, quel que soit le dessin.
// `q` est en rayons d'effet (1 = rayon final). L'âge est posé par le script (jamais TIME : l'effet se fige avec le
// jeu, la pause et les captures).
//
// Sortes (fx_state.w) :
//   0 ENSŌ : onde de choc au pinceau. Le pinceau trace le cercle d'un geste (attaque pointue, pression qui ondule,
//     queue qui chevauche le départ) pendant que l'anneau s'ouvre ; contour d'encre, corps teinté, filet clair ;
//     poils secs (kasure) qui gagnent le trait en vieillissant ; lavis dilué à l'intérieur ; gouttelettes projetées
//     au-delà du bord ; séchage en fin de vie (le trait se casse en poils).
//   1 BRÛLURE : roussi au bord déchiqueté, suie marbrée et craquelée ; braises vives dans les fentes et au bord,
//     qui refroidissent (or -> vermillon -> sombre) ; auréole de fumée autour ; effacement par érosion.
//   2 OMBRE : encre violette qui fuse dans le papier : un cœur sombre, des digitations qui rampent vers
//     l'extérieur, bord mouillé plus foncé, lavis pâle ; séchage puis érosion.
//   3 EAU : comme l'ensō, au bleu de Prusse qui s'éclaircit vers l'écume, griffes d'écume à la Hokusai sur le bord
//     extérieur et embruns.

const float EXT = 1.6;  // demi-côté du quad, en rayons d'effet (gouttes et griffes comprises) ; vfx.FX_EXT

instance uniform vec4 fx_body : source_color = vec4(0.1, 0.1, 0.12, 1.0);  // corps du trait (teinte de l'école)
instance uniform vec4 fx_edge : source_color = vec4(0.1, 0.1, 0.12, 1.0);  // contour (encre)
instance uniform vec4 fx_core : source_color = vec4(1.0, 1.0, 1.0, 1.0);  // filet clair / braise / écume
// x : âge (s), y : vie (s), z : graine, w : sorte
instance uniform vec4 fx_state = vec4(0.0, 0.5, 0.0, 0.0);

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

float fbm2(vec2 p) {
	return vnoise(p) * 0.65 + vnoise(p * 2.13 + 17.3) * 0.35;
}

void vertex() {
	q = VERTEX.xz * EXT;
}

// pression du pinceau le long de l'ensō (s : 0 attaque .. 1,08 fin de la queue)
float press(float s, float seed) {
	float att = smoothstep(0.0, 0.07, s);
	float tail = 1.0 - 0.75 * smoothstep(0.72, 1.08, s);
	float und = 0.84 + 0.16 * sin(s * 19.0 + seed * 3.0) + 0.06 * sin(s * 47.0 + seed);
	return att * tail * und;
}

// --- 0 / 3 : ensō (onde de choc) ; renvoie la couleur, alpha dans .a
vec4 enso(float age, float life, float seed, bool water) {
	float t = clamp(age / max(life, 0.01), 0.0, 1.0);
	float r = length(q);
	float ang = atan(q.y, q.x);
	// l'anneau s'ouvre (vite puis lentement)
	float ko = clamp(t / 0.6, 0.0, 1.0);
	float R = mix(0.2, 1.0, 1.0 - (1.0 - ko) * (1.0 - ko) * (1.0 - ko));
	// le pinceau fait le tour d'un geste : le trait est peint jusqu'à `paint` (en tours)
	float paint = 1.08 * smoothstep(0.0, 0.26, t);
	float a0 = seed * 6.2832;
	float u = fract((ang - a0) / 6.2832);
	// deux passages possibles (la queue chevauche l'attaque) : on garde le plus large
	float s1 = u;
	float s2 = u + 1.0;
	float w1 = s1 <= paint ? press(s1, seed) : 0.0;
	float w2 = s2 <= paint ? press(s2, seed) : 0.0;
	float s = w2 > w1 ? s2 : s1;
	float pw = max(w1, w2);
	// bout du pinceau en train de peindre : un peu plus gras (l'encre s'accumule sous la pointe)
	float head = smoothstep(0.08, 0.0, abs(s - paint)) * (1.0 - step(1.07, paint));
	float W = 0.105 * (1.0 - 0.3 * t) * (pw + 0.25 * head);
	// bord qui boit le papier
	float en = vnoise(vec2(ang * 9.0 + seed * 5.0, r * 6.0)) - 0.5;
	float across = (r - R) / max(W, 0.001);  // -1 dedans .. 1 dehors
	float d = abs(r - R) - W + en * 0.018;
	float aa = max(fwidth(r), 0.002);
	float cov = 1.0 - smoothstep(-aa, aa, d);
	// poils secs : stries le long du trait, qui gagnent avec l'âge et vers la queue
	float hair = vnoise(vec2(s * 5.0 + seed, across * 4.5 + 7.0)) * 0.6 + vnoise(vec2(s * 13.0 - seed, across * 11.0)) * 0.4;
	float dry = clamp(t * 1.25 - 0.18 + 0.35 * smoothstep(0.6, 1.08, s) + 0.25 * abs(across) * abs(across), 0.0, 1.0);
	float keep = smoothstep(dry * 0.75, dry * 0.75 + 0.16, hair);
	cov *= mix(1.0, keep, clamp(dry * 1.8, 0.0, 1.0));
	// couches : contour d'encre dehors et dedans, corps, filet clair côté extérieur
	float ae = abs(across);
	vec3 body = fx_body.rgb;
	if (water) {
		// bleu de Prusse au creux, qui s'éclaircit vers l'écume côté extérieur
		body = mix(fx_edge.rgb * 1.4 + 0.02, fx_body.rgb, smoothstep(-0.9, 0.3, across));
	}
	vec3 col = mix(body, fx_edge.rgb, smoothstep(0.58, 0.8, ae));
	float core = (1.0 - smoothstep(0.08, 0.3, abs(across - 0.28))) * (1.0 - 0.6 * t);
	col = mix(col, fx_core.rgb, core * fx_core.a);
	float a = cov * mix(fx_body.a, fx_edge.a, smoothstep(0.58, 0.8, ae));
	// lavis : le corps dilué au dedans de l'anneau, marbré, plus dense près du trait
	float mott = fbm2(q * 3.2 + seed * 7.0);
	float wash = (1.0 - smoothstep(R * 0.98, R, r)) * smoothstep(0.0, R, r) * smoothstep(0.0, 0.08, t);
	wash *= (0.45 + 0.55 * mott) * 0.22 * (1.0 - t) * fx_body.a;
	vec3 wc = mix(fx_body.rgb, vec3(dot(fx_body.rgb, vec3(0.333))), 0.2);
	// gouttelettes projetées au-delà du bord, dans le sens de l'ouverture
	float cell = floor(u * 26.0);
	float hc = hash12(vec2(cell, seed * 13.0));
	float hd = hash12(vec2(cell + 3.1, seed * 7.0));
	float he = hash12(vec2(cell + 9.7, seed * 3.0));
	float ca = (cell + 0.5 + (hd - 0.5) * 0.6) / 26.0 * 6.2832 + a0;
	float cr = R + W + 0.04 + hc * 0.2 * smoothstep(0.0, 0.5, t);
	vec2 cp = vec2(cos(ca), sin(ca)) * cr;
	float drad = (0.012 + 0.026 * he * he) * step(0.45, hd) * step(s, paint + 0.02);
	float dropc = 1.0 - smoothstep(drad - aa, drad + aa, length(q - cp));
	dropc *= 1.0 - smoothstep(0.55, 0.95, t);
	if (water) {
		// griffes d'écume (Hokusai) : doigts courbés qui se tendent vers l'extérieur sur le bord
		float cl = fract(u * 16.0 + seed);
		float hk = hash12(vec2(floor(u * 16.0 + seed), seed));
		float L = (0.07 + 0.11 * hk) * smoothstep(0.08, 0.4, t);
		float rr = (r - (R + W * 0.4)) / max(L, 0.001);  // 0 au pied du doigt .. 1 au bout
		float cxc = cl - 0.5 - 0.28 * rr * rr;  // le doigt se recourbe (crochet)
		float hw = 0.2 * pow(max(1.0 - rr, 0.0), 0.7);
		float claw = (1.0 - smoothstep(hw - 0.05, hw, abs(cxc))) * step(0.0, rr) * step(rr, 1.0);
		claw *= step(s, paint) * step(0.22, hk) * (1.0 - smoothstep(0.6, 0.95, t));
		col = mix(col, fx_core.rgb, claw);
		a = max(a, claw * 0.95);
		// embruns : les gouttelettes sont d'écume
		col = mix(col, fx_core.rgb, dropc * (1.0 - cov));
	} else {
		col = mix(col, fx_edge.rgb, dropc * (1.0 - cov));
	}
	a = max(a, dropc * 0.9 * fx_edge.a);
	// le lavis passe sous le trait
	vec3 outc = mix(wc, col, clamp(a / max(a + wash, 0.001) * 1.5, 0.0, 1.0));
	float outa = a + wash * (1.0 - a);
	// fin de vie : le trait sec s'efface
	outa *= 1.0 - smoothstep(0.78, 1.0, t);
	return vec4(outc, outa);
}

// --- 1 : brûlure
vec4 scorch(float age, float life, float seed) {
	float t = clamp(age / max(life, 0.01), 0.0, 1.0);
	vec2 p = q + (vec2(vnoise(q * 1.9 + seed), vnoise(q * 1.9 + seed + 11.0)) - 0.5) * 0.25;
	float r = length(p);
	vec2 dir = p / max(r, 0.0001);
	float grow = 1.0 - pow(1.0 - clamp(age / 0.12, 0.0, 1.0), 3.0);
	float Rb = (0.25 + 0.75 * grow) * (0.72 + 0.32 * fbm2(dir * 2.3 + seed * 3.1) + 0.08 * vnoise(dir * 9.0 + seed));
	float d = r - Rb;
	float aa = max(fwidth(d), 0.002);
	float cov = 1.0 - smoothstep(-aa * 2.0, aa * 2.0, d);
	// suie : marbrée, plus dense au bord (le papier roussi fonce sur son pourtour)
	float mott = fbm2(q * 4.3 + seed * 5.0);
	float rim = smoothstep(-0.28, -0.02, d);
	vec3 soot = fx_body.rgb;
	vec3 col = mix(soot * 1.35 + 0.03, soot * 0.7, rim * 0.6 + mott * 0.4);
	float a = cov * fx_body.a * (0.62 + 0.38 * rim) * (0.75 + 0.25 * mott);
	// fentes de braise : lignes de niveau du bruit
	float cr = abs(vnoise(q * 5.5 + seed * 2.0) - 0.5);
	float crack = (1.0 - smoothstep(0.02, 0.06, cr)) * smoothstep(-0.55, -0.12, d) * cov;
	// braise du bord, qui refroidit
	float edge = (1.0 - smoothstep(0.0, 0.09, abs(d + 0.03))) * (0.6 + 0.4 * vnoise(dir * 14.0 + seed));
	float heat = exp(-t * 4.2) * smoothstep(0.0, 0.06, age);
	float glow = clamp((crack * 0.9 + edge) * heat * 1.4, 0.0, 1.0);
	vec3 hot = mix(fx_edge.rgb, fx_core.rgb, clamp(heat * 1.4 * glow, 0.0, 1.0));
	col = mix(col, hot, glow);
	a = max(a, glow * 0.95 * smoothstep(-aa * 3.0, 0.02, -d + 0.06));
	// fumée : auréole brune hors du bord
	float halo = (1.0 - smoothstep(0.0, 0.32, d)) * step(0.0, d) * 0.28 * fx_body.a * (0.5 + 0.5 * mott);
	col = mix(col, soot * 1.6 + 0.08, halo * (1.0 - a));
	a = a + halo * (1.0 - a);
	// érosion finale : l'intérieur clair part d'abord
	float fade = smoothstep(0.55, 1.0, t);
	float er = smoothstep(fade * 1.15 - 0.1, fade * 1.15 + 0.08, mott * 0.7 + rim * 0.3);
	return vec4(col, a * er * (1.0 - fade * 0.4));
}

// --- 2 : ombre qui fuse
vec4 shade(float age, float life, float seed) {
	float t = clamp(age / max(life, 0.01), 0.0, 1.0);
	vec2 p = q + (vec2(vnoise(q * 2.2 + seed), vnoise(q * 2.2 + seed + 5.0)) - 0.5) * 0.18;
	float r = length(p);
	float ang = atan(p.y, p.x);
	vec2 dir = p / max(r, 0.0001);
	float grow = 1.0 - pow(1.0 - clamp(age / 0.16, 0.0, 1.0), 3.0);
	// l'encre fuse : digitations qui rampent vers l'extérieur (lentement, après le jaillissement)
	float creep = smoothstep(0.05, 0.7, t);
	float fing = pow(vnoise(vec2(ang * 2.0 + seed * 9.0, seed)) * 0.5 + vnoise(dir * 3.5 + seed * 3.0) * 0.5, 2.6);
	float Rb = 0.48 * grow * (0.82 + 0.3 * fbm2(dir * 2.0 + seed * 2.0)) + fing * (0.25 + 0.55 * creep) * grow;
	float d = r - Rb;
	float aa = max(fwidth(d), 0.002);
	float fib = vnoise(q * 22.0 + seed);
	d += (fib - 0.5) * (0.03 + 0.05 * creep);
	float cov = 1.0 - smoothstep(-aa - 0.02 * creep, aa + 0.02 * creep, d);
	float rim = 1.0 - smoothstep(0.0, 0.1, -d);
	float mott = fbm2(q * 3.6 + seed * 4.0);
	// cœur sombre, lavis violet, bord mouillé plus foncé
	vec3 col = mix(fx_edge.rgb, fx_body.rgb, smoothstep(0.05, 0.42, r) * 0.8 + mott * 0.2);
	col = mix(col, fx_edge.rgb * 0.8, rim * 0.7);
	float a = cov * mix(0.55 + 0.35 * mott, 1.0, max(rim, 1.0 - smoothstep(0.0, 0.25, r))) * fx_body.a;
	// lueur pâle juste au bord tant que c'est frais
	float glw = (1.0 - smoothstep(0.0, 0.07, abs(d - 0.02))) * (1.0 - smoothstep(0.0, 0.5, t)) * 0.6;
	col = mix(col, fx_core.rgb, glw * (1.0 - rim * 0.5));
	a = max(a, glw * 0.7);
	float fade = smoothstep(0.6, 1.0, t);
	float er = smoothstep(fade * 1.15 - 0.1, fade * 1.15 + 0.08, mott * 0.6 + rim * 0.4);
	return vec4(col, a * er);
}

void fragment() {
	float age = fx_state.x;
	float life = fx_state.y;
	float seed = fx_state.z;
	float mode = fx_state.w;
	vec4 c;
	if (mode < 0.5) {
		c = enso(age, life, seed, false);
	} else if (mode < 1.5) {
		c = scorch(age, life, seed);
	} else if (mode < 2.5) {
		c = shade(age, life, seed);
	} else {
		c = enso(age, life, seed, true);
	}
	ALBEDO = c.rgb;
	ALPHA = clamp(c.a, 0.0, 1.0);
}
