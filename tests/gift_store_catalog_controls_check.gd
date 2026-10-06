extends SceneTree

const STORE_SCENE := preload("res://scenes/interface/donator_store_popup.tscn")
var failed := false

func _init() -> void:
	call_deferred("_run")

func _choose(store: DonatorStorePopup, kind: String, value: String) -> void:
	var select: OptionButton = store.catalog_filter_select if kind == "filter" else store.catalog_sort_select
	for index in range(select.item_count):
		if str(select.get_item_metadata(index)) == value:
			select.select(index)
			select.item_selected.emit(index)
			return

func _run() -> void:
	var store := STORE_SCENE.instantiate() as DonatorStorePopup
	root.add_child(store)
	await process_frame
	root.get_node("LocalizationManager").set_locale("en")
	store.call("_select_category", "cosmetics")
	store.call("_select_cosmetic_filter_group", "all")
	_choose(store, "filter", "gems_affordable")
	_check(store.product_buttons.is_empty(), "Affordability waits for authoritative catalog")
	store.apply_store_state({"gems": 100, "gift_voucher_balance": 75}, {"items": [
		{"itemId": "adinho-chroma-hair", "voucherEligible": true, "costs": [{"currency": "gems", "amount": 90}]},
		{"itemId": "adinho-chroma-shoes", "voucherEligible": true, "costs": [{"currency": "gems", "amount": 75}]},
		{"itemId": "adinho-chroma-shirt", "voucherEligible": false, "costs": [{"currency": "gems", "amount": 125}]},
	]})
	_check(store.product_buttons.size() == 2, "Gem affordability uses server prices and balance")
	store.call("_select_product", "adinho-chroma-hair")
	_choose(store, "sort", "price_desc")
	_check(store.product_buttons.keys() == ["adinho-chroma-hair", "adinho-chroma-shoes"], "Descending prices use server values")
	_check(store.selected_item_id == "adinho-chroma-hair", "Sorting preserves selection")
	_choose(store, "sort", "price_asc")
	_check(store.product_buttons.keys() == ["adinho-chroma-shoes", "adinho-chroma-hair"], "Ascending prices use server values")
	_choose(store, "filter", "voucher_affordable")
	_check(store.product_buttons.keys() == ["adinho-chroma-shoes"], "Voucher affordability uses separate balance and eligibility")
	_check(store.selected_item_id == "", "Filtering clears hidden selection")
	store.set_voucher_balance(90)
	_check(store.product_buttons.size() == 2, "Balance updates refresh filtered products")
	_choose(store, "filter", "voucher_eligible")
	store.call("_on_catalog_search_changed", "shoes")
	_check(store.product_buttons.keys() == ["adinho-chroma-shoes"], "Search combines with filter and sorting")
	store.call("_on_catalog_search_changed", "")
	_choose(store, "filter", "all")
	_choose(store, "sort", "price_desc")
	_check(store.product_buttons.keys()[0] == "adinho-chroma-shirt", "Unknown prices sort after available prices even descending")
	_choose(store, "sort", "name")
	var names: Array[String] = []
	for id: String in store.product_buttons:
		names.append(store.call("_item_name", store.call("_catalog_item", id)))
	for index in range(1, names.size()):
		_check(names[index - 1].naturalnocasecmp_to(names[index]) <= 0, "Names sort alphabetically")
	for locale in ["en", "nl", "pt_BR", "zh_CN"]:
		root.get_node("LocalizationManager").set_locale(locale)
		_check(not store.catalog_filter_select.get_item_text(0).begins_with("ui.store."), "Filter localized: " + locale)
		_check(store.active_catalog_sort == "name", "Locale change preserves sorting")
	store.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL " + message)
