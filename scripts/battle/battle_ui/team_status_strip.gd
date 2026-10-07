extends HBoxContainer
## Two battle sides, each containing up to two public Trainer statuses.
## No clock, deadline, selected move or target is part of this UI contract.

var sides: Array[PanelContainer] = []
var headings: Array[Label] = []
var trainer_rows: Array = []
var _teams: Array = [[], []]
var _titles: Array[String] = ["", ""]
var _status_styles: Dictionary = {}

func configure(_panel_style: StyleBox) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for tone: String in ["94b9dc", "67e8bf", "fbbf24", "fb91a5", "c4b5fd"]:
		_status_styles[tone] = _frame(Color(tone, 0.10), Color(tone, 0.32), 10, 6, 2)
	for side in range(2):
		var accent := Color("7dd3fc") if side == 0 else Color("f9a8d4")
		if side == 1:
			var emblem := PanelContainer.new()
			emblem.custom_minimum_size = Vector2(40, 40)
			emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			emblem.add_theme_stylebox_override("panel", _frame(Color("132031"), Color("456078"), 12, 4, 4))
			add_child(emblem)
			var versus := Label.new()
			versus.name = "VersusLabel"
			versus.text = "VS"
			versus.add_theme_font_size_override("font_size", 18)
			versus.add_theme_color_override("font_color", Color("bacbdc"))
			versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			emblem.add_child(versus)
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(310, 80)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var panel_frame := _frame(Color("0c1624", 0.96), Color(accent, 0.45), 12, 0, 0)
		panel_frame.border_width_left = 3
		panel_frame.shadow_color = Color(0, 0, 0, 0.25)
		panel_frame.shadow_size = 3
		panel.add_theme_stylebox_override("panel", panel_frame)
		add_child(panel)
		sides.append(panel)
		var margin := MarginContainer.new()
		for edge: String in ["left", "right"]:
			margin.add_theme_constant_override("margin_" + edge, 10)
		for edge: String in ["top", "bottom"]:
			margin.add_theme_constant_override("margin_" + edge, 6)
		panel.add_child(margin)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		margin.add_child(column)
		var heading := Label.new()
		heading.name = "TeamHeading"
		heading.add_theme_font_size_override("font_size", 14)
		heading.add_theme_color_override("font_color", accent)
		column.add_child(heading)
		headings.append(heading)
		var rows: Array = []
		for index in range(2):
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			column.add_child(row)
			var badge := PanelContainer.new()
			badge.custom_minimum_size = Vector2(24, 24)
			badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			badge.add_theme_stylebox_override("panel", _frame(Color(accent, 0.12), Color(accent, 0.28), 12, 2, 0))
			row.add_child(badge)
			var initial := Label.new()
			initial.name = "TrainerBadgeLetter"
			initial.add_theme_font_size_override("font_size", 13)
			initial.add_theme_color_override("font_color", accent)
			initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			badge.add_child(initial)
			var trainer := Label.new()
			trainer.name = "TrainerName"
			trainer.custom_minimum_size.x = 70
			trainer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			trainer.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			trainer.add_theme_font_size_override("font_size", 17)
			trainer.add_theme_color_override("font_color", Color("e4edf7"))
			trainer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(trainer)
			var chip := PanelContainer.new()
			chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(chip)
			var status := Label.new()
			status.name = "TrainerStatus"
			status.add_theme_font_size_override("font_size", 14)
			status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			chip.add_child(status)
			rows.append({"name": trainer, "status": status, "badge": badge, "initial": initial, "chip": chip, "tone": ""})
		trainer_rows.append(rows)
	_ignore_mouse(self)
	var localization := get_node_or_null("/root/LocalizationManager")
	if localization != null:
		localization.locale_changed.connect(_on_locale_changed)

func set_teams(left: Array, right: Array, left_title: String, right_title: String) -> void:
	_teams = [left.duplicate(true), right.duplicate(true)]
	_titles = [left_title, right_title]
	_render()

func _render() -> void:
	if sides.is_empty():
		return
	for side in range(2):
		headings[side].text = _text(_titles[side])
		for index in range(2):
			var row: Dictionary = trainer_rows[side][index]
			var trainer: Dictionary = _teams[side][index] if index < _teams[side].size() else {}
			row.name.text = str(trainer.get("name", ""))
			row.name.tooltip_text = row.name.text
			row.initial.text = row.name.text.left(1).to_upper()
			# Reserve the second row's height without showing an empty badge.
			row.badge.modulate.a = 0.0 if row.name.text.is_empty() else 1.0
			if trainer.get("local", false):
				row.name.text += " · " + _text("ui.chat.you")
			var state := str(trainer.get("state", ""))
			row.status.text = _text("battle.coop.status." + state) if not state.is_empty() else ""
			row.chip.visible = not state.is_empty()
			var tone := _status_tone(state)
			if row.tone != tone:
				row.chip.add_theme_stylebox_override("panel", _status_styles[tone])
				row.status.add_theme_color_override("font_color", Color(tone))
				row.tone = tone

func _status_tone(state: String) -> String:
	if state in ["ready", "ready_next"]:
		return "67e8bf"
	if state == "disconnected":
		return "fb91a5"
	if state in ["checking", "sending", "connecting"]:
		return "fbbf24"
	if state in ["switching", "waiting", "confirming"]:
		return "c4b5fd"
	return "94b9dc"

func _frame(background: Color, border: Color, radius: int, horizontal: int, vertical: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style

func _text(key: String) -> String:
	var localization := get_node_or_null("/root/LocalizationManager")
	return str(localization.text(key)) if localization != null else key

func _on_locale_changed(_locale: String) -> void:
	_render()

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_ignore_mouse(child)
