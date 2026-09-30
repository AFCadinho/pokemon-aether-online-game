extends SceneTree
## Offline correction for sampled parent/child scale compensation.
## Explicit hash-bound tracks only; preserves every authored key and timestamp.
func _init() -> void:
	var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("POKEAETHER_TRACK_INTERPOLATION_JOB")))
	assert(job.schema == 1 and job.source != job.output)
	assert(FileAccess.get_sha256(job.source) == job.source_sha256)
	assert(not FileAccess.file_exists(job.output) and not FileAccess.file_exists(job.report))
	assert(job.tracks is Array and not job.tracks.is_empty())
	var actor = load(job.source).instantiate()
	var players = actor.find_children("*", "AnimationPlayer", true, false)
	assert(players.size() == 1)
	var changes := []
	var found := {}
	for action in players[0].get_animation_list():
		var animation: Animation = players[0].get_animation(action)
		for track in animation.get_track_count():
			var path := str(animation.track_get_path(track))
			if path not in job.tracks:
				continue
			assert(animation.track_get_type(track) in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D])
			found[path] = true
			var old := animation.track_get_interpolation_type(track)
			animation.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
			changes.append({"action": action, "path": path, "type": animation.track_get_type(track), "prior_interpolation": old, "keys": animation.track_get_key_count(track)})
	assert(found.size() == job.tracks.size())
	var packed := PackedScene.new()
	assert(packed.pack(actor) == OK and ResourceSaver.save(packed, job.output) == OK)
	FileAccess.open(job.report, FileAccess.WRITE).store_string(JSON.stringify({"schema": 1, "source_sha256": job.source_sha256, "runtime_sha256": FileAccess.get_sha256(job.output), "changes": changes, "reason": job.reason}, "  "))
	actor.free()
	print("INTERPOLATION_PATCH_OK ", job.output)
	quit()
