extends SceneTree
## Produce local repaired SCNs; never change source files or admit/publish candidates.
const Visibility = preload("res://scripts/battle/animations/reviewed_source_visibility.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var source := OS.get_environment("MODEL_REPAIR_CATALOG")
	var output := OS.get_environment("MODEL_REPAIR_OUTPUT")
	assert(source.is_absolute_path() and output.is_absolute_path())
	assert(not DirAccess.dir_exists_absolute(output), "Use a new output directory")
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string(source))
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var rows := []
	for entry: Dictionary in catalog:
		var identity: String = entry.species + ("@shiny" if entry.get("variant") == "shiny" else "")
		if not Visibility.REPAIRS.data.models.has(identity): continue
		assert(FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
		assert(Visibility.matches(identity, entry.runtime_sha256))
		var packed: PackedScene = ResourceLoader.load(entry.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		var actor := packed.instantiate()
		root.add_child(actor)
		assert(Visibility.apply(actor, identity, entry.runtime_sha256))
		# The repaired scene owns its visibility tracks. It must not pretend to
		# be a live instance of the old source revision after serialization.
		actor.remove_meta(Visibility.META)
		var repaired := PackedScene.new()
		assert(repaired.pack(actor) == OK)
		var path := output.path_join(identity.replace("@", "-") + ".scn")
		assert(ResourceSaver.save(repaired, path, ResourceSaver.FLAG_COMPRESS) == OK)
		var reloaded: PackedScene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		var checked := reloaded.instantiate()
		root.add_child(checked)
		var player: AnimationPlayer = checked.find_child("AnimationPlayer", true, false)
		var profile: Dictionary = Visibility.REPAIRS.data.profiles[Visibility.REPAIRS.data.models[identity].profile]
		for action in player.get_animation_list():
			player.play(action)
			player.seek(0.0, true)
			player.pause()
			var clip: Dictionary = profile.clips.idle if action == "RESET" else profile.clips[action]
			for track: Dictionary in clip.tracks:
				assert(checked.find_child(track.mesh, true, false).visible == track.keys[0][1])
		var row := entry.duplicate(true)
		row["repair_source_sha256"] = entry.runtime_sha256
		row.runtime_path = path
		row.runtime_sha256 = FileAccess.get_sha256(path)
		row["runtime_approved"] = false
		row["published"] = false
		rows.append(row)
		actor.queue_free()
		checked.queue_free()
		RenderingServer.force_draw(false)
		for frame in 3: await process_frame
		print("REPAIRED_SCENE_RELOAD_OK ", identity)
	assert(rows.size() == Visibility.REPAIRS.data.models.size())
	var report := FileAccess.open(output.path_join("catalog.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(rows, "  ") + "\n")
	report.close()
	print("REVIEWED_VISIBILITY_BAKE_OK scenes=", rows.size())
	quit()
