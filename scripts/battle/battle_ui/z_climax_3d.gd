extends RefCounted
## Per-move finales: one compressed core, a coherent expansion, then dissipation.
## Geometry, lighting and recoil use the same native recovery fraction.
const DATA = preload("res://data/battle_z_climaxes_3d.json")
const Forms = preload("res://scripts/battle/battle_ui/z_move_forms_3d.gd")
var profile: Dictionary
var cloud: ShaderMaterial
var hot: ShaderMaterial
var shell: ShaderMaterial
var solid: ShaderMaterial
var spectrum: Array[ShaderMaterial] = []
var ball := SphereMesh.new()
var ring := TorusMesh.new()
var plume: ArrayMesh
var ground := Vector3.ZERO
var scale_value := 1.0
var start_index := -1
var end_index := -1

static func supports(key: String) -> bool:
	return DATA.data.moves.has(key)

static func pulse(key: String, after: float) -> float:
	var p: Dictionary = DATA.data.moves[key]
	return smoothstep(float(p.delay),float(p.peak)*0.65,after)*(1.0-smoothstep(float(p.peak),0.58,after))

static func recoil(key: String, after: float) -> Vector2:
	var p: Dictionary = DATA.data.moves[key]
	var t := maxf(0,after-float(p.delay))
	var weight := smoothstep(0,0.045,t)*(1.0-smoothstep(0.06,0.32,t))*float(p.recoil)
	return Vector2(sin(t*45)*0.07,cos(t*33)*0.05)*weight

static func frame_half(key: String) -> Vector3:
	var p: Dictionary = DATA.data.moves[key]
	return Vector3(float(p.radius)*2.2,float(p.height)*0.8,float(p.radius)*2.2)

func _init(key: String) -> void:
	profile = DATA.data.moves[key]
	ball.radius = 1
	ball.height = 2
	ball.radial_segments = 48
	ball.rings = 24
	ring.inner_radius = 0.95
	ring.outer_radius = 1
	ring.rings = 64
	ring.ring_segments = 10
	cloud = _material(0)
	hot = _material(1)
	shell = _material(2)
	var kind := 2 if profile.family == "earth" else 4 if profile.family == "shatter" else 1 if profile.family == "liquid" else 0
	solid = Forms.material(Color(profile.tint),kind,true)
	if profile.motif in ["rainbow","evolution"]:
		for color in ["ff695c","ffdc66","91e776","7ee7dd","7faaff","bf8aff","ef91de","fff1ca"]:
			var material := _material(1)
			material.set_shader_parameter("tint",Color(color))
			material.set_shader_parameter("hot_color",Color(color).lerp(Color.WHITE,0.18))
			spectrum.append(material)
	var points: Array[Vector3] = []
	var radii: Array[float] = []
	for i in 13:
		var t := i/12.0
		points.append(Vector3(t,sin(t*PI*0.8)*0.75,0))
		radii.append(0.22*pow(1.0-t,0.7)+0.006)
	plume = Forms.tube(points,radii)

func _material(kind: int) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
uniform vec4 tint : source_color;
uniform vec4 hot_color : source_color;
uniform float seconds = 0.0;
uniform float opacity = 1.0;
uniform float heat = 0.0;
uniform int kind = 0;
varying vec3 shape;
float hash(vec3 p) {
 p = fract(p * 0.1031);
 p += dot(p, p.yzx + 33.33);
 return fract((p.x + p.y) * p.z);
}
float noise3(vec3 p) {
 vec3 i = floor(p); vec3 f = fract(p); f = f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
 mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { shape = VERTEX; }
void fragment() {
 vec3 field = shape*3.8-vec3(0,seconds*1.6,0);
 float flow = noise3(field)*0.72+noise3(field*2.1)*0.28;
 float face = max(dot(normalize(NORMAL),normalize(VIEW)),0.0);
 float density = smoothstep(0.18,0.8,flow);
 float glow = smoothstep(0.42,0.72,flow)*heat;
 vec3 color = mix(tint.rgb*0.15,tint.rgb,density);
 color = mix(color,hot_color.rgb,glow);
 float alpha = opacity*smoothstep(0.0,0.4,face)*(0.5+density*0.5);
 if (kind == 1) {
  color = mix(tint.rgb,hot_color.rgb,pow(face,0.4));
  alpha = opacity*smoothstep(0.0,0.6,face);
 } else if (kind == 2) {
  color = mix(tint.rgb,hot_color.rgb,0.45+heat*0.4);
  alpha = opacity*(0.08+pow(1.0-face,2.5)*0.7);
 }
 ALBEDO = color;
 EMISSION = color*(kind == 1 ? 1.6 : 0.35+glow*0.75);
 ALPHA = alpha;
}
"""
	var result := ShaderMaterial.new()
	result.shader = shader
	result.set_shader_parameter("kind",kind)
	result.set_shader_parameter("tint",Color(profile.tint))
	result.set_shader_parameter("hot_color",Color(profile.hot))
	return result

func _put(effect: Node, mesh: Mesh, material: Material, point: Vector3, size: Vector3, basis := Basis.IDENTITY) -> void:
	effect._piece(mesh,material,ground+point*scale_value,size,basis)

func draw(effect: Node, after: float, at_ground: Vector3) -> void:
	start_index = -1
	end_index = -1
	if after < 0 or (not effect.hit and profile.motif != "evolution"): return
	ground = at_ground
	scale_value = float(effect._geometry_scale())
	start_index = effect.cursor
	var grow := smoothstep(float(profile.delay),float(profile.peak),after)
	var fade := 1.0-smoothstep(0.38,0.96,after)
	var radius := float(profile.radius)*(0.055+grow*0.945+maxf(0,after-float(profile.peak))*0.12)
	var height := float(profile.height)*(0.1+grow*0.9)
	var center := Vector3.UP*height*0.43
	var heat := pulse(effect.key,after)
	for material in [cloud,hot,shell]+spectrum:
		material.set_shader_parameter("seconds",after*1.8)
		material.set_shader_parameter("heat",heat)
		material.set_shader_parameter("opacity",fade*0.92)
	hot.set_shader_parameter("opacity",1.0-smoothstep(float(profile.peak)*0.6,0.44,after))
	if profile.motif == "evolution": hot.set_shader_parameter("opacity",fade*0.6)
	solid.set_shader_parameter("seconds",after*1.8)
	solid.set_shader_parameter("opacity",fade)
	match profile.family:
		"energy", "electric", "strike":
			_cloud(effect,center,radius,height,after)
			if profile.family == "electric": _electric(effect,center,radius,height,after)
			elif profile.family == "strike": _strike(effect,center,radius,height,after)
			else: _energy(effect,center,radius,height,after)
		"earth":
			_cloud(effect,Vector3.UP*height*0.25,radius,height*0.6,after)
			_earth(effect,radius,height,grow,after)
		"liquid":
			_put(effect,ball,cloud,center*0.65,Vector3(radius,height*0.35,radius))
			_crown(effect,radius,height,after,solid,6 if profile.motif != "opera" else 8)
			_put(effect,ball,hot,center*0.65,Vector3(radius*0.7,height*0.3,radius*0.7))
		"void": _void(effect,center,radius,height,grow,after)
		"shatter":
			_cloud(effect,center,radius*0.72,height*0.8,after)
			_shatter(effect,center,radius,height,grow,after)
		"strand":
			_cloud(effect,center,radius*0.8,height*0.8,after)
			_strands(effect,center,radius,height,grow,after)
		"resonance":
			_cloud(effect,center,radius*0.65,height*0.8,after)
			for i in 3:
				var reach := radius*(0.7+i*0.3)
				_put(effect,ball,shell,center,Vector3(reach,height*(0.35+i*0.1),reach))
			_crown(effect,radius,height*0.55,after,hot,6)
		"bloom", "aura": _bloom(effect,center,radius,height,grow,after)
	# A single ground front anchors every finale in the arena.
	var reach := float(profile.radius)*1.85*smoothstep(float(profile.delay),float(profile.peak)+0.12,after)
	_put(effect,ring,shell,Vector3.UP*0.13,Vector3(reach,1.1+grow,reach))
	end_index = effect.cursor

func _cloud(effect: Node, center: Vector3, radius: float, height: float, after: float) -> void:
	_put(effect,ball,cloud,center,Vector3(radius,height*0.46,radius))
	for i in 6:
		var angle := i*2.39996+after*(0.3+i*0.03)
		var offset := Vector3(cos(angle)*radius*0.5,sin(i*2.4)*height*0.1,sin(angle)*radius*0.5)
		var size := 0.52+0.1*sin(i*3.5)
		_put(effect,ball,cloud,center+offset,Vector3(radius*size,height*0.32,radius*size))
	_put(effect,ball,hot,center,Vector3(radius*0.68,height*0.32,radius*0.68))

func _crown(effect: Node, radius: float, height: float, after: float, material: Material, count: int) -> void:
	for i in count:
		var angle := i*TAU/count+after*0.4
		var basis := Basis(Vector3.UP,angle)
		_put(effect,plume,material,basis.x*radius*0.25+Vector3.UP*0.12,Vector3(radius*1.25,height*1.1,radius*0.65),basis)

func _energy(effect: Node, center: Vector3, radius: float, height: float, after: float) -> void:
	match profile.motif:
		"fire", "dragon", "moon", "pillar":
			_crown(effect,radius*0.8,height,after,hot,3 if profile.motif == "dragon" else 5)
			if profile.motif in ["moon", "pillar"]:
				_put(effect,ball,hot,Vector3.UP*height*0.6,Vector3(radius*0.28,height*0.6,radius*0.28))
		"sun":
			for i in 8:
				var direction := Vector3(cos(i*TAU/8),0.4,sin(i*TAU/8)).normalized()
				_put(effect,effect.tooth,hot,center+direction*radius*0.75,Vector3(radius*0.16,radius*1.6,radius*0.16),Forms.Volume.along(direction))
		"nova", "darkfire":
			for i in 2:
				_put(effect,ring,shell,center,Vector3.ONE*radius*(1.35+i*0.1),Basis(Vector3.RIGHT,PI*(0.23+i*0.5))*Basis(Vector3.FORWARD,after*0.5))

func _electric(effect: Node, center: Vector3, radius: float, height: float, after: float) -> void:
	var count := 8 if profile.motif == "rainbow" else 6
	for i in count:
		var angle := i*TAU/count
		var direction := Vector3(cos(angle),0,sin(angle))
		var previous := center
		for j in 4:
			var t := (j+1)/4.0
			var p := center+direction*radius*t*1.6+Vector3.UP*(sin(t*PI)*height*0.4-center.y*t)
			p += direction.cross(Vector3.UP)*sin(j*3.5+i+after*16)*radius*0.12*sin(t*PI)
			var delta := p-previous
			_put(effect,effect.tube,spectrum[i] if profile.motif == "rainbow" else hot,(p+previous)*0.5,Vector3(0.035,delta.length(),0.035),Forms.Volume.along(delta))
			previous = p
	if profile.motif == "surf":
		_put(effect,ball,shell,center*0.7,Vector3(radius*1.7,height*0.6,radius*0.8))
	elif profile.motif == "dive": _crown(effect,radius*0.8,height,after,hot,5)

func _strike(effect: Node, center: Vector3, radius: float, height: float, after: float) -> void:
	var direction: Vector3 = ground-effect.fixed_actor_ground
	direction.y = 0
	if direction.is_zero_approx(): direction = Vector3.FORWARD
	direction = direction.normalized()
	match profile.motif:
		"barrage", "ram":
			_put(effect,plume,hot,center-direction*radius*0.4,Vector3(radius*1.6,height*0.35,radius*0.8),Basis(Vector3.UP,atan2(-direction.z,direction.x)))
			_put(effect,ball,shell,center+direction*radius*0.4,Vector3(radius*1.4,height*0.5,radius*1.4))
		"drill":
			for i in 3:
				_put(effect,ring,shell,center+direction*(i-1)*radius*0.4,Vector3.ONE*radius*(0.8+i*0.15),Forms.Volume.along(direction)*Basis(Vector3.RIGHT,0.25*sin(after*5+i)))
		_:
			var count := 7 if profile.motif == "seven" else 4
			for i in count:
				var angle := i*TAU/count+after*0.2
				var ray := Vector3(cos(angle),0.3,sin(angle)).normalized()
				_put(effect,effect.tooth,hot,center+ray*radius*0.65,Vector3(radius*0.16,radius*1.3,radius*0.16),Forms.Volume.along(ray))

func _earth(effect: Node, radius: float, height: float, grow: float, after: float) -> void:
	var count := 7 if profile.motif == "shards" else 6
	for i in count:
		var a := i*TAU/count
		var point := Vector3(cos(a)*radius*1.05,height*(0.15+sin(after*PI)*0.22),sin(a)*radius*1.05)
		var tall: float = 0.7 if profile.motif == "fissure" else 0.5 if profile.motif == "shards" else 0.2
		var basis := Basis(Vector3.UP,a)*Basis(Vector3.FORWARD,after*(0.5 if profile.motif == "fissure" else 1.8))
		_put(effect,effect.prism,solid,point,Vector3(radius*0.33,height*tall,radius*0.4)*grow,basis)

func _void(effect: Node, center: Vector3, radius: float, height: float, grow: float, after: float) -> void:
	if after < float(profile.delay):
		var squeeze := lerpf(float(profile.radius)*0.85,0.12,smoothstep(0,float(profile.delay),after))
		_put(effect,ball,cloud,Vector3.UP*float(profile.height)*0.4,Vector3.ONE*squeeze)
		_put(effect,ring,shell,Vector3.UP*float(profile.height)*0.4,Vector3.ONE*squeeze*1.2,Basis(Vector3.RIGHT,0.4))
		return
	cloud.set_shader_parameter("heat",pulse(effect.key,after)*0.28)
	_put(effect,ball,cloud,center,Vector3(radius,height*0.46,radius))
	_put(effect,ball,shell,center,Vector3(radius*1.4,height*0.6,radius*1.4))
	if profile.motif == "singularity":
		_put(effect,ring,hot,center,Vector3.ONE*radius*1.35,Basis(Vector3.RIGHT,0.4))
	else: _strands(effect,center,radius,height,grow,after)

func _shatter(effect: Node, center: Vector3, radius: float, height: float, grow: float, after: float) -> void:
	var ice: bool = profile.motif == "ice"
	var count := 6 if ice else 8
	for i in count:
		var a := i*TAU/count
		var point := center+Vector3(cos(a)*radius*1.1,sin(i*2.4)*height*0.2,sin(a)*radius*1.1)
		_put(effect,effect.prism if ice else effect.box,solid,point,Vector3(radius*0.22,height*0.44,radius*(0.22 if ice else 0.06))*grow,Basis(Vector3.UP,a+after)*Basis(Vector3.FORWARD,after*(1.0 if ice else 2.0)))

func _strands(effect: Node, center: Vector3, radius: float, height: float, grow: float, after: float) -> void:
	for i in 6:
		var a := i*TAU/6+after*0.5
		var basis := Basis(Vector3.UP,a)
		if profile.motif == "arrows":
			_put(effect,effect.tooth,hot,center+basis.x*radius,Vector3(radius*0.2,height*0.9,radius*0.2)*grow,basis*Basis(Vector3.FORWARD,-0.35))
		else:
			_put(effect,plume,shell,Vector3.UP*0.1+basis.x*radius*0.15,Vector3(radius*1.4,height*1.1,radius*0.5),basis)

func _bloom(effect: Node, center: Vector3, radius: float, height: float, grow: float, after: float) -> void:
	var evolution: bool = profile.motif == "evolution"
	var count := 6 if profile.motif == "fairy" else 8
	_put(effect,ball,hot,center,Vector3(radius*0.55,height*0.48,radius*0.55))
	_put(effect,ball,shell,center,Vector3(radius,height*0.6,radius))
	for i in count:
		var a := i*TAU/count+after*0.6
		var basis := Basis(Vector3.UP,a)*Basis(Vector3.FORWARD,lerpf(-0.7,-0.15,grow))
		_put(effect,plume,spectrum[i] if evolution else cloud,Vector3.UP*height*0.25,Vector3(radius*1.6,height*0.65,radius*0.9),basis)
	if evolution:
		for i in 3:
			_put(effect,ring,spectrum[i*2],Vector3.UP*height*(0.2+i*0.25),Vector3.ONE*radius*(0.7+i*0.1),Basis(Vector3.UP,after))
