shader_type spatial;
uniform vec4 water_color : source_color = vec4(0.075, 0.60, 0.72, 1.0);
varying vec3 world_position;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
 vec2 p = world_position.xz;
 float a = sin(p.x * 2.6 + sin(p.y * 2.0 + TIME * 0.38));
 float b = sin(p.y * 2.8 - sin(p.x * 1.7 - TIME * 0.31));
 float caustic = pow(1.0 - abs(a * 0.55 + b * 0.45), 12.0);
 float ripple = sin(p.x * 4.0 + p.y * 3.0 + TIME * 0.7);
 ALBEDO = water_color.rgb + vec3(0.15, 0.25, 0.21) * caustic + ripple * 0.012;
 NORMAL_MAP = vec3(0.5 + 0.035 * sin(p.x * 3.0 + TIME * 0.4), 0.5 + 0.035 * cos(p.y * 3.2 + TIME * 0.3), 1.0);
 ROUGHNESS = 0.25;
 SPECULAR = 0.5;
}
