extends SceneTree

const STORE_SCENE := preload("res://scenes/interface/donator_store_popup.tscn")
var failed := false

func _init() -> void:
	call_deferred("_run")

func _settle() -> void:
	for frame in range(5):
		await process_frame

func _run() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 900)
	root.add_child(host)
	var store := STORE_SCENE.instantiate() as DonatorStorePopup
	host.add_child(store)
	store.show()
	await _settle()
	var baseline := store.get_rect()
	_check(baseline.size == Vector2(1120, 680), "Store starts at its intended size")
	var localization := root.get_node("LocalizationManager")
	for locale in ["en", "nl", "pt_BR", "zh_CN"]:
		localization.set_locale(locale)
		for category in store.CATEGORY_ORDER:
			store.call("_select_category", category)
			await _settle()
			_check(store.get_rect() == baseline, "Stable size and position: " + locale + " / " + category)
		for select: OptionButton in [store.catalog_filter_select, store.catalog_sort_select]:
			for index in range(select.item_count):
				select.select(index)
				select.item_selected.emit(index)
				await _settle()
				_check(store.get_rect() == baseline, "Catalog controls preserve size: " + locale + " / " + str(select.get_item_metadata(index)))
				_check(store.get_global_rect().encloses(select.get_global_rect()), "Catalog control fits the window")
			select.select(0)
			select.item_selected.emit(0)
	for item: Dictionary in store.CATALOG:
		store.call("_select_product", str(item.id))
		await _settle()
		_check(store.get_rect() == baseline, "Stable size for product " + str(item.id))
	localization.set_locale("en")
	store.call("_select_category", "cosmetics")
	store.call("_select_product", "adinho-chroma-hair")
	store.payment_select.select(1)
	store.call("_refresh_purchase_state")
	store.selection_description_label.text = "Long product details with wrapped text. ".repeat(100)
	store.status_label.text = "A lengthy checkout status message. ".repeat(10)
	await _settle()
	_check(store.get_rect() == baseline, "Long descriptions and checkout messages cannot resize the window")
	var scroll := store.find_child("ProductDetailsScroll", true, false) as ScrollContainer
	_check(scroll.get_v_scroll_bar().max_value > scroll.size.y, "Long item details can be scrolled")
	var purchase_rect := store.purchase_button.get_global_rect()
	_check(store.get_global_rect().encloses(purchase_rect) and not scroll.is_ancestor_of(store.purchase_button), "Checkout stays visible outside the scrolling details")
	host.size = Vector2(800, 600)
	await _settle()
	_check(store.size == baseline.size, "Small screens preserve the logical window size")
	var footprint := Rect2(store.position, store.size * store.scale)
	_check(Rect2(Vector2.ZERO, host.size).encloses(footprint), "Scaled store fits the smaller screen")
	host.size = Vector2(1280, 900)
	await _settle()
	_check(store.get_rect() == baseline and store.scale == Vector2.ONE, "Screen resize restores the original centered layout")
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280, 900)
		store.call("_select_product", "adinho-chroma-hair")
		store.set_voucher_balance(1000)
		scroll.scroll_vertical = 0
		await _settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/home/adinho/Desktop/pokemonaetheronline/game/.worktrees/slot-b/gift-store-layout.png")
	host.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL " + message)
