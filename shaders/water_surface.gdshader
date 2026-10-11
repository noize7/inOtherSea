shader_type canvas_item;

// Textures
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// Color Palette
uniform vec4 surface_color : source_color = vec4(0.40, 0.85, 0.98, 0.88);
uniform vec4 foam_color : source_color = vec4(0.95, 0.98, 1.0, 0.98);
uniform vec4 shallow_color : source_color = vec4(0.12, 0.52, 0.78, 0.65);
uniform vec4 mid_color : source_color = vec4(0.06, 0.30, 0.56, 0.82);
uniform vec4 deep_color : source_color = vec4(0.02, 0.12, 0.30, 0.95);
uniform vec4 sun_ray_color : source_color = vec4(0.98, 0.88, 0.76, 1.0);

// Optics & Physics
uniform float refraction_strength : hint_range(0.0, 0.05) = 0.012;
uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.003;
uniform float surface_band : hint_range(10.0, 200.0) = 80.0;
uniform float foam_thickness : hint_range(1.0, 30.0) = 9.0;
uniform float wave_speed : hint_range(0.1, 5.0) = 1.8;
uniform float wave_frequency : hint_range(0.005, 0.1) = 0.02;
uniform float caustic_intensity : hint_range(0.0, 1.5) = 0.40;
uniform float sun_ray_intensity : hint_range(0.0, 1.0) = 0.30;
uniform float sparkle_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float absorption_depth : hint_range(200.0, 2000.0) = 900.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

// Procedural caustic pattern
float get_caustics(vec2 pos, float time) {
	vec2 uv1 = pos * 0.015 + vec2(time * 0.06, time * 0.04);
	vec2 uv2 = pos * 0.018 + vec2(-time * 0.05, time * 0.07);
	vec2 uv3 = pos * 0.024 + vec2(time * 0.03, -time * 0.05);

	float n1 = sin(uv1.x * 3.14 + sin(uv1.y * 3.14 + time * 1.2));
	float n2 = sin(uv2.x * 2.80 + cos(uv2.y * 3.50 - time * 0.9));
	float n3 = cos(uv3.x * 3.60 + sin(uv3.y * 2.50 + time * 0.7));

	float c = (n1 + n2 + n3) / 3.0;
	c = pow(max(0.0, c * 0.5 + 0.5), 4.0);
	return c;
}

void fragment() {
	float depth = max(local_pos.y, 0.0);

	// Surface noise & wave interference for foam crest and caustics
	float t = TIME * wave_speed;
	float w1 = sin(local_pos.x * wave_frequency + t * 1.5);
	float w2 = sin(local_pos.x * (wave_frequency * 1.7) - t * 1.2 + local_pos.y * 0.05);
	float w3 = cos(local_pos.x * (wave_frequency * 0.8) + t * 0.9);
	float wave_noise = (w1 + w2 + w3) / 3.0; // [-1.0, 1.0]

	// 1. Refraction: Distort the screen texture behind the water
	float surface_refract_damp = smoothstep(0.0, 35.0, depth);
	float depth_refract_damp = smoothstep(1600.0, 600.0, depth);
	float refract_mask = surface_refract_damp * depth_refract_damp;

	vec2 distort = vec2(
		sin(local_pos.y * 0.025 + t * 1.4 + local_pos.x * 0.01) * 0.7 + cos(local_pos.x * 0.03 - t * 1.1) * 0.3,
		cos(local_pos.x * 0.025 + t * 1.2 + local_pos.y * 0.015) * 0.7 + sin(local_pos.y * 0.03 - t * 0.8) * 0.3
	) * refraction_strength * refract_mask;

	// Chromatic aberration in refraction
	vec2 uv_r = SCREEN_UV + distort + vec2(chromatic_aberration * refract_mask, 0.0);
	vec2 uv_g = SCREEN_UV + distort;
	vec2 uv_b = SCREEN_UV + distort - vec2(chromatic_aberration * refract_mask, 0.0);

	float bg_r = texture(screen_texture, uv_r).r;
	float bg_g = texture(screen_texture, uv_g).g;
	float bg_b = texture(screen_texture, uv_b).b;
	vec3 bg_color = vec3(bg_r, bg_g, bg_b);

	// 2. Optical depth gradient & absorption (Beer-Lambert attenuation)
	float depth_ratio = clamp(depth / absorption_depth, 0.0, 1.0);
	float mid_blend = smoothstep(0.0, 0.5, depth_ratio);
	float deep_blend = smoothstep(0.4, 1.0, depth_ratio);

	vec4 water_tint = mix(shallow_color, mid_color, mid_blend);
	water_tint = mix(water_tint, deep_color, deep_blend);

	// Blend refracted background with the volume tint
	float absorption = 1.0 - exp(-depth / (absorption_depth * 0.45));
	vec3 water_rgb = mix(bg_color * water_tint.rgb * 1.25, water_tint.rgb, clamp(absorption, 0.15, 0.95));

	// 3. Volumetric Sun Rays
	float ray_coord = (local_pos.x + local_pos.y * 0.35) * 0.0035;
	float r1 = sin(ray_coord * 18.0 + TIME * 0.35) * 0.5 + 0.5;
	float r2 = sin(ray_coord * 32.0 - TIME * 0.22) * 0.5 + 0.5;
	float sun_rays = pow(r1 * r2, 2.0) * smoothstep(750.0, 30.0, depth) * sun_ray_intensity;
	water_rgb += sun_ray_color.rgb * sun_rays * 0.35;

	// 4. Underwater Caustics
	float caustic = get_caustics(local_pos, TIME) * caustic_intensity;
	float caustic_depth_fade = smoothstep(650.0, 15.0, depth);
	water_rgb += vec3(caustic * caustic_depth_fade * 0.45);

	// 5. Surface Zone Tint & Sparkles
	float surface_mask = smoothstep(surface_band, 0.0, depth);
	water_rgb = mix(water_rgb, surface_color.rgb, surface_mask * 0.25);

	// Sparkle / Specular glints on surface
	float caustic_pattern = pow(max(0.0, wave_noise + 0.35), 4.0) * surface_mask;
	vec3 sparkle = vec3(caustic_pattern * sparkle_intensity);
	water_rgb += sparkle * sun_ray_color.rgb;

	// 6. Dual-layer Foam at the surface boundary
	float soft_foam_edge = foam_thickness * 2.2 + wave_noise * 5.0;
	float soft_foam = smoothstep(soft_foam_edge, 0.0, depth) * 0.45;
	water_rgb = mix(water_rgb, foam_color.rgb, soft_foam);

	float crisp_foam_edge = foam_thickness + wave_noise * 3.5;
	float crisp_foam = smoothstep(crisp_foam_edge, 0.0, depth);
	water_rgb = mix(water_rgb, foam_color.rgb, crisp_foam * foam_color.a);

	COLOR = vec4(water_rgb, max(water_tint.a, crisp_foam));
}
