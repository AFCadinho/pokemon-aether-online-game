shader_type canvas_item;

uniform float spin_speed = 3.4;

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float angle = TIME * spin_speed;
	float sine = sin(angle);
	float cosine = cos(angle);
	vec2 rotated_uv = vec2(
		centered_uv.x * cosine - centered_uv.y * sine,
		centered_uv.x * sine + centered_uv.y * cosine
	) + vec2(0.5);
	COLOR = texture(TEXTURE, rotated_uv) * COLOR;
}
