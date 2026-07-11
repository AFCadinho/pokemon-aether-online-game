extends ConfirmationDialog

class_name TradeInvitationDialog

const DIALOG_SIZE := Vector2i(460, 230)
const TRADE_BG := Color("#050912fa")
const TRADE_SURFACE := Color("#0b1422f7")
const TRADE_BORDER := Color("#345170")
const TRADE_ACCENT := Color("#62d7ff")
const TRADE_GOLD := Color("#d8b767")
const TRADE_TEXT := Color("#f4f0de")
const TRADE_MUTED := Color("#aeb8c5")

var trade: Dictionary = {}
var status_label: Label
var mode_label: Label
var action_in_flight := false


func setup() -> void:
	title = "Trade Invitation"
	dialog_text = ""
	min_size = DIALOG_SIZE
	max_size = DIALOG_SIZE
	unresizable = true
	get_label().visible = false
	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_theme_stylebox_override("panel", _panel_style(TRADE_BG, TRADE_GOLD, 7, 1))
	add_child(background)
	move_child(background, 0)
	var content_panel := PanelContainer.new()
	content_panel.anchor_left = 0.0
	content_panel.anchor_top = 0.0
	content_panel.anchor_right = 1.0
	content_panel.anchor_bottom = 0.0
	content_panel.offset_left = 16
	content_panel.offset_top = 16
	content_panel.offset_right = -16
	content_panel.offset_bottom = 145
	content_panel.add_theme_stylebox_override("panel", _panel_style(TRADE_SURFACE, TRADE_BORDER, 6, 1))
	add_child(content_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	content_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)
	mode_label = Label.new()
	mode_label.text = "TRADE REQUEST"
	mode_label.add_theme_color_override("font_color", TRADE_GOLD)
	mode_label.add_theme_font_size_override("font_size", 12)
	stack.add_child(mode_label)
	var heading := Label.new()
	heading.text = "Pokemon Trade"
	heading.add_theme_color_override("font_color", TRADE_TEXT)
	heading.add_theme_font_size_override("font_size", 21)
	stack.add_child(heading)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", TRADE_MUTED)
	stack.add_child(status_label)
	get_ok_button().text = "Accept"
	_style_button(get_ok_button(), "primary")
	_style_button(get_cancel_button(), "danger")
	confirmed.connect(_accept)
	get_cancel_button().pressed.connect(_decline_or_close)
	close_requested.connect(hide)
	var realtime := get_node_or_null("/root/TradeRealtimeService")
	if realtime != null:
		realtime.invitation_received.connect(show_trade)
		realtime.active_trade_changed.connect(_on_trade_changed)
		var snapshot: Dictionary = realtime.active_trade_snapshot
		if str(snapshot.get("status", "")) == "invited" and _role_for_trade(snapshot) == "recipient":
			show_trade.call_deferred(snapshot.duplicate(true))


func send_invitation(username: String) -> Dictionary:
	var service := get_node_or_null("/root/TradeService")
	if service == null:
		return {"success": false, "error": "Trade service unavailable."}
	action_in_flight = true
	var result: Dictionary = await service.create_invitation(username)
	action_in_flight = false
	if bool(result.get("success", false)):
		show_trade(result.get("trade", {}))
		var realtime := get_node_or_null("/root/TradeRealtimeService")
		if realtime != null:
			realtime.apply_snapshot(trade)
			realtime.restore_active_trade_and_connect.call_deferred()
	else:
		show_error(str(result.get("error", "Could not send trade invitation.")))
	return result


func show_trade(value: Dictionary) -> void:
	trade = value.duplicate(true)
	if str(trade.get("status", "")) != "invited":
		hide()
		return
	var incoming := _current_role() == "recipient"
	get_ok_button().visible = incoming and str(trade.get("status", "")) == "invited"
	get_cancel_button().text = "Decline" if incoming else "Cancel Invitation"
	mode_label.text = "INCOMING REQUEST" if incoming else "REQUEST SENT"
	_style_button(get_cancel_button(), "danger" if incoming else "secondary")
	status_label.text = _status_text(incoming)
	size = DIALOG_SIZE
	popup_centered(DIALOG_SIZE)
	if get_ok_button().visible:
		get_ok_button().grab_focus()
	else:
		get_cancel_button().grab_focus()


func show_error(message: String) -> void:
	trade.clear()
	get_ok_button().visible = false
	get_cancel_button().text = "Close"
	mode_label.text = "REQUEST ERROR"
	_style_button(get_cancel_button(), "secondary")
	status_label.text = message
	size = DIALOG_SIZE
	popup_centered(DIALOG_SIZE)


func _accept() -> void:
	if action_in_flight or trade.is_empty():
		return
	action_in_flight = true
	var result: Dictionary = await get_node("/root/TradeService").accept_invitation(str(trade.get("tradeId", "")), int(trade.get("revision", 0)))
	action_in_flight = false
	_apply_result(result)


func _decline_or_close() -> void:
	if action_in_flight or trade.is_empty() or str(trade.get("status", "")) != "invited":
		return
	action_in_flight = true
	var service := get_node("/root/TradeService")
	var result: Dictionary
	if _current_role() == "recipient":
		result = await service.decline_invitation(str(trade.get("tradeId", "")), int(trade.get("revision", 0)))
	else:
		result = await service.cancel_invitation(str(trade.get("tradeId", "")), int(trade.get("revision", 0)))
	action_in_flight = false
	_apply_result(result)


func _apply_result(result: Dictionary) -> void:
	if bool(result.get("success", false)):
		var result_trade: Dictionary = result.get("trade", {})
		show_trade(result_trade)
		var realtime := get_node_or_null("/root/TradeRealtimeService")
		if realtime != null:
			realtime.apply_snapshot(result_trade)
	else:
		show_error(str(result.get("error", "Trade invitation action failed.")))


func _on_trade_changed(value: Dictionary) -> void:
	if str(value.get("status", "")) == "invited" and _role_for_trade(value) == "recipient":
		show_trade(value)
		return
	if str(value.get("tradeId", "")) == str(trade.get("tradeId", "")):
		trade = value.duplicate(true)
		if str(trade.get("status", "")) != "invited":
			hide()
			return
		show_trade(trade)


func _current_role() -> String:
	return _role_for_trade(trade)


func _role_for_trade(value: Dictionary) -> String:
	var auth := get_node_or_null("/root/AuthService")
	var user_id := int(auth.current_user.get("id", 0)) if auth != null else 0
	for participant_value: Variant in value.get("participants", []):
		if participant_value is Dictionary and int(participant_value.get("userId", 0)) == user_id:
			return str(participant_value.get("role", ""))
	return ""


func _status_text(incoming: bool) -> String:
	match str(trade.get("status", "")):
		"invited": return "A player invited you to trade." if incoming else "Waiting for the other player to respond."
		"active": return "Trade accepted. Setup will continue in the next step."
		"declined": return "The trade invitation was declined."
		"cancelled": return "The trade invitation was cancelled."
		"expired": return "The trade invitation expired."
		_: return "Trade invitation state unavailable."


func _panel_style(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := _panel_style(background, border, 5, 1)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _style_button(button: Button, kind: String) -> void:
	var normal_bg := Color("#0d4359")
	var hover_bg := Color("#12627f")
	var border := TRADE_ACCENT
	if kind == "secondary":
		normal_bg = Color("#111d2c")
		hover_bg = Color("#192c42")
		border = TRADE_BORDER
	elif kind == "danger":
		normal_bg = Color("#2a1015")
		hover_bg = Color("#5b1c26")
		border = Color("#b84c58")
	button.add_theme_color_override("font_color", TRADE_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(normal_bg, border))
	button.add_theme_stylebox_override("hover", _button_style(hover_bg, border.lightened(0.2)))
	button.add_theme_stylebox_override("pressed", _button_style(TRADE_BG, border))
	button.add_theme_stylebox_override("focus", _button_style(hover_bg, TRADE_GOLD))
