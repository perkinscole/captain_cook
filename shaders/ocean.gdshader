shader_type spatial;
render_mode cull_disabled;

// The sea. Eight trains of waves move the surface: two long swells from far
// away and six wind waves that run before the local wind. They are
// trochoidal ("Gerstner") waves: the water moves in circles, which makes the
// crests sharp and the troughs wide, as on the real sea. scripts/sea.gd works
// out the same waves so that the ship can ride them.

uniform vec4 wave_a[8];   // direction x, direction z, wavenumber, height
uniform vec4 wave_b[8];   // phase of the wave at `anchor`
uniform vec2 anchor;      // the point the phases are measured from (the ship)
uniform float chop = 0.8; // how sharp the crests are
uniform float sea_time = 0.0;
uniform float storm : hint_range(0.0, 1.0) = 0.0;
uniform vec3 sky_color : source_color = vec3(0.85, 0.72, 0.55);
// Depth of water in metres round the island, so shallows show pale.
uniform sampler2D depth_map : filter_linear, repeat_disable;
uniform bool has_depth_map = false;
uniform vec2 map_centre = vec2(0.0);
uniform float map_size = 1800.0;

varying vec3 world_pos;
varying float crest;
varying float fold;

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
	// UV holds how far apart the mesh's points are here. A wave too short
	// for the mesh to draw is faded out, so the distance stays calm and clean.
	float spacing = max(max(UV.x, UV.y), 0.01);
	vec3 offset = vec3(0.0);
	vec3 n = vec3(0.0, 1.0, 0.0);
	float folded = 0.0;
	float total = 0.001;
	for (int i = 0; i < 8; i++) {
		float k = max(wave_a[i].z, 0.0001);
		float keep = clamp(6.2831853 / k / spacing / 3.0 - 1.0, 0.0, 1.0);
		float amp = wave_a[i].w * keep;
		vec2 d = wave_a[i].xy;
		float theta = k * dot(d, wp.xz - anchor) + wave_b[i].x;
		float s = sin(theta);
		float c = cos(theta);
		offset.xz += d * (chop * amp * c);
		offset.y += amp * s;
		n.xz -= d * (k * amp * c);
		n.y -= chop * k * amp * s;
		folded += chop * k * amp * s;
		total += wave_a[i].w;
	}
	VERTEX += offset;
	NORMAL = normalize(n);
	crest = offset.y / total;
	fold = folded;
	world_pos = wp + offset;
}

void fragment() {
	vec2 p = world_pos.xz;
	float t = sea_time;

	// Small ripples, too fine for the mesh: they only tilt the light.
	vec2 q1 = p * 0.55 + vec2(t * 0.35, t * 0.12);
	vec2 q2 = p * 1.7 - vec2(t * 0.22, t * 0.5);
	float e = 0.35;
	float h0 = vnoise(q1) + 0.5 * vnoise(q2);
	float hx = vnoise(q1 + vec2(e, 0.0)) + 0.5 * vnoise(q2 + vec2(e, 0.0));
	float hz = vnoise(q1 + vec2(0.0, e)) + 0.5 * vnoise(q2 + vec2(0.0, e));
	vec2 slope = vec2(hx - h0, hz - h0) / e;
	float nearness = clamp(1.0 - length(VERTEX) / 600.0, 0.15, 1.0);
	float ripple = (0.10 + 0.12 * storm) * nearness;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(-slope.x, 0.0, -slope.y, 0.0)).xyz * ripple);

	float depth = 60.0;
	if (has_depth_map) {
		vec2 uv = (p - map_centre) / map_size + vec2(0.5);
		if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {
			depth = textureLod(depth_map, uv, 0.0).r;
		}
	}

	// Deep water is nearly black-blue; crests are greener; shallows are pale.
	vec3 deep = vec3(0.010, 0.055, 0.105);
	vec3 lit = vec3(0.020, 0.16, 0.22);
	vec3 shallow = vec3(0.10, 0.48, 0.44);
	vec3 sea = mix(deep, lit, smoothstep(-0.6, 0.9, crest));
	sea += vec3(0.02, 0.10, 0.09) * smoothstep(0.35, 1.0, crest);  // light through the crests
	float shoal = 1.0 - smoothstep(1.5, 14.0, depth);
	sea = mix(sea, shallow, shoal * 0.6 * (1.0 - 0.6 * storm));

	// Seen at a low angle the sea takes the colour of the sky.
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	sea = mix(sea, sky_color * 0.8, pow(1.0 - facing, 5.0) * 0.45);

	// White water: on crests that are folding over, and along the shore.
	float lace = 0.6 * vnoise(p * 0.9 + vec2(t * 0.2, 0.0)) + 0.4 * vnoise(p * 3.1 - vec2(0.0, t * 0.4));
	float cap = smoothstep(0.06, 0.15, fold) * smoothstep(0.3, 0.7, lace + 0.3 * crest);
	float wash = 1.0 - smoothstep(0.3, 3.2, depth);
	float shore = wash * smoothstep(0.35, 0.65, lace + 0.25 * sin(t * 0.9 + depth * 2.0));
	float foam = clamp(cap + shore, 0.0, 1.0);

	sea = mix(sea, sea * 0.5 + vec3(0.03, 0.04, 0.045), storm * 0.8);
	ALBEDO = mix(sea, vec3(0.93, 0.95, 0.93), foam);
	ROUGHNESS = mix(0.08, 0.7, foam);
	SPECULAR = 0.55;
	METALLIC = 0.0;
}
