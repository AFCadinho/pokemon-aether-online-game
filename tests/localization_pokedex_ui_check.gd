extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"
const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false
var localization_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	_check(localization_manager != null, "Pokédex localization check can access LocalizationManager")
	if localization_manager == null:
		quit(1)
		return

	var original_locale := str(localization_manager.get("current_locale"))
	_check_pokedex_runtime_translation()
	var overlay_source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)
	_check(overlay_source.contains('_is_pokedex_unlocked'), "Pokédex access is item gated")
	_check(overlay_source.contains('has_item", "pokedex"'), "Owning the Pokédex unlocks its UI")
	_check(overlay_source.contains('has_item", "town-map"'), "Owning the Town Map unlocks its UI")
	_check(overlay_source.contains('ui.pokedex.locked'), "Locked Pokédex use gives player feedback")
	localization_manager.call("set_locale", original_locale)
	await process_frame
	quit(1 if failed else 0)


func _check_pokedex_runtime_translation() -> void:
	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	_check(packed != null, "localized Pokédex overlay loads")
	if packed == null:
		return

	var overlay := packed.instantiate()
	overlay.set("root_control", overlay.get_node_or_null("Control"))
	localization_manager.call("set_locale", "nl")
	overlay.call("_setup_pokedex_popup")

	var search := overlay.get("pokedex_search_input") as LineEdit
	var pokedex_popup := overlay.get("pokedex_popup") as PanelContainer
	var dex_selector := overlay.get("pokedex_dex_selector") as OptionButton
	var name_label := overlay.get("pokedex_name_label") as Label
	var tab_buttons := overlay.get("pokedex_tab_buttons") as Dictionary
	var moves_button := tab_buttons.get("moves") as Button
	var detail_stack := overlay.get("pokedex_detail_stack") as VBoxContainer
	_check(search != null and search.placeholder_text == "Zoek op naam of nummer...", "Pokédex search renders in Dutch")
	_check(
		pokedex_popup != null
		and pokedex_popup.get_theme_stylebox("panel", "TooltipPanel") is StyleBoxFlat
		and pokedex_popup.get_theme_font_size("font_size", "TooltipLabel") == 12,
		"Every Pokédex tooltip resolves the shared styled hover card theme"
	)
	_check(
		dex_selector != null and dex_selector.get_item_text(0) == "Nationale Dex",
		"Pokédex selector renders in Dutch"
	)
	_check(name_label != null and name_label.text == "Selecteer een soort", "Pokédex empty header renders in Dutch")
	_check(moves_button != null and moves_button.text == "Aanvallen", "Pokédex tabs render in Dutch")
	_check(
		detail_stack != null and _tree_contains_text(detail_stack, "POKÉDEXSTATUS"),
		"Pokédex empty detail renders in Dutch"
	)
	_check_evolution_navigation(overlay, detail_stack)
	_check_eelevate_hover(overlay)

	localization_manager.call("set_locale", "pt_BR")
	overlay.call("_on_locale_changed", "pt_BR")
	_check(search != null and search.placeholder_text == "Buscar por nome ou número...", "Pokédex search updates to Portuguese")
	_check(
		dex_selector != null and dex_selector.get_item_text(0) == "Dex Nacional",
		"Pokédex selector updates to Portuguese"
	)
	_check(name_label != null and name_label.text == "Selecione uma espécie", "Pokédex header updates to Portuguese")
	_check(moves_button != null and moves_button.text == "Golpes", "Pokédex tabs update to Portuguese")
	_check(
		detail_stack != null and _tree_contains_text(detail_stack, "STATUS DA POKÉDEX"),
		"Pokédex detail updates to Portuguese"
	)

	for loader_property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(loader_property) as Node
		if loader != null:
			loader.free()
	overlay.free()


func _check_eelevate_hover(overlay: Node) -> void:
	localization_manager.call("set_locale", "en")
	overlay.set("pokedex_active_tab", "general")
	overlay.set("pokedex_selected_species", {
		"id": "eelektross-mega",
		"abilities": [{"id": "eelevate", "name": "Eelevate", "slot": "primary"}],
	})
	overlay.call("_refresh_pokedex_detail")
	var ability_row := overlay.find_child("PokedexAbility_eelevate", true, false) as Control
	_check(
		ability_row != null
		and ability_row.tooltip_text.contains("Ground-type moves")
		and ability_row.tooltip_text.contains("highest stat"),
		"Mega Eelektross's Eelevate hover explains both parts of the Ability"
	)
	overlay.set("pokedex_selected_species", {})
	overlay.call("_set_pokedex_header_from_species", {})
	overlay.call("_refresh_pokedex_detail")
	localization_manager.call("set_locale", "nl")


func _check_evolution_navigation(overlay: Node, detail_stack: VBoxContainer) -> void:
	overlay.set("pokedex_active_tab", "evolutions")
	overlay.set("pokedex_selected_species", {
		"id": "raichu",
		"preEvolutions": [
			{
				"speciesId": "pikachu",
				"speciesName": "Pikachu",
				"evolvesIntoSpeciesId": "raichu",
				"evolvesIntoSpeciesName": "Raichu",
				"method": "item",
				"trigger": "item",
				"condition": "Thunder Stone",
				"items": ["thunder-stone"],
			},
		],
		"evolutions": [],
	})
	overlay.call("_refresh_pokedex_detail")

	var species_link := overlay.find_child("EvolutionSpeciesLink_pikachu", true, false) as LinkButton
	var item_link := overlay.find_child("EvolutionItemLink_thunder-stone", true, false) as Button
	_check(
		detail_stack != null and _tree_contains_text(detail_stack, "PRE-EVOLUTIES"),
		"Pokédex shows a localized pre-evolution section"
	)
	_check(
		species_link != null and species_link.text == "Pikachu" and not species_link.pressed.get_connections().is_empty(),
		"Pre-evolution species renders as a connected Pokédex link"
	)
	_check(
		item_link != null and item_link.text == "Thunder Stone" and not item_link.pressed.get_connections().is_empty(),
		"Evolution item renders as a connected Item Dex link"
	)
	overlay.set("pokedex_selected_species", {})
	overlay.set("pokedex_active_tab", "general")
	overlay.call("_set_pokedex_header_from_species", {})
	overlay.call("_refresh_pokedex_detail")


func _tree_contains_text(node: Node, expected: String) -> bool:
	if node is Label and (node as Label).text == expected:
		return true
	for child: Node in node.get_children():
		if _tree_contains_text(child, expected):
			return true
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
