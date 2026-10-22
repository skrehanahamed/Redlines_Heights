shader_type spatial;
// Clear shiny fountain/lake water. The surface is a real mirror-like PBR surface (very low roughness, fresnel, sun glints, sky and
// cloud reflections come from the engine); the picture of the floor shows through, bent by the ripples and tinted by depth.
// Ripple rings and white foam spread from each water jet where it falls back in; caustic light drifts over the floor.
render_mode cull_back, depth_draw_always, specular_schlick_ggx;

uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec3 shallow_col : source_color = vec3(0.12, 0.65, 0.78);
uniform vec3 deep_col : source_color = vec3(0.02, 0.28, 0.42);
uniform vec3 glow_col : source_color = vec3(0.15, 0.85, 0.95);
uniform float flow_speed = 0.6;
uniform float normal_depth = 0.55;
uniform float night = 0.0;
uniform float clarity = 0.45;
uniform vec2 jets[16];
uniform int jet_count = 0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz;
	float t = TIME * flow_speed;
	vec3 n1 = texture(normal_tex, uv * 0.22 + vec2(t * 0.030, t * 0.015)).xyz * 2.0 - 1.0;
	vec3 n2 = texture(normal_tex, uv * 0.41 - vec2(t * 0.040, -t * 0.022)).xyz * 2.0 - 1.0;
	vec2 slope = n1.xy + n2.xy * 0.6;

	// rings and foam where the jets come back down
	float foam = 0.0;
	for (int i = 0; i < 16; i++) {
		if (i >= jet_count) break;
		vec2 d = uv - jets[i];
		float r = length(d);
		float ring = sin(r * 7.0 - TIME * 4.5) * exp(-r * 0.9) * smoothstep(0.0, 0.5, r);
		slope += (d / max(r, 0.001)) * ring * 0.9;
		foam += (1.0 - smoothstep(0.35, 1.3, r)) * (0.55 + 0.45 * n2.x);
	}

	vec3 nm = normalize(vec3(slope, 1.0));
	NORMAL_MAP = nm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = normal_depth;

	float d0 = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d0, 1.0);
	v.xyz /= v.w;
	float thick = max(-v.z + VERTEX.z, 0.0);

	vec2 off = nm.xy * 0.03 * clamp(thick * 3.0, 0.0, 1.0);
	float d2 = texture(depth_tex, SCREEN_UV + off).r;
	vec4 v2 = INV_PROJECTION_MATRIX * vec4((SCREEN_UV + off) * 2.0 - 1.0, d2, 1.0);
	v2.xyz /= v2.w;
	vec2 suv = (-v2.z + VERTEX.z) > 0.0 ? SCREEN_UV + off : SCREEN_UV;
	vec3 floor_col = textureLod(screen_tex, suv, 0.0).rgb;

	float depth_k = 1.0 - exp(-thick / clarity);
	vec3 tint = mix(shallow_col, deep_col, depth_k);
	float caus = pow(clamp(dot(n1.xy, n2.xy) * 0.5 + 0.5, 0.0, 1.0), 3.0);
	vec3 under = mix(floor_col * tint * 1.5, tint, depth_k * 0.9) + shallow_col * caus * 0.12 * (1.0 - depth_k);

	float edge = (1.0 - smoothstep(0.0, 0.18, thick)) * 0.8;
	under = mix(under, vec3(0.93, 0.98, 1.0), clamp(foam * 0.8 + edge, 0.0, 1.0));

	// the engine adds the mirror reflections; what is seen through the water is added as emission, weakened at grazing angles
	vec3 N = normalize(NORMAL);
	float cosv = clamp(dot(N, normalize(VIEW)), 0.0, 1.0);
	float fres = 0.03 + 0.97 * pow(1.0 - cosv, 5.0);
	// mirrored sky: horizon-to-zenith gradient with soft clouds, seen with fresnel strength (strong at a low viewing angle)
	vec3 R = (INV_VIEW_MATRIX * vec4(reflect(-normalize(VIEW), N), 0.0)).xyz;
	float up = clamp(R.y, 0.0, 1.0);
	vec3 sky = mix(vec3(0.62, 0.78, 0.96), vec3(0.18, 0.48, 0.92), pow(up, 0.5));
	float cloud = smoothstep(0.50, 0.80, texture(normal_tex, R.xz / (R.y + 0.35) * 0.35 + vec2(TIME * 0.004, 0.0)).r);
	sky = mix(sky, vec3(1.0), cloud * 0.4 * (1.0 - night));
	sky *= (1.0 - night * 0.93);
	ALBEDO = vec3(0.0);
	EMISSION = mix(under, sky, clamp(fres * 0.8, 0.0, 0.55)) + glow_col * night * 0.7;
	METALLIC = 0.0;
	SPECULAR = 0.75;
	ROUGHNESS = mix(0.02, 0.5, clamp(foam, 0.0, 1.0));
	ALPHA = 1.0;
}
