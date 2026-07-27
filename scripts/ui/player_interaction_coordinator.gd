extends Node

class_name PlayerInteractionCoordinator

const TradeInvitationDialogScript := preload("res://scripts/ui/trade_invitation_dialog.gd")
const NEARBY_TRAINERS_ICON: Texture2D = preload("res://assets/ui/socials_nearby.svg")

signal private_message_requested(user: Dictionary)
signal mail_requested(username: String)
signal trainer_card_requested(player: Dictionary)
signal social_overview_updated(overview: Dictionary)

const PANEL_WIDTH := 410.0
const CONTEXT_MENU_WIDTH := 344.0
const VIEWPORT_MARGIN := 12.0
const WINDOW_Z_INDEX := 1002
const CONTEXT_Z_INDEX := WINDOW_Z_INDEX + 1
const UI_SURFACE_BASE := Color("#050b14ed")
const UI_SURFACE_RAISED := Color("#081522eb")
const UI_SURFACE_INTERACTIVE := Color("#0b1a2bea")
const UI_SURFACE_HOVER := Color("#112a44f2")
const UI_SURFACE_PRESSED := Color("#060e18f2")
const UI_SURFACE_INSET := Color("#030812d6")
const UI_BORDER_SUBTLE := Color("#2d4b66b3")
const UI_BORDER_SOFT := Color("#315070")
const UI_BORDER_FOCUS := Color("#7aa7f4")
const UI_ACCENT := Color("#60d3ff")
const UI_ACCENT_SOFT := Color("#60d3ffaa")
const UI_ACCENT_FAINT := Color("#60d3ff4d")
const UI_TEXT := Color("#f4f0de")
const UI_MUTED_TEXT := Color("#aeb8c5")
const UI_DANGER := Color("#ff6b74")

var host: Control
var players_panel: PanelContainer
var players_list: VBoxContainer
var players_status_label: Label
var context_menu: PanelContainer
var context_title: Label
var context_username_label: Label
var context_status_label: Label
var context_actions: VBoxContainer
var current_target: Dictionary = {}
var social_overview: Dictionary = {}
var social_request_serial := 0
var social_action_in_flight := false
var social_state_loading := false
var social_status_message := ""
var social_status_is_error := false
var trade_capabilities: Dictionary = {}
var trade_capabilities_loaded := false
var trade_capabilities_loading := false
var trade_capabilities_error := ""
var trade_invitation_dialog: Window


func setup(host_control: Control) -> void:
	if host_control == null:
		return
	host = host_control
	add_to_group("player_interaction_coordinator")
	_build_ui()
	_setup_trade_invitation_dialog()
	var presence := get_node_or_null("/root/WorldPresenceService")
	if presence != null and presence.has_signal("roster_changed"):
		var roster_callable := Callable(self, "_on_roster_changed")
		if not presence.roster_changed.is_connected(roster_callable):
			presence.roster_changed.connect(roster_callable)


func open_players_on_map(anchor_rect: Rect2) -> void:
	if players_panel == null:
		return
	close_context_menu()
	players_panel.visible = true
	_render_players()
	_position_panel(players_panel, anchor_rect.position + Vector2(0.0, anchor_rect.size.y + 8.0))
	players_panel.move_to_front()
	_focus_first_player_row()


func open_context_for_player(player_state: Dictionary, screen_position: Vector2) -> void:
	var normalized := _normalized_player(player_state)
	if normalized.is_empty() or _is_self(normalized):
		return
	current_target = normalized
	if not trade_capabilities_loaded and not trade_capabilities_loading:
		_refresh_trade_capabilities()
	social_overview.clear()
	social_state_loading = true
	social_status_message = ""
	social_status_is_error = false
	context_menu.visible = true
	_position_panel(context_menu, screen_position + Vector2(10.0, 10.0))
	context_menu.move_to_front()
	_render_context_menu()
	_focus_first_context_action()
	_refresh_social_overview_for_target(normalized)


func close_topmost() -> bool:
	if context_menu != null and context_menu.visible:
		close_context_menu()
		return true
	if players_panel != null and players_panel.visible:
		close_players_panel()
		return true
	return false


func close_for_map_transition() -> void:
	close_context_menu()
	close_players_panel()


func _build_ui() -> void:
	if host == null or players_panel != null:
		return
	players_panel = PanelContainer.new()
	players_panel.name = "PlayersOnMapPanel"
	players_panel.visible = false
	players_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	players_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	players_panel.z_index = WINDOW_Z_INDEX
	players_panel.add_theme_stylebox_override("panel", _glass_panel_style(13))
	host.add_child(players_panel)
	var players_margin := _margin_container(14)
	players_panel.add_child(players_margin)
	var players_root := VBoxContainer.new()
	players_root.add_theme_constant_override("separation", 11)
	players_margin.add_child(players_root)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 48)
	header.add_theme_constant_override("separation", 10)
	players_root.add_child(header)

	var header_accent := Panel.new()
	header_accent.custom_minimum_size = Vector2(3, 0)
	header_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_accent.add_theme_stylebox_override("panel", _panel_style(UI_ACCENT, UI_ACCENT, 2, 0))
	header.add_child(header_accent)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(42, 42)
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#071c29e8"), UI_ACCENT_SOFT, 9)
	)
	header.add_child(icon_frame)
	var icon_center := CenterContainer.new()
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(icon_center)
	var icon := TextureRect.new()
	icon.texture = NEARBY_TRAINERS_ICON
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.add_child(icon)

	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_theme_constant_override("separation", 1)
	header.add_child(heading)
	var title := Label.new()
	title.text = "Nearby Trainers"
	title.add_theme_color_override("font_color", UI_TEXT)
	title.add_theme_font_size_override("font_size", 19)
	heading.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Trainers currently exploring this map"
	subtitle.add_theme_color_override("font_color", UI_MUTED_TEXT)
	subtitle.add_theme_font_size_override("font_size", 10)
	heading.add_child(subtitle)

	var close_button := _compact_close_button()
	close_button.pressed.connect(close_players_panel)
	header.add_child(close_button)

	var roster_header := HBoxContainer.new()
	roster_header.add_theme_constant_override("separation", 8)
	players_root.add_child(roster_header)
	var roster_caption := Label.new()
	roster_caption.text = "LIVE ROSTER"
	roster_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_caption.add_theme_font_size_override("font_size", 10)
	roster_caption.add_theme_color_override("font_color", UI_ACCENT)
	roster_header.add_child(roster_caption)
	players_status_label = Label.new()
	players_status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	players_status_label.add_theme_font_size_override("font_size", 10)
	roster_header.add_child(players_status_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 318.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	players_root.add_child(scroll)
	players_list = VBoxContainer.new()
	players_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_list.add_theme_constant_override("separation", 7)
	scroll.add_child(players_list)

	var roster_hint := Label.new()
	roster_hint.text = "Select a trainer to open social actions"
	roster_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roster_hint.add_theme_font_size_override("font_size", 10)
	roster_hint.add_theme_color_override(
		"font_color",
		Color(UI_MUTED_TEXT.r, UI_MUTED_TEXT.g, UI_MUTED_TEXT.b, 0.72)
	)
	players_root.add_child(roster_hint)

	context_menu = PanelContainer.new()
	context_menu.name = "PlayerContextMenu"
	context_menu.visible = false
	context_menu.custom_minimum_size = Vector2(CONTEXT_MENU_WIDTH, 0.0)
	context_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	context_menu.z_index = CONTEXT_Z_INDEX
	var context_style := _glass_panel_style(13)
	context_style.border_color = Color("#456784cc")
	context_menu.add_theme_stylebox_override("panel", context_style)
	host.add_child(context_menu)
	var context_margin := _margin_container(13)
	context_menu.add_child(context_margin)
	var context_root := VBoxContainer.new()
	context_root.add_theme_constant_override("separation", 9)
	context_margin.add_child(context_root)

	var context_header := HBoxContainer.new()
	context_header.add_theme_constant_override("separation", 10)
	context_root.add_child(context_header)
	var identity_badge := PanelContainer.new()
	identity_badge.name = "IdentityBadge"
	identity_badge.custom_minimum_size = Vector2(42, 42)
	identity_badge.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#071c29e8"), UI_ACCENT_SOFT, 10)
	)
	context_header.add_child(identity_badge)
	var identity_initial := Label.new()
	identity_initial.name = "Initial"
	identity_initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	identity_initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	identity_initial.add_theme_font_size_override("font_size", 18)
	identity_initial.add_theme_color_override("font_color", UI_ACCENT)
	identity_badge.add_child(identity_initial)

	var context_identity := VBoxContainer.new()
	context_identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	context_identity.alignment = BoxContainer.ALIGNMENT_CENTER
	context_identity.add_theme_constant_override("separation", 1)
	context_header.add_child(context_identity)
	context_title = Label.new()
	context_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	context_title.add_theme_color_override("font_color", UI_TEXT)
	context_title.add_theme_font_size_override("font_size", 17)
	context_identity.add_child(context_title)
	context_username_label = Label.new()
	context_username_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	context_username_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	context_username_label.add_theme_font_size_override("font_size", 10)
	context_identity.add_child(context_username_label)

	var context_close_button := _compact_close_button()
	context_close_button.pressed.connect(close_context_menu)
	context_header.add_child(context_close_button)

	var status_panel := PanelContainer.new()
	status_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(UI_SURFACE_INSET, UI_BORDER_SUBTLE, 8)
	)
	context_root.add_child(status_panel)
	var status_margin := _margin_container(8)
	status_panel.add_child(status_margin)
	context_status_label = Label.new()
	context_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	context_status_label.add_theme_font_size_override("font_size", 10)
	status_margin.add_child(context_status_label)

	context_actions = VBoxContainer.new()
	context_actions.add_theme_constant_override("separation", 6)
	context_root.add_child(context_actions)


func _on_roster_changed(_players: Array, _roster_revision: int) -> void:
	if players_panel != null and players_panel.visible:
		_render_players()
	if context_menu != null and context_menu.visible and not _target_is_on_current_map():
		close_context_menu()


func _render_players() -> void:
	if players_list == null:
		return
	_clear_children(players_list)
	var players := _current_map_players()
	players_status_label.text = "%d trainer%s nearby" % [players.size(), "" if players.size() == 1 else "s"]
	if players.is_empty():
		players_list.add_child(_create_empty_roster_state())
		return
	for player: Dictionary in players:
		players_list.add_child(_create_player_row(player))


func _create_player_row(player: Dictionary) -> Button:
	var row := Button.new()
	row.name = "Trainer_%s" % int(player.get("userId", 0))
	row.custom_minimum_size = Vector2(0, 66)
	row.focus_mode = Control.FOCUS_ALL
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.tooltip_text = "Open actions for %s" % _player_primary_name(player)
	row.pressed.connect(_on_player_row_pressed.bind(player))
	_apply_player_row_style(row)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 7)
	row.add_child(margin)

	var content := HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var identity_badge := PanelContainer.new()
	identity_badge.custom_minimum_size = Vector2(44, 44)
	identity_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity_badge.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#071c29d9"), UI_ACCENT_FAINT, 10)
	)
	content.add_child(identity_badge)
	var initial := Label.new()
	initial.text = _player_initial(player)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	initial.add_theme_font_size_override("font_size", 17)
	initial.add_theme_color_override("font_color", UI_ACCENT)
	identity_badge.add_child(initial)

	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_theme_constant_override("separation", 1)
	content.add_child(identity)
	var name_label := Label.new()
	name_label.text = _player_primary_name(player)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", UI_TEXT)
	identity.add_child(name_label)
	var username_label := Label.new()
	username_label.text = "@%s" % str(player.get("username", "")).strip_edges()
	username_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	username_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	username_label.add_theme_font_size_override("font_size", 10)
	username_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	identity.add_child(username_label)

	var nearby_label := Label.new()
	nearby_label.text = "NEARBY"
	nearby_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nearby_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nearby_label.add_theme_font_size_override("font_size", 9)
	nearby_label.add_theme_color_override("font_color", UI_ACCENT)
	content.add_child(nearby_label)
	var chevron := Label.new()
	chevron.text = "›"
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron.add_theme_font_size_override("font_size", 20)
	chevron.add_theme_color_override("font_color", UI_MUTED_TEXT)
	content.add_child(chevron)
	return row


func _create_empty_roster_state() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 150)
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(UI_SURFACE_INSET, UI_BORDER_SUBTLE, 10)
	)
	var center := CenterContainer.new()
	panel.add_child(center)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 5)
	center.add_child(stack)
	var icon := TextureRect.new()
	icon.texture = NEARBY_TRAINERS_ICON
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color(1, 1, 1, 0.55)
	stack.add_child(icon)
	var title := Label.new()
	title.text = "No trainers nearby"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", UI_TEXT)
	stack.add_child(title)
	var description := Label.new()
	description.text = "Other trainers on this map will appear here automatically."
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(270, 0)
	description.add_theme_font_size_override("font_size", 10)
	description.add_theme_color_override("font_color", UI_MUTED_TEXT)
	stack.add_child(description)
	return panel


func _on_player_row_pressed(player: Dictionary) -> void:
	if players_panel == null:
		return
	open_context_for_player(player, players_panel.get_global_rect().position + Vector2(players_panel.size.x + 8.0, 34.0))


func _render_context_menu() -> void:
	if context_menu == null or current_target.is_empty():
		return
	context_title.text = _player_primary_name(current_target)
	context_username_label.text = "@%s" % str(current_target.get("username", "")).strip_edges()
	var initial_label := context_menu.find_child("Initial", true, false) as Label
	if initial_label != null:
		initial_label.text = _player_initial(current_target)
	_refresh_context_status()
	_clear_children(context_actions)
	context_actions.add_child(_context_section_label("TRAINER ACTIONS"))
	_add_context_action("View Trainer Card", "Inspect profile, badges and stats", _on_trainer_card_pressed)
	_add_context_action("Message", "Start a private conversation", _on_message_pressed)
	_add_context_action("Send Mail", "Send a message or attachment", _on_mail_pressed)
	var trade_enabled := bool(trade_capabilities.get("enabled", false))
	_add_context_action(
		"Trade",
		_trade_action_description(trade_enabled),
		_on_trade_pressed,
		"default",
		trade_capabilities_loading or (trade_capabilities_loaded and not trade_enabled)
	)
	context_actions.add_child(_context_section_label("SOCIAL"))
	_add_context_action(
		"Remove Friend" if _is_friend(current_target) else "Add Friend",
		"Update your friends list",
		_on_friend_pressed
	)
	_add_context_action(
		"Unblock" if _is_blocked(current_target) else "Block",
		"Restore contact" if _is_blocked(current_target) else "Prevent future contact",
		_on_block_pressed,
		"default" if _is_blocked(current_target) else "danger"
	)


func _refresh_context_status() -> void:
	if context_status_label == null:
		return
	if social_state_loading:
		context_status_label.text = "Checking friendship and block status..."
		context_status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
		return
	if social_action_in_flight:
		context_status_label.text = "Updating social state..."
		context_status_label.add_theme_color_override("font_color", UI_ACCENT)
		return
	if social_status_message != "":
		context_status_label.text = social_status_message
		context_status_label.add_theme_color_override(
			"font_color",
			UI_DANGER if social_status_is_error else UI_MUTED_TEXT
		)
		return
	if _is_blocked(current_target):
		context_status_label.text = "Blocked trainer · direct contact is restricted"
		context_status_label.add_theme_color_override("font_color", UI_DANGER)
	elif _is_friend(current_target):
		context_status_label.text = "Friend · currently on this map"
		context_status_label.add_theme_color_override("font_color", Color("#6fe49a"))
	else:
		context_status_label.text = "Trainer currently active on this map"
		context_status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)


func _add_context_action(
	label: String,
	description: String,
	action: Callable,
	variant: String = "default",
	force_disabled := false
) -> void:
	var button := _context_action_button(label, description, variant)
	button.disabled = (
		force_disabled
		or (
			label not in ["View Trainer Card", "Message", "Send Mail"]
			and (social_action_in_flight or social_state_loading)
		)
	)
	button.pressed.connect(action)
	context_actions.add_child(button)

func _trade_action_description(trade_enabled: bool) -> String:
	if trade_enabled:
		return "Invite this trainer to trade"
	if trade_capabilities_loading:
		return "Checking trade availability..."
	if trade_capabilities_error != "":
		return "Could not check trade availability · select to retry"
	if trade_capabilities_loaded:
		return "Trading is currently unavailable"
	return "Check whether trading is available"


func _on_message_pressed() -> void:
	if current_target.is_empty():
		return
	private_message_requested.emit(current_target.duplicate(true))
	close_context_menu()


func _on_trainer_card_pressed() -> void:
	if current_target.is_empty():
		return
	trainer_card_requested.emit(current_target.duplicate(true))
	close_context_menu()


func _on_mail_pressed() -> void:
	var username := str(current_target.get("username", "")).strip_edges()
	if username == "":
		return
	mail_requested.emit(username)
	close_context_menu()


func _on_trade_pressed() -> void:
	if not bool(trade_capabilities.get("enabled", false)):
		_refresh_trade_capabilities()
		return
	var username := str(current_target.get("username", "")).strip_edges()
	if username == "" or trade_invitation_dialog == null:
		return
	close_context_menu()
	trade_invitation_dialog.send_invitation(username)


func _setup_trade_invitation_dialog() -> void:
	if host == null or trade_invitation_dialog != null:
		return
	trade_invitation_dialog = TradeInvitationDialogScript.new()
	host.add_child(trade_invitation_dialog)
	trade_invitation_dialog.setup()


func _refresh_trade_capabilities() -> void:
	if trade_capabilities_loading:
		return
	var service := get_node_or_null("/root/TradeService")
	if service == null:
		trade_capabilities.clear()
		trade_capabilities_loaded = false
		trade_capabilities_error = "Trade service is unavailable."
		if context_menu != null and context_menu.visible:
			_render_context_menu()
		return
	trade_capabilities_loading = true
	trade_capabilities_error = ""
	if context_menu != null and context_menu.visible:
		_render_context_menu()
	var result: Dictionary = await service.load_capabilities()
	trade_capabilities_loading = false
	trade_capabilities_loaded = bool(result.get("success", false))
	if trade_capabilities_loaded:
		trade_capabilities = result.get("capabilities", {}).duplicate(true)
		trade_capabilities_error = ""
	else:
		trade_capabilities.clear()
		trade_capabilities_error = str(result.get("error", "Could not check trade availability."))
	if context_menu != null and context_menu.visible:
		_render_context_menu()


func _on_friend_pressed() -> void:
	if current_target.is_empty() or social_action_in_flight:
		return
	var username := str(current_target.get("username", "")).strip_edges()
	if username == "":
		return
	social_action_in_flight = true
	_render_context_menu()
	var result: Dictionary = {}
	if _is_friend(current_target):
		result = await _social_action("remove_friend", username)
	else:
		result = await _social_action("send_friend_request", username)
	_apply_social_result(result)


func _on_block_pressed() -> void:
	if current_target.is_empty() or social_action_in_flight:
		return
	var username := str(current_target.get("username", "")).strip_edges()
	if username == "":
		return
	social_action_in_flight = true
	_render_context_menu()
	var result: Dictionary = {}
	if _is_blocked(current_target):
		result = await _social_action("unblock_user", username)
	else:
		result = await _social_action("block_user", username)
	_apply_social_result(result)


func _apply_social_result(result: Dictionary) -> void:
	social_action_in_flight = false
	if bool(result.get("success", false)):
		social_overview = _dictionary_from_value(result.get("overview", {}))
		social_state_loading = false
		social_status_message = ""
		social_status_is_error = false
		social_overview_updated.emit(social_overview.duplicate(true))
	else:
		social_state_loading = false
		social_status_message = str(result.get("error", "Action failed."))
		social_status_is_error = true
	_render_context_menu()
	if bool(result.get("success", false)):
		_refresh_social_overview_for_target(current_target)


func _refresh_social_overview_for_target(target: Dictionary) -> void:
	social_request_serial += 1
	var request_serial := social_request_serial
	social_state_loading = true
	_render_context_menu()
	var username := str(target.get("username", "")).strip_edges()
	if username == "":
		return
	var result: Dictionary = await _social_action("load_socials")
	if request_serial != social_request_serial or str(current_target.get("username", "")) != username:
		return
	if bool(result.get("success", false)):
		social_overview = _dictionary_from_value(result.get("overview", {}))
		social_state_loading = false
		social_status_message = ""
		social_status_is_error = false
		social_overview_updated.emit(social_overview.duplicate(true))
	else:
		social_state_loading = false
		social_status_message = str(result.get("error", "Could not refresh social state."))
		social_status_is_error = true
	_render_context_menu()


func close_players_panel() -> void:
	if players_panel != null:
		players_panel.visible = false


func close_context_menu() -> void:
	if context_menu != null:
		context_menu.visible = false
	current_target.clear()
	social_request_serial += 1
	social_action_in_flight = false
	social_state_loading = false
	social_status_message = ""
	social_status_is_error = false


func _current_map_players() -> Array[Dictionary]:
	var presence := get_node_or_null("/root/WorldPresenceService")
	if presence == null or not presence.has_method("get_current_map_players"):
		return []
	var roster_value: Variant = presence.call("get_current_map_players")
	var players: Array[Dictionary] = []
	if not roster_value is Array:
		return players
	for state_value: Variant in roster_value:
		var player := _normalized_player(_dictionary_from_value(state_value))
		if not player.is_empty() and not _is_self(player):
			players.append(player)
	players.sort_custom(_compare_players)
	return players


func _normalized_player(player: Dictionary) -> Dictionary:
	var user_id := int(player.get("userId", 0))
	var username := str(player.get("username", "")).strip_edges()
	if user_id <= 0 or username == "":
		return {}
	return player.duplicate(true)


func _is_self(player: Dictionary) -> bool:
	var auth := get_node_or_null("/root/AuthService")
	if auth == null:
		return false
	var current_user: Dictionary = _dictionary_from_value(auth.get("current_user"))
	return int(player.get("userId", 0)) == int(current_user.get("id", 0))


func _compare_players(first: Dictionary, second: Dictionary) -> bool:
	var first_name := str(first.get("displayName", first.get("username", ""))).to_lower()
	var second_name := str(second.get("displayName", second.get("username", ""))).to_lower()
	if first_name == second_name:
		return int(first.get("userId", 0)) < int(second.get("userId", 0))
	return first_name < second_name


func _target_is_on_current_map() -> bool:
	var target_id := int(current_target.get("userId", 0))
	for player: Dictionary in _current_map_players():
		if int(player.get("userId", 0)) == target_id:
			return true
	return false


func _is_friend(player: Dictionary) -> bool:
	return _overview_has_user("friends", player)


func _is_blocked(player: Dictionary) -> bool:
	return _overview_has_user("blockedUsers", player)


func _overview_has_user(key: String, player: Dictionary) -> bool:
	var target_id := int(player.get("userId", 0))
	var target_username := str(player.get("username", "")).to_lower()
	var values: Variant = social_overview.get(key, [])
	if not values is Array:
		return false
	for value: Variant in values:
		var entry := _dictionary_from_value(value)
		var user := _dictionary_from_value(entry.get("user", entry))
		if int(user.get("id", user.get("userId", 0))) == target_id:
			return true
		if str(user.get("username", "")).to_lower() == target_username:
			return true
	return false


func _player_display_name(player: Dictionary) -> String:
	var username := str(player.get("username", "")).strip_edges()
	var display_name := str(player.get("displayName", "")).strip_edges()
	return "%s (@%s)" % [display_name, username] if display_name != "" and display_name.to_lower() != username.to_lower() else (display_name if display_name != "" else username)


func _player_primary_name(player: Dictionary) -> String:
	var display_name := str(player.get("displayName", "")).strip_edges()
	var username := str(player.get("username", "")).strip_edges()
	return display_name if display_name != "" else username


func _player_initial(player: Dictionary) -> String:
	var display_name := _player_primary_name(player)
	return display_name.left(1).to_upper() if display_name != "" else "?"


func _position_panel(panel: Control, requested_position: Vector2) -> void:
	panel.reset_size()
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := panel.get_combined_minimum_size()
	panel.size = panel_size
	panel.position = Vector2(clampf(requested_position.x, VIEWPORT_MARGIN, maxf(VIEWPORT_MARGIN, viewport_size.x - panel_size.x - VIEWPORT_MARGIN)), clampf(requested_position.y, VIEWPORT_MARGIN, maxf(VIEWPORT_MARGIN, viewport_size.y - panel_size.y - VIEWPORT_MARGIN)))


func _focus_first_player_row() -> void:
	if players_list == null:
		return
	for child: Node in players_list.get_children():
		if child is Button:
			(child as Button).grab_focus()
			return


func _focus_first_context_action() -> void:
	if context_actions == null:
		return
	for child: Node in context_actions.get_children():
		if child is Button and not (child as Button).disabled:
			(child as Button).grab_focus()
			return


func _margin_container(amount: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", amount)
	margin.add_theme_constant_override("margin_top", amount)
	margin.add_theme_constant_override("margin_right", amount)
	margin.add_theme_constant_override("margin_bottom", amount)
	return margin


func _compact_close_button() -> Button:
	var button := Button.new()
	button.text = "×"
	button.tooltip_text = "Close"
	button.custom_minimum_size = Vector2(32, 32)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", UI_MUTED_TEXT)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_color_override("font_pressed_color", UI_TEXT)
	button.add_theme_stylebox_override("normal", _button_style(UI_SURFACE_INTERACTIVE, UI_BORDER_SUBTLE, 8))
	button.add_theme_stylebox_override("hover", _button_style(UI_SURFACE_HOVER, UI_BORDER_FOCUS, 8))
	button.add_theme_stylebox_override("pressed", _button_style(UI_SURFACE_PRESSED, UI_BORDER_FOCUS, 8))
	return button


func _context_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", UI_ACCENT)
	return label


func _context_action_button(label_text: String, description_text: String, variant: String) -> Button:
	var button := Button.new()
	button.set_meta("player_action", label_text)
	button.custom_minimum_size = Vector2(0, 50)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var normal_background := UI_SURFACE_INTERACTIVE
	var normal_border := UI_BORDER_SUBTLE
	var hover_border := UI_ACCENT_SOFT
	var title_color := UI_TEXT
	if variant == "danger":
		normal_background = Color("#241016e8")
		normal_border = Color("#7a2b33aa")
		hover_border = UI_DANGER
		title_color = Color("#ff9aa2")
	button.add_theme_stylebox_override("normal", _button_style(normal_background, normal_border, 8))
	button.add_theme_stylebox_override("hover", _button_style(UI_SURFACE_HOVER, hover_border, 8))
	button.add_theme_stylebox_override("pressed", _button_style(UI_SURFACE_PRESSED, hover_border, 8))
	button.add_theme_stylebox_override("focus", _button_style(UI_SURFACE_HOVER, UI_BORDER_FOCUS, 8))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 6)
	button.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_theme_constant_override("separation", 0)
	row.add_child(copy)
	var title := Label.new()
	title.text = label_text
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", title_color)
	copy.add_child(title)
	var description := Label.new()
	description.text = description_text
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description.add_theme_font_size_override("font_size", 9)
	description.add_theme_color_override("font_color", UI_MUTED_TEXT)
	copy.add_child(description)
	var chevron := Label.new()
	chevron.text = "›"
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron.add_theme_font_size_override("font_size", 18)
	chevron.add_theme_color_override("font_color", UI_MUTED_TEXT)
	row.add_child(chevron)
	return button


func _apply_player_row_style(button: Button) -> void:
	button.add_theme_stylebox_override(
		"normal",
		_button_style(UI_SURFACE_INTERACTIVE, UI_BORDER_SUBTLE, 9)
	)
	button.add_theme_stylebox_override(
		"hover",
		_button_style(UI_SURFACE_HOVER, UI_ACCENT_SOFT, 9)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_button_style(UI_SURFACE_PRESSED, UI_ACCENT, 9)
	)
	button.add_theme_stylebox_override(
		"focus",
		_button_style(UI_SURFACE_HOVER, UI_BORDER_FOCUS, 9)
	)


func _button_style(background: Color, border: Color, corner_radius: int) -> StyleBoxFlat:
	var style := _panel_style(background, border, corner_radius)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style


func _glass_panel_style(corner_radius: int) -> StyleBoxFlat:
	var style := _panel_style(UI_SURFACE_BASE, UI_BORDER_SUBTLE, corner_radius)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 9
	style.shadow_offset = Vector2(0, 4)
	return style


func _panel_style(background: Color, border: Color, corner_radius: int = 8, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	return style


func _clear_children(container: Node) -> void:
	for child: Node in container.get_children():
		child.queue_free()


func _dictionary_from_value(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	return value as Dictionary


func _social_action(method_name: String, username: String = "") -> Dictionary:
	var social_service := get_node_or_null("/root/SocialService")
	if social_service == null or not social_service.has_method(method_name):
		return {"success": false, "error": "Social service is unavailable."}
	var result: Variant = await social_service.call(method_name, username) if username != "" else await social_service.call(method_name)
	return _dictionary_from_value(result)
