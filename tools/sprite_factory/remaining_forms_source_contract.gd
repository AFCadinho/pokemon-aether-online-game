extends SceneTree
const Ordering = preload("alternate_forms_recovery_opaque_order.gd")
const LayeredPack = preload("remaining_forms_layered_pack.gd")
const Audit = preload("model_texture_audit.gd")

class ErrorSink extends Logger:
	var failed := false
	var tree: SceneTree
	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _notify: bool, _kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		failed = true
		tree.call_deferred("quit", 2)
var sink := ErrorSink.new()

func _initialize() -> void:
	sink.tree = self
	OS.add_logger(sink)
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
		var changes := ["visibility_sampling"]
		if entry.has("opaque_order_changes"):
			assert(str(entry.species).begins_with("sawsbuck-"))
			var ordered := Ordering.apply(expected)
			assert(ordered.size() == entry.opaque_order_changes.size())
			for i in ordered.size():
				var pinned: Dictionary = entry.opaque_order_changes[i]
				assert(ordered[i].mesh == str(pinned.mesh))
				assert(ordered[i].surface == int(pinned.surface) and ordered[i].priority == int(pinned.priority))
			changes.append("opaque_surface_order")
		if entry.has("independent_layer_sampling"):
			assert(str(entry.species).begins_with("rotom-fan"))
			assert(LayeredPack.apply(expected,entry.independent_layer_sampling)==entry.independent_layer_materials)
			changes.append("independent_layer_sampling")
		var planned := PackedScene.new()
		assert(planned.pack(expected) == OK)
		var actual := ResourceLoader.load(entry.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		assert(Audit.signature(actual) == Audit.signature(planned), "Unexpected source change: " + str(entry.species))
		assert(changed == entry.visibility_tracks)
		records.append({"species":entry.species, "runtime_sha256":entry.runtime_sha256,
			"original_native_sha256":entry.original_native_sha256,"declared_changes_only":true,"declared_changes":changes})
		expected.free()
	if sink.failed:
		quit(2)
		return
	var output := FileAccess.open(args[1],FileAccess.WRITE)
	output.store_string(JSON.stringify({"complete":true,"entries":records},"  "))
	print("REMAINING_SOURCE_CONTRACT_OK scenes=",records.size())
	quit()
