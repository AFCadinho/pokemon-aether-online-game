extends SceneTree

const STORE_SCENE := preload("res://scenes/interface/donator_store_popup.tscn")
var failed := false


func _init() -> void:
	_run.call_deferred()


func _choose(store: DonatorStorePopup, kind: String, value: String) -> void:
	var select: OptionButton = store.catalog_filter_select if kind == "filter" else store.catalog_sort_select
	for index in range(select.item_count):
		if str(select.get_item_metadata(index)) == value:
			select.select(index)
			select.item_selected.emit(index)
			return


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var host := Control.new()
	host.size = Vector2(1280, 800)
	root.add_child(host)
	var store := STORE_SCENE.instantiate() as DonatorStorePopup
	host.add_child(store)
	store.show()
	await process_frame
	root.get_node("LocalizationManager").set_locale("en")
	var items: Array = []
	for item: Dictionary in store.CATALOG:
		if item.has("price"):
			items.append({"itemId": item.id, "voucherEligible": false, "costs": [{"currency": "gems", "amount": item.price}]})
	store.apply_store_state({"gems": 350}, {"items": items})
	store._select_category("guilds")
	_check(store.guild_subcategory_bar.visible and store.guild_subcategory_buttons.emblems.button_pressed, "Guilds opens on Emblems")
	_check(store.product_buttons.size() == 6, "All six emblems are shown")
	_check(not store.product_buttons.has("guild-room-1-template"), "Room templates are excluded from Emblems")
	store._select_product("squirtle-guild-emblem-template")
	store.catalog_search_input.text = "squirtle"
	store.catalog_search_input.text_changed.emit("squirtle")
	_check(store.product_buttons.size() == 1, "Emblem search narrows the active tab")
	store.guild_subcategory_buttons.rooms.pressed.emit()
	_check(store.selected_item_id.is_empty() and store.catalog_search_input.text.is_empty(), "Switching tabs clears stale selection and search")
	_check(store.product_buttons.size() == 2 and store.product_buttons.has("guild-room-1-template") and store.product_buttons.has("guild-room-2-template"), "Rooms contains exactly the two room templates")
	_check(not store.room_preview_button.visible, "Previous preview is cleared until a new selection")
	store._select_product("guild-room-1-template")
	_check(store.room_preview_button.visible and not store.purchase_button.disabled, "Room preview and purchase still work")
	_check(store._gem_price("guild-room-1-template") == 350, "Room price stays 350 Gems")
	_choose(store, "sort", "name")
	_check(store.product_buttons.size() == 2 and store.selected_item_id == "guild-room-1-template", "Sorting preserves room products and selection")
	var names: Array[String] = []
	for id: String in store.product_buttons:
		names.append(store._item_name(store._catalog_item(id)))
	_check(names[0].naturalnocasecmp_to(names[1]) <= 0, "Rooms sort by localized name")
	store.catalog_search_input.text = "squirtle"
	store.catalog_search_input.text_changed.emit("squirtle")
	_check(store.product_buttons.is_empty() and store.selected_item_id.is_empty(), "Room search cannot leak emblems or keep a hidden selection")
	store.catalog_search_input.text = ""
	store.catalog_search_input.text_changed.emit("")
	store.set_gem_balance(349)
	_choose(store, "filter", "gems_affordable")
	_check(store.product_buttons.is_empty(), "Affordability filters within Rooms using server prices")
	store.guild_subcategory_buttons.emblems.pressed.emit()
	_check(store.product_buttons.size() == 6 and store.active_catalog_sort == "name", "Tabs retain filter and sort settings")
	store.guild_subcategory_buttons.rooms.pressed.emit()
	store.set_gem_balance(350)
	_check(store.product_buttons.size() == 2, "Balance refresh retains the selected room tab")
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		root.get_node("LocalizationManager").set_locale(locale)
		for button: Button in store.guild_subcategory_buttons.values():
			_check(not button.text.begins_with("ui."), "Guild tab translation: " + locale)
		_check(store.active_guild_subcategory == "rooms" and store.product_buttons.size() == 2, "Locale refresh keeps Rooms selected")
		for frame in range(3):
			await process_frame
		_check(store.get_global_rect().encloses(store.guild_subcategory_bar.get_global_rect()), "Guild tabs fit the Store: " + locale)
	store._select_category("cosmetics")
	_check(not store.guild_subcategory_bar.visible, "Guild tabs hide outside Guilds")
	store._select_category("guilds")
	_check(store.active_guild_subcategory == "rooms" and store.product_buttons.size() == 2, "Returning to Guilds remembers the selected tab")
	root.get_node("LocalizationManager").set_locale("en")
	store._select_product("guild-room-2-template")
	for frame in range(5):
		await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(arg.trim_prefix("--capture="))
	host.queue_free()
	await process_frame
	print("Gift Store Guild tabs: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
