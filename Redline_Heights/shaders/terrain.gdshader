shader_type spatial;
// Ground: grass inland, sand on the beach (vertex colour r = sand, g = seabed tint, b = wet sand).
uniform sampler2D grass_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass2_tex : source_color, filter_linear_mipmap, repeat_enable;   // a second lawn with clover, mixed in patches
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;     // bare earth in worn patches and where grass meets sand
uniform vec3 grass_tint : source_color = vec3(0.86, 1.0, 0.84);
uniform sampler2D pave_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D conc_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 pave_pads[16];     // x, z, yaw, kind (0 = fenced garden of a white villa, 1 = brick villa)
uniform int pave_n = 0;
uniform vec4 pave_half = vec4(12.2, 14.0, 17.4, 17.6);   // half sizes: kind 0 (x, z), kind 1 (x, z)
varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 ga = texture(grass_tex, wp.xz * 0.14).rgb;
	vec3 gb = texture(grass2_tex, wp.xz * 0.11).rgb;
	vec3 gc = texture(grass_tex, wp.xz * 0.031).rgb;                       // the same lawn at a larger scale breaks up the repeat
	float mixp = texture(sand_tex, wp.xz * 0.0042).g;
	float wear = texture(sand_tex, wp.xz * 0.019).b;
	vec3 g = mix(ga, gb, smoothstep(0.38, 0.66, mixp));
	g = mix(g, g * (0.7 + gc * 0.6), 0.45);
	vec3 dirt = texture(dirt_tex, wp.xz * 0.16).rgb;
	g = mix(g, dirt, clamp(smoothstep(0.66, 0.82, wear) * 0.55 + smoothstep(0.04, 0.45, COLOR.r) * 0.45, 0.0, 0.8));
	g *= grass_tint;
	vec3 s = texture(sand_tex, wp.xz * 0.16).rgb;
	float big = texture(sand_tex, wp.xz * 0.011).r;
	s *= 0.88 + big * 0.28;
	// The tide leaves a darker, tighter strip with low ripples.  It uses the
	// terrain's existing wet-sand vertex mask, so it follows every irregular
	// bay instead of reading as a painted straight shoreline.
	float wet_sand = COLOR.b * smoothstep(0.05, 0.92, COLOR.r);
	float tide_ripple = pow(0.5 + 0.5 * sin(wp.x * 0.82 + wp.z * 0.19 + big * 5.0), 10.0);
	s *= mix(1.0, 0.58 + tide_ripple * 0.13, wet_sand);
	s = mix(s, s * vec3(0.88, 0.96, 1.02), tide_ripple * wet_sand * 0.2);
	s = mix(s, s * vec3(0.5, 0.62, 0.66), COLOR.g);
	// sand blows into the grass in patches rather than along a straight line
	float k = smoothstep(0.42, 0.58, COLOR.r + (big - 0.5) * 0.35 * (1.0 - step(0.99, COLOR.r)) * step(0.01, COLOR.r));
	// the Renowood hills: sun-dried grass with greener patches, bare earth and rock on the steep parts
	float hm = COLOR.a;
	float pat = texture(sand_tex, wp.xz * 0.0035).g;
	float pat2 = texture(sand_tex, wp.xz * 0.02).r;
	vec3 dry = g * vec3(1.25, 1.0, 0.55) + vec3(0.02, 0.015, 0.0);
	vec3 green = g * vec3(0.82, 1.05, 0.75);
	vec3 hillc = mix(dry, green, smoothstep(0.35, 0.7, pat));
	hillc *= 0.88 + pat2 * 0.24;
	float slope = 1.0 - clamp(wn.y, 0.0, 1.0);
	vec3 earth = vec3(0.17, 0.105, 0.055) * (0.8 + pat2 * 0.4);
	hillc = mix(hillc, earth, smoothstep(0.34, 0.5, slope) * 0.8);
	hillc = mix(hillc, vec3(0.15, 0.135, 0.12) * (0.8 + pat2 * 0.4), smoothstep(0.62, 0.8, slope));
	vec3 base_c = mix(g, hillc, smoothstep(0.0, 0.5, hm));
	vec3 col_out = mix(base_c, s, k);
	// paved floors: pavers inside the white villas' fences, plain concrete under and round the brick villas
	for (int i = 0; i < 16; i++) {
		if (i >= pave_n) break;
		vec4 pp = pave_pads[i];
		vec2 d = wp.xz - pp.xy;
		float cy = cos(pp.z);
		float sy = sin(pp.z);
		vec2 l = vec2(d.x * cy - d.y * sy, d.x * sy + d.y * cy);
		vec2 hf = pp.w < 0.5 ? pave_half.xy : pave_half.zw;
		vec2 q = hf - abs(l);
		float inside = smoothstep(0.0, 0.5, min(q.x, q.y));
		vec3 floor_c = pp.w < 0.5 ? texture(pave_tex, wp.xz * 0.22).rgb * vec3(0.95, 0.93, 0.9) : vec3(0.075, 0.08, 0.085) * (0.8 + 0.4 * texture(conc_tex, wp.xz * 0.12).r);
		col_out = mix(col_out, floor_c, inside);
	}
	ALBEDO = col_out;
	// Dry dune sand remains matte; recently washed sand has a small natural
	// sheen that catches low-angle sunlight beside the breaking waves.
	ROUGHNESS = mix(1.0, 0.34, wet_sand);
}
