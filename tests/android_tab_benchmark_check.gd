extends SceneTree
## Debug-only physical workload. Never extends production asset admission.
const Contract = preload("res://tools/sprite_factory/model_pair_bundle_contract.gd")
const Reviewed = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Pool = preload("res://scripts/battle/arenas/shared/environment_pool.gd")
const Catalog = preload("res://scripts/battle/arenas/arena_catalog.gd")
const Cache = preload("res://scripts/battle/battle_ui/model_resource_cache.gd")
const REPORT := "user://android-tab-benchmark-details.json"
const ORIGIN := "http://127.0.0.1:8799/"
const DIMENSIONS := Vector2i(960, 540)

class IsolationPool:
	extends "res://scripts/battle/arenas/shared/environment_pool.gd"
	var disable_msaa := false
	var disable_grass := false
	func _build_pass(light_pass: bool) -> Dictionary:
		var built := super._build_pass(light_pass)
		if disable_msaa:
			built.viewport.msaa_3d = Viewport.MSAA_DISABLED
		if disable_grass:
			var grass: Node3D = built.arena.find_child("SharedForestGrass", true, false)
			assert(grass != null)
			grass.visible = false
		return built

class PilotStage:
	extends "res://scripts/battle/battle_ui/experimental_battle_3d.gd"
	var qualified_entries := {}
	var qualified_profiles := {}
	func _ensure_downloaded_models(_preserve_actors := false) -> void:
		pass # The preceding pinned original/candidate check installed these PCKs.
	func _load_catalog(path: String, preserve_actors := false) -> void:
		assert(OS.is_debug_build() and OS.has_feature("android_tab_benchmark"))
		super._load_catalog(path, preserve_actors)
		catalog_entries = qualified_entries.duplicate(true)
		catalog_problem = ""
		_queue_needed_models()
	func _finish_validation(entry: Dictionary, check: IntegrityRead) -> bool:
		assert(OS.is_debug_build() and OS.has_feature("android_tab_benchmark"))
		var identity: String = entry.species
		var expected: Dictionary = qualified_entries.get(identity, {})
		var profile: Dictionary = qualified_profiles.get(identity, {})
		if expected.is_empty() or profile.is_empty() or check.digest != expected.runtime_sha256 or check.bytes != int(expected.bytes):
			failed_models[identity] = true
			return false
		var calibration: Dictionary = profile.get("grounding", {}).duplicate(true)
		if not calibration.is_empty():
			calibration.sha256 = check.digest
		var placement := ModelPlacement.resolve(entry, calibration, check.digest)
		if placement.is_empty():
			return false
		placements[identity] = placement
		ground_offsets.erase(identity)
		if placement.calibrated:
			ground_offsets[identity] = placement
		var motion: Dictionary = profile.get("motion", {}).duplicate(true)
		if not motion.is_empty():
			motion.sha256 = check.digest
		motion_clips[identity] = MotionPlacement.resolve(motion, placement, check.digest, entry.action_timing)
		if profile.get("bounds") is Dictionary:
			visual_bounds[identity] = profile.bounds
		entry["_verified_runtime_hash"] = check.digest
		entry["_source_bytes"] = check.bytes
		# Both arms disable prepared-resource LRU admission. This tests the new
		# layout's presenter compatibility; dependency-aware production LRU is pending.
		entry["_resource_cache_key"] = ""
		validated_entries[identity] = entry.duplicate(true)
		model_validation_ms += check.elapsed_ms
		return true

class ErrorSink extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			errors.append(code + " " + rationale)

var sink := ErrorSink.new()
var failures: Array[String] = []
var report := {"schema": 1, "suite": "android-tab-benchmark", "prototype_only": true, "phases": []}
var settings: Node
var stage: Control
var pool: Node
var canvas: SubViewport
var status: Label
var fixture := {}
var entries_by_kind := {}
var profiles := {}

func _init() -> void:
	_run.call_deferred()

func _check(ok: bool, reason: String) -> bool:
	if not ok:
		failures.append(reason)
		print("ANDROID_TAB_FAIL ", reason)
	return ok

func _write(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if _check(file != null, "Write report"):
		file.store_string(JSON.stringify(value, "\t"))
		file.close()

func _preparing(label: String) -> void:
	report["preparation_phase"] = label
	_write(REPORT, report)
	_write("user://android-tab-benchmark-phase.json", {"run_id": fixture.run_id, "label": label})
	print("ANDROID_TAB_PREPARING ", label)

func _stream_arena(path: String, pin: Dictionary) -> bool:
	var request := HTTPRequest.new()
	request.use_threads = true
	request.timeout = 120
	request.body_size_limit = 80 * 1024 * 1024
	request.download_file = path + ".partial"
	root.add_child(request)
	if not _check(request.request(ORIGIN + "forest.pck") == OK, "Arena stream starts"):
		request.queue_free()
		return false
	var result: Array = await request.request_completed
	request.queue_free()
	if not _check(result[0] == HTTPRequest.RESULT_SUCCESS and result[1] == 200, "Arena HTTP result=" + str(result[0]) + " status=" + str(result[1])):
		return false
	var file := FileAccess.open(path + ".partial", FileAccess.READ)
	if not _check(file != null and file.get_length() == int(pin.bytes) and FileAccess.get_sha256(path + ".partial") == pin.sha256, "Pinned streamed ETC2 arena"):
		return false
	file.close()
	return _check(DirAccess.rename_absolute(path + ".partial", path) == OK, "Publish streamed arena")

func _prepare_entries() -> bool:
	for kind in ["baseline", "shared"]:
		var entries := {}
		for pair: Dictionary in fixture.pairs:
			var pin: Dictionary = pair[kind]
			if not _check(Contract.validate(pin.resource_root, pin.manifest).is_empty(), "Closed model pack before rendering"):
				return false
			for model: Dictionary in pin.manifest.models:
				var original: Dictionary = pair.baseline.manifest.files.filter(func(f): return f.path == model.path)[0]
				var profile := Reviewed.resolve(model.identity, original.sha256)
				if not _check(not profile.is_empty(), "Original has checked-in placement/motion: " + str(model.identity)):
					return false
				var member: Dictionary = pin.manifest.files.filter(func(f): return f.path == model.path)[0]
				entries[model.identity] = {"species": model.identity, "variant": "shiny" if str(model.identity).ends_with("@shiny") else "normal",
					"runtime_schema": 1, "runtime_path": pin.resource_root.path_join(model.path), "runtime_sha256": member.sha256,
					"bytes": member.bytes, "placement": profile.placement, "action_timing": profile.action_timing,
					"attack_family_actions": profile.get("attack_family_actions", {})}
				profiles[model.identity] = profile
		entries_by_kind[kind] = entries
	return true

func _forest() -> bool:
	var pin: Dictionary = fixture.arena
	var path := "user://tab-forest-" + str(pin.sha256) + ".pck"
	var cached := FileAccess.open(path, FileAccess.READ)
	if cached == null or cached.get_length() != int(pin.bytes) or FileAccess.get_sha256(path) != pin.sha256:
		cached = null
		if not await _stream_arena(path, pin):
			return false
	else:
		cached.close()
	_write("user://tab-forest.json", {"schema": 1, "pack": path.get_file()})
	settings.battle_3d_forest_manifest = "user://tab-forest.json"
	if not _check(Catalog.prepare_forest(settings.battle_3d_forest_manifest).is_empty(), "Prepare forest"):
		return false
	var deadline := Time.get_ticks_msec() + 120000
	while not Catalog.forest_ready() and Catalog.forest_error.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	return _check(Catalog.forest_ready(), "Forest resource load")

func _new_stage(kind: String) -> void:
	var path := "user://tab-catalog-" + kind + ".json"
	_write(path, entries_by_kind[kind].values())
	settings.battle_3d_catalog_path = path
	settings._manual_model_catalog_this_session = true
	stage = PilotStage.new()
	stage.qualified_entries = entries_by_kind[kind]
	stage.qualified_profiles = profiles
	canvas.add_child(stage)
	stage.setup()
	stage.set_battle_context(&"grass", "wild")

func _prepare(left: String, shiny: bool) -> Dictionary:
	var started := Time.get_ticks_usec()
	stage.set_combatant(1, "Garchomp")
	stage.set_combatant(0, left, shiny, true)
	await stage.await_prepared(true, 60000)
	var identity := Reviewed.key(left, shiny)
	var ok := _check(stage.active and stage.handles("p1") and stage.handles("p2") and stage.arena_id == "forest", "3D actors and arena: " + identity + ": " + stage.reason)
	ok = _check(stage.identities[0] == identity and stage.viewport.size == DIMENSIONS, "Fixed raster / expected actor") and ok
	if stage.material_response.viewport != null:
		ok = _check(stage.material_response.viewport.size == DIMENSIONS, "Fixed irradiance raster") and ok
	return {"ok": ok, "elapsed_ms": (Time.get_ticks_usec() - started) / 1000.0, "preparation": stage.preparation_metrics.duplicate(true)}

func _observe(label: String, seconds: float, preparation: Dictionary) -> void:
	_write("user://android-tab-benchmark-phase.json", {"run_id": fixture.run_id, "label": label})
	print("ANDROID_TAB_PHASE ", label)
	var samples: Array[float] = []
	var started := Time.get_ticks_usec()
	var last := started
	var action_step := 0
	while (Time.get_ticks_usec() - started) / 1000000.0 < seconds:
		await process_frame
		var now := Time.get_ticks_usec()
		var elapsed := (now - started) / 1000000.0
		samples.append((now - last) / 1000.0)
		last = now
		status.text = "3D tablet test · %s\n%.0f FPS · %.1f minutes measured" % [label, Performance.get_monitor(Performance.TIME_FPS), float(report.get("observed_seconds", 0)) / 60.0 + elapsed / 60.0]
		if action_step == 0 and elapsed >= 2.0:
			stage.start_action("p1", "physical_attack")
			action_step = 1
		elif action_step == 1 and elapsed >= 6.0:
			stage.start_move_action("p1", "Flamethrower")
			_check(stage.create_move_effect("Flamethrower", "p1", "p2", {}) != null, "Real move effect")
			action_step = 2
		elif action_step == 2 and elapsed >= 11.0:
			stage.set_sleeping(0, true)
			action_step = 3
		elif action_step == 3 and elapsed >= 15.0:
			stage.set_sleeping(0, false)
			action_step = 4
		elif action_step == 4 and elapsed >= 18.0:
			stage.start_action("p1", "faint_start")
			action_step = 5
		if not stage.active or not failures.is_empty() or not sink.errors.is_empty():
			break
	var measured := (Time.get_ticks_usec() - started) / 1000000.0
	samples.sort()
	if not _check(not samples.is_empty(), "Frame samples"):
		return
	var phase := {"label": label, "seconds": measured, "frames": samples.size(), "fps_average": samples.size() / measured,
		"frame_p50_ms": samples[samples.size() / 2], "frame_p95_ms": samples[int(samples.size() * 0.95)], "frame_max_ms": samples.back(),
		"frames_over_33_ms": samples.filter(func(x): return x > 33.334).size(), "frames_over_100_ms": samples.filter(func(x): return x > 100.0).size(),
		"texture_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED), "render_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"identities": stage.identities.duplicate(), "preparation": preparation, "cache_entries": Cache.items.size()}
	report.phases.append(phase)
	report["observed_seconds"] = float(report.get("observed_seconds", 0)) + measured
	_write(REPORT, report)
	if report.phases.size() <= 4 or "mega" in label or "palkia" in label or "dondozo" in label:
		await RenderingServer.frame_post_draw
		_check(canvas.get_texture().get_image().save_png("user://tab-" + label + ".png") == OK, "Capture")

func _run() -> void:
	OS.add_logger(sink)
	if not _check(OS.has_feature("android") and OS.has_feature("android_tab_benchmark") and OS.is_debug_build(), "Physical debug benchmark only"):
		_finish()
		return
	# Use the exact fixture already fetched by the successful preceding check.
	# No second network request or regenerated model source enters this comparison.
	fixture = JSON.parse_string(FileAccess.get_file_as_string("user://android-tab-benchmark-fixture.json"))
	var prior: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://android-model-pairs-details.json"))
	if not _check(prior.get("success", false) and prior.get("run_id") == fixture.run_id, "Current original/candidate qualification completed"):
		_finish()
		return
	report["run_id"] = fixture.run_id
	report["renderer"] = RenderingServer.get_current_rendering_method()
	report["adapter"] = RenderingServer.get_video_adapter_name()
	report["render_size"] = [DIMENSIONS.x, DIMENSIONS.y]
	report["shader_cache"] = ProjectSettings.get_setting("rendering/shader_compiler/shader_cache/enabled", true)
	report["frame_pacing"] = ProjectSettings.get_setting("display/window/frame_pacing/android/enable_frame_pacing", true)
	report["msaa"] = "disabled-diagnostic" if fixture.get("disable_msaa", false) else "4x"
	report["grass"] = not fixture.get("disable_grass", false)
	report["models_only"] = fixture.get("models_only", false)
	if not _check(report.renderer == "mobile" and report.shader_cache and report.frame_pacing, "Ordinary Mobile defaults"):
		_finish()
		return
	if fixture.get("models_only", false):
		_finish()
		return
	settings = root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_arena = "forest"
	settings.battle_3d_camera_motion = false
	status = Label.new()
	status.position = Vector2(20, 20)
	status.add_theme_font_size_override("font_size", 20)
	root.add_child(status)
	status.text = "Preparing the 3D battlefield…"
	_preparing("forest-resources")
	if not _prepare_entries() or not await _forest():
		_finish()
		return
	Cache.clear()
	_preparing("forest-pool")
	if fixture.get("disable_msaa", false) or fixture.get("disable_grass", false):
		# Explicit isolation experiment; never a pass for the original 4x workload.
		pool = IsolationPool.new()
		pool.disable_msaa = fixture.get("disable_msaa", false)
		pool.disable_grass = fixture.get("disable_grass", false)
		pool.name = "IsolationDiagnosticPool"
		pool.render_size = DIMENSIONS
		pool.started = Time.get_ticks_msec()
		pool.memory_before = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
		pool.process_mode = Node.PROCESS_MODE_ALWAYS
		Pool.current = weakref(pool)
		root.add_child(pool)
	else:
		pool = Pool.prepare(root, settings.battle_3d_forest_manifest, DIMENSIONS, "forest")
	var deadline := Time.get_ticks_msec() + 120000
	while not pool.ready_for_battle and not pool.failed and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(pool.ready_for_battle, "Arena pool"):
		_finish()
		return
	for pass_data: Dictionary in pool.passes:
		var light: Node = pass_data.arena.get_node("OutdoorLighting")
		light.set_process(false)
		light.apply_seconds(43200.0)
	canvas = SubViewport.new()
	canvas.size = DIMENSIONS
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var surface := TextureRect.new()
	surface.texture = canvas.get_texture()
	surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	root.add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status.move_to_front()
	for shiny in [false, true]:
		for pair_index in fixture.pairs.size():
			var pair: Dictionary = fixture.pairs[pair_index]
			var kinds := ["baseline", "shared"] if pair_index % 2 == 0 else ["shared", "baseline"]
			for kind: String in kinds:
				_new_stage(kind)
				var prepared := await _prepare(pair.species, shiny)
				if not prepared.ok:
					_finish()
					return
				var label: String = str(pair_index) + "-" + str(pair.species) + "-" + kind + ("-shiny" if shiny else "-normal")
				await _observe(label, float(fixture.get("phase_seconds", 20.0)), prepared)
				stage.queue_free()
				await process_frame
				await process_frame
				stage = null
				if not failures.is_empty() or not sink.errors.is_empty():
					_finish()
					return
	# Exercise the actual anticipated Mega preload/reveal API on the shared pack.
	_new_stage("shared")
	var prepared := await _prepare("Garchomp", false)
	_check(prepared.ok and await stage.prepare_mega_form("p1", "Dragonite-Mega", false, 60000), "Mega model prepared before reveal")
	prepared = await _prepare("Dragonite-Mega", false)
	if prepared.ok:
		await _observe("mega-prepared-shared", 20.0, prepared)
	stage.queue_free()
	await process_frame
	await process_frame
	stage = null
	_check(pool.borrower == null and Cache.items.is_empty(), "Released scene and bounded cache")
	_finish()

func _finish() -> void:
	report["failures"] = failures
	report["engine_errors"] = sink.errors
	var expected_phases := 0 if fixture.get("models_only", false) else int(fixture.get("pairs", []).size()) * 4 + 1
	report["success"] = failures.is_empty() and sink.errors.is_empty() and report.phases.size() == expected_phases
	_write(REPORT, report)
	print("ANDROID_TAB_COMPLETE ", report.success)
	if status != null:
		status.text = "3D tablet test finished."
	quit(0 if report.success else 1)
