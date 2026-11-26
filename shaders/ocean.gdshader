shader_type spatial;

// Placeholder sea: a flat plane with a moving colour pattern in world space,
// so the water reads as passing under the ship.

uniform float storm : hint_range(0.0, 1.0) = 0.0;  // 0 = fair, 1 = squall

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float swell = sin(world_pos.x * 0.08 + TIME * 0.9) * sin(world_pos.z * 0.06 + TIME * 0.7);
	float chop = 0.5 * sin((world_pos.x + world_pos.z) * 0.21 - TIME * 1.3);
	float fine = 0.25 * sin(world_pos.x * 0.9 - TIME * 2.0) * sin(world_pos.z * 1.1 + TIME * 1.7);
	vec3 deep = vec3(0.02, 0.10, 0.18);
	vec3 crest = vec3(0.07, 0.26, 0.33);
	vec3 sea = mix(deep, crest, smoothstep(-1.0, 1.6, swell + chop + fine * (1.0 + 2.0 * storm)));
	ALBEDO = mix(sea, sea * 0.45 + vec3(0.03, 0.04, 0.045), storm);
	ROUGHNESS = 0.3;
	METALLIC = 0.0;
}
