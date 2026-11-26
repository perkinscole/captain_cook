// Brush strokes painted onto surfaces.
//
// The strokes belong to the object, not the screen: they are laid out in the
// object's own space, so they stay put on the wood or the sail as it moves.
// Each stroke is one dab of the brush: a slightly different mix of the
// colour, with paint piled up along its sides and the marks of the hairs
// along its length. Strokes are kept about the same size on screen however
// far away the surface is, the way a painter uses the same brush for the
// near deck and the distant hill.

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

// One coat of strokes on a flat sheet. A stroke is 1 unit long and about a
// fifth as wide; rows of strokes overlap like courses of bricks.
// Returns (which mix of the colour this stroke is, how high the paint stands).
vec2 paint_strokes(vec2 uv, float turn) {
	float c = cos(turn);
	float s = sin(turn);
	uv = vec2(uv.x * c - uv.y * s, uv.x * s + uv.y * c);
	uv.y += 0.12 * (paint_noise(uv * 0.7) - 0.5);       // no hand paints a dead straight row
	float row = floor(uv.y / 0.22);
	float u = uv.x + paint_hash(vec2(row, 3.7)) * 7.0;  // each row starts somewhere different
	float stroke = floor(u);
	float mixed = paint_hash(vec2(stroke, row));
	float along = fract(u);
	float across = fract(uv.y / 0.22);
	// The brush pushes paint out to its sides and leaves a lip where it lifts off.
	float side = min(across, 1.0 - across);
	float tip = 1.0 - along;
	float ridge = 0.55 * (1.0 - smoothstep(0.0, 0.28, side)) + 0.45 * (1.0 - smoothstep(0.0, 0.08, tip));
	float hairs = paint_noise(vec2(across * 9.0 + mixed * 40.0, u * 1.4));
	return vec2(mixed, 0.4 * hairs + 0.45 * ridge + 0.15 * mixed);
}

// Strokes on a surface facing any way: three flat coats, one for each
// axis, blended by which way the surface faces.
vec2 paint_coat(vec3 pos, vec3 nrm, float size) {
	vec3 w = pow(abs(nrm), vec3(4.0));
	w /= (w.x + w.y + w.z + 0.0001);
	vec3 q = pos / size;
	return paint_strokes(q.zy, 0.35) * w.x + paint_strokes(q.xz, -0.5) * w.y
			+ paint_strokes(q.xy, 0.2) * w.z;
}

// The paint on a point of a surface.
//   pos, nrm     the point and which way it faces, in the object's own space
//   stroke       length of a stroke up close, in the object's units
//   screen_px    how many pixels long a stroke should look from far away
// Returns (mix of colour 0..1, height of paint 0..1, size of stroke used).
vec3 paint_on(vec3 pos, vec3 nrm, float stroke, float screen_px) {
	float px = max(length(dFdx(pos)), length(dFdy(pos)));   // object units per pixel
	float level = log2(max(px * screen_px / stroke, 1.0));
	float size = stroke * exp2(floor(level));
	float blend = smoothstep(0.55, 1.0, fract(level));
	vec2 coat = mix(paint_coat(pos, nrm, size), paint_coat(pos, nrm, size * 2.0), blend);
	return vec3(coat, mix(size, size * 2.0, blend));
}

// One colour as a painter would mix it for this stroke: now a little
// lighter and warmer, now darker and cooler.
vec3 paint_colour(vec3 base, vec3 paint, float variation) {
	float t = (paint.x - 0.5) * 2.0;
	vec3 mixed = base * mix(vec3(0.86, 0.91, 1.03), vec3(1.13, 1.05, 0.90), 0.5 + 0.5 * t);
	mixed = mix(base, mixed, variation * 4.0);
	return mixed * (1.0 - variation + 2.0 * variation * (0.35 + 0.65 * paint.y));
}

// Tilts a surface's normal to follow the thickness of the paint, so that
// the scene's own light catches the ridges. `vpos` is the view-space
// position and `n` the view-space normal.
vec3 paint_relief(vec3 n, vec3 vpos, vec3 paint, float relief) {
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
