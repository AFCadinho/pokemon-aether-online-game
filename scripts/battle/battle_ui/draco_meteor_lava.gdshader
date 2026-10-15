
shader_type spatial;
render_mode unshaded;
uniform sampler2D cracks : filter_linear, repeat_enable;
uniform sampler2D rock : filter_linear, repeat_enable;
uniform float seconds = 0.0;
void fragment() {
 float n = texture(cracks, UV * 2.0 + vec2(seconds * 0.07,0.0)).r;
 float grain = texture(rock, UV * 3.0).r;
 float hot = smoothstep(0.7,0.93,n);
 float facet = 0.65 + abs(dot(normalize(NORMAL), normalize(VIEW))) * 0.35;
 ALBEDO = mix(vec3(0.16,0.075,0.04) * (0.6 + grain) * facet, vec3(1.0,0.38,0.025),hot);
 EMISSION = vec3(1.0,0.26,0.015) * hot * 0.7;
}
