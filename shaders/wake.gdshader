shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;

// The ship's wake: churned white water that spreads and fades astern.
// UV.x runs across the wake, UV.y along it; the vertex colour's alpha says
// how fresh each part is.

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
	float across = abs(UV.x * 2.0 - 1.0);  // 0 in the middle, 1 at the edges
	float churn = vnoise(vec2(UV.x * 9.0, UV.y * 0.35 - TIME * 0.2))
			* vnoise(vec2(UV.x * 23.0, UV.y * 0.9 + TIME * 0.1));
	// Strongest along the two edges, where the bow wave rolls off.
	float shape = mix(0.45, 1.0, smoothstep(0.45, 0.9, across)) * (1.0 - smoothstep(0.9, 1.0, across));
	ALBEDO = vec3(0.94, 0.96, 0.94);
	ROUGHNESS = 0.8;
	ALPHA = clamp(COLOR.a * shape * smoothstep(0.05, 0.3, churn) * 1.4, 0.0, 0.9);
}
