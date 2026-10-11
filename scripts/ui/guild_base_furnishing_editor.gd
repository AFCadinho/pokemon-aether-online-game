extends CanvasLayer

const Catalog := preload("res://scripts/world/guild_base_furniture_catalog.gd")
const Furniture := preload("res://scripts/world/guild_base_furniture.gd")
const SelectorStyle := preload("res://scripts/ui/language_selector_style.gd")
const FURNISH_ICON := preload("res://assets/ui/guild_base_furnish.svg")
const TEXT := Color("#f4f0de")
const MUTED := Color("#aeb8c5")
const BORDER := Color("#315070")
const ACCENT := Color("#60d3ff")
const GOLD := Color("#dec58a")

const INPUT_LOCK := &"guild_base_furnishing"
const CATEGORIES := ["tables", "seating", "decorations", "kitchen", "walls", "floor", "table_decor"]

var guild_service: Node
var room: Node2D
var state: Dictionary = {}
var building := false
var busy := false
var refreshing := false
var lease_token := ""
var selected_furniture := ""
var selected_instance := ""
var selecting := false
var pending_id := ""
var candidate: Dictionary = {}
var preview: Node2D
var last_preview: Dictionary = {}
var camera_state: Dictionary = {}
var rendered_revision := -1
var enter_button: Button
var placement_surface: Control
var done_button: Button
var panel: PanelContainer
var list: ItemList
var category: OptionButton
var dimensions: HBoxContainer
var width_box: SpinBox
var height_box: SpinBox
var status_label: Label
var remove_button: Button
var rights_button: Button
var select_button: Button
var refresh_timer: Timer
var lease_timer: Timer
var rights_window: Window

func _ready() -> void:
	if guild_service == null:
		guild_service = get_node("/root/GuildService")
	layer = 55
	_build_ui()
	refresh_timer = Timer.new()
	refresh_timer.wait_time = 10
	refresh_timer.autostart = true
	refresh_timer.timeout.connect(refresh)
	add_child(refresh_timer)
	lease_timer = Timer.new()
	lease_timer.wait_time = 12
	lease_timer.timeout.connect(_renew_lease)
	add_child(lease_timer)
	var presence := get_node_or_null("/root/WorldPresenceService")
	if presence != null:
		presence.guild_base_layout_updated.connect(_layout_event)
		presence.connection_changed.connect(_presence_connection)
	# Player reapplies its normal pixel scale on these signals as well.
	# Fit after all listeners, so that resizing cannot replace the editor zoom.
	get_viewport().size_changed.connect(_queue_camera_fit)
	get_node("/root/SettingsManager").world_pixel_scale_changed.connect(func(_scale: float): _queue_camera_fit())
	refresh.call_deferred()

func _text(key: String, values: Dictionary = {}) -> String:
	return LocalizationManager.text("ui.guild_base.furnish." + key, values)

func _style(background: Color, border := BORDER, radius := 9, margin := 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style

func _editor_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", TEXT)
	for type: String in ["Button", "CheckBox"]:
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_hover_color", type, Color.WHITE)
		theme.set_color("font_pressed_color", type, Color.WHITE)
		theme.set_color("font_disabled_color", type, Color("#69798b"))
		theme.set_stylebox("normal", type, _style(Color("#0b1a2b")))
		theme.set_stylebox("hover", type, _style(Color("#112a44"), ACCENT))
		theme.set_stylebox("pressed", type, _style(Color("#060e18"), ACCENT))
		theme.set_stylebox("focus", type, _style(Color.TRANSPARENT, ACCENT, 9, 0))
		theme.set_stylebox("disabled", type, _style(Color("#080f19"), Color("#26384b")))
	theme.set_icon("checked", "CheckBox", SelectorStyle.RADIO_CHECKED)
	theme.set_icon("unchecked", "CheckBox", SelectorStyle.RADIO_UNCHECKED)
	theme.set_icon("checked_disabled", "CheckBox", SelectorStyle.RADIO_CHECKED)
	theme.set_icon("unchecked_disabled", "CheckBox", SelectorStyle.RADIO_UNCHECKED)
	theme.set_constant("h_separation", "CheckBox", 12)
	var inset := _style(Color("#060e19"), Color("#263e55"), 9, 10)
	theme.set_stylebox("panel", "ItemList", inset)
	theme.set_stylebox("focus", "ItemList", _style(Color.TRANSPARENT, ACCENT, 9, 0))
	theme.set_stylebox("selected", "ItemList", _style(Color("#16314a"), GOLD, 7, 5))
	theme.set_stylebox("selected_focus", "ItemList", _style(Color("#183851"), GOLD, 7, 5))
	theme.set_stylebox("hovered", "ItemList", _style(Color("#0e2337"), BORDER, 7, 5))
	theme.set_color("font_color", "ItemList", TEXT)
	theme.set_color("font_selected_color", "ItemList", Color.WHITE)
	theme.set_constant("v_separation", "ItemList", 12)
	theme.set_constant("icon_margin", "ItemList", 14)
	for type: String in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", type, _style(Color("#08111e"), Color.TRANSPARENT, 3, 3))
		theme.set_stylebox("scroll_focus", type, _style(Color("#08111e"), Color.TRANSPARENT, 3, 3))
		for state_name: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
			theme.set_stylebox(state_name, type, _style(BORDER if state_name == "grabber" else ACCENT, Color.TRANSPARENT, 3, 3))
	theme.set_stylebox("normal", "LineEdit", inset)
	theme.set_stylebox("focus", "LineEdit", _style(Color("#071225"), ACCENT))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("caret_color", "LineEdit", GOLD)
	theme.set_color("selection_color", "LineEdit", Color("#224b68"))
	theme.set_stylebox("panel", "TooltipPanel", _style(Color("#081522")))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_font_size("font_size", "TooltipLabel", 13)
	var window_border := _style(Color("#050b14"), BORDER, 12, 12)
	window_border.content_margin_top = 34
	window_border.shadow_color = Color(0, 0, 0, 0.5)
	window_border.shadow_size = 16
	theme.set_stylebox("embedded_border", "Window", window_border)
	theme.set_stylebox("embedded_unfocused_border", "Window", window_border)
	theme.set_color("title_color", "Window", TEXT)
	theme.set_font_size("title_font_size", "Window", 16)
	return theme

func _button(text: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	button.custom_minimum_size.y = 42
	if primary:
		button.add_theme_stylebox_override("normal", _style(Color("#12364b"), ACCENT))
		button.add_theme_stylebox_override("hover", _style(Color("#194860"), Color("#a1eaff")))
		button.add_theme_stylebox_override("pressed", _style(Color("#0b2435"), ACCENT))
	return button

func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", MUTED)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _build_ui() -> void:
	var root := Control.new()
	placement_surface = root
	root.theme = _editor_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.gui_input.connect(_on_placement_surface_input)
	add_child(root)
	enter_button = _button(_text("open"), begin_editing)
	root.add_child(enter_button)
	# A dedicated action below the top HUD, clear of its right-hand icons.
	enter_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	enter_button.position = Vector2(24, 96)
	enter_button.custom_minimum_size = Vector2(248, 54)
	enter_button.size = enter_button.custom_minimum_size
	enter_button.icon = FURNISH_ICON
	enter_button.add_theme_constant_override("h_separation", 12)
	enter_button.add_theme_font_size_override("font_size", 16)
	var action_style := _style(Color("#142237"), GOLD, 11, 14)
	action_style.shadow_color = Color(0, 0, 0, 0.55)
	action_style.shadow_size = 10
	enter_button.add_theme_stylebox_override("normal", action_style)
	enter_button.add_theme_stylebox_override("hover", _style(Color("#203550"), GOLD, 11, 14))
	enter_button.add_theme_stylebox_override("pressed", _style(Color("#0d192a"), GOLD, 11, 14))
	enter_button.visible = false
	panel = PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 1
	panel.offset_left = -452
	panel.offset_top = 88
	panel.offset_right = -88
	panel.offset_bottom = -24
	var frame := _style(Color("#050b14f7"), BORDER, 13, 16)
	frame.border_width_top = 2
	frame.shadow_color = Color(0, 0, 0, 0.55)
	frame.shadow_size = 18
	frame.shadow_offset = Vector2(0, 6)
	panel.add_theme_stylebox_override("panel", frame)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	var icon := TextureRect.new()
	icon.texture = FURNISH_ICON
	icon.custom_minimum_size = Vector2(32, 32)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(icon)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var eyebrow := _caption(_text("eyebrow").to_upper())
	eyebrow.add_theme_color_override("font_color", GOLD)
	heading.add_child(eyebrow)
	var title := Label.new()
	title.text = _text("title")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 20)
	heading.add_child(title)
	column.add_child(_caption(_text("shared_storage")))
	var separator := HSeparator.new()
	separator.add_theme_stylebox_override("separator", _style(Color("#263e55"), Color.TRANSPARENT, 0, 0))
	column.add_child(separator)
	column.add_child(_caption(_text("category_label")))
	category = OptionButton.new()
	SelectorStyle.configure(category)
	for id: String in CATEGORIES:
		category.add_item(_text("category." + id))
		category.set_item_metadata(category.item_count - 1, id)
	category.item_selected.connect(func(_index: int): _populate_catalog())
	column.add_child(category)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(250, 112)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.fixed_icon_size = Vector2i(48, 48)
	list.max_text_lines = 2
	list.item_selected.connect(_catalog_selected)
	column.add_child(list)
	dimensions = HBoxContainer.new()
	dimensions.add_theme_constant_override("separation", 12)
	column.add_child(dimensions)
	for dimension: String in ["width", "height"]:
		var field := VBoxContainer.new()
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dimensions.add_child(field)
		field.add_child(_caption(_text(dimension)))
		var box := SpinBox.new()
		box.min_value = 2
		box.max_value = 15 if dimension == "width" else 12
		box.value = 3
		box.custom_minimum_size.y = 40
		field.add_child(box)
		if dimension == "width":
			width_box = box
		else:
			height_box = box
	dimensions.visible = false
	var help_panel := PanelContainer.new()
	var help_style := _style(Color("#0b1827"), BORDER, 8, 12)
	help_style.border_width_left = 3
	help_panel.add_theme_stylebox_override("panel", help_style)
	column.add_child(help_panel)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 44
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", MUTED)
	help_panel.add_child(status_label)
	select_button = _button(_text("select_move"), _start_selecting)
	column.add_child(select_button)
	remove_button = _button(_text("take_back"), _take_back)
	remove_button.disabled = true
	column.add_child(remove_button)
	rights_button = _button(_text("rights"), _show_rights)
	rights_button.add_theme_font_size_override("font_size", 14)
	column.add_child(rights_button)
	done_button = _button(_text("done"), finish_editing, true)
	column.add_child(done_button)
	panel.visible = false

func _set_status(message: String, error := false) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color("#efb0b2") if error else MUTED)

func _current() -> bool:
	return is_instance_valid(room) and room.is_inside_tree() and GameState.current_map == room and room.guild_id > 0 and AuthService.is_authenticated()

func refresh() -> void:
	if refreshing or busy or not _current():
		return
	refreshing = true
	var map_id: String = room.map_id
	var result: Dictionary = await guild_service.base_furniture(room.room_key)
	refreshing = false
	if not _current() or room.map_id != map_id:
		return
	if bool(result.get("success", false)):
		apply_state(result.state)
	elif building:
		_error(result)
		finish_editing()

func apply_state(value: Dictionary) -> void:
	if int(value.get("guildId", -1)) != room.guild_id or str(value.get("roomKey", "")) != room.room_key:
		return
	if int(value.get("revision", -1)) < int(state.get("revision", -1)):
		return
	state = value.duplicate(true)
	if rendered_revision != int(state.revision):
		rendered_revision = int(state.revision)
		_render_furniture()
	enter_button.visible = bool(state.get("canEdit", false)) and not building
	rights_button.visible = bool(state.get("canManageEditors", false))
	if building and not bool(state.get("canEdit", false)):
		finish_editing()
	if building:
		_populate_catalog()

func _render_furniture() -> void:
	var container := room.get_node("Entities/Furniture")
	for child: Node in container.get_children():
		child.free()
	for placement: Dictionary in state.get("items", []):
		if placement.get("parentId") != null:
			continue
		container.add_child(Furniture.instantiate_placement(room, placement, state.items))
	_set_selected_visibility(container, false)
	_recover_local_player()

func _set_selected_visibility(node: Node, restore: bool) -> void:
	if node.get_script() == Furniture:
		node.visible = restore or str(node.placement.get("id", "")) != selected_instance
	for child: Node in node.get_children():
		_set_selected_visibility(child, restore)

func _recover_local_player() -> void:
	if not _current():
		return
	var world: Node = GameState.get_world()
	var player: Node2D = world.get("player") if world != null else null
	if player == null:
		return
	var point: Vector2 = player.call("get_persistent_world_position") if player.has_method("get_persistent_world_position") else player.global_position
	var blocked := Catalog.blocked_cells(state.items)
	if not blocked.has(Vector2i((room.to_local(point) / 32).floor())):
		return
	# An in-flight movement can finish after another player places furniture.
	# Move to the nearest free floor tile before normal autosave resumes.
	var nearest := Vector2.ZERO
	var distance := INF
	for y: int in range(room.room_size.y):
		for x: int in range(room.room_size.x):
			var tile := Vector2i(x, y)
			var center := room.to_global(Vector2(tile) * 32 + Vector2(16, 16))
			if room.is_walkable_tile(tile) and not blocked.has(tile) and center.distance_squared_to(point) < distance:
				nearest = center
				distance = center.distance_squared_to(point)
	if distance < INF:
		if player.has_method("reset_movement_state"):
			player.reset_movement_state()
		player.global_position = nearest
		if world.has_method("save_current_player_state"):
			world.save_current_player_state.call_deferred()

func begin_editing() -> void:
	if busy or building or not _current():
		return
	busy = true
	GameState.acquire_overworld_input_lock(INPUT_LOCK)
	var world: Node = GameState.get_world()
	var position_result: Dictionary = await world.sync_player_position_for_world_action() if world != null else {"success": false}
	if not _current() or not bool(position_result.get("success", false)):
		busy = false
		GameState.release_overworld_input_lock(INPUT_LOCK)
		_error(position_result)
		return
	var result: Dictionary = await guild_service.base_furniture_lease(room.room_key, "acquire")
	busy = false
	if not _current() or not bool(result.get("success", false)):
		GameState.release_overworld_input_lock(INPUT_LOCK)
		_error(result)
		return
	lease_token = str(result.state.leaseToken)
	building = true
	apply_state(result.state)
	panel.visible = true
	placement_surface.mouse_filter = Control.MOUSE_FILTER_STOP
	enter_button.visible = false
	_capture_camera()
	_fit_camera()
	lease_timer.start()
	_populate_catalog()
	_set_status(_text("help"))

func finish_editing() -> void:
	if busy:
		return
	var old_token := lease_token
	lease_token = ""
	building = false
	lease_timer.stop()
	_clear_selection()
	panel.visible = false
	placement_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enter_button.visible = bool(state.get("canEdit", false))
	_restore_camera()
	GameState.release_overworld_input_lock(INPUT_LOCK)
	if rights_window != null:
		rights_window.queue_free()
		rights_window = null
	if old_token != "" and _current():
		await guild_service.base_furniture_lease(room.room_key, "release", old_token)

func _renew_lease() -> void:
	if not building or busy or not _current():
		return
	var token := lease_token
	var result: Dictionary = await guild_service.base_furniture_lease(room.room_key, "renew", token)
	if not building or token != lease_token:
		return
	if bool(result.get("success", false)):
		apply_state(result.state)
	else:
		_error(result)
		finish_editing()

func _populate_catalog() -> void:
	list.clear()
	var filter: String = category.get_item_metadata(category.selected)
	for spec: Dictionary in Catalog.load_data().items:
		if str(spec.category) != filter:
			continue
		var count := int(state.get("inventory", {}).get(spec.id, 0))
		list.add_item("%s   ×%d" % [LocalizationManager.text(str(spec.nameKey)), count], load("res://assets/guild_base/furniture/icons/%s.png" % str(spec.id)))
		var index := list.item_count - 1
		list.set_item_tooltip(index, _text("available", {"count": count}))
		list.set_item_metadata(index, str(spec.id))
		list.set_item_disabled(index, count <= 0 or busy)
		if str(spec.id) == selected_furniture:
			list.select(index)

func _catalog_selected(index: int) -> void:
	_clear_selection()
	selected_furniture = str(list.get_item_metadata(index))
	pending_id = _uuid()
	var spec := Catalog.item(selected_furniture)
	dimensions.visible = bool(spec.resizable)
	width_box.value = spec.footprint[0]
	height_box.value = spec.footprint[1]
	_set_status(_text("surface_help" if str(spec.placement) == "surface" else "help"))

func _start_selecting() -> void:
	_clear_selection()
	selecting = true
	_set_status(_text("select_help"))

func _clear_selection() -> void:
	if is_instance_valid(preview):
		preview.free()
	preview = null
	candidate.clear()
	last_preview.clear()
	selected_furniture = ""
	selected_instance = ""
	selecting = false
	dimensions.visible = false
	remove_button.disabled = true
	_set_selected_visibility(room.get_node("Entities/Furniture"), true)

func _process(_delta: float) -> void:
	if not building or busy or selected_furniture == "" or not _current():
		return
	var mouse := room.get_global_mouse_position()
	candidate = _placement_at(mouse)
	if candidate.is_empty():
		if is_instance_valid(preview):
			preview.visible = false
		return
	if candidate != last_preview:
		if is_instance_valid(preview):
			preview.free()
		if Catalog.item(selected_furniture).placement == "surface":
			preview = load(str(Catalog.item(selected_furniture).scenePath)).instantiate()
			var parent := _placement_by_id(str(candidate.parentId))
			preview.configure_surface(room, candidate, Catalog.item(str(parent.furnitureId)), true)
			preview.position += Vector2(int(parent.x), int(parent.y) + int(parent.height)) * 32
		else:
			preview = Furniture.instantiate_placement(room, candidate, state.items, true)
		room.add_child(preview)
		preview.z_as_relative = false
		preview.z_index = 4095
		last_preview = candidate.duplicate(true)
	preview.visible = true
	var reason := _candidate_error(candidate)
	preview.modulate = Color(0.4, 1, 0.6, 0.65) if reason == "" else Color(1, 0.35, 0.35, 0.65)
	_set_status(_text("valid" if reason == "" else "invalid." + reason), reason != "")

func _placement_at(world_position: Vector2) -> Dictionary:
	var spec := Catalog.item(selected_furniture)
	var tile := Vector2i((room.to_local(world_position) / 32).floor())
	var value := {"id": pending_id, "furnitureId": selected_furniture, "x": tile.x, "y": tile.y,
		"width": int(spec.footprint[0]), "height": int(spec.footprint[1]), "parentId": null, "slot": null}
	if selected_instance != "":
		value.id = selected_instance
	if bool(spec.resizable):
		value.width = int(width_box.value)
		value.height = int(height_box.value)
	if str(spec.placement) == "wall":
		value.y = 4
	if str(spec.placement) == "surface":
		var table := _surface_table_at(room.to_local(world_position))
		if table.is_empty():
			return {}
		var slots: Array = Catalog.item(str(table.furnitureId)).surfaceSlots
		var root_position := Vector2(int(table.x), int(table.y) + int(table.height)) * 32
		var used := {}
		for placed: Dictionary in state.items:
			if str(placed.get("parentId", "")) == str(table.id) and str(placed.id) != selected_instance:
				used[int(placed.slot)] = true
		var nearest := -1
		var distance := INF
		for index: int in range(slots.size()):
			var position := root_position + Vector2(slots[index][0], slots[index][1]) + Vector2(16, -16)
			var candidate_distance := position.distance_squared_to(room.to_local(world_position))
			if not used.has(index) and candidate_distance < distance:
				nearest = index
				distance = candidate_distance
		if nearest < 0:
			return {}
		value.x = 0
		value.y = 0
		value.parentId = str(table.id)
		value.slot = nearest
	return value

func _visual_rect(value: Dictionary) -> Rect2:
	var spec := Catalog.item(str(value.furnitureId))
	var rectangle := Catalog.footprint(value)
	var size := rectangle.size if bool(spec.resizable) else Vector2i(spec.visualSize[0], spec.visualSize[1])
	var offset := Vector2(0, -rectangle.size.y*32) if bool(spec.resizable) else Vector2(spec.visualOffset[0], spec.visualOffset[1])
	var position := Vector2(rectangle.position.x, rectangle.end.y)*32
	if value.get("parentId") != null:
		var parent := _placement_by_id(str(value.parentId))
		var slot: Array = Catalog.item(str(parent.furnitureId)).surfaceSlots[int(value.slot)]
		position = Vector2(int(parent.x), int(parent.y)+int(parent.height))*32 + Vector2(slot[0], slot[1])
	return Rect2(position+offset, Vector2(size)*32)

func _surface_table_at(position: Vector2) -> Dictionary:
	for value: Dictionary in state.items:
		if not Catalog.item(str(value.furnitureId)).surfaceSlots.is_empty() and _visual_rect(value).has_point(position):
			return value
	return {}

func _placement_by_id(id: String) -> Dictionary:
	for value: Dictionary in state.get("items", []):
		if str(value.id) == id:
			return value
	return {}

func _candidate_items(value: Dictionary) -> Array:
	var items: Array = state.items.duplicate(true)
	for index: int in range(items.size()):
		if str(items[index].id) == str(value.id):
			items[index] = value
			return items
	items.append(value)
	return items

func _candidate_error(value: Dictionary) -> String:
	if selected_instance == "" and int(state.inventory.get(value.furnitureId, 0)) <= 0:
		return "stock_required"
	var error := Catalog.validate(room, _candidate_items(value))
	if error != "":
		return error
	if bool(Catalog.item(str(value.furnitureId)).blocksMovement):
		var world: Node = GameState.get_world()
		var actors: Array[Node] = room.get_node("Entities/Players").get_children()
		if world != null and world.get("player") != null:
			actors.append(world.get("player"))
		for actor: Node in actors:
			if actor is Node2D:
				var position: Vector2 = actor.call("get_persistent_world_position") if actor.has_method("get_persistent_world_position") else actor.global_position
				if Catalog.footprint(value).has_point(Vector2i((room.to_local(position)/32).floor())):
					return "player_occupied"
	return ""

func _on_placement_surface_input(event: InputEvent) -> void:
	# The ordinary HUD consumes clicks before _unhandled_input. While editing,
	# this surface receives room clicks above that HUD; panel controls still
	# handle their own input without placing furniture behind the catalog.
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		var viewport_event: InputEvent = event.duplicate()
		viewport_event.position = placement_surface.get_global_transform_with_canvas() * event.position
		_unhandled_input(viewport_event)
	else:
		_unhandled_input(event)

func _unhandled_input(event: InputEvent) -> void:
	if not building or busy:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		finish_editing()
		get_viewport().set_input_as_handled()
		return
	var clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	clicked = clicked or (event is InputEventScreenTouch and event.pressed)
	if not clicked:
		return
	var screen_position: Vector2 = event.position
	var world_position := get_viewport().get_canvas_transform().affine_inverse() * screen_position
	get_viewport().set_input_as_handled()
	if selecting:
		_select_at(room.to_local(world_position))
	elif selected_furniture != "":
		var value := _placement_at(world_position)
		if not value.is_empty() and _candidate_error(value) == "":
			_commit(_candidate_items(value))

func _select_at(position: Vector2) -> void:
	var hit: Dictionary = {}
	var priority := -INF
	for value: Dictionary in state.items:
		if not _visual_rect(value).has_point(position):
			continue
		var depth := float(value.y) + float(value.height)
		if str(Catalog.item(str(value.furnitureId)).category) == "floor":
			depth = -1
		if value.get("parentId") != null:
			var parent := _placement_by_id(str(value.parentId))
			depth = float(parent.y) + float(parent.height) + 0.5
		if depth >= priority:
			hit = value
			priority = depth
	if hit.is_empty():
		return
	_clear_selection()
	selected_instance = str(hit.id)
	selected_furniture = str(hit.furnitureId)
	pending_id = selected_instance
	width_box.value = int(hit.width)
	height_box.value = int(hit.height)
	dimensions.visible = bool(Catalog.item(selected_furniture).resizable)
	remove_button.disabled = false
	_render_furniture()

func _take_back() -> void:
	if selected_instance == "" or busy:
		return
	var items: Array = []
	for value: Dictionary in state.items:
		if str(value.id) != selected_instance and str(value.get("parentId", "")) != selected_instance:
			items.append(value)
	await _commit(items)

func _commit(items: Array) -> void:
	if busy or not building or not _current():
		return
	busy = true
	_set_status(_text("saving"))
	remove_button.disabled = true
	var result: Dictionary = await guild_service.save_base_furniture(room.room_key, lease_token, int(state.revision), items)
	busy = false
	if not _current():
		return
	if bool(result.get("success", false)):
		_clear_selection()
		apply_state(result.state)
		_set_status(_text("saved"))
	else:
		_clear_selection()
		await refresh()
		_error(result)
		if BackendErrorLocalizationService.error_code(result) in ["guild_base_furniture_lease_expired", "guild_base_furniture_forbidden", "guild_base_access_denied"]:
			finish_editing()

func _error(response: Dictionary) -> void:
	if is_instance_valid(status_label):
		_set_status(BackendErrorLocalizationService.message(response, "ui.guild_base.furnish.failed"), true)
	if not building and _current():
		await GameErrorDialogService.show_response(response, "ui.guild_base.furnish.failed")

func _show_rights() -> void:
	if busy or rights_window != null:
		return
	busy = true
	var result: Dictionary = await guild_service.base_furniture_editors()
	busy = false
	if not _current() or not building:
		return
	if not bool(result.get("success", false)):
		_error(result)
		return
	rights_window = Window.new()
	rights_window.theme = placement_surface.theme
	rights_window.title = _text("rights")
	rights_window.size = Vector2i(360, 400)
	rights_window.transient = true
	rights_window.exclusive = true
	rights_window.close_requested.connect(func(): rights_window.queue_free(); rights_window = null)
	add_child(rights_window)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rights_window.add_child(scroll)
	scroll.add_theme_stylebox_override("panel", _style(Color("#050b14"), BORDER, 10, 12))
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	for member: Dictionary in result.state.members:
		var checkbox := CheckBox.new()
		checkbox.text = str(member.name)
		checkbox.button_pressed = bool(member.allowed)
		checkbox.disabled = bool(member.isLeader)
		column.add_child(checkbox)
		checkbox.toggled.connect(func(allowed: bool): _change_right(member, allowed, checkbox))
	rights_window.popup_centered()

func _change_right(member: Dictionary, allowed: bool, checkbox: CheckBox) -> void:
	checkbox.disabled = true
	var result: Dictionary = await guild_service.set_base_furniture_editor(int(member.userId), allowed)
	if not is_instance_valid(checkbox):
		return
	checkbox.disabled = false
	if not bool(result.get("success", false)):
		checkbox.set_pressed_no_signal(not allowed)
		_error(result)

func _capture_camera() -> void:
	var camera := _camera()
	if camera == null:
		return
	camera_state = {"zoom": camera.zoom, "limits": Vector4i(camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom),
		"constrain": room.get_node("FloorVisibilityMask").constrain_camera_to_active_floor}
	room.get_node("FloorVisibilityMask").constrain_camera_to_active_floor = false

func _camera() -> Camera2D:
	var world: Node = GameState.get_world()
	var player: Node = world.get("player") if world != null else null
	return player.get_node_or_null("Camera2D") as Camera2D if player != null else null

func _fit_camera() -> void:
	if not building:
		return
	var camera := _camera()
	if camera == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var region: Rect2 = room.get_node("FloorVisibilityMask").get_active_floor_region()
	var dock_width := viewport_size.x - panel.position.x + 24
	var zoom := clampf(minf((viewport_size.x-dock_width-48)/region.size.x, (viewport_size.y-64)/region.size.y), 0.2, 1.5)
	camera.zoom = Vector2(zoom, zoom)
	var center := room.to_global(region.get_center()) + Vector2(dock_width/(2*zoom), 0)
	var size := viewport_size/zoom
	camera.limit_left = floori(center.x-size.x/2)
	camera.limit_right = ceili(center.x+size.x/2)
	camera.limit_top = floori(center.y-size.y/2)
	camera.limit_bottom = ceili(center.y+size.y/2)
	camera.reset_smoothing()
	camera.force_update_scroll()

func _queue_camera_fit() -> void:
	_fit_camera.call_deferred()

func _restore_camera() -> void:
	var camera := _camera()
	if camera != null and not camera_state.is_empty() and GameState.current_map == room:
		camera.zoom = camera_state.zoom
		var limits: Vector4i = camera_state.limits
		camera.limit_left = limits.x
		camera.limit_top = limits.y
		camera.limit_right = limits.z
		camera.limit_bottom = limits.w
		room.get_node("FloorVisibilityMask").constrain_camera_to_active_floor = bool(camera_state.constrain)
		camera.reset_smoothing()
		var world: Node = GameState.get_world()
		var player: Node = world.get("player") if world != null else null
		if player != null and player.has_method("_apply_world_pixel_scale"):
			player._apply_world_pixel_scale()
	camera_state.clear()

func _layout_event(map_id: String, revision: int) -> void:
	if _current() and map_id == room.map_id and revision > int(state.get("revision", -1)):
		refresh.call_deferred()

func _presence_connection(connected: bool) -> void:
	if connected:
		refresh.call_deferred()

func _exit_tree() -> void:
	_restore_camera()
	GameState.release_overworld_input_lock(INPUT_LOCK)
	if is_instance_valid(preview):
		preview.queue_free()

func _uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20)]
