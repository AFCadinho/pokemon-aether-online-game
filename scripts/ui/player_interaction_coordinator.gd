extends Node

class_name PlayerInteractionCoordinator

const TradeInvitationDialogScript := preload("res://scripts/ui/trade_invitation_dialog.gd")
const GuildInvitationDialogScript := preload("res://scripts/ui/guild_invitation_dialog.gd")
const AetherConfirmationDialogScene := preload("res://scenes/interface/aether_confirmation_dialog.tscn")
const NEARBY_TRAINERS_ICON: Texture2D = preload("res://assets/ui/socials_nearby.svg")
const GUILD_INVITATION_POLL_SECONDS := 10.0

signal private_message_requested(user: Dictionary)
signal mail_requested(username: String)
signal trainer_card_requested(player: Dictionary)
signal chat_moderation_requested(action: String, player: Dictionary)
signal social_overview_updated(overview: Dictionary)

const CHAT_MUTE_PERMISSION := "chat:mute"

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
var context_more_actions_expanded := false
var context_requested_position := Vector2.ZERO
var context_layout_serial := 0
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
var guild_invitation_dialog: Window
var guild_invitation_poll_timer: Timer
var guild_invitation_poll_in_flight := false
var guild_membership: Dictionary = {}
var guild_membership_loaded := false
var guild_membership_loading := false
var guild_members: Array[Dictionary] = []
var guild_members_loaded := false
var guild_members_loading := false
var guild_action_in_flight := false
var guild_status_message := ""
var guild_status_is_error := false
var aether_clash_action_in_flight := false
var aether_clash_status_message := ""
var aether_clash_status_is_error := false
var chat_moderation_state_loading := false
var chat_target_is_muted := false


func setup(host_control: Control) -> void:
	if host_control == null:
		return
	host = host_control
	add_to_group("player_interaction_coordinator")
	_build_ui()
	_setup_trade_invitation_dialog()
	_setup_guild_invitation_dialog()
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		var locale_callable := Callable(self, "_on_locale_changed")
		if not localization_manager.is_connected("locale_changed", locale_callable):
			localization_manager.connect("locale_changed", locale_callable)
	var presence := get_node_or_null("/root/WorldPresenceService")
	if presence != null and presence.has_signal("roster_changed"):
		var roster_callable := Callable(self, "_on_roster_changed")
		if not presence.roster_changed.is_connected(roster_callable):
			presence.roster_changed.connect(roster_callable)
	var guild_service := get_node_or_null("/root/GuildService")
	if guild_service != null:
		var membership_callable := Callable(self, "_on_guild_membership_changed")
		if guild_service.has_signal("membership_changed") and not guild_service.membership_changed.is_connected(membership_callable):
			guild_service.membership_changed.connect(membership_callable)
		if bool(guild_service.get("membership_loaded")):
			_on_guild_membership_changed(
				_dictionary_from_value(guild_service.get("current_membership"))
			)


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
	if not guild_membership_loaded and not guild_membership_loading:
		_refresh_guild_membership()
	elif _has_guild_invite_permission() and not guild_members_loading:
		# Membership can change without changing the local player's own Guild state.
		# Hide the action until a fresh authoritative roster confirms the target is eligible.
		guild_members_loaded = false
		_refresh_guild_members()
	social_overview.clear()
	social_state_loading = true
	social_status_message = ""
	social_status_is_error = false
	context_more_actions_expanded = false
	chat_moderation_state_loading = _can_moderate_chat()
	chat_target_is_muted = false
	context_requested_position = screen_position + Vector2(10.0, 10.0)
	context_menu.visible = true
	_render_context_menu()
	_position_panel(context_menu, context_requested_position)
	context_menu.move_to_front()
	_focus_first_context_action()
	_refresh_social_overview_for_target(normalized)
	if chat_moderation_state_loading:
		_refresh_chat_moderation_state.call_deferred(normalized)


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
	_set_localized_property(title, "text", "ui.nearby.title")
	title.add_theme_color_override("font_color", UI_TEXT)
	title.add_theme_font_size_override("font_size", 19)
	heading.add_child(title)
	var subtitle := Label.new()
	_set_localized_property(subtitle, "text", "ui.nearby.subtitle")
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
	_set_localized_property(roster_caption, "text", "ui.nearby.roster")
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
	_set_localized_property(roster_hint, "text", "ui.nearby.hint")
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
	players_status_label.text = _t("ui.nearby.count", {"count": players.size()})
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
	row.tooltip_text = _t("ui.nearby.open_actions", {
		"trainer": _player_primary_name(player),
	})
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
	nearby_label.text = _t("ui.nearby.badge")
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
	title.text = _t("ui.nearby.empty.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", UI_TEXT)
	stack.add_child(title)
	var description := Label.new()
	description.text = _t("ui.nearby.empty.description")
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
	# Keep the default right-click card focused on the two actions trainers use
	# most. Everything else stays one deliberate click away.
	_add_context_action("Message", _t("ui.nearby.action.message.description"), _on_message_pressed)
	var trade_enabled := bool(trade_capabilities.get("enabled", false))
	_add_context_action(
		"Trade",
		_trade_action_description(trade_enabled),
		_on_trade_pressed,
		"default",
		trade_capabilities_loading or (trade_capabilities_loaded and not trade_enabled)
	)
	_add_context_action(
		"Lend",
		_t("ui.nearby.action.lend.description"),
		_on_lend_pressed,
		"default",
		not _target_is_on_current_map()
	)
	if _can_challenge_aether_clash():
		_add_context_action(
			"Challenge to Aether Clash",
			_t("ui.nearby.action.aether_clash.description"),
			_on_aether_clash_challenge_pressed,
			"default",
			aether_clash_action_in_flight
		)
	_add_context_more_actions_toggle()
	if context_more_actions_expanded:
		context_actions.add_child(_context_section_label(_t("ui.nearby.more_actions")))
		_add_context_action(
			"View Trainer Card",
			_t("ui.nearby.action.trainer_card.description"),
			_on_trainer_card_pressed
		)
		_add_context_action(
			"Send Mail",
			_t("ui.nearby.action.mail.description"),
			_on_mail_pressed
		)
		if _can_invite_to_guild():
			_add_context_action(
				"Invite to Guild",
				_t("ui.nearby.action.guild.description"),
				_on_guild_invite_pressed,
				"default",
				guild_action_in_flight
			)
		_add_context_action(
			"Remove Friend" if _is_friend(current_target) else "Add Friend",
			_t("ui.nearby.action.friend.description"),
			_on_friend_pressed
		)
		_add_context_action(
			"Unblock" if _is_blocked(current_target) else "Block",
			_t(
				"ui.nearby.action.unblock.description"
				if _is_blocked(current_target)
				else "ui.nearby.action.block.description"
			),
			_on_block_pressed,
			"default" if _is_blocked(current_target) else "danger"
		)
		if _can_moderate_chat():
			_add_context_action(
				"Unmute Player" if chat_target_is_muted else "Mute Player",
				_t(
					"ui.nearby.action.unmute_player.description"
					if chat_target_is_muted
					else "ui.nearby.action.mute_player.description"
				),
				_on_chat_moderation_pressed,
				"default" if chat_target_is_muted else "danger"
			)
	_schedule_context_menu_content_fit()


func _add_context_more_actions_toggle() -> void:
	var button := Button.new()
	button.set_meta("player_action", "More actions")
	button.text = _t("ui.nearby.more_actions_toggle", {
		"indicator": "▴" if context_more_actions_expanded else "▾",
	})
	button.tooltip_text = _t("ui.nearby.more_actions_tooltip")
	button.custom_minimum_size = Vector2(0, 34)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", UI_ACCENT)
	button.add_theme_stylebox_override("normal", _button_style(UI_SURFACE_INSET, UI_BORDER_SUBTLE, 8))
	button.add_theme_stylebox_override("hover", _button_style(UI_SURFACE_HOVER, UI_ACCENT_SOFT, 8))
	button.add_theme_stylebox_override("pressed", _button_style(UI_SURFACE_PRESSED, UI_BORDER_FOCUS, 8))
	button.pressed.connect(_toggle_context_more_actions)
	context_actions.add_child(button)


func _toggle_context_more_actions() -> void:
	context_more_actions_expanded = not context_more_actions_expanded
	context_requested_position = context_menu.position
	_render_context_menu()


func _schedule_context_menu_content_fit() -> void:
	context_layout_serial += 1
	_fit_context_menu_to_content.call_deferred(context_layout_serial)


func _fit_context_menu_to_content(layout_serial: int) -> void:
	# Container minimum sizes update during the layout pass. Wait for it before
	# reading the height, otherwise a first-open menu can retain a stale height.
	await get_tree().process_frame
	if layout_serial != context_layout_serial or context_menu == null or not context_menu.visible:
		return
	context_menu.reset_size()
	_position_panel(context_menu, context_requested_position)
	context_menu.move_to_front()


func _refresh_context_status() -> void:
	if context_status_label == null:
		return
	if social_state_loading:
		context_status_label.text = _t("ui.nearby.status.checking_social")
		context_status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
		return
	if social_action_in_flight:
		context_status_label.text = _t("ui.nearby.status.updating_social")
		context_status_label.add_theme_color_override("font_color", UI_ACCENT)
		return
	if guild_action_in_flight:
		context_status_label.text = _t("ui.nearby.status.sending_guild")
		context_status_label.add_theme_color_override("font_color", UI_ACCENT)
		return
	if aether_clash_action_in_flight:
		context_status_label.text = _t("ui.nearby.status.sending_aether_clash")
		context_status_label.add_theme_color_override("font_color", UI_ACCENT)
		return
	if aether_clash_status_message != "":
		context_status_label.text = aether_clash_status_message
		context_status_label.add_theme_color_override(
			"font_color",
			UI_DANGER if aether_clash_status_is_error else Color("#6fe49a")
		)
		return
	if guild_status_message != "":
		context_status_label.text = guild_status_message
		context_status_label.add_theme_color_override(
			"font_color",
			UI_DANGER if guild_status_is_error else Color("#6fe49a")
		)
		return
	if social_status_message != "":
		context_status_label.text = social_status_message
		context_status_label.add_theme_color_override(
			"font_color",
			UI_DANGER if social_status_is_error else UI_MUTED_TEXT
		)
		return
	if _is_blocked(current_target):
		context_status_label.text = _t("ui.nearby.status.blocked")
		context_status_label.add_theme_color_override("font_color", UI_DANGER)
	elif _is_friend(current_target):
		context_status_label.text = _t("ui.nearby.status.friend")
		context_status_label.add_theme_color_override("font_color", Color("#6fe49a"))
	else:
		context_status_label.text = _t("ui.nearby.status.active")
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
			label not in [
				"View Trainer Card",
				"Message",
				"Send Mail",
				"Mute Player",
				"Unmute Player",
				"Challenge to Aether Clash",
			]
			and (social_action_in_flight or social_state_loading)
		)
	)
	button.pressed.connect(action)
	context_actions.add_child(button)

func _trade_action_description(trade_enabled: bool) -> String:
	if trade_enabled:
		return _t("ui.nearby.action.trade.description")
	if trade_capabilities_loading:
		return _t("ui.nearby.action.trade.checking")
	if trade_capabilities_error != "":
		return _t("ui.nearby.action.trade.retry")
	if trade_capabilities_loaded:
		return _t("ui.nearby.action.trade.unavailable")
	return _t("ui.nearby.action.trade.check")


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


func _on_chat_moderation_pressed() -> void:
	if current_target.is_empty() or not _can_moderate_chat():
		return
	var action := "unmute" if chat_target_is_muted else "mute"
	chat_moderation_requested.emit(
		action,
		current_target.duplicate(true)
	)
	close_context_menu()


func _refresh_chat_moderation_state(target: Dictionary) -> void:
	var target_id := int(target.get("userId", 0))
	if target_id <= 0 or not _can_moderate_chat():
		chat_moderation_state_loading = false
		return
	var moderation_service := get_node_or_null("/root/ChatModerationService")
	if moderation_service == null or not moderation_service.has_method("get_mute_state"):
		chat_moderation_state_loading = false
		_render_context_menu()
		return
	var result := _dictionary_from_value(
		await moderation_service.call("get_mute_state", target_id)
	)
	if current_target.is_empty() or int(current_target.get("userId", 0)) != target_id:
		return
	chat_moderation_state_loading = false
	if bool(result.get("success", false)):
		var state := _dictionary_from_value(result.get("body", {}))
		chat_target_is_muted = bool(state.get("muted", false))
	_render_context_menu()


func _can_moderate_chat() -> bool:
	var auth := get_node_or_null("/root/AuthService")
	if auth == null:
		return false
	var current_user := _dictionary_from_value(auth.get("current_user"))
	var permissions: Variant = current_user.get("permissions", [])
	if permissions is Array:
		for value: Variant in permissions:
			if str(value).strip_edges().to_lower() == CHAT_MUTE_PERMISSION:
				return true
	var roles: Variant = current_user.get("roles", [])
	if roles is Array:
		for value: Variant in roles:
			var role_id := (
				str((value as Dictionary).get("id", ""))
				if value is Dictionary
				else str(value)
			).strip_edges().to_lower()
			if role_id == "owner":
				return true
	return false


func can_moderate_chat() -> bool:
	return _can_moderate_chat()


func _on_trade_pressed() -> void:
	if not bool(trade_capabilities.get("enabled", false)):
		_refresh_trade_capabilities()
		return
	var username := str(current_target.get("username", "")).strip_edges()
	if username == "" or trade_invitation_dialog == null:
		return
	close_context_menu()
	trade_invitation_dialog.send_invitation(username)


func _on_lend_pressed() -> void:
	if not _target_is_on_current_map():
		return
	var username := str(current_target.get("username", "")).strip_edges()
	var workspace := get_node_or_null("/root/LendingWorkspace")
	if username == "" or workspace == null or not workspace.has_method("open_for_trainer"):
		return
	close_context_menu()
	workspace.call("open_for_trainer", username)


func _setup_trade_invitation_dialog() -> void:
	if host == null or trade_invitation_dialog != null:
		return
	trade_invitation_dialog = TradeInvitationDialogScript.new()
	host.add_child(trade_invitation_dialog)
	trade_invitation_dialog.setup()


func _setup_guild_invitation_dialog() -> void:
	if host == null or guild_invitation_dialog != null:
		return
	guild_invitation_dialog = GuildInvitationDialogScript.new()
	host.add_child(guild_invitation_dialog)
	guild_invitation_dialog.setup()
	guild_invitation_poll_timer = Timer.new()
	guild_invitation_poll_timer.wait_time = GUILD_INVITATION_POLL_SECONDS
	guild_invitation_poll_timer.one_shot = false
	guild_invitation_poll_timer.timeout.connect(_poll_guild_invitations)
	add_child(guild_invitation_poll_timer)
	guild_invitation_poll_timer.start()
	_poll_guild_invitations.call_deferred()


func _poll_guild_invitations() -> void:
	if guild_invitation_poll_in_flight or guild_invitation_dialog == null:
		return
	var auth := get_node_or_null("/root/AuthService")
	if auth == null or not auth.has_method("is_authenticated") or not bool(auth.is_authenticated()):
		return
	var service := get_node_or_null("/root/GuildService")
	if service == null or not service.has_method("load_invitations"):
		return
	if bool(service.get("membership_loaded")) and not _dictionary_from_value(
		service.get("current_membership")
	).is_empty():
		guild_invitation_dialog.show_invitations([])
		return
	guild_invitation_poll_in_flight = true
	var result: Dictionary = await service.load_invitations()
	guild_invitation_poll_in_flight = false
	if bool(result.get("success", false)) and is_instance_valid(guild_invitation_dialog):
		guild_invitation_dialog.show_invitations(result.get("invitations", []))


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


func _refresh_guild_membership() -> void:
	if guild_membership_loading:
		return
	var service := get_node_or_null("/root/GuildService")
	if service == null:
		guild_membership.clear()
		guild_membership_loaded = false
		return
	guild_membership_loading = true
	var result: Dictionary = await service.load_directory()
	guild_membership_loading = false
	guild_membership_loaded = bool(result.get("success", false))
	guild_membership = (
		_dictionary_from_value(result.get("membership", {}))
		if guild_membership_loaded
		else {}
	)
	if context_menu != null and context_menu.visible:
		_render_context_menu()


func _on_guild_membership_changed(membership: Dictionary) -> void:
	var previous_guild_id := int(guild_membership.get("guildId", 0))
	guild_membership = membership.duplicate(true)
	guild_membership_loaded = true
	guild_membership_loading = false
	if previous_guild_id != int(guild_membership.get("guildId", 0)):
		guild_members.clear()
		guild_members_loaded = false
	if _has_guild_invite_permission() and not guild_members_loaded and not guild_members_loading:
		_refresh_guild_members.call_deferred()
	if guild_invitation_poll_timer != null:
		if guild_membership.is_empty():
			if guild_invitation_poll_timer.is_stopped():
				guild_invitation_poll_timer.start()
			_poll_guild_invitations.call_deferred()
		else:
			guild_invitation_poll_timer.stop()
			if guild_invitation_dialog != null:
				guild_invitation_dialog.show_invitations([])
	if context_menu != null and context_menu.visible:
		_render_context_menu()


func _refresh_guild_members() -> void:
	if guild_members_loading or not _has_guild_invite_permission():
		return
	var service := get_node_or_null("/root/GuildService")
	if service == null:
		guild_members.clear()
		guild_members_loaded = false
		return
	guild_members_loading = true
	var result: Dictionary = await service.load_home()
	guild_members_loading = false
	guild_members_loaded = bool(result.get("success", false))
	guild_members.clear()
	if guild_members_loaded:
		for value: Variant in result.get("members", []):
			if value is Dictionary:
				guild_members.append((value as Dictionary).duplicate(true))
	if context_menu != null and context_menu.visible:
		_render_context_menu()


func _has_guild_invite_permission() -> bool:
	var permissions: Variant = guild_membership.get("permissions", [])
	if permissions is Array and (permissions as Array).has("manage_members"):
		return true
	return str(guild_membership.get("role", "")).to_lower() in ["leader", "captain", "officer"]


func _target_is_current_guild_member() -> bool:
	var target_user_id := int(current_target.get("userId", 0))
	var target_username := str(current_target.get("username", "")).strip_edges().to_lower()
	for member: Dictionary in guild_members:
		if target_user_id > 0 and int(member.get("userId", member.get("id", 0))) == target_user_id:
			return true
		if target_username != "" and str(member.get("username", "")).strip_edges().to_lower() == target_username:
			return true
	return false


func _can_invite_to_guild() -> bool:
	return (
		_has_guild_invite_permission()
		and guild_members_loaded
		and not _target_is_current_guild_member()
	)


func _on_guild_invite_pressed() -> void:
	if current_target.is_empty() or guild_action_in_flight or not _can_invite_to_guild():
		return
	var username := str(current_target.get("username", "")).strip_edges()
	var service := get_node_or_null("/root/GuildService")
	if username == "" or service == null:
		return
	guild_action_in_flight = true
	guild_status_message = ""
	guild_status_is_error = false
	_render_context_menu()
	var result: Dictionary = await service.invite_member(username)
	guild_action_in_flight = false
	guild_status_is_error = not bool(result.get("success", false))
	guild_status_message = (
		_t("ui.nearby.status.guild_sent", {"username": username})
		if not guild_status_is_error
		else str(result.get("error", _t("ui.nearby.error.guild_invite")))
	)
	if context_menu != null and context_menu.visible:
		_render_context_menu()


func _can_challenge_aether_clash() -> bool:
	if not guild_membership_loaded or guild_membership.is_empty():
		return false
	var permissions: Variant = guild_membership.get("permissions", [])
	if permissions is Array and (permissions as Array).has("challenge_aether_clash"):
		return true
	return str(guild_membership.get("role", "")).to_lower() in ["leader", "captain", "officer"]


func _on_aether_clash_challenge_pressed() -> void:
	if current_target.is_empty() or aether_clash_action_in_flight or not _can_challenge_aether_clash():
		return
	var target_user_id := int(current_target.get("userId", 0))
	if target_user_id <= 0 or host == null:
		return
	var target_name := _player_primary_name(current_target)
	var dialog := AetherConfirmationDialogScene.instantiate() as AetherConfirmationDialog
	dialog.name = "AetherClashPlayerChallengeDialog"
	host.add_child(dialog)
	dialog.configure(
		_t("ui.guild.aether_clash.challenge_title"),
		_t("ui.nearby.aether_clash.challenge_confirm", {
			"trainer": target_name,
		}),
		_t("ui.guild.aether_clash.challenge"),
		_t("common.cancel")
	)
	var spectator_access := OptionButton.new()
	spectator_access.name = "AetherClashPlayerSpectatorAccess"
	spectator_access.custom_minimum_size = Vector2(0, 42)
	spectator_access.add_item(_t("ui.guild.aether_clash.spectators.public"))
	spectator_access.set_item_metadata(0, "public")
	spectator_access.add_item(_t("ui.guild.aether_clash.spectators.guilds_only"))
	spectator_access.set_item_metadata(1, "guilds_only")
	dialog.style_option_button(spectator_access)
	dialog.add_custom_control(spectator_access)
	dialog.confirmed.connect(
		_send_aether_clash_player_challenge.bind(
			target_user_id,
			spectator_access
		),
		CONNECT_ONE_SHOT
	)
	dialog.confirmed.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	dialog.canceled.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	dialog.popup_centered(Vector2i(540, 330))


func _send_aether_clash_player_challenge(
	target_user_id: int,
	spectator_access_selector: OptionButton
) -> void:
	if aether_clash_action_in_flight:
		return
	var spectator_access := "public"
	if spectator_access_selector != null and spectator_access_selector.selected >= 0:
		spectator_access = str(spectator_access_selector.get_item_metadata(
			spectator_access_selector.selected
		))
	aether_clash_action_in_flight = true
	aether_clash_status_message = ""
	aether_clash_status_is_error = false
	_render_context_menu()
	var service := get_node_or_null("/root/GuildService")
	var result: Dictionary = {}
	if service != null and service.has_method("create_aether_clash_player_challenge"):
		result = _dictionary_from_value(await service.call(
			"create_aether_clash_player_challenge",
			target_user_id,
			spectator_access
		))
	else:
		result = {
			"success": false,
			"error": _t("ui.guild.error.service_unavailable"),
		}
	aether_clash_action_in_flight = false
	aether_clash_status_is_error = not bool(result.get("success", false))
	aether_clash_status_message = (
		_t("ui.guild.aether_clash.challenge_sent")
		if not aether_clash_status_is_error
		else str(result.get("error", _t("ui.guild.aether_clash.action_error")))
	)
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
		social_status_message = str(result.get("error", _t("ui.friends.error.action")))
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
		social_status_message = str(result.get("error", _t("ui.nearby.error.refresh_social")))
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
	guild_action_in_flight = false
	guild_status_message = ""
	guild_status_is_error = false
	aether_clash_action_in_flight = false
	aether_clash_status_message = ""
	aether_clash_status_is_error = false


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
	button.tooltip_text = _t("common.close")
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
	title.text = _t(_context_action_label_key(label_text))
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

func _context_action_label_key(label_text: String) -> String:
	return str({
		"Message": "ui.nearby.action.message",
		"Trade": "ui.nearby.action.trade",
		"Lend": "ui.nearby.action.lend",
		"View Trainer Card": "ui.nearby.action.trainer_card",
		"Send Mail": "ui.nearby.action.mail",
		"Invite to Guild": "ui.nearby.action.guild",
		"Challenge to Aether Clash": "ui.nearby.action.aether_clash",
		"Remove Friend": "ui.nearby.action.remove_friend",
		"Add Friend": "ui.nearby.action.add_friend",
		"Unblock": "ui.nearby.action.unblock",
		"Block": "ui.nearby.action.block",
		"Mute Player": "ui.nearby.action.mute_player",
		"Unmute Player": "ui.nearby.action.unmute_player",
	}.get(label_text, label_text))

func _on_locale_changed(_locale: String) -> void:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		if players_panel != null:
			localization_manager.call("localize_tree", players_panel)
		if context_menu != null:
			localization_manager.call("localize_tree", context_menu)
	social_status_message = ""
	guild_status_message = ""
	aether_clash_status_message = ""
	_render_players()
	if not current_target.is_empty():
		_render_context_menu()

func _set_localized_property(control: Control, property_name: String, key: String) -> void:
	control.set_meta("i18n_source_%s" % property_name, key)
	control.set(property_name, _t(key))

func _t(key: String, values: Dictionary = {}) -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager == null:
		return key
	return str(localization_manager.call("text", key, values))


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
		return {"success": false, "error": _t("ui.nearby.error.social_unavailable")}
	var result: Variant = await social_service.call(method_name, username) if username != "" else await social_service.call(method_name)
	return _dictionary_from_value(result)
