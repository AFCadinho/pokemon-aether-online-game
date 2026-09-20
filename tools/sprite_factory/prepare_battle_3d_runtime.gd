extends SceneTree
## Offline conversion only: preserve meshes/materials/native animation tracks.
## Never perform GLTF import on the interactive battle thread.

func _init() -> void:
	_run.call_deferred()

func _player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _player(child)
		if found != null:
			return found
	return null

func _run() -> void:
	var path := OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Array:
		quit(2)
		return
	var output := path.get_base_dir().path_join("prepared-runtime")
	DirAccess.make_dir_recursive_absolute(output)
	var result := []
	for entry: Dictionary in data:
		if entry.species not in ["dragonite", "roaring-moon"]:
			continue
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_file(entry.path, state) == OK)
		var node := document.generate_scene(state, 60)
		assert(node != null)
		var player := _player(node)
		assert(player != null)
		for action: String in entry.action_timing:
			assert(player.has_animation(action))
			var spec: Dictionary = entry.action_timing[action]
			var animation := player.get_animation(action)
			animation.length = float(spec.frames) / 60.0
			animation.loop_mode = Animation.LOOP_LINEAR if spec.get("loop", false) else Animation.LOOP_NONE
		var packed := PackedScene.new()
		assert(packed.pack(node) == OK)
		var target := output.path_join(entry.species + ".scn")
		assert(ResourceSaver.save(packed, target, ResourceSaver.FLAG_COMPRESS) == OK)
		node.free()
		var prepared := entry.duplicate(true)
		prepared.runtime_path = target
		prepared.source_sha256 = FileAccess.get_sha256(entry.path)
		prepared.runtime_schema = 1
		result.append(prepared)
		print("PREPARED ", entry.species, " bytes=", FileAccess.open(target, FileAccess.READ).get_length())
	var report := FileAccess.open(path + ".runtime.json", FileAccess.WRITE)
	assert(report != null)
	report.store_string(JSON.stringify(result, "\t"))
	report.close()
	print("PREPARED_REPORT ", path + ".runtime.json")
	quit()
