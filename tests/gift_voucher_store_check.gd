extends SceneTree

const STORE_SCENE := preload("res://scenes/interface/donator_store_popup.tscn")
var failed := false
var purchases: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var localization_manager := root.get_node("LocalizationManager")
	var item_localization := root.get_node("ItemLocalization")
	localization_manager.set_locale("en")
	var store := STORE_SCENE.instantiate() as DonatorStorePopup
	root.add_child(store)
	await process_frame
	store.purchase_requested.connect(func(item: String, colors: Dictionary, currency: String) -> void:
		purchases.append({"itemId": item, "colors": colors, "currency": currency})
	)
	store.apply_store_state({"gems": 0, "gift_voucher_balance": 250}, {"items": [
		{"itemId": "adinho-chroma-hair", "voucherEligible": true, "costs": [{"currency": "gems", "amount": 100}]},
		{"itemId": "surf-charm", "voucherEligible": true, "costs": [{"currency": "gems", "amount": 350}]},
		{"itemId": "aether-blessing-voucher-3-days", "voucherEligible": true, "costs": [{"currency": "gems", "amount": 75}]},
		{"itemId": "aether-credit-voucher-100", "voucherEligible": false, "costs": [{"currency": "gems", "amount": 100}]},
		{"itemId": "aether-credit-voucher-250", "voucherEligible": false, "costs": [{"currency": "gems", "amount": 250}]},
		{"itemId": "aether-credit-voucher-500", "voucherEligible": false, "costs": [{"currency": "gems", "amount": 500}]},
		{"itemId": "aether-credit-voucher-1000", "voucherEligible": false, "costs": [{"currency": "gems", "amount": 1000}]},
	]})
	_check(store.balance_label.text.contains("Aether Gems"), "Gem balance has an explicit currency name")
	_check(store.voucher_balance_label.text.contains("Card credit: 250"), "Voucher balance is shown separately")
	store.call("_select_product", "adinho-chroma-hair")
	_check(store.purchase_button.disabled, "Gems cannot be silently replaced with vouchers")
	store.payment_select.select(1)
	store.call("_refresh_purchase_state")
	_check(not store.purchase_button.disabled, "Voucher purchase works with zero Gems")
	_check(store.voucher_notice_label.text.contains("all box contents"), "Binding includes box contents")
	_check(store.status_label.text.contains("150"), "Voucher checkout previews its remaining balance")
	store.call("_on_purchase_pressed")
	_check(purchases.is_empty(), "Voucher purchase requires its explicit confirmation")
	_check(store.voucher_confirm_dialog.message_label.text.contains("permanently untradeable"), "Confirmation explains permanent binding")
	store.voucher_confirm_dialog.hide_dialog()
	store.call("_cancel_voucher_purchase")
	_check(purchases.is_empty(), "Canceling confirmation does not spend credit")
	store.call("_on_purchase_pressed")
	store.voucher_confirm_dialog.hide_dialog()
	store.call("_confirm_voucher_purchase")
	_check(purchases.size() == 1 and purchases[0].currency == "gift_voucher", "Confirmed purchase sends the voucher payment method")
	store.set_purchase_in_progress(false)
	store.set_voucher_balance(99)
	_check(store.purchase_button.disabled, "Insufficient voucher credit blocks purchase")
	store.set_voucher_balance(150)
	store.set_gem_balance(1000)
	store.call("_select_product", "surf-charm")
	_check(not store.payment_select.is_item_disabled(1), "Personal charms accept card credit")
	store.call("_select_product", "aether-blessing-voucher-3-days")
	_check(not store.payment_select.is_item_disabled(1), "Blessing vouchers accept card credit")
	store.call("_select_product", "aether-credit-voucher-100")
	_check(store.payment_select.is_item_disabled(1), "Ineligible products disable voucher payment")
	_check(store.payment_select.selected == 0, "Ineligible products select Gems")
	_check(store.voucher_notice_label.text.contains("Requires Aether Gems"), "Ineligible products explain voucher restriction")
	var localized: Dictionary = item_localization.localize_item({
		"id": "adinho-chroma-hair-bound", "canonicalItemId": "adinho-chroma-hair",
		"category": "cosmetics", "shortDesc": "Tradeable cosmetic", "tradable": false,
	})
	_check(str(localized.shortDesc).contains("Cannot be traded"), "Bound Bag descriptions cannot claim an item is tradeable")
	var blessing: Dictionary = item_localization.localize_item({"id": "aether-blessing-voucher-3-days-bound", "canonicalItemId": "aether-blessing-voucher-3-days", "category": "vouchers"})
	_check(str(blessing.shortDesc).contains("activate") and str(blessing.shortDesc).contains("Cannot be traded"), "Bound Blessing can be kept for later activation")
	var key: Dictionary = item_localization.localize_item({"id": "aether-gift-voucher", "voucherBalance": 150.0})
	_check(str(key.shortDesc).contains("150") and not str(key.shortDesc).contains("150.0"), "Key Item displays whole voucher credit without JSON decimals")
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		localization_manager.set_locale(locale)
		await process_frame
		_check(localization_manager.text("ui.store.voucher.binding") != "ui.store.voucher.binding", "Voucher binding is localized for " + locale)
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280, 900)
		localization_manager.set_locale("en")
		store.visible = true
		store.set_voucher_balance(1000)
		store.set_gem_balance(0)
		store.call("_select_category", "cosmetics")
		store.call("_select_product", "adinho-chroma-hair")
		store.payment_select.select(1)
		store.call("_refresh_purchase_state")
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://credit-card-store-preview.png")
		store.set_gem_balance(1000)
		store.call("_select_category", "credits")
		store.call("_select_product", "aether-credit-voucher-250")
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://credit-vouchers-store-preview.png")
	store.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL " + message)
