extends PanelContainer

class_name FriendlistPopup

signal closed
signal private_message_requested(user: Dictionary)

const POPUP_SIZE := Vector2(720, 560)
const UI_BG := Color("#070b14f2")
const UI_SLOT_BG := Color("#0d1625e6")
const UI_INPUT_BG := Color("#050912e8")
const UI_BORDER := Color("#d8b767")
const UI_BORDER_SOFT := Color("#315070")
const UI_BORDER_FOCUS := Color("#7aa7f4")
const UI_TEXT := Color("#f4f0de")
const UI_MUTED_TEXT := Color("#aeb8c5")
const UI_SECTION_TEXT := Color("#d8b767")
const UI_DANGER := Color("#ff6b74")
const UI_DANGER_BG := Color("#2a1015e8")
const UI_SUCCESS := Color("#79e49b")
const UI_OFFLINE := Color("#778194")

var overview: Dictionary = {}
var is_busy := false

var status_label: Label
var tabs: TabContainer
var friends_list: VBoxContainer
var requests_list: VBoxContainer
var blocked_list: VBoxContainer
var add_friend_input: LineEdit
var block_user_input: LineEdit
var status_message_input: LineEdit
var save_status_button: Button


func _ready() -> void:
	visible = false
	custom_minimum_size = POPUP_SIZE
	size = POPUP_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _make_outer_style())
	_build_ui()


func open() -> void:
	visible = true
	_center_in_viewport()
	_load_socials_async()


func close() -> void:
	visible = false
	closed.emit()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	var title := Label.new()
	title.text = "Friendlist"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", UI_SECTION_TEXT)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_shadow_color", Color("#000000aa"))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	header.add_child(title)

	var refresh_button := Button.new()
	refresh_button.text = "Refresh"
	refresh_button.pressed.connect(_on_refresh_pressed)
	_apply_button_style(refresh_button, "primary")
	header.add_child(refresh_button)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(close)
	_apply_button_style(close_button)
	header.add_child(close_button)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.text = ""
	status_label.custom_minimum_size = Vector2(0, 22)
	status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	status_label.add_theme_font_size_override("font_size", 13)
	root.add_child(status_label)

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_stylebox_override("panel", _make_inner_style())
	tabs.add_theme_color_override("font_selected_color", UI_SECTION_TEXT)
	tabs.add_theme_color_override("font_unselected_color", UI_TEXT)
	root.add_child(tabs)

	tabs.add_child(_build_friends_tab())
	tabs.add_child(_build_requests_tab())
	tabs.add_child(_build_blocked_tab())
	tabs.add_child(_build_status_tab())


func _build_friends_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "Friends"
	tab.add_theme_constant_override("separation", 10)

	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 8)
	tab.add_child(add_row)

	add_friend_input = LineEdit.new()
	add_friend_input.placeholder_text = "Username"
	add_friend_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_friend_input.text_submitted.connect(_on_add_friend_submitted)
	_apply_line_edit_style(add_friend_input)
	add_row.add_child(add_friend_input)

	var add_button := Button.new()
	add_button.text = "Add Friend"
	add_button.pressed.connect(_on_add_friend_pressed)
	_apply_button_style(add_button, "primary")
	add_row.add_child(add_button)

	friends_list = VBoxContainer.new()
	friends_list.add_theme_constant_override("separation", 7)
	tab.add_child(_scroll_for(friends_list))
	return tab


func _build_requests_tab() -> Control:
	requests_list = VBoxContainer.new()
	requests_list.name = "Requests"
	requests_list.add_theme_constant_override("separation", 8)
	return _scroll_for(requests_list, "Requests")


func _build_blocked_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "Blocked"
	tab.add_theme_constant_override("separation", 10)

	var block_row := HBoxContainer.new()
	block_row.add_theme_constant_override("separation", 8)
	tab.add_child(block_row)

	block_user_input = LineEdit.new()
	block_user_input.placeholder_text = "Username"
	block_user_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block_user_input.text_submitted.connect(_on_block_user_submitted)
	_apply_line_edit_style(block_user_input)
	block_row.add_child(block_user_input)

	var block_button := Button.new()
	block_button.text = "Block"
	block_button.pressed.connect(_on_block_user_pressed)
	_apply_button_style(block_button, "danger")
	block_row.add_child(block_button)

	blocked_list = VBoxContainer.new()
	blocked_list.add_theme_constant_override("separation", 7)
	tab.add_child(_scroll_for(blocked_list))
	return tab


func _build_status_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "Status"
	tab.add_theme_constant_override("separation", 10)

	var hint := Label.new()
	hint.text = "Status message"
	hint.add_theme_color_override("font_color", UI_SECTION_TEXT)
	hint.add_theme_font_size_override("font_size", 15)
	tab.add_child(hint)

	status_message_input = LineEdit.new()
	status_message_input.max_length = 100
	status_message_input.placeholder_text = "What are you doing?"
	_apply_line_edit_style(status_message_input)
	tab.add_child(status_message_input)

	save_status_button = Button.new()
	save_status_button.text = "Save"
	save_status_button.pressed.connect(_on_save_status_pressed)
	_apply_button_style(save_status_button, "primary")
	tab.add_child(save_status_button)

	return tab


func _scroll_for(content: Control, tab_name: String = "") -> ScrollContainer:
	var scroll := ScrollContainer.new()
	if tab_name != "":
		scroll.name = tab_name
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 7)
	scroll.add_child(content)
	return scroll


func _load_socials_async() -> void:
	if is_busy:
		return
	is_busy = true
	_set_status("Loading socials...")
	var result: Dictionary = await SocialService.load_socials()
	is_busy = false
	if not bool(result.get("success", false)):
		_set_status(str(result.get("error", "Could not load socials.")))
		return

	overview = _dictionary_from_value(result.get("overview", {}))
	_render_overview()
	_set_status("")


func _render_overview() -> void:
	_render_friends(_array_from_value(overview.get("friends", [])))
	_render_requests(
		_array_from_value(overview.get("incomingFriendRequests", [])),
		_array_from_value(overview.get("outgoingFriendRequests", []))
	)
	_render_blocked(_array_from_value(overview.get("blockedUsers", [])))

	var profile: Dictionary = _dictionary_from_value(overview.get("profile", {}))
	if status_message_input != null:
		status_message_input.text = str(profile.get("statusMessage", ""))


func _render_friends(friends: Array) -> void:
	_clear_children(friends_list)
	if friends.is_empty():
		friends_list.add_child(_empty_label("No friends yet."))
		return

	for friend_value: Variant in friends:
		var friend: Dictionary = _dictionary_from_value(friend_value)
		var user: Dictionary = _dictionary_from_value(friend.get("user", {}))
		friends_list.add_child(_friend_row(user))


func _friend_row(user: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var online := bool(user.get("online", false))
	var status_dot := Label.new()
	status_dot.text = "● Online" if online else "● Offline"
	status_dot.custom_minimum_size = Vector2(78, 0)
	status_dot.add_theme_color_override("font_color", UI_SUCCESS if online else UI_OFFLINE)
	status_dot.add_theme_font_size_override("font_size", 13)
	row.add_child(status_dot)

	var name_label := Label.new()
	name_label.text = _display_user_name(user)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", UI_TEXT)
	name_label.add_theme_font_size_override("font_size", 14)
	row.add_child(name_label)

	var status_message := str(user.get("statusMessage", "")).strip_edges()
	var status_message_label := Label.new()
	status_message_label.text = status_message if status_message != "" else "No status"
	status_message_label.clip_text = true
	status_message_label.custom_minimum_size = Vector2(180, 0)
	status_message_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	status_message_label.add_theme_font_size_override("font_size", 13)
	row.add_child(status_message_label)

	var pm_button := Button.new()
	pm_button.text = "PM"
	pm_button.tooltip_text = "Open private message."
	pm_button.pressed.connect(_on_private_message_pressed.bind(user.duplicate(true)))
	_apply_button_style(pm_button, "primary")
	row.add_child(pm_button)

	var remove_button := Button.new()
	remove_button.text = "Remove"
	remove_button.pressed.connect(_on_remove_friend_pressed.bind(str(user.get("username", ""))))
	_apply_button_style(remove_button, "danger")
	row.add_child(remove_button)

	return _row_panel(row)


func _render_requests(incoming: Array, outgoing: Array) -> void:
	_clear_children(requests_list)

	var incoming_title := Label.new()
	incoming_title.text = "Incoming"
	_apply_section_label_style(incoming_title)
	requests_list.add_child(incoming_title)
	if incoming.is_empty():
		requests_list.add_child(_empty_label("No incoming requests."))
	else:
		for request_value: Variant in incoming:
			requests_list.add_child(_incoming_request_row(_dictionary_from_value(request_value)))

	var outgoing_title := Label.new()
	outgoing_title.text = "Outgoing"
	_apply_section_label_style(outgoing_title)
	requests_list.add_child(outgoing_title)
	if outgoing.is_empty():
		requests_list.add_child(_empty_label("No outgoing requests."))
	else:
		for request_value: Variant in outgoing:
			requests_list.add_child(_outgoing_request_row(_dictionary_from_value(request_value)))


func _incoming_request_row(request: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var requester: Dictionary = _dictionary_from_value(request.get("requester", {}))
	var friendship_id := int(request.get("id", 0))

	var label := Label.new()
	label.text = _display_user_name(requester)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", UI_TEXT)
	row.add_child(label)

	var accept_button := Button.new()
	accept_button.text = "Accept"
	accept_button.pressed.connect(_on_accept_request_pressed.bind(friendship_id))
	_apply_button_style(accept_button, "primary")
	row.add_child(accept_button)

	var decline_button := Button.new()
	decline_button.text = "Decline"
	decline_button.pressed.connect(_on_decline_request_pressed.bind(friendship_id))
	_apply_button_style(decline_button, "danger")
	row.add_child(decline_button)

	return _row_panel(row)


func _outgoing_request_row(request: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var addressee: Dictionary = _dictionary_from_value(request.get("addressee", {}))
	var friendship_id := int(request.get("id", 0))

	var label := Label.new()
	label.text = _display_user_name(addressee)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", UI_TEXT)
	row.add_child(label)

	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(_on_cancel_request_pressed.bind(friendship_id))
	_apply_button_style(cancel_button)
	row.add_child(cancel_button)

	return _row_panel(row)


func _render_blocked(blocked_users: Array) -> void:
	_clear_children(blocked_list)
	if blocked_users.is_empty():
		blocked_list.add_child(_empty_label("No blocked users."))
		return

	for block_value: Variant in blocked_users:
		var block: Dictionary = _dictionary_from_value(block_value)
		var user: Dictionary = _dictionary_from_value(block.get("user", {}))
		blocked_list.add_child(_blocked_row(user))


func _blocked_row(user: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label := Label.new()
	label.text = _display_user_name(user)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", UI_TEXT)
	row.add_child(label)

	var unblock_button := Button.new()
	unblock_button.text = "Unblock"
	unblock_button.pressed.connect(_on_unblock_user_pressed.bind(str(user.get("username", ""))))
	_apply_button_style(unblock_button)
	row.add_child(unblock_button)

	return _row_panel(row)


func _on_refresh_pressed() -> void:
	_load_socials_async()


func _on_private_message_pressed(user: Dictionary) -> void:
	private_message_requested.emit(user)


func _on_add_friend_pressed() -> void:
	_send_friend_request_async(add_friend_input.text)


func _on_add_friend_submitted(username: String) -> void:
	_send_friend_request_async(username)


func _send_friend_request_async(username: String) -> void:
	var result: Dictionary = await SocialService.send_friend_request(username)
	_apply_action_result(result, "Friend request sent.")
	if bool(result.get("success", false)):
		add_friend_input.text = ""


func _on_accept_request_pressed(friendship_id: int) -> void:
	_accept_request_async(friendship_id)


func _on_decline_request_pressed(friendship_id: int) -> void:
	_decline_request_async(friendship_id)


func _on_cancel_request_pressed(friendship_id: int) -> void:
	_cancel_request_async(friendship_id)


func _on_remove_friend_pressed(username: String) -> void:
	_remove_friend_async(username)


func _on_block_user_pressed() -> void:
	_block_user_async(block_user_input.text)


func _on_block_user_submitted(username: String) -> void:
	_block_user_async(username)


func _block_user_async(username: String) -> void:
	var result: Dictionary = await SocialService.block_user(username)
	_apply_action_result(result, "User blocked.")
	if bool(result.get("success", false)):
		block_user_input.text = ""


func _on_unblock_user_pressed(username: String) -> void:
	_unblock_user_async(username)


func _on_save_status_pressed() -> void:
	_save_status_async()


func _accept_request_async(friendship_id: int) -> void:
	var result: Dictionary = await SocialService.accept_friend_request(friendship_id)
	_apply_action_result(result, "Friend request accepted.")


func _decline_request_async(friendship_id: int) -> void:
	var result: Dictionary = await SocialService.decline_friend_request(friendship_id)
	_apply_action_result(result, "Friend request declined.")


func _cancel_request_async(friendship_id: int) -> void:
	var result: Dictionary = await SocialService.cancel_friend_request(friendship_id)
	_apply_action_result(result, "Friend request cancelled.")


func _remove_friend_async(username: String) -> void:
	var result: Dictionary = await SocialService.remove_friend(username)
	_apply_action_result(result, "Friend removed.")


func _unblock_user_async(username: String) -> void:
	var result: Dictionary = await SocialService.unblock_user(username)
	_apply_action_result(result, "User unblocked.")


func _save_status_async() -> void:
	var result: Dictionary = await SocialService.update_status_message(status_message_input.text)
	_apply_action_result(result, "Status saved.")


func _apply_action_result(result: Dictionary, success_message: String) -> void:
	if not bool(result.get("success", false)):
		_set_status(str(result.get("error", "Action failed.")))
		return

	_set_status(success_message)
	if result.has("overview"):
		overview = _dictionary_from_value(result.get("overview", {}))
		_render_overview()
	else:
		_load_socials_async()


func _display_user_name(user: Dictionary) -> String:
	var username := str(user.get("username", "")).strip_edges()
	var display_name := str(user.get("displayName", "")).strip_edges()
	if display_name != "" and display_name.to_lower() != username.to_lower():
		return "%s (@%s)" % [display_name, username]
	if display_name != "":
		return display_name
	return username


func _empty_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	label.add_theme_font_size_override("font_size", 13)
	return label


func _set_status(message: String) -> void:
	if status_label != null:
		status_label.text = message
		status_label.add_theme_color_override("font_color", UI_MUTED_TEXT if message == "" else UI_SECTION_TEXT)


func _center_in_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	size = POPUP_SIZE
	position = (viewport_size - size) * 0.5


func _clear_children(container: Node) -> void:
	for child: Node in container.get_children():
		child.queue_free()


func _dictionary_from_value(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var dictionary: Dictionary = value
	return dictionary


func _array_from_value(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var array: Array = value
	return array


func _row_panel(content: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_row_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)
	margin.add_child(content)
	return panel


func _apply_section_label_style(label: Label) -> void:
	label.add_theme_color_override("font_color", UI_SECTION_TEXT)
	label.add_theme_font_size_override("font_size", 15)


func _apply_button_style(button: Button, variant: String = "default") -> void:
	var normal_bg := UI_SLOT_BG
	var hover_bg := Color("#151f36f2")
	var pressed_bg := Color("#080d18f2")
	var border := UI_BORDER_SOFT
	var hover_border := UI_BORDER
	var font_color := UI_TEXT
	if variant == "danger":
		normal_bg = UI_DANGER_BG
		hover_bg = Color("#3a151cee")
		pressed_bg = Color("#19090dee")
		border = Color("#7a2b33")
		hover_border = UI_DANGER
		font_color = UI_DANGER
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_color_override("font_pressed_color", UI_TEXT)
	button.add_theme_color_override("font_disabled_color", Color(UI_MUTED_TEXT.r, UI_MUTED_TEXT.g, UI_MUTED_TEXT.b, 0.45))
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _make_button_style(normal_bg, border))
	button.add_theme_stylebox_override("hover", _make_button_style(hover_bg, hover_border))
	button.add_theme_stylebox_override("pressed", _make_button_style(pressed_bg, hover_border))
	button.add_theme_stylebox_override("focus", _make_button_style(UI_INPUT_BG, UI_BORDER_FOCUS, 8, 1))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _apply_line_edit_style(input: LineEdit) -> void:
	input.add_theme_color_override("font_color", UI_TEXT)
	input.add_theme_color_override("font_placeholder_color", Color(UI_MUTED_TEXT.r, UI_MUTED_TEXT.g, UI_MUTED_TEXT.b, 0.7))
	input.add_theme_color_override("caret_color", UI_SECTION_TEXT)
	input.add_theme_font_size_override("font_size", 14)
	input.add_theme_stylebox_override("normal", _make_input_style(UI_INPUT_BG, UI_BORDER_SOFT))
	input.add_theme_stylebox_override("focus", _make_input_style(Color("#071225f2"), UI_BORDER_FOCUS, 2))
	input.add_theme_stylebox_override("read_only", _make_input_style(Color("#090d16d8"), UI_BORDER_SOFT))


func _make_panel_style(background_color: Color, border_color: Color, corner_radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	return style


func _make_outer_style() -> StyleBoxFlat:
	var style := _make_panel_style(UI_BG, UI_BORDER, 10, 1)
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	return style


func _make_inner_style() -> StyleBoxFlat:
	return _make_panel_style(Color("#05091288"), Color("#31507088"), 8, 1)


func _make_row_style() -> StyleBoxFlat:
	return _make_panel_style(UI_SLOT_BG, UI_BORDER_SOFT, 8, 1)


func _make_button_style(background_color: Color, border_color: Color, corner_radius: int = 8, border_width: int = 1) -> StyleBoxFlat:
	var style := _make_panel_style(background_color, border_color, corner_radius, border_width)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _make_input_style(background_color: Color, border_color: Color, border_width: int = 1) -> StyleBoxFlat:
	var style := _make_panel_style(background_color, border_color, 7, border_width)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style
