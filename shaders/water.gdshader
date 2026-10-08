shader_type spatial;
render_mode diffuse_toon, specular_disabled;

// Le vide sous l'arène (mer, étang, lave, encre) : fond en lavis qui dérive lentement, rubans de vague
// à la Hokusai (traits brisés et animés, effacés au loin), écume au pied du cadre de l'arène.

uniform vec4 deep : source_color = vec4(0.07, 0.14, 0.25, 1.0);
uniform vec4 shallow : source_color = vec4(0.12, 0.23, 0.37, 1.0);
uniform vec4 foam : source_color = vec4(0.91, 0.93, 0.94, 1.0);
uniform float foam_k = 0.35;
uniform float flow = 1.0;
uniform float band = 0.8;
uniform vec4 shore_rect = vec4(-4.6, -8.6, 4.6, 8.6);
uniform float shore_k = 0.5;
uniform bool fine = true;

varying vec3 v_world;

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
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_world.xz;
	float t = TIME * flow;
	// fond : grandes taches de profondeur qui dérivent
	float n = vnoise(p * 0.11 + vec2(t * 0.021, t * 0.013));
	if (fine) {
		n = n * 0.65 + vnoise(p * 0.33 - vec2(t * 0.034, -t * 0.01)) * 0.35;
	}
	vec3 col = mix(deep.rgb, shallow.rgb, smoothstep(0.2, 0.8, n));
	// rubans de vague : lignes ondulées, brisées en traits de pinceau
	float v = p.y * band + sin(p.x * 0.42 + t * 0.33 + n * 3.5) * 0.55 + t * 0.09;
	float fv = abs(fract(v) - 0.5);
	float fw = fwidth(v);
	float wl = 1.0 - smoothstep(0.07 - fw, 0.07 + fw, fv);
	float row = floor(v);
	float dash = smoothstep(0.4, 0.62, vnoise(vec2(p.x * 0.55 - t * 0.12 + row * 3.7, row * 1.9)));
	wl *= dash * clamp(1.3 - fw * 3.5, 0.0, 1.0);
	col = mix(col, foam.rgb, wl * foam_k);
	// pied du cadre de l'arène, côté mer : ombre portée, liseré d'écume, ondes qui s'éloignent
	vec2 c = (shore_rect.xy + shore_rect.zw) * 0.5;
	vec2 hs = (shore_rect.zw - shore_rect.xy) * 0.5;
	vec2 q = abs(p - c) - hs;
	float sd = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
	float outside = step(0.0, sd);
	float od = max(sd, 0.0);
	float close = (1.0 - smoothstep(0.0, 1.6, od)) * outside;
	col *= 1.0 - 0.3 * close * close;
	float rf = od * 1.4 - t * 0.3;
	float rw = fwidth(rf);
	float rip = abs(fract(rf) - 0.5);
	float ring = 1.0 - smoothstep(0.08 - rw, 0.08 + rw, rip);
	float lip = (1.0 - smoothstep(0.0, 0.1 + rw, od)) * outside;
	col = mix(col, foam.rgb, clamp(ring * close * close * shore_k + lip * shore_k * 0.8, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.6;
}
