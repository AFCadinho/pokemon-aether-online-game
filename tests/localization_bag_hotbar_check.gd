extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"
const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"
const PREVIEW := preload("res://scripts/ui/bag_item_effect_preview.gd")

var failed := false
var localization_manager: Node
var item_localization: Node
var settings_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	item_localization = root.get_node_or_null("ItemLocalization")
	settings_manager = root.get_node_or_null("SettingsManager")
	_check(localization_manager != null, "Bag and hotbar check can access LocalizationManager")
	_check(item_localization != null, "Bag and hotbar check can access ItemLocalization")
	_check(settings_manager != null, "Bag and hotbar check can access SettingsManager")
	var overlay_source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)
	_check(
		overlay_source.contains(
			"hotbar_index >= 0 and not typing and not _is_world_battle_active()"
		),
		"number keys bypass the overworld hotbar during battle"
	)
	if localization_manager == null or item_localization == null or settings_manager == null:
		quit(1)
		return

	var original_locale := str(localization_manager.get("current_locale"))
	var original_content_name_language := str(settings_manager.get("content_name_language"))
	settings_manager.set("content_name_language", "localized")
	_check_bag_and_hotbar_runtime_translation()
	_check_item_effect_preview_translation()
	settings_manager.set("content_name_language", original_content_name_language)
	localization_manager.call("set_locale", original_locale)
	await process_frame
	quit(1 if failed else 0)


func _check_bag_and_hotbar_runtime_translation() -> void:
	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	_check(packed != null, "localized Bag and hotbar scene loads")
	if packed == null:
		return

	var overlay := packed.instantiate()
	overlay.set("root_control", overlay.get_node_or_null("Control"))
	overlay.set("hotkey_sidebar_panel", overlay.get_node_or_null("Control/HotkeySidebar"))

	localization_manager.call("set_locale", "nl")
	overlay.call("_setup_bag_popup")
	overlay.call("_setup_player_hotbar")

	var search := overlay.get("bag_search_input") as LineEdit
	var category_buttons := overlay.get("bag_category_buttons") as Dictionary
	var all_button := category_buttons.get("all") as Button
	var all_label := all_button.find_child("Label", true, false) as Label
	var hotbar_panel := overlay.get("hotkey_sidebar_panel") as PanelContainer
	var hotbar_grid := hotbar_panel.get_node_or_null("MarginContainer/SlotStack") as GridContainer
	var hotbar_buttons := overlay.get("hotbar_buttons") as Array
	var first_hotbar_button := hotbar_buttons[0] as Control
	_check(search != null and search.placeholder_text == "Items zoeken...", "Bag search renders in Dutch")
	_check(all_label != null and all_label.text == "Alle items", "Bag category renders in Dutch")
	_check(
		first_hotbar_button != null
		and first_hotbar_button.tooltip_text.begins_with("Lege sneltoets 1")
		and first_hotbar_button.tooltip_text.contains("Ctrl+1"),
		"hotbar instructions render in Dutch"
	)
	_check(
		hotbar_grid != null
		and hotbar_grid.columns == 2
		and hotbar_grid.get_child_count() == 8,
		"hotbar keeps all eight shortcuts in a two-column grid"
	)
	_check(
		localization_manager.call(
			"text",
			"ui.hotbar.escape_rope.confirm.title",
			{"item": "Escape Rope"}
		) == "Escape Rope gebruiken?",
		"Escape Rope confirmation renders in Dutch"
	)

	var max_level_pokemon := Pokemon.new("Blastoise", 100)
	max_level_pokemon.owned_pokemon_id = 42
	max_level_pokemon.experience = 1_000_000
	max_level_pokemon.growth_rate = "medium"
	overlay.set("bag_item_use_pending_item", {"id": "exp-candy-l"})
	var disabled_target := overlay.call("_create_bag_item_use_pokemon_button", max_level_pokemon, 0) as Button
	_check(disabled_target != null and disabled_target.disabled, "max-level Bag target is disabled")
	_check(
		_find_label(disabled_target, "Niet bruikbaar · Maximaal niveau") != null,
		"disabled Bag target explains the reason inline"
	)
	if disabled_target != null:
		disabled_target.free()

	var external_item := {
		"id": "potion",
		"name": "Potion",
		"category": "medicine",
		"quantity": 2,
		"shortDesc": "Restores 20 HP.",
	}
	overlay.set(
		"bag_inventory_items",
		overlay.call("_normalize_bag_inventory_items", [external_item])
	)
	overlay.set("bag_inventory_loaded", true)
	overlay.call("_refresh_bag_items")
	var detail_name := overlay.get("bag_detail_name_label") as Label
	var detail_meta := overlay.get("bag_detail_meta_label") as Label
	var detail_description := overlay.get("bag_detail_description_label") as Label
	_check(detail_name != null and detail_name.text == "Potion", "Bag resolves the approved Dutch item name")
	_check(detail_meta != null and detail_meta.text.contains("Medicijnen"), "Bag detail grammar renders in Dutch")
	_check(
		detail_description != null and detail_description.text == "Herstelt 20 HP.",
		"Bag resolves the Dutch item description by canonical ID"
	)

	localization_manager.call("set_locale", "pt_BR")
	localization_manager.call("localize_tree", overlay)
	overlay.call("_refresh_bag_category_buttons")
	overlay.call("_refresh_bag_localized_ui")
	_check(search != null and search.placeholder_text == "Buscar itens...", "Bag search updates to Portuguese")
	_check(all_label != null and all_label.text == "Todos os itens", "Bag category updates to Portuguese")
	_check(detail_name != null and detail_name.text == "Poção", "locale switching updates the item name")
	_check(detail_meta != null and detail_meta.text.contains("Medicamentos"), "Bag detail grammar updates to Portuguese")
	_check(
		detail_description != null and detail_description.text == "Restaura 20 PS.",
		"locale switching updates the item description"
	)
	_check(
		first_hotbar_button != null and first_hotbar_button.tooltip_text.begins_with("Atalho vazio 1"),
		"hotbar instructions update to Portuguese"
	)
	_check(
		localization_manager.call(
			"text",
			"ui.hotbar.escape_rope.confirm.title",
			{"item": "Escape Rope"}
		) == "Usar Escape Rope?",
		"Escape Rope confirmation updates to Portuguese"
	)

	for loader_property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(loader_property) as Node
		if loader != null:
			loader.free()
	overlay.free()


func _check_item_effect_preview_translation() -> void:
	var pokemon := Pokemon.new("Rattata", 10)
	pokemon.current_hp = 70
	pokemon.max_hp = 90
	pokemon.stats["hp"] = 90
	pokemon.status = "psn"
	var antidote := {
		"target": "pokemon",
		"contexts": ["field"],
		"quantityPolicy": "single",
		"effects": [{"type": "cure_status", "statuses": ["psn", "tox"]}],
	}

	localization_manager.call("set_locale", "nl")
	_check(
		str(PREVIEW.preview(pokemon, antidote, 1).get("label")) == "Vergiftigd → Gezond",
		"item-effect preview renders in Dutch"
	)
	localization_manager.call("set_locale", "pt_BR")
	_check(
		str(PREVIEW.preview(pokemon, antidote, 1).get("label")) == "Envenenado → Saudável",
		"item-effect preview updates to Portuguese"
	)


func _find_label(node: Node, text: String) -> Label:
	if node == null:
		return null
	if node is Label and (node as Label).text == text:
		return node as Label
	for child: Node in node.get_children():
		var result := _find_label(child, text)
		if result != null:
			return result
	return null


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
