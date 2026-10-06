shader_type canvas_item;

// Colors
uniform vec4 surface_color : source_color = vec4(0.35, 0.82, 1.0, 0.85);
uniform vec4 foam_color : source_color = vec4(0.88, 0.97, 1.0, 0.95);
uniform vec4 shallow_color : source_color = vec4(0.10, 0.42, 0.75, 0.78);
uniform vec4 deep_color : source_color = vec4(0.03, 0.16, 0.38, 0.92);

// Surface effect controls
uniform float surface_band : hint_range(10.0, 200.0) = 75.0;
uniform float foam_thickness : hint_range(1.0, 30.0) = 8.0;
uniform float wave_speed : hint_range(0.1, 5.0) = 2.0;
uniform float wave_frequency : hint_range(0.005, 0.1) = 0.025;
uniform float sparkle_intensity : hint_range(0.0, 2.0) = 0.8;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	// Depth from the wavy surface in local pixels
	float depth = max(local_pos.y, 0.0);

	// Surface noise & wave interference for foam crest and caustics
	float w1 = sin(local_pos.x * wave_frequency + TIME * wave_speed * 1.8);
	float w2 = sin(local_pos.x * (wave_frequency * 1.6) - TIME * wave_speed * 1.4 + local_pos.y * 0.08);
	float w3 = cos(local_pos.x * (wave_frequency * 0.7) + TIME * wave_speed * 0.9);
	float wave_noise = (w1 + w2 + w3) / 3.0; // [-1.0, 1.0]

	// 1. Foam line right at the water surface boundary (top 6-10 px)
	float dynamic_foam_edge = foam_thickness + wave_noise * 3.5;
	float foam_mask = smoothstep(dynamic_foam_edge, 0.0, depth);

	// 2. Surface zone factor (decays smoothly down to 0 at surface_band)
	float surface_mask = smoothstep(surface_band, 0.0, depth);

	// 3. Shimmer / sunlight caustics across the surface band
	float caustic_pattern = pow(max(0.0, wave_noise + 0.2), 3.0) * surface_mask;
	vec3 sparkle = vec3(caustic_pattern * sparkle_intensity);

	// 4. Underwater depth gradient (shallow near top -> deep marine blue at bottom)
	float depth_ratio = clamp(depth / 900.0, 0.0, 1.0);
	vec4 base_water = mix(shallow_color, deep_color, depth_ratio);

	// Blend surface tint and sparkles
	vec4 col = mix(base_water, surface_color, surface_mask * 0.35);
	col.rgb += sparkle;

	// Blend foam crest at the very surface
	col = mix(col, foam_color, foam_mask);

	COLOR = col;
}
