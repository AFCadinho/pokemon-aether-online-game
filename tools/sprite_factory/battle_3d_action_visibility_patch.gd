extends SceneTree
## Offline, hash-pinned mesh visibility patch for a reviewed battle action.
## Writes a new scene; never edits the source or the selected model catalog.

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var job_path := OS.get_environment("POKEAETHER_3D_VISIBILITY_PATCH_JOB")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(job_path))
	if not raw is Dictionary or raw.get("schema") != 1:
		_fail("Invalid visibility patch job")
		return
	var source := str(raw.get("source", ""))
	var output := str(raw.get("output", ""))
	var report_path := str(raw.get("report", ""))
	var expected_hash := str(raw.get("source_sha256", ""))
	var mesh_path := str(raw.get("mesh_path", ""))
	var hidden: Variant = raw.get("hidden_actions")
	if not source.is_absolute_path() or not output.is_absolute_path() or not report_path.is_absolute_path() or source == output or source == report_path or output == report_path or expected_hash.length() != 64 or FileAccess.get_sha256(source) != expected_hash or FileAccess.file_exists(output) or FileAccess.file_exists(report_path) or not hidden is Array or hidden.is_empty() or mesh_path.is_empty():
		_fail("Unreviewed input or occupied output")
		return
	var packed := ResourceLoader.load(source, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if packed == null:
		_fail("Cannot load source scene")
		return
	var actor := packed.instantiate() as Node3D
	if actor == null or not actor.has_node(mesh_path):
		_fail("Missing actor or target mesh")
		return
	root.add_child(actor)
	var mesh := actor.get_node(mesh_path) as MeshInstance3D
	var players := actor.find_children("*", "AnimationPlayer", true, false)
	if mesh == null or mesh.mesh == null or players.size() != 1:
		_fail("Expected one mesh and one animation player")
		return
	var player := players[0] as AnimationPlayer
	var actions := Array(player.get_animation_list())
	for action in hidden:
		if not action is String or not action in actions:
			_fail("Unknown hidden action")
			return
	var visibility_path := NodePath(mesh_path + ":visible")
	for action in actions:
		var animation := player.get_animation(action)
		for track in animation.get_track_count():
			if animation.track_get_path(track) == visibility_path:
				_fail("Visibility already animated: " + str(action))
				return
		var index := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(index, visibility_path)
		animation.value_track_set_update_mode(index, Animation.UPDATE_DISCRETE)
		animation.track_insert_key(index, 0.0, not action in hidden)
	var result := PackedScene.new()
	if result.pack(actor) != OK or ResourceSaver.save(result, output) != OK:
		_fail("Cannot save patched scene")
		return
	var saved := ResourceLoader.load(output, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if saved == null:
		_fail("Cannot reload patched scene")
		return
	var report := {"schema": 1, "source": source, "source_sha256": expected_hash,
		"output": output, "output_sha256": FileAccess.get_sha256(output),
		"mesh_path": mesh_path, "hidden_actions": hidden, "actions": actions}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		_fail("Cannot write patch report")
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("VISIBILITY_PATCH_OK ", report_path)
	quit()


func _fail(reason: String) -> void:
	printerr("VISIBILITY_PATCH_FAILED: ", reason)
	quit(2)
