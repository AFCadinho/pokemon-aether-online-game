extends PanelContainer

class_name FriendlistPopup

signal closed
signal private_message_requested(user: Dictionary)
signal mail_requested(user: Dictionary)
signal incoming_friend_requests_changed(count: int)

const POPUP_SIZE := Vector2(880, 620)
const FRIENDLIST_ICON: Texture2D = preload("res://assets/ui/friendlist.svg")
const UI_BG := Color("#050b14ed")
const UI_SURFACE_RAISED := Color("#081522eb")
const UI_SLOT_BG := Color("#0b1a2bea")
const UI_HOVER_BG := Color("#112a44f2")
const UI_INPUT_BG := Color("#030812d6")
const UI_BORDER := Color("#60d3ff")
const UI_BORDER_SOFT := Color("#315070")
const UI_BORDER_FRIENDLIST := Color("#3d7596cc")
const UI_BORDER_FRIENDLIST_INNER := Color("#2d4b66b3")
const UI_BORDER_FOCUS := Color("#7aa7f4")
const UI_TEXT := Color("#f4f0de")
const UI_MUTED_TEXT := Color("#aeb8c5")
const UI_SECTION_TEXT := Color("#60d3ff")
const UI_DANGER := Color("#ff6b74")
const UI_DANGER_BG := Color("#2a1015e8")
const UI_SUCCESS := Color("#79e49b")
const UI_OFFLINE := Color("#778194")
const FRIEND_STATUS_PREVIEW_LINES := 2

var overview: Dictionary = {}
var is_busy := false
var friend_search_query := ""
var is_dragging_popup := false

var status_label: Label
var tabs: TabContainer
var tab_button_row: HBoxContainer
var tab_buttons: Dictionary = {}
var friends_list: VBoxContainer
var requests_list: VBoxContainer
var requests_tab_attention_badge: Panel
var blocked_list: VBoxContainer
var friend_search_input: LineEdit
var friends_summary_label: Label
var block_user_input: LineEdit
var status_message_input: LineEdit
var status_character_label: Label
var save_status_button: Button
var remove_friend_confirm_dialog: PanelContainer
var remove_friend_confirm_label: Label
var remove_friend_confirm_button: Button
var remove_friend_cancel_button: Button
var pending_remove_friend_username := ""
var add_friend_dialog: PanelContainer
var add_friend_input: LineEdit
var add_friend_confirm_button: Button
var add_friend_cancel_button: Button


func _ready() -> void:
	visible = false
	custom_minimum_size = POPUP_SIZE
	size = POPUP_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _make_outer_style())
	_build_ui()
	_setup_add_friend_dialog()
	_setup_remove_friend_confirm_dialog()


func open() -> void:
	visible = true
	_center_in_viewport()
	_clamp_to_viewport()
	_load_socials_async()


func refresh() -> void:
	_load_socials_async()


func close() -> void:
	_hide_remove_friend_confirm_dialog()
	_hide_add_friend_dialog()
	is_dragging_popup = false
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible or not is_dragging_popup:
		return

	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
		is_dragging_popup = false
		get_viewport().set_input_as_handled()
		return

	var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
	if mouse_motion != null:
		position += mouse_motion.relative
		_clamp_to_viewport()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 52)
	header.add_theme_constant_override("separation", 10)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header.gui_input.connect(_on_drag_handle_gui_input)
	root.add_child(header)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(44, 44)
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color("#0a2133e8"), Color("#60d3ff99"), 10, 1)
	)
	header.add_child(icon_frame)

	var icon_center := CenterContainer.new()
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(icon_center)

	var icon := TextureRect.new()
	icon.texture = FRIENDLIST_ICON
	icon.custom_minimum_size = Vector2(31, 31)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.add_child(icon)

	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_theme_constant_override("separation", 0)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(heading)

	var title := Label.new()
	title.text = "Friends"
	title.add_theme_color_override("font_color", UI_TEXT)
	title.add_theme_font_size_override("font_size", 21)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Your trainer network and social activity"
	subtitle.add_theme_color_override("font_color", UI_MUTED_TEXT)
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(subtitle)

	var add_friend_button := Button.new()
	add_friend_button.text = "+  Add Friend"
	add_friend_button.custom_minimum_size = Vector2(126, 38)
	add_friend_button.pressed.connect(_show_add_friend_dialog)
	_apply_button_style(add_friend_button, "primary")
	header.add_child(add_friend_button)

	var refresh_button := Button.new()
	refresh_button.text = "↻"
	refresh_button.tooltip_text = "Refresh friends"
	refresh_button.custom_minimum_size = Vector2(38, 38)
	refresh_button.pressed.connect(_on_refresh_pressed)
	_apply_button_style(refresh_button)
	refresh_button.add_theme_font_size_override("font_size", 18)
	header.add_child(refresh_button)

	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = "Close friends"
	close_button.custom_minimum_size = Vector2(38, 38)
	close_button.pressed.connect(close)
	_apply_button_style(close_button)
	close_button.add_theme_font_size_override("font_size", 18)
	header.add_child(close_button)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.text = ""
	status_label.visible = false
	status_label.custom_minimum_size = Vector2(0, 28)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	status_label.add_theme_font_size_override("font_size", 12)
	root.add_child(status_label)

	var tab_shell := MarginContainer.new()
	tab_shell.add_theme_constant_override("margin_left", 0)
	tab_shell.add_theme_constant_override("margin_top", 2)
	tab_shell.add_theme_constant_override("margin_right", 0)
	root.add_child(tab_shell)

	tab_button_row = HBoxContainer.new()
	tab_button_row.add_theme_constant_override("separation", 4)
	tab_shell.add_child(tab_button_row)

	tabs = TabContainer.new()
	tabs.tabs_visible = false
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_stylebox_override("panel", _make_inner_style())
	root.add_child(tabs)

	tabs.add_child(_build_friends_tab())
	tabs.add_child(_build_requests_tab())
	tabs.add_child(_build_blocked_tab())
	tabs.add_child(_build_status_tab())
	_setup_friendlist_tab_buttons()


func _build_friends_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.add_theme_constant_override("separation", 10)

	var tools_row := HBoxContainer.new()
	tools_row.add_theme_constant_override("separation", 10)
	tab.add_child(tools_row)

	friends_summary_label = Label.new()
	friends_summary_label.text = "0 friends"
	friends_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	friends_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	friends_summary_label.add_theme_font_size_override("font_size", 12)
	friends_summary_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	tools_row.add_child(friends_summary_label)

	friend_search_input = LineEdit.new()
	friend_search_input.placeholder_text = "Search by name or username"
	friend_search_input.custom_minimum_size = Vector2(300, 38)
	friend_search_input.clear_button_enabled = true
	friend_search_input.text_changed.connect(_on_friend_search_changed)
	_apply_line_edit_style(friend_search_input)
	tools_row.add_child(friend_search_input)

	friends_list = VBoxContainer.new()
	friends_list.add_theme_constant_override("separation", 8)
	tab.add_child(_scroll_for(friends_list))
	return _tab_content_margin(tab, "Friends", 12)


func _build_requests_tab() -> Control:
	requests_list = VBoxContainer.new()
	requests_list.add_theme_constant_override("separation", 9)
	return _tab_content_margin(_scroll_for(requests_list), "Requests", 12)


func _build_blocked_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.add_theme_constant_override("separation", 10)

	var block_row := HBoxContainer.new()
	block_row.add_theme_constant_override("separation", 8)
	tab.add_child(block_row)

	block_user_input = LineEdit.new()
	block_user_input.placeholder_text = "Enter a username to block"
	block_user_input.custom_minimum_size = Vector2(0, 38)
	block_user_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block_user_input.text_submitted.connect(_on_block_user_submitted)
	_apply_line_edit_style(block_user_input)
	block_row.add_child(block_user_input)

	var block_button := Button.new()
	block_button.text = "Block"
	block_button.custom_minimum_size = Vector2(96, 38)
	block_button.pressed.connect(_on_block_user_pressed)
	_apply_button_style(block_button, "danger")
	block_row.add_child(block_button)

	blocked_list = VBoxContainer.new()
	blocked_list.add_theme_constant_override("separation", 7)
	tab.add_child(_scroll_for(blocked_list))
	return _tab_content_margin(tab, "Blocked", 12)


func _build_status_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.add_theme_constant_override("separation", 9)

	var hint := Label.new()
	hint.text = "YOUR STATUS"
	hint.add_theme_color_override("font_color", UI_SECTION_TEXT)
	hint.add_theme_font_size_override("font_size", 10)
	tab.add_child(hint)

	var description := Label.new()
	description.text = "Let friends know what you are currently doing."
	description.add_theme_color_override("font_color", UI_MUTED_TEXT)
	description.add_theme_font_size_override("font_size", 12)
	tab.add_child(description)

	status_message_input = LineEdit.new()
	status_message_input.max_length = 100
	status_message_input.placeholder_text = "Training, trading, exploring..."
	status_message_input.custom_minimum_size = Vector2(0, 40)
	status_message_input.text_changed.connect(_on_status_message_changed)
	_apply_line_edit_style(status_message_input)
	tab.add_child(status_message_input)

	status_character_label = Label.new()
	status_character_label.text = "0 / 100"
	status_character_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_character_label.add_theme_font_size_override("font_size", 10)
	status_character_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	tab.add_child(status_character_label)

	save_status_button = Button.new()
	save_status_button.text = "Save Status"
	save_status_button.custom_minimum_size = Vector2(132, 38)
	save_status_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	save_status_button.pressed.connect(_on_save_status_pressed)
	_apply_button_style(save_status_button, "primary")
	tab.add_child(save_status_button)

	return _tab_content_margin(tab, "Status", 18)


func _scroll_for(content: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 7)
	scroll.add_child(content)
	return scroll


func _tab_content_margin(content: Control, tab_name: String, top_margin: int = 10) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.name = tab_name
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", top_margin)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(content)
	return margin


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
	var friends: Array = _array_from_value(overview.get("friends", []))
	var incoming_requests: Array = _array_from_value(overview.get("incomingFriendRequests", []))
	var outgoing_requests: Array = _array_from_value(overview.get("outgoingFriendRequests", []))
	var blocked_users: Array = _array_from_value(overview.get("blockedUsers", []))
	_render_friends(friends)
	_render_requests(
		incoming_requests,
		outgoing_requests
	)
	_render_blocked(blocked_users)
	_refresh_tab_counts(friends.size(), incoming_requests.size() + outgoing_requests.size(), blocked_users.size())
	_set_requests_attention(incoming_requests.size())
	incoming_friend_requests_changed.emit(incoming_requests.size())

	var profile: Dictionary = _dictionary_from_value(overview.get("profile", {}))
	if status_message_input != null:
		status_message_input.text = str(profile.get("statusMessage", ""))
		_on_status_message_changed(status_message_input.text)


func _render_friends(friends: Array) -> void:
	_clear_children(friends_list)
	var online_count := 0
	for friend_value: Variant in friends:
		var friend: Dictionary = _dictionary_from_value(friend_value)
		var friend_user: Dictionary = _dictionary_from_value(friend.get("user", {}))
		if bool(friend_user.get("online", false)):
			online_count += 1
	if friends_summary_label != null:
		friends_summary_label.text = "%s friend%s  ·  %s online" % [
			friends.size(),
			"" if friends.size() == 1 else "s",
			online_count,
		]
	if friends.is_empty():
		friends_list.add_child(_empty_label("No friends yet.\nAdd a trainer to start building your network."))
		return

	var rendered_count := 0
	for friend_value: Variant in friends:
		var friend: Dictionary = _dictionary_from_value(friend_value)
		var user: Dictionary = _dictionary_from_value(friend.get("user", {}))
		if not _friend_matches_search(user):
			continue
		friends_list.add_child(_friend_row(user))
		rendered_count += 1

	if rendered_count == 0:
		friends_list.add_child(_empty_label("No friends match this search."))


func _friend_row(user: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 11)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var online := bool(user.get("online", false))
	row.add_child(_create_user_avatar(user, online))

	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 1)
	row.add_child(identity)

	var identity_header := HBoxContainer.new()
	identity_header.add_theme_constant_override("separation", 8)
	identity.add_child(identity_header)

	var name_label := Label.new()
	name_label.text = _user_display_name(user)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_color_override("font_color", UI_TEXT)
	name_label.add_theme_font_size_override("font_size", 15)
	identity_header.add_child(name_label)

	var presence_label := Label.new()
	presence_label.text = _presence_label_text(user).to_upper()
	presence_label.add_theme_color_override("font_color", UI_SUCCESS if online else UI_OFFLINE)
	presence_label.add_theme_font_size_override("font_size", 9)
	identity_header.add_child(presence_label)

	var username_label := Label.new()
	username_label.text = "@%s" % _user_handle(user)
	username_label.add_theme_color_override("font_color", Color("#79d9ff"))
	username_label.add_theme_font_size_override("font_size", 10)
	identity.add_child(username_label)

	var status_message: String = str(user.get("statusMessage", "")).strip_edges()
	var status_message_label := Label.new()
	status_message_label.text = status_message if status_message != "" else "No status message"
	status_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_message_label.max_lines_visible = FRIEND_STATUS_PREVIEW_LINES
	status_message_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_message_label.tooltip_text = status_message_label.text
	status_message_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	status_message_label.add_theme_font_size_override("font_size", 11)
	identity.add_child(status_message_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 6)
	row.add_child(actions)

	var message_button := Button.new()
	message_button.text = "Message"
	message_button.tooltip_text = "Open a private conversation." if online else "This friend is offline."
	message_button.custom_minimum_size = Vector2(96, 34)
	message_button.disabled = not online
	message_button.pressed.connect(_on_private_message_pressed.bind(user.duplicate(true)))
	_apply_button_style(message_button, "primary")
	actions.add_child(message_button)

	var mail_button := Button.new()
	mail_button.text = "Mail"
	mail_button.tooltip_text = "Send mail to this trainer."
	mail_button.custom_minimum_size = Vector2(72, 34)
	mail_button.pressed.connect(_on_mail_pressed.bind(user.duplicate(true)))
	_apply_button_style(mail_button)
	actions.add_child(mail_button)

	var remove_button := Button.new()
	remove_button.text = "Remove"
	remove_button.tooltip_text = "Remove this trainer from your friends."
	remove_button.custom_minimum_size = Vector2(82, 34)
	remove_button.pressed.connect(_on_remove_friend_pressed.bind(
		str(user.get("username", "")),
		_display_user_name(user)
	))
	_apply_button_style(remove_button, "danger")
	remove_button.add_theme_font_size_override("font_size", 12)
	actions.add_child(remove_button)

	return _row_panel(row, UI_SUCCESS if online else UI_BORDER_SOFT)


func _friend_matches_search(user: Dictionary) -> bool:
	var query := friend_search_query.strip_edges().to_lower()
	if query == "":
		return true
	var username := str(user.get("username", "")).strip_edges().to_lower()
	var display_name := str(user.get("displayName", "")).strip_edges().to_lower()
	return username.contains(query) or display_name.contains(query)


func _render_requests(incoming: Array, outgoing: Array) -> void:
	_clear_children(requests_list)

	var incoming_title := Label.new()
	incoming_title.text = "INCOMING  ·  %s" % incoming.size()
	_apply_section_label_style(incoming_title)
	requests_list.add_child(incoming_title)
	if incoming.is_empty():
		requests_list.add_child(_empty_label("No incoming friend requests."))
	else:
		for request_value: Variant in incoming:
			requests_list.add_child(_incoming_request_row(_dictionary_from_value(request_value)))

	var outgoing_title := Label.new()
	outgoing_title.text = "SENT  ·  %s" % outgoing.size()
	_apply_section_label_style(outgoing_title)
	requests_list.add_child(outgoing_title)
	if outgoing.is_empty():
		requests_list.add_child(_empty_label("No pending requests sent."))
	else:
		for request_value: Variant in outgoing:
			requests_list.add_child(_outgoing_request_row(_dictionary_from_value(request_value)))


func _setup_friendlist_tab_buttons() -> void:
	if tab_button_row == null:
		return
	tab_buttons.clear()
	var tab_specs: Array[Dictionary] = [
		{"index": 0, "label": "Friends", "id": "friends"},
		{"index": 1, "label": "Requests", "id": "requests"},
		{"index": 2, "label": "Blocked", "id": "blocked"},
		{"index": 3, "label": "Status", "id": "status"},
	]
	for spec: Dictionary in tab_specs:
		var button := Button.new()
		button.text = str(spec.get("label", ""))
		button.set_meta("base_label", str(spec.get("label", "")))
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 36)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_friendlist_tab_pressed.bind(int(spec.get("index", 0))))
		tab_button_row.add_child(button)
		tab_buttons[str(spec.get("id", ""))] = button
		if str(spec.get("id", "")) == "requests":
			requests_tab_attention_badge = _create_attention_badge_for_button(button, 4.0, 3.0)
	_refresh_friendlist_tab_buttons()


func _refresh_tab_counts(friend_count: int, request_count: int, blocked_count: int) -> void:
	var counts := {
		"friends": friend_count,
		"requests": request_count,
		"blocked": blocked_count,
	}
	for tab_id: String in tab_buttons:
		var button: Button = tab_buttons.get(tab_id) as Button
		if button == null:
			continue
		var base_label: String = str(button.get_meta("base_label", button.text))
		button.text = (
			"%s  %s" % [base_label, int(counts.get(tab_id, 0))]
			if counts.has(tab_id)
			else base_label
		)


func _on_friendlist_tab_pressed(tab_index: int) -> void:
	if tabs == null:
		return
	tabs.current_tab = tab_index
	_refresh_friendlist_tab_buttons()


func _refresh_friendlist_tab_buttons() -> void:
	if tabs == null:
		return
	var active_index: int = tabs.current_tab
	var id_by_index: Dictionary = {
		0: "friends",
		1: "requests",
		2: "blocked",
		3: "status",
	}
	for index_value: Variant in id_by_index.keys():
		var index: int = int(index_value)
		var button: Button = tab_buttons.get(str(id_by_index.get(index, ""))) as Button
		if button == null:
			continue
		_apply_friendlist_tab_button_style(button, index == active_index)


func _setup_requests_tab_attention_badge() -> void:
	if requests_tab_attention_badge != null:
		return
	var requests_button: Button = tab_buttons.get("requests") as Button
	if requests_button != null:
		requests_tab_attention_badge = _create_attention_badge_for_button(requests_button, 4.0, 3.0)


func _set_requests_attention(count: int) -> void:
	_setup_requests_tab_attention_badge()
	if requests_tab_attention_badge != null:
		requests_tab_attention_badge.visible = count > 0


func _setup_add_friend_dialog() -> void:
	add_friend_dialog = PanelContainer.new()
	add_friend_dialog.name = "AddFriendDialog"
	add_friend_dialog.visible = false
	add_friend_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	add_friend_dialog.z_index = 120
	add_friend_dialog.custom_minimum_size = Vector2(390, 184)
	add_friend_dialog.add_theme_stylebox_override("panel", _make_outer_style())
	add_child(add_friend_dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_friend_dialog.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "Add Friend"
	title.add_theme_color_override("font_color", UI_TEXT)
	title.add_theme_font_size_override("font_size", 18)
	layout.add_child(title)

	var hint := Label.new()
	hint.text = "Send a friend request using a trainer's username."
	hint.add_theme_color_override("font_color", UI_MUTED_TEXT)
	hint.add_theme_font_size_override("font_size", 11)
	layout.add_child(hint)

	add_friend_input = LineEdit.new()
	add_friend_input.placeholder_text = "Trainer username"
	add_friend_input.custom_minimum_size = Vector2(0, 38)
	add_friend_input.text_submitted.connect(_on_add_friend_submitted)
	_apply_line_edit_style(add_friend_input)
	layout.add_child(add_friend_input)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 8)
	layout.add_child(button_row)

	add_friend_cancel_button = Button.new()
	add_friend_cancel_button.text = "Cancel"
	add_friend_cancel_button.custom_minimum_size = Vector2(92, 32)
	add_friend_cancel_button.pressed.connect(_hide_add_friend_dialog)
	_apply_button_style(add_friend_cancel_button)
	button_row.add_child(add_friend_cancel_button)

	add_friend_confirm_button = Button.new()
	add_friend_confirm_button.text = "Send Request"
	add_friend_confirm_button.custom_minimum_size = Vector2(126, 34)
	add_friend_confirm_button.pressed.connect(_confirm_add_friend)
	_apply_button_style(add_friend_confirm_button, "success")
	button_row.add_child(add_friend_confirm_button)


func _show_add_friend_dialog() -> void:
	if add_friend_dialog == null:
		return
	_hide_remove_friend_confirm_dialog()
	add_friend_input.text = ""
	add_friend_dialog.size = Vector2(390, 184)
	add_friend_dialog.position = (size - add_friend_dialog.size) * 0.5
	add_friend_dialog.visible = true
	add_friend_dialog.move_to_front()
	add_friend_input.grab_focus()


func _hide_add_friend_dialog() -> void:
	if add_friend_dialog != null:
		add_friend_dialog.visible = false


func _confirm_add_friend() -> void:
	if add_friend_input == null:
		return
	var username: String = add_friend_input.text.strip_edges()
	if username == "":
		add_friend_input.grab_focus()
		return
	_hide_add_friend_dialog()
	_add_friend_async(username)


func _setup_remove_friend_confirm_dialog() -> void:
	remove_friend_confirm_dialog = PanelContainer.new()
	remove_friend_confirm_dialog.name = "RemoveFriendConfirm"
	remove_friend_confirm_dialog.visible = false
	remove_friend_confirm_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	remove_friend_confirm_dialog.z_index = 120
	remove_friend_confirm_dialog.custom_minimum_size = Vector2(380, 170)
	remove_friend_confirm_dialog.add_theme_stylebox_override("panel", _make_outer_style())
	add_child(remove_friend_confirm_dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	remove_friend_confirm_dialog.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "Remove Friend"
	title.add_theme_color_override("font_color", UI_TEXT)
	title.add_theme_font_size_override("font_size", 18)
	layout.add_child(title)

	remove_friend_confirm_label = Label.new()
	remove_friend_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	remove_friend_confirm_label.add_theme_color_override("font_color", UI_TEXT)
	remove_friend_confirm_label.add_theme_font_size_override("font_size", 14)
	layout.add_child(remove_friend_confirm_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 8)
	layout.add_child(button_row)

	remove_friend_cancel_button = Button.new()
	remove_friend_cancel_button.text = "Cancel"
	remove_friend_cancel_button.custom_minimum_size = Vector2(92, 32)
	remove_friend_cancel_button.pressed.connect(_hide_remove_friend_confirm_dialog)
	_apply_button_style(remove_friend_cancel_button)
	button_row.add_child(remove_friend_cancel_button)

	remove_friend_confirm_button = Button.new()
	remove_friend_confirm_button.text = "Remove"
	remove_friend_confirm_button.custom_minimum_size = Vector2(104, 32)
	remove_friend_confirm_button.pressed.connect(_confirm_remove_friend)
	_apply_button_style(remove_friend_confirm_button, "danger")
	button_row.add_child(remove_friend_confirm_button)


func _show_remove_friend_confirm_dialog(username: String, display_name: String) -> void:
	pending_remove_friend_username = username.strip_edges()
	if pending_remove_friend_username == "":
		return
	_hide_add_friend_dialog()
	var name_text: String = display_name.strip_edges()
	if name_text == "":
		name_text = pending_remove_friend_username
	remove_friend_confirm_label.text = "Remove %s from your friends?" % name_text
	remove_friend_confirm_dialog.size = Vector2(380, 170)
	remove_friend_confirm_dialog.position = (size - remove_friend_confirm_dialog.size) * 0.5
	remove_friend_confirm_dialog.visible = true
	remove_friend_confirm_dialog.move_to_front()


func _hide_remove_friend_confirm_dialog() -> void:
	pending_remove_friend_username = ""
	if remove_friend_confirm_dialog != null:
		remove_friend_confirm_dialog.visible = false


func _confirm_remove_friend() -> void:
	var username: String = pending_remove_friend_username
	_hide_remove_friend_confirm_dialog()
	_remove_friend_async(username)


func _make_attention_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#ff3434")
	style.border_color = Color("#ff8a8a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color("#ff343499")
	style.shadow_size = 6
	style.shadow_offset = Vector2.ZERO
	return style


func _incoming_request_row(request: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var requester: Dictionary = _dictionary_from_value(request.get("requester", {}))
	var friendship_id := int(request.get("id", 0))

	row.add_child(_create_user_avatar(requester, true))
	row.add_child(_create_request_identity(requester, "Wants to add you as a friend"))

	var accept_button := Button.new()
	accept_button.text = "Accept"
	accept_button.custom_minimum_size = Vector2(92, 34)
	accept_button.pressed.connect(_on_accept_request_pressed.bind(friendship_id))
	_apply_button_style(accept_button, "primary")
	row.add_child(accept_button)

	var decline_button := Button.new()
	decline_button.text = "Decline"
	decline_button.custom_minimum_size = Vector2(92, 34)
	decline_button.pressed.connect(_on_decline_request_pressed.bind(friendship_id))
	_apply_button_style(decline_button, "danger")
	row.add_child(decline_button)

	return _row_panel(row, UI_BORDER)


func _outgoing_request_row(request: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var addressee: Dictionary = _dictionary_from_value(request.get("addressee", {}))
	var friendship_id := int(request.get("id", 0))

	row.add_child(_create_user_avatar(addressee, false))
	row.add_child(_create_request_identity(addressee, "Waiting for a response"))

	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(92, 34)
	cancel_button.pressed.connect(_on_cancel_request_pressed.bind(friendship_id))
	_apply_button_style(cancel_button)
	row.add_child(cancel_button)

	return _row_panel(row)


func _render_blocked(blocked_users: Array) -> void:
	_clear_children(blocked_list)
	if blocked_users.is_empty():
		blocked_list.add_child(_empty_label("No blocked trainers.\nBlocked trainers will be listed here."))
		return

	for block_value: Variant in blocked_users:
		var block: Dictionary = _dictionary_from_value(block_value)
		var user: Dictionary = _dictionary_from_value(block.get("user", {}))
		blocked_list.add_child(_blocked_row(user))


func _blocked_row(user: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	row.add_child(_create_user_avatar(user, false, true))
	row.add_child(_create_request_identity(user, "Messages and social invites are hidden"))

	var unblock_button := Button.new()
	unblock_button.text = "Unblock"
	unblock_button.custom_minimum_size = Vector2(104, 34)
	unblock_button.pressed.connect(_on_unblock_user_pressed.bind(str(user.get("username", ""))))
	_apply_button_style(unblock_button)
	row.add_child(unblock_button)

	return _row_panel(row, Color("#8f4650"))


func _create_user_avatar(user: Dictionary, online: bool, blocked: bool = false) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(46, 46)
	var border_color := Color("#8f4650") if blocked else (UI_SUCCESS if online else UI_BORDER_SOFT)
	frame.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color("#0a1b2be8"), border_color, 10, 1)
	)

	var initials := Label.new()
	initials.text = _user_initials(user)
	initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initials.add_theme_font_size_override("font_size", 13)
	initials.add_theme_color_override("font_color", UI_MUTED_TEXT if blocked else UI_TEXT)
	initials.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(initials)
	return frame


func _create_request_identity(user: Dictionary, detail_text: String) -> Control:
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 1)

	var name_label := Label.new()
	name_label.text = _user_display_name(user)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", UI_TEXT)
	identity.add_child(name_label)

	var detail_label := Label.new()
	detail_label.text = "@%s  ·  %s" % [_user_handle(user), detail_text]
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_label.add_theme_font_size_override("font_size", 10)
	detail_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	identity.add_child(detail_label)
	return identity


func _user_initials(user: Dictionary) -> String:
	var source: String = _user_display_name(user).strip_edges()
	if source == "":
		source = _user_handle(user)
	var words: PackedStringArray = source.split(" ", false)
	if words.is_empty():
		return "?"
	var initials := words[0].substr(0, 1)
	if words.size() > 1:
		initials += words[words.size() - 1].substr(0, 1)
	return initials.to_upper()


func _on_refresh_pressed() -> void:
	_load_socials_async()


func _on_private_message_pressed(user: Dictionary) -> void:
	if not bool(user.get("online", false)):
		_set_status("%s is offline." % _display_user_name(user))
		return
	private_message_requested.emit(user)


func _on_mail_pressed(user: Dictionary) -> void:
	mail_requested.emit(user)


func _on_friend_search_changed(query: String) -> void:
	friend_search_query = query
	_render_friends(_array_from_value(overview.get("friends", [])))


func _on_status_message_changed(message: String) -> void:
	if status_character_label != null:
		status_character_label.text = "%s / 100" % message.length()


func _on_add_friend_submitted(_username: String) -> void:
	_confirm_add_friend()


func _on_accept_request_pressed(friendship_id: int) -> void:
	_accept_request_async(friendship_id)


func _on_decline_request_pressed(friendship_id: int) -> void:
	_decline_request_async(friendship_id)


func _on_cancel_request_pressed(friendship_id: int) -> void:
	_cancel_request_async(friendship_id)


func _on_remove_friend_pressed(username: String, display_name: String = "") -> void:
	_show_remove_friend_confirm_dialog(username, display_name)


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


func _add_friend_async(username: String) -> void:
	var result: Dictionary = await SocialService.send_friend_request(username)
	_apply_action_result(result, "Friend request sent.")


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
	var username := _user_handle(user)
	var display_name := _user_display_name(user)
	if display_name != "" and display_name.to_lower() != username.to_lower():
		return "%s (@%s)" % [display_name, username]
	if display_name != "":
		return display_name
	return username


func _user_display_name(user: Dictionary) -> String:
	var display_name := str(user.get("displayName", "")).strip_edges()
	if display_name != "":
		return display_name
	return _user_handle(user)


func _user_handle(user: Dictionary) -> String:
	var username := str(user.get("username", "")).strip_edges()
	return username if username != "" else "unknown"


func _presence_label_text(user: Dictionary) -> String:
	if bool(user.get("online", false)):
		return "Online"
	var last_seen_at: String = str(user.get("lastSeenAt", "")).strip_edges()
	if last_seen_at == "":
		return "Offline"
	return "Last seen %s" % _relative_last_seen_text(last_seen_at)


func _relative_last_seen_text(last_seen_at: String) -> String:
	var last_seen_unix: float = _unix_from_iso_datetime(last_seen_at)
	if last_seen_unix <= 0.0:
		return "offline"
	var now_unix: float = Time.get_unix_time_from_system()
	var elapsed_seconds: int = maxi(0, int(now_unix - last_seen_unix))
	if elapsed_seconds < 60:
		return "just now"
	if elapsed_seconds < 3600:
		return "%sm ago" % int(elapsed_seconds / 60)
	if elapsed_seconds < 86400:
		return "%sh ago" % int(elapsed_seconds / 3600)
	if elapsed_seconds < 172800:
		return "yesterday"
	if elapsed_seconds < 604800:
		return "%sd ago" % int(elapsed_seconds / 86400)

	var datetime: Dictionary = Time.get_datetime_dict_from_unix_time(int(last_seen_unix))
	var month: int = int(datetime.get("month", 0))
	var day: int = int(datetime.get("day", 0))
	var year: int = int(datetime.get("year", 0))
	var months: Array[String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	if month < 1 or month > months.size() or day < 1:
		return "offline"
	if year == int(Time.get_datetime_dict_from_system().get("year", 0)):
		return "%s %s" % [months[month - 1], day]
	return "%s %s, %s" % [months[month - 1], day, year]


func _unix_from_iso_datetime(value: String) -> float:
	var datetime_text: String = value.strip_edges()
	if datetime_text == "":
		return 0.0
	if datetime_text.ends_with("Z"):
		datetime_text = datetime_text.substr(0, datetime_text.length() - 1)
	var plus_index: int = datetime_text.find("+", 10)
	if plus_index >= 0:
		datetime_text = datetime_text.substr(0, plus_index)
	else:
		var minus_index: int = datetime_text.find("-", 10)
		if minus_index >= 0:
			datetime_text = datetime_text.substr(0, minus_index)
	var dot_index: int = datetime_text.find(".")
	if dot_index >= 0:
		datetime_text = datetime_text.substr(0, dot_index)
	return float(Time.get_unix_time_from_datetime_string(datetime_text))


func _empty_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(0, 72)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	label.add_theme_font_size_override("font_size", 12)
	return label


func _set_status(message: String) -> void:
	if status_label != null:
		status_label.text = message
		status_label.visible = message != ""
		status_label.add_theme_color_override("font_color", UI_MUTED_TEXT if message == "" else UI_SECTION_TEXT)


func _center_in_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	size = POPUP_SIZE
	position = (viewport_size - size) * 0.5


func _clamp_to_viewport() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var max_x: float = maxf(0.0, viewport_size.x - size.x)
	var max_y: float = maxf(0.0, viewport_size.y - size.y)
	position = Vector2(
		clampf(position.x, 0.0, max_x),
		clampf(position.y, 0.0, max_y)
	)


func _on_drag_handle_gui_input(event: InputEvent) -> void:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		is_dragging_popup = mouse_button.pressed
		if is_dragging_popup:
			move_to_front()
		accept_event()


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


func _row_panel(content: Control, accent_color: Color = UI_BORDER_SOFT) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 72)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_row_style(accent_color))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 11)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	margin.add_child(content)
	return panel


func _apply_section_label_style(label: Label) -> void:
	label.add_theme_color_override("font_color", UI_SECTION_TEXT)
	label.add_theme_font_size_override("font_size", 10)


func _apply_button_style(button: Button, variant: String = "default") -> void:
	var normal_bg := UI_SLOT_BG
	var hover_bg := UI_HOVER_BG
	var pressed_bg := Color("#060e18f2")
	var border := UI_BORDER_SOFT
	var hover_border := UI_BORDER_FOCUS
	var font_color := UI_TEXT
	if variant == "primary":
		normal_bg = Color("#0b2235f2")
		hover_bg = Color("#12334df2")
		pressed_bg = Color("#071624f2")
		border = Color("#4b9dc4cc")
		hover_border = Color("#79d9ff")
		font_color = Color("#e9f2ff")
	elif variant == "success":
		normal_bg = Color("#123b26f0")
		hover_bg = Color("#1a5a38ee")
		pressed_bg = Color("#0b2417f2")
		border = Color("#3f9f68")
		hover_border = Color("#80e2a2")
		font_color = Color("#dfffe9")
	elif variant == "danger":
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
	button.add_theme_stylebox_override("disabled", _make_button_style(
		Color(UI_SLOT_BG.r, UI_SLOT_BG.g, UI_SLOT_BG.b, 0.42),
		Color(UI_BORDER_SOFT.r, UI_BORDER_SOFT.g, UI_BORDER_SOFT.b, 0.35),
		8,
		1
	))
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _apply_compact_remove_button_style(button: Button) -> void:
	var normal_bg: Color = Color("#160b0ee0")
	var hover_bg: Color = Color("#341319ee")
	var pressed_bg: Color = Color("#21090df0")
	var border: Color = Color("#5d2229")
	button.add_theme_color_override("font_color", UI_DANGER)
	button.add_theme_color_override("font_hover_color", Color("#ff9aa1"))
	button.add_theme_color_override("font_pressed_color", Color("#ffd1d4"))
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _make_button_style(normal_bg, border, 6, 1))
	button.add_theme_stylebox_override("hover", _make_button_style(hover_bg, UI_DANGER, 6, 1))
	button.add_theme_stylebox_override("pressed", _make_button_style(pressed_bg, UI_DANGER, 6, 1))
	button.add_theme_stylebox_override("focus", _make_button_style(hover_bg, UI_BORDER_FOCUS, 6, 1))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _apply_friendlist_tab_button_style(button: Button, selected: bool) -> void:
	var background: Color = UI_SLOT_BG if selected else Color("#07111edc")
	var hover_background: Color = UI_HOVER_BG
	var border: Color = Color("#60d3ffbb") if selected else Color("#29415f")
	var hover_border: Color = UI_BORDER_FOCUS
	var font_color: Color = UI_TEXT if selected else UI_MUTED_TEXT
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_color_override("font_pressed_color", UI_TEXT)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _make_tab_style(background, border, selected))
	button.add_theme_stylebox_override("hover", _make_tab_style(hover_background, hover_border, selected))
	button.add_theme_stylebox_override("pressed", _make_tab_style(Color("#0d1730f2"), hover_border, selected))
	button.add_theme_stylebox_override("focus", _make_tab_style(Color("#10213aee"), UI_BORDER_FOCUS, selected))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _make_tab_style(background_color: Color, border_color: Color, selected: bool) -> StyleBoxFlat:
	var style := _make_button_style(background_color, border_color, 6, 1)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	if selected:
		style.border_width_bottom = 2
		style.border_color = Color("#60d3ff")
	return style


func _create_attention_badge_for_button(button: Button, right_offset: float = 2.0, top_offset: float = 2.0) -> Panel:
	if button == null:
		return null
	var badge := Panel.new()
	badge.name = "AttentionBadge"
	badge.visible = false
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.z_index = 100
	badge.add_theme_stylebox_override("panel", _make_attention_badge_style())
	button.add_child(badge)
	var badge_size: Vector2 = Vector2(12, 12)
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT, false)
	badge.offset_left = -badge_size.x - right_offset
	badge.offset_top = top_offset
	badge.offset_right = -right_offset
	badge.offset_bottom = top_offset + badge_size.y
	badge.size = badge_size
	return badge


func _apply_line_edit_style(input: LineEdit) -> void:
	input.add_theme_color_override("font_color", UI_TEXT)
	input.add_theme_color_override("font_placeholder_color", Color(UI_MUTED_TEXT.r, UI_MUTED_TEXT.g, UI_MUTED_TEXT.b, 0.7))
	input.add_theme_color_override("caret_color", Color("#79d9ff"))
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
	var style := _make_panel_style(UI_BG, UI_BORDER_FRIENDLIST, 13, 1)
	style.border_width_top = 2
	style.shadow_color = Color(0, 0, 0, 0.48)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 7)
	return style


func _make_inner_style() -> StyleBoxFlat:
	return _make_panel_style(UI_SURFACE_RAISED, UI_BORDER_FRIENDLIST_INNER, 10, 1)


func _make_row_style(accent_color: Color = UI_BORDER_SOFT) -> StyleBoxFlat:
	var style := _make_panel_style(UI_SLOT_BG, Color(accent_color.r, accent_color.g, accent_color.b, 0.58), 9, 1)
	style.border_width_left = 3
	style.shadow_color = Color("#00000026")
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 1)
	return style


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
