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
		var background := PanelContainer.new()
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(background)
		var margin := MarginContainer.new()
		for side in ["left", "top", "right", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 24)
		background.add_child(margin)
		var scroll := ScrollContainer.new()
		margin.add_child(scroll)
		_content = VBoxContainer.new()
		_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(_content)
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
	visible = battle_mode or CoopService.available
	var signature := JSON.stringify([CoopService.party, CoopService.invitations,
		CoopService.activity.get("status", ""), CoopService.view.get("revision", -1),
		CoopService.pending_command.get("idempotencyKey", "")])
	if signature == _signature:
		return
	_signature = signature
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_status = _label("Co-op battle" if battle_mode else "Adventure Party · up to 3 Pokémon each")
	if battle_mode:
		_build_battle()
	else:
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


func _build_battle() -> void:
	var state: Dictionary = CoopService.activity
	var status := str(state.get("status", "starting"))
	if status in ["finished", "cancelled"]:
		_status.text = "Battle finished" if status == "finished" else "Battle start cancelled"
		_button("Return to the world", func() -> void:
			var world := GameState.get_world()
			if world != null:
				await world.call("finish_coop_activity"))
		return
	if status == "starting" or CoopService.view.is_empty():
		_status.text = "Connecting both Trainers…"
		if state.get("canCancel", false):
			_button("Cancel start", func() -> void: await CoopService.party_action("cancel", {"reservationId": state["reservationId"]}))
		return
	var view: Dictionary = CoopService.view
	_status.text = "Turn %s · %s" % [str(view.get("turn", 1)), "partner ready" if view.get("partnerReady", false) else "waiting for partner"]
	if view.get("ended", false):
		_status.text = "Battle finished. Saving both Trainers…"
		return
	_label("Each choice has 60 seconds. After 30 seconds disconnected, temporary AI chooses for that Trainer.")
	for position: Dictionary in view.get("positions", []):
		_label("%s · %s · %s%% HP" % [str(position.get("position", "")), str(position.get("details", "")), str(position.get("hpPercent", 0))])
	_label("Your Pokémon")
	for pokemon: Dictionary in view.get("ownTeam", []):
		_label("%s. %s · %s/%s HP" % [str(pokemon.get("slot")), str(pokemon.get("species")), str(pokemon.get("hp")), str(pokemon.get("maxHp"))])
	if not CoopService.pending_command.is_empty():
		_button("Check / retry my choice", func() -> void: await CoopService.retry_command())
		return
	if view.get("locked", true):
		_label("Choice received. Waiting for the other actions…")
		return
	for action: Dictionary in view.get("legalActions", []):
		var text := "Switch to Pokémon %s" % str(action.get("slot"))
		if action.get("type") == "move":
			text = "Move %s" % str(action.get("slot"))
			for move: Dictionary in view.get("moves", []):
				if move.get("slot") == action.get("slot"):
					text = "%s (%s PP)" % [str(move.get("name")), str(move.get("pp"))]
			if action.has("target"):
				text += " → " + _target_label(int(action["target"]), str(view.get("participant")))
		_button(text, func() -> void: await CoopService.submit_action(action))


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
