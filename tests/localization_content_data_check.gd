extends SceneTree

const CATALOG_PATHS: Dictionary = {
	"en": "res://localization/content/en.json",
	"nl": "res://localization/content/nl.json",
	"pt_BR": "res://localization/content/pt_BR.json",
}

var failed := false
var localization_manager: Node
var content_localization: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	content_localization = root.get_node_or_null("ContentLocalization")
	_check(localization_manager != null, "content-data check can access LocalizationManager")
	_check(content_localization != null, "content-data check can access ContentLocalization")
	if localization_manager == null or content_localization == null:
		quit(1)
		return

	var original_locale := str(localization_manager.get("current_locale"))
	_check_catalogs()
	_check_runtime_resolution()
	_check_search_terms_preserve_canonical_values()
	localization_manager.call("set_locale", original_locale)
	quit(1 if failed else 0)


func _check_catalogs() -> void:
	var catalogs: Dictionary = {}
	for locale: String in CATALOG_PATHS:
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(str(CATALOG_PATHS[locale]))
		)
		_check(parsed is Dictionary, "%s content catalog is valid JSON" % locale)
		catalogs[locale] = parsed as Dictionary if parsed is Dictionary else {}

	var english: Dictionary = catalogs.get("en", {})
	for kind: String in ["types", "natures"]:
		var english_entries: Dictionary = english.get(kind, {})
		_check(english_entries.size() == (18 if kind == "types" else 25), "English %s catalog is complete" % kind)
		var english_ids: Array = english_entries.keys()
		english_ids.sort()
		for locale: String in CATALOG_PATHS:
			var entries: Dictionary = (catalogs.get(locale, {}) as Dictionary).get(kind, {})
			var localized_ids: Array = entries.keys()
			localized_ids.sort()
			_check(localized_ids == english_ids, "%s %s IDs match English" % [locale, kind])
			for content_id_value: Variant in english_ids:
				var content_id := str(content_id_value)
				var entry: Dictionary = entries.get(content_id, {})
				_check(not str(entry.get("name", "")).strip_edges().is_empty(), "%s %s %s has a name" % [locale, kind, content_id])


func _check_runtime_resolution() -> void:
	localization_manager.call("set_locale", "nl")
	_check(content_localization.call("type_name", "fire", "Fire") == "Vuur", "Dutch type name resolves by canonical ID")
	_check(content_localization.call("nature_name", "Adamant", "Adamant") == "Vastberaden", "Dutch nature resolves by canonical value")

	localization_manager.call("set_locale", "pt_BR")
	_check(content_localization.call("type_name", "water", "Water") == "Água", "Portuguese type name resolves by canonical ID")
	_check(content_localization.call("nature_name", "Jolly", "Jolly") == "Alegre", "Portuguese nature resolves by canonical value")

	_check(
		content_localization.call("display_name", "moves", "future-move", "Future Move") == "Future Move",
		"missing content overlay keeps its English source fallback"
	)


func _check_search_terms_preserve_canonical_values() -> void:
	localization_manager.call("set_locale", "nl")
	var type_terms: Array[String] = content_localization.call("search_terms", "types", "fire", "Fire")
	_check(type_terms.has("fire"), "type search retains canonical ID")
	_check(type_terms.has("Fire"), "type search retains English fallback")
	_check(type_terms.has("Vuur"), "type search includes localized display name")

	var canonical_pokemon := {
		"types": ["fire"],
		"nature": "Adamant",
		"level": 50,
	}
	content_localization.call("type_name", canonical_pokemon.types[0], "Fire")
	content_localization.call("nature_name", canonical_pokemon.nature, canonical_pokemon.nature)
	_check(canonical_pokemon.types == ["fire"], "type localization does not mutate Pokémon mechanics")
	_check(canonical_pokemon.nature == "Adamant", "nature localization does not mutate Pokémon mechanics")
	_check(canonical_pokemon.level == 50, "content localization does not alter unrelated mechanics")


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
