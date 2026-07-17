extends Node

class_name PlayerInteractionCoordinator

const TradeInvitationDialogScript := preload("res://scripts/ui/trade_invitation_dialog.gd")

signal private_message_requested(user: Dictionary)
signal mail_requested(username: String)
signal trainer_card_requested(player: Dictionary)
signal social_overview_updated(overview: Dictionary)

const PANEL_WIDTH := 310.0
const CONTEXT_MENU_WIDTH := 216.0
const VIEWPORT_MARGIN := 12.0
const UI_BG := Color("#070b14f2")
const UI_SLOT_BG := Color("#0d1625e6")
const UI_BORDER := Color("#d8b767")
const UI_BORDER_SOFT := Color("#315070")
const UI_BORDER_FOCUS := Color("#7aa7f4")
const UI_TEXT := Color("#f4f0de")
const UI_MUTED_TEXT := Color("#aeb8c5")
const UI_DANGER := Color("#ff6b74")

var host: Control
var players_panel: PanelContainer
var players_list: VBoxContainer
var players_status_label: Label
var context_menu: PanelContainer
var context_title: Label
var context_status_label: Label
var context_actions: VBoxContainer
var current_target: Dictionary = {}
var social_overview: Dictionary = {}
var social_request_serial := 0
var social_action_in_flight := false
var social_state_loading := false
var trade_capabilities: Dictionary = {}
var trade_invitation_dialog: Window


func setup(host_control: Control) -> void:
	if host_control == null:
		return
	host = host_control
	add_to_group("player_interaction_coordinator")
	_build_ui()
	_setup_trade_invitation_dialog()
	_refresh_trade_capabilities()
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
	if trade_capabilities.is_empty():
		_refresh_trade_capabilities()
	social_overview.clear()
	social_state_loading = true
	close_players_panel()
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
	players_panel.z_index = 1000
	players_panel.add_theme_stylebox_override("panel", _panel_style(UI_BG, UI_BORDER))
	host.add_child(players_panel)
	var players_margin := _margin_container(12)
	players_panel.add_child(players_margin)
	var players_root := VBoxContainer.new()
	players_root.add_theme_constant_override("separation", 8)
	players_margin.add_child(players_root)
	var header := HBoxContainer.new()
	players_root.add_child(header)
	var title := Label.new()
	title.text = "Players on Map"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", UI_BORDER)
	title.add_theme_font_size_override("font_size", 18)
	header.add_child(title)
	var close_button := _button("Close", "default")
	close_button.pressed.connect(close_players_panel)
	header.add_child(close_button)
	players_status_label = Label.new()
	players_status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	players_status_label.add_theme_font_size_override("font_size", 13)
	players_root.add_child(players_status_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 260.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	players_root.add_child(scroll)
	players_list = VBoxContainer.new()
	players_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_list.add_theme_constant_override("separation", 6)
	scroll.add_child(players_list)

	context_menu = PanelContainer.new()
	context_menu.name = "PlayerContextMenu"
	context_menu.visible = false
	context_menu.custom_minimum_size = Vector2(CONTEXT_MENU_WIDTH, 0.0)
	context_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	context_menu.z_index = 1100
	context_menu.add_theme_stylebox_override("panel", _panel_style(UI_BG, UI_BORDER))
	host.add_child(context_menu)
	var context_margin := _margin_container(10)
	context_menu.add_child(context_margin)
	var context_root := VBoxContainer.new()
	context_root.add_theme_constant_override("separation", 7)
	context_margin.add_child(context_root)
	context_title = Label.new()
	context_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_title.add_theme_color_override("font_color", UI_TEXT)
	context_title.add_theme_font_size_override("font_size", 16)
	context_root.add_child(context_title)
	context_status_label = Label.new()
	context_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	context_status_label.add_theme_font_size_override("font_size", 12)
	context_root.add_child(context_status_label)
	context_root.add_child(HSeparator.new())
	context_actions = VBoxContainer.new()
	context_actions.add_theme_constant_override("separation", 5)
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
	players_status_label.text = "%d player%s nearby" % [players.size(), "" if players.size() == 1 else "s"]
	if players.is_empty():
		var empty := Label.new()
		empty.text = "No other players are on this map."
		empty.add_theme_color_override("font_color", UI_MUTED_TEXT)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		players_list.add_child(empty)
		return
	for player: Dictionary in players:
		var row := _button(_player_display_name(player), "default")
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.tooltip_text = "Open player actions"
		row.pressed.connect(_on_player_row_pressed.bind(player))
		players_list.add_child(row)


func _on_player_row_pressed(player: Dictionary) -> void:
	if players_panel == null:
		return
	open_context_for_player(player, players_panel.get_global_rect().position + Vector2(players_panel.size.x + 8.0, 34.0))


func _render_context_menu() -> void:
	if context_menu == null or current_target.is_empty():
		return
	context_title.text = _player_display_name(current_target)
	context_status_label.text = "Loading social state..." if social_state_loading else context_status_label.text
	_clear_children(context_actions)
	_add_context_action("View Trainer Card", _on_trainer_card_pressed)
	_add_context_action("Message", _on_message_pressed)
	_add_context_action("Send Mail", _on_mail_pressed)
	if bool(trade_capabilities.get("enabled", false)):
		_add_context_action("Trade", _on_trade_pressed)
	_add_context_action("Remove Friend" if _is_friend(current_target) else "Add Friend", _on_friend_pressed)
	_add_context_action("Unblock" if _is_blocked(current_target) else "Block", _on_block_pressed, "default" if _is_blocked(current_target) else "danger")
	_add_context_action("Close", close_context_menu)


func _add_context_action(label: String, action: Callable, variant: String = "default") -> void:
	var button := _button(label, variant)
	button.disabled = label not in ["View Trainer Card", "Message", "Send Mail", "Close"] and (social_action_in_flight or social_state_loading)
	button.pressed.connect(action)
	context_actions.add_child(button)


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
	var service := get_node_or_null("/root/TradeService")
	if service == null:
		return
	var result: Dictionary = await service.load_capabilities()
	trade_capabilities = result.get("capabilities", {}).duplicate(true) if bool(result.get("success", false)) else {}
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
		context_status_label.text = ""
		social_overview_updated.emit(social_overview.duplicate(true))
	else:
		social_state_loading = false
		context_status_label.text = str(result.get("error", "Action failed."))
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
		context_status_label.text = ""
		social_overview_updated.emit(social_overview.duplicate(true))
	else:
		social_state_loading = false
		context_status_label.text = str(result.get("error", "Could not refresh social state."))
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


func _button(label: String, variant: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0.0, 32.0)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal_background := UI_SLOT_BG
	var border := UI_BORDER_SOFT
	var hover_background := Color("#151f36f2")
	if variant == "danger":
		normal_background = Color("#2a1015e8")
		border = Color("#7a2b33")
		hover_background = Color("#3a151cee")
		button.add_theme_color_override("font_color", UI_DANGER)
	else:
		button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_color_override("font_pressed_color", UI_TEXT)
	button.add_theme_color_override("font_disabled_color", Color(UI_MUTED_TEXT.r, UI_MUTED_TEXT.g, UI_MUTED_TEXT.b, 0.45))
	button.add_theme_stylebox_override("normal", _panel_style(normal_background, border))
	button.add_theme_stylebox_override("hover", _panel_style(hover_background, UI_BORDER))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#080d18f2"), UI_BORDER_FOCUS))
	button.add_theme_stylebox_override("focus", _panel_style(normal_background, UI_BORDER_FOCUS))
	return button


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 9
	style.content_margin_top = 5
	style.content_margin_right = 9
	style.content_margin_bottom = 5
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
