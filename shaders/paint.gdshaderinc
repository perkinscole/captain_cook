// Brush strokes painted onto solid surfaces. The strokes themselves are
// described in paint_strokes.gdshaderinc; this file lays them on objects.

#include "res://shaders/paint_strokes.gdshaderinc"

// Strokes on a surface facing any way: three flat coats, one for each
// axis, blended by which way the surface faces.
vec3 paint_coat(vec3 pos, vec3 nrm, float size) {
	vec3 w = pow(abs(nrm), vec3(4.0));
	w /= (w.x + w.y + w.z + 0.0001);
	vec3 q = pos / size;
	return paint_layers(q.zy, 0.35, 1.0) * w.x + paint_layers(q.xz, -0.5, 1.0) * w.y
			+ paint_layers(q.xy, 0.2, 1.0) * w.z;
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
