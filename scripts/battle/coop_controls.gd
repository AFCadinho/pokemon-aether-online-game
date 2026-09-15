extends Control

var battle_mode := false
var _window: Window
var _content: VBoxContainer
var _status: Label
var _signature := ""
var _recipient_text := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if battle_mode:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(load("res://scripts/battle/coop_battle_panel.gd").new())
		return
	else:
		var button := Button.new()
		button.text = "Co-op party"
		button.position = Vector2(24, 120)
		button.pressed.connect(_show_party)
		add_child(button)
		_window = Window.new()
		_window.title = "Adventure Party"
		_window.size = Vector2i(460, 360)
		_window.close_requested.connect(_window.hide)
		add_child(_window)
		_content = VBoxContainer.new()
		_content.position = Vector2(16, 16)
		_content.custom_minimum_size = Vector2(425, 300)
		_window.add_child(_content)
	CoopService.state_changed.connect(_update)
	CoopService.request_failed.connect(_show_error)
	_update()


func _show_party() -> void:
	_window.popup_centered()


func _show_error(message: String) -> void:
	if is_instance_valid(_status):
		_status.text = message


func _update() -> void:
	visible = CoopService.available and CoopService.activity.is_empty()
	if not visible and _window != null:
		_window.hide()
	var signature := JSON.stringify([CoopService.party, CoopService.invitations,
		CoopService.activity.get("status", ""), CoopService.view.get("revision", -1),
		CoopService.pending_command.get("idempotencyKey", "")])
	if signature == _signature:
		return
	_signature = signature
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_status = _label("Adventure Party · up to 3 Pokémon each")
	_build_party()


func _build_party() -> void:
	if CoopService.party.is_empty():
		_label("Invite another Trainer using their Trainer ID.")
		var recipient := LineEdit.new()
		recipient.placeholder_text = "Trainer ID"
		recipient.text = _recipient_text
		recipient.text_changed.connect(func(value: String) -> void: _recipient_text = value)
		_content.add_child(recipient)
		_button("Invite", func() -> void:
			if _recipient_text.is_valid_int():
				await CoopService.party_action("invite", {"recipientId": int(_recipient_text)}))
	else:
		_label("Members: %s\nLeader: %s" % [str(CoopService.party.get("memberIds", [])), str(CoopService.party.get("leaderId", ""))])
		_button("Leave party", func() -> void: await CoopService.party_action("leave"))
	for invitation: Dictionary in CoopService.invitations:
		_label("Invitation from Trainer %s" % str(invitation.get("senderId", "")))
		var payload := {"invitationId": invitation.get("invitationId", "")}
		_button("Accept", func() -> void: await CoopService.party_action("accept", payload))
		_button("Decline", func() -> void: await CoopService.party_action("close-invitation", payload))


func _target_label(target: int, _participant: String) -> String:
	var controller := "p2" if target == 1 else "p4" if target == 2 else "p1" if target == -1 else "p3"
	for position: Dictionary in CoopService.view.get("positions", []):
		if position.get("controller") == controller:
			return str(position.get("details", controller))
	return controller


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	_content.add_child(label)
	return label


func _button(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	_content.add_child(button)
