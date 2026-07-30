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
	var search_input := overlay.get("pc_search_input") as LineEdit
	var filter_button := overlay.get("pc_filter_button") as Button
	var species_filter := overlay.get("pc_filter_species_input") as LineEdit
	var box_title := overlay.get("pc_box_title_label") as Label
	var status := overlay.get("pc_status_label") as Label

	_check(popup != null, "Pokémon Storage popup is constructed")
	_check(release_button != null and release_button.text == "Vrijlaten", "Storage release action renders in Dutch")
	_check(close_button != null and close_button.tooltip_text == "Pokémonopslag sluiten", "Storage close tooltip renders in Dutch")
	_check(search_input != null and search_input.placeholder_text.begins_with("Doorzoek"), "Storage search renders in Dutch")
	_check(filter_button != null and filter_button.text == "Filteren", "Storage filter action renders in Dutch")
	_check(species_filter != null and species_filter.placeholder_text == "Soort", "Storage species filter renders in Dutch")
	_check(box_title != null and box_title.text == "Box 1", "Storage default box name renders in Dutch")
	_check(status != null and status.text.begins_with("Slepen"), "Storage status renders in Dutch")

	overlay.call("_set_pc_release_mode_active", true)
	_check(release_button != null and release_button.text == "Annuleren", "Storage release mode updates in Dutch")
	overlay.call("_set_pc_status", "ui.storage.search_scope", {"number": 2})

	localization_manager.call("set_locale", "pt_BR")
	overlay.call("_refresh_pc_localized_ui")
	_check(release_button != null and release_button.text == "Cancelar", "Storage release mode updates to Portuguese")
	_check(search_input != null and search_input.placeholder_text.begins_with("Buscar"), "Storage search updates to Portuguese")
	_check(species_filter != null and species_filter.placeholder_text == "Espécie", "Storage species filter updates to Portuguese")
	_check(status != null and status.text.contains("Box 2"), "Dynamic Storage status updates to Portuguese")

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
