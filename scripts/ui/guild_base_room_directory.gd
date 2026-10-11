extends CanvasLayer

signal resolved(floor: int)

const PANEL := Color("101c28f5")
const CARD := Color("172c3b")
const ACCENT := Color("65cbd8")
const GOLD := Color("efd28a")
const MUTED := Color("a0b9c9")
var _data: Dictionary = {}
var _lift := false
var _finished := false
var _lock_owner: StringName
var _list: VBoxContainer
var _search: LineEdit
var _hint: Label
var _travel: Button
var _selected_floor := -1
var _mine_only := false
var _floor_buttons: Dictionary = {}
var _all_floors: Array[int] = []
var _floor_grid: GridContainer
var _floor_scroll: ScrollContainer
var _destination: Label
var _empty_floors: Label
var _stack_shortcuts := false
var _floor_player_names: Dictionary = {}
var _floor_addresses: Dictionary = {}

func open(data: Dictionary, lift := false) -> void:
	_data = data.duplicate(true)
	_lift = lift
	if _lift:
		_all_floors = [0]
		for value: Variant in _data.get("floors", []):
			var floor := int(value)
			if floor > 0 and not _all_floors.has(floor):
				_all_floors.append(floor)
		_all_floors.sort()
		for room: Dictionary in _data.get("rooms", []):
			var floor := int(room.get("floor", -1))
			_floor_player_names[floor] = str(_floor_player_names.get(floor, "")) + "\n" + str(room.get("name", "")).to_lower()
			_floor_addresses[floor] = str(_floor_addresses.get(floor, "")) + "\n" + _room_address(room)
	layer = 120
	_lock_owner = StringName("guild_base_directory_%d" % get_instance_id())
	get_node("/root/GameState").acquire_overworld_input_lock(_lock_owner)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.035, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "GuildBaseRoomDirectory"
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width := minf(540 if _lift else 580, viewport_size.x - 32)
	_stack_shortcuts = panel_width < 460
	var columns := _floor_columns(panel_width - 44)
	var lift_rows := ceili(float(maxi(_all_floors.size() - 1, 1)) / columns)
	var panel_height := minf(520, 370 + lift_rows * 72 + (50 if _stack_shortcuts else 0)) if _lift else 580.0
	panel.custom_minimum_size = Vector2(panel_width, minf(panel_height, viewport_size.y - 32))
	panel.add_theme_stylebox_override("panel", _style(PANEL, ACCENT))
	panel.theme = _theme()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var title := Label.new()
	title.text = _t("lift_title" if _lift else "directory_title")
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", GOLD)
	if _lift:
		var header := HBoxContainer.new()
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(header)
		header.add_child(title)
		var close := _button("×", "CloseButton")
		close.custom_minimum_size.x = 42
		close.tooltip_text = str(get_node("/root/LocalizationManager").call("text", "common.close"))
		close.pressed.connect(_finish.bind(-1))
		header.add_child(close)
	else:
		content.add_child(title)
	_hint = Label.new()
	_hint.text = _t("lift_hint", {"floor": _floor_label(int(_data.get("currentFloor", 0)))}) if _lift else _t("directory_hint")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_color", MUTED)
	content.add_child(_hint)
	if _lift:
		_build_lift_content(content, columns)
	else:
		var own := _button(_t("my_room"), "FindMyRoom")
		own.pressed.connect(_show_my_room)
		content.add_child(own)
		_search = _search_field(_t("search"), "PlayerSearch")
		_search.text_changed.connect(_search_changed)
		content.add_child(_search)
		var scroll := ScrollContainer.new()
		scroll.name = "RoomsScroll"
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		content.add_child(scroll)
		_list = VBoxContainer.new()
		_list.name = "RoomResults"
		_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list.add_theme_constant_override("separation", 8)
		scroll.add_child(_list)
		_render_rooms()
		var close := _button(str(get_node("/root/LocalizationManager").call("text", "common.close")), "CloseButton")
		close.pressed.connect(_finish.bind(-1))
		content.add_child(close)
	_search.grab_focus()

func _build_lift_content(content: VBoxContainer, columns: int) -> void:
	var shortcuts: BoxContainer = VBoxContainer.new() if _stack_shortcuts else HBoxContainer.new()
	shortcuts.name = "LiftShortcuts"
	shortcuts.add_theme_constant_override("separation", 8)
	content.add_child(shortcuts)
	var ground := _button(_t("ground"), "GroundFloorShortcut")
	ground.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ground.pressed.connect(_reveal_floor.bind(0))
	shortcuts.add_child(ground)
	_floor_buttons[0] = ground
	var mine: Dictionary = _data.get("myRoom", {})
	var own := _button(_t("my_room"), "FindMyRoom")
	if not mine.is_empty():
		own.text += " · " + str(int(mine.get("floor", 0)))
		own.tooltip_text = _room_address(mine)
	own.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	own.pressed.connect(_show_my_room)
	shortcuts.add_child(own)
	_search = _search_field(_t("floor_search"), "FloorSearch")
	_search.text_changed.connect(_filter_floors)
	_search.text_submitted.connect(_submit_floor_search)
	content.add_child(_search)
	_floor_scroll = ScrollContainer.new()
	_floor_scroll.name = "FloorScroll"
	_floor_scroll.custom_minimum_size.y = 72
	_floor_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_floor_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(_floor_scroll)
	_floor_scroll.resized.connect(_resize_floor_grid)
	var results := VBoxContainer.new()
	results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_floor_scroll.add_child(results)
	_floor_grid = GridContainer.new()
	_floor_grid.name = "FloorGrid"
	_floor_grid.columns = columns
	_floor_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_floor_grid.add_theme_constant_override("h_separation", 8)
	_floor_grid.add_theme_constant_override("v_separation", 8)
	results.add_child(_floor_grid)
	_empty_floors = Label.new()
	_empty_floors.text = _t("no_floors")
	_empty_floors.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	results.add_child(_empty_floors)
	var footer := HBoxContainer.new()
	footer.name = "LiftDestination"
	footer.add_theme_constant_override("separation", 12)
	content.add_child(footer)
	_destination = Label.new()
	_destination.name = "SelectedDestination"
	_destination.text = _t("choose_floor")
	_destination.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_destination.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_destination.add_theme_color_override("font_color", GOLD)
	footer.add_child(_destination)
	_travel = _button(_t("travel"), "TravelButton")
	_travel.custom_minimum_size.x = 140
	_travel.disabled = true
	_travel.pressed.connect(_finish_selected)
	footer.add_child(_travel)
	_render_floors()

func _search_field(placeholder: String, node_name: String) -> LineEdit:
	var field := LineEdit.new()
	field.name = node_name
	field.placeholder_text = placeholder
	field.custom_minimum_size.y = 42
	field.clear_button_enabled = true
	return field

func _resize_floor_grid() -> void:
	if _floor_grid != null:
		_floor_grid.columns = _floor_columns(_floor_scroll.size.x - 12)

func _floor_columns(width: float) -> int:
	var digits := str(_all_floors.back()).length() if not _all_floors.is_empty() else 2
	var cell_width := maxi(80, digits * 14 + 36)
	return clampi(int(width / cell_width), 2, 6)

func _filter_floors(_query: String) -> void:
	_render_floors()
	_floor_scroll.scroll_vertical = 0

func _render_floors() -> void:
	for child: Node in _floor_grid.get_children():
		child.free()
	var ground: Button = _floor_buttons[0]
	_floor_buttons.clear()
	_floor_buttons[0] = ground
	var query := _search.text.strip_edges().to_lower()
	for floor: int in _all_floors:
		if floor == 0 or not _floor_matches(floor, query):
			continue
		var button := _button(str(floor), "Floor%d" % floor)
		button.custom_minimum_size = Vector2(64, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 22)
		button.tooltip_text = _floor_label(floor)
		button.tooltip_text += str(_floor_addresses.get(floor, ""))
		button.pressed.connect(_select_floor.bind(floor))
		_floor_grid.add_child(button)
		_floor_buttons[floor] = button
	_empty_floors.visible = _floor_grid.get_child_count() == 0
	if _selected_floor >= 0:
		_select_floor(_selected_floor)

func _floor_matches(floor: int, query: String) -> bool:
	if query.is_empty():
		return true
	if query.is_valid_int():
		return floor == int(query)
	if _floor_label(floor).to_lower().contains(query):
		return true
	return str(_floor_player_names.get(floor, "")).contains(query)

func _submit_floor_search(query: String) -> void:
	var value := query.strip_edges()
	var target := -1
	if value.is_valid_int() and _all_floors.has(int(value)):
		target = int(value)
	elif _floor_grid.get_child_count() == 1:
		for floor: Variant in _floor_buttons:
			if int(floor) != 0:
				target = int(floor)
	if target < 0:
		return
	if value.is_valid_int():
		_reveal_floor(target)
	else:
		_select_floor(target)
	_travel.grab_focus()

func _reveal_floor(floor: int) -> void:
	_search.text = ""
	_render_floors()
	_select_floor(floor)
	if _floor_buttons.has(floor) and floor > 0:
		_scroll_to_selected_floor.call_deferred()

func _scroll_to_selected_floor() -> void:
	if _finished or not is_inside_tree():
		return
	await get_tree().process_frame
	if _finished or not is_inside_tree() or not _floor_buttons.has(_selected_floor):
		return
	var button: Button = _floor_buttons[_selected_floor]
	if _floor_scroll.is_ancestor_of(button):
		_floor_scroll.ensure_control_visible(button)

func _select_floor(floor: int) -> void:
	if not _all_floors.has(floor):
		return
	_selected_floor = floor
	for value: Variant in _floor_buttons:
		var button: Button = _floor_buttons[value]
		button.add_theme_stylebox_override("normal", _style(Color("30413a") if int(value) == floor else CARD, GOLD if int(value) == floor else Color("355466")))
	_travel.disabled = false
	_destination.text = _floor_label(floor)
	_travel.text = _t("travel")
	_travel.tooltip_text = _t("go_to_floor", {"floor": _floor_label(floor)})

func _finish_selected() -> void:
	if _selected_floor >= 0:
		_finish(_selected_floor)

func _show_my_room() -> void:
	var mine: Dictionary = _data.get("myRoom", {})
	if mine.is_empty():
		_hint.text = _t("no_room")
		return
	if _lift:
		_reveal_floor(int(mine.floor))
		_destination.text = _room_address(mine)
	else:
		_hint.text = _room_address(mine)
		_search.text = str(mine.name)
		_mine_only = true
		_render_rooms()

func _search_changed(_query: String) -> void:
	_mine_only = false
	_render_rooms()

func _render_rooms() -> void:
	for child: Node in _list.get_children():
		child.free()
	var query := _search.text.strip_edges().to_lower() if _search != null else ""
	var mine: Dictionary = _data.get("myRoom", {})
	var count := 0
	for room: Dictionary in _data.get("rooms", []):
		if _mine_only and room.get("userId") != mine.get("userId"):
			continue
		if not _mine_only and not query.is_empty() and not str(room.name).to_lower().contains(query):
			continue
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style(CARD, Color("355466")))
		_list.add_child(card)
		var label := Label.new()
		label.text = _room_address(room)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(label)
		count += 1
	if count == 0:
		var empty := Label.new()
		empty.text = _t("no_results")
		_list.add_child(empty)

func _room_address(room: Dictionary) -> String:
	return _t("address", {"name": str(room.get("name", "")), "floor": int(room.get("floor", 0)), "room": int(room.get("room", 0))})

func _floor_label(floor: int) -> String:
	return _t("ground") if floor == 0 else _t("floor", {"floor": floor})

func _button(text: String, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size.y = 42
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button

func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		theme.set_stylebox(state, "Button", _style(Color("243d4d") if state in ["hover", "pressed"] else CARD, ACCENT if state in ["hover", "focus"] else Color("355466")))
	theme.set_color("font_color", "Label", Color("edf6fc"))
	theme.set_color("font_color", "Button", Color("edf6fc"))
	theme.set_stylebox("normal", "LineEdit", _style(Color("0c1721"), Color("355466")))
	theme.set_stylebox("focus", "LineEdit", _style(Color("0c1721"), ACCENT))
	for state: String in ["scroll", "grabber", "grabber_highlight", "grabber_pressed"]:
		var background := Color("0c1721") if state == "scroll" else (ACCENT if state in ["grabber_highlight", "grabber_pressed"] else Color("467287"))
		var scrollbar := _style(background, background)
		scrollbar.content_margin_left = 4
		scrollbar.content_margin_right = 4
		scrollbar.content_margin_top = 4
		scrollbar.content_margin_bottom = 4
		theme.set_stylebox(state, "VScrollBar", scrollbar)
	return theme

func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _input(event: InputEvent) -> void:
	if not _finished and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish(-1)

func _finish(floor: int) -> void:
	if _finished:
		return
	_finished = true
	get_node("/root/GameState").release_overworld_input_lock(_lock_owner)
	resolved.emit(floor)
	queue_free()

func _exit_tree() -> void:
	if not _lock_owner.is_empty():
		get_node("/root/GameState").release_overworld_input_lock(_lock_owner)

func _t(key: String, values: Dictionary = {}) -> String:
	return str(get_node("/root/LocalizationManager").call("text", "ui.guild_base.rooms." + key, values))
