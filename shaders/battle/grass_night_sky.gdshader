shader_type canvas_item;

uniform float night_amount : hint_range(0.0, 1.0) = 0.0;
varying vec4 background_tint;

void vertex() {
	background_tint = COLOR;
}

float star_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 result = source.rgb;
	if (night_amount > 0.0) {
		// This mask is specific to the meadow's upper sky. Green foliage stays intact.
		float upper_sky = 1.0 - smoothstep(0.18, 0.30, UV.y);
		float blue_sky = smoothstep(0.02, 0.07, source.b - source.r)
			* smoothstep(-0.03, 0.035, source.b - source.g);
		float cloud_brightness = min(source.r, min(source.g, source.b));
		float cloud = smoothstep(0.42, 0.68, cloud_brightness);
		float sky_mask = upper_sky * max(blue_sky, cloud);
		vec3 night_sky = mix(vec3(0.04, 0.07, 0.17), vec3(0.10, 0.16, 0.28), clamp(UV.y / 0.30, 0.0, 1.0));
		vec3 night_cloud = source.rgb * vec3(0.25, 0.30, 0.43);
		result = mix(result, mix(night_sky, night_cloud, smoothstep(0.25, 0.85, cloud_brightness)), sky_mask * night_amount);

		// Fixed stars sit behind moving clouds, with no twinkle/flicker at video seams.
		vec2 grid = UV * vec2(160.0, 90.0);
		vec2 cell = floor(grid);
		float seed = star_hash(cell);
		vec2 point = vec2(star_hash(cell + 7.3), star_hash(cell + 19.1)) * 0.6 + 0.2;
		float star = (1.0 - smoothstep(0.025, 0.11, length(fract(grid) - point))) * step(0.975, seed);
		float clear_sky = blue_sky * (1.0 - smoothstep(0.35, 0.65, source.r));
		float star_region = 1.0 - smoothstep(0.14, 0.21, UV.y);
		result += vec3(0.72, 0.82, 1.0) * star * clear_sky * star_region * night_amount;
	}
	// Preserve the independent world-time tint and battle-weather modulation.
	COLOR = vec4(result, source.a) * background_tint;
}
