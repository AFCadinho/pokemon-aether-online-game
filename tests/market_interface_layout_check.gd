extends SceneTree

const UI_OVERLAY_SCRIPT := "res://scripts/ui/ui_overlay.gd"
const MARKET_ICON := "res://assets/ui/market_shop.svg"

var failed := false


func _init() -> void:
	var text := _read_text(UI_OVERLAY_SCRIPT)

	_check_true(text.contains("const MARKET_SIZE := Vector2(930, 610)"), "market uses a dedicated workspace size")
	_check_true(text.contains("MARKET_INTERFACE_ICON"), "market uses a dedicated shop icon")
	_check_true(FileAccess.file_exists(MARKET_ICON), "market shop icon exists")
	_check_true(text.contains("MarketWorkspace"), "market separates catalog and purchase workspace")
	_check_true(text.contains("CatalogPanel"), "market exposes a catalog panel")
	_check_true(text.contains("PurchasePanel"), "market exposes a purchase panel")
	_check_true(text.contains('"ui.market.search.buy"'), "market catalog has localized search")
	_check_true(text.contains("func _filtered_market_items()"), "market filters its catalog")
	_check_true(text.contains("_load_item_icon(item_id)"), "market rows use real item icons")
	_check_true(text.contains("SelectedItemPreview"), "market shows a selected item preview")
	_check_true(text.contains('"ui.market.unit_price"'), "market distinguishes the localized unit price")
	_check_true(text.contains("market_total_price_label"), "market shows the purchase total")
	_check_true(text.contains('"ui.market.delivery.buy"'), "market explains item delivery with localized copy")
	_check_true(text.contains("market_buy_button.focus_mode = Control.FOCUS_NONE"), "market purchase button cannot capture Space")
	_check_true(text.contains("_activate_ui_panel(market_popup)"), "market opens above the base overlay")

	quit(1 if failed else 0)


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
