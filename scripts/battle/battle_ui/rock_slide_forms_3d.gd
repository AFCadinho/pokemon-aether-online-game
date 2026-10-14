extends RefCounted
## Five heavy falling rocks, sampled entirely from the native move clock.
const OFFSETS := [Vector2.ZERO, Vector2(-.95,.4), Vector2(.9,-.45), Vector2(-.55,-.85), Vector2(.6,.85)]
var boulder: ArrayMesh
var stone: ShaderMaterial
var dust: ShaderMaterial
var crack: StandardMaterial3D
var impact_start_index := 0

func _init() -> void:
	boulder = _boulder_mesh()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform float opacity = 1.;
varying vec3 local_point;
void vertex() { local_point = VERTEX; }
void fragment() {
 float layers = .5+.5*sin(local_point.y*19.+sin(local_point.x*8.+local_point.z*5.)*1.7);
 float grain = .5+.5*sin(dot(local_point,vec3(37.,53.,29.)));
 ALBEDO = mix(vec3(.19,.14,.095),vec3(.48,.38,.25),.3+layers*.45+grain*.12);
 ROUGHNESS = .96;
 ALPHA = opacity;
}
"""
	stone = ShaderMaterial.new()
	stone.shader = shader
	dust = preload("res://scripts/battle/battle_ui/move_cinematic_forms_3d.gd").material(Color("b39a78"),"rock",1)
	dust.set_shader_parameter("luminous",0.0)
	crack = StandardMaterial3D.new()
	crack.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	crack.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crack.albedo_color = Color("423529")

static func fall_height(effect: Node) -> float:
	return maxf(4.4,effect.aim.y-effect.ground.y+3.0)

static func recoil(after: float) -> Vector2:
	var weight := smoothstep(0,.025,after)*(1.-smoothstep(.06,.38,after))
	return Vector2(sin(after*65.)*.07,sin(after*45.)*.055)*weight

func draw(effect: Node) -> void:
	var forward: Vector3 = effect.ground-effect.actor_ground
	forward.y = 0
	if forward.is_zero_approx(): forward = Vector3.FORWARD
	forward = forward.normalized()
	var side := forward.cross(Vector3.UP)
	var after: float = effect.after
	var fade := 1.-smoothstep(.38,.9,after)
	stone.set_shader_parameter("opacity",fade)
	dust.set_shader_parameter("seconds",effect.elapsed/effect.duration*float(effect.recipe.duration_seconds))
	dust.set_shader_parameter("opacity",fade*.7)
	crack.albedo_color.a = fade
	if effect.flight < 0:
		# A few rising stone plates accompany the caster's wind-up.
		var q: float = effect.charge_progress()
		for i in 3:
			var a := i*TAU/3.
			var point: Vector3 = effect.actor_ground+Vector3(cos(a),0,sin(a))*.65
			_rock(effect,point,Vector3(.19,.22,.17)*q,Basis(Vector3.UP,a),.18*q)
		impact_start_index = effect.cursor
		return
	var appear := smoothstep(0,.14,effect.flight)
	for i in OFFSETS.size():
		var landing: float = effect.impact+(effect.duration-effect.impact)*i*.045
		var progress := clampf((effect.elapsed-effect.launch)/maxf(.01,landing-effect.launch),0,1)
		if progress>=1 and not effect.hit: continue
		var offset: Vector2 = OFFSETS[i]
		var point: Vector3 = effect.ground+side*offset.x+forward*offset.y
		point -= forward*(1.-progress)*.65
		var size := 1.0 if i==0 else .7+(i%3)*.1
		var pose := Basis(Vector3(1,.3,.5).normalized(),i*1.7+progress*1.15)
		_rock(effect,point,Vector3(.74,.83,.65)*size*appear,pose,fall_height(effect)*(1.-progress*progress))
	impact_start_index = effect.cursor
	if not effect.impact_drawn: return
	var grow := smoothstep(0,.3,after)
	# Connected low dust rolls leave the upper body and falling silhouettes readable.
	for i in 3:
		var offset := side*(i-1)*(.45+grow*.6)
		var height := (.16+grow*.28)*fade
		effect._piece(effect.sphere,dust,effect.ground+offset+Vector3.UP*(height+.04),Vector3(.55+grow*.6,height,.55+grow*.7))
	var radius := .65+grow*1.7
	effect._piece(effect.ring,dust,effect.ground+Vector3.UP*.08,Vector3(radius,.18,radius))
	for i in 6:
		var angle := i*TAU/6.+.2
		var radial := Vector3(cos(angle),0,sin(angle))
		var point: Vector3 = effect.ground+radial*(.5+grow*1.55)
		var bounce := sin(clampf(after/.65,0,1)*PI)*(.3+(i%2)*.25)
		_rock(effect,point,Vector3(.15,.19,.12)*(1.-smoothstep(.55,.95,after)),Basis(radial.cross(Vector3.UP),after*5.+i),bounce)
		var end: Vector3 = effect.ground+radial*(.6+grow*1.05)+Vector3.UP*.035
		var bend: Vector3 = effect.ground+radial*.5+side*sin(i*2.4)*.13+Vector3.UP*.035
		effect._line(effect.ground+radial*.2+Vector3.UP*.035,bend,.018*fade,crack)
		effect._line(bend,end,.024*fade,crack)

func _rock(effect: Node, floor_point: Vector3, size: Vector3, pose: Basis, height: float) -> void:
	# Rotating and shrinking stones rest on their actual bounds, also on raised arenas.
	var bounds := boulder.get_aabb()
	var transform := pose*Basis.from_scale(size)
	var depth := 0.0
	for corner in 8: depth=maxf(depth,-(transform*bounds.get_endpoint(corner)).y)
	effect._piece(boulder,stone,floor_point+Vector3.UP*(depth+height+.025),size,pose)

static func _boulder_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for row in 3:
		var ring := PackedVector3Array()
		for i in 7:
			var angle := i*TAU/7.+row*.14
			var radius: float = [.62,1.,.7][row]*(.88+.12*sin(i*2.7+row))
			ring.append(Vector3(cos(angle)*radius,[-.72,.02,.64][row]+sin(i*2.3+row)*.13,sin(angle)*radius))
		rings.append(ring)
	for i in 7:
		var next := (i+1)%7
		_triangle(tool,Vector3(0,-.95,0),rings[0][i],rings[0][next])
		_triangle(tool,Vector3(.12,.96,-.1),rings[2][next],rings[2][i])
		for row in 2:
			_triangle(tool,rings[row][i],rings[row+1][i],rings[row+1][next])
			_triangle(tool,rings[row][i],rings[row+1][next],rings[row][next])
	return tool.commit()

static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b-a).cross(c-a).normalized()
	if normal.dot((a+b+c)/3.)<0: normal=-normal
	for point in [a,b,c]:
		tool.set_normal(normal)
		tool.add_vertex(point)
