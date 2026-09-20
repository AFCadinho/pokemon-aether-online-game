shader_type spatial;
render_mode unshaded;
uniform bool supporter_light = false;
varying float phase;
varying float enthusiasm;
void vertex() {
	phase = INSTANCE_CUSTOM.r*6.28318;
	enthusiasm = INSTANCE_CUSTOM.g;
	float cheer = smoothstep(-0.3,0.6,sin(TIME*0.55+phase));
	float wave = sin(TIME*(1.7+enthusiasm*0.7)+phase);
	if (!supporter_light && abs(UV2.x)>0.5) {
		float side = sign(UV2.x);
		vec2 shoulder = vec2(side*0.13,0.16);
		vec2 arm = VERTEX.xy-shoulder;
		float angle = side*(0.25+cheer*(1.65+0.30*wave));
		VERTEX.xy = shoulder+mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)))*arm;
	}
	VERTEX.x += 0.07*wave;
	VERTEX.y += cheer*0.09*(0.5+0.5*wave);
	if (supporter_light) {
		VERTEX.y += cheer*0.22;
	}
}
void fragment() {
	if (supporter_light) {
		float pulse = pow(0.5+0.5*sin(TIME*1.2+phase),3.0);
		ALBEDO = mix(vec3(0.18,0.08,0.4),vec3(0.6,0.75,1.0),0.5+0.5*sin(phase));
		EMISSION = ALBEDO*(0.3+2.2*pulse);
	} else {
		ALBEDO = COLOR.rgb;
	}
}
