shader_type spatial;
render_mode cull_back, blend_mix, depth_draw_never;
uniform vec4 tint : source_color;
uniform float seconds = 0.;
uniform float opacity = 1.;
uniform float luminous = .4;
uniform int kind = 0;
uniform int mode = 0;
varying vec3 local_point;
float hash3(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise3(vec3 p) {
 vec3 i=floor(p), f=fract(p); f=f*f*(3.-2.*f);
 return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),
 mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { local_point=VERTEX; }
void fragment() {
 float face=abs(dot(normalize(NORMAL),normalize(VIEW)));
 float n=noise3(local_point*3.+vec3(0.,-seconds*1.4,seconds*.35));
 float fold=.5+.5*sin(UV.x*18.84956+UV.y*13.-seconds*5.+n*4.);
 vec3 low=tint.rgb*.32;
 vec3 high=mix(tint.rgb,vec3(1.),.3);
 float shade=clamp(.24+n*.55+pow(face,2.)*.3,0.,1.);
 if(kind==1) { low=tint.rgb*.25; high=mix(tint.rgb,vec3(1.,.86,.42),.75); shade=smoothstep(.15,.95,n+fold*.32); }
 if(kind==2) { high=mix(tint.rgb,vec3(.85,.98,1.),.6); shade=.25+n*.4+pow(1.-face,3.)*.35; }
 if(kind==3) { low=tint.rgb*.08; shade=smoothstep(.25,.9,n+fold*.25); }
 if(kind==4) { shade=.25+n*.65; }
 ALBEDO=mix(low,high,shade);
 EMISSION=ALBEDO*luminous*(.35+fold*.25);
 ROUGHNESS=kind==2 ? .2 : .65;
 METALLIC=kind==4 ? .15 : 0.;
 float alpha=opacity;
 if(mode==1) alpha*=pow(face,1.4)*(.26+n*.24);
 if(mode==2) alpha*=pow(face,.55)*(1.-smoothstep(.0,1.,UV.y))*(.45+fold*.25);
 if(mode==3) {
  float ends=smoothstep(0.,.10,UV.y)*(1.-smoothstep(.83,1.,UV.y));
  alpha*=ends*(.18+pow(fold,3.)*.65);
 }
 ALPHA=alpha;
}
