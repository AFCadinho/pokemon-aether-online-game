extends SceneTree
## Local diagnostic: times the real synchronous install work without network I/O.
## slot-env SLOT -- godot --headless --path FRONTEND --script res://tools/benchmarks/model_install_latency.gd -- ASSET_JSON ARCHIVE_ZIP

const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")

var previous_frame := 0
var longest_frame_usec := 0
var frame_count := 0

class InstallProbe extends RefCounted:
	var result := {}
	var duration_ms := 0.0
	func run(service: Node, asset: Dictionary, archive: String) -> void:
		var start := Time.get_ticks_usec()
		if not service._valid_file(archive, int(asset.size_bytes), str(asset.sha256)):
			result = {"error": "Archive verification failed."}
		else:
			result = service._unpack_asset(asset, archive)
		duration_ms = (Time.get_ticks_usec() - start) / 1000.0

class PipelineProbe extends Service:
	var archive_path := ""
	func _fetch(_url: String, path: String, expected: int, digest: String, _limit: int, _label: String) -> String:
		# Supply an already downloaded approved input, then exercise the real
		# verification/publication/install path without network variability.
		var absolute := ProjectSettings.globalize_path(path)
		var copied: bool = await _run_storage_work(_copy_download.bind(absolute))
		if not copied:
			return "Could not prepare the benchmark archive."
		return await _run_storage_work(_publish_verified_download.bind(absolute, expected, digest))
	func _copy_download(absolute: String) -> bool:
		return DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) == OK and DirAccess.copy_absolute(archive_path, absolute + ".partial") == OK


func _init() -> void:
	process_frame.connect(_frame)
	_run.call_deferred()


func _frame() -> void:
	frame_count += 1
	var now := Time.get_ticks_usec()
	if previous_frame > 0:
		longest_frame_usec = maxi(longest_frame_usec, now - previous_frame)
	previous_frame = now


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected approved asset JSON and archive ZIP paths.")
		quit(1)
		return
	var asset: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var service := Service.new()
	root.add_child(service)
	var archive := args[1]
	await process_frame
	await process_frame
	var rows: Array[Dictionary] = []
	for iteration in 3:
		longest_frame_usec = 0
		var start := Time.get_ticks_usec()
		var valid := service._valid_file(archive, int(asset.size_bytes), str(asset.sha256))
		var archive_check_ms := (Time.get_ticks_usec() - start) / 1000.0
		if not valid:
			push_error("Archive does not match the approved metadata.")
			quit(1)
			return
		start = Time.get_ticks_usec()
		var installed: Dictionary = service._unpack_asset(asset, archive)
		var install_ms := (Time.get_ticks_usec() - start) / 1000.0
		if not str(installed.get("error", "")).is_empty():
			push_error(str(installed.error))
			quit(1)
			return
		await process_frame
		var install_frame_ms := longest_frame_usec / 1000.0
		start = Time.get_ticks_usec()
		for entry: Dictionary in installed.entries:
			assert(service._valid_file(entry.runtime_path, int(entry.bytes), str(entry.runtime_sha256)))
		var installed_check_ms := (Time.get_ticks_usec() - start) / 1000.0
		await process_frame
		rows.append({"iteration": iteration + 1, "archive_check_ms": archive_check_ms,
			"synchronous_install_ms": install_ms, "installed_check_ms": installed_check_ms,
			"blocking_work_ms": archive_check_ms + install_ms, "longest_install_frame_ms": install_frame_ms})
		await process_frame
	# Diagnostic comparison only: production still calls the synchronous path.
	longest_frame_usec = 0
	var frames_before := frame_count
	var probe := InstallProbe.new()
	var task := WorkerThreadPool.add_task(probe.run.bind(service, asset, archive))
	while not WorkerThreadPool.is_task_completed(task):
		await process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	assert(str(probe.result.get("error", "")).is_empty())
	var worker := {"work_ms": probe.duration_ms, "frames_during_work": frame_count - frames_before,
		"longest_frame_ms": longest_frame_usec / 1000.0}
	var pipeline := PipelineProbe.new()
	pipeline.archive_path = archive
	root.add_child(pipeline)
	pipeline._busy = true
	longest_frame_usec = 0
	frames_before = frame_count
	var started := Time.get_ticks_usec()
	var installed: Dictionary = await pipeline._install_asset(asset)
	assert(str(installed.get("error", "")).is_empty())
	var application := {"elapsed_ms": (Time.get_ticks_usec() - started) / 1000.0,
		"frames_during_work": frame_count - frames_before, "longest_frame_ms": longest_frame_usec / 1000.0}
	pipeline._busy = false
	pipeline.free()
	print("MODEL_INSTALL_LATENCY " + JSON.stringify({"asset_id": asset.asset_id,
		"archive_bytes": asset.size_bytes, "headless": true, "measurements": rows,
		"worker_comparison": worker, "application_install_comparison": application}))
	service.free()
	quit()
