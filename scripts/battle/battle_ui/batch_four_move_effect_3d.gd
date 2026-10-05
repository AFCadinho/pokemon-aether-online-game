extends "res://scripts/battle/battle_ui/source_move_effect_3d.gd"
## Ten inspected SV sources, with authored 3D geometry on the shared native clock.
const MOVE_KEYS := ["shadowball", "sludgebomb", "focusblast", "moonblast", "iceshard", "poisonsting", "swift", "flashcannon", "magicalleaf", "waterpulse"]
const PALETTES := {
	"shadowball": [Color("21062e"), Color("9b38e8")],
	"sludgebomb": [Color("421052"), Color("bc58d4")],
	"focusblast": [Color("1368da"), Color("84f4ff")],
	"moonblast": [Color("939fff"), Color("ffb3ed")],
	"iceshard": [Color("549fff"), Color("d7f6ff")],
	"poisonsting": [Color("5b168d"), Color("d4a0ff")],
	"swift": [Color("ffa918"), Color("fff1a1")],
	"flashcannon": [Color("779ba9"), Color("e4fbff")],
	"magicalleaf": [Color("28871e"), Color("bdff75")],
	"waterpulse": [Color("1366cf"), Color("8eedff")],
}
const MASKS := {
	"shadowball": [preload("res://assets/battles/moves_3d/sv_shadowball/cpt_3_flow0017.png"), preload("res://assets/battles/moves_3d/sv_shadowball/upt_ew0247_smoke2301.png")],
	"sludgebomb": [preload("res://assets/battles/moves_3d/sv_sludgebomb/cpt_3_flow0015.png"), preload("res://assets/battles/moves_3d/sv_sludgebomb/cpt_3_flow0025.png")],
	"focusblast": [preload("res://assets/battles/moves_3d/sv_focusblast/cpt_4_flow0801s.png"), preload("res://assets/battles/moves_3d/sv_focusblast/cpt_0_aura0003s.png")],
	"moonblast": [preload("res://assets/battles/moves_3d/sv_moonblast/cpt_3_flow0703s.png"), preload("res://assets/battles/moves_3d/sv_moonblast/cpt_3_flow0703s.png")],
	"iceshard": [preload("res://assets/battles/moves_3d/sv_iceshard/cpt_0_ice0002.png"), preload("res://assets/battles/moves_3d/sv_iceshard/cpt_0_ice0002.png")],
	"swift": [preload("res://assets/battles/moves_3d/sv_swift/cpt_0_mark0004.png"), preload("res://assets/battles/moves_3d/sv_swift/cpt_3_blur0012.png")],
	"flashcannon": [preload("res://assets/battles/moves_3d/sv_flashcannon/cpt_3_flow0006.png"), preload("res://assets/battles/moves_3d/sv_flashcannon/cpt_3_flow0017.png")],
	"waterpulse": [preload("res://assets/battles/moves_3d/sv_waterpulse/cpt_4_flow0804.png"), preload("res://assets/battles/moves_3d/sv_waterpulse/cpt_3_flow0005.png")],
}
const ART := {
	"shadowball_hit": [preload("res://assets/battles/moves_3d/sv_shadowball/cpt_2_shock0010.png"), Vector3(0.65,0.25,1), 8.0, false],
	"sludgebomb_hit": [preload("res://assets/battles/moves_3d/sv_sludgebomb/cpt_2_shock0010.png"), Vector3(0.73,0.27,0.9), 8.0, false],
	"sludge_splash": [preload("res://assets/battles/moves_3d/sv_sludgebomb/cpt_2_water0013.png"), Vector3(0.72,0.25,0.9), 8.0, true],
	"focusblast_hit": [preload("res://assets/battles/moves_3d/sv_focusblast/cpt_0_flash0202s.png"), Vector3(0.7,0.95,1), 1.0, false],
	"focus_streak": [preload("res://assets/battles/moves_3d/sv_focusblast/cpt_0_shock0701s.png"), Vector3(1,0.65,0.15), 1.0, true],
	"moonblast_hit": [preload("res://assets/battles/moves_3d/sv_moonblast/cpt_0_circle0601.png"), Vector3(0.92,0.62,1), 1.0, true],
	"moon": [preload("res://assets/battles/moves_3d/sv_moonblast/upt_ew585_moon_07.png"), Vector3(0.62,0.75,1), 1.0, false],
	"moon_spark": [preload("res://assets/battles/moves_3d/sv_moonblast/cpt_0_flash0001.png"), Vector3(1,0.75,1), 1.0, false],
	"iceshard_hit": [preload("res://assets/battles/moves_3d/sv_iceshard/cpt_2_shock0003.png"), Vector3(0.55,0.85,1), 4.0, false],
	"ice_trail": [preload("res://assets/battles/moves_3d/sv_iceshard/cpt_2_fire0004.png"), Vector3(0.58,0.86,1), 8.0, false],
	"poisonsting_hit": [preload("res://assets/battles/moves_3d/sv_poisonsting/cpt_2_shock0008.png"), Vector3(0.76,0.35,1), 4.0, false],
	"poison_trail": [preload("res://assets/battles/moves_3d/sv_poisonsting/cpt_2_line0004.png"), Vector3(0.76,0.35,1), 8.0, false],
	"poison_bubble": [preload("res://assets/battles/moves_3d/sv_poisonsting/cpt_2_bubble0004.png"), Vector3(0.75,0.4,1), 8.0, true],
	"swift_spark": [preload("res://assets/battles/moves_3d/sv_swift/cpt_0_flash0002.png"), Vector3(1,0.9,0.4), 1.0, false],
	"swift_hit": [preload("res://assets/battles/moves_3d/sv_swift/cpt_0_flash0002.png"), Vector3(1,0.9,0.4), 1.0, false],
	"flashcannon_hit": [preload("res://assets/battles/moves_3d/sv_flashcannon/cpt_2_shock0011.png"), Vector3(0.8,0.95,1), 4.0, true],
	"flash_muzzle": [preload("res://assets/battles/moves_3d/sv_flashcannon/cpt_0_flash0005.png"), Vector3(0.8,0.95,1), 1.0, false],
	"magicalleaf_hit": [preload("res://assets/battles/moves_3d/sv_magicalleaf/cpt_2_shock0008.png"), Vector3(0.7,1,0.35), 4.0, false],
	"magic_glow": [preload("res://assets/battles/moves_3d/sv_magicalleaf/cpt_0_obj2201.png"), Vector3(0.8,1,0.45), 1.0, false],
	"magic_debris": [preload("res://assets/battles/moves_3d/sv_magicalleaf/cpt_2_obj0006.png"), Vector3(0.6,1,0.3), 4.0, true],
	"waterpulse_hit": [preload("res://assets/battles/moves_3d/sv_waterpulse/cpt_2_shock0003.png"), Vector3(0.35,0.75,1), 4.0, false],
	"pulse_bubble": [preload("res://assets/battles/moves_3d/sv_waterpulse/cpt_2_bubble0005.png"), Vector3(0.65,0.9,1), 8.0, true],
}
var surface_material: ShaderMaterial
var gold_material: StandardMaterial3D
var ring := TorusMesh.new()
var shape: ArrayMesh
var leaf_materials: Array[ShaderMaterial] = []
var launch_origin := Vector3.ZERO
var launched := false

func _sprite_values(id: String) -> Array:
	return ART[id] if ART.has(id) else super._sprite_values(id)

func _build_surface() -> void:
	# The source moon mask includes a gray square border; crop it in the shader
	# while retaining the original packaged pixels and source provenance.
	sprite_shader.code = sprite_shader.code.replace("void fragment() {", "uniform bool moon_disc = false;\nvoid fragment() {")
	sprite_shader.code = sprite_shader.code.replace("* opacity;", "* opacity;\n\tif (moon_disc) { ALPHA *= 1.0 - smoothstep(0.43, 0.46, length(UV - vec2(0.5))); }")
	ring.inner_radius = 0.83
	ring.outer_radius = 1.0
	ring.rings = 24
	ring.ring_segments = 8
	gold_material = _material(Color("ffbd52"), 0.85)
	if not MASKS.has(key): return
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_never;
uniform sampler2D surface_mask : filter_linear, repeat_enable;
uniform sampler2D detail_mask : filter_linear, repeat_enable;
uniform vec4 low_color : source_color;
uniform vec4 high_color : source_color;
uniform float seconds = 0.0;
uniform float opacity = 1.0;
uniform float motion = 1.0;
void fragment() {
	vec2 drift = vec2(seconds * 0.45, seconds * -0.3) * motion;
	float noise = texture(surface_mask, UV * vec2(2.0, 1.0) + drift).r;
	float detail = texture(detail_mask, UV * 2.0 - drift * 1.7).r;
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.0);
	ALBEDO = mix(low_color.rgb, high_color.rgb, clamp(noise * 0.65 + detail * 0.2 + rim * 0.3, 0.0, 1.0));
	ALPHA = opacity;
}
"""
	surface_material = ShaderMaterial.new()
	surface_material.shader = shader
	surface_material.set_shader_parameter("surface_mask", MASKS[key][0])
	surface_material.set_shader_parameter("detail_mask", MASKS[key][1])
	surface_material.set_shader_parameter("low_color", PALETTES[key][0])
	surface_material.set_shader_parameter("high_color", PALETTES[key][1])
	if key in ["iceshard","swift"]: surface_material.set_shader_parameter("motion", 0.0)

func _draw_source_move(from: Vector3, to: Vector3, right: Vector3, up: Vector3) -> bool:
	if gold_material == null: _build_surface()
	var facing := Basis(right,up,right.cross(up))
	var travel := (elapsed-launch)/maxf(impact-launch,0.01)
	var after := (elapsed-impact)/maxf(duration*0.22,0.01)
	if surface_material != null: surface_material.set_shader_parameter("seconds", elapsed)
	edge.albedo_color.a = 0.85*(1.0-clampf(after,0,1))
	gold_material.albedo_color.a = 0.85*(1.0-clampf(after,0,1))
	if travel >= 0 and not launched:
		launch_origin = from
		launched = true
	# Flying objects leave their launch point; later head motion cannot drag them.
	var origin := launch_origin if launched else from
	var forward := (to-origin).normalized()
	var side := forward.cross(Vector3.UP if absf(forward.y)<0.95 else Vector3.RIGHT).normalized()
	var vertical := side.cross(forward).normalized()
	var path_basis := Basis(side,forward,side.cross(forward))
	match key:
		"shadowball", "sludgebomb", "focusblast", "moonblast":
			_draw_orb(origin,to,travel,after,facing,path_basis)
		"iceshard", "poisonsting", "swift", "magicalleaf":
			_draw_objects(origin,to,travel,facing,side,vertical,path_basis)
		"flashcannon": _draw_cannon(to,travel,after,facing)
		"waterpulse": _draw_pulse(origin,to,travel,facing,path_basis)
	if hit and after >= 0 and after < 1: _draw_hit(to,after,facing,path_basis)
	return true

func _draw_orb(from: Vector3, to: Vector3, travel: float, _after: float, facing: Basis, path_basis: Basis) -> void:
	var charge := clampf(elapsed/maxf(launch,0.01),0,1)
	if elapsed<=0: return
	if key=="moonblast" and travel<0.6:
		_source_sprite(from+Vector3.UP*(1.35+0.3*(presentation_scale-1.0)),0.85,"moon",0,sin(charge*PI*0.5)*(1.0-clampf(travel/0.6,0,1))*0.7,facing)
		if cursor>0 and sprite_keys[cursor-1]=="moon":
			sprite_materials[cursor-1].set_shader_parameter("moon_disc",true)
	if travel>=1: return
	var t := maxf(travel,0)
	var point := from.lerp(to,t)
	if key=="sludgebomb": point.y += sin(t*PI)*0.6
	# Let the moon appear first, build the orb, then hold it briefly at full size.
	var orb_charge := clampf((charge-0.25)/0.65,0,1) if key=="moonblast" else charge
	var radius := (0.34 if key=="sludgebomb" else 0.29) * (orb_charge if travel<0 else 1.0)
	var orb_scale := Vector3.ONE * radius
	if key=="sludgebomb": orb_scale *= Vector3(1.0+sin(elapsed*15)*0.12,0.9,1.1)
	_piece(sphere,surface_material,point,orb_scale)
	if key=="focusblast":
		for angle in [0.55,-0.65]:
			_piece(ring,gold_material,point,Vector3.ONE*radius*1.28,path_basis*Basis(Vector3.RIGHT,angle)*Basis(Vector3.UP,elapsed*6))
		_source_sprite(point,radius*2.4,"focus_streak",0,0.65,facing,elapsed*5)
	if key=="shadowball":
		for i in 2:
			_piece(ring,edge,point,Vector3.ONE*radius*(1.2+i*0.2),path_basis*Basis(Vector3.RIGHT,elapsed*3+i*1.2))
	if travel<0: return
	for i in 5:
		var p := maxf(t-float(i+1)*0.035,0)
		var behind := from.lerp(to,p)
		var size := radius*(0.52-float(i)*0.075)
		if key=="sludgebomb":
			behind.y += sin(p*PI)*0.6 - float(i)*0.035
			_piece(sphere,surface_material,behind,Vector3.ONE*size)
		elif key=="moonblast":
			behind += Vector3(sin(i*2.4),cos(i*2.4),sin(i))*0.13
			_source_sprite(behind,0.26,"moon_spark",0,0.9-float(i)*0.13,facing,elapsed+i)
		else:
			_piece(sphere,surface_material,behind,Vector3.ONE*size)

func _draw_objects(from: Vector3, to: Vector3, travel: float, facing: Basis, side: Vector3, vertical: Vector3, path_basis: Basis) -> void:
	if travel<0 or travel>=1: return
	if shape==null:
		if key=="swift": _build_star()
		elif key=="magicalleaf": _build_leaves()
		elif key=="iceshard": _build_crystal()
	var count := 3 if key=="iceshard" else 5
	for i in count:
		var delay := float(i)*0.045
		var t := (travel-delay)/(1.0-delay)
		if t<0: continue
		var angle := float(i)*TAU/float(count)
		var spread := 0.18 if key=="poisonsting" else (0.68 if key=="magicalleaf" else 0.4)
		var curve := sin(t*PI)*spread
		if key=="magicalleaf": angle += t*TAU*0.7
		var point := from.lerp(to,t)+(side*cos(angle)+vertical*sin(angle))*curve
		match key:
			"iceshard":
				_piece(shape,surface_material,point,Vector3(0.12,0.42,0.12),path_basis*Basis(Vector3.UP,elapsed*5+i))
				_source_sprite(point-(to-from).normalized()*0.22,0.35,"ice_trail",t,0.7,facing,angle)
			"poisonsting":
				_piece(tooth,edge,point,Vector3(0.045,0.52,0.045),path_basis)
				_source_sprite(point,0.58,"poison_trail",minf(t*0.7,0.7),0.85,path_basis,0,Vector2(0.3,1))
			"swift":
				var orientation := Basis(side,vertical,side.cross(vertical))*Basis(Vector3.FORWARD,t*6+angle)
				orientation *= Basis(Vector3.RIGHT,sin(t*PI)*0.45)
				_piece(shape,surface_material,point,Vector3.ONE*0.3,orientation)
				_source_sprite(point,0.35,"swift_spark",0,0.6,facing,angle)
			"magicalleaf":
				var orientation := Basis(side,vertical,side.cross(vertical))*Basis(Vector3.FORWARD,angle+t*5)
				orientation *= Basis(Vector3.RIGHT,sin(t*TAU+angle)*0.6)
				_piece(shape,leaf_materials[i],point,Vector3.ONE*0.55,orientation)
				_source_sprite(point,0.65,"magic_glow",0,0.55,orientation,0,Vector2(0.6,1))

func _draw_cannon(to: Vector3, travel: float, after: float, facing: Basis) -> void:
	var fade := 1.0-clampf(after/0.65,0,1)
	var charge := clampf(elapsed/maxf(launch,0.01),0,1)
	for origin: Vector3 in emission_sources:
		if travel<0:
			_source_sprite(origin,charge*0.7,"flash_muzzle",0,charge*0.75,facing,elapsed*4)
		elif after<0.65:
			var tip := origin.lerp(to,clampf(travel,0,1))
			_line(origin,tip,0.095*fade,surface_material)
			_line(origin,tip,0.025*fade,core)
			_source_sprite(origin,0.65,"flash_muzzle",0,fade,facing,elapsed*4)
			var direction := (to-origin).normalized()
			var side := direction.cross(Vector3.UP if absf(direction.y)<0.95 else Vector3.RIGHT).normalized()
			var orientation := Basis(side,direction,side.cross(direction))
			for i in 4:
				var t := fmod(maxf(travel,0)+i*0.25,1)*clampf(travel,0,1)
				_piece(ring,surface_material,origin.lerp(to,t),Vector3.ONE*0.15*fade,orientation)

func _draw_pulse(from: Vector3, to: Vector3, travel: float, facing: Basis, path_basis: Basis) -> void:
	if travel<0 or travel>=1: return
	for i in 3:
		var delay := i*0.09
		var t := (travel-delay)/(1.0-delay)
		if t<0: continue
		var point := from.lerp(to,t)
		var size := 0.23+sin(t*PI)*0.28+float(i)*0.08
		_piece(ring,surface_material,point,Vector3.ONE*size,path_basis)
		for j in 3:
			var angle := j*TAU/3.0+elapsed*2
			var offset := (path_basis.x*cos(angle)+path_basis.z*sin(angle))*size
			_source_sprite(point+offset,0.12,"pulse_bubble",t,0.7,facing)

func _draw_hit(to: Vector3, after: float, facing: Basis, path_basis: Basis) -> void:
	var fade := 1.0-after
	_source_sprite(to,1.05+after*0.9,key+"_hit",after,fade,facing,after*0.4)
	match key:
		"sludgebomb":
			_source_sprite(to,1.6,"sludge_splash",after,fade,facing)
			for i in 6:
				var offset := Vector3(cos(i*2.4),sin(i*2.4),sin(i))*after*0.7
				offset.y -= after*after*0.5
				_piece(sphere,surface_material,to+offset,Vector3.ONE*0.1*fade)
		"focusblast", "moonblast", "waterpulse", "shadowball":
			_piece(ring,gold_material if key=="focusblast" else edge,to,Vector3.ONE*(0.15+after*0.9),path_basis)
			if key=="moonblast":
				for i in 5:
					_source_sprite(to+Vector3(cos(i*2.4),sin(i*2.4),sin(i))*after*0.7,0.35,"moon_spark",0,fade,facing)
		"poisonsting": _source_sprite(to,0.8,"poison_bubble",after,fade*0.65,facing)
		"magicalleaf": _source_sprite(to,1.1,"magic_debris",after,fade,facing)

func _build_crystal() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 5:
		var a := Vector3(cos(i*TAU/5),-0.25,sin(i*TAU/5))
		var b := Vector3(cos((i+1)*TAU/5),-0.25,sin((i+1)*TAU/5))
		for vertex: Vector3 in [Vector3.UP,a,b,Vector3.DOWN,b,a]:
			surface.set_uv(Vector2(vertex.x*0.5+0.5,vertex.y*0.5+0.5))
			surface.add_vertex(vertex)
	surface.generate_normals()
	shape = surface.commit()

func _build_star() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		var angle_a := PI*0.5+i*TAU/10
		var angle_b := PI*0.5+(i+1)*TAU/10
		var a := Vector3(cos(angle_a),sin(angle_a),0)*(1.0 if i%2==0 else 0.45)
		var b := Vector3(cos(angle_b),sin(angle_b),0)*(1.0 if i%2==1 else 0.45)
		for depth in [-0.12,0.12]:
			for vertex: Vector3 in [Vector3(0,0,depth),a+Vector3(0,0,depth),b+Vector3(0,0,depth)]:
				surface.set_uv(Vector2(vertex.x*0.5+0.5,0.5-vertex.y*0.5))
				surface.add_vertex(vertex)
		for vertex: Vector3 in [a+Vector3(0,0,-0.12),b+Vector3(0,0,-0.12),b+Vector3(0,0,0.12),a+Vector3(0,0,-0.12),b+Vector3(0,0,0.12),a+Vector3(0,0,0.12)]:
			surface.set_uv(Vector2(vertex.x*0.5+0.5,0.5-vertex.y*0.5))
			surface.add_vertex(vertex)
	surface.generate_normals()
	shape = surface.commit()
	# Both star faces and their thin sides must remain visible during tumbling.
	var shader := surface_material.shader.duplicate() as Shader
	shader.code = shader.code.replace("cull_back", "cull_disabled")
	surface_material.shader = shader

func _build_leaves() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 8:
		for col in 4:
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var uv := Vector2((col+corner.x)/4.0,(row+corner.y)/8.0)
				surface.set_uv(uv)
				surface.add_vertex(Vector3((uv.x-0.5)*0.6,0.5-uv.y,sin(uv.y*PI)*0.12+absf(uv.x-0.5)*0.14))
	surface.generate_normals()
	shape = surface.commit()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D leaf_texture : filter_linear, repeat_disable;
uniform vec4 tint : source_color;
void fragment() {
	vec4 leaf = texture(leaf_texture, UV);
	ALBEDO = tint.rgb * (0.2 + leaf.r * 0.8);
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
}
"""
	for color in [Color("9cff65"),Color("60eee7"),Color("e9bdff"),Color("fff07b"),Color("b4ff93")]:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("leaf_texture",preload("res://assets/battles/moves_3d/sv_magicalleaf/cpt_0_obj0203.png"))
		mat.set_shader_parameter("tint",color)
		leaf_materials.append(mat)
