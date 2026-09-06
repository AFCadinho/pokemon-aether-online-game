class_name BankPopup
extends PanelContainer

signal closed
signal wallet_changed

const UI_BG := Color("#050b14fa")
const UI_RAISED := Color("#081522f5")
const UI_INTERACTIVE := Color("#0b1d30f2")
const UI_HOVER := Color("#112a44fa")
const UI_BORDER := Color("#355672c0")
const UI_TEXT := Color("#eef5fb")
const UI_MUTED := Color("#91a4b7")
const UI_GREEN := Color("#70d6a1")
const UI_CYAN := Color("#74d7ef")

var carried_amount_label: Label
var stored_amount_label: Label
var amount_input: LineEdit
var deposit_button: Button
var withdraw_button: Button
var carried_set_amount_button: Button
var stored_set_amount_button: Button
var quick_amount_buttons: Array[Button] = []
var status_label: Label
var request_in_progress := false
var balances_loaded := false
var dragging := false
var drag_pointer_offset := Vector2.ZERO


func _ready() -> void:
	add_theme_stylebox_override("panel", _panel_style(UI_BG, Color("#397b9cdd"), 14, 2))
	_build_interface()
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		var locale_callable := Callable(self, "_on_locale_changed")
		if not localization_manager.is_connected("locale_changed", locale_callable):
			localization_manager.connect("locale_changed", locale_callable)


func open_bank() -> void:
	visible = true
	request_in_progress = true
	balances_loaded = false
	_set_status(_t("ui.bank.status.loading"), false)
	_refresh_balances()
	_refresh_actions()
	var wallet_service := get_node_or_null("/root/PlayerWalletService")
	if wallet_service == null:
		request_in_progress = false
		_set_status(_t("ui.bank.error.load"), true)
		_refresh_actions()
		return
	var result: Dictionary = await wallet_service.call("load_wallet")
	request_in_progress = false
	if not bool(result.get("success", false)):
		_set_status(str(result.get("error", _t("ui.bank.error.load"))), true)
		_refresh_actions()
		return
	wallet_service.call("apply_wallet_result", result)
	balances_loaded = true
	_refresh_balances()
	_refresh_actions()
	_set_status(_t("ui.bank.status.ready"), false)


func close_bank() -> void:
	if request_in_progress:
		return
	visible = false
	closed.emit()


func _build_interface() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	layout.add_child(_build_header())

	var balances := HBoxContainer.new()
	balances.add_theme_constant_override("separation", 10)
	balances.add_child(_build_balance_card("ui.bank.carried", false))
	balances.add_child(_build_balance_card("ui.bank.stored", true))
	layout.add_child(balances)

	var amount_caption := Label.new()
	_set_localized_property(amount_caption, "text", "ui.bank.amount")
	amount_caption.add_theme_color_override("font_color", UI_MUTED)
	layout.add_child(amount_caption)
	amount_input = LineEdit.new()
	amount_input.name = "BankAmountInput"
	amount_input.text = "1"
	amount_input.placeholder_text = "0"
	amount_input.max_length = 10
	amount_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	amount_input.custom_minimum_size = Vector2(0, 36)
	amount_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amount_input.text_changed.connect(_on_amount_changed)
	_apply_amount_input_style()
	layout.add_child(amount_input)
	var quick_caption := Label.new()
	_set_localized_property(quick_caption, "text", "ui.bank.quick_amount")
	quick_caption.add_theme_color_override("font_color", UI_MUTED)
	layout.add_child(quick_caption)
	var quick_amounts := HBoxContainer.new()
	quick_amounts.add_theme_constant_override("separation", 8)
	layout.add_child(quick_amounts)
	for quick_amount: int in [10_000, 100_000, 1_000_000]:
		var quick_button := Button.new()
		quick_button.name = "QuickAmount%s" % quick_amount
		quick_button.text = _format_compact_amount(quick_amount)
		quick_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quick_button.focus_mode = Control.FOCUS_NONE
		quick_button.pressed.connect(_set_amount.bind(quick_amount))
		_apply_button_style(quick_button, false)
		quick_amounts.add_child(quick_button)
		quick_amount_buttons.append(quick_button)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	layout.add_child(actions)
	deposit_button = Button.new()
	deposit_button.name = "DepositButton"
	_set_localized_property(deposit_button, "text", "ui.bank.deposit")
	deposit_button.custom_minimum_size = Vector2(0, 44)
	deposit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deposit_button.focus_mode = Control.FOCUS_NONE
	deposit_button.pressed.connect(_transfer.bind("deposit"))
	_apply_button_style(deposit_button, true)
	actions.add_child(deposit_button)
	withdraw_button = Button.new()
	withdraw_button.name = "WithdrawButton"
	_set_localized_property(withdraw_button, "text", "ui.bank.withdraw")
	withdraw_button.custom_minimum_size = Vector2(0, 44)
	withdraw_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	withdraw_button.focus_mode = Control.FOCUS_NONE
	withdraw_button.pressed.connect(_transfer.bind("withdraw"))
	_apply_button_style(withdraw_button, true)
	actions.add_child(withdraw_button)
	status_label = Label.new()
	status_label.name = "BankStatusLabel"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", UI_MUTED)
	layout.add_child(status_label)


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(_on_header_gui_input)
	var icon := PanelContainer.new()
	icon.custom_minimum_size = Vector2(44, 34)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_theme_stylebox_override("panel", _panel_style(Color("#54c98b"), Color("#d9ffe9"), 8, 2))
	var icon_label := Label.new()
	icon_label.text = "₽"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 19)
	icon_label.add_theme_color_override("font_color", Color("#0a2824"))
	icon.add_child(icon_label)
	header.add_child(icon)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(heading)
	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_localized_property(title, "text", "ui.bank.title")
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", UI_TEXT)
	heading.add_child(title)
	var subtitle := Label.new()
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_localized_property(subtitle, "text", "ui.bank.subtitle")
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", UI_MUTED)
	heading.add_child(subtitle)
	var close_button := Button.new()
	close_button.text = "×"
	_set_localized_property(close_button, "tooltip_text", "common.close")
	close_button.custom_minimum_size = Vector2(34, 34)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close_bank)
	_apply_button_style(close_button, false)
	header.add_child(close_button)
	return header


func _build_balance_card(label_key: String, stored: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 96)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(UI_RAISED, UI_BORDER, 9, 1))
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(stack)
	var caption := Label.new()
	_set_localized_property(caption, "text", label_key)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color", UI_MUTED)
	stack.add_child(caption)
	var amount := Label.new()
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.add_theme_font_size_override("font_size", 20)
	amount.add_theme_color_override("font_color", UI_CYAN if stored else UI_GREEN)
	stack.add_child(amount)
	var set_amount_button := Button.new()
	set_amount_button.name = "StoredSetAmountButton" if stored else "CarriedSetAmountButton"
	_set_localized_property(set_amount_button, "text", "ui.bank.set_amount")
	set_amount_button.custom_minimum_size = Vector2(0, 28)
	set_amount_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	set_amount_button.focus_mode = Control.FOCUS_NONE
	set_amount_button.pressed.connect(_set_balance_amount.bind(stored))
	_apply_button_style(set_amount_button, false)
	stack.add_child(set_amount_button)
	if stored:
		stored_amount_label = amount
		stored_set_amount_button = set_amount_button
	else:
		carried_amount_label = amount
		carried_set_amount_button = set_amount_button
	return panel


func _transfer(direction: String, amount_override := -1) -> void:
	if request_in_progress:
		return
	var amount := amount_override if amount_override > 0 else _requested_amount()
	if amount <= 0:
		return
	request_in_progress = true
	_set_status(_t("ui.bank.status.transferring"), false)
	_refresh_actions()
	var wallet_service := get_node_or_null("/root/PlayerWalletService")
	if wallet_service == null:
		request_in_progress = false
		_set_status(_t("ui.bank.error.transfer"), true)
		_refresh_actions()
		return
	var result: Dictionary = await wallet_service.call("transfer_bank_money", direction, amount)
	request_in_progress = false
	if not bool(result.get("success", false)):
		_set_status(str(result.get("error", _t("ui.bank.error.transfer"))), true)
		_refresh_actions()
		return
	wallet_service.call("apply_wallet_result", result)
	_refresh_balances()
	_refresh_actions()
	_set_status(
		_t("ui.bank.status.deposited" if direction == "deposit" else "ui.bank.status.withdrawn"),
		false
	)
	wallet_changed.emit()


func _on_amount_changed(_value: String) -> void:
	_refresh_actions()


func _set_amount(amount: int) -> void:
	if not request_in_progress:
		amount_input.text = str(amount)


func _set_balance_amount(stored: bool) -> void:
	_set_amount(_stored_money() if stored else _carried_money())


func _refresh_balances() -> void:
	if carried_amount_label != null:
		carried_amount_label.text = "₽%s" % _format_amount(_carried_money())
	if stored_amount_label != null:
		stored_amount_label.text = "₽%s" % _format_amount(_stored_money())


func _refresh_actions() -> void:
	if amount_input == null:
		return
	var amount := _requested_amount()
	var actions_blocked := request_in_progress or not balances_loaded
	amount_input.editable = not actions_blocked
	deposit_button.disabled = actions_blocked or amount <= 0 or amount > _carried_money()
	withdraw_button.disabled = actions_blocked or amount <= 0 or amount > _stored_money()
	carried_set_amount_button.disabled = actions_blocked or _carried_money() <= 0
	stored_set_amount_button.disabled = actions_blocked or _stored_money() <= 0
	for quick_button: Button in quick_amount_buttons:
		quick_button.disabled = actions_blocked


func _carried_money() -> int:
	var player_save := get_node_or_null("/root/PlayerSave")
	return maxi(int(player_save.get("money")), 0) if player_save != null else 0


func _stored_money() -> int:
	var player_save := get_node_or_null("/root/PlayerSave")
	return maxi(int(player_save.get("bank_money")), 0) if player_save != null else 0


func _requested_amount() -> int:
	if amount_input == null:
		return 0
	var amount_text := amount_input.text.strip_edges()
	if amount_text.is_empty() or not amount_text.is_valid_int():
		return 0
	return clampi(amount_text.to_int(), 0, 2_147_483_647)


func _set_status(text: String, is_error: bool) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", Color("#ef7085") if is_error else UI_MUTED)


func _on_locale_changed(_locale: String = "") -> void:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		localization_manager.call("localize_tree", self)
	_refresh_balances()


func _format_amount(amount: int) -> String:
	var digits := str(maxi(amount, 0))
	var formatted := ""
	while digits.length() > 3:
		formatted = ",%s%s" % [digits.substr(digits.length() - 3), formatted]
		digits = digits.left(digits.length() - 3)
	return digits + formatted


func _format_compact_amount(amount: int) -> String:
	if amount >= 1_000_000:
		return "%sM" % (amount / 1_000_000)
	if amount >= 1_000:
		return "%sK" % (amount / 1_000)
	return str(amount)


func _set_localized_property(control: Control, property_name: String, key: String) -> void:
	control.set(property_name, _t(key))
	control.set_meta("i18n_source_%s" % property_name, key)


func _t(key: String) -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	return str(localization_manager.call("text", key)) if localization_manager != null else key


func _apply_button_style(button: Button, primary: bool) -> void:
	var normal_color := Color("#13563fff") if primary else UI_INTERACTIVE
	var border_color := UI_GREEN if primary else UI_BORDER
	button.add_theme_stylebox_override("normal", _panel_style(normal_color, border_color, 8, 1))
	button.add_theme_stylebox_override("hover", _panel_style(UI_HOVER, UI_CYAN, 8, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#0c342aff"), UI_GREEN, 8, 1))
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_color_override("font_disabled_color", Color("#657484"))


func _apply_amount_input_style() -> void:
	amount_input.add_theme_stylebox_override("normal", _panel_style(UI_INTERACTIVE, UI_BORDER, 8, 1))
	amount_input.add_theme_stylebox_override("focus", _panel_style(UI_HOVER, UI_CYAN, 8, 1))
	amount_input.add_theme_stylebox_override("read_only", _panel_style(UI_RAISED, UI_BORDER, 8, 1))
	amount_input.add_theme_color_override("font_color", UI_TEXT)
	amount_input.add_theme_color_override("font_placeholder_color", UI_MUTED)
	amount_input.add_theme_font_size_override("font_size", 16)


func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if dragging:
			drag_pointer_offset = get_global_mouse_position() - global_position
		accept_event()


func _input(event: InputEvent) -> void:
	if not dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		dragging = false
		return
	if event is InputEventMouseMotion:
		global_position = get_global_mouse_position() - drag_pointer_offset


func _panel_style(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	return style
