shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Brume de sol (scripts/graphismes.gd build_mist, GRAPHISMES ZINZIN) : grandes nappes couchées au ras du sol
// autour de l'arène, deux couches de bruit qui dérivent lentement, bords fondus ; couleur de la brume du monde.
// Très légère : le cœur de l'arène n'en reçoit presque pas (les nappes sont en périphérie, et le pied de
// chaque nappe s'efface vers le centre : INSTANCE_CUSTOM.r = sens du centre en UV.x, .g = graine).

uniform vec4 tint : source_color = vec4(0.9, 0.9, 0.95, 1.0);
uniform float strength = 0.14;
uniform float speed = 0.03;

varying float v_seed;
varying float v_side;

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
	v_seed = INSTANCE_CUSTOM.g;
	v_side = INSTANCE_CUSTOM.r;
}

void fragment() {
	float t = TIME * speed;
	vec2 p = UV * vec2(3.0, 2.0) + vec2(v_seed * 17.0, v_seed * 9.0);
	float n = vnoise(p + vec2(t, t * 0.4)) * 0.6 + vnoise(p * 2.3 - vec2(t * 0.7, t * 0.2)) * 0.4;
	n = smoothstep(0.32, 0.78, n);
	// bords fondus ; le côté tourné vers le centre de l'arène s'efface plus tôt
	vec2 d = abs(UV * 2.0 - 1.0);
	float edge = (1.0 - smoothstep(0.35, 1.0, d.x)) * (1.0 - smoothstep(0.3, 1.0, d.y));
	float toward = mix(UV.x, 1.0 - UV.x, step(0.5, v_side));
	edge *= 1.0 - smoothstep(0.45, 1.0, toward);
	ALBEDO = tint.rgb;
	ALPHA = strength * n * edge;
}
