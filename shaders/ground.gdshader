shader_type spatial;
render_mode diffuse_toon, specular_disabled;

// Sol de l'arène : tuiles en MultiMesh (boîte unité mise à l'échelle par instance).
// Teinte qui varie d'une tuile à l'autre (vers une 2e teinte), joints usés et assombris, mousse dans
// les joints, plages délavées, pied des flancs dans l'ombre, grain du papier / fil du bois, mouchetis d'encre.
// Jamais plus clair en moyenne que la couleur de base.

uniform vec4 albedo : source_color = vec4(0.6, 0.56, 0.5, 1.0);
uniform vec4 alt : source_color = vec4(0.5, 0.48, 0.45, 1.0);
uniform vec4 ink : source_color = vec4(0.106, 0.102, 0.118, 1.0);
uniform vec4 moss : source_color = vec4(0.32, 0.38, 0.27, 1.0);
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

varying vec3 v_local;
varying vec3 v_scale;
varying vec3 v_world;
varying float v_ny;
varying float v_seed;

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
	v_local = VERTEX;
	v_ny = NORMAL.y;
	v_scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// une graine par tuile (centre de l'instance)
	v_seed = hash12(MODEL_MATRIX[3].xz * 1.37 + vec2(MODEL_MATRIX[3].y * 7.1, 0.0));
}

void fragment() {
	// teinte de la tuile : entre la couleur de base et la 2e teinte, puis légère variation de valeur
	vec3 col = mix(albedo.rgb, alt.rgb, alt_k * v_seed * v_seed);
	col *= 1.0 + (fract(v_seed * 7.13) - 0.5) * 2.0 * tile_var;
	float top = smoothstep(0.5, 0.9, v_ny);
	// joints : distance (m) au bord de la face du dessus
	vec2 dd = (vec2(0.5) - abs(v_local.xz)) * v_scale.xz;
	float e = min(dd.x, dd.y);
	float joint = 1.0 - smoothstep(0.0, edge_w, e);
	// flancs : plus sombres vers le bas (contact, ombre du dessous)
	float h = clamp(v_local.y + 0.5, 0.0, 1.0);
	col *= 1.0 - side_ao * (1.0 - top) * (1.0 - h);
	if (fine) {
		vec2 wp = v_world.xz;
		float g = vnoise(wp * grain_scale) * 0.65 + vnoise(wp * grain_scale * 2.7 + vec2(3.1, 1.7)) * 0.35;
		col *= 1.0 + (g - 0.5) * 2.0 * grain;
		// plages délavées (usure) : la couleur se ternit, sans s'éclaircir
		float wear = smoothstep(0.55, 0.85, vnoise(wp * 0.42 + vec2(11.0, 5.0)));
		float lum = dot(col, vec3(0.3, 0.55, 0.15));
		col = mix(col, vec3(lum) * 0.98, wear * wear_k * top);
		// mousse : dans les joints et par plaques
		float mp = vnoise(wp * 0.7 + vec2(4.0, 9.0));
		float mz = smoothstep(0.5, 0.8, mp) * (0.35 + 0.65 * joint) * moss_k * top;
		col = mix(col, moss.rgb, clamp(mz, 0.0, 0.85));
		// mouchetis d'encre (pinceau secoué) : rares et à demi-teinte, pour ne jamais passer pour
		// un projectile ou une tache d'attaque
		float sp = vnoise(wp * 9.0 + vec2(v_seed * 31.0, v_seed * 17.0));
		float dots = smoothstep(0.88, 0.94, sp) * speckle * top;
		col = mix(col, ink.rgb, dots * 0.6);
	}
	col *= 1.0 - edge_ao * joint * top;
	ALBEDO = col;
	ROUGHNESS = 0.85;
}
