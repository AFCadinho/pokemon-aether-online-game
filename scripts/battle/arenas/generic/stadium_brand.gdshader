shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D brand_texture : source_color, filter_linear_mipmap_anisotropic;
uniform float float_amount = 0.0;
uniform float phase = 0.0;
void vertex() {
	if (float_amount > 0.0) {
		VERTEX.xy *= 1.0+0.025*sin(TIME*1.1+phase);
	}
	VERTEX.y += float_amount*sin(TIME*0.85+phase);
}
void fragment() {
	vec4 brand = texture(brand_texture, UV);
	// Broad, clearly visible sweep every four seconds, with a quiet interval.
	float sweep = mod(TIME*0.48+phase, 1.9)-0.30;
	float band = exp(-pow((UV.x+UV.y*0.22-sweep)/0.12,2.0));
	ALBEDO = brand.rgb;
	EMISSION = brand.rgb*(0.10+0.10*sin(TIME*1.1+phase)) + (brand.rgb*0.65+vec3(0.45,0.60,0.85))*band;
	ALPHA = brand.a;
}
