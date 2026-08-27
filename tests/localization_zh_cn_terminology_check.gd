extends SceneTree

const GLOSSARY_PATH := "res://localization/terminology/zh_CN.json"
const CHINESE_CATALOG_PATHS: Array[String] = [
	"res://localization/zh_CN.json",
	"res://localization/content/zh_CN.json",
	"res://localization/content/generated/zh_CN.json",
	"res://localization/items/zh_CN.json",
	"res://localization/items/generated/zh_CN.json",
]
const ALLOWED_STATUSES: Array[String] = ["official", "official_legacy", "project_approved"]

var failed := false
var parsed_catalogs: Dictionary = {}


func _init() -> void:
	_run()


func _run() -> void:
	var glossary_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(GLOSSARY_PATH))
	_check(glossary_value is Dictionary, "Simplified Chinese terminology glossary is valid JSON")
	if not (glossary_value is Dictionary):
		quit(1)
		return
	var glossary: Dictionary = glossary_value as Dictionary
	_check(int(glossary.get("schemaVersion", 0)) == 1, "terminology glossary has a supported schema")
	_check(str(glossary.get("locale", "")) == "zh_CN", "terminology glossary targets Simplified Chinese")
	_check(
		not bool((glossary.get("policy", {}) as Dictionary).get("unreviewedLiteralTranslationsAllowed", true)),
		"terminology policy rejects unreviewed literal translations"
	)

	for path: String in CHINESE_CATALOG_PATHS:
		var parsed_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(parsed_value is Dictionary, "%s is valid JSON" % path)
		parsed_catalogs[path] = parsed_value as Dictionary if parsed_value is Dictionary else {}

	var sources: Dictionary = glossary.get("sources", {})
	var terms: Dictionary = glossary.get("terms", {})
	_check(not sources.is_empty(), "terminology glossary documents its sources")
	for source_id_value: Variant in sources:
		var source: Dictionary = sources.get(source_id_value, {})
		_check(not str(source.get("label", "")).strip_edges().is_empty(), "%s has a source label" % source_id_value)
		_check(str(source.get("url", "")).begins_with("https://"), "%s uses an HTTPS source" % source_id_value)
	_check(not terms.is_empty(), "terminology glossary contains protected terms")
	for term_id_value: Variant in terms:
		_check_term(str(term_id_value), terms.get(term_id_value, {}), sources)

	var forbidden: Dictionary = glossary.get("forbiddenLiteralTranslations", {})
	_check(not forbidden.is_empty(), "terminology glossary records known literal mistranslations")
	for path: String in CHINESE_CATALOG_PATHS:
		var catalog: Dictionary = parsed_catalogs.get(path, {})
		for forbidden_value: Variant in forbidden:
			var literal := str(forbidden_value)
			_check(
				not _contains_text(catalog, literal),
				"%s does not contain forbidden literal translation %s" % [path, literal]
			)
	var generator_source := FileAccess.get_file_as_string(
		"res://tools/generate_content_translation_drafts.mjs"
	)
	_check(
		generator_source.contains("protectedGeneratedContentNames")
		and generator_source.contains("localization/terminology"),
		"machine-translation regeneration reapplies protected terminology"
	)
	quit(1 if failed else 0)


func _check_term(term_id: String, term_value: Variant, sources: Dictionary) -> void:
	_check(term_value is Dictionary, "%s has structured glossary metadata" % term_id)
	if not (term_value is Dictionary):
		return
	var term: Dictionary = term_value as Dictionary
	_check(not str(term.get("value", "")).strip_edges().is_empty(), "%s has a Chinese value" % term_id)
	_check(str(term.get("status", "")) in ALLOWED_STATUSES, "%s has an approved review status" % term_id)
	var source_ids_value: Variant = term.get("sourceIds", [])
	_check(source_ids_value is Array and not (source_ids_value as Array).is_empty(), "%s cites a source" % term_id)
	if source_ids_value is Array:
		for source_id_value: Variant in source_ids_value as Array:
			var source_id := str(source_id_value)
			_check(sources.has(source_id), "%s cites known source %s" % [term_id, source_id])

	var targets_value: Variant = term.get("targets", [])
	if not (targets_value is Array):
		_check(false, "%s targets are an array" % term_id)
		return
	if term_id.begins_with("badge.") or term_id.begins_with("move."):
		_check(not (targets_value as Array).is_empty(), "%s protects at least one catalog target" % term_id)
	for target_value: Variant in targets_value as Array:
		_check_target(term_id, str(term.get("value", "")), target_value)


func _check_target(term_id: String, expected: String, target_value: Variant) -> void:
	_check(target_value is Dictionary, "%s target is structured" % term_id)
	if not (target_value is Dictionary):
		return
	var target: Dictionary = target_value as Dictionary
	var path := str(target.get("path", ""))
	var keys_value: Variant = target.get("keys", [])
	_check(path in CHINESE_CATALOG_PATHS, "%s target uses a protected Chinese catalog" % term_id)
	_check(keys_value is Array and not (keys_value as Array).is_empty(), "%s target has a key path" % term_id)
	if not parsed_catalogs.has(path) or not (keys_value is Array):
		return
	var resolved: Variant = parsed_catalogs.get(path, {})
	for key_value: Variant in keys_value as Array:
		if not (resolved is Dictionary) or not (resolved as Dictionary).has(str(key_value)):
			resolved = null
			break
		resolved = (resolved as Dictionary).get(str(key_value))
	_check(str(resolved) == expected, "%s target matches the protected term %s" % [term_id, expected])


func _contains_text(value: Variant, needle: String) -> bool:
	if value is Dictionary:
		for child: Variant in (value as Dictionary).values():
			if _contains_text(child, needle):
				return true
	elif value is Array:
		for child: Variant in value as Array:
			if _contains_text(child, needle):
				return true
	elif value is String:
		return str(value).contains(needle)
	return false


func _check(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
