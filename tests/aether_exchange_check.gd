extends SceneTree

const EXCHANGE_SERVICE := preload("res://scripts/services/aether_exchange_service.gd")
const EXCHANGE_POPUP := preload("res://scenes/interface/aether_exchange_popup.tscn")
const EXCHANGE_POPUP_PATH := "res://scripts/ui/aether_exchange_popup.gd"
const EXCHANGE_SERVICE_PATH := "res://scripts/services/aether_exchange_service.gd"
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
	var advanced_filter_button := popup.get("advanced_filter_button") as Button
	var browse_sort_button := popup.get("browse_sort_button") as OptionButton
	var advanced_filter_overlay := popup.get("advanced_filter_overlay") as ColorRect
	var advanced_filter_panel := popup.get("advanced_filter_panel") as PanelContainer
	_check(advanced_filter_button != null, "Browse exposes advanced market filters")
	_check(advanced_filter_button.get_theme_stylebox("normal") is StyleBoxFlat, "Filter action uses the Exchange button styling")
	_check(browse_sort_button != null and browse_sort_button.item_count == 6, "Browse exposes all date, price, and Pokémon level sort modes")
	_check(browse_sort_button.get_theme_icon("arrow").resource_path.ends_with("photo_mode_dropdown_arrow.svg"), "Browse sort uses the Aether dropdown styling")
	_check(browse_sort_button.get_popup().get_theme_stylebox("panel") is StyleBoxFlat, "Browse sort menu uses the Aether popup surface")
	_check(str(browse_sort_button.get_item_metadata(0)) == "newest_desc", "Browse defaults to newest listings first")
	_check(browse_sort_button.is_item_disabled(4) and browse_sort_button.is_item_disabled(5), "Item browsing disables Pokémon-only level sorting")
	advanced_filter_button.pressed.emit()
	_check(advanced_filter_overlay.visible and advanced_filter_panel.visible, "Filter action opens a centered modal filter panel")
	var advanced_fields := popup.get("advanced_filter_fields") as Dictionary
	_check((_dictionary(advanced_fields.get("category")).get("root") as Control).visible, "Item filters expose item category")
	_check(not (_dictionary(advanced_fields.get("min_level")).get("root") as Control).visible, "Item filters hide Pokémon-only fields")
	popup.set("asset_filter", "pokemon")
	popup.call("_refresh_advanced_filter_panel")
	popup.call("_sync_advanced_filter_controls")
	popup.call("_refresh_browse_sort_button")
	_check(not (_dictionary(advanced_fields.get("category")).get("root") as Control).visible, "Pokémon filters hide item-only fields")
	_check((_dictionary(advanced_fields.get("min_level")).get("root") as Control).visible, "Pokémon filters expose level constraints")
	_check(not browse_sort_button.is_item_disabled(4) and not browse_sort_button.is_item_disabled(5), "Pokémon browsing enables level sorting")
	_check((popup.get("advanced_filter_sections") as Dictionary).has("ivs"), "Pokémon filters group individual IV values in their own section")
	_check(popup.get("advanced_filter_cancel_button") is Button, "Filter modal exposes an explicit Cancel action")
	var advanced_controls := popup.get("advanced_filter_controls") as Dictionary
	var styled_dropdown_count := 0
	for control_value: Variant in advanced_controls.values():
		var dropdown := control_value as OptionButton
		if dropdown == null:
			continue
		styled_dropdown_count += 1
		var dropdown_popup := dropdown.get_popup()
		_check(dropdown.get_theme_icon("arrow").resource_path.ends_with("photo_mode_dropdown_arrow.svg"), "Filter dropdown uses the Aether arrow icon")
		_check(dropdown_popup.get_theme_stylebox("panel") is StyleBoxFlat, "Filter dropdown menu uses the Aether popup surface")
		_check(dropdown_popup.get_theme_stylebox("hover") is StyleBoxFlat, "Filter dropdown menu has an Aether hover state")
		_check(dropdown_popup.get_theme_icon("radio_checked").resource_path.ends_with("photo_mode_radio_checked.svg"), "Filter dropdown menu uses styled selection markers")
	_check(styled_dropdown_count == 5, "Every advanced filter dropdown receives the shared Aether menu styling")
	(advanced_controls.get("min_price") as SpinBox).value = 1000
	(advanced_controls.get("min_level") as SpinBox).value = 50
	(advanced_controls.get("max_level") as SpinBox).value = 80
	(advanced_controls.get("ability") as LineEdit).text = "Sharpness"
	(advanced_controls.get("min_iv_hp") as SpinBox).value = 31
	(advanced_controls.get("min_iv_atk") as SpinBox).value = 30
	(advanced_controls.get("min_iv_spe") as SpinBox).value = 29
	popup.call("_select_filter_option", "primary_type", "water")
	popup.call("_select_filter_option", "secondary_type", "dark")
	popup.call("_select_filter_option", "nature", "jolly")
	popup.call("_select_filter_option", "shiny", 1)
	popup.call("_select_filter_option", "hidden_ability", 0)
	_check(bool(popup.call("_apply_browse_sort_mode", "price_desc")), "Browse accepts expensive-to-cheap sorting")
	popup.call("_read_advanced_filter_controls")
	var pokemon_filter_params := popup.call("_current_browse_filter_params") as Dictionary
	_check(pokemon_filter_params.get("minPrice") == 1000, "Filters retain the minimum market price")
	_check(pokemon_filter_params.get("minLevel") == 50 and pokemon_filter_params.get("maxLevel") == 80, "Filters retain the Pokémon level range")
	_check(
		pokemon_filter_params.get("primaryType") == "water"
		and pokemon_filter_params.get("secondaryType") == "dark"
		and pokemon_filter_params.get("nature") == "jolly",
		"Filters retain both Pokémon types and nature"
	)
	_check(pokemon_filter_params.get("ability") == "Sharpness", "Filters retain an ability query")
	_check(pokemon_filter_params.get("shiny") == true and pokemon_filter_params.get("hiddenAbility") == false, "Filters retain shiny and Hidden Ability choices")
	_check(
		pokemon_filter_params.get("minHpIv") == 31
		and pokemon_filter_params.get("minAtkIv") == 30
		and pokemon_filter_params.get("minSpeedIv") == 29,
		"Filters retain minimum IVs for individual stats"
	)
	_check(
		pokemon_filter_params.get("sortBy") == "price"
		and pokemon_filter_params.get("sortDirection") == "desc",
		"Filters retain listing sort field and direction"
	)
	_check(int(popup.call("_active_advanced_filter_count")) == 12, "Sorting is not counted as an active advanced filter")
	_check(bool(popup.call("_apply_browse_sort_mode", "newest_asc")), "Browse accepts oldest-to-newest sorting")
	var oldest_filter_params := popup.call("_current_browse_filter_params") as Dictionary
	_check(
		oldest_filter_params.get("sortBy") == "newest"
		and oldest_filter_params.get("sortDirection") == "asc",
		"Oldest-first maps to ascending listing date sorting"
	)
	_check(bool(popup.call("_apply_browse_sort_mode", "level_desc")), "Pokémon browse accepts highest-level-first sorting")
	popup.set("browse_filters", {
		"item": popup.call("_default_browse_filter_state", "item"),
		"pokemon": popup.call("_default_browse_filter_state", "pokemon"),
	})
	popup.set("asset_filter", "item")
	popup.call("_hide_advanced_filter_panel")
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
	var sell_detail_stack := popup.get("detail_stack") as VBoxContainer
	var item_header := sell_detail_stack.get_child(0) as PanelContainer
	var item_detail_icon := item_header.find_child("ItemDetailIcon", true, false) as TextureRect
	_check(item_header.get_theme_stylebox("panel") is StyleBoxFlat, "Item details use a compact information header")
	_check(item_detail_icon != null and item_detail_icon.size == Vector2(48, 48), "Item details preserve the native 48-pixel artwork size")
	_check(item_detail_icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Item details render pixel art without smoothing")
	_check(popup.get("quantity_spin") is SpinBox, "Item listings expose quantity input")
	_check(popup.get("price_spin") is SpinBox, "Listings expose fixed-price input")
	var sellable_garchomp := {
		"pokemonId": 25,
		"species": "garchomp",
		"speciesId": "Garchomp",
		"speciesName": "garchomp",
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
			{"id": "ceaseless-edge", "name": "Ceaseless Edge", "type": "dark", "pp": 15, "maxPp": 15},
			{"id": "razor-shell", "name": "Razor Shell", "type": "water", "pp": 10, "maxPp": 10},
			{"id": "flip-turn", "name": "Flip Turn", "type": "water", "pp": 20, "maxPp": 20},
			{"id": "knock-off", "name": "Knock Off", "type": "dark", "pp": 20, "maxPp": 20},
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
	var current_detail_stack := popup.get("detail_stack") as VBoxContainer
	var purchase_header := current_detail_stack.get_child(0) as PanelContainer
	var quick_summary := current_detail_stack.get_child(1) as PanelContainer
	_check(purchase_header != null, "Pokémon identity and Summary action share a compact header")
	_check(quick_summary != null, "Selected Pokémon renders a compact purchase summary")
	_check(_count_meta_controls(purchase_header, "exchange_type_chip") == 2, "Pokémon header renders both types as styled chips")
	_check(_count_meta_controls(quick_summary, "exchange_move_chip") == 4, "Pokémon summary renders four styled move chips")
	_check(summary_button.get_theme_stylebox("normal") is StyleBoxFlat, "Pokémon Summary action uses Exchange styling")
	popup.pokemon_summary_requested.connect(_capture_summary_payload)
	summary_button.pressed.emit()
	_check(str(requested_summary_payload.get("species", "")) == "garchomp", "Summary payload includes the factory species identifier")
	_check(_array(requested_summary_payload.get("moves", [])).size() == 4, "Summary payload preserves the listed Pokémon's moves")
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
		var browse_asset := sellable_garchomp.duplicate(true) if index == 0 else {
			"pokemonId": 100 + index,
			"species": "bulbasaur",
			"speciesName": "Bulbasaur",
			"level": 12,
		}
		var browse_asset_type := "pokemon"
		if index == 3:
			browse_asset_type = "item"
			browse_asset = {
				"itemId": "air-balloon",
				"name": "Air Balloon",
				"shortDesc": "A useful held item.",
			}
		browse_entries.append({
			"id": "browse-%d" % index,
			"assetType": browse_asset_type,
			"asset": browse_asset,
			"quantity": 1,
			"totalPrice": 5000 + index,
			"status": "active",
		})
	popup.set("active_tab", "browse")
	popup.set("browse_listings", browse_entries)
	popup.call("_render_current_list")
	await process_frame
	await process_frame
	_check(popup.size == Vector2(1040, 660), "Browse cards do not resize the Exchange popup")
	_check(list_container.columns == 4, "Browse listings render four portrait cards per row")
	_check(list_container.get_child_count() == 4, "Browse grid renders every available listing")
	var first_browse_card := list_container.get_child(0) as Button
	_check(first_browse_card.custom_minimum_size.y == 172.0, "Browse cards use the portrait listing height")
	_check(first_browse_card.size.y > first_browse_card.size.x, "Pokémon browse cards are taller than they are wide")
	_check((list_container.get_child(3) as Button).size.y > (list_container.get_child(3) as Button).size.x, "Item browse cards are taller than they are wide")
	var available_label := str(popup.call("_t", "ui.exchange.state.active"))
	for card_index: int in [0, 3]:
		var card_text := ""
		for label_value: Variant in (list_container.get_child(card_index) as Button).find_children("*", "Label", true, false):
			card_text += (label_value as Label).text
		_check(not card_text.contains(available_label), "Browse cards omit the redundant Available status")
	popup.set("wallet_money", 1_000_000)
	popup.call("_select_entry", browse_entries[0], "listing")
	await process_frame
	await process_frame
	var detail_scroll := popup.find_child("ExchangeDetailScroll", true, false) as ScrollContainer
	current_detail_stack = popup.get("detail_stack") as VBoxContainer
	var purchase_footer := current_detail_stack.get_child(current_detail_stack.get_child_count() - 1) as PanelContainer
	var footer_content := purchase_footer.get_child(0) as VBoxContainer
	var buy_button := footer_content.get_child(footer_content.get_child_count() - 1) as Button
	_check(buy_button != null and buy_button.visible, "Browse keeps Buy Now visible with a complete Pokémon summary")
	_check(purchase_footer.get_theme_stylebox("panel") is StyleBoxFlat, "Price and purchase action share a styled footer")
	_check(not detail_scroll.get_v_scroll_bar().visible, "Complete Pokémon purchase details fit without vertical scrolling")
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
	var service_source := FileAccess.get_file_as_string(EXCHANGE_SERVICE_PATH)
	var popup_source := FileAccess.get_file_as_string(EXCHANGE_POPUP_PATH)
	var overlay_source := FileAccess.get_file_as_string(UI_OVERLAY_PATH)
	_check(project_source.contains('AetherExchangeService="*res://scripts/services/aether_exchange_service.gd"'), "Exchange API client is an autoload")
	_check(overlay_source.contains("aether_exchange_popup.open_exchange()"), "Existing Exchange navigation opens the live popup")
	_check(overlay_source.contains("pokemon_summary_requested.connect(_on_aether_exchange_pokemon_summary_requested)"), "Exchange Summary actions are connected to the UI overlay")
	_check(overlay_source.contains("_open_readonly_pokemon_summary(pokemon_payload)"), "Exchange opens the existing read-only Pokémon Summary")
	_check(not overlay_source.contains("Aether Exchange is not implemented yet."), "Coming-soon behavior was removed")
	_check(popup_source.contains("func _load_portfolio() -> bool:"), "Portfolio loads report whether they succeeded")
	_check(popup_source.contains("func _load_browse() -> bool:"), "Browse loads report whether they succeeded")
	_check(service_source.contains('"minPrice", "maxPrice", "itemCategory", "minLevel", "maxLevel"'), "Exchange API client forwards advanced market filters")
	_check(service_source.contains('"minHpIv", "minAtkIv", "minDefIv", "minSpAtkIv", "minSpDefIv", "minSpeedIv"'), "Exchange API client forwards per-stat IV filters")
	_check(service_source.contains('"type", "primaryType", "secondaryType"'), "Exchange API client forwards primary and secondary type filters")
	_check(service_source.contains('"sortBy", "sortDirection"'), "Exchange API client forwards server-side sorting")
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


func _count_meta_controls(root_node: Node, meta_key: String) -> int:
	var count := 1 if root_node.has_meta(meta_key) else 0
	for child: Node in root_node.get_children():
		count += _count_meta_controls(child, meta_key)
	return count


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return value as Array if value is Array else []
