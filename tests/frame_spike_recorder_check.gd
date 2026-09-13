extends SceneTree

const Recorder := preload("res://scripts/services/frame_spike_recorder.gd")
const TEST_PATH := "user://tests/cerulean_frame_spikes_test.jsonl"

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var recorder := Recorder.new()
	recorder.log_path = TEST_PATH
	var context_calls := [0]
	var context_provider := func() -> Dictionary:
		context_calls[0] += 1
		return {"map_id": "kanto_cerulean_city", "player": {"mount_id": "cyclizar"}}
	recorder.start({"renderer": "test"})
	_check(recorder.is_recording(), "recorder starts explicitly")
	_check(not recorder.record_frame(16667, context_provider), "normal frames remain summary-only")
	_check(context_calls[0] == 0, "normal frames do not collect expensive context")
	_check(recorder.record_frame(25000, context_provider), "20 ms frame spikes are captured")
	_check(context_calls[0] == 1, "spike context is collected once")
	_check(recorder.finish(), "completed capture is written")
	_check(not recorder.is_recording(), "finishing stops the capture")
	var contents := FileAccess.get_file_as_string(TEST_PATH)
	var lines := contents.split("\n", false)
	_check(lines.size() == 3, "capture contains session, spike and summary records")
	if lines.size() == 3:
		var header: Variant = JSON.parse_string(lines[0])
		var spike: Variant = JSON.parse_string(lines[1])
		var summary: Variant = JSON.parse_string(lines[2])
		_check(header is Dictionary and str(header.get("renderer", "")) == "test",
			"session context is retained")
		_check(spike is Dictionary and is_equal_approx(float(spike.get("frame_ms", 0.0)), 25.0),
			"spike duration is stored in milliseconds")
		_check(spike is Dictionary and str(spike.get("map_id", "")) == "kanto_cerulean_city",
			"spike location context is retained")
		_check(summary is Dictionary and int(summary.get("frame_count", 0)) == 2,
			"summary counts normal and slow frames")
		_check(summary is Dictionary and int((summary.get("frames_over_usec", {}) as Dictionary).get("20000", 0)) == 1,
			"summary groups slow frames by severity")
	recorder.start({"renderer": "second-test"})
	recorder.record_frame(16000)
	_check(recorder.finish(), "a second Cerulean visit is written")
	var appended_lines := FileAccess.get_file_as_string(TEST_PATH).split("\n", false)
	_check(appended_lines.size() == 5, "multiple Cerulean visits remain in the same session log")
	if appended_lines.size() == 5:
		var second_header: Variant = JSON.parse_string(appended_lines[3])
		_check(second_header is Dictionary and int(second_header.get("session_index", -1)) == 1,
			"appended visits retain their session order")
	var absolute_path := ProjectSettings.globalize_path(TEST_PATH)
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(absolute_path)
	print("frame_spike_recorder_check: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
