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
	"/scenes/npcs/market_attendant_npc.tscn",
	"/scenes/npcs/item_gift_npc.tscn",
	"/scenes/npcs/trainer_npc.tscn",
	"/scenes/npcs/boss_battle_npc.tscn",
]

const TRAINER_NPC_SCENE_SUFFIX := "/scenes/npcs/trainer_npc.tscn"
const TRAINER_NPC_SCRIPT := "res://scripts/world/npcs/trainer_npc.gd"
const TRAINER_METADATA_SERVICE_SCRIPT := "res://scripts/services/trainer_metadata_service.gd"

const LOCAL_DIALOGUE_DIRS: Array[String] = [
	"res://data/dialogues",
	"res://data/dialogue",
	"res://metadata/dialogues",
	"res://metadata/dialogue",
	"res://tests/fixtures/dialogues",
	"res://tests/fixtures/dialogue",
]

const LOCAL_TRAINER_DIRS: Array[String] = [
	"res://data/trainers",
	"res://metadata/trainers",
	"res://tests/fixtures/trainers",
]

const TRAINER_DIALOGUE_ID_FIELDS: Array[String] = [
	"battleIntroDialogueId",
	"battle_intro_dialogue_id",
	"introDialogueId",
	"intro_dialogue_id",
	"dialogueId",
	"dialogue_id",
]

var failed := false
var placed_npcs: Array[Dictionary] = []


func _init() -> void:
	var dialogue_catalog := _load_dialogue_catalog()
	var trainer_metadata_entries := _load_metadata_entries(LOCAL_TRAINER_DIRS)
	placed_npcs = _load_placed_npcs()

	_check_placed_npc_identity()
	_check_placed_dialogue_references(dialogue_catalog)
	_check_trainer_metadata_dialogue_references(trainer_metadata_entries, dialogue_catalog)
	_check_dialogue_before_battle_fallback_allowed()

	quit(1 if failed else 0)


func _load_placed_npcs() -> Array[Dictionary]:
	var npcs: Array[Dictionary] = []
	for scene_path: String in OVERWORLD_SCENES:
		var text := _read_text(scene_path)
		_check_true(text != "", "%s readable" % scene_path)
		if text == "":
			continue

		var ext_resources := _parse_ext_resources(text)
		var nodes := _parse_nodes(text, ext_resources)
		for node: Dictionary in nodes:
			if not _is_placed_npc_node(node):
				continue
			_merge_profile_identity(node, ext_resources)
			node["scene_path"] = scene_path
			npcs.append(node)

	return npcs


func _check_placed_npc_identity() -> void:
	for npc: Dictionary in placed_npcs:
		var properties: Dictionary = npc.get("properties", {})
		var context := _npc_context(npc)
		var npc_id := str(properties.get("npc_id", "")).strip_edges()
		_check_true(npc_id != "", "%s has npc_id" % context)
		_check_true(_is_snake_case_id(npc_id), "%s npc_id is valid snake_case: %s" % [context, npc_id])

		if _is_trainer_npc(npc):
			var trainer_id := str(properties.get("trainer_id", "")).strip_edges()
			if trainer_id.is_empty():
				trainer_id = _get_default_trainer_id()
			_check_true(trainer_id != "", "%s has trainer_id" % context)
			_check_true(_is_snake_case_id(trainer_id), "%s trainer_id is valid snake_case: %s" % [context, trainer_id])


func _merge_profile_identity(node: Dictionary, ext_resources: Dictionary) -> void:
	var properties: Dictionary = node.get("properties", {})
	var profile_path := _resolve_ext_resource_value(
		str(properties.get("npc_profile", "")),
		ext_resources
	)
	if profile_path.is_empty():
		return

	var profile := load(profile_path)
	_check_true(profile != null, "%s NPC profile loads" % profile_path)
	if profile == null:
		return

	for property_name: String in ["npc_id", "npc_definition_id", "display_name"]:
		if str(properties.get(property_name, "")).strip_edges().is_empty():
			properties[property_name] = str(profile.get(property_name))


func _check_placed_dialogue_references(dialogue_catalog: Dictionary) -> void:
	var has_catalog := bool(dialogue_catalog.get("available", false))
	var dialogue_ids: Dictionary = dialogue_catalog.get("ids", {})
	for npc: Dictionary in placed_npcs:
		var properties: Dictionary = npc.get("properties", {})
		var dialogue_id := str(
			properties.get(
				"dialogue_override_id",
				properties.get("dialogue_id", "")
			)
		).strip_edges()
		if dialogue_id.is_empty():
			continue

		if not has_catalog:
			push_warning("%s dialogue override=%s is backend-only; no local dialogue catalog found." % [_npc_context(npc), dialogue_id])
			continue

		_check_true(
			dialogue_ids.has(dialogue_id),
			"%s dialogue override exists in local dialogue catalog: %s" % [_npc_context(npc), dialogue_id]
		)


func _check_trainer_metadata_dialogue_references(
	trainer_metadata_entries: Array[Dictionary],
	dialogue_catalog: Dictionary
) -> void:
	if trainer_metadata_entries.is_empty():
		push_warning("No local trainer metadata fixtures found; skipping trainer metadata dialogue reference validation.")
		return

	var has_catalog := bool(dialogue_catalog.get("available", false))
	var dialogue_ids: Dictionary = dialogue_catalog.get("ids", {})
	if not has_catalog:
		push_warning("Local trainer metadata exists, but no local dialogue catalog was found; dialogue id references are treated as backend-only.")
		return

	for entry: Dictionary in trainer_metadata_entries:
		var trainer_id := str(entry.get("id", entry.get("trainer_id", "<unknown>"))).strip_edges()
		for field: String in TRAINER_DIALOGUE_ID_FIELDS:
			var dialogue_id := str(entry.get(field, "")).strip_edges()
			if dialogue_id.is_empty():
				continue
			_check_true(
				dialogue_ids.has(dialogue_id),
				"trainer metadata %s %s exists in local dialogue catalog: %s" % [trainer_id, field, dialogue_id]
			)


func _check_dialogue_before_battle_fallback_allowed() -> void:
	var text := _read_text(TRAINER_NPC_SCRIPT)
	_check_true(
		text.contains("return _get_dialogue_lines_from_trainer_metadata(trainer_metadata)"),
		"dialogue_before_battle fallback remains allowed"
	)
	_check_true(
		text.contains("trainer_metadata.get(\"dialogue_before_battle\", [])"),
		"TrainerNPC still reads dialogue_before_battle"
	)

	var service_text := _read_text(TRAINER_METADATA_SERVICE_SCRIPT)
	_check_true(
		service_text.contains("trainer_metadata[\"dialogue_before_battle\"]"),
		"TrainerMetadataService still normalizes dialogue_before_battle"
	)


func _load_dialogue_catalog() -> Dictionary:
	var entries := _load_metadata_entries(LOCAL_DIALOGUE_DIRS)
	var ids := {}
	for entry: Dictionary in entries:
		var dialogue_id := _get_dialogue_entry_id(entry)
		if not dialogue_id.is_empty():
			ids[dialogue_id] = true

	if entries.is_empty():
		push_warning("No local dialogue metadata fixtures found; placed dialogue_id references will be treated as backend-only.")
	elif ids.is_empty():
		_fail("Local dialogue metadata fixtures were found, but no dialogue ids could be parsed.")

	return {
		"available": not ids.is_empty(),
		"ids": ids,
	}


func _get_dialogue_entry_id(entry: Dictionary) -> String:
	for key: String in ["id", "dialogueId", "dialogue_id"]:
		var value := str(entry.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return ""


func _load_metadata_entries(dirs: Array[String]) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for dir_path: String in dirs:
		_collect_metadata_entries(dir_path, entries)
	return entries


func _collect_metadata_entries(path: String, entries: Array[Dictionary]) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return

	var dir := DirAccess.open(absolute_path)
	if dir == null:
		push_warning("Could not open metadata directory: %s" % path)
		return

	dir.list_dir_begin()
	while true:
		var entry_name := dir.get_next()
		if entry_name == "":
			break
		if entry_name.begins_with("."):
			continue

		var entry_path := "%s/%s" % [path, entry_name]
		if dir.current_is_dir():
			_collect_metadata_entries(entry_path, entries)
		elif entry_name.ends_with(".json"):
			_parse_json_metadata_file(entry_path, entries)
	dir.list_dir_end()


func _parse_json_metadata_file(path: String, entries: Array[Dictionary]) -> void:
	var text := _read_text(path)
	if text == "":
		_fail("metadata file is empty or unreadable: %s" % path)
		return

	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_collect_dictionaries_from_json(parsed as Dictionary, entries)
	elif parsed is Array:
		for item: Variant in parsed as Array:
			if item is Dictionary:
				_collect_dictionaries_from_json(item as Dictionary, entries)
	else:
		_fail("metadata file is not JSON object or array: %s" % path)


func _collect_dictionaries_from_json(value: Dictionary, entries: Array[Dictionary]) -> void:
	entries.append(value)
	for key: Variant in value.keys():
		var child: Variant = value.get(key)
		if child is Dictionary:
			entries.append(child as Dictionary)
		elif child is Array:
			for item: Variant in child as Array:
				if item is Dictionary:
					entries.append(item as Dictionary)


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


func _is_trainer_npc(node: Dictionary) -> bool:
	return str(node.get("instance_path", "")).ends_with(TRAINER_NPC_SCENE_SUFFIX)


func _npc_context(npc: Dictionary) -> String:
	return "%s:%s" % [str(npc.get("scene_path", "")), str(npc.get("name", ""))]


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


func _resolve_ext_resource_value(raw_value: String, ext_resources: Dictionary) -> String:
	const PREFIX := 'ExtResource("'
	if not raw_value.begins_with(PREFIX) or not raw_value.ends_with('")'):
		return ""
	var resource_id := raw_value.substr(PREFIX.length(), raw_value.length() - PREFIX.length() - 2)
	return str(ext_resources.get(resource_id, ""))


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

	_fail(message)


func _fail(message: String) -> void:
	failed = true
	push_error("FAIL %s" % message)
