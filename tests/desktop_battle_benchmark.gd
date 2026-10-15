extends "res://tests/android_quality_phone_check.gd"
## Real desktop renderer/ordinary host; reuse the checked four-cast/menu workload.
const DesktopQuality := preload("res://scripts/services/battle_quality_policy.gd")
const PairPack := preload("res://scripts/services/model_pair_pack.gd")
var output := ""
var entry_script: Script
var old_settings := ""
var settings_existed := false
var original_models: Node
class LocalModels extends Node:
	var catalog := ""
	func ensure_models(_ids: Array[String], _source: String) -> Dictionary:
		return {"error": "", "path": catalog, "catalog_changed": true}
	func progress_text() -> String: return ""
	func battle_download_progress() -> Dictionary: return {}
	func verify_shared_entry(entry: Dictionary) -> Dictionary:
		var asset: Dictionary = entry.pair_asset
		var checked := PairPack.inspect_entry(entry, asset)
		return {"error": checked.error, "asset": asset, "checked": checked}

func _marker(phase: String) -> void:
	print("DESKTOP_BENCHMARK_PHASE ", phase)
	if not output.is_empty(): _write(output.path_join("phase.json"), {"run_id": fixture.run_id, "phase": phase})

func _gameplay_profile_valid() -> bool:
	return settings.desktop_battle_quality_preset == stage.quality_preset

func _move_capture_path(index: int) -> String:
	return output.path_join("move-%d.png" % index)

func _run() -> void:
	OS.add_logger(sink)
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Pass one host-generated fixture path after --")
		quit(1); return
	fixture = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	output = fixture.output
	report = {"schema": 1, "run_id": fixture.run_id, "protocol": fixture, "phases": [], "failures": [], "complete": false,
		"renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(),
		"engine": Engine.get_version_info().string, "note": "Offline ordinary desktop host; no authenticated world/network gameplay."}
	if not _check(OS.has_feature("pc") and not OS.has_feature("android") and DisplayServer.get_name() != "headless" and report.renderer == "forward_plus", "Native visible Forward+ desktop required"):
		_finish(); return
	ProjectSettings.set_setting("_custom_features", "desktop_3d_move_warmup" if fixture.warmup else "")
	settings = root.get_node("SettingsManager")
	settings_existed = FileAccess.file_exists(settings.SETTINGS_PATH)
	old_settings = FileAccess.get_file_as_string(settings.SETTINGS_PATH) if settings_existed else ""
	if not _check(not root.get_node("AuthService").is_authenticated(), "No game account/session used"):
		_finish(); return
	DisplayServer.window_set_size(Vector2i(1600,900))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	settings.set_desktop_fps_limit(60)
	settings.battle_animations = true
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_arena = "forest"
	settings.battle_3d_camera_motion = false
	settings.battle_3d_forest_manifest = fixture.forest_manifest
	root.get_node("WorldTimeService").set_debug_time(12)
	var entries := []
	_marker("verify-assets")
	for item: Dictionary in fixture.models:
		var checked := PairPack.inspect(item.path, item.asset)
		if not _check(str(checked.error).is_empty(), "Real model pack verifies"): _finish(); return
		for entry: Dictionary in PairPack.catalog_entries(item.asset, item.path.get_base_dir()):
			entry.pack_path = item.path
			entries.append(entry)
	var catalog := output.path_join("models.json")
	var catalog_file := FileAccess.open(catalog, FileAccess.WRITE)
	catalog_file.store_string(JSON.stringify(entries))
	catalog_file.close()
	original_models = root.get_node("OnDemand3DBundleService")
	root.remove_child(original_models)
	var local := LocalModels.new()
	local.name = "OnDemand3DBundleService"
	local.catalog = catalog
	root.add_child(local)
	settings.battle_3d_catalog_path = catalog
	# Match a launcher-managed installation. A manual catalog intentionally
	# bypasses the host's pending-response gate and is a different entry flow.
	OS.set_environment("POKEAETHER_MODEL_CATALOG", catalog)
	settings._manual_model_catalog_this_session = false
	entry_script = load("res://tests/fixtures/android_battle_entry_trial.gd")
	for i in 3: await process_frame
	dimensions = root.size
	report.native_size = [dimensions.x, dimensions.y]
	var order: Array = fixture.order
	for i in order.size():
		await _desktop_observe(str(order[i]), i, fixture.mode == "soak" and i > 0)
		if not report.failures.is_empty() or not sink.errors.is_empty(): _finish(); return
	await _capture_moves()
	if fixture.mode != "soak":
		entry_trial.host._open_battle_settings()
		var menu: Control = entry_trial.host.battle_settings_menu
		menu.tab_container.current_tab = 2
		for i in 5: await process_frame
		await RenderingServer.frame_post_draw
		_check(menu.is_visible_in_tree() and entry_trial.host.settings_overlay.visible, "Ordinary host settings visibly open")
		_check(root.get_texture().get_image().save_png(output.path_join("graphics.png")) == OK, "Desktop settings captured")
		menu.close()
	report.complete = true
	_finish()

func _prepare(preset: String) -> bool:
	_release_stage()
	# Retire the previous world and its queued renderer resources before the
	# next allocation. Errors remain logged throughout this untimed boundary.
	for frame in 2: await process_frame
	await RenderingServer.frame_post_draw
	settings.set_desktop_battle_quality_preset(preset)
	_marker("prepare:" + preset)
	pool = Pool.prepare(root, settings.get_battle_3d_forest_manifest(), dimensions, "forest")
	if not _check(pool != null, "Real desktop arena pool created"): return false
	var deadline := Time.get_ticks_msec() + 120000
	while not pool.ready_for_battle and not pool.failed and Time.get_ticks_msec() < deadline: await process_frame
	if not _check(pool.ready_for_battle, "Real forest prepared"): return false
	for data in pool.passes:
		var light: Node = data.arena.get_node("OutdoorLighting")
		light.set_process(false)
		light.apply_seconds(43200.0)
	RenderingServer.global_shader_parameter_set("wind_speed", 0.0)
	entry_trial = entry_script.new()
	var kind: String = entry_script.CASES[entry_index % 3] if fixture.mode == "entry" else "covered_wild"
	await entry_trial.mount(self, kind)
	stage = entry_trial.stage
	entry_observation = await entry_trial.finish(self, 60000)
	if not _check(entry_trial.errors.is_empty() and entry_observation.ready and entry_observation.warmup_enabled == fixture.warmup and stage.active and stage.viewport != null, "Ordinary 3D intro/gate ready: " + stage.reason): return false
	# First-turn readiness can resume within the frame that rebuilds the early
	# arena's response pass. Match the phone fixture: observe after rendering,
	# outside both the recorded intro duration and the timed action window.
	for frame in 2: await process_frame
	await RenderingServer.frame_post_draw
	if not _check(stage.material_response.viewport != null, "Response pass exists after entry rendering"): return false
	var screen: Transform2D = stage.get_viewport().get_final_transform() * stage.get_global_transform_with_canvas()
	var arena := Vector2i(ceili(stage.size.x * screen.x.length()), ceili(stage.size.y * screen.y.length()))
	entry_observation.arena_native_size = [arena.x, arena.y]
	var expected := DesktopQuality.dimensions(arena, preset)
	_check(stage.viewport.size == expected and stage.material_response.viewport.size == expected and stage.quality_preset == preset, "Both passes use actual desktop profile dimensions")
	for view in [stage.viewport, stage.material_response.viewport]:
		RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), true)
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(output.path_join("entry-%d.png" % entry_index)) == OK, "Ordinary UI captured outside measurement")
	return report.failures.is_empty()

func _desktop_observe(preset: String, index: int, reuse: bool) -> void:
	entry_index = index
	if not reuse:
		if not await _prepare(preset): return
		var warm_until := Time.get_ticks_msec() + 3000
		while Time.get_ticks_msec() < warm_until: await process_frame
	_marker("sample:%d:%s" % [index,preset])
	var started := Time.get_ticks_usec()
	var last := started
	var samples := {"frame_ms": [], "main_gpu_ms": [], "response_gpu_ms": []}
	var render_peak := 0.0
	var pipeline_start: Array = stage._blocking_pipelines()
	_gameplay_sequence(index)
	while Time.get_ticks_usec() - started < int(fixture.seconds) * 1000000 or not gameplay_done:
		await process_frame
		var now := Time.get_ticks_usec()
		if not _check(now-started < (int(fixture.seconds)+90)*1000000, "Bounded action cycle"): return
		var frame_ms := (now-last)/1000.0
		samples.frame_ms.append(frame_ms)
		if not move_samples.is_empty():
			move_samples.frame_ms.append(frame_ms)
			if not stage.common_effects.is_empty(): move_samples.effect_frames += 1
			for effect in stage.common_effects:
				if is_instance_valid(effect) and effect.has_meta("android_prepared_cast"): move_samples.prepared_instance = effect.get_instance_id()
				if is_instance_valid(effect) and effect.cursor > 0:
					move_samples.visible_frames += 1
					if effect.is_visible_in_tree(): move_samples.render_visible_frames += 1
				if _visible_impact(effect): move_samples.hit_seen = true
		last = now
		for pass_index in 2:
			var key := "main_gpu_ms" if pass_index == 0 else "response_gpu_ms"
			var value := RenderingServer.viewport_get_measured_render_time_gpu(pool.passes[pass_index].viewport.get_viewport_rid())
			samples[key].append(value)
			if not move_samples.is_empty(): move_samples[key].append(value)
		render_peak = maxf(render_peak, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	var row := {"preset": preset, "index": index, "seconds": (last-started)/1000000.0, "timings": {}, "gameplay": gameplay_row.duplicate(true),
		"render_size": [stage.viewport.size.x, stage.viewport.size.y], "response_size": [stage.material_response.viewport.size.x, stage.material_response.viewport.size.y],
		"msaa": stage.viewport.msaa_3d, "entry": entry_observation.duplicate(true), "stage_instance": stage.get_instance_id(),
		"render_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED), "render_peak_bytes": render_peak,
		"pipeline_start": pipeline_start, "pipeline_end": stage._blocking_pipelines(), "focused": DisplayServer.window_is_focused()}
	for key in samples: row.timings[key] = Stats.stats(samples[key])
	row.fps = samples.frame_ms.size()/row.seconds
	report.phases.append(row)
	_write(output.path_join("details.json"), report)
	if index == 0 or index == fixture.order.size()-1:
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png(output.path_join("battle-%d.png" % index)) == OK, "Battle image outside timed interval")

func _finish() -> void:
	_release_stage()
	if is_instance_valid(original_models):
		root.get_node("OnDemand3DBundleService").free()
		root.add_child(original_models)
	if is_instance_valid(settings):
		if settings_existed:
			var file := FileAccess.open(settings.SETTINGS_PATH, FileAccess.WRITE)
			file.store_string(old_settings)
			file.close()
		else: DirAccess.remove_absolute(settings.SETTINGS_PATH)
	report.engine_errors = sink.errors.duplicate()
	if not output.is_empty(): _write(output.path_join("details.json"), report)
	OS.remove_logger(sink)
	quit(0 if report.complete and report.failures.is_empty() and sink.errors.is_empty() else 1)
