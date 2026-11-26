shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;

// A waterfall seen from far off: white threads sliding down a dark valley.
// UV.x runs across the fall and UV.y down it, in metres.

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float threads = vnoise(vec2(UV.x * 9.0, UV.y * 0.12 - TIME * 1.6));
	float gusts = vnoise(vec2(UV.x * 3.0, UV.y * 0.04 - TIME * 0.5));
	float middle = 1.0 - abs(UV.x * 2.0 - 1.0);
	ALBEDO = vec3(0.93, 0.96, 0.97);
	ROUGHNESS = 0.9;
	ALPHA = clamp(smoothstep(0.25, 0.7, threads * 0.6 + gusts * 0.5) * smoothstep(0.0, 0.5, middle), 0.0, 0.92);
}
