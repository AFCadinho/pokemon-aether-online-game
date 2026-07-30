extends SceneTree

const PARTY_SLOT_SCENE_PATH := "res://scenes/interface/party_slot.tscn"
const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"

var failed := false
var localization_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	_check(localization_manager != null, "Party and Summary check can access LocalizationManager")
	if localization_manager == null:
		quit(1)
		return

	var original_locale := str(localization_manager.get("current_locale"))
	await _check_party_slot_runtime_translation()
	_check_summary_translation()
	localization_manager.call("set_locale", original_locale)
	await process_frame
	quit(1 if failed else 0)


func _check_party_slot_runtime_translation() -> void:
	var packed := load(PARTY_SLOT_SCENE_PATH) as PackedScene
	_check(packed != null, "localized Party slot scene loads")
	if packed == null:
		return

	localization_manager.call("set_locale", "nl")
	var slot := packed.instantiate()
	root.add_child(slot)
	await process_frame
	slot.call("set_pokemon_data", {
		"displaySpecies": "Pikachu",
		"level": 42,
		"maxHp": 100,
		"hp": 75,
		"shiny": true,
		"item": "mystic-water",
		"status": "burned",
	})

	var name_label := slot.get("name_label") as Label
	var level_label := slot.get("level_label") as Label
	var shiny_badge := slot.get("shiny_badge") as Label
	var held_item_marker := slot.get("held_item_marker") as Control
	var status_icon := slot.get("status_icon") as TextureRect
	_check(name_label != null and name_label.text == "Pikachu", "Party keeps the canonical species name")
	_check(level_label != null and level_label.text == "Lv. 42", "Party level renders in Dutch")
	_check(shiny_badge != null and shiny_badge.tooltip_text == "Shiny Pokémon", "Party shiny tooltip renders in Dutch")
	_check(
		held_item_marker != null and held_item_marker.tooltip_text == "Draagt Mystic Water",
		"Party held-item grammar renders in Dutch"
	)
	_check(status_icon != null and status_icon.tooltip_text == "Verbrand", "Party status renders in Dutch")

	localization_manager.call("set_locale", "pt_BR")
	await process_frame
	_check(level_label != null and level_label.text == "Nv. 42", "Party level updates to Portuguese at runtime")
	_check(
		shiny_badge != null and shiny_badge.tooltip_text == "Pokémon Brilhante",
		"Party shiny tooltip updates to Portuguese at runtime"
	)
	_check(
		held_item_marker != null and held_item_marker.tooltip_text == "Segurando Mystic Water",
		"Party held-item grammar updates while preserving the item name"
	)
	_check(status_icon != null and status_icon.tooltip_text == "Queimado", "Party status updates to Portuguese at runtime")

	slot.queue_free()
	await process_frame


func _check_summary_translation() -> void:
	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	_check(packed != null, "localized Pokémon Summary scene loads")
	if packed == null:
		return

	var overlay := packed.instantiate()
	var root_control := overlay.get_node_or_null("Control") as Control
	overlay.set("root_control", root_control)

	localization_manager.call("set_locale", "nl")
	overlay.call("_setup_pokemon_summary_popup", "localization_nl")
	var ball_search := overlay.get("pokemon_summary_ball_search_input") as LineEdit
	var held_item_search := overlay.get("pokemon_summary_item_search_input") as LineEdit
	var tabs := overlay.get("pokemon_summary_tab_buttons") as Dictionary
	_check(ball_search != null and ball_search.placeholder_text == "Poké Ball zoeken...", "Summary Ball search renders in Dutch")
	_check(
		held_item_search != null and held_item_search.placeholder_text == "Vastgehouden item zoeken...",
		"Summary held-item search renders in Dutch"
	)
	var moves_tab := tabs.get("moves") as Button
	_check(
		moves_tab != null and moves_tab.text == "AANVALLEN",
		"Summary tab renders in Dutch (received %s)" % str(moves_tab.text if moves_tab != null else "<missing>")
	)
	_check(overlay.call("_get_pokemon_summary_status_tooltip", "tox") == "Zwaar vergiftigd", "Summary status renders in Dutch")
	_check(overlay.call("_summary_stat_label", "atk") == "AANVAL", "Summary stat label renders in Dutch")
	_check(overlay.call("_format_pokemon_origin_method", "gift") == "Cadeau", "Summary origin method renders in Dutch")
	_check(
		overlay.call("_get_summary_move_accuracy_text", {"accuracy": true}) == "Altijd",
		"Summary move chrome renders in Dutch"
	)

	localization_manager.call("set_locale", "pt_BR")
	localization_manager.call("localize_tree", overlay)
	overlay.call("_refresh_pokemon_summary_tab_buttons")
	_check(ball_search != null and ball_search.placeholder_text == "Buscar Poké Bola...", "Summary Ball search updates to Portuguese")
	_check(
		held_item_search != null and held_item_search.placeholder_text == "Buscar item segurado...",
		"Summary held-item search updates to Portuguese"
	)
	moves_tab = tabs.get("moves") as Button
	_check(
		moves_tab != null and moves_tab.text == "MOVIMENTOS",
		"Summary tab updates to Portuguese (received %s)" % str(moves_tab.text if moves_tab != null else "<missing>")
	)
	_check(overlay.call("_get_pokemon_summary_status_tooltip", "tox") == "Gravemente envenenado", "Summary status renders in Portuguese")
	_check(overlay.call("_summary_stat_label", "atk") == "ATAQUE", "Summary stat label renders in Portuguese")
	_check(overlay.call("_format_pokemon_origin_method", "gift") == "Presente", "Summary origin method renders in Portuguese")
	_check(
		overlay.call("_get_summary_move_accuracy_text", {"accuracy": true}) == "Sempre",
		"Summary move chrome renders in Portuguese"
	)

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
