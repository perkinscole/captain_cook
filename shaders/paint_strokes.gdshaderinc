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
// `freedom` is how far the brushing may turn from patch to patch (0..1).
// Returns (which mix of the colour this stroke is, how high the paint
// stands, how much bare ground shows here).
vec3 paint_strokes(vec2 uv, float turn, float freedom) {
	// The painter works in patches, and brushes each one a different way.
	// The patches have wandering edges, not straight ones.
	vec2 wander = vec2(paint_noise(uv * 0.35), paint_noise(uv * 0.35 + vec2(17.0, 5.0)));
	vec2 patch_id = floor((uv + 2.5 * wander) / 4.5);
	turn += (paint_hash(patch_id) - 0.5) * 1.3 * freedom;
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
vec3 paint_layers(vec2 uv, float turn, float freedom) {
	vec3 under = paint_strokes(uv, turn, freedom);
	vec3 over = paint_strokes(uv * 0.55 + vec2(13.0, 29.0), turn + 1.05 * freedom, freedom);
	float covers = step(0.5, over.x) * (1.0 - over.z);
	vec3 top = vec3(fract(over.x * 2.0), over.y + 0.35, over.z);
	return mix(under, top, covers);
}
