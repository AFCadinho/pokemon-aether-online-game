extends "res://tests/battle_move_effects_3d_check.gd"
class AndroidStage extends Stage:
	func uses_android_camera() -> bool: return true

func _run() -> void:
	_setup()
	SettingsManager.battle_presentation_mode = "3d"
	SettingsManager.battle_3d_camera_motion = false
	assert(not stage.uses_android_camera())
	assert(stage.user_camera_zoom == 0.63 and stage.camera_zoom_limits() == Vector2(0.30, 1.60))
	var view := SubViewport.new()
	add_child(view)
	stage.camera = Camera3D.new()
	view.add_child(stage.camera)
	stage.camera.fov = 48.0
	var android := AndroidStage.new()
	add_child(android)
	android.set_process(false)
	assert(android.user_camera_zoom == 0.60, "Android retains the approved default")
	android.camera = Camera3D.new()
	view.add_child(android.camera)
	android.camera.fov = 48.0
	android.identities = stage.identities.duplicate()
	android.visual_bounds = stage.visual_bounds.duplicate(true)
	var samples := 0
	for dimensions in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(960, 600)]:
		view.size = dimensions
		for arena in ["stadium", "forest", "route_25_water"]:
			stage.arena_id = arena
			android.arena_id = arena
			for doubles in [false, true]:
				stage.double_mode = doubles
				android.double_mode = doubles
				for zoom in [0.30, 0.60, 1.60]:
					for yaw in [0.0, 0.65]:
						stage.user_camera_zoom = zoom
						android.user_camera_zoom = zoom
						stage.user_camera_yaw = yaw
						android.user_camera_yaw = yaw
						stage._update_camera(0.0)
						android._update_camera(0.0)
						assert(stage.camera.transform.is_equal_approx(android.camera.transform), "Desktop and Android use identical close-up framing at equal viewport sizes")
						samples += 1
	stage.double_mode = false
	stage.reset_user_camera()
	stage.entry_arena_requested = true
	stage._update_camera(0.0)
	var opening: Transform3D = stage.camera.transform
	var focus: Vector3 = Stage.ArenaCatalog.camera_target(stage.arena_id)
	focus.y = stage._position(0).y + 1.2
	stage.user_camera_zoom = 0.60
	stage._update_camera(0.0)
	assert(is_equal_approx(opening.origin.distance_to(focus) / stage.camera.position.distance_to(focus), 1.05), "Desktop starts only five percent farther away than the former close-up")
	stage.reset_user_camera()
	stage.visual_bounds.fixture.idle.size = [20, 30, 20]
	stage.entry_arena_requested = false
	stage._update_camera(0.0)
	assert(stage.camera.transform.is_equal_approx(opening), "The visible entry overview survives newly available model envelopes")
	stage.user_camera_zoom = 0.30
	stage._update_camera(0.0)
	assert(stage.camera.position.distance_to(focus) < opening.origin.distance_to(focus), "Mouse-wheel zoom can move closer than the opening view")
	stage.reset_user_camera()
	stage._update_camera(0.0)
	assert(stage.camera.transform.is_equal_approx(opening), "Reset restores the stable opening camera")
	stage.preview_enabled = true
	stage._update_camera(0.0)
	assert(not stage.camera.transform.is_equal_approx(opening), "Team Preview retains its separate roster camera")
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	android.queue_free()
	view.queue_free()
	await get_tree().process_frame
	print("DESKTOP_CLOSE_UP_CAMERA_PASS samples=%d android_parity=true stable_entry=true zoom=true reset=true preview=true" % samples)
	get_tree().quit()
