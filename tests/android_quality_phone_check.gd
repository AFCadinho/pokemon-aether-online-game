extends SceneTree
## Separate debug APK only. Real production presenter/assets; fixed public actors.
const Stage := preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Pool := preload("res://scripts/battle/arenas/shared/environment_pool.gd")
const Quality := preload("res://scripts/services/android_quality_policy.gd")
const Stats := preload("res://scripts/battle/battle_ui/android_3d_performance_probe.gd")
const REPORT := "user://android-quality-details.json"
const FIXTURE := "user://android-quality-fixture.json"
const ORDERS := [["ultra", "high", "medium", "low", "ultra"], ["ultra", "low", "medium", "high", "ultra"]]
var fixture := {}
var report := {"schema": 1, "phases": [], "failures": [], "complete": false}
var stage: Control
var pool: Node
var canvas: SubViewport
var surface: TextureRect
var status: Label
var settings: Node
var telemetry: Node
var dimensions := Vector2i.ZERO

class ErrorSink extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			errors.append(code + " " + rationale)
var sink := ErrorSink.new()

class LifecycleProbe extends Node:
	var pauses := 0
	var resumes := 0
	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_PAUSED:
			pauses += 1
		elif what == NOTIFICATION_APPLICATION_RESUMED:
			resumes += 1

static func valid_fixture(value: Variant) -> bool:
	if not value is Dictionary or value.get("schema") != 1:
		return false
	if value.get("order") not in ["descending", "ascending"]:
		return false
	var seconds: Variant = value.get("phase_seconds")
	var port: Variant = value.get("port")
	if not (seconds is float or seconds is int) or not (port is float or port is int):
		return false
	if float(seconds) not in [10.0, 15.0, 20.0] or float(port) != floorf(float(port)) or port < 1024 or port > 65535:
		return false
	var run_id: Variant = value.get("run_id")
	return run_id is String and RegEx.create_from_string("^[0-9a-f]{32}$").search(run_id) != null

func _init() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> bool:
	if not ok:
		report.failures.append(message)
		print("ANDROID_QUALITY_FAIL ", message)
	return ok

func _write(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if _check(file != null, "Diagnostic file writable"):
		file.store_string(JSON.stringify(value))
		file.close()

func _marker(phase: String) -> void:
	status.text = "Android quality test · " + phase
	_write("user://android-quality-phase.json", {"run_id": fixture.run_id, "phase": phase})
	print("ANDROID_QUALITY_PHASE ", phase)

func _release_stage() -> void:
	if is_instance_valid(stage):
		stage.free()
	stage = null
	if is_instance_valid(pool):
		pool.free()
	pool = null
	if is_instance_valid(surface):
		surface.free()
	surface = null
	if is_instance_valid(canvas):
		canvas.free()
	canvas = null

func _prepare(preset: String) -> bool:
	_release_stage()
	settings.set_android_quality_preset(preset)
	_marker("prepare:" + preset)
	var started := Time.get_ticks_msec()
	pool = Pool.prepare(root, settings.get_battle_3d_forest_manifest(), dimensions, "forest")
	if not _check(pool != null, "Real arena pool created"):
		return false
	while not pool.ready_for_battle and not pool.failed and Time.get_ticks_msec() - started < 120000:
		await process_frame
	if not _check(pool.ready_for_battle, "Real arena pool prepared"):
		return false
	for data in pool.passes:
		var light: Node = data.arena.get_node("OutdoorLighting")
		light.set_process(false)
		light.apply_seconds(43200.0)
	canvas = SubViewport.new()
	canvas.size = dimensions
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	surface = TextureRect.new()
	surface.texture = canvas.get_texture()
	surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	root.add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage = Stage.new()
	canvas.add_child(stage)
	stage.setup()
	stage.set_battle_context(&"grass", "wild")
	stage.set_combatant(0, "Charizard")
	stage.set_combatant(1, "Dragonite")
	await stage.await_prepared(true, 60000)
	report.preparation = {"active": stage.active, "phase": stage.preparation_phase, "reason": stage.reason,
		"arena": stage.arena_id, "arena_problem": stage.arena_problem, "pooled": not stage.forest_lease.is_empty(),
		"catalog_problem": stage.catalog_problem, "packed_count": stage.packed.size(), "grounded_count": stage.ground_offsets.size(),
		"pool_preset": pool.quality_preset, "stage_preset": stage.quality_preset, "pool_discarded": pool.discard_requested,
		"requested_arena": stage._requested_arena(), "manual_catalog": settings.has_manual_battle_3d_catalog_selection(),
		"catalog_path": settings.get_battle_3d_catalog_path(), "failed_models": stage.failed_models.duplicate(),
		"model_revision": root.get_node("OnDemand3DBundleService")._selected_release().get("revision", "unknown")}
	var expected := Quality.dimensions(dimensions, preset)
	if not _check(stage.active and stage.handles("p1") and stage.handles("p2") and not stage.forest_lease.is_empty(), "Real actors use the arena pool"):
		return false
	for data in pool.passes:
		if not _check(data.viewport.size == expected and data.viewport.msaa_3d == Quality.msaa(preset), "Both passes apply the selected raster/MSAA"):
			return false
		RenderingServer.viewport_set_measure_render_time(data.viewport.get_viewport_rid(), true)
	stage.playback_speed = 0.0
	RenderingServer.global_shader_parameter_set("wind_speed", 0.0)
	return _check(stage.quality_preset == preset and pool.quality_preset == preset, "Presenter and pool retain the same profile")

func _observe(preset: String, index: int) -> void:
	var prepared := Time.get_ticks_msec()
	if not await _prepare(preset):
		return
	var preparation_ms := Time.get_ticks_msec() - prepared
	_marker("warm:" + preset)
	var warm_until := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < warm_until:
		await process_frame
	telemetry._reset_window()
	telemetry.context = {"scene": "battle", "presentation": "3d", "preset": preset, "presetVersion": 1,
		"targetFps": 60, "renderWidth": stage.viewport.size.x, "renderHeight": stage.viewport.size.y,
		"screenWidth": dimensions.x, "screenHeight": dimensions.y}
	telemetry.native = telemetry._native_sample()
	_marker("sample:%d:%s" % [index, preset])
	var started := Time.get_ticks_usec()
	var last := started
	var samples := {"frame_ms": [], "main_gpu_ms": [], "response_gpu_ms": []}
	var pipeline_start: Array = stage._blocking_pipelines()
	var next_counters := started
	while Time.get_ticks_usec() - started < int(fixture.phase_seconds) * 1000000:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.frame_ms.append((now - last) / 1000.0)
		telemetry.window.record(now - last, 60)
		telemetry.foreground_usec += now - last
		last = now
		for pass_index in 2:
			var rid: RID = pool.passes[pass_index].viewport.get_viewport_rid()
			samples["main_gpu_ms" if pass_index == 0 else "response_gpu_ms"].append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		if now >= next_counters:
			next_counters = now + 1000000
			telemetry._sample_counters()
	# End the measured interval before the synchronous native PSS query.
	var sampled_seconds: float = telemetry.window.total_usec / 1000000.0
	telemetry.native = telemetry._native_sample()
	var row := {"preset": preset, "index": index, "seconds": sampled_seconds,
		"preparation_ms": preparation_ms, "render_size": [stage.viewport.size.x, stage.viewport.size.y],
		"response_size": [pool.passes[1].viewport.size.x, pool.passes[1].viewport.size.y],
		"msaa": stage.viewport.msaa_3d, "timings": {}, "pipeline_start": pipeline_start,
		"pipeline_end": stage._blocking_pipelines(), "native": telemetry.native.duplicate(),
		"render_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	for key in samples:
		row.timings[key] = Stats.stats(samples[key])
	row.fps = samples.frame_ms.size() / row.seconds
	report.phases.append(row)
	telemetry._finish_window(Time.get_ticks_usec())
	# Transport-only local fixture: no real/synthetic account session is created.
	# Authentication has separate backend tests; this checks actual Android JSON,
	# native counters, upload completion and opt-out on the physical runtime.
	telemetry._send(Time.get_ticks_usec())
	var upload_until := Time.get_ticks_msec() + 12000
	while is_instance_valid(telemetry.request) and Time.get_ticks_msec() < upload_until:
		await process_frame
	_check(not is_instance_valid(telemetry.request) and telemetry.in_flight.is_empty(), "USB-local telemetry upload completed")
	await RenderingServer.frame_post_draw
	_check(stage.viewport.get_texture().get_image().save_png("user://android-quality-%d-%s.png" % [index, preset]) == OK, "Own arena capture saved")
	_write(REPORT, report)
	print("ANDROID_QUALITY_RESULT ", JSON.stringify(row))

func _check_controls() -> void:
	var menu: Control = load("res://scenes/interface/settings/settings_menu.tscn").instantiate()
	root.add_child(menu)
	menu.open("login")
	menu.tab_container.current_tab = 2
	for frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("user://android-quality-graphics.png") == OK, "Native Graphics UI captured")
	_check(menu.android_quality_options != null and menu.android_fps_options != null, "Real Android quality/FPS controls exist")
	menu.tab_container.current_tab = 6
	for frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("user://android-quality-support.png") == OK, "Native Support UI captured")
	_check(menu.android_performance_toggle != null and not menu.android_performance_toggle.button_pressed, "Diagnostic sharing starts disabled")
	menu.android_performance_toggle.button_pressed = true
	_check(settings.share_android_performance, "Native diagnostic switch enables the test service")
	menu.close()
	menu.queue_free()
	await process_frame

func _run() -> void:
	OS.add_logger(sink)
	if not _check(OS.has_feature("android_quality_benchmark") and OS.has_feature("android") and OS.is_debug_build(), "Dedicated Android debug APK required"):
		_finish(); return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not _check(valid_fixture(parsed), "Bounded fixture supplied over USB"):
		_finish(); return
	fixture = parsed
	report.run_id = fixture.run_id
	report.protocol = fixture.duplicate()
	report.renderer = RenderingServer.get_current_rendering_method()
	report.adapter = RenderingServer.get_video_adapter_name()
	report.note = "Fixed renderer workload, not full gameplay or unique-user telemetry."
	DisplayServer.screen_set_keep_on(true)
	status = Label.new()
	status.z_index = 100
	status.position = Vector2(12, 12)
	root.add_child(status)
	settings = root.get_node("SettingsManager")
	telemetry = root.get_node("AndroidPerformanceService")
	if not _check(not root.get_node("AuthService").is_authenticated(), "No game account/session used"):
		_finish(); return
	root.get_node("GatewayApiConfig").cached_url = "http://127.0.0.1:%d" % int(fixture.port)
	await _check_controls()
	if not report.failures.is_empty():
		_finish(); return
	settings.set_android_fps_limit(60)
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_arena = "forest"
	settings.battle_3d_camera_motion = false
	settings.android_3d_idle_camera_motion = false
	settings.android_3d_move_camera = false
	root.get_node("WorldTimeService").set_debug_time(12)
	_marker("assets")
	if not _check((await root.get_node("Android3DEnvironmentService").ensure_ready()).is_empty(), "Pinned arena verified via USB"):
		_finish(); return
	dimensions = root.size
	report.native_size = [dimensions.x, dimensions.y]
	report.native = telemetry._native_sample()
	if not _check(report.native.has("androidApi") and report.native.has("processPssBytes"), "Real native bridge/counters available"):
		_finish(); return
	var order: Array = ORDERS[0 if fixture.order == "descending" else 1]
	for index in order.size():
		await _observe(order[index], index)
		if not report.failures.is_empty() or not sink.errors.is_empty():
			_finish(); return
	_marker("lifecycle-ready")
	var lifecycle := LifecycleProbe.new()
	root.add_child(lifecycle)
	telemetry.window.record(10000, 60)
	var until := Time.get_ticks_msec() + 30000
	while lifecycle.resumes == 0 and Time.get_ticks_msec() < until:
		await process_frame
	_check(lifecycle.pauses > 0 and lifecycle.resumes > 0 and telemetry.foreground and telemetry.window.count == 0, "Actual Android background/resume discards the interrupted sample")
	telemetry.queue.assign([{"test": true}])
	settings.set_share_android_performance(false)
	_check(telemetry.queue.is_empty() and telemetry.in_flight.is_empty() and not telemetry.is_processing(), "Actual opt-out clears pending data and stops sampling")
	report.lifecycle = {"pauses": lifecycle.pauses, "resumes": lifecycle.resumes, "opt_out_cleared": telemetry.queue.is_empty()}
	lifecycle.queue_free()
	report.complete = report.failures.is_empty()
	_finish()

func _finish() -> void:
	_release_stage()
	if is_instance_valid(settings):
		settings.set_share_android_performance(false)
	report.engine_errors = sink.errors.duplicate()
	_write(REPORT, report)
	OS.remove_logger(sink)
	quit(0 if report.complete and report.failures.is_empty() and sink.errors.is_empty() else 1)
