extends PanelContainer
class_name CoopPartyPopup

signal closed

const BACKGROUND := Color("#050b14f5")
const SURFACE := Color("#0b1a2bea")
const BORDER := Color("#315070")
const ACCENT := Color("#60d3ff")
const TEXT := Color("#f4f0de")
const MUTED := Color("#aeb8c5")
const DANGER := Color("#f1a9a9")

var _content: VBoxContainer
var _status: Label
var _recipient: LineEdit
var _recipient_text := ""
var _dragging := false
var _focused_invitation_id := ""
var _response_pending := false
var _rendered_party_signature := ""


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
	var party_signature := JSON.stringify(CoopService.party) if _focused_invitation_id.is_empty() and not CoopService.party.is_empty() else ""
	if visible and not party_signature.is_empty() and party_signature == _rendered_party_signature:
		return
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_rendered_party_signature = party_signature
	var party_mode := not CoopService.party.is_empty() and _focused_invitation_id.is_empty()
	var target_size := Vector2(460, 370 if party_mode else 340)
	if size != target_size:
		custom_minimum_size = target_size
		size = target_size
		if visible:
			position = ((get_viewport_rect().size - size) / 2.0).max(Vector2.ZERO)
	_status = _label("2 Trainers · up to 3 Pokémon each" if party_mode else "Up to 3 Pokémon per Trainer", MUTED)
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
		var appearances: Dictionary = CoopService.party.get("memberAppearances", {}) if CoopService.party.get("memberAppearances") is Dictionary else {}
		var members: Array = CoopService.party.get("memberIds", []) if CoopService.party.get("memberIds") is Array else []
		var own_id := int(AuthService.current_user.get("id", 0))
		if members.size() == 2 and int(members[1]) == own_id:
			members = [members[1], members[0]]
		var leader_id := int(CoopService.party.get("leaderId", 0))
		for member_id: Variant in members:
			var key := str(int(member_id))
			var appearance: Dictionary = appearances.get(key, {}) if appearances.get(key) is Dictionary else {}
			_add_member_card(str(names.get(key, "Trainer #%s" % key)), appearance,
				int(member_id) == own_id, int(member_id) == leader_id)
		var level_cap := int(CoopService.party.get("sharedLevelCap", 0))
		_add_level_cap_card(level_cap)
		var leave_button := _button("Leave party", func() -> void: await CoopService.party_action("leave"))
		leave_button.custom_minimum_size.y = 42
		leave_button.add_theme_color_override("font_color", DANGER)
		leave_button.add_theme_stylebox_override("normal", _style(SURFACE, Color("#8c4a55")))
		leave_button.add_theme_stylebox_override("hover", _style(Color("#351b26"), DANGER))
		_content.add_child(leave_button)
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
		_status.text = LocalizationManager.text("ui.coop.wild.partner_too_far") if message == "coop_partner_too_far" else message


func _add_member_card(name: String, appearance: Dictionary, is_self: bool, is_leader: bool) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(SURFACE, BORDER))
	_content.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var frame := CenterContainer.new()
	frame.custom_minimum_size = Vector2(48, 48)
	row.add_child(frame)
	var portrait := TrainerHeadPortrait.new()
	portrait.custom_minimum_size = Vector2(48, 48)
	portrait.appearance_state = appearance
	frame.add_child(portrait)
	if str(appearance.get("body", "")).is_empty():
		var initial := Label.new()
		initial.text = name.substr(0, 1).to_upper()
		initial.add_theme_color_override("font_color", MUTED)
		frame.add_child(initial)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 2)
	row.add_child(details)
	var role := Label.new()
	role.text = "YOU · LEADER" if is_self and is_leader else "YOU" if is_self else "PARTNER · LEADER" if is_leader else "PARTNER"
	role.add_theme_color_override("font_color", ACCENT if is_self else MUTED)
	role.add_theme_font_size_override("font_size", 10)
	details.add_child(role)
	var name_label := Label.new()
	name_label.text = name
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_color_override("font_color", TEXT)
	name_label.add_theme_font_size_override("font_size", 16)
	details.add_child(name_label)


func _add_level_cap_card(level_cap: int) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(Color("#10263a"), BORDER))
	_content.add_child(card)
	var row := HBoxContainer.new()
	card.add_child(row)
	var label := Label.new()
	label.text = "SHARED LEVEL CAP"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", MUTED)
	label.add_theme_font_size_override("font_size", 11)
	row.add_child(label)
	var value := Label.new()
	value.text = "Lv. %d" % level_cap if level_cap > 0 else "—"
	value.add_theme_color_override("font_color", ACCENT)
	value.add_theme_font_size_override("font_size", 15)
	row.add_child(value)


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
