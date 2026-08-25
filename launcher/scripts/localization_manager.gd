extends Node

signal locale_changed(locale: String)

const DEFAULT_LOCALE := "en"
const SIMPLIFIED_CHINESE_FONT: Font = preload(
	"res://assets/fonts/NotoSansCJKsc-Regular.otf"
)
const SUPPORTED_LOCALES: Array[String] = ["en", "nl", "pt_BR", "zh_CN"]
const CATALOG_PATHS: Dictionary = {
	"en": "res://localization/en.json",
	"nl": "res://localization/nl.json",
	"pt_BR": "res://localization/pt_BR.json",
	"zh_CN": "res://localization/zh_CN.json",
}
const HTTP_LOCALE_BY_GODOT_LOCALE: Dictionary = {
	"en": "en",
	"nl": "nl",
	"pt_BR": "pt-BR",
	"zh_CN": "zh-CN",
}

var current_locale := DEFAULT_LOCALE
var catalogs: Dictionary = {}
var default_fallback_font: Font


func _ready() -> void:
	default_fallback_font = ThemeDB.fallback_font
	_load_catalogs()


func set_locale(locale: String) -> String:
	var normalized_locale := normalize_locale(locale)
	var changed := current_locale != normalized_locale
	current_locale = normalized_locale
	_apply_locale_font(current_locale)
	TranslationServer.set_locale(current_locale)
	if changed:
		locale_changed.emit(current_locale)
	return current_locale


func _apply_locale_font(locale: String) -> void:
	ThemeDB.fallback_font = (
		SIMPLIFIED_CHINESE_FONT
		if locale == "zh_CN"
		else default_fallback_font
	)


func normalize_locale(locale: String) -> String:
	var normalized := locale.strip_edges().replace("-", "_")
	if normalized.is_empty():
		return DEFAULT_LOCALE

	var language := normalized.split("_", false, 1)[0].to_lower()
	match language:
		"nl":
			return "nl"
		"pt":
			return "pt_BR"
		"zh":
			return "zh_CN"
		_:
			return "en"


func get_preferred_system_locale() -> String:
	return normalize_locale(OS.get_locale())


func get_supported_locales() -> Array[String]:
	return SUPPORTED_LOCALES.duplicate()


func get_http_locale(locale: String = "") -> String:
	var normalized := current_locale if locale.strip_edges().is_empty() else normalize_locale(locale)
	return str(HTTP_LOCALE_BY_GODOT_LOCALE.get(normalized, "en"))


func get_language_name(locale: String) -> String:
	return text("language.%s" % normalize_locale(locale))


func text(key: String, values: Dictionary = {}) -> String:
	var normalized_key := key.strip_edges()
	if normalized_key.is_empty():
		return ""
	var localized: Dictionary = catalogs.get(current_locale, {})
	var english: Dictionary = catalogs.get(DEFAULT_LOCALE, {})
	return str(localized.get(normalized_key, english.get(normalized_key, normalized_key))).format(values)


func has_key(key: String, locale: String = "") -> bool:
	var normalized := current_locale if locale.strip_edges().is_empty() else normalize_locale(locale)
	return (catalogs.get(normalized, {}) as Dictionary).has(key)


func localize_tree(root: Node) -> void:
	if root == null:
		return
	if root is Label:
		_localize_property(root as Control, "text")
	elif root is BaseButton and not root is OptionButton:
		_localize_property(root as Control, "text")
	if root is Control:
		_localize_property(root as Control, "tooltip_text")
	for child: Node in root.get_children():
		localize_tree(child)


func _load_catalogs() -> void:
	catalogs.clear()
	for locale: String in SUPPORTED_LOCALES:
		var path := str(CATALOG_PATHS.get(locale, ""))
		if path.is_empty() or not FileAccess.file_exists(path):
			push_error("LauncherLocalization: missing catalog %s" % path)
			catalogs[locale] = {}
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		catalogs[locale] = parsed as Dictionary if parsed is Dictionary else {}


func _localize_property(control: Control, property_name: String) -> void:
	var metadata_key := "i18n_source_%s" % property_name
	var source_key := str(control.get_meta(metadata_key, ""))
	if source_key.is_empty():
		source_key = str(control.get(property_name))
		if not has_key(source_key, DEFAULT_LOCALE):
			return
		control.set_meta(metadata_key, source_key)
	control.set(property_name, text(source_key))
