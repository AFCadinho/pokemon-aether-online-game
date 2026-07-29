extends Window

class_name GuildInvitationDialog

signal invitation_resolved(action: String, invitation: Dictionary)

const DIALOG_SIZE := Vector2i(510, 300)
const GUILD_ICON: Texture2D = preload("res://assets/ui/guild.svg")
const UI_BG := Color("#050912fa")
const UI_SURFACE_RAISED := Color("#0b1a2bf7")
const UI_BORDER := Color("#4f4935cc")
const UI_ACCENT := Color("#e3bd68")
const UI_TEXT := Color("#f4f0de")
const UI_MUTED := Color("#aeb8c5")
const UI_DANGER := Color("#ff6b74")

var invitations: Array[Dictionary] = []
var invitation: Dictionary = {}
var notified_invitation_ids: Dictionary = {}
var action_in_flight := false

var position_label: Label
var heading_label: Label
var status_label: Label
var accept_button: Button
var decline_button: Button


func setup() -> void:
	hide()
	title = _t("ui.guild.invitation.title")
	min_size = DIALOG_SIZE
	max_size = DIALOG_SIZE
	unresizable = true
	borderless = true

	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_theme_stylebox_override("panel", _outer_style())
	add_child(background)

	var margin := MarginContainer.new()
	_set_margins(margin, 16, 15, 16, 15)
	background.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 46)
	header.add_theme_constant_override("separation", 11)
	root.add_child(header)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(44, 44)
	icon_frame.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#e3bd681f"), Color("#e3bd6888"), 9, 1)
	)
	header.add_child(icon_frame)

	var icon_margin := MarginContainer.new()
	_set_margins(icon_margin, 6, 6, 6, 6)
	icon_frame.add_child(icon_margin)

	var icon := TextureRect.new()
	icon.texture = GUILD_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_margin.add_child(icon)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	title_stack.add_theme_constant_override("separation", 0)
	header.add_child(title_stack)

	var window_title := Label.new()
	_set_localized_property(window_title, "text", "ui.guild.invitation.title")
	window_title.add_theme_color_override("font_color", UI_TEXT)
	window_title.add_theme_font_size_override("font_size", 19)
	title_stack.add_child(window_title)

	var window_subtitle := Label.new()
	_set_localized_property(window_subtitle, "text", "ui.guild.invitation.subtitle")
	window_subtitle.add_theme_color_override("font_color", UI_MUTED)
	window_subtitle.add_theme_font_size_override("font_size", 11)
	title_stack.add_child(window_subtitle)

	var close_button := Button.new()
	close_button.name = "DeclineGuildInvitationCloseButton"
	close_button.text = "×"
	_set_localized_property(close_button, "tooltip_text", "ui.guild.invitation.decline_tooltip")
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.custom_minimum_size = Vector2(36, 34)
	close_button.add_theme_color_override("font_color", UI_MUTED)
	close_button.add_theme_color_override("font_hover_color", Color.WHITE)
	close_button.add_theme_stylebox_override(
		"normal",
		_panel_style(Color("#07111ed8"), UI_BORDER, 7, 1)
	)
	close_button.add_theme_stylebox_override(
		"hover",
		_panel_style(Color("#2a1015"), Color("#b84c58"), 7, 1)
	)
	close_button.pressed.connect(_decline)
	header.add_child(close_button)

	var content_panel := PanelContainer.new()
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(UI_SURFACE_RAISED, UI_BORDER, 9, 1)
	)
	root.add_child(content_panel)

	var content_margin := MarginContainer.new()
	_set_margins(content_margin, 15, 13, 15, 13)
	content_panel.add_child(content_margin)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 6)
	content_margin.add_child(stack)

	position_label = Label.new()
	position_label.name = "GuildInvitationPosition"
	position_label.add_theme_color_override("font_color", UI_ACCENT)
	position_label.add_theme_font_size_override("font_size", 10)
	stack.add_child(position_label)

	heading_label = Label.new()
	heading_label.name = "GuildInvitationHeading"
	heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading_label.add_theme_color_override("font_color", UI_TEXT)
	heading_label.add_theme_font_size_override("font_size", 18)
	stack.add_child(heading_label)

	status_label = Label.new()
	status_label.name = "GuildInvitationStatus"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", UI_MUTED)
	stack.add_child(status_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	root.add_child(actions)

	var action_spacer := Control.new()
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(action_spacer)

	decline_button = Button.new()
	decline_button.name = "DeclineGuildInvitationDialogButton"
	_set_localized_property(decline_button, "text", "common.decline")
	decline_button.custom_minimum_size = Vector2(112, 38)
	decline_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	decline_button.pressed.connect(_decline)
	_style_button(decline_button, "secondary")
	actions.add_child(decline_button)

	accept_button = Button.new()
	accept_button.name = "AcceptGuildInvitationDialogButton"
	_set_localized_property(accept_button, "text", "common.accept")
	accept_button.custom_minimum_size = Vector2(132, 38)
	accept_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	accept_button.pressed.connect(_accept)
	_style_button(accept_button, "primary")
	actions.add_child(accept_button)

	close_requested.connect(_decline)
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		var locale_callable := Callable(self, "_on_locale_changed")
		if not localization_manager.is_connected("locale_changed", locale_callable):
			localization_manager.connect("locale_changed", locale_callable)


func show_invitations(values: Array) -> void:
	if action_in_flight:
		return
	invitations.clear()
	for value: Variant in values:
		if not value is Dictionary:
			continue
		var candidate := (value as Dictionary).duplicate(true)
		if int(candidate.get("id", 0)) > 0 and str(candidate.get("status", "pending")) == "pending":
			invitations.append(candidate)
	if invitations.is_empty():
		invitation.clear()
		hide()
		return
	invitation = invitations[0].duplicate(true)
	_render_invitation()


func _render_invitation() -> void:
	if invitation.is_empty():
		hide()
		return
	var guild_name := str(invitation.get("guildName", _t("ui.guild.fallback.guild"))).strip_edges()
	var inviter_name := str(invitation.get("invitedBy", _t("ui.guild.fallback.member"))).strip_edges()
	position_label.text = (
		_t("ui.guild.invitation.incoming")
		if invitations.size() == 1
		else _t("ui.guild.invitation.position", {"current": 1, "total": invitations.size()})
	)
	heading_label.text = _t("ui.guild.invitation.join", {"guild": guild_name})
	status_label.text = _t("ui.guild.invitation.invited_by", {"inviter": inviter_name})
	status_label.add_theme_color_override("font_color", UI_MUTED)
	_set_action_in_flight(false)
	_notify_once(invitation)
	size = DIALOG_SIZE
	popup_centered(DIALOG_SIZE)


func _accept() -> void:
	if action_in_flight or invitation.is_empty():
		return
	var service := get_node_or_null("/root/GuildService")
	if service == null:
		_show_error(_t("ui.guild.error.service_unavailable"))
		return
	_set_action_in_flight(true)
	var resolved_invitation := invitation.duplicate(true)
	var result: Dictionary = await service.accept_invitation(int(invitation.get("id", 0)))
	if not bool(result.get("success", false)):
		_set_action_in_flight(false)
		_show_error(str(result.get("error", _t("ui.guild.error.accept_invitation"))))
		return
	_set_action_in_flight(false)
	invitations.clear()
	invitation.clear()
	hide()
	_add_system_message(_t("ui.guild.invitation.joined", {
		"guild": str(resolved_invitation.get("guildName", _t("ui.guild.fallback.the_guild"))),
	}))
	invitation_resolved.emit("accepted", resolved_invitation)


func _decline() -> void:
	if action_in_flight or invitation.is_empty():
		return
	var service := get_node_or_null("/root/GuildService")
	if service == null:
		_show_error(_t("ui.guild.error.service_unavailable"))
		return
	_set_action_in_flight(true)
	var resolved_invitation := invitation.duplicate(true)
	var invitation_id := int(invitation.get("id", 0))
	var result: Dictionary = await service.decline_invitation(invitation_id)
	if not bool(result.get("success", false)):
		_set_action_in_flight(false)
		_show_error(str(result.get("error", _t("ui.guild.error.decline_invitation"))))
		return
	var remaining: Array[Dictionary] = []
	for value: Dictionary in invitations:
		if int(value.get("id", 0)) != invitation_id:
			remaining.append(value)
	invitations = remaining
	invitation_resolved.emit("declined", resolved_invitation)
	if invitations.is_empty():
		_set_action_in_flight(false)
		invitation.clear()
		hide()
		return
	invitation = invitations[0].duplicate(true)
	_render_invitation()


func _set_action_in_flight(value: bool) -> void:
	action_in_flight = value
	accept_button.disabled = value
	decline_button.disabled = value
	if value:
		status_label.text = _t("ui.guild.invitation.updating")
		status_label.add_theme_color_override("font_color", UI_MUTED)


func _show_error(message: String) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", UI_DANGER)


func _notify_once(value: Dictionary) -> void:
	var invitation_id := int(value.get("id", 0))
	if invitation_id <= 0 or notified_invitation_ids.has(invitation_id):
		return
	notified_invitation_ids[invitation_id] = true
	_add_system_message(
		_t("ui.guild.invitation.received", {
			"inviter": str(value.get("invitedBy", _t("ui.guild.fallback.member_lower"))),
			"guild": str(value.get("guildName", _t("ui.guild.fallback.guild_lower"))),
		})
	)


func _on_locale_changed(_locale: String) -> void:
	title = _t("ui.guild.invitation.title")
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		localization_manager.call("localize_tree", self)
	if not invitation.is_empty() and not action_in_flight:
		_render_invitation()


func _set_localized_property(control: Control, property_name: String, key: String) -> void:
	control.set_meta("i18n_source_%s" % property_name, key)
	control.set(property_name, _t(key))


func _t(key: String, values: Dictionary = {}) -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager == null:
		return key.format(values)
	return str(localization_manager.call("text", key, values))


func _add_system_message(message: String) -> void:
	var overlay := get_tree().get_first_node_in_group("ui_overlay")
	if overlay != null and overlay.has_method("add_system_message"):
		overlay.call("add_system_message", message)


func _panel_style(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


func _outer_style() -> StyleBoxFlat:
	var style := _panel_style(UI_BG, Color("#e3bd6899"), 12, 1)
	style.border_width_top = 2
	style.shadow_color = Color("#00000099")
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 7)
	return style


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := _panel_style(background, border, 7, 1)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _style_button(button: Button, variant: String) -> void:
	if variant == "primary":
		button.add_theme_color_override("font_color", Color("#061019"))
		button.add_theme_color_override("font_hover_color", Color("#061019"))
		button.add_theme_color_override("font_pressed_color", Color("#061019"))
		button.add_theme_stylebox_override("normal", _button_style(UI_ACCENT, Color("#f0d58f")))
		button.add_theme_stylebox_override("hover", _button_style(Color("#f0d58f"), Color("#ffeab3")))
		button.add_theme_stylebox_override("pressed", _button_style(Color("#cda550"), Color("#f0d58f")))
	else:
		button.add_theme_color_override("font_color", UI_TEXT)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", _button_style(Color("#07111ed8"), UI_BORDER))
		button.add_theme_stylebox_override("hover", _button_style(Color("#122337f2"), Color("#6c6680")))
		button.add_theme_stylebox_override("pressed", _button_style(Color("#050b13f2"), UI_BORDER))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#08101aa8"), Color("#28374788")))


func _set_margins(
	margin: MarginContainer,
	left: int,
	top: int,
	right: int,
	bottom: int
) -> void:
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
