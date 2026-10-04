// Adapted from GDQuest godot-4-VFX-assets/effects/3d_flame/source/flame.gdshader.
// Copyright (c) 2023-present GDQuest, MIT. See docs/licenses/gdquest-vfx-MIT.txt.
// Uses analytic masks/noise instead of the upstream separately licensed artwork.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 flame_color : source_color = vec4(1.0,0.65,0.08,1.0);
uniform float effect_time = 0.0;
uniform float strength = 0.0;

void fragment() {
	float wave = 0.5 + 0.5 * sin(UV.x * 75.0 + sin(UV.x * 29.0 - effect_time * 11.0) * 2.0 - effect_time * 13.0);
	float taper = smoothstep(0.0,0.25,UV.y) * smoothstep(1.0,0.4,UV.y);
	float flame_sdf = taper * (0.35 + 0.65 * wave);
	ALBEDO = flame_color.rgb;
	EMISSION = flame_color.rgb * 0.35;
	ALPHA = smoothstep(0.15,0.6,flame_sdf) * strength * 0.65;
}
