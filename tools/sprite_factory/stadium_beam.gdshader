shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
void fragment() {
	float edge = pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.0);
	ALBEDO = vec3(0.34,0.27,0.75);
	ALPHA = 0.035*edge*sin(clamp(UV.y,0.0,1.0)*3.14159);
}
