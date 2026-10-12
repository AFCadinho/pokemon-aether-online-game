extends "res://scripts/battle/battle_ui/source_move_effect_3d.gd"
## Authored 3D choreography using the inspected SV ew0434 masks and atlases.
const CHARGE_RADIUS := 0.34
const VolumeForms = preload("res://scripts/battle/battle_ui/move_volume_forms_3d.gd")
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
var ring := TorusMesh.new()
var lava: ShaderMaterial
var flame: ShaderMaterial
var debris: StandardMaterial3D
var amber: StandardMaterial3D
var tail_mesh: ArrayMesh
var charge_surface: ShaderMaterial
var released := false
var origin := Vector3.ZERO
var aim := Vector3.ZERO
var ground := Vector3.ZERO
var sky := Vector3.ZERO
var forward := Vector3.FORWARD
var sideways := Vector3.RIGHT

func _init() -> void:
	super._init()
	sprite_shader = preload("res://scripts/battle/battle_ui/draco_meteor_sprite.gdshader")
	meteor.radius = 1.0
	meteor.height = 2.0
	meteor.radial_segments = 9
	meteor.rings = 5
	tail_mesh = VolumeForms.swept_mesh(false)
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
 float hot = smoothstep(0.7,0.93,n);
 float facet = 0.65 + abs(dot(normalize(NORMAL), normalize(VIEW))) * 0.35;
 ALBEDO = mix(vec3(0.16,0.075,0.04) * (0.6 + grain) * facet, vec3(1.0,0.38,0.025),hot);
 EMISSION = vec3(1.0,0.26,0.015) * hot * 0.7;
}
"""
	lava = ShaderMaterial.new()
	lava.shader = shader
	lava.set_shader_parameter("cracks",LAVA)
	lava.set_shader_parameter("rock",ROCK)
	flame = VolumeForms.tail_material()
	charge_surface = VolumeForms.energy_material(false)
	debris = _material(Color("513025"),1.0)
	amber = _material(Color("ffac32"),0.8)

func _draw_source_move(from: Vector3, to: Vector3, right: Vector3, up: Vector3) -> bool:
	if lava==null: _build_materials()
	var facing := Basis(right,up,right.cross(up))
	var p := elapsed/duration
	lava.set_shader_parameter("seconds",p*3.2)
	flame.set_shader_parameter("seconds",p*3.2)
	charge_surface.set_shader_parameter("seconds",p*3.2)
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
		_ball(origin,r,charge_surface)
		_sprite(origin,r*3.4,"charge",0,0.38,facing)
	elif p<0.43:
		var t := clampf((p-launch/duration)/(0.43-launch/duration),0,1)
		var point := origin.lerp(sky,t*t)
		_ball(point,CHARGE_RADIUS,charge_surface)
		_sprite(point,0.9,"charge",0,0.4,facing)
		_piece(tail_mesh,flame,point,Vector3(CHARGE_RADIUS, minf(point.distance_to(origin), 1.6), CHARGE_RADIUS),VolumeForms.along(origin-sky),true)
	var burst := (p-0.40)/0.13
	if burst>=0 and burst<1:
		_sprite(sky,1.6+burst*1.4,"flash",0,(1.0-burst)*0.9,facing,0.4)
		_piece(ring,amber,sky,Vector3.ONE*(0.3+burst*1.2),facing*Basis(Vector3.RIGHT,PI/2))
	# Five readable rocks carry the shower; the leading rock retains the damage beat.
	for i in 5:
		var angle := i*2.399963
		var offset := Vector3.ZERO if i==0 else (sideways*cos(angle)+forward*sin(angle))*(0.95+0.2*(i%3))
		var landing := aim if i==0 else ground+offset+Vector3.UP*0.15
		var arrival := impact/duration+float(i)*0.024
		var fall_start := 0.44+float(i)*0.014
		var fall := (p-fall_start)/(arrival-fall_start)
		var top := sky + offset*1.4 - forward*(0.7+float(i)*0.1)
		var radius := 0.43 if i==0 else (0.26+float(i%3)*0.04)
		if fall>=0 and fall<1:
			var point := top.lerp(landing,fall*fall)
			_meteor(point,(top-landing).normalized(),radius,i,p)
		var after := (p-arrival)/0.19
		if hit and after>=0 and after<1:
			_impact(landing,ground+offset,after,radius,facing,i)
	return true

func _meteor(point: Vector3, trail: Vector3, radius: float, index: int, p: float) -> void:
	_piece(meteor,lava,point,Vector3.ONE*radius,Basis(Vector3(1,0.5,0.2).normalized(),p*7+index))
	var length := radius*5.0
	_piece(tail_mesh,flame,point+trail*radius*.3,Vector3(radius*1.1,length,radius*1.1),VolumeForms.along(trail),true)

func _impact(point: Vector3, floor_point: Vector3, after: float, radius: float, facing: Basis, index: int) -> void:
	var strength := 1.3 if index==0 else 0.8
	var compression := sin(clampf(after / 0.28,0,1)*PI)
	if compression > 0.001:
		_piece(meteor,charge_surface,point,Vector3(1.0,0.38,1.0)*radius*2.0*compression)
	_sprite(point+Vector3.UP*(0.15+after*.5),strength*(0.65+after*.9),"smoke",after,0.28*(1-after),facing,index)
	_piece(ring,amber,floor_point,Vector3(1,0.25,1)*(radius+after*strength))
	for j in 4:
		var angle := j*TAU/4+index
		var direction := sideways*cos(angle)+forward*sin(angle)
		var shard := floor_point+direction*after*strength+Vector3.UP*4.0*after*(1-after)*.65
		_piece(meteor,debris,shard,Vector3.ONE*radius*.32*(1-after),Basis(Vector3.RIGHT,after*8+j))
