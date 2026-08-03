extends Control

class_name TownMapPopup

signal closed

const REGION_MAP_PATH := "res://data/region_maps/kanto.json"
const WORLD_ACCESS_PATH := "res://generated/world_access_catalog.json"
const TownMapCanvasScript := preload("res://scripts/ui/town_map_canvas.gd")

var region_data: Dictionary = {}
var layout_data: Dictionary = {}
var world_access: Dictionary = {}
var shell: PanelContainer
var title_label: Label
var subtitle_label: Label
var current_location_label: Label
var map_canvas: TownMapCanvas
var detail_name_label: Label
var detail_kind_label: Label
var detail_description_label: Label
var detail_connections_label: Label
var selected_location_id := ""
var current_location_id := ""


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
	closed.emit()


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
	backdrop.color = Color("#020812d9")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	shell = PanelContainer.new()
	shell.name = "TownMapShell"
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.add_theme_stylebox_override("panel", _panel_style(Color("#071421f7"), Color("#5dcce8"), 16, 2))
	add_child(shell)

	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 20)
	outer_margin.add_theme_constant_override("margin_top", 18)
	outer_margin.add_theme_constant_override("margin_right", 20)
	outer_margin.add_theme_constant_override("margin_bottom", 20)
	shell.add_child(outer_margin)

	var main_column := VBoxContainer.new()
	main_column.add_theme_constant_override("separation", 14)
	outer_margin.add_child(main_column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	main_column.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color("#f3d477"))
	heading.add_child(title_label)
	subtitle_label = Label.new()
	subtitle_label.add_theme_font_size_override("font_size", 13)
	subtitle_label.add_theme_color_override("font_color", Color("#9eb1c3"))
	heading.add_child(subtitle_label)
	current_location_label = Label.new()
	current_location_label.add_theme_font_size_override("font_size", 14)
	current_location_label.add_theme_color_override("font_color", Color("#7ee5fa"))
	current_location_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(current_location_label)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(42, 42)
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_font_size_override("font_size", 22)
	close_button.add_theme_stylebox_override("normal", _panel_style(Color("#0b1d2d"), Color("#31536c"), 10, 1))
	close_button.add_theme_stylebox_override("hover", _panel_style(Color("#12324a"), Color("#66d9f4"), 10, 1))
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var divider := HSeparator.new()
	divider.add_theme_color_override("separator", Color("#315064"))
	main_column.add_child(divider)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	main_column.add_child(body)

	var map_frame := PanelContainer.new()
	map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_frame.add_theme_stylebox_override("panel", _panel_style(Color("#03101a"), Color("#264a60"), 12, 1))
	body.add_child(map_frame)
	var map_margin := MarginContainer.new()
	map_margin.add_theme_constant_override("margin_left", 8)
	map_margin.add_theme_constant_override("margin_top", 8)
	map_margin.add_theme_constant_override("margin_right", 8)
	map_margin.add_theme_constant_override("margin_bottom", 8)
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
	var background_path := str(region_data.get("backgroundPath", ""))
	if ResourceLoader.exists(background_path):
		map_canvas.set_background(load(background_path) as Texture2D)
	map_canvas.configure(
		region_data.get("locations", {}) as Dictionary,
		region_data.get("paths", []) as Array
	)
	map_canvas.location_selected.connect(_refresh_details)

	var details := PanelContainer.new()
	details.custom_minimum_size = Vector2(286, 0)
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_theme_stylebox_override("panel", _panel_style(Color("#081827e8"), Color("#294a61"), 12, 1))
	body.add_child(details)
	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 18)
	detail_margin.add_theme_constant_override("margin_top", 18)
	detail_margin.add_theme_constant_override("margin_right", 18)
	detail_margin.add_theme_constant_override("margin_bottom", 18)
	details.add_child(detail_margin)
	var detail_column := VBoxContainer.new()
	detail_column.add_theme_constant_override("separation", 12)
	detail_margin.add_child(detail_column)
	var detail_overline := Label.new()
	detail_overline.text = _t("ui.town_map.selected_location")
	detail_overline.add_theme_font_size_override("font_size", 11)
	detail_overline.add_theme_color_override("font_color", Color("#65d7f3"))
	detail_column.add_child(detail_overline)
	detail_name_label = Label.new()
	detail_name_label.add_theme_font_size_override("font_size", 23)
	detail_name_label.add_theme_color_override("font_color", Color("#f0e6ca"))
	detail_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_column.add_child(detail_name_label)
	detail_kind_label = Label.new()
	detail_kind_label.add_theme_font_size_override("font_size", 12)
	detail_kind_label.add_theme_color_override("font_color", Color("#f2cb6b"))
	detail_column.add_child(detail_kind_label)
	var detail_divider := HSeparator.new()
	detail_column.add_child(detail_divider)
	detail_description_label = Label.new()
	detail_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_description_label.add_theme_font_size_override("font_size", 14)
	detail_description_label.add_theme_color_override("font_color", Color("#bdc9d4"))
	detail_column.add_child(detail_description_label)
	var connections_title := Label.new()
	connections_title.text = _t("ui.town_map.connections")
	connections_title.add_theme_font_size_override("font_size", 11)
	connections_title.add_theme_color_override("font_color", Color("#65d7f3"))
	detail_column.add_child(connections_title)
	detail_connections_label = Label.new()
	detail_connections_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_connections_label.add_theme_font_size_override("font_size", 14)
	detail_connections_label.add_theme_color_override("font_color", Color("#e2e9ef"))
	detail_column.add_child(detail_connections_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_column.add_child(spacer)
	var legend := Label.new()
	legend.text = _t("ui.town_map.legend")
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.add_theme_font_size_override("font_size", 12)
	legend.add_theme_color_override("font_color", Color("#879cad"))
	detail_column.add_child(legend)
	_position_shell.call_deferred()


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
	detail_kind_label.text = _t(
		"ui.town_map.kind.%s" % str(location.get("kind", "route"))
	)
	detail_description_label.text = _t(str(location.get("descriptionKey", "")))
	var connected_names: Array[String] = []
	for path_value: Variant in region_data.get("paths", []):
		var endpoints := _path_endpoints(path_value)
		if endpoints.size() < 2:
			continue
		var from_id := endpoints[0]
		var to_id := endpoints[1]
		if from_id == location_id:
			connected_names.append(_location_name(to_id))
		elif to_id == location_id:
			connected_names.append(_location_name(from_id))
	detail_connections_label.text = " • " + "\n • ".join(connected_names)


func _location_name(location_id: String) -> String:
	var locations := region_data.get("locations", {}) as Dictionary
	var location := locations.get(location_id, {}) as Dictionary
	return _t(str(location.get("nameKey", "")))


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
