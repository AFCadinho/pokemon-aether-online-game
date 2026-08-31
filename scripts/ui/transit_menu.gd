extends CanvasLayer

class_name TransitMenu

signal resolved(destination_id: String)

const AetherConfirmationDialogScene := preload("res://scenes/interface/aether_confirmation_dialog.tscn")
const PANEL_MAX_WIDTH := 780.0
const PANEL_MAX_HEIGHT := 650.0
const PANEL_VIEWPORT_MARGIN := 48.0
const COLOR_PANEL := Color("101827f5")
const COLOR_CARD := Color("172538f2")
const COLOR_CARD_HOVER := Color("1d3148f8")
const COLOR_BORDER := Color("31506d")
const COLOR_ACCENT := Color("69d8e7")
const COLOR_TEXT := Color("eef8ff")
const COLOR_MUTED := Color("9eb3c5")
const COLOR_LOCKED := Color("768897")
const COLOR_SUCCESS := Color("78e0a3")
const COLOR_WARNING := Color("efc56a")
const COLOR_HUB := Color("a98cff")
const COLOR_HUB_ACCENT := Color("72e4f2")
const COLOR_HUB_CARD := Color("1b1b3df5")
const COLOR_HUB_CARD_HOVER := Color("292453fa")

var _resolved := false
var _confirmation: AetherConfirmationDialog
var _pending_destination_id := ""
var _network: Dictionary = {}
var _destinations_by_region: Dictionary = {}
var _global_hubs: Array[Dictionary] = []
var _region_ids: Array[String] = []
var _region_select: OptionButton
var _destination_stack: VBoxContainer
var _travel_button: Button
var _selected_destination: Dictionary = {}
var _destination_buttons: Dictionary = {}
var _selection_order: Array[Dictionary] = []
var _wide_layout := false


func open(network: Dictionary) -> void:
	_network = network.duplicate(true)
	_index_destinations()
	layer = 120

	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.035, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "TransitPanel"
	var viewport_size := get_viewport().get_visible_rect().size
	panel.custom_minimum_size = Vector2(
		minf(PANEL_MAX_WIDTH, maxf(viewport_size.x - PANEL_VIEWPORT_MARGIN, 420.0)),
		minf(PANEL_MAX_HEIGHT, maxf(viewport_size.y - PANEL_VIEWPORT_MARGIN, 360.0))
	)
	panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_BORDER, 1, 18))
	center.add_child(panel)
	var margin := MarginContainer.new()
	_set_margins(margin, 26, 26, 22, 22)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	_build_header(content)
	_build_region_navigation(content)
	_build_destination_area(content, viewport_size)
	_build_footer(content)

	_confirmation = AetherConfirmationDialogScene.instantiate() as AetherConfirmationDialog
	_confirmation.confirmed.connect(_confirm_travel)
	add_child(_confirmation)
	_show_region(0)


func _build_header(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	parent.add_child(header)
	var heading_stack := VBoxContainer.new()
	heading_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_stack.add_theme_constant_override("separation", 2)
	header.add_child(heading_stack)
	var title := Label.new()
	title.text = _t("ui.transit.title")
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	heading_stack.add_child(title)
	var subtitle := Label.new()
	subtitle.text = _t(
		"ui.transit.hub_hint" if str(_network.get("sourceRegionId", "")) == "all" else "ui.transit.region_hint"
	)
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", COLOR_MUTED)
	subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading_stack.add_child(subtitle)

	var header_actions := HBoxContainer.new()
	header_actions.alignment = BoxContainer.ALIGNMENT_END
	header_actions.add_theme_constant_override("separation", 8)
	header.add_child(header_actions)
	var wallet := _network.get("wallet", {}) as Dictionary
	var balance := Label.new()
	balance.text = _t("ui.transit.balance", {"money": int(wallet.get("money", 0))})
	balance.add_theme_font_size_override("font_size", 14)
	balance.add_theme_color_override("font_color", COLOR_ACCENT)
	balance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_actions.add_child(balance)
	var close_button := Button.new()
	close_button.name = "HeaderCloseButton"
	close_button.text = "×"
	close_button.tooltip_text = _t("ui.transit.close")
	close_button.custom_minimum_size = Vector2(42, 42)
	close_button.add_theme_font_size_override("font_size", 22)
	close_button.add_theme_stylebox_override("normal", _style(Color("121d2bf0"), Color("2a4055"), 1, 9))
	close_button.add_theme_stylebox_override("hover", _style(COLOR_CARD_HOVER, COLOR_ACCENT, 1, 9))
	close_button.pressed.connect(_finish.bind(""))
	header_actions.add_child(close_button)


func _build_region_navigation(parent: VBoxContainer) -> void:
	if str(_network.get("sourceRegionId", "")) != "all" or _region_ids.size() <= 1:
		return
	var navigation := HBoxContainer.new()
	navigation.name = "RegionNavigation"
	navigation.add_theme_constant_override("separation", 12)
	parent.add_child(navigation)
	var region_label := Label.new()
	region_label.text = _t("ui.transit.region")
	region_label.add_theme_color_override("font_color", COLOR_MUTED)
	region_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	navigation.add_child(region_label)
	_region_select = OptionButton.new()
	_region_select.name = "RegionSelect"
	_region_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_region_select.custom_minimum_size.y = 40
	for region_id: String in _region_ids:
		_region_select.add_item(_region_name(region_id))
		_region_select.set_item_metadata(_region_select.item_count - 1, region_id)
	_region_select.item_selected.connect(_show_region)
	navigation.add_child(_region_select)


func _build_destination_area(parent: VBoxContainer, viewport_size: Vector2) -> void:
	_wide_layout = viewport_size.x >= 900.0
	var scroll := ScrollContainer.new()
	scroll.name = "DestinationScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	_destination_stack = VBoxContainer.new()
	_destination_stack.name = "DestinationStack"
	_destination_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_destination_stack.add_theme_constant_override("separation", 9)
	scroll.add_child(_destination_stack)


func _build_footer(parent: VBoxContainer) -> void:
	var separator := HSeparator.new()
	parent.add_child(separator)
	var footer := HBoxContainer.new()
	footer.name = "TravelFooter"
	footer.alignment = BoxContainer.ALIGNMENT_END
	parent.add_child(footer)
	_travel_button = Button.new()
	_travel_button.name = "TravelButton"
	_travel_button.custom_minimum_size = Vector2(270, 42)
	_travel_button.disabled = true
	_travel_button.text = _t("ui.transit.select_destination")
	_travel_button.add_theme_stylebox_override("normal", _style(Color("174458"), Color("4fc6d8"), 1, 9))
	_travel_button.add_theme_stylebox_override("hover", _style(COLOR_CARD_HOVER, COLOR_ACCENT, 2, 9))
	_travel_button.add_theme_stylebox_override("pressed", _style(Color("102e3c"), COLOR_ACCENT, 2, 9))
	_travel_button.add_theme_stylebox_override("disabled", _style(Color("111c29"), Color("273c50"), 1, 9))
	_travel_button.pressed.connect(_request_selected_confirmation)
	footer.add_child(_travel_button)


func _show_region(index: int) -> void:
	for child: Node in _destination_stack.get_children():
		child.free()
	_destination_buttons.clear()
	_selection_order.clear()
	_selected_destination.clear()
	if _region_ids.is_empty():
		_add_empty_message(_destination_stack, _t("ui.transit.empty_region"))
		_build_global_hub_section(_destination_stack)
		_select_default_destination()
		return

	var safe_index := clampi(index, 0, _region_ids.size() - 1)
	var region_id := _region_ids[safe_index]
	_build_region_heading(_destination_stack, region_id)
	var destinations := _destinations_by_region.get(region_id, []) as Array
	var available: Array[Dictionary] = []
	var locked: Array[Dictionary] = []
	for value: Variant in destinations:
		if not value is Dictionary:
			continue
		var destination := value as Dictionary
		if bool(destination.get("attuned", false)) or bool(destination.get("isAnchor", false)):
			available.append(destination)
		else:
			locked.append(destination)

	_add_section_heading(_destination_stack, "AvailableHeading", _t("ui.transit.available"), COLOR_ACCENT)
	if available.is_empty():
		_add_empty_message(_destination_stack, _t("ui.transit.no_available"))
	else:
		var available_list := VBoxContainer.new()
		available_list.name = "AvailableDestinations"
		available_list.add_theme_constant_override("separation", 7)
		_destination_stack.add_child(available_list)
		for destination: Dictionary in available:
			available_list.add_child(_available_destination_card(destination))

	if not locked.is_empty():
		_add_section_heading(_destination_stack, "LockedHeading", _t("ui.transit.locked_destinations"), COLOR_MUTED)
		var locked_grid := GridContainer.new()
		locked_grid.name = "LockedDestinations"
		locked_grid.columns = 2 if _wide_layout else 1
		locked_grid.add_theme_constant_override("h_separation", 7)
		locked_grid.add_theme_constant_override("v_separation", 7)
		_destination_stack.add_child(locked_grid)
		for destination: Dictionary in locked:
			locked_grid.add_child(_locked_destination_card(destination))

	_build_global_hub_section(_destination_stack)
	_select_default_destination()


func _build_region_heading(parent: VBoxContainer, region_id: String) -> void:
	var row := HBoxContainer.new()
	row.name = "RegionHeading"
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var heading := Label.new()
	heading.text = _t("ui.transit.destinations", {"region": _region_name(region_id)})
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", COLOR_TEXT)
	row.add_child(heading)
	if bool(_network.get("membershipDiscountActive", false)):
		var discount := Label.new()
		discount.text = _t("ui.transit.tier.blessing")
		discount.add_theme_font_size_override("font_size", 10)
		discount.add_theme_color_override("font_color", COLOR_SUCCESS)
		discount.add_theme_stylebox_override("normal", _style(Color("14291f"), Color("39704f"), 1, 7))
		row.add_child(discount)


func _build_global_hub_section(parent: VBoxContainer) -> void:
	if _global_hubs.is_empty():
		return
	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 4)
	parent.add_child(separator)
	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 9)
	parent.add_child(heading_row)
	var heading := Label.new()
	heading.text = _t("ui.transit.hubs")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", COLOR_TEXT)
	heading_row.add_child(heading)
	var global_badge := Label.new()
	global_badge.text = _t("ui.transit.hub.badge")
	global_badge.add_theme_font_size_override("font_size", 9)
	global_badge.add_theme_color_override("font_color", COLOR_HUB_ACCENT)
	global_badge.add_theme_stylebox_override("normal", _style(Color("152d45"), Color("4aa6bd"), 1, 7))
	heading_row.add_child(global_badge)
	for destination: Dictionary in _global_hubs:
		parent.add_child(_global_hub_card(destination))


func _available_destination_card(destination: Dictionary) -> Button:
	var destination_id := str(destination.get("destinationId", ""))
	var is_anchor := bool(destination.get("isAnchor", false))
	var current := destination_id == str(_network.get("sourceMapId", ""))
	var card := Button.new()
	card.name = "Destination_%s" % _node_safe_id(destination_id)
	card.text = ""
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 76)
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.disabled = current
	card.set_meta("is_hub", false)
	card.pressed.connect(_select_destination.bind(destination))
	_destination_buttons[destination_id] = card
	if not current:
		_selection_order.append(destination)
	_add_card_content(card, destination, false, current, is_anchor)
	_apply_destination_card_style(card, false, false)
	return card


func _locked_destination_card(destination: Dictionary) -> PanelContainer:
	var destination_id := str(destination.get("destinationId", ""))
	var card := PanelContainer.new()
	card.name = "Locked_%s" % _node_safe_id(destination_id)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 62)
	card.add_theme_stylebox_override("panel", _style(Color("111b28dc"), Color("24394c99"), 1, 10))
	var margin := MarginContainer.new()
	_set_margins(margin, 13, 13, 8, 8)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var marker := Label.new()
	marker.text = "◇"
	marker.add_theme_font_size_override("font_size", 20)
	marker.add_theme_color_override("font_color", COLOR_LOCKED)
	row.add_child(marker)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(details)
	var name_label := Label.new()
	name_label.text = str(destination.get("name", destination_id))
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", COLOR_LOCKED)
	details.add_child(name_label)
	var status := Label.new()
	status.text = _t("ui.transit.status.locked")
	status.add_theme_font_size_override("font_size", 10)
	status.add_theme_color_override("font_color", COLOR_WARNING)
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	details.add_child(status)
	return card


func _global_hub_card(destination: Dictionary) -> Button:
	var destination_id := str(destination.get("destinationId", ""))
	var current := destination_id == str(_network.get("sourceMapId", ""))
	var card := Button.new()
	card.name = "Destination_%s" % _node_safe_id(destination_id)
	card.text = ""
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 82)
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = _t("ui.transit.hub.tooltip")
	card.disabled = current
	card.set_meta("is_hub", true)
	card.pressed.connect(_select_destination.bind(destination))
	_destination_buttons[destination_id] = card
	if not current:
		_selection_order.append(destination)
	_add_card_content(card, destination, true, current, false)
	_apply_destination_card_style(card, false, true)
	return card


func _add_card_content(card: Button, destination: Dictionary, is_hub: bool, current: bool, is_anchor: bool) -> void:
	var destination_id := str(destination.get("destinationId", ""))
	var fare_value := int(destination.get("fare", 0))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_set_margins(margin, 16 if is_hub else 15, 16 if is_hub else 15, 10, 10)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var marker := Label.new()
	marker.text = "✦" if is_hub or is_anchor else "◆"
	marker.add_theme_font_size_override("font_size", 25 if is_hub else 23)
	marker.add_theme_color_override("font_color", COLOR_HUB_ACCENT if is_hub else COLOR_ACCENT)
	row.add_child(marker)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	details.add_theme_constant_override("separation", 1 if is_hub else 2)
	row.add_child(details)
	var name_label := Label.new()
	name_label.text = str(destination.get("name", destination_id))
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	details.add_child(name_label)
	if is_hub:
		var description := Label.new()
		description.text = _t("ui.transit.hub.description")
		description.add_theme_font_size_override("font_size", 11)
		description.add_theme_color_override("font_color", COLOR_MUTED)
		description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		details.add_child(description)
	var status := Label.new()
	if current:
		status.text = _t("ui.transit.status.current")
		status.add_theme_color_override("font_color", COLOR_SUCCESS)
	elif is_hub and bool(destination.get("guildBenefitActive", false)):
		status.text = _t("ui.transit.hub.guild_free")
		status.add_theme_color_override("font_color", COLOR_SUCCESS)
	elif is_hub:
		status.text = _t("ui.transit.hub.public_fare", {"fare": fare_value})
		status.add_theme_color_override("font_color", COLOR_WARNING)
	elif is_anchor:
		status.text = _t("ui.transit.status.anchor")
		status.add_theme_color_override("font_color", COLOR_SUCCESS)
	else:
		status.text = _t("ui.transit.status.ready")
		status.add_theme_color_override("font_color", COLOR_ACCENT)
	status.add_theme_font_size_override("font_size", 11 if is_hub else 12)
	details.add_child(status)
	var fare := Label.new()
	fare.text = _destination_fare_text(destination, current)
	fare.add_theme_font_size_override("font_size", 13)
	fare.add_theme_color_override("font_color", COLOR_MUTED if current else (COLOR_SUCCESS if fare_value == 0 else COLOR_TEXT))
	fare.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(fare)
	_set_mouse_filter_recursive(margin)


func _select_default_destination() -> void:
	var fallback: Dictionary = {}
	for destination: Dictionary in _selection_order:
		if fallback.is_empty():
			fallback = destination
		if _can_afford(destination):
			_select_destination(destination)
			return
	if not fallback.is_empty():
		_select_destination(fallback)
	else:
		_refresh_travel_button()


func _select_destination(destination: Dictionary) -> void:
	_selected_destination = destination.duplicate(true)
	var selected_id := str(_selected_destination.get("destinationId", ""))
	for destination_id: Variant in _destination_buttons:
		var button := _destination_buttons[destination_id] as Button
		_apply_destination_card_style(button, str(destination_id) == selected_id, bool(button.get_meta("is_hub", false)))
	_refresh_travel_button()
	var selected_button := _destination_buttons.get(selected_id) as Button
	if selected_button != null:
		selected_button.call_deferred("grab_focus")


func _refresh_travel_button() -> void:
	if _selected_destination.is_empty():
		_travel_button.disabled = true
		_travel_button.text = _t("ui.transit.select_destination")
		return
	var fare := int(_selected_destination.get("fare", 0))
	if not _can_afford(_selected_destination):
		_travel_button.disabled = true
		_travel_button.text = _t("ui.transit.insufficient_funds")
		return
	_travel_button.disabled = false
	_travel_button.text = _t(
		"ui.transit.travel_to_free" if fare == 0 else "ui.transit.travel_to",
		{"name": str(_selected_destination.get("name", "")), "fare": fare}
	)


func _apply_destination_card_style(button: Button, selected: bool, is_hub: bool) -> void:
	var base := COLOR_HUB_CARD if is_hub else COLOR_CARD
	var hover := COLOR_HUB_CARD_HOVER if is_hub else COLOR_CARD_HOVER
	var accent := COLOR_HUB if is_hub else COLOR_ACCENT
	var border := accent if selected else Color(COLOR_BORDER, 0.55)
	button.add_theme_stylebox_override("normal", _style(base, border, 2 if selected else 1, 11))
	button.add_theme_stylebox_override("hover", _style(hover, accent, 2, 11))
	button.add_theme_stylebox_override("pressed", _style(base.darkened(0.15), accent, 2, 11))
	button.add_theme_stylebox_override("focus", _style(base, accent, 2, 11))
	button.add_theme_stylebox_override("disabled", _style(Color(base, 0.72), Color(COLOR_BORDER, 0.35), 1, 11))


func _destination_fare_text(destination: Dictionary, current: bool) -> String:
	if current:
		return _t("ui.transit.current")
	var fare := int(destination.get("fare", 0))
	return _t("ui.transit.free") if fare == 0 else "₽%d" % fare


func _can_afford(destination: Dictionary) -> bool:
	var wallet := _network.get("wallet", {}) as Dictionary
	return int(wallet.get("money", 0)) >= int(destination.get("fare", 0))


func _add_section_heading(parent: VBoxContainer, node_name: String, text_value: String, color: Color) -> void:
	var heading := Label.new()
	heading.name = node_name
	heading.text = text_value.to_upper()
	heading.add_theme_font_size_override("font_size", 11)
	heading.add_theme_color_override("font_color", color)
	parent.add_child(heading)


func _add_empty_message(parent: VBoxContainer, text_value: String) -> void:
	var empty := Label.new()
	empty.text = text_value
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.add_theme_color_override("font_color", COLOR_MUTED)
	empty.custom_minimum_size.y = 44
	empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(empty)


func _index_destinations() -> void:
	_destinations_by_region.clear()
	_global_hubs.clear()
	_region_ids.clear()
	for value: Variant in _network.get("destinations", []):
		if not value is Dictionary:
			continue
		var destination := value as Dictionary
		if bool(destination.get("isGlobalHub", false)):
			_global_hubs.append(destination)
			continue
		var region_id := str(destination.get("regionId", "unknown"))
		if not _destinations_by_region.has(region_id):
			_destinations_by_region[region_id] = []
			_region_ids.append(region_id)
		(_destinations_by_region[region_id] as Array).append(destination)
	_region_ids.sort_custom(func(a: String, b: String) -> bool: return _region_name(a) < _region_name(b))
	for region_id: String in _region_ids:
		(_destinations_by_region[region_id] as Array).sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("name", "")) < str(b.get("name", ""))
		)
	_global_hubs.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("name", "")) < str(b.get("name", ""))
	)


func _region_name(region_id: String) -> String:
	var key := "world.region.%s" % region_id.to_lower()
	var translated := _t(key)
	if translated != key:
		return translated
	return region_id.replace("_", " ").capitalize()


func _unhandled_input(event: InputEvent) -> void:
	if _confirmation != null and _confirmation.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish("")


func _request_selected_confirmation() -> void:
	if _selected_destination.is_empty() or not _can_afford(_selected_destination):
		return
	_request_confirmation(_selected_destination)


func _request_confirmation(destination: Dictionary) -> void:
	_pending_destination_id = str(destination.get("destinationId", ""))
	_confirmation.configure(
		_t("ui.transit.confirm_title"),
		_t(
			"ui.transit.confirm_free" if int(destination.get("fare", 0)) == 0 else "ui.transit.confirm",
			{"name": str(destination.get("name", "")), "fare": int(destination.get("fare", 0))}
		),
		_t("common.confirm"),
		_t("common.cancel")
	)
	_confirmation.popup_centered()


func _confirm_travel() -> void:
	_finish(_pending_destination_id)


func _finish(destination_id: String) -> void:
	if _resolved:
		return
	_resolved = true
	resolved.emit(destination_id)
	queue_free()


func _node_safe_id(value: String) -> String:
	return value.replace("-", "_").replace(" ", "_")


func _t(key: String, values: Dictionary = {}) -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager == null:
		return key.format(values)
	return str(localization_manager.call("text", key, values))


func _set_mouse_filter_recursive(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in control.get_children():
		if child is Control:
			_set_mouse_filter_recursive(child as Control)


func _style(background: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _set_margins(container: MarginContainer, left: int, right: int, top: int, bottom: int) -> void:
	container.add_theme_constant_override("margin_left", left)
	container.add_theme_constant_override("margin_right", right)
	container.add_theme_constant_override("margin_top", top)
	container.add_theme_constant_override("margin_bottom", bottom)
