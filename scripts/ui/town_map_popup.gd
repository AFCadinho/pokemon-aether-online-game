extends Control

class_name TownMapPopup

signal closed

const REGION_MAP_PATH := "res://data/region_maps/kanto.json"
const WORLD_ACCESS_PATH := "res://generated/world_access_catalog.json"
const TownMapCanvasScript := preload("res://scripts/ui/town_map_canvas.gd")
const TrainerHeadPortraitScript := preload("res://scripts/ui/trainer_head_portrait.gd")

var region_data: Dictionary = {}
var layout_data: Dictionary = {}
var world_access: Dictionary = {}
var shell: PanelContainer
var title_label: Label
var subtitle_label: Label
var current_location_chip: PanelContainer
var current_location_label: Label
var map_canvas: TownMapCanvas
var detail_overline_label: Label
var detail_name_label: Label
var detail_portrait: TrainerHeadPortrait
var detail_kind_panel: PanelContainer
var detail_kind_label: Label
var detail_description_label: Label
var connections_title_label: Label
var detail_connections_container: VBoxContainer
var legend_kind_labels: Dictionary = {}
var selected_location_id := ""
var current_location_id := ""
var owns_overworld_input_lock := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	region_data = _load_json(REGION_MAP_PATH)
	layout_data = _load_json(str(region_data.get("layoutPath", "")))
	_apply_layout()
	world_access = _load_json(WORLD_ACCESS_PATH)
	_build_ui()
	get_viewport().size_changed.connect(_position_shell)


func open_for_map(map_id: String) -> void:
	if region_data.is_empty():
		return
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and not bool(game_state.call("is_overworld_input_locked")):
		game_state.call("lock_overworld_input")
		owns_overworld_input_lock = true
	current_location_id = _resolve_location_group(map_id)
	if not region_data.get("locations", {}).has(current_location_id):
		current_location_id = ""
	selected_location_id = current_location_id
	if selected_location_id == "":
		var location_ids: Array = (region_data.get("locations", {}) as Dictionary).keys()
		if not location_ids.is_empty():
			selected_location_id = str(location_ids[0])
	visible = true
	_position_shell()
	map_canvas.set_current_location(current_location_id)
	map_canvas.select_location(selected_location_id)
	_refresh_header()
	_refresh_details(selected_location_id)
	var close_button := shell.find_child("CloseButton", true, false) as Button
	if close_button != null:
		close_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	_release_overworld_input_lock()
	closed.emit()


func _exit_tree() -> void:
	_release_overworld_input_lock()


func _release_overworld_input_lock() -> void:
	if not owns_overworld_input_lock:
		return
	owns_overworld_input_lock = false
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.call("unlock_overworld_input")


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func refresh_localized_ui() -> void:
	_refresh_header()
	_refresh_details(selected_location_id)
	if map_canvas != null:
		map_canvas.configure(
			region_data.get("locations", {}) as Dictionary,
			region_data.get("paths", []) as Array
		)
		map_canvas.set_current_location(current_location_id)
		map_canvas.select_location(selected_location_id)


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#010711e6")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	shell = PanelContainer.new()
	shell.name = "TownMapShell"
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	var shell_style := _panel_style(Color("#061522fa"), Color("#4bcce8"), 18, 2)
	shell_style.shadow_color = Color("#00000099")
	shell_style.shadow_size = 18
	shell.add_theme_stylebox_override("panel", shell_style)
	add_child(shell)

	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 18)
	outer_margin.add_theme_constant_override("margin_top", 16)
	outer_margin.add_theme_constant_override("margin_right", 18)
	outer_margin.add_theme_constant_override("margin_bottom", 16)
	shell.add_child(outer_margin)

	var main_column := VBoxContainer.new()
	main_column.add_theme_constant_override("separation", 12)
	outer_margin.add_child(main_column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	main_column.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 1)
	header.add_child(heading)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 27)
	title_label.add_theme_color_override("font_color", Color("#f5d77b"))
	heading.add_child(title_label)
	subtitle_label = Label.new()
	subtitle_label.add_theme_font_size_override("font_size", 12)
	subtitle_label.add_theme_color_override("font_color", Color("#9eb1c3"))
	heading.add_child(subtitle_label)

	current_location_chip = PanelContainer.new()
	current_location_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	current_location_chip.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#082739e8"), Color("#52dced"), 12, 1)
	)
	var current_margin := MarginContainer.new()
	current_margin.add_theme_constant_override("margin_left", 11)
	current_margin.add_theme_constant_override("margin_top", 7)
	current_margin.add_theme_constant_override("margin_right", 12)
	current_margin.add_theme_constant_override("margin_bottom", 7)
	current_location_chip.add_child(current_margin)
	var current_row := HBoxContainer.new()
	current_row.add_theme_constant_override("separation", 7)
	current_margin.add_child(current_row)
	var current_dot := Label.new()
	current_dot.text = "●"
	current_dot.add_theme_font_size_override("font_size", 12)
	current_dot.add_theme_color_override("font_color", Color("#5cecff"))
	current_row.add_child(current_dot)
	current_location_label = Label.new()
	current_location_label.add_theme_font_size_override("font_size", 12)
	current_location_label.add_theme_color_override("font_color", Color("#c8f8ff"))
	current_location_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	current_row.add_child(current_location_label)
	header.add_child(current_location_chip)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(44, 44)
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_font_size_override("font_size", 22)
	close_button.add_theme_color_override("font_color", Color("#d8e4eb"))
	close_button.add_theme_color_override("font_hover_color", Color.WHITE)
	close_button.add_theme_stylebox_override("normal", _panel_style(Color("#0a1b2a"), Color("#365970"), 11, 1))
	close_button.add_theme_stylebox_override("hover", _panel_style(Color("#3a1733"), Color("#ff65df"), 11, 1))
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var divider := HSeparator.new()
	divider.add_theme_color_override("separator", Color("#315064"))
	main_column.add_child(divider)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	main_column.add_child(body)

	var map_column := VBoxContainer.new()
	map_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_column.add_theme_constant_override("separation", 9)
	body.add_child(map_column)

	var map_frame := PanelContainer.new()
	map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_frame.add_theme_stylebox_override("panel", _panel_style(Color("#020d16"), Color("#315b70"), 14, 1))
	map_column.add_child(map_frame)
	var map_margin := MarginContainer.new()
	map_margin.add_theme_constant_override("margin_left", 7)
	map_margin.add_theme_constant_override("margin_top", 7)
	map_margin.add_theme_constant_override("margin_right", 7)
	map_margin.add_theme_constant_override("margin_bottom", 7)
	map_frame.add_child(map_margin)
	var map_stack := Control.new()
	map_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_stack.clip_contents = true
	map_margin.add_child(map_stack)
	map_canvas = TownMapCanvasScript.new() as TownMapCanvas
	map_stack.add_child(map_canvas)
	map_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	map_canvas.set_overlay_visibility(
		bool(region_data.get("showConnectionOverlay", true)),
		bool(region_data.get("showMarkerOverlay", true))
	)
	var background_path := str(region_data.get("backgroundPath", ""))
	if ResourceLoader.exists(background_path):
		map_canvas.set_background(load(background_path) as Texture2D)
	map_canvas.configure(
		region_data.get("locations", {}) as Dictionary,
		region_data.get("paths", []) as Array
	)
	map_canvas.location_selected.connect(_refresh_details)

	var legend_bar := PanelContainer.new()
	legend_bar.add_theme_stylebox_override("panel", _panel_style(Color("#081a28e8"), Color("#24465a"), 10, 1))
	map_column.add_child(legend_bar)
	var legend_margin := MarginContainer.new()
	legend_margin.add_theme_constant_override("margin_left", 10)
	legend_margin.add_theme_constant_override("margin_top", 7)
	legend_margin.add_theme_constant_override("margin_right", 10)
	legend_margin.add_theme_constant_override("margin_bottom", 7)
	legend_bar.add_child(legend_margin)
	var legend_flow := HFlowContainer.new()
	legend_flow.add_theme_constant_override("h_separation", 7)
	legend_flow.add_theme_constant_override("v_separation", 5)
	legend_margin.add_child(legend_flow)
	_add_legend_chip(legend_flow, "town", Color("#f1c85d"))
	_add_legend_chip(legend_flow, "city", Color("#f1c85d"))
	_add_legend_chip(legend_flow, "route", Color("#65d8f4"))
	_add_legend_chip(legend_flow, "wilderness", Color("#69d69b"))

	var details := PanelContainer.new()
	details.custom_minimum_size = Vector2(300, 0)
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_theme_stylebox_override("panel", _panel_style(Color("#081a29f2"), Color("#31566c"), 14, 1))
	body.add_child(details)
	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 17)
	detail_margin.add_theme_constant_override("margin_top", 16)
	detail_margin.add_theme_constant_override("margin_right", 17)
	detail_margin.add_theme_constant_override("margin_bottom", 16)
	details.add_child(detail_margin)
	var detail_column := VBoxContainer.new()
	detail_column.add_theme_constant_override("separation", 11)
	detail_margin.add_child(detail_column)

	detail_overline_label = Label.new()
	detail_overline_label.add_theme_font_size_override("font_size", 10)
	detail_overline_label.add_theme_color_override("font_color", Color("#ff73e2"))
	detail_column.add_child(detail_overline_label)

	var detail_heading_row := HBoxContainer.new()
	detail_heading_row.add_theme_constant_override("separation", 10)
	detail_column.add_child(detail_heading_row)
	var detail_heading := VBoxContainer.new()
	detail_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_heading.add_theme_constant_override("separation", 7)
	detail_heading_row.add_child(detail_heading)
	detail_name_label = Label.new()
	detail_name_label.add_theme_font_size_override("font_size", 24)
	detail_name_label.add_theme_color_override("font_color", Color("#f0e6ca"))
	detail_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_heading.add_child(detail_name_label)
	detail_kind_panel = PanelContainer.new()
	detail_kind_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	detail_heading.add_child(detail_kind_panel)
	var kind_margin := MarginContainer.new()
	kind_margin.add_theme_constant_override("margin_left", 8)
	kind_margin.add_theme_constant_override("margin_top", 3)
	kind_margin.add_theme_constant_override("margin_right", 8)
	kind_margin.add_theme_constant_override("margin_bottom", 3)
	detail_kind_panel.add_child(kind_margin)
	detail_kind_label = Label.new()
	detail_kind_label.add_theme_font_size_override("font_size", 10)
	kind_margin.add_child(detail_kind_label)
	detail_portrait = TrainerHeadPortraitScript.new() as TrainerHeadPortrait
	detail_portrait.custom_minimum_size = Vector2(58, 58)
	detail_portrait.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	detail_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	detail_portrait.visible = false
	detail_heading_row.add_child(detail_portrait)

	var detail_divider := HSeparator.new()
	detail_divider.add_theme_color_override("separator", Color("#355064"))
	detail_column.add_child(detail_divider)

	var description_card := PanelContainer.new()
	description_card.add_theme_stylebox_override("panel", _panel_style(Color("#06131f"), Color("#203d50"), 10, 1))
	detail_column.add_child(description_card)
	var description_margin := MarginContainer.new()
	description_margin.add_theme_constant_override("margin_left", 11)
	description_margin.add_theme_constant_override("margin_top", 10)
	description_margin.add_theme_constant_override("margin_right", 11)
	description_margin.add_theme_constant_override("margin_bottom", 10)
	description_card.add_child(description_margin)
	detail_description_label = Label.new()
	detail_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_description_label.add_theme_font_size_override("font_size", 14)
	detail_description_label.add_theme_color_override("font_color", Color("#c0cdd7"))
	description_margin.add_child(detail_description_label)

	connections_title_label = Label.new()
	connections_title_label.add_theme_font_size_override("font_size", 10)
	connections_title_label.add_theme_color_override("font_color", Color("#65d7f3"))
	detail_column.add_child(connections_title_label)
	detail_connections_container = VBoxContainer.new()
	detail_connections_container.add_theme_constant_override("separation", 7)
	detail_column.add_child(detail_connections_container)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_column.add_child(spacer)
	_position_shell.call_deferred()


func _add_legend_chip(parent: Container, kind: String, color: Color) -> void:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(color.r * 0.13, color.g * 0.13, color.b * 0.13, 0.94),
			Color(color.r, color.g, color.b, 0.48),
			8,
			1
		)
	)
	parent.add_child(chip)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 4)
	chip.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	margin.add_child(row)
	var dot := Label.new()
	dot.text = "●"
	dot.add_theme_font_size_override("font_size", 10)
	dot.add_theme_color_override("font_color", color)
	row.add_child(dot)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#d4e0e8"))
	row.add_child(label)
	legend_kind_labels[kind] = label


func _position_shell() -> void:
	if shell == null:
		return
	var viewport_size := get_viewport_rect().size
	var target_size := Vector2(
		minf(1180.0, maxf(viewport_size.x - 40.0, 680.0)),
		minf(760.0, maxf(viewport_size.y - 40.0, 460.0))
	)
	shell.set_anchors_preset(Control.PRESET_CENTER)
	shell.offset_left = -target_size.x * 0.5
	shell.offset_top = -target_size.y * 0.5
	shell.offset_right = target_size.x * 0.5
	shell.offset_bottom = target_size.y * 0.5


func _refresh_header() -> void:
	if title_label == null:
		return
	title_label.text = _t("ui.town_map.title")
	subtitle_label.text = _t("ui.town_map.subtitle")
	if detail_overline_label != null:
		detail_overline_label.text = _t("ui.town_map.selected_location")
	if connections_title_label != null:
		connections_title_label.text = _t("ui.town_map.connections")
	for kind_value: Variant in legend_kind_labels.keys():
		var kind := str(kind_value)
		var kind_label := legend_kind_labels.get(kind) as Label
		if kind_label != null:
			kind_label.text = _t("ui.town_map.kind.%s" % kind)
	var current_name := _t("ui.town_map.current_unknown")
	if current_location_id != "":
		current_name = _location_name(current_location_id)
	current_location_label.text = _t(
		"ui.town_map.current_location",
		{"location": current_name}
	)


func _refresh_details(location_id: String) -> void:
	var locations := region_data.get("locations", {}) as Dictionary
	if not locations.has(location_id):
		return
	selected_location_id = location_id
	if map_canvas != null:
		map_canvas.select_location(location_id)
	var location := locations.get(location_id, {}) as Dictionary
	detail_name_label.text = _location_name(location_id)
	if detail_portrait != null:
		var portrait_state: Variant = location.get("portraitAppearance", {})
		if not portrait_state is Dictionary or (portrait_state as Dictionary).is_empty():
			portrait_state = {}
		if (portrait_state as Dictionary).is_empty() and location_id == current_location_id:
			var player_save := get_node_or_null("/root/PlayerSave")
			if player_save != null and player_save.has_method("to_appearance_state"):
				portrait_state = player_save.call("to_appearance_state")
		detail_portrait.visible = portrait_state is Dictionary and not (portrait_state as Dictionary).is_empty()
		if detail_portrait.visible:
			detail_portrait.set_appearance_state(portrait_state as Dictionary)
	detail_kind_label.text = _t(
		"ui.town_map.kind.%s" % str(location.get("kind", "route"))
	)
	var kind_color := _kind_color(str(location.get("kind", "route")))
	detail_kind_label.add_theme_color_override("font_color", kind_color)
	if detail_kind_panel != null:
		detail_kind_panel.add_theme_stylebox_override(
			"panel",
			_panel_style(
				Color(kind_color.r * 0.13, kind_color.g * 0.13, kind_color.b * 0.13, 0.96),
				Color(kind_color.r, kind_color.g, kind_color.b, 0.55),
				7,
				1
			)
		)
	detail_description_label.text = _t(str(location.get("descriptionKey", "")))
	var connected_location_ids: Array[String] = []
	for path_value: Variant in region_data.get("paths", []):
		var endpoints := _path_endpoints(path_value)
		if endpoints.size() < 2:
			continue
		var from_id := endpoints[0]
		var to_id := endpoints[1]
		if from_id == location_id:
			connected_location_ids.append(to_id)
		elif to_id == location_id:
			connected_location_ids.append(from_id)
	_refresh_connection_buttons(connected_location_ids)


func _refresh_connection_buttons(location_ids: Array[String]) -> void:
	if detail_connections_container == null:
		return
	for child: Node in detail_connections_container.get_children():
		detail_connections_container.remove_child(child)
		child.queue_free()
	if location_ids.is_empty():
		var unavailable := Label.new()
		unavailable.text = _t("common.unavailable")
		unavailable.add_theme_font_size_override("font_size", 13)
		unavailable.add_theme_color_override("font_color", Color("#788d9d"))
		detail_connections_container.add_child(unavailable)
		return
	for location_id: String in location_ids:
		var button := Button.new()
		button.text = "→  %s" % _location_name(location_id)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 38)
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_color_override("font_color", Color("#d5e3eb"))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		var normal_style := _panel_style(Color("#071522"), Color("#27495d"), 8, 1)
		normal_style.content_margin_left = 11.0
		var hover_style := _panel_style(Color("#102a3a"), Color("#5cecff"), 8, 1)
		hover_style.content_margin_left = 11.0
		var pressed_style := _panel_style(Color("#32162f"), Color("#ff5bdc"), 8, 1)
		pressed_style.content_margin_left = 11.0
		button.add_theme_stylebox_override("normal", normal_style)
		button.add_theme_stylebox_override("hover", hover_style)
		button.add_theme_stylebox_override("pressed", pressed_style)
		button.pressed.connect(_refresh_details.bind(location_id))
		detail_connections_container.add_child(button)


func _kind_color(kind: String) -> Color:
	match kind:
		"town", "city":
			return Color("#f1c85d")
		"wilderness":
			return Color("#69d69b")
		_:
			return Color("#65d8f4")


func _location_name(location_id: String) -> String:
	var locations := region_data.get("locations", {}) as Dictionary
	var location := locations.get(location_id, {}) as Dictionary
	var name_key := str(location.get("nameKey", "")).strip_edges()
	if name_key != "":
		return _t(name_key)
	return str(location.get("name", location_id)).strip_edges()


func _resolve_location_group(map_id: String) -> String:
	var areas := world_access.get("areas", {}) as Dictionary
	var area := areas.get(map_id, {}) as Dictionary
	return str(area.get("locationGroupId", map_id)).strip_edges()


func _path_endpoints(path_value: Variant) -> Array[String]:
	var endpoints: Array[String] = []
	if path_value is Array:
		var path := path_value as Array
		if path.size() >= 2:
			endpoints.assign([str(path[0]), str(path[1])])
	elif path_value is Dictionary:
		var path := path_value as Dictionary
		endpoints.assign([str(path.get("from", "")), str(path.get("to", ""))])
	return endpoints


func _apply_layout() -> void:
	if region_data.is_empty() or layout_data.is_empty():
		return
	var coordinate_space := layout_data.get("coordinateSpace", {}) as Dictionary
	var width := maxf(float(coordinate_space.get("width", 1000.0)), 1.0)
	var height := maxf(float(coordinate_space.get("height", 707.0)), 1.0)
	var locations := region_data.get("locations", {}) as Dictionary
	var points := layout_data.get("points", {}) as Dictionary
	for point_id_value: Variant in points.keys():
		var point_id := str(point_id_value)
		if locations.has(point_id):
			continue
		var point_data := points.get(point_id, {}) as Dictionary
		locations[point_id] = {
			"kind": str(point_data.get("kind", "route")),
			"name": str(point_data.get("name", point_id)),
			"description": str(point_data.get("description", "")),
			"planned": bool(point_data.get("planned", true)),
		}
	for route_value: Variant in layout_data.get("routePoints", []):
		if not route_value is Dictionary:
			continue
		var route_point := route_value as Dictionary
		var route_id := str(route_point.get("id", "")).strip_edges()
		if route_id == "" or locations.has(route_id):
			continue
		locations[route_id] = {
			"kind": "route",
			"name": str(route_point.get("name", route_id)),
			"description": str(route_point.get("description", "")),
			"planned": bool(route_point.get("planned", true)),
		}
		points[route_id] = route_point
	for location_id_value: Variant in locations.keys():
		var location_id := str(location_id_value)
		var location := locations.get(location_id, {}) as Dictionary
		var point := points.get(location_id, {}) as Dictionary
		location["position"] = {
			"x": clampf(float(point.get("x", width * 0.5)) / width, 0.0, 1.0),
			"y": clampf(float(point.get("y", height * 0.5)) / height, 0.0, 1.0),
		}
		locations[location_id] = location
	region_data["locations"] = locations

	var normalized_connections: Array = []
	for connection_value: Variant in layout_data.get("connections", []):
		if not connection_value is Dictionary:
			continue
		var connection := (connection_value as Dictionary).duplicate(true)
		var normalized_waypoints: Array = []
		for waypoint_value: Variant in connection.get("waypoints", []):
			if not waypoint_value is Dictionary:
				continue
			var waypoint := waypoint_value as Dictionary
			normalized_waypoints.append({
				"x": clampf(float(waypoint.get("x", width * 0.5)) / width, 0.0, 1.0),
				"y": clampf(float(waypoint.get("y", height * 0.5)) / height, 0.0, 1.0),
			})
		connection["waypoints"] = normalized_waypoints
		normalized_connections.append(connection)
	region_data["paths"] = normalized_connections


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("TownMapPopup: missing catalog %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed as Dictionary
	push_warning("TownMapPopup: invalid catalog %s" % path)
	return {}


func _panel_style(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


func _t(key: String, values: Dictionary = {}) -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null and localization_manager.has_method("text"):
		return str(localization_manager.call("text", key, values))
	return key
