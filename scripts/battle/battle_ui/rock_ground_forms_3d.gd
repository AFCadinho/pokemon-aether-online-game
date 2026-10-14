extends RefCounted
## Authored solid geometry; all motion and fades follow the native move clock.
const KEYS := ["rocktomb","stoneedge","rockblast","ancientpower","bulldoze","precipiceblades"]
const Rocks = preload("res://scripts/battle/battle_ui/rock_slide_forms_3d.gd")
var rocks := Rocks.new()
var spike: ArrayMesh
var heat := StandardMaterial3D.new()
var impact_start_index := 0
var forward := Vector3.FORWARD
var side := Vector3.RIGHT

func _init() -> void:
	# This material belongs to this effect; the approved Rock Slide stays untouched.
	rocks.stone.shader = rocks.stone.shader.duplicate()
	rocks.stone.shader.code = rocks.stone.shader.code.replace("uniform float opacity", "uniform vec3 tone = vec3(1.);\nuniform float opacity").replace("ROUGHNESS = .96;", "ALBEDO *= tone;\n ROUGHNESS = .96;")
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 5:
		var a := Vector3(cos(i*TAU/5.),0,sin(i*TAU/5.))
		var b := Vector3(cos((i+1)*TAU/5.),0,sin((i+1)*TAU/5.))
		Rocks._triangle(tool,a,Vector3(.22,1,-.16),b)
		Rocks._triangle(tool,Vector3.ZERO,b,a)
	spike = tool.commit()
	heat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	heat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	heat.albedo_color = Color("ff963d")
	heat.emission_enabled = true
	heat.emission = Color("e85619")
	heat.emission_energy_multiplier = 1.5

func draw(e: Node) -> void:
	forward = e.ground-e.actor_ground
	forward.y = 0
	forward = forward.normalized() if forward.length_squared()>.001 else Vector3.FORWARD
	side = forward.cross(Vector3.UP)
	var fade := 1.-smoothstep(.4,.95,e.after)
	rocks.stone.set_shader_parameter("tone",Vector3(.48,.48,.52) if e.key=="precipiceblades" else Vector3.ONE)
	rocks.stone.set_shader_parameter("opacity",fade)
	rocks.dust.set_shader_parameter("seconds",e.elapsed/e.duration*float(e.recipe.duration_seconds))
	rocks.dust.set_shader_parameter("opacity",fade*.55)
	rocks.crack.albedo_color.a = fade
	heat.albedo_color.a = fade*.8
	if e.key in ["rockblast","ancientpower"]:
		_volley(e,e.key=="ancientpower")
	elif e.flight<0:
		for i in 4:
			var angle := i*TAU/4.+.5
			var q: float = e.charge_progress()
			rocks._rock(e,e.actor_ground+Vector3(cos(angle),0,sin(angle))*.85,Vector3(.25,.12,.22)*q,Basis(Vector3.UP,angle),q*.12)
	elif e.key=="rocktomb": _tomb(e)
	elif e.key=="bulldoze": _wave(e)
	else: _fault(e,e.key=="precipiceblades")
	impact_start_index = e.cursor
	if not e.impact_drawn: return
	if e.key in ["stoneedge","precipiceblades"]: _crown(e,e.key=="precipiceblades")
	_impact(e,fade)

func _tomb(e: Node) -> void:
	for i in 4:
		var landing: float = e.impact+(e.duration-e.impact)*i*.04
		var p := clampf((e.elapsed-e.launch)/(landing-e.launch),0,1)
		if p>=1 and not e.hit: continue
		# Leave the camera-facing side open so the victim remains readable.
		var angle := .45+i*1.15
		var point: Vector3 = e.ground+(side*cos(angle)+forward*sin(angle))*1.2
		var size := Vector3(.58,1.05,.52)*smoothstep(0,.12,e.flight)
		rocks._rock(e,point,size,Basis(Vector3.UP,angle),Rocks.fall_height(e)*(1.-p*p))

func _volley(e: Node, ancient: bool) -> void:
	var count := 6 if ancient else 5
	for i in count:
		var angle: float = i*TAU/count+e.elapsed*1.6
		var departure: float = e.launch+(e.impact-e.launch)*i*.14
		var arrival: float = e.impact+(e.duration-e.impact)*i*.11
		var p := clampf((e.elapsed-departure)/(arrival-departure),0,1)
		if p>=1: continue
		var orbit := (side*cos(angle)+Vector3.UP*sin(angle))*.85 if ancient else side*(i-2)*.13
		var q: float = e.charge_progress() if e.flight<0 else 1.
		var point: Vector3 = e.origin.lerp(e.aim,p)+orbit*(1.-p)*q
		point += Vector3.UP*sin(p*PI)*(.85 if ancient else .4)
		var size := Vector3(.36,.42,.32)*q*(1. if ancient else lerpf(.4,1.,smoothstep(0,.25,p)))
		if ancient: size *= 1.2
		var pose := Basis(Vector3(1,.4,.3).normalized(),i+e.elapsed*4.)
		# Limit the full rotating mesh at low anchors without moving its aim.
		point.y = maxf(point.y,lerpf(e.actor_ground.y,e.ground.y,p)+.03)
		var basis := pose*Basis.from_scale(size)
		var depth := 0.
		for corner in 8: depth=maxf(depth,-(basis*rocks.boulder.get_aabb().get_endpoint(corner)).y)
		var clearance: float = point.y-lerpf(e.actor_ground.y,e.ground.y,p)-.015
		basis = Basis.from_scale(Vector3(1,minf(1.,clearance/maxf(.001,depth)),1))*basis
		e._piece(rocks.boulder,rocks.stone,point,Vector3.ONE,basis)
	if ancient and e.flight<0:
		e._piece(e.ring,heat,e.actor_ground+Vector3.UP*.05,Vector3(.95,.08,.95)*e.charge_progress())

func _wave(e: Node) -> void:
	if e.flight>=1: return
	var p := clampf(e.flight,0,1)
	var base: Vector3 = e.actor_ground.lerp(e.ground,p)
	var grow := smoothstep(0,.12,p)
	for i in 9:
		var x := (i-4)*.43
		var point := base+side*x-forward*absf(x)*.18
		rocks._rock(e,point,Vector3(.42,.24,.48)*grow,Basis(Vector3.UP,i*.8),sin(p*PI)*.12)
	for i in 3:
		_dust(e,base+side*(i-1)*1.15-forward*.5,Vector3(.9,.22,.7)*grow)

func _fault(e: Node, volcanic: bool) -> void:
	var p := clampf(e.flight,0,1)
	for i in 6:
		var fraction := (i+1)/7.
		if p<fraction: continue
		var point: Vector3 = e.actor_ground.lerp(e.ground,fraction)
		var grow := smoothstep(fraction,minf(1.,fraction+.18),p)
		var material: Material = heat if volcanic else rocks.crack
		e._line(point-side*.45+Vector3.UP*.04,point+side*.45+Vector3.UP*.04,.025,material)
		if volcanic:
			e._piece(spike,rocks.stone,point+Vector3.UP*.025,Vector3(.38,(.5+fraction)*grow,.4),Basis(Vector3.UP,i*1.3))

func _crown(e: Node, volcanic: bool) -> void:
	for i in 7:
		var angle := i*TAU/7.+.25
		var grow := smoothstep(i*.012,i*.012+.13,e.after)
		var point: Vector3 = e.ground+(side*cos(angle)+forward*sin(angle))*1.45
		var height := (3.+(i%3)*.55) if volcanic else (1.6+(i%3)*.45)
		var size := Vector3(.6 if volcanic else .42,height*grow,.48 if volcanic else .38)
		var pose := Basis(Vector3.UP,angle)
		e._piece(spike,rocks.stone,point+Vector3.UP*.025,size,pose)
		if volcanic:
			# Exposed heated edges follow the sloping surface, not the hidden centre.
			for edge in [0,2]:
				var base := Vector3(cos(edge*TAU/5.),0,sin(edge*TAU/5.))*1.06
				var tip := base.lerp(Vector3(.22,1,-.16),.8)
				e._line(point+Vector3.UP*.05+pose*(base*size),point+Vector3.UP*.05+pose*(tip*size),.022,heat)

func _impact(e: Node, fade: float) -> void:
	var grow := smoothstep(0,.35,e.after)
	var spread := 1.7 if e.key in ["bulldoze","precipiceblades"] else 1.25
	for i in 3:
		_dust(e,e.ground+side*(i-1)*grow*spread,Vector3(.6+grow*.6,(.15+grow*.22)*fade,.65+grow*.55))
	for i in 6:
		var angle := i*TAU/6.+.3
		var radial := side*cos(angle)+forward*sin(angle)
		var point: Vector3 = e.ground+radial*(.5+grow*spread)
		rocks._rock(e,point,Vector3(.17,.2,.13)*fade,Basis(radial.cross(Vector3.UP),i+e.after*5.),sin(clampf(e.after/.75,0,1)*PI)*.6)

func _dust(e: Node, point: Vector3, size: Vector3) -> void:
	# Account for the haze shader's small vertex displacement as well as its mesh.
	e._piece(e.sphere,rocks.dust,point+Vector3.UP*(size.y*1.1+.04),size)
