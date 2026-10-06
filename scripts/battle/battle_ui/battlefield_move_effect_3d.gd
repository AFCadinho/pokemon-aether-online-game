extends "res://scripts/battle/battle_ui/family_move_effect_3d.gd"
## Stage-wide pilots. World coordinates are captured once; only sprite facing
## follows the camera. Ground decoration never changes arena/gameplay state.
const APPROVED_KEYS := ["earthquake", "blizzard", "bloomdoom"]
const NEXT_KEYS := ["earthpower", "heatwave", "hurricane", "bleakwindstorm", "powdersnow", "freezedry", "explosion", "makeitrain", "terastarstorm"]
const FIELD_KEYS := APPROVED_KEYS + NEXT_KEYS
# Existing packaged SV masks reused where a generic shock sheet is unsuitable.
const SHARED_CAST_ART := {"earthpower":"powdersnow", "explosion":"powdersnow", "hurricane":"powdersnow", "bleakwindstorm":"powdersnow", "heatwave":"pyroball"}
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
var gold: StandardMaterial3D
var spectrum: Array[StandardMaterial3D] = []
var wind_mesh: ArrayMesh
var star_mesh: ArrayMesh
var wind_material: ShaderMaterial
var blast_material: ShaderMaterial
var shock_ring := TorusMesh.new()
var fire_shader: Shader
var star_halos: Array[ShaderMaterial] = []

func _sprite_values(id: String) -> Array:
	if id=="heat_flame":return SPRITES.ember_core
	if id=="heat_spark":return SPRITES.ember_sparks
	return super._sprite_values(id)

func _geometry_scale() -> float:
	# The arena dimensions are world meters, independent of projectile magnification.
	return 1.0

func _prepare() -> void:
	super._prepare()
	if key in SHARED_CAST_ART:
		art=art.duplicate()
		var shared: Array=Art.MANIFEST.data.moves[SHARED_CAST_ART[key]].textures
		art[0]=shared[0 if key=="heatwave" else 1]
		if key=="heatwave":art[1]=shared[1]
	soil = _material(Color("675344"),.9)
	leaf = _material(Color("66a849"),.85)
	gold = _material(Color("ffcd53"),.9)
	for color in ["ffc2e3","b2e9ff","d1b5ff","fff4a3"]:spectrum.append(_material(Color(color),.85))
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
	_prepare_wide_meshes()
	_prepare_fire_and_starlight()

func _prepare_fire_and_starlight() -> void:
	if key=="heatwave":
		# Dense red/orange edges and a hot yellow core keep fire readable against
		# the purple arena; low-opacity additive beige looked like drifting dust.
		fire_shader=Shader.new()
		fire_shader.code="""
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform sampler2D source_mask : filter_linear, repeat_disable;
uniform float frames;
uniform float frame_index;
uniform float opacity;
void fragment() {
	vec2 texel=.5/vec2(textureSize(source_mask,0));
	vec2 uv=clamp(UV,texel*vec2(frames,1.),vec2(1.)-texel*vec2(frames,1.));
	float f=floor(frame_index);
	float mask=mix(texture(source_mask,vec2((uv.x+f)/frames,uv.y)).r,texture(source_mask,vec2((uv.x+min(f+1.,frames-1.))/frames,uv.y)).r,fract(frame_index));
	vec3 flame=mix(vec3(.9,.025,.002),vec3(1.,.25,.006),smoothstep(.08,.42,mask));
	flame=mix(flame,vec3(1.,.86,.12),smoothstep(.45,.95,mask)*(1.-UV.y*.3));
	ALBEDO=flame;
	EMISSION=flame*.65;
	ALPHA=smoothstep(.015,.32,mask)*opacity;
}
"""
	if key=="terastarstorm":
		var halo_shader := Shader.new()
		halo_shader.code="""
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform vec4 tint : source_color;
uniform float opacity;
void fragment() {
	float radius=length((UV-.5)*2.);
	float mask=exp(-radius*radius*4.)*(1.-smoothstep(.65,1.,radius));
	ALBEDO=tint.rgb;
	ALPHA=mask*opacity;
}
"""
		for mat in spectrum:
			var halo := ShaderMaterial.new()
			halo.shader=halo_shader
			halo.set_shader_parameter("tint",mat.albedo_color)
			star_halos.append(halo)

func _fire_sprite(point: Vector3,size_value: float,phase: float,alpha: float,facing: Basis,aspect := Vector2.ONE) -> void:
	var before := cursor
	_source_sprite(point,size_value,"heat_flame",phase,alpha,facing,0,aspect)
	if cursor>before:sprite_materials[before].shader=fire_shader

func _prepare_wide_meshes() -> void:
	if key not in NEXT_KEYS:return
	shock_ring.inner_radius=.99
	shock_ring.outer_radius=1.0
	shock_ring.rings=64
	shock_ring.ring_segments=6
	var wind_shader := Shader.new()
	wind_shader.code="""
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform float opacity;
void fragment() {
	float across=sin(UV.y*3.14159);
	float ends=sin(UV.x*3.14159);
	ALBEDO=vec3(.63,.84,.91);
	ALPHA=pow(across,2.)*ends*opacity;
}
"""
	wind_material=ShaderMaterial.new()
	wind_material.shader=wind_shader
	var blast_shader := Shader.new()
	blast_shader.code="""
shader_type spatial;
render_mode unshaded, cull_back, blend_add, depth_draw_never;
uniform float opacity;
void fragment() {
	float rim=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),3.);
	ALBEDO=vec3(1.,.73,.42);
	ALPHA=rim*opacity;
}
"""
	blast_material=ShaderMaterial.new()
	blast_material.shader=blast_shader
	var ribbon := SurfaceTool.new()
	ribbon.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in 64:
		for corner: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
			var h := (j+corner.x)/64.0
			var a := h*TAU*1.4
			var radius := (1.25+h*.7)/field_radius if key=="bleakwindstorm" else .82-h*.48
			ribbon.set_uv(Vector2(h,corner.y))
			ribbon.add_vertex(Vector3(cos(a)*radius,.12+h*3.2+(corner.y-.5)*.25,sin(a)*radius))
	wind_mesh=ribbon.commit()
	var star := SurfaceTool.new()
	star.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [-1,1]:
		for i in 8:
			var a := i*TAU/8
			var b := (i+1)*TAU/8
			star.add_vertex(Vector3(0,0,.2*face))
			star.add_vertex(Vector3(cos(a),sin(a),0)*(1.0 if i%2==0 else .25))
			star.add_vertex(Vector3(cos(b),sin(b),0)*(1.0 if (i+1)%2==0 else .25))
	star_mesh=star.commit()

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
	if key in APPROVED_KEYS:
		_piece(floor_mesh,floor_material,field_center,Vector3(field_radius*2,1,field_radius*2),ground_basis)
	match key:
		"earthquake":_earthquake(travel,after,envelope,facing)
		"blizzard":_blizzard(travel,after,envelope,facing)
		"bloomdoom":_bloom_field(t,travel,after,envelope,facing)
		"earthpower":_earth_power(travel,after,envelope,facing)
		"heatwave":_heat_wave(travel,after,envelope,facing)
		"hurricane", "bleakwindstorm":_wide_storm(travel,after,envelope,facing)
		"powdersnow":_powder_snow(travel,after,envelope,facing)
		"freezedry":_freeze_dry(travel,after,envelope,facing)
		"explosion":_explosion(travel,after,envelope,facing)
		"makeitrain":_coin_rain(travel,after,envelope,facing)
		"terastarstorm":_star_storm(travel,after,envelope,facing)
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

func _earth_power(travel: float,after: float,alpha: float,facing: Basis) -> void:
	# Underground energy fans out, followed by staggered vents across the floor.
	var warm := clampf(elapsed/maxf(launch,.01),0,1)
	_source_sprite(origin+Vector3.UP*.1,1.4*warm,"0",warm,alpha*.5,facing)
	if elapsed<launch:return
	for i in 7:
		var end := _seed_point(i*2+3,18)
		var previous := origin
		for j in 3:
			var p := (j+1)/3.0*travel
			var point := origin.lerp(end,p)+lateral*sin(p*PI)*sin(i*4+j*3)*.45
			_line(previous,point,.025*alpha,edge)
			previous=point
	for i in 18:
		var base := _seed_point(i,18)
		var arrival := ((base-field_center).dot(forward)/field_radius+1)*.32
		var eruption := sin(clampf((travel-arrival)/.48,0,1)*PI)
		if eruption<=0:continue
		var top := base+Vector3.UP*eruption*(.7+(i%3)*.45)
		_piece(tooth,surface,base.lerp(top,.5),Vector3(.22*eruption,top.y-base.y,.22*eruption))
		_source_sprite(top,.8*eruption,"1",travel,alpha*eruption*.65,facing,i)
	if after>=0:
		var fade := 1-clampf(after,0,1)
		_source_sprite(aim,2.6,"1",after,alpha*fade*.65,facing)

func _heat_wave(travel: float,after: float,alpha: float,facing: Basis) -> void:
	var upright_right := Vector3(facing.x.x,0,facing.x.z).normalized()
	var upright := Basis(upright_right,Vector3.UP,upright_right.cross(Vector3.UP))
	if elapsed<launch:
		var charge := elapsed/maxf(launch,.01)
		for i in 5:
			var offset := lateral*(i-2)*.24
			_fire_sprite(origin+offset+Vector3.UP*(.45+charge*.3),.8+charge*.5,fmod(charge+i*.12,1),alpha*.85,upright,Vector2(.8,1.5))
		return
	var fade := 1-smoothstep(0,.75,after)
	# Two curling fronts, tall tongues of fire, then rising embers.
	for row in 2:
		var q := travel*1.15-row*.16
		if q<0 or q>1.15:continue
		for i in 15:
			var across := (i-7)/7.0*field_radius*.88
			var along := lerpf(-field_radius*.9,field_radius*.9,q)-absf(across)*.13+sin(i*.8+elapsed*2)*.12
			if Vector2(along,across).length()>field_radius:continue
			var height_value := 1.25+sin(i*1.7+elapsed*4)*.35
			var point := _field_point(along,across,height_value*.6)
			_fire_sprite(point,1.5-row*.2,fmod(elapsed*.8+i*.17,1),alpha*fade*(.9-row*.2),upright,Vector2(.9,height_value))
	for i in 18:
		var phase := fmod(elapsed*.7+i*.618,1.)
		var across := sin(i*2.4)*field_radius*.8
		var along := maxf(-field_radius*.9,lerpf(-field_radius*.8,field_radius*.8,travel)-phase*3.8)
		var point := _field_point(along,across,.3+phase*2.7)
		_source_sprite(point,.18+(i%3)*.04,"heat_spark",phase,alpha*fade*sin(phase*PI),facing,i)

func _wide_storm(travel: float,after: float,alpha: float,facing: Basis) -> void:
	var icy := key=="bleakwindstorm"
	var grow := smoothstep(0,launch/maxf(duration,.01),elapsed/duration)
	var fade := 1-smoothstep(.15,1,after)
	wind_material.set_shader_parameter("opacity",alpha*fade*.65)
	# Hurricane is one broad funnel; Bleakwind has two opposed icy spirals.
	for funnel in (2 if icy else 1):
		var center := field_center+lateral*(funnel*2-1)*field_radius*.38 if icy else field_center
		for ribbon in 2:
			_piece(wind_mesh,wind_material,center,Vector3(field_radius,1,field_radius)*grow,Basis(Vector3.UP,elapsed*(3.5 if funnel==0 else -3.5)+ribbon*PI))
	for i in 18:
		var angle := elapsed*2.8+i*2.4
		var radius := field_radius*(.4+(i%3)*.23)*grow
		var point := field_center+Vector3(cos(angle)*radius,.3+(i%4)*.48,sin(angle)*radius)
		_source_sprite(point,.75 if icy else 1.0,"0",fmod(elapsed*.5+i*.13,1),alpha*fade*.4,facing,angle)

func _powder_snow(travel: float,after: float,alpha: float,facing: Basis) -> void:
	if elapsed<launch:return
	# Low drifting powder opens into a wide cone, unlike Blizzard's high storm.
	for i in 42:
		var p := clampf(travel*1.35-i*.009,0,1)
		var across := sin(i*2.4)*field_radius*.82*p
		var along := lerpf(-field_radius*.9,field_radius*.9,p)
		var point := _field_point(along,across,.2+fmod(i*.37,.7)+sin(p*PI)*.35)
		if Vector2(along,across).length()>field_radius:continue
		# Seeds behind the front retain a brief drifting tail across both halves.
		point-=forward*fmod(i*.57,3.8)*p
		var fade := alpha*sin(p*PI)*(1-smoothstep(0,.8,after))
		_source_sprite(point,.3+(i%4)*.13,"0",p,fade*.65,facing,i+elapsed*.3)
		if i%5==0:_source_sprite(point-forward*.5,.6,"1",p,fade*.2,facing)

func _freeze_dry(travel: float,after: float,alpha: float,facing: Basis) -> void:
	if elapsed<launch:
		_source_sprite(origin+Vector3.UP*.4,1.0,"0",0,alpha*.35,facing)
		return
	for i in 24:
		var p := _seed_point(i,24)
		var arrival := ((p-field_center).dot(forward)/field_radius+1)*.35
		var grow := smoothstep(arrival,arrival+.22,travel)*alpha
		var height_value := (.4+(i%4)*.2)*grow
		_piece(tooth,surface,p+Vector3.UP*height_value*.5,Vector3(.14*grow,height_value,.14*grow),Basis(Vector3.FORWARD,sin(i)*.2))
		_source_sprite(p+Vector3.UP*.12,.85,"0",travel,grow*.28,facing,i)
		if i%2==0:
			var neighbor := _seed_point((i+5)%24,24)
			_line(p,p.lerp(neighbor,grow),.012*grow,core)
	if after>=0:
		for i in 5:
			var a := i*TAU/5
			var fade := 1-clampf(after,0,1)
			_piece(tooth,surface,aim+Vector3(cos(a)*.7,-.25,sin(a)*.7),Vector3(.15,.85,.15)*fade,Basis(Vector3.FORWARD,cos(a)*.3))

func _explosion(travel: float,after: float,alpha: float,facing: Basis) -> void:
	var center := origin+Vector3.UP*.7
	if elapsed<launch:
		var charge := elapsed/maxf(launch,.01)
		_source_sprite(center,1.2+charge,"0",charge,alpha*.7,facing)
		_piece(ring,edge,origin,Vector3.ONE*(1.4-charge*.8))
		return
	var radius := travel*(field_radius+origin.distance_to(field_center))
	var fade := 1-smoothstep(0,1,after)
	blast_material.set_shader_parameter("opacity",alpha*fade*.16)
	_piece(shock_ring,glow,origin+Vector3.UP*.04,Vector3.ONE*radius)
	_piece(sphere,blast_material,center,Vector3(radius,radius*.4,radius))
	_source_sprite(center,3.6,"1",travel,alpha*fade*(1-travel*.6),facing)
	for i in 24:
		var a := i*TAU/24
		var point := origin+Vector3(cos(a)*radius,.15+sin(travel*PI)*(i%3)*.4,sin(a)*radius)
		_source_sprite(point,1.2,"0",travel,alpha*fade*.4,facing,i)

func _coin_rain(travel: float,after: float,alpha: float,facing: Basis) -> void:
	gold.albedo_color.a=alpha*.9
	var charge := clampf(elapsed/maxf(launch,.01),0,1)
	for i in 24:
		var destination := _seed_point(i,24)
		var sky := destination+Vector3.UP*(3.8+(i%3)*.4)
		var p := clampf(travel*1.25-i*.009,0,1)
		var point := origin.lerp(sky,charge)+Vector3.UP*sin(charge*PI)*1.1 if elapsed<launch else sky.lerp(destination,p*p)
		if p>=1:point+=Vector3.UP*sin(clampf(after*2+(i%3)*.1,0,1)*PI)*.3
		_piece(tube,gold,point,Vector3(.16,.04,.16),Basis(Vector3.FORWARD,elapsed*4+i)*Basis(Vector3.RIGHT,.6))
		_source_sprite(point,.5,"0",p,alpha*.3,facing,i)
		if i%3==0 and elapsed>=launch:
			_line(point+Vector3.UP*.45,point,.016*alpha,core)

func _star_storm(travel: float,after: float,alpha: float,facing: Basis) -> void:
	for mat in spectrum:mat.albedo_color.a=alpha*.9
	for mat in star_halos:mat.set_shader_parameter("opacity",alpha*.65)
	var charge := clampf(elapsed/maxf(launch,.01),0,1)
	var sky_center := field_center+Vector3.UP*4.2
	var finale := 1-smoothstep(0,.6,after)
	# A large prismatic star gathers above a constellation spanning the arena.
	var main_point := origin.lerp(sky_center,smoothstep(0,1,charge)) if elapsed<launch else sky_center.lerp(aim,pow(travel,2.4))
	var main_size := (.25+charge*.85)*finale
	_piece(star_mesh,spectrum[1],main_point,Vector3(main_size,main_size*1.25,main_size*.45),facing*Basis(Vector3.FORWARD,elapsed*.35))
	_piece(star_mesh,core,main_point+facing.z*.02,Vector3.ONE*main_size*.46,facing*Basis(Vector3.FORWARD,elapsed*.35))
	_piece(quad,star_halos[1],main_point,Vector3.ONE*main_size*4.2,facing)
	for i in 12:
		var a := i*TAU/12+elapsed*.12
		var radius := field_radius*(.5+(i%2)*.28)
		var sky := sky_center+Vector3(cos(a)*radius,(i%2)*.35,sin(a)*radius)
		var destination := _seed_point(i,12)+Vector3.UP*.3
		var p := smoothstep(0,1,clampf(travel*1.18-i*.012,0,1))
		var point := origin.lerp(sky,smoothstep(0,1,charge)) if elapsed<launch else sky.lerp(destination,p)
		var visibility := (1-smoothstep(.86,1.,p))*alpha
		var size_value := (.32+charge*.17)*visibility
		_piece(star_mesh,spectrum[i%4],point,Vector3(size_value,size_value*1.4,size_value*.4),facing*Basis(Vector3.FORWARD,elapsed*.4+i))
		_piece(quad,star_halos[i%4],point,Vector3.ONE*size_value*3.8,facing)
		if elapsed>=launch:
			_line(sky.lerp(destination,maxf(0,p-.22)),point,.05*visibility,spectrum[i%4])
		elif i%2==0:
			_line(main_point,point,.014*alpha*charge,spectrum[i%4])
	# At impact the central star opens into a field-wide prismatic burst.
	if after>=0:
		var spread := sin(clampf(after*1.4,0,1)*PI*.5)
		var fade := 1-clampf(after,0,1)
		for i in 16:
			var a := i*TAU/16
			var offset := Vector3(cos(a),.35+sin(i*2.4)*.4,sin(a))*field_radius*spread
			var point := aim+offset
			_piece(star_mesh,spectrum[i%4],point,Vector3.ONE*(.3+spread*.15)*fade,facing*Basis(Vector3.FORWARD,elapsed+i))
			_line(aim+offset*.62,point,.035*alpha*fade,spectrum[i%4])
		for i in 3:
			var radius := maxf(0,spread-i*.08)*field_radius
			_piece(shock_ring,spectrum[i],field_center+Vector3.UP*(.08+i*.07),Vector3.ONE*radius)
		_piece(quad,star_halos[0],aim,Vector3.ONE*(2.5+spread*3)*fade,facing)
