extends "prepare_battle_3d_runtime.gd"
## Candidate-only native conversion with source-state visibility sampling.
const Audit = preload("model_texture_audit.gd")

func _convert(entry: Dictionary, output: String) -> Dictionary:
	var prepared := super._convert(entry, output)
	if prepared.is_empty(): return prepared
	var original := str(prepared.runtime_path) + ".source.scn"
	assert(DirAccess.copy_absolute(prepared.runtime_path, original) == OK)
	var scene := ResourceLoader.load(original, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var actor := scene.instantiate()
	var player: AnimationPlayer = actor.find_children("*", "AnimationPlayer", true, false)[0]
	var changed := 0
	for action in player.get_animation_list():
		var animation := player.get_animation(action)
		for track in animation.get_track_count():
			if not str(animation.track_get_path(track)).ends_with(":visible"): continue
			assert(animation.track_get_type(track) == Animation.TYPE_VALUE)
			assert(animation.track_get_interpolation_type(track) == Animation.INTERPOLATION_NEAREST)
			assert(animation.value_track_get_update_mode(track) == Animation.UPDATE_DISCRETE)
			animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
			changed += 1
	var expected := PackedScene.new()
	assert(expected.pack(actor) == OK)
	assert(ResourceSaver.save(expected, prepared.runtime_path, ResourceSaver.FLAG_COMPRESS) == OK)
	var actual := ResourceLoader.load(prepared.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	assert(Audit.signature(actual) == Audit.signature(expected))
	actor.free()
	prepared["original_native_path"] = original
	prepared["original_native_sha256"] = FileAccess.get_sha256(original)
	prepared.runtime_sha256 = FileAccess.get_sha256(prepared.runtime_path)
	prepared["visibility_sampling"] = "continuous-nearest-source-keys"
	prepared["visibility_tracks"] = changed
	prepared["native_reload_semantics_exact"] = true
	return prepared
