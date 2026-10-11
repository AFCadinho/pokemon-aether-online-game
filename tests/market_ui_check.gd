extends SceneTree

const UI_OVERLAY_SCRIPT := "res://scripts/ui/ui_overlay.gd"
const MARKET_ATTENDANT_SCRIPT := "res://scripts/world/npcs/market_attendant_npc.gd"

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_market_popup_contract()
	_check_market_attendant_uses_ui()
	_check_shop_description_presentation()
	quit(1 if failed else 0)


func _check_market_popup_contract() -> void:
	var text := _read_text(UI_OVERLAY_SCRIPT)
	_check_true(text.contains("var market_popup: PanelContainer"), "UIOverlay tracks market popup")
	_check_true(text.contains("_setup_market_popup()"), "UIOverlay sets up market popup")
	_check_true(text.contains('func open_market(market: Dictionary, requested_mode: String = "player_buys"'), "UIOverlay exposes mode-aware open_market")
	_check_true(text.contains("func _apply_market_item_row_style"), "UIOverlay styles market item rows")
	_check_true(text.contains("func _is_market_item_row_disabled") and text.contains('market_mode != "player_sells" and bool(item.get("owned", false))'), "UIOverlay treats owned buy rows as disabled catalog options")
	_check_true(text.contains("Control.MOUSE_FILTER_IGNORE if disabled") and text.contains("UI_MUTED_TEXT if disabled else UI_MONEY"), "Owned catalog rows are non-interactive and visually muted")
	_check_true(text.contains("func _market_item_subtitle"), "UIOverlay shows market item subtitles")
	_check_true(text.contains("func _refresh_market_detail"), "UIOverlay refreshes selected item details")
	_check_true(text.contains("func _on_market_search_changed"), "UIOverlay supports catalog search")
	_check_true(text.contains('"ui.market.money"'), "UIOverlay localizes the market money label")
	_check_true(text.contains("MarketService.purchase_item("), "UIOverlay purchases from its active named market")
	_check_true(text.contains('market_context.get("id", "standard_pokemart")'), "UIOverlay preserves the active market id during purchase")
	_check_true(text.contains("MarketService.sell_standard_item(item_id, quantity)"), "UIOverlay sells through MarketService")
	_check_true(
		text.contains('LocalizationManager.text("ui.market.confirm_sale_title")')
		and text.contains('Callable(self, "_submit_market_transaction").bind(selected_item, quantity)'),
		"Item Buyer requires confirmation before submitting a sale"
	)
	_check_true(text.contains('market_mode == "player_sells"'), "UIOverlay supports the player-sells mode")
	_check_true(text.contains("for inventory_value: Variant in inventory_items:"), "Market buyer builds its catalog from the player's inventory")
	_check_true(text.contains('inventory_item.get("tradable"'), "Market buyer filters inventory by server-authoritative tradeability")
	_check_true(text.contains('inventory_item.get(\n\t\t\t"sellPrice"'), "Market buyer uses the server-authoritative item sale price")
	_check_true(text.contains("PlayerWalletService.apply_wallet_result(result)"), "UIOverlay applies wallet updates")
	_check_true(text.contains('market_selected_item.get("owned", false)'), "UIOverlay disables purchases for owned account-unique items")
	_check_true(text.contains('"canonicalItemId": canonical_item_id') and text.contains('"ownershipVariant"'), "Market and Bag preserve hidden Mega Stone provenance")
	_check_true(text.contains("func _group_mega_stone_bag_items") and text.contains('ui.bag.mega_marker.both'), "Bag groups bound and tradeable Mega Stones without combining them into x2")
	_check_true(text.contains("_market_item_max_purchase_quantity"), "UIOverlay enforces server-provided purchase quantity caps")
	_check_true(text.contains("_mark_market_item_owned(item_id)"), "UIOverlay marks a unique item owned after purchase")
	_check_true(text.contains('"ui.market.account_bound"'), "UIOverlay labels account-bound catalog items")
	_check_true(text.contains("_track_movement_blocking_ui_panel(panel)"), "modal UI windows block overworld movement")
	_check_true(text.contains("_untrack_movement_blocking_ui_panel(panel)"), "closing the last modal restores overworld movement")
	_check_true(text.contains("bag_inventory_items = _normalize_bag_inventory_items(inventory_value)"), "UIOverlay refreshes bag inventory")
	_check_true(text.contains('"ui.market.status.not_enough_money"'), "UIOverlay localizes insufficient-money feedback")
	_check_true(
		text.contains('"ui.market.message.sold" if player_is_selling else "ui.market.message.bought"'),
		"UIOverlay posts localized role-aware transaction feedback"
	)
	_check_true(
		text.contains('transaction.get("totalPrice", 0)')
		and text.contains('transaction.get("currency", "money")')
		and text.contains("add_system_message(_market_currency_spent_message("),
		"successful NPC purchases report the authoritative wallet deduction"
	)
	_check_true(
		text.contains("add_system_message(_market_currency_received_message(")
		and text.contains("if player_is_selling:"),
		"successful Item Buyer sales report the authoritative wallet credit"
	)
	var sale_branch_index := text.find("\tif player_is_selling:\n\t\tvar received_amount")
	var sale_sound_index := text.find('SfxManager.play("npc_shop_purchase")', sale_branch_index)
	var sale_else_index := text.find("\telse:", sale_branch_index)
	_check_true(
		sale_branch_index >= 0 and sale_sound_index > sale_branch_index and sale_sound_index < sale_else_index,
		"successful Item Buyer sales play the NPC shop sound"
	)


func _check_market_attendant_uses_ui() -> void:
	var text := _read_text(MARKET_ATTENDANT_SCRIPT)
	_check_true(text.contains('ui_overlay.call("open_market", market, market_mode, inventory_items)'), "Market attendant opens the selected market mode")


func _check_shop_description_presentation() -> void:
	var overlay = load(UI_OVERLAY_SCRIPT).new()
	var host := Control.new()
	root.add_child(host)
	overlay.root_control = host
	var item := {
		"itemId": "auspicious-armor", "name": "Auspicious Armor", "category": "misc",
		"shortDesc": "Use to evolve: Charcadet → Armarouge. Consumed only on successful evolution.",
		"flavorText": "An old set of golden armor, treasured for its fine craftsmanship.",
		"costs": [{"currency": "money", "amount": 100000}],
	}
	var empty_catalog: Array[Dictionary] = []
	var localization := root.get_node("ItemLocalization")
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		root.get_node("LocalizationManager").set_locale(locale)
		var catalog: Dictionary = localization.get_catalog(locale)
		var expected := str(catalog["auspicious-armor"]["flavorText"])
		overlay.open_market({"id": "evolution_item_shop", "items": [item]})
		_check_true(overlay.market_detail_description_label.text == expected, locale + " shop detail uses the general description")
		_check_true(not expected.contains("Armarouge"), locale + " general description does not give an evolution recipe")
		_check_true(str(overlay.market_selected_item["shortDesc"]).contains("Armarouge"), locale + " evolution instructions remain in the item summary")
		for row: Node in overlay.market_item_list.get_children():
			if not row.is_queued_for_deletion():
				_check_true(row.tooltip_text == expected, locale + " shop tooltip uses the same description")
		var sold: Array = overlay._market_sell_items(empty_catalog, [{"itemId": "auspicious-armor", "quantity": 1, "tradable": true, "sellPrice": 1000}])
		_check_true(sold.size() == 1 and overlay._market_item_description(sold[0]) == expected, locale + " Item Buyer also uses the general description")
		for item_id: Variant in catalog:
			if (catalog[item_id] as Dictionary).has("flavorText"):
				_check_true(not localization.shop_description({"id": item_id}).is_empty(), locale + " localizes general item description: " + str(item_id))
		overlay._hide_market_popup()
	root.get_node("LocalizationManager").set_locale("en")
	_check_true(localization.shop_description({"id": "unknown-item", "shortDesc": "Fallback summary"}) == "Fallback summary", "items without general text retain their summary")
	_check_true(localization.shop_description({"id": "unknown-item", "flavorText": "Server general description"}) == "Server general description", "English accepts a server-provided general description")
	_check_true(localization.short_description("auspicious-armor").contains("Armarouge"), "Bag and Item Dex retain the evolution explanation")
	host.free()
	overlay.free()
	print("PASS shop general descriptions, evolution summaries and four locales")


func _read_text(path: String) -> String:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _check_true(condition: bool, message: String) -> void:
	if condition:
		return

	failed = true
	push_error("FAIL %s" % message)
