// Brush strokes painted onto surfaces.
//
// The strokes belong to the object, not the screen: they are laid out in the
// object's own space, so they stay put on the wood or the sail as it moves.
// Each stroke is one dab of the brush: a slightly different mix of the
// colour, with paint piled up along its sides and the marks of the hairs
// along its length. Strokes are kept about the same size on screen however
// far away the surface is, the way a painter uses the same brush for the
// near deck and the distant hill.
//
// To keep it from looking mechanical, the way a real canvas does not:
//   - the surface is worked in patches, each brushed in its own direction;
//   - strokes differ in length from row to row;
//   - a second, sparser coat of broader strokes lies over the first;
//   - now and then a stroke is a bright accent or a dark one;
//   - thin dark ground shows in the gaps between strokes;
//   - under it all the colour drifts, warmer here and cooler there.

float paint_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float paint_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(paint_hash(i), paint_hash(i + vec2(1.0, 0.0)), u.x),
			mix(paint_hash(i + vec2(0.0, 1.0)), paint_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// One coat of strokes on a flat sheet. A stroke is about 1 unit long and a
// fifth as wide; rows of strokes overlap like courses of bricks.
// Returns (which mix of the colour this stroke is, how high the paint
// stands, how much bare ground shows here).
vec3 paint_strokes(vec2 uv, float turn) {
	// The painter works in patches, and brushes each one a different way.
	// The patches have wandering edges, not straight ones.
	vec2 wander = vec2(paint_noise(uv * 0.35), paint_noise(uv * 0.35 + vec2(17.0, 5.0)));
	vec2 patch_id = floor((uv + 2.5 * wander) / 4.5);
	turn += (paint_hash(patch_id) - 0.5) * 1.3;
	float c = cos(turn);
	float s = sin(turn);
	uv = vec2(uv.x * c - uv.y * s, uv.x * s + uv.y * c);
	uv.y += 0.14 * (paint_noise(uv * 0.7) - 0.5);       // no hand paints a dead straight row
	float row = floor(uv.y / 0.22);
	float reach = 0.65 + 0.9 * paint_hash(vec2(row, 9.1));   // long strokes and short ones
	float u = uv.x / reach + paint_hash(vec2(row, 3.7)) * 7.0;
	float stroke = floor(u);
	float mixed = paint_hash(vec2(stroke, row) + patch_id * 0.37);
	float along = fract(u);
	float across = fract(uv.y / 0.22);
	// The brush pushes paint out to its sides and leaves a lip where it lifts off.
	float side = min(across, 1.0 - across);
	float tip = 1.0 - along;
	float ridge = 0.55 * (1.0 - smoothstep(0.0, 0.28, side)) + 0.45 * (1.0 - smoothstep(0.0, 0.08, tip));
	float hairs = paint_noise(vec2(across * 9.0 + mixed * 40.0, u * reach * 1.4));
	// As the brush runs dry toward the end of a stroke, it skips, and the
	// ground shows through between the hairs and between the strokes.
	float dry = smoothstep(0.55, 1.0, along) * smoothstep(0.45, 0.75, hairs);
	float gap = max(1.0 - smoothstep(0.0, 0.045, side), 0.7 * dry);
	return vec3(mixed, 0.4 * hairs + 0.45 * ridge + 0.15 * mixed, gap);
}

// Two coats: fine strokes underneath and, over about half the surface,
// broader strokes laid across them at another angle.
vec3 paint_layers(vec2 uv, float turn) {
	vec3 under = paint_strokes(uv, turn);
	vec3 over = paint_strokes(uv * 0.55 + vec2(13.0, 29.0), turn + 1.05);
	float covers = step(0.5, over.x) * (1.0 - over.z);
	vec3 top = vec3(fract(over.x * 2.0), over.y + 0.35, over.z);
	return mix(under, top, covers);
}

// Strokes on a surface facing any way: three flat coats, one for each
// axis, blended by which way the surface faces.
vec3 paint_coat(vec3 pos, vec3 nrm, float size) {
	vec3 w = pow(abs(nrm), vec3(4.0));
	w /= (w.x + w.y + w.z + 0.0001);
	vec3 q = pos / size;
	return paint_layers(q.zy, 0.35) * w.x + paint_layers(q.xz, -0.5) * w.y
			+ paint_layers(q.xy, 0.2) * w.z;
}

// The paint on a point of a surface.
//   pos, nrm     the point and which way it faces, in the object's own space
//   stroke       length of a stroke up close, in the object's units
//   screen_px    how many pixels long a stroke should look from far away
// Returns (mix of colour 0..1, height of paint, size of stroke used, bare ground 0..1).
vec4 paint_on(vec3 pos, vec3 nrm, float stroke, float screen_px) {
	float px = max(length(dFdx(pos)), length(dFdy(pos)));   // object units per pixel
	float level = log2(max(px * screen_px / stroke, 1.0));
	float size = stroke * exp2(floor(level));
	float blend = smoothstep(0.55, 1.0, fract(level));
	vec3 coat = mix(paint_coat(pos, nrm, size), paint_coat(pos, nrm, size * 2.0), blend);
	return vec4(coat.xy, mix(size, size * 2.0, blend), coat.z);
}

// One colour as a painter would lay it down here.
//   base       the colour of the thing
//   paint      what paint_on returned
//   variation  how freely the colour is varied
//   pos        the point, in the object's space, for the slow drift of colour
vec3 paint_colour(vec3 base, vec4 paint, float variation, vec3 pos) {
	// Each stroke: now a little lighter and warmer, now darker and cooler.
	float t = (paint.x - 0.5) * 2.0;
	vec3 mixed = base * mix(vec3(0.84, 0.90, 1.04), vec3(1.15, 1.06, 0.88), 0.5 + 0.5 * t);
	mixed = mix(base, mixed, clamp(variation * 4.0, 0.0, 1.0));
	// The odd stroke is an accent: a touch of light, or a dark one.
	mixed *= 1.0 + variation * 2.2 * (smoothstep(0.9, 0.97, paint.x) - smoothstep(0.1, 0.03, paint.x));
	// Under the strokes the colour drifts across the surface in broad areas.
	float drift = paint_noise(pos.xz * 0.45 + pos.y * 0.31) - 0.5;
	float drift_hue = paint_noise(pos.zy * 0.3 + pos.x * 0.23 + vec2(40.0, 9.0)) - 0.5;
	mixed *= 1.0 + variation * 1.6 * drift;
	mixed *= mix(vec3(1.0), vec3(1.0 + 0.5 * drift_hue, 1.0, 1.0 - 0.5 * drift_hue), variation * 1.8);
	// Thicker paint is brighter; the dark ground shows in the gaps.
	mixed *= 1.0 - variation + 2.0 * variation * (0.35 + 0.65 * paint.y);
	return mixed * (1.0 - 0.38 * paint.w);
}

// Tilts a surface's normal to follow the thickness of the paint, so that
// the scene's own light catches the ridges. `vpos` is the view-space
// position and `n` the view-space normal.
vec3 paint_relief(vec3 n, vec3 vpos, vec4 paint, float relief) {
	float h = paint.y * paint.z * 0.035 * relief;
	vec3 dpdx = dFdx(vpos);
	vec3 dpdy = dFdy(vpos);
	float dhdx = dFdx(h);
	float dhdy = dFdy(h);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	if (abs(det) < 0.0000000001) {
		return n;   // seen exactly edge-on: leave the surface as it is
	}
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
	return normalize(abs(det) * n - grad);
}
