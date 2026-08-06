extends CanvasLayer

class_name JailBailDialog

signal closed

var detainees: Array = []
var rows: VBoxContainer
var status_label: Label
var close_button: Button
var request_in_flight := false


func _ready() -> void:
	layer = 120
	_build_ui()
	_refresh_rows()


func open_with_detainees(value: Array) -> void:
	detainees = value.duplicate(true)
	if is_node_ready():
		_refresh_rows()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not request_in_flight:
		_close()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var blocker := ColorRect.new()
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.color = Color("#02070db8")
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blocker)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-320, -245)
	panel.custom_minimum_size = Vector2(640, 490)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#071522f5")
	panel_style.border_color = Color("#168de0")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	blocker.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = "Viridian City Jail"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#eaf6ff"))
	header.add_child(title)
	close_button = Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(38, 38)
	close_button.pressed.connect(_close)
	header.add_child(close_button)

	var description := Label.new()
	description.text = "Pay bail for trainers arrested for thieving. Staff detentions cannot be paid off."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", Color("#a9bfd0"))
	layout.add_child(description)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color("#a9bfd0"))
	layout.add_child(status_label)


func _refresh_rows() -> void:
	if rows == null:
		return
	for child: Node in rows.get_children():
		child.queue_free()
	if detainees.is_empty():
		status_label.text = "Nobody is currently eligible for bail."
		return
	status_label.text = "%d trainer(s) eligible for bail." % detainees.size()
	for value: Variant in detainees:
		if value is Dictionary:
			rows.add_child(_create_detainee_row(value as Dictionary))


func _create_detainee_row(detainee: Dictionary) -> Control:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0d2131")
	style.border_color = Color("#24465f")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 14
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	row.add_theme_stylebox_override("panel", style)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	row.add_child(content)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(details)
	var name_label := Label.new()
	name_label.text = str(detainee.get("displayName", detainee.get("username", "Trainer")))
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color("#eaf6ff"))
	details.add_child(name_label)
	var remaining := maxi(int(detainee.get("remainingSeconds", 0)), 0)
	var bail_cost := maxi(int(detainee.get("bailCost", 0)), 0)
	var info := Label.new()
	info.text = "%s remaining  •  ₽%d bail" % [_format_duration(remaining), bail_cost]
	info.add_theme_color_override("font_color", Color("#a9bfd0"))
	details.add_child(info)
	var pay_button := Button.new()
	pay_button.text = "Pay ₽%d" % bail_cost
	pay_button.custom_minimum_size = Vector2(120, 42)
	pay_button.pressed.connect(_pay_bail.bind(int(detainee.get("targetPlayerId", 0))))
	content.add_child(pay_button)
	return row


func _pay_bail(target_player_id: int) -> void:
	if request_in_flight or target_player_id <= 0:
		return
	request_in_flight = true
	close_button.disabled = true
	status_label.text = "Processing bail..."
	var result: Dictionary = await ThievingService.pay_bail(target_player_id)
	request_in_flight = false
	close_button.disabled = false
	if not bool(result.get("success", false)):
		status_label.text = str(result.get("error", "Could not pay bail."))
		return
	get_tree().call_group("ui_overlay", "add_system_message", "%s was released for ₽%d." % [
		str(result.get("targetDisplayName", "The trainer")),
		int(result.get("paidAmount", 0)),
	])
	var refreshed: Dictionary = await ThievingService.load_bailable_detainees()
	if bool(refreshed.get("success", false)):
		detainees = refreshed.get("detainees", []) as Array
		_refresh_rows()


func _format_duration(seconds: int) -> String:
	if seconds >= 3600:
		return "%dh %02dm" % [seconds / 3600, (seconds % 3600) / 60]
	if seconds >= 60:
		return "%dm %02ds" % [seconds / 60, seconds % 60]
	return "%ds" % seconds


func _close() -> void:
	if request_in_flight:
		return
	closed.emit()
	queue_free()
