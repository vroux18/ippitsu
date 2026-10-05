// Rendu cartoon des personnages KayKit, recolorés dans la palette Ippitsu.
// Les teintes « peau / os » (claires, orangées, peu saturées) sont préservées,
// le reste du vêtement est ramené vers la couleur `tint`.
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_amount = 0.0;
uniform float keep_skin = 1.0;
uniform vec4 glow_color : source_color = vec4(0.843, 0.216, 0.169, 1.0);
uniform float glow = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_amount = 0.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	vec3 hsv = rgb2hsv(c);
	float skin = keep_skin * step(0.01, hsv.x) * step(hsv.x, 0.13) * step(0.5, hsv.z) * step(hsv.y, 0.7);
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 tinted = tint.rgb * (0.55 + 0.9 * lum);
	c = mix(c, tinted, tint_amount * (1.0 - skin));
	c = mix(c, glow_color.rgb, glow);
	c = mix(c, flash_color.rgb, flash_amount);
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
}
