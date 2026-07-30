extends Node

signal locale_changed(locale: String)

const DEFAULT_LOCALE := "en"
const SUPPORTED_LOCALES: Array[String] = ["en", "nl", "pt_BR"]
const CATALOG_PATHS: Dictionary = {
	"en": "res://localization/en.json",
	"nl": "res://localization/nl.json",
	"pt_BR": "res://localization/pt_BR.json",
}
const HTTP_LOCALE_BY_GODOT_LOCALE: Dictionary = {
	"en": "en",
	"nl": "nl",
	"pt_BR": "pt-BR",
}

var current_locale := DEFAULT_LOCALE
var catalogs: Dictionary = {}
var registered_translations: Array[Translation] = []


func _ready() -> void:
	_load_catalogs()
	set_locale(DEFAULT_LOCALE)


func set_locale(locale: String) -> String:
	var normalized_locale := normalize_locale(locale)
	var changed := current_locale != normalized_locale
	current_locale = normalized_locale
	TranslationServer.set_locale(current_locale)
	if changed:
		locale_changed.emit(current_locale)
	return current_locale


func refresh_current_locale() -> void:
	locale_changed.emit(current_locale)


func normalize_locale(locale: String) -> String:
	var normalized := locale.strip_edges().replace("-", "_")
	if normalized.is_empty():
		return DEFAULT_LOCALE

	var parts := normalized.split("_", false, 1)
	var language := parts[0].to_lower()
	match language:
		"nl":
			return "nl"
		"pt":
			return "pt_BR"
		"en":
			return "en"
		_:
			return DEFAULT_LOCALE


func get_preferred_system_locale() -> String:
	return normalize_locale(OS.get_locale())


func get_supported_locales() -> Array[String]:
	return SUPPORTED_LOCALES.duplicate()


func get_http_locale(locale: String = "") -> String:
	var normalized_locale := current_locale if locale.strip_edges().is_empty() else normalize_locale(locale)
	return str(HTTP_LOCALE_BY_GODOT_LOCALE.get(normalized_locale, "en"))


func get_language_name(locale: String) -> String:
	return text("language.%s" % normalize_locale(locale))


func text(key: String, values: Dictionary = {}) -> String:
	var normalized_key := key.strip_edges()
	if normalized_key.is_empty():
		return ""

	var localized_catalog: Dictionary = catalogs.get(current_locale, {})
	var english_catalog: Dictionary = catalogs.get(DEFAULT_LOCALE, {})
	var translated := str(localized_catalog.get(normalized_key, english_catalog.get(normalized_key, normalized_key)))
	return translated.format(values)


func plural(one_key: String, many_key: String, count: int, values: Dictionary = {}) -> String:
	var format_values := values.duplicate()
	format_values["count"] = count
	return text(one_key if count == 1 else many_key, format_values)


func has_key(key: String, locale: String = "") -> bool:
	var normalized_locale := current_locale if locale.strip_edges().is_empty() else normalize_locale(locale)
	var catalog: Dictionary = catalogs.get(normalized_locale, {})
	return catalog.has(key)


func get_catalog(locale: String) -> Dictionary:
	return (catalogs.get(normalize_locale(locale), {}) as Dictionary).duplicate()


func localize_tree(root: Node) -> void:
	if root == null:
		return
	if root is Label:
		_localize_control_property(root as Control, "text")
	elif root is BaseButton and not root is OptionButton:
		_localize_control_property(root as Control, "text")
	if root is LineEdit:
		_localize_control_property(root as Control, "placeholder_text")
	if root is Control:
		_localize_control_property(root as Control, "tooltip_text")
	for child: Node in root.get_children():
		localize_tree(child)


func _load_catalogs() -> void:
	catalogs.clear()
	registered_translations.clear()

	for locale: String in SUPPORTED_LOCALES:
		var catalog := _load_catalog(locale, str(CATALOG_PATHS.get(locale, "")))
		catalogs[locale] = catalog
		_register_translation(locale, catalog)


func _load_catalog(locale: String, path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		push_error("LocalizationManager: missing %s catalog at %s" % [locale, path])
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("LocalizationManager: catalog %s is not a JSON object" % path)
		return {}

	var catalog: Dictionary = {}
	for key_value: Variant in (parsed as Dictionary).keys():
		var key := str(key_value).strip_edges()
		var value := str((parsed as Dictionary).get(key_value, ""))
		if key.is_empty() or value.is_empty():
			push_error("LocalizationManager: catalog %s contains an empty key or value" % path)
			continue
		catalog[key] = value
	return catalog


func _register_translation(locale: String, catalog: Dictionary) -> void:
	var translation := Translation.new()
	translation.locale = locale
	for key_value: Variant in catalog.keys():
		var key := str(key_value)
		translation.add_message(StringName(key), StringName(str(catalog[key_value])))
	TranslationServer.add_translation(translation)
	registered_translations.append(translation)


func _localize_control_property(control: Control, property_name: String) -> void:
	var metadata_key := "i18n_source_%s" % property_name
	var source_key := str(control.get_meta(metadata_key, ""))
	if source_key.is_empty():
		var current_value := str(control.get(property_name))
		if not has_key(current_value, DEFAULT_LOCALE):
			return
		source_key = current_value
		control.set_meta(metadata_key, source_key)
	control.set(property_name, text(source_key))
