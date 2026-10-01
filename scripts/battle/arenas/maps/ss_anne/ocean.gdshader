shader_type spatial;
varying vec3 world_position;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
 vec2 p = world_position.xz;
 float detail = 1.0 - smoothstep(50.0, 350.0, length(p));
 float wave = sin(p.x * 0.8 + p.y * 1.3 + TIME * 0.7);
 float cross_wave = sin(p.y * 0.65 - p.x * 1.2 - TIME * 0.5);
 float crest = smoothstep(0.88, 1.0, wave * cross_wave) * detail;
 ALBEDO = mix(vec3(0.035, 0.26, 0.39), vec3(0.32, 0.58, 0.65), crest * 0.4);
 NORMAL_MAP = vec3(0.5 + 0.04 * wave * detail, 0.5 + 0.04 * cross_wave * detail, 1.0);
 ROUGHNESS = 0.32;
 SPECULAR = 0.3;
}
