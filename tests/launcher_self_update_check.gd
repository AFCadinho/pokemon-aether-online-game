extends SceneTree


func _init() -> void:
	var source := FileAccess.get_file_as_string("res://launcher/scripts/launcher.gd")

	_check_true(
		source.contains('exec_args = PackedStringArray(["/D", "/C", script_path])'),
		"Windows starts one direct cmd updater without a nested start/call chain"
	)
	_check_true(
		not source.contains('PackedStringArray(["/C", "start", "\\\"\\\"", "/MIN", "cmd.exe"'),
		"Windows no longer relies on the fragile detached cmd quoting chain"
	)
	_check_true(
		source.contains('set "LAUNCHER_PID=%s"'),
		"Windows updater records the exact running launcher process"
	)
	_check_true(
		source.contains('tasklist /FI "PID eq %%LAUNCHER_PID%%" /NH'),
		"Windows updater waits for the exact launcher process before replacing files"
	)
	_check_true(
		source.contains("await get_tree().create_timer(0.35).timeout"),
		"launcher keeps running long enough to validate updater startup"
	)
	_check_true(
		source.contains("if not OS.is_process_running(updater_process_id):"),
		"launcher refuses to close when the updater exits prematurely"
	)
	_check_true(
		source.contains('if OS.get_name() == "Windows":') and source.contains("OS.kill(OS.get_process_id())"),
		"Windows releases launcher file locks with an explicit self-termination after updater verification"
	)
	_check_true(
		source.contains("if %%WAIT_ATTEMPTS%% GEQ 60 ("),
		"Windows updater cannot wait indefinitely for a launcher process"
	)

	print("PASS launcher_self_update_check")
	quit(0)


func _check_true(value: bool, message: String) -> void:
	if value:
		return
	push_error("FAIL %s" % message)
	quit(1)
