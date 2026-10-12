shader_type canvas_item;
render_mode unshaded;

uniform vec2 viewport_size = vec2(1.0);
uniform vec2 player_screen_position = vec2(0.0);
uniform vec2 world_per_screen_x = vec2(1.0, 0.0);
uniform vec2 world_per_screen_y = vec2(0.0, 1.0);
uniform float sight_radius = 96.0;
uniform float full_radius = 1024.0;
uniform float feather = 12.0;
uniform float reveal_progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 screen_delta = UV * viewport_size - player_screen_position;
	vec2 world_delta = screen_delta.x * world_per_screen_x + screen_delta.y * world_per_screen_y;
	float radius = mix(sight_radius, full_radius, reveal_progress);
	float darkness = smoothstep(max(radius - feather, 0.0), radius, length(world_delta));
	COLOR = vec4(0.0, 0.0, 0.0, darkness);
}
