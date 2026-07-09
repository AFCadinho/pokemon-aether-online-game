extends SceneTree

const OVERWORLD_SCENES: Array[String] = [
	"res://scenes/overworld/kanto/routes/kanto_route_1.tscn",
	"res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn",
	"res://scenes/overworld/kanto/towns/pallet_town/oaks_lab.tscn",
	"res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn",
]

const NPC_SCENE_SUFFIXES: Array[String] = [
	"/scenes/npcs/dialogue_npc.tscn",
	"/scenes/npcs/gate_npc.tscn",
	"/scenes/npcs/heal_npc.tscn",
	"/scenes/npcs/trainer_npc.tscn",
	"/scenes/npcs/boss_battle_npc.tscn",
]

const TRAINER_NPC_SCENE_SUFFIX := "/scenes/npcs/trainer_npc.tscn"
const TRAINER_NPC_SCRIPT := "res://scripts/world/npcs/trainer_npc.gd"

var failed := false


func _init() -> void:
	for scene_path: String in OVERWORLD_SCENES:
		_check_scene_text(scene_path)

	quit(1 if failed else 0)


func _check_scene_text(scene_path: String) -> void:
	var text := _read_text(scene_path)
	_check_true(text != "", "%s readable" % scene_path)
	if text == "":
		return

	var ext_resources := _parse_ext_resources(text)
	var nodes := _parse_nodes(text, ext_resources)
	for node: Dictionary in nodes:
		if not _is_placed_npc_node(node):
			continue
		_check_placed_npc(scene_path, node)


func _parse_ext_resources(text: String) -> Dictionary:
	var resources := {}
	for line: String in text.split("\n"):
		if not line.begins_with("[ext_resource "):
			continue

		var id := _extract_quoted_attribute(line, "id")
		var path := _extract_quoted_attribute(line, "path")
		if id != "" and path != "":
			resources[id] = path

	return resources


func _parse_nodes(text: String, ext_resources: Dictionary) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	var current := {}

	for line: String in text.split("\n"):
		if line.begins_with("[node "):
			if not current.is_empty():
				nodes.append(current)
			current = {
				"header": line,
				"name": _extract_quoted_attribute(line, "name"),
				"instance_path": _resolve_instance_path(line, ext_resources),
				"properties": {},
			}
			continue

		if current.is_empty() or not line.contains(" = "):
			continue

		var separator_index := line.find(" = ")
		var property_name := line.substr(0, separator_index).strip_edges()
		var raw_value := line.substr(separator_index + 3).strip_edges()
		(current["properties"] as Dictionary)[property_name] = _strip_string_value(raw_value)

	if not current.is_empty():
		nodes.append(current)

	return nodes


func _resolve_instance_path(node_header: String, ext_resources: Dictionary) -> String:
	var marker := "instance=ExtResource(\""
	var start := node_header.find(marker)
	if start == -1:
		return ""
	start += marker.length()
	var end := node_header.find("\")", start)
	if end == -1:
		return ""

	var resource_id := node_header.substr(start, end - start)
	return str(ext_resources.get(resource_id, ""))


func _is_placed_npc_node(node: Dictionary) -> bool:
	var instance_path := str(node.get("instance_path", ""))
	for suffix: String in NPC_SCENE_SUFFIXES:
		if instance_path.ends_with(suffix):
			return true
	return false


func _check_placed_npc(scene_path: String, node: Dictionary) -> void:
	var properties: Dictionary = node.get("properties", {})
	var context := "%s:%s" % [scene_path, str(node.get("name", ""))]
	var npc_id := str(properties.get("npc_id", "")).strip_edges()
	var display_name := str(properties.get("display_name", "")).strip_edges()

	_check_true(npc_id != "", "%s has npc_id" % context)
	_check_true(_is_snake_case_id(npc_id), "%s npc_id is snake_case: %s" % [context, npc_id])
	if display_name != "":
		_check_true(npc_id.to_lower() != display_name.to_lower(), "%s npc_id is not display_name" % context)

	if str(node.get("instance_path", "")).ends_with(TRAINER_NPC_SCENE_SUFFIX):
		var trainer_id := str(properties.get("trainer_id", "")).strip_edges()
		if trainer_id.is_empty():
			trainer_id = _get_default_trainer_id()
		_check_true(trainer_id != "", "%s trainer NPC has trainer_id" % context)


func _extract_quoted_attribute(line: String, attribute_name: String) -> String:
	var marker := " %s=\"" % attribute_name
	var start := line.find(marker)
	if start == -1:
		marker = "[%s=\"" % attribute_name
		start = line.find(marker)
	if start == -1:
		return ""
	start += marker.length()
	var end := line.find("\"", start)
	if end == -1:
		return ""
	return line.substr(start, end - start)


func _strip_string_value(raw_value: String) -> String:
	if raw_value.length() >= 2 and raw_value.begins_with("\"") and raw_value.ends_with("\""):
		return raw_value.substr(1, raw_value.length() - 2)
	return raw_value


func _is_snake_case_id(value: String) -> bool:
	if value == "":
		return false
	if value.begins_with("_") or value.ends_with("_"):
		return false
	if value.contains("__"):
		return false

	for index in range(value.length()):
		var code := value.unicode_at(index)
		var is_lower := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57
		var is_underscore := code == 95
		if not (is_lower or is_digit or is_underscore):
			return false

	return true


func _get_default_trainer_id() -> String:
	var text := _read_text(TRAINER_NPC_SCRIPT)
	var marker := "@export var trainer_id := \""
	var start := text.find(marker)
	if start == -1:
		return ""
	start += marker.length()
	var end := text.find("\"", start)
	if end == -1:
		return ""
	return text.substr(start, end - start).strip_edges()


func _read_text(path: String) -> String:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _check_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return

	failed = true
	push_error("FAIL %s" % message)
