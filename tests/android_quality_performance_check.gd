extends SceneTree
const Quality := preload("res://scripts/services/android_quality_policy.gd")
const FrameStats := preload("res://scripts/services/android_performance_window.gd")

class FakeWorld extends Node:
	var is_in_battle := true
	var is_loading_map := false

class FakeStage extends Control:
	var active := true
	var warming_render := false
	var arena_preparing := false
	var quality_preset := "low"
	var viewport: SubViewport
	func _models_pending() -> bool:
		return false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(Quality.validate_preset("invalid") == "ultra")
	assert(Quality.validate_fps("30") == 60)
	assert(Quality.validate_fps(30.5) == 60)
	assert(Quality.validate_fps(30.0) == 30)
	assert(Quality.dimensions(Vector2i(2400, 1080), "low") == Vector2i(1200, 540))
	assert(Quality.dimensions(Vector2i(1080, 2400), "medium") == Vector2i(720, 1600))
	assert(Quality.dimensions(Vector2i(3120, 1440), "high") == Vector2i(2340, 1080))
	assert(Quality.dimensions(Vector2i(640, 360), "low") == Vector2i(640, 360))
	assert(Quality.dimensions(Vector2i(3120, 1440), "ultra") == Vector2i(3120, 1440))
	assert(Quality.dimensions(Vector2i.ZERO, "low") == Vector2i(2, 2))
	var view := SubViewport.new()
	Quality.apply_viewport(view, "low")
	assert(view.msaa_3d == Viewport.MSAA_DISABLED)
	Quality.apply_viewport(view, "medium")
	assert(view.msaa_3d == Viewport.MSAA_2X)
	view.free()
	var world := Node3D.new()
	var light := DirectionalLight3D.new()
	light.shadow_enabled = true
	light.light_energy = 1.25
	world.add_child(light)
	Quality.apply_lights(world, "ultra")
	assert(light.shadow_enabled)
	Quality.apply_lights(world, "low")
	assert(not light.shadow_enabled and light.light_energy == 1.25)
	world.free()
	var pool := preload("res://scripts/battle/arenas/shared/environment_pool.gd").new()
	pool.quality_preset = "low"
	pool.arena_id = "cave"
	pool.render_size = Vector2i(1200, 540)
	root.add_child(pool)
	pool.set_process(false)
	for response_pass in [false, true]:
		var pass_data: Dictionary = pool._build_pass(response_pass)
		assert(pass_data.viewport.size == Vector2i(1200, 540) and pass_data.viewport.msaa_3d == Viewport.MSAA_DISABLED)
		_assert_no_shadows(pass_data.world)
	pool.free()
	var window := FrameStats.new()
	for index in 100:
		window.record(16667, 60)
	window.record(120000, 60)
	assert(window.count == 101 and window.histogram[2] == 100 and window.histogram[7] == 1)
	assert(window.over_budget == 1 and window.over_50 == 1 and window.over_100 == 1)
	var slow := FrameStats.new()
	slow.record(33333, 30)
	assert(slow.over_budget == 0)
	# Exercise actual report creation and opt-out/pause handling, without enabling
	# Android or issuing any request from this desktop-only check.
	var settings := root.get_node("SettingsManager")
	var existed := FileAccess.file_exists(settings.SETTINGS_PATH)
	var saved := FileAccess.get_file_as_string(settings.SETTINGS_PATH) if existed else ""
	var old_max_fps := Engine.max_fps
	var old_presentation: String = settings.battle_presentation_mode
	var fresh_settings: Node = settings.get_script().new()
	assert(fresh_settings.share_android_performance, "Fresh profiles must enable diagnostics")
	fresh_settings.free()
	# Profiles predating diagnostics receive the default; saved opt-outs survive
	# subsequent loads, regardless of the current in-memory value.
	var legacy_profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(settings.SETTINGS_PATH))
	legacy_profile.erase("share_android_performance")
	var legacy_file := FileAccess.open(settings.SETTINGS_PATH, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy_profile))
	legacy_file.close()
	settings.share_android_performance = false
	settings.load_settings()
	assert(settings.share_android_performance, "An absent preference must enable diagnostics")
	settings.set_share_android_performance(false)
	settings.share_android_performance = true
	settings.load_settings()
	assert(not settings.share_android_performance, "A saved opt-out must survive loading")
	var menu: Control = load("res://scenes/interface/settings/settings_menu.tscn").instantiate()
	root.add_child(menu)
	menu._create_android_quality_controls(menu.find_child("GraphicsContent", true, false))
	menu._create_android_performance_controls(menu.find_child("SupportContent", true, false))
	menu._apply_settings_to_controls()
	menu.android_quality_options.select(0)
	menu.android_quality_options.item_selected.emit(0)
	menu.android_fps_options.select(0)
	menu.android_fps_options.item_selected.emit(0)
	menu.android_performance_toggle.button_pressed = true
	settings.android_quality_preset = "ultra"
	settings.android_fps_limit = 60
	settings.share_android_performance = false
	settings.load_settings()
	assert(settings.android_quality_preset == "low" and settings.android_fps_limit == 30 and settings.share_android_performance)
	assert(settings.battle_presentation_mode == old_presentation and Engine.max_fps == old_max_fps)
	menu._apply_settings_to_controls()
	assert(menu.android_quality_options.selected == 0 and menu.android_fps_options.selected == 0 and menu.android_performance_toggle.button_pressed)
	var invalid_profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(settings.SETTINGS_PATH))
	invalid_profile.share_android_performance = "true"
	var invalid_file := FileAccess.open(settings.SETTINGS_PATH, FileAccess.WRITE)
	invalid_file.store_string(JSON.stringify(invalid_profile))
	invalid_file.close()
	settings.load_settings()
	assert(not settings.share_android_performance, "Malformed preferences must not opt a player in")
	menu.android_performance_toggle.button_pressed = false
	assert(not settings.share_android_performance)
	menu.queue_free()
	if existed:
		var settings_file := FileAccess.open(settings.SETTINGS_PATH, FileAccess.WRITE)
		settings_file.store_string(saved)
		settings_file.close()
	else:
		DirAccess.remove_absolute(settings.SETTINGS_PATH)
	settings.load_settings()
	var service: Node = load("res://scripts/services/android_performance_service.gd").new()
	root.add_child(service)
	assert(not service.is_processing())
	service.context = {"scene": "battle", "presentation": "3d", "preset": "low", "presetVersion": 1,
		"targetFps": 60, "renderWidth": 1200, "renderHeight": 540, "screenWidth": 2400, "screenHeight": 1080}
	service.native = {"androidApi": 35, "thermalStatus": 2, "processPssBytes": 100000000, "powerSaveMode": false}
	for index in 12:
		service.window = window
		service._finish_window(40000000)
	assert(service.queue.size() == 8)
	var report: Dictionary = service.queue.back().duplicate(true)
	assert(report.reportId.length() == 36 and report.frameCount == 101)
	assert(not report.has("userId") and not report.has("installationId"))
	# Portable contract fixture consumed by the backend test (only metadata that
	# requires a real Android device is substituted).
	report.deviceModel = "Contract Android"
	report.renderer = "gl_compatibility"
	report.gpu = "Contract GPU"
	var file := FileAccess.open("res://.tmp/android-performance-contract.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"reports": [report]}))
	file.close()
	service.window.record(100000, 60)
	service._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert(not service.foreground and service.window.count == 0 and service.last_tick == 0)
	service._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert(service.foreground and service.last_tick == 0)
	service._clear()
	assert(service.queue.is_empty() and service.in_flight.is_empty() and service.window.count == 0)
	# An in-progress battle reports its retained profile, even if the player has
	# already selected a different profile for the next battle.
	var fake_world := FakeWorld.new()
	root.add_child(fake_world)
	fake_world.add_to_group("world")
	var stage := FakeStage.new()
	root.add_child(stage)
	stage.add_to_group("performance_3d_stage")
	stage.viewport = SubViewport.new()
	stage.viewport.size = Vector2i(1200, 540)
	stage.add_child(stage.viewport)
	var previous_quality: String = settings.android_quality_preset
	settings.android_quality_preset = "high"
	var observed: Dictionary = service._context()
	assert(observed.scene == "battle" and observed.presentation == "3d" and observed.preset == "low" and observed.renderWidth == 1200)
	stage.warming_render = true
	assert(service._context().scene == "loading")
	stage.warming_render = false
	stage.active = false
	assert(service._context().presentation == "2d" and service._context().renderWidth == 0)
	settings.android_quality_preset = previous_quality
	fake_world.free()
	stage.free()
	service.in_flight.assign([report])
	for attempt in 3:
		service._completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
	assert(service.in_flight.is_empty() and service.retries == 0)
	service.queue.assign([report])
	service._completed(HTTPRequest.RESULT_SUCCESS, 404, PackedStringArray(), PackedByteArray())
	assert(service.queue.is_empty() and not service.is_processing())
	service.queue_free()
	print("ANDROID_QUALITY_PERFORMANCE_OK presets histogram bounded_queue pause opt_out contract")
	quit()

func _assert_no_shadows(node: Node) -> void:
	if node is Light3D:
		assert(not node.shadow_enabled)
	for child in node.get_children():
		_assert_no_shadows(child)
