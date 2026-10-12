extends "res://scripts/battle/battle_ui/elemental_move_effect_3d.gd"
## Separate choreography per move; inherit only native clock, anchors and reusable geometry.
const Profiles = preload("res://scripts/battle/battle_ui/elemental_batch_profiles_3d.gd")
const Volume = preload("res://scripts/battle/battle_ui/move_volume_forms_3d.gd")
const Wrath = preload("res://scripts/battle/battle_ui/fiery_wrath_forms_3d.gd")
var funnel: ArrayMesh
var flame: ArrayMesh
var helix: ArrayMesh
var dragon_neck: ArrayMesh
var leaf_mesh: ArrayMesh
var veil: ShaderMaterial
var wind: ShaderMaterial
var clock_seconds := 0.0

func _palette() -> Array:
	return [Color(Profiles.DATA[key].low),Color(Profiles.DATA[key].high)]

func _surface_kind() -> int:
	return int(Profiles.DATA[key].kind)

func _prepare() -> void:
	super._prepare()
	funnel = Volume.swept_mesh(true)
	flame = Wrath.new().flame
	var points: Array[Vector3] = []
	var radii: Array[float] = []
	for i in 49:
		var p := i/48.
		var a := p*TAU*1.75
		points.append(Vector3(cos(a),p*2.,sin(a))*(.55+p*.35))
		radii.append(.04+.08*sin(p*PI))
	helix = Forms.tube(points,radii)
	points.clear(); radii.clear()
	for i in 25:
		var p := i/24.
		points.append(Vector3(sin(p*TAU)*.18,-p*2.1,0))
		radii.append(.025+(1.-p)*.28)
	dragon_neck = Forms.tube(points,radii)
	leaf_mesh = _leaf_mesh()
	veil = surface.duplicate()
	var soft_shader := Shader.new()
	soft_shader.code = surface.shader.code.replace("cull_disabled, depth_prepass_alpha","cull_back, depth_draw_never").replace("ALPHA=opacity*density;","ALPHA=opacity*density*pow(1.-rim,1.3)*.32;")
	veil.shader = soft_shader
	wind = Volume.funnel_material()
	var wind_shader := Shader.new()
	wind_shader.code = wind.shader.code.replace("uniform float seconds", "uniform vec4 low_color : source_color;\nuniform vec4 high_color : source_color;\nuniform float seconds").replace("vec3(0.32, 0.44, 0.5), vec3(0.77, 0.91, 0.95)","low_color.rgb, high_color.rgb")
	wind.shader = wind_shader
	wind.set_shader_parameter("low_color",_palette()[0])
	wind.set_shader_parameter("high_color",_palette()[1])
	water_body.set_shader_parameter("high_color",_palette()[0].lerp(_palette()[1],.25))
	tooth.radial_segments = 24

func _draw_source_move(from: Vector3, to: Vector3, right: Vector3, up: Vector3) -> bool:
	super._draw_source_move(from,to,right,up)
	clock_seconds = elapsed/duration*float(recipe.duration_seconds)
	for mat in [veil,wind]:
		mat.set_shader_parameter("seconds",clock_seconds)
		mat.set_shader_parameter("opacity",alpha)
	if key == "psychic": veil.set_shader_parameter("opacity",alpha*2.)
	match key:
		"fireblast": _fire_blast()
		"heatwave": _heat_wave()
		"eruption": _eruption()
		"lavaplume": _lava_plume()
		"magmastorm": _magma_storm()
		"mysticalfire": _mystical_fire()
		"muddywater": _muddy_water()
		"sludgewave": _sludge_wave()
		"nightdaze": _night_daze()
		"dragonpulse": _dragon_pulse()
		"psychic": _psychic()
		"psyshock": _psyshock()
		"leafstorm": _leaf_storm()
		"sandsearstorm": _sandsear_storm()
		"bleakwindstorm": _bleakwind_storm()
	return true

func _impact() -> bool:
	impact_start_index = cursor
	impact_drawn = hit and after>=0
	return impact_drawn

func _fade() -> float:
	return 1.-smoothstep(.18,.85,after)

func _burst(point: Vector3, radius: float, height: float) -> void:
	var grow := smoothstep(0,.18,after)
	var fade := _fade()
	_piece(sphere,surface,point,Vector3(radius,height,radius)*(.22+grow*.78)*fade)
	for i in 4:
		var a := i*TAU/4.+.3
		var offset := (lateral*cos(a)+Vector3.UP*sin(a))*.65*radius*grow*fade
		_piece(sphere,hot,point+offset,Vector3.ONE*radius*.42*grow*fade)

func _floor_pulse(radius: float, material: Material) -> void:
	_piece(ring,material,ground+Vector3.UP*.08,Vector3(radius,.13,radius)*_fade())

func _fire_blast() -> void:
	var size := lerpf(.18,1.45,charge_progress() if elapsed<launch else 1.)*_fade()
	var point := origin.lerp(aim,flight)
	# The five-ended 大 silhouette is sculpted from thick tapered strokes.
	var axis := Basis(lateral,Vector3.UP,-forward)
	for segment: Vector4 in [Vector4(-.9,.35,.9,.35),Vector4(0,1.1,0,.15),Vector4(0,.15,-.85,-.9),Vector4(0,.15,.85,-.9)]:
		var a := point+(axis.x*segment.x+axis.y*segment.y)*size
		var b := point+(axis.x*segment.z+axis.y*segment.w)*size
		_line(a,b,.14*size,surface)
		_line(a,b,.05*size,hot)
	for i in 3:
		_piece(plume,surface,point+lateral*(i-1)*.5*size,Vector3(.4,.55,.4)*size,ground_basis)
	if _impact(): _burst(aim,1.35,1.45)

func _heat_wave() -> void:
	var charge := charge_progress()
	var center := actor_ground.lerp(ground,flight)
	var fade := _fade()
	# Three low, connected hot-air fronts sweep the arena rather than rising vents.
	for i in 3:
		var p := center-forward*i*1.15
		_piece(wave,veil,p,Vector3(2.8,1.9-i*.3,1.35)*charge*fade,ground_basis)
		_piece(flame,surface,p,Vector3(.55,.60-i*.13,.75)*charge*fade,ground_basis)
	if _impact(): _floor_pulse(1.+after*2.8,edge)

func _eruption() -> void:
	var charge := charge_progress()
	# Caster vent is delivery; target eruption is reserved for confirmed impact.
	var lift := (charge if elapsed<launch else 1.-smoothstep(.1,.7,flight))*1.65
	_piece(plume,hot,actor_ground,Vector3(1.1,lift,1.1))
	_piece(sphere,surface,actor_ground+Vector3.UP*.12,Vector3(1.0,.22,1.0)*charge*_fade())
	if elapsed>=launch and after<0:
		for i in 5:
			var p := clampf((flight-i*.035)/(1.-i*.035),0,1)
			var end := ground+lateral*(i-2)*.48
			var point := (actor_ground+Vector3.UP*2.2).lerp(end+Vector3.UP*.4,p)+Vector3.UP*sin(p*PI)*2.
			_piece(slab,surface,point,Vector3(.36,.55,.38),Basis(Vector3.ONE.normalized(),clock_seconds+i))
			_piece(sphere,hot,point,Vector3.ONE*.20)
	if _impact():
		_burst(ground+Vector3.UP*.8,1.6,1.)
		for i in 5:
			var a := i*TAU/5.
			_piece(plume,hot,ground+Vector3(cos(a),0,sin(a))*.7,Vector3(.7,1.45,.7)*sin(clampf(after/.8,0,1)*PI),Basis(Vector3.UP,a))

func _lava_plume() -> void:
	var center := actor_ground.lerp(ground,flight*.85)
	var grow := .3+charge_progress()*.7
	# Dense low ash over a connected orange flame bed, spreading outward.
	for i in 3:
		var point := center-forward*i*.65+Vector3.UP*(.7+i*.25)
		_piece(sphere,veil,point,Vector3(1.5+i*.4,1.0,1.15)*grow*_fade())
		_piece(flame,surface,point-Vector3.UP*.65,Vector3(.4+i*.07,.4,.5)*grow*_fade(),ground_basis)
	if _impact():
		_burst(aim,1.7,1.2)
		_floor_pulse(1.+after*2.2,edge)

func _magma_storm() -> void:
	if elapsed<launch:
		_piece(helix,surface,actor_ground,Vector3.ONE*.6*charge_progress(),Basis(Vector3.UP,clock_seconds*2.))
	else:
		var point := actor_ground.lerp(ground,flight)
		var grow := (.3+flight*.7)*_fade()
		_piece(funnel,wind,point,Vector3(1.35,3.3,1.35)*grow,Basis(Vector3.UP,clock_seconds*2.))
		for i in 2:
			_piece(helix,surface,point,Vector3(1.2,1.55,1.2)*grow,Basis(Vector3.UP,clock_seconds*2.+i*PI))
	if _impact():
		for i in 4:
			var a := i*TAU/4.+clock_seconds*.5
			_piece(plume,hot,ground+Vector3(cos(a),0,sin(a))*1.05,Vector3(.55,1.,.55)*sin(clampf(after/.85,0,1)*PI),Basis(Vector3.UP,a))
		_floor_pulse(1.3+after,edge)

func _mystical_fire() -> void:
	var q := charge_progress()
	var point := origin.lerp(aim,flight)
	# Three entwined curved flame tongues orbit a compact magical heart.
	for i in 3:
		var a := i*TAU/3.+clock_seconds*2.
		var offset := (lateral*cos(a)+Vector3.UP*sin(a))*(.2+flight*.3)
		_piece(plume,surface,point+offset-Vector3.UP*.5,Vector3(.55,.55,.55)*q*_fade(),ground_basis*Basis(Vector3.UP,a))
	_piece(sphere,hot,point,Vector3.ONE*.2*q*_fade())
	if _impact():
		for i in 3:
			var a := i*TAU/3.+clock_seconds
			_piece(helix,hot,ground,Vector3(.65,.9,.65)*sin(clampf(after/.8,0,1)*PI),Basis(Vector3.UP,a))

func _muddy_water() -> void:
	var point := actor_ground.lerp(ground,flight)
	var height := (1.6+flight*.45)*charge_progress()*(1.-smoothstep(0,.65,after)*.8)
	# A broad uneven brown breaker with a heavy sediment bed.
	_piece(wave,surface,point,Vector3(3.,height,1.25),ground_basis)
	_piece(wave,water_body,point-forward*.65,Vector3(2.7,height*.55,1.),ground_basis)
	_piece(sphere,water_body,point-forward*.5+Vector3.UP*.12,Vector3(2.8,.25,1.3)*_fade())
	for i in 4:
		_piece(slab,stone,point+lateral*(i-1.5)*.8+Vector3.UP*.2,Vector3(.18,.26,.2)*_fade(),Basis(Vector3.UP,i))
	if _impact():
		for i in 4:
			_piece(plume,surface,ground+lateral*(i-1.5)*.65,Vector3(.55,.65,.55)*sin(clampf(after/.8,0,1)*PI),Basis(Vector3.UP,i))

func _sludge_wave() -> void:
	var point := actor_ground.lerp(ground,flight)
	var grow := charge_progress()*_fade()
	# Viscous low bulges merge into a thick, slow folding lip.
	_piece(wave,surface,point,Vector3(2.8,1.25,1.35)*grow,ground_basis)
	for i in 3:
		_piece(sphere,surface,point+lateral*(i-1)*1.05+Vector3.UP*.35,Vector3(1.3,.55,1.05)*grow)
	if _impact():
		for i in 5:
			var a := i*TAU/5.
			_piece(plume,hot,ground+Vector3(cos(a),0,sin(a))*.95,Vector3(.7,.65,.7)*sin(clampf(after/.8,0,1)*PI),Basis(Vector3.UP,a))
		_floor_pulse(1.+after*2.,edge)

func _night_daze() -> void:
	var grow := charge_progress()
	var radius := lerpf(.45,actor_ground.distance_to(ground)*.7,flight)*_fade()
	var point := actor_ground.lerp(field_center,flight*.6)
	# Radial dusk shock from the caster; the dark curved curtain stays low.
	_piece(ring,surface,point+Vector3.UP*.35,Vector3(radius,.7,radius)*grow)
	_piece(sphere,veil,point+Vector3.UP*.3,Vector3(radius,.5,radius)*grow)
	if _impact():
		_piece(sphere,surface,aim,Vector3(1.3,.35,1.3)*(1.+after)*_fade(),Basis(lateral,forward,lateral.cross(forward)))
		_floor_pulse(1.+after*1.5,hot)

func _dragon_pulse() -> void:
	var axis := Basis(lateral,forward,lateral.cross(forward))
	if elapsed<launch:
		_ball(origin,.06+charge_progress()*.3,hot)
		_impact()
		return
	var size := (.20+1.25*smoothstep(0,.65,flight))*_fade()
	var point := origin.lerp(aim,flight)
	# Sculpted energy-dragon snout, brow, twin horns and a continuous neck.
	_piece(sphere,surface,point,Vector3(.5,.65,.4)*size,axis)
	_piece(sphere,hot,point+forward*.48*size,Vector3(.30,.42,.26)*size,axis)
	_piece(sphere,surface,point+forward*.25*size-Vector3.UP*.23*size,Vector3(.30,.4,.20)*size,axis)
	_piece(dragon_neck,surface,point-forward*.2*size,Vector3.ONE*size,axis)
	for sign_value in [-1.,1.]:
		var horn: Vector3 = point+lateral*sign_value*.32*size+Vector3.UP*.2*size
		_piece(tooth,hot,horn,Vector3(.12,.7,.12)*size,Volume.along((Vector3.UP-forward*.45+lateral*sign_value*.15).normalized()))
		_ball(point+lateral*sign_value*.38*size+forward*.22*size+Vector3.UP*.17*size,.07*size,core)
	if _impact(): _burst(aim,1.3,1.2)

func _psychic() -> void:
	var axis := Basis(lateral,forward,lateral.cross(forward))
	var point := origin.lerp(aim,flight)
	var size := (.2+flight*.75)*charge_progress()*_fade()
	_piece(sphere,veil,point,Vector3(size,.25,size),axis)
	_piece(ring,hot,point,Vector3(size,.08,size),axis)
	if _impact():
		var squeeze := (1.5-smoothstep(0,.3,after)*.65)*_fade()
		_piece(sphere,veil,aim,Vector3(1.15,1.5,1.15)*squeeze)
		for i in 3:
			_piece(ring,surface,aim,Vector3(1.25,.07,1.25)*squeeze,Basis(Vector3.RIGHT,i*PI/3.)*Basis(Vector3.UP,clock_seconds*.7))
		_ball(aim,.28*sin(clampf(after/.65,0,1)*PI),hot)

func _psyshock() -> void:
	var axis := Basis(lateral,forward,lateral.cross(forward))
	if after<0:
		for i in 3:
			var p := clampf((flight-i*.045)/(1.-i*.045),0,1)
			var point := origin.lerp(aim,p)+lateral*(i-1)*.65*(1.-p)
			var grow := charge_progress()*(.5+p*.5)
			_piece(slab,surface,point,Vector3(.22,1.3,.22)*grow,axis)
			_piece(slab,hot,point,Vector3(.08,1.4,.08)*grow,axis)
	if _impact():
		for i in 3:
			var a := i*TAU/3.
			var direction := (lateral*cos(a)+Vector3.UP*sin(a))
			_piece(slab,hot,aim+direction*(.25+after)*_fade(),Vector3(.18,.8,.15)*_fade(),Volume.along(direction))
		_floor_pulse(.75+after*1.8,edge)

func _leaf_storm() -> void:
	var point := actor_ground.lerp(ground,flight)
	var grow := charge_progress()*_fade()
	_piece(funnel,wind,point,Vector3(1.8,3.2,1.8)*grow,Basis(Vector3.UP,clock_seconds*2.))
	_piece(helix,surface,point,Vector3(1.6,1.5,1.6)*grow,Basis(Vector3.UP,clock_seconds*2.))
	for i in 9:
		var p := i/9.
		var a := p*TAU*1.75+clock_seconds*2.
		var center := point+Vector3(cos(a)*(1.+p*.45),.3+p*2.5,sin(a)*(1.+p*.45))*grow
		_piece(leaf_mesh,hot,center,Vector3(.24,.6,.3)*grow,Basis(Vector3.UP,-a)*Basis(Vector3.RIGHT,.5))
	if _impact():
		_piece(wave,veil,ground,Vector3(2.,1.4,1.4)*sin(clampf(after/.85,0,1)*PI),ground_basis)
		_floor_pulse(1.+after*1.8,edge)

func _sandsear_storm() -> void:
	var point := actor_ground.lerp(ground,flight)
	var grow := charge_progress()*_fade()
	_piece(funnel,wind,point,Vector3(2.,3.7,2.)*grow,Basis(Vector3.UP,clock_seconds*1.6))
	_piece(sphere,veil,point+Vector3.UP*.5,Vector3(2.,.65,2.)*grow)
	for i in 6:
		var a := i*TAU/6.+clock_seconds*1.6
		var pos := point+Vector3(cos(a)*1.3,.4+(i%3)*.75,sin(a)*1.3)*grow
		_piece(slab,stone,pos,Vector3(.28,.35,.27)*grow,Basis(Vector3.UP,a))
	if _impact():
		for i in 3:
			_piece(plume,hot,ground+lateral*(i-1)*.75,Vector3(.5,1.2,.5)*sin(clampf(after/.85,0,1)*PI),ground_basis)
		_floor_pulse(1.2+after*2.2,edge)

func _bleakwind_storm() -> void:
	var point := actor_ground.lerp(ground,flight)
	var grow := charge_progress()*_fade()
	# Twin pale vortices lean together around the advance, with a few solid ice blades.
	for sign_value in [-1.,1.]:
		var base: Vector3 = point+lateral*sign_value*.9
		_piece(funnel,wind,base,Vector3(1.25,3.4,1.25)*grow,ground_basis*Basis(Vector3.FORWARD,sign_value*.14)*Basis(Vector3.UP,clock_seconds*sign_value*2.))
		_piece(helix,veil,base,Vector3(1.,1.5,1.)*grow,Basis(Vector3.UP,clock_seconds*sign_value*2.))
	for i in 6:
		var a := i*TAU/6.+clock_seconds*2.
		var pos := point+Vector3(cos(a)*1.65,.5+(i%3)*.6,sin(a)*1.3)*grow
		_piece(slab,hot,pos,Vector3(.07,.55,.1)*grow,ground_basis*Basis(Vector3.RIGHT,.8))
	if _impact():
		_piece(sphere,veil,aim,Vector3(2.,1.1,2.)*sin(clampf(after/.85,0,1)*PI))
		_floor_pulse(1.+after*2.,hot)

func _leaf_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 12:
		for sign_value in [-1.,1.]:
			for c: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var p := (i+c.y)/12.
				tool.set_uv(Vector2(c.x,p))
				tool.add_vertex(Vector3(sign_value*c.x*sin(p*PI),p*2.-1.,sin(p*PI)*(.2-c.x*.15)))
	tool.generate_normals()
	return tool.commit()
