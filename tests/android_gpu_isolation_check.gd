extends SceneTree
## Separate debug APK: production arena/models, fixed workload, reversible controls.
const Stage = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Pair = preload("res://scripts/services/model_pair_pilot.gd")
const Pool = preload("res://scripts/battle/arenas/shared/environment_pool.gd")
const Cutout = preload("res://scripts/battle/arenas/shared/android_grass_cutout.gd")
const Stats = preload("res://scripts/battle/battle_ui/android_3d_performance_probe.gd")
const REPORT := "user://android-gpu-details.json"
const MATRIX := ["baseline", "no_grass", "baseline", "no_shadows", "baseline", "msaa_2", "baseline", "msaa_off", "baseline"]
var fixture := {}
var report := {"schema": 1, "phases": [], "failures": [], "complete": false}
var stage: Control
var canvas: SubViewport
var pool: Node
var status: Label
var original_grass: Array = []
var original_lights: Array = []
var original_msaa: Array = []
var original_materials: Array = []
var dimensions := Vector2i.ZERO
class ErrorSink extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			errors.append(code + " " + rationale)
var sink := ErrorSink.new()

func _init() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> bool:
	if not ok:
		report.failures.append(message)
		print("ANDROID_GPU_FAIL ", message)
	return ok

func _write(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if _check(file != null, "Diagnostic report writable"):
		file.store_string(JSON.stringify(value))
		file.close()

func _marker(phase: String) -> void:
	status.text = "3D GPU benchmark · " + phase
	_write("user://android-gpu-phase.json", {"run_id": fixture.run_id, "phase": phase})
	print("ANDROID_GPU_PHASE ", phase)

func _views() -> Dictionary:
	return {"screen": root, "canvas": canvas, "main": stage.viewport, "response": pool.passes[1].viewport}

func _restore() -> void:
	for row in original_grass:
		if is_instance_valid(row[0]): row[0].visible = row[1]
	for row in original_lights:
		if is_instance_valid(row[0]): row[0].shadow_enabled = row[1]
	for row in original_msaa:
		if is_instance_valid(row[0]): row[0].msaa_3d = row[1]
	for row in original_materials:
		if is_instance_valid(row[0]): row[0].material_override = row[1]

func _control(variant: String) -> void:
	_restore()
	if variant == "no_grass":
		for row in original_grass: row[0].visible = false
	elif variant == "no_shadows":
		for row in original_lights: row[0].shadow_enabled = false
	elif variant in ["msaa_2", "msaa_off"]:
		for row in original_msaa:
			row[0].msaa_3d = Viewport.MSAA_2X if variant == "msaa_2" else Viewport.MSAA_DISABLED
	elif variant == "grass_early_cutout":
		for row in original_materials: row[0].material_override = row[2]
	for row in original_grass:
		_check(row[0].visible == (false if variant == "no_grass" else row[1]), "Grass control restored")
	for row in original_lights:
		_check(row[0].shadow_enabled == (false if variant == "no_shadows" else row[1]), "Shadow control restored")
	for row in original_msaa:
		var expected: int = Viewport.MSAA_DISABLED if variant == "msaa_off" else (Viewport.MSAA_2X if variant == "msaa_2" else row[1])
		_check(row[0].msaa_3d == expected, "MSAA control restored")
	for row in original_materials:
		_check(row[0].material_override == (row[2] if variant == "grass_early_cutout" else row[1]), "Grass material control restored")

func _collect_lights(node: Node) -> void:
	if node is Light3D:
		original_lights.append([node, node.shadow_enabled])
	for child in node.get_children(): _collect_lights(child)

func _record(samples: Dictionary, key: String, value: float) -> void:
	if not samples.has(key): samples[key] = []
	samples[key].append(value)

func _observe(variant: String, round_index: int, moves := false) -> void:
	_control(variant if not moves else "baseline")
	var label := "%d:%d:%s" % [round_index, report.phases.size(), variant]
	_marker("warm:" + label)
	var until := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until:
		await process_frame
	_marker(label)
	var started := Time.get_ticks_usec()
	var last := started
	var samples := {}
	var action_step := 0
	var pipelines_start: Array = stage._blocking_pipelines()
	while Time.get_ticks_usec() - started < int(fixture.phase_seconds) * 1000000:
		await process_frame
		var now := Time.get_ticks_usec()
		_record(samples, "engine_frame_ms", (now - last) / 1000.0)
		last = now
		var views := _views()
		for key in views:
			var view: Viewport = views[key]
			var rid := view.get_viewport_rid()
			_record(samples, key + "_cpu_ms", RenderingServer.viewport_get_measured_render_time_cpu(rid))
			_record(samples, key + "_gpu_ms", RenderingServer.viewport_get_measured_render_time_gpu(rid))
		var elapsed := (now - started) / 1000000.0
		if moves:
			if action_step == 0 and elapsed >= 1:
				stage.start_action("p1", "physical_attack")
				action_step = 1
			elif action_step == 1 and elapsed >= 4:
				stage.start_move_action("p1", "Flamethrower")
				_check(stage.create_move_effect("Flamethrower", "p1", "p2", {}) != null, "Flamethrower effect")
				action_step = 2
			elif action_step == 2 and elapsed >= 8:
				_check(stage.create_move_effect("Thunderbolt", "p1", "p2", {}) != null, "Thunderbolt effect")
				action_step = 3
		if not report.failures.is_empty() or not sink.errors.is_empty(): break
	var seconds := (Time.get_ticks_usec() - started) / 1000000.0
	var metrics := {"label": label, "variant": variant, "round": round_index,
		"seconds": seconds, "timings": {}, "pipeline_start": pipelines_start,
		"pipeline_end": stage._blocking_pipelines(), "models": stage.identities.duplicate(),
		"texture_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"render_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED), "viewports": {}}
	for key in samples:
		metrics.timings[key] = Stats.stats(samples[key])
		metrics.timings[key].p99 = _p99(samples[key])
	var frames: Array = samples.get("engine_frame_ms", [])
	metrics.fps = frames.size() / seconds
	metrics.frames_over_100_ms = frames.filter(func(value): return value > 100).size()
	for key in _views():
		var view: Viewport = _views()[key]
		var rid := view.get_viewport_rid()
		metrics.viewports[key] = {"size": [view.size.x, view.size.y], "msaa": view.msaa_3d,
			"visible_draws": RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
			"shadow_draws": RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)}
	_check(stage.active and stage.handles("p1") and stage.handles("p2"), "Resolved actors stay active")
	_check(stage.viewport.size == dimensions, "Main raster remains fixed")
	report.phases.append(metrics)
	_write(REPORT, report)
	_marker("capture:" + label)
	await RenderingServer.frame_post_draw
	_check(stage.viewport.get_texture().get_image().save_png("user://android-gpu-" + label.replace(":", "-") + ".png") == OK, "Diagnostic frame saved")
	print("ANDROID_GPU_RESULT ", JSON.stringify({"label": label, "fps": metrics.fps,
		"main_gpu_ms": metrics.timings.main_gpu_ms.p50, "frame_p95_ms": metrics.timings.engine_frame_ms.p95}))

static func _p99(values: Array) -> float:
	var ordered := values.duplicate()
	ordered.sort()
	return float(ordered[maxi(0, ceili(ordered.size() * .99) - 1)]) if not ordered.is_empty() else 0.0

static func valid_fixture(value: Variant) -> bool:
	if not value is Dictionary or value.get("schema") != 1:
		return false
	var seconds: Variant = value.get("phase_seconds")
	var rounds: Variant = value.get("rounds")
	if typeof(seconds) not in [TYPE_FLOAT, TYPE_INT] or typeof(rounds) not in [TYPE_FLOAT, TYPE_INT]:
		return false
	# JSON numbers are floats; Array membership distinguishes int and float.
	if float(seconds) not in [10.0, 15.0, 20.0] or float(rounds) not in [1.0, 2.0]:
		return false
	var run_id: Variant = value.get("run_id")
	return value.get("candidate", "") in ["", "grass_early_cutout"] and run_id is String and RegEx.create_from_string("^[0-9a-f]{32}$").search(run_id) != null

func _run() -> void:
	OS.add_logger(sink)
	if not _check(OS.has_feature("android_gpu_isolation") and OS.has_feature("android") and OS.is_debug_build(), "Dedicated physical debug benchmark only"):
		_finish(); return
	var file := FileAccess.open("user://android-gpu-fixture.json", FileAccess.READ)
	if not _check(file != null, "Bounded benchmark fixture supplied"):
		_finish(); return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not _check(valid_fixture(parsed), "Valid fixture contract"):
		_finish(); return
	fixture = parsed
	report.run_id = fixture.run_id
	report.renderer = RenderingServer.get_current_rendering_method()
	report.adapter = RenderingServer.get_video_adapter_name()
	report.models_revision = Pair.release().revision
	report.protocol = fixture.duplicate()
	if not _check(report.renderer == "mobile" and Pair.production_v14(), "Actual Mobile and approved v14 models"):
		_finish(); return
	status = Label.new()
	root.add_child(status)
	status.z_index = 100
	status.position = Vector2(12, 12)
	_marker("assets")
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_arena = "forest"
	settings.battle_3d_camera_motion = false
	root.get_node("WorldTimeService").set_debug_time(12)
	var environment := root.get_node("Android3DEnvironmentService")
	if not _check((await environment.ensure_ready()).is_empty(), "Pinned production arena available"):
		_finish(); return
	dimensions = root.size
	report.render_size = [dimensions.x, dimensions.y]
	# Normal gameplay prepares this session-owned pool before entering a battle.
	# Require the same path so the optimized response pass is actually exercised.
	pool = Pool.prepare(root, settings.get_battle_3d_forest_manifest(), dimensions, "forest")
	if not _check(pool != null, "Production environment pool created"):
		_finish(); return
	var pool_deadline := Time.get_ticks_msec() + 120000
	while not pool.ready_for_battle and not pool.failed and Time.get_ticks_msec() < pool_deadline:
		await process_frame
	if not _check(pool.ready_for_battle, "Production environment pool prepared"):
		_finish(); return
	for data in pool.passes:
		var light: Node = data.arena.get_node("OutdoorLighting")
		light.set_process(false)
		light.apply_seconds(43200.0)
	canvas = SubViewport.new()
	canvas.size = dimensions
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var surface := TextureRect.new()
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
	report.preparation = {"active": stage.active, "phase": stage.preparation_phase,
		"reason": stage.reason, "arena": stage.arena_id, "pooled": not stage.forest_lease.is_empty()}
	if not _check(stage.active and stage.handles("p1") and stage.handles("p2") and not stage.forest_lease.is_empty(), "Production forest and actors prepared"):
		_finish(); return
	pool = stage.forest_pool
	for data in pool.passes:
		var grasses: Array[Node] = data.arena.find_children("SharedForestGrass", "", true, false)
		if _check(grasses.size() == 1, "One grass graph in each authored arena hierarchy"):
			original_grass.append([grasses[0], grasses[0].visible])
		_collect_lights(data.world)
		original_msaa.append([data.viewport, data.viewport.msaa_3d])
	_check(original_grass.size() == 2, "Both original grass graphs present")
	if not report.failures.is_empty():
		_finish(); return
	if fixture.get("candidate", "") == "grass_early_cutout":
		var materials := {}
		for row in original_grass:
			for child in row[0].get_children():
				if child is MultiMeshInstance3D:
					var original: Material = child.material_override
					if not materials.has(original): materials[original] = Cutout.material(original)
					if not _check(materials[original] != null, "Approved grass shader matches cutout candidate"):
						_finish(); return
					original_materials.append([child, original, materials[original]])
	if not original_grass.is_empty():
		var grass_facts := {"batches": 0, "instances": 0, "shader": ""}
		for child in original_grass[0][0].get_children():
			if child is MultiMeshInstance3D:
				grass_facts.batches += 1
				grass_facts.instances += child.multimesh.instance_count
				if child.material_override is ShaderMaterial:
					grass_facts.shader = child.material_override.shader.code
		report.grass = grass_facts
	for view: Viewport in _views().values():
		RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), true)
	stage.playback_speed = 0.0
	RenderingServer.global_shader_parameter_set("wind_speed", 0.0)
	for round_index in int(fixture.rounds):
		var order := ["baseline", "grass_early_cutout", "baseline"] if fixture.get("candidate", "") == "grass_early_cutout" else MATRIX.duplicate()
		if round_index % 2 == 1: order.reverse()
		for variant: String in order:
			await _observe(variant, round_index)
			if not report.failures.is_empty() or not sink.errors.is_empty():
				_finish(); return
	stage.playback_speed = 1.0
	await _observe("moves_first", int(fixture.rounds), true)
	await _observe("moves_repeat", int(fixture.rounds), true)
	_restore()
	stage.queue_free()
	await process_frame
	report.complete = true
	_finish()

func _finish() -> void:
	_restore()
	report.engine_errors = sink.errors.duplicate()
	_write(REPORT, report)
	OS.remove_logger(sink)
	quit(0 if report.complete and report.failures.is_empty() and sink.errors.is_empty() else 1)
