extends Node

class_name ContentLocalizationServiceNode

const DEFAULT_LOCALE := "en"
const CATALOG_PATHS: Dictionary = {
	"en": "res://localization/content/en.json",
	"nl": "res://localization/content/nl.json",
	"pt_BR": "res://localization/content/pt_BR.json",
}
const SUPPORTED_KINDS: Array[String] = [
	"types",
	"natures",
	"species",
	"moves",
	"abilities",
	"statuses",
]

var catalogs: Dictionary = {}


func _ready() -> void:
	_load_catalogs()


func display_name(
	kind: String,
	content_id: String,
	fallback_name: String = "",
	locale: String = ""
) -> String:
	var normalized_kind := _normalize_kind(kind)
	var normalized_id := normalize_id(content_id)
	if normalized_kind.is_empty() or normalized_id.is_empty():
		return fallback_name

	var normalized_locale := _normalized_locale(locale)
	var localized_entry := _catalog_entry(normalized_locale, normalized_kind, normalized_id)
	var english_entry := _catalog_entry(DEFAULT_LOCALE, normalized_kind, normalized_id)
	var localized_name := str(localized_entry.get("name", "")).strip_edges()
	if not localized_name.is_empty():
		return localized_name
	var english_name := str(english_entry.get("name", "")).strip_edges()
	if not english_name.is_empty():
		return english_name
	return fallback_name


func type_name(type_id: String, fallback_name: String = "", locale: String = "") -> String:
	return display_name("types", type_id, fallback_name, locale)


func nature_name(nature_id: String, fallback_name: String = "", locale: String = "") -> String:
	return display_name("natures", nature_id, fallback_name, locale)


func short_description(
	kind: String,
	content_id: String,
	fallback_description: String = "",
	locale: String = ""
) -> String:
	var normalized_kind := _normalize_kind(kind)
	var normalized_id := normalize_id(content_id)
	if normalized_kind.is_empty() or normalized_id.is_empty():
		return fallback_description

	var normalized_locale := _normalized_locale(locale)
	var localized_entry := _catalog_entry(normalized_locale, normalized_kind, normalized_id)
	var english_entry := _catalog_entry(DEFAULT_LOCALE, normalized_kind, normalized_id)
	var localized_description := str(localized_entry.get("shortDesc", "")).strip_edges()
	if not localized_description.is_empty():
		return localized_description
	var english_description := str(english_entry.get("shortDesc", "")).strip_edges()
	if not english_description.is_empty():
		return english_description
	return fallback_description


func localize_metadata(
	kind: String,
	content_id: String,
	metadata: Dictionary,
	locale: String = ""
) -> Dictionary:
	var localized := metadata.duplicate(true)
	var source_name := str(localized.get("_i18n_source_name", localized.get("name", ""))).strip_edges()
	var source_description := str(localized.get(
		"_i18n_source_short_desc",
		localized.get("shortDesc", localized.get("short_desc", localized.get("description", "")))
	)).strip_edges()
	localized["_i18n_source_name"] = source_name
	localized["_i18n_source_short_desc"] = source_description
	localized["name"] = display_name(kind, content_id, source_name, locale)
	var translated_description := short_description(kind, content_id, source_description, locale)
	if localized.has("shortDesc") or not translated_description.is_empty():
		localized["shortDesc"] = translated_description
	if localized.has("short_desc"):
		localized["short_desc"] = translated_description
	if localized.has("description"):
		localized["description"] = translated_description
	return localized


func search_terms(
	kind: String,
	content_id: String,
	fallback_name: String = "",
	locale: String = ""
) -> Array[String]:
	var terms: Array[String] = []
	for value: String in [
		content_id,
		fallback_name,
		display_name(kind, content_id, fallback_name, locale),
		display_name(kind, content_id, fallback_name, DEFAULT_LOCALE),
	]:
		var term := value.strip_edges()
		if not term.is_empty() and not terms.has(term):
			terms.append(term)
	return terms


func get_catalog(locale: String) -> Dictionary:
	return (catalogs.get(_normalized_locale(locale), {}) as Dictionary).duplicate(true)


func normalize_id(content_id: String) -> String:
	var normalized := content_id.strip_edges().to_lower().replace("_", "-").replace(" ", "-")
	while normalized.contains("--"):
		normalized = normalized.replace("--", "-")
	return normalized


func _catalog_entry(locale: String, kind: String, content_id: String) -> Dictionary:
	var catalog: Dictionary = catalogs.get(locale, {})
	var kind_catalog_value: Variant = catalog.get(kind, {})
	if not kind_catalog_value is Dictionary:
		return {}
	var entry_value: Variant = (kind_catalog_value as Dictionary).get(content_id, {})
	return entry_value as Dictionary if entry_value is Dictionary else {}


func _normalized_locale(locale: String) -> String:
	if locale.strip_edges().is_empty():
		return str(LocalizationManager.current_locale)
	return LocalizationManager.normalize_locale(locale)


func _normalize_kind(kind: String) -> String:
	var normalized := kind.strip_edges().to_lower()
	if normalized.ends_with("s"):
		return normalized if SUPPORTED_KINDS.has(normalized) else ""
	var plural := "%ss" % normalized
	return plural if SUPPORTED_KINDS.has(plural) else ""


func _load_catalogs() -> void:
	catalogs.clear()
	for locale_value: Variant in CATALOG_PATHS.keys():
		var locale := str(locale_value)
		catalogs[locale] = _load_catalog(locale, str(CATALOG_PATHS.get(locale, "")))


func _load_catalog(locale: String, path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		push_error("ContentLocalization: missing %s catalog at %s" % [locale, path])
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("ContentLocalization: catalog %s is not a JSON object" % path)
		return {}

	var catalog: Dictionary = {}
	for kind_value: Variant in (parsed as Dictionary).keys():
		var kind := _normalize_kind(str(kind_value))
		var entries_value: Variant = (parsed as Dictionary).get(kind_value, {})
		if kind.is_empty() or not entries_value is Dictionary:
			push_error("ContentLocalization: invalid content kind in %s" % path)
			continue

		var entries: Dictionary = {}
		for content_id_value: Variant in (entries_value as Dictionary).keys():
			var content_id := normalize_id(str(content_id_value))
			var entry_value: Variant = (entries_value as Dictionary).get(content_id_value, {})
			if content_id.is_empty() or not entry_value is Dictionary:
				push_error("ContentLocalization: invalid %s entry in %s" % [kind, path])
				continue
			var name := str((entry_value as Dictionary).get("name", "")).strip_edges()
			if name.is_empty():
				push_error("ContentLocalization: missing %s name for %s in %s" % [kind, content_id, locale])
				continue
			var normalized_entry := {"name": name}
			var short_description_value := str((entry_value as Dictionary).get("shortDesc", "")).strip_edges()
			if not short_description_value.is_empty():
				normalized_entry["shortDesc"] = short_description_value
			entries[content_id] = normalized_entry
		catalog[kind] = entries
	return catalog
