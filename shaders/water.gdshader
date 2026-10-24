shader_type spatial;
render_mode diffuse_toon, specular_disabled;

// Le vide sous l'arène (mer, étang, lave, encre) : fond en lavis qui dérive lentement, rubans de vague
// à la Hokusai (traits brisés et animés, effacés au loin), écume au pied du cadre de l'arène.
// Au large seulement (jamais au pied des plateformes ni dans les fosses) : motif seigaiha d'éventails
// de vagues, très léger, coupé en rendu allégé.

uniform vec4 deep : source_color = vec4(0.07, 0.14, 0.25, 1.0);
uniform vec4 shallow : source_color = vec4(0.12, 0.23, 0.37, 1.0);
uniform vec4 foam : source_color = vec4(0.91, 0.93, 0.94, 1.0);
uniform float foam_k = 0.35;
uniform float flow = 1.0;
uniform float band = 0.8;
uniform vec4 shore_rect = vec4(-4.6, -8.6, 4.6, 8.6);
// sanctuaire : jusqu'à cinq rectangles de plus (quai, allée, parvis…), l'écume suit leur union ;
// rejetés très loin quand ils ne servent pas (coût : quelques distances par pixel)
uniform vec4 shore_b = vec4(9000.0, 9000.0, 9001.0, 9001.0);
uniform vec4 shore_c = vec4(9000.0, 9000.0, 9001.0, 9001.0);
uniform vec4 shore_d = vec4(9000.0, 9000.0, 9001.0, 9001.0);
uniform vec4 shore_e = vec4(9000.0, 9000.0, 9001.0, 9001.0);
uniform vec4 shore_f = vec4(9000.0, 9000.0, 9001.0, 9001.0);
uniform float shore_k = 0.5;
uniform float sei_k = 0.0;  // force du motif seigaiha (0 : aucun)
uniform float sei_size = 0.55;  // rayon d'un éventail (m)
uniform bool fine = true;
uniform sampler2D noise : hint_default_white, filter_linear_mipmap, repeat_enable;  // bruit partagé (toon.gd)

varying vec3 v_world;

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

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Distance signée au rectangle r = (x min, z min, x max, z max) : négative dedans.
float rect_sd(vec2 p, vec4 r) {
	vec2 c = (r.xy + r.zw) * 0.5;
	vec2 hs = (r.zw - r.xy) * 0.5;
	vec2 q = abs(p - c) - hs;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
}

// Seigaiha : éventails de cercles concentriques en rangées décalées, chaque rangée recouvrant la
// précédente (vers +z, le bas de l'écran). Renvoie l'intensité du trait (0..1).
float seigaiha(vec2 p) {
	vec2 q = p / sei_size;
	float sv = 0.5;
	float k = floor((q.y + 1.0) / sv);
	float d = 1.0;
	bool found = false;
	for (int i = 0; i < 4; i++) {
		float row = k - float(i);
		float off = mod(row, 2.0);
		float cx = floor((q.x - off) * 0.5 + 0.5) * 2.0 + off;
		float dd = length(q - vec2(cx, row * sv));
		if (!found && dd < 1.0) {
			d = dd;
			found = true;
		}
	}
	// trois arcs par éventail ; s'efface quand les traits deviennent plus fins qu'un pixel
	float f = d * 3.0;
	float fw = fwidth(f);
	float ring = smoothstep(0.38 - fw, 0.38 + fw, abs(fract(f) - 0.5));
	return ring * clamp(1.0 - fw * 2.5, 0.0, 1.0);
}

void fragment() {
	vec2 p = v_world.xz;
	float t = TIME * flow;
	// fond : grandes taches de profondeur qui dérivent (bruit partagé : une lecture par octave)
	float n = texture(noise, p * 0.031 + vec2(t * 0.006, t * 0.0037)).r;
	if (fine) {
		n = n * 0.65 + texture(noise, p * 0.09 - vec2(t * 0.0095, -t * 0.003)).g * 0.35;
	}
	vec3 col = mix(deep.rgb, shallow.rgb, smoothstep(0.2, 0.8, n));
	// grain du washi sur le lavis
	col *= 1.0 + (texture(noise, p * 0.7).a - 0.5) * 0.09;
	// rubans de vague : lignes ondulées, brisées en traits de pinceau
	float v = p.y * band + sin(p.x * 0.42 + t * 0.33 + n * 3.5) * 0.55 + t * 0.09;
	float fv = abs(fract(v) - 0.5);
	float fw = fwidth(v);
	float wl = 1.0 - smoothstep(0.07 - fw, 0.07 + fw, fv);
	float row = floor(v);
	float dash = smoothstep(0.4, 0.62, vnoise(vec2(p.x * 0.55 - t * 0.12 + row * 3.7, row * 1.9)));
	float far_k = clamp(1.3 - fw * 3.5, 0.0, 1.0);
	wl *= dash * far_k;
	// trait d'encre sous chaque ruban (la planche de trait de l'estampe), puis l'écume
	float fk = abs(fract(v + 0.13) - 0.5);
	float key = (1.0 - smoothstep(0.045 - fw, 0.045 + fw, fk)) * dash * far_k;
	col = mix(col, deep.rgb * 0.55, key * foam_k * 0.8);
	col = mix(col, foam.rgb, wl * foam_k);
	// pied du cadre de l'arène, côté mer : ombre portée, liseré d'écume, ondes qui s'éloignent
	// union des rectangles : la plus petite des distances (exacte hors des plateformes)
	float sd = rect_sd(p, shore_rect);
	sd = min(sd, rect_sd(p, shore_b));
	sd = min(sd, rect_sd(p, shore_c));
	sd = min(sd, rect_sd(p, shore_d));
	sd = min(sd, rect_sd(p, shore_e));
	sd = min(sd, rect_sd(p, shore_f));
	float outside = step(0.0, sd);
	float od = max(sd, 0.0);
	float close = (1.0 - smoothstep(0.0, 1.6, od)) * outside;
	// (plus sombre au pied des plateformes : l'eau passe sous leur ombre, la dalle se détache du vide)
	col *= 1.0 - 0.45 * close * close;
	float rf = od * 1.4 - t * 0.3;
	float rw = fwidth(rf);
	float rip = abs(fract(rf) - 0.5);
	float ring = 1.0 - smoothstep(0.08 - rw, 0.08 + rw, rip);
	float lip = (1.0 - smoothstep(0.0, 0.1 + rw, od)) * outside;
	col = mix(col, foam.rgb, clamp(ring * close * close * shore_k + lip * shore_k * 0.8, 0.0, 1.0));
	// seigaiha au large : nul au pied du cadre (lisibilité), monte entre 1.2 et 3 m
	if (fine && sei_k > 0.0) {
		float far_k = smoothstep(1.2, 3.0, od) * outside;
		col = mix(col, mix(col, foam.rgb, 0.55), seigaiha(p + vec2(0.0, t * 0.05)) * sei_k * far_k);
	}
	ALBEDO = col;
	ROUGHNESS = 0.6;
}
