extends "res://tests/battle_move_effects_3d_check.gd"
class AndroidStage extends Stage:
	func uses_android_camera() -> bool: return true

func _make_stage() -> Node:
	return AndroidStage.new()

func _run() -> void:
	_setup()
	SettingsManager.battle_presentation_mode = "3d"
	SettingsManager.battle_3d_camera_motion = false
	assert(is_equal_approx(stage.user_camera_zoom, 0.60))
	assert(stage.camera_zoom_limits() == Vector2(0.3, 1.6))
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
				for zoom in [0.3, 0.60, 1.6]:
					stage.user_camera_zoom = zoom
					for yaw in [0.0, 1.3, -2.4]:
						stage.user_camera_yaw = yaw
						for pitch in [-0.12, 0.65]:
							stage.user_camera_pitch = pitch
							stage._update_camera(0.0)
							for index in stage._slot_count():
								assert(not stage.camera.is_position_behind(stage._position(index) + Vector3.UP * 1.2), "Close views retain combatant centres ahead of the near plane")
							if zoom == 1.6:
								for point in Stage.OverviewCamera.resting_points(stage):
									assert(Stage.OverviewCamera.ANDROID_SAFE_RECT.grow(0.0001).has_point(stage.camera.unproject_position(point) / Vector2(dimensions)), "Zooming out retains a complete overview")
							samples += 1
	# The shared close-up region permits a nearer fit than the conservative frame.
	view.size = Vector2i(2340, 1080)
	stage.double_mode = false
	var points: Array[Vector3] = Stage.OverviewCamera.resting_points(stage)
	var focus := Vector3(0, 1.2, 0)
	var offset := Vector3(2, 1, 3)
	var conservative: Transform3D = Stage.OverviewCamera.fit(stage.camera, points, focus, offset)
	var close_up: Transform3D = Stage.OverviewCamera.fit(stage.camera, points, focus, offset, Stage.OverviewCamera.CLOSE_UP_SAFE_RECT)
	assert(close_up.origin.distance_to(focus) < conservative.origin.distance_to(focus))
	stage.user_camera_yaw = 0.0
	stage.user_camera_pitch = 0.0
	stage.user_camera_zoom = 1.0
	stage._update_camera(0.0)
	var overview: Transform3D = stage.camera.transform
	stage.user_camera_zoom = 0.60
	stage._update_camera(0.0)
	assert(stage.camera.position.distance_to(focus) < overview.origin.distance_to(focus) * 0.65, "Default is substantially closer, even with large conservative bounds")
	var starting: Transform3D = stage.camera.transform
	stage.user_camera_zoom = 0.3
	stage._update_camera(0.0)
	assert(stage.camera.position.distance_to(focus) < starting.origin.distance_to(focus), "Pinch zoom must not be undone by model-envelope fitting")
	stage.reset_user_camera()
	assert(stage.user_camera_yaw == 0 and stage.user_camera_pitch == 0 and is_equal_approx(stage.user_camera_zoom, 0.60))
	stage.preview_enabled = true
	stage._update_camera(0.0)
	var preview: Transform3D = stage.camera.transform
	stage.user_camera_zoom = 0.3
	stage._update_camera(0.0)
	assert(stage.camera.transform.is_equal_approx(preview), "Battle close-up must not crop the Team Preview roster")
	var gesture := preload("res://scripts/battle/battle_ui/immersive_camera_input.gd").new()
	add_child(gesture)
	assert(not gesture._may_rotate(stage), "Roster selection keeps its touches")
	gesture.queue_free()
	stage.preview_enabled = false
	var probe := preload("res://scripts/battle/battle_ui/android_3d_performance_probe.gd").new()
	probe.stage = stage
	add_child(probe)
	probe.set_process(false)
	probe.last_label = "active"
	stage.user_camera_yaw = 0.33
	stage.user_camera_pitch = -0.05
	stage.user_camera_zoom = 0.81
	stage._update_camera(0.0)
	var chosen: Transform3D = stage.camera.transform
	var measurement: Dictionary = probe._camera_record()
	assert(measurement.idle and is_equal_approx(measurement.yaw_radians, 0.33) and is_equal_approx(measurement.pitch_radians, -0.05) and is_equal_approx(measurement.zoom, 0.81), "USB measurements retain the actual selected mobile orbit and zoom")
	assert(stage.camera.transform == chosen, "Measuring does not change the view")
	stage.current_actions[0] = "special_attack"
	assert(not probe._camera_record().idle, "Move shots cannot be selected as an idle camera preference")
	stage.current_actions[0] = "idle"
	stage.preview_enabled = true
	assert(not probe._camera_record().idle, "Team Preview cannot be selected as a battle camera preference")
	stage.preview_enabled = false
	probe.samples = {"engine_frame_ms": [16.0]}
	probe._emit(Time.get_ticks_usec())
	probe.queue_free()
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	view.queue_free()
	await get_tree().process_frame
	print("ANDROID_CAMERA_FRAMING_PASS samples=%d closer=true singles=true doubles=true large_models=true reset=true measurement=true" % samples)
	get_tree().quit()
