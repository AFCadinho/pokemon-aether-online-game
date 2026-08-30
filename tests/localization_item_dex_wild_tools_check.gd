extends SceneTree

const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"
const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"

var failed := false
var localization_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	_check(localization_manager != null, "Item Dex localization check can access LocalizationManager")
	if localization_manager == null:
		quit(1)
		return

	var original_locale := str(localization_manager.get("current_locale"))
	_check_runtime_copy()
	_check_scene_uses_semantic_keys()
	localization_manager.call("set_locale", original_locale)
	await process_frame
	quit(1 if failed else 0)


func _check_runtime_copy() -> void:
	var overlay_script := load(OVERLAY_SCRIPT_PATH) as Script
	_check(overlay_script != null, "Item Dex overlay script loads")
	if overlay_script == null:
		return
	var overlay: Node = overlay_script.new()
	var tooltip_theme := overlay.call("_make_item_dex_tooltip_theme") as Theme
	_check(
		tooltip_theme != null
		and tooltip_theme.get_stylebox("panel", "TooltipPanel") is StyleBoxFlat
		and tooltip_theme.get_font_size("font_size", "TooltipLabel") == 12,
		"Item Dex hover cards use the shared styled tooltip theme"
	)
	var medicine := {
		"id": "potion",
		"category": "medicine",
		"subCategory": "heal",
		"cost": 300,
		"potency": 20,
		"potencyUnit": "hp",
	}

	localization_manager.call("set_locale", "nl")
	var dutch_meta := str(overlay.call("_format_item_dex_meta", medicine))
	var dutch_effect := str(overlay.call("_format_item_dex_effect_info", medicine))
	_check(dutch_meta.contains("Categorie: Medicijnen"), "Item Dex metadata renders in Dutch")
	_check(dutch_meta.contains("Kracht: 20 HP"), "Item Dex potency renders in Dutch")
	_check(dutch_effect.contains("Type: Genezing"), "Item Dex effect type renders in Dutch")
	_check(dutch_effect.contains("Herstelt de HP"), "Item Dex effect description renders in Dutch")
	_check(overlay.call("_wild_encounter_method_label", "grass") == "Hoog gras", "Wild encounter method renders in Dutch")
	_check(overlay.call("_wild_pokemon_rarity_label", "very_rare") == "Zeer zeldzaam", "Wild rarity renders in Dutch")
	_check(
		str(overlay.call("_format_item_dex_capture_info", {"id": "master-ball", "category": "balls"})).begins_with("Gegarandeerde vangst"),
		"Item Dex capture rules render in Dutch"
	)
	_check(
		overlay.call(
			"_format_item_dex_source_chance",
			{"minimum": 0.0075, "maximum": 0.012},
			"won_fishing_battle"
		) == "Kans: 0.75%–1.2%, afhankelijk van level per gewonnen fishing-gevecht",
		"Item Dex renders effective chance ranges in Dutch"
	)
	var dutch_requirements: Array[String] = overlay.call(
		"_item_dex_source_requirements",
		[{"type": "rock_smash_level", "minimum": 25, "maximum": 49}]
	)
	_check(
		dutch_requirements == ["Rock Smash lv. 25–49"],
		"Item Dex renders acquisition requirements in Dutch"
	)

	localization_manager.call("set_locale", "pt_BR")
	var portuguese_meta := str(overlay.call("_format_item_dex_meta", medicine))
	var portuguese_effect := str(overlay.call("_format_item_dex_effect_info", medicine))
	_check(portuguese_meta.contains("Categoria: Medicamentos"), "Item Dex metadata updates to Portuguese")
	_check(portuguese_meta.contains("Potência: 20 PS"), "Item Dex potency updates to Portuguese")
	_check(portuguese_effect.contains("Tipo: Cura"), "Item Dex effect type updates to Portuguese")
	_check(portuguese_effect.contains("Restaura os PS"), "Item Dex effect description updates to Portuguese")
	_check(overlay.call("_wild_encounter_method_label", "grass") == "Grama alta", "Wild encounter method updates to Portuguese")
	_check(overlay.call("_wild_pokemon_rarity_label", "very_rare") == "Muito raro", "Wild rarity updates to Portuguese")
	_check(
		overlay.call("_format_item_dex_source_chance", {"minimum": 0.1, "maximum": 0.1})
		== "Chance: 10%",
		"Item Dex acquisition chances update to Portuguese"
	)
	overlay.free()


func _check_scene_uses_semantic_keys() -> void:
	var source := FileAccess.get_file_as_string(OVERLAY_SCENE_PATH)
	for key: String in [
		"ui.staff.dev.pokemon.add_title",
		"ui.staff.dev.pokemon.add_placeholder",
		"ui.staff.dev.create_pokemon",
		"ui.staff.dev.start_encounter",
		"ui.staff.dev.clear_data",
		"ui.navigation.pvp",
		"ui.navigation.escape_rope",
	]:
		_check(source.contains('"%s"' % key), "Overlay scene uses semantic key %s" % key)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
