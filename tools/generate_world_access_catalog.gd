extends Node

const Builder := preload("res://tools/world_access_catalog_builder.gd")
const DEFAULT_OUTPUT := "res://generated/world_access_catalog.json"


func _ready() -> void:
	var output_path := DEFAULT_OUTPUT
	var check_only := false
	for argument in OS.get_cmdline_user_args():
		if argument == "--check":
			check_only = true
		elif argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=").strip_edges()

	var result: Dictionary = Builder.new().build()
	if not bool(result.get("success", false)):
		for error: String in result.get("errors", []):
			push_error(error)
		get_tree().quit(1)
		return

	var catalog: Dictionary = result.get("catalog", {})
	var generated_text := JSON.stringify(catalog, "\t", true) + "\n"
	var absolute_output_path := output_path
	if output_path.begins_with("res://") or output_path.begins_with("user://"):
		absolute_output_path = ProjectSettings.globalize_path(output_path)

	if check_only:
		var existing_text := FileAccess.get_file_as_string(absolute_output_path)
		if existing_text != generated_text:
			push_error("World access catalog is stale: %s" % output_path)
			get_tree().quit(1)
			return
		print("World access catalog is current: %s" % output_path)
		get_tree().quit(0)
		return

	var error := DirAccess.make_dir_recursive_absolute(
		absolute_output_path.get_base_dir()
	)
	if error != OK:
		push_error("Could not create catalog directory: %s" % error_string(error))
		get_tree().quit(1)
		return
	var file := FileAccess.open(absolute_output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write world access catalog: %s" % output_path)
		get_tree().quit(1)
		return
	file.store_string(generated_text)
	file.close()
	print(
		"Wrote %d areas and %d transitions to %s."
		% [
			(catalog.get("areas", {}) as Dictionary).size(),
			(catalog.get("transitions", {}) as Dictionary).size(),
			output_path,
		]
	)
	get_tree().quit(0)
