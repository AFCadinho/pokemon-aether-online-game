extends VBoxContainer

const ErrorText := preload("res://scripts/services/backend_error_localization_service.gd")
var service: Node
var guild_id := 0
var state: Dictionary = {}
var room_key := "right_room"
var mode := "saved"
var selected: Dictionary = {}
var busy := false
var room_select: OptionButton
var rows: ItemList
var name_field: LineEdit
var status: Label
var controls: Dictionary = {}
var tabs: Array[Button] = []

func configure(guild_service: Node, owner_id: int) -> void:
	service = guild_service
	guild_id = owner_id
	add_theme_constant_override("separation", 8)
	room_select = OptionButton.new()
	preload("res://scripts/ui/language_selector_style.gd").configure(room_select)
	room_select.add_item(_t("room_1"))
	room_select.add_item(_t("room_2"))
	room_select.item_selected.connect(func(index: int): room_key = "right_room" if index == 0 else "left_room"; selected = {}; _render())
	var header := HBoxContainer.new()
	add_child(header)
	room_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(room_select)
	_button(header, "reload", refresh)
	controls.reload.size_flags_horizontal = Control.SIZE_SHRINK_END
	controls.reload.custom_minimum_size.x = 100
	var tab_row := HBoxContainer.new()
	add_child(tab_row)
	for value: String in ["saved", "template"]:
		var button := Button.new()
		button.text = _t(value)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.pressed.connect(func(): mode = value; selected = {}; _render())
		tab_row.add_child(button)
		tabs.append(button)
	rows = ItemList.new()
	rows.custom_minimum_size.y = 110
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.item_selected.connect(_select)
	add_child(rows)
	var naming := HBoxContainer.new()
	add_child(naming)
	name_field = LineEdit.new()
	name_field.max_length = 40
	name_field.placeholder_text = _t("design_name")
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	naming.add_child(name_field)
	name_field.text_changed.connect(func(_value: String): _update_controls())
	_button(naming, "save", func(): _change("save", {}))
	for choices: Array in [["preview", "apply", "redeem"], ["update", "rename"], ["delete", "restore"]]:
		var row := HBoxContainer.new()
		add_child(row)
		for choice: String in choices:
			_button(row, choice, _act.bind(choice))
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	_update_controls()

func refresh() -> void:
	if busy:
		return
	busy = true
	_update_controls()
	status.text = _t("loading")
	var result: Dictionary = await service.base_design_library(guild_id)
	if not is_inside_tree():
		return
	busy = false
	if bool(result.get("success", false)):
		state = result.state
		status.text = _t("hint")
		_render()
	else:
		status.text = ErrorText.message(result)
		_update_controls()

func _button(row: HBoxContainer, key: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = _t(key)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	row.add_child(button)
	controls[key] = button

func _render() -> void:
	rows.clear()
	for design: Dictionary in state.get("saved" if mode == "saved" else "templates", []):
		if str(design.roomKey) != room_key:
			continue
		var text := str(design.name)
		if mode == "template":
			text += " · " + _t("owned" if bool(design.get("unlocked", false)) else "not_owned")
			if int(design.get("bagQuantity", 0)) > 0:
				text += " · " + _t("in_bag", {"count": int(design.bagQuantity)})
		rows.add_item(text)
		rows.set_item_metadata(rows.item_count - 1, design)
		if str(design.id) == str(selected.get("id", "")):
			rows.select(rows.item_count - 1)
			selected = design
	if rows.get_selected_items().is_empty():
		selected = {}
	name_field.visible = mode == "saved"
	tabs[0].set_pressed_no_signal(mode == "saved")
	tabs[1].set_pressed_no_signal(mode == "template")
	_update_controls()

func _select(index: int) -> void:
	selected = rows.get_item_metadata(index)
	if mode == "saved":
		name_field.text = str(selected.name)
	_update_controls()

func _update_controls() -> void:
	var can_edit := bool(state.get("canEdit", false)) and not busy
	room_select.disabled = busy
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE if busy else Control.MOUSE_FILTER_STOP
	name_field.editable = can_edit
	for tab: Button in tabs:
		tab.disabled = busy
	for key: String in controls:
		controls[key].disabled = busy or state.is_empty()
	controls.reload.disabled = busy
	controls.save.visible = mode == "saved"
	controls.save.disabled = not can_edit or name_field.text.strip_edges().is_empty()
	controls.preview.disabled = busy or selected.is_empty()
	controls.apply.disabled = not can_edit or selected.is_empty() or (mode == "template" and not bool(selected.get("unlocked", false)))
	controls.redeem.visible = mode == "template"
	controls.redeem.disabled = busy or selected.is_empty() or bool(selected.get("unlocked", false)) or int(selected.get("bagQuantity", 0)) <= 0
	for key: String in ["update", "rename", "delete"]:
		controls[key].visible = mode == "saved"
		controls[key].disabled = not can_edit or selected.is_empty() or (key != "delete" and name_field.text.strip_edges().is_empty())
	controls.restore.visible = mode == "saved"
	controls.restore.disabled = not can_edit or not state.get("backups", {}).has(room_key)

func _act(choice: String) -> void:
	if busy:
		return
	if choice == "preview":
		var viewer := preload("res://scripts/ui/guild_room_design_preview.gd").new()
		add_child(viewer)
		viewer.open_preview(room_key, selected.items, str(selected.name))
		return
	var payload := {"designId": str(selected.get("id", "")), "source": mode}
	match choice:
		"update": _change("save", payload, true)
		"rename": _change("rename", payload)
		"delete": _change("delete", payload, true)
		"apply": _change("apply", payload, true)
		"redeem": _change("redeem", payload, true)
		"restore": _change("apply", {"source": "backup"}, true)

func _change(operation: String, details: Dictionary, confirm := false) -> void:
	if busy or state.is_empty():
		return
	var payload := {"action": operation, "roomKey": room_key, "expectedRevision": int(state.revision), "expectedRoomRevision": int(state.rooms[room_key].revision), "name": name_field.text}
	payload.merge(details, true)
	if confirm:
		var dialog := preload("res://scenes/interface/aether_confirmation_dialog.tscn").instantiate() as AetherConfirmationDialog
		add_child(dialog)
		var confirmation_key := "restore" if str(details.get("source", "")) == "backup" else operation
		dialog.configure(_t(confirmation_key), _t("confirm_" + confirmation_key, {"guild": str(state.guildName), "design": str(selected.get("name", ""))}), _t(confirmation_key), _t("close"))
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
		status.text = _t("done")
		_render()
		if str(payload.action) == "redeem":
			get_node("/root/InventoryService").load_inventory()
	else:
		status.text = ErrorText.message(result)
		_update_controls()

func _t(key: String, parameters: Dictionary = {}) -> String:
	return get_node("/root/LocalizationManager").text("ui.guild_design." + key, parameters)
