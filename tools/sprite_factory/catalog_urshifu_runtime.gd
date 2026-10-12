extends "prepare_battle_3d_runtime.gd"
## Bake state sampling for Rapid Strike's dynamic mesh visibility.
## Discrete event tracks can retain the wrong mesh when the same attack is rewound.
## Continuous nearest sampling preserves every source key while resolving its state
## at the current animation clock, including same-clip restarts and backwards seeks.

func _convert(entry: Dictionary, output: String) -> Dictionary:
	var prepared := super._convert(entry, output)
	if prepared.is_empty(): return prepared
	assert(entry.species in ["urshifu-rapid-strike", "urshifu-rapid-strike-shiny"])
	var scene := ResourceLoader.load(prepared.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var actor := scene.instantiate()
	var player: AnimationPlayer = actor.find_children("*", "AnimationPlayer", true, false)[0]
	var changed := 0
	for action in player.get_animation_list():
		var animation: Animation = player.get_animation(action)
		for index in animation.get_track_count():
			if not str(animation.track_get_path(index)).ends_with(":visible"): continue
			assert(animation.track_get_type(index) == Animation.TYPE_VALUE)
			assert(animation.track_get_interpolation_type(index) == Animation.INTERPOLATION_NEAREST)
			assert(animation.value_track_get_update_mode(index) == Animation.UPDATE_DISCRETE)
			animation.value_track_set_update_mode(index, Animation.UPDATE_CONTINUOUS)
			changed += 1
	assert(changed > 0)
	var saved := PackedScene.new()
	assert(saved.pack(actor) == OK)
	assert(ResourceSaver.save(saved, prepared.runtime_path, ResourceSaver.FLAG_COMPRESS) == OK)
	actor.free()
	prepared.runtime_sha256 = FileAccess.get_sha256(prepared.runtime_path)
	prepared["visibility_sampling"] = "continuous-nearest-source-keys"
	prepared["visibility_tracks"] = changed
	return prepared
