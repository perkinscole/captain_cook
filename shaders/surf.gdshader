shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;

// Surf along the shore: lines of white water running in and fading.

varying vec2 along_across;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void vertex() {
	along_across = UV;
}

void fragment() {
	float along = along_across.x;
	float across = along_across.y;  // 0 at the beach, 1 out at sea
	float cell = floor(along * 0.25);
	float lag = mix(hash(cell), hash(cell + 1.0), smoothstep(0.0, 1.0, fract(along * 0.25)));
	float run = fract(across * 1.6 + TIME * 0.16 + lag);
	float line = smoothstep(0.0, 0.12, run) * (1.0 - smoothstep(0.12, 0.55, run));
	float lace = 0.6 + 0.4 * sin(along * 3.0 + TIME * 1.3 + lag * 6.0);
	float ends = smoothstep(0.0, 0.15, across) * (1.0 - smoothstep(0.7, 1.0, across));
	ALBEDO = vec3(0.95, 0.97, 0.95);
	ROUGHNESS = 0.8;
	ALPHA = clamp(line * lace * ends * 0.85, 0.0, 1.0);
}
