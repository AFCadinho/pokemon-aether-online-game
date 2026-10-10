extends SceneTree
## Recovery must retain live installs, unknown files, links and mounted packs.
const Pair = preload("res://scripts/services/model_pair_pack.gd")
const Pilot = preload("res://scripts/services/model_pair_pilot.gd")
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func check(value: bool, reason: String) -> void:
	if not value:
		failures.append(reason)
		print("RECOVERY_OWNERSHIP_FAIL ", reason)

func write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func partial(directory: String, asset: Dictionary) -> void:
	write(directory.path_join("bundle.json"), JSON.stringify(asset))
	write(directory.path_join("model-pair.pck"), "partial test object")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or OS.get_name() != "Linux":
		quit(2)
		return
	var asset: Dictionary = Pilot.DATA.data.assets[0]
	var source: String = args[0].path_join(str(asset.object_key).get_file())
	var task_root := ProjectSettings.globalize_path("user://shared-model-recovery-ownership-" + str(Time.get_ticks_usec()))
	var destination := task_root.path_join(str(asset.sha256))
	var dead_pid := OS.create_process("/usr/bin/true", [])
	while OS.is_process_running(dead_pid):
		await process_frame
	var suffix := str(dead_pid) + "-" + str(Time.get_ticks_usec())
	var abandoned := destination + ".install-" + suffix
	partial(abandoned, asset)
	var live := destination + ".install-" + str(OS.get_process_id()) + "-" + str(Time.get_ticks_usec())
	partial(live, asset)
	var output: Array = []
	check(OS.execute("/bin/ps", ["-p", str(OS.get_process_id()), "-o", "ppid="], output) == 0, "Find unrelated live parent process")
	var parent_pid := str(output[0]).strip_edges().to_int()
	var external := destination + ".install-" + str(parent_pid) + "-" + str(Time.get_ticks_usec())
	partial(external, asset)
	var unknown := destination + ".install-" + str(dead_pid) + "-" + str(Time.get_ticks_usec())
	partial(unknown, asset)
	write(unknown.path_join("personal.txt"), "unknown files must survive")
	var linked_target := task_root.path_join("link-target")
	partial(linked_target, asset)
	var linked := destination + ".install-" + str(dead_pid) + "-" + str(Time.get_ticks_usec())
	check(OS.execute("/usr/bin/ln", ["-s", linked_target, linked]) == 0, "Create test-only linked artifact")
	var bad_source := task_root.path_join("bad.pck")
	write(bad_source, "invalid")
	check(not str(Pair.install(bad_source, asset, destination).error).is_empty(), "Invalid input never authorizes recovery")
	check(DirAccess.dir_exists_absolute(abandoned), "Failed source verification preserves staged files")
	check(str(Pair.install(source, asset, destination).error).is_empty(), "Verified retry succeeds")
	check(not DirAccess.dir_exists_absolute(abandoned), "Owned dead-process partial copy is removed")
	check(FileAccess.get_file_as_string(live.path_join("model-pair.pck")) == "partial test object", "Live installation survives")
	check(FileAccess.get_file_as_string(external.path_join("model-pair.pck")) == "partial test object", "Unrelated live installer survives")
	check(FileAccess.get_file_as_string(unknown.path_join("personal.txt")) == "unknown files must survive", "Unknown files survive")
	check(DirAccess.open(task_root).is_link(linked) and FileAccess.get_file_as_string(linked_target.path_join("model-pair.pck")) == "partial test object", "Linked artifact and target survive")
	var staged := destination + ".install-" + suffix
	check(DirAccess.rename_absolute(destination, staged) == OK, "Simulate death after complete staging")
	check(str(Pair.install(source, asset, destination).error).is_empty(), "Verified completed stage is recovered")
	check(not DirAccess.dir_exists_absolute(staged) and str(Pair.object_check(destination, asset).error).is_empty(), "Recovered object is complete")
	var previous := destination + ".replaced-" + suffix
	check(DirAccess.rename_absolute(destination, previous) == OK, "Simulate death after quarantine")
	check(not str(Pair.install(source, asset, destination, false).error).is_empty(), "Game lease defers interrupted replacement")
	check(DirAccess.dir_exists_absolute(previous), "Deferred replacement preserves quarantine")
	check(str(Pair.install(source, asset, destination).error).is_empty(), "Recovery after lease ends")
	check(not DirAccess.dir_exists_absolute(previous), "Quarantine removed after verified publication")
	var occupied := task_root.path_join("unknown-object")
	partial(occupied, asset)
	write(occupied.path_join("personal.txt"), "owned by someone else")
	check(not str(Pair.install(source, asset, occupied).error).is_empty(), "Unknown destination cannot be replaced")
	check(FileAccess.get_file_as_string(occupied.path_join("personal.txt")) == "owned by someone else", "Unknown destination contents preserved")
	var pack := destination.path_join("model-pair.pck")
	check(Pair.mount_checked(pack, asset, Pair.inspect(pack, asset)).is_empty(), "Mount known physical object")
	write(pack, "corrupted after mounting")
	check(not str(Pair.install(source, asset, destination).error).is_empty(), "Mounted pack repair deferred")
	check(FileAccess.get_file_as_string(pack) == "corrupted after mounting", "Mounted physical file is not replaced")
	check(FileAccess.get_file_as_bytes("res://scripts/services/model_pair_pack.gd") == FileAccess.get_file_as_bytes("res://launcher/scripts/model_pair_pack.gd"), "Independent validators stay identical")
	print("SHARED_MODEL_RECOVERY_OWNERSHIP_CHECK ", "OK" if failures.is_empty() else "FAILED", " ", failures)
	quit(0 if failures.is_empty() else 1)
