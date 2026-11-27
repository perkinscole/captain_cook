shader_type spatial;

// The ground of the island, painted in oils.
//
// The shape of the land comes from a height map that was made by wearing a
// volcano down with rivers (tools/make_island.py). Nothing here is drawn by
// hand: what covers each spot is decided by rule from the lie of the land,
// the way a landscape painter reads a hillside. Steep ground is bare rock,
// in bands where the old lava flows show. Hollows where the water gathers
// are dark, wet forest; open ridges and high ground carry pale fern;
// the plain is bright with groves; the shore is sand, black or white.
// With that goes light worked out beforehand over the whole island: how
// much sky each spot sees, and where the peaks throw their shadows.

#include "res://shaders/paint.gdshaderinc"

uniform sampler2D heights : filter_linear, repeat_disable;   // metres
uniform sampler2D masks : filter_linear, repeat_disable;     // sky, sun, water, rock
uniform float span = 1024.0;
uniform float texel = 1.0;
uniform float sun_shadow : hint_range(0.0, 1.0) = 0.62;   // how dark the baked shadows are
uniform float stroke = 0.55;

varying vec3 land_pos;

float height_at(vec2 xz) {
	return texture(heights, xz / span + 0.5).r;
}

float layered(vec2 p) {
	return 0.5 * paint_noise(p) + 0.3 * paint_noise(p * 2.3 + 17.0) + 0.2 * paint_noise(p * 5.1 + 41.0);
}

void vertex() {
	land_pos = VERTEX;
}

void fragment() {
	vec2 xz = land_pos.xz;
	// The lie of the land, finer than the mesh.
	float e = texel;
	float h = height_at(xz);
	vec3 lie = normalize(vec3(height_at(xz - vec2(e, 0.0)) - height_at(xz + vec2(e, 0.0)),
			2.0 * e, height_at(xz - vec2(0.0, e)) - height_at(xz + vec2(0.0, e))));
	float slope = sqrt(max(1.0 - lie.y * lie.y, 0.0)) / max(lie.y, 0.05);
	vec4 mask = texture(masks, xz / span + 0.5);
	float sky = mask.r;
	float sunlit = mask.g;
	float wet = mask.b;

	float broad = layered(xz / 60.0);
	float patch = layered(xz / 9.0);
	float fine = layered(xz / 2.2);

	// Forest: dark in the wet hollows, paler fern on open ridges and heights.
	vec3 forest = mix(vec3(0.045, 0.125, 0.045), vec3(0.085, 0.20, 0.06), patch);
	vec3 fern = mix(vec3(0.20, 0.33, 0.10), vec3(0.32, 0.40, 0.14), broad);
	float open = smoothstep(0.62, 0.95, sky + 0.25 * (patch - 0.5))
			* smoothstep(18.0, 95.0, h + 30.0 * (broad - 0.5));
	vec3 green = mix(forest, fern, open);
	green *= 1.0 - 0.4 * smoothstep(0.38, 0.8, wet);
	// The plain: breadfruit and coconut groves, gardens, grass.
	vec3 grove = mix(vec3(0.13, 0.27, 0.08), vec3(0.30, 0.42, 0.15), smoothstep(0.35, 0.7, patch));
	green = mix(grove, green, smoothstep(9.0, 20.0, h + 6.0 * (broad - 0.5)));

	// Rock where it is too steep for much to grow: old lava in level bands,
	// grey to rust, with ferns hanging on where they can.
	float bands = 0.5 + 0.5 * sin(h * 1.4 + 6.0 * broad) * sin(h * 0.37 + 3.0 * patch);
	vec3 stone = mix(vec3(0.115, 0.105, 0.10), vec3(0.24, 0.20, 0.17), bands);
	stone = mix(stone, vec3(0.30, 0.17, 0.11), smoothstep(0.55, 0.9, broad) * 0.7);
	stone *= 0.8 + 0.4 * fine;
	float bare = smoothstep(1.15, 1.9, slope + 0.5 * (patch - 0.5) + 0.25 * (fine - 0.5));
	bare *= 0.55 + 0.45 * smoothstep(0.3, 0.7, mask.a + 0.4 * (broad - 0.5));
	vec3 land = mix(green, stone, bare);

	// Streams show as a thread of pale water in the valley floors.
	float stream = smoothstep(0.62, 0.74, wet) * (1.0 - smoothstep(0.2, 1.2, slope));
	land = mix(land, vec3(0.42, 0.52, 0.50), 0.55 * stream);

	// The shore: black volcanic sand on most beaches, pale coral sand on
	// some, darker where the sea has just been.
	vec3 sand = mix(vec3(0.085, 0.08, 0.08), vec3(0.72, 0.65, 0.48), smoothstep(0.42, 0.6, broad));
	sand *= mix(0.62, 1.0, smoothstep(0.1, 0.9, h));
	land = mix(sand, land, smoothstep(1.3, 2.6, h + 0.8 * (patch - 0.5)));
	// Below the tide: sand and coral seen through shallow water.
	land = mix(vec3(0.16, 0.30, 0.27), land, smoothstep(-2.5, 0.05, h));

	// Light that was worked out beforehand.
	float tops = (1.0 - bare) * smoothstep(2.6, 9.0, h);     // where there are treetops
	land *= mix(1.0, 0.72 + 0.56 * fine, 0.6 * tops);        // sunlit crowns, dark gaps
	land *= mix(1.0 - sun_shadow, 1.0, sunlit);
	land *= 0.55 + 0.45 * smoothstep(0.25, 0.85, sky);

	float screen_px = 70.0 * VIEWPORT_SIZE.y / 720.0;
	vec4 paint = paint_on(land_pos, lie, stroke, screen_px);
	ALBEDO = paint_colour(land, paint, 0.14, land_pos, 0.12);
	// Treetops roughen the outline of the light on forested ground.
	vec3 bumpy = normalize(lie + tops * 0.5 * vec3(patch - 0.5, 0.0, fine - 0.5));
	vec3 seen = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(bumpy, 0.0)).xyz);
	NORMAL = paint_relief(seen, VERTEX, paint, 0.7);
	ROUGHNESS = mix(0.92, 0.75, bare);
	AO = mix(0.45, 1.0, sky);
	AO_LIGHT_AFFECT = 0.35;
}
