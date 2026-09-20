shader_type spatial;
render_mode unshaded;
uniform bool supporter_light = false;
varying float phase;
void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	phase = origin.x*1.93+origin.z*2.37;
	VERTEX.x += 0.045*sin(TIME*1.4+phase);
}
void fragment() {
	if (supporter_light) {
		float pulse = pow(0.5+0.5*sin(TIME*0.8+phase),6.0);
		ALBEDO = mix(vec3(0.18,0.08,0.4),vec3(0.6,0.75,1.0),0.5+0.5*sin(phase));
		EMISSION = ALBEDO*(0.3+2.2*pulse);
	} else {
		ALBEDO = COLOR.rgb;
	}
}
