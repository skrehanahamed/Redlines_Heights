shader_type spatial;
// A flag cloth waving in the wind: the cloth is a flat grid pinned along its left edge (UV.x = 0). Each vertex is pushed sideways and up/down by
// travelling waves that grow away from the pole; the lighting normal follows the wave so the folds catch the light.
render_mode cull_disabled;
uniform vec3 cloth : source_color = vec3(0.88, 0.12, 0.14);
uniform vec3 stripe : source_color = vec3(1.0, 1.0, 1.0);
uniform float speed = 3.2;
uniform float amp = 0.16;
uniform float wind_dir = 0.0;       // radians, the way the flag streams (world yaw offset handled by the mesh rotation)

float wave(vec2 uv, float t) {
	float a = uv.x;
	return sin(uv.x * 9.0 - t * speed + uv.y * 2.4) * a + 0.4 * sin(uv.x * 17.0 - t * speed * 1.7 + uv.y * 5.0) * a * a;
}

void vertex() {
	float t = TIME;
	float w = wave(UV, t);
	VERTEX.z += w * amp;
	VERTEX.y += sin(UV.x * 6.0 - t * speed * 0.8) * UV.x * amp * 0.4;
	float e = 0.02;
	float dw = (wave(UV + vec2(e, 0.0), t) - w) / e;
	NORMAL = normalize(vec3(-dw * amp * 0.12, 0.0, 1.0));
}

void fragment() {
	float band = step(0.38, UV.y) * step(UV.y, 0.62);
	ALBEDO = mix(cloth, stripe, band);
	ROUGHNESS = 0.85;
	BACKLIGHT = vec3(0.25);
}
