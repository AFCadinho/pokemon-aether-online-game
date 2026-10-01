extends "res://scripts/battle/arenas/shared/geometry.gd"
## Shared by client and visual review.

func _finish(color: Color, glow := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.42
	mat.metallic = 0.35
	if glow > 0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat

func _box(parent: Node3D, material: Material, pos: Vector3, size: Vector3) -> MeshInstance3D:
	var node := _put(parent, BoxMesh.new(), material, pos, size)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _wordmark(parent: Node3D, pos: Vector3, width: float) -> void:
	var texture: Texture2D = load("res://assets/ui/pokeaether_text_logo.png")
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/battle/arenas/generic/stadium_brand.gdshader")
	material.set_shader_parameter("brand_texture", texture)
	material.set_shader_parameter("phase", pos.x*0.05)
	var quad := QuadMesh.new()
	quad.size = Vector2(width, width*texture.get_height()/float(texture.get_width()))
	var node := _put(parent, quad, material, pos, Vector3.ONE)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _screen(parent: Node3D, pos: Vector3, rotation_y: float) -> void:
	var panel := Node3D.new()
	panel.position = pos
	panel.rotation.y = rotation_y
	parent.add_child(panel)
	_box(panel, _finish(Color("151122")), Vector3.ZERO, Vector3(17, 9, 0.6))
	var screen := ShaderMaterial.new()
	screen.shader = load("res://scripts/battle/arenas/generic/stadium_screen.gdshader")
	var quad := QuadMesh.new()
	quad.size = Vector2(16.4, 8.4)
	_put(panel, quad, screen, Vector3(0, 0, 0.32), Vector3.ONE)
	var logo := ShaderMaterial.new()
	logo.shader = load("res://scripts/battle/arenas/generic/stadium_brand.gdshader")
	logo.set_shader_parameter("brand_texture", load("res://assets/ui/logo.png"))
	logo.set_shader_parameter("float_amount", 0.16)
	var logo_quad := QuadMesh.new()
	logo_quad.size = Vector2(6.5, 6.5)
	_put(panel, logo_quad, logo, Vector3(0, 0.3, 0.35), Vector3.ONE)
	_wordmark(panel, Vector3(0, -3.0, 0.4), 7.0)
	var neon := _finish(Color("8d42ed"), 2.0)
	for side in [-1, 1]:
		_box(panel, neon, Vector3(side*8.4, 0, 0.4), Vector3(0.08, 9, 0.08))
		_box(panel, neon, Vector3(0, side*4.4, 0.4), Vector3(17, 0.08, 0.08))

func _crowd(parent: Node3D) -> void:
	var audience := Node3D.new()
	audience.name = "StadiumAudience"
	parent.add_child(audience)
	var spectator_script = preload("res://scripts/battle/arenas/shared/animated_spectator.gd")
	# A bounded rigged crowd: keep stair aisles clear and face the battle court.
	# Rear tiers keep the full zoomed-out camera orbit ahead of the audience.
	var index := 0
	for side in 4:
		for row in [4, 5, 6, 7, 8]:
			for seat in [-16.0, -12.0, -7.0, -3.0, 3.0, 7.0, 12.0, 16.0]:
				var spectator: Node3D = spectator_script.new()
				spectator.name = "Supporter%d" % index
				spectator.position = Vector3(seat, 2.0 + row * 0.65, -20.0 - row * 1.05).rotated(Vector3.UP, side * PI / 2)
				spectator.rotation.y = atan2(-spectator.position.x, -spectator.position.z)
				spectator.configure(spectator_script.MODELS[(index + row + side) % 4], index * 1.37, 0.7)
				audience.add_child(spectator)
				index += 1

func build() -> Node3D:
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	for child in stage.world.get_children():
		if child is DirectionalLight3D:
			child.shadow_blur = 2.0/3.0
		if child is WorldEnvironment:
			child.environment.background_color = Color("060510")
			child.environment.ssr_enabled = true
			child.environment.glow_enabled = true
			child.environment.glow_intensity = 0.5
	var arena := Node3D.new()
	arena.name = "PokeAetherStadiumStudy"
	var dark := _finish(Color("101020"))
	var tier := _finish(Color("18182e"))
	var purple := _finish(Color("8d3ef0"), 2.3)
	var cyan := _finish(Color("40bde5"), 2.0)
	var floor_material := ShaderMaterial.new()
	floor_material.shader = load("res://scripts/battle/arenas/generic/stadium_floor.gdshader")
	var plane := PlaneMesh.new()
	plane.size = Vector2(65,65)
	_put(arena, plane, floor_material, Vector3.ZERO, Vector3.ONE)
	# Tiered seating and fascia on all four sides, with regular stair aisles.
	for side in 4:
		var stand := Node3D.new()
		stand.rotation.y = side*PI/2.0
		arena.add_child(stand)
		_box(stand, dark, Vector3(0, 1.0, -18.5), Vector3(46, 2, 0.8))
		for row in 9:
			_box(stand, tier, Vector3(0, 0.9+row*0.65, -20-row*1.05), Vector3(46, 2.2, 1.2))
		for x in [-18,-9,0,9,18]:
			for row in 18:
				_box(stand, dark, Vector3(x, 1.9+row*0.325, -19.7-row*0.525), Vector3(0.85, 0.16, 0.54))
		for i in 15:
			_box(stand, cyan if i%3==0 else purple, Vector3((i-7)*3.05, 0.6, -18.04), Vector3(1.7, 0.07, 0.04))
			_box(stand, cyan if i%3==1 else purple, Vector3((i-7)*3.05, 5.0, -24.0), Vector3(1.8, 0.09, 0.06))
		for y in [1.9, 8.1, 11.5]:
			_box(stand, purple, Vector3(0,y,-19 if y<2 else -29), Vector3(47,0.055,0.08))
		for x in [-14,0,14]:
			_wordmark(stand, Vector3(x,1.15,-18.03),5.6)
		_box(stand, dark, Vector3(0,9.5,-30),Vector3(64,20,0.6))
		for x in [-26,-13,13,26]:
			_box(stand,dark,Vector3(x,10,-28),Vector3(0.5,18,0.7))
			_box(stand,cyan,Vector3(x+0.3,10,-27.6),Vector3(0.04,17,0.04))
		for x in [-21,-14,-7,0,7,14,21]:
			_box(stand,dark,Vector3(x,17,-18),Vector3(0.5,0.5,27))
			_box(stand,purple,Vector3(x,16.7,-11),Vector3(0.15,0.1,1.5))
	_box(arena,dark,Vector3(0,20,0),Vector3(65,0.5,65))
	var beam_material := ShaderMaterial.new()
	beam_material.shader = load("res://scripts/battle/arenas/generic/stadium_beam.gdshader")
	for x in [-12,12]:
		for z in [-15,0,15]:
			var moving_beam: ShaderMaterial = beam_material.duplicate()
			moving_beam.set_shader_parameter("phase",float(x)*0.17+float(z)*0.11)
			var beam := CylinderMesh.new()
			beam.top_radius = 0.12
			beam.bottom_radius = 2.8
			beam.height = 16.4
			beam.cap_top = false
			beam.cap_bottom = false
			beam.radial_segments = 24
			var shaft := _put(arena,beam,moving_beam,Vector3(x,8.3,z),Vector3.ONE)
			shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_box(arena,cyan,Vector3(x,16.6,z),Vector3(0.5,0.1,0.5))
	_screen(arena,Vector3(0,11,-28.5),0.0)
	_screen(arena,Vector3(0,11,28.5),PI)
	_crowd(arena)
	print("STADIUM_GEOMETRY_OK spectators=", arena.get_node("StadiumAudience").get_child_count())
	return arena
