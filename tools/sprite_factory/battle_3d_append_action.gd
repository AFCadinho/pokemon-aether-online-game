extends SceneTree
## Offline, hash-pinned action transplant between scenes with the same rig.
## Writes a new candidate scene; never changes a source or selected catalog.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var job_path := OS.get_environment("POKEAETHER_3D_APPEND_ACTION_JOB")
	var job: Variant = JSON.parse_string(FileAccess.get_file_as_string(job_path))
	if not job is Dictionary or job.get("schema") != 1:
		_fail("Invalid append-action job")
		return
	var source := str(job.get("source", ""))
	var target := str(job.get("target", ""))
	var output := str(job.get("output", ""))
	var report_path := str(job.get("report", ""))
	var action := str(job.get("action", ""))
	if not source.is_absolute_path() or not target.is_absolute_path() or not output.is_absolute_path() or not report_path.is_absolute_path() or action.is_empty() or FileAccess.file_exists(output) or FileAccess.file_exists(report_path) or source == target or source == output or target == output or FileAccess.get_sha256(source) != str(job.get("source_sha256", "")) or FileAccess.get_sha256(target) != str(job.get("target_sha256", "")):
		_fail("Unpinned input or occupied output")
		return
	var source_scene := ResourceLoader.load(source, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var target_scene := ResourceLoader.load(target, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if source_scene == null or target_scene == null:
		_fail("Could not load scenes")
		return
	var source_actor := source_scene.instantiate() as Node3D
	var target_actor := target_scene.instantiate() as Node3D
	if source_actor == null or target_actor == null:
		_fail("Expected Node3D actors")
		return
	root.add_child(source_actor)
	root.add_child(target_actor)
	var source_players := source_actor.find_children("*", "AnimationPlayer", true, false)
	var target_players := target_actor.find_children("*", "AnimationPlayer", true, false)
	var source_skeletons := source_actor.find_children("*", "Skeleton3D", true, false)
	var target_skeletons := target_actor.find_children("*", "Skeleton3D", true, false)
	if source_players.size() != 1 or target_players.size() != 1 or source_skeletons.size() != 1 or target_skeletons.size() != 1:
		_fail("Expected one animation player and skeleton per scene")
		return
	var source_player := source_players[0] as AnimationPlayer
	var target_player := target_players[0] as AnimationPlayer
	var source_skeleton := source_skeletons[0] as Skeleton3D
	var target_skeleton := target_skeletons[0] as Skeleton3D
	var source_bones: Array[String] = []
	var target_bones: Array[String] = []
	for index in source_skeleton.get_bone_count():
		source_bones.append(str(source_skeleton.get_bone_name(index)))
	for index in target_skeleton.get_bone_count():
		target_bones.append(str(target_skeleton.get_bone_name(index)))
	if source_bones != target_bones or source_player.root_node != target_player.root_node or not source_player.has_animation(action) or target_player.has_animation(action):
		_fail("Action missing, already present, or rig mismatch")
		return
	var source_animation := source_player.get_animation(action)
	var copy := source_animation.duplicate(true) as Animation
	var source_library := source_player.get_animation_library("")
	var target_library := target_player.get_animation_library("")
	if source_library == null or target_library == null or target_library.add_animation(action, copy) != OK:
		_fail("Could not append action")
		return
	var packed := PackedScene.new()
	if packed.pack(target_actor) != OK or ResourceSaver.save(packed, output) != OK:
		_fail("Could not save candidate")
		return
	var reloaded := ResourceLoader.load(output, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if reloaded == null:
		_fail("Could not reload candidate")
		return
	var check_actor := reloaded.instantiate()
	var check_players := check_actor.find_children("*", "AnimationPlayer", true, false)
	if check_players.size() != 1 or not (check_players[0] as AnimationPlayer).has_animation(action):
		_fail("Saved candidate lost action")
		return
	var report := {"schema": 1, "source": source, "source_sha256": job.source_sha256,
		"target": target, "target_sha256": job.target_sha256, "output": output,
		"output_sha256": FileAccess.get_sha256(output), "action": action,
		"frames": source_animation.length * 60.0, "tracks": source_animation.get_track_count(),
		"bones": source_bones.size()}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write report")
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	check_actor.free()
	source_actor.queue_free()
	target_actor.queue_free()
	await process_frame
	print("APPEND_ACTION_OK ", report_path)
	quit()

func _fail(reason: String) -> void:
	printerr("APPEND_ACTION_FAILED: ", reason)
	quit(2)
