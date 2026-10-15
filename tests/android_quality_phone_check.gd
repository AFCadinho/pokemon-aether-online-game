extends SceneTree
## Separate debug APK only. Real production presenter/assets; fixed public actors.
const Stage := preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Pool := preload("res://scripts/battle/arenas/shared/environment_pool.gd")
const Quality := preload("res://scripts/services/android_quality_policy.gd")
const Stats := preload("res://scripts/battle/battle_ui/android_3d_performance_probe.gd")
const REPORT := "user://android-quality-details.json"
const FIXTURE := "user://android-quality-fixture.json"
const ORDERS := [["ultra", "high", "medium", "low", "ultra"], ["ultra", "low", "medium", "high", "ultra"]]
const MOVES := ["Flamethrower", "Thunderbolt", "Rock Slide", "Draco Meteor"]
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
var observation_lifecycle: Node
var soak_started := 0
var router: RefCounted
var gameplay_done := false
var gameplay_row := {}
var move_samples := {}
var profile_hitches := false
var profile_step := "idle"

# Diagnostic subclasses preserve the production implementations. Timing data
# stays in this private APK; none of these probes runs in the ordinary game.
class EffectProbe extends RefCounted:
	var events: Array = []
	var cap := {"dropped": 0}
	var move := ""
	var cpu_ms: Array = []
	func span(label: String, started: int) -> void:
		var ended := Time.get_ticks_usec()
		if events.size() >= 1024:
			cap.dropped += 1
			return
		events.append({"kind": "span", "label": label, "from_usec": started, "to_usec": ended,
			"ms": (ended-started)/1000.0})
	func record(effect: Node, started: int) -> void:
		var ended := Time.get_ticks_usec()
		var ms := (ended - started) / 1000.0
		cpu_ms.append(ms)
		if ms < 2.0: return
		if events.size() >= 1024:
			cap.dropped += 1
			return
		events.append({"kind": "effect_process", "move": move, "from_usec": started, "to_usec": ended,
			"ms": ms, "effect_seconds": effect.elapsed, "visible_pieces": effect.cursor})

class ProfiledFire extends "res://scripts/battle/battle_ui/fire_stream_move_effect_3d.gd":
	var probe := EffectProbe.new()
	func _process(delta: float) -> void:
		var started := Time.get_ticks_usec()
		super._process(delta)
		probe.record(self, started)

class ProfiledThunder extends "res://scripts/battle/battle_ui/thunderbolt_move_effect_3d.gd":
	var probe := EffectProbe.new()
	func _process(delta: float) -> void:
		var started := Time.get_ticks_usec()
		super._process(delta)
		probe.record(self, started)

class ProfiledRock extends "res://scripts/battle/battle_ui/extended_move_effect_3d.gd":
	var probe := EffectProbe.new()
	func _prepare() -> void:
		var started := Time.get_ticks_usec()
		super._prepare()
		probe.span("rock_prepare", started)
	func _wave_mesh() -> ArrayMesh:
		var started := Time.get_ticks_usec()
		var result := super._wave_mesh()
		probe.span("rock_wave_mesh", started)
		return result
	func _process(delta: float) -> void:
		var started := Time.get_ticks_usec()
		super._process(delta)
		probe.record(self, started)

class ProfiledDraco extends "res://scripts/battle/battle_ui/draco_meteor_effect_3d.gd":
	var probe := EffectProbe.new()
	func _process(delta: float) -> void:
		var started := Time.get_ticks_usec()
		super._process(delta)
		probe.record(self, started)

class ProfiledStage extends Stage:
	var hitch_events: Array = []
	var probes: Array = []
	var trace_cap := {"dropped": 0}
	var draw_profile_effects := true
	func new_move_effect(move: String) -> Node3D:
		var effect: Node3D
		match MoveEffect.move_key(move):
			"flamethrower": effect = ProfiledFire.new()
			"thunderbolt": effect = ProfiledThunder.new()
			"rockslide": effect = ProfiledRock.new()
			"dracometeor": effect = ProfiledDraco.new()
			_: return super.new_move_effect(move)
		effect.probe.events = hitch_events
		effect.probe.cap = trace_cap
		effect.probe.move = move
		effect.visible = draw_profile_effects
		probes.append(effect.probe)
		return effect
	func _record_android_move_phase(phase: String) -> void:
		if hitch_events.size() >= 1024:
			trace_cap.dropped += 1
			return
		hitch_events.append({"kind": "router_phase", "phase": phase, "at_usec": Time.get_ticks_usec()})

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
	var soak: bool = value.get("mode", "smoke") == "soak"
	var paired: bool = value.get("mode", "smoke") == "warm-compare"
	var gameplay: bool = value.get("mode") == "gameplay"
	if value.get("mode", "smoke") not in ["smoke", "soak", "warm-compare", "gameplay"]:
		return false
	if not value.get("profile_hitches", false) is bool or (value.get("profile_hitches", false) and not gameplay):
		return false
	if not value.get("hitch_visibility_control", false) is bool or (value.get("hitch_visibility_control", false) and not value.get("profile_hitches", false)):
		return false
	if soak and value.get("preset") not in ["low", "medium", "high", "ultra"]:
		return false
	var seconds: Variant = value.get("phase_seconds")
	var port: Variant = value.get("port")
	if not (seconds is float or seconds is int) or not (port is float or port is int):
		return false
	if float(seconds) not in ([30.0] if soak or paired or gameplay else [10.0, 15.0, 20.0]) or float(port) != floorf(float(port)) or port < 1024 or port > 65535:
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
	if router != null:
		router.cancel_render()
		router.release_threaded_resource_requests()
		router = null
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
	stage = ProfiledStage.new() if profile_hitches else Stage.new()
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
	stage.playback_speed = 1.0 if fixture.get("mode") == "gameplay" else 0.0
	RenderingServer.global_shader_parameter_set("wind_speed", 0.0)
	return _check(stage.quality_preset == preset and pool.quality_preset == preset, "Presenter and pool retain the same profile")

func _profile_span(label: String, started: int) -> void:
	if not profile_hitches: return
	if stage.hitch_events.size() >= 1024:
		stage.trace_cap.dropped += 1
		return
	var ended := Time.get_ticks_usec()
	stage.hitch_events.append({"kind": "span", "label": label, "from_usec": started, "to_usec": ended,
		"ms": (ended - started) / 1000.0})

func _verify_profile_factories() -> void:
	# Run after measurement: constructing controls must not prewarm the trial.
	var ordinary := Stage.new()
	report.profile_factory_match = true
	for move in MOVES:
		var original: Node = ordinary.new_move_effect(move)
		var wrapped: Node = stage.new_move_effect(move)
		report.profile_factory_match = report.profile_factory_match and original.get_script() == wrapped.get_script().get_base_script()
		original.free()
		wrapped.free()
	ordinary.free()
	_check(report.profile_factory_match, "Profiling wrappers preserve the actual production effect classes")

func _profile_menu_tabs(menu: Control) -> Array:
	var rows := []
	for tab in 8:
		profile_step = "menu_reopen_tab:%d" % tab
		var started := Time.get_ticks_usec()
		menu.tab_container.current_tab = tab
		_profile_span(profile_step, started)
		for frame in 10: await process_frame
		rows.append({"tab": tab, "visible": menu.visible and menu.tab_container.current_tab == tab})
	return rows

func _gameplay_sequence(index: int) -> void:
	gameplay_done = false
	gameplay_row = {"moves": [], "tabs": [], "complete": false}
	profile_step = "router_load_new"
	var router_started := Time.get_ticks_usec()
	router = load("res://scripts/battle/battle_animation_router.gd").new()
	_profile_span(profile_step, router_started)
	router.model_presenter = stage
	router.animation_parent = stage
	for i in MOVES.size():
		profile_step = "move:" + MOVES[i]
		var actor := "p1" if i % 2 == 0 else "p2"
		var target := "p2" if actor == "p1" else "p1"
		var started := Time.get_ticks_usec()
		move_samples = {"frame_ms": [], "main_gpu_ms": [], "response_gpu_ms": [], "effect_frames": 0,
			"visible_frames": 0, "render_visible_frames": 0, "suppressed_frames": 0, "hit_seen": false}
		await router.play_move_animation(MOVES[i], actor, target, {"show_impact": true})
		await router.finish_3d_impact_damage(target)
		var until := Time.get_ticks_msec() + 3000
		while not router.active_audio_nodes.is_empty() and Time.get_ticks_msec() < until:
			await process_frame
		var row := {"move": MOVES[i], "actor": actor, "seconds": (Time.get_ticks_usec() - started) / 1000000.0,
			"effect_frames": move_samples.effect_frames, "visible_frames": move_samples.visible_frames,
			"render_visible_frames": move_samples.render_visible_frames, "suppressed_frames": move_samples.suppressed_frames,
			"hit_seen": move_samples.hit_seen, "timings": {},
			"cleaned": stage.common_effects.is_empty() and router.active_audio_nodes.is_empty() and not router.has_3d_impact_damage()}
		for key in ["frame_ms", "main_gpu_ms", "response_gpu_ms"]:
			row.timings[key] = Stats.stats(move_samples[key])
		_check(row.visible_frames > 0 and row.hit_seen and row.cleaned, "Real move reached visible impact and effect/audio cleanup: " + MOVES[i])
		gameplay_row.moves.append(row)
		move_samples = {}
	profile_step = "menu_load"
	var menu_started := Time.get_ticks_usec()
	var packed: PackedScene = load("res://scenes/interface/settings/settings_menu.tscn")
	_profile_span(profile_step, menu_started)
	profile_step = "menu_instantiate"
	menu_started = Time.get_ticks_usec()
	var menu: Control = packed.instantiate()
	_profile_span(profile_step, menu_started)
	profile_step = "menu_add_ready"
	menu_started = Time.get_ticks_usec()
	root.add_child(menu)
	_profile_span(profile_step, menu_started)
	profile_step = "menu_open_new"
	menu_started = Time.get_ticks_usec()
	menu.open("game")
	_profile_span(profile_step, menu_started)
	for tab in 8:
		profile_step = "menu_tab:%d" % tab
		var started := Time.get_ticks_usec()
		menu.tab_container.current_tab = tab
		_profile_span(profile_step, started)
		for frame in 10:
			await process_frame
		gameplay_row.tabs.append({"tab": tab, "visible": menu.visible and menu.tab_container.current_tab == tab,
			"ten_frame_ms": (Time.get_ticks_usec() - started) / 1000.0})
	profile_step = "menu_close_new"
	menu_started = Time.get_ticks_usec()
	menu.close()
	_profile_span(profile_step, menu_started)
	_check(not menu.visible and settings.android_quality_preset == "medium", "Menu closes and retains Medium")
	if profile_hitches:
		gameplay_row.menu_instance = menu.get_instance_id()
		for frame in 10: await process_frame
		profile_step = "menu_open_retained"
		menu_started = Time.get_ticks_usec()
		menu.open("game")
		_profile_span(profile_step, menu_started)
		gameplay_row.reopened_menu_instance = menu.get_instance_id()
		gameplay_row.reopen_tabs = await _profile_menu_tabs(menu)
		profile_step = "menu_close_retained"
		menu_started = Time.get_ticks_usec()
		menu.close()
		_profile_span(profile_step, menu_started)
		_check(not menu.visible, "Retained menu closes")
	profile_step = "menu_queue_free"
	menu.queue_free()
	await process_frame
	profile_step = "idle"
	gameplay_row.complete = true
	gameplay_row.cycle = index
	gameplay_done = true

# Separate evidence pass: PNG readback/encoding is excluded from measured casts.
func _capture_moves() -> void:
	report.move_captures = []
	for i in MOVES.size():
		var done := {"value": false}
		_capture_cast(i, done)
		var until := Time.get_ticks_msec() + 20000
		while not done.value and Time.get_ticks_msec() < until:
			await process_frame
		_check(done.value, "Bounded move capture")
		if not done.value:
			router.cancel_render()
			return

func _capture_cast(index: int, done: Dictionary) -> void:
	var completed := {"value": false}
	var actor := "p1" if index % 2 == 0 else "p2"
	var target := "p2" if actor == "p1" else "p1"
	_capture_route(MOVES[index], actor, target, completed)
	var captured := false
	while not completed.value:
		await process_frame
		if captured:
			continue
		for effect in stage.common_effects:
			if _visible_impact(effect):
				var evidence := {"index": index, "elapsed": effect.elapsed, "impact": effect.impact, "visible_pieces": effect.cursor}
				await RenderingServer.frame_post_draw
				captured = stage.viewport.get_texture().get_image().save_png("user://android-quality-move-%d.png" % index) == OK
				report.move_captures.append(evidence)
				break
	_check(captured, "Actual move impact captured: " + MOVES[index])
	done.value = true

func _visible_impact(effect: Node) -> bool:
	# `hit` is an option set at creation, not an impact notification.
	return is_instance_valid(effect) and effect.hit and effect.elapsed >= effect.impact + 0.025 and effect.cursor > 0

func _capture_route(move: String, actor: String, target: String, done: Dictionary) -> void:
	await router.play_move_animation(move, actor, target, {"show_impact": true})
	await router.finish_3d_impact_damage(target)
	done.value = true

func _preheat() -> bool:
	if not await _prepare("high"):
		return false
	if not _check(report.native.has("thermalStatus"), "Native thermal status required for warm comparison"):
		return false
	observation_lifecycle = LifecycleProbe.new()
	root.add_child(observation_lifecycle)
	_marker("preheat:high")
	report.preheat = []
	report.preheat_ready = false
	report.preheat_stage = stage.get_instance_id()
	var started := Time.get_ticks_usec()
	var block_started := started
	var frames := 0
	while Time.get_ticks_usec() - started < 600000000:
		await process_frame
		if observation_lifecycle.pauses > 0 or observation_lifecycle.resumes > 0:
			_check(false, "Warm comparison interrupted during preheat")
			return false
		frames += 1
		var now := Time.get_ticks_usec()
		if now - block_started < 5000000:
			continue
		var native: Dictionary = telemetry._native_sample()
		var row := {"elapsed_seconds": (now - started) / 1000000.0,
			"fps": frames * 1000000.0 / (now - block_started), "native": native}
		report.preheat.append(row)
		if not _check(int(native.get("thermalStatus", 0)) < 4, "Preheat thermal status below critical"):
			return false
		report.preheat_ready = row.elapsed_seconds >= 30.0 and int(native.get("thermalStatus", 0)) >= 2 and row.fps <= 55.0
		_write(REPORT, report)
		if report.preheat_ready:
			return true
		block_started = Time.get_ticks_usec()
		frames = 0
	_check(false, "Warm comparison did not reach moderate thermal status and reduced High FPS within ten minutes")
	return false

func _observe(preset: String, index: int) -> void:
	var soak: bool = fixture.get("mode", "smoke") == "soak"
	var paired: bool = fixture.get("mode", "smoke") == "warm-compare"
	var gameplay: bool = fixture.get("mode") == "gameplay"
	var reuse: bool = (soak and index > 0) or (paired and index in [0, 2])
	var prepared := Time.get_ticks_msec()
	if not reuse and not await _prepare(preset):
		return
	if fixture.get("hitch_visibility_control", false):
		stage.draw_profile_effects = index in [0, 3]
	var preparation_ms := Time.get_ticks_msec() - prepared if not reuse else 0
	if not reuse:
		_marker("warm:" + preset)
		var warm_until := Time.get_ticks_msec() + (30000 if soak else 3000)
		while Time.get_ticks_msec() < warm_until:
			await process_frame
	if (soak or gameplay) and observation_lifecycle == null:
		observation_lifecycle = LifecycleProbe.new()
		root.add_child(observation_lifecycle)
	if not _check(stage.active and stage.handles("p1") and stage.handles("p2") and stage.quality_preset == preset and not stage.forest_lease.is_empty(), "Prepared workload remains active"):
		return
	telemetry._reset_window()
	telemetry.context = {"scene": "battle", "presentation": "3d", "preset": preset, "presetVersion": 1,
		"targetFps": 60, "renderWidth": stage.viewport.size.x, "renderHeight": stage.viewport.size.y,
		"screenWidth": dimensions.x, "screenHeight": dimensions.y}
	telemetry.native = telemetry._native_sample()
	var native_start: Dictionary = telemetry.native.duplicate()
	_marker("sample:%d:%s" % [index, preset])
	var started := Time.get_ticks_usec()
	if (soak or paired) and soak_started == 0:
		soak_started = started
	var last := started
	var samples := {"frame_ms": [], "main_gpu_ms": [], "response_gpu_ms": []}
	var pipeline_start: Array = stage._blocking_pipelines()
	var next_counters := started
	var last_step := "start"
	var previous_pipelines: Array = pipeline_start.duplicate()
	if profile_hitches:
		stage.hitch_events.clear()
	if gameplay:
		_gameplay_sequence(index)
	while Time.get_ticks_usec() - started < int(fixture.phase_seconds) * 1000000 or (gameplay and not gameplay_done):
		await process_frame
		if (soak or paired or gameplay) and (observation_lifecycle.pauses > 0 or observation_lifecycle.resumes > 0):
			_check(false, "Observation interrupted by Android background/resume")
			return
		var now := Time.get_ticks_usec()
		if profile_hitches:
			var pipelines: Array = stage._blocking_pipelines()
			if now - last > 25000:
				if stage.hitch_events.size() < 1024:
					stage.hitch_events.append({"kind": "slow_frame", "from_usec": last, "to_usec": now,
						"ms": (now-last)/1000.0, "from_step": last_step, "to_step": profile_step,
						"pipeline_before": previous_pipelines.duplicate(), "pipeline_after": pipelines.duplicate(),
						"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
						"main_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(stage.viewport.get_viewport_rid())})
				else: stage.trace_cap.dropped += 1
			previous_pipelines = pipelines
			last_step = profile_step
		if gameplay and not _check(now - started < 90000000, "Bounded gameplay cycle"):
			return
		samples.frame_ms.append((now - last) / 1000.0)
		if not move_samples.is_empty():
			move_samples.frame_ms.append((now - last) / 1000.0)
			if not stage.common_effects.is_empty():
				move_samples.effect_frames += 1
			for effect in stage.common_effects:
				if is_instance_valid(effect) and effect.cursor > 0:
					move_samples.visible_frames += 1
					if effect.is_visible_in_tree(): move_samples.render_visible_frames += 1
					else: move_samples.suppressed_frames += 1
				if _visible_impact(effect):
					move_samples.hit_seen = true
		telemetry.window.record(now - last, 60)
		telemetry.foreground_usec += now - last
		last = now
		for pass_index in 2:
			var rid: RID = pool.passes[pass_index].viewport.get_viewport_rid()
			var key := "main_gpu_ms" if pass_index == 0 else "response_gpu_ms"
			var gpu_ms := RenderingServer.viewport_get_measured_render_time_gpu(rid)
			samples[key].append(gpu_ms)
			if not move_samples.is_empty():
				move_samples[key].append(gpu_ms)
		if now >= next_counters:
			next_counters = now + 1000000
			telemetry._sample_counters()
	# End the measured interval before the synchronous native PSS query.
	var sampled_seconds: float = telemetry.window.total_usec / 1000000.0
	var sample_ended := Time.get_ticks_usec()
	telemetry.native = telemetry._native_sample()
	var row := {"preset": preset, "index": index, "seconds": sampled_seconds,
		"preparation_ms": preparation_ms, "render_size": [stage.viewport.size.x, stage.viewport.size.y],
		"response_size": [pool.passes[1].viewport.size.x, pool.passes[1].viewport.size.y],
		"msaa": stage.viewport.msaa_3d, "timings": {}, "pipeline_start": pipeline_start,
		"pipeline_end": stage._blocking_pipelines(), "native": telemetry.native.duplicate(),
		"render_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	if soak or paired or gameplay:
		row.stage_instance = stage.get_instance_id()
		row.elapsed_seconds = (sample_ended - soak_started) / 1000000.0
		_check(int(telemetry.native.get("thermalStatus", 0)) < 4, "Android thermal status below critical")
	if paired:
		row.native_start = native_start
	if gameplay:
		row.gameplay = gameplay_row.duplicate(true)
	if profile_hitches:
		row.hitch_profile = {"events": stage.hitch_events.duplicate(true), "dropped": stage.trace_cap.dropped,
			"effects_visible": stage.draw_profile_effects, "effects": []}
		for probe in stage.probes:
			row.hitch_profile.effects.append({"move": probe.move, "process_cpu_ms": Stats.stats(probe.cpu_ms)})
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
	if not soak or index in [0, 39]:
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
	profile_hitches = fixture.get("profile_hitches", false)
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
	settings.battle_animations = true
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
	if fixture.get("mode", "smoke") == "soak":
		order = []
		order.resize(40)
		order.fill(fixture.preset)
	elif fixture.get("mode", "smoke") == "warm-compare":
		if not await _preheat():
			_finish(); return
		order = ["high", "medium", "medium", "high"]
	elif fixture.get("mode") == "gameplay":
		order = ["medium", "medium", "medium"]
		if fixture.get("hitch_visibility_control", false):
			order.append("medium")
		report.note = "Offline animated renderer/router, real settings and repeated arena reconstructions; no authenticated world/network gameplay. Wind and camera fixed."
	for index in order.size():
		await _observe(order[index], index)
		if not report.failures.is_empty() or not sink.errors.is_empty():
			_finish(); return
	if fixture.get("mode") == "gameplay":
		if profile_hitches:
			_verify_profile_factories()
		await _capture_moves()
	if is_instance_valid(observation_lifecycle):
		_check(observation_lifecycle.pauses == 0 and observation_lifecycle.resumes == 0, "Uninterrupted observation")
		observation_lifecycle.free()
		observation_lifecycle = null
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
