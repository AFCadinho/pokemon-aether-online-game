extends SceneTree
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
	var settings := root.get_node("SettingsManager")
	var service := root.get_node("DesktopPerformanceService")
	assert(service._supported_platform())
	assert(not root.get_node("AndroidPerformanceService").is_processing())
	assert(not root.get_node("AuthService").is_authenticated())
	var saved := FileAccess.get_file_as_string(settings.SETTINGS_PATH)
	var old_max_fps := Engine.max_fps
	var fresh: Node = settings.get_script().new()
	assert(fresh.share_desktop_performance)
	fresh.free()
	var profile: Dictionary = JSON.parse_string(saved)
	profile.erase("share_desktop_performance")
	_write(settings.SETTINGS_PATH, profile)
	settings.load_settings()
	assert(settings.share_desktop_performance)
	var android_preference: bool = settings.share_android_performance
	var menu: Control = load("res://scenes/interface/settings/settings_menu.tscn").instantiate()
	root.add_child(menu)
	menu._apply_settings_to_controls()
	assert(menu.desktop_performance_toggle != null and menu.desktop_performance_toggle.button_pressed)
	service.queue.assign([{"pending": true}])
	service.in_flight.assign([{"pending": true}])
	service.window.record(100000, 60)
	service.request = HTTPRequest.new()
	service.add_child(service.request)
	menu.desktop_performance_toggle.button_pressed = false
	assert(not settings.share_desktop_performance and not service.is_processing())
	assert(service.queue.is_empty() and service.in_flight.is_empty() and service.window.count == 0 and service.request == null)
	assert(settings.share_android_performance == android_preference)
	settings.share_desktop_performance = true
	settings.load_settings()
	assert(not settings.share_desktop_performance, "Saved opt-out must survive reload")
	menu._apply_settings_to_controls()
	assert(not menu.desktop_performance_toggle.button_pressed)
	profile.share_desktop_performance = "true"
	_write(settings.SETTINGS_PATH, profile)
	settings.load_settings()
	assert(not settings.share_desktop_performance, "Malformed values must stay disabled")
	settings.set_share_desktop_performance(true)
	assert(service.is_processing())
	assert(service._native_sample().is_empty())
	# Retained presenter quality must win over a pending next-battle preference.
	var world := FakeWorld.new()
	root.add_child(world)
	world.add_to_group("world")
	var stage := FakeStage.new()
	root.add_child(stage)
	stage.add_to_group("performance_3d_stage")
	stage.viewport = SubViewport.new()
	stage.viewport.size = Vector2i(800, 450)
	stage.add_child(stage.viewport)
	settings.desktop_battle_quality_preset = "ultra"
	service.context = service._context()
	assert(service.context.preset == "low" and service.context.renderWidth == 800)
	assert(service.context.scene == "battle" and service.context.presentation == "3d")
	var reports: Array[Dictionary] = []
	for limit in [0, 30, 60, 120]:
		settings.desktop_fps_limit = limit
		service.context = service._context()
		service.window = FrameStats.new()
		for frame in 100:
			service.window.record(16667, limit)
		service.window.record(120000, limit)
		service._finish_window(40000000)
		var report: Dictionary = service.queue.back().duplicate(true)
		assert(report.platform == "desktop" and report.deviceModel == "desktop")
		assert(report.targetFps == limit and report.frameCount == 101)
		assert(not report.has("androidApi") and not report.has("processPssBytes"))
		assert(not report.has("userId") and not report.has("installationId"))
		assert(report.overBudgetFrames == (0 if limit == 0 else (101 if limit == 120 else 1)))
		reports.append(report)
	stage.warming_render = true
	assert(service._context().scene == "loading")
	stage.warming_render = false
	stage.active = false
	assert(service._context().presentation == "2d")
	stage.free()
	world.free()
	DirAccess.make_dir_recursive_absolute("res://.tmp")
	_write("res://.tmp/desktop-performance-contract.json", {"reports": reports})
	service._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(not service.foreground and service.window.count == 0)
	service._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert(service.foreground and service.last_tick == 0)
	service.account_key = 123
	service._process(0.0)
	assert(service.queue.is_empty() and service.in_flight.is_empty() and service.account_key == 0)
	service.queue.assign([reports[0]])
	service._completed(HTTPRequest.RESULT_SUCCESS, 404, PackedStringArray(), PackedByteArray())
	assert(service.queue.is_empty() and not service.is_processing())
	# Restore this slot's settings; no network is used by the unauthenticated test.
	var restore := FileAccess.open(settings.SETTINGS_PATH, FileAccess.WRITE)
	restore.store_string(saved)
	restore.close()
	settings.load_settings()
	Engine.max_fps = old_max_fps
	menu.queue_free()
	print("DESKTOP_PERFORMANCE_OK defaults opt_out persisted unlimited retained_profile focus logout contract")
	quit()

func _write(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()
