extends "res://tools/sprite_factory/new_pair_geometry_render.gd"
## Existing fire shaders can have review_time without effect-schema metadata.
## Match the existing shared_model_catalog_render.gd clock control exactly.
func effect_time(actor: Node, seconds: float) -> void:
	var seen := {}
	for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material: Material = mesh.get_active_material(surface)
			while material != null and not seen.has(material.get_instance_id()):
				seen[material.get_instance_id()] = true
				if material is ShaderMaterial and material.shader != null:
					for uniform: Dictionary in material.shader.get_shader_uniform_list():
						if uniform.name == "review_time":
							material.set_shader_parameter("review_time", seconds)
				material = material.next_pass

func save_json(path: String, data: Variant) -> void:
	if path.ends_with("report.json"):
		data["render_clock_implementation_sha256"] = FileAccess.get_sha256(get_script().resource_path)
		data["render_clock_control"] = "all_review_time_uniforms"
	super.save_json(path, data)

func _run() -> void:
	error_sink.tree = self
	OS.add_logger(error_sink)
	assert(DisplayServer.get_name() != "headless")
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
	DirAccess.make_dir_recursive_absolute(directory)
	var records := []
	for row: Dictionary in config.models:
		assert(FileAccess.get_sha256(row.source_path) == row.source_sha256)
		assert(FileAccess.get_sha256(row.candidate_path) == row.candidate_sha256)
		var source := await _render(row.source_path, directory.path_join(row.identity + "/source"))
		var repeat := await _render(row.source_path, directory.path_join(row.identity + "/repeat-source"), source.camera_size)
		var candidate := await _render(row.candidate_path, directory.path_join(row.identity + "/candidate"), source.camera_size)
		assert(source.camera_size == candidate.camera_size and source.response_schema == candidate.response_schema)
		assert(source.frames.keys() == repeat.frames.keys() and source.frames.keys() == candidate.frames.keys())
		for key: String in source.frames:
			# Exact whole-frame source OR repeated-source equality, identical to
			# qualify_shared_model_catalog.compare. Never a per-pixel tolerance.
			assert(candidate.frames[key] == source.frames[key] or candidate.frames[key] == repeat.frames[key], "Candidate matches neither source control")
		records.append({"identity": row.identity, "source": source, "repeat_source": repeat,
			"candidate": candidate, "source_sha256": row.source_sha256, "candidate_sha256": row.candidate_sha256})
		print("NEW_GEOMETRY_RENDER_OK ", row.identity)
	save_json(directory.path_join("report.json"), {"schema": 1, "complete": records.size() == config.models.size(),
		"prototype_only": true, "production_approved": false, "godot": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(), "device": RenderingServer.get_video_adapter_name(),
		"input_sha256": FileAccess.get_sha256(args[0]), "records": records})
	quit()
