extends Node

class_name SignTextServiceNode

const DEFAULT_LOCALE := "en"
const SIGN_TEXT_ROOT := "res://data/world_text/signs"
const SIGN_DIRECTORY_BY_LOCALE: Dictionary = {
	"en": "en",
	"nl": "nl",
	"pt_BR": "pt-BR",
}

var sign_catalog_cache: Dictionary = {}


func get_sign(sign_id: String, map_id: String = "", locale: String = "") -> Dictionary:
	var normalized_sign_id := sign_id.strip_edges()
	if normalized_sign_id.is_empty():
		return {
			"success": false,
			"error": "Missing sign_id",
			"metadata": {},
		}

	var normalized_locale := _normalize_locale(locale)
	var catalog := _load_sign_catalog(normalized_locale)
	var entries: Dictionary = catalog.get("entries", {})
	if not entries.has(normalized_sign_id):
		var fallback_catalog := _load_sign_catalog(DEFAULT_LOCALE)
		var fallback_entries: Dictionary = fallback_catalog.get("entries", {})
		if not fallback_entries.has(normalized_sign_id):
			return {
				"success": false,
				"error": "Sign text not found",
				"metadata": {},
			}
		entries = fallback_entries

	var metadata: Dictionary = (entries[normalized_sign_id] as Dictionary).duplicate(true)
	var expected_map_id := map_id.strip_edges()
	var sign_map_id := str(metadata.get("mapId", metadata.get("map_id", ""))).strip_edges()
	if not expected_map_id.is_empty() and not sign_map_id.is_empty() and sign_map_id != expected_map_id:
		return {
			"success": false,
			"error": "Sign text belongs to map %s, not %s" % [sign_map_id, expected_map_id],
			"metadata": {},
		}

	return {
		"success": true,
		"metadata": metadata,
	}


func get_lines(sign_id: String, map_id: String = "", locale: String = "") -> Array[String]:
	var response: Dictionary = get_sign(sign_id, map_id, locale)
	if not response.get("success", false):
		return []

	var metadata: Dictionary = response.get("metadata", {})
	return _get_string_array(metadata.get("lines", []))


func has_sign(sign_id: String, map_id: String = "", locale: String = "") -> bool:
	return not get_lines(sign_id, map_id, locale).is_empty()


func clear_cache() -> void:
	sign_catalog_cache.clear()


func _load_sign_catalog(locale: String) -> Dictionary:
	var normalized_locale := _normalize_locale(locale)
	if sign_catalog_cache.has(normalized_locale):
		return sign_catalog_cache[normalized_locale]

	var entries: Dictionary = {}
	var directory_name := str(SIGN_DIRECTORY_BY_LOCALE.get(normalized_locale, DEFAULT_LOCALE))
	var root_path := "%s/%s" % [SIGN_TEXT_ROOT, directory_name]
	_collect_sign_entries(root_path, entries)

	var catalog := {
		"locale": normalized_locale,
		"entries": entries,
	}
	sign_catalog_cache[normalized_locale] = catalog
	return catalog


func _collect_sign_entries(path: String, entries: Dictionary) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return

	var dir := DirAccess.open(absolute_path)
	if dir == null:
		push_warning("SignTextService: could not open sign text directory %s" % path)
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
			_collect_sign_entries(entry_path, entries)
		elif entry_name.ends_with(".json"):
			_parse_sign_text_file(entry_path, entries)
	dir.list_dir_end()


func _parse_sign_text_file(path: String, entries: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("SignTextService: could not read sign text file %s" % path)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("SignTextService: sign text file is not a JSON object: %s" % path)
		return

	var data := parsed as Dictionary
	var region_id := str(data.get("regionId", data.get("region_id", ""))).strip_edges()
	var map_id := str(data.get("mapId", data.get("map_id", ""))).strip_edges()
	var signs_value: Variant = data.get("signs", [])
	if not (signs_value is Array):
		push_warning("SignTextService: sign text file has no signs array: %s" % path)
		return

	for sign_value: Variant in signs_value as Array:
		if not (sign_value is Dictionary):
			continue

		var sign := _normalize_sign_metadata(sign_value as Dictionary, region_id, map_id)
		var sign_id := str(sign.get("id", "")).strip_edges()
		if sign_id.is_empty():
			continue

		if entries.has(sign_id):
			push_warning("SignTextService: duplicate sign_id %s in %s" % [sign_id, path])
			continue

		entries[sign_id] = sign


func _normalize_sign_metadata(sign: Dictionary, region_id: String, map_id: String) -> Dictionary:
	var metadata := sign.duplicate(true)
	metadata["id"] = str(metadata.get("id", metadata.get("signId", metadata.get("sign_id", "")))).strip_edges()
	metadata["signId"] = str(metadata.get("signId", metadata.get("sign_id", metadata["id"]))).strip_edges()
	metadata["type"] = str(metadata.get("type", metadata.get("signType", metadata.get("sign_type", "generic")))).strip_edges()
	metadata["title"] = str(metadata.get("title", "")).strip_edges()
	metadata["speakerName"] = str(metadata.get("speakerName", metadata.get("speaker_name", ""))).strip_edges()
	metadata["regionId"] = str(metadata.get("regionId", metadata.get("region_id", region_id))).strip_edges()
	metadata["mapId"] = str(metadata.get("mapId", metadata.get("map_id", map_id))).strip_edges()
	metadata["lines"] = _get_string_array(metadata.get("lines", metadata.get("text", [])))
	return metadata


func _normalize_locale(locale: String) -> String:
	if locale.strip_edges().is_empty():
		var localization_manager := get_node_or_null("/root/LocalizationManager") if is_inside_tree() else null
		if localization_manager != null:
			return str(localization_manager.get("current_locale"))
		return DEFAULT_LOCALE

	var localization_manager := get_node_or_null("/root/LocalizationManager") if is_inside_tree() else null
	if localization_manager != null and localization_manager.has_method("normalize_locale"):
		return str(localization_manager.call("normalize_locale", locale))

	var normalized := locale.strip_edges().replace("-", "_").to_lower()
	if normalized.begins_with("nl"):
		return "nl"
	if normalized.begins_with("pt"):
		return "pt_BR"
	return DEFAULT_LOCALE


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
