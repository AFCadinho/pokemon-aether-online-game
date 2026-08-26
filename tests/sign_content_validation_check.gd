extends SceneTree

const OVERWORLD_SCENE_MAP_IDS: Dictionary = {
	"res://scenes/overworld/kanto/routes/kanto_route_1.tscn": "kanto_route_1",
	"res://scenes/overworld/kanto/routes/kanto_route_2.tscn": "kanto_route_2",
	"res://scenes/overworld/kanto/routes/kanto_route_22.tscn": "kanto_route_22",
	"res://scenes/overworld/kanto/routes/kanto_route_3.tscn": "kanto_route_3",
	"res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn": "kanto_pallet_town",
	"res://scenes/overworld/kanto/towns/pallet_town/oaks_lab.tscn": "kanto_oaks_lab",
	"res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn": "kanto_viridian_city",
	"res://scenes/overworld/kanto/towns/pewter_city/pewter_city.tscn": "kanto_pewter_city",
}

const SIGN_SCENE_SUFFIXES: Array[String] = [
	"/scenes/world/interactables/sign_interactable.tscn",
	"/scenes/world/interactables/large_sign_interactable.tscn",
]
const SIGN_DATA_ROOT := "res://data/world_text/signs"
const SUPPORTED_LOCALES: Array[String] = ["en", "nl", "pt-br", "zh-cn"]
const LOCAL_CONTENT_SOURCES: Array[String] = ["", "local"]
const VALID_CONTENT_SOURCES: Dictionary = {
	"local": true,
	"inline": true,
	"remote": true,
}
const VALID_INTERACTION_MODES: Dictionary = {
	"facing_target_tile": true,
	"standing_tile": true,
}
const VALID_SIGN_SIZES: Dictionary = {
	"small": true,
	"large": true,
}
const VALID_FACING_DIRECTIONS: Dictionary = {
	"any": true,
	"up": true,
	"down": true,
	"left": true,
	"right": true,
}
const VALID_SIGN_TYPES: Dictionary = {
	"road": true,
	"town": true,
	"building": true,
	"trainer_tips": true,
	"notice": true,
	"generic": true,
}

var failed := false
var placed_signs: Array[Dictionary] = []
var sign_catalogs: Dictionary = {}


func _init() -> void:
	sign_catalogs = _load_sign_catalogs()
	placed_signs = _load_placed_signs()

	_check_placed_signs()
	_check_sign_catalog_entries_are_referenced_by_valid_maps()
	_check_supported_locale_catalog_parity()

	quit(1 if failed else 0)


func _load_placed_signs() -> Array[Dictionary]:
	var signs: Array[Dictionary] = []
	for scene_path: String in OVERWORLD_SCENE_MAP_IDS.keys():
		var text := _read_text(scene_path)
		_check_true(text != "", "%s readable" % scene_path)
		if text == "":
			continue

		var ext_resources := _parse_ext_resources(text)
		var nodes := _parse_nodes(text, ext_resources)
		for node: Dictionary in nodes:
			if not _is_placed_sign_node(node):
				continue
			node["scene_path"] = scene_path
			node["map_id"] = str(OVERWORLD_SCENE_MAP_IDS.get(scene_path, ""))
			signs.append(node)

	return signs


func _check_placed_signs() -> void:
	for sign: Dictionary in placed_signs:
		var context := _sign_context(sign)
		var parent := str(sign.get("parent", "")).strip_edges()
		_check_true(parent.begins_with("Entities/Interactables"), "%s is placed under Entities/Interactables" % context)

		var properties: Dictionary = sign.get("properties", {})
		var content_source := str(properties.get("content_source", "local")).strip_edges()
		_check_true(VALID_CONTENT_SOURCES.has(content_source), "%s content_source is valid: %s" % [context, content_source])

		var sign_type := str(properties.get("sign_type", "generic")).strip_edges()
		_check_true(VALID_SIGN_TYPES.has(sign_type), "%s sign_type is valid: %s" % [context, sign_type])

		var sign_size := str(properties.get("sign_size", _get_default_sign_size_for_node(sign))).strip_edges()
		_check_true(VALID_SIGN_SIZES.has(sign_size), "%s sign_size is valid: %s" % [context, sign_size])

		var interaction_mode := str(properties.get("interaction_mode", "standing_tile")).strip_edges()
		_check_true(VALID_INTERACTION_MODES.has(interaction_mode), "%s interaction_mode is valid: %s" % [context, interaction_mode])

		var required_facing_direction := str(properties.get("required_facing_direction", "up")).strip_edges()
		_check_true(VALID_FACING_DIRECTIONS.has(required_facing_direction), "%s required_facing_direction is valid: %s" % [context, required_facing_direction])

		if LOCAL_CONTENT_SOURCES.has(content_source):
			var sign_id := str(properties.get("sign_id", "")).strip_edges()
			_check_true(sign_id != "", "%s has sign_id" % context)
			_check_true(_is_snake_case_id(sign_id), "%s sign_id is valid snake_case: %s" % [context, sign_id])

			var default_catalog: Dictionary = sign_catalogs.get("en", {})
			var catalog_entry: Dictionary = default_catalog.get(sign_id, {})
			_check_true(not catalog_entry.is_empty(), "%s sign_id exists in local sign catalog: %s" % [context, sign_id])
			if not catalog_entry.is_empty():
				var expected_map_id := str(sign.get("map_id", "")).strip_edges()
				var actual_map_id := str(catalog_entry.get("mapId", "")).strip_edges()
				_check_true(
					actual_map_id == expected_map_id,
					"%s sign_id mapId matches scene mapId: %s" % [context, sign_id]
				)


func _check_sign_catalog_entries_are_referenced_by_valid_maps() -> void:
	var valid_map_ids := {}
	for map_id_value: Variant in OVERWORLD_SCENE_MAP_IDS.values():
		valid_map_ids[str(map_id_value)] = true

	for locale_value: Variant in sign_catalogs.keys():
		var locale := str(locale_value)
		var catalog: Dictionary = sign_catalogs.get(locale, {})
		for sign_id_value: Variant in catalog.keys():
			var sign_id := str(sign_id_value)
			var entry: Dictionary = catalog.get(sign_id, {})
			var map_id := str(entry.get("mapId", "")).strip_edges()
			_check_true(map_id != "", "sign catalog entry %s:%s has mapId" % [locale, sign_id])
			_check_true(valid_map_ids.has(map_id), "sign catalog entry %s:%s references a known mapId: %s" % [locale, sign_id, map_id])


func _check_supported_locale_catalog_parity() -> void:
	var english_catalog: Dictionary = sign_catalogs.get("en", {})
	_check_true(not english_catalog.is_empty(), "English sign catalog is available")

	for locale: String in SUPPORTED_LOCALES:
		var catalog: Dictionary = sign_catalogs.get(locale, {})
		_check_true(not catalog.is_empty(), "%s sign catalog is available" % locale)
		_check_equal(
			_sorted_keys(catalog),
			_sorted_keys(english_catalog),
			"%s sign IDs match the English catalog" % locale
		)


func _load_sign_catalogs() -> Dictionary:
	var catalogs: Dictionary = {}
	_collect_sign_files(SIGN_DATA_ROOT, catalogs)
	return catalogs


func _collect_sign_files(path: String, catalogs: Dictionary) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		_fail("sign data directory does not exist: %s" % path)
		return

	var dir := DirAccess.open(absolute_path)
	if dir == null:
		_fail("could not open sign data directory: %s" % path)
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
			_collect_sign_files(entry_path, catalogs)
		elif entry_name.ends_with(".json"):
			_parse_sign_file(entry_path, catalogs)
	dir.list_dir_end()


func _parse_sign_file(path: String, catalogs: Dictionary) -> void:
	var text := _read_text(path)
	_check_true(text != "", "sign data file readable: %s" % path)
	if text == "":
		return

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_fail("sign data file is not a JSON object: %s" % path)
		return

	var data := parsed as Dictionary
	var locale := _get_locale_from_path(path)
	if not catalogs.has(locale):
		catalogs[locale] = {}
	var catalog: Dictionary = catalogs[locale]

	var file_map_id := str(data.get("mapId", data.get("map_id", ""))).strip_edges()
	_check_true(file_map_id != "", "%s has mapId" % path)

	var signs_value: Variant = data.get("signs", [])
	if not (signs_value is Array):
		_fail("%s has signs array" % path)
		return

	for sign_value: Variant in signs_value as Array:
		if not (sign_value is Dictionary):
			_fail("%s contains non-object sign entry" % path)
			continue

		var sign := sign_value as Dictionary
		var sign_id := _get_sign_id(sign)
		_check_true(sign_id != "", "%s sign has id" % path)
		if sign_id == "":
			continue
		_check_true(_is_snake_case_id(sign_id), "%s sign id is valid snake_case: %s" % [path, sign_id])
		_check_true(not catalog.has(sign_id), "sign_id is unique in %s: %s" % [locale, sign_id])

		var sign_type := str(sign.get("type", sign.get("signType", sign.get("sign_type", "generic")))).strip_edges()
		_check_true(VALID_SIGN_TYPES.has(sign_type), "%s sign %s type is valid: %s" % [path, sign_id, sign_type])

		var lines := _get_string_array(sign.get("lines", sign.get("text", [])))
		_check_true(not lines.is_empty(), "%s sign %s has non-empty lines" % [path, sign_id])

		var raw_lines_value: Variant = sign.get("lines", sign.get("text", []))
		_check_true(_has_only_valid_lines(raw_lines_value), "%s sign %s has no empty lines" % [path, sign_id])

		if not catalog.has(sign_id):
			var normalized := sign.duplicate(true)
			normalized["id"] = sign_id
			normalized["mapId"] = str(sign.get("mapId", sign.get("map_id", file_map_id))).strip_edges()
			normalized["lines"] = lines
			catalog[sign_id] = normalized


func _get_locale_from_path(path: String) -> String:
	var prefix := "%s/" % SIGN_DATA_ROOT
	if not path.begins_with(prefix):
		return "en"

	var remainder := path.substr(prefix.length())
	var slash_index := remainder.find("/")
	if slash_index == -1:
		return "en"

	var locale := remainder.substr(0, slash_index).strip_edges().to_lower()
	return "en" if locale.is_empty() else locale


func _sorted_keys(dictionary: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key_value: Variant in dictionary.keys():
		keys.append(str(key_value))
	keys.sort()
	return keys


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
				"parent": _extract_quoted_attribute(line, "parent"),
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


func _is_placed_sign_node(node: Dictionary) -> bool:
	var instance_path := str(node.get("instance_path", ""))
	for suffix: String in SIGN_SCENE_SUFFIXES:
		if instance_path.ends_with(suffix):
			return true
	return false


func _get_default_sign_size_for_node(node: Dictionary) -> String:
	var instance_path := str(node.get("instance_path", ""))
	if instance_path.ends_with("/scenes/world/interactables/large_sign_interactable.tscn"):
		return "large"
	return "small"


func _sign_context(sign: Dictionary) -> String:
	return "%s:%s" % [str(sign.get("scene_path", "")), str(sign.get("name", ""))]


func _get_sign_id(sign: Dictionary) -> String:
	for key: String in ["id", "signId", "sign_id"]:
		var value := str(sign.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return ""


func _get_string_array(value: Variant) -> Array[String]:
	var strings: Array[String] = []
	if value is Array:
		for item: Variant in value:
			var line := str(item).strip_edges()
			if not line.is_empty():
				strings.append(line)
	elif value is String:
		var line := str(value).strip_edges()
		if not line.is_empty():
			strings.append(line)
	return strings


func _has_only_valid_lines(value: Variant) -> bool:
	if value is String:
		return not str(value).strip_edges().is_empty()
	if not (value is Array):
		return false
	for item: Variant in value as Array:
		if not (item is String) or str(item).strip_edges().is_empty():
			return false
	return true


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


func _check_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		print("PASS %s" % message)
		return

	_fail("%s expected=%s actual=%s" % [message, str(expected), str(actual)])


func _fail(message: String) -> void:
	failed = true
	push_error("FAIL %s" % message)
