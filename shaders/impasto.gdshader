shader_type canvas_item;

// The last touch on the whole picture: the colouring of an old oil painting.
// The brush strokes themselves are painted on the surfaces (painted.gdshader),
// so nothing here lays a pattern over the screen. It only deepens the
// shadows, warms the lights, yellows the varnish and darkens the border.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float vignette : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, 1.2);                          // richer colour
	col = mix(col, col * col * (3.0 - 2.0 * col), 0.45);   // deep shadows, bright lights
	col *= mix(vec3(0.94, 0.97, 1.05), vec3(1.03, 1.0, 0.96), smoothstep(0.1, 0.8, l));
	col *= vec3(1.01, 1.0, 0.975);                         // the faintest warmth of old varnish
	vec2 from_middle = SCREEN_UV - vec2(0.5);
	col *= 1.0 - vignette * smoothstep(0.22, 0.85, dot(from_middle, from_middle) * 2.0);
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
