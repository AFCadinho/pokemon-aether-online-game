extends "res://scripts/battle/battle_ui/family_move_effect_3d.gd"
## World-space staging for the remaining ordinary moves. Outcomes stay event-owned.
const STAGING = preload("res://data/battle_move_staging_3d.json")
var profile: Dictionary
var motif := ""
var field_center := Vector3.ZERO
var field_radius := 5.8
var caster_ground := Vector3.ZERO
var target_ground := Vector3.ZERO
var initial_center := Vector3.ZERO
var captured := false
var weight := 1.0
var body := .7
var crescent: ArrayMesh
var feather: ArrayMesh
var pearl: StandardMaterial3D
var soft: ShaderMaterial
var soft_quad := QuadMesh.new()
var combo_hand: StandardMaterial3D
var combo_knuckles: StandardMaterial3D
var combo_spotlight: ShaderMaterial
var combo_beats_drawn: Array[int] = []

func _geometry_scale() -> float:return presentation_scale

func _sprite_values(id: String) -> Array:
	if id=="fire":
		var c := Color("996fff") if motif=="ghost-flames" else Color(str(recipe.color))
		return [SPRITES.ember_core[0],Vector3(c.r,c.g,c.b),4.0,false]
	if id=="water":return SPRITES.water_splash
	if id=="spark":return [preload("res://assets/battles/moves_3d/sv_moonblast/cpt_0_flash0001.png"),Vector3.ONE,1.0,false]
	if id=="mist":
		var binding: Dictionary=Art.MANIFEST.data.moves.powdersnow.textures[1]
		var c := Color(str(recipe.color))
		return [Art.TEXTURES[binding.path],Vector3(c.r,c.g,c.b),1.0,false]
	return super._sprite_values(id)

func _prepare() -> void:
	super._prepare()
	profile=STAGING.data.moves[key]
	motif=str(profile.motif)
	weight=float(profile.weight)
	tooth.radial_segments=16
	pearl=_material(Color(str(recipe.color)).lerp(Color.WHITE,.65),.8)
	edge.vertex_color_use_as_albedo=true
	pearl.vertex_color_use_as_albedo=true
	var shader := Shader.new()
	shader.code="""
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform vec4 tint : source_color;
uniform float opacity;
void fragment() {
	float r=length((UV-.5)*2.);
	ALBEDO=tint.rgb;
	ALPHA=exp(-r*r*4.)*(1.-smoothstep(.65,1.,r))*opacity;
}
"""
	soft=ShaderMaterial.new();soft.shader=shader
	soft.set_shader_parameter("tint",Color(str(recipe.color)))
	if key=="closecombat":
		combo_hand=_material(Color("657d74"),.98)
		combo_hand.shading_mode=BaseMaterial3D.SHADING_MODE_PER_PIXEL
		combo_hand.roughness=.65
		combo_hand.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
		combo_hand.cull_mode=BaseMaterial3D.CULL_BACK
		combo_hand.emission_energy_multiplier=.15
		combo_knuckles=combo_hand.duplicate()
		combo_knuckles.albedo_color=Color("c0d0b7")
		combo_spotlight=soft.duplicate()
		combo_spotlight.set_shader_parameter("tint",Color("36b9fa"))
	var tool := SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 32:
		for corner: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
			var p := (i+corner.x)/32.0
			var a := lerpf(-1.3,1.3,p)
			var radius := 1.-corner.y*.22*sin(p*PI)
			tool.set_color(Color(1,1,1,sin(p*PI)*lerpf(.25,.85,corner.y)))
			tool.add_vertex(Vector3(cos(a),sin(a),0)*radius)
	crescent=tool.commit()
	tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in [Vector3(0,-1,0),Vector3(.22,0,.06),Vector3(0,1,0),Vector3(0,1,0),Vector3(-.22,0,.06),Vector3(0,-1,0)]:
		tool.set_uv(Vector2(p.x/.44+.5,p.y*.5+.5))
		tool.add_vertex(p)
	feather=tool.commit()

func _draw_source_move(from: Vector3,to: Vector3,right: Vector3,up: Vector3) -> bool:
	if recipe.is_empty():_prepare()
	var points: Dictionary=anchors.call()
	var center: Vector3=points.get("actor_center",from)
	if not captured:
		captured=true
		caster_ground=points.get("actor_ground",Vector3(from.x,.04,from.z))
		target_ground=points.get("target_ground",Vector3(to.x,.04,to.z))
		initial_center=center
		var field: Dictionary=points.get("field",{})
		field_center=field.get("center",(caster_ground+target_ground)*.5)
		field_radius=float(field.get("radius",5.8))
		body=clampf(float(points.get("actor_radius",.7)),.45,1.4)
	if not launched:
		origin=from;aim=to
		if elapsed>=launch:launched=true
	var facing := Basis(right,up,right.cross(up))
	var direction := (aim-origin).normalized()
	if direction.length()<.01:direction=Vector3.FORWARD
	var side := direction.cross(Vector3.UP if absf(direction.y)<.95 else Vector3.RIGHT).normalized()
	var axis := Basis(side,direction,side.cross(direction))
	var t := elapsed/duration
	var flight := (elapsed-launch)/maxf(impact-launch,.01)
	var after := (elapsed-impact)/maxf(duration-impact,.01)
	var envelope := smoothstep(0,.1,t)*(1-smoothstep(.76,1.,t))
	edge.albedo_color.a=envelope*.7;core.albedo_color.a=envelope*.9;glow.albedo_color.a=envelope*.08;pearl.albedo_color.a=envelope*.8
	surface.set_shader_parameter("seconds",elapsed);surface.set_shader_parameter("opacity",envelope*.65)
	soft.set_shader_parameter("opacity",envelope*.5)
	if key=="closecombat":
		_close_combat(t,envelope,facing)
	elif recipe.contact:
		_contact_stage(from,center,flight,after,envelope,facing,side,axis)
	elif recipe.family=="beams":_beam_stage(from,flight,after,envelope,facing,axis)
	elif recipe.family=="projectiles":_projectile_stage(flight,after,envelope,facing,side,axis)
	elif recipe.family=="waves" or motif=="sound-call":_wave_stage(flight,after,envelope,facing,side,axis)
	elif recipe.family=="status":_status_stage(flight,after,envelope,facing,side,axis)
	elif recipe.family=="self":_self_stage(center,t,flight,after,envelope,facing)
	else:_field_stage(center,t,flight,after,envelope,facing,side)
	impact_drawn=hit and bool(recipe.damaging) and after>=0
	if impact_drawn:
		var fade := 1-clampf(after,0,1)
		_source_sprite(aim,(1.3+after)*weight,"1",clampf(after,0,1),fade*.65,facing)
		_piece(soft_quad,soft,aim,Vector3.ONE*weight*(2.+after),facing)
		for i in 6:
			var a := i*TAU/6
			var offset := (side*cos(a)+Vector3.UP*sin(a))*(.4+after*1.8)*weight
			_line(aim+offset*.55,aim+offset,.025*fade,pearl)
	return true

func _cast_art() -> String:
	if recipe.type=="fire":return "fire"
	if recipe.type=="water":return "water"
	if recipe.type in ["ghost","dark","poison"]:return "mist"
	return "0"

func _floor_point(i: int,count: int,opposing := false) -> Vector3:
	var a := i*2.399963
	var radius := sqrt((i+.5)/count)*field_radius*(.4 if opposing else .86)
	var center := field_center.lerp(target_ground,.65) if opposing else field_center
	return center+Vector3(cos(a)*radius,.025,sin(a)*radius)

func _contact_stage(from: Vector3,center: Vector3,flight: float,after: float,alpha: float,facing: Basis,side: Vector3,axis: Basis) -> void:
	if flight<0:
		var q := elapsed/maxf(launch,.01)
		for i in 3:
			var a := i*TAU/3+elapsed*2
			_source_sprite(initial_center+Vector3(cos(a),.1,sin(a))*body*(1.3-q*.3),.38,"spark",0,q*.3,facing)
		return
	var fade := 1-smoothstep(.1,.85,after)
	# Native contact motion owns approach/return; the wake follows that motion.
	for i in 8:
		var p := clampf(flight-i*.035,0,1)
		var ground := caster_ground.lerp(target_ground,p)
		var offset := side*sin(i*2.4)*body*.65
		if motif in ["water-rush","electric-rush","leaf-rush","energy-rush","dark-rush"]:
			_source_sprite(center-axis.y*i*.12+offset,.6-i*.035,_cast_art(),fmod(elapsed+i*.13,1),alpha*fade*.45,facing,i)
		else:_line(ground+offset-axis.y*.3,ground+offset,.015*alpha*fade,edge)
	if motif=="elemental-punch":
		var fist_center := from.lerp(aim,smoothstep(.35,.85,flight))
		for i in 7:
			var a := i*TAU/7+elapsed*4
			var point := fist_center+(side*cos(a)+Vector3.UP*sin(a))*.32
			if recipe.type=="ice":_piece(prism,surface,point,Vector3(.1,.3,.1)*fade,axis*Basis(Vector3.UP,a))
			elif recipe.type=="electric":_line(fist_center,point+axis.y*.3,.022*fade,pearl)
			else:_source_sprite(point,.7,"fire",fmod(elapsed+i*.1,1),alpha*fade*.7,facing,a)
	if motif in ["heavy-ram","rolling-rush","return-rush"]:
		_piece(crescent,edge,center,Vector3.ONE*body*1.25*fade,facing*Basis(Vector3.FORWARD,elapsed*7))
	if flight<.75 or after>.7:return
	var strike := sin(clampf((flight-.75)/.45,0,1)*PI)*alpha
	var amount := 5 if motif=="punch-barrage" or key=="furyattack" else 2 if key=="doublekick" else 1
	if motif in ["cross-slash","ghost-strike"]:
		for i in 3:
			_piece(crescent,pearl,aim+side*(i-1)*.2,Vector3.ONE*(.5+strike*.7)*weight*fade,facing*Basis(Vector3.FORWARD,-.7+i*.4))
	elif motif=="reaching-lash":
		var last := from
		for i in 12:
			var p := (i+1)/12.0
			var point := from.lerp(aim,p)+side*sin(p*PI)*sin(elapsed*8)*.75
			_line(last,point,.045*fade,edge);last=point
	elif motif=="biting-strike":
		for i in 8:
			var a := i*TAU/8
			var point := aim+(side*cos(a)+Vector3.UP*sin(a))*(.6-strike*.22)
			_piece(tooth,pearl,point,Vector3(.12,.24,.12)*fade,facing*Basis(Vector3.FORWARD,a+PI*.5))
	else:
		for i in amount:
			var beat := sin(clampf((flight-.75-i*.035)/.4,0,1)*PI)*fade
			var offset := (side*sin(i*2.4)+Vector3.UP*cos(i*2.4))*(.2 if amount>1 else 0.)
			var shape := Vector3(.23,.16,.55) if motif=="rising-kick" else Vector3(.28,.25,.3)
			if motif=="piercing-strike":_piece(tooth,pearl,aim+offset,Vector3(.13,.65,.13)*beat,axis)
			else:_piece(sphere,pearl,aim+offset,shape*weight*beat,axis)
			_piece(crescent,edge,aim+offset,Vector3.ONE*(.4+beat*.5)*weight*fade,facing*Basis(Vector3.FORWARD,i+elapsed*3))
	if motif=="draining-punch" and hit and after>=0:
		for i in 5:
			var p := clampf(after*1.5-i*.06,0,1)
			_source_sprite(aim.lerp(initial_center,p)+Vector3.UP*sin(p*PI)*.5,.24,"spark",0,alpha*(1-p),facing)

func _beam_stage(from: Vector3,flight: float,after: float,alpha: float,facing: Basis,axis: Basis) -> void:
	var charge := clampf(elapsed/maxf(launch,.01),0,1)
	for source: Vector3 in emission_sources:
		if flight<0:
			_piece(soft_quad,soft,source,Vector3.ONE*(.5+charge*1.2)*weight,facing)
			for i in 5:
				var a := elapsed*2+i*TAU/5
				var offset := (axis.x*cos(a)+axis.z*sin(a))*(1-charge*.65)*weight
				_line(source+offset,source+offset*.65,.016*alpha,pearl)
			continue
		var p := clampf(flight,0,1)
		var end := source.lerp(aim,p)
		var fade := (1-smoothstep(0,.65,after))*smoothstep(0,.12,flight)
		var width := (.18 if motif=="breath-stream" else .25)*weight*fade
		_line(source,end,width,surface);_line(source,end,width*.32,pearl)
		for i in 12:
			var q := fmod(elapsed*1.2+i/12.0,1.)*p
			var point := source.lerp(end,q)
			var spin := elapsed*7+i*.7
			var offset := (axis.x*cos(spin)+axis.z*sin(spin))*width*1.7
			_source_sprite(point+offset,.48,_cast_art(),fmod(elapsed+i*.1,1),alpha*fade*.55,facing,spin)
			if i%3==0:_piece(ring,edge,point,Vector3.ONE*width*(1.5+q),axis)
		if motif=="electric-beam":
			for i in 6:
				_line(source.lerp(end,i/6.)+axis.x*sin(i*3+elapsed*30)*.15,source.lerp(end,(i+1)/6.)+axis.x*sin((i+1)*3+elapsed*30)*.15,.03*fade,pearl)

func _projectile_stage(flight: float,after: float,alpha: float,facing: Basis,side: Vector3,axis: Basis) -> void:
	var charge := clampf(elapsed/maxf(launch,.01),0,1)
	if flight<0:
		_piece(soft_quad,soft,origin,Vector3.ONE*(.4+charge)*weight,facing)
		_source_sprite(origin,.5+charge*.4,_cast_art(),charge,alpha*.65,facing)
		return
	var count := 7 if motif=="leaf-fan" else 4 if motif=="spinning-shards" else 1
	var fade := 1-smoothstep(0,.45,after)
	for i in count:
		var p := smoothstep(0,1,clampf(flight-i*.025,0,1))
		var point := origin.lerp(aim,p)+side*sin(p*PI)*(i-(count-1)*.5)*.45
		if motif=="arcing-bomb":point.y+=sin(p*PI)*1.8
		if motif=="leaf-fan":_piece(feather,surface,point,Vector3(.55,.45,.4)*fade,axis*Basis(Vector3.UP,elapsed*7+i))
		elif motif=="spinning-shards":
			_piece(prism,surface,point,Vector3(.2,.5,.25)*fade,axis*Basis(Vector3.UP,elapsed*8+i))
			if key=="watershuriken":_piece(crescent,pearl,point,Vector3.ONE*.4*fade,facing*Basis(Vector3.FORWARD,elapsed*14+i))
		else:
			_piece(sphere,surface,point,Vector3.ONE*.4*weight*fade)
			_piece(soft_quad,soft,point,Vector3.ONE*1.65*fade,facing)
			for turn in 2:_piece(crescent,edge,point,Vector3.ONE*.6*fade,facing*Basis(Vector3.FORWARD,elapsed*4+turn*PI))
		for j in 5:
			var q := maxf(0,p-j*.025)
			var tail := origin.lerp(aim,q)+side*sin(q*PI)*(i-(count-1)*.5)*.45
			if motif=="arcing-bomb":tail.y+=sin(q*PI)*1.8
			_source_sprite(tail,(.65-j*.09) if count==1 else .28,_cast_art(),fmod(elapsed+j*.13,1),alpha*fade*(.55-j*.07),facing,i+j)

func _wave_stage(flight: float,after: float,alpha: float,facing: Basis,side: Vector3,axis: Basis) -> void:
	if motif=="heart-stream":_status_stage(flight,after,alpha,facing,side,axis);return
	if flight<0:
		_piece(soft_quad,soft,origin,Vector3.ONE*.9*elapsed/maxf(launch,.01),facing)
		return
	var fade := 1-smoothstep(.1,1,after)
	if motif=="sound-call" and recipe.target=="actor":
		for i in 5:
			var q := clampf(flight-i*.13,0,1)
			_piece(ring,edge,initial_center,Vector3.ONE*(body*.5+q*1.4)*fade,Basis(Vector3.RIGHT,PI/2)*Basis(Vector3.UP,i*.3))
		return
	if motif=="wind-spiral":
		for i in 24:
			var p := clampf(flight-i*.018,0,1)
			var a := elapsed*5+i*.65
			var point := origin.lerp(aim,p)+(side*cos(a)+axis.z*sin(a))*sin(p*PI)*.85
			_source_sprite(point,.65,"mist",p,alpha*fade*.4,facing,a)
		return
	for i in 7:
		var p := flight-i*.09
		if p<0 or p>1.3:continue
		var travel := clampf(p,0,1)
		var point := origin.lerp(aim,travel)
		var radius := (.2+travel*(1.2 if motif=="sound-tunnel" else .9))*weight
		var visibility := sin(clampf(p/1.3,0,1)*PI)*fade
		_piece(ring,edge,point,Vector3.ONE*radius*visibility,axis)
		if motif in ["psychic-tunnel","dark-tunnel"]:
			for sign_value in [-1.,1.]:_piece(crescent,pearl,point,Vector3.ONE*radius*visibility,axis*Basis(Vector3.RIGHT,PI/2)*Basis(Vector3.UP,elapsed*sign_value+i))
			_source_sprite(point,radius*1.4,"mist" if motif=="dark-tunnel" else "spark",travel,alpha*visibility*.3,facing)
		elif motif=="sound-tunnel":
			for sign_value in [-1.,1.]:_line(point+side*radius*sign_value,point+side*radius*sign_value+Vector3.UP*.35,.02*visibility,pearl)
	if motif=="returning-drain" and hit and after>=0:
		for i in 9:
			var p := clampf(after*1.5-i*.03,0,1)
			_source_sprite(aim.lerp(initial_center,p)+Vector3.UP*sin(p*PI)*.8,.35,"spark",0,alpha*(1-p),facing)

func _status_stage(flight: float,after: float,alpha: float,facing: Basis,side: Vector3,axis: Basis) -> void:
	if flight<0:return
	var fade := 1-smoothstep(.1,1,after)
	var p := clampf(flight,0,1)
	match motif:
		"heart-stream":
			for i in 5:
				var q := clampf(flight-i*.06,0,1)
				var point := origin.lerp(aim,q)+side*sin(q*PI)*(i-2)*.45+Vector3.UP*sin(q*PI)*.4
				_heart(point,(.17+i%2*.04)*fade,facing,edge)
				_source_sprite(point,.55,"spark",q,alpha*fade*.3,facing)
		"woven-threads", "paralysis-arcs":
			for strand in 3:
				var last := origin
				for i in 10:
					var q := (i+1)/10.0*p
					var curl := sin(q*PI)*(strand-1)*.7
					var point := origin.lerp(aim,q)+side*curl+Vector3.UP*sin(i*3+elapsed*15)*(.16 if motif=="paralysis-arcs" else .035)
					_line(last,point,.025*fade,pearl);last=point
		"taunt-glyph":
			var point := origin.lerp(aim,p)
			if key=="encore":
				for i in 6:
					var a := i*TAU/6+elapsed*.5
					_piece(crescent,pearl,point+(side*cos(a)+Vector3.UP*sin(a))*.8,Vector3.ONE*.25*fade,facing*Basis(Vector3.FORWARD,a))
			for i in 2:
				_piece(crescent,edge,point+side*(i-.5)*.55,Vector3(.35,.18,.35)*fade,facing*Basis(Vector3.FORWARD,PI*.5))
				_ball(point+side*(i-.5)*.55,.08*fade,pearl)
			for i in 5:_source_sprite(aim+(side*cos(i*TAU/5)+Vector3.UP*sin(i*TAU/5))*(.8+after*.3),.35,"spark",p,alpha*fade*maxf(0,flight-.5),facing)
		"seed-arc", "toxic-arc", "ghost-flames":
			for i in 5:
				var q := clampf(flight-i*.035,0,1)
				var point := origin.lerp(aim,q)+Vector3.UP*sin(q*PI)*(1.2+i*.12)+side*sin(q*PI)*(i-2)*.25
				if motif=="ghost-flames":
					_source_sprite(point,1.25,"fire",fmod(elapsed+i*.1,1),alpha*fade*.9,facing,i*.2)
					_piece(sphere,pearl,point,Vector3(.08,.14,.08)*fade)
					_piece(soft_quad,soft,point,Vector3.ONE*.85*fade,facing)
				else:_piece(sphere,surface,point,Vector3.ONE*(.09 if motif=="seed-arc" else .2)*fade)
				_source_sprite(point,.5,"mist",p,alpha*fade*.35,facing)
			if motif=="seed-arc" and flight>.8:
				for i in 6:
					var a := i*TAU/6
					_line(target_ground,target_ground+Vector3(cos(a),.04,sin(a))*(.4+clampf(after,0,1)),.018*fade,edge)
		_:
			for i in 24:
				var q := clampf(flight-i*.012,0,1)
				var a := i*2.4+elapsed*.6
				var spread := sin(q*PI*.8)*(.3+q*.9)
				var point := origin.lerp(aim,q)+(side*cos(a)+Vector3.UP*sin(a))*spread
				_source_sprite(point,.38+(i%3)*.16,"mist",q,alpha*fade*.4,facing,a)

func _self_stage(center: Vector3,t: float,flight: float,after: float,alpha: float,facing: Basis) -> void:
	var charge := smoothstep(0,.6,t)
	match motif:
		"sword-circle":
			for i in 4:
				var a := i*TAU/4+elapsed*.65
				var point := center+Vector3(cos(a)*body*1.4,sin(t*PI)*.6,sin(a)*body*1.4)
				_piece(tooth,pearl,point,Vector3(.1,1.1,.1)*alpha)
				_line(point-Vector3.UP*.4-facing.x*.2,point-Vector3.UP*.4+facing.x*.2,.045*alpha,edge)
				_source_sprite(point,.7,"spark",t,alpha*.4,facing)
		"armor-shell":
			for i in 5:
				var a := elapsed*.6+i*TAU/5
				_piece(crescent,edge,center,Vector3.ONE*body*(1.3-charge*.25),Basis(Vector3.UP,a)*Basis(Vector3.FORWARD,.3))
			_piece(sphere,glow,center,Vector3.ONE*body*1.2)
		"thought-bubbles":
			for i in 3:
				var point := center+Vector3.UP*(body*.8+i*.4)+facing.x*sin(i+elapsed)*.25
				_piece(sphere,glow,point,Vector3.ONE*(.15+i*.13)*alpha)
				_piece(ring,edge,point,Vector3.ONE*(.15+i*.13)*alpha,facing*Basis(Vector3.RIGHT,PI/2))
		"healing-rise", "growing-aura":
			for i in 12:
				var p := fmod(t+i/12.,1.)
				var a := i*2.4+elapsed*.4
				var point := caster_ground+Vector3(cos(a)*body*1.2,p*2.4,sin(a)*body*1.2)
				if key=="roost" or motif=="growing-aura":_piece(feather,pearl,point,Vector3.ONE*.25*sin(p*PI),facing*Basis(Vector3.FORWARD,a))
				else:
					_line(point-facing.x*.10,point+facing.x*.10,.028*alpha,pearl)
					_line(point-facing.y*.10,point+facing.y*.10,.028*alpha,pearl)
				_source_sprite(point,.35,"spark",t,alpha*sin(p*PI)*.5,facing)
		_:
			for i in 12:
				var a := elapsed*(4. if motif=="orbit-dance" else 1.4)+i*TAU/12
				var radius := body*(1.8-charge*.65) if motif=="inward-focus" else body*1.3
				var point := center+Vector3(cos(a)*radius,sin(a*2)*body*.55,sin(a)*radius)
				_source_sprite(point,.5,"spark" if motif=="electric-charge" else _cast_art(),fmod(t+i*.1,1),alpha*.6,facing,a)
				if i%3==0:_piece(crescent,edge,center,Vector3.ONE*radius,Basis(Vector3.UP,a)*Basis(Vector3.FORWARD,a*.3))
	_piece(soft_quad,soft,center,Vector3.ONE*body*2.2,facing)

func _field_stage(center: Vector3,t: float,flight: float,after: float,alpha: float,facing: Basis,side: Vector3) -> void:
	var grow := smoothstep(0,.55,t)
	var fade := 1-smoothstep(.1,1,after)
	match motif:
		"protective-screen":
			var width := body*(1.25 if key=="protect" else 1.7)*grow
			var point := center if recipe.target=="actor" else aim
			_piece(box,glow,point,Vector3(width*2,body*2.8*grow,.08),facing)
			for row in 3:
				for column in 3:
					var p := point+facing.x*(column-1)*width*.7+facing.y*(row-1)*body*.65
					_piece(ring,edge,p,Vector3.ONE*width*.34,facing*Basis(Vector3.RIGHT,PI/2))
			_piece(soft_quad,soft,point,Vector3(width*3,body*3.4,1),facing)
		"phase-portal", "exchanging-sides":
			for i in 3:
				var a := elapsed*2+i*TAU/3
				var base := caster_ground if motif=="phase-portal" else caster_ground.lerp(target_ground,t)
				_piece(ring,edge,base+Vector3.UP*(.15+i*.2),Vector3.ONE*body*(.8+i*.25)*alpha)
				_source_sprite(base+Vector3(cos(a),grow*1.8,sin(a))*body,.65,"mist",t,alpha*.5,facing)
			if motif=="exchanging-sides":
				for i in 10:
					var p := clampf(t*1.3-i*.025,0,1)
					_source_sprite(target_ground.lerp(caster_ground,p)+Vector3.UP*sin(p*PI)*2,.5,"spark",p,alpha*.6,facing)
		"scattered-hazards", "ground-web":
			for i in 9:
				var land := _floor_point(i,9,true)
				var p := smoothstep(0,1,clampf(flight-i*.015,0,1))
				var point := origin.lerp(land,p)+Vector3.UP*sin(p*PI)*2
				if motif=="ground-web":
					_line(land,land.lerp(_floor_point((i+3)%9,9,true),grow),.014*alpha,pearl)
					if i%3==0:_piece(ring,edge,land,Vector3.ONE*.65*grow)
				else:_piece(prism if key=="stealthrock" else tooth,surface,point+Vector3.UP*.2,Vector3(.23,.65,.23)*alpha,Basis(Vector3.FORWARD,sin(i)*.25))
		"future-eye", "wishing-star":
			var point := (center if motif=="wishing-star" else aim)+Vector3.UP*1.1
			_piece(crescent,edge,point,Vector3(1.2,.6,1)*grow,facing*Basis(Vector3.FORWARD,PI*.5))
			_source_sprite(point,1.5,"spark",t,alpha*.8,facing,elapsed*.3)
			for i in 7:
				var a := i*TAU/7+elapsed*.4
				_source_sprite(point+(facing.x*cos(a)+facing.y*sin(a))*1.2,.3,"spark",t,alpha*.4,facing)
		_:
			for i in 24:
				var base := _floor_point(i,24)
				var arrival := i/24.*.4
				var rise := smoothstep(arrival,arrival+.3,t)*alpha
				match motif:
					"grass-field":
						_piece(feather,edge,base+Vector3.UP*.35*rise,Vector3(.35,.6,.25)*rise,Basis(Vector3.UP,i)*Basis(Vector3.FORWARD,sin(elapsed+i)*.15))
						_source_sprite(base+Vector3.UP*.55,.4,"spark",t,rise*.4,facing)
					"electric-field":
						var end := _floor_point((i+5)%24,24)
						var mid := base.lerp(end,.5)+Vector3.UP*(.1+sin(i+elapsed*20)*.06)
						_line(base,mid,.018*rise,edge);_line(mid,base.lerp(end,rise),.018*rise,pearl)
					"psychic-field":
						_piece(crescent,edge,base+Vector3.UP*(.1+sin(elapsed+i)*.08),Vector3.ONE*.65*rise,Basis(Vector3.RIGHT,PI/2)*Basis(Vector3.FORWARD,elapsed+i))
						_source_sprite(base+Vector3.UP*.3,.6,"mist",t,rise*.3,facing)
					_:
						var height_value := .3+sin(elapsed+i)*.12
						if motif=="cold-front":height_value+=fmod(t+i*.618,1.)*1.5
						var motion := Vector3(cos(i+elapsed),0,sin(i+elapsed))*.35
						_source_sprite(base+motion+Vector3.UP*height_value,1.1 if motif=="clearing-mist" else .8,"mist",t,rise*.4,facing,i)

# Preserve the 2D beat positions/order in a world-space combat plane. These
# symbolic hands are authored geometry; no imported 2D strike sprites are used.
func _combo_fist(point: Vector3, size_value: float, orientation: Basis, palm: bool) -> void:
	# Broad knuckle row, curled fingers and an opposed thumb: readable at battle distance.
	_piece(sphere,combo_hand,point,Vector3(.48,.27,.32)*size_value,orientation)
	for finger in 4:
		var tip := Vector3((finger-1.5)*.25,.32,-.18)
		var shape := Vector3(.13,.23,.23)
		if palm:
			tip.y=.42+sin((finger+1)*PI/5)*.12
			shape=Vector3(.11,.34,.13)
		_piece(sphere,combo_knuckles,point+orientation*tip*size_value,shape*size_value,orientation)
	_piece(sphere,combo_hand,point+orientation*Vector3(-.46,-.10,-.12)*size_value,Vector3(.20,.24,.25)*size_value,orientation)

func _close_combat(t: float,alpha: float,facing: Basis) -> void:
	var combo: Dictionary=recipe.close_choreography
	var frame := t*float(combo.source_frames)
	var forward := aim-initial_center
	forward.y=0
	forward=forward.normalized()
	if forward.length()<.01:forward=Vector3.FORWARD
	var side := forward.cross(Vector3.UP).normalized()
	var hand_basis := Basis(side,Vector3.UP,-forward)
	var target_size := clampf(float(anchors.call().radius),.8,1.3)
	combo_hand.albedo_color.a=alpha*.98
	combo_knuckles.albedo_color.a=alpha
	combo_spotlight.set_shader_parameter("opacity",alpha*.48)
	var middle := caster_ground.lerp(target_ground,.68)
	_piece(soft_quad,combo_spotlight,middle+Vector3.UP*.04,Vector3(6,6,1),Basis(Vector3.RIGHT,-PI/2))
	for i in 8:
		var lane := caster_ground.lerp(target_ground,clampf(t*5-i*.06,0,1))
		var offset := side*(i%2*2-1)*(.7+i*.09)
		_line(lane+offset-forward*.8,lane+offset,.025*alpha*(1-smoothstep(.18,.4,t)),pearl)
	combo_beats_drawn.clear()
	for index in combo.beats.size():
		var beat: Dictionary=combo.beats[index]
		var source_age := frame-float(beat.frame)
		var finishing := bool(beat.finisher)
		var lifetime := 7.0 if finishing else 3.2
		if source_age<0 or source_age>lifetime+1:continue
		combo_beats_drawn.append(index)
		# Each source accent leads a left/right pair. Their overlapping recoveries
		# make a continuous flurry, rather than isolated small floating hit icons.
		for hand_index in (1 if finishing else 2):
			var age := source_age-hand_index*.85
			if age<0 or age>lifetime:continue
			var fade := 1-smoothstep(1.25,lifetime,age)
			var handedness := 1.0 if (index+hand_index)%2==0 else -1.0
			var offset := (side*(float(beat.x)/56.+handedness*.4)+Vector3.UP*float(beat.y)/56.)*target_size
			if hand_index==1:offset=side*-offset.dot(side)+Vector3.UP*(offset.y+.25*target_size)
			if finishing:offset=Vector3.UP*.15*target_size
			var contact := aim+offset
			var size_value := (1.65 if finishing else 1.05)*target_size
			var advance := smoothstep(0,1,age)
			var arc := sin(advance*PI)
			var hand := contact-forward*(1-advance)*(2.4 if finishing else 1.75)
			hand+=side*handedness*arc*.55*target_size
			var orientation := hand_basis*Basis(Vector3.FORWARD,handedness*(.28+(1-advance)*.6))
			_combo_fist(hand,size_value*fade,orientation,finishing)
			# Short curved speed ribbons follow the actual punch, with a bright core.
			for streak in 3:
				var point := hand+side*(streak-1)*size_value*.4
				var tail := point-forward*(.8+size_value)+side*handedness*.3
				_line(tail,point,.025*fade,pearl)
				_line(tail-forward*.35,tail,.045*fade,edge)
			var flash_age := age-1.
			if hit and flash_age>=0:
				var flare := 1-clampf(flash_age/(4. if finishing else 1.65),0,1)
				var extent := (2.1 if finishing else .75)*target_size
				var flare_point := contact+forward*.25
				_source_sprite(flare_point,extent*2,"1",clampf(flash_age/3,0,1),flare*.9,facing)
				for ray in (10 if finishing else 5):
					var a: float=ray*TAU/(10 if finishing else 5)+index*.7
					var direction := side*cos(a)+Vector3.UP*sin(a)
					_line(flare_point+direction*extent*.35,flare_point+direction*extent*(1+flash_age*.4),.045*flare,pearl)
				if finishing:
					for wave in 2:
						var spread := maxf(0,flash_age-wave*.6)
						_piece(ring,edge,target_ground+Vector3.UP*(.06+wave*.06),Vector3.ONE*(.6+spread*.9)*flare)
