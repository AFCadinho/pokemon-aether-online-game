extends SceneTree
## Native synthetic irradiance comparison; excludes scenery boundary pixels.
const Pool = preload("res://scripts/battle/arenas/shared/environment_pool.gd")
const Response = preload("res://scripts/battle/battle_ui/material_response.gd")
var views: Array[SubViewport] = []
var cameras: Array[Camera3D] = []

func _init() -> void:
	_run.call_deferred()

func _build(trim: bool) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(256, 256)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.use_hdr_2d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	views.append(view)
	var world := Node3D.new()
	view.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	world.add_child(environment)
	Response.apply_neutral_lighting(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 2.5, 7)
	camera.look_at(Vector3(0, 1, 0))
	camera.current = true
	cameras.append(camera)
	var actor := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1
	sphere.height = 2
	actor.mesh = sphere
	actor.position.y = 1
	var irradiance := ShaderMaterial.new()
	irradiance.shader = Response.IRRADIANCE
	actor.material_override = irradiance
	world.add_child(actor)
	var arena := Node3D.new()
	world.add_child(arena)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(ground)
	var caster := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2, 4, 1)
	caster.mesh = box
	caster.position = Vector3(-2, 2, -1)
	arena.add_child(caster)
	if trim:
		Pool._response_shadow_geometry(arena)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("A real native renderer is required for actor pixel comparison")
		quit(1)
		return
	_build(false)
	_build(true)
	for frame in 12:
		await process_frame
		await RenderingServer.frame_post_draw
	var original := views[0].get_texture().get_image()
	var optimized := views[1].get_texture().get_image()
	var centre := Vector2i(cameras[0].unproject_position(Vector3(0, 1, 0)))
	var compared := 0
	var changed := 0
	var darkest := INF
	var brightest := 0.0
	for y in range(-20, 21):
		for x in range(-20, 21):
			if x * x + y * y > 400:
				continue
			var point := centre + Vector2i(x, y)
			compared += 1
			var pixel := original.get_pixelv(point)
			var brightness := (pixel.r + pixel.g + pixel.b) / 3.0
			darkest = minf(darkest, brightness)
			brightest = maxf(brightest, brightness)
			if original.get_pixelv(point) != optimized.get_pixelv(point):
				changed += 1
	print("ANDROID_RESPONSE_ACTOR_PIXELS compared=", compared, " changed=", changed,
		" renderer=", RenderingServer.get_current_rendering_method())
	for view in views:
		view.queue_free()
	await process_frame
	quit(0 if changed == 0 and compared > 1000 and brightest > .1 and brightest - darkest > .05 else 1)
