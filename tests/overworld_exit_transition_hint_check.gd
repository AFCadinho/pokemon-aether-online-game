extends SceneTree

const OVERWORLD_ROOT := "res://scenes/overworld"

var failed := false
var checked_exits := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_paths: Array[String] = []
	_collect_scene_paths(OVERWORLD_ROOT, scene_paths)
	scene_paths.sort()

	for scene_path: String in scene_paths:
		_check_scene(scene_path)

	print("Checked %d overworld exits across %d scenes." % [checked_exits, scene_paths.size()])
	quit(1 if failed else 0)


func _collect_scene_paths(directory_path: String, scene_paths: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		failed = true
		printerr("FAIL could not open %s" % directory_path)
		return

	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var entry_path := directory_path.path_join(entry)
		if directory.current_is_dir():
			_collect_scene_paths(entry_path, scene_paths)
		elif entry.ends_with(".tscn"):
			scene_paths.append(entry_path)
		entry = directory.get_next()
	directory.list_dir_end()


func _check_scene(scene_path: String) -> void:
	var source := FileAccess.get_file_as_string(scene_path)
	if source.is_empty() and FileAccess.get_open_error() != OK:
		failed = true
		printerr("FAIL could not read %s" % scene_path)
		return

	var exit_names: Array[String] = []
	var hinted_exits: Dictionary = {}
	for line: String in source.split("\n"):
		if not line.begins_with("[node "):
			continue
		var node_name := _extract_attribute(line, "name")
		var parent_path := _extract_attribute(line, "parent")
		if line.contains('type="Area2D"') and parent_path == "Exits":
			exit_names.append(node_name)
		elif node_name in ["RouteTransitionHint", "DoorTransitionHint"] and parent_path.begins_with("Exits/"):
			hinted_exits[parent_path.trim_prefix("Exits/")] = true

	for exit_name: String in exit_names:
		checked_exits += 1
		if not hinted_exits.has(exit_name):
			failed = true
			printerr("MISSING %s :: Exits/%s" % [scene_path, exit_name])


func _extract_attribute(node_declaration: String, attribute: String) -> String:
	var marker := '%s="' % attribute
	var value_start := node_declaration.find(marker)
	if value_start < 0:
		return ""
	value_start += marker.length()
	var value_end := node_declaration.find('"', value_start)
	if value_end < 0:
		return ""
	return node_declaration.substr(value_start, value_end - value_start)
