extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"

var failed := false
var localization_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	_check(localization_manager != null, "Market localization check can access LocalizationManager")
	if localization_manager == null:
		quit(1)
		return

	var original_locale := str(localization_manager.get("current_locale"))
	_check_market_runtime_translation()
	localization_manager.call("set_locale", original_locale)
	await process_frame
	quit(1 if failed else 0)


func _check_market_runtime_translation() -> void:
	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	_check(packed != null, "localized Market overlay loads")
	if packed == null:
		return

	var overlay := packed.instantiate()
	overlay.set("root_control", overlay.get_node_or_null("Control"))
	localization_manager.call("set_locale", "nl")
	overlay.call("_setup_market_popup")
	overlay.call("open_market", {
		"name": "Pallet Town Poké Mart",
		"locationName": "Pallet Town",
		"items": [{
			"itemId": "potion",
			"name": "Potion",
			"category": "medicine",
			"shortDesc": "Restores 20 HP.",
			"costs": [{
				"currency": "money",
				"amount": 285,
				"baseAmount": 300,
				"membershipDiscountPercent": 5,
			}],
		}],
	})
	var game_state := root.get_node_or_null("GameState")
	_check(
		game_state != null and bool(game_state.call("is_overworld_input_locked")),
		"opening a Market window blocks player movement"
	)

	var title := overlay.get("market_title_label") as Label
	var subtitle := overlay.get("market_subtitle_label") as Label
	var search := overlay.get("market_search_input") as LineEdit
	var caption := overlay.get("market_catalog_caption_label") as Label
	var detail_description := overlay.get("market_detail_description_label") as Label
	var buy_button := overlay.get("market_buy_button") as Button
	_check(title != null and title.text == "Pallet Town Poké Mart", "Market preserves its proper name")
	_check(
		subtitle != null and subtitle.text.contains("Trainerbenodigdheden"),
		"Market activity renders in Dutch"
	)
	_check(search != null and search.placeholder_text == "Doorzoek het aanbod...", "Market search renders in Dutch")
	_check(caption != null and caption.text == "WINKELAANBOD", "Market catalog caption renders in Dutch")
	_check(
		detail_description != null and detail_description.text == "Herstelt 20 HP.",
		"Market uses the Dutch item description"
	)
	_check(buy_button != null and buy_button.text.begins_with("Kopen"), "Market purchase action renders in Dutch")
	var selected_item := overlay.get("market_selected_item") as Dictionary
	_check(int(selected_item.get("price", 0)) == 285, "Market uses the server-calculated member price")
	_check(
		int(selected_item.get("membershipDiscountPercent", 0)) == 5,
		"Market preserves the active Aether Blessing discount"
	)
	_check(
		overlay.call("_format_market_currency_amount", 38, "battle_points") == "38 BP",
		"Market formats Battle Point prices"
	)
	_check(
		overlay.call("_market_category_label", "medicine") == "Medicijnen",
		"Market category reuses localized Bag terminology"
	)

	localization_manager.call("set_locale", "pt_BR")
	overlay.call("_on_locale_changed", "pt_BR")
	_check(subtitle != null and subtitle.text.contains("Suprimentos"), "Market activity updates to Portuguese")
	_check(search != null and search.placeholder_text == "Buscar no catálogo...", "Market search updates to Portuguese")
	_check(caption != null and caption.text == "CATÁLOGO DA LOJA", "Market caption updates to Portuguese")
	_check(
		detail_description != null and detail_description.text == "Restaura 20 PS.",
		"Market item description updates to Portuguese"
	)
	_check(buy_button != null and buy_button.text.begins_with("Comprar"), "Market action updates to Portuguese")

	var secondary_modal := PanelContainer.new()
	secondary_modal.visible = true
	(overlay.get("root_control") as Control).add_child(secondary_modal)
	overlay.call("_activate_ui_panel", secondary_modal)
	overlay.call("_hide_market_popup")
	_check(
		game_state != null and bool(game_state.call("is_overworld_input_locked")),
		"closing one of multiple modal windows keeps player movement blocked"
	)
	secondary_modal.visible = false
	_check(
		game_state != null and not bool(game_state.call("is_overworld_input_locked")),
		"closing the last modal window restores player movement"
	)
	game_state.call("lock_overworld_input")
	secondary_modal.visible = true
	overlay.call("_activate_ui_panel", secondary_modal)
	secondary_modal.visible = false
	_check(
		bool(game_state.call("is_overworld_input_locked")),
		"closing a modal does not release an overworld lock owned by another flow"
	)
	game_state.call("unlock_overworld_input")
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
