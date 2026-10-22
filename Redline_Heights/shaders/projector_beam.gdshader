shader_type spatial;
// The visible light beam of a Burj projector: a soft cone from the lens to the tower, bright in the middle and faint at the
// edges, dimming along its length, tinted saffron / white / green by the height it passes (the colours it is about to paint).
render_mode unshaded, blend_add, cull_back, depth_draw_never;

uniform float night = 0.0;
uniform float length_m = 40.0;
uniform float strength = 0.45;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = clamp(0.5 - VERTEX.y / length_m, 0.0, 1.0);          // 0 at the lens, 1 at the tower
	float core = pow(clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 3.2);
	float fade = 1.0 * (0.45 + 0.55 * (1.0 - t * 0.5)) * smoothstep(0.0, 0.06, t);
	vec3 saffron = vec3(1.0, 0.50, 0.08);
	vec3 white = vec3(1.0, 1.0, 1.0);
	vec3 green = vec3(0.08, 0.85, 0.30);
	vec3 col = mix(green, white, smoothstep(34.0, 46.0, wpos.y));
	col = mix(col, saffron, smoothstep(56.0, 68.0, wpos.y));
	col = mix(vec3(1.0, 0.95, 0.85), col, smoothstep(0.0, 0.25, t));  // white-hot at the lens
	float dust = 0.9 + 0.1 * sin(TIME * 3.0 + wpos.y * 0.35 + wpos.x * 0.2);
	ALBEDO = col;
	ALPHA = core * fade * strength * night * dust;
}
