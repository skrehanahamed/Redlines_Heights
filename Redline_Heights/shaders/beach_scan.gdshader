shader_type spatial;
render_mode cull_disabled;
// A photo-scanned beach piece whose edges dissolve into the sand around it (dithered, so no sorting problems).
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 centre = vec2(0.0);
uniform vec2 radius = vec2(1.0);
uniform float feather = 0.28;
uniform float tint_k = 0.0;
uniform vec3 tint : source_color = vec3(1.0, 0.97, 0.9);
varying vec2 lp;

void vertex() {
	lp = VERTEX.xz;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	ALBEDO = mix(c, c * tint, tint_k);
	ROUGHNESS = 1.0;
	vec2 q = (lp - centre) / radius;
	float r = length(q);
	float a = 1.0 - smoothstep(1.0 - feather, 1.0, r);
	ALPHA = a;
	ALPHA_HASH_SCALE = 1.0;
}
