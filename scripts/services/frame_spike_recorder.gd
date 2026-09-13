extends RefCounted

const DEFAULT_LOG_PATH := "user://diagnostics/cerulean_frame_spikes.jsonl"
const SPIKE_THRESHOLD_USEC := 20000
const MAX_SPIKE_SAMPLES := 1000
const FRAME_BUCKETS_USEC: Array[int] = [20000, 25000, 33333, 50000, 100000]

var log_path := DEFAULT_LOG_PATH
var recording := false
var started_at_unix := 0
var frame_count := 0
var total_frame_usec := 0
var worst_frame_usec := 0
var spike_samples: Array[Dictionary] = []
var dropped_samples := 0
var frame_buckets: Dictionary = {}
var session_context: Dictionary = {}
var completed_sessions := 0


func start(context: Dictionary = {}) -> void:
	if recording:
		return
	recording = true
	started_at_unix = int(Time.get_unix_time_from_system())
	frame_count = 0
	total_frame_usec = 0
	worst_frame_usec = 0
	spike_samples.clear()
	dropped_samples = 0
	frame_buckets.clear()
	for threshold_usec: int in FRAME_BUCKETS_USEC:
		frame_buckets[str(threshold_usec)] = 0
	session_context = context.duplicate(true)


func record_frame(duration_usec: int, context_provider := Callable()) -> bool:
	if not recording or duration_usec <= 0:
		return false
	frame_count += 1
	total_frame_usec += duration_usec
	worst_frame_usec = maxi(worst_frame_usec, duration_usec)
	for threshold_usec: int in FRAME_BUCKETS_USEC:
		if duration_usec >= threshold_usec:
			var key := str(threshold_usec)
			frame_buckets[key] = int(frame_buckets.get(key, 0)) + 1
	if duration_usec < SPIKE_THRESHOLD_USEC:
		return false
	if spike_samples.size() >= MAX_SPIKE_SAMPLES:
		dropped_samples += 1
		return true
	var sample := {
		"type": "spike",
		"elapsed_ms": Time.get_ticks_msec(),
		"frame_ms": snappedf(float(duration_usec) / 1000.0, 0.001),
	}
	if context_provider.is_valid():
		var context_value: Variant = context_provider.call()
		if context_value is Dictionary:
			sample.merge(context_value as Dictionary, true)
	spike_samples.append(sample)
	return true


func finish() -> bool:
	if not recording:
		return false
	recording = false
	var absolute_directory := ProjectSettings.globalize_path(log_path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		return false
	var file := FileAccess.open(
		log_path,
		FileAccess.READ_WRITE if completed_sessions > 0 else FileAccess.WRITE
	)
	if file == null:
		return false
	if completed_sessions > 0:
		file.seek_end()
	var header := session_context.duplicate(true)
	header["type"] = "session"
	header["schema"] = 1
	header["session_index"] = completed_sessions
	header["started_at_unix"] = started_at_unix
	file.store_line(JSON.stringify(header))
	for sample: Dictionary in spike_samples:
		file.store_line(JSON.stringify(sample))
	file.store_line(JSON.stringify({
		"type": "summary",
		"frame_count": frame_count,
		"average_frame_ms": 0.0 if frame_count == 0 else snappedf(
			float(total_frame_usec) / float(frame_count) / 1000.0,
			0.001
		),
		"worst_frame_ms": snappedf(float(worst_frame_usec) / 1000.0, 0.001),
		"frames_over_usec": frame_buckets,
		"spike_samples": spike_samples.size(),
		"dropped_samples": dropped_samples,
		"finished_at_unix": int(Time.get_unix_time_from_system()),
	}))
	file.close()
	completed_sessions += 1
	return true


func is_recording() -> bool:
	return recording


func get_absolute_log_path() -> String:
	return ProjectSettings.globalize_path(log_path)
