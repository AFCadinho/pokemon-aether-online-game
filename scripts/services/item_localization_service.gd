extends Node

const DEFAULT_LOCALE := "en"
const CATALOG_PATHS: Dictionary = {
	"en": [
		"res://localization/items/generated/en.json",
		"res://localization/items/en.json",
	],
	"nl": [
		"res://localization/items/generated/nl.json",
		"res://localization/items/nl.json",
	],
	"pt_BR": [
		"res://localization/items/generated/pt_BR.json",
		"res://localization/items/pt_BR.json",
	],
}
const SOURCE_NAME_FIELD := "_i18n_source_name"
const SOURCE_DESCRIPTION_FIELD := "_i18n_source_short_desc"

var catalogs: Dictionary = {}


func _ready() -> void:
	_load_catalogs()


func display_name(item_id: String, fallback_name: String = "", locale: String = "") -> String:
	return _localized_field(item_id, "name", fallback_name, _normalized_name_locale(locale))


func short_description(
	item_id: String,
	fallback_description: String = "",
	locale: String = ""
) -> String:
	return _localized_field(item_id, "shortDesc", fallback_description, _normalized_locale(locale))


func localize_item(item: Dictionary, locale: String = "") -> Dictionary:
	var localized := item.duplicate(true)
	var item_id := _item_id(localized)
	if item_id.is_empty():
		return localized

	var source_name := str(localized.get(
		SOURCE_NAME_FIELD,
		localized.get("name", _display_name_from_id(item_id))
	)).strip_edges()
	var source_description := str(localized.get(
		SOURCE_DESCRIPTION_FIELD,
		localized.get("shortDesc", localized.get("short_desc", localized.get("description", "")))
	)).strip_edges()
	localized[SOURCE_NAME_FIELD] = source_name
	localized[SOURCE_DESCRIPTION_FIELD] = source_description
	localized["name"] = display_name(item_id, source_name, locale)

	var translated_description := short_description(item_id, source_description, locale)
	if localized.has("shortDesc") or not translated_description.is_empty():
		localized["shortDesc"] = translated_description
	if localized.has("short_desc"):
		localized["short_desc"] = translated_description
	if localized.has("description"):
		localized["description"] = translated_description
	return localized


func localize_items(items: Array, locale: String = "") -> Array:
	var localized_items: Array = []
	for value: Variant in items:
		if value is Dictionary:
			localized_items.append(localize_item(value as Dictionary, locale))
		else:
			localized_items.append(value)
	return localized_items


func has_translation(item_id: String, locale: String = "") -> bool:
	var normalized_locale := _normalized_locale(locale)
	var catalog: Dictionary = catalogs.get(normalized_locale, {})
	return catalog.has(_normalize_item_id(item_id))


func get_catalog(locale: String) -> Dictionary:
	return (catalogs.get(_normalized_locale(locale), {}) as Dictionary).duplicate(true)


func _localized_field(
	item_id: String,
	field_name: String,
	fallback_value: String,
	locale: String
) -> String:
	var normalized_id := _normalize_item_id(item_id)
	if normalized_id.is_empty():
		return fallback_value

	var localized_entry := _catalog_entry(locale, normalized_id)
	var english_entry := _catalog_entry(DEFAULT_LOCALE, normalized_id)
	var localized_value := str(localized_entry.get(field_name, "")).strip_edges()
	if not localized_value.is_empty():
		return localized_value
	var english_value := str(english_entry.get(field_name, "")).strip_edges()
	if not english_value.is_empty():
		return english_value
	return fallback_value


func _catalog_entry(locale: String, item_id: String) -> Dictionary:
	var catalog: Dictionary = catalogs.get(locale, {})
	var value: Variant = catalog.get(item_id, {})
	return value as Dictionary if value is Dictionary else {}


func _normalized_locale(locale: String) -> String:
	if locale.strip_edges().is_empty():
		return str(LocalizationManager.current_locale)
	return LocalizationManager.normalize_locale(locale)


func _normalized_name_locale(locale: String) -> String:
	if not locale.strip_edges().is_empty():
		return LocalizationManager.normalize_locale(locale)
	if SettingsManager != null and SettingsManager.has_method("get_content_name_locale"):
		return str(SettingsManager.get_content_name_locale())
	return _normalized_locale(locale)


func _item_id(item: Dictionary) -> String:
	return _normalize_item_id(str(item.get("itemId", item.get("id", ""))))


func _normalize_item_id(item_id: String) -> String:
	return item_id.strip_edges().to_lower().replace("_", "-").replace(" ", "-")


func _display_name_from_id(item_id: String) -> String:
	var words := item_id.split("-")
	var formatted_words: Array[String] = []
	for word: String in words:
		if not word.is_empty():
			formatted_words.append(word.substr(0, 1).to_upper() + word.substr(1).to_lower())
	return " ".join(formatted_words)


func _load_catalogs() -> void:
	catalogs.clear()
	for locale_value: Variant in CATALOG_PATHS.keys():
		var locale := str(locale_value)
		var merged_catalog: Dictionary = {}
		var paths_value: Variant = CATALOG_PATHS.get(locale, [])
		var paths: Array = paths_value if paths_value is Array else [paths_value]
		for path_value: Variant in paths:
			merged_catalog.merge(_load_catalog(locale, str(path_value)), true)
		catalogs[locale] = merged_catalog


func _load_catalog(locale: String, path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		push_error("ItemLocalization: missing %s catalog at %s" % [locale, path])
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("ItemLocalization: catalog %s is not a JSON object" % path)
		return {}

	var catalog: Dictionary = {}
	for item_id_value: Variant in (parsed as Dictionary).keys():
		var item_id := _normalize_item_id(str(item_id_value))
		var entry_value: Variant = (parsed as Dictionary).get(item_id_value, {})
		if item_id.is_empty() or not entry_value is Dictionary:
			push_error("ItemLocalization: invalid item entry in %s" % path)
			continue
		var source_entry := entry_value as Dictionary
		var name := str(source_entry.get("name", "")).strip_edges()
		var short_description_value := str(source_entry.get("shortDesc", "")).strip_edges()
		if name.is_empty() or short_description_value.is_empty():
			push_error("ItemLocalization: incomplete %s entry for %s" % [locale, item_id])
			continue
		catalog[item_id] = {
			"name": name,
			"shortDesc": short_description_value,
		}
	return catalog
