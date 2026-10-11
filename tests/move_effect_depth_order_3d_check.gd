extends SceneTree
## GPU regression: an alpha-prepass model colour pass overpaints a near beam.
const Effect = preload("res://scripts/battle/battle_ui/move_effect_3d.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(20).timeout.connect(func(): quit(1))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(360, 240)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.0
	camera.position = Vector3(0, 0, 10)
	camera.look_at(Vector3.ZERO)
	var caster := MeshInstance3D.new()
	var body := BoxMesh.new()
	body.size = Vector3(2, 3, .5)
	caster.mesh = body
	var blue := StandardMaterial3D.new()
	blue.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blue.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	blue.albedo_color = Color.BLUE
	# Explicit model surface priorities must also precede the effect pass.
	blue.render_priority = 1
	caster.material_override = blue
	world.add_child(caster)
	var effect := Effect.new()
	world.add_child(effect)
	effect.set_process(false)
	effect.tube.height = 1.0
	effect.tube.top_radius = 1.0
	effect.tube.bottom_radius = 1.0
	var green := StandardMaterial3D.new()
	green.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	green.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	green.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	green.albedo_color = Color(0, 1, 0, .95)
	effect._line(Vector3(0, 0, 1), Vector3(-4, 0, -5), .12, green)
	assert(green.render_priority == Effect.EFFECT_RENDER_PRIORITY)
	assert(not green.no_depth_test, "Sorting must retain real model occlusion")
	# Control: default effect priority lets the model paint over its near end.
	green.render_priority = 0
	var before := await _capture(viewport)
	var front := camera.unproject_position(Vector3(-.15, 0, .775)).round()
	var blocked := camera.unproject_position(Vector3(-.8, 0, -.2)).round()
	var outside := camera.unproject_position(Vector3(-2.0, 0, -2.0)).round()
	assert(before.get_pixelv(front).b > before.get_pixelv(front).g + .4, "Control must reproduce caster painting over the beam")
	green.render_priority = Effect.EFFECT_RENDER_PRIORITY
	var after := await _capture(viewport)
	assert(after.get_pixelv(front).g > after.get_pixelv(front).b + .4, "Near beam endpoint must remain visible")
	assert(after.get_pixelv(blocked).b > after.get_pixelv(blocked).g + .4, "Caster must still hide the beam behind its surface")
	assert(after.get_pixelv(outside).g > after.get_pixelv(outside).b + .4, "Exposed far segment must remain visible")
	viewport.free()
	print("MOVE_EFFECT_DEPTH_ORDER_3D_OK control=true front=true occlusion=true far=true")
	quit()

func _capture(viewport: SubViewport) -> Image:
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
