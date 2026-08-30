extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"

var failed := false
var localization_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	_check(localization_manager != null, "Storage localization check can access LocalizationManager")
	if localization_manager == null:
		quit(1)
		return

	var original_locale := str(localization_manager.get("current_locale"))
	_check_storage_runtime_translation()
	localization_manager.call("set_locale", original_locale)
	await process_frame
	quit(1 if failed else 0)


func _check_storage_runtime_translation() -> void:
	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	_check(packed != null, "localized Pokémon Storage overlay loads")
	if packed == null:
		return

	var overlay := packed.instantiate()
	overlay.set("root_control", overlay.get_node_or_null("Control"))
	localization_manager.call("set_locale", "nl")
	overlay.call("_setup_pc_ui")

	var popup := overlay.get("pc_popup") as PanelContainer
	var release_button := overlay.get("pc_release_mode_button") as Button
	var close_button := overlay.get("pc_close_button") as Button
	var box_previous_button := overlay.get("pc_box_tab_prev_button") as Button
	var search_input := overlay.get("pc_search_input") as LineEdit
	var filter_button := overlay.get("pc_filter_button") as Button
	var filter_clear_button := overlay.get("pc_filter_clear_button") as Button
	var species_filter := overlay.get("pc_filter_species_input") as LineEdit
	var box_selector := overlay.get("pc_box_selector_button") as Button
	var status := overlay.get("pc_status_label") as Label
	var slot_context_menu := overlay.get("pc_slot_context_menu") as PopupMenu

	_check(popup != null, "Pokémon Storage popup is constructed")
	_check(release_button != null and release_button.text == "Vrijlaten", "Storage release action renders in Dutch")
	_check(release_button != null and release_button.get_theme_color("font_color") == Color("#dfeaf5"), "Inactive Storage release action stays visually neutral")
	_check(close_button != null and close_button.tooltip_text == "Pokémonopslag sluiten", "Storage close tooltip renders in Dutch")
	_check(close_button != null and close_button.get_theme_color("font_color") == Color("#9fb0c0"), "Storage close action stays quiet at rest")
	_check(close_button != null and close_button.get_theme_color("font_hover_color") == Color("#ff6b74"), "Storage close action becomes red on hover")
	_check(search_input != null and search_input.placeholder_text.begins_with("Doorzoek"), "Storage search renders in Dutch")
	_check(filter_button != null and filter_button.text == "Filteren", "Storage filter action renders in Dutch")
	_check(filter_clear_button != null and filter_clear_button.disabled, "Storage clear-filters action starts quiet and disabled")
	_check(species_filter != null and species_filter.placeholder_text == "Soort", "Storage species filter renders in Dutch")
	_check(box_selector != null and box_selector.text.begins_with("Box 1"), "Storage default box name renders in Dutch")
	var selector_style := box_selector.get_theme_stylebox("normal") as StyleBoxFlat
	_check(selector_style != null and selector_style.bg_color == Color("#176887e8"), "Storage box selector is the clear primary action")
	var previous_style := box_previous_button.get_theme_stylebox("normal") as StyleBoxFlat
	_check(previous_style != null and previous_style.bg_color.a == 0.0 and previous_style.border_width_left == 0, "Storage arrow navigation uses a quiet icon style")
	_check(status != null and status.text.begins_with("Slepen"), "Storage status renders in Dutch")
	_check(status != null and status.text.contains("Rechtsklik"), "Storage status teaches the box context action")
	_check(slot_context_menu != null and slot_context_menu.min_size.x >= 220, "Storage creates a readable slot context menu")
	_check(
		localization_manager.call("text", "ui.storage.context.take_item", {"item": "Restjes"}) == "Restjes afnemen",
		"Storage take-item action renders in Dutch"
	)
	overlay.call("_populate_pc_slot_context_menu", {"heldItemId": "leftovers"})
	_check(slot_context_menu.item_count == 2, "Held items add one focused action to the Storage context menu")
	_check(slot_context_menu.get_item_text(0) == "Pokémon bekijken", "Storage context summary renders in Dutch")
	_check(slot_context_menu.get_item_text(1) == "Leftovers afnemen", "Storage context take-item action includes the localized item name")
	overlay.call("_populate_pc_slot_context_menu", {})
	_check(slot_context_menu.item_count == 1, "Storage omits the take action when a Pokémon holds no item")
	species_filter.text = "Pikachu"
	overlay.call("_on_pc_filter_text_changed", species_filter.text)
	_check(filter_button.text == "Filters (1)", "Storage toolbar reports active filters")
	var active_filter_style := filter_button.get_theme_stylebox("normal") as StyleBoxFlat
	_check(active_filter_style != null and active_filter_style.bg_color == Color("#176887e8"), "Active Storage filters receive primary emphasis")
	_check(not filter_clear_button.disabled, "Storage enables clearing when a filter is active")
	overlay.call("_on_pc_clear_filters_pressed")
	_check(species_filter.text == "" and filter_clear_button.disabled, "Storage clears all advanced filters in one action")

	overlay.call("_set_pc_release_mode_active", true)
	_check(release_button != null and release_button.text == "Annuleren", "Storage release mode updates in Dutch")
	_check(release_button != null and release_button.get_theme_color("font_color") == Color("#ffe3e6"), "Active Storage release mode becomes clearly dangerous")
	overlay.call("_set_pc_status", "ui.storage.search_scope", {"number": 2})

	localization_manager.call("set_locale", "pt_BR")
	overlay.call("_refresh_pc_localized_ui")
	_check(release_button != null and release_button.text == "Cancelar", "Storage release mode updates to Portuguese")
	_check(search_input != null and search_input.placeholder_text.begins_with("Buscar"), "Storage search updates to Portuguese")
	_check(species_filter != null and species_filter.placeholder_text == "Espécie", "Storage species filter updates to Portuguese")
	_check(status != null and status.text.contains("Box 2"), "Dynamic Storage status updates to Portuguese")
	_check(
		localization_manager.call("text", "ui.storage.context.take_item", {"item": "Restos"}) == "Retirar Restos",
		"Storage take-item action updates to Portuguese"
	)

	if popup != null:
		var minimum_size := popup.get_combined_minimum_size()
		_check(minimum_size.x <= 1160.0 and minimum_size.y <= 720.0, "Storage translations fit the designed popup bounds")

	for loader_property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(loader_property) as Node
		if loader != null:
			loader.free()
	overlay.free()


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
