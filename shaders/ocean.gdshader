shader_type spatial;

// The sea. Four long swells move the surface itself (the same four are
// worked out in scripts/sea.gd so the ship can ride them), and finer ripples,
// foam and reflected sky are painted on top.

uniform vec4 waves[4];             // direction x, direction z, wavelength, height share
uniform float wave_scale = 0.5;    // overall wave height in metres. 0 = flat.
uniform float sea_time = 0.0;
uniform float half_size = 1200.0;  // waves die away toward the edge of the mesh
uniform float storm : hint_range(0.0, 1.0) = 0.0;  // 0 = fair, 1 = squall
uniform vec3 sky_color : source_color = vec3(0.85, 0.72, 0.55);
// Coral reefs as (x, z, radius). Shoal water shows paler in good light.
uniform vec3 reefs[8];

varying vec3 world_pos;
varying float crest;

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

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 middle = MODEL_MATRIX[3].xz;
	float fade = 1.0 - smoothstep(0.72, 0.97, distance(wp.xz, middle) / half_size);
	float h = 0.0;
	vec2 slope = vec2(0.0);
	for (int i = 0; i < 4; i++) {
		float k = 6.2831853 / max(waves[i].z, 1.0);
		float phase = dot(waves[i].xy, wp.xz) * k - sqrt(9.81 * k) * sea_time;
		h += waves[i].w * sin(phase);
		slope += waves[i].xy * (waves[i].w * k * cos(phase));
	}
	float amount = wave_scale * fade;
	VERTEX.y += h * amount;
	NORMAL = normalize(vec3(-slope.x * amount, 1.0, -slope.y * amount));
	crest = h;
	world_pos = vec3(wp.x, wp.y + h * amount, wp.z);
}

void fragment() {
	// Fine ripples: too small for the mesh, so they only tilt the light.
	vec2 p = world_pos.xz;
	float t = sea_time;
	vec2 ripple = vec2(
			cos(p.x * 0.9 + t * 1.7) + 0.6 * cos(p.x * 2.3 - p.y * 1.1 + t * 2.6),
			cos(p.y * 1.1 - t * 1.4) + 0.6 * cos(p.y * 2.0 + p.x * 1.3 - t * 2.2));
	float rough_sea = 0.05 + 0.07 * storm;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(ripple.x, 0.0, ripple.y, 0.0)).xyz * rough_sea);

	vec3 deep = vec3(0.012, 0.065, 0.11);
	vec3 lit = vec3(0.03, 0.21, 0.26);
	vec3 sea = mix(deep, lit, smoothstep(-0.9, 1.0, crest));

	float shoal = 0.0;
	for (int i = 0; i < 8; i++) {
		if (reefs[i].z > 0.0) {
			float d = distance(p, reefs[i].xy) / reefs[i].z;
			shoal = max(shoal, 1.0 - smoothstep(0.2, 1.0, d));
		}
	}
	sea = mix(sea, vec3(0.10, 0.42, 0.38), shoal * 0.45);

	// The sea is a dark mirror: seen at a low angle it takes the sky's colour.
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 4.0);
	sea = mix(sea, sky_color * 0.85, fresnel * 0.75);

	// Foam streaks on the crests, more of them as it blows up.
	float streaks = vnoise(p * 0.35 + vec2(t * 0.3, 0.0)) * vnoise(p * 1.7 - vec2(0.0, t * 0.5));
	float foam = smoothstep(0.55 - 0.3 * storm, 1.05, crest) * smoothstep(0.12, 0.4, streaks);
	foam = clamp(foam * (0.6 + 1.2 * storm), 0.0, 1.0) * wave_scale;

	sea = mix(sea, sea * 0.5 + vec3(0.03, 0.04, 0.045), storm);
	ALBEDO = mix(sea, vec3(0.92, 0.95, 0.93), clamp(foam, 0.0, 1.0));
	ROUGHNESS = mix(0.12, 0.6, clamp(foam, 0.0, 1.0));
	SPECULAR = 0.6;
	METALLIC = 0.0;
}
