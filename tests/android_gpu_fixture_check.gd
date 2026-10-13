extends SceneTree
const Probe = preload("res://tests/android_gpu_isolation_check.gd")
func _init() -> void:
	var fixture: Dictionary = JSON.parse_string('{"schema":1,"run_id":"0123456789abcdef0123456789abcdef","phase_seconds":15,"rounds":2}')
	assert(Probe.valid_fixture(fixture), "Host integer JSON parses as Godot float numbers")
	for key in ["phase_seconds", "rounds"]:
		for bad in [null, true, "15", 15.5, 100]:
			var invalid := fixture.duplicate()
			invalid[key] = bad
			assert(not Probe.valid_fixture(invalid), "Reject malformed or unbounded workload")
	fixture.run_id = "../../other"
	assert(not Probe.valid_fixture(fixture), "Bound run identity")
	print("ANDROID_GPU_FIXTURE_PASS")
	quit()
