extends SceneTree

const UI_OVERLAY_SCRIPT := "res://scripts/ui/ui_overlay.gd"
const MARKET_ATTENDANT_SCRIPT := "res://scripts/world/npcs/market_attendant_npc.gd"

var failed := false


func _init() -> void:
	_check_market_popup_contract()
	_check_market_attendant_uses_ui()

	quit(1 if failed else 0)


func _check_market_popup_contract() -> void:
	var text := _read_text(UI_OVERLAY_SCRIPT)
	_check_true(text.contains("var market_popup: PanelContainer"), "UIOverlay tracks market popup")
	_check_true(text.contains("_setup_market_popup()"), "UIOverlay sets up market popup")
	_check_true(text.contains('func open_market(market: Dictionary, requested_mode: String = "player_buys"'), "UIOverlay exposes mode-aware open_market")
	_check_true(text.contains("func _apply_market_item_row_style"), "UIOverlay styles market item rows")
	_check_true(text.contains("func _market_item_subtitle"), "UIOverlay shows market item subtitles")
	_check_true(text.contains("func _refresh_market_detail"), "UIOverlay refreshes selected item details")
	_check_true(text.contains("func _on_market_search_changed"), "UIOverlay supports catalog search")
	_check_true(text.contains('"ui.market.money"'), "UIOverlay localizes the market money label")
	_check_true(text.contains("MarketService.purchase_item("), "UIOverlay purchases from its active named market")
	_check_true(text.contains('market_context.get("id", "standard_pokemart")'), "UIOverlay preserves the active market id during purchase")
	_check_true(text.contains("MarketService.sell_standard_item(item_id, quantity)"), "UIOverlay sells through MarketService")
	_check_true(text.contains('market_mode == "player_sells"'), "UIOverlay supports the player-sells mode")
	_check_true(text.contains("for inventory_value: Variant in inventory_items:"), "Market buyer builds its catalog from the player's inventory")
	_check_true(text.contains('inventory_item.get("tradable"'), "Market buyer filters inventory by server-authoritative tradeability")
	_check_true(text.contains('inventory_item.get(\n\t\t\t"sellPrice"'), "Market buyer uses the server-authoritative item sale price")
	_check_true(text.contains("PlayerWalletService.apply_wallet_result(result)"), "UIOverlay applies wallet updates")
	_check_true(text.contains("_track_movement_blocking_ui_panel(panel)"), "modal UI windows block overworld movement")
	_check_true(text.contains("_untrack_movement_blocking_ui_panel(panel)"), "closing the last modal restores overworld movement")
	_check_true(text.contains("bag_inventory_items = _normalize_bag_inventory_items(inventory_value)"), "UIOverlay refreshes bag inventory")
	_check_true(text.contains('"ui.market.status.not_enough_money"'), "UIOverlay localizes insufficient-money feedback")
	_check_true(
		text.contains('"ui.market.message.sold" if player_is_selling else "ui.market.message.bought"'),
		"UIOverlay posts localized role-aware transaction feedback"
	)


func _check_market_attendant_uses_ui() -> void:
	var text := _read_text(MARKET_ATTENDANT_SCRIPT)
	_check_true(text.contains('ui_overlay.call("open_market", market, market_mode, inventory_items)'), "Market attendant opens the selected market mode")


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
