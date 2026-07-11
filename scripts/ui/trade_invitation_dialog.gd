extends ConfirmationDialog

class_name TradeInvitationDialog

var trade: Dictionary = {}
var status_label: Label
var action_in_flight := false


func setup() -> void:
	title = "Trade Invitation"
	dialog_text = ""
	min_size = Vector2i(390, 180)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label)
	get_ok_button().text = "Accept"
	confirmed.connect(_accept)
	canceled.connect(_decline_or_close)
	var realtime := get_node_or_null("/root/TradeRealtimeService")
	if realtime != null:
		realtime.invitation_received.connect(show_trade)
		realtime.active_trade_changed.connect(_on_trade_changed)


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
	if str(trade.get("status", "")) in ["active", "locked"]:
		hide()
		return
	var incoming := _current_role() == "recipient"
	get_ok_button().visible = incoming and str(trade.get("status", "")) == "invited"
	get_cancel_button().text = "Decline" if incoming else "Cancel Invitation"
	status_label.text = _status_text(incoming)
	popup_centered()
	if get_ok_button().visible:
		get_ok_button().grab_focus()
	else:
		get_cancel_button().grab_focus()


func show_error(message: String) -> void:
	trade.clear()
	get_ok_button().visible = false
	get_cancel_button().text = "Close"
	status_label.text = message
	popup_centered()


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
	if str(value.get("tradeId", "")) == str(trade.get("tradeId", "")):
		trade = value.duplicate(true)
		if str(trade.get("status", "")) in ["active", "locked"]:
			hide()
			return
		show_trade(trade)


func _current_role() -> String:
	var auth := get_node_or_null("/root/AuthService")
	var user_id := int(auth.current_user.get("id", 0)) if auth != null else 0
	for participant_value: Variant in trade.get("participants", []):
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
