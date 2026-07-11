extends SceneTree

const DialogScript := preload("res://scripts/ui/trade_invitation_dialog.gd")

var failed := false


func _init() -> void:
	var dialog := DialogScript.new()
	root.add_child(dialog)
	await process_frame
	dialog.setup()
	var auth := root.get_node_or_null("AuthService")
	if auth != null:
		auth.current_user = {"id": 2, "username": "misty"}
	dialog.trade = {
		"tradeId": "trade-1",
		"status": "invited",
		"revision": 1,
		"participants": [
			{"userId": 1, "role": "initiator"},
			{"userId": 2, "role": "recipient"},
		],
	}
	_check(dialog._current_role() == "recipient", "recipient derived from authenticated user")
	_check(dialog._status_text(true).contains("invited"), "incoming invitation copy")
	dialog.trade["status"] = "active"
	_check(dialog._status_text(true).contains("accepted"), "minimal accepted state")
	dialog.show_trade(dialog.trade)
	_check(not dialog.visible, "active trade closes invitation dialog")
	dialog.trade["status"] = "expired"
	_check(dialog._status_text(true).contains("expired"), "expired state")
	var source := FileAccess.get_file_as_string("res://scripts/ui/trade_invitation_dialog.gd")
	_check(source.contains("accept_invitation"), "accept command wiring")
	_check(source.contains("decline_invitation"), "decline command wiring")
	_check(source.contains("cancel_invitation"), "cancel command wiring")
	_check(source.contains("hide()"), "active trade closes invitation surface")
	_check(not source.contains("Pokemon"), "no Pokemon offer UI")
	dialog.queue_free()
	quit(1 if failed else 0)


func _check(value: bool, label: String) -> void:
	if not value:
		failed = true
		push_error(label)
