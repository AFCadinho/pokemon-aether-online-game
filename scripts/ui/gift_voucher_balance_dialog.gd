extends AetherConfirmationDialog

class_name GiftVoucherBalanceDialog

var _refresh_generation := 0


func open_balance() -> void:
	_refresh_generation += 1
	var generation := _refresh_generation
	configure(
		get_node("/root/ItemLocalization").display_name("aether-gift-voucher", "Aether Credit Card"),
		get_node("/root/LocalizationManager").text("ui.voucher.loading"),
		get_node("/root/LocalizationManager").text("common.close"),
		get_node("/root/LocalizationManager").text("common.close")
	)
	cancel_button.hide()
	configure_option("")
	popup_centered(Vector2i(520, 270))
	var result: Dictionary = await _load_wallet()
	if generation != _refresh_generation or not visible:
		return
	if not bool(result.get("success", false)):
		message_label.text = get_node("/root/LocalizationManager").text("ui.voucher.load_failed")
		return
	get_node("/root/PlayerWalletService").apply_wallet_result(result)
	var wallet := result.get("wallet", {}) as Dictionary
	message_label.text = get_node("/root/LocalizationManager").text("ui.voucher.balance", {
		"balance": str(maxi(int(wallet.get("gift_voucher_balance", 0)), 0)),
	})


func _load_wallet() -> Dictionary:
	return await get_node("/root/PlayerWalletService").load_wallet()
