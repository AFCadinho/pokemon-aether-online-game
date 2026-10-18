extends CanvasLayer

signal finished
const DIALOG := preload("res://scenes/interface/aether_confirmation_dialog.tscn")
var service: Node
var dialog: Control
var choice: OptionButton
var balance: Label
var status_label: Label
var offers: Array = []
var wallet: Dictionary = {}
var busy := false
var unit_price := 100

func _ready() -> void:
	layer = 130
	if service == null:
		service = get_node("/root/PlayerWalletService")
	dialog = DIALOG.instantiate()
	add_child(dialog)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	balance = Label.new()
	balance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(balance)
	choice = OptionButton.new()
	choice.custom_minimum_size.y = 40
	content.add_child(choice)
	choice.item_selected.connect(func(_index): _set_busy(false))
	dialog.style_option_button(choice)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status_label)
	dialog.add_custom_control(content)
	dialog.confirmed.connect(_buy)
	dialog.canceled.connect(_cancel)
	_refresh_text()
	dialog.popup_centered(Vector2i(560, 380))
	_load_catalog()

func _t(key: String, values: Dictionary = {}) -> String:
	return get_node("/root/LocalizationManager").text("ui.casino." + key, values)

func _refresh_text() -> void:
	dialog.configure(_t("title"), _t("description", {"price": unit_price}), _t("buy"), _t("close"))
	balance.text = _t("balance", {"money": int(wallet.get("money", 0)), "tokens": int(wallet.get("casino_tokens", 0))})

func _set_busy(value: bool) -> void:
	busy = value
	choice.disabled = value or not service.casino_pending_purchase.is_empty()
	var unaffordable := false
	if not offers.is_empty() and choice.selected >= 0 and service.casino_pending_purchase.is_empty():
		unaffordable = int(offers[choice.selected].moneyCost) > int(wallet.get("money", 0))
	dialog.confirm_button.disabled = value or offers.is_empty() or unaffordable
	dialog.confirm_button.tooltip_text = get_node("/root/LocalizationManager").text("backend.error.not_enough_money") if unaffordable else ""
	dialog.cancel_button.disabled = value
	dialog.close_button.disabled = value

func _load_catalog() -> void:
	_set_busy(true)
	status_label.text = _t("loading")
	var result: Dictionary = await service.load_casino_tokens()
	if not bool(result.get("success", false)):
		offers.clear()
		choice.clear()
		status_label.text = str(result.get("error", _t("load_failed")))
		_set_busy(false)
		return
	offers = result.offers
	wallet = result.wallet
	unit_price = int(result.unitPrice)
	choice.clear()
	for offer: Dictionary in offers:
		choice.add_item(_t("bundle", {"tokens": int(offer.tokenAmount), "money": int(offer.moneyCost)}))
		if not service.casino_pending_purchase.is_empty() and int(service.casino_pending_purchase.tokenAmount) == int(offer.tokenAmount):
			choice.select(choice.item_count - 1)
	status_label.text = _t("retry") if not service.casino_pending_purchase.is_empty() else _t("bound")
	_refresh_text()
	_set_busy(false)

func _buy() -> void:
	# Confirmation dialogs hide before emitting; keep this counter open during checkout.
	dialog.popup_centered(Vector2i(560, 380))
	if busy or choice.selected < 0 or choice.selected >= offers.size():
		return
	var amount := int(offers[choice.selected].tokenAmount)
	_set_busy(true)
	status_label.text = _t("buying")
	var result: Dictionary = await service.purchase_casino_tokens(amount)
	if bool(result.get("success", false)):
		wallet = result.wallet
		status_label.text = _t("purchased", {"tokens": int(result.purchase.tokenAmount), "money": int(result.purchase.moneyCost)})
		_refresh_text()
	elif bool(result.get("retryRequired", false)):
		status_label.text = _t("retry")
	else:
		status_label.text = str(result.get("error", _t("purchase_failed")))
	_set_busy(false)

func _cancel() -> void:
	if busy:
		dialog.popup_centered(Vector2i(560, 380))
		return
	finished.emit()
