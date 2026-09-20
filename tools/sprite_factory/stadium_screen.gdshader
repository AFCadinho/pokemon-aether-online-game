shader_type spatial;
render_mode unshaded;
void fragment() {
	vec2 p = UV*vec2(2.0,1.0);
	float cloud = sin(p.x*8.0+sin(p.y*9.0)+TIME*0.08)*sin(p.y*7.0-p.x*3.0);
	vec2 cell = floor(UV*vec2(150.0,80.0));
	float star = step(0.994,fract(sin(dot(cell,vec2(12.9898,78.233)))*43758.5453));
	ALBEDO = vec3(0.025,0.013,0.08)+vec3(0.15,0.06,0.28)*(cloud*0.5+0.5)+vec3(star*0.65);
}
