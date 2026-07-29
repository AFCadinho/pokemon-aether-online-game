extends SceneTree

const DialogScript := preload("res://scripts/ui/trade_invitation_dialog.gd")

var failed := false

class FakeSystemOverlay extends Node:
	var messages: Array[String] = []
	func add_system_message(text: String) -> void:
		messages.append(text)


func _init() -> void:
	var system_overlay := FakeSystemOverlay.new()
	system_overlay.add_to_group("ui_overlay")
	root.add_child(system_overlay)
	var dialog := DialogScript.new()
	root.add_child(dialog)
	await process_frame
	dialog.setup()
	_check(not dialog.visible and dialog.trade.is_empty(), "invitation window starts hidden without authoritative trade state")
	var auth := root.get_node_or_null("AuthService")
	if auth != null:
		auth.current_user = {"id": 2, "username": "misty"}
	dialog.trade = {
		"tradeId": "trade-1",
		"status": "invited",
		"revision": 1,
		"participants": [
			{"userId": 1, "role": "initiator", "username": "ash", "displayName": "Ash Ketchum"},
			{"userId": 2, "role": "recipient"},
		],
	}
	_check(dialog._current_role() == "recipient", "recipient derived from authenticated user")
	_check(not dialog._status_text(true).is_empty(), "incoming invitation copy is localized")
	_check(dialog._initiator_display_name() == "Ash Ketchum (@ash)", "incoming invitation identifies the initiator")
	_check(dialog._invitation_status_text(true).contains("Ash Ketchum (@ash)"), "incoming dialog names the initiator")
	dialog.trade["status"] = "active"
	_check(not dialog._status_text(true).is_empty(), "minimal accepted state is localized")
	dialog.show_trade(dialog.trade)
	_check(not dialog.visible, "active trade closes invitation dialog")
	dialog.trade["status"] = "completed"
	dialog.show_trade(dialog.trade)
	_check(not dialog.visible, "completed trade closes invitation dialog")
	dialog.trade["status"] = "expired"
	_check(not dialog._status_text(true).is_empty(), "expired state is localized")
	var incoming_snapshot := {
		"tradeId": "trade-2",
		"status": "invited",
		"revision": 1,
		"participants": [
			{"userId": 1, "role": "initiator"},
			{"userId": 2, "role": "recipient"},
		],
	}
	dialog._on_trade_changed(incoming_snapshot)
	_check(dialog.visible and str(dialog.trade.get("tradeId", "")) == "trade-2", "authoritative invited snapshot opens recipient dialog")
	_check(system_overlay.messages.size() == 1, "incoming invitation adds one localized system message")
	dialog._on_trade_changed(incoming_snapshot)
	_check(system_overlay.messages.size() == 1, "replayed invitation does not duplicate the system message")
	var localization_manager := root.get_node_or_null("LocalizationManager")
	if localization_manager != null:
		localization_manager.set_locale("pt_BR")
		await process_frame
		_check(dialog.title == "Convite para troca", "invitation title refreshes in Brazilian Portuguese")
		_check(dialog.mode_label.text == "PEDIDO RECEBIDO", "invitation state refreshes in Brazilian Portuguese")
		localization_manager.set_locale("en")
		await process_frame
	var source := FileAccess.get_file_as_string("res://scripts/ui/trade_invitation_dialog.gd")
	_check(source.contains("accept_invitation"), "accept command wiring")
	_check(source.contains("decline_invitation"), "decline command wiring")
	_check(source.contains("cancel_invitation"), "cancel command wiring")
	_check(source.contains("decline_button.pressed.connect(_decline_or_close)"), "explicit cancel button owns invitation cancellation")
	_check(source.contains("close_button.pressed.connect(_decline_or_close)"), "custom close resolves the durable invitation")
	_check(source.contains("close_requested.connect(_decline_or_close)"), "window close resolves the durable invitation")
	_check(source.contains("active_trade_changed.connect(_on_trade_changed)"), "authoritative trade snapshots reconcile invitations")
	_check(source.contains("notified_incoming_trade_ids") and source.contains("add_system_message"), "incoming invitations emit one deduplicated system message")
	_check(source.contains("hide()"), "active trade closes invitation surface")
	_check(not source.contains("replace_offer") and not source.contains("offer_slots") and not source.contains("Ready"), "no Pokemon offer mutation UI")
	_check(source.contains("DIALOG_SIZE") and source.contains("_style_button"), "invitation dialog uses compact trade styling")
	_check(source.contains("borderless = true"), "invitation uses custom chrome")
	_check(source.contains("mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND"), "invitation buttons use the pointing-hand cursor")
	dialog.queue_free()
	system_overlay.queue_free()
	quit(1 if failed else 0)


func _check(value: bool, label: String) -> void:
	if not value:
		failed = true
		push_error(label)
