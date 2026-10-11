shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Lueurs des lanternes, braseros et torches (scripts/lueurs.gd) : un seul MultiMesh additif par salle.
// Par instance (INSTANCE_CUSTOM) : rgb = couleur déjà pondérée, a = graine (0..1) + 1 (halo) + 2 (flamme).
//  - flaque : quad couché au sol, dégradé doux qui s'éteint au bord ;
//  - halo : quad face caméra autour de la flamme (garde l'échelle de l'instance et du nœud : la miniature
//    du préchauffage reste minuscule), avancé vers l'objectif pour ne pas être mangé par la lanterne.
// Chaque lueur palpite à son rythme (trois sinus désaccordés par la graine) ; les flammes plus que le papier.

uniform float gain = 1.0;  // flaques : force selon le monde (nuit : forte, plein jour : discrète)
uniform float halo_gain = 1.0;

varying vec3 v_col;
varying float v_halo;

void vertex() {
	float a = INSTANCE_CUSTOM.a;
	float seed = fract(a);
	float halo = mod(floor(a), 2.0);
	float fire = step(1.5, floor(a));
	float t = TIME;
	float fl = sin(t * (4.3 + 2.9 * seed) + seed * 40.0) * 0.5
		+ sin(t * (10.7 + 3.1 * seed) + seed * 17.0) * 0.3
		+ sin(t * 1.7 + seed * 7.0) * 0.2;
	float amp = mix(0.06, 0.18, fire);
	v_col = INSTANCE_CUSTOM.rgb * (1.0 + fl * amp) * mix(gain, halo_gain, halo);
	v_halo = halo;
	if (halo > 0.5) {
		vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sc.x, INV_VIEW_MATRIX[1] * sc.y, INV_VIEW_MATRIX[2] * sc.z, MODEL_MATRIX[3]);
		MODELVIEW_MATRIX[3].z += 0.35 * sc.x;
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
		VERTEX *= 1.0 + fl * amp * 0.5;
	}
}

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float f = max(1.0 - dot(d, d), 0.0);
	// flaque : large et douce ; halo : cœur serré, longue traîne
	f = v_halo > 0.5 ? f * f * f : f * f * (0.55 + 0.45 * f);
	ALBEDO = v_col * f;
}
