shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D colour_map : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(0.45,0.85,1.0,1.0);
uniform float phase = 0.0;
uniform float crystal = 0.0;
void fragment() {
 vec4 tex = texture(colour_map, UV);
 float rim=pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),2.0);
 float pulse=0.92+0.08*sin(phase*6.2831853);
 ALBEDO=mix(tex.rgb,tex.rgb*0.45+tint.rgb*0.35,crystal);
 ROUGHNESS=mix(0.32,0.16,crystal);METALLIC=0.12;
 EMISSION=(tex.rgb*0.12+rim*tint.rgb*0.55)*pulse;
 ALPHA=mix(tex.a,0.25+rim*0.5,crystal);
}
