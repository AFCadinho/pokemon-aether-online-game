extends "res://tests/battle_move_effects_3d_check.gd"

func _run() -> void:
	_setup()
	SettingsManager.battle_presentation_mode = "3d"
	SettingsManager.battle_3d_camera_motion = false
	var viewport := SubViewport.new()
	add_child(viewport)
	stage.camera = Camera3D.new()
	viewport.add_child(stage.camera)
	stage.camera.fov = 48.0
	var samples := 0
	for dimensions in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(360, 780)]:
		viewport.size = dimensions
		for arena in ["stadium", "forest", "route_25_water"]:
			stage.arena_id = arena
			for doubles in [false, true]:
				stage.double_mode = doubles
				for model_size in [Vector3(1, 2, 1), Vector3(5, 6, 4)]:
					stage.visual_bounds.fixture.idle.size = [model_size.x, model_size.y, model_size.z]
					for zoom in [0.72, 1.0, 1.45]:
						stage.user_camera_zoom = zoom
						for yaw in [0.0, 1.3, -2.4]:
							stage.user_camera_yaw = yaw
							for pitch in [-0.12, 0.65]:
								stage.user_camera_pitch = pitch
								stage._update_camera(0.0)
								var safe: Rect2 = Stage.OverviewCamera.SAFE_RECT
								for point in Stage.OverviewCamera.resting_points(stage):
									var pixel: Vector2 = stage.camera.unproject_position(point)
									assert(not stage.camera.is_position_behind(point))
									assert(safe.grow(0.0001).has_point(pixel / Vector2(dimensions)), "Model must stay above the controls at maximum zoom")
								samples += 1
	# A lunge, dodge, pose or recall shrink must not pull the overview with it.
	var overview: Transform3D = stage.camera.transform
	var rest_points: Array[Vector3] = Stage.OverviewCamera.resting_points(stage)
	stage.actors[0].position += Vector3(8, 4, -6)
	stage.actors[0].rotation.y += 1.0
	stage.actors[0].scale *= 0.1
	stage.resting[0] = false
	stage.current_actions[0] = "physical_attack"
	stage._update_camera(1.0)
	assert(Stage.OverviewCamera.resting_points(stage) == rest_points)
	assert(stage.camera.transform.is_equal_approx(overview))
	# FOV and projection remain available unchanged to the cinematic controller.
	assert(stage.camera.fov == 48.0 and stage.camera.h_offset == 0.0 and stage.camera.v_offset == 0.0)
	# Responsive prompt height constrains the frame even while controls hide.
	var wrapper := Control.new()
	add_child(wrapper)
	wrapper.owner = self
	stage.reparent(wrapper)
	stage.size = Vector2(1200, 800)
	var prompt := Control.new()
	prompt.name = "CurrentActionPanel"
	wrapper.add_child(prompt)
	prompt.owner = self
	prompt.unique_name_in_owner = true
	prompt.position = Vector2(300, 520)
	prompt.size = Vector2(600, 60)
	var safe: Rect2 = Stage.OverviewCamera.safe_rect(stage)
	assert(is_equal_approx(safe.end.y, 0.615), "Scaled HUD reserves space")
	prompt.hide()
	assert(Stage.OverviewCamera.safe_rect(stage) == safe, "Hidden move controls never reframe an attack")
	SettingsManager.battle_presentation_mode = "2.5d"
	stage._update_camera(0.0)
	assert(stage.camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
	assert(stage.camera.position == Vector3(0, 5.5, 16))
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	wrapper.queue_free()
	viewport.queue_free()
	await get_tree().process_frame
	print("OVERVIEW_CAMERA_3D_OK samples=%d sizes=true zoom=true orbit=true doubles=true translated_arenas=true stable_actions=true hybrid=true" % samples)
	get_tree().quit()
