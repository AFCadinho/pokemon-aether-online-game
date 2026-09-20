shader_type spatial;
varying vec2 p;
void vertex() { p = (MODEL_MATRIX*vec4(VERTEX,1.0)).xz; }
void fragment() {
	vec2 cell = abs(fract(p/3.0+0.5)-0.5)*3.0;
	float line = 1.0-smoothstep(0.012,0.045,min(cell.x,cell.y));
	float r = length(p);
	float rings = max(1.0-smoothstep(0.025,0.065,abs(r-5.8)),1.0-smoothstep(0.025,0.065,abs(r-4.7)));
	rings = max(rings,1.0-smoothstep(0.025,0.065,abs(r-0.8)));
	float center = (1.0-smoothstep(0.02,0.06,abs(p.x)))*step(0.8,r);
	float pool = exp(-abs(p.x)*0.3)*0.09 + exp(-abs(abs(p.x)-16.0)*0.7)*0.13;
	ALBEDO = vec3(0.022,0.017,0.05);
	EMISSION = vec3(0.20,0.05,0.48)*(line*0.6+pool) + vec3(0.43,0.24,0.65)*max(rings,center);
	ROUGHNESS = 0.24;
	METALLIC = 0.55;
}
