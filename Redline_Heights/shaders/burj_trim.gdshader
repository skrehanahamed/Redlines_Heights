shader_type spatial;
// Burj Khalifa trim (the tiered podium and the silver ribs): polished silver with fine vertical fins and floor lines by day;
// at night those grooves become LED strips whose colours drift and pulse upward, like the tower's light show.
uniform float night = 0.0;
uniform float gain = 1.0;
uniform float floor_h = 3.8;
uniform float fin_w = 0.9;
uniform vec2 center = vec2(145.0, 2156.0);
varying vec3 wpos;
varying vec3 wnrm;

vec3 hsv(float h, float s, float v) {
	vec3 k = clamp(abs(fract(vec3(h) + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return v * mix(vec3(1.0), k, s);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float side = 1.0 - smoothstep(0.35, 0.65, abs(wnrm.y));
	vec2 d = wpos.xz - center;
	float tx = atan(d.y, d.x) * length(d) / fin_w;   // arc length: no swirls on the curved tiers
	float fx = abs(fract(tx) - 0.5) * 2.0;                       // 1 at the fin edge, 0 in the middle
	float fy = abs(fract(wpos.y / floor_h) - 0.5) * 2.0;
	float groove = max(smoothstep(0.82, 0.96, fx), smoothstep(0.88, 0.98, fy)) * side;

	vec3 silver = vec3(0.86, 0.89, 0.94);
	ALBEDO = mix(silver, vec3(0.10, 0.12, 0.16), groove * 0.85);
	METALLIC = 0.9;
	ROUGHNESS = mix(0.22, 0.45, groove);

	// light show
	float hue = fract(wpos.y * 0.006 + wpos.x * 0.002 - TIME * 0.05);
	float wave = 0.55 + 0.45 * sin(wpos.y * 0.30 - TIME * 2.2);
	vec3 col = hsv(hue, 0.85, 1.0);
	float led = groove * (0.45 + 0.55 * wave);
	float wash = (1.0 - side) * 0.25 * wave;                      // tier tops catch a soft colour wash
	EMISSION = col * (led * 2.2 + wash) * night * gain;
}
