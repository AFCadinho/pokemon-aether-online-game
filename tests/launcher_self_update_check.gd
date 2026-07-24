extends SceneTree


func _init() -> void:
	var source := FileAccess.get_file_as_string("res://launcher/scripts/launcher.gd")
	var scene := FileAccess.get_file_as_string("res://launcher/scenes/launcher.tscn")

	_check_true(
		scene.contains('[node name="LauncherUpdateOverlay" type="Control"'),
		"launcher update uses a custom overlay instead of a Godot confirmation dialog"
	)
	_check_true(
		not scene.contains('[node name="LauncherUpdateConfirmDialog" type="ConfirmationDialog"'),
		"launcher update no longer exposes the default Godot confirmation dialog"
	)
	_check_true(
		scene.contains('text = "Update & restart"') and source.contains("func _show_launcher_update_prompt"),
		"launcher update prompt presents a clear modern update action"
	)

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
	_check_true(
		source.contains('robocopy "%%UPDATE_DIR%%" "%%LAUNCHER_DIR%%" /E /R:30 /W:1'),
		"Windows retries temporarily locked launcher files during replacement"
	)
	_check_true(
		source.contains("if %%COPY_EXIT%% GEQ 8 ("),
		"Windows accepts successful robocopy result codes and rejects real copy failures"
	)
	_check_true(
		source.contains('set "LAUNCHER_PCK_BAK=%s"'),
		"Windows backs up the launcher package as well as its executable"
	)

	print("PASS launcher_self_update_check")
	quit(0)


func _check_true(value: bool, message: String) -> void:
	if value:
		return
	push_error("FAIL %s" % message)
	quit(1)
