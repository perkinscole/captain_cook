shader_type spatial;
render_mode cull_disabled;

// A surface painted in oils. See paint.gdshaderinc for how the strokes work.

#include "res://shaders/paint.gdshaderinc"

uniform vec3 tint : source_color = vec3(1.0);
uniform float stroke = 0.3;                              // length of a stroke up close
uniform float variation : hint_range(0.0, 0.5) = 0.12;   // how much each stroke's colour differs
uniform float relief : hint_range(0.0, 2.0) = 1.0;       // how thick the paint stands
uniform float roughness : hint_range(0.0, 1.0) = 0.6;    // oil paint has a soft shine
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

varying vec3 object_pos;
varying vec3 object_normal;

void vertex() {
	object_pos = VERTEX;
	object_normal = NORMAL;
}

void fragment() {
	float screen_px = 70.0 * VIEWPORT_SIZE.y / 720.0;
	vec3 paint = paint_on(object_pos, normalize(object_normal), stroke, screen_px);
	ALBEDO = paint_colour(tint * COLOR.rgb, paint, variation);
	NORMAL = paint_relief(normalize(NORMAL), VERTEX, paint, relief);
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
