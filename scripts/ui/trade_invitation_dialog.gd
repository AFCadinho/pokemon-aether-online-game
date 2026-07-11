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
	get_cancel_button().pressed.connect(_decline_or_close)
	close_requested.connect(hide)
	var realtime := get_node_or_null("/root/TradeRealtimeService")
	_trace("dialog_setup", {"hasRealtimeService": realtime != null})
	if realtime != null:
		realtime.invitation_received.connect(show_trade)
		realtime.active_trade_changed.connect(_on_trade_changed)
		var snapshot: Dictionary = realtime.active_trade_snapshot
		_trace("dialog_initial_snapshot", {"tradeId": str(snapshot.get("tradeId", "")), "status": str(snapshot.get("status", "")), "role": _role_for_trade(snapshot)})
		if str(snapshot.get("status", "")) == "invited" and _role_for_trade(snapshot) == "recipient":
			show_trade.call_deferred(snapshot.duplicate(true))


func send_invitation(username: String) -> Dictionary:
	_trace("invitation_send_started", {"targetUsername": username})
	var service := get_node_or_null("/root/TradeService")
	if service == null:
		return {"success": false, "error": "Trade service unavailable."}
	action_in_flight = true
	var result: Dictionary = await service.create_invitation(username)
	_trace("invitation_send_result", {"success": bool(result.get("success", false)), "tradeId": str(result.get("trade", {}).get("tradeId", "")), "status": str(result.get("trade", {}).get("status", "")), "error": str(result.get("error", ""))})
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
	_trace("dialog_show_trade", {"tradeId": str(trade.get("tradeId", "")), "status": str(trade.get("status", "")), "role": _current_role(), "wasVisible": visible})
	if str(trade.get("status", "")) != "invited":
		_trace("dialog_hidden_for_status", {"tradeId": str(trade.get("tradeId", "")), "status": str(trade.get("status", ""))})
		hide()
		return
	var incoming := _current_role() == "recipient"
	get_ok_button().visible = incoming and str(trade.get("status", "")) == "invited"
	get_cancel_button().text = "Decline" if incoming else "Cancel Invitation"
	status_label.text = _status_text(incoming)
	popup_centered()
	_trace("dialog_opened", {"tradeId": str(trade.get("tradeId", "")), "incoming": incoming, "acceptVisible": get_ok_button().visible, "visible": visible})
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
	_trace("dialog_trade_changed", {"incomingTradeId": str(value.get("tradeId", "")), "incomingStatus": str(value.get("status", "")), "incomingRole": _role_for_trade(value), "currentTradeId": str(trade.get("tradeId", "")), "visible": visible})
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


func _trace(action: String, fields: Dictionary = {}) -> void:
	var record := fields.duplicate(true)
	record["action"] = action
	record["timeMsec"] = Time.get_ticks_msec()
	var auth := get_node_or_null("/root/AuthService")
	if auth != null:
		record["userId"] = int(auth.current_user.get("id", 0))
	print("[TradeDebug][InvitationDialog] ", JSON.stringify(record))
