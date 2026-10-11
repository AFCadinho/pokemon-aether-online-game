extends SceneTree

const IconResolver := preload("res://scripts/services/item_icon_resolver.gd")
const EffectPreview := preload("res://scripts/ui/bag_item_effect_preview.gd")
const ICON_PATHS := {
	"alola-stone": "res://assets/items/icons/ALOLASTONE.svg",
	"galar-stone": "res://assets/items/icons/GALARSTONE.svg",
	"hisui-stone": "res://assets/items/icons/HISUISTONE.svg",
}
const LOCALIZED_NAMES := {
	"en": ["Alola Stone", "Galar Stone", "Hisui Stone"],
	"nl": ["Alola Stone", "Galar Stone", "Hisui Stone"],
	"pt_BR": ["Pedra de Alola", "Pedra de Galar", "Pedra de Hisui"],
	"zh_CN": ["阿罗拉之石", "伽勒尔之石", "洗翠之石"],
}

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings := root.get_node("SettingsManager")
	var localization := root.get_node("ItemLocalization")
	var old_name_language: String = settings.content_name_language
	settings.content_name_language = "localized"
	for locale: String in LOCALIZED_NAMES:
		var index := 0
		for item_id: String in ICON_PATHS:
			_check(localization.display_name(item_id, "fallback", locale) == LOCALIZED_NAMES[locale][index], locale + " resolves " + item_id)
			var description: String = localization.short_description(item_id, "fallback", locale)
			_check(description != "fallback" and not description.is_empty(), locale + " describes " + item_id)
			index += 1
	settings.content_name_language = old_name_language
	var seen_paths: Array[String] = []
	for item_id: String in ICON_PATHS:
		var icon := IconResolver.load_icon(item_id)
		_check(icon != null, item_id + " loads an icon")
		if icon != null:
			_check(icon.resource_path == ICON_PATHS[item_id], item_id + " uses its dedicated stone icon")
			_check(not seen_paths.has(icon.resource_path), item_id + " has a distinct icon")
			seen_paths.append(icon.resource_path)
		var bound_icon := IconResolver.load_icon(item_id + "-bound")
		_check(bound_icon != null and bound_icon == icon, item_id + " bound variant shares its icon")
	# These direct-use stones have no day/night prerequisite in the Bag.
	var gameplay := {"target": "pokemon", "contexts": ["field"], "quantityPolicy": "single", "effects": [{"type": "evolve_item"}]}
	for hour: int in [0, 5, 12, 21, 23]:
		_check(EffectPreview.unmet_evolution_time(gameplay, hour).is_empty(), "regional stones accept game hour %d" % hour)
	quit(1 if failures else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		push_error(label)
