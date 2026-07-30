extends Window

class_name TradeInvitationDialog

const DIALOG_SIZE := Vector2i(510, 300)
const TRADE_ICON: Texture2D = preload("res://assets/ui/player_trade.svg")
const TRADE_BG := Color("#050912fa")
const TRADE_SURFACE := Color("#081522f7")
const TRADE_SURFACE_RAISED := Color("#0b1a2bf7")
const TRADE_BORDER := Color("#2d4b66b3")
const TRADE_ACCENT := Color("#62d7ff")
const TRADE_GOLD := Color("#d8b767")
const TRADE_TEXT := Color("#f4f0de")
const TRADE_MUTED := Color("#aeb8c5")

var trade: Dictionary = {}
var status_label: Label
var mode_label: Label
var heading_label: Label
var accept_button: Button
var decline_button: Button
var action_in_flight := false
var notified_incoming_trade_ids: Dictionary = {}


func setup() -> void:
	hide()
	trade.clear()
	title = _t("ui.trade.invitation.window_title")
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
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 15)
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
	icon_frame.add_theme_stylebox_override("panel", _panel_style(Color("#62d7ff1f"), Color("#62d7ff88"), 9, 1))
	header.add_child(icon_frame)

	var icon_margin := MarginContainer.new()
	icon_margin.add_theme_constant_override("margin_left", 6)
	icon_margin.add_theme_constant_override("margin_top", 6)
	icon_margin.add_theme_constant_override("margin_right", 6)
	icon_margin.add_theme_constant_override("margin_bottom", 6)
	icon_frame.add_child(icon_margin)

	var icon := TextureRect.new()
	icon.texture = TRADE_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_margin.add_child(icon)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	title_stack.add_theme_constant_override("separation", 0)
	header.add_child(title_stack)

	var window_title := Label.new()
	_set_localized_property(window_title, "text", "ui.trade.invitation.title")
	window_title.add_theme_color_override("font_color", TRADE_TEXT)
	window_title.add_theme_font_size_override("font_size", 19)
	title_stack.add_child(window_title)

	var window_subtitle := Label.new()
	_set_localized_property(window_subtitle, "text", "ui.trade.invitation.subtitle")
	window_subtitle.add_theme_color_override("font_color", TRADE_MUTED)
	window_subtitle.add_theme_font_size_override("font_size", 11)
	title_stack.add_child(window_subtitle)

	var close_button := Button.new()
	close_button.text = "×"
	_set_localized_property(close_button, "tooltip_text", "ui.trade.invitation.close")
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.custom_minimum_size = Vector2(36, 34)
	close_button.add_theme_color_override("font_color", TRADE_MUTED)
	close_button.add_theme_color_override("font_hover_color", Color.WHITE)
	close_button.add_theme_stylebox_override("normal", _panel_style(Color("#07111ed8"), TRADE_BORDER, 7, 1))
	close_button.add_theme_stylebox_override("hover", _panel_style(Color("#2a1015"), Color("#b84c58"), 7, 1))
	close_button.pressed.connect(_decline_or_close)
	header.add_child(close_button)

	var content_panel := PanelContainer.new()
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.add_theme_stylebox_override("panel", _panel_style(TRADE_SURFACE_RAISED, TRADE_BORDER, 9, 1))
	root.add_child(content_panel)

	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 15)
	content_margin.add_theme_constant_override("margin_top", 13)
	content_margin.add_theme_constant_override("margin_right", 15)
	content_margin.add_theme_constant_override("margin_bottom", 13)
	content_panel.add_child(content_margin)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 6)
	content_margin.add_child(stack)

	mode_label = Label.new()
	mode_label.text = _t("ui.trade.invitation.incoming")
	mode_label.add_theme_color_override("font_color", TRADE_ACCENT)
	mode_label.add_theme_font_size_override("font_size", 10)
	stack.add_child(mode_label)

	heading_label = Label.new()
	heading_label.text = _t("ui.trade.invitation.heading")
	heading_label.add_theme_color_override("font_color", TRADE_TEXT)
	heading_label.add_theme_font_size_override("font_size", 18)
	stack.add_child(heading_label)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", TRADE_MUTED)
	stack.add_child(status_label)

	var safety_label := Label.new()
	_set_localized_property(safety_label, "text", "ui.trade.invitation.safety")
	safety_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	safety_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	safety_label.add_theme_color_override("font_color", Color("#75d99a"))
	safety_label.add_theme_font_size_override("font_size", 10)
	stack.add_child(safety_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	root.add_child(actions)

	var action_spacer := Control.new()
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(action_spacer)

	decline_button = Button.new()
	_set_localized_property(decline_button, "text", "common.decline")
	decline_button.custom_minimum_size = Vector2(112, 38)
	decline_button.pressed.connect(_decline_or_close)
	_style_button(decline_button, "secondary")
	actions.add_child(decline_button)

	accept_button = Button.new()
	_set_localized_property(accept_button, "text", "ui.trade.invitation.accept")
	accept_button.custom_minimum_size = Vector2(132, 38)
	accept_button.pressed.connect(_accept)
	_style_button(accept_button, "primary")
	actions.add_child(accept_button)

	close_requested.connect(_decline_or_close)
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		var locale_callable := Callable(self, "_on_locale_changed")
		if not localization_manager.is_connected("locale_changed", locale_callable):
			localization_manager.connect("locale_changed", locale_callable)
	var realtime := get_node_or_null("/root/TradeRealtimeService")
	if realtime != null:
		realtime.invitation_received.connect(show_trade)
		realtime.active_trade_changed.connect(_on_trade_changed)
		var snapshot: Dictionary = realtime.active_trade_snapshot
		if str(snapshot.get("status", "")) == "invited" and _role_for_trade(snapshot) == "recipient":
			show_trade.call_deferred(snapshot.duplicate(true))


func send_invitation(username: String) -> Dictionary:
	var service := get_node_or_null("/root/TradeService")
	if service == null:
		return {"success": false, "error": _t("ui.trade.error.service_unavailable")}
	action_in_flight = true
	var result: Dictionary = await service.create_invitation(username)
	action_in_flight = false
	if bool(result.get("success", false)):
		show_trade(result.get("trade", {}))
		var realtime := get_node_or_null("/root/TradeRealtimeService")
		if realtime != null:
			realtime.apply_snapshot(trade)
			realtime.restore_active_trade_and_connect.call_deferred()
	else:
		show_error(str(result.get("error", _t("ui.trade.error.send_invitation"))))
	return result


func show_trade(value: Dictionary) -> void:
	trade = value.duplicate(true)
	if str(trade.get("status", "")) != "invited":
		hide()
		return
	var incoming := _current_role() == "recipient"
	accept_button.visible = incoming and str(trade.get("status", "")) == "invited"
	decline_button.text = _t("common.decline") if incoming else _t("ui.trade.invitation.cancel")
	mode_label.text = _t("ui.trade.invitation.incoming") if incoming else _t("ui.trade.invitation.sent_mode")
	heading_label.text = (
		_t("ui.trade.invitation.wants_to_trade", {"trainer": _initiator_display_name()})
		if incoming
		else _t("ui.trade.invitation.sent")
	)
	_style_button(decline_button, "secondary")
	status_label.text = _invitation_status_text(incoming)
	if incoming:
		_notify_incoming_invitation_once()
	size = DIALOG_SIZE
	popup_centered(DIALOG_SIZE)


func show_error(message: String) -> void:
	trade.clear()
	accept_button.visible = false
	decline_button.text = _t("common.close")
	mode_label.text = _t("ui.trade.invitation.error_mode")
	heading_label.text = _t("ui.trade.invitation.error_heading")
	_style_button(decline_button, "secondary")
	status_label.text = message
	size = DIALOG_SIZE
	popup_centered(DIALOG_SIZE)


func _accept() -> void:
	if action_in_flight or trade.is_empty():
		return
	action_in_flight = true
	var result: Dictionary = await get_node("/root/TradeService").accept_invitation(str(trade.get("tradeId", "")), int(trade.get("revision", 0)))
	action_in_flight = false
	_apply_result(result)


func _decline_or_close() -> void:
	if action_in_flight:
		return
	if trade.is_empty():
		hide()
		return
	if str(trade.get("status", "")) != "invited":
		return
	action_in_flight = true
	var service := get_node("/root/TradeService")
	var result: Dictionary
	var role := _current_role()
	if role == "recipient":
		result = await service.decline_invitation(str(trade.get("tradeId", "")), int(trade.get("revision", 0)))
	else:
		result = await service.cancel_invitation(str(trade.get("tradeId", "")), int(trade.get("revision", 0)))
	action_in_flight = false
	_apply_result(result)


func _apply_result(result: Dictionary) -> void:
	if bool(result.get("success", false)):
		var result_trade: Dictionary = result.get("trade", {})
		show_trade(result_trade)
		var realtime := get_node_or_null("/root/TradeRealtimeService")
		if realtime != null:
			realtime.apply_snapshot(result_trade)
	else:
		show_error(str(result.get("error", _t("ui.trade.error.invitation_action"))))


func _on_trade_changed(value: Dictionary) -> void:
	if str(value.get("status", "")) == "invited" and _role_for_trade(value) == "recipient":
		show_trade(value)
		return
	if str(value.get("tradeId", "")) == str(trade.get("tradeId", "")):
		trade = value.duplicate(true)
		if str(trade.get("status", "")) != "invited":
			hide()
			return
		show_trade(trade)


func _current_role() -> String:
	return _role_for_trade(trade)


func _role_for_trade(value: Dictionary) -> String:
	var auth := get_node_or_null("/root/AuthService")
	var user_id := int(auth.current_user.get("id", 0)) if auth != null else 0
	for participant_value: Variant in value.get("participants", []):
		if participant_value is Dictionary and int(participant_value.get("userId", 0)) == user_id:
			return str(participant_value.get("role", ""))
	return ""


func _status_text(incoming: bool) -> String:
	match str(trade.get("status", "")):
		"invited":
			return _t("ui.trade.invitation.status.incoming") if incoming else _t("ui.trade.invitation.status.waiting")
		"active": return _t("ui.trade.invitation.status.accepted")
		"declined": return _t("ui.trade.invitation.status.declined")
		"cancelled": return _t("ui.trade.invitation.status.cancelled")
		"expired": return _t("ui.trade.invitation.status.expired")
		_: return _t("ui.trade.invitation.status.unavailable")


func _invitation_status_text(incoming: bool) -> String:
	if incoming and str(trade.get("status", "")) == "invited":
		return _t("ui.trade.invitation.invited_by", {"trainer": _initiator_display_name()})
	return _status_text(incoming)


func _initiator_display_name() -> String:
	for participant_value: Variant in trade.get("participants", []):
		if not participant_value is Dictionary or str(participant_value.get("role", "")) != "initiator":
			continue
		var username := str(participant_value.get("username", "")).strip_edges()
		var display_name := str(participant_value.get("displayName", "")).strip_edges()
		if display_name != "" and username != "" and display_name.to_lower() != username.to_lower():
			return "%s (@%s)" % [display_name, username]
		if display_name != "":
			return display_name
		if username != "":
			return "@%s" % username
	return _t("ui.trade.fallback.player")


func _notify_incoming_invitation_once() -> void:
	var trade_id := str(trade.get("tradeId", "")).strip_edges()
	if trade_id == "" or notified_incoming_trade_ids.has(trade_id):
		return
	notified_incoming_trade_ids[trade_id] = true
	var overlay := get_tree().get_first_node_in_group("ui_overlay")
	if overlay != null and overlay.has_method("add_system_message"):
		overlay.call("add_system_message", _t("ui.trade.invitation.received", {
			"trainer": _initiator_display_name(),
		}))


func _on_locale_changed(_locale: String) -> void:
	title = _t("ui.trade.invitation.window_title")
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		localization_manager.call("localize_tree", self)
	if not trade.is_empty() and str(trade.get("status", "")) == "invited":
		show_trade(trade)


func _set_localized_property(control: Control, property_name: String, key: String) -> void:
	control.set_meta("i18n_source_%s" % property_name, key)
	control.set(property_name, _t(key))


func _t(key: String, values: Dictionary = {}) -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager == null:
		return key.format(values)
	return str(localization_manager.call("text", key, values))


func _panel_style(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


func _outer_style() -> StyleBoxFlat:
	var style := _panel_style(TRADE_BG, Color("#62d7ff99"), 12, 1)
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


func _style_button(button: Button, kind: String) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	var normal_bg := Color("#0d4359")
	var hover_bg := Color("#12627f")
	var border := TRADE_ACCENT
	if kind == "secondary":
		normal_bg = Color("#111d2c")
		hover_bg = Color("#192c42")
		border = TRADE_BORDER
	elif kind == "danger":
		normal_bg = Color("#2a1015")
		hover_bg = Color("#5b1c26")
		border = Color("#b84c58")
	button.add_theme_color_override("font_color", TRADE_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(normal_bg, border))
	button.add_theme_stylebox_override("hover", _button_style(hover_bg, border.lightened(0.2)))
	button.add_theme_stylebox_override("pressed", _button_style(TRADE_BG, border))
	button.add_theme_stylebox_override("focus", _button_style(hover_bg, TRADE_GOLD))
