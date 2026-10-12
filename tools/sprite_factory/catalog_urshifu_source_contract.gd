extends SceneTree
const Audit = preload("model_texture_audit.gd")

func _initialize() -> void:
	var directory := OS.get_environment("POKEAETHER_FORM_BUNDLE_WORK")
	assert(directory.is_absolute_path() and DisplayServer.get_name() == "headless")
	var source: Array = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("runtime/report.json")))
	var candidate: Array = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("runtime-v2/report.json")))
	assert(source.size() == 2 and candidate.size() == 2)
	var records := []
	for i in source.size():
		assert(source[i].species == candidate[i].species)
		assert(FileAccess.get_sha256(source[i].runtime_path) == source[i].runtime_sha256)
		assert(FileAccess.get_sha256(candidate[i].runtime_path) == candidate[i].runtime_sha256)
		var original := load(source[i].runtime_path) as PackedScene
		var expected := original.instantiate()
		var player: AnimationPlayer = expected.find_children("*", "AnimationPlayer", true, false)[0]
		for action in player.get_animation_list():
			var animation: Animation = player.get_animation(action)
			for track in animation.get_track_count():
				if str(animation.track_get_path(track)).ends_with(":visible"):
					assert(animation.value_track_get_update_mode(track) == Animation.UPDATE_DISCRETE)
					animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
		var planned := PackedScene.new()
		assert(planned.pack(expected) == OK)
		var actual := load(candidate[i].runtime_path) as PackedScene
		assert(Audit.signature(actual) == Audit.signature(planned), "Unexpected source model change")
		records.append({"species": source[i].species, "source_sha256": source[i].runtime_sha256,
			"candidate_sha256": candidate[i].runtime_sha256, "only_visibility_sampling_changed": true})
		expected.free()
	var file := FileAccess.open(directory.path_join("source-contract.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"complete": true, "entries": records}, "  "))
	print("URSHIFU_SOURCE_CONTRACT_OK models=2 geometry_materials_animation_keys_unchanged=true")
	quit()
