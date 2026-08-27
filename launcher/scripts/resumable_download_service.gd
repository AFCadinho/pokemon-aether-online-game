class_name ResumableDownloadService
extends Node

signal progress_changed(snapshot: Dictionary)
signal diagnostic_event(event: Dictionary)
signal download_completed(file_path: String, summary: Dictionary)
signal download_failed(message: String, summary: Dictionary)

const DEFAULT_DOWNLOAD_DIR := "user://downloads"
const MAX_RETRIES := 5
const MAX_REDIRECTS := 5
const STALL_WARNING_SECONDS := 30.0
const STALL_RECONNECT_SECONDS := 90.0
const PROGRESS_EMIT_INTERVAL_SECONDS := 0.25
const DIAGNOSTIC_SAMPLE_INTERVAL_SECONDS := 15.0
const RETRY_DELAYS_SECONDS: Array[float] = [2.0, 5.0, 15.0, 30.0, 60.0]
const READ_CHUNK_SIZE := 256 * 1024
const STALE_PARTIAL_MAX_AGE_SECONDS := 14 * 24 * 60 * 60
const PARALLEL_CONNECTIONS := 4
const PARALLEL_MIN_SIZE_BYTES := 8 * 1024 * 1024

enum DownloadState {
	IDLE,
	WAITING_TO_RETRY,
	CONNECTING,
	REQUESTING,
	READING_BODY,
}

var state := DownloadState.IDLE
var job: Dictionary = {}
var client: HTTPClient
var output_file: FileAccess
var part_path := ""
var metadata_path := ""
var request_url := ""
var response_headers: Dictionary = {}
var response_code := 0
var request_offset := 0
var expected_size := 0
var expected_sha256 := ""
var bytes_received := 0
var network_bytes_received := 0
var retry_count := 0
var checksum_retry_count := 0
var redirect_count := 0
var retry_at_msec := 0
var started_at_msec := 0
var attempt_started_at_msec := 0
var first_byte_at_msec := 0
var last_byte_at_msec := 0
var last_progress_emit_msec := 0
var last_diagnostic_sample_msec := 0
var speed_sample_at_msec := 0
var speed_sample_bytes := 0
var recent_bytes_per_second := 0.0
var stall_reported := false
var last_failure_reason := ""
var edge_code := ""
var stored_etag := ""
var resumed_bytes := 0
var stall_count := 0
var stall_warning_seconds := STALL_WARNING_SECONDS
var stall_reconnect_seconds := STALL_RECONNECT_SECONDS
var max_retries := MAX_RETRIES
var retry_delays_seconds: Array[float] = RETRY_DELAYS_SECONDS.duplicate()
var parallel_connection_count := PARALLEL_CONNECTIONS
var parallel_min_size_bytes := PARALLEL_MIN_SIZE_BYTES
var parallel_mode := false
var parallel_used := false
var parallel_fallback_used := false
var parallel_connections_peak := 0
var segments: Array[Dictionary] = []


func is_active() -> bool:
	return state != DownloadState.IDLE


func start_download(download_job: Dictionary) -> Error:
	if is_active():
		return ERR_BUSY

	var validation_error := _validate_job(download_job)
	if validation_error != OK:
		return validation_error

	job = download_job.duplicate(true)
	expected_size = int(job.get("size_bytes", 0))
	expected_sha256 = str(job.get("sha256", "")).strip_edges().to_lower()
	request_url = str(job.get("url", "")).strip_edges()
	parallel_mode = (
		bool(job.get("parallel", true))
		and parallel_connection_count > 1
		and expected_size >= parallel_min_size_bytes
	)
	parallel_used = false
	parallel_fallback_used = false
	parallel_connections_peak = 0
	segments.clear()
	retry_count = 0
	checksum_retry_count = 0
	redirect_count = 0
	bytes_received = 0
	network_bytes_received = 0
	resumed_bytes = 0
	stall_count = 0
	edge_code = ""
	stored_etag = ""
	last_failure_reason = ""
	started_at_msec = Time.get_ticks_msec()
	first_byte_at_msec = 0

	var download_dir := str(job.get("download_dir", DEFAULT_DOWNLOAD_DIR))
	var make_dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(download_dir))
	if make_dir_error != OK:
		_reset_runtime()
		return make_dir_error

	var identity := "%s\n%s\n%s\n%s\n%s" % [
		str(job.get("type", "download")),
		str(job.get("id", "download")),
		str(job.get("version", "")),
		expected_size,
		expected_sha256,
	]
	var safe_id := _safe_file_component(str(job.get("id", "download")))
	var identity_hash := identity.sha256_text().substr(0, 16)
	part_path = download_dir.path_join("%s-%s.part" % [safe_id, identity_hash])
	metadata_path = "%s.json" % part_path
	if parallel_mode:
		_initialize_segments()

	_cleanup_stale_partials(download_dir)
	_prepare_partial_download()
	_emit_event("download_start", {
		"offset": bytes_received,
		"expected_size": expected_size,
		"resumed": bytes_received > 0,
		"parallel": parallel_mode,
	})
	_begin_attempt()
	return OK


func cancel() -> void:
	if not is_active():
		return
	_close_connection()
	_emit_event("download_cancelled", {"downloaded_bytes": _current_downloaded_size()})
	_reset_runtime()


func _process(_delta: float) -> void:
	if state == DownloadState.IDLE:
		return

	var now := Time.get_ticks_msec()
	if state == DownloadState.WAITING_TO_RETRY:
		if now >= retry_at_msec:
			_begin_attempt()
		return
	if parallel_mode:
		_process_parallel(now)
		return

	if client == null:
		_schedule_retry("missing HTTP client")
		return

	var poll_error := client.poll()
	if poll_error != OK:
		_schedule_retry("network poll failed: %s" % error_string(poll_error))
		return

	match state:
		DownloadState.CONNECTING:
			_process_connecting()
		DownloadState.REQUESTING:
			_process_requesting()
		DownloadState.READING_BODY:
			_process_body()

	if state in [DownloadState.CONNECTING, DownloadState.REQUESTING, DownloadState.READING_BODY]:
		_process_stall_watchdog(now)
		_emit_progress_if_due(now)


func _process_connecting() -> void:
	var status := client.get_status()
	if status == HTTPClient.STATUS_CONNECTED:
		_send_request()
	elif status not in [HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING]:
		_schedule_retry("connection failed: status %d" % status)


func _process_requesting() -> void:
	var status := client.get_status()
	if status in [HTTPClient.STATUS_BODY, HTTPClient.STATUS_CONNECTED] and client.has_response():
		_handle_response_headers()
	elif status != HTTPClient.STATUS_REQUESTING:
		_schedule_retry("request failed: status %d" % status)


func _process_body() -> void:
	while client != null and client.get_status() == HTTPClient.STATUS_BODY:
		var chunk := client.read_response_body_chunk()
		if chunk.is_empty():
			break
		if output_file == null:
			_fail_terminal("download file is not open")
			return
		output_file.store_buffer(chunk)
		if output_file.get_error() != OK:
			_fail_terminal("download write failed: %s" % error_string(output_file.get_error()))
			return
		bytes_received += chunk.size()
		network_bytes_received += chunk.size()
		var now := Time.get_ticks_msec()
		if first_byte_at_msec == 0:
			first_byte_at_msec = now
		last_byte_at_msec = now
		stall_reported = false

	if client == null:
		return
	var status := client.get_status()
	if status == HTTPClient.STATUS_CONNECTED:
		_finish_response_body()
	elif status != HTTPClient.STATUS_BODY:
		_schedule_retry("connection ended before the response completed: status %d" % status)


func _process_parallel(now: int) -> void:
	var all_done := true
	for index in range(segments.size()):
		var segment: Dictionary = segments[index]
		if bool(segment.get("done", false)):
			continue
		all_done = false
		var segment_client: HTTPClient = segment.get("client")
		if segment_client == null:
			_schedule_retry("parallel segment %d is missing its HTTP client" % index)
			return
		var poll_error := segment_client.poll()
		if poll_error != OK:
			_schedule_retry("parallel segment %d network poll failed: %s" % [index, error_string(poll_error)])
			return
		match int(segment.get("state", DownloadState.CONNECTING)):
			DownloadState.CONNECTING:
				_process_parallel_connecting(index)
			DownloadState.REQUESTING:
				_process_parallel_requesting(index)
			DownloadState.READING_BODY:
				_process_parallel_body(index)
		if not parallel_mode or state == DownloadState.WAITING_TO_RETRY or job.is_empty():
			return

	if all_done or _all_parallel_segments_done():
		_merge_parallel_segments()
		return
	_process_parallel_stall_watchdog(now)
	if parallel_mode and state != DownloadState.WAITING_TO_RETRY:
		_emit_progress_if_due(now)


func _begin_parallel_attempt() -> void:
	_close_parallel_connections()
	_initialize_segments()
	bytes_received = _parallel_downloaded_size()
	if retry_count > 0 and bytes_received > 0:
		resumed_bytes = maxi(resumed_bytes, bytes_received)
	parallel_used = true
	state = DownloadState.CONNECTING
	attempt_started_at_msec = Time.get_ticks_msec()
	last_byte_at_msec = attempt_started_at_msec
	last_progress_emit_msec = 0
	last_diagnostic_sample_msec = attempt_started_at_msec
	speed_sample_at_msec = attempt_started_at_msec
	speed_sample_bytes = bytes_received
	recent_bytes_per_second = 0.0
	stall_reported = false

	var parsed := parse_http_url(request_url)
	if not bool(parsed.get("valid", false)):
		_fail_terminal("invalid download URL")
		return

	var active_connections := 0
	for index in range(segments.size()):
		var segment: Dictionary = segments[index]
		var segment_length := _segment_length(segment)
		var downloaded := _segment_file_size(segment)
		if downloaded == segment_length:
			segment["done"] = true
			continue
		if downloaded < 0 or downloaded > segment_length:
			_reset_partial_download("parallel segment %d has an invalid size" % index)
			_schedule_retry("invalid parallel partial required a clean restart", 0.0)
			return
		segment["downloaded"] = downloaded
		segment["request_start"] = int(segment.get("start", 0)) + downloaded
		segment["last_byte_at_msec"] = attempt_started_at_msec
		segment["stall_reported"] = false
		segment["state"] = DownloadState.CONNECTING
		var segment_client := HTTPClient.new()
		segment_client.read_chunk_size = READ_CHUNK_SIZE
		segment["client"] = segment_client
		var tls_options: TLSOptions = null
		if str(parsed.get("scheme", "")) == "https":
			tls_options = TLSOptions.client()
		var connect_error := segment_client.connect_to_host(
			str(parsed.get("host", "")),
			int(parsed.get("port", -1)),
			tls_options
		)
		if connect_error != OK:
			_schedule_retry("parallel segment %d could not connect: %s" % [index, error_string(connect_error)])
			return
		active_connections += 1

	parallel_connections_peak = maxi(parallel_connections_peak, active_connections)
	_emit_event("parallel_download_attempt", {
		"attempt": retry_count + 1,
		"connections": active_connections,
		"downloaded_bytes": bytes_received,
		"segments": segments.size(),
	})
	if active_connections == 0:
		_merge_parallel_segments()


func _process_parallel_connecting(index: int) -> void:
	var segment: Dictionary = segments[index]
	var segment_client: HTTPClient = segment.get("client")
	var status := segment_client.get_status()
	if status == HTTPClient.STATUS_CONNECTED:
		_send_parallel_request(index)
	elif status not in [HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING]:
		_schedule_retry("parallel segment %d connection failed: status %d" % [index, status])


func _send_parallel_request(index: int) -> void:
	var segment: Dictionary = segments[index]
	var parsed := parse_http_url(request_url)
	var request_start := int(segment.get("request_start", segment.get("start", 0)))
	var request_end := int(segment.get("end", -1))
	var headers := PackedStringArray([
		"User-Agent: PokeAetherLauncher/1.0",
		"Accept: application/octet-stream",
		"Accept-Encoding: identity",
		"Connection: keep-alive",
		"Range: bytes=%d-%d" % [request_start, request_end],
	])
	if not stored_etag.is_empty() and not stored_etag.begins_with("W/"):
		headers.append("If-Range: %s" % stored_etag)
	if checksum_retry_count > 0:
		headers.append("Cache-Control: no-cache")
		headers.append("Pragma: no-cache")
	var segment_client: HTTPClient = segment.get("client")
	var request_error := segment_client.request(
		HTTPClient.METHOD_GET,
		str(parsed.get("target", "/")),
		headers
	)
	if request_error != OK:
		_schedule_retry("parallel segment %d could not send request: %s" % [index, error_string(request_error)])
		return
	segment["state"] = DownloadState.REQUESTING


func _process_parallel_requesting(index: int) -> void:
	var segment: Dictionary = segments[index]
	var segment_client: HTTPClient = segment.get("client")
	var status := segment_client.get_status()
	if status in [HTTPClient.STATUS_BODY, HTTPClient.STATUS_CONNECTED] and segment_client.has_response():
		_handle_parallel_response_headers(index)
	elif status != HTTPClient.STATUS_REQUESTING:
		_schedule_retry("parallel segment %d request failed: status %d" % [index, status])


func _handle_parallel_response_headers(index: int) -> void:
	var segment: Dictionary = segments[index]
	var segment_client: HTTPClient = segment.get("client")
	var status_code := segment_client.get_response_code()
	var headers := _normalize_headers(segment_client.get_response_headers_as_dictionary())
	var segment_edge := _cloudflare_edge(str(headers.get("cf-ray", "")))
	if not segment_edge.is_empty():
		edge_code = segment_edge

	if status_code in [301, 302, 303, 307, 308]:
		_handle_parallel_redirect(str(headers.get("location", "")))
		return
	if status_code == 200:
		_fallback_to_single("server ignored bounded byte ranges")
		return
	if status_code != 206:
		var reason := "parallel segment %d HTTP %d" % [index, status_code]
		if _is_retriable_status(status_code):
			_schedule_retry(reason, _retry_after_from_headers(headers))
		else:
			_fail_terminal(reason)
		return

	var content_range := parse_content_range(str(headers.get("content-range", "")))
	var request_start := int(segment.get("request_start", -1))
	var request_end := int(segment.get("end", -1))
	if (
		not bool(content_range.get("valid", false))
		or int(content_range.get("start", -1)) != request_start
		or int(content_range.get("end", -1)) != request_end
		or int(content_range.get("total", 0)) != expected_size
	):
		_fallback_to_single("server returned an incompatible bounded byte range")
		return

	var response_etag := str(headers.get("etag", ""))
	if not stored_etag.is_empty() and not response_etag.is_empty() and response_etag != stored_etag:
		_reset_partial_download("parallel response ETag changed")
		_schedule_retry("parallel response changed during resume", 0.0)
		return
	if stored_etag.is_empty() and not response_etag.is_empty():
		stored_etag = response_etag
	if not _open_parallel_segment_for_append(index):
		_fail_terminal("could not open parallel segment %d for writing" % index)
		return
	_write_metadata()
	segment["state"] = DownloadState.READING_BODY
	_emit_event("parallel_response_headers", {
		"segment": index,
		"status": status_code,
		"offset": request_start,
		"content_range": str(headers.get("content-range", "")),
		"accept_ranges": str(headers.get("accept-ranges", "")),
		"edge": segment_edge,
	})


func _process_parallel_body(index: int) -> void:
	var segment: Dictionary = segments[index]
	var segment_client: HTTPClient = segment.get("client")
	while segment_client != null and segment_client.get_status() == HTTPClient.STATUS_BODY:
		var chunk := segment_client.read_response_body_chunk()
		if chunk.is_empty():
			break
		var segment_file: FileAccess = segment.get("file")
		if segment_file == null:
			_fail_terminal("parallel segment %d file is not open" % index)
			return
		if int(segment.get("downloaded", 0)) + chunk.size() > _segment_length(segment):
			_fail_terminal("parallel segment %d exceeded its expected size" % index)
			return
		segment_file.store_buffer(chunk)
		if segment_file.get_error() != OK:
			_fail_terminal("parallel segment %d write failed: %s" % [index, error_string(segment_file.get_error())])
			return
		segment["downloaded"] = int(segment.get("downloaded", 0)) + chunk.size()
		bytes_received += chunk.size()
		network_bytes_received += chunk.size()
		var now := Time.get_ticks_msec()
		if first_byte_at_msec == 0:
			first_byte_at_msec = now
		last_byte_at_msec = now
		segment["last_byte_at_msec"] = now
		segment["stall_reported"] = false

	if segment_client == null:
		return
	var status := segment_client.get_status()
	if status == HTTPClient.STATUS_CONNECTED:
		_finish_parallel_segment(index)
	elif status != HTTPClient.STATUS_BODY:
		_schedule_retry("parallel segment %d ended before completion: status %d" % [index, status])


func _finish_parallel_segment(index: int) -> void:
	var segment: Dictionary = segments[index]
	_close_parallel_segment(index)
	var actual_size := _segment_file_size(segment)
	if actual_size != _segment_length(segment):
		_schedule_retry("parallel segment %d ended early at %d bytes" % [index, actual_size])
		return
	segment["downloaded"] = actual_size
	segment["done"] = true
	_emit_event("parallel_segment_complete", {
		"segment": index,
		"segments": segments.size(),
		"downloaded_bytes": bytes_received,
	})


func _process_parallel_stall_watchdog(now: int) -> void:
	for index in range(segments.size()):
		var segment: Dictionary = segments[index]
		if bool(segment.get("done", false)):
			continue
		var stalled_seconds := float(now - int(segment.get("last_byte_at_msec", now))) / 1000.0
		if stalled_seconds >= stall_warning_seconds and not bool(segment.get("stall_reported", false)):
			segment["stall_reported"] = true
			stall_count += 1
			_emit_event("download_stall", {
				"segment": index,
				"seconds_without_bytes": int(stalled_seconds),
				"downloaded_bytes": bytes_received,
			})
		if stalled_seconds >= stall_reconnect_seconds:
			_schedule_retry("parallel segment %d received no bytes for %d seconds" % [index, int(stalled_seconds)])
			return


func _handle_parallel_redirect(location: String) -> void:
	var trimmed := location.strip_edges()
	if trimmed.is_empty():
		_fail_terminal("parallel redirect response has no Location header")
		return
	redirect_count += 1
	if redirect_count > MAX_REDIRECTS:
		_fail_terminal("redirect limit reached")
		return
	request_url = resolve_redirect_url(request_url, trimmed)
	if not bool(parse_http_url(request_url).get("valid", false)):
		_fail_terminal("redirect URL is invalid")
		return
	_emit_event("download_redirect", {"redirect": redirect_count, "parallel": true})
	_schedule_retry("following parallel download redirect", 0.0, false)


func _fallback_to_single(reason: String) -> void:
	_close_parallel_connections()
	_remove_parallel_segment_files()
	_remove_file(metadata_path)
	parallel_mode = false
	parallel_fallback_used = true
	bytes_received = 0
	resumed_bytes = 0
	stored_etag = ""
	_emit_event("parallel_download_fallback", {"reason": reason})
	_begin_attempt()


func _merge_parallel_segments() -> void:
	_close_parallel_connections()
	for segment: Dictionary in segments:
		if _segment_file_size(segment) != _segment_length(segment):
			_schedule_retry("parallel segments were incomplete before merge")
			return
	var merged_file := FileAccess.open(part_path, FileAccess.WRITE)
	if merged_file == null:
		_fail_terminal("could not create merged parallel download")
		return
	for segment: Dictionary in segments:
		var segment_file := FileAccess.open(str(segment.get("path", "")), FileAccess.READ)
		if segment_file == null:
			merged_file.close()
			_reset_partial_download("parallel segment disappeared before merge")
			_fail_terminal("could not read parallel segment during merge")
			return
		while segment_file.get_position() < segment_file.get_length():
			var remaining := segment_file.get_length() - segment_file.get_position()
			var chunk := segment_file.get_buffer(mini(READ_CHUNK_SIZE, remaining))
			if chunk.is_empty() and remaining > 0:
				segment_file.close()
				merged_file.close()
				_reset_partial_download("parallel segment read failed during merge")
				_fail_terminal("could not merge parallel segment")
				return
			merged_file.store_buffer(chunk)
			if merged_file.get_error() != OK:
				segment_file.close()
				merged_file.close()
				_reset_partial_download("parallel merged file write failed")
				_fail_terminal("could not write merged parallel download")
				return
		segment_file.close()
	merged_file.flush()
	merged_file.close()
	_remove_parallel_segment_files()
	parallel_mode = false
	bytes_received = _partial_file_size()
	_emit_event("parallel_download_merged", {
		"connections": parallel_connections_peak,
		"actual_size": bytes_received,
	})
	_verify_completed_download()


func _begin_attempt() -> void:
	_close_connection()
	if parallel_mode:
		_begin_parallel_attempt()
		return
	state = DownloadState.CONNECTING
	request_offset = _partial_file_size()
	bytes_received = request_offset
	if retry_count > 0 and request_offset > 0:
		resumed_bytes = maxi(resumed_bytes, request_offset)
	attempt_started_at_msec = Time.get_ticks_msec()
	last_byte_at_msec = attempt_started_at_msec
	last_progress_emit_msec = 0
	last_diagnostic_sample_msec = attempt_started_at_msec
	speed_sample_at_msec = attempt_started_at_msec
	speed_sample_bytes = bytes_received
	recent_bytes_per_second = 0.0
	stall_reported = false

	var parsed := parse_http_url(request_url)
	if not bool(parsed.get("valid", false)):
		_fail_terminal("invalid download URL")
		return

	client = HTTPClient.new()
	client.read_chunk_size = READ_CHUNK_SIZE
	var tls_options: TLSOptions = null
	if str(parsed.get("scheme", "")) == "https":
		tls_options = TLSOptions.client()
	var connect_error := client.connect_to_host(
		str(parsed.get("host", "")),
		int(parsed.get("port", -1)),
		tls_options
	)
	if connect_error != OK:
		_schedule_retry("could not start connection: %s" % error_string(connect_error))
		return

	_emit_event("download_attempt", {
		"attempt": retry_count + 1,
		"offset": request_offset,
		"redirect": redirect_count,
	})


func _send_request() -> void:
	var parsed := parse_http_url(request_url)
	var headers := PackedStringArray([
		"User-Agent: PokeAetherLauncher/1.0",
		"Accept: application/octet-stream",
		"Accept-Encoding: identity",
		"Connection: keep-alive",
	])
	if request_offset > 0:
		headers.append("Range: bytes=%d-" % request_offset)
		if not stored_etag.is_empty() and not stored_etag.begins_with("W/"):
			headers.append("If-Range: %s" % stored_etag)
	if checksum_retry_count > 0:
		headers.append("Cache-Control: no-cache")
		headers.append("Pragma: no-cache")

	var request_error := client.request(
		HTTPClient.METHOD_GET,
		str(parsed.get("target", "/")),
		headers
	)
	if request_error != OK:
		_schedule_retry("could not send request: %s" % error_string(request_error))
		return
	state = DownloadState.REQUESTING


func _handle_response_headers() -> void:
	response_code = client.get_response_code()
	response_headers = _normalize_headers(client.get_response_headers_as_dictionary())
	edge_code = _cloudflare_edge(str(response_headers.get("cf-ray", "")))
	var response_etag := str(response_headers.get("etag", ""))
	if not response_etag.is_empty():
		stored_etag = response_etag

	if response_code in [301, 302, 303, 307, 308]:
		_handle_redirect()
		return

	if response_code == 416:
		if expected_size > 0 and _partial_file_size() == expected_size:
			_verify_completed_download()
		else:
			_reset_partial_download("range rejected for incomplete file")
			_schedule_retry("HTTP 416 required a clean restart", 0.0)
		return

	if response_code == 206:
		var content_range := parse_content_range(str(response_headers.get("content-range", "")))
		if not bool(content_range.get("valid", false)):
			_fail_terminal("invalid Content-Range response")
			return
		if int(content_range.get("start", -1)) != request_offset:
			_fail_terminal("Content-Range starts at an unexpected byte")
			return
		var range_total := int(content_range.get("total", 0))
		if expected_size > 0 and range_total > 0 and range_total != expected_size:
			_fail_terminal("Content-Range total does not match the manifest")
			return
	elif response_code == 200:
		if request_offset > 0:
			_reset_partial_download("server returned a full response to a Range request")
			request_offset = 0
	else:
		var reason := "HTTP %d" % response_code
		if _is_retriable_status(response_code):
			_schedule_retry(reason, _retry_after_seconds())
		else:
			_fail_terminal(reason)
		return

	if response_code not in [200, 206]:
		return
	if not _open_partial_for_append():
		_fail_terminal("could not open partial download for writing")
		return
	_write_metadata()
	state = DownloadState.READING_BODY
	_emit_event("response_headers", {
		"status": response_code,
		"offset": request_offset,
		"content_range": str(response_headers.get("content-range", "")),
		"accept_ranges": str(response_headers.get("accept-ranges", "")),
		"edge": edge_code,
	})


func _finish_response_body() -> void:
	_close_output_file()
	var actual_size := _partial_file_size()
	bytes_received = actual_size
	if expected_size > 0 and actual_size < expected_size:
		_schedule_retry("response ended early at %d of %d bytes" % [actual_size, expected_size])
		return
	if expected_size > 0 and actual_size > expected_size:
		_reset_partial_download("download exceeded expected size")
		_schedule_retry("download size exceeded the manifest", 0.0)
		return
	_verify_completed_download()


func _verify_completed_download() -> void:
	_close_connection()
	state = DownloadState.IDLE
	var actual_size := _partial_file_size()
	if expected_size > 0 and actual_size != expected_size:
		_schedule_retry("download size mismatch: expected %d, got %d" % [expected_size, actual_size])
		return

	_emit_event("download_verifying", {"size": actual_size})
	var actual_sha256 := ""
	if not expected_sha256.is_empty():
		actual_sha256 = FileAccess.get_sha256(part_path).to_lower()
		if actual_sha256 != expected_sha256:
			if checksum_retry_count < 1:
				checksum_retry_count += 1
				var clean_restart_error := _prepare_clean_checksum_retry()
				if clean_restart_error != OK:
					_fail_terminal(
						"could not prepare a clean checksum retry: %s" % error_string(clean_restart_error)
					)
					return
				_schedule_retry("checksum mismatch required a clean restart", 0.0, false)
				return
			_fail_terminal("download checksum mismatch")
			return

	_remove_file(metadata_path)
	var summary := _build_summary()
	summary["actual_size"] = actual_size
	summary["actual_sha256"] = actual_sha256
	_emit_event("download_complete", summary)
	var completed_path := part_path
	_reset_runtime()
	download_completed.emit(completed_path, summary)


func _handle_redirect() -> void:
	var location := str(response_headers.get("location", "")).strip_edges()
	if location.is_empty():
		_fail_terminal("redirect response has no Location header")
		return
	redirect_count += 1
	if redirect_count > MAX_REDIRECTS:
		_fail_terminal("redirect limit reached")
		return
	request_url = resolve_redirect_url(request_url, location)
	if not bool(parse_http_url(request_url).get("valid", false)):
		_fail_terminal("redirect URL is invalid")
		return
	_emit_event("download_redirect", {"redirect": redirect_count})
	_begin_attempt()


func _process_stall_watchdog(now: int) -> void:
	var stalled_seconds := float(now - last_byte_at_msec) / 1000.0
	if stalled_seconds >= stall_warning_seconds and not stall_reported:
		stall_reported = true
		stall_count += 1
		_emit_event("download_stall", {
			"seconds_without_bytes": int(stalled_seconds),
			"downloaded_bytes": bytes_received,
		})
	if stalled_seconds >= stall_reconnect_seconds:
		_schedule_retry("no bytes received for %d seconds" % int(stalled_seconds))


func _emit_progress_if_due(now: int) -> void:
	if last_progress_emit_msec > 0 and now - last_progress_emit_msec < int(PROGRESS_EMIT_INTERVAL_SECONDS * 1000.0):
		return
	last_progress_emit_msec = now
	var speed_elapsed := float(now - speed_sample_at_msec) / 1000.0
	if speed_elapsed >= 2.0:
		recent_bytes_per_second = float(bytes_received - speed_sample_bytes) / speed_elapsed
		speed_sample_at_msec = now
		speed_sample_bytes = bytes_received
	var snapshot := _progress_snapshot(now)
	progress_changed.emit(snapshot)
	if now - last_diagnostic_sample_msec >= int(DIAGNOSTIC_SAMPLE_INTERVAL_SECONDS * 1000.0):
		last_diagnostic_sample_msec = now
		_emit_event("download_progress", snapshot)


func _progress_snapshot(now: int = 0) -> Dictionary:
	if now <= 0:
		now = Time.get_ticks_msec()
	var elapsed_seconds := maxf(float(now - started_at_msec) / 1000.0, 0.001)
	return {
		"downloaded_bytes": bytes_received,
		"total_bytes": expected_size,
		"recent_bytes_per_second": maxf(recent_bytes_per_second, 0.0),
		"average_bytes_per_second": float(network_bytes_received) / elapsed_seconds,
		"seconds_without_bytes": maxf(float(now - last_byte_at_msec) / 1000.0, 0.0),
		"retry": retry_count,
		"max_retries": max_retries,
		"state": DownloadState.keys()[state],
	}


func _schedule_retry(reason: String, requested_delay: float = -1.0, count_retry: bool = true) -> void:
	if state == DownloadState.IDLE and job.is_empty():
		return
	_close_connection()
	last_failure_reason = reason
	if count_retry:
		if retry_count >= max_retries:
			_fail_terminal("%s after %d retries" % [reason, retry_count])
			return
		retry_count += 1
	var delay := requested_delay
	if delay < 0.0:
		var delay_index := clampi(maxi(retry_count - 1, 0), 0, retry_delays_seconds.size() - 1)
		delay = retry_delays_seconds[delay_index]
	if delay > 0.0:
		var jitter := delay * randf_range(-0.15, 0.15)
		delay = maxf(delay + jitter, 0.25)
	retry_at_msec = Time.get_ticks_msec() + int(delay * 1000.0)
	state = DownloadState.WAITING_TO_RETRY
	_emit_event("download_retry", {
		"retry": retry_count,
		"max_retries": max_retries,
		"delay_seconds": snappedf(delay, 0.1),
		"reason": reason,
		"resume_offset": _current_downloaded_size(),
	})


func _fail_terminal(message: String) -> void:
	_close_connection()
	last_failure_reason = message
	var summary := _build_summary()
	_emit_event("download_failed", summary)
	_reset_runtime()
	download_failed.emit(message, summary)


func _build_summary() -> Dictionary:
	var now := Time.get_ticks_msec()
	var duration_seconds := maxf(float(now - started_at_msec) / 1000.0, 0.0)
	return {
		"id": str(job.get("id", "download")),
		"type": str(job.get("type", "download")),
		"version": str(job.get("version", "")),
		"expected_size": expected_size,
		"downloaded_bytes": _current_downloaded_size(),
		"network_bytes_received": network_bytes_received,
		"duration_seconds": snappedf(duration_seconds, 0.1),
		"time_to_first_byte_seconds": -1.0 if first_byte_at_msec == 0 else snappedf(float(first_byte_at_msec - started_at_msec) / 1000.0, 0.1),
		"average_bytes_per_second": 0.0 if duration_seconds <= 0.0 else float(network_bytes_received) / duration_seconds,
		"retries": retry_count,
		"stalls": stall_count,
		"resumed_bytes": resumed_bytes,
		"edge": edge_code,
		"last_failure": last_failure_reason,
		"parallel_used": parallel_used,
		"parallel_connections": parallel_connections_peak,
		"parallel_fallback": parallel_fallback_used,
	}


func _prepare_partial_download() -> void:
	var metadata := _read_metadata()
	var metadata_matches := (
		str(metadata.get("identity", "")) == _job_identity()
		and int(metadata.get("expected_size", -1)) == expected_size
		and str(metadata.get("sha256", "")).to_lower() == expected_sha256
		and str(metadata.get("url", "")) == _url_without_query(str(job.get("url", "")))
	)
	if parallel_mode and str(metadata.get("mode", "")) == "parallel":
		if not metadata_matches or not _parallel_layout_matches(metadata):
			_reset_partial_download("stale or incompatible parallel partial download")
			return
		stored_etag = str(metadata.get("etag", ""))
		bytes_received = _parallel_downloaded_size()
		resumed_bytes = bytes_received
		return

	var partial_size := _partial_file_size()
	if partial_size <= 0:
		if not metadata.is_empty() or _parallel_downloaded_size() > 0:
			_reset_partial_download("incomplete download metadata did not match available partials")
			return
		_remove_file(part_path)
		_remove_file(metadata_path)
		bytes_received = 0
		return

	if not metadata_matches or (expected_size > 0 and partial_size > expected_size):
		_reset_partial_download("stale or incompatible partial download")
		return
	parallel_mode = false
	stored_etag = str(metadata.get("etag", ""))
	bytes_received = partial_size
	resumed_bytes = partial_size


func _open_partial_for_append() -> bool:
	_close_output_file()
	output_file = FileAccess.open(part_path, FileAccess.READ_WRITE)
	if output_file == null:
		output_file = FileAccess.open(part_path, FileAccess.WRITE_READ)
	if output_file == null:
		return false
	output_file.seek_end()
	return true


func _close_output_file() -> void:
	if output_file != null:
		output_file.flush()
		output_file.close()
		output_file = null


func _close_connection() -> void:
	_close_output_file()
	_close_parallel_connections()
	if client != null:
		client.close()
		client = null


func _reset_partial_download(reason: String) -> void:
	_close_connection()
	_remove_file(part_path)
	_remove_parallel_segment_files()
	_remove_file(metadata_path)
	bytes_received = 0
	stored_etag = ""
	speed_sample_at_msec = Time.get_ticks_msec()
	speed_sample_bytes = 0
	recent_bytes_per_second = 0.0
	_emit_event("partial_reset", {"reason": reason})


func _prepare_clean_checksum_retry() -> Error:
	_close_connection()
	var corrupt_part_path := part_path
	var corrupt_metadata_path := metadata_path
	_remove_file(corrupt_part_path)
	_remove_file(corrupt_metadata_path)

	# A virus scanner or another Windows process can temporarily retain the
	# completed ZIP. Reusing its deterministic path would then turn the promised
	# clean retry into another Range request against the same corrupt bytes.
	# Always select a previously unused path, independent of whether deletion of
	# the corrupt file succeeded.
	var base_path := corrupt_part_path.trim_suffix(".part")
	var selected_path := ""
	for suffix in range(1, 1000):
		var candidate := "%s.clean-%d.part" % [base_path, suffix]
		if not FileAccess.file_exists(candidate) and not FileAccess.file_exists("%s.json" % candidate):
			selected_path = candidate
			break
	if selected_path.is_empty():
		return ERR_ALREADY_EXISTS

	part_path = selected_path
	metadata_path = "%s.json" % part_path
	bytes_received = 0
	stored_etag = ""
	speed_sample_at_msec = Time.get_ticks_msec()
	speed_sample_bytes = 0
	recent_bytes_per_second = 0.0
	_emit_event("partial_reset", {
		"reason": "checksum mismatch",
		"fresh_file": true,
		"corrupt_file_removed": not FileAccess.file_exists(corrupt_part_path),
	})
	return OK


func _write_metadata() -> void:
	var metadata := {
		"identity": _job_identity(),
		"url": _url_without_query(str(job.get("url", ""))),
		"expected_size": expected_size,
		"sha256": expected_sha256,
		"etag": stored_etag,
		"mode": "parallel" if parallel_mode else "single",
	}
	if parallel_mode:
		var metadata_segments: Array[Dictionary] = []
		for segment: Dictionary in segments:
			metadata_segments.append({
				"index": int(segment.get("index", -1)),
				"start": int(segment.get("start", -1)),
				"end": int(segment.get("end", -1)),
			})
		metadata["segments"] = metadata_segments
	var temp_path := "%s.tmp" % metadata_path
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(metadata, "  ") + "\n")
	file.close()
	_remove_file(metadata_path)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(metadata_path))


func _read_metadata() -> Dictionary:
	if not FileAccess.file_exists(metadata_path):
		return {}
	var file := FileAccess.open(metadata_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _partial_file_size() -> int:
	if part_path.is_empty() or not FileAccess.file_exists(part_path):
		return 0
	return FileAccess.get_size(part_path)


func _current_downloaded_size() -> int:
	return _parallel_downloaded_size() if parallel_mode else _partial_file_size()


func _initialize_segments() -> void:
	segments.clear()
	var connection_count := mini(maxi(parallel_connection_count, 2), expected_size)
	var base_size := int(expected_size / connection_count)
	var remainder := expected_size % connection_count
	var start := 0
	for index in range(connection_count):
		var length := base_size + (1 if index < remainder else 0)
		var finish := start + length - 1
		segments.append({
			"index": index,
			"start": start,
			"end": finish,
			"path": _segment_path(index),
			"downloaded": 0,
			"request_start": start,
			"client": null,
			"file": null,
			"state": DownloadState.IDLE,
			"done": false,
			"last_byte_at_msec": 0,
			"stall_reported": false,
		})
		start = finish + 1


func _segment_path(index: int) -> String:
	return "%s.segment-%d.part" % [part_path, index]


func _segment_length(segment: Dictionary) -> int:
	return int(segment.get("end", -1)) - int(segment.get("start", 0)) + 1


func _segment_file_size(segment: Dictionary) -> int:
	var path := str(segment.get("path", ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		return 0
	return FileAccess.get_size(path)


func _parallel_downloaded_size() -> int:
	var total := 0
	for segment: Dictionary in segments:
		total += _segment_file_size(segment)
	return total


func _parallel_layout_matches(metadata: Dictionary) -> bool:
	var metadata_segments: Variant = metadata.get("segments", [])
	if typeof(metadata_segments) != TYPE_ARRAY or metadata_segments.size() != segments.size():
		return false
	for index in range(segments.size()):
		var saved: Variant = metadata_segments[index]
		if typeof(saved) != TYPE_DICTIONARY:
			return false
		var segment: Dictionary = segments[index]
		if (
			int(saved.get("index", -1)) != index
			or int(saved.get("start", -1)) != int(segment.get("start", -2))
			or int(saved.get("end", -1)) != int(segment.get("end", -2))
			or _segment_file_size(segment) > _segment_length(segment)
		):
			return false
	return true


func _open_parallel_segment_for_append(index: int) -> bool:
	_close_parallel_segment_file(index)
	var segment: Dictionary = segments[index]
	var path := str(segment.get("path", ""))
	var segment_file := FileAccess.open(path, FileAccess.READ_WRITE)
	if segment_file == null:
		segment_file = FileAccess.open(path, FileAccess.WRITE_READ)
	if segment_file == null:
		return false
	segment_file.seek_end()
	segment["downloaded"] = segment_file.get_length()
	segment["file"] = segment_file
	return true


func _close_parallel_segment_file(index: int) -> void:
	if index < 0 or index >= segments.size():
		return
	var segment: Dictionary = segments[index]
	var segment_file: FileAccess = segment.get("file")
	if segment_file != null:
		segment_file.flush()
		segment_file.close()
		segment["file"] = null


func _close_parallel_segment(index: int) -> void:
	if index < 0 or index >= segments.size():
		return
	_close_parallel_segment_file(index)
	var segment: Dictionary = segments[index]
	var segment_client: HTTPClient = segment.get("client")
	if segment_client != null:
		segment_client.close()
		segment["client"] = null


func _close_parallel_connections() -> void:
	for index in range(segments.size()):
		_close_parallel_segment(index)


func _remove_parallel_segment_files() -> void:
	for index in range(maxi(segments.size(), parallel_connection_count)):
		_remove_file(_segment_path(index))


func _all_parallel_segments_done() -> bool:
	if segments.is_empty():
		return false
	for segment: Dictionary in segments:
		if not bool(segment.get("done", false)):
			return false
	return true


func _job_identity() -> String:
	return "%s:%s:%s" % [
		str(job.get("type", "download")),
		str(job.get("id", "download")),
		str(job.get("version", "")),
	]


func _validate_job(download_job: Dictionary) -> Error:
	if str(download_job.get("id", "")).strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	if str(download_job.get("version", "")).strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	if int(download_job.get("size_bytes", 0)) <= 0:
		return ERR_INVALID_PARAMETER
	if not bool(parse_http_url(str(download_job.get("url", ""))).get("valid", false)):
		return ERR_INVALID_PARAMETER
	var sha256 := str(download_job.get("sha256", "")).strip_edges()
	if not sha256.is_empty() and (sha256.length() != 64 or not sha256.is_valid_hex_number()):
		return ERR_INVALID_PARAMETER
	return OK


func _retry_after_seconds() -> float:
	return _retry_after_from_headers(response_headers)


func _retry_after_from_headers(headers: Dictionary) -> float:
	var value := str(headers.get("retry-after", "")).strip_edges()
	if value.is_valid_int():
		return clampf(float(value.to_int()), 0.0, 300.0)
	return -1.0


func _is_retriable_status(status_code: int) -> bool:
	return status_code in [408, 425, 429, 500, 502, 503, 504]


func _emit_event(event_name: String, details: Dictionary = {}) -> void:
	var payload := {
		"event": event_name,
		"id": str(job.get("id", "download")),
		"version": str(job.get("version", "")),
	}
	for key: Variant in details:
		payload[key] = details[key]
	diagnostic_event.emit(payload)


func _reset_runtime() -> void:
	_close_connection()
	state = DownloadState.IDLE
	job = {}
	part_path = ""
	metadata_path = ""
	request_url = ""
	response_headers = {}
	response_code = 0
	parallel_mode = false
	segments.clear()


func _remove_file(path: String) -> void:
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _cleanup_stale_partials(download_dir: String) -> void:
	var directory := DirAccess.open(download_dir)
	if directory == null:
		return
	var now := int(Time.get_unix_time_from_system())
	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		if not directory.current_is_dir() and (entry_name.ends_with(".part") or entry_name.ends_with(".part.json")):
			var candidate := download_dir.path_join(entry_name)
			if candidate != part_path and candidate != metadata_path:
				var modified_at := int(FileAccess.get_modified_time(candidate))
				if modified_at > 0 and now - modified_at > STALE_PARTIAL_MAX_AGE_SECONDS:
					_remove_file(candidate)
		entry_name = directory.get_next()
	directory.list_dir_end()


func _safe_file_component(value: String) -> String:
	var safe := ""
	for character: String in value.to_lower():
		if character.to_ascii_buffer()[0] in range(97, 123) or character.is_valid_int() or character in ["-", "_"]:
			safe += character
		else:
			safe += "-"
	return safe.trim_prefix("-").trim_suffix("-") if not safe.is_empty() else "download"


func _url_without_query(url: String) -> String:
	return url.get_slice("?", 0)


static func parse_http_url(url: String) -> Dictionary:
	var trimmed := url.strip_edges()
	var scheme_separator := trimmed.find("://")
	if scheme_separator <= 0:
		return {"valid": false}
	var scheme := trimmed.substr(0, scheme_separator).to_lower()
	if scheme not in ["http", "https"]:
		return {"valid": false}
	var remainder := trimmed.substr(scheme_separator + 3)
	var path_start := remainder.find("/")
	var query_start := remainder.find("?")
	if path_start < 0 or (query_start >= 0 and query_start < path_start):
		path_start = query_start
	var authority := remainder if path_start < 0 else remainder.substr(0, path_start)
	var target := "/" if path_start < 0 else remainder.substr(path_start)
	if target.begins_with("?"):
		target = "/%s" % target
	if authority.is_empty() or authority.contains("@"):
		return {"valid": false}
	var host := authority
	var port := 443 if scheme == "https" else 80
	var colon := authority.rfind(":")
	if colon > 0 and not authority.ends_with("]"):
		var port_text := authority.substr(colon + 1)
		if not port_text.is_valid_int():
			return {"valid": false}
		host = authority.substr(0, colon)
		port = port_text.to_int()
	if host.is_empty() or port <= 0 or port > 65535:
		return {"valid": false}
	return {
		"valid": true,
		"scheme": scheme,
		"host": host,
		"port": port,
		"target": target,
	}


static func parse_content_range(value: String) -> Dictionary:
	var normalized := value.strip_edges().to_lower()
	if not normalized.begins_with("bytes ") or not normalized.contains("/"):
		return {"valid": false}
	var range_and_total := normalized.trim_prefix("bytes ").split("/", false, 1)
	if range_and_total.size() != 2 or range_and_total[1] == "*":
		return {"valid": false}
	var bounds := range_and_total[0].split("-", false, 1)
	if bounds.size() != 2:
		return {"valid": false}
	if not bounds[0].is_valid_int() or not bounds[1].is_valid_int() or not range_and_total[1].is_valid_int():
		return {"valid": false}
	var start := bounds[0].to_int()
	var finish := bounds[1].to_int()
	var total := range_and_total[1].to_int()
	if start < 0 or finish < start or total <= finish:
		return {"valid": false}
	return {"valid": true, "start": start, "end": finish, "total": total}


static func resolve_redirect_url(current_url: String, location: String) -> String:
	var trimmed := location.strip_edges()
	if trimmed.begins_with("http://") or trimmed.begins_with("https://"):
		return trimmed
	var parsed := parse_http_url(current_url)
	if not bool(parsed.get("valid", false)):
		return ""
	var origin := "%s://%s" % [str(parsed.get("scheme", "")), str(parsed.get("host", ""))]
	var port := int(parsed.get("port", -1))
	if (str(parsed.get("scheme", "")) == "https" and port != 443) or (str(parsed.get("scheme", "")) == "http" and port != 80):
		origin += ":%d" % port
	if trimmed.begins_with("//"):
		return "%s:%s" % [str(parsed.get("scheme", "")), trimmed]
	if trimmed.begins_with("/"):
		return origin + trimmed
	var current_target := str(parsed.get("target", "/")).get_slice("?", 0)
	return origin + current_target.get_base_dir().path_join(trimmed)


static func _normalize_headers(headers: Dictionary) -> Dictionary:
	var normalized := {}
	for key: Variant in headers:
		normalized[str(key).to_lower()] = str(headers[key]).strip_edges()
	return normalized


static func _cloudflare_edge(cf_ray: String) -> String:
	var separator := cf_ray.rfind("-")
	if separator < 0:
		return ""
	var edge := cf_ray.substr(separator + 1).strip_edges().to_upper()
	if edge.length() < 3 or edge.length() > 4:
		return ""
	return edge
