extends "res://scripts/battle/battle_ui/move_effect_3d.gd"
## Five authored silhouettes. Geometry, surface motion and impacts share the native clock.
const MOVE_KEYS := ["darkpulse", "surf", "blizzard", "earthpower", "overheat"]
const Forms = preload("res://scripts/battle/battle_ui/z_move_forms_3d.gd")
const PALETTES := {
	"darkpulse": [Color("130d24"), Color("a247d2")],
	"surf": [Color("086aaf"), Color("d6fbff")],
	"blizzard": [Color("6e9ab9"), Color("ecfaff")],
	"earthpower": [Color("683923"), Color("ffc66b")],
	"overheat": [Color("d42b0a"), Color("ffedab")],
}
var recipe: Dictionary
var captured := false
var launched := false
var origin := Vector3.ZERO
var aim := Vector3.ZERO
var actor_ground := Vector3.ZERO
var ground := Vector3.ZERO
var field_center := Vector3.ZERO
var field_radius := 5.8
var forward := Vector3.FORWARD
var lateral := Vector3.RIGHT
var ground_basis := Basis.IDENTITY
var surface: ShaderMaterial
var hot: ShaderMaterial
var stone: StandardMaterial3D
var wave: ArrayMesh
var plume: ArrayMesh
var foam: ArrayMesh
var water_body: ShaderMaterial
var ring := TorusMesh.new()
var slab := PrismMesh.new()
var impact_drawn := false
var impact_start_index := 0
var after := -1.0
var flight := 0.0
var alpha := 0.0

func _geometry_scale() -> float:
	# Field volumes use metres, independent of emitter anatomy or recipe magnification.
	return 1.0

func _palette() -> Array:
	return PALETTES[key]

func _surface_kind() -> int:
	return MOVE_KEYS.find(key)

func _prepare() -> void:
	recipe = RecipeCatalog.get_recipe(key)
	sphere.radial_segments = 48
	sphere.rings = 24
	ring.inner_radius = .78
	ring.outer_radius = 1.0
	ring.rings = 64
	ring.ring_segments = 12
	slab.size = Vector3.ONE
	stone = _material(Color("6d5142"), 1.0)
	wave = _wave_mesh()
	var lip := PackedVector3Array()
	var lip_radii := PackedFloat32Array()
	for i in 49:
		var u := i/48.
		lip.append(Vector3((u-.5)*2.,(.998*pow(maxf(0.,sin(u*PI)),.4)+.025),-.89))
		lip_radii.append(.012+.045*sin(u*PI))
	foam = Forms.tube(lip,lip_radii)
	var spine := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in 17:
		var p := i / 16.0
		spine.append(Vector3(sin(p*PI)*.32,p*2.,p*p*.65))
		radii.append(.03 + sin(p*PI)*.27)
	plume = Forms.tube(spine,radii)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform vec4 low_color : source_color;
uniform vec4 high_color : source_color;
uniform float seconds;
uniform float opacity;
uniform int kind;
uniform bool bright = false;
varying vec3 local_point;
float hash(vec3 p) { p=fract(p*.1031); p+=dot(p,p.yzx+33.33); return fract((p.x+p.y)*p.z); }
float noise(vec3 p) {
 vec3 i=floor(p); vec3 f=fract(p); f=f*f*(3.-2.*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() {
 local_point=VERTEX;
 if(kind==1) {
  VERTEX.y += sin(UV.x*24.+seconds*5.)*UV.y*.045;
  VERTEX.z += sin(UV.x*18.-seconds*4.)*UV.y*.05;
 } else {
  float ripple=sin(VERTEX.y*9.+seconds*7.+VERTEX.x*6.)*sin(VERTEX.z*7.-seconds*4.);
  VERTEX += NORMAL * ripple * .055;
 }
}
void fragment() {
 vec3 p=local_point*3.+vec3(seconds*.55,-seconds*1.5,seconds*.4);
 float n=noise(p)*.7+noise(p*2.1)*.3;
 float rim=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),2.);
 float heat=smoothstep(.28,.8,n);
 vec3 color=mix(low_color.rgb,high_color.rgb,heat*.6+rim*.2);
 float density=1.;
 if(kind==1) {
  float foam=smoothstep(.43,.65,UV.y+n*.08);
  color=mix(low_color.rgb*(.65+n*.5),high_color.rgb,foam);
  density=smoothstep(0.,.025,UV.x)*(1.-smoothstep(.975,1.,UV.x));
 } else if(kind==2) {
  color=mix(low_color.rgb,high_color.rgb,.35+n*.65);
  density=(1.-rim*.7)*(.55+n*.45);
 } else if(kind==0) {
  color=mix(low_color.rgb,high_color.rgb,pow(heat,3.)*.75+rim*.25);
 }
 if(bright) color=mix(color,high_color.rgb,.55);
 ALBEDO=color;
 EMISSION=color*(.35 + (kind==4 ? heat*.65 : .05));
 ALPHA=opacity*density;
}
"""
	surface = ShaderMaterial.new()
	surface.shader = shader
	surface.set_shader_parameter("low_color",_palette()[0])
	surface.set_shader_parameter("high_color",_palette()[1])
	surface.set_shader_parameter("kind",_surface_kind())
	hot = surface.duplicate()
	hot.set_shader_parameter("bright",true)
	water_body = surface.duplicate()
	water_body.set_shader_parameter("kind",5)
	water_body.set_shader_parameter("high_color",Color("2184b1"))
	if key == "blizzard":
		# Soft volume boundaries prevent the rolling snow from reading as solid discs.
		var snow_shader := Shader.new()
		snow_shader.code = shader.code.replace("cull_disabled, depth_prepass_alpha", "cull_back, depth_draw_never").replace("density=(1.-rim*.7)*(.55+n*.45);", "density=pow(1.-rim,1.6)*(.12+n*.42);")
		surface.shader = snow_shader

func _draw_source_move(from: Vector3, to: Vector3, _right: Vector3, _up: Vector3) -> bool:
	if surface == null: _prepare()
	var points: Dictionary = anchors.call()
	if not captured:
		captured = true
		actor_ground = points.get("actor_ground", Vector3(from.x,0,from.z))
		ground = points.get("target_ground", Vector3(to.x,0,to.z))
		field_center = points.get("field",{}).get("center",(actor_ground+ground)*.5)
		field_radius = float(points.get("field",{}).get("radius",5.8))
	if not launched:
		origin = from
		aim = to
		if elapsed >= launch: launched = true
	forward = (ground-actor_ground).normalized()
	if forward.is_zero_approx(): forward = Vector3.FORWARD
	lateral = forward.cross(Vector3.UP).normalized()
	ground_basis = Basis(lateral,Vector3.UP,-forward)
	flight = clampf((elapsed-launch)/maxf(.01,impact-launch),0,1)
	after = (elapsed-impact)/maxf(.01,duration-impact)
	alpha = smoothstep(effect_start,maxf(effect_start+.01,launch*.5),elapsed)*(1.-smoothstep(.5,1.,after))
	for mat in [surface,hot,water_body]:
		mat.set_shader_parameter("seconds",elapsed/duration*float(recipe.duration_seconds))
		mat.set_shader_parameter("opacity",alpha)
	core.albedo_color.a = alpha*.8
	edge.albedo_color.a = alpha*.6
	stone.albedo_color.a = alpha
	impact_drawn = false
	match key:
		"darkpulse": _dark_pulse()
		"surf": _surf()
		"blizzard": _blizzard()
		"earthpower": _earth_power()
		"overheat": _overheat()
	return true

func _dark_pulse() -> void:
	var axis := Basis(lateral,forward,lateral.cross(forward))
	if elapsed < launch:
		_piece(sphere,surface,origin,Vector3.ONE*lerpf(.08,.38,charge_progress()))
		return
	if after < 0:
		var point := origin.lerp(aim,flight)
		var radius := lerpf(.22,1.15,smoothstep(0,.6,flight))
		# A dense folded pressure front, with a connected taper behind it.
		_piece(sphere,surface,point,Vector3(radius,.22,radius),axis)
		_piece(ring,hot,point-forward*.06,Vector3(radius*.85,.3,radius*.85),axis)
		_piece(sphere,surface,point-forward*.28,Vector3(radius*.7,.48,radius*.7),axis)
	impact_start_index = cursor
	if after >= 0 and hit:
		impact_drawn = true
		var grow := smoothstep(0,.24,after)
		var fade := 1.-smoothstep(.25,.85,after)
		_piece(sphere,surface,aim,Vector3(1.25,.25,1.25)*(1.+grow*.5)*fade,axis)
		_piece(ring,hot,aim,Vector3(1.1+grow, .18,1.1+grow)*fade,axis)

func _surf() -> void:
	var charge := charge_progress()
	var progress := flight if elapsed >= launch else 0.0
	var collapse := smoothstep(0,.6,after)
	var point := actor_ground.lerp(ground,progress)+forward*maxf(after,0)*.7
	var width := lerpf(1.1,2.8,smoothstep(0,.6,progress))
	var height := lerpf(.2,2.4,charge)*(1.-collapse*.85)
	_piece(wave,surface,point,Vector3(width,height,1.05+collapse),ground_basis)
	_piece(foam,hot,point,Vector3(width,height,1.05+collapse),ground_basis)
	# A single lower body joins the rolled lip to the moving water mass.
	_piece(sphere,water_body,point-forward*.65+Vector3.UP*.18,Vector3(width,.23,1.15)*(1.-collapse*.5))
	impact_start_index = cursor
	if after >= 0 and hit:
		impact_drawn = true
		for i in 5:
			var a := i*PI/4.
			var grow := sin(clampf(after/.75,0,1)*PI)
			_piece(plume,hot,ground+lateral*cos(a)*1.7,Vector3(.5,.6,.6)*grow,ground_basis*Basis(Vector3.UP,a))

func _blizzard() -> void:
	var radius := minf(field_radius*.78,4.5)
	var reach := minf(field_radius*.78,4.5)
	var advance := lerpf(-reach,reach,flight)
	var grow := lerpf(.18,1.,charge_progress())
	# Three overlapping billowing banks form one moving snow front.
	for i in 3:
		var point := field_center+forward*(advance-i*.55)+Vector3.UP*(1.0+i*.22)
		_piece(sphere,surface,point,Vector3(radius*(1.-i*.12),(1.1+i*.1)*grow,1.1+i*.6),ground_basis)
	# A few solid ice slivers indicate the direction inside the snow, not a sprite cloud.
	for i in 8:
		var p := fmod(elapsed/duration*2.+i*.618,1.)
		var point := field_center+forward*(advance+(p-.5)*1.6)+lateral*(i-3.5)*radius*.22+Vector3.UP*(.6+fmod(i*.73,1.6))
		_piece(slab,hot,point,Vector3(.04,.32,.06)*sin(p*PI)*alpha,ground_basis*Basis(Vector3.RIGHT,1.1))
	impact_start_index = cursor
	if after >= 0 and hit:
		impact_drawn = true
		_piece(ring,hot,ground+Vector3.UP*.08,Vector3(1.+after*2.,.12,1.+after*2.)*(1.-after))

func _earth_power() -> void:
	# The branching seam travels along the floor; only confirmed hits rupture it.
	var floor_start := actor_ground+Vector3.UP*.045
	var floor_end := ground+Vector3.UP*.045
	var previous := floor_start
	for i in 10:
		var p := (i+1)/10.*flight
		var point := floor_start.lerp(floor_end,p)+lateral*sin(i*2.7)*.16*flight
		_line(previous,point,.035*alpha,hot)
		if i%3==0:_line(point,point+lateral*(1 if i%2==0 else -1)*.45*flight,.018*alpha,hot)
		previous = point
	impact_start_index = cursor
	if after < 0 or not hit: return
	impact_drawn = true
	var rise := smoothstep(0,.18,after)*(1.-smoothstep(.4,1.,after))
	_piece(sphere,surface,ground+Vector3.UP*.3*rise,Vector3(1.4,.5,1.4)*rise)
	for i in 7:
		var a := i*TAU/7.
		var offset := Vector3(cos(a),0,sin(a))
		var point := ground+offset*(.5+rise*.7)+Vector3.UP*(.16+rise*(.35+(i%3)*.2))
		_piece(slab,stone,point,Vector3(.65,.8+(i%3)*.3,.55)*rise,Basis(Vector3.UP,a)*Basis(Vector3.FORWARD,.3+rise*.4))
		_piece(plume,hot,ground+offset*.65,Vector3(.9,1.1+(i%2)*.3,.9)*rise,Basis(Vector3.UP,a))
	_piece(ring,edge,ground+Vector3.UP*.07,Vector3(1.+after*2.3,.12,1.+after*2.3)*alpha)

func _overheat() -> void:
	var charge := charge_progress()
	if elapsed < launch:
		for i in 5:
			var a := i*TAU/5.
			_piece(plume,surface,actor_ground+Vector3(cos(a),0,sin(a))*.55,Vector3(.85,.45+charge*.6,.85)*charge,Basis(Vector3.UP,a))
		_piece(sphere,hot,origin,Vector3.ONE*(.06+charge*.25))
		return
	if after < 0:
		var point := origin.lerp(aim,flight)
		var radius := lerpf(.28,1.0,smoothstep(0,.7,flight))
		var axis := Basis(lateral,forward,lateral.cross(forward))
		_piece(sphere,surface,point,Vector3(radius,radius*.8,radius),axis)
		_piece(sphere,hot,point,Vector3.ONE*radius*.66)
		for i in 3:
			var a := i*TAU/3.
			_piece(plume,surface,point,Vector3(radius*.8,.7,radius*.8),axis*Basis(Vector3.RIGHT,PI)*Basis(Vector3.UP,a))
	impact_start_index = cursor
	if after >= 0 and hit:
		impact_drawn = true
		var expansion := smoothstep(0,.18,after)
		var fade := 1.-smoothstep(.25,.9,after)
		_piece(sphere,surface,aim,Vector3.ONE*(.55+expansion*1.1)*fade)
		_piece(sphere,hot,aim,Vector3.ONE*(.35+expansion*.7)*fade)
		for i in 4:
			var a := i*TAU/4.+.4
			var offset := (lateral*cos(a)+Vector3.UP*sin(a))*(.55+expansion*.65)*fade
			_piece(sphere,surface,aim+offset,Vector3.ONE*(.2+expansion*.36)*fade)
		for i in 5:
			var a := i*TAU/5.
			_piece(plume,surface,ground+Vector3(cos(a),0,sin(a))*.6,Vector3(.8,1.25,.8)*expansion*fade,Basis(Vector3.UP,a))
		_piece(ring,edge,ground+Vector3.UP*.08,Vector3(1.+expansion*1.5,.15,1.+expansion*1.5)*fade)

func _wave_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [-1.,1.]:
		for x in 48:
			for y in 24:
				for corner: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
					var u := (x+corner.x)/48.
					var v := (y+corner.y)/24.
					var span := pow(maxf(0.,sin(u*PI)),.4)
					var curl := v*PI*1.35
					tool.set_uv(Vector2(u,v))
					tool.add_vertex(Vector3((u-.5)*2.,sin(curl*.65)*span,-(1.-cos(curl))*.5+face*sin(v*PI)*.1))
	tool.generate_normals()
	return tool.commit()
