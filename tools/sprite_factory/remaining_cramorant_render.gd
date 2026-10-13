extends "shared_model_catalog_render.gd"
## Compare pixels to the user's exact preview, after the eye selector changes.
func _render_model(path: String, directory: String, identity: String, framing := 0.0) -> Dictionary:
	# This process binds each independently hash-checked local candidate in turn.
	Reviewed.DATA.data.models[identity].sha256=FileAccess.get_sha256(path)
	return await super._render_model(path,directory,identity,framing)

func _run() -> void:
	error_sink.tree=self
	OS.add_logger(error_sink)
	assert(DisplayServer.get_name()!="headless" and RenderingServer.get_rendering_device()!=null)
	var original:=root.get_node("OnDemand3DBundleService")
	root.remove_child(original);original.free()
	root.mode=Window.MODE_WINDOWED
	root.always_on_top=true
	root.show()
	process_frame.connect(func():RenderingServer.force_draw(false))
	var args:=OS.get_cmdline_user_args()
	assert(args.size()==2)
	var input: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(input.fixture))
	Reviewed.DATA.data.models.merge(fixture.models,true)
	Reviewed.DATA.data.profiles.merge(fixture.profiles,true)
	var settings:=root.get_node("SettingsManager")
	settings.battle_presentation_mode="3d"
	settings.battle_animations=true
	settings.terrain_effects=false
	settings.weather_effects=false
	OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	var directory: String=args[1]
	assert(not DirAccess.dir_exists_absolute(directory))
	DirAccess.make_dir_recursive_absolute(directory)
	var rows:=[]
	var frames:=0
	for row: Dictionary in input.models:
		assert(FileAccess.get_sha256(row.source_path)==row.source_sha256)
		assert(FileAccess.get_sha256(row.candidate_path)==row.candidate_sha256)
		var source:=await _render_model(row.source_path,directory.path_join(row.identity+"/source"),row.identity)
		var repeat_source:=await _render_model(row.source_path,directory.path_join(row.identity+"/repeat-source"),row.identity,source.camera_size)
		var candidate:=await _render_model(row.candidate_path,directory.path_join(row.identity+"/candidate"),row.identity,source.camera_size)
		for key in source.frames:
			assert(candidate.frames[key] in [source.frames[key],repeat_source.frames[key]],"Preview pixels changed: "+row.identity+"/"+key)
			frames+=1
		rows.append({"identity":row.identity,"source_sha256":row.source_sha256,"candidate_sha256":row.candidate_sha256,
			"source":source,"repeat_source":repeat_source,"candidate":candidate})
	save_json(directory.path_join("report.json"),{"complete":true,"pixel_exact_frames":frames,"records":rows,"renderer":RenderingServer.get_current_rendering_method()})
	print("CRAMORANT_APPROVED_PREVIEW_PIXELS_OK frames=",frames)
	quit()
