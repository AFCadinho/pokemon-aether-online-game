extends SceneTree

const EXCHANGE_SERVICE := preload("res://scripts/services/aether_exchange_service.gd")
const EXCHANGE_POPUP := preload("res://scenes/interface/aether_exchange_popup.tscn")
const EXCHANGE_POPUP_PATH := "res://scripts/ui/aether_exchange_popup.gd"
const UI_OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"
const PROJECT_PATH := "res://project.godot"

var failed := false


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

	var popup := EXCHANGE_POPUP.instantiate() as AetherExchangePopup
	root.add_child(popup)
	await process_frame
	_check(popup != null, "Exchange popup scene instantiates")
	_check(popup.custom_minimum_size == Vector2(1040, 660), "Exchange popup uses the production workspace size")
	_check((popup.get("tab_buttons") as Dictionary).size() == 3, "Exchange popup exposes Browse, Sell, and My Listings")
	_check((popup.get("filter_buttons") as Dictionary).size() == 3, "Exchange popup exposes asset filters")

	popup.set("active_tab", "sell")
	popup.set("sellable_items", [{
		"itemId": "poke-ball",
		"name": "Poké Ball",
		"category": "items",
		"shortDesc": "A useful item.",
		"quantity": 5,
	}])
	popup.call("_render_current_list")
	await process_frame
	var list_container := popup.get("list_container") as VBoxContainer
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
		"speciesId": "Garchomp",
		"speciesName": "Garchomp",
		"formId": null,
		"nickname": null,
		"level": 100,
		"nature": "Jolly",
	}
	popup.set("sellable_pokemon", [sellable_garchomp])
	popup.call("_render_current_list")
	popup.call("_select_entry", sellable_garchomp, "sell")
	await process_frame
	var selected_pokemon := popup.get("selected_entry") as Dictionary
	_check(int(selected_pokemon.get("pokemonId", 0)) == 25, "Sell selection retains the selected Pokémon")
	_check((popup.get("detail_stack") as VBoxContainer).get_child_count() > 1, "Selected Pokémon renders listing details immediately")
	_check(str(popup.call("_entry_name", selected_pokemon, "sell")) == "Garchomp", "Null Pokémon nicknames fall back to the species name")
	_check(str(popup.call("_optional_text", null)) == "", "Null form ids do not become sprite identifiers")

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

	var project_source := FileAccess.get_file_as_string(PROJECT_PATH)
	var popup_source := FileAccess.get_file_as_string(EXCHANGE_POPUP_PATH)
	var overlay_source := FileAccess.get_file_as_string(UI_OVERLAY_PATH)
	_check(project_source.contains('AetherExchangeService="*res://scripts/services/aether_exchange_service.gd"'), "Exchange API client is an autoload")
	_check(overlay_source.contains("aether_exchange_popup.open_exchange()"), "Existing Exchange navigation opens the live popup")
	_check(not overlay_source.contains("Aether Exchange is not implemented yet."), "Coming-soon behavior was removed")
	_check(popup_source.contains("func _load_portfolio() -> bool:"), "Portfolio loads report whether they succeeded")
	_check(popup_source.contains("func _load_browse() -> bool:"), "Browse loads report whether they succeeded")
	_check(popup_source.contains("if portfolio_loaded and browse_loaded:"), "Exchange success states require both requests to succeed")
	_check(popup_source.contains("if refreshed:\n\t\t_set_status(_t(\"ui.exchange.status.updated\")"), "Refresh errors are not overwritten by a success state")

	popup.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}
