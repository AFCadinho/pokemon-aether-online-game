extends CanvasLayer

class_name TransitMenu

signal resolved(destination_id: String)

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

var _resolved := false
var _confirmation: ConfirmationDialog
var _pending_destination_id := ""
var _network: Dictionary = {}
var _destinations_by_region: Dictionary = {}
var _region_ids: Array[String] = []
var _region_select: OptionButton
var _region_heading: Label
var _destination_grid: GridContainer


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
	var viewport_size := get_viewport().get_visible_rect().size
	panel.custom_minimum_size = Vector2(
		minf(PANEL_MAX_WIDTH, maxf(viewport_size.x - PANEL_VIEWPORT_MARGIN, 420.0)),
		minf(PANEL_MAX_HEIGHT, maxf(viewport_size.y - PANEL_VIEWPORT_MARGIN, 360.0))
	)
	panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_BORDER, 2, 18))
	center.add_child(panel)

	var margin := MarginContainer.new()
	_set_margins(margin, 26, 26, 22, 22)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)
	_build_header(content)
	_build_region_navigation(content)
	_build_destination_area(content, viewport_size)
	_build_footer(content)

	_confirmation = ConfirmationDialog.new()
	_confirmation.title = LocalizationManager.text("ui.transit.confirm_title")
	_confirmation.confirmed.connect(_confirm_travel)
	add_child(_confirmation)
	_show_region(0)


func _build_header(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	parent.add_child(header)
	var heading_stack := VBoxContainer.new()
	heading_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_stack.add_theme_constant_override("separation", 2)
	header.add_child(heading_stack)
	var title := Label.new()
	title.text = LocalizationManager.text("ui.transit.title")
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	heading_stack.add_child(title)
	var subtitle := Label.new()
	subtitle.text = LocalizationManager.text(
		"ui.transit.hub_hint" if str(_network.get("sourceRegionId", "")) == "all" else "ui.transit.region_hint"
	)
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", COLOR_MUTED)
	heading_stack.add_child(subtitle)

	var wallet := _network.get("wallet", {}) as Dictionary
	var balance_panel := PanelContainer.new()
	balance_panel.add_theme_stylebox_override("panel", _style(Color("102b35"), Color("347785"), 1, 10))
	header.add_child(balance_panel)
	var balance_margin := MarginContainer.new()
	_set_margins(balance_margin, 14, 14, 8, 8)
	balance_panel.add_child(balance_margin)
	var balance := Label.new()
	balance.text = LocalizationManager.text("ui.transit.balance", {"money": int(wallet.get("money", 0))})
	balance.add_theme_font_size_override("font_size", 16)
	balance.add_theme_color_override("font_color", COLOR_ACCENT)
	balance_margin.add_child(balance)


func _build_region_navigation(parent: VBoxContainer) -> void:
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 12)
	parent.add_child(navigation)
	var region_label := Label.new()
	region_label.text = LocalizationManager.text("ui.transit.region")
	region_label.add_theme_color_override("font_color", COLOR_MUTED)
	navigation.add_child(region_label)
	_region_select = OptionButton.new()
	_region_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_region_select.custom_minimum_size.y = 42
	for region_id: String in _region_ids:
		_region_select.add_item(_region_name(region_id))
		_region_select.set_item_metadata(_region_select.item_count - 1, region_id)
	_region_select.disabled = str(_network.get("sourceRegionId", "")) != "all" or _region_ids.size() <= 1
	_region_select.item_selected.connect(_show_region)
	navigation.add_child(_region_select)

	var fare_panel := PanelContainer.new()
	fare_panel.add_theme_stylebox_override("panel", _style(Color("202538"), Color("4b5574"), 1, 10))
	navigation.add_child(fare_panel)
	var fare_margin := MarginContainer.new()
	_set_margins(fare_margin, 12, 12, 8, 8)
	fare_panel.add_child(fare_margin)
	var fare := Label.new()
	var discounted := bool(_network.get("membershipDiscountActive", false))
	fare.text = LocalizationManager.text("ui.transit.fare", {
		"fare": int(_network.get("membershipFare" if discounted else "standardFare", 0)),
		"tier": LocalizationManager.text("ui.transit.tier.blessing" if discounted else "ui.transit.tier.standard"),
	})
	fare.add_theme_font_size_override("font_size", 13)
	fare.add_theme_color_override("font_color", COLOR_SUCCESS if discounted else COLOR_TEXT)
	fare_margin.add_child(fare)


func _build_destination_area(parent: VBoxContainer, viewport_size: Vector2) -> void:
	_region_heading = Label.new()
	_region_heading.add_theme_font_size_override("font_size", 18)
	_region_heading.add_theme_color_override("font_color", COLOR_TEXT)
	parent.add_child(_region_heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	_destination_grid = GridContainer.new()
	_destination_grid.columns = 2 if viewport_size.x >= 900.0 else 1
	_destination_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_destination_grid.add_theme_constant_override("h_separation", 10)
	_destination_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_destination_grid)


func _build_footer(parent: VBoxContainer) -> void:
	var separator := HSeparator.new()
	parent.add_child(separator)
	var footer := HBoxContainer.new()
	parent.add_child(footer)
	var legend := Label.new()
	legend.text = LocalizationManager.text("ui.transit.attunement_hint")
	legend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend.add_theme_font_size_override("font_size", 12)
	legend.add_theme_color_override("font_color", COLOR_MUTED)
	footer.add_child(legend)
	var close_button := Button.new()
	close_button.text = LocalizationManager.text("ui.transit.close")
	close_button.custom_minimum_size = Vector2(120, 38)
	close_button.pressed.connect(_finish.bind(""))
	footer.add_child(close_button)


func _show_region(index: int) -> void:
	if _region_ids.is_empty():
		_region_heading.text = LocalizationManager.text("ui.transit.destinations", {"region": ""})
		return
	var safe_index := clampi(index, 0, _region_ids.size() - 1)
	var region_id := _region_ids[safe_index]
	_region_heading.text = LocalizationManager.text("ui.transit.destinations", {"region": _region_name(region_id)})
	for child: Node in _destination_grid.get_children():
		child.free()
	var destinations := _destinations_by_region.get(region_id, []) as Array
	if destinations.is_empty():
		var empty := Label.new()
		empty.text = LocalizationManager.text("ui.transit.empty_region")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", COLOR_MUTED)
		_destination_grid.add_child(empty)
		return
	for value: Variant in destinations:
		if value is Dictionary:
			_destination_grid.add_child(_destination_card(value as Dictionary))


func _destination_card(destination: Dictionary) -> Control:
	var destination_id := str(destination.get("destinationId", ""))
	var attuned := bool(destination.get("attuned", false))
	var current := destination_id == str(_network.get("sourceMapId", ""))
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 92)
	card.add_theme_stylebox_override("panel", _style(COLOR_CARD, COLOR_BORDER, 1, 12))
	var margin := MarginContainer.new()
	_set_margins(margin, 15, 15, 12, 12)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var marker := Label.new()
	marker.text = "◆" if attuned else "◇"
	marker.add_theme_font_size_override("font_size", 25)
	marker.add_theme_color_override("font_color", COLOR_ACCENT if attuned else COLOR_LOCKED)
	row.add_child(marker)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 3)
	row.add_child(details)
	var name_label := Label.new()
	name_label.text = str(destination.get("name", destination_id))
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", COLOR_TEXT if attuned else COLOR_LOCKED)
	details.add_child(name_label)
	var status_label := Label.new()
	if current:
		status_label.text = LocalizationManager.text("ui.transit.status.current")
		status_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	elif attuned:
		status_label.text = LocalizationManager.text("ui.transit.status.ready")
		status_label.add_theme_color_override("font_color", COLOR_ACCENT)
	else:
		status_label.text = LocalizationManager.text("ui.transit.status.locked")
		status_label.add_theme_color_override("font_color", COLOR_WARNING)
	status_label.add_theme_font_size_override("font_size", 12)
	details.add_child(status_label)
	var action := Button.new()
	action.custom_minimum_size = Vector2(112, 44)
	action.text = LocalizationManager.text("ui.transit.current") if current else (
		LocalizationManager.text("ui.transit.locked") if not attuned else LocalizationManager.text("ui.transit.travel", {"fare": int(destination.get("fare", 0))})
	)
	action.disabled = not attuned or current
	if not action.disabled:
		action.add_theme_stylebox_override("normal", _style(Color("174458"), Color("4fc6d8"), 1, 9))
		action.add_theme_stylebox_override("hover", _style(COLOR_CARD_HOVER, COLOR_ACCENT, 2, 9))
		action.pressed.connect(_request_confirmation.bind(destination))
	row.add_child(action)
	return card


func _index_destinations() -> void:
	_destinations_by_region.clear()
	_region_ids.clear()
	for value: Variant in _network.get("destinations", []):
		if not value is Dictionary:
			continue
		var destination := value as Dictionary
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


func _region_name(region_id: String) -> String:
	var key := "world.region.%s" % region_id.to_lower()
	var translated := LocalizationManager.text(key)
	if translated != key:
		return translated
	return region_id.replace("_", " ").capitalize()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish("")


func _request_confirmation(destination: Dictionary) -> void:
	_pending_destination_id = str(destination.get("destinationId", ""))
	_confirmation.dialog_text = LocalizationManager.text("ui.transit.confirm", {
		"name": str(destination.get("name", "")),
		"fare": int(destination.get("fare", 0)),
	})
	_confirmation.popup_centered()


func _confirm_travel() -> void:
	_finish(_pending_destination_id)


func _finish(destination_id: String) -> void:
	if _resolved:
		return
	_resolved = true
	resolved.emit(destination_id)
	queue_free()


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
