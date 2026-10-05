extends "res://scripts/battle/battle_ui/source_move_effect_3d.gd"
## Authored 3D choreography using the inspected SV ew0434 masks and atlases.
const CHARGE_RADIUS := 0.34
const ART := {
	"charge": [preload("res://assets/battles/moves_3d/sv_dracometeor/cpt_1_circle0005.png"),Vector3(1,0.42,0.06),1.0,false],
	"flash": [preload("res://assets/battles/moves_3d/sv_dracometeor/cpt_1_flash0001.png"),Vector3(1,0.8,0.28),1.0,false],
	"streak": [preload("res://assets/battles/moves_3d/sv_dracometeor/cpt_1_blur0003.png"),Vector3(0.22,0.45,1),1.0,false],
	"fire": [preload("res://assets/battles/moves_3d/sv_dracometeor/cpt_2_fire0007.png"),Vector3(1,0.5,0.07),8.0,false],
	"sparks": [preload("res://assets/battles/moves_3d/sv_dracometeor/cpt_2_fire0008.png"),Vector3(1,0.65,0.16),4.0,false],
	"shock": [preload("res://assets/battles/moves_3d/sv_dracometeor/cpt_2_shock0004.png"),Vector3(1,0.53,0.13),4.0,false],
	"smoke": [preload("res://assets/battles/moves_3d/sv_dracometeor/cpt_2_smoke0011.png"),Vector3(0.28,0.17,0.1),4.0,true],
}
const LAVA = preload("res://assets/battles/moves_3d/sv_dracometeor/cpt_3_flow0024.png")
const ROCK = preload("res://assets/battles/moves_3d/sv_dracometeor/cpt_3_flow0026.png")
var meteor := SphereMesh.new()
var cone := CylinderMesh.new()
var ring := TorusMesh.new()
var lava: ShaderMaterial
var flame: ShaderMaterial
var debris: StandardMaterial3D
var amber: StandardMaterial3D
var released := false
var origin := Vector3.ZERO
var aim := Vector3.ZERO
var ground := Vector3.ZERO
var sky := Vector3.ZERO
var forward := Vector3.FORWARD
var sideways := Vector3.RIGHT

func _init() -> void:
	super._init()
	sprite_shader.code = sprite_shader.code.replace("void fragment() {", "uniform bool quarter_mask = false;\nuniform float atlas_rows = 1.0;\nvoid fragment() {")
	sprite_shader.code = sprite_shader.code.replace("vec2 uv = vec2((UV.x + floor(frame_index)) / frames, UV.y);", "float columns = frames / atlas_rows;\nvec2 uv = (UV + vec2(mod(floor(frame_index), columns), floor(frame_index / columns))) / vec2(columns, atlas_rows);\nif (quarter_mask) uv = vec2(1.0) - abs(UV * 2.0 - vec2(1.0));")
	meteor.radius = 1.0
	meteor.height = 2.0
	meteor.radial_segments = 9
	meteor.rings = 5
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 12
	ring.inner_radius = 0.92
	ring.outer_radius = 1.0
	ring.rings = 24
	ring.ring_segments = 6

func _sprite_values(id: String) -> Array:
	return ART[id]

func _sprite(point: Vector3, size: float, id: String, phase: float, opacity: float, facing: Basis, turn := 0.0, aspect := Vector2.ONE) -> void:
	var before := cursor
	_source_sprite(point,size,id,phase,opacity,facing,turn,aspect)
	if cursor>before:
		sprite_materials[cursor-1].set_shader_parameter("quarter_mask",id in ["charge","flash","streak"])
		sprite_materials[cursor-1].set_shader_parameter("atlas_rows",2.0 if id=="smoke" else 1.0)

func _build_materials() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded;
uniform sampler2D cracks : filter_linear, repeat_enable;
uniform sampler2D rock : filter_linear, repeat_enable;
uniform float seconds = 0.0;
void fragment() {
 float n = texture(cracks, UV * 2.0 + vec2(seconds * 0.07,0.0)).r;
 float grain = texture(rock, UV * 3.0).r;
 float hot = smoothstep(0.56,0.9,n);
 ALBEDO = mix(vec3(0.075,0.035,0.025) * (0.6 + grain), vec3(1.0,0.38,0.025),hot);
 EMISSION = vec3(1.0,0.26,0.015) * hot * 0.7;
}
"""
	lava = ShaderMaterial.new()
	lava.shader = shader
	lava.set_shader_parameter("cracks",LAVA)
	lava.set_shader_parameter("rock",ROCK)
	var flame_shader := Shader.new()
	flame_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform sampler2D noise_mask : filter_linear, repeat_enable;
uniform float seconds = 0.0;
void fragment() {
 float n = texture(noise_mask,UV * vec2(2.0,1.5)+vec2(0.0,seconds*2.0)).r;
 ALBEDO = mix(vec3(1.0,0.16,0.015),vec3(1.0,0.82,0.2),n);
 float edge = pow(abs(dot(normalize(NORMAL),normalize(VIEW))),0.7);
 ALPHA = smoothstep(0.0,0.6,UV.y) * smoothstep(0.18,0.7,n) * edge * 0.55;
}
"""
	flame = ShaderMaterial.new()
	flame.shader = flame_shader
	flame.set_shader_parameter("noise_mask",LAVA)
	debris = _material(Color("513025"),1.0)
	amber = _material(Color("ffac32"),0.8)

func _draw_source_move(from: Vector3, to: Vector3, right: Vector3, up: Vector3) -> bool:
	if lava==null: _build_materials()
	var facing := Basis(right,up,right.cross(up))
	var p := elapsed/duration
	lava.set_shader_parameter("seconds",p*3.2)
	flame.set_shader_parameter("seconds",p*3.2)
	amber.albedo_color.a = 0.8*(1.0-smoothstep(0.76,0.98,p))
	if not released:
		origin = from
		aim = to
		ground = anchors.call().get("target_ground",Vector3(to.x,0.04,to.z))
		forward = Vector3(to.x-from.x,0,to.z-from.z).normalized()
		sideways = forward.cross(Vector3.UP).normalized()
		sky = from.lerp(to,0.55) + Vector3.UP*4.3
		if elapsed>=launch: released = true
	var charge := clampf(elapsed/maxf(launch,0.01),0,1)
	if elapsed<launch:
		var r := CHARGE_RADIUS*smoothstep(0,0.8,charge)
		_ball(origin,r,core)
		_sprite(origin,r*5,"charge",0,0.65,facing)
		for i in 6:
			var angle := i*TAU/6.0+p*9.0
			var distance := (1.0-charge)*1.2+0.12
			_sprite(origin+Vector3(cos(angle),sin(angle),sin(angle*2)*0.35)*distance,0.12,"flash",0,charge,facing,angle)
			_sprite(origin+Vector3(cos(angle),sin(angle),0)*distance,0.24,"streak",0,charge*(1-charge),facing,angle,Vector2(0.35,1))
	elif p<0.43:
		var t := clampf((p-launch/duration)/(0.43-launch/duration),0,1)
		var point := origin.lerp(sky,t*t)
		_ball(point,CHARGE_RADIUS,core)
		_sprite(point,1.1,"charge",0,0.85,facing)
		for i in 5:
			var back := maxf(t-0.055*(i+1),0)
			_sprite(origin.lerp(sky,back*back),0.6-i*0.07,"fire",fmod(p*10+i*0.13,1),0.75-i*0.1,facing)
	var burst := (p-0.40)/0.13
	if burst>=0 and burst<1:
		_sprite(sky,1.6+burst*1.4,"flash",0,(1.0-burst)*0.9,facing,0.4)
		_piece(ring,amber,sky,Vector3.ONE*(0.3+burst*1.2),facing*Basis(Vector3.RIGHT,PI/2))
	# One direct meteor establishes the damage beat; six satellites make the shower.
	for i in 7:
		var angle := i*2.399963
		var offset := Vector3.ZERO if i==0 else (sideways*cos(angle)+forward*sin(angle))*(0.95+0.2*(i%3))
		var landing := aim if i==0 else ground+offset+Vector3.UP*0.15
		var arrival := impact/duration+float(i)*0.024
		var fall_start := 0.44+float(i)*0.014
		var fall := (p-fall_start)/(arrival-fall_start)
		var top := sky + offset*1.4 - forward*(0.7+float(i)*0.1)
		var radius := 0.33 if i==0 else (0.19+float(i%3)*0.04)
		if fall>=0 and fall<1:
			var point := top.lerp(landing,fall*fall)
			_meteor(point,(top-landing).normalized(),radius,facing,i,p)
		var after := (p-arrival)/0.19
		if hit and after>=0 and after<1:
			_impact(landing,ground+offset,after,radius,facing,i)
	return true

func _meteor(point: Vector3, trail: Vector3, radius: float, facing: Basis, index: int, p: float) -> void:
	_piece(meteor,lava,point,Vector3.ONE*radius,Basis(Vector3(1,0.5,0.2).normalized(),p*7+index))
	var x := trail.cross(Vector3.RIGHT if absf(trail.y)>0.95 else Vector3.UP).normalized()
	var length := radius*6.5
	_piece(cone,flame,point+trail*length*0.5,Vector3(radius*1.6,length,radius*1.6),Basis(x,trail,x.cross(trail)),true)
	_sprite(point,radius*3.6,"charge",0,0.38,facing)
	for j in 2:
		_sprite(point+trail*radius*(1.7+j*1.3),radius*(2.4-j*0.5),"fire",fmod(p*10+index*.17+j*.3,1),0.65-j*.15,facing,index+j)

func _impact(point: Vector3, floor_point: Vector3, after: float, radius: float, facing: Basis, index: int) -> void:
	var strength := 1.3 if index==0 else 0.8
	_sprite(point+Vector3.UP*after*.6,strength*(0.9+after),"shock",after,1.0-after,facing)
	_sprite(point+Vector3.UP*(0.3+after),strength*(0.7+after*.7),"smoke",after,0.45*(1-after),facing,index)
	_piece(ring,amber,floor_point,Vector3(1,0.25,1)*(radius+after*strength))
	for j in 3:
		var angle := j*TAU/3+index
		var direction := sideways*cos(angle)+forward*sin(angle)
		var shard := point+direction*after*strength+Vector3.UP*sin(after*PI)*.6
		_piece(meteor,debris,shard,Vector3.ONE*radius*.22*(1-after),Basis(Vector3.RIGHT,after*8+j))
	_sprite(point,strength,"sparks",after,0.8*(1-after),facing,index)
