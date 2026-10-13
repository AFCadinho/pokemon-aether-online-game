shader_type spatial;
render_mode cull_disabled;
uniform sampler2D layer_mask : filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 colour1 = vec4(1.0);
uniform vec4 colour2 = vec4(1.0);
uniform vec4 colour3 = vec4(1.0);
uniform vec4 colour4 = vec4(1.0);
uniform vec4 emission1 = vec4(0.0);
uniform vec4 emission2 = vec4(0.0);
uniform vec4 emission3 = vec4(0.0);
uniform vec4 emission4 = vec4(0.0);
uniform vec4 powers = vec4(0.0);
uniform vec4 scales = vec4(1.0);
void fragment(){
 vec4 mask=clamp(texture(layer_mask,UV2)*2.0*scales,vec4(0.0),vec4(1.0));
 vec3 colour=vec3(1.0); vec3 glow=vec3(0.0);
 vec4 colours[4]={colour1,colour2,colour3,colour4};
 vec4 emissions[4]={emission1,emission2,emission3,emission4};
 for(int i=0;i<4;i++){colour=mix(colour,colours[i].rgb,mask[i]);glow=mix(glow,emissions[i].rgb*powers[i],mask[i]);}
 ALBEDO=colour;EMISSION=glow*.5;ROUGHNESS=.45;
 vec4 n=texture(normal_map,UV2);NORMAL_MAP=vec3(n.rg,n.a);NORMAL_MAP_DEPTH=1.0;
}
