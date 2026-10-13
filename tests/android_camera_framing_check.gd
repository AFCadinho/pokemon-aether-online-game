extends "res://tests/battle_move_effects_3d_check.gd"
class AndroidStage extends Stage:
	func uses_android_camera() -> bool: return true

func _make_stage() -> Node:
	return AndroidStage.new()

func _run() -> void:
	_setup()
	SettingsManager.battle_presentation_mode = "3d"
	SettingsManager.battle_3d_camera_motion = false
	assert(is_equal_approx(stage.user_camera_zoom, 0.86))
	assert(stage.camera_zoom_limits() == Vector2(0.5, 1.6))
	var view := SubViewport.new()
	add_child(view)
	stage.camera = Camera3D.new()
	view.add_child(stage.camera)
	stage.camera.fov = 48.0
	var samples := 0
	for dimensions in [Vector2i(2340, 1080), Vector2i(1280, 720), Vector2i(360, 780)]:
		view.size = dimensions
		for doubles in [false, true]:
			stage.double_mode = doubles
			for model_size in [Vector3(1, 2, 1), Vector3(5, 6, 4)]:
				stage.visual_bounds.fixture.idle.size = [model_size.x, model_size.y, model_size.z]
				for zoom in [0.5, 0.86, 1.6]:
					stage.user_camera_zoom = zoom
					for yaw in [0.0, 1.3, -2.4]:
						stage.user_camera_yaw = yaw
						for pitch in [-0.12, 0.65]:
							stage.user_camera_pitch = pitch
							stage._update_camera(0.0)
							for point in Stage.OverviewCamera.resting_points(stage):
								assert(not stage.camera.is_position_behind(point))
								assert(Stage.OverviewCamera.ANDROID_SAFE_RECT.grow(0.0001).has_point(stage.camera.unproject_position(point) / Vector2(dimensions)))
							samples += 1
	# Prove that the wider mobile frame actually allows a closer camera.
	view.size = Vector2i(2340, 1080)
	stage.double_mode = false
	var points: Array[Vector3] = Stage.OverviewCamera.resting_points(stage)
	var focus := Vector3(0, 1.2, 0)
	var offset := Vector3(2, 1, 3)
	var desktop: Transform3D = Stage.OverviewCamera.fit(stage.camera, points, focus, offset)
	var mobile: Transform3D = Stage.OverviewCamera.fit(stage.camera, points, focus, offset, Stage.OverviewCamera.ANDROID_SAFE_RECT)
	assert(mobile.origin.distance_to(focus) < desktop.origin.distance_to(focus))
	stage.reset_user_camera()
	assert(stage.user_camera_yaw == 0 and stage.user_camera_pitch == 0 and is_equal_approx(stage.user_camera_zoom, 0.86))
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	view.queue_free()
	await get_tree().process_frame
	print("ANDROID_CAMERA_FRAMING_PASS samples=%d closer=true singles=true doubles=true large_models=true reset=true" % samples)
	get_tree().quit()
