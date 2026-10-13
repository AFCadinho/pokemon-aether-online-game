extends Node
## Explicit local USB feature only. Emits numeric costs, never battle identities.
var stage: Control
var enabled_rids: Array[RID] = []
var samples := {}
var last_label := ""
var window_started := 0
var last_tick := 0

func _viewports() -> Dictionary:
	var result := {"screen": get_viewport(), "main": stage.viewport}
	result.response = stage.material_response.viewport if is_instance_valid(stage.material_response) else null
	return result

static func stats(values: Array) -> Dictionary:
	if values.is_empty():
		return {}
	var ordered := values.duplicate()
	ordered.sort()
	return {"count": ordered.size(), "p50": ordered[maxi(0, ceili(ordered.size() * .5) - 1)],
		"p95": ordered[maxi(0, ceili(ordered.size() * .95) - 1)], "max": ordered.back()}

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var label := "active" if stage.active else "inactive"
	if stage.warming_render or stage.arena_preparing or is_instance_valid(stage.model_downloader) or stage._models_pending():
		label = "preparing"
	if label != last_label:
		_emit(now)
		samples.clear()
		window_started = now
		last_tick = 0
		last_label = label
	if last_tick > 0:
		_record("engine_frame_ms", (now - last_tick) / 1000.0)
	last_tick = now
	_record("process_ms", Performance.get_monitor(Performance.TIME_PROCESS) * 1000)
	var views := _viewports()
	for key in views:
		var view: Viewport = views[key]
		if not is_instance_valid(view):
			continue
		var rid := view.get_viewport_rid()
		if rid not in enabled_rids:
			RenderingServer.viewport_set_measure_render_time(rid, true)
			enabled_rids.append(rid)
			continue # The first read is not yet measured.
		_record(key + "_cpu_ms", RenderingServer.viewport_get_measured_render_time_cpu(rid))
		_record(key + "_gpu_ms", RenderingServer.viewport_get_measured_render_time_gpu(rid))
	if now - window_started >= 5000000:
		_emit(now)
		samples.clear()
		window_started = now

func _record(key: String, value: float) -> void:
	if not samples.has(key):
		samples[key] = []
	samples[key].append(value)

func _emit(now: int) -> void:
	if samples.is_empty():
		return
	var record := {"phase": last_label, "seconds": (now - window_started) / 1000000.0,
		"renderer": RenderingServer.get_current_rendering_method(), "timings": {},
		"static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"render_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"texture_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"pipelines": stage._blocking_pipelines()}
	for key in samples:
		record.timings[key] = stats(samples[key])
	for key in _viewports():
		var view: Viewport = _viewports()[key]
		if is_instance_valid(view):
			record[key + "_size"] = [view.size.x, view.size.y]
			record[key + "_msaa"] = view.msaa_3d
	# Preparation dictionaries contain model names; allow only fixed numeric keys.
	var prep := {}
	for key in ["elapsed_ms", "forest_load_ms", "catalog_read_ms", "model_validation_ms", "arena_build_ms", "actor_build_ms", "render_warm_ms"]:
		var value: Variant = stage.preparation_metrics.get(key)
		if value is float or value is int:
			prep[key] = value
	record.preparation = prep
	var timings: Dictionary = record.timings
	record.erase("timings")
	# Godot's Android stdout truncates long lines. Keep each JSON record small.
	print("ANDROID_3D_PERFORMANCE ", JSON.stringify(record))
	for key in timings:
		var values: Dictionary = timings[key]
		for field in ["p50", "p95", "max"]:
			values[field] = snappedf(float(values[field]), .001)
		print("ANDROID_3D_TIMING ", JSON.stringify({"phase": last_label, "metric": key, "values": values}))

func _exit_tree() -> void:
	_emit(Time.get_ticks_usec())
	# The pool may retain the stage's viewports. Disable only still-live views.
	for key in _viewports():
		var view: Viewport = _viewports()[key]
		if is_instance_valid(view) and view.get_viewport_rid() in enabled_rids:
			RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), false)
