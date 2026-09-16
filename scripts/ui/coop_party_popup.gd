extends PanelContainer
class_name CoopPartyPopup

signal closed

const BACKGROUND := Color("#050b14f5")
const SURFACE := Color("#0b1a2bea")
const BORDER := Color("#315070")
const ACCENT := Color("#60d3ff")
const TEXT := Color("#f4f0de")
const MUTED := Color("#aeb8c5")

var _content: VBoxContainer
var _status: Label
var _recipient: LineEdit
var _recipient_text := ""
var _dragging := false
var _focused_invitation_id := ""
var _response_pending := false


func _ready() -> void:
	visible = false
	size = Vector2(460, 340)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _style(BACKGROUND, BORDER))
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 42
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header.gui_input.connect(_on_header_input)
	column.add_child(header)
	var title := Label.new()
	title.text = "ADVENTURE PARTY"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_font_size_override("font_size", 20)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title)
	var close_button := _button("×", close)
	close_button.custom_minimum_size = Vector2(38, 36)
	header.add_child(close_button)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	column.add_child(_content)
	CoopService.state_changed.connect(_refresh)
	CoopService.request_failed.connect(_show_error)
	CoopService.invitation_failed.connect(_show_error)
	_refresh()


func open(recipient_name: String = "") -> void:
	_focused_invitation_id = ""
	if not recipient_name.is_empty():
		_recipient_text = recipient_name
	_refresh()
	visible = true
	var viewport_size := get_viewport_rect().size
	position = ((viewport_size - size) / 2.0).max(Vector2.ZERO)
	move_to_front()


func open_invitation(invitation: Dictionary) -> void:
	open()
	_focused_invitation_id = str(invitation.get("invitationId", ""))
	_refresh()


func close() -> void:
	_dragging = false
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible or not _dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		position += event.relative
		var extent := (get_viewport_rect().size - size).max(Vector2.ZERO)
		position = position.clamp(Vector2.ZERO, extent)
		get_viewport().set_input_as_handled()


func _on_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		accept_event()


func _refresh() -> void:
	if _content == null:
		return
	if not CoopService.available or not CoopService.activity.is_empty():
		if visible:
			close()
		return
	# Party state is polled every two seconds. Rebuilding a focused LineEdit on
	# every poll drops keyboard focus and makes a username impossible to finish.
	if visible and _focused_invitation_id.is_empty() and CoopService.party.is_empty() \
			and is_instance_valid(_recipient) and _recipient.has_focus():
		return
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_status = _label("Up to 3 Pokémon per Trainer", MUTED)
	if not _focused_invitation_id.is_empty():
		for invitation_value: Variant in CoopService.invitations:
			if invitation_value is Dictionary and str(invitation_value.get("invitationId", "")) == _focused_invitation_id:
				var sender := str(invitation_value.get("senderUsername", "Trainer"))
				_label("%s invited you to an Adventure Party." % sender, TEXT)
				_label("Play together with up to 3 Pokémon each.", MUTED)
				var level_cap: Variant = invitation_value.get("sharedLevelCap")
				if level_cap is int and level_cap > 0:
					_label("Shared level cap: Lv. %d" % level_cap, TEXT)
					_label("Based on the lower story cap; checked again before battle.", MUTED)
				_content.add_child(_button("Accept invitation", func() -> void: await _respond("accept", _focused_invitation_id)))
				_content.add_child(_button("Decline invitation", func() -> void: await _respond("close-invitation", _focused_invitation_id)))
				return
		close()
		return
	if CoopService.party.is_empty():
		_label("Invite a Trainer by username or Trainer name.", TEXT)
		_recipient = LineEdit.new()
		_recipient.placeholder_text = "Username or Trainer name"
		_recipient.text = _recipient_text
		_recipient.text_changed.connect(func(value: String) -> void: _recipient_text = value)
		_recipient.add_theme_stylebox_override("normal", _style(SURFACE, BORDER))
		_recipient.add_theme_color_override("font_color", TEXT)
		_recipient.custom_minimum_size.y = 42
		_content.add_child(_recipient)
		_content.add_child(_button("Invite Trainer", _invite))
	else:
		var names: Dictionary = CoopService.party.get("memberUsernames", {}) if CoopService.party.get("memberUsernames") is Dictionary else {}
		var members: Array = CoopService.party.get("memberIds", []) if CoopService.party.get("memberIds") is Array else []
		var display_names: Array[String] = []
		for member_id: Variant in members:
			display_names.append(str(names.get(str(int(member_id)), "Trainer")))
		var leader_name := str(names.get(str(int(CoopService.party.get("leaderId", 0))), "Trainer"))
		_label("Members: %s\nLeader: %s" % [", ".join(display_names), leader_name], TEXT)
		var level_cap := int(CoopService.party.get("sharedLevelCap", 0))
		if level_cap > 0:
			_label("Shared level cap: Lv. %d" % level_cap, MUTED)
		_content.add_child(_button("Leave party", func() -> void: await CoopService.party_action("leave")))
	for invitation: Dictionary in CoopService.invitations:
		_label("Invitation from %s" % str(invitation.get("senderUsername", "Trainer")), TEXT)
		var level_cap: Variant = invitation.get("sharedLevelCap")
		if level_cap is int and level_cap > 0:
			_label("Shared level cap: Lv. %d" % level_cap, MUTED)
		var invitation_id := str(invitation.get("invitationId", ""))
		_content.add_child(_button("Accept", func() -> void: await _respond("accept", invitation_id)))
		_content.add_child(_button("Decline", func() -> void: await _respond("close-invitation", invitation_id)))


func _respond(action: String, invitation_id: String) -> void:
	if _response_pending:
		return
	_response_pending = true
	var result: Dictionary = await CoopService.party_action(action, {"invitationId": invitation_id})
	_response_pending = false
	if result.get("success", false) and _focused_invitation_id == invitation_id:
		close()


func _invite() -> void:
	var name := _recipient_text.strip_edges()
	if name.is_empty() or name.length() > 32:
		_show_error("Enter a username or Trainer name (up to 32 characters).")
		return
	var result: Dictionary = await CoopService.party_action("invite", {"recipientName": name})
	if result.get("success", false):
		_status.text = "Invitation sent."
	elif result.get("code") == "coop_recipient_name_ambiguous":
		_show_error("Several Trainers use that name. Enter their unique username.")
	elif result.get("code") == "coop_recipient_unavailable":
		_show_error("No Trainer found with that name.")


func _show_error(message: String) -> void:
	if is_instance_valid(_status):
		_status.text = message


func _label(value: String, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color", color)
	_content.add_child(label)
	return label


func _button(value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_stylebox_override("normal", _style(SURFACE, BORDER))
	button.add_theme_stylebox_override("hover", _style(Color("#143b55f5"), ACCENT))
	button.add_theme_stylebox_override("pressed", _style(Color("#0d2b40f2"), ACCENT))
	button.add_theme_stylebox_override("focus", _style(SURFACE, ACCENT))
	button.pressed.connect(callback)
	return button


func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	return style
