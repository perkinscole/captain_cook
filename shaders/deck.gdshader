shader_type spatial;
render_mode cull_disabled;

// Deck planking: boards running fore and aft, with dark caulked seams.

uniform vec3 wood : source_color = vec3(0.62, 0.52, 0.36);

varying vec3 local_pos;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float width = 0.28;
	float plank = floor(local_pos.x / width);
	float along = local_pos.z + hash(plank) * 5.0;
	float board = floor(along / 5.0);
	float tone = 0.82 + 0.3 * hash(plank * 7.3 + board * 1.7);

	float across = fract(local_pos.x / width);
	float seam = 1.0 - smoothstep(0.006, 0.02, min(across, 1.0 - across) * width);
	float butt_at = fract(along / 5.0);
	float butt = 1.0 - smoothstep(0.006, 0.02, min(butt_at, 1.0 - butt_at) * 5.0);

	ALBEDO = wood * tone * (1.0 - 0.75 * max(seam, butt));
	ROUGHNESS = 0.9;
}
