extends SceneTree

const DIALOG_SCENE := preload("res://scenes/interface/gift_voucher_balance_dialog.tscn")
var failed := false

class FakeDialog extends GiftVoucherBalanceDialog:
	signal release_request
	var response := {"success": true, "wallet": {"gift_voucher_balance": 1234}}
	var requests := 0
	var delay := false
	func _load_wallet() -> Dictionary:
		requests += 1
		var snapshot := response.duplicate(true)
		if delay:
			await release_request
		return snapshot

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var localization := root.get_node("LocalizationManager")
	localization.set_locale("en")
	var overlay_script := load("res://scripts/ui/ui_overlay.gd") as GDScript
	var overlay = overlay_script.new()
	var item := {"id": "aether-gift-voucher", "useAction": "open_gift_voucher", "quantity": 1}
	_check(overlay._bag_item_can_use_from_bag(item), "Voucher is usable from Bag")
	_check(overlay._bag_item_can_assign_to_hotbar(item), "Voucher can be assigned to hotbar")
	_check(overlay._bag_item_use_action_label(item) == "View balance", "Bag action names the balance dialog")
	var topup := {"id": "aether-credit-voucher-100", "useAction": "redeem_credit_voucher", "quantity": 1}
	_check(overlay._bag_item_can_use_from_bag(topup), "Credit Voucher can be claimed from Bag")
	_check(overlay._bag_item_use_action_label(topup) == localization.text("ui.bag.action.redeem_voucher"), "Credit Voucher action describes redemption")
	var dialog := DIALOG_SCENE.instantiate()
	dialog.set_script(FakeDialog)
	var host := Control.new()
	root.add_child(host)
	host.add_child(dialog)
	overlay.root_control = host
	overlay.gift_voucher_balance_dialog = dialog
	await process_frame
	await dialog.open_balance()
	_check(dialog.visible and dialog.message_label.text.contains("1234"), "Opening displays current server balance")
	_check(dialog.message_label.text.contains("all box contents"), "Dialog explains binding of box contents")
	_check(not dialog.cancel_button.visible, "Balance dialog has a single Close action")
	dialog.response = {"success": true, "wallet": {"gift_voucher_balance": 0}}
	await dialog.open_balance()
	_check(dialog.requests == 2 and dialog.message_label.text.contains("credit: 0"), "Reopening fetches current zero balance")
	dialog.response = {"success": false, "error": "offline"}
	await dialog.open_balance()
	_check(dialog.message_label.text.contains("Could not load"), "Fetch failure does not display a stale balance")
	dialog.delay = true
	dialog.response = {"success": true, "wallet": {"gift_voucher_balance": 12}}
	dialog.open_balance()
	_check(dialog.message_label.text.contains("Loading"), "Loading hides the previous balance")
	dialog.hide_dialog()
	dialog.delay = false
	dialog.response = {"success": true, "wallet": {"gift_voucher_balance": 250}}
	await dialog.open_balance()
	dialog.release_request.emit()
	await process_frame
	_check(dialog.message_label.text.contains("credit: 250"), "A late response cannot overwrite a reopened dialog")
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		localization.set_locale(locale)
		await dialog.open_balance()
		_check(not dialog.message_label.text.begins_with("ui.voucher."), "Balance dialog is localized for " + locale)
	var before: int = dialog.requests
	await overlay._on_bag_item_selected(item)
	_check(dialog.requests == before + 1, "Bag use opens the balance dialog")
	overlay.hotbar_slots = [{"slot": 2, "entryType": "key_item_action", "entryId": "aether-gift-voucher"}]
	overlay._on_hotbar_slot_pressed(2)
	_check(dialog.requests == before + 2, "Third hotbar activation opens the same balance dialog")
	overlay._hide_gift_voucher_balance()
	_check(not dialog.visible, "Closing releases the dialog")
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(800, 520)
		localization.set_locale("nl")
		dialog.response = {"success": true, "wallet": {"gift_voucher_balance": 1000}}
		dialog.accent_icon.texture = overlay._load_item_icon("aether-gift-voucher")
		await dialog.open_balance()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://credit-card-balance-preview.png")
	var source := HotbarBagItemSlot.new()
	source.hotbar_item = item
	root.add_child(source)
	_check(source._get_drag_data(Vector2.ZERO) is Dictionary, "Permanent voucher supports native Bag drag to hotbar")
	overlay.free()
	host.queue_free()
	source.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL " + message)
