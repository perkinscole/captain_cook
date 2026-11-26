shader_type canvas_item;

// Oil paint, second pass: give the dabs thickness.
//
// Real oil paint stands up from the canvas. A brush leaves ridges along the
// way it travelled, the paint is thickest in the lights, and the room's
// light catches every ridge. This pass:
//   1. works out which way a brush would have travelled at each point
//      (along the edges of shapes, and wandering in open areas);
//   2. lays brush-hair ridges along that direction;
//   3. lights the ridges from the upper left, with small glints;
//   4. lets the canvas weave show through where the paint is thin and dark;
//   5. groups tones into a few steps, as a painter mixing a limited palette
//      does, and adds old varnish and a darkened border.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float relief : hint_range(0.0, 2.0) = 1.0;     // how thick the paint stands
uniform float bristles : hint_range(0.0, 2.0) = 1.0;   // how marked the brush hairs are
uniform float weave : hint_range(0.0, 1.0) = 0.6;      // how much canvas shows
uniform float vignette : hint_range(0.0, 1.0) = 0.5;
uniform float palette_steps = 9.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// Height of the paint at a point, for a brush travelling along `along`:
// long streaks in the direction of travel, fine ridges across it.
float brushed(vec2 q, vec2 along) {
	vec2 across = vec2(-along.y, along.x);
	vec2 st = vec2(dot(q, along) * 0.035, dot(q, across) * 0.55);
	return 0.65 * vnoise(st) + 0.35 * vnoise(st * vec2(2.3, 2.1) + vec2(31.0, 7.0));
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	float scale = 1.0 / (px.y * 720.0);       // so the strokes are the same size on any screen
	vec2 q = FRAGCOORD.xy / scale;
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float tone = luma(col);

	// Where shapes meet, a brush follows the edge. Find the edge.
	vec2 step_x = vec2(2.0 * scale, 0.0) * px;
	vec2 step_y = vec2(0.0, 2.0 * scale) * px;
	float across_x = luma(texture(screen_tex, SCREEN_UV + step_x).rgb)
			- luma(texture(screen_tex, SCREEN_UV - step_x).rgb);
	float across_y = luma(texture(screen_tex, SCREEN_UV + step_y).rgb)
			- luma(texture(screen_tex, SCREEN_UV - step_y).rgb);
	vec2 grad = vec2(across_x, across_y);
	float edge = length(grad);

	// In open areas the brush wanders in long lazy curves.
	float wander = vnoise(q * 0.004) * 6.2831853;
	vec2 open_dir = vec2(cos(wander), sin(wander));
	vec2 edge_dir = open_dir;
	if (edge > 0.0001) {
		edge_dir = vec2(-grad.y, grad.x) / edge;
		if (dot(edge_dir, open_dir) < 0.0) {
			edge_dir = -edge_dir;
		}
	}
	vec2 along = normalize(mix(open_dir, edge_dir, smoothstep(0.01, 0.07, edge)) + vec2(0.0001));

	// The paint: thick in the lights, thin in the darks.
	float body = smoothstep(0.12, 0.9, tone);
	float h0 = brushed(q, along);
	float hx = brushed(q + vec2(1.5, 0.0), along);
	float hy = brushed(q + vec2(0.0, 1.5), along);
	vec2 slope = vec2(hx - h0, hy - h0) * (0.5 + 1.7 * body) * bristles;
	slope += grad * 1.4;                      // a ridge where one colour is laid against another
	vec3 normal = normalize(vec3(-slope * 3.2 * relief, 1.0));

	// Lit from the upper left, as a picture on a wall is.
	vec3 light = normalize(vec3(-0.5, -0.6, 0.62));
	float shade = dot(normal, light) / light.z;
	col *= mix(1.0, shade, 0.6);
	float glint = pow(max(dot(normal, normalize(light + vec3(0.0, 0.0, 1.0))), 0.0), 48.0);
	col += vec3(1.0, 0.97, 0.9) * glint * 0.16 * (0.3 + body) * relief;
	col *= 0.92 + 0.16 * h0;                  // streaks of pigment in the stroke

	// Group the tones into a few steps, like colours mixed on a palette.
	float stepped = floor(tone * palette_steps + 0.5) / palette_steps;
	col *= mix(1.0, (stepped + 0.03) / (tone + 0.03), 0.4);

	// Canvas shows through thin paint.
	float threads = sin(q.x * 2.4) * sin(q.y * 2.4) + 0.6 * (hash(floor(q * 0.6)) - 0.5);
	col += threads * 0.035 * weave * (1.0 - body);

	// Richer colour, deeper shadows, warm lights and cool darks.
	float l = luma(col);
	col = mix(vec3(l), col, 1.22);
	col = mix(col, col * col * (3.0 - 2.0 * col), 0.4);
	col *= mix(vec3(0.90, 0.95, 1.06), vec3(1.07, 1.0, 0.90), smoothstep(0.1, 0.8, l));
	col *= vec3(1.02, 0.99, 0.93);            // a century of yellowed varnish

	vec2 from_middle = SCREEN_UV - vec2(0.5);
	col *= 1.0 - vignette * smoothstep(0.22, 0.85, dot(from_middle, from_middle) * 2.0);

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
