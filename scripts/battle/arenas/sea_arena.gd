extends "res://scripts/battle/arenas/arena_geometry.gd"
## Shared by client and visual review. The sandbank is submerged.
const WATER_DEPTH := 0.025

func _sandbar() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in 3:
		var radii := [0.0, 8.0, 10.0, 14.0]
		var heights := [0.0, 0.0, -0.3, -1.8]
		for i in 128:
			var points: Array[Vector3] = []
			for pair in [Vector2i(ring, i), Vector2i(ring, i+1), Vector2i(ring+1, i), Vector2i(ring+1, i+1)]:
				var theta: float = TAU*pair.y/128.0
				var radius: float = radii[pair.x] * (1.0 + 0.035*sin(theta*5.0))
				points.append(Vector3(sin(theta)*radius, heights[pair.x], cos(theta)*radius))
			for index in [0, 1, 2, 1, 3, 2]:
				surface.add_vertex(points[index])
	surface.generate_normals()
	return surface.commit()

func build() -> Node3D:
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	for child in stage.world.get_children():
		if child is DirectionalLight3D:
			child.shadow_blur = 2.0 / 3.0
		if child is WorldEnvironment:
			var sky_material := ProceduralSkyMaterial.new()
			sky_material.sky_top_color = Color("5294c3")
			sky_material.sky_horizon_color = Color("c8e2e7")
			sky_material.ground_horizon_color = Color("c8e2e7")
			sky_material.ground_bottom_color = Color("367f98")
			var sky := Sky.new()
			sky.sky_material = sky_material
			child.environment.sky = sky
			child.environment.background_mode = Environment.BG_SKY
			child.environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	var coast := Node3D.new()
	coast.name = "SeaSandbarStudy"
	# Actors keep their calibrated ground contact; only a thin water layer covers it.
	coast.set_meta("surface_height", 0.0)
	_put(coast, _sandbar(), _stone(Color("d5c29a"), true), Vector3.ZERO, Vector3.ONE).name = "SubmergedSandbank"
	var ocean := PlaneMesh.new()
	ocean.size = Vector2(2000, 2000)
	var water := ShaderMaterial.new()
	water.shader = load("res://tools/sprite_factory/sea_water.gdshader")
	var surface := _put(coast, ocean, water, Vector3(0, WATER_DEPTH, 0), Vector3.ONE)
	surface.name = "ShallowWater"
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rock := _stone(Color("8c9390"))
	var grass := _stone(Color("688b59"))
	# Distant rocky coastline, never entering the fighting area.
	for i in 15:
		var x := (i-7)*6.0
		var z := -48.0 - 5.0*sin(i*0.7)
		var height := 2.5 + 2.0*(0.5+0.5*sin(i*1.7))
		_put(coast, _rock_mesh(420+i), rock, Vector3(x, height*0.2-0.5, z), Vector3(6, height, 7), i*0.4)
		_put(coast, _rock_mesh(440+i), grass, Vector3(x, height*0.85-0.4, z-2), Vector3(5.5, height*0.3, 5), i*0.4)
	for i in 9:
		var theta := 1.7 + i*0.45
		_put(coast, _rock_mesh(460+i), rock, Vector3(sin(theta)*13, -0.3, cos(theta)*13), Vector3(0.7, 0.5, 0.9), theta)
	print("SEA_GEOMETRY_OK children=", coast.get_child_count())
	return coast
