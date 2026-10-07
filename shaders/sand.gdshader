shader_type canvas_item;

uniform vec4 top_sand_color : source_color = vec4(0.88, 0.76, 0.52, 1.0);
uniform vec4 bottom_sand_color : source_color = vec4(0.58, 0.44, 0.24, 1.0);
uniform float gradient_depth : hint_range(50.0, 500.0) = 220.0;
uniform float ripple_strength : hint_range(0.0, 0.1) = 0.025;
uniform float ripple_frequency : hint_range(10.0, 200.0) = 90.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	// Depth gradient from dune surface downwards
	float d = clamp(max(local_pos.y, 0.0) / gradient_depth, 0.0, 1.0);
	vec4 sand = mix(top_sand_color, bottom_sand_color, d);

	// Subtle organic sand ripples & fine grain
	float ripples = sin(local_pos.x * (ripple_frequency * 0.01) + local_pos.y * 0.04);
	float grain = fract(sin(dot(local_pos, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	sand.rgb += (ripples * 0.02 + grain * 0.015) * ripple_strength * 20.0;

	COLOR = sand;
}
