shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D brand_texture : source_color, filter_linear_mipmap_anisotropic;
uniform float float_amount = 0.0;
uniform float phase = 0.0;
void vertex() {
	VERTEX.y += float_amount*sin(TIME*0.65+phase);
}
void fragment() {
	vec4 brand = texture(brand_texture, UV);
	// One slow diagonal highlight, then a pause. Preserve the original alpha.
	float sweep = mod(TIME*0.17+phase, 2.0)-0.35;
	float band = exp(-pow((UV.x+UV.y*0.22-sweep)/0.065,2.0));
	ALBEDO = brand.rgb;
	EMISSION = brand.rgb*band*0.30 + vec3(0.10,0.14,0.20)*band;
	ALPHA = brand.a;
}
