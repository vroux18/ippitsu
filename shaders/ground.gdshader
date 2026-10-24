shader_type spatial;
render_mode diffuse_toon, specular_disabled;

// Sol de l'arène : tuiles en MultiMesh (boîte unité mise à l'échelle par instance).
// Teinte qui varie d'une tuile à l'autre (vers une 2e teinte), joints usés et assombris, mousse dans
// les joints, plages délavées, pied des flancs dans l'ombre, grain du papier, mouchetis d'encre.
// Matière selon le style (arena._ground_mat) : fil du bois (veines, nœuds, clous aux bouts des planches),
// pierre (coups de ciseau, fissures, piqûres), cendre (fissures à braise), neige (étincelles, sastrugi),
// papier (fibres, lavis) ; auréoles d'eau et taches d'encre ; marques au pinceau au sol (atlas Toon.decal_tex :
// kanji du monde et autres, seigaiha et asanoha gravés par endroits, auréoles, éclaboussures), rares.
// Flancs : strates et hachures de gravure côté ombre. Jamais plus clair en moyenne que la couleur de base.
// Bruits : une texture partagée (Toon.noise_tex : r doux, g fin tordu, b cellules, a grain) lue en repère monde,
// bien moins chère que des hachages par pixel sur téléphone ; le hachage ne sert qu'aux tirages par cellule.

uniform vec4 albedo : source_color = vec4(0.6, 0.56, 0.5, 1.0);
uniform vec4 alt : source_color = vec4(0.5, 0.48, 0.45, 1.0);
uniform vec4 ink : source_color = vec4(0.106, 0.102, 0.118, 1.0);
uniform vec4 moss : source_color = vec4(0.32, 0.38, 0.27, 1.0);
uniform vec4 ember : source_color = vec4(0.77, 0.6, 0.27, 1.0);  // braise au fond des fissures (cendre)
uniform float alt_k = 0.0;
uniform float moss_k = 0.0;
uniform float wear_k = 0.0;
uniform float tile_var = 0.07;
uniform float edge_ao = 0.25;
uniform float edge_w = 0.08;
uniform float side_ao = 0.4;
uniform float grain = 0.06;
uniform vec2 grain_scale = vec2(5.0, 5.0);
uniform float speckle = 0.2;
uniform bool fine = true;
// matière (0 : aucune) : veines du bois, clous, fissures / coups de ciseau, taches (auréoles d'eau, encre),
// braise des fissures, étincelles de neige, marques au pinceau (atlas), motifs gravés (seigaiha / asanoha)
uniform float vein_k = 0.0;
uniform float nail_k = 0.0;
uniform float crack_k = 0.0;
uniform float chisel_k = 0.0;
uniform float stain_k = 0.0;
uniform float ember_k = 0.0;
uniform float sparkle_k = 0.0;
uniform float decal_k = 0.0;
uniform float pattern_k = 0.0;
uniform float kanji_tile = 0.0;  // case de l'atlas du kanji du monde (0..10)
uniform float strata_k = 0.0;  // strates des flancs
uniform float hatch_k = 0.0;  // hachures des flancs à l'ombre
uniform sampler2D noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D decals : hint_default_black, filter_linear_mipmap, repeat_disable;
// biseau des arêtes du dessus (m) : la normale s'incline vers le bord, la lumière du soleil fait le reste
// (arête tournée vers lui claire, arête opposée dans l'ombre) : relief des dalles et des planches sans géométrie
uniform float bevel = 0.09;
uniform float bevel_k = 1.1;
uniform float bevel_shade = 0.7;  // le biseau marque aussi la couleur (arête au soleil claire, arête opposée sombre)
uniform vec3 sun_dir = vec3(0.47, -0.64, -0.6);  // sens de la lumière du soleil (main : rotation -40°, -38°)
// dessus encré (bords des plateformes : liseré d'encre au sommet, flanc en dégradé dessous)
uniform float top_ink = 0.0;

varying vec3 v_local;
varying vec3 v_scale;
varying vec3 v_world;
varying vec3 v_nw;
varying float v_ny;
varying float v_seed;

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

void vertex() {
	v_local = VERTEX;
	v_ny = NORMAL.y;
	v_scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_nw = normalize(mat3(MODEL_MATRIX) * (NORMAL / max(v_scale, vec3(0.0001))));
	// une graine par tuile (centre de l'instance)
	v_seed = hash12(MODEL_MATRIX[3].xz * 1.37 + vec2(MODEL_MATRIX[3].y * 7.1, 0.0));
}

// Marque de l'atlas (case `tile`, 4 × 4) au point `uv` (0..1 dans la marque) ; dérivées continues du monde.
float decal_at(float tile, vec2 uv, vec2 ddx, vec2 ddy) {
	vec2 tuv = (vec2(mod(tile, 4.0), floor(tile / 4.0)) + clamp(uv, vec2(0.004), vec2(0.996))) * 0.25;
	return textureGrad(decals, tuv, ddx * 0.25, ddy * 0.25).r;
}

// Une marque par cellule de `cs` m (probabilité `p`), taille `s0`..`s1`, inclinaison ±`tilt`, grille décalée de
// `salt` ; `kind` 0 : kanji (celui du monde, un autre) ou tache, 1 : motif gravé. Renvoie l'encre (0..1).
float decal_cells(vec2 wp, float cs, float p, float s0, float s1, float tilt, float salt, int kind, vec2 dwx, vec2 dwy) {
	vec2 cell = floor(wp / cs) + vec2(salt);
	float h = hash12(cell);
	if (h >= p) {
		return 0.0;
	}
	float h2 = hash12(cell + vec2(7.0, 3.0));
	float h3 = hash12(cell + vec2(19.0, 11.0));
	float h4 = hash12(cell + vec2(31.0, 23.0));
	float h5 = hash12(cell + vec2(43.0, 37.0));
	vec2 c = (cell - vec2(salt) + 0.5 + (vec2(h2, h3) - 0.5) * 0.45) * cs;
	float sz = mix(s0, s1, h4);
	float ang = (h5 - 0.5) * 2.0 * tilt;
	vec2 d = wp - c;
	float ca = cos(ang);
	float sa = sin(ang);
	vec2 q = vec2(ca * d.x + sa * d.y, -sa * d.x + ca * d.y) / sz + 0.5;
	if (q.x < 0.0 || q.x > 1.0 || q.y < 0.0 || q.y > 1.0) {
		return 0.0;
	}
	float tile = 0.0;
	if (kind == 0) {
		// kanji : celui du monde une fois sur deux, sinon un autre ; taches (13..15) parfois
		float h6 = hash12(cell + vec2(53.0, 59.0));
		if (h6 < 0.3) {
			tile = 13.0 + floor(h5 * 3.0);
		} else if (h6 < 0.65) {
			tile = kanji_tile;
		} else {
			tile = floor(h4 * 11.0);
		}
	} else {
		tile = (h5 < 0.5) ? 11.0 : 12.0;  // motifs gravés : seigaiha ou asanoha
	}
	return decal_at(tile, q, dwx / sz, dwy / sz);
}

void fragment() {
	// teinte de la tuile : entre la couleur de base et la 2e teinte, puis légère variation de valeur
	vec3 col = mix(albedo.rgb, alt.rgb, alt_k * v_seed * v_seed);
	col *= 1.0 + (fract(v_seed * 7.13) - 0.5) * 2.0 * tile_var;
	float top = smoothstep(0.5, 0.9, v_ny);
	// joints : distance (m) au bord de la face du dessus
	vec2 hs = 0.5 * v_scale.xz;
	vec2 q = v_local.xz * v_scale.xz;  // position sur la face (m), centre en 0
	vec2 dd = hs - abs(q);
	float e = min(dd.x, dd.y);
	float joint = 1.0 - smoothstep(0.0, edge_w, e);
	// flancs : plus sombres vers le bas (contact, ombre du dessous)
	float h = clamp(v_local.y + 0.5, 0.0, 1.0);
	col *= 1.0 - side_ao * (1.0 - top) * (1.0 - h);
	vec2 wp = v_world.xz;
	vec2 pp = wp + vec2(v_seed * 13.7, v_seed * 5.3);  // décalé par tuile : deux planches voisines diffèrent
	// bruits partagés : doux (r), fin (g), cellules (b), grain (a) à deux échelles
	vec4 n1 = texture(noise, wp * 0.21);
	vec4 n2 = texture(noise, pp * vec2(0.9, 0.3) + vec2(0.37, 0.11));
	if (top > 0.01) {
		// grain du papier / de la pierre
		float g = n2.a * 0.6 + texture(noise, wp * grain_scale * 0.23).a * 0.4;
		col *= 1.0 + (g - 0.5) * 2.0 * grain * top;
		// plages délavées (usure) : la couleur se ternit, sans s'éclaircir
		float wear = smoothstep(0.5, 0.8, n1.r);
		float lum = dot(col, vec3(0.3, 0.55, 0.15));
		col = mix(col, vec3(lum) * 0.98, wear * wear_k * top);
		// fil du bois : veines fines et longues le long de la planche (z), à peine ondulées, nœuds rares
		if (vein_k > 0.0) {
			vec4 nz = texture(noise, pp * vec2(0.5, 0.08) + vec2(0.23, 0.71));  // bruit étiré le long du fil
			float warp = (nz.r - 0.5) * 0.09 + (nz.g - 0.5) * 0.03;
			float rings = (pp.x + warp) * 7.0 + v_seed * 3.0;
			float fw = fwidth(rings);
			float ring = abs(fract(rings) - 0.5);
			float vein = 1.0 - smoothstep(0.03, 0.09 + fw, ring);
			vein *= clamp(1.3 - fw * 2.5, 0.0, 1.0) * smoothstep(0.25, 0.6, nz.g);  // traits interrompus
			col *= 1.0 - vein * vein_k * 0.13 * top;
			// nœud : cœur d'une cellule du bruit (le canal b vaut 1 au centre, 0 sur les bords), anneaux serrés autour
			float cellv = texture(noise, pp * 0.07 + vec2(0.61, 0.29)).b;
			float knot = smoothstep(0.8, 0.93, cellv);
			if (knot > 0.0) {
				float kr = abs(fract(cellv * 30.0) - 0.5);
				col *= 1.0 - knot * (0.2 + 0.2 * smoothstep(0.3, 0.5, kr)) * vein_k * top;
			}
		}
		// clous aux bouts de la planche (tête sombre, cerne de rouille)
		if (nail_k > 0.0 && hs.y > 0.3 && hs.x > 0.12) {
			vec2 nq = vec2(abs(q.x) - hs.x * 0.42, abs(q.y) - (hs.y - 0.11));
			float nd = length(nq);
			float head = 1.0 - smoothstep(0.012, 0.02, nd);
			float rust = (1.0 - smoothstep(0.02, 0.05, nd)) * (1.0 - head);
			col = mix(col, col * vec3(0.72, 0.6, 0.5), rust * 0.6 * nail_k * top);
			col = mix(col, ink.rgb * 1.6, head * nail_k * top);
		}
		// pierre : coups de ciseau (traits courts, sens propre à chaque dalle), fissures, piqûres
		if (chisel_k > 0.0) {
			float ang = v_seed * 6.2832;
			float u = (q.x * cos(ang) + q.y * sin(ang)) * 34.0;
			float fw = fwidth(u);
			float lines = 1.0 - smoothstep(0.1, 0.1 + fw * 1.5, abs(fract(u) - 0.5));
			lines *= smoothstep(0.42, 0.6, n2.g) * clamp(1.2 - fw * 2.0, 0.0, 1.0);
			col *= 1.0 - lines * 0.12 * chisel_k * top;
			float pits = smoothstep(0.78, 0.9, n2.a);
			col *= 1.0 - pits * 0.14 * chisel_k * top;
		}
		if (crack_k > 0.0) {
			float cv = texture(noise, pp * 0.35 + vec2(0.17, 0.83)).b;
			float crack = 1.0 - smoothstep(0.0, 0.055, cv);
			crack *= smoothstep(0.35, 0.55, n1.g);  // par endroits seulement
			col *= 1.0 - crack * 0.45 * crack_k * top;
			if (ember_k > 0.0) {
				float core = (1.0 - smoothstep(0.0, 0.02, cv)) * smoothstep(0.5, 0.7, n1.g);
				col = mix(col, ember.rgb, core * ember_k * top);
			}
		}
		// neige : étincelles, sastrugi (ondes bleutées très douces)
		if (sparkle_k > 0.0) {
			float sp = smoothstep(0.9, 0.97, texture(noise, wp * 1.7).a);
			col = mix(col, vec3(1.0), sp * 0.25 * sparkle_k * top);
			float sas = wp.x * 1.4 + wp.y * 0.25 + n1.r * 2.4;
			float fws = fwidth(sas);
			float rip = 1.0 - smoothstep(0.06, 0.12 + fws, abs(fract(sas) - 0.5));
			rip *= clamp(1.2 - fws * 2.0, 0.0, 1.0) * smoothstep(0.35, 0.6, n2.g);
			col *= 1.0 - rip * 0.07 * sparkle_k * top;
		}
		// auréoles d'eau et taches d'encre : plage ternie, bord plus sombre (l'eau laisse une marge)
		if (stain_k > 0.0) {
			float st = texture(noise, wp * 0.071 + vec2(0.53, 0.47)).r;
			float plage = smoothstep(0.6, 0.78, st);
			float bord = smoothstep(0.58, 0.61, st) * (1.0 - smoothstep(0.61, 0.66, st));
			col = mix(col, col * mix(vec3(0.84), ink.rgb / max(col, vec3(0.05)), 0.2), plage * 0.35 * stain_k * top);
			col = mix(col, ink.rgb, bord * 0.22 * stain_k * top);
		}
		// mousse : dans les joints et par plaques
		float mp = texture(noise, wp * 0.33 + vec2(0.2, 0.7)).r;
		float mz = smoothstep(0.5, 0.78, mp) * (0.35 + 0.65 * joint) * moss_k * top;
		col = mix(col, moss.rgb, clamp(mz, 0.0, 0.85));
		if (fine) {
			// mouchetis d'encre (pinceau secoué) : rares et à demi-teinte, pour ne jamais passer pour
			// un projectile ou une tache d'attaque
			float sp = texture(noise, wp * 2.3 + vec2(v_seed * 0.31, v_seed * 0.17)).a;
			float dots = smoothstep(0.86, 0.93, sp) * speckle * top;
			col = mix(col, ink.rgb, dots * 0.6);
		}
		// marques au pinceau et motifs gravés (atlas), coupés par un grain d'encre sèche
		if (decal_k > 0.0 || pattern_k > 0.0) {
			vec2 dwx = dFdx(wp);
			vec2 dwy = dFdy(wp);
			float dry = smoothstep(0.22, 0.5, n2.g + n2.a * 0.3);
			if (decal_k > 0.0) {
				float a = decal_cells(wp, 2.6, 0.26, 0.8, 1.5, 0.2, 0.0, 0, dwx, dwy);
				col = mix(col, ink.rgb, a * dry * 0.72 * decal_k * top);
			}
			if (pattern_k > 0.0) {
				float a = decal_cells(wp, 4.5, 0.3, 1.8, 2.8, 0.0, 100.0, 1, dwx, dwy);
				col *= 1.0 - a * (0.55 + 0.45 * dry) * 0.3 * pattern_k * top;
			}
		}
	}
	col *= 1.0 - edge_ao * joint * top;
	col = mix(col, ink.rgb, top_ink * top);
	// flancs : strates de pierre / fil de coupe, hachures côté ombre
	if (top < 0.99 && (strata_k > 0.0 || hatch_k > 0.0)) {
		float side = 1.0 - top;
		float sy = v_world.y * 7.0 + (n1.r - 0.5) * 1.2;
		float fws = fwidth(sy);
		float strat = 1.0 - smoothstep(0.1, 0.1 + fws * 1.5, abs(fract(sy) - 0.5));
		strat *= clamp(1.2 - fws * 2.0, 0.0, 1.0) * smoothstep(0.3, 0.5, n2.g);
		col *= 1.0 - strat * 0.18 * strata_k * side;
		vec3 ls = -normalize(sun_dir);
		float shade = 1.0 - smoothstep(-0.3, 0.2, dot(v_nw, ls));
		float u = (v_world.x + v_world.z) * 0.7 + v_world.y * 0.9;
		float fw = fwidth(u * 13.0);
		float lines = 1.0 - smoothstep(0.1, 0.1 + fw * 1.5, abs(fract(u * 13.0) - 0.5));
		lines *= clamp(1.2 - fw * 2.0, 0.0, 1.0);
		col = mix(col, ink.rgb, lines * shade * 0.35 * hatch_k * side);
	}
	// biseau : près d'un bord du dessus, la normale penche vers ce bord (repère du monde, puis de la vue)
	if (bevel > 0.0 && top > 0.5) {
		vec2 dist = hs - abs(q);  // distance à chaque bord
		vec2 tilt = sign(q) * (1.0 - smoothstep(0.0, bevel, dist));
		vec3 nl = normalize(vec3(tilt.x * bevel_k, 1.0, tilt.y * bevel_k));
		vec3 nw = normalize(mat3(MODEL_MATRIX) * (nl / max(v_scale, vec3(0.0001))));
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
		vec3 ls = -normalize(sun_dir);
		col *= 1.0 + clamp((dot(nw, ls) - ls.y) * bevel_shade, -0.4, 0.3);
	}
	ALBEDO = col;
	ROUGHNESS = 0.85;
}
