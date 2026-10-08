extends SceneTree
func _init() -> void: _run.call_deferred()
func _run() -> void:
	# Synthetic identity must never trigger polling on the application's services.
	await process_frame
	for child in root.get_children(): child.process_mode = Node.PROCESS_MODE_DISABLED
	var auth = load("res://tests/fixtures/remember_me_disk_auth.gd").new()
	root.add_child(auth)
	var mode := OS.get_cmdline_user_args()[0]
	var path: String = auth._session_file_path()
	if mode in ["seed", "unchecked"]:
		var result: Dictionary = await auth.login("disk-fixture", "synthetic-password", mode == "seed")
		if not result.success: quit(1); return
	elif mode == "partial-update":
		var result: Dictionary = await auth.restore_saved_session()
		if not result.success: quit(1); return
		# Reproduce being killed with an incomplete replacement on disk.
		var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
		file.store_string('{"token":')
		file.flush()
		file.close()
	elif mode == "failed-write":
		var before := FileAccess.get_file_as_string(path)
		# Deny the replacement write without altering the existing session.
		DirAccess.make_dir_absolute(path + ".tmp")
		auth._write_session_file({"token": "synthetic-replacement"})
		if FileAccess.get_file_as_string(path) != before: quit(1); return
		DirAccess.remove_absolute(path + ".tmp")
		auth.free()
		quit(0)
		return
	elif mode == "restore":
		var result: Dictionary = await auth.restore_saved_session()
		if not result.success or not auth.remember_me_enabled: quit(1); return
		print("REMEMBER_DISK_RESTORED")
		auth.free()
		quit(0)
		return
	elif mode == "missing":
		var result: Dictionary = await auth.restore_saved_session()
		if result.success or FileAccess.file_exists(path) or FileAccess.file_exists(path + ".tmp"): quit(1); return
		auth.free()
		quit(0)
		return
	else:
		quit(1)
		return
	print("REMEMBER_DISK_READY")
	# Parent test sends SIGKILL: no normal shutdown/exit handlers can run.
