shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float phase = 0.0;
varying float beam_depth;
void vertex() {
	// Shear from the fixed fixture; shared phase drives the matching floor pool.
	float depth = 8.2-VERTEX.y;
	beam_depth = depth/16.4;
	VERTEX.x += depth*0.16*sin(TIME*0.28+phase);
	VERTEX.z += depth*0.12*cos(TIME*0.23+phase);
}
void fragment() {
	float soft_edge = pow(abs(dot(normalize(NORMAL),normalize(VIEW))),1.5);
	float fade = smoothstep(0.0,0.08,beam_depth)*(1.0-smoothstep(0.45,1.0,beam_depth));
	ALBEDO = vec3(0.45,0.35,0.95);
	ALPHA = 0.09*soft_edge*fade;
}
