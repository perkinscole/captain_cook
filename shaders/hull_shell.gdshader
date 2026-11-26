shader_type spatial;
render_mode cull_back;

// The modelled hull. It has been reshaped (tools/fit_hull.py) to fit the
// ship that is built in code, and is in her measure: metres, x to starboard,
// y up, z aft. Her planked sides, the inside of her bulwarks and her decks
// are drawn from it. What it has of its own standing on the decks and across
// the breaks is cut away, because the bulkheads, ladders and fittings there
// are the built ones; so is whatever stands above the line of the rail, and
// the deck over the hatch that leads below. Its inner faces toward the sea
// are not drawn, so the view out of the cabin windows stays clear.

#include "res://shaders/paint.gdshaderinc"

uniform sampler2D picture : source_color, filter_linear_mipmap, repeat_enable;
// The ship's plan (ShipLayout).
uniform vec3 deck_heights = vec3(4.05, 3.15, 5.25);   // forecastle, waist, quarterdeck
uniform vec2 breaks = vec2(-7.5, 4.0);
uniform float bulwark = 1.05;
uniform vec4 hatch = vec4(-1.7, 0.55, -0.6, 1.6);     // x, half width, z from, z to
uniform float deck_lift = 0.02;

varying vec3 ship_pos;
varying vec3 ship_normal;

float deck_top(float z) {
	float fore = 1.0 - smoothstep(breaks.x - 0.12, breaks.x + 0.12, z);
	float aft = smoothstep(breaks.y - 0.12, breaks.y + 0.12, z);
	return deck_heights.y + (deck_heights.x - deck_heights.y) * fore
			+ (deck_heights.z - deck_heights.y) * aft;
}

void vertex() {
	ship_pos = VERTEX;
	ship_normal = NORMAL;
}

void fragment() {
	// Half the ship's own breadth here (the same curve as ShipLayout.half_breadth).
	float u = clamp((ship_pos.z + 16.0) / 31.0, 0.0, 1.0);
	float bow = 1.0 - pow(1.0 - clamp(u / 0.3, 0.0, 1.0), 2.2);
	float stern = 1.0 - 0.22 * pow(clamp((u - 0.78) / 0.22, 0.0, 1.0), 2.0);
	float half_breadth = 4.0 * bow * stern;
	float deck = deck_top(ship_pos.z);
	float rail = deck + bulwark + 0.45 * pow(abs(u - 0.5) * 2.0, 2.0);
	vec3 facing = normalize(ship_normal);

	// Above the rail, except the stem head and the taffrail.
	if (ship_pos.y > rail + 0.02 && ship_pos.z > -14.6 && ship_pos.z < 14.9) {
		discard;
	}
	// Inboard of the bulwarks only the deck planking is kept. The outer
	// faces of her stern and bows are inboard too, by that measure, and stay.
	bool inboard = abs(ship_pos.x) < half_breadth - 0.45;
	bool end_face = (ship_pos.z > 11.0 && facing.z > 0.4)
			|| (ship_pos.z < -12.0 && facing.z < -0.4);
	if (inboard && !end_face && ship_pos.y > 2.3
			&& abs(ship_pos.y - deck - deck_lift) > 0.05) {
		discard;
	}
	// The hatch and its ladder.
	if (abs(ship_pos.x - hatch.x) < hatch.y + 0.06 && ship_pos.z > hatch.z - 0.06
			&& ship_pos.z < hatch.w + 0.06 && ship_pos.y > 2.3) {
		discard;
	}
	float screen_px = 70.0 * VIEWPORT_SIZE.y / 720.0;
	vec4 paint = paint_on(ship_pos, facing, 0.35, screen_px);
	ALBEDO = paint_colour(texture(picture, UV).rgb, paint, 0.1, ship_pos, 0.1);
	NORMAL = paint_relief(normalize(NORMAL), VERTEX, paint, 0.8);
	ROUGHNESS = 0.7;
}
