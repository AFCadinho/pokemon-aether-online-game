extends Node
## Optional, immutable Android art. No downloads for players choosing 2D.
const DESCRIPTOR = preload("res://data/android_3d_experiment.json")
const ROOT := "user://android-3d-environment-v1"
var busy := false
var verified := false
var last_error := ""
var pending_task := -1

func _exit_tree() -> void:
	if pending_task >= 0:
		WorkerThreadPool.wait_for_task_completion(pending_task)
		pending_task = -1

class InstallWork extends RefCounted:
	var result := ""
	func run(pin: Dictionary, archive: String, directory: String) -> void:
		DirAccess.make_dir_recursive_absolute(directory)
		var pack := directory.path_join("forest.pck")
		if matches(pack, int(pin.pack_bytes), str(pin.pack_sha256)):
			return
		if not matches(archive, int(pin.archive_bytes), str(pin.archive_sha256)):
			result = "The 3D battlefield download could not be verified."
			return
		var zip := ZIPReader.new()
		if zip.open(archive) != OK:
			result = "The 3D battlefield download could not be opened."
			return
		var files := zip.get_files()
		if files.size() != 2 or "forest-runtime/forest.pck" not in files or "forest-runtime/forest.json" not in files:
			zip.close()
			result = "Unexpected files in the 3D battlefield download."
			return
		var data := zip.read_file("forest-runtime/forest.pck")
		zip.close()
		var file := FileAccess.open(pack + ".partial", FileAccess.WRITE)
		if file == null:
			result = "Not enough storage for the 3D battlefield."
			return
		file.store_buffer(data)
		file.close()
		data = PackedByteArray()
		if not matches(pack + ".partial", int(pin.pack_bytes), str(pin.pack_sha256)):
			result = "The installed 3D battlefield could not be verified."
			return
		if DirAccess.rename_absolute(pack + ".partial", pack) != OK:
			result = "Could not save the 3D battlefield."
	static func matches(path: String, size: int, sha: String) -> bool:
		var file := FileAccess.open(path, FileAccess.READ)
		return file != null and file.get_length() == size and FileAccess.get_sha256(path) == sha

func _enabled() -> bool:
	var settings := get_node_or_null("/root/SettingsManager")
	return settings != null and settings.is_android_3d_experimental() and settings.battle_presentation_mode == "3d"

func manifest_path() -> String:
	return _directory().path_join("forest.json") if verified else ""

func _directory() -> String:
	return ROOT.path_join(str(DESCRIPTOR.data.arena.pack_sha256))

func ensure_ready() -> String:
	if not _enabled():
		return ""
	while busy:
		await get_tree().process_frame
	if verified:
		return ""
	busy = true
	last_error = ""
	var pin: Dictionary = DESCRIPTOR.data.arena
	var directory := _directory()
	var archive := directory.path_join("download.zip")
	var work := InstallWork.new()
	var task := WorkerThreadPool.add_task(work.run.bind(pin, archive, directory))
	pending_task = task
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	pending_task = -1
	if not work.result.is_empty():
		var request := HTTPRequest.new()
		request.use_threads = true
		request.timeout = 120
		request.body_size_limit = int(pin.archive_bytes)
		request.download_file = archive + ".partial"
		add_child(request)
		if request.request("https://updates.pokeaether.com/" + str(pin.object_key)) == OK:
			var response: Array = await request.request_completed
			if response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 200 and DirAccess.rename_absolute(archive + ".partial", archive) == OK:
				work = InstallWork.new()
				task = WorkerThreadPool.add_task(work.run.bind(pin, archive, directory))
				pending_task = task
				while not WorkerThreadPool.is_task_completed(task):
					await get_tree().process_frame
				WorkerThreadPool.wait_for_task_completion(task)
				pending_task = -1
				last_error = work.result
			else:
				last_error = "Could not download the experimental 3D battlefield. Choose 2D or retry in Settings."
		else:
			last_error = "Could not start the 3D battlefield download."
		request.queue_free()
	if last_error.is_empty():
		var file := FileAccess.open(directory.path_join("forest.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"schema": 1, "pack": "forest.pck"}))
			file.close()
			verified = true
			# Archive is no longer needed; the verified PCK stays on this device.
			if FileAccess.file_exists(archive):
				DirAccess.remove_absolute(archive)
		else:
			last_error = "Could not save the 3D battlefield manifest."
	busy = false
	return last_error
