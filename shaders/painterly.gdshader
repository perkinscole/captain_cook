shader_type canvas_item;

// Makes the 3D picture look painted. This is a Kuwahara filter: for every
// pixel it looks at four neighbouring patches, finds the one whose colours
// vary least, and uses that patch's average. Flat areas turn into smooth
// dabs of paint while edges stay sharp. A little colour grading, a darkened
// border and a canvas weave go on top.

const int RADIUS = 3;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float brush = 1.6;      // how far apart the samples are, in pixels
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.45;
uniform float weave : hint_range(0.0, 1.0) = 0.25;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * brush;
	vec3 plain = texture(screen_tex, SCREEN_UV).rgb;
	vec3 best = plain;
	float best_spread = 1000.0;
	float count = float((RADIUS + 1) * (RADIUS + 1));
	for (int q = 0; q < 4; q++) {
		vec2 dir = vec2((q == 0 || q == 2) ? -1.0 : 1.0, (q < 2) ? -1.0 : 1.0);
		vec3 sum = vec3(0.0);
		vec3 sum_sq = vec3(0.0);
		for (int i = 0; i <= RADIUS; i++) {
			for (int j = 0; j <= RADIUS; j++) {
				vec3 c = texture(screen_tex, SCREEN_UV + vec2(float(i), float(j)) * dir * px).rgb;
				sum += c;
				sum_sq += c * c;
			}
		}
		vec3 mean = sum / count;
		vec3 variance = abs(sum_sq / count - mean * mean);
		float spread = variance.r + variance.g + variance.b;
		if (spread < best_spread) {
			best_spread = spread;
			best = mean;
		}
	}
	vec3 col = mix(plain, best, amount);

	// Deeper shadows, warmer lights, a touch more colour.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, 1.18);
	col = mix(col, col * col * (3.0 - 2.0 * col), 0.35);
	col *= mix(vec3(0.92, 0.96, 1.05), vec3(1.06, 1.0, 0.92), smoothstep(0.1, 0.8, luma));

	// Canvas weave and a darkened border, like an old picture in its frame.
	vec2 grid = FRAGCOORD.xy;
	float threads = sin(grid.x * 1.9) * sin(grid.y * 1.9) * 0.5 + (hash(floor(grid * 0.5)) - 0.5);
	col += threads * 0.022 * weave;
	vec2 from_middle = SCREEN_UV - vec2(0.5);
	col *= 1.0 - vignette * smoothstep(0.25, 0.85, dot(from_middle, from_middle) * 2.0);

	COLOR = vec4(col, 1.0);
}
