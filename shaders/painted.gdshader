shader_type spatial;
render_mode cull_disabled;

// A surface painted in oils. See paint.gdshaderinc for how the strokes work.

#include "res://shaders/paint.gdshaderinc"

uniform vec3 tint : source_color = vec3(1.0);
uniform float stroke = 0.3;                              // length of a stroke up close
uniform float variation : hint_range(0.0, 0.5) = 0.17;   // how much each stroke's colour differs
uniform float relief : hint_range(0.0, 2.0) = 1.25;      // how thick the paint stands
uniform float ground : hint_range(0.0, 0.5) = 0.18;     // how dark the gaps between strokes are
uniform float roughness : hint_range(0.0, 1.0) = 0.6;    // oil paint has a soft shine
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
// Darkens the underside of a thing, as leaves are darker beneath a tree.
uniform float shade_below : hint_range(0.0, 1.0) = 0.0;

varying vec3 object_pos;
varying vec3 object_normal;

void vertex() {
	// Measure in real metres even if the object has been stretched or
	// squashed, so a stroke is the same size on a head as on a mast.
	vec3 stretch = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz),
			length(MODEL_MATRIX[2].xyz));
	object_pos = VERTEX * stretch;
	object_normal = NORMAL / max(stretch, vec3(0.0001));
}

void fragment() {
	float screen_px = 70.0 * VIEWPORT_SIZE.y / 720.0;
	vec4 paint = paint_on(object_pos, normalize(object_normal), stroke, screen_px);
	vec3 base = tint * COLOR.rgb;
	base *= 1.0 - shade_below * (1.0 - smoothstep(-0.7, 0.6, normalize(object_normal).y));
	ALBEDO = paint_colour(base, paint, variation, object_pos, ground);
	NORMAL = paint_relief(normalize(NORMAL), VERTEX, paint, relief);
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
