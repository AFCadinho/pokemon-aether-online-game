extends SceneTree

const EXCHANGE_SERVICE := preload("res://scripts/services/aether_exchange_service.gd")
const EXCHANGE_POPUP := preload("res://scenes/interface/aether_exchange_popup.tscn")
const EXCHANGE_POPUP_PATH := "res://scripts/ui/aether_exchange_popup.gd"
const UI_OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"
const PROJECT_PATH := "res://project.godot"

var failed := false
var requested_summary_payload: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var service := EXCHANGE_SERVICE.new()
	var listing := service.normalize_listing({
		"id": "listing-1",
		"assetType": "pokemon",
		"asset": {"pokemonId": 42, "speciesName": "Bulbasaur", "level": 12},
		"quantity": 1,
		"unitPrice": 5000,
		"totalPrice": 5000,
		"status": "active",
		"isMine": false,
		"createdAt": "2026-08-17T12:00:00Z",
	})
	_check(str(listing.get("id", "")) == "listing-1", "Exchange service retains listing ids")
	_check(int(listing.get("totalPrice", 0)) == 5000, "Exchange service retains authoritative totals")
	_check(_dictionary(listing.get("asset", {})).get("speciesName") == "Bulbasaur", "Exchange service retains public Pokémon snapshots")
	service.free()

	var popup_host := Control.new()
	popup_host.size = Vector2(1600, 900)
	root.add_child(popup_host)
	var popup := EXCHANGE_POPUP.instantiate() as AetherExchangePopup
	popup_host.add_child(popup)
	popup.visible = true
	await process_frame
	_check(popup != null, "Exchange popup scene instantiates")
	_check(popup.get_class() == "Panel", "Exchange outer window cannot be resized by child containers")
	_check(popup.custom_minimum_size == Vector2(1040, 660), "Exchange popup uses the production workspace size")
	_check(popup.size == Vector2(1040, 660), "Exchange popup starts at its fixed workspace size")
	_check(popup.call("_get_minimum_size") == Vector2(1040, 660), "Exchange content cannot increase the popup minimum size")
	_check((popup.get("tab_buttons") as Dictionary).size() == 3, "Exchange popup exposes Browse, Sell, and My Listings")
	_check((popup.get("filter_buttons") as Dictionary).size() == 2, "Exchange popup exposes only Items and Pokémon filters")
	_check(not (popup.get("filter_buttons") as Dictionary).has(""), "Browse does not expose a combined All filter")
	_check(str(popup.get("asset_filter")) == "item", "Browse defaults to the Items category")
	var search_input := popup.get("search_input") as LineEdit
	var refresh_button := popup.get("refresh_button") as Button
	_check(search_input.get_theme_stylebox("normal") is StyleBoxFlat, "Exchange search field uses the styled input surface")
	_check(search_input.get_theme_stylebox("focus") is StyleBoxFlat, "Exchange search field has a styled focus state")
	_check(refresh_button.get_theme_stylebox("normal") is StyleBoxFlat, "Exchange Refresh action uses the styled button surface")
	_check(refresh_button.get_theme_stylebox("hover") is StyleBoxFlat, "Exchange Refresh action has a styled hover state")
	var fixed_popup_rect := Rect2(popup.position, popup.size)
	((popup.get("tab_buttons") as Dictionary).get("sell") as Button).pressed.emit()
	await process_frame
	await process_frame
	_check(Rect2(popup.position, popup.size) == fixed_popup_rect, "Clicking Sell preserves the complete Exchange window geometry")
	var list_container := popup.get("list_container") as GridContainer
	var empty_state := list_container.get_child(0) as Label
	var list_panel := popup.find_child("ExchangeListPanel", true, false) as PanelContainer
	var detail_panel := popup.find_child("ExchangeDetailPanel", true, false) as PanelContainer
	_check(empty_state != null and empty_state.autowrap_mode != TextServer.AUTOWRAP_OFF, "Sell empty-state guidance wraps within its panel")
	_check(list_panel.size.x <= 635.0, "Sell empty-state text cannot expand the listing panel")
	_check(detail_panel.position.x + detail_panel.size.x <= popup.size.x - 15.0, "Sell keeps the detail panel inside the Exchange window")
	((popup.get("tab_buttons") as Dictionary).get("mine") as Button).pressed.emit()
	await process_frame
	await process_frame
	_check(Rect2(popup.position, popup.size) == fixed_popup_rect, "Clicking My Listings preserves the complete Exchange window geometry")
	var drag_handle := popup.find_child("ExchangeDragHandle", true, false) as Control
	_check(drag_handle != null, "Exchange header exposes a drag handle")
	_check(drag_handle.mouse_default_cursor_shape == Control.CURSOR_MOVE, "Exchange drag handle uses the move cursor")

	popup.set("active_tab", "sell")
	popup.set("asset_filter", "")
	popup.call("_refresh_controls")
	var filter_buttons := popup.get("filter_buttons") as Dictionary
	_check((filter_buttons.get("item") as Button).visible, "Sell keeps the Items category visible")
	_check((filter_buttons.get("pokemon") as Button).visible, "Sell keeps the Pokémon category visible")
	_check(str(popup.get("asset_filter")) == "item", "Sell defaults to the Items category")
	popup.set("sellable_items", [{
		"itemId": "poke-ball",
		"name": "Poké Ball",
		"category": "items",
		"shortDesc": "A useful item.",
		"quantity": 5,
	}])
	popup.call("_render_current_list")
	await process_frame
	_check(list_container.get_child_count() == 1, "Sell view renders eligible inventory assets")
	popup.call("_select_entry", {
		"itemId": "poke-ball",
		"name": "Poké Ball",
		"category": "items",
		"shortDesc": "A useful item.",
		"quantity": 5,
	}, "sell")
	await process_frame
	_check(popup.get("quantity_spin") is SpinBox, "Item listings expose quantity input")
	_check(popup.get("price_spin") is SpinBox, "Listings expose fixed-price input")
	var sellable_garchomp := {
		"pokemonId": 25,
		"species": "garchomp",
		"speciesId": "Garchomp",
		"speciesName": "Garchomp",
		"formId": null,
		"nickname": null,
		"level": 100,
		"nature": "Jolly",
		"ability": "Rough Skin",
		"hiddenAbility": true,
		"gender": "Female",
		"ivs": {"hp": 31, "atk": 31, "def": 20, "spa": 0, "spd": 24, "spe": 31},
		"evs": {"hp": 4, "atk": 252, "def": 0, "spa": 0, "spd": 0, "spe": 252},
		"stats": {"hp": 357, "atk": 394, "def": 226, "spa": 176, "spd": 212, "spe": 333},
		"moves": [
			{"id": "earthquake", "name": "Earthquake", "pp": 10, "maxPp": 10},
			{"id": "dragon-claw", "name": "Dragon Claw", "pp": 15, "maxPp": 15},
		],
		"types": ["dragon", "ground"],
		"possibleAbilities": ["sand-veil", "rough-skin"],
		"origin": {
			"locationName": "Victory Road",
			"currentTrainerName": "Private seller",
			"currentTrainerUserId": 987,
		},
	}
	popup.set("asset_filter", "pokemon")
	popup.set("sellable_pokemon", [sellable_garchomp])
	popup.call("_render_current_list")
	popup.call("_select_entry", sellable_garchomp, "sell")
	await process_frame
	_check(popup.size == Vector2(1040, 660), "Sell details do not resize the Exchange popup")
	var selected_pokemon := popup.get("selected_entry") as Dictionary
	_check(int(selected_pokemon.get("pokemonId", 0)) == 25, "Sell selection retains the selected Pokémon")
	_check((popup.get("detail_stack") as VBoxContainer).get_child_count() > 1, "Selected Pokémon renders listing details immediately")
	_check(str(popup.call("_entry_name", selected_pokemon, "sell")) == "Garchomp", "Null Pokémon nicknames fall back to the species name")
	_check(str(popup.call("_optional_text", null)) == "", "Null form ids do not become sprite identifiers")
	var summary_button := popup.find_child("PokemonSummaryButton", true, false) as Button
	_check(summary_button != null, "Pokémon details expose the full read-only Summary action")
	var quick_summary := summary_button.get_parent().get_parent() as PanelContainer
	_check(quick_summary != null, "Selected Pokémon renders a compact purchase summary")
	_check(summary_button.get_theme_stylebox("normal") is StyleBoxFlat, "Pokémon Summary action uses Exchange styling")
	popup.pokemon_summary_requested.connect(_capture_summary_payload)
	summary_button.pressed.emit()
	_check(str(requested_summary_payload.get("species", "")) == "garchomp", "Summary payload includes the factory species identifier")
	_check(_array(requested_summary_payload.get("moves", [])).size() == 2, "Summary payload preserves the listed Pokémon's moves")
	var summary_origin := _dictionary(requested_summary_payload.get("origin", {}))
	_check(not summary_origin.has("currentTrainerUserId"), "Summary payload removes private trainer ids")
	_check(str(summary_origin.get("currentTrainerName", "")) != "Private seller", "Summary payload anonymizes the seller name")
	var readonly_pokemon := PokemonFactory.create_pokemon_from_backend_payload(requested_summary_payload)
	_check(readonly_pokemon != null, "Exchange payload can materialize the existing read-only Pokémon Summary")
	popup.set("active_tab", "mine")
	popup.set("my_listings", [{
		"id": "mine-long-name",
		"assetType": "pokemon",
		"asset": {
			"pokemonId": 27,
			"speciesName": "A deliberately very long Pokémon listing name that must never resize the popup",
			"level": 100,
		},
		"totalPrice": 999999,
		"status": "active",
	}])
	popup.call("_render_current_list")
	await process_frame
	await process_frame
	_check(popup.size == Vector2(1040, 660), "My Listings content does not resize the Exchange popup")

	var browse_entries: Array = []
	for index: int in range(4):
		browse_entries.append({
			"id": "browse-%d" % index,
			"assetType": "pokemon",
			"asset": {
				"pokemonId": 100 + index,
				"speciesName": "Bulbasaur",
				"level": 12,
			},
			"totalPrice": 5000 + index,
			"status": "active",
		})
	popup.set("active_tab", "browse")
	popup.set("browse_listings", browse_entries)
	popup.call("_render_current_list")
	await process_frame
	await process_frame
	_check(popup.size == Vector2(1040, 660), "Browse cards do not resize the Exchange popup")
	_check(list_container.columns >= 2, "Browse listings render in a multi-column card grid")
	_check(list_container.get_child_count() == 4, "Browse grid renders every available listing")
	_check((list_container.get_child(0) as Button).custom_minimum_size.y == 82.0, "Browse cards use the compact listing height")
	_check((list_container.get_child(0) as Button).size.x < list_container.size.x, "Browse cards do not consume a full listing row")
	_check(bool(popup.call("_mutation_requires_party_refresh", {"assetType": "pokemon"}, "ui.exchange.status.listed")), "Listing a Pokémon refreshes the persisted party")
	_check(bool(popup.call("_mutation_requires_party_refresh", {"assetType": "pokemon"}, "ui.exchange.status.cancelled")), "Cancelling a Pokémon listing refreshes the persisted party")
	_check(not bool(popup.call("_mutation_requires_party_refresh", {"assetType": "item"}, "ui.exchange.status.listed")), "Item listings do not trigger an unnecessary party refresh")

	popup.call("_show_confirmation", "Confirm listing", "This asset will be held by the Exchange.", Callable())
	await process_frame
	var confirmation_overlay := popup.get("confirmation_overlay") as Control
	var confirmation_card := popup.get("confirmation_card") as PanelContainer
	_check(confirmation_overlay != null and confirmation_overlay.visible, "Exchange confirmations use an in-interface modal overlay")
	_check(confirmation_card.get_theme_stylebox("panel") is StyleBoxFlat, "Exchange confirmation modal uses the Exchange panel styling")
	_check(popup.get("confirmation_confirm_button") is Button, "Exchange confirmation modal provides a styled confirm action")
	_check(popup.get("confirmation_cancel_button") is Button, "Exchange confirmation modal provides a styled cancel action")
	_check(popup.find_children("*", "ConfirmationDialog", true, false).is_empty(), "Exchange does not fall back to a default Godot confirmation window")
	popup.call("_on_confirmation_cancelled")
	_check(not confirmation_overlay.visible, "Exchange confirmation modal closes through its cancel action")

	var drag_press := InputEventMouseButton.new()
	drag_press.button_index = MOUSE_BUTTON_LEFT
	drag_press.pressed = true
	drag_handle.emit_signal("gui_input", drag_press)
	_check(bool(popup.get("is_dragging_popup")), "Pressing the Exchange header starts dragging")
	var drag_start := popup.position
	var drag_motion := InputEventMouseMotion.new()
	drag_motion.relative = Vector2(12, 8)
	popup.call("_input", drag_motion)
	_check(popup.position != drag_start, "Dragging the Exchange header moves the popup")
	var drag_release := InputEventMouseButton.new()
	drag_release.button_index = MOUSE_BUTTON_LEFT
	drag_release.pressed = false
	popup.call("_input", drag_release)
	_check(not bool(popup.get("is_dragging_popup")), "Releasing the mouse stops Exchange dragging")

	var project_source := FileAccess.get_file_as_string(PROJECT_PATH)
	var popup_source := FileAccess.get_file_as_string(EXCHANGE_POPUP_PATH)
	var overlay_source := FileAccess.get_file_as_string(UI_OVERLAY_PATH)
	_check(project_source.contains('AetherExchangeService="*res://scripts/services/aether_exchange_service.gd"'), "Exchange API client is an autoload")
	_check(overlay_source.contains("aether_exchange_popup.open_exchange()"), "Existing Exchange navigation opens the live popup")
	_check(overlay_source.contains("pokemon_summary_requested.connect(_on_aether_exchange_pokemon_summary_requested)"), "Exchange Summary actions are connected to the UI overlay")
	_check(overlay_source.contains("_open_readonly_pokemon_summary(pokemon_payload)"), "Exchange opens the existing read-only Pokémon Summary")
	_check(not overlay_source.contains("Aether Exchange is not implemented yet."), "Coming-soon behavior was removed")
	_check(popup_source.contains("func _load_portfolio() -> bool:"), "Portfolio loads report whether they succeeded")
	_check(popup_source.contains("func _load_browse() -> bool:"), "Browse loads report whether they succeeded")
	_check(popup_source.contains("if portfolio_loaded and browse_loaded:"), "Exchange success states require both requests to succeed")
	_check(popup_source.contains("if refreshed:\n\t\t_set_status(_t(\"ui.exchange.status.updated\")"), "Refresh errors are not overwritten by a success state")
	_check(popup_source.contains('party_service.call("refresh_party")'), "Successful Pokémon mutations synchronize the party sidebar")

	popup_host.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)


func _capture_summary_payload(payload: Dictionary) -> void:
	requested_summary_payload = payload.duplicate(true)


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return value as Array if value is Array else []
