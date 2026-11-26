shader_type canvas_item;

// Oil paint, first pass: turn the picture into dabs of colour.
//
// For every pixel this looks at eight wedges of the picture around it, like
// slices of a pie. A wedge whose colours are all much alike is "one dab of
// paint"; a wedge that crosses an edge is not. The pixel takes its colour
// mostly from the calmest wedges. Flat areas melt into smooth dabs while
// edges stay crisp, which is how a loaded brush lays colour down.
// The second pass (impasto.gdshader) then gives the paint thickness.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float brush = 3.0;        // size of a dab, in pixels on a 720-line screen
uniform float amount : hint_range(0.0, 1.0) = 0.45;   // how much of the dab replaces the picture
uniform float crispness = 2.0;    // how strongly calm wedges win over busy ones

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	float radius = brush / (px.y * 720.0);
	vec3 total = vec3(0.0);
	float weight_sum = 0.0;
	for (int wedge = 0; wedge < 8; wedge++) {
		vec3 sum = vec3(0.0);
		vec3 sum_sq = vec3(0.0);
		for (int a = 0; a < 3; a++) {
			float angle = (float(wedge) + (float(a) - 1.0) * 0.33) * 0.7853982;
			vec2 dir = vec2(cos(angle), sin(angle));
			for (int r = 1; r <= 3; r++) {
				vec3 c = texture(screen_tex, SCREEN_UV + dir * (radius * float(r) / 3.0) * px).rgb;
				sum += c;
				sum_sq += c * c;
			}
		}
		vec3 mean = sum / 9.0;
		vec3 variance = abs(sum_sq / 9.0 - mean * mean);
		float busy = variance.r + variance.g + variance.b;
		float weight = 1.0 / (1.0 + pow(busy * 600.0, crispness));
		total += mean * weight;
		weight_sum += weight;
	}
	// The surfaces are already painted in strokes; too much smoothing on top
	// turns them to mush, so the dabs are only laid partly over the picture.
	vec3 sharp = texture(screen_tex, SCREEN_UV).rgb;
	COLOR = vec4(mix(sharp, total / max(weight_sum, 0.00001), amount), 1.0);
}
