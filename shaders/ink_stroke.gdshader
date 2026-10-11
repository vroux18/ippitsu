shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Trait d'encre au sol (ink_stroke.gd) : UNE matière partagée par tous les traits, l'état de chaque trait en
// paramètre d'instance. La géométrie (bande le long des points) ne change pas : seul l'aspect de l'encre.
// Sommets : COLOR = teinte finale (alpha : effilement vers la queue), UV.x = abscisse le long du trait (m),
// UV.y = travers (0..1), UV2.x = densité (1 : le pinceau a ralenti, l'encre s'accumule ; 0 : trait vif),
// UV2.y = horloge du trait à la pose du point (s), NORMAL = côté de la bande (plan XZ).
// Le bord boit le papier (franges bruitées), l'encre fraîche brille (ménisque clair côté lumière), et en
// séchant l'intérieur pâlit et se marbre tandis que le bord fonce (auréole), puis le trait s'efface par érosion.

// x : horloge du trait (s), y : temps de séchage (s, 0 tant que le pinceau est posé), z : graine
instance uniform vec4 stroke_state = vec4(0.0, 0.0, 0.0, 0.0);

varying vec2 wxz;
varying float lit;  // côté de la bande tourné vers la lumière (-1..1)

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

void vertex() {
	vec4 w = MODEL_MATRIX * vec4(VERTEX, 1.0);
	wxz = w.xz;
	vec3 sw = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec2 L = normalize(vec2(-0.5, -0.85));
	lit = dot(normalize(sw.xz + vec2(0.0001)), L);
}

void fragment() {
	float now = stroke_state.x;
	float dry_t = stroke_state.y;
	float seed = stroke_state.z;
	float s = UV.x;
	float e = UV.y * 2.0 - 1.0;  // -1..1 en travers
	float ae = abs(e);
	float dens = UV2.x;
	float age = max(now - UV2.y, 0.0);
	float dry = smoothstep(0.0, 0.8, dry_t);
	float fade = clamp((dry_t - 0.5) / 1.1, 0.0, 1.0);

	// bord qui boit le papier : seuil bruité le long du trait + fibres du papier (plus marqué en séchant)
	float nb = vnoise(vec2(s * 4.5, seed)) * 0.6 + vnoise(vec2(s * 13.0, seed + 3.0)) * 0.4;
	float fib = vnoise(wxz * 30.0 + seed);
	float thr = 0.84 + 0.13 * nb + 0.03 * dens;
	float edge = ae + (fib - 0.5) * (0.1 + 0.1 * dry);
	float soft = fwidth(e) * 1.2 + 0.03 + 0.07 * dry;
	float cov = 1.0 - smoothstep(thr - soft, thr + soft * 0.4, edge);

	// trait vif : quelques poils secs (kasure) vers la queue
	float hair = vnoise(vec2(s * 1.4 + seed, UV.y * 15.0));
	float tailk = clamp((0.95 - COLOR.a) / 0.25, 0.0, 1.0);
	float kas = mix(1.0, smoothstep(0.12, 0.36, hair), (1.0 - dens) * 0.6 * tailk * tailk);
	cov *= kas;

	// densité : là où le pinceau a ralenti, l'encre est plus pleine et plus sombre
	vec3 base = COLOR.rgb;
	vec3 col = base * mix(1.08, 0.8, dens);
	float a = COLOR.a * mix(0.86, 1.0, dens);

	// séchage : auréole au bord, intérieur pâle et marbré
	float rim = smoothstep(thr - 0.42, thr - 0.06, edge);
	float mott = vnoise(wxz * 3.3 + seed) * 0.6 + vnoise(wxz * 8.1 - seed) * 0.4;
	vec3 grey = vec3(dot(base, vec3(0.333)));
	vec3 pale = mix(base, grey, 0.35) * 1.5 + 0.06;
	vec3 dcol = mix(pale, base * 0.6, rim);
	col = mix(col, dcol, dry);
	a *= mix(1.0, mix(0.5 + 0.3 * mott, 1.0, rim), dry);

	// reflet humide : ménisque clair côté lumière, plus vif sur l'encre la plus fraîche
	float wet = (1.0 - dry) * (1.0 - 0.55 * smoothstep(0.2, 1.6, age));
	float side = lit * sign(e);
	float band = smoothstep(0.38, 0.5, ae) * (1.0 - smoothstep(0.56, 0.68, ae));
	float glint = band * smoothstep(0.1, 0.6, side) * (0.55 + 0.45 * smoothstep(0.35, 0.65, vnoise(vec2(s * 2.2, seed + 9.0))));
	float hl = glint * wet;
	col = mix(col, vec3(0.86, 0.89, 0.95), hl * 0.42);
	col *= 1.0 - 0.2 * wet * band * smoothstep(0.1, 0.7, -side);

	// fondu : érosion (l'intérieur pâle part d'abord, l'auréole ensuite)
	float keep = mott * 0.6 + rim * 0.45 + fib * 0.06;
	float er = smoothstep(fade * 1.2 - 0.12, fade * 1.2 + 0.08, keep);
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0) * cov * er * (1.0 - 0.3 * fade);
}
