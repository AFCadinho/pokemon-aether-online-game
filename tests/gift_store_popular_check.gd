extends SceneTree

const STORE_SCENE := preload("res://scenes/interface/donator_store_popup.tscn")
var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 800)
	root.add_child(host)
	var store := STORE_SCENE.instantiate() as DonatorStorePopup
	host.add_child(store)
	store.show()
	await process_frame
	var localization := root.get_node("LocalizationManager")
	localization.set_locale("en")
	var selected := [
		"adinho-chroma-shoes", "aether-blossom-chroma-hair",
		"glaceon-mount-box", "primal-kyogre-mount-box",
		"aether-blessing-voucher-7-days", "charizard-guild-emblem-template",
	]
	var offers: Array[Dictionary] = []
	for item_id: String in selected:
		var item: Dictionary = store.call("_catalog_item", item_id)
		offers.append({"itemId": item_id, "voucherEligible": true, "costs": [{"currency": "gems", "amount": int(item.get("price", 0))}]})
	for item_id: String in ["thor-outfit", "cobalion-mount-box", "shadow-lugia-mount-box"]:
		var item: Dictionary = store.call("_catalog_item", item_id)
		offers.append({"itemId": item_id, "voucherEligible": true, "costs": [{"currency": "gems", "amount": int(item.get("price", 0))}]})
	# Unknown, unavailable and duplicate server IDs must never create cards.
	var server_ids := selected.duplicate()
	server_ids.insert(0, "unknown-product")
	server_ids.insert(1, "rayquaza-mount-box")
	server_ids.insert(2, selected[0])
	store.apply_store_state({"gems": 100}, {"items": offers, "featured": {
		"itemIds": server_ids, "popularItemIds": [selected[0], selected[2]], "windowDays": 30,
	}})
	store.call("_select_category", "featured")
	_check(store.product_buttons.keys() == selected, "Popular uses the server's varied selection including items without the old Featured tag")
	_check(store.category_buttons["featured"].visible, "Popular is visible when selected offers are available")
	var popular_badge := store.product_buttons[selected[0]].find_child("FeaturedSelectionBadge", true, false) as Label
	var curated_badge := store.product_buttons[selected[1]].find_child("FeaturedSelectionBadge", true, false) as Label
	_check(popular_badge != null and popular_badge.text == "Popular · 30 days", "Ranked products have a popularity badge")
	_check(curated_badge != null and curated_badge.text == "Featured", "Fallback products are labelled Featured")
	store.call("_select_category", "cosmetics")
	store.call("_select_cosmetic_filter_group", "all")
	_check(store.product_buttons.keys().front() == selected[0], "Default Cosmetics order puts the recent bestseller first")
	_check_nonpopular_prices_descending(store, "Default Cosmetics remainder is ordered by highest price")
	store.call("_select_category", "mounts")
	_check(store.product_buttons.keys().front() == selected[2], "Default Mounts order puts the recent bestseller first")
	_check_nonpopular_prices_descending(store, "Default Mounts remainder is ordered by highest price")
	store.call("_select_category", "featured")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			root.size = Vector2i(1280, 800)
			localization.set_locale("nl")
			for frame in range(5):
				await process_frame
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(arg.trim_prefix("--capture="))
			localization.set_locale("en")
	store.call("_on_catalog_search_changed", "Glaceon")
	_check(store.product_buttons.keys() == ["glaceon-mount-box"], "Search applies to popular picks")
	store.call("_on_catalog_search_changed", "")
	store.call("_select_product", selected[0])
	store.apply_store_state({"gems": 100}, {"items": offers, "featured": {
		"itemIds": [selected[2]], "popularItemIds": [],
	}})
	_check(store.product_buttons.keys() == [selected[2]], "Refreshing the server selection clears stale popular cards")
	_check(store.selected_item_id == "", "Removed selections clear checkout")
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		localization.set_locale(locale)
		_check(store.category_buttons["featured"].text == localization.text("ui.store.category.featured.label"), "Popular tab is localized: " + locale)
		_check(store.hero_description_label.text == localization.text("ui.store.category.featured.description"), "Popular description is localized: " + locale)
		_check(store.hero_description_label.tooltip_text == localization.text("ui.store.featured.explanation"), "Popularity explanation is localized: " + locale)
		curated_badge = store.product_buttons[selected[2]].find_child("FeaturedSelectionBadge", true, false) as Label
		_check(curated_badge.text == localization.text("ui.store.featured.curated"), "Featured badge refreshes with locale: " + locale)
	store.apply_store_state({"gems": 100}, {"items": offers, "featured": {"itemIds": [], "popularItemIds": []}})
	_check(store.product_buttons.is_empty(), "An authoritative empty selection does not revive old picks")
	_check(not store.category_buttons["featured"].visible, "Popular hides an empty selection")
	# Older servers can still show the varied, explicitly curated local fallback.
	store.apply_store_state({"gems": 100}, {"items": [
		{"itemId": "mysterious-outfit", "costs": [{"currency": "gems", "amount": 400}]},
		{"itemId": "aether-blossom-outfit", "costs": [{"currency": "gems", "amount": 400}]},
		{"itemId": "rayquaza-mount-box", "costs": [{"currency": "gems", "amount": 1000}]},
		{"itemId": "primal-kyogre-mount-box", "costs": [{"currency": "gems", "amount": 1000}]},
		{"itemId": "aether-blessing-voucher-30-days", "costs": [{"currency": "gems", "amount": 500}]},
		{"itemId": "surf-charm", "costs": [{"currency": "gems", "amount": 350}]},
	]})
	store.call("_select_category", "featured")
	_check(store.product_buttons.size() == 6 and store.popular_item_ids.is_empty(), "Older servers get six varied featured picks without popularity claims")
	store.call("_select_category", "mounts")
	_check(store.product_buttons.has("rayquaza-mount-box") and not store.product_buttons.has("mysterious-outfit"), "Other categories keep their own membership")
	host.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL " + message)


func _check_nonpopular_prices_descending(store: DonatorStorePopup, message: String) -> void:
	var item_ids: Array = store.product_buttons.keys()
	var previous_price := 2147483647
	for index: int in range(1, item_ids.size()):
		var price := int(store.call("_gem_price", str(item_ids[index])))
		if price > previous_price:
			_check(false, message)
			return
		previous_price = price
	_check(true, message)
