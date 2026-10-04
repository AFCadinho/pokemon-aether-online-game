extends SceneTree

const Versions := "user://versions.json"
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/launcher.tscn") as PackedScene
	# All fixtures and version metadata belong to this test's isolated slot.
	var had_versions := FileAccess.file_exists(Versions)
	var previous := FileAccess.get_file_as_bytes(Versions) if had_versions else PackedByteArray()
	var fixture := "user://update-checkpoint-test-" + str(Time.get_ticks_usec())
	var launcher := scene.instantiate()
	launcher.set("install_dir", fixture)
	var executable := str(launcher.call("_get_default_game_executable_name"))
	var manifest := {
		"game": {"version": "1.0.0", "buildId": "checkpoint-build", "executable": executable,
			"url": "https://updates.example/game.zip"},
		"assetPacks": [{"id": "music", "version": "music-new", "url": "https://updates.example/music.zip"}],
	}
	launcher.set("manifest", manifest)
	launcher.set("local_versions", {"gameVersion": "old", "assetPacks": {}})
	var staged := fixture.path_join(".staging/game")
	_write(staged.path_join(executable), "game fixture")
	var installed := int(launcher.call("_commit_staged_download", {"type": "game", "id": "game"}, staged))
	_check(installed == OK, "game transaction succeeds")
	launcher.call("_mark_download_installed", {"type": "game", "id": "game", "version": "1.0.0", "build_id": "checkpoint-build"})
	# A later game transaction fails before it can be marked installed.
	var incomplete := fixture.path_join(".staging/incomplete")
	_write(incomplete.path_join("wrong.txt"), "incomplete")
	_check(int(launcher.call("_commit_staged_download", {"type": "game", "id": "game"}, incomplete)) != OK,
		"incomplete later transaction fails")
	launcher.free()
	var restarted := scene.instantiate()
	restarted.set("install_dir", fixture)
	restarted.set("manifest", manifest)
	restarted.call("_load_local_versions")
	var versions: Dictionary = restarted.get("local_versions")
	_check(versions.get("gameBuildId") == "checkpoint-build", "completed game survives interruption and restart")
	restarted.call("_build_download_queue")
	var jobs: Array = restarted.get("pending_downloads")
	_check(not jobs.any(func(job: Dictionary) -> bool: return job.type == "game"), "restart skips the already installed game")
	_check(jobs.any(func(job: Dictionary) -> bool: return job.id == "music"), "restart still queues the unfinished music pack")
	var required: Array = restarted.ASSET_PACK_REQUIRED_FILES.music
	for path: String in required:
		_write(fixture.path_join(path), "music fixture")
	restarted.call("_mark_download_installed", {"type": "asset_pack", "id": "music", "version": "music-new"})
	restarted.free()
	var next_restart := scene.instantiate()
	next_restart.set("install_dir", fixture)
	next_restart.set("manifest", manifest)
	next_restart.call("_load_local_versions")
	next_restart.call("_build_download_queue")
	_check(next_restart.get("pending_downloads").is_empty(), "completed game and music are both skipped after restart")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture.path_join(required[0])))
	next_restart.call("_build_download_queue")
	jobs = next_restart.get("pending_downloads")
	_check(jobs.size() == 1 and jobs[0].id == "music", "missing music file is still repaired despite saved metadata")
	next_restart.call("_remove_directory_tree", fixture)
	next_restart.free()
	if had_versions:
		var output := FileAccess.open(Versions, FileAccess.WRITE)
		output.store_buffer(previous)
		output.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Versions))
	if not failed:
		print("PASS launcher update_checkpoint_check")
	quit(1 if failed else 0)


func _write(path: String, contents: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()


func _check(condition: bool, description: String) -> void:
	if not condition:
		failed = true
		push_error("FAIL " + description)
