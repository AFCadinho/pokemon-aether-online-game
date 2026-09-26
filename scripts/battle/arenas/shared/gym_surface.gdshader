shader_type spatial;
render_mode cull_back;
uniform vec4 base_color : source_color = vec4(0.6, 0.5, 0.4, 1.0);
uniform vec4 joint_color : source_color = vec4(0.3, 0.25, 0.2, 1.0);
uniform float cell_size = 1.2;
uniform int pattern = 0; // 0: floor tiles, 1: coursed wall stone, 2: timber
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
 vec2 p = world_position.xz;
 if (abs(world_normal.y) < 0.6) {
  p = abs(world_normal.x) > abs(world_normal.z) ? world_position.zy : world_position.xy;
 }
 p /= cell_size;
 if (pattern == 1) { p.x *= 0.5; p.x += mod(floor(p.y), 2.0) * 0.5; }
 if (pattern == 2) { p.x *= 0.22; p.y *= 2.0; }
 vec2 f = fract(p);
 vec2 aa = max(fwidth(p), vec2(0.001));
 vec2 edge = smoothstep(vec2(0.012), vec2(0.012) + aa, min(f, 1.0 - f));
 float grain = sin(world_position.x * 23.0 + sin(world_position.z * 17.0)) * sin(world_position.z * 31.0 + world_position.y * 19.0);
 float variation = fract(sin(dot(floor(p), vec2(12.9898, 78.233))) * 43758.5453);
 ALBEDO = mix(joint_color.rgb, base_color.rgb * (0.93 + variation * 0.12 + grain * 0.015), edge.x * edge.y);
 ROUGHNESS = pattern == 0 ? 0.68 : 0.92;
 SPECULAR = 0.16;
}
