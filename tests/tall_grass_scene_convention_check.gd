extends SceneTree

const OVERWORLD_SCENES_ROOT := "res://scenes/overworld"
const TALL_GRASS_LAYER_NAME := "TallGrass"

var failed := false
var tall_grass_layer_count := 0


func _init() -> void:
	var scene_paths: Array[String] = []
	_collect_scene_paths(OVERWORLD_SCENES_ROOT, scene_paths)
	for scene_path: String in scene_paths:
		_check_scene(scene_path)
	_check(tall_grass_layer_count >= 6, "all existing tall-grass scene masks are audited")
	quit(1 if failed else 0)


func _collect_scene_paths(directory_path: String, scene_paths: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	_check(directory != null, "overworld scene directory is readable: %s" % directory_path)
	if directory == null:
		return

	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		var entry_path := directory_path.path_join(entry_name)
		if directory.current_is_dir():
			_collect_scene_paths(entry_path, scene_paths)
		elif entry_name.ends_with(".tscn"):
			scene_paths.append(entry_path)
		entry_name = directory.get_next()
	directory.list_dir_end()


func _check_scene(scene_path: String) -> void:
	var lines := FileAccess.get_file_as_string(scene_path).split("\n")
	for line_index: int in range(lines.size()):
		var line := lines[line_index]
		if not line.begins_with("[node ") or not line.contains('type="TileMapLayer"'):
			continue
		var node_name := _node_attribute(line, "name")
		if not node_name.to_lower().contains("grass"):
			continue

		_check(
			node_name == TALL_GRASS_LAYER_NAME,
			"%s uses TallGrass for its scene-owned grass mask" % scene_path
		)
		if node_name != TALL_GRASS_LAYER_NAME:
			continue
		tall_grass_layer_count += 1
		_check(
			_node_attribute(line, "parent") == "Tiles",
			"%s keeps TallGrass under its Tiles node" % scene_path
		)
		_check(
			_node_property_is_false(lines, line_index + 1, "visible"),
			"%s keeps TallGrass invisible" % scene_path
		)


func _node_attribute(node_header: String, attribute_name: String) -> String:
	var prefix := '%s="' % attribute_name
	var value_start := node_header.find(prefix)
	if value_start < 0:
		return ""
	value_start += prefix.length()
	var value_end := node_header.find('"', value_start)
	if value_end < 0:
		return ""
	return node_header.substr(value_start, value_end - value_start)


func _node_property_is_false(lines: PackedStringArray, property_start: int, property_name: String) -> bool:
	for line_index: int in range(property_start, lines.size()):
		var line := lines[line_index]
		if line.begins_with("[node "):
			return false
		if line.strip_edges() == "%s = false" % property_name:
			return true
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
