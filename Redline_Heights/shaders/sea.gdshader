shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_schlick_ggx;
// The sea: rolling swells whose crests run parallel to the coast and travel in towards the beach (the distance-to-shore texture gives
// every point its own distance and the coast's direction), growing as the water shallows, breaking into foam and washing up the sand
// in a thin sheet. Out at sea the swell is a gentler open-ocean pattern. Rain makes rings on the surface.
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D shore_tex : filter_linear, repeat_disable;       // R = distance to land in water, 0 .. 64 m (0.25 m steps)
uniform vec4 shore_rect = vec4(0.0, 0.0, 1.0, 1.0);                // x0, z0, width, height of that texture in metres
uniform vec3 shallow : source_color = vec3(0.16, 0.62, 0.62);
uniform vec3 deep : source_color = vec3(0.015, 0.14, 0.26);
uniform float night = 0.0;
uniform float storm = 0.0;
uniform float wave_amp = 0.18;     // open-sea swell
uniform float surf = 1.0;          // 0 = calm lagoon / canal (no breaking waves), 1 = open coast
uniform float flow = 1.0;
uniform float depth_scale = 0.22;
uniform float foam_amount = 1.0;
uniform float rain = 0.0;
varying vec3 wpos;
varying float v_d;                 // distance to shore (m)
varying vec2 v_dir;                // direction pointing out to sea

float hash11(float x) { return fract(sin(x * 127.1) * 43758.5453); }
vec2 hash22(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }

float shore_d(vec2 xz) {
	vec2 uv = (xz - shore_rect.xy) / shore_rect.zw;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return 64.0;
	return textureLod(shore_tex, uv, 0.0).r * 64.0 * (255.0 / 255.0);
}

// the surf wave height at a point: two swells whose crests follow the coast (phase = distance to shore), sharpened to peaks
float surf_h(float d, vec2 xz, float t, out float shape_out) {
	float irr = sin(xz.x * 0.011 + xz.y * 0.007) * 1.7 + sin(xz.x * 0.027 - xz.y * 0.019) * 0.8;
	float ph1 = d * 0.185 + t * 0.62 + irr;
	float ph2 = d * 0.37 + t * 1.15 + irr * 1.6;
	float s1 = pow(0.5 + 0.5 * sin(ph1), 2.6);
	float s2 = pow(0.5 + 0.5 * sin(ph2), 2.2);
	float grow = 0.45 + 0.9 * smoothstep(60.0, 12.0, d);                 // steeper as it shoals
	float collapse = smoothstep(1.0, 9.0, d) * 0.85 + 0.15;               // the wave spends itself on the beach
	float h = (s1 * 0.30 + s2 * 0.10) * grow * collapse;
	shape_out = s1;
	return h;
}

void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * flow;
	float amp = wave_amp * (1.0 + storm * 2.5);
	float h_open = sin(p.x * 0.045 + t * 0.9) * 0.5 + sin(p.z * 0.06 - t * 1.1) * 0.5 + sin((p.x + p.z) * 0.03 + t * 0.6) * 0.6;
	float d = shore_d(p.xz);
	v_d = d;
	// the coast's direction from the texture's slope
	vec2 g = vec2(shore_d(p.xz + vec2(2.0, 0.0)) - shore_d(p.xz - vec2(2.0, 0.0)), shore_d(p.xz + vec2(0.0, 2.0)) - shore_d(p.xz - vec2(0.0, 2.0)));
	v_dir = length(g) > 0.001 ? normalize(g) : vec2(0.0, 1.0);
	float near_k = surf * (1.0 - smoothstep(30.0, 62.0, d));
	float sh;
	float hs = surf_h(d, p.xz, TIME, sh) * (1.0 + storm * 1.6) * near_k;
	float hh = mix(h_open * amp, hs * 1.0 + h_open * amp * 0.25, near_k);
	VERTEX.y += hh;
	wpos = p;
}

vec2 rain_rings(vec2 p, float t) {
	vec2 g = floor(p);
	vec2 f = fract(p);
	vec2 n = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = vec2(float(i), float(j));
			vec2 id = g + cell;
			vec2 rnd = hash22(id);
			float life = fract(t * 0.9 + rnd.x * 7.0);
			vec2 dv = f - cell - rnd;
			float dist = length(dv);
			float ring = smoothstep(0.07, 0.0, abs(dist - life * 0.6)) * (1.0 - life) * (1.0 - life);
			n += dv / max(dist, 0.001) * ring;
		}
	}
	return n;
}

void fragment() {
	vec2 uv = wpos.xz;
	float t = TIME * flow;
	vec3 n1 = texture(normal_tex, uv / 26.0 + vec2(t * 0.012, t * 0.006)).xyz * 2.0 - 1.0;
	vec3 n2 = texture(normal_tex, uv / 9.0 - vec2(t * 0.02, -t * 0.015)).xyz * 2.0 - 1.0;
	vec3 n3 = texture(normal_tex, uv / 5.5 + vec2(t * 0.04, t * 0.03)).xyz * 2.0 - 1.0;
	vec3 nm = normalize(vec3(n1.xy + n2.xy * 0.8 + n3.xy * 0.2 * (1.0 + storm), 1.0));
	// rain: rings spreading from every drop, two sizes
	vec2 rr = rain_rings(uv * 1.3, TIME) + rain_rings(uv * 2.1 + 17.0, TIME * 1.3) * 0.6;
	nm.xy += rr * rain * 1.8;
	NORMAL_MAP = nm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = (0.45 + storm * 0.5 + rain * 0.2) * (1.0 - smoothstep(80.0, 400.0, -VERTEX.z) * 0.85);
	// water depth under this pixel
	float dp = texture(depth_tex, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, dp);
	vec4 vw = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vw.xyz /= vw.w;
	float near_k = 1.0 - smoothstep(60.0, 220.0, -VERTEX.z);
	float depth = mix(40.0, max(VERTEX.z - vw.z, 0.0), near_k);
	vec3 col = mix(shallow, deep, clamp(1.0 - exp(-depth * depth_scale), 0.0, 1.0));
	vec3 tex = texture(albedo_tex, uv / 30.0 + vec2(t * 0.004, 0.0)).rgb;
	float lum = dot(tex, vec3(0.3, 0.59, 0.11));
	col = mix(col, col * (0.7 + tex * 1.4), 0.45);
	float crest = smoothstep(0.55, 0.85, lum) * (0.25 + storm * 0.6);
	// breaking waves: foam on the crests as they near the shore, white water behind the break, and the wash running up the sand
	float d = v_d;
	float sh;
	float hs = surf_h(d, uv, TIME, sh);
	float live = surf * (1.0 - smoothstep(26.0, 58.0, d));
	float break_foam = smoothstep(0.72, 0.97, sh) * (1.0 - smoothstep(9.0, 30.0, d)) * live;
	float whitewater = (1.0 - smoothstep(2.0, 11.0, d)) * smoothstep(0.0, 0.8, d) * (0.45 + 0.45 * sin(d * 0.9 + TIME * 1.7 + uv.x * 0.05)) * live;
	float wash_edge = 1.5 + 1.6 * (0.5 + 0.5 * sin(TIME * 0.55 + uv.x * 0.02 + uv.y * 0.013));
	float wash = (1.0 - smoothstep(wash_edge, wash_edge + 0.9, d)) * live;
	float streak = 0.55 + 0.7 * lum;
	float foam = clamp((break_foam * 0.9 + whitewater * 0.75 + wash * 0.9) * streak + crest * 0.5, 0.0, 1.0);
	foam = max(foam, (1.0 - smoothstep(0.0, 0.3, depth)) * 0.5 * surf);        // a thin line right at the waterline
	foam *= foam_amount;
	foam = clamp(foam + max(rr.x * rr.x + rr.y * rr.y, 0.0) * rain * 0.35, 0.0, 1.0);
	col = mix(col, vec3(0.93, 0.97, 0.98), foam);
	col *= mix(1.0, 0.12, night);
	ALBEDO = col;
	ROUGHNESS = mix(0.22, 0.6, foam);
	METALLIC = 0.0;
	SPECULAR = 0.5;
	ALPHA = clamp(0.5 + depth * 0.7, 0.0, 0.98) * (1.0 - wash * 0.25);
}
