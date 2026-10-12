extends "res://scripts/battle/battle_ui/move_effect_3d.gd"
## Explicit catalogue presentations. Solid silhouettes, native clock, no gameplay writes.
const Forms = preload("res://scripts/battle/battle_ui/move_volume_forms_3d.gd")
const FieryWrath = preload("res://scripts/battle/battle_ui/fiery_wrath_forms_3d.gd")
var wrath: RefCounted
var recipe: Dictionary
var motif := ""
var launched := false
var origin := Vector3.ZERO
var launch_origin := Vector3.ZERO
var aim := Vector3.ZERO
var ground := Vector3.ZERO
var actor_ground := Vector3.ZERO
var field_center := Vector3.ZERO
var field_radius := 5.8
var captured := false
var impact_drawn := false
var emission_end := -1.0
var projectile_arc_height := 0.0
var ring := TorusMesh.new()
var box := BoxMesh.new()
var rock := PrismMesh.new()
var crescent: ArrayMesh
var crest: ArrayMesh
var funnel: ArrayMesh
var solid: ShaderMaterial
var mist_material: StandardMaterial3D
var accent: StandardMaterial3D
var direction := Vector3.FORWARD
var side := Vector3.RIGHT
var axis := Basis.IDENTITY
var facing := Basis.IDENTITY
var flight := 0.0
var after := 0.0
var envelope := 0.0
var body := .7
var center := Vector3.ZERO
var prepared := false

func start(move: String, timing: Dictionary, options: Dictionary, native_clock: Callable, positions: Callable, guard: Callable) -> void:
	emission_end = float(timing.get("emission_end_frame", -60.0)) / 60.0
	super.start(move, timing, options, native_clock, positions, guard)

func _prepare() -> void:
	recipe = RecipeCatalog.get_recipe(key)
	motif = str(recipe.motif)
	projectile_arc_height = float(recipe.arc)
	if emission_end < 0: emission_end = lerpf(impact, duration, .55)
	ring.inner_radius = .94
	ring.outer_radius = 1.
	ring.rings = 32
	ring.ring_segments = 8
	box.size = Vector3.ONE
	rock.size = Vector3.ONE
	tooth.radial_segments = 8
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color;
uniform float seconds;
uniform float luminous;
uniform bool water = false;
void fragment() {
 float flow = sin(UV.y*18.-seconds*7.+sin(UV.x*18.85)*.7)*.5+.5;
 float rim = pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),2.);
 ALBEDO = mix(tint.rgb*.55,tint.rgb, .4+flow*.25+rim*.35);
 if (water) {
  float foam = smoothstep(.78,.97,UV.y + sin(UV.x*35.-seconds*4.)*.045);
  ALBEDO = mix(ALBEDO*.8, vec3(.78,.94,1.), foam);
 }
 EMISSION = tint.rgb*(.18+flow*.18+rim*.25)*luminous;
 ROUGHNESS = .45;
}
"""
	solid = ShaderMaterial.new()
	solid.shader = shader
	solid.set_shader_parameter("tint", Color(str(recipe.color)))
	solid.set_shader_parameter("water", motif=="wave" or key=="maxgeyser")
	solid.set_shader_parameter("luminous", 1.0 if float(recipe.lighting.energy)>0 else .15)
	accent = _material(Color(str(recipe.color)).lerp(Color.WHITE,.65),.8)
	mist_material = _material(Color(str(recipe.color)),.12)
	crescent = _ribbon(false)
	crest = _wave_mesh()
	funnel = Forms.swept_mesh(true)
	prepared = true
	if key == "fierywrath": wrath = FieryWrath.new()

func _ribbon(wave: bool) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 32:
		for corner: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
			var p := (i+corner.x)/32.
			var angle := lerpf(-1.3,1.3,p)
			var radius := 1.-corner.y*.28*sin(p*PI)
			var point := Vector3(cos(angle),sin(angle),0)*radius
			if wave: point = Vector3((p-.5)*4.,corner.y*(.5+sin(p*PI)),sin(corner.y*PI)*.45)
			tool.set_uv(Vector2(p,corner.y))
			tool.add_vertex(point)
	tool.generate_normals()
	return tool.commit()

func _draw_source_move(from: Vector3, to: Vector3, right: Vector3, up: Vector3) -> bool:
	if not prepared: _prepare()
	var points: Dictionary = anchors.call()
	center = points.get("actor_center",from)
	body = clampf(float(points.get("actor_radius",.7)),.45,1.4)
	if not captured:
		captured = true
		actor_ground = points.get("actor_ground",Vector3(from.x,.04,from.z))
		ground = points.get("target_ground",Vector3(to.x,.04,to.z))
		field_center = points.get("field",{}).get("center",(actor_ground+ground)*.5)
		field_radius = float(points.get("field",{}).get("radius",5.8))
	if not launched:
		origin = from
		launch_origin = from
		aim = to
		if elapsed >= launch: launched = true
	direction = (aim-origin).normalized()
	if direction.length_squared()<.01: direction = Vector3.FORWARD
	side = direction.cross(Vector3.UP if absf(direction.y)<.95 else Vector3.RIGHT).normalized()
	axis = Basis(side,direction,side.cross(direction))
	facing = Basis(right,up,right.cross(up))
	flight = (elapsed-launch)/maxf(impact-launch,.01)
	after = (elapsed-impact)/maxf(duration-impact,.01)
	var t := elapsed/duration
	envelope = smoothstep(0,.08,t)*(1.-smoothstep(.78,1.,t))
	solid.set_shader_parameter("seconds",t*float(recipe.duration_seconds))
	edge.albedo_color.a = envelope*.75
	accent.albedo_color.a = envelope*.8
	mist_material.albedo_color.a = envelope*.13
	impact_drawn = hit and bool(recipe.damaging) and after>=0
	if wrath != null:
		wrath.draw(self)
		return true
	if motif in ["ram","rush","punch","kick","slash","fang","pierce","lash","spin","hammer","grip","vanish"]: _contact()
	else:
		match motif:
			"beam": _beam()
			"orb", "bomb", "shard", "boomerang", "prism", "swarm", "cutwave": _projectile()
			"sound", "statussound", "pulse", "statuswave", "drain": _pulse()
			"shield": _shield()
			"heal": _heal()
			"boost": _boost()
			"heart": _hearts()
			"seal", "cage": _seal()
			"exchange": _exchange()
			"ritual": _ritual()
			"weather": _weather()
			"room": _room()
			"mist", "statuscloud": _mist()
			_: _field()
	if impact_drawn:
		var fade := 1.-smoothstep(.05,.7,after)
		if fade>.001:
			_piece(ring,accent,aim,Vector3.ONE*(.25+after*1.8)*fade,axis)
			_piece(sphere,solid,aim,Vector3(.38,.1,.38)*sin(clampf(after/.4,0,1)*PI),axis)
	return true

func _charge() -> void:
	var q := charge_progress()
	_ball(origin,.11*q*emission_scale,solid)
	_piece(ring,edge,origin,Vector3.ONE*(.25-.13*q)*envelope,axis)

func _beam() -> void:
	if elapsed>=emission_end: return
	if flight<0:
		for source: Vector3 in emission_sources:
			_ball(source,.12*charge_progress()*emission_scale,solid)
		return
	var fade := (1.-smoothstep(impact,emission_end,elapsed))*smoothstep(0,.12,flight)
	for source: Vector3 in emission_sources:
		var tip := source.lerp(aim,clampf(flight,0,1))
		var width := float(recipe.width)*emission_scale*fade
		var tip_radius := _tapered_beam(source,tip,width,solid,source.distance_to(aim))
		_ball(tip,tip_radius,solid)
		_tapered_beam(source,tip,width*.28,accent,source.distance_to(aim))

func projectile_point(fraction: float, index := 0) -> Vector3:
	var spread := (index-(int(recipe.count)-1)*.5)*.3
	return origin.lerp(aim,fraction)+Vector3.UP*sin(fraction*PI)*projectile_arc_height+side*sin(fraction*PI)*spread

func _projectile() -> void:
	if flight<0: _charge(); return
	if after>=0 and motif!="boomerang": return
	var count := int(recipe.count)
	for i in count:
		var p := clampf((flight-i*.045)/maxf(.1,1.-i*.045),0,1)
		if motif=="boomerang":p=sin(clampf(flight/1.65,0,1)*PI)
		var point := projectile_point(p,i)
		var size := float(recipe.width)*lerpf(.38,1.,smoothstep(0,.3,p))*emission_scale
		var basis_value := axis*Basis(Vector3.UP,elapsed*7.+i)
		match motif:
			"shard": _piece(rock,solid,point,Vector3(size*.6,size*2.,size*.6),basis_value)
			"cutwave": _piece(crescent,solid,point,Vector3.ONE*size*2.4,facing*Basis(Vector3.FORWARD,float(recipe.rotation)+i*.5))
			"boomerang":
				_line(point-side*.4,point+side*.4,.075,solid)
				_ball(point-side*.4,.13,solid); _ball(point+side*.4,.13,solid)
			"swarm":
				_piece(sphere,solid,point,Vector3(size,size*.5,size*.5),basis_value)
				_piece(crescent,accent,point,Vector3.ONE*size*1.6,basis_value)
			"prism":
				var colors := [Color("ff9854"),Color("9be7ff"),Color("fff179")]
				var material := core if i==0 else edge if i==1 else accent
				material.albedo_color=colors[i%3]
				_ball(point,size,material)
			_: _ball(point,size,solid)
		# A single continuous wake, bounded by the distance already travelled.
		var tail := projectile_point(maxf(0,p-.12),i)
		_line(tail,point,size*.35,accent)

func _contact() -> void:
	if flight<0:
		_piece(ring,edge,center,Vector3.ONE*body*.8*charge_progress(),axis)
		return
	var fade := 1.-smoothstep(.05,.55,after)
	if fade<=.001:return
	if motif in ["rush","vanish","ram"]:
		_piece(crescent,accent,center,Vector3.ONE*body*fade,axis*Basis(Vector3.RIGHT,PI*.5))
		for i in 3:
			var a := i*TAU/3
			var offset := (side*cos(a)+Vector3.UP*sin(a))*body*.7
			_line(center+offset-direction*.65,center+offset,.022*fade,edge)
		if motif=="vanish":
			_piece(ring,edge,actor_ground,Vector3.ONE*body*fade)
			_piece(ring,edge,ground,Vector3.ONE*body*fade)
		return
	# Strike forms travel to the original aim even on a dodge; confirmed impact
	# is separately gated. A block never receives the contact flash.
	var strike := sin(clampf((flight-.55)/.65,0,1)*PI)*fade
	if strike<=.001:return
	var count := int(recipe.count)
	for i in count:
		var point := aim+side*(i-(count-1)*.5)*.16
		var swing := Basis(Vector3.FORWARD,float(recipe.rotation)+i*.5+(1.-strike)*.6)
		match motif:
			"slash": _piece(crescent,solid,point,Vector3.ONE*.75*strike,facing*swing)
			"punch": _fist(point,strike*.55,facing)
			"kick": _piece(box,solid,point,Vector3(.2,.22,.65)*strike,axis*swing)
			"fang":
				for jaw in [-1,1]:
					for n in 4:
						var pos: Vector3 = point+side*(n-1.5)*.17+Vector3.UP*jaw*(.5-strike*.25)
						_piece(tooth,solid,pos,Vector3(.1,.25,.12)*strike,Basis(Vector3.RIGHT,PI if jaw>0 else 0.))
			"pierce": _piece(tooth,solid,point-direction*(1.-strike)*.6,Vector3(.14,.9,.14)*strike,axis)
			"hammer":
				_line(point-Vector3.UP*.6,point+Vector3.UP*.3,.065*strike,solid)
				_piece(box,solid,point+Vector3.UP*.3,Vector3(.65,.35,.35)*strike,facing*swing)
			"lash":
				for n in 12:
					var q := n/12.
					var r := (n+1)/12.
					_line(center.lerp(aim,q)+Vector3.UP*sin(q*PI)*strike,center.lerp(aim,r)+Vector3.UP*sin(r*PI)*strike,.04*strike,solid)
			"spin": _piece(ring,solid,point,Vector3.ONE*.7*strike,axis*Basis(Vector3.RIGHT,elapsed*9.))
			"grip":
				for sign_value in [-1,1]:_piece(crescent,solid,point+side*sign_value*(1.-strike)*.4,Vector3.ONE*.5*strike,facing*Basis(Vector3.FORWARD,PI if sign_value<0 else 0.))

func _pulse() -> void:
	if flight<0: _charge();return
	for i in 3:
		var p := clampf((flight-i*.13)/.74,0,1)
		var fade := sin(p*PI)*envelope
		var point := origin.lerp(aim,p)
		if motif=="drain" and hit and after>=0:
			point=aim.lerp(origin,clampf(after*1.5,0,1));fade=envelope
		_piece(ring,edge,point,Vector3.ONE*(.12+p*.75)*fade,axis)
		if motif in ["sound","statussound"]:
			var note := point+Vector3.UP*.25
			_ball(note,.08*fade,solid)
			_line(note,note+Vector3.UP*.32,.02*fade,solid)

func _shield() -> void:
	var p := smoothstep(0,.35,elapsed/duration)*envelope
	var point := center+direction*body*.75
	_piece(sphere,mist_material,center,Vector3.ONE*body*1.35*p)
	_piece(ring,solid,point,Vector3.ONE*body*p,axis)
	for i in 6:
		var a := i*TAU/6
		var b := (i+1)*TAU/6
		_line(point+(side*cos(a)+Vector3.UP*sin(a))*body*p,point+(side*cos(b)+Vector3.UP*sin(b))*body*p,.035,accent)
	if key in ["spikyshield","banefulbunker","silktrap"]:
		for i in 6:_piece(tooth,solid,point+side*cos(i*TAU/6)*body+Vector3.UP*sin(i*TAU/6)*body,Vector3(.1,.3,.1)*p,axis)

func _heal() -> void:
	var recipient := center if recipe.target=="actor" else aim
	var p := elapsed/duration
	for i in 3:
		var q := fmod(p+i/3.,1.)
		_piece(ring,edge,recipient+Vector3.UP*(q-.5)*1.2,Vector3.ONE*(.25+q*.5)*sin(q*PI)*envelope)
	var size := .18*envelope
	_piece(box,accent,recipient+Vector3.UP*.6,Vector3(size*.55,size*2.,size*.4))
	_piece(box,accent,recipient+Vector3.UP*.6,Vector3(size*2.,size*.55,size*.4))
	if key in ["moonlight","lunardance","lunarblessing"]:_piece(crescent,solid,recipient+Vector3.UP*1.2,Vector3.ONE*.45*envelope,facing)

func _boost() -> void:
	var q := smoothstep(0,.5,elapsed/duration)*envelope
	_piece(ring,edge,actor_ground,Vector3.ONE*body*1.3*q)
	for i in 3:
		var a := i*TAU/3+elapsed*1.5
		var point := center+Vector3(cos(a),sin(elapsed*2.+i)*.15,sin(a))*body*1.2
		_piece(tooth,solid,point,Vector3(.13,.55,.13)*q)
	if key in ["shellsmash","filletaway","autotomize"]:
		for i in 4:_piece(rock,solid,center+Vector3(cos(i*1.57),-.2,sin(i*1.57))*q,Vector3(.25,.4,.15)*(1.-q)*envelope)

func _hearts() -> void:
	if flight<0:return
	for i in 2:
		var p := clampf(flight-i*.16,0,1)
		var point := origin.lerp(aim,p)+Vector3.UP*sin(p*PI)*.4
		var size := .16*sin(p*PI)*envelope
		_ball(point-side*size*.45+Vector3.UP*size*.35,size*.7,solid)
		_ball(point+side*size*.45+Vector3.UP*size*.35,size*.7,solid)
		_piece(tooth,solid,point-Vector3.UP*size*.3,Vector3(size,size*1.7,size*.5),Basis(Vector3.RIGHT,PI))

func _seal() -> void:
	var q := smoothstep(launch,impact,elapsed)*envelope
	_piece(ring,edge,aim,Vector3.ONE*.65*q,axis)
	if motif=="cage" or key in ["block","fairylock","imprison","spiderweb","octolock"]:
		for i in 6:
			var a := i*TAU/6
			var offset := Vector3(cos(a),0,sin(a))*.65*q
			_line(aim+offset-Vector3.UP*.5*q,aim+offset+Vector3.UP*.65*q,.025,solid)
	else:
		for i in 4:
			var offset := (side*cos(i*PI*.5)+Vector3.UP*sin(i*PI*.5))*.5*q
			_line(aim+offset*.65,aim+offset*1.35,.03*q,solid)
		_ball(aim,.12*q,solid)

func _exchange() -> void:
	var q := clampf(flight,0,1)
	var fade := sin(q*PI)*envelope
	for sign_value in [-1,1]:
		var start := center if sign_value==1 else aim
		var end := aim if sign_value==1 else center
		var point: Vector3 = start.lerp(end,q)+side*sign_value*sin(q*PI)*.45
		_piece(tooth,solid,point,Vector3(.13,.45,.13)*fade,axis*Basis(Vector3.RIGHT,PI if sign_value<0 else 0.))
		_piece(ring,edge,start,Vector3.ONE*.45*envelope,axis)

func _ritual() -> void:
	var q := elapsed/duration
	if key=="splash":
		_piece(ring,edge,actor_ground,Vector3.ONE*(.3+q)*sin(q*PI))
		return
	for i in 3:
		var a := q*TAU+i*TAU/3
		var point := center+Vector3(cos(a),.2,sin(a))*body*1.2
		_piece(rock,solid,point,Vector3(.2,.35,.15)*envelope,Basis(Vector3.UP,-a))
	_piece(ring,edge,actor_ground,Vector3.ONE*body*envelope)

func _mist() -> void:
	var q := clampf(flight,0,1)
	var point := origin.lerp(aim,q)
	for i in 3:
		var offset := side*(i-1)*.28+Vector3.UP*sin(elapsed*2.+i)*.08
		_piece(sphere,mist_material,point+offset,Vector3(.45,.28,.35)*envelope*(.3+q))

func _weather() -> void:
	if key=="sunnyday":
		var point := field_center+Vector3.UP*3.6
		_ball(point,.42*envelope,solid)
		_piece(ring,accent,point,Vector3.ONE*.7*envelope,facing)
		return
	if key=="sandstorm":
		_piece(funnel,mist_material,field_center,Vector3(field_radius*.65,2.5,field_radius*.65)*envelope)
		return
	for i in 12:
		var a := i*2.4
		var radius := sqrt((i+.5)/12.)*field_radius*.8
		var q := fmod(elapsed*.7+i*.618,1.)
		var point := field_center+Vector3(cos(a)*radius,(1.-q)*3.3,sin(a)*radius)
		if key=="raindance":_line(point,point+Vector3.UP*.28,.018*envelope,accent)
		else:_piece(rock,accent,point,Vector3.ONE*.07*envelope,Basis(Vector3.ONE.normalized(),elapsed+i))

func _room() -> void:
	var radius := minf(field_radius*.7,4.)
	var q := smoothstep(0,.4,elapsed/duration)*envelope
	if key in ["tailwind","whirlwind"]:
		for i in 3:_piece(crescent,edge,field_center+Vector3.UP*(.5+i*.55),Vector3.ONE*(1.+i*.2)*q,Basis(Vector3.UP,elapsed*2.+i))
		return
	for x in [-1,1]:
		for z in [-1,1]:
			var p := field_center+Vector3(x*radius,0,z*radius)*q
			_line(p,p+Vector3.UP*2.7*q,.025,edge)
			for y in [0.,2.7]:
				_line(field_center+Vector3(x*radius,y,z*radius)*q,field_center+Vector3(-x*radius,y,z*radius)*q,.025,edge)

func _field() -> void:
	if flight<0:_charge();return
	var p := clampf(flight,0,1)
	var fade := 1.-smoothstep(.05,.85,after)
	var count := int(recipe.count)
	match motif:
		"wave":
			var point := actor_ground.lerp(ground,p)
			_piece(crest,solid,point,Vector3(1.,1.5,1.)*fade,Basis(side,Vector3.UP,-Vector3(side.z,0,-side.x)))
		"vortex": _piece(funnel,mist_material,ground,Vector3(1.15,2.6,1.15)*envelope,Basis(Vector3.UP,elapsed*3.))
		"rain":
			for i in count:
				var q := clampf((flight-i*.04)/maxf(.1,1.-i*.04),0,1)
				var offset := side*(i-(count-1)*.5)*.4
				var point := aim+offset+Vector3.UP*(1.-q)*3.2
				_piece(rock,solid,point,Vector3(.22,.5,.24)*fade,Basis(Vector3.ONE.normalized(),elapsed+i))
		"eruption":
			for i in count:
				var point := actor_ground.lerp(ground,(i+1.)/count)
				var rise := smoothstep(i/float(count)*.7,i/float(count)*.7+.3,p)*fade
				_piece(tooth,solid,point+Vector3.UP*rise*.6,Vector3(.35,1.2,.35)*rise)
		"lightning":
			var point := aim+Vector3.UP*3.5
			for i in 8:
				var q := i/8.
				var r := (i+1)/8.
				_line(point.lerp(aim,q)+side*sin(i*3.7)*.22,point.lerp(aim,r)+side*sin((i+1)*3.7)*.22,.055*envelope,solid)
		"firestar":
			var point := origin.lerp(aim,p)
			var size := (.15+p)*fade
			if key=="fireblast":
				# The familiar five-ended fire glyph: crossbar, spine and two legs.
				_line(point-side*size,point+side*size,.085*fade,solid)
				_line(point+Vector3.UP*size,point-Vector3.UP*size*.15,.1*fade,solid)
				for sign_value in [-1,1]:_line(point,point+(side*sign_value-Vector3.UP)*size,.09*fade,solid)
			else:
				for i in 3:_piece(crescent,solid,point,Vector3.ONE*size,facing*Basis(Vector3.FORWARD,elapsed+i*TAU/3))
		"max": _max_move(p,fade)
		_: # Bounded dome for eruptions/explosions, not a particle cloud.
			_piece(sphere,mist_material,aim,Vector3.ONE*(.2+p*1.5)*fade)
			for i in 3:_piece(ring,solid,aim,Vector3.ONE*(.2+p*(.7+i*.2))*fade,Basis(Vector3.RIGHT,i*PI/3))

func _max_move(p: float, fade: float) -> void:
	var size := p*fade
	match key:
		"maxairstream", "maxwyrmwind":
			_piece(funnel,mist_material,ground,Vector3(1.4,3.,1.4)*size,Basis(Vector3.UP,elapsed*3.))
		"maxrockfall", "maxhailstorm":
			for i in 3:
				var point := aim+side*(i-1)*.8+Vector3.UP*(1.-p)*3.5
				_piece(rock,solid,point,Vector3(.55,.8,.6)*fade,Basis(Vector3.ONE.normalized(),i+.5))
		"maxgeyser":
			_piece(crest,solid,actor_ground.lerp(ground,p),Vector3(1.25,2.4,1.)*fade,Basis(side,Vector3.UP,side.cross(Vector3.UP)))
		"maxknuckle":
			var point := aim+Vector3.UP*(1.-p)*2.5
			_fist(point,fade*1.4,facing)
		"maxovergrowth", "maxsteelspike", "maxquake":
			for i in 5:
				var point := ground+Vector3(cos(i*TAU/5),0,sin(i*TAU/5))*.9
				_piece(tooth,solid,point+Vector3.UP*size*.9,Vector3(.24,1.8,.24)*size)
		"maxooze":
			_piece(sphere,solid,ground,Vector3(1.5,.15,1.5)*size)
			for i in 3:_ball(ground+Vector3(sin(i*2.),.18,cos(i*2.))*.7,.22*size,solid)
		"maxlightning":
			for i in 8:
				var a := aim+Vector3.UP*(3.-i*.375)+side*sin(i*2.7)*.2
				var b := aim+Vector3.UP*(3.-(i+1)*.375)+side*sin((i+1)*2.7)*.2
				_line(a,b,.07*size,solid)
		"maxflutterby":
			for i in 2:_piece(crescent,solid,aim,Vector3(1.2,1.6,1.)*size,facing*Basis(Vector3.FORWARD,PI*i))
		"maxphantasm", "maxdarkness":
			for i in 3:
				var point := aim+side*(i-1)*.7+Vector3.UP*(1.-p)*1.8
				_piece(crescent,solid,point,Vector3.ONE*.8*fade,facing*Basis(Vector3.FORWARD,-PI*.5))
		"maxstarfall":
			for i in 5:
				var a := i*TAU/5
				_line(aim,aim+(side*cos(a)+Vector3.UP*sin(a))*1.3*size,.075*fade,solid)
		"maxmindstorm":
			for i in 3:_piece(ring,solid,aim,Vector3.ONE*(.8+i*.2)*size,facing*Basis(Vector3.UP,elapsed+i))
		"maxflare":
			_piece(funnel,solid,ground,Vector3(.9,3.,.9)*size,Basis(Vector3.UP,elapsed*2.))
		_: _piece(ring,solid,ground,Vector3.ONE*(.2+p*2.)*fade)

func _fist(point: Vector3, size: float, pose: Basis) -> void:
	_piece(sphere,solid,point,Vector3(.38,.31,.25)*size,pose)
	for i in 4:
		var offset := pose.x*(i-1.5)*.17+pose.y*.12+pose.z*.19
		_piece(sphere,solid,point+offset*size*presentation_scale,Vector3(.105,.18,.14)*size,pose)
	var thumb := -pose.x*.3-pose.y*.11+pose.z*.16
	_piece(sphere,solid,point+thumb*size*presentation_scale,Vector3(.15,.22,.14)*size,pose*Basis(Vector3.FORWARD,-.5))

func _wave_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in 32:
		for y in 12:
			for corner: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var u := (x+corner.x)/32.
				var v := (y+corner.y)/12.
				var span := sin(u*PI)
				# Rolled crest with an overhanging lip, not a flat rising panel.
				var angle := v*PI*1.3
				var height := (.4+span*.8)*sin(angle*.65)
				var curl := (1.-cos(angle))*.42
				tool.set_uv(Vector2(u,v))
				tool.add_vertex(Vector3((u-.5)*4.,height,curl))
	tool.generate_normals()
	return tool.commit()
