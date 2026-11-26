shader_type sky;

// The sky: a painted gradient from horizon to zenith, a sun with a wide
// glow, and drifting clouds lit from the sun's side.

uniform vec3 zenith : source_color = vec3(0.13, 0.36, 0.78);
uniform vec3 horizon : source_color = vec3(0.62, 0.80, 0.95);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.98, 0.94);
uniform vec3 cloud_shade : source_color = vec3(0.55, 0.61, 0.74);
uniform float coverage : hint_range(0.0, 1.0) = 0.45;  // how much of the sky is cloud
uniform vec2 drift = vec2(0.012, 0.005);               // which way the clouds move
uniform float cloud_time = 0.0;

#include "res://shaders/paint_strokes.gdshaderinc"

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float weight = 0.5;
	for (int i = 0; i < 5; i++) {
		total += weight * vnoise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		weight *= 0.5;
	}
	return total;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	// The brush strokes of the sky are fixed to the dome of the sky itself,
	// so they stay still as you look about.
	vec3 brush = paint_layers(dir.xz / (1.0 + abs(dir.y)) * 14.0, 0.3, 0.6);
	float up = clamp(dir.y, 0.0, 1.0);
	vec3 col = mix(horizon, zenith, pow(up, 0.55));
	if (dir.y < 0.0) {
		col = mix(horizon, horizon * 0.3, clamp(-dir.y * 4.0, 0.0, 1.0));
	}

	float toward_sun = 0.0;
	vec3 sun_col = vec3(0.0);
	if (LIGHT0_ENABLED) {
		toward_sun = max(dot(dir, LIGHT0_DIRECTION), 0.0);
		sun_col = LIGHT0_COLOR * min(LIGHT0_ENERGY, 1.5);
	}
	col += sun_col * (pow(toward_sun, 24.0) * 0.10 + pow(toward_sun, 300.0) * 0.4);
	float disk = smoothstep(0.9993, 0.9997, toward_sun);

	if (dir.y > 0.0) {
		vec2 uv = dir.xz / (dir.y + 0.12) * 0.9 + drift * cloud_time;
		uv += (brush.x - 0.5) * 0.12;   // clouds are built of dabs, with broken edges
		float shape = fbm(uv);
		float wisps = fbm(uv * 3.1 + vec2(40.0, 13.0));
		float edge = 1.0 - coverage;
		float density = smoothstep(edge, edge + 0.28, shape + wisps * 0.25 - 0.12);
		float light = clamp(0.3 + 0.6 * pow(toward_sun, 3.0) + 0.8 * (shape - 0.5), 0.0, 1.0);
		vec3 cloud = mix(cloud_shade, cloud_lit, light);
		cloud += sun_col * pow(toward_sun, 14.0) * 0.45;  // bright rims near the sun
		float thin_at_horizon = smoothstep(0.0, 0.16, dir.y);
		disk *= 1.0 - density;
		col = mix(col, cloud, density * thin_at_horizon);
	}
	// Each stroke of sky is a slightly different blue, and thicker or thinner.
	col *= 1.0 + 0.16 * (brush.x - 0.5) + 0.07 * (brush.y - 0.5);
	col = mix(col, col * vec3(0.90, 0.96, 1.06), 0.5 * brush.z + 0.25 * step(0.85, brush.x));
	col += sun_col * disk * 6.0;
	COLOR = col;
}
