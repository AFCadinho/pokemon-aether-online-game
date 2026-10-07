extends RefCounted
## Keep model files in use by a running game until that process exits.

static func register_process(root: String, pid: int) -> Error:
	if pid <= 0:
		return ERR_INVALID_PARAMETER
	var directory := root.path_join("game-leases")
	var parent := DirAccess.open(root)
	if parent != null and parent.is_link("game-leases"):
		return ERR_INVALID_DATA
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return error
	var file := FileAccess.open(directory.path_join(str(pid) + ".json"), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"pid": pid}) + "\n")
	error = file.get_error()
	file.close()
	return error


static func has_running_game(root: String, protect_legacy_clients := true) -> bool:
	var parent := DirAccess.open(root)
	if parent == null:
		return false
	# Older exported clients have no lease marker yet. Protect those during upgrade.
	if protect_legacy_clients and _has_exported_game():
		return true
	if parent.is_link("game-leases"):
		return true
	var path := root.path_join("game-leases")
	var directory := DirAccess.open(path)
	if directory == null:
		return DirAccess.dir_exists_absolute(path)
	for name in directory.get_files():
		if directory.is_link(name) or name.get_extension() != "json" or not name.get_basename().is_valid_int():
			return true
		var pid := name.get_basename().to_int()
		if pid <= 0 or _process_running(pid):
			return true
		# This marker belongs to a game that has exited, not retained models.
		if DirAccess.remove_absolute(path.path_join(name)) != OK:
			return true
	return not directory.get_directories().is_empty()


static func _process_running(pid: int) -> bool:
	if pid == OS.get_process_id():
		return true
	# Godot's is_process_running only checks children spawned by this instance.
	# A restarted launcher must also recognize games started by its predecessor.
	if OS.get_name() == "Linux" and DirAccess.dir_exists_absolute("/proc"):
		return DirAccess.dir_exists_absolute("/proc/" + str(pid))
	var output: Array = []
	if OS.get_name() == "Windows":
		var command := OS.get_environment("SystemRoot").path_join("System32/tasklist.exe")
		var status := OS.execute(command, PackedStringArray(["/FI", "PID eq " + str(pid), "/FO", "CSV", "/NH"]), output, true)
		return true if status != 0 else _pid_in_tasklist(output, pid)
	if OS.get_name() in ["macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
		var status := OS.execute("/bin/ps", PackedStringArray(["-p", str(pid), "-o", "pid="]), output, true)
		# ps returns 1 for a missing PID; other failures defer cleanup.
		return status != 1
	return true


static func _pid_in_tasklist(output: Array, pid: int) -> bool:
	for row: Variant in output:
		if str(row).contains('\",\"%d\",' % pid):
			return true
	return false


static func _has_exported_game() -> bool:
	var output: Array = []
	if OS.get_name() == "Windows":
		var command := OS.get_environment("SystemRoot").path_join("System32/tasklist.exe")
		if OS.execute(command, PackedStringArray(["/FI", "IMAGENAME eq PokeAether.exe", "/FO", "CSV", "/NH"]), output, true) != 0:
			return true
		for row: Variant in output:
			if str(row).to_lower().contains('"pokeaether.exe",'):
				return true
		return false
	if OS.get_name() in ["macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
		if OS.execute("/bin/ps", PackedStringArray(["-A", "-o", "comm="]), output, true) != 0:
			return true
		for row: Variant in output:
			for name in str(row).split("\n"):
				if _is_game_name(name.strip_edges().get_file()):
					return true
		return false
	return true


static func _is_game_name(name: String) -> bool:
	var lower := name.to_lower()
	return lower in ["pokeaether", "pokeaether.exe"] or lower.begins_with("pokeaether.x86_") or lower.begins_with("pokeaether.arm64")
