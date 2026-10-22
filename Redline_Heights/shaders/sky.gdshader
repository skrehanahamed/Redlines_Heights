shader_type sky;
// Daytime sky: blue gradient with a warm horizon haze, a sun with glow, and slowly drifting cumulus clouds.
uniform vec3 top_color : source_color = vec3(0.03, 0.20, 0.70);
uniform vec3 mid_color : source_color = vec3(0.20, 0.52, 0.96);
uniform vec3 horizon_color : source_color = vec3(0.80, 0.90, 0.98);
uniform sampler2D cloud_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 ground_color : source_color = vec3(0.55, 0.58, 0.55);
uniform float cloud_cover = 0.52;
uniform float night = 0.0;          // 0 day .. 1 night
uniform float dusk = 0.0;           // warm horizon glow at sunrise / sunset
uniform float storm = 0.0;          // 0 clear .. 1 dark storm sky
uniform float flash = 0.0;          // lightning flash
uniform vec3 moon_dir = vec3(0.0, 0.7, 0.7);
uniform vec3 sun_pos = vec3(0.0, 1.0, 0.0);
uniform vec2 cloud_offset = vec2(0.0);   // accumulated drift, advanced by the weather script (so changes in wind never make clouds jump)
uniform sampler2D moon_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float moon_phase = 0.5;     // 0 new .. 0.5 full .. 1 new
uniform float moon_radius = 0.055;  // apparent angular radius (radians)
uniform float moon_red = 0.0;       // 0 normal .. 1 blood moon
uniform float moon_bright = 1.0;    // fades in daylight / storms
uniform float haze = 0.0;           // fog / dust veil over the whole sky
uniform vec3 haze_color : source_color = vec3(0.75, 0.78, 0.82);
uniform float heat = 0.0;           // heat wave tint

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;
	vec3 top = mix(top_color, vec3(0.01, 0.02, 0.07), night);
	vec3 midc = mix(mid_color, vec3(0.03, 0.06, 0.15), night);
	vec3 hor = mix(horizon_color, vec3(0.06, 0.09, 0.17), night);
	hor = mix(hor, vec3(1.0, 0.5, 0.25), dusk * 0.8);
	midc = mix(midc, vec3(0.65, 0.4, 0.45), dusk * 0.4);
	// storms: everything goes grey
	vec3 grey = vec3(0.30, 0.33, 0.38) * (1.0 - night * 0.8);
	top = mix(top, grey * 0.8, storm);
	midc = mix(midc, grey, storm);
	hor = mix(hor, grey * 1.15, storm);
	vec3 col;
	if (h >= 0.0) {
		float t = pow(clamp(h, 0.0, 1.0), 0.55);
		col = mix(hor, midc, smoothstep(0.0, 0.35, t));
		col = mix(col, top, smoothstep(0.3, 1.0, t));
	} else {
		col = mix(hor, ground_color * (1.0 - night * 0.85), smoothstep(0.0, 0.3, -h));
	}
	// stars
	if (h > 0.0 && night > 0.05) {
		vec2 sp = dir.xz / (h + 0.3) * 60.0;
		vec2 cell = floor(sp);
		vec2 f = fract(sp) - 0.5;
		float r = hash(cell);
		float star = step(0.985, r) * smoothstep(0.18, 0.0, length(f + vec2(hash(cell + 3.0) - 0.5, hash(cell + 7.0) - 0.5) * 0.5));
		col += vec3(star) * night * (1.0 - storm) * (0.6 + 0.4 * sin(TIME * 2.0 + r * 40.0));
	}
	// sun and moon
	vec3 sun_dir = normalize(sun_pos);
	float sd = max(dot(dir, sun_dir), 0.0);
	float sun_vis = (1.0 - night) * (1.0 - storm * 0.85);
	// the sun: a bright disc with a soft corona (visible through thin cloud, fades in storms)
	float disc = smoothstep(0.99900, 0.99935, sd);
	col += vec3(1.0, 0.95, 0.8) * disc * 6.0 * sun_vis;
	col += vec3(1.0, 0.85, 0.55) * (pow(sd, 90.0) * 0.55 + pow(sd, 14.0) * 0.28 + pow(sd, 3.0) * 0.06) * sun_vis;
	// the moon: NASA LRO map on a lit sphere, with phases, a red "blood moon" tint and a halo
	vec3 mdir = normalize(moon_dir);
	float md = max(dot(dir, mdir), 0.0);
	float illum = 0.5 - 0.5 * cos(moon_phase * 6.28318);
	vec3 moon_glow_col = mix(vec3(0.55, 0.65, 1.0), vec3(1.0, 0.25, 0.1), moon_red);
	vec3 up = abs(mdir.y) < 0.95 ? vec3(0, 1, 0) : vec3(1, 0, 0);
	vec3 mr = normalize(cross(up, mdir));
	vec3 mu = cross(mdir, mr);
	float above = smoothstep(-0.05, 0.03, h);
	if (md > 0.0) {
		vec2 mp = vec2(dot(dir, mr), dot(dir, mu)) / sin(moon_radius);
		float r = length(mp);
		if (r < 1.0) {
			vec3 N = vec3(mp, sqrt(1.0 - r * r));
			float lon = atan(N.x, N.z);
			float lat = asin(clamp(N.y, -1.0, 1.0));
			vec3 alb = texture(moon_tex, vec2(0.5 + lon / 6.28318, 0.5 - lat / 3.14159)).rgb;
			alb = clamp((alb - 0.42) * 2.1 + 0.42, 0.0, 1.2);
			float a = moon_phase * 6.28318;
			vec2 sp = vec2(dot(sun_dir, mr), dot(sun_dir, mu));
			sp = length(sp) > 0.0001 ? normalize(sp) : vec2(1.0, 0.0);
			vec3 L = vec3(abs(sin(a)) * sp, -cos(a));
			float lit = smoothstep(-0.03, 0.18, dot(N, L));
			lit = mix(lit, 1.0, moon_red);
			lit = max(lit, 0.012);
			vec3 base = alb * vec3(1.0, 0.97, 0.9);
			vec3 blood = alb * vec3(1.0, 0.20, 0.07);
			base = mix(base, blood, moon_red);
			float limb = mix(1.0, 0.72 + 0.28 * N.z, 0.8);
			vec3 moon_col = base * lit * limb * mix(2.6, 1.9, moon_red);
			float edge = smoothstep(1.0, 0.985, r);
			col = mix(col, moon_col, edge * moon_bright * above);
		}
	}
	float halo_w = max(moon_radius, 0.02);
	float ang = acos(clamp(md, 0.0, 1.0));
	col += moon_glow_col * (exp(-ang / (halo_w * 2.5)) * 0.22 + exp(-ang / (halo_w * 12.0)) * 0.07) * (0.25 + illum * 0.75) * moon_bright * above;
	// faint 22 degree ring when thin high cloud is about
	col += moon_glow_col * smoothstep(0.03, 0.0, abs(ang - 0.38)) * 0.02 * illum * moon_bright * above;
	// clouds: tileable cloud texture projected on two high planes (billowy cumulus + wispy cirrus)
	float cover = clamp(cloud_cover + storm * 0.55, 0.0, 1.0);
	if (h > 0.01) {
		float fade = smoothstep(0.01, 0.16, h);
		vec2 duv = dir.xz / (h + 0.22);
		vec2 wind = cloud_offset;
		// cirrus streaks high up
		vec2 cuv = duv * 0.22 + wind * 0.4 + vec2(0.3, 0.7);
		float cir = texture(cloud_tex, cuv).b;
		cir = smoothstep(0.45, 0.95, cir) * 0.55 * (1.0 - storm);
		// cumulus
		vec2 uv = duv * 0.38 + wind;
		vec4 t = texture(cloud_tex, uv);
		float dens = t.r + (t.g - 0.5) * 0.12;
		float thr = 1.0 - cover * 0.62 - 0.12;
		float c = smoothstep(thr, thr + 0.30 + storm * 0.1, dens);
		// light comes from the sun side: compare density towards the sun to get lit tops and shaded bases
		vec2 sdir = normalize(sun_dir.xz + vec2(0.0001));
		float d2 = texture(cloud_tex, uv + sdir * 0.02).r + (texture(cloud_tex, uv + sdir * 0.02).g - 0.5) * 0.12;
		float lit_k = clamp(0.62 + (dens - d2) * 7.0, 0.0, 1.0);
		float thick = clamp((dens - thr) * 3.5, 0.0, 1.0);
		vec3 shadow_col = mix(vec3(0.52, 0.60, 0.74), vec3(0.40, 0.46, 0.60), thick);
		vec3 lit = mix(shadow_col, vec3(1.0, 0.99, 0.96), lit_k);
		vec3 stormy = mix(vec3(0.16, 0.18, 0.22), vec3(0.46, 0.49, 0.55), lit_k);
		vec3 cloud_col = mix(lit, stormy, storm);
		cloud_col = mix(cloud_col, cloud_col * vec3(0.12, 0.14, 0.22), night);
		vec3 warm = mix(vec3(1.0, 0.62, 0.42), vec3(1.0, 0.78, 0.6), lit_k);
		cloud_col = mix(cloud_col, warm * (0.55 + 0.45 * lit_k), dusk * 0.6 * (1.0 - storm));
		// silver lining on the thin edges facing the sun
		cloud_col += vec3(1.0, 0.95, 0.85) * pow(sd, 6.0) * (1.0 - thick) * 0.55 * sun_vis;
		cloud_col += vec3(0.75, 0.8, 1.0) * flash * 1.6;
		vec3 cir_col = mix(vec3(1.0), vec3(1.0, 0.7, 0.55), dusk) * mix(1.0, 0.08, night);
		col = mix(col, cir_col, cir * fade);
		col = mix(col, cloud_col, c * fade * 0.97);
	}
	col = mix(col, col * vec3(1.12, 0.98, 0.82) + vec3(0.06, 0.03, 0.0), heat);
	float hz = haze * (1.0 - smoothstep(0.55, 1.0, h) * 0.25);
	col = mix(col, haze_color, clamp(hz, 0.0, 1.0));
	col += vec3(0.7, 0.75, 1.0) * flash * 0.5;
	COLOR = col;
}
