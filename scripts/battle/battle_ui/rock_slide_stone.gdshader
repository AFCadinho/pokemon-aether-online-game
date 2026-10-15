
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform float opacity = 1.;
varying vec3 local_point;
void vertex() { local_point = VERTEX; }
void fragment() {
 float layers = .5+.5*sin(local_point.y*19.+sin(local_point.x*8.+local_point.z*5.)*1.7);
 float grain = .5+.5*sin(dot(local_point,vec3(37.,53.,29.)));
 ALBEDO = mix(vec3(.19,.14,.095),vec3(.48,.38,.25),.3+layers*.45+grain*.12);
 ROUGHNESS = .96;
 ALPHA = opacity;
}
