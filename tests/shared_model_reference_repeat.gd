extends "res://tools/sprite_factory/shared_model_catalog_render.gd"
## Diagnostic only: repeat an unchanged approved source, never a candidate.
## Retain every capture; this does not rewrite the original comparison verdict.
func _run() -> void:
	error_sink.tree = self
	OS.add_logger(error_sink)
	assert(DisplayServer.get_name() != "headless")
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2)
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var directory: String = args[1]
	assert(input.repeats == 16 and not DirAccess.dir_exists_absolute(directory))
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	OS.set_environment("POKEAETHER_SHARED_MODEL_CATALOG_TEST", "1")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 120
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_animations = true
	settings.terrain_effects = false
	settings.weather_effects = false
	var rows := []
	for model: Dictionary in input.models:
		assert(FileAccess.get_sha256(model.source_path) == model.source_sha256)
		var controls := []
		for repeat in int(input.repeats):
			var capture := await _render_model(model.source_path,
				directory.path_join(model.identity + "/repeat-%02d" % repeat), model.identity, model.camera_size)
			assert(capture.animation_signature == model.animation_signature)
			assert(capture.pose_signatures == model.pose_signatures and capture.corrections == model.corrections)
			controls.append(capture)
			print("UNCHANGED_REFERENCE_CAPTURE ", model.identity, " ", repeat + 1)
		assert(FileAccess.get_sha256(model.source_path) == model.source_sha256)
		rows.append({"identity": model.identity, "source_sha256": model.source_sha256, "controls": controls})
		save_json(directory.path_join(model.identity + "/receipt.json"), rows[-1])
	save_json(directory.path_join("report.json"), {"schema": 1, "complete": true, "reference_only": true,
		"original_verdict_preserved": true, "input_sha256": FileAccess.get_sha256(args[0]),
		"script_sha256": FileAccess.get_sha256("res://tests/shared_model_reference_repeat.gd"),
		"render_script_sha256": FileAccess.get_sha256("res://tools/sprite_factory/shared_model_catalog_render.gd"),
		"renderer": RenderingServer.get_current_rendering_method(), "device": RenderingServer.get_video_adapter_name(), "records": rows})
	quit()
