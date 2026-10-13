extends "res://tools/sprite_factory/shared_geometry_collection.gd"
## Offline v14 cohort. Use the actual Compatibility renderer for native actors.
func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	assert(RenderingServer.get_current_rendering_method() == "gl_compatibility")
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 3)
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var directory: String = args[2]
	DirAccess.make_dir_recursive_absolute(directory)
	var receipt := FileAccess.open(directory.path_join("records.jsonl"), FileAccess.WRITE)
	for index in input.jobs.size():
		var job: Dictionary = input.jobs[index]
		var result: Dictionary
		match args[0]:
			"produce":
				output = directory.path_join(str(index))
				result = produce(job, str(input.recipe))
			"verify":
				output = directory.path_join("objects")
				result = verify(job)
			_: assert(false)
		receipt.store_line(JSON.stringify(result))
		receipt.flush()
		await process_frame
		await process_frame
	receipt.close()
	quit()
