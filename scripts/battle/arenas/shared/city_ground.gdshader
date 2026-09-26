shader_type spatial;
uniform sampler2D ground_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 p;
void vertex() { p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
 vec3 grass = vec3(0.122, 0.323, 0.089);
 vec3 dirt = vec3(0.462, 0.327, 0.162);
 vec2 cell = p / 1.3;
 vec2 f = fract(cell);
 vec2 aa = max(fwidth(cell), vec2(0.001));
 vec2 edge = smoothstep(vec2(0.012), vec2(0.012) + aa, min(f, 1.0 - f));
 vec3 paving = mix(vec3(0.23, 0.26, 0.27), vec3(0.37, 0.40, 0.40), edge.x * edge.y);
 float town = 1.0 - smoothstep(39.0, 49.0, max(abs(p.x), abs(p.y)));
 vec3 tint = mix(grass, mix(dirt, paving, town), COLOR.r);
 ALBEDO = texture(ground_albedo, p * 0.1).rgb * tint;
 NORMAL_MAP = texture(ground_normal, p * 0.1).rgb;
 NORMAL_MAP_DEPTH = 0.35;
 ROUGHNESS = 0.95;
 SPECULAR = 0.0;
}
