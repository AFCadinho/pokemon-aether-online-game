extends VBoxContainer

const ErrorText := preload("res://scripts/services/backend_error_localization_service.gd")
const SelectorStyle := preload("res://scripts/ui/language_selector_style.gd")
const MANAGE_ACTIONS := ["rename", "update", "delete"]

var service: Node
var guild_id := 0
var state: Dictionary = {}
var room_key := "right_room"
var mode := "saved"
var selected: Dictionary = {}
var busy := false
var room_select: OptionButton
var rows: ItemList
var empty_state: PanelContainer
var empty_title: Label
var empty_hint: Label
var selection_panel: VBoxContainer
var selection_title: Label
var selection_hint: Label
var list_hint: Label
var current_room_actions: VBoxContainer
var current_room_label: Label
var rights_hint: Label
var more_actions: MenuButton
var name_field: LineEdit
var name_dialog: AetherConfirmationDialog
var status: Label
var controls: Dictionary = {}
var tabs: Array[Button] = []


func configure(guild_service: Node, owner_id: int) -> void:
	service = guild_service
	guild_id = owner_id
	add_theme_constant_override("separation", 10)
	room_select = OptionButton.new()
	SelectorStyle.configure(room_select)
	room_select.add_item(_t("room_1"))
	room_select.add_item(_t("room_2"))
	room_select.item_selected.connect(_switch_room)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	add_child(header)
	room_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(room_select)
	_button(header, "reload", refresh)
	controls.reload.size_flags_horizontal = Control.SIZE_SHRINK_END
	controls.reload.add_theme_font_size_override("font_size", 14)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	add_child(tab_row)
	var group := ButtonGroup.new()
	for value: String in ["saved", "template"]:
		var button := Button.new()
		button.text = _t(value)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_group = group
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_switch_mode.bind(value))
		tab_row.add_child(button)
		tabs.append(button)
	list_hint = _label("choose_design")
	add_child(list_hint)
	rows = ItemList.new()
	rows.name = "RoomDesignList"
	rows.custom_minimum_size.y = 140
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_theme_font_size_override("font_size", 15)
	rows.add_theme_constant_override("v_separation", 8)
	rows.item_selected.connect(_select)
	add_child(rows)
	_build_empty_state()
	selection_panel = VBoxContainer.new()
	selection_panel.add_theme_constant_override("separation", 6)
	add_child(selection_panel)
	selection_title = _label("")
	selection_title.add_theme_font_size_override("font_size", 17)
	selection_title.add_theme_color_override("font_color", Color("#f6cf72"))
	selection_panel.add_child(selection_title)
	selection_hint = _label("")
	selection_panel.add_child(selection_hint)
	var selected_actions := HBoxContainer.new()
	selected_actions.add_theme_constant_override("separation", 8)
	selection_panel.add_child(selected_actions)
	for choice: String in ["preview", "apply", "redeem"]:
		_button(selected_actions, choice, _act.bind(choice))
	_style_primary(controls.apply)
	_style_primary(controls.redeem)
	more_actions = MenuButton.new()
	more_actions.name = "DesignMoreActions"
	more_actions.text = _t("more_actions")
	more_actions.icon = SelectorStyle.DROPDOWN_ARROW
	more_actions.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	more_actions.add_theme_constant_override("h_separation", 8)
	more_actions.flat = false
	more_actions.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	more_actions.switch_on_hover = false
	selected_actions.add_child(more_actions)
	var popup := more_actions.get_popup()
	SelectorStyle._configure_popup(popup)
	for choice: String in MANAGE_ACTIONS:
		popup.add_item(_t("replace_current" if choice == "update" else choice))
	popup.id_pressed.connect(func(index: int): _act(MANAGE_ACTIONS[index]))
	current_room_actions = VBoxContainer.new()
	current_room_actions.add_theme_constant_override("separation", 6)
	add_child(current_room_actions)
	current_room_actions.add_child(HSeparator.new())
	current_room_label = _label("current_room")
	current_room_actions.add_child(current_room_label)
	var current_actions := HBoxContainer.new()
	current_actions.add_theme_constant_override("separation", 8)
	current_room_actions.add_child(current_actions)
	_button(current_actions, "save", _open_name_dialog.bind("save"))
	controls.save.text = _t("save_current")
	_button(current_actions, "restore", _act.bind("restore"))
	rights_hint = _label("read_only")
	add_child(rights_hint)
	status = _label("")
	add_child(status)
	_render()


func _label(key: String) -> Label:
	var label := Label.new()
	label.text = _t(key) if not key.is_empty() else ""
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("#a8becb"))
	return label


func _build_empty_state() -> void:
	empty_state = PanelContainer.new()
	empty_state.name = "EmptyRoomDesigns"
	empty_state.custom_minimum_size.y = 140
	empty_state.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var skin := preload("res://scripts/ui/guild_base_room_directory.gd").new()
	empty_state.add_theme_stylebox_override("panel", skin._style(Color("#08141e"), Color("#355466")))
	skin.free()
	add_child(empty_state)
	var column := VBoxContainer.new()
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 10)
	empty_state.add_child(column)
	empty_title = _label("")
	empty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_title.add_theme_font_size_override("font_size", 17)
	empty_title.add_theme_color_override("font_color", Color("#edf6fc"))
	column.add_child(empty_title)
	empty_hint = _label("")
	empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(empty_hint)


func _style_primary(button: Button) -> void:
	var skin := preload("res://scripts/ui/guild_base_room_directory.gd").new()
	button.add_theme_stylebox_override("normal", skin._style(Color("#16485b"), Color("#65bbc6")))
	skin.free()


func _switch_room(index: int) -> void:
	if busy:
		return
	room_key = "right_room" if index == 0 else "left_room"
	selected = {}
	_set_status("")
	_render()


func _switch_mode(value: String) -> void:
	if busy:
		return
	mode = value
	selected = {}
	_set_status("")
	_render()


func refresh() -> void:
	if busy:
		return
	busy = true
	_update_controls()
	_set_status(_t("loading"))
	var result: Dictionary = await service.base_design_library(guild_id)
	if not is_inside_tree():
		return
	busy = false
	if bool(result.get("success", false)):
		state = result.state
		_set_status("")
		_render()
	else:
		_set_status(ErrorText.message(result))
		_update_controls()


func _button(row: HBoxContainer, key: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = "DesignAction_" + key
	button.text = _t(key)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	row.add_child(button)
	controls[key] = button


func _render() -> void:
	rows.clear()
	for design: Dictionary in state.get("saved" if mode == "saved" else "templates", []):
		if str(design.roomKey) != room_key:
			continue
		if mode == "template" and not bool(design.get("unlocked", false)) and int(design.get("bagQuantity", 0)) <= 0:
			continue
		var text := str(design.name)
		if mode == "template":
			text += " · " + _t("owned" if bool(design.get("unlocked", false)) else "in_bag", {"count": int(design.get("bagQuantity", 0))})
		rows.add_item(text)
		rows.set_item_tooltip(rows.item_count - 1, text)
		rows.set_item_metadata(rows.item_count - 1, design)
		if str(design.id) == str(selected.get("id", "")):
			rows.select(rows.item_count - 1)
			selected = design
	if rows.get_selected_items().is_empty():
		selected = {}
	rows.visible = rows.item_count > 0
	empty_state.visible = rows.item_count == 0
	list_hint.visible = rows.item_count > 0
	empty_title.text = _t("empty_saved" if mode == "saved" else "empty_templates")
	empty_hint.text = _t("empty_saved_hint" if mode == "saved" and bool(state.get("canEdit", false)) else "empty_saved_read_only" if mode == "saved" else "empty_templates_hint")
	tabs[0].set_pressed_no_signal(mode == "saved")
	tabs[1].set_pressed_no_signal(mode == "template")
	_update_controls()


func _select(index: int) -> void:
	if busy:
		return
	selected = rows.get_item_metadata(index)
	_set_status("")
	_update_controls()


func _update_controls() -> void:
	var can_edit := bool(state.get("canEdit", false)) and not busy
	room_select.disabled = busy
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE if busy else Control.MOUSE_FILTER_STOP
	rows.focus_mode = Control.FOCUS_NONE if busy else Control.FOCUS_ALL
	for tab: Button in tabs:
		tab.disabled = busy
	for key: String in controls:
		controls[key].disabled = busy or state.is_empty()
	controls.reload.disabled = busy
	controls.save.disabled = not can_edit
	selection_panel.visible = not selected.is_empty()
	list_hint.visible = rows.item_count > 0 and selected.is_empty()
	selection_title.text = str(selected.get("name", ""))
	selection_hint.text = _t("saved_details", {"count": selected.get("items", []).size()}) if mode == "saved" else _t("owned_hint" if bool(selected.get("unlocked", false)) else "donate_hint")
	controls.preview.disabled = busy or selected.is_empty()
	var unlocked := mode == "saved" or bool(selected.get("unlocked", false))
	controls.apply.visible = unlocked
	controls.apply.disabled = not can_edit or selected.is_empty() or not unlocked
	controls.redeem.visible = mode == "template" and not unlocked
	controls.redeem.disabled = busy or selected.is_empty() or unlocked or int(selected.get("bagQuantity", 0)) <= 0
	more_actions.visible = mode == "saved" and bool(state.get("canEdit", false))
	more_actions.disabled = not can_edit or selected.is_empty()
	for index: int in range(MANAGE_ACTIONS.size()):
		more_actions.get_popup().set_item_disabled(index, more_actions.disabled)
	current_room_actions.visible = mode == "saved" and bool(state.get("canEdit", false))
	current_room_label.visible = selected.is_empty()
	controls.restore.visible = state.get("backups", {}).has(room_key)
	controls.restore.disabled = not can_edit or not controls.restore.visible
	rights_hint.visible = not state.is_empty() and not bool(state.get("canEdit", false))
	status.visible = not status.text.is_empty()


func _set_status(message: String) -> void:
	status.text = message
	status.visible = not message.is_empty()


func _open_name_dialog(operation: String) -> void:
	if busy or not bool(state.get("canEdit", false)) or (operation == "rename" and selected.is_empty()):
		return
	if is_instance_valid(name_dialog):
		return
	var dialog := preload("res://scenes/interface/aether_confirmation_dialog.tscn").instantiate() as AetherConfirmationDialog
	name_dialog = dialog
	add_child(dialog)
	var details: Dictionary = {"designId": str(selected.get("id", "")), "source": "saved"} if operation == "rename" else {}
	dialog.configure(_t("rename" if operation == "rename" else "save_current"), _t("rename_hint", {"design": str(selected.get("name", ""))}) if operation == "rename" else _t("save_hint", {"room": room_select.get_item_text(room_select.selected)}), _t("rename" if operation == "rename" else "save_design"), _t("cancel"))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.add_child(_label("design_name"))
	name_field = LineEdit.new()
	name_field.name = "RoomDesignName"
	name_field.max_length = 40
	name_field.placeholder_text = _t("design_name")
	name_field.text = str(selected.get("name", "")) if operation == "rename" else ""
	name_field.add_theme_font_size_override("font_size", 15)
	name_field.add_theme_stylebox_override("normal", SelectorStyle._button_style(Color("#07111f"), Color("#315070")))
	name_field.add_theme_stylebox_override("focus", SelectorStyle._button_style(Color("#0d2037"), Color("#65bbc6")))
	column.add_child(name_field)
	dialog.add_custom_control(column)
	var field := name_field
	dialog.confirm_button.disabled = field.text.strip_edges().is_empty()
	field.text_changed.connect(func(value: String): dialog.confirm_button.disabled = value.strip_edges().is_empty())
	field.text_submitted.connect(func(_value: String):
		if not dialog.confirm_button.disabled:
			dialog.hide_dialog()
			dialog.confirmed.emit()
	)
	dialog.confirmed.connect(func():
		var value := field.text.strip_edges()
		name_dialog = null
		name_field = null
		dialog.queue_free()
		if not value.is_empty():
			_change(operation, details, false, value)
	, CONNECT_ONE_SHOT)
	dialog.canceled.connect(func(): name_dialog = null; name_field = null; dialog.queue_free(), CONNECT_ONE_SHOT)
	dialog.popup_centered(Vector2i(480, 300), true)
	field.grab_focus.call_deferred()
	field.select_all.call_deferred()


func _act(choice: String) -> void:
	if busy:
		return
	if choice == "preview":
		if selected.is_empty():
			return
		var viewer := preload("res://scripts/ui/guild_room_design_preview.gd").new()
		add_child(viewer)
		viewer.open_preview(room_key, selected.items, str(selected.name))
		return
	if choice == "rename":
		_open_name_dialog("rename")
		return
	var payload := {"designId": str(selected.get("id", "")), "source": mode}
	match choice:
		"update": _change("save", payload, true)
		"delete": _change("delete", payload, true)
		"apply": _change("apply", payload, true)
		"redeem": _change("redeem", payload, true)
		"restore": _change("apply", {"source": "backup"}, true)


func _change(operation: String, details: Dictionary, confirm := false, design_name := "") -> void:
	if busy or state.is_empty():
		return
	if operation != "redeem" and not bool(state.get("canEdit", false)):
		return
	var payload := {"action": operation, "roomKey": room_key, "expectedRevision": int(state.revision), "expectedRoomRevision": int(state.rooms[room_key].revision), "name": design_name if not design_name.is_empty() else str(selected.get("name", ""))}
	payload.merge(details, true)
	if confirm:
		var dialog := preload("res://scenes/interface/aether_confirmation_dialog.tscn").instantiate() as AetherConfirmationDialog
		add_child(dialog)
		var confirmation_key := "restore" if str(details.get("source", "")) == "backup" else "update" if operation == "save" and details.has("designId") else operation
		dialog.configure(_t(confirmation_key), _t("confirm_" + confirmation_key, {"guild": str(state.guildName), "design": str(selected.get("name", ""))}), _t(confirmation_key), _t("cancel"))
		dialog.confirmed.connect(func(): dialog.queue_free(); _send(payload), CONNECT_ONE_SHOT)
		dialog.canceled.connect(dialog.queue_free, CONNECT_ONE_SHOT)
		dialog.popup_centered(Vector2i(460, 210))
	else:
		await _send(payload)


func _send(payload: Dictionary) -> void:
	if busy:
		return
	busy = true
	_update_controls()
	var result: Dictionary = await service.change_base_design(guild_id, payload)
	if not is_inside_tree():
		return
	busy = false
	if bool(result.get("success", false)):
		state = result.state
		_set_status(_t("done"))
		_render()
		if str(payload.action) == "redeem":
			get_node("/root/InventoryService").load_inventory()
	else:
		_set_status(ErrorText.message(result))
		_update_controls()


func _t(key: String, parameters: Dictionary = {}) -> String:
	return get_node("/root/LocalizationManager").text("ui.guild_design." + key, parameters)
