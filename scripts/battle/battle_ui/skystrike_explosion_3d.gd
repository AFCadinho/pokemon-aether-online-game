extends RefCounted
## One contiguous blast: compression, rapid expansion, rolling cloud, dissipation.
## All phases are fractions of the existing recovery; never use a wall clock.
const FRAME_RADIUS := 6.4
var cloud: ShaderMaterial
var core: ShaderMaterial
var shock: ShaderMaterial
var pressure := TorusMesh.new()

static func expansion(after: float) -> float:
	return smoothstep(0.025,0.23,after)

static func pulse(after: float) -> float:
	return smoothstep(0.015,0.085,after)*(1.0-smoothstep(0.20,0.52,after))

static func recoil(after: float) -> Vector2:
	var envelope := smoothstep(0.025,0.08,after)*(1.0-smoothstep(0.08,0.35,after))
	return Vector2(sin(after*45.0)*0.08,cos(after*33.0)*0.055)*envelope

func _init() -> void:
	pressure.inner_radius = 0.94
	pressure.outer_radius = 1.0
	pressure.rings = 64
	pressure.ring_segments = 12
	cloud = _material(false)
	core = _material(true)
	shock = _material(false)

func _material(white_core: bool) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform float seconds = 0.0;
uniform float opacity = 1.0;
uniform float heat = 0.0;
uniform bool white_core = false;
varying vec3 shape;
float hash(vec3 p) {
 return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);
}
float noise3(vec3 p) {
 vec3 i = floor(p);
 vec3 f = fract(p);
 f = f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
 mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() {
 shape = VERTEX;
 // Keep transparent surfaces convex: displaced concave triangles cannot
 // reliably sort within one mesh. Rolling detail belongs in the density.
}
void fragment() {
 vec3 field = shape*4.5-vec3(0,seconds*1.8,0);
 float flow = noise3(field)*0.65+noise3(field*2.1)*0.25+noise3(field*4.2)*0.1;
 float facing = max(dot(normalize(NORMAL),normalize(VIEW)),0.0);
 float light = clamp(dot(normalize(NORMAL),normalize(vec3(-0.4,0.8,0.5)))*0.5+0.5,0.0,1.0);
 float billow = smoothstep(0.25,0.72,flow);
 vec3 color = mix(vec3(0.025,0.12,0.3),vec3(0.5,0.82,1.0),billow*(0.45+light*0.55));
 float hot = smoothstep(0.48,0.68,flow)*heat;
 color = mix(color,vec3(0.87,0.97,1.0),hot);
 if (white_core) color = mix(vec3(0.33,0.79,1.0),vec3(1.0),pow(facing,0.3));
 ALBEDO = color;
 EMISSION = color*(white_core ? 2.1 : 0.3+hot*0.9);
 ALPHA = opacity*smoothstep(0.0,0.45,facing)*(white_core ? 1.0 : 0.55+billow*0.45);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("white_core",white_core)
	return material

func draw(effect: Node, after: float) -> void:
	if not effect.hit or after < 0: return
	var growth := expansion(after)
	var fade := 1.0-smoothstep(0.34,0.92,after)
	var radius := lerpf(0.18,2.45,growth)+maxf(0,after-0.23)*0.6
	var scale_value: float = effect.presentation_scale
	var center: Vector3 = effect.fixed_ground+Vector3.UP*(0.35+radius*0.65)*scale_value
	for material in [cloud,core,shock]: material.set_shader_parameter("seconds",after*1.5)
	cloud.set_shader_parameter("opacity",fade*0.96)
	cloud.set_shader_parameter("heat",pulse(after))
	core.set_shader_parameter("opacity",1.0-smoothstep(0.10,0.32,after))
	shock.set_shader_parameter("opacity",(1.0-smoothstep(0.36,0.88,after))*growth*0.8)
	# Overlapping lobes stay attached to the center, making a rolling blast
	# silhouette rather than a spray of individual particles or flat masks.
	effect._piece(effect.sphere,cloud,center,Vector3(1.0,1.15,1.0)*radius)
	for i in 7:
		var angle := i*2.39996+after*(0.25+i*0.025)
		var outward := Vector3(cos(angle),sin(i*2.4)*0.38,sin(angle))
		var point := center+outward*radius*(0.65+sin(i*1.7)*0.1)*scale_value
		var size := 0.67+0.15*sin(i*3.5)
		effect._piece(effect.sphere,cloud,point,Vector3(size,size*1.15,size)*radius,Basis(Vector3(1,1,0).normalized(),angle))
	effect._piece(effect.sphere,core,center,Vector3.ONE*radius*0.8)
	for i in 6:
		var angle := i*TAU/6.0
		var direction := Vector3(cos(angle),0.25+0.15*sin(i*2.4),sin(angle)).normalized()
		var basis := Basis.looking_at(direction,Vector3.UP)*Basis(Vector3.RIGHT,-PI/2)
		effect._piece(effect.tooth,core,center+direction*radius*0.9*scale_value,Vector3(0.25,1.8,0.25)*radius,basis)
	# A thick ground-hugging pressure front expands even while its opacity fades.
	var reach := lerpf(0.25,5.5,smoothstep(0.02,0.38,after))
	effect._piece(pressure,shock,effect.fixed_ground+Vector3.UP*0.16,Vector3(reach,0.8+growth,reach))
