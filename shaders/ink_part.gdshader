shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Particules peintes (CPUParticles3D de vfx.gd) : un quad (QuadMesh 1 × 1) tourné vers la caméra dans le shader
// (l'échelle de la particule est gardée), l'âge de chaque particule lu dans INSTANCE_CUSTOM.y (0 naissance .. 1 fin),
// sa graine dans INSTANCE_CUSTOM.z (anim_offset tiré au hasard). Une matière par sorte, partagée.
//   mode 0 FLAMME : langue de flamme peinte, contour de braise sombre, corps vermillon, cœur or qui se resserre en
//     vieillissant ; la pointe ondule et se détache, et finit en fumée d'encre.
//   mode 1 LAVIS : bouffée de lavis (fumée d'ombre, cendre, brume) : tache diluée au bord mouillé plus foncé, grain
//     du papier, qui s'étale et pâlit ; teinte de la particule (COLOR, rampe de couleur de l'émetteur).

uniform int mode = 0;
uniform vec4 deep : source_color = vec4(0.35, 0.06, 0.03, 1.0);  // contour (braise sombre)
uniform vec4 body : source_color = vec4(1.0, 0.36, 0.12, 1.0);  // corps
uniform vec4 core : source_color = vec4(1.0, 0.8, 0.3, 1.0);  // cœur
uniform vec4 smoke : source_color = vec4(0.12, 0.1, 0.12, 0.6);  // fumée de la pointe

varying vec2 q;
varying float life_k;
varying float seed;

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
	q = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);  // -1..1 (indépendant de la taille du quad)
	life_k = INSTANCE_CUSTOM.y;
	seed = INSTANCE_CUSTOM.z * 37.0;
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	mat4 mw = mat4(INV_VIEW_MATRIX[0] * sc.x, INV_VIEW_MATRIX[1] * sc.y, INV_VIEW_MATRIX[2] * sc.z, MODEL_MATRIX[3]);
	if (mode == 1) {
		// lavis : la bouffée tourne sur elle-même (angle de la particule)
		float a = INSTANCE_CUSTOM.x;
		mw = mw * mat4(vec4(cos(a), -sin(a), 0.0, 0.0), vec4(sin(a), cos(a), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	}
	MODELVIEW_MATRIX = VIEW_MATRIX * mw;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

// langue de flamme entre y0 (base ronde) et y1 (pointe), largeur relative k : distance signée (approchée)
float tongue(vec2 p, float k, float y0, float y1) {
	float y = (p.y - y0) / (y1 - y0);
	float w = 0.56 * k * pow(max(sin(3.1416 * pow(clamp(y, 0.0, 1.0), 0.55)), 0.0), 0.8);
	return max(abs(p.x) - w, max(-y, y - 1.0) * (y1 - y0));
}

void fragment() {
	vec4 outc = vec4(0.0);
	float lk = clamp(life_k, 0.0, 1.0);
	if (mode == 0) {
		// la flamme ondule : la pointe se balance plus que la base
		float y01 = clamp((q.y + 1.0) * 0.5, 0.0, 1.0);
		float sway = (vnoise(vec2(seed, lk * 5.0 + q.y * 1.4)) - 0.5) * 0.7 * y01 * y01;
		vec2 p = vec2(q.x - sway, q.y);
		// coup de pinceau : stries verticales
		float st = vnoise(vec2(p.x * 7.0 + seed, p.y * 1.6 - lk * 3.0));
		float hot = 1.0 - lk;
		float d0 = tongue(p, 1.0, -0.92, 0.96) + (st - 0.5) * 0.08;
		float d1 = tongue(p, 0.72, -0.8, 0.62) + (st - 0.5) * 0.05;
		float d2 = tongue(p, 0.42 * (0.45 + 0.55 * hot), -0.7, 0.05 + 0.25 * hot);
		float aa = max(fwidth(p.x), 0.01);
		float c0 = 1.0 - smoothstep(-aa, aa, d0);
		float c1 = 1.0 - smoothstep(-aa, aa, d1);
		float c2 = 1.0 - smoothstep(-aa, aa, d2);
		vec3 col = deep.rgb;
		col = mix(col, body.rgb * (0.9 + 0.2 * st), c1);
		col = mix(col, core.rgb, c2 * (0.5 + 0.5 * hot));
		// la pointe se détache en fumée d'encre quand la langue vieillit
		float tipk = smoothstep(0.35, 1.0, lk) * smoothstep(0.1, 0.9, y01);
		col = mix(col, smoke.rgb, tipk * 0.85);
		float a = c0 * (1.0 - smoothstep(0.6, 1.0, lk) * (0.5 + 0.5 * y01));
		// les bords sèchent (poils) en fin de vie
		float hair = vnoise(vec2(p.x * 14.0, p.y * 3.0) + seed);
		a *= smoothstep(lk * 0.55 - 0.05, lk * 0.55 + 0.12, hair + (1.0 - y01) * 0.35);
		outc = vec4(col, a * mix(1.0, smoke.a, tipk) * COLOR.a);
	} else {
		// lavis : tache diluée, bord mouillé plus foncé, grain
		float r = length(q);
		vec2 dir = q / max(r, 0.0001);
		float edge = 0.72 + 0.22 * vnoise(dir * 2.2 + seed) + 0.08 * vnoise(dir * 7.0 + seed);
		float soft = 0.06 + 0.22 * lk;
		float d = r - edge * (0.85 + 0.15 * lk);
		float cov = 1.0 - smoothstep(-soft, soft * 0.5, d);
		float rim = smoothstep(-0.3 - 0.2 * lk, -0.02, d) * (1.0 - lk * 0.6);
		float grain = vnoise(q * 6.0 + seed) * 0.6 + vnoise(q * 17.0 - seed) * 0.4;
		vec3 col = COLOR.rgb * mix(1.1, 0.7, rim);
		float a = cov * COLOR.a * (0.45 + 0.35 * rim + 0.2 * grain);
		outc = vec4(col, a);
	}
	ALBEDO = outc.rgb;
	ALPHA = clamp(outc.a, 0.0, 1.0);
}
