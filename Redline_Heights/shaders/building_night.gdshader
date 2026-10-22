shader_type spatial;
// A building facade that keeps its daytime look and, at night, shows warm light only through its windows (light from inside).
// mode 0: windows are the dark parts of the texture; mode 1: a grid of windows laid out by world position (floors x bays),
// some of them lit; mode 2: windows from a separate emission map; mode 3: a pane mask (R = per-pane random value, 0 outside
// windows; G = per-pane warmth); mode 4: the same, but the per-pane values are baked into the vertex colours (glass panes that
// are separate geometry in the model): a pane is lit when R is above 1 - lit_frac, so only real window panes ever glow.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D emit_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_col : source_color = vec4(1.0);
uniform bool has_tex = true;
uniform int mode = 0;
uniform float thr = 0.12;
uniform float night = 0.0;
uniform float gain = 1.0;
uniform vec3 warm : source_color = vec3(1.0, 0.76, 0.42);
uniform float floor_h = 3.6;
uniform float cell_w = 2.6;
uniform float lit_frac = 0.55;
uniform float metal = 0.0;
uniform float rough = 0.8;
uniform bool radial = false;          // curved tower: measure along the wall by arc length round `center` (a normal-based tangent swirls on curves)
uniform vec2 center = vec2(0.0);
uniform bool facade = false;          // procedural office: the texture is one window cell, repeated by world position
uniform vec3 roof_col : source_color = vec3(0.42, 0.43, 0.45);
varying vec3 wpos;
varying vec3 wnrm;
varying vec2 vcol;

float h2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vcol = COLOR.rg;
}

float along(vec3 p, vec3 n) {
	if (radial) {
		vec2 d = p.xz - center;
		return atan(d.y, d.x) * length(d);
	}
	return dot(p.xz, vec2(-n.z, n.x));
}

void fragment() {
	vec4 t = has_tex ? texture(albedo_tex, UV) : vec4(1.0);
	ALBEDO = t.rgb * albedo_col.rgb;
	if (facade) {
		float fw = 1.0 - smoothstep(0.35, 0.6, abs(wnrm.y));
		float fxx = along(wpos, wnrm) / cell_w;
		float fyy = wpos.y / floor_h;
		vec3 ft = texture(albedo_tex, vec2(fxx, -fyy)).rgb * albedo_col.rgb;
		ALBEDO = mix(roof_col, ft, fw);
	}
	ROUGHNESS = rough;
	METALLIC = metal;
	float lit = 0.0;
	vec3 glow = warm;
	if (mode == 4) {
		lit = step(1.0 - lit_frac, vcol.x) * step(0.01, vcol.x);
		glow = mix(vec3(1.0, 0.55, 0.25), vec3(1.0, 0.88, 0.62), vcol.y);
	} else if (mode == 3) {
		vec3 pm = texture(emit_tex, UV).rgb;
		lit = step(0.01, pm.r) * step(1.0 - lit_frac, pm.r);
		glow = mix(vec3(1.0, 0.55, 0.25), vec3(1.0, 0.88, 0.62), pm.g);
	} else if (mode == 0) {
		float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
		lit = smoothstep(thr + 0.02, thr - 0.02, lum);
		lit *= step(1.0 - lit_frac, h2(floor(UV * 48.0)));
	} else if (mode == 2) {
		lit = texture(emit_tex, UV).r;
		lit *= step(1.0 - lit_frac, h2(floor(UV * 40.0)));
	} else {
		float wall = 1.0 - smoothstep(0.35, 0.6, abs(wnrm.y));
		float tx = along(wpos, wnrm);
		float fy = wpos.y / floor_h;
		float fx = tx / cell_w;
		float in_win = step(0.2, fract(fy)) * step(fract(fy), 0.78) * step(0.14, fract(fx)) * step(fract(fx), 0.86);
		float rnd = h2(vec2(floor(fx), floor(fy)) + floor(dot(wpos.xz, wnrm.xz) * 0.31));
		lit = wall * in_win * step(1.0 - lit_frac, rnd);
	}
	EMISSION = glow * lit * night * gain;
}
