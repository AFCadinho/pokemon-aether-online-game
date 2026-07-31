extends Control

class_name QuestJournalView

signal journal_opened
signal journal_closed

const SURFACE := Color("#050b14f2")
const TRACKER_SURFACE := Color("#050b14ed")
const SURFACE_RAISED := Color("#081522f7")
const SURFACE_INSET := Color("#030812e8")
const BORDER := Color("#d8b767")
const BORDER_SOFT := Color("#315070")
const TEXT := Color("#f4f0de")
const MUTED_TEXT := Color("#aeb8c5")
const ACCENT := Color("#60d3ff")
const SIDE_QUEST_ACCENT := Color("#d8b767")
const SUCCESS := Color("#73d98b")
const DANGER := Color("#ff6b74")
const JOURNAL_FILTERS: Array[String] = ["all", "main", "side", "completed"]

var tracker_panel: PanelContainer
var tracker_type_label: Label
var tracker_title_label: Label
var tracker_objective_label: Label
var tracker_progress_label: Label

var modal_layer: Control
var journal_panel: PanelContainer
var journal_title_label: Label
var journal_subtitle_label: Label
var close_button: Button
var filter_buttons: Dictionary = {}
var quest_list: VBoxContainer
var empty_list_label: Label
var list_heading_label: Label
var list_count_label: Label
var detail_content: VBoxContainer
var detail_type_label: Label
var detail_title_label: Label
var detail_summary_label: Label
var detail_objective_heading: Label
var detail_steps: VBoxContainer

var selected_quest_id := ""
var selected_filter := "all"
var localization_manager: Node


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	localization_manager = get_node_or_null("/root/LocalizationManager")
	_build_tracker()
	_build_journal()
	var journal_service := _journal_service()
	if journal_service != null and not journal_service.journal_changed.is_connected(_on_journal_changed):
		journal_service.journal_changed.connect(_on_journal_changed)
	if localization_manager != null and not localization_manager.locale_changed.is_connected(_on_locale_changed):
		localization_manager.locale_changed.connect(_on_locale_changed)
	refresh()


func open_journal() -> void:
	if modal_layer.visible:
		return
	modal_layer.visible = true
	refresh()
	close_button.grab_focus()
	journal_opened.emit()


func close_journal() -> void:
	if not modal_layer.visible:
		return
	modal_layer.visible = false
	journal_closed.emit()


func is_journal_open() -> bool:
	return modal_layer != null and modal_layer.visible


func get_journal_panel() -> Control:
	return journal_panel


func set_tracker_top_offset(top_offset: float) -> void:
	if tracker_panel == null:
		return
	var tracker_height := tracker_panel.custom_minimum_size.y
	tracker_panel.offset_top = top_offset
	tracker_panel.offset_bottom = top_offset + tracker_height


func refresh() -> void:
	_refresh_tracker()
	_refresh_journal()


func _build_tracker() -> void:
	tracker_panel = PanelContainer.new()
	tracker_panel.name = "QuestObjectiveTracker"
	tracker_panel.custom_minimum_size = Vector2(248, 90)
	tracker_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tracker_panel.offset_left = -248.0
	tracker_panel.offset_top = 76.0
	tracker_panel.offset_right = 0.0
	tracker_panel.offset_bottom = 166.0
	tracker_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	tracker_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tracker_panel.tooltip_text = localization_manager.text("ui.quest.open_log")
	tracker_panel.z_index = 100
	tracker_panel.add_theme_stylebox_override("panel", _style(TRACKER_SURFACE, BORDER_SOFT, 10, 1))
	tracker_panel.gui_input.connect(_on_tracker_gui_input)
	add_child(tracker_panel)

	var margin := MarginContainer.new()
	_set_margins(margin, 8, 7, 10, 8)
	tracker_panel.add_child(margin)
	var content_row := HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 8)
	margin.add_child(content_row)
	var accent_line := ColorRect.new()
	accent_line.custom_minimum_size = Vector2(2, 0)
	accent_line.color = Color("#60d3ffaa")
	accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_row.add_child(accent_line)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 2)
	content_row.add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	stack.add_child(header)
	tracker_type_label = _label(10, ACCENT)
	tracker_type_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(tracker_type_label)
	tracker_progress_label = _label(10, MUTED_TEXT)
	tracker_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(tracker_progress_label)

	tracker_title_label = _label(14, TEXT)
	tracker_title_label.clip_text = true
	tracker_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(tracker_title_label)
	tracker_objective_label = _label(11, MUTED_TEXT)
	tracker_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tracker_objective_label.max_lines_visible = 2
	tracker_objective_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(tracker_objective_label)


func _build_journal() -> void:
	modal_layer = Control.new()
	modal_layer.name = "QuestJournalModal"
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.visible = false
	modal_layer.z_index = 1001
	add_child(modal_layer)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.02, 0.04, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(dim)

	journal_panel = PanelContainer.new()
	journal_panel.name = "QuestJournalPanel"
	journal_panel.custom_minimum_size = Vector2(900, 570)
	journal_panel.set_anchors_preset(Control.PRESET_CENTER)
	journal_panel.offset_left = -450.0
	journal_panel.offset_top = -285.0
	journal_panel.offset_right = 450.0
	journal_panel.offset_bottom = 285.0
	journal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	journal_panel.add_theme_stylebox_override("panel", _style(SURFACE_RAISED, BORDER, 14, 1))
	modal_layer.add_child(journal_panel)

	var outer_margin := MarginContainer.new()
	_set_margins(outer_margin, 20, 18, 20, 20)
	journal_panel.add_child(outer_margin)
	var outer_stack := VBoxContainer.new()
	outer_stack.add_theme_constant_override("separation", 14)
	outer_margin.add_child(outer_stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	outer_stack.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 2)
	header.add_child(heading)
	journal_title_label = _label(25, TEXT)
	heading.add_child(journal_title_label)
	journal_subtitle_label = _label(12, MUTED_TEXT)
	journal_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_child(journal_subtitle_label)
	close_button = Button.new()
	close_button.custom_minimum_size = Vector2(92, 38)
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.pressed.connect(close_journal)
	_style_button(close_button, false)
	header.add_child(close_button)

	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 7)
	outer_stack.add_child(filter_row)
	for filter_id: String in JOURNAL_FILTERS:
		var filter_button := Button.new()
		filter_button.custom_minimum_size = Vector2(108, 32)
		filter_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		filter_button.focus_mode = Control.FOCUS_NONE
		filter_button.pressed.connect(set_filter.bind(filter_id))
		filter_row.add_child(filter_button)
		filter_buttons[filter_id] = filter_button
	var filter_spacer := Control.new()
	filter_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_row.add_child(filter_spacer)

	var divider := HSeparator.new()
	divider.add_theme_constant_override("separation", 1)
	outer_stack.add_child(divider)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	outer_stack.add_child(body)

	var list_panel := PanelContainer.new()
	list_panel.custom_minimum_size = Vector2(300, 0)
	list_panel.add_theme_stylebox_override("panel", _style(SURFACE_INSET, BORDER_SOFT, 10, 1))
	body.add_child(list_panel)
	var list_margin := MarginContainer.new()
	_set_margins(list_margin, 9, 9, 9, 9)
	list_panel.add_child(list_margin)
	var list_stack := VBoxContainer.new()
	list_stack.add_theme_constant_override("separation", 8)
	list_margin.add_child(list_stack)
	var list_header := HBoxContainer.new()
	list_stack.add_child(list_header)
	list_heading_label = _label(11, MUTED_TEXT)
	list_heading_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_header.add_child(list_heading_label)
	list_count_label = _label(11, MUTED_TEXT)
	list_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	list_header.add_child(list_count_label)
	var list_scroll := ScrollContainer.new()
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_stack.add_child(list_scroll)
	quest_list = VBoxContainer.new()
	quest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_list.add_theme_constant_override("separation", 7)
	list_scroll.add_child(quest_list)
	empty_list_label = _label(13, MUTED_TEXT)
	empty_list_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_list_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_list_label.custom_minimum_size = Vector2(260, 80)
	quest_list.add_child(empty_list_label)

	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _style(SURFACE, BORDER_SOFT, 10, 1))
	body.add_child(detail_panel)
	var detail_margin := MarginContainer.new()
	_set_margins(detail_margin, 20, 18, 20, 18)
	detail_panel.add_child(detail_margin)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_margin.add_child(detail_scroll)
	detail_content = VBoxContainer.new()
	detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_content.add_theme_constant_override("separation", 10)
	detail_scroll.add_child(detail_content)
	detail_type_label = _label(12, ACCENT)
	detail_content.add_child(detail_type_label)
	detail_title_label = _label(23, TEXT)
	detail_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_content.add_child(detail_title_label)
	detail_summary_label = _label(14, MUTED_TEXT)
	detail_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_content.add_child(detail_summary_label)
	var detail_divider := HSeparator.new()
	detail_content.add_child(detail_divider)
	detail_objective_heading = _label(12, ACCENT)
	detail_content.add_child(detail_objective_heading)
	detail_steps = VBoxContainer.new()
	detail_steps.add_theme_constant_override("separation", 8)
	detail_content.add_child(detail_steps)


func _refresh_tracker() -> void:
	var journal_service := _journal_service()
	var quest: Dictionary = journal_service.get_active_main_quest() if journal_service != null else {}
	var objective: Dictionary = journal_service.get_active_objective(quest) if journal_service != null else {}
	tracker_panel.visible = not quest.is_empty() and not objective.is_empty()
	if not tracker_panel.visible:
		return
	tracker_panel.tooltip_text = localization_manager.text("ui.quest.open_log")
	tracker_type_label.text = localization_manager.text("ui.quest.main_story").to_upper()
	tracker_title_label.text = _localized_definition(
		str(quest.get("titleKey", "")),
		str(quest.get("questId", ""))
	)
	tracker_objective_label.text = "› %s" % _localized_definition(
		str(objective.get("objectiveKey", "")),
		str(objective.get("stepId", ""))
	)
	var current := int(objective.get("currentValue", 0))
	var target := maxi(int(objective.get("targetValue", 1)), 1)
	tracker_progress_label.text = "%d / %d" % [current, target] if target > 1 else ""


func _refresh_journal() -> void:
	journal_title_label.text = localization_manager.text("ui.quest.log_title")
	journal_subtitle_label.text = localization_manager.text("ui.quest.log_subtitle")
	close_button.text = localization_manager.text("common.close")
	list_heading_label.text = localization_manager.text("ui.quest.list_heading").to_upper()
	detail_objective_heading.text = localization_manager.text("ui.quest.objectives").to_upper()

	_clear_children_except(quest_list, empty_list_label)

	var journal_service := _journal_service()
	var all_entries: Array = journal_service.get_entries() if journal_service != null else []
	var entries := _filter_entries(all_entries)
	_refresh_filter_buttons(all_entries)
	list_count_label.text = str(entries.size())
	empty_list_label.text = localization_manager.text(
		"ui.quest.empty" if all_entries.is_empty() else "ui.quest.empty_filter"
	)
	empty_list_label.visible = entries.is_empty()
	if entries.is_empty():
		selected_quest_id = ""
		_show_empty_detail()
		return

	var selected_exists := false
	for quest_value: Variant in entries:
		var quest: Dictionary = quest_value as Dictionary
		if str(quest.get("questId", "")) == selected_quest_id:
			selected_exists = true
	if not selected_exists:
		var active_quest: Dictionary = journal_service.get_active_main_quest()
		selected_quest_id = str(active_quest.get("questId", "")) if _entry_matches_filter(active_quest) else ""
		if selected_quest_id.is_empty():
			selected_quest_id = str((entries[0] as Dictionary).get("questId", ""))

	var current_section := ""
	for quest_value: Variant in entries:
		var quest: Dictionary = quest_value as Dictionary
		var quest_id := str(quest.get("questId", ""))
		var status := str(quest.get("status", ""))
		var section := "active" if status == "active" else "history"
		if section != current_section:
			current_section = section
			var section_label := _label(10, MUTED_TEXT)
			section_label.text = localization_manager.text("ui.quest.section.%s" % section).to_upper()
			section_label.add_theme_constant_override("outline_size", 1)
			quest_list.add_child(section_label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 70)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s  •  %s\n%s" % [
			_quest_type_text(str(quest.get("questType", "main"))).to_upper(),
			_status_text(status).to_upper(),
			_localized_definition(str(quest.get("titleKey", "")), quest_id),
		]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_quest_button(
			button,
			quest_id == selected_quest_id,
			str(quest.get("questType", "main"))
		)
		button.pressed.connect(_on_quest_selected.bind(quest_id))
		quest_list.add_child(button)

	_show_quest_detail(_find_entry(entries, selected_quest_id))


func _show_quest_detail(quest: Dictionary) -> void:
	if quest.is_empty():
		_show_empty_detail()
		return
	var quest_type := str(quest.get("questType", "main"))
	detail_type_label.text = "%s  •  %s" % [
		_quest_type_text(quest_type).to_upper(),
		_status_text(str(quest.get("status", ""))).to_upper(),
	]
	detail_type_label.add_theme_color_override(
		"font_color",
		_quest_type_color(quest_type)
	)
	detail_title_label.text = _localized_definition(
		str(quest.get("titleKey", "")),
		str(quest.get("questId", ""))
	)
	detail_summary_label.text = _localized_definition(
		str(quest.get("summaryKey", "")),
		str(quest.get("questId", ""))
	)
	detail_objective_heading.visible = true
	_clear_children_except(detail_steps)
	var journal_service := _journal_service()
	var visible_steps: Array = journal_service.get_visible_steps(quest) if journal_service != null else []
	for step_value: Variant in visible_steps:
		var step: Dictionary = step_value as Dictionary
		var status := str(step.get("status", ""))
		var row_panel := PanelContainer.new()
		row_panel.add_theme_stylebox_override(
			"panel",
			_objective_row_style(status, quest_type)
		)
		detail_steps.add_child(row_panel)
		var row_margin := MarginContainer.new()
		_set_margins(row_margin, 11, 8, 11, 8)
		row_panel.add_child(row_margin)
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_theme_font_size_override("font_size", 13)
		row.add_theme_color_override("font_color", _objective_color(status, quest_type))
		row.text = "%s  %s%s" % [
			_step_marker(status),
			_localized_definition(str(step.get("objectiveKey", "")), str(step.get("stepId", ""))),
			_step_progress_suffix(step),
		]
		row_margin.add_child(row)


func _show_empty_detail() -> void:
	detail_type_label.text = localization_manager.text("ui.quest.list_heading").to_upper()
	detail_type_label.add_theme_color_override("font_color", MUTED_TEXT)
	detail_title_label.text = localization_manager.text("ui.quest.empty_title")
	detail_summary_label.text = localization_manager.text("ui.quest.empty_detail")
	detail_objective_heading.visible = false
	_clear_children_except(detail_steps)


func set_filter(filter_id: String) -> void:
	if filter_id not in JOURNAL_FILTERS or selected_filter == filter_id:
		return
	selected_filter = filter_id
	selected_quest_id = ""
	_refresh_journal()


func _on_quest_selected(quest_id: String) -> void:
	selected_quest_id = quest_id
	_refresh_journal()


func _on_tracker_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			open_journal()
			accept_event()


func _on_journal_changed() -> void:
	refresh()


func _on_locale_changed(_locale: String) -> void:
	refresh()


func _journal_service() -> Node:
	return get_node_or_null("/root/QuestJournalService")


func _find_entry(entries: Array, quest_id: String) -> Dictionary:
	for quest_value: Variant in entries:
		var quest: Dictionary = quest_value as Dictionary
		if str(quest.get("questId", "")) == quest_id:
			return quest
	return {}


func _filter_entries(entries: Array) -> Array:
	var result: Array = []
	for quest_value: Variant in entries:
		if not (quest_value is Dictionary):
			continue
		var quest: Dictionary = quest_value as Dictionary
		if _entry_matches_filter(quest):
			result.append(quest.duplicate(true))
	return result


func _entry_matches_filter(quest: Dictionary) -> bool:
	if quest.is_empty():
		return false
	match selected_filter:
		"main", "side":
			return str(quest.get("questType", "main")) == selected_filter
		"completed":
			return str(quest.get("status", "")) == "completed"
		_:
			return true


func _refresh_filter_buttons(entries: Array) -> void:
	for filter_id: String in JOURNAL_FILTERS:
		var button: Button = filter_buttons.get(filter_id) as Button
		if button == null:
			continue
		var count := 0
		for quest_value: Variant in entries:
			if quest_value is Dictionary and _quest_matches_filter_id(quest_value as Dictionary, filter_id):
				count += 1
		button.text = "%s  %d" % [
			localization_manager.text("ui.quest.filter.%s" % filter_id),
			count,
		]
		_style_filter_button(button, filter_id == selected_filter, filter_id)


func _quest_matches_filter_id(quest: Dictionary, filter_id: String) -> bool:
	match filter_id:
		"main", "side":
			return str(quest.get("questType", "main")) == filter_id
		"completed":
			return str(quest.get("status", "")) == "completed"
		_:
			return true


func _localized_definition(key: String, fallback_id: String) -> String:
	var normalized_key := key.strip_edges()
	if not normalized_key.is_empty() and localization_manager.has_key(normalized_key):
		return localization_manager.text(normalized_key)
	return fallback_id.replace("_", " ").capitalize()


func _status_text(status: String) -> String:
	return localization_manager.text("ui.quest.status.%s" % status)


func _quest_type_text(quest_type: String) -> String:
	return localization_manager.text(
		"ui.quest.side_quest" if quest_type == "side" else "ui.quest.main_story"
	)


func _quest_type_color(quest_type: String) -> Color:
	return SIDE_QUEST_ACCENT if quest_type == "side" else ACCENT


func _status_color(status: String) -> Color:
	match status:
		"completed":
			return SUCCESS
		"failed":
			return DANGER
		"active":
			return ACCENT
		_:
			return MUTED_TEXT


func _objective_color(status: String, quest_type: String) -> Color:
	if status == "active":
		return _quest_type_color(quest_type)
	return _status_color(status)


func _objective_row_style(status: String, quest_type: String) -> StyleBoxFlat:
	var accent := _objective_color(status, quest_type)
	return _style(
		_color_with_alpha(accent, 0.08) if status == "active" else SURFACE_INSET,
		_color_with_alpha(accent, 0.5) if status in ["active", "failed"] else BORDER_SOFT,
		7,
		1
	)


func _step_marker(status: String) -> String:
	match status:
		"completed":
			return "✓"
		"active":
			return "›"
		"failed":
			return "!"
		_:
			return "–"


func _step_progress_suffix(step: Dictionary) -> String:
	var target := maxi(int(step.get("targetValue", 1)), 1)
	if target <= 1:
		return ""
	return "  (%d/%d)" % [int(step.get("currentValue", 0)), target]


func _label(font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result


func _clear_children_except(container: Node, preserved: Node = null) -> void:
	for child: Node in container.get_children():
		if child == preserved:
			continue
		container.remove_child(child)
		child.queue_free()


func _set_margins(container: MarginContainer, left: int, top: int, right: int, bottom: int) -> void:
	container.add_theme_constant_override("margin_left", left)
	container.add_theme_constant_override("margin_top", top)
	container.add_theme_constant_override("margin_right", right)
	container.add_theme_constant_override("margin_bottom", bottom)


func _style(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = background
	result.border_color = border
	result.set_border_width_all(width)
	result.set_corner_radius_all(radius)
	return result


func _color_with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


func _style_filter_button(button: Button, selected: bool, filter_id: String) -> void:
	var accent := SIDE_QUEST_ACCENT if filter_id == "side" else ACCENT
	var background := _color_with_alpha(accent, 0.12) if selected else SURFACE_INSET
	var border := _color_with_alpha(accent, 0.85) if selected else BORDER_SOFT
	button.add_theme_color_override("font_color", TEXT if selected else MUTED_TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_stylebox_override("normal", _style(background, border, 7, 1))
	button.add_theme_stylebox_override("hover", _style(SURFACE_RAISED, accent, 7, 1))
	button.add_theme_stylebox_override("pressed", _style(SURFACE_INSET, accent, 7, 1))
	button.add_theme_stylebox_override("focus", _style(background, accent, 7, 1))


func _style_quest_button(button: Button, selected: bool, quest_type: String) -> void:
	var accent := _quest_type_color(quest_type)
	var background := _color_with_alpha(accent, 0.12) if selected else Color("#0b1a2bea")
	var border := accent if selected else BORDER_SOFT
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _style(background, border, 8, 1))
	button.add_theme_stylebox_override("hover", _style(Color("#112a44f2"), accent, 8, 1))
	button.add_theme_stylebox_override("pressed", _style(Color("#060e18f2"), accent, 8, 1))
	button.add_theme_stylebox_override("focus", _style(background, accent, 8, 1))


func _style_button(button: Button, selected: bool) -> void:
	var border := ACCENT if selected else BORDER_SOFT
	var normal_background := Color("#10263be8") if selected else Color("#0b1a2bea")
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_stylebox_override("normal", _style(normal_background, border, 8, 1))
	button.add_theme_stylebox_override("hover", _style(Color("#112a44f2"), ACCENT, 8, 1))
	button.add_theme_stylebox_override("pressed", _style(Color("#060e18f2"), ACCENT, 8, 1))
	button.add_theme_stylebox_override("focus", _style(normal_background, ACCENT, 8, 1))
