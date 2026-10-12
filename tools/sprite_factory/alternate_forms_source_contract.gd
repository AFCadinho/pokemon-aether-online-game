extends SceneTree
const Audit = preload("model_texture_audit.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2 and DisplayServer.get_name() == "headless")
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var records := []
	for entry: Dictionary in entries:
		assert(FileAccess.get_sha256(entry.original_native_path) == entry.original_native_sha256)
		assert(FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
		var original := ResourceLoader.load(entry.original_native_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		var expected := original.instantiate()
		var player: AnimationPlayer = expected.find_children("*", "AnimationPlayer", true, false)[0]
		var changed := 0
		for action: String in player.get_animation_list():
			var animation := player.get_animation(action)
			for track in animation.get_track_count():
				if str(animation.track_get_path(track)).ends_with(":visible"):
					assert(animation.track_get_type(track) == Animation.TYPE_VALUE)
					assert(animation.track_get_interpolation_type(track) == Animation.INTERPOLATION_NEAREST)
					assert(animation.value_track_get_update_mode(track) == Animation.UPDATE_DISCRETE)
					animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
					changed += 1
		var planned := PackedScene.new()
		assert(planned.pack(expected) == OK)
		var actual := ResourceLoader.load(entry.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		assert(Audit.signature(actual) == Audit.signature(planned), "Unexpected source change: " + str(entry.species))
		assert(changed == entry.visibility_tracks)
		records.append({"species":entry.species, "runtime_sha256":entry.runtime_sha256,
			"original_native_sha256":entry.original_native_sha256,"only_visibility_sampling_changed":true})
		expected.free()
	var output := FileAccess.open(args[1],FileAccess.WRITE)
	output.store_string(JSON.stringify({"complete":true,"entries":records},"  "))
	print("FORM_BATCH_SOURCE_CONTRACT_OK scenes=",records.size())
	quit()
