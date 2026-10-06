shader_type canvas_item;

// Colors sampled from reference image
uniform vec4 top_color : source_color = vec4(0.36, 0.43, 0.64, 1.0);       // Serene twilight blue/violet
uniform vec4 mid_color : source_color = vec4(0.70, 0.65, 0.76, 1.0);       // Soft pastel lavender/mauve
uniform vec4 bottom_color : source_color = vec4(0.96, 0.74, 0.67, 1.0);    // Warm sunset peach

// Gradient controls
uniform float horizon_y = 545.0;
uniform float gradient_height = 540.0;
uniform float mid_offset : hint_range(0.1, 0.9) = 0.50;
uniform float blend_smoothness : hint_range(0.1, 2.0) = 1.0;
uniform float dither_strength : hint_range(0.0, 0.03) = 0.005;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// Atmospheric gradient from upper sky down to horizon
	float dist_from_horizon = horizon_y - world_pos.y;
	float t = clamp(1.0 - (dist_from_horizon / gradient_height), 0.0, 1.0);

	// Soft, non-linear diffusion between colors
	vec4 sky;
	if (t < mid_offset) {
		float factor = t / mid_offset;
		factor = pow(smoothstep(0.0, 1.0, factor), blend_smoothness);
		sky = mix(top_color, mid_color, factor);
	} else {
		float factor = (t - mid_offset) / (1.0 - mid_offset);
		factor = pow(smoothstep(0.0, 1.0, factor), blend_smoothness);
		sky = mix(mid_color, bottom_color, factor);
	}

	// Subtle pseudo-random dither to prevent 8-bit color banding
	float dither = fract(sin(dot(UV * 500.0, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	sky.rgb += dither * dither_strength;

	COLOR = sky;
}
