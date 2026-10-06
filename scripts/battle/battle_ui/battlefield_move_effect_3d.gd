extends "res://scripts/battle/battle_ui/family_move_effect_3d.gd"
## Stage-wide pilots. World coordinates are captured once; only sprite facing
## follows the camera. Ground decoration never changes arena/gameplay state.
const FIELD_KEYS := ["earthquake", "blizzard", "bloomdoom"]
var field_center := Vector3.ZERO
var field_radius := 5.8
var forward := Vector3.RIGHT
var lateral := Vector3.FORWARD
var captured := false
var floor_mesh := PlaneMesh.new()
var floor_material: ShaderMaterial
var soil: StandardMaterial3D
var leaf: StandardMaterial3D
var petals: Array[StandardMaterial3D] = []
var flower_mesh: ArrayMesh
var ground_basis := Basis.IDENTITY
var shaft_mesh := QuadMesh.new()
var shaft_material: ShaderMaterial

func _geometry_scale() -> float:
	# The arena dimensions are world meters, independent of projectile magnification.
	return 1.0

func _prepare() -> void:
	super._prepare()
	soil = _material(Color("675344"),.9)
	leaf = _material(Color("66a849"),.85)
	for color in ["ffb9e1","ffe099","f4dcff"]:petals.append(_material(Color(color),.9))
	floor_mesh.size=Vector2.ONE
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float progress;
uniform float opacity;
uniform int kind;
void fragment() {
	vec2 p = (UV-.5)*2.;
	p.y = -p.y;
	float disk = 1.-smoothstep(.90,1.,length(p));
	float front = progress*2.4-1.2;
	float reached = 1.-smoothstep(front-.10,front+.10,p.y);
	float mask = 0.;
	vec3 color = vec3(.21,.14,.07);
	if(kind==0) {
		float cracks = 0.;
		for(int i=0;i<7;i++) {
			float lane = float(i-3)*.21*(.8+(p.y+1.)*.18);
			float zig = abs(fract(p.y*3.7+float(i)*.618)*2.-1.);
			float detail = abs(fract(p.y*8.3+float(i)*.37)*2.-1.);
			float fault = lane+(zig-.5)*.11+(detail-.5)*.035;
			float branch_start = -.65+float(i)*.18;
			float fork = fault+max(0.,p.y-branch_start)*.28;
			float branch = (1.-smoothstep(.002,.009,abs(p.x-fork)))*step(branch_start,p.y)*(1.-smoothstep(branch_start+.25,branch_start+.5,p.y));
			cracks=max(cracks,max(branch,1.-smoothstep(.004,.015,abs(p.x-fault))));
		}
		mask=cracks*reached;
		color=mix(vec3(.065,.035,.012),vec3(.65,.38,.13),1.-smoothstep(.02,.18,abs(p.y-front)));
	} else if(kind==1) {
		float veins=pow(abs(sin(p.x*24.+sin(p.y*15.)*2.)*sin(p.y*31.)),12.);
		mask=(.08+veins*.35)*reached;
		color=vec3(.55,.83,1.);
	} else {
		float veins=pow(abs(sin(p.x*14.+p.y*7.)*sin(p.y*19.-p.x*6.)),8.);
		mask=(.08+veins*.38)*reached;
		color=vec3(.26,.72,.21);
	}
	ALBEDO=color;
	EMISSION=color*.2;
	ALPHA=mask*disk*opacity;
}
"""
	floor_material=ShaderMaterial.new()
	floor_material.shader=shader
	floor_material.set_shader_parameter("kind",FIELD_KEYS.find(key))
	var shaft_shader := Shader.new()
	shaft_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform float opacity;
void fragment() {
	float x=abs(UV.x-.5)*2.;
	float glow=exp(-x*x*7.)*(1.-smoothstep(.7,1.,x));
	float ends=smoothstep(0.,.25,UV.y)*(1.-smoothstep(.65,1.,UV.y));
	ALBEDO=mix(vec3(.4,.85,.24),vec3(1.,.96,.65),glow);
	ALPHA=glow*ends*opacity;
}
"""
	shaft_material=ShaderMaterial.new()
	shaft_material.shader=shaft_shader
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for petal in 5:
		var a := petal*TAU/5.0
		for segment in 5:
			var b := a-.48+segment*.96/5
			var c := b+.96/5
			tool.add_vertex(Vector3(0,.04,0))
			tool.add_vertex(Vector3(cos(b),.13,sin(b))*(.55+.45*sin(segment*PI/5)))
			tool.add_vertex(Vector3(cos(c),.13,sin(c))*(.55+.45*sin((segment+1)*PI/5)))
	flower_mesh=tool.commit()

func _field_point(along: float, across: float, height: float = 0.0) -> Vector3:
	return field_center+forward*along+lateral*across+Vector3.UP*height

func _seed_point(index: int, count: int) -> Vector3:
	var angle := index*2.399963
	var radius := field_radius*sqrt((index+.5)/count)*.88
	return _field_point(cos(angle)*radius,sin(angle)*radius)

func _draw_source_move(from: Vector3,to: Vector3,right: Vector3,up: Vector3) -> bool:
	if recipe.is_empty():_prepare()
	if not captured:
		captured=true
		var points: Dictionary=anchors.call()
		var field: Dictionary=points.get("field",{})
		field_center=field.get("center",(from+to)*.5*Vector3(1,0,1)+Vector3.UP*.055)
		field_radius=float(field.get("radius",5.8))
		origin=points.get("actor_ground",Vector3(from.x,field_center.y,from.z))
		aim=to
		forward=Vector3(to.x-from.x,0,to.z-from.z).normalized()
		if forward.length()<.01:forward=Vector3.RIGHT
		lateral=forward.cross(Vector3.UP).normalized()
		ground_basis=Basis(lateral,Vector3.UP,-forward)
	var facing := Basis(right,up,right.cross(up))
	var t := elapsed/duration
	var travel := clampf((elapsed-launch)/maxf(impact-launch,.01),0,1)
	var after := (elapsed-impact)/maxf(duration-impact,.01)
	var envelope := smoothstep(0,.10,t)*(1-smoothstep(.72,1,t))
	edge.albedo_color.a=envelope*.7
	core.albedo_color.a=envelope*.85
	glow.albedo_color.a=envelope*.10
	soil.albedo_color.a=envelope*.85
	leaf.albedo_color.a=envelope*.8
	for mat in petals:mat.albedo_color.a=envelope*.9
	surface.set_shader_parameter("opacity",envelope*.65)
	surface.set_shader_parameter("seconds",elapsed)
	floor_material.set_shader_parameter("progress",travel if key!="bloomdoom" else smoothstep(0,.52,t))
	floor_material.set_shader_parameter("opacity",envelope)
	_piece(floor_mesh,floor_material,field_center,Vector3(field_radius*2,1,field_radius*2),ground_basis)
	match key:
		"earthquake":_earthquake(travel,after,envelope,facing)
		"blizzard":_blizzard(travel,after,envelope,facing)
		"bloomdoom":_bloom_field(t,travel,after,envelope,facing)
	impact_drawn=hit and after>=0
	if impact_drawn:
		var fade := 1-clampf(after,0,1)
		_source_sprite(aim,1.8+after,"1",clampf(after,0,1),fade*.7,facing)
		for i in 6:
			var a := i*TAU/6
			var offset := (lateral*cos(a)+Vector3.UP*sin(a))*(.25+after*1.5)
			_line(aim+offset*.4,aim+offset,.025*fade,core)
	return true

func _earthquake(travel: float,after: float,alpha: float,facing: Basis) -> void:
	if elapsed<launch:
		for i in 5:
			var a := i*TAU/5
			_source_sprite(origin+Vector3(cos(a),.15,sin(a))*.65,.5,"0",0,alpha*.25,facing)
		return
	# Successive ridges cross the painted circle, leaving branching cracks behind.
	for i in 24:
		var p := _seed_point(i,24)
		var arrival := ((p-field_center).dot(forward)/field_radius+1)*.5
		var age := travel-arrival*.86
		if age<0:continue
		var lift := sin(clampf(age/.32,0,1)*PI)*.55
		_piece(prism,soil,p+Vector3.UP*(lift+.06),Vector3(.25,.18+lift*.5,.38)*alpha,Basis(Vector3.UP,i)*Basis(Vector3.FORWARD,lift*.5))
		if age<.35:
			_source_sprite(p+Vector3.UP*(.15+age*2),.8+age,"0",age*2,alpha*(1-age/.35)*.32,facing,i)
	for band in 2:
		var q := travel*1.15-band*.17
		if q<0 or q>1:continue
		var x := lerpf(-field_radius,field_radius,q)
		var width := sqrt(maxf(0,field_radius*field_radius-x*x))*.92
		for i in 10:
			var z := lerpf(-width,width,i/10.0)
			var z2 := lerpf(-width,width,(i+1)/10.0)
			_line(_field_point(x+sin(i*2.5)*.08,z,.06),_field_point(x+sin((i+1)*2.5)*.08,z2,.06),.028*alpha,edge)

func _blizzard(travel: float,after: float,alpha: float,facing: Basis) -> void:
	# A broad bank of snow crosses the arena, then curls around its outer edge.
	for i in 42:
		var seed := _seed_point(i,42)
		var phase := fmod(tween_phase()+i*.618,1.0)
		var across := (seed-field_center).dot(lateral)
		var along := lerpf(-field_radius,field_radius,phase)
		if Vector2(along,across).length()>field_radius*.95:continue
		var height_value := .25+fmod(i*.73,2.4)+sin(phase*PI)*.5
		var p := _field_point(along,across,height_value)
		var visibility := sin(phase*PI)*alpha
		_source_sprite(p,.24+(i%3)*.1,"0",phase,visibility*.65,facing,elapsed+i)
		if i%4==0:_line(p-forward*.38-Vector3.UP*.10,p,.012*visibility,core)
	for stream in 3:
		var q := clampf(travel*1.25-stream*.15,0,1)
		var previous := _field_point(-field_radius*.85,(stream-1)*1.6,.35+stream*.35)
		for i in 8:
			var f := (i+1)/8.0*q
			var along := lerpf(-field_radius*.85,field_radius*.85,f)
			var across := (stream-1)*1.6+sin(f*TAU+elapsed)*.5
			var p := _field_point(along,across,.35+stream*.35+sin(f*PI)*.7)
			_line(previous,p,.018*alpha,edge)
			previous=p

func tween_phase() -> float:
	return elapsed/maxf(duration,.01)*1.65

func _bloom_field(t: float,travel: float,after: float,alpha: float,facing: Basis) -> void:
	for i in 18:
		var p := _seed_point(i,18)
		var arrival := ((p-field_center).dot(forward)/field_radius+1)*.5
		var grow := smoothstep(arrival*.30,arrival*.30+.18,t)*alpha
		var top := p+Vector3.UP*(.18+(i%3)*.15)*grow
		_line(p,top,.022*grow,leaf)
		_piece(flower_mesh,petals[i%3],top,Vector3.ONE*(.32+(i%3)*.06)*grow,Basis(Vector3.UP,i+sin(elapsed+i)*.08))
		if i%2==0:_piece(prism,leaf,p+Vector3.UP*.12*grow,Vector3(.24,.10,.10)*grow,Basis(Vector3.UP,i))
	if elapsed>=launch:
		for i in 8:
			var start := _seed_point(i*2,18)+Vector3.UP*.3
			var p := smoothstep(0,1,clampf(travel*1.18-i*.025,0,1))
			var point := start.lerp(aim,p)+Vector3.UP*sin(p*PI)*1.8
			var tail := start.lerp(aim,maxf(0,p-.06))+Vector3.UP*sin(maxf(0,p-.06)*PI)*1.8
			_source_sprite(point,.45,"0",p,alpha*(1-smoothstep(.92,1,p))*.75,facing,i)
			_line(tail,point,.025*alpha,edge)
	if after>=0:
		var fade := 1-clampf(after,0,1)
		shaft_material.set_shader_parameter("opacity",fade*alpha*.6)
		_piece(shaft_mesh,shaft_material,aim+Vector3.UP*.8,Vector3(3.1,4.8,1),facing)
		for i in 8:
			var a := i*TAU/8+elapsed
			_piece(flower_mesh,petals[i%3],aim+Vector3(cos(a),after*1.4,sin(a))*(.4+after*1.6),Vector3.ONE*.18*fade,Basis(Vector3.RIGHT,a))
