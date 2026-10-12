extends RefCounted
## Shared construction, not shared choreography. Callers own paths, native time,
## emitter scale and confirmed outcomes. No TIME, random particles or raster masks.
const Volumes = preload("res://scripts/battle/battle_ui/move_volume_forms_3d.gd")
const SURFACE = preload("res://scripts/battle/battle_ui/move_cinematic_surface_3d.gdshader")
static var shared_wake: ArrayMesh
static var shared_blade: ArrayMesh
var skin: ShaderMaterial
var haze: ShaderMaterial
var trail: ShaderMaterial
var vortex: ShaderMaterial
var wake: ArrayMesh
var blade: ArrayMesh
var element := ""

func _init(tint: Color, type: String) -> void:
	element = type
	skin = material(tint, type, 0)
	haze = material(tint, type, 1)
	trail = material(tint, type, 2)
	vortex = material(tint, type, 3)
	if shared_wake == null: shared_wake = Volumes.swept_mesh(false)
	if shared_blade == null: shared_blade = _blade()
	wake = shared_wake
	blade = shared_blade

static func material(tint: Color, type: String, mode: int) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = SURFACE
	result.set_shader_parameter("tint", tint)
	result.set_shader_parameter("mode", mode)
	result.set_shader_parameter("kind", 1 if type=="fire" else 2 if type in ["water","ice"] else 3 if type in ["dark","ghost","poison"] else 4 if type in ["rock","ground","steel"] else 0)
	result.set_shader_parameter("luminous", .1 if type in ["rock","ground","steel","normal","fighting"] else .65)
	return result

func sample(seconds: float, opacity: float) -> void:
	for mat in [skin,haze,trail,vortex]:
		mat.set_shader_parameter("seconds", seconds)
		mat.set_shader_parameter("opacity", clampf(opacity,0,1))

func plume(effect: Node, point: Vector3, dimensions: Vector3, pose := Basis.IDENTITY) -> void:
	effect._piece(effect.sphere,haze,point,dimensions,pose)

func tail(effect: Node, point: Vector3, backwards: Vector3, radius: float, length_value: float) -> void:
	if radius < .001 or length_value < .001: return
	# Width receives artistic scale once; measured world length stays exact.
	effect._piece(wake,trail,point,Vector3(radius,length_value,radius),Volumes.along(backwards),true)

func impact(effect: Node, point: Vector3, after: float, size_value: float, pose: Basis, contact: bool) -> void:
	if not effect.hit or after<0: return
	var fade := 1.-smoothstep(.1,.72,after)
	if fade < .001: return
	var grow := smoothstep(0,.23,after)
	var size := size_value*(.18+grow*.72)*fade
	if contact:
		# A short compressed shock, leaving fists, claws and the victim readable.
		effect._piece(effect.sphere,skin,point,Vector3(size,.13*size,size),pose)
		return
	var physical := element in ["rock","ground","steel","ice"]
	if physical:
		# A joined fracture crown, rather than unrelated debris travelling away.
		for i in 5:
			var a := i*TAU/5.
			var offset := (pose.x*cos(a)+pose.z*sin(a))*size*.48
			effect._piece(effect.tooth,skin,point+offset,Vector3(.24,.7,.24)*size,pose*Basis(Vector3.RIGHT,.6)*Basis(Vector3.UP,a))
	else:
		plume(effect,point,Vector3.ONE*size*1.25)
		effect._piece(effect.sphere,skin,point,Vector3(size,size*.55,size)*(.75-grow*.35),pose)
		for i in 3:
			var a := i*TAU/3.
			var offset := (pose.x*cos(a)+pose.z*sin(a))*size*.55
			plume(effect,point+offset,Vector3.ONE*size*.65)

func aura(effect: Node, point: Vector3, radius: float, phase: float, inward := false) -> void:
	# Three broad overlapping curved leaves make one ascending/contracting aura.
	for i in 3:
		var turn := phase*TAU*(.35 if inward else .65)+i*TAU/3.
		var size := radius*(1.25-phase*.25 if inward else .8+phase*.25)
		effect._piece(blade,trail,point,Vector3(size,size*1.15,size),Basis(Vector3.UP,turn)*Basis(Vector3.FORWARD,.25))

static func _blade() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 32:
		for j in 8:
			for c: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var p := (i+c.x)/32.
				var a := lerpf(-1.4,1.4,p)
				var roll := (j+c.y)*TAU/8.
				var radius := .85+cos(roll)*.15*sin(p*PI)
				tool.set_uv(Vector2(p,(j+c.y)/8.))
				tool.add_vertex(Vector3(cos(a)*radius,sin(a)*radius,sin(roll)*sin(p*PI)*.07))
	tool.generate_normals()
	return tool.commit()
