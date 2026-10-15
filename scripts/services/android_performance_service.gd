extends Node
## Optional, bounded, in-memory telemetry. No disk queue or stable device identity.
const FrameWindow := preload("res://scripts/services/android_performance_window.gd")
const Quality := preload("res://scripts/services/android_quality_policy.gd")
const WINDOW_USEC := 30000000
const SEND_USEC := 60000000
const MAX_QUEUED := 8
var window := FrameWindow.new()
var context := {}
var queue: Array[Dictionary] = []
var in_flight: Array[Dictionary] = []
var request: HTTPRequest
var foreground := true
var last_tick := 0
var next_context := 0
var next_native := 0
var next_send := 0
var retries := 0
var account_key := 0
var native := {}
var render_peak := 0
var texture_peak := 0
var draw_peak := 0
var native_bridge: Object
var java_wrapper: Object
var android_runtime: Object
var native_checked := false
var context_started := 0
var foreground_usec := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	if not _supported_platform():
		return
	SettingsManager.settings_changed.connect(_settings_changed)
	_settings_changed()

func _settings_changed() -> void:
	var enabled := _supported_platform() and _sharing_enabled()
	set_process(enabled)
	if not enabled:
		_clear()

func _supported_platform() -> bool:
	return OS.has_feature("android")

func _sharing_enabled() -> bool:
	return SettingsManager.share_android_performance

func _quality_preset() -> String:
	return SettingsManager.android_quality_preset

func _target_fps() -> int:
	return SettingsManager.android_fps_limit

func _platform_metadata() -> Dictionary:
	return {"platform": "android", "deviceModel": (OS.get_model_name().left(96) if not OS.get_model_name().is_empty() else "unknown")}

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		foreground = false
		# Pause/focus time must never become a slow gameplay frame.
		_reset_window()
		context = {}
		context_started = 0
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		foreground = true
		last_tick = 0
		next_context = 0
		next_native = 0

func _clear() -> void:
	if is_instance_valid(request):
		request.cancel_request()
		request.queue_free()
	request = null
	queue.clear()
	in_flight.clear()
	account_key = 0
	context = {}
	native = {}
	retries = 0
	next_send = 0
	foreground_usec = 0
	_reset_window()

func _reset_window() -> void:
	window = FrameWindow.new()
	last_tick = 0
	render_peak = 0
	texture_peak = 0
	draw_peak = 0

func _process(_delta: float) -> void:
	if not AuthService.is_authenticated() or AuthService.is_impersonating():
		if account_key != 0:
			_clear()
		return
	# This value never enters a report. Drop pending data on account changes.
	var current_account := int(AuthService.current_user.get("id", 0))
	if current_account != account_key:
		_clear()
		account_key = current_account
	if not foreground:
		return
	var now := Time.get_ticks_usec()
	if last_tick > 0:
		foreground_usec += now - last_tick
		if not context.is_empty():
			window.record(now - last_tick, int(context.targetFps))
	last_tick = now
	if now >= next_context:
		next_context = now + 500000
		var current := _context()
		if current != context:
			var load_ms := minf(600000.0, (now - context_started) / 1000.0) if context.get("scene") == "loading" and current.scene != "loading" else 0.0
			_finish_window(now, load_ms)
			if context.get("scene") != current.scene:
				context_started = now
			context = current
		_sample_counters()
	if now >= next_native:
		next_native = now + 5000000
		native = _native_sample()
	if window.total_usec >= WINDOW_USEC or window.count >= 10000:
		_finish_window(now)
	if next_send == 0:
		next_send = now + SEND_USEC
	if now >= next_send and not is_instance_valid(request):
		_send(now)

func _context() -> Dictionary:
	var scene := "menu"
	var presentation := "2d"
	var preset := _quality_preset()
	var raster := Vector2i.ZERO
	var world := GameState.get_world()
	if world != null:
		scene = "overworld"
		if bool(world.get("is_loading_map")):
			scene = "loading"
		elif bool(world.get("is_in_battle")):
			scene = "battle"
			for stage: Node in get_tree().get_nodes_in_group("performance_3d_stage"):
				if not stage.is_visible_in_tree():
					continue
				if stage.warming_render or stage.arena_preparing or stage._models_pending():
					scene = "loading"
				if stage.active and is_instance_valid(stage.viewport):
					presentation = "3d"
					preset = stage.quality_preset
					raster = stage.viewport.size
					break
	if scene == "overworld" and GameState.is_ui_input_locked():
		scene = "menu"
	for menu: Node in get_tree().get_nodes_in_group("performance_menu"):
		if menu.is_visible_in_tree():
			scene = "menu"
	return {"scene": scene, "presentation": presentation, "preset": preset,
		"presetVersion": Quality.SCHEMA_VERSION, "targetFps": _target_fps(),
		"renderWidth": raster.x, "renderHeight": raster.y,
		"screenWidth": get_window().size.x, "screenHeight": get_window().size.y}

func _sample_counters() -> void:
	render_peak = maxi(render_peak, int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)))
	texture_peak = maxi(texture_peak, int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)))
	draw_peak = maxi(draw_peak, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))

func _native_sample() -> Dictionary:
	if not native_checked:
		native_checked = true
		if Engine.has_singleton("AndroidRuntime") and Engine.has_singleton("JavaClassWrapper"):
			android_runtime = Engine.get_singleton("AndroidRuntime")
			java_wrapper = Engine.get_singleton("JavaClassWrapper")
			native_bridge = java_wrapper.call("wrap", "com.pokeaether.game.ApkInstallBridge")
			if java_wrapper.call("get_exception") != null:
				native_bridge = null
	if native_bridge == null:
		return {}
	var value: Variant = native_bridge.call("getPerformanceSnapshot", android_runtime.call("getActivity"))
	if java_wrapper.call("get_exception") != null or not value is String:
		return {}
	var parsed: Variant = JSON.parse_string(value)
	if not parsed is Dictionary:
		return {}
	var result := {}
	for key in ["androidApi", "processPssBytes", "thermalStatus"]:
		if parsed.get(key) is float or parsed.get(key) is int:
			result[key] = int(parsed[key])
	if parsed.get("powerSaveMode") is bool:
		result.powerSaveMode = parsed.powerSaveMode
	return result

func _finish_window(now: int, load_ms := 0.0) -> void:
	if (window.total_usec >= 1000000 or load_ms > 0) and window.count > 0 and not context.is_empty():
		var report := context.duplicate()
		report.merge(window.summary())
		if load_ms > 0:
			report.loadingDurationMs = load_ms
		report.merge(native)
		report.merge(_platform_metadata())
		report.merge({"reportId": _report_id(), "schemaVersion": 1,
			"gameVersion": str(ProjectSettings.get_setting("application/config/version", "dev")).left(80),
			"clientBuild": str(ProjectSettings.get_setting("application/config/build_id", "dev")).left(120),
			"renderer": RenderingServer.get_current_rendering_method(), "gpu": (RenderingServer.get_video_adapter_name().left(120) if not RenderingServer.get_video_adapter_name().is_empty() else "unknown"), "debugBuild": OS.is_debug_build(),
			"sessionAgeSeconds": int(foreground_usec / 1000000),
			"renderMemoryPeakBytes": render_peak, "textureMemoryPeakBytes": texture_peak,
			"drawCallsPeak": draw_peak})
		if queue.size() >= MAX_QUEUED:
			queue.pop_front()
		queue.append(report)
	_reset_window()
	last_tick = now

static func _report_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]

func _send(now: int) -> void:
	next_send = now + SEND_USEC
	if queue.is_empty() and in_flight.is_empty():
		return
	if in_flight.is_empty():
		in_flight.assign(queue)
		queue.clear()
	request = HTTPRequest.new()
	request.use_threads = true
	request.timeout = 8.0
	request.body_size_limit = 4096
	add_child(request)
	request.request_completed.connect(_completed)
	var started := request.request(GatewayApiConfig.get_base_url() + "/account/game/client-performance",
		GatewayApiConfig.get_json_headers(), HTTPClient.METHOD_POST, JSON.stringify({"reports": in_flight}))
	if started != OK:
		_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())

func _completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if is_instance_valid(request):
		request.queue_free()
	request = null
	if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
		in_flight.clear()
		retries = 0
	elif code in [404, 410]:
		# An older gateway or server kill switch should cost one request, not a
		# failed upload every minute. A new app session can try again.
		_clear()
		set_process(false)
	elif code >= 400 and code < 500 and code != 429:
		in_flight.clear()
		retries = 0
	else:
		retries += 1
		if retries >= 3:
			in_flight.clear()
			retries = 0
		next_send = Time.get_ticks_usec() + mini(900, 60 * (1 << retries)) * 1000000
