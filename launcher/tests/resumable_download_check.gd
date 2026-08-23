extends SceneTree

const DownloadService := preload("res://scripts/resumable_download_service.gd")
const EXPECTED_SIZE := 2097152
const EXPECTED_SHA256 := "91d3beb88a9b2f778a6c44a1c53b63d3c79931845a9aef84b3fb414610bd1938"

var failed := false
var base_url := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	base_url = OS.get_environment("LAUNCHER_RANGE_TEST_BASE_URL")
	_check(not base_url.is_empty(), "range test server URL is configured")
	if base_url.is_empty():
		quit(1)
		return
	_remove_test_downloads()

	await _run_download_case("drop", "/drop.bin", true, false)
	await _run_download_case("ignored-range", "/ignore-range.bin", true, true)
	await _run_download_case("retry-status", "/retry.bin", true, false)
	await _run_stall_case()
	await _run_bounded_failure_case()
	await _run_checksum_failure_case()
	await _run_restart_case()
	_check_static_parsers()
	_remove_test_downloads()

	if not failed:
		print("PASS launcher resumable_download_check")
	quit(1 if failed else 0)


func _run_download_case(case_id: String, path: String, expect_retry: bool, expect_reset: bool) -> void:
	var service := DownloadService.new()
	root.add_child(service)
	var events: Array[Dictionary] = []
	var result := {"done": false, "failed": false, "path": "", "summary": {}}
	service.diagnostic_event.connect(func(event: Dictionary) -> void: events.append(event.duplicate(true)))
	service.download_completed.connect(func(file_path: String, summary: Dictionary) -> void:
		result["done"] = true
		result["path"] = file_path
		result["summary"] = summary
	)
	service.download_failed.connect(func(_message: String, summary: Dictionary) -> void:
		result["done"] = true
		result["failed"] = true
		result["summary"] = summary
	)
	var start_error := service.start_download(_job(case_id, path))
	_check(start_error == OK, "%s download starts" % case_id)
	await _wait_until_done(result, 20.0)
	_check(bool(result.get("done", false)), "%s download finishes before timeout" % case_id)
	_check(not bool(result.get("failed", false)), "%s download succeeds" % case_id)
	var completed_path := str(result.get("path", ""))
	_check(FileAccess.file_exists(completed_path), "%s completed file exists" % case_id)
	if FileAccess.file_exists(completed_path):
		_check(FileAccess.get_size(completed_path) == EXPECTED_SIZE, "%s size is exact" % case_id)
		_check(FileAccess.get_sha256(completed_path) == EXPECTED_SHA256, "%s checksum is exact" % case_id)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(completed_path))
	if expect_retry:
		_check(_has_event(events, "download_retry"), "%s records a retry" % case_id)
	if expect_reset:
		_check(_has_event(events, "partial_reset"), "%s safely resets when Range is ignored" % case_id)
	service.queue_free()
	await process_frame


func _run_restart_case() -> void:
	var first_service := DownloadService.new()
	root.add_child(first_service)
	var first_progress := {"bytes": 0}
	first_service.progress_changed.connect(func(snapshot: Dictionary) -> void:
		first_progress["bytes"] = int(snapshot.get("downloaded_bytes", 0))
	)
	_check(first_service.start_download(_job("restart", "/slow.bin")) == OK, "restart download starts")
	var deadline := Time.get_ticks_msec() + 10000
	while int(first_progress.get("bytes", 0)) < 256 * 1024 and Time.get_ticks_msec() < deadline:
		await process_frame
	var saved_bytes := int(first_progress.get("bytes", 0))
	_check(saved_bytes >= 256 * 1024, "restart case receives partial data")
	first_service.cancel()
	first_service.queue_free()
	await process_frame

	var second_service := DownloadService.new()
	root.add_child(second_service)
	var events: Array[Dictionary] = []
	var result := {"done": false, "failed": false, "path": ""}
	second_service.diagnostic_event.connect(func(event: Dictionary) -> void: events.append(event.duplicate(true)))
	second_service.download_completed.connect(func(file_path: String, _summary: Dictionary) -> void:
		result["done"] = true
		result["path"] = file_path
	)
	second_service.download_failed.connect(func(_message: String, _summary: Dictionary) -> void:
		result["done"] = true
		result["failed"] = true
	)
	_check(second_service.start_download(_job("restart", "/slow.bin")) == OK, "restart resume starts")
	await _wait_until_done(result, 20.0)
	_check(not bool(result.get("failed", false)), "restart resume succeeds")
	_check(_event_has_positive_offset(events), "restart resumes from a saved byte offset")
	var completed_path := str(result.get("path", ""))
	if FileAccess.file_exists(completed_path):
		_check(FileAccess.get_sha256(completed_path) == EXPECTED_SHA256, "restart result checksum is exact")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(completed_path))
	second_service.queue_free()
	await process_frame


func _run_stall_case() -> void:
	var service := DownloadService.new()
	service.stall_warning_seconds = 0.1
	service.stall_reconnect_seconds = 0.25
	root.add_child(service)
	var events: Array[Dictionary] = []
	var result := {"done": false, "failed": false, "path": ""}
	service.diagnostic_event.connect(func(event: Dictionary) -> void: events.append(event.duplicate(true)))
	service.download_completed.connect(func(file_path: String, _summary: Dictionary) -> void:
		result["done"] = true
		result["path"] = file_path
	)
	service.download_failed.connect(func(_message: String, _summary: Dictionary) -> void:
		result["done"] = true
		result["failed"] = true
	)
	_check(service.start_download(_job("stall", "/stall.bin")) == OK, "stall download starts")
	await _wait_until_done(result, 20.0)
	_check(not bool(result.get("failed", false)), "stalled download reconnects and succeeds")
	_check(_has_event(events, "download_stall"), "stall is recorded")
	_check(_has_event(events, "download_retry"), "stall triggers a bounded reconnect")
	var completed_path := str(result.get("path", ""))
	if FileAccess.file_exists(completed_path):
		_check(FileAccess.get_sha256(completed_path) == EXPECTED_SHA256, "stalled download checksum is exact")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(completed_path))
	service.queue_free()
	await process_frame


func _run_bounded_failure_case() -> void:
	var service := DownloadService.new()
	service.max_retries = 2
	service.retry_delays_seconds = [0.0, 0.0]
	root.add_child(service)
	var result := {"done": false, "failed": false, "summary": {}}
	service.download_completed.connect(func(_file_path: String, _summary: Dictionary) -> void:
		result["done"] = true
	)
	service.download_failed.connect(func(_message: String, summary: Dictionary) -> void:
		result["done"] = true
		result["failed"] = true
		result["summary"] = summary
	)
	_check(service.start_download(_job("bounded-failure", "/always-503.bin")) == OK, "bounded failure download starts")
	await _wait_until_done(result, 5.0)
	_check(bool(result.get("failed", false)), "temporary failures stop after the retry limit")
	_check(int(result.get("summary", {}).get("retries", -1)) == 2, "failure summary records the bounded retry count")
	service.queue_free()
	await process_frame


func _run_checksum_failure_case() -> void:
	var service := DownloadService.new()
	root.add_child(service)
	var events: Array[Dictionary] = []
	var result := {"done": false, "failed": false}
	service.diagnostic_event.connect(func(event: Dictionary) -> void: events.append(event.duplicate(true)))
	service.download_completed.connect(func(_file_path: String, _summary: Dictionary) -> void:
		result["done"] = true
	)
	service.download_failed.connect(func(message: String, _summary: Dictionary) -> void:
		result["done"] = true
		result["failed"] = message.contains("checksum")
	)
	var invalid_job := _job("checksum-failure", "/stable.bin")
	invalid_job["sha256"] = "00".repeat(32)
	_check(service.start_download(invalid_job) == OK, "checksum failure download starts")
	await _wait_until_done(result, 10.0)
	_check(bool(result.get("failed", false)), "checksum mismatch fails after one clean redownload")
	_check(_event_count(events, "download_attempt") == 2, "checksum mismatch performs exactly one clean redownload")
	_check(_has_event(events, "partial_reset"), "checksum mismatch discards corrupt partial data")
	service.queue_free()
	await process_frame


func _job(case_id: String, path: String) -> Dictionary:
	return {
		"type": "test",
		"id": case_id,
		"version": "v1",
		"url": base_url + path,
		"size_bytes": EXPECTED_SIZE,
		"sha256": EXPECTED_SHA256,
		"download_dir": "user://range-test-downloads",
	}


func _wait_until_done(result: Dictionary, timeout_seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while not bool(result.get("done", false)) and Time.get_ticks_msec() < deadline:
		await process_frame


func _has_event(events: Array[Dictionary], event_name: String) -> bool:
	for event: Dictionary in events:
		if str(event.get("event", "")) == event_name:
			return true
	return false


func _event_count(events: Array[Dictionary], event_name: String) -> int:
	var count := 0
	for event: Dictionary in events:
		if str(event.get("event", "")) == event_name:
			count += 1
	return count


func _remove_test_downloads() -> void:
	var path := ProjectSettings.globalize_path("user://range-test-downloads")
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry not in [".", ".."] and not directory.current_is_dir():
			DirAccess.remove_absolute(path.path_join(entry))
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)


func _event_has_positive_offset(events: Array[Dictionary]) -> bool:
	for event: Dictionary in events:
		if str(event.get("event", "")) == "download_attempt" and int(event.get("offset", 0)) > 0:
			return true
	return false


func _check_static_parsers() -> void:
	var content_range := DownloadService.parse_content_range("bytes 10-19/100")
	_check(bool(content_range.get("valid", false)) and int(content_range.get("start", -1)) == 10, "Content-Range parser accepts valid ranges")
	_check(not bool(DownloadService.parse_content_range("bytes 20-10/100").get("valid", false)), "Content-Range parser rejects reversed ranges")
	var parsed_url := DownloadService.parse_http_url("https://updates.example:8443/assets/file.zip?x=1")
	_check(bool(parsed_url.get("valid", false)) and int(parsed_url.get("port", 0)) == 8443, "HTTP URL parser preserves explicit ports")
	_check(not bool(DownloadService.parse_http_url("file:///private/file.zip").get("valid", false)), "HTTP URL parser rejects non-HTTP schemes")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failed = true
	push_error("FAIL: %s" % message)
