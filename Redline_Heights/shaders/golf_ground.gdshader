shader_type spatial;
// Golf course ground (ambientCG CC0 materials, see CREDITS.md). Vertex colour = zone weights:
// r fairway / tee boxes, g green, b bunker sand, a path.  Fairway = Grass001, rough = Grass008 (darker, drier), green = Grass001 at a
// finer scale and brighter, bunkers = Ground093A.  Each zone has colour, normal map and roughness; fairways and greens are mown in stripes.
uniform sampler2D fair_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fair_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fair_r : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_r : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_r : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// tile breaking: the same texture at two scales
	vec2 u1 = wp.xz * 0.28;
	vec2 u2 = wp.xz * 0.043 + vec2(0.37, 0.61);
	vec3 big = texture(fair_c, u2).rgb;

	vec3 fc = mix(texture(fair_c, u1).rgb, texture(fair_c, u1 * 0.37 + 0.2).rgb, 0.4) * (0.78 + big * 0.5);
	vec3 rc = mix(texture(rough_c, u1 * 0.8).rgb, texture(rough_c, u1 * 0.29 + 0.5).rgb, 0.45) * (0.72 + big * 0.5);
	vec3 gc = texture(fair_c, wp.xz * 0.55).rgb;
	vec3 sc = texture(sand_c, wp.xz * 0.30).rgb;

	// mown stripes: lawn colour darkens / lightens, along a slowly turning direction
	float s1 = step(0.5, fract((wp.x * 0.71 + wp.z * 0.46) / 2.8));
	float s2 = step(0.5, fract((wp.x * 0.5 - wp.z * 0.5) / 1.3));
	vec3 fair = fc * vec3(0.78, 1.18, 0.55) * (0.88 + 0.24 * s1);
	vec3 rgh = rc * vec3(0.78, 0.92, 0.50);
	vec3 grn = gc * vec3(0.76, 1.32, 0.62) * (0.93 + 0.14 * s2);
	vec3 snd = sc * vec3(1.05, 1.0, 0.9);

	// fringe: a ring of slightly longer grass round every green (between fairway and green weights)
	float fringe = smoothstep(0.0, 0.5, COLOR.g) * (1.0 - smoothstep(0.7, 1.0, COLOR.g));
	grn = mix(grn, fair * 0.95, fringe * 0.6);

	vec3 col = rgh;
	col = mix(col, fair, clamp(COLOR.r, 0.0, 1.0));
	col = mix(col, grn, clamp(COLOR.g, 0.0, 1.0));
	col = mix(col, snd, clamp(COLOR.b, 0.0, 1.0));
	ALBEDO = col;

	vec3 nr = texture(rough_n, u1 * 0.8).rgb;
	vec3 nf = texture(fair_n, u1).rgb;
	vec3 nn = texture(sand_n, wp.xz * 0.30).rgb;
	vec3 nrm = mix(nr, nf, clamp(COLOR.r + COLOR.g, 0.0, 1.0));
	nrm = mix(nrm, nn, clamp(COLOR.b, 0.0, 1.0));
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = mix(1.0, 0.45, clamp(COLOR.g + COLOR.b * 0.4, 0.0, 1.0));

	float rr = mix(texture(rough_r, u1 * 0.8).r, texture(fair_r, u1).r, clamp(COLOR.r + COLOR.g, 0.0, 1.0));
	rr = mix(rr, texture(sand_r, wp.xz * 0.30).r, clamp(COLOR.b, 0.0, 1.0));
	ROUGHNESS = clamp(rr, 0.35, 1.0);
}
