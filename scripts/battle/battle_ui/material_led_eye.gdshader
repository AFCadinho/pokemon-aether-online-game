shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_back;
uniform sampler2D mask_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D iris_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 tint = vec4(1.0);
uniform vec2 grid = vec2(1.0);
uniform vec4 uv_transform = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 iris_transform = vec4(1.0, 1.0, 0.0, 0.0);
uniform float frame = 0.0;
uniform float intensity = 1.0;
uniform float iris_weight = 1.0;
void fragment() {
    vec2 atlas_offset = vec2(mod(floor(frame), grid.x), floor(frame / grid.x)) / grid;
    float mask = texture(mask_tex, UV * uv_transform.xy + uv_transform.zw + atlas_offset).r;
    float iris = texture(iris_tex, UV * iris_transform.xy + iris_transform.zw).r;
    ALBEDO = tint.rgb * intensity;
    ALPHA = clamp(mask * (1.0 - iris * iris_weight), 0.0, 1.0);
}
