shader_type spatial;
render_mode cull_disabled;

// Deck planking: boards running fore and aft with dark caulked seams,
// painted in strokes that run along the boards.

#include "res://shaders/paint.gdshaderinc"

uniform vec3 wood : source_color = vec3(0.62, 0.52, 0.36);

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	float width = 0.28;
	float plank = floor(local_pos.x / width);
	float along = local_pos.z + paint_hash(vec2(plank, 1.0)) * 5.0;
	float board = floor(along / 5.0);
	float tone = 0.82 + 0.3 * paint_hash(vec2(plank * 7.3, board * 1.7));

	float across = fract(local_pos.x / width);
	float seam = 1.0 - smoothstep(0.006, 0.02, min(across, 1.0 - across) * width);
	float butt_at = fract(along / 5.0);
	float butt = 1.0 - smoothstep(0.006, 0.02, min(butt_at, 1.0 - butt_at) * 5.0);

	float screen_px = 70.0 * VIEWPORT_SIZE.y / 720.0;
	vec3 paint = paint_on(local_pos, normalize(local_normal), 0.3, screen_px);
	vec3 colour = paint_colour(wood * tone, paint, 0.1);
	ALBEDO = colour * (1.0 - 0.75 * max(seam, butt));
	NORMAL = paint_relief(normalize(NORMAL), VERTEX, paint, 0.8);
	ROUGHNESS = 0.7;
}
