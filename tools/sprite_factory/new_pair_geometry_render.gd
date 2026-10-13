extends "res://tools/sprite_factory/model_texture_render_probe.gd"
## Matched raw-model GPU controls; no compiled production binding is changed.
const Pair = preload("res://scripts/services/model_pair_pack.gd")

class ErrorSink extends Logger:
	var tree: SceneTree
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			printerr("NEW_GEOMETRY_RENDER_ERROR ", code, " ", rationale)
			tree.call_deferred("quit", 2)
var error_sink := ErrorSink.new()

func _run() -> void:
	error_sink.tree = self
	OS.add_logger(error_sink)
	assert(DisplayServer.get_name() != "headless")
	assert(RenderingServer.get_current_rendering_method() == "gl_compatibility")
	var settings := ProbeSettings.new()
	settings.name = "SettingsManager"
	root.add_child(settings)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 120
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	for pin: Dictionary in config.packs:
		var checked := Pair.inspect(pin.path, pin.asset)
		assert(str(checked.error).is_empty(), str(checked.error))
		assert(Pair.mount_checked(pin.path, pin.asset, checked).is_empty())
	var directory: String = args[1]
	assert(not DirAccess.dir_exists_absolute(directory))
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	var records := []
	for row: Dictionary in config.models:
		assert(FileAccess.get_sha256(row.source_path) == row.source_sha256)
		assert(FileAccess.get_sha256(row.candidate_path) == row.candidate_sha256)
		var source := await _render(row.source_path, directory.path_join(row.identity + "/source"))
		var repeat_source := await _render(row.source_path, directory.path_join(row.identity + "/repeat-source"), source.camera_size)
		var candidate := await _render(row.candidate_path, directory.path_join(row.identity + "/candidate"), source.camera_size)
		assert(source.camera_size == candidate.camera_size and source.response_schema == candidate.response_schema)
		assert(source.frames == repeat_source.frames, "Unstable repeated source frames")
		assert(source.frames == candidate.frames, "Candidate pixels differ")
		records.append({"identity": row.identity, "source_sha256": row.source_sha256, "candidate_sha256": row.candidate_sha256,
			"source": source, "repeat_source": repeat_source, "candidate": candidate, "pixels_exact": true})
		print("NEW_GEOMETRY_RENDER_OK ", row.identity)
	save_json(directory.path_join("report.json"), {"schema": 1, "complete": records.size() == config.models.size(),
		"prototype_only": true, "production_approved": false, "godot": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(), "device": RenderingServer.get_video_adapter_name(),
		"input_sha256": FileAccess.get_sha256(args[0]), "records": records})
	quit()
