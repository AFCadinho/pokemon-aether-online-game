extends "res://scripts/battle/battle_ui/source_move_effect_3d.gd"
## First-pass move choreography. Source masks are from SV; motion is authored here.
## Damage, persistent conditions, healing and field state remain event-owned.
const Recipes = preload("res://scripts/battle/battle_ui/move_recipe_3d.gd")
const Art = preload("res://scripts/battle/battle_ui/move_recipe_sources_3d.gd")
var recipe: Dictionary
var art: Array
var ring := TorusMesh.new()
var box := BoxMesh.new()
var prism := PrismMesh.new()
var launched := false
var origin := Vector3.ZERO
var aim := Vector3.ZERO
var surface: ShaderMaterial
var impact_drawn := false

func _sprite_values(id: String) -> Array:
	var binding: Dictionary = art[mini(int(id),art.size()-1)]
	var color := Color(str(recipe.color))
	return [Art.TEXTURES[binding.path],Vector3(color.r,color.g,color.b),float(binding.frames),bool(binding.source_alpha)]

func _prepare() -> void:
	recipe = Recipes.get_recipe(key)
	art = Art.MANIFEST.data.moves[key].textures
	ring.inner_radius = 0.90
	ring.outer_radius = 1.0
	ring.rings = 24
	ring.ring_segments = 6
	box.size = Vector3.ONE
	prism.size = Vector3.ONE
	# Source texture also shades solid objects/streams, so they have volume
	# from every camera angle instead of being enlarged 2D move sheets.
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_never;
uniform sampler2D mask : repeat_enable, filter_linear;
uniform vec4 tint : source_color;
uniform float seconds;
uniform float opacity = 1.0;
void fragment() {
	float n = texture(mask, UV * vec2(2., 1.) + vec2(seconds * .3, seconds * -.65)).r;
	float rim = pow(1. - max(dot(normalize(NORMAL), normalize(VIEW)), 0.), 2.);
	ALBEDO = mix(tint.rgb * .45, tint.rgb, n * .65 + rim * .35) + vec3(.16) * n;
	ALPHA = opacity;
}
"""
	surface = ShaderMaterial.new()
	surface.shader = shader
	surface.set_shader_parameter("mask",Art.TEXTURES[art[0].path])
	surface.set_shader_parameter("tint",Color(str(recipe.color)))

func _draw_source_move(from: Vector3, to: Vector3, right: Vector3, up: Vector3) -> bool:
	if recipe.is_empty(): _prepare()
	var points: Dictionary = anchors.call()
	var center: Vector3 = points.get("actor_center",from)
	var ground: Vector3 = points.get("target_ground",Vector3(to.x,0.04,to.z))
	var body := clampf(float(points.get("actor_radius",0.6)),0.45,1.4)
	var facing := Basis(right,up,right.cross(up))
	var t := elapsed/duration
	var travel := (elapsed-launch)/maxf(impact-launch,0.01)
	var after := (elapsed-impact)/maxf(duration-impact,0.01)
	var envelope := clampf(minf(t/0.12,(1-t)/0.22),0,1)
	var variant := str(recipe.variant)
	var family := str(recipe.family)
	if not launched and elapsed>=launch:
		origin = from
		aim = to
		launched = true
	var start := origin if launched and not bool(recipe.contact) else from
	var target := aim if launched else to
	var forward := (target-start).normalized()
	if forward.length()<0.01: forward = Vector3.FORWARD
	var side := forward.cross(Vector3.UP if absf(forward.y)<0.95 else Vector3.RIGHT).normalized()
	var path_basis := Basis(side,forward,side.cross(forward))
	surface.set_shader_parameter("seconds",elapsed)
	surface.set_shader_parameter("opacity",envelope*0.92)
	edge.albedo_color.a = envelope*0.8
	core.albedo_color.a = envelope*0.92
	glow.albedo_color.a = envelope*0.16
	impact_drawn = false
	if family=="z" and elapsed<impact:
		_charge(center,body,clampf(t/0.3,0,1),envelope,facing)
	if bool(recipe.contact):
		_contact(from,target,center,body,travel,after,envelope,variant,facing,side,path_basis)
	elif family=="beams" or family=="z" and variant in ["beam","electric"]:
		_beam(target,travel,after,envelope,variant,facing)
	elif family=="self" or recipe.target=="actor" and family!="area":
		_self_cast(center,points.get("actor_ground",center-Vector3.UP*0.7),body,t,envelope,variant,facing)
	elif family=="field":
		_field_cast(target,ground,t,envelope,variant,facing)
	elif family=="status" or family=="z" and variant=="web":
		_status_cast(start,target,travel,envelope,variant,facing,side)
	elif family=="area" or variant in ["storm","snow","rain","quakes","burst","flames"] and family=="z":
		_area(target,ground,t,travel,after,envelope,variant,facing)
	elif family=="waves" or variant in ["sound","pulse","drain"]:
		_wave(start,target,travel,after,envelope,variant,facing,path_basis)
	else:
		_projectile(start,target,travel,envelope,variant,facing,side,path_basis)
	# Cast animations never claim a status/HP change. Only ordered confirmed
	# damage outcomes receive this impact burst; miss and block get no hit art.
	if hit and bool(recipe.damaging) and after>=0 and after<0.75:
		impact_drawn = true
		var p := after/0.75
		_source_sprite(target,1.65+0.55*p,"1",p,(1-p)*0.85,facing)
		for i in 6:
			var a := TAU*i/6.0
			var offset := (side*cos(a)+Vector3.UP*sin(a))*p*1.1
			_line(target+offset*0.35,target+offset,0.025*(1-p),core)
	return true

func _charge(center: Vector3, radius: float, phase: float, alpha: float, facing: Basis) -> void:
	for i in 3:
		var a := elapsed*3+i*TAU/3
		var point := center+Vector3(cos(a),sin(a*1.5)*0.5,sin(a))*radius*(1.5-phase*0.4)
		_source_sprite(point,0.48,"0",fmod(phase+i*.25,1),alpha*0.65,facing)
	_piece(ring,edge,center-Vector3.UP*0.45,Vector3.ONE*radius*(0.8+phase*0.25))

func _contact(from: Vector3,to: Vector3,center: Vector3,body: float,travel: float,after: float,alpha: float,variant: String,facing: Basis,side: Vector3,path_basis: Basis) -> void:
	if travel<0: return
	if after<0.15:
		for i in 4:
			var offset := side*(i-1.5)*0.17+Vector3.UP*sin(i*2.2)*body*0.4
			_line(from+offset-(to-from).normalized()*0.75,from+offset,0.025*alpha,edge)
	if variant=="spin":
		for i in 2: _piece(ring,edge,center+Vector3.UP*(i-.5)*.3,Vector3.ONE*body*(1.1+i*.15),Basis(Vector3.FORWARD,.25*sin(elapsed*15)))
	if not (hit or miss) or travel<0.86 or after>0.5: return
	var swipe := clampf((travel-.86)/.32,0,1)
	var fade := 1.0-clampf(after*2,0,1)
	match variant:
		"slash", "whip":
			for i in (2 if variant=="whip" else 3):
				var base := to+side*(i-1)*.2
				_line(base+Vector3.UP*.5-side*.3,base+Vector3.DOWN*.5*swipe+side*.3*swipe,.025*fade,core)
		"bite":
			for i in 6:
				var offset := side*(i%3-1)*.24+Vector3.UP*(1 if i<3 else -1)*(.55-swipe*.36)
				_piece(tooth,core,to+offset,Vector3(.11,.22,.11),Basis(Vector3.FORWARD,PI if i<3 else 0))
		"kick", "punch", "flurry", "drain":
			for i in (3 if variant=="flurry" else 2 if key=="doublekick" else 1):
				var offset := side*(i-1)*.2+Vector3.UP*sin(i*3)*.3
				_piece(box,edge,to+offset,Vector3(.22,.15,.42 if variant=="kick" else .23)*fade,facing*Basis(Vector3.FORWARD,swipe*1.1))
				_source_sprite(to+offset,.95,"0",swipe,fade*.65,facing)
		_:
			_piece(ring,edge,to,Vector3.ONE*(.25+swipe*.45)*fade,path_basis)

func _beam(to: Vector3,travel: float,after: float,alpha: float,variant: String,facing: Basis) -> void:
	for source: Vector3 in emission_sources:
		if travel<0:
			_source_sprite(source,.6*clampf(elapsed/maxf(launch,.01),0,1),"0",0,alpha,facing)
		elif after<.45:
			var end := source.lerp(to,clampf(travel,0,1))
			var width := (.16 if key in ["hyperbeam","solarbeam"] else .11)*(1-clampf(after/.45,0,1))
			_line(source,end,width,surface)
			_line(source,end,width*.3,core)
			for i in 4:
				var p := fmod(elapsed*3+i*.25,1)*clampf(travel,0,1)
				_source_sprite(source.lerp(end,p),.45,"0",p,alpha*.55,facing,elapsed*2+i)
			if variant=="electric":
				for i in 6:
					var a := source.lerp(end,i/6.0)
					var b := source.lerp(end,(i+1)/6.0)+Vector3.UP*sin(elapsed*45+i*3)*.12
					_line(a,b,.028,edge)

func _projectile(from: Vector3,to: Vector3,travel: float,alpha: float,variant: String,facing: Basis,side: Vector3,path_basis: Basis) -> void:
	if travel<0:
		_source_sprite(from,.5*clampf(elapsed/maxf(launch,.01),0,1),"0",0,alpha*.5,facing)
		return
	if travel>=1.05: return
	var count := 5 if variant in ["leaves","shards","hearts"] else 3 if variant in ["electric","web"] else 1
	for i in count:
		var p := clampf(travel-i*.015,0,1)
		var point := from.lerp(to,p)+side*sin(p*PI)*(i-(count-1)*.5)*.35
		if variant=="arc":point.y+=sin(p*PI)*1.1
		if variant=="leaves":
			_piece(prism,surface,point,Vector3(.16,.35,.05),facing*Basis(Vector3.FORWARD,elapsed*8+i))
		elif variant=="shards":
			_piece(prism,surface,point,Vector3(.15,.34,.2),path_basis*Basis(Vector3.UP,elapsed*6+i))
		elif variant=="hearts":
			_heart(point,.22,facing,edge)
		else:
			_piece(sphere,surface,point,Vector3.ONE*(.28 if count==1 else .13))
		_source_sprite(point,.70 if count==1 else .38,"0",fmod(elapsed*2,1),alpha*.55,facing,elapsed+i)
		for j in 3:
			var q := maxf(p-(j+1)*.04,0)
			var tail := from.lerp(to,q)+side*sin(q*PI)*(i-(count-1)*.5)*.35
			if variant=="arc": tail.y+=sin(q*PI)*1.1
			_source_sprite(tail,.28-j*.05,"0",j/3.0,alpha*.42,facing)

func _wave(from: Vector3,to: Vector3,travel: float,after: float,alpha: float,variant: String,facing: Basis,path_basis: Basis) -> void:
	if travel<0: return
	for i in 4:
		var p := travel-i*.1
		if p<0 or p>1:continue
		var point := from.lerp(to,p)
		_piece(ring,edge,point,Vector3.ONE*(.2+p*.6),path_basis)
		if variant=="pulse":_source_sprite(point,.9,"0",p,alpha*.6,facing)
	# Drain return is only a visual consequence of a confirmed hit.
	if variant=="drain" and hit and after>=0:
		for i in 5:
			var p := clampf(after*1.5-i*.07,0,1)
			_source_sprite(to.lerp(from,p)+Vector3.UP*sin(p*PI)*.35,.25,"0",p,(1-p)*alpha,facing)

func _status_cast(from: Vector3,to: Vector3,travel: float,alpha: float,variant: String,facing: Basis,side: Vector3) -> void:
	if travel<0 or travel>1.18:return
	var p := clampf(travel,0,1)
	if variant=="hearts":
		for i in 3: _heart(from.lerp(to,p)+side*(i-1)*sin(p*PI)*.5+Vector3.UP*sin(p*PI)*.3,.17, facing,edge)
	elif variant=="web":
		var center := from.lerp(to,p)
		for i in 6:
			var a := TAU*i/6
			_line(center,center+(side*cos(a)+Vector3.UP*sin(a))*.55*p,.015*alpha,core)
	elif variant=="electric":
		for i in 8:
			var a := from.lerp(to,p*i/8.0)+Vector3.UP*sin(i*4+elapsed*25)*.12
			var b := from.lerp(to,p*(i+1)/8.0)+Vector3.UP*sin((i+1)*4+elapsed*25)*.12
			_line(a,b,.025*alpha,edge)
	elif variant in ["eye","debuff"]:
		for i in 3:
			var point := from.lerp(to,p)+side*(i-1)*.3
			_source_sprite(point,.65,"0",p,alpha*.6,facing)
	else:
		for i in 9:
			var q := clampf(travel-i*.025,0,1)
			var offset := side*sin(i*2.4)*.5+Vector3.UP*cos(i*2.4)*.35
			var point := from.lerp(to,q)+offset*sin(q*PI)
			if variant=="arc":point.y+=sin(q*PI)*.5
			_source_sprite(point,.32 if variant=="powder" else .43,"0",fmod(elapsed+i*.15,1),alpha*.6,facing,i)

func _heart(point: Vector3,size_value: float,facing: Basis,mat: Material) -> void:
	_ball(point+facing.x*size_value*.38,size_value*.5,mat)
	_ball(point-facing.x*size_value*.38,size_value*.5,mat)
	_piece(prism,mat,point-facing.y*size_value*.35,Vector3(size_value*1.35,size_value*1.2,size_value*.5),facing*Basis(Vector3.FORWARD,PI))

func _self_cast(center: Vector3,ground: Vector3,body: float,t: float,alpha: float,variant: String,facing: Basis) -> void:
	match variant:
		"swords":
			for i in 3:
				var a := TAU*i/3+elapsed*2.5
				var p := center+Vector3(cos(a),sin(t*PI)*.55,sin(a))*body*1.1
				_piece(prism,core,p,Vector3(.12,.75,.07),Basis(Vector3.FORWARD,-.15))
				_line(p-Vector3.UP*.3-Vector3.RIGHT*.18,p-Vector3.UP*.3+Vector3.RIGHT*.18,.04,edge)
		"shield":
			_piece(sphere,glow,center,Vector3.ONE*body*1.2)
			for i in 2:_piece(ring,edge,center+Vector3.UP*(i-.5)*.35,Vector3.ONE*body*(1.0+i*.12),Basis(Vector3.FORWARD,t*.7))
		"heal":
			for i in 6:
				var a := i*TAU/6
				var p := center+Vector3(cos(a)*body,(t-.5)*1.1,sin(a)*body)
				_line(p-facing.y*.1,p+facing.y*.1,.035*alpha,core)
				_line(p-facing.x*.1,p+facing.x*.1,.035*alpha,core)
		"portal":
			for i in 3:_piece(ring,edge,center+Vector3.UP*(i-1)*.35,Vector3.ONE*body*(.8+.2*sin(t*TAU+i)))
		"spin":
			for i in 4:
				var a := elapsed*8+i*TAU/4
				_source_sprite(center+Vector3(cos(a),.1,sin(a))*body,.65,"0",t,alpha*.65,facing,a)
		"terrain", "mist", "snow":_field_cast(center,ground,t,alpha,variant,facing)
		_:
			_charge(center,body,t,alpha,facing)
			for i in 5:
				var a := TAU*i/5
				_source_sprite(center+Vector3(cos(a)*body,(t-.5)*1.2,sin(a)*body),.5,"0",t,alpha*.6,facing)

func _field_cast(target: Vector3,ground: Vector3,t: float,alpha: float,variant: String,facing: Basis) -> void:
	var size_value := 1.0+1.2*t
	match variant:
		"spikes":
			for i in 7:
				var a := TAU*i/7
				var p := ground+Vector3(cos(a),0,sin(a))*(.6+i%2*.55)+Vector3.UP*(1-t)*1.3
				_piece(prism,surface,p,Vector3(.18,.4,.18),Basis(Vector3.UP,a))
		"web":
			for i in 8:
				var a := TAU*i/8
				_line(ground,ground+Vector3(cos(a),0,sin(a))*size_value,.014*alpha,core)
			for i in 3:_piece(ring,edge,ground,Vector3.ONE*size_value*(i+1)/3.0)
		"eye":
			_piece(ring,edge,target,Vector3(size_value*.45,.1,size_value*.22),Basis(Vector3.RIGHT,PI/2))
			_source_sprite(target,.6,"0",t,alpha*.7,facing)
		"mist", "snow":
			for i in 10:
				var a := i*2.4
				_source_sprite(ground+Vector3(cos(a)*size_value,.2+sin(i)*.15,sin(a)*size_value),.85,"0",fmod(t+i*.13,1),alpha*.35,facing)
		_:
			for i in 3:_piece(ring,edge,ground+Vector3.UP*.03*i,Vector3.ONE*size_value*(i+1)/3.0)
			for i in 6:
				var a := TAU*i/6
				_source_sprite(ground+Vector3(cos(a)*size_value,t*.7,sin(a)*size_value),.45,"0",t,alpha*.5,facing)

func _area(target: Vector3,ground: Vector3,t: float,travel: float,after: float,alpha: float,variant: String,facing: Basis) -> void:
	if travel<0:return
	match variant:
		"quakes":
			for i in 3:
				var p := clampf(travel-i*.12,0,1)
				_piece(ring,edge,ground+Vector3.UP*i*.025,Vector3.ONE*(.3+p*1.8))
			for i in 8:
				var a := TAU*i/8
				var p := ground+Vector3(cos(a),maxf(0,sin(t*PI))*0.4,sin(a))*(.75+i%2*.5)
				_piece(prism,surface,p,Vector3(.2,.45,.2),Basis(Vector3.UP,a))
		"storm":
			for i in 12:
				var h := float(i)/12
				var a := elapsed*8+i*2.4
				var p := ground+Vector3(cos(a)*(.4+h*.65),h*2.2,sin(a)*(.4+h*.65))
				_source_sprite(p,.8,"0",fmod(t+i*.1,1),alpha*.6,facing,a)
			for i in 3:_piece(ring,glow,ground+Vector3.UP*(i*.55+.2),Vector3.ONE*(.45+i*.25),Basis(Vector3.FORWARD,.1))
		"rain", "snow":
			for i in 12:
				var p := clampf(travel-i*.025,0,1)
				var a := i*2.4
				var destination := ground+Vector3(cos(a),.2,sin(a))*(.35+i%3*.4)
				var point := destination+Vector3(.5,3.0,0)*(1-p)
				if key=="makeitrain":
					_piece(tube,edge,point,Vector3(.11,.025,.11),facing*Basis(Vector3.RIGHT,PI/2+elapsed*4))
				elif variant=="rain":
					_piece(prism,surface,point,Vector3(.22,.3,.22),Basis(Vector3.FORWARD,elapsed*3+i))
				else:
					_piece(prism,surface,point,Vector3(.08,.25,.08),Basis(Vector3.FORWARD,.3))
				_source_sprite(point,.4,"0",t,alpha*.4,facing)
		"flames":
			for i in 8:
				var a := i*TAU/8
				_source_sprite(ground+Vector3(cos(a)*.8,travel*.7,sin(a)*.8),1.1,"0",fmod(t+i*.12,1),alpha*.75,facing)
		_:
			var p := clampf(travel,0,1)
			_piece(sphere,glow,target,Vector3.ONE*(.15+p*1.15))
			for i in 3:_piece(ring,edge,target,Vector3.ONE*(.2+p*.9),Basis(Vector3.RIGHT,i*PI/3)*Basis(Vector3.FORWARD,elapsed))
			_source_sprite(target,1.4,"0",clampf(after,0,1),alpha*.6,facing)
