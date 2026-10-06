extends SceneTree
## Local future-release pin fixture; actual launcher downloader/adapter/store.
const Release = preload("res://scripts/release_asset_bundles.gd")
const Downloader = preload("res://scripts/resumable_download_service.gd")
const Approval = preload("res://scripts/model_pack_manifest.gd")
const Index = preload("res://scripts/asset_bundle_index.gd")
var fixture: Dictionary
var service: RefCounted
var downloader: Node
var base: String
var output: String
var phase: String
var report := {"complete": false, "prototype_only": true, "production_approved": false, "downloads": [], "stages": []}
var completed := false
var failure := ""
var downloaded := ""
var download_summary := {}
var cancellation_threshold := 0

class ErrorSink extends Logger:
	var tree: SceneTree
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, _kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		tree.call_deferred("abort_check", code + " " + rationale)

var sink := ErrorSink.new()

func cancel_fixture_download() -> void:
	download_summary = downloader._build_summary()
	downloader.cancel()
	failure = "cancelled-fixture"
	completed = true

func _init() -> void:
	_run.call_deferred()

func abort_check(message: String) -> void:
	report.complete = false
	report["failure"] = message
	save_report()
	quit(2)

func save_report() -> void:
	if output.is_empty():
		return
	var file := FileAccess.open(output.path_join(phase + "-report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")

func pin_stage(stage: Dictionary) -> Dictionary:
	# The isolated project compiles against generated future-release metadata.
	# No data mutation or approval-policy override occurs inside this script.
	var descriptor: Dictionary = stage.descriptor.duplicate(true)
	descriptor.url = base + "/" + descriptor.object_key
	descriptor.objectBaseUrl = base
	var pin_error := Release.descriptor_error(descriptor)
	assert(pin_error.is_empty(), pin_error + " fixture=" + str(stage.label))
	return descriptor

func download(job: Dictionary, cancel_after := 0) -> Dictionary:
	completed = false
	failure = ""
	downloaded = ""
	download_summary = {}
	cancellation_threshold = cancel_after
	job = job.duplicate(true)
	job.download_dir = output.path_join("downloads")
	if cancel_after > 0:
		job.parallel = false
	assert(downloader.start_download(job) == OK)
	var deadline := Time.get_ticks_msec() + 120000
	while not completed:
		assert(Time.get_ticks_msec() < deadline, "Launcher download did not complete")
		await process_frame
	var result := {"error": failure, "path": downloaded, "summary": download_summary.duplicate(true)}
	report.downloads.append({"id": job.id, "version": job.version, "error": failure,
		"cancelled": cancel_after > 0, "summary": download_summary.duplicate(true)})
	return result

func snapshot(label: String) -> void:
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string(service.catalog_path()))
	assert(catalog.size() == fixture.stages[0].models.size())
	for entry: Dictionary in catalog:
		assert(FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
	var file := FileAccess.open(output.path_join(label + "-catalog.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(catalog, "\t") + "\n")
	file.close()

func install_stage(stage: Dictionary) -> void:
	var descriptor := pin_stage(stage)
	var accepted: Dictionary = service.jobs(descriptor)
	assert(accepted.error.is_empty(), accepted.error)
	if not accepted.jobs.is_empty() and accepted.jobs[0].type == "asset_bundle_index":
		var result := await download(accepted.jobs[0])
		assert(result.error.is_empty(), result.error)
		accepted = service.accept_index(descriptor, result.path)
	assert(accepted.error.is_empty(), accepted.error)
	var index: Dictionary = service.cached_index(descriptor)
	assert(accepted.jobs.size() == index.assets.size())
	var started := Time.get_ticks_usec()
	for job: Dictionary in accepted.jobs:
		var transfer := await download(job)
		assert(transfer.error.is_empty(), transfer.error)
		var installed: Dictionary = service.accept_bundle(index, job.id, transfer.path)
		assert(installed.error.is_empty(), installed.error)
		DirAccess.remove_absolute(transfer.path)
	assert(service.jobs(descriptor).jobs.is_empty(), "Installed models were scheduled again")
	var generation: String = service.store.active_generation()
	service = Release.new(output.path_join("store"), output.path_join("indexes"))
	assert(service.store.active_generation() == generation)
	assert(service.jobs(descriptor).jobs.is_empty(), "Restart requested installed models again")
	snapshot(stage.label)
	report.stages.append({"label": stage.label, "bundles": index.assets.size(),
		"archive_bytes": stage.archive_bytes, "generation": generation,
		"installation_ms": (Time.get_ticks_usec() - started) / 1000.0,
		"restart_no_op": true, "catalog_path": service.catalog_path()})
	save_report()
	print("NATIVE_LAUNCHER_INSTALLED ", stage.label)

func _run() -> void:
	sink.tree = self
	OS.add_logger(sink)
	base = OS.get_environment("POKEAETHER_NATIVE_HTTP_BASE")
	output = OS.get_environment("POKEAETHER_NATIVE_INSTALL_OUTPUT")
	phase = OS.get_environment("POKEAETHER_NATIVE_PHASE")
	assert(base.begins_with("http://127.0.0.1:") and output.is_absolute_path())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	fixture = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("POKEAETHER_NATIVE_FIXTURE")))
	assert(fixture.prototype_only and not fixture.production_approved)
	service = Release.new(output.path_join("store"), output.path_join("indexes"))
	var unapproved: Dictionary = fixture.stages[-1].descriptor.duplicate(true)
	unapproved.url = base + "/" + unapproved.object_key
	unapproved.objectBaseUrl = base
	if phase == "policy":
		assert(not Release.descriptor_error(unapproved).is_empty(), "Unpublished subset unexpectedly release-approved")
		report["published_pins_reject_fixture"] = true
		report.complete = true
		save_report()
		quit()
		return
	downloader = Downloader.new()
	root.add_child(downloader)
	downloader.download_completed.connect(func(path: String, summary: Dictionary) -> void:
		downloaded = path; download_summary = summary; completed = true)
	downloader.download_failed.connect(func(message: String, summary: Dictionary) -> void:
		failure = message; download_summary = summary; completed = true)
	downloader.progress_changed.connect(func(progress: Dictionary) -> void:
		if cancellation_threshold > 0 and int(progress.get("downloaded_bytes", 0)) >= cancellation_threshold:
			cancellation_threshold = 0
			cancel_fixture_download.call_deferred())
	var stage: Dictionary = fixture.stages[0] if phase == "rollback" else fixture.stages.filter(func(item): return item.label == phase)[0]
	stage = stage.duplicate(true)
	stage.label = phase
	await install_stage(stage)
	if phase != "native-1m":
		report.complete = true
		save_report()
		quit()
		return
	var stable: String = service.store.active_generation()
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture.stages[-1].index_path))
	var descriptor := pin_stage(fixture.stages[-1])
	# Download cancellation and checksum failure must never activate an update.
	var asset: Dictionary = Index.by_id(index)[fixture.failure_asset_id]
	var job := {"type": "asset_bundle", "id": asset.asset_id, "version": str(asset.version),
		"url": base + "/fault/slow-cancel.zip", "sha256": asset.sha256,
		"size_bytes": asset.size_bytes, "file_name": str(asset.object_key).get_file()}
	var cancelled := await download(job, 262144)
	assert(cancelled.error == "cancelled-fixture" and int(cancelled.summary.get("downloaded_bytes", 0)) > 0 and service.store.active_generation() == stable)
	job.url = base + "/fault/corrupt.zip"
	var corrupt := await download(job)
	assert(not corrupt.error.is_empty() and service.store.active_generation() == stable)
	var bad: Dictionary = fixture.bad_manifest_index
	var bad_asset: Dictionary = Index.by_id(bad)[fixture.failure_asset_id]
	job.version = str(bad_asset.version); job.url = base + "/" + bad_asset.object_key
	job.sha256 = bad_asset.sha256; job.size_bytes = bad_asset.size_bytes
	var bad_transfer := await download(job)
	assert(bad_transfer.error.is_empty())
	assert(not service.accept_bundle(bad, bad_asset.asset_id, bad_transfer.path).error.is_empty())
	assert(service.store.active_generation() == stable)
	var immutable_violation: Dictionary = bad.duplicate(true)
	for row: Dictionary in immutable_violation.assets:
		if row.asset_id == asset.asset_id:
			row.version = asset.version
	assert(not service.accept_bundle(immutable_violation, asset.asset_id, bad_transfer.path).error.is_empty())
	assert(service.store.active_generation() == stable)
	DirAccess.remove_absolute(bad_transfer.path)
	var truncated := output.path_join("truncated.zip")
	var file := FileAccess.open(truncated, FileAccess.WRITE)
	file.store_buffer(FileAccess.get_file_as_bytes(fixture.routes["/" + asset.object_key]).slice(0, 100))
	file.close()
	assert(not service.accept_bundle(index, asset.asset_id, truncated).error.is_empty())
	assert(service.store.active_generation() == stable)
	report["cancel_preserves_active"] = true
	report["corrupt_download_preserves_active"] = true
	report["bad_manifest_preserves_active"] = true
	report["truncated_archive_preserves_active"] = true
	report["immutable_version_preserves_active"] = true
	report.complete = true
	save_report()
	print("NATIVE_LAUNCHER_CHECK_OK")
	quit()
