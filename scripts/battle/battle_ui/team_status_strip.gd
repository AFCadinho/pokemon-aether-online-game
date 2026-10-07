extends HBoxContainer
## Two battle sides, each containing up to two public Trainer statuses.
## No clock, deadline, selected move or target is part of this UI contract.

var sides: Array[PanelContainer] = []
var headings: Array[Label] = []
var trainer_rows: Array = []
var _teams: Array = [[], []]
var _titles: Array[String] = ["", ""]

func configure(panel_style: StyleBox) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in range(2):
		if side == 1:
			var versus := Label.new()
			versus.text = "VS"
			versus.add_theme_font_size_override("font_size", 18)
			versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			versus.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(versus)
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(310, 80)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", panel_style)
		add_child(panel)
		sides.append(panel)
		var margin := MarginContainer.new()
		for edge: String in ["left", "right"]:
			margin.add_theme_constant_override("margin_" + edge, 10)
		for edge: String in ["top", "bottom"]:
			margin.add_theme_constant_override("margin_" + edge, 5)
		panel.add_child(margin)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		margin.add_child(column)
		var heading := Label.new()
		heading.add_theme_font_size_override("font_size", 14)
		heading.modulate = Color("7dd3fc") if side == 0 else Color("f9a8d4")
		column.add_child(heading)
		headings.append(heading)
		var rows: Array = []
		for index in range(2):
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			column.add_child(row)
			var trainer := Label.new()
			trainer.custom_minimum_size.x = 70
			trainer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			trainer.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			trainer.add_theme_font_size_override("font_size", 17)
			row.add_child(trainer)
			var status := Label.new()
			status.add_theme_font_size_override("font_size", 16)
			status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(status)
			rows.append({"name": trainer, "status": status})
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
			if trainer.get("local", false):
				row.name.text += " · " + _text("ui.chat.you")
			var state := str(trainer.get("state", ""))
			row.status.text = _text("battle.coop.status." + state) if not state.is_empty() else ""
			row.status.modulate = Color("67e8bf") if state in ["ready", "ready_next"] else Color("fbbf24") if state in ["disconnected", "checking"] else Color.WHITE

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
