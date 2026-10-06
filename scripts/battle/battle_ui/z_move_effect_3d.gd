extends "res://scripts/battle/battle_ui/family_move_effect_3d.gd"
## Authored 3D interpretations of the existing 2D Z-move storyboards.
## Per-move source frames and hashes live beside each choreography in the recipe.
const Z_ART := {
	"fire": [preload("res://assets/battles/moves_3d/sv_source/cpt_2_fire0010.png"),4.0,false],
	"water": [preload("res://assets/battles/moves_3d/sv_source/cpt_2_water0013.png"),8.0,true],
	"spark": [preload("res://assets/battles/moves_3d/sv_moonblast/cpt_0_flash0001.png"),1.0,false],
	"smoke": [preload("res://assets/battles/moves_3d/sv_shadowball/upt_ew0247_smoke2301.png"),1.0,false],
}
var style := ""
var dark: StandardMaterial3D
var accent: StandardMaterial3D
var pale: StandardMaterial3D
var wing: ArrayMesh
var star: ArrayMesh
var fixed_ground := Vector3.ZERO
var fixed_source := Vector3.ZERO
var fixed_center := Vector3.ZERO
var fixed_actor_ground := Vector3.ZERO
var captured := false
var body_size := 1.0
var tone_materials: Array[StandardMaterial3D] = []

func _sprite_values(id: String) -> Array:
	if not Z_ART.has(id): return super._sprite_values(id)
	var color := Color(str(recipe.color))
	var values: Array = Z_ART[id]
	return [values[0],Vector3(color.r,color.g,color.b),values[1],values[2]]

func _prepare() -> void:
	super._prepare()
	tooth.radial_segments = 24
	style = str(recipe.z_choreography.style)
	ring.inner_radius = 0.965
	dark = _material(Color("150e29"),0.9)
	accent = _material(Color(str(recipe.color)).lerp(Color.WHITE,0.25),0.65)
	pale = _material(Color("ffdf86"),0.8)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in [Vector3(0,0,0),Vector3(1,.6,.2),Vector3(.75,-.15,.45)]: tool.add_vertex(p)
	wing = tool.commit()
	tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		tool.add_vertex(Vector3.ZERO)
		for j in [i,i+1]:
			var a: float = j*TAU/10.0+PI/2
			tool.add_vertex(Vector3(cos(a),sin(a),0)*(1.0 if j%2==0 else .32))
	star = tool.commit()
	for color in ["ff9a43","71cfff","ffee59","c5a2f1","ffd0ea","8fde6c","a8efff","ba84f0"]:
		tone_materials.append(_material(Color(color),.8))

func _draw_source_move(from: Vector3,to: Vector3,right: Vector3,up: Vector3) -> bool:
	if recipe.is_empty(): _prepare()
	var points: Dictionary = anchors.call()
	if not captured:
		captured = true
		fixed_source = from
		aim = to
		fixed_center = points.get("actor_center",from)
		fixed_ground = points.get("target_ground",Vector3(to.x,0.04,to.z))
		fixed_actor_ground = points.get("actor_ground",Vector3(from.x,0.04,from.z))
		body_size = clampf(float(points.radius),.55,1.35)
	var facing := Basis(right,up,right.cross(up))
	var forward := (aim-fixed_source).normalized()
	if forward.length()<.01:forward=Vector3.FORWARD
	var side := forward.cross(Vector3.UP if absf(forward.y)<.95 else Vector3.RIGHT).normalized()
	var axis := Basis(side,forward,side.cross(forward))
	var t := elapsed/duration
	var charge := clampf(elapsed/maxf(launch,.01),0,1)
	var flight := clampf((elapsed-launch)/maxf(impact-launch,.01),0,1)
	var after := (elapsed-impact)/maxf(duration-impact,.01)
	var fade := 1-clampf(after,0,1)
	var envelope := clampf(minf(t/.07,(1-t)/.18),0,1)
	edge.albedo_color.a = .85*envelope
	core.albedo_color.a = .95*envelope
	glow.albedo_color.a = .10*envelope
	accent.albedo_color.a = .65*envelope
	pale.albedo_color.a = .8*envelope
	dark.albedo_color.a = .85*envelope
	surface.set_shader_parameter("seconds",elapsed)
	surface.set_shader_parameter("opacity",envelope*.7)
	impact_drawn = false
	# Small inward streaks establish energy; each move supplies its own main form.
	if elapsed<launch:
		for i in 6:
			var a := i*TAU/6+elapsed
			var offset := Vector3(cos(a),sin(a*2)*.5,sin(a))*(1.8-charge*.9)
			_line(fixed_center+offset,fixed_center+offset*.78,.025*charge,edge)
	match style:
		"barrage", "guardian_fist", "seven_stars": _strikes(flight,after,envelope,facing,side,axis)
		"black_hole", "dna_nova", "sun_nova", "ocean_orb", "fire_orb": _orb_scene(charge,flight,after,envelope,facing,axis)
		"water_vortex", "acid_column", "sun_column", "moon_column": _column(flight,after,envelope,facing)
		"lightning", "rainbow_lightning", "electric_surf": _lightning_scene(from,charge,flight,after,facing,side)
		"bloom_pillar": _bloom(charge,flight,after,envelope,facing)
		"boulder", "stone_rain", "arrow_rain": _falling(flight,after,envelope,facing,axis)
		"drill": _drill_scene(from,flight,after,envelope,axis)
		"dragon": _dragon_scene(charge,flight,after,envelope,facing,side,axis)
		"chains", "cocoon", "shadow_shroud", "prism", "ice_prison": _enclosure(flight,after,envelope,facing)
		"sound_rings": _sound_scene(flight,after,envelope,axis)
		"evolution": _evolution_scene(charge,flight,after,envelope,facing)
		"fissure": _fissure_scene(flight,after,envelope,facing,side)
		_: _body_scene(from,points.get("actor_center",from),charge,flight,after,envelope,facing,side,axis)
	# One final gameplay beat; the preceding barrage/spiral is only choreography.
	if hit and bool(recipe.damaging) and after>=0:
		impact_drawn = true
		_climax(aim,fixed_ground,after,facing,side)
	return true

func _bolt(a: Vector3,b: Vector3,width: float,seed_value: float,mat: Material) -> void:
	var last := a
	for j in 7:
		var p := (j+1)/7.0
		var offset := Vector3(sin(j*7+seed_value),cos(j*4+seed_value),sin(j*2+seed_value))*.19*sin(p*PI)
		var point := a.lerp(b,p)+offset
		_line(last,point,width,mat)
		last=point

func _fist(point: Vector3,size_value: float,basis_value: Basis,mat: Material) -> void:
	_piece(box,mat,point,Vector3(.65,.48,.5)*size_value,basis_value)
	for j in 4:
		_ball(point+basis_value.x*(j-1.5)*.16*size_value+basis_value.y*.24*size_value,.12*size_value,mat)
	_ball(point-basis_value.x*.36*size_value-basis_value.y*.08*size_value,.17*size_value,mat)

func _strikes(flight: float,after: float,alpha: float,facing: Basis,side: Vector3,axis: Basis) -> void:
	if style=="guardian_fist":
		var p := fixed_source.lerp(aim,flight)+Vector3.UP*sin(flight*PI)*1.5
		if after<0:_fist(p,.3+flight*2.3,axis,pale)
		for i in 6:
			var a := i*TAU/6
			var fragment := p+Vector3(cos(a),sin(a),cos(a*2))*(1.6-flight)*.9
			_piece(prism,edge,fragment,Vector3.ONE*.2*alpha,Basis(Vector3.UP,elapsed+i))
	elif style=="seven_stars":
		for i in 7:
			var a := TAU*i/7
			var p := aim+(facing.x*cos(a)+facing.y*sin(a))*1.4
			var b := TAU*((i+2)%7)/7
			if elapsed>=launch:
				_piece(star,core,p,Vector3.ONE*.18*alpha,facing*Basis(Vector3.FORWARD,elapsed))
				_line(p,aim+(facing.x*cos(b)+facing.y*sin(b))*1.4,.025*alpha,edge)
		if flight>.65 and after<.15:_fist(aim+side*(1-flight),1.4*alpha,axis,dark)
	else:
		if elapsed<launch or after>.25:return
		for i in 6:
			var beat := fmod(flight*3+i/6.0,1)
			var offset := facing.x*sin(i*2.4)*.8+facing.y*cos(i*2.4)*.7
			var p := aim+offset-(aim-fixed_source).normalized()*(1-beat)*1.25
			_fist(p,.50*alpha,axis,edge if i%2==0 else core)
			_line(p-(aim-fixed_source).normalized()*.6,p,.03*alpha,edge)
		if after>=0:_fist(aim,1.2*(1-after),axis,pale)

func _orb_scene(charge: float,flight: float,after: float,alpha: float,facing: Basis,axis: Basis) -> void:
	var center := fixed_source
	var radius := .3+charge*.5
	match style:
		"black_hole":
			center = fixed_source.lerp(aim,smoothstep(0,.55,flight))
			radius = .2+sin(clampf(flight,0,1)*PI*.7)*1.6
			if after>=0:radius=maxf(.03,1.45*(1-clampf(after/.35,0,1)))
			_piece(sphere,dark,center,Vector3.ONE*radius)
			for i in 3:_piece(ring,edge,center,Vector3.ONE*radius*(1.15+i*.12),axis*Basis(Vector3.RIGHT,.4*i+elapsed*.6))
			for i in 8:
				var a := i*TAU/8+elapsed*3
				_source_sprite(center+Vector3(cos(a),sin(a),sin(a*2)*.3)*radius*1.5,.45,"smoke",flight,alpha*.45,facing,a)
		"dna_nova":
			center=fixed_source.lerp(aim,smoothstep(.3,1,flight))
			radius=(.3+flight*1.3)*(1-clampf(after,0,1))
			if flight<.7:
				for i in 10:
					var a := i*.7+elapsed*2
					var base := fixed_source+Vector3.UP*(i-4.5)*.25
					var offset := facing.x*cos(a)*.6+facing.z*sin(a)*.6
					_ball(base+offset,.07,core);_ball(base-offset,.07,core)
					_line(base+offset,base-offset,.016,edge)
			_piece(sphere,surface,center,Vector3.ONE*radius)
			_source_sprite(center,radius*2.6,"spark",0,alpha*.5,facing)
		"sun_nova":
			center=fixed_source.lerp(aim,smoothstep(.65,1,flight))+Vector3.UP*(1.5+sin(flight*PI)*.6)
			radius=(.18+charge*.5+flight*1.4)*(1-clampf(after,0,1))
			_piece(sphere,surface,center,Vector3.ONE*radius)
			for i in 3:_piece(ring,pale,center,Vector3.ONE*radius*(1.12+i*.13),Basis(Vector3.RIGHT,i*PI/3)*Basis(Vector3.FORWARD,elapsed*.8))
			for i in 7:
				var a := i*TAU/7+elapsed
				_source_sprite(center+(facing.x*cos(a)+facing.y*sin(a))*radius,1.1,"fire",fmod(elapsed+i*.1,1),alpha*.8,facing,a)
		"ocean_orb":
			center=fixed_source.lerp(aim,flight)+Vector3.UP*sin(flight*PI)*1.8
			radius=(.35+flight*1.35)*(1-clampf(after,0,1))
			_piece(sphere,surface,center,Vector3.ONE*radius)
			for i in 4:
				var a := i*TAU/4+elapsed
				var p := center+Vector3(cos(a),sin(a*.5),sin(a))*(radius+.4)
				_ball(p,.10*alpha,pale);_line(p,p+Vector3.UP*.35,.025*alpha,pale)
				_line(p+Vector3.UP*.35,p+Vector3.UP*.27+facing.x*.16,.024*alpha,pale)
			_source_sprite(center,radius*2,"water",flight,alpha*.6,facing)
		_:
			center=fixed_source.lerp(aim,flight)+Vector3.UP*sin(flight*PI)*.5
			radius=(.35+charge*.3+flight*.5)*(1-clampf(after,0,1))
			_piece(sphere,surface,center,Vector3.ONE*radius)
			for i in 7:_source_sprite(center-Vector3.UP*.2+(fixed_source-aim).normalized()*i*.18,1.0-i*.08,"fire",fmod(elapsed+i*.1,1),alpha*.85,facing,i)

func _column(flight: float,after: float,alpha: float,facing: Basis) -> void:
	if elapsed<launch:return
	var height_value := (1.0+flight*3.3)*(1-clampf(after,0,1)*.6)
	var water := style=="water_vortex"
	var acid := style=="acid_column"
	if water or acid:
		for i in 18:
			var h := i/18.0
			var a := h*TAU*2+elapsed*5
			var radius := (.5+h*.65)*(1-clampf(after,0,1)*.5)
			var p := fixed_ground+Vector3(cos(a)*radius,h*height_value,sin(a)*radius)
			_source_sprite(p,1.0 if water else .85,"water" if water else "smoke",fmod(h+elapsed*.6,1),alpha*.65,facing,a)
			if i%3==0:_piece(ring,edge,fixed_ground+Vector3.UP*h*height_value,Vector3.ONE*radius)
	else:
		var top := aim+Vector3.UP*4
		var bottom := top.lerp(fixed_ground,clampf(flight*1.4,0,1))
		_line(top,bottom,.35+flight*.35,glow)
		_line(top,bottom,.14+flight*.14,core)
		for i in 6:
			var p := top.lerp(bottom,i/6.0)
			_piece(ring,edge,p,Vector3.ONE*(.7+flight*.3),Basis(Vector3.UP,elapsed))
			_source_sprite(p,.95,"fire" if style=="sun_column" else "spark",fmod(elapsed+i*.13,1),alpha*.6,facing,elapsed)

func _lightning_scene(from: Vector3,charge: float,flight: float,after: float,facing: Basis,side: Vector3) -> void:
	var alpha := 1-clampf(after,0,1)
	if elapsed<launch:
		for i in 3:
			var a := i*TAU/3
			_bolt(from+Vector3(cos(a),sin(a),0)*.9,from,.023*charge,elapsed*20+i,edge)
	else:
		var count := 5 if style=="rainbow_lightning" else 3
		for i in count:
			var offset := side*(i-(count-1)*.5)*.5
			var top := aim+offset+Vector3.UP*(3.2+sin(i)*.6)
			var bottom := top.lerp(aim+offset*.3,clampf(flight*1.7-i*.10,0,1))
			_bolt(top,bottom,.05*alpha,elapsed*35+i*7,tone_materials[i] if style=="rainbow_lightning" else edge)
			_source_sprite(bottom,.9,"spark",0,alpha*.75,facing,elapsed+i)
		if style=="electric_surf":
			for i in 5:
				var p := fixed_source.lerp(aim,i/5.0)
				_bolt(p-side*.35,p+side*.35,.028*alpha,i+elapsed*30,edge)

func _bloom(charge: float,flight: float,after: float,alpha: float,facing: Basis) -> void:
	# The 2D light pillar and flying leaves become a 3D patch around the target.
	for i in 9:
		var a := i*2.4
		var p := fixed_ground+Vector3(cos(a),0,sin(a))*(.7+i%3*.55)
		var height_value := (.3+flight*.7)*charge
		_line(p,p+Vector3.UP*height_value,.025*alpha,edge)
		_piece(prism,edge,p+Vector3.UP*height_value*.7,Vector3(.18,.4,.07)*alpha,Basis(Vector3.FORWARD,a))
		if flight>.25:_piece(star,pale,p+Vector3.UP*height_value,Vector3.ONE*.18*alpha,facing*Basis(Vector3.FORWARD,a))
	if elapsed>=launch:
		_line(fixed_ground,fixed_ground+Vector3.UP*(1+flight*3),.32*alpha,glow)
		for i in 5:
			var a := elapsed*3+i*TAU/5
			var p := aim+Vector3(cos(a)*.9,flight*1.8,sin(a)*.9)
			_source_sprite(p,.55,"spark",0,alpha*.75,facing)

func _falling(flight: float,after: float,alpha: float,facing: Basis,axis: Basis) -> void:
	if elapsed<launch:return
	if style=="boulder":
		var center := aim+Vector3.UP*(3.5*(1-pow(flight,3)))
		for i in 7:
			var a := i*2.4
			var p := center+Vector3(cos(a),sin(a*2)*.6,sin(a))*.65
			_piece(prism,surface,p,Vector3(.9,1.2,.9)*alpha,Basis(Vector3.UP,a)*Basis(Vector3.FORWARD,a*.3))
	else:
		for i in 12:
			var a := i*2.4
			var q := clampf((flight-i*.016)/.82,0,1)
			var land := aim+Vector3(cos(a)*.9,sin(a*2)*.3,sin(a)*.9)
			var p := land+Vector3(1.1,3.5,0)*(1-q)
			if style=="arrow_rain":
				_line(p+Vector3(.18,.55,0),p,.028*alpha,dark)
				_piece(tooth,edge,p,Vector3(.09,.22,.09)*alpha,Basis(Vector3.FORWARD,PI-.25))
			else:_piece(prism,surface,p,Vector3(.24,.5,.24)*alpha,axis*Basis(Vector3.UP,elapsed+i))
			if after>=0:_source_sprite(land,.5,"spark",after,alpha*.4,facing)

func _drill_scene(from: Vector3,flight: float,after: float,alpha: float,axis: Basis) -> void:
	var center := from+(aim-from).normalized()*.65
	if not bool(recipe.contact):center=fixed_source.lerp(aim,flight)
	_piece(tooth,surface,center,Vector3(.65,1.8,.65)*alpha,axis)
	for i in 7:
		var p := center+axis.y*(i/7.0-.5)*1.8
		_piece(ring,core,p,Vector3.ONE*(.63-i*.075)*alpha,axis*Basis(Vector3.RIGHT,PI/2)*Basis(Vector3.UP,elapsed*10))
	if after>=0:
		for i in 8:
			var a := i*TAU/8
			_piece(prism,surface,fixed_ground+Vector3(cos(a),after*.7,sin(a))*(.5+after),Vector3(.18,.3,.18)*alpha,Basis(Vector3.UP,a))

func _dragon_scene(charge: float,flight: float,after: float,alpha: float,facing: Basis,side: Vector3,axis: Basis) -> void:
	var head := fixed_source.lerp(aim,flight)+Vector3.UP*sin(flight*PI)*1.1
	var scale_value := (.25+charge*.6)*alpha
	_piece(sphere,surface,head,Vector3(.35,.3,.6)*scale_value,axis)
	for i in 10:
		var q := maxf(0,flight-i*.027)
		var p := fixed_source.lerp(aim,q)+Vector3.UP*(sin(q*PI)*1.1+sin(elapsed*4-i*.65)*.2)+side*sin(elapsed*5-i*.6)*.25
		_piece(sphere,surface,p,Vector3.ONE*(.35-i*.023)*scale_value)
		if i%2==0:_source_sprite(p,.75,"fire",fmod(elapsed+i*.1,1),alpha*.65,facing,i)
	for sign_value in [-1.0,1.0]:
		_piece(wing,edge,head+side*.2*sign_value,Vector3(sign_value*1.6,1.2,.9)*scale_value,axis*Basis(Vector3.RIGHT,PI/2)*Basis(Vector3.UP,sin(elapsed*6)*.2))
	if after>=0:_source_sprite(aim,2.4,"fire",after,alpha*.8,facing)

func _enclosure(flight: float,after: float,alpha: float,facing: Basis) -> void:
	if elapsed<launch:return
	var extent := 1.25*(.3+.7*minf(flight*2,1))
	if after>=0:extent*=1+after*.65
	match style:
		"chains":
			_piece(ring,dark,fixed_ground,Vector3.ONE*1.4)
			for i in 5:
				var a := TAU*i/5+elapsed*.35
				for j in 5:
					var p := aim+Vector3(cos(a)*extent,(j-2)*.4,sin(a)*extent)
					_piece(ring,edge,p,Vector3(.12,.12,.20)*alpha,Basis(Vector3.RIGHT,PI/2)*Basis(Vector3.FORWARD,j%2*PI/2))
		"cocoon", "shadow_shroud":
			if style=="shadow_shroud":
				_piece(tooth,dark,aim+Vector3.UP*.3,Vector3(extent,2.0,extent)*alpha)
			else:
				_piece(sphere,glow,aim,Vector3(extent,extent*1.3,extent))
			for i in 10:
				var h := i/9.0
				_piece(ring,accent,aim+Vector3.UP*(h-.5)*2,Vector3.ONE*sin(h*PI)*extent, Basis(Vector3.FORWARD,.1*sin(elapsed*14+i)))
			if flight>.6:
				for i in 6:
					var a := i*TAU/6+elapsed*8
					_source_sprite(aim+(facing.x*cos(a)+facing.y*sin(a))*extent,.75,"spark",0,alpha*.8,facing,a)
		"prism", "ice_prison":
			var rot := Basis(Vector3.UP,elapsed*.5)*Basis(Vector3.FORWARD,.12)
			if style=="prism":
				_piece(box,glow,aim,Vector3.ONE*extent*1.8,rot)
				for y in [-1.0,1.0]:
					for j in 4:
						var a := PI/4+j*PI/2
						var b := a+PI/2
						var p := Vector3(cos(a),y*.7,sin(a))*extent
						_line(aim+rot*p,aim+rot*Vector3(cos(b),y*.7,sin(b))*extent,.026*alpha,edge)
						if y<0:_line(aim+rot*p,aim+rot*(p+Vector3.UP*1.4*extent),.026*alpha,edge)
			else:
				for i in 7:
					var a := TAU*i/7
					_piece(prism,surface,fixed_ground+Vector3(cos(a)*extent*.7,extent*.6,sin(a)*extent*.7),Vector3(.35,1.5,.35)*alpha,Basis(Vector3.FORWARD,sin(a)*.3))
			if after>=0:
				for i in 10:
					var a := i*2.4
					_piece(prism,core,aim+Vector3(cos(a),sin(a),sin(a*2))*after*2,Vector3(.13,.3,.1)*alpha,rot*Basis(Vector3.UP,a))

func _sound_scene(flight: float,after: float,alpha: float,axis: Basis) -> void:
	if elapsed<launch:return
	for i in 9:
		var q := fmod(flight*2+i/9.0,1)
		_piece(ring,edge,fixed_source.lerp(aim,q),Vector3.ONE*(.25+q*1.3)*alpha,axis*Basis(Vector3.RIGHT,PI/2))
	if after>=0:_piece(sphere,glow,aim,Vector3.ONE*(1+after*1.5))

func _evolution_scene(charge: float,flight: float,after: float,alpha: float,facing: Basis) -> void:
	for i in 8:
		var a := TAU*i/8+elapsed*.45
		var radius := (1.8-flight*1.1)*charge
		var p := fixed_center+Vector3(cos(a)*radius,sin(a*2)*.3+flight*.7,sin(a)*radius)
		_ball(p,.18*alpha,tone_materials[i])
		_piece(star,tone_materials[i],p,Vector3.ONE*.32*alpha,facing*Basis(Vector3.FORWARD,elapsed))
		if flight>.5:_line(p,fixed_center,.025*alpha,tone_materials[i])
	if after>=0:
		for i in 3:_piece(ring,pale,fixed_center+Vector3.UP*(i*.35+after),Vector3.ONE*(.5+after*.7)*alpha)

func _fissure_scene(flight: float,after: float,alpha: float,facing: Basis,side: Vector3) -> void:
	if elapsed<launch:return
	for i in 8:
		var p := fixed_actor_ground.lerp(fixed_ground,(i+1)/8.0)
		var q := p+side*sin(i*5)*.55
		_line(p-side*.25,q+side*.25,.09*alpha,dark)
		_line(p-side*.2+Vector3.UP*.03,q+side*.2+Vector3.UP*.03,.025*alpha,pale)
		if flight>i/10.0:
			_piece(prism,surface,p+side*.4,Vector3(.3,.2+flight*.7,.3)*alpha,Basis(Vector3.FORWARD,.2))
			_source_sprite(q+Vector3.UP*(flight*.8),.85,"smoke",flight,alpha*.5,facing,i)
	if flight>.55:
		_line(fixed_ground,fixed_ground+Vector3.UP*(flight-.55)*6,.5*alpha,glow)
		_source_sprite(aim,2.2,"fire",clampf(after,0,1),alpha*.6,facing)

func _body_scene(from: Vector3,center: Vector3,charge: float,flight: float,after: float,alpha: float,facing: Basis,side: Vector3,axis: Basis) -> void:
	var electric := style=="electric_dive"
	var fairy := style=="fairy_comet"
	var aerial := style in ["moonsault","sky_dive","body_slam"]
	if elapsed<launch:
		_source_sprite(from,.4+charge*.6,"spark",0,charge*.8,facing)
		return
	var point := center
	if aerial:point+=Vector3.UP*.2
	if electric:
		for i in 3:_bolt(point+side*(i-1)*.6,point+Vector3.UP*.7,.025*alpha,elapsed*20+i,edge)
	elif fairy:
		for i in 7:
			var a := i*TAU/7+elapsed*4
			_piece(star,tone_materials[i],point+(facing.x*cos(a)+facing.y*sin(a))*.75,Vector3.ONE*.16*alpha,facing*Basis(Vector3.FORWARD,a))
	for i in 6:
		var offset := side*sin(i*2.4)*.7+Vector3.UP*cos(i*2.4)*.45
		_line(point+offset-axis.y*(.5+flight),point+offset,.035*alpha,edge)
	if style=="moonsault" and after>=0:_source_sprite(aim,2.8,"fire",after,alpha*.85,facing)
	if style=="body_slam" and after>=0:
		for i in 2:_piece(ring,edge,fixed_ground,Vector3.ONE*(.7+after*(2+i*.5))*alpha)

func _climax(target: Vector3,ground: Vector3,after: float,facing: Basis,side: Vector3) -> void:
	var fade := 1-clampf(after,0,1)
	var flash := 1-smoothstep(0,.32,after)
	_source_sprite(target,2.6+after*2.2,"spark",0,flash*.8,facing)
	for i in 2:_piece(ring,edge,ground+Vector3.UP*.04*i,Vector3.ONE*(.45+after*(2.6+i*.5))*fade)
	for i in 8:
		var a := i*TAU/8
		var direction := side*cos(a)+Vector3.UP*sin(a)+facing.z*sin(a*3)*.25
		_line(target+direction*(.15+after*.8),target+direction*(.4+after*2.4),.026*fade,core)
		_source_sprite(target+direction*(.5+after*1.8),.35*fade,"spark",0,fade*.65,facing,a)
