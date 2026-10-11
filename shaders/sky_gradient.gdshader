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

// Cloud haze controls
uniform float cloud_opacity : hint_range(0.0, 0.5) = 0.18;
uniform float cloud_speed : hint_range(0.001, 0.05) = 0.012;

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

	// Soft atmospheric drifting twilight clouds / haze
	float cloud_u = world_pos.x * 0.0008 + TIME * cloud_speed;
	float cloud_v = world_pos.y * 0.0025;
	float c1 = sin(cloud_u * 3.2 + sin(cloud_v * 3.8)) * 0.5 + 0.5;
	float c2 = cos(cloud_u * 5.4 - cloud_v * 2.2 + TIME * (cloud_speed * 0.7)) * 0.5 + 0.5;
	float cloud_shape = smoothstep(0.42, 0.82, c1 * c2);
	float cloud_altitude = smoothstep(0.08, 0.35, t) * smoothstep(0.92, 0.60, t);
	vec4 cloud_color = mix(vec4(0.85, 0.80, 0.90, 1.0), vec4(1.0, 0.84, 0.76, 1.0), t);
	sky.rgb = mix(sky.rgb, cloud_color.rgb, cloud_shape * cloud_altitude * cloud_opacity);

	// Subtle pseudo-random dither to prevent 8-bit color banding
	float dither = fract(sin(dot(UV * 500.0, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	sky.rgb += dither * dither_strength;

	COLOR = sky;
}
