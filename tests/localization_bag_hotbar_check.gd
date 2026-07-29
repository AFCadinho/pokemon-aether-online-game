extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"
const PREVIEW := preload("res://scripts/ui/bag_item_effect_preview.gd")

var failed := false
var localization_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	_check(localization_manager != null, "Bag and hotbar check can access LocalizationManager")
	if localization_manager == null:
		quit(1)
		return

	var original_locale := str(localization_manager.get("current_locale"))
	_check_bag_and_hotbar_runtime_translation()
	_check_item_effect_preview_translation()
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
	var hotbar_buttons := overlay.get("hotbar_buttons") as Array
	var first_hotbar_button := hotbar_buttons[0] as Control
	_check(search != null and search.placeholder_text == "Items zoeken...", "Bag search renders in Dutch")
	_check(all_label != null and all_label.text == "Alle items", "Bag category renders in Dutch")
	_check(
		first_hotbar_button != null and first_hotbar_button.tooltip_text.begins_with("Lege sneltoets 1"),
		"hotbar instructions render in Dutch"
	)
	_check(
		localization_manager.call(
			"text",
			"ui.hotbar.escape_rope.confirm.title",
			{"item": "Escape Rope"}
		) == "Escape Rope gebruiken?",
		"Escape Rope confirmation renders in Dutch"
	)

	var external_item := {
		"id": "potion",
		"name": "Potion",
		"category": "medicine",
		"quantity": 2,
		"shortDesc": "Restores 20 HP.",
	}
	overlay.set("bag_selected_item", external_item)
	overlay.call("_refresh_bag_detail")
	var detail_name := overlay.get("bag_detail_name_label") as Label
	var detail_meta := overlay.get("bag_detail_meta_label") as Label
	var detail_description := overlay.get("bag_detail_description_label") as Label
	_check(detail_name != null and detail_name.text == "Potion", "Bag keeps the external item name unchanged")
	_check(detail_meta != null and detail_meta.text.contains("Medicijnen"), "Bag detail grammar renders in Dutch")
	_check(
		detail_description != null and detail_description.text == "Restores 20 HP.",
		"Bag keeps the external item description unchanged"
	)

	localization_manager.call("set_locale", "pt_BR")
	localization_manager.call("localize_tree", overlay)
	overlay.call("_refresh_bag_category_buttons")
	overlay.call("_refresh_bag_detail")
	overlay.call("_refresh_hotbar_ui")
	_check(search != null and search.placeholder_text == "Buscar itens...", "Bag search updates to Portuguese")
	_check(all_label != null and all_label.text == "Todos os itens", "Bag category updates to Portuguese")
	_check(detail_name != null and detail_name.text == "Potion", "locale switching preserves the external item name")
	_check(detail_meta != null and detail_meta.text.contains("Medicamentos"), "Bag detail grammar updates to Portuguese")
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


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
