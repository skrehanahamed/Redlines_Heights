shader_type spatial;
render_mode cull_back, depth_draw_always;
// Car paint with see-through windows. The PSX car textures bake the glass in as dark, slightly cool-tinted
// texels (neutral greys are trim and tyres, saturated colours are paint), so those texels become translucent.
// The texture is sampled raw (sRGB) so the colour thresholds match what the artist painted.

uniform sampler2D albedo_tex : filter_nearest_mipmap, repeat_enable;
uniform float glass_max_lum = 0.27;
uniform float glass_alpha = 0.58;
uniform float roughness_val = 0.75;

vec3 to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.001);
	float cool = c.b - c.r;
	float glass = step(lum, glass_max_lum) * step(0.014, cool) * step(0.015, c.g - c.r) * step(sat, 0.45) * step(0.03, lum);
	// tinted glass: dark cool tint, translucent, with a little shine
	vec3 col = mix(c.rgb, vec3(0.05, 0.09, 0.12), glass * 0.8);   // dark tint
	ALBEDO = to_linear(col);
	SPECULAR = mix(0.5, 0.9, glass);
	ROUGHNESS = mix(roughness_val, 0.15, glass);
	ALPHA = mix(1.0, glass_alpha, glass);
}
