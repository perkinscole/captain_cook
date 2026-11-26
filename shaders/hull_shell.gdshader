shader_type spatial;
render_mode cull_back;

// The outer shell of the ship: a modelled hull wrapped round the ship that
// is built in code. It is only ever seen from outside. From on board its
// inner faces are not drawn at all (so the view out of the cabin windows
// and over the rails is clear), and whatever it has of its own inside the
// ship's rails, such as its deck, is cut away, because the decks you walk
// on are the ones built in code.

#include "res://shaders/paint.gdshaderinc"

uniform sampler2D picture : source_color, filter_linear_mipmap, repeat_enable;
// How the model's own measurements map onto the ship's: metres per unit
// along her length, height and beam, and where its middle sits.
uniform vec3 fit_scale = vec3(16.6, 15.5, 14.6);
uniform float fit_up = 2.54;
uniform float fit_aft = -0.5;

varying vec3 ship_pos;
varying vec3 ship_normal;

void vertex() {
	// The model lies along its own X, bow toward -X; the ship lies along Z.
	ship_pos = vec3(VERTEX.z * fit_scale.z, VERTEX.y * fit_scale.y + fit_up,
			VERTEX.x * fit_scale.x + fit_aft);
	ship_normal = normalize(vec3(NORMAL.z, NORMAL.y, NORMAL.x));
}

void fragment() {
	// Half the ship's own breadth here (the same curve as ShipLayout.half_breadth).
	float u = clamp((ship_pos.z + 16.0) / 31.0, 0.0, 1.0);
	float bow = 1.0 - pow(1.0 - clamp(u / 0.3, 0.0, 1.0), 2.2);
	float stern = 1.0 - 0.22 * pow(clamp((u - 0.78) / 0.22, 0.0, 1.0), 2.0);
	if (ship_pos.y > 2.3 && abs(ship_pos.x) < 4.0 * bow * stern - 0.25) {
		discard;
	}
	float screen_px = 70.0 * VIEWPORT_SIZE.y / 720.0;
	vec4 paint = paint_on(ship_pos, ship_normal, 0.35, screen_px);
	ALBEDO = paint_colour(texture(picture, UV).rgb, paint, 0.1, ship_pos, 0.1);
	NORMAL = paint_relief(normalize(NORMAL), VERTEX, paint, 0.8);
	ROUGHNESS = 0.7;
}
