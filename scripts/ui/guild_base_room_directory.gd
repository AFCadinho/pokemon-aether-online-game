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

func open(data: Dictionary, lift := false) -> void:
	_data = data.duplicate(true)
	_lift = lift
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
	panel.custom_minimum_size = Vector2(minf(580, viewport_size.x - 32), minf(580, viewport_size.y - 32))
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
	content.add_child(title)
	_hint = Label.new()
	_hint.text = _t("lift_hint", {"floor": _floor_label(int(_data.get("currentFloor", 0)))}) if _lift else _t("directory_hint")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_color", MUTED)
	content.add_child(_hint)
	var own := _button(_t("my_room"), "FindMyRoom")
	own.pressed.connect(_show_my_room)
	content.add_child(own)
	if not _lift:
		_search = LineEdit.new()
		_search.name = "PlayerSearch"
		_search.placeholder_text = _t("search")
		_search.custom_minimum_size.y = 42
		_search.clear_button_enabled = true
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
	if _lift:
		_build_floors()
		_travel = _button(_t("choose_floor"), "TravelButton")
		_travel.disabled = true
		_travel.pressed.connect(_finish_selected)
		content.add_child(_travel)
	else:
		_render_rooms()
	var close := _button(str(get_node("/root/LocalizationManager").call("text", "common.close")), "CloseButton")
	close.pressed.connect(_finish.bind(-1))
	content.add_child(close)
	if _search != null:
		_search.grab_focus()

func _build_floors() -> void:
	var floors: Array = [0]
	floors.append_array(_data.get("floors", []))
	for value: Variant in floors:
		var floor := int(value)
		var button := _button(_floor_label(floor), "Floor%d" % floor)
		button.pressed.connect(_select_floor.bind(floor))
		_list.add_child(button)
		_floor_buttons[floor] = button

func _select_floor(floor: int) -> void:
	_selected_floor = floor
	for value: Variant in _floor_buttons:
		var button: Button = _floor_buttons[value]
		button.add_theme_stylebox_override("normal", _style(Color("30413a") if int(value) == floor else CARD, GOLD if int(value) == floor else Color("355466")))
	_travel.disabled = false
	_travel.text = _t("go_to_floor", {"floor": _floor_label(floor)})

func _finish_selected() -> void:
	if _selected_floor >= 0:
		_finish(_selected_floor)

func _show_my_room() -> void:
	var mine: Dictionary = _data.get("myRoom", {})
	if mine.is_empty():
		_hint.text = _t("no_room")
		return
	_hint.text = _room_address(mine)
	if _lift:
		_select_floor(int(mine.floor))
	else:
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
