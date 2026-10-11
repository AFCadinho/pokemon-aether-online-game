extends CanvasLayer

signal resolved(action: Dictionary)
const ErrorText := preload("res://scripts/services/backend_error_localization_service.gd")
const SelectorStyle := preload("res://scripts/ui/language_selector_style.gd")
var service: Node
var registrar_id := ""
var guild_id := 0
var host := false
var data: Dictionary = {}
var list: ItemList
var search: LineEdit
var status: Label
var action: Button
var decline: Button
var policy: OptionButton
var busy := false
var closed := false
var selected_id := 0
var lock_owner: StringName
var debounce: Timer
var visitor_page: VBoxContainer
var names_page: VBoxContainer
var name_fields: Dictionary = {}
var name_buttons: Array[Button] = []
var room_status: Label
var navigation: Array[Button] = []

func open(guild_service: Node, initial: Dictionary, registrar := "", owner_id := 0, identity: Dictionary = {}) -> void:
	service = guild_service
	data = initial
	registrar_id = registrar
	guild_id = owner_id
	host = guild_id > 0
	layer = 120
	lock_owner = StringName("guild_base_visit_menu_%d" % get_instance_id())
	get_node("/root/GameState").acquire_overworld_input_lock(lock_owner)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.035, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(540, get_viewport().get_visible_rect().size.x - 24), minf(540, get_viewport().get_visible_rect().size.y - 24))
	var skin := preload("res://scripts/ui/guild_base_room_directory.gd").new()
	panel.theme = skin._theme()
	panel.theme.set_stylebox("panel", "ItemList", skin._style(Color("#08141e"), Color("#355466")))
	for state: String in ["selected", "selected_focus", "hovered"]:
		panel.theme.set_stylebox(state, "ItemList", skin._style(Color("#203f50"), Color("#65bbc6")))
	panel.theme.set_color("font_color", "ItemList", Color("#edf6fc"))
	panel.theme.set_color("font_selected_color", "ItemList", Color.WHITE)
	panel.add_theme_stylebox_override("panel", skin._style(Color("#0d1d2b"), Color("#65bbc6")))
	skin.free()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := Label.new()
	var management := host and not identity.is_empty()
	title.text = _t("manager_title" if management else "host_title" if host else "guard_title")
	title.add_theme_color_override("font_color", Color("#f6cf72"))
	title.add_theme_font_size_override("font_size", 23)
	column.add_child(title)
	if management:
		var tabs := HBoxContainer.new()
		column.add_child(tabs)
		for page: String in ["visitors", "room_names"]:
			var tab := Button.new()
			tab.text = _t(page)
			tab.toggle_mode = true
			tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tab.pressed.connect(_show_page.bind(page))
			tabs.add_child(tab)
			navigation.append(tab)
	visitor_page = VBoxContainer.new()
	visitor_page.add_theme_constant_override("separation", 12)
	visitor_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(visitor_page)
	if host:
		policy = OptionButton.new()
		SelectorStyle.configure(policy)
		policy.add_item(_t("policy_request"))
		policy.add_item(_t("policy_open"))
		policy.disabled = not bool(data.get("canManage", false))
		policy.select(1 if str(data.get("policy", "request")) == "open" else 0)
		policy.item_selected.connect(_set_policy)
		visitor_page.add_child(policy)
	else:
		var shortcuts := HBoxContainer.new()
		visitor_page.add_child(shortcuts)
		var own := Button.new()
		own.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		own.text = _t("own_base")
		var state: Dictionary = data.get("registrar", {})
		own.disabled = state.get("baseTownId") != state.get("townId") or state.get("guildId") == null
		own.pressed.connect(func(): _finish({"kind": "enter", "guildId": int(state.get("guildId", 0))}))
		shortcuts.add_child(own)
		var buy := Button.new()
		buy.text = _t("purchase")
		buy.visible = state.get("baseTownId") == null
		buy.pressed.connect(func(): _finish({"kind": "purchase"}))
		shortcuts.add_child(buy)
		search = LineEdit.new()
		search.placeholder_text = _t("search")
		visitor_page.add_child(search)
		debounce = Timer.new()
		debounce.one_shot = true
		debounce.wait_time = 0.3
		debounce.timeout.connect(refresh)
		add_child(debounce)
		search.text_changed.connect(func(_value: String): debounce.start())
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size.y = 120
	list.item_selected.connect(_selected)
	visitor_page.add_child(list)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visitor_page.add_child(status)
	var actions := HBoxContainer.new()
	visitor_page.add_child(actions)
	action = Button.new()
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.pressed.connect(_act)
	actions.add_child(action)
	decline = Button.new()
	decline.text = _t("decline")
	decline.visible = host
	decline.disabled = true
	decline.pressed.connect(func(): _answer(false))
	actions.add_child(decline)
	if management:
		_build_room_names(column, identity)
		_show_page("visitors")
	var close := Button.new()
	close.text = get_node("/root/LocalizationManager").text("common.close")
	close.pressed.connect(func(): _finish({}))
	column.add_child(close)
	var timer := Timer.new()
	timer.wait_time = 5
	timer.autostart = true
	timer.timeout.connect(refresh)
	add_child(timer)
	_render()

func refresh() -> void:
	if busy or closed or (is_instance_valid(names_page) and names_page.visible):
		return
	busy = true
	var response: Dictionary = await service.base_visit_requests(guild_id) if host else await service.base_visit_directory(registrar_id, search.text)
	busy = false
	if closed:
		return
	if not bool(response.get("success", false)):
		status.text = ErrorText.message(response)
		return
	data = response.state
	_render()

func _render() -> void:
	_update_room_controls()
	if host:
		policy.disabled = not bool(data.get("canManage", false))
		policy.select(1 if str(data.get("policy", "request")) == "open" else 0)
	list.clear()
	var rows: Array = data.get("requests" if host else "guilds", [])
	for value: Dictionary in rows:
		var id := int(value.get("userId" if host else "id", 0))
		list.add_item(str(value.name) if host else "%s · %s" % [str(value.name), _t("policy_" + str(value.policy))])
		list.set_item_metadata(list.item_count - 1, id)
		if id == selected_id:
			list.select(list.item_count - 1)
	if list.get_selected_items().is_empty():
		selected_id = 0
	status.text = _t("no_requests" if host else "no_bases") if rows.is_empty() else _t("host_hint" if host else "guard_hint")
	_update_action()

func _build_room_names(column: VBoxContainer, identity: Dictionary) -> void:
	names_page = VBoxContainer.new()
	names_page.add_theme_constant_override("separation", 16)
	names_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(names_page)
	var hint := Label.new()
	hint.text = _t("room_names_hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names_page.add_child(hint)
	var room_names: Dictionary = identity.get("roomNames", {})
	for room_key: String in ["left_room", "right_room"]:
		var label := Label.new()
		label.text = get_node("/root/LocalizationManager").text("ui.guild_base.location." + room_key)
		names_page.add_child(label)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		names_page.add_child(row)
		var field := LineEdit.new()
		field.max_length = 40
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field.placeholder_text = label.text
		field.text = str(room_names.get(room_key, ""))
		field.text_submitted.connect(_submit_room_name.bind(room_key))
		field.text_changed.connect(_room_name_changed)
		row.add_child(field)
		name_fields[room_key] = field
		var save := Button.new()
		save.text = _t("save_room_name")
		save.pressed.connect(_save_room_name.bind(room_key))
		row.add_child(save)
		name_buttons.append(save)
	room_status = Label.new()
	room_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names_page.add_child(room_status)
	_update_room_controls()

func _show_page(page: String) -> void:
	visitor_page.visible = page == "visitors"
	names_page.visible = page == "room_names"
	navigation[0].set_pressed_no_signal(visitor_page.visible)
	navigation[1].set_pressed_no_signal(names_page.visible)

func _update_room_controls() -> void:
	var can_edit := bool(data.get("canManage", false)) and not busy
	if is_instance_valid(policy):
		policy.disabled = not can_edit
	for field: LineEdit in name_fields.values():
		field.editable = can_edit
	for save: Button in name_buttons:
		save.disabled = not can_edit

func _save_room_name(room_key: String) -> void:
	if busy or closed or not bool(data.get("canManage", false)):
		return
	busy = true
	_update_room_controls()
	_update_action()
	var result: Dictionary = await service.set_base_room_name(guild_id, room_key, name_fields[room_key].text)
	busy = false
	if closed:
		return
	_update_room_controls()
	_update_action()
	if bool(result.get("success", false)):
		var room_names: Dictionary = result.state.get("roomNames", {})
		name_fields[room_key].text = str(room_names.get(room_key, ""))
		room_status.text = _t("room_name_saved")
	else:
		room_status.text = ErrorText.message(result)

func _submit_room_name(_value: String, room_key: String) -> void:
	await _save_room_name(room_key)

func _room_name_changed(_value: String) -> void:
	if is_instance_valid(room_status):
		room_status.text = ""

func _selected(index: int) -> void:
	selected_id = int(list.get_item_metadata(index))
	_update_action()

func _update_action() -> void:
	action.disabled = selected_id <= 0 or busy
	decline.disabled = action.disabled
	action.text = _t("accept" if host else "enter")
	if host:
		return
	for value: Dictionary in data.get("guilds", []):
		if int(value.id) != selected_id:
			continue
		var visit: Dictionary = data.get("visit", {})
		var visit_status := str(visit.get("status", "")) if int(visit.get("guildId", 0)) == selected_id else ""
		if not bool(value.get("isOwn", false)) and str(value.policy) != "open":
			action.text = _t("enter" if visit_status == "approved" else "waiting" if visit_status == "pending" else "request")
			action.disabled = action.disabled or visit_status == "pending"
		if visit_status in ["approved", "pending", "declined", "expired"]:
			status.text = _t("status_" + visit_status)

func _act() -> void:
	if busy or selected_id <= 0:
		return
	if host:
		await _answer(true)
		return
	for value: Dictionary in data.get("guilds", []):
		if int(value.id) != selected_id:
			continue
		var visit: Dictionary = data.get("visit", {})
		if bool(value.get("isOwn", false)) or str(value.policy) == "open" or (int(visit.get("guildId", 0)) == selected_id and str(visit.get("status", "")) == "approved"):
			_finish({"kind": "enter", "guildId": selected_id})
			return
		busy = true
		_update_action()
		var result: Dictionary = await service.base_visit_request(registrar_id, selected_id)
		busy = false
		if closed:
			return
		if bool(result.get("success", false)):
			data.visit = result.state
			_update_action()
		else:
			_update_action()
			status.text = ErrorText.message(result)
		return

func _answer(accept: bool) -> void:
	if busy or selected_id <= 0:
		return
	busy = true
	_update_room_controls()
	_update_action()
	var result: Dictionary = await service.base_visit_answer(guild_id, selected_id, accept)
	busy = false
	if closed:
		return
	_update_room_controls()
	if bool(result.get("success", false)):
		selected_id = 0
		await refresh()
	else:
		status.text = ErrorText.message(result)
		_update_action()

func _set_policy(index: int) -> void:
	if busy:
		policy.select(1 if str(data.policy) == "open" else 0)
		return
	busy = true
	_update_room_controls()
	policy.disabled = true
	var result: Dictionary = await service.base_visit_policy(guild_id, "open" if index == 1 else "request")
	busy = false
	if closed:
		return
	_update_room_controls()
	policy.disabled = not bool(data.get("canManage", false))
	if bool(result.get("success", false)):
		data.policy = result.state.policy
	else:
		policy.select(1 if str(data.policy) == "open" else 0)
		status.text = ErrorText.message(result)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish({})

func _finish(value: Dictionary) -> void:
	if closed:
		return
	closed = true
	get_node("/root/GameState").release_overworld_input_lock(lock_owner)
	resolved.emit(value)
	queue_free()

func _exit_tree() -> void:
	if lock_owner != &"":
		get_node("/root/GameState").release_overworld_input_lock(lock_owner)

func _t(key: String) -> String:
	return get_node("/root/LocalizationManager").text("ui.guild_base.visits." + key)
