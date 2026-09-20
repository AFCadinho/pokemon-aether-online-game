shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float radius = length(p) / (1.0 + 0.035*sin(atan(p.x, p.y)*5.0));
	float shallow = 1.0-smoothstep(10.0, 23.0, radius);
	float detail = 1.0-smoothstep(20.0, 100.0, length(p));
	float wave = sin(p.x*1.7 + p.y*0.9 + sin(p.y*0.47) + TIME*1.1)*detail;
	float cross_wave = sin(p.y*2.3-p.x*0.6+sin(p.x*0.39)-TIME*0.8)*detail;
	vec3 deep_color = vec3(0.055, 0.30, 0.46);
	vec3 shallow_color = vec3(0.20, 0.62, 0.65);
	vec3 color = mix(deep_color, shallow_color, shallow);
	color += 0.018*wave*cross_wave;
	float edge = 9.02 + 0.10*sin(TIME*1.0+p.x*0.5);
	float foam = (1.0-smoothstep(0.02, 0.28, abs(radius-edge))) * (0.30+0.25*sin(p.x*3.0+p.y*2.0+TIME));
	ALBEDO = mix(color, vec3(0.77, 0.88, 0.84), foam);
	NORMAL_MAP = vec3(0.5+0.035*wave, 0.5+0.025*cross_wave, 1.0);
	ROUGHNESS = 0.32;
	SPECULAR = 0.3;
}
