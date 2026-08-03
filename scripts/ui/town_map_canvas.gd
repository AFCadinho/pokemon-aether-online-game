extends Control

class_name TownMapCanvas

signal location_selected(location_id: String)

const MARKER_SIZE := Vector2(22.0, 22.0)
const PATH_SHADOW := Color("#06111dcc")
const PATH_COLOR := Color("#63d7f5e8")
const PATH_HIGHLIGHT := Color("#f3cc69")

var locations: Dictionary = {}
var paths: Array = []
var current_location_id := ""
var selected_location_id := ""
var marker_buttons: Dictionary = {}
var background_texture: Texture2D


func configure(map_locations: Dictionary, map_paths: Array) -> void:
	locations = map_locations.duplicate(true)
	paths = map_paths.duplicate(true)
	_build_markers()
	queue_redraw()


func set_background(texture: Texture2D) -> void:
	background_texture = texture
	queue_redraw()


func set_current_location(location_id: String) -> void:
	current_location_id = location_id
	_refresh_markers()
	queue_redraw()


func select_location(location_id: String) -> void:
	if not locations.has(location_id):
		return
	selected_location_id = location_id
	_refresh_markers()
	queue_redraw()


func _ready() -> void:
	resized.connect(_position_markers)
	set_process(true)


func _process(_delta: float) -> void:
	if current_location_id != "" and is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	if background_texture != null:
		draw_texture_rect(background_texture, Rect2(Vector2.ZERO, size), false)
	for path_value: Variant in paths:
		if not path_value is Array or (path_value as Array).size() < 2:
			continue
		var path := path_value as Array
		var from_id := str(path[0])
		var to_id := str(path[1])
		if not locations.has(from_id) or not locations.has(to_id):
			continue
		var from_point := _location_point(from_id)
		var to_point := _location_point(to_id)
		draw_line(from_point, to_point, PATH_SHADOW, 8.0, true)
		var is_selected_path := from_id == selected_location_id or to_id == selected_location_id
		draw_line(
			from_point,
			to_point,
			PATH_HIGHLIGHT if is_selected_path else PATH_COLOR,
			4.0,
			true
		)

	if current_location_id != "" and locations.has(current_location_id):
		var pulse := (sin(Time.get_ticks_msec() / 180.0) + 1.0) * 0.5
		var center := _location_point(current_location_id)
		draw_circle(center, 15.0 + pulse * 5.0, Color(0.35, 0.86, 1.0, 0.2 - pulse * 0.08))
		draw_arc(center, 14.0 + pulse * 5.0, 0.0, TAU, 32, Color("#8ceaff"), 2.0, true)


func _build_markers() -> void:
	for marker_value: Variant in marker_buttons.values():
		var marker := marker_value as Button
		if marker != null:
			marker.queue_free()
	marker_buttons.clear()

	for location_id_value: Variant in locations.keys():
		var location_id := str(location_id_value)
		var location := locations.get(location_id, {}) as Dictionary
		var marker := Button.new()
		marker.name = "Marker_%s" % location_id
		marker.custom_minimum_size = MARKER_SIZE
		marker.size = MARKER_SIZE
		marker.focus_mode = Control.FOCUS_NONE
		marker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		marker.tooltip_text = _t(str(location.get("nameKey", "")))
		marker.add_theme_stylebox_override("normal", _marker_style(location, false, false))
		marker.add_theme_stylebox_override("hover", _marker_style(location, true, false))
		marker.add_theme_stylebox_override("pressed", _marker_style(location, true, true))
		marker.pressed.connect(_on_marker_pressed.bind(location_id))
		add_child(marker)
		marker_buttons[location_id] = marker
	_position_markers.call_deferred()


func _refresh_markers() -> void:
	for location_id_value: Variant in marker_buttons.keys():
		var location_id := str(location_id_value)
		var marker := marker_buttons.get(location_id) as Button
		if marker == null:
			continue
		var location := locations.get(location_id, {}) as Dictionary
		var selected := location_id == selected_location_id
		var current := location_id == current_location_id
		marker.add_theme_stylebox_override("normal", _marker_style(location, selected, current))
		marker.add_theme_stylebox_override("hover", _marker_style(location, true, current))
		marker.add_theme_stylebox_override("pressed", _marker_style(location, true, true))


func _position_markers() -> void:
	for location_id_value: Variant in marker_buttons.keys():
		var location_id := str(location_id_value)
		var marker := marker_buttons.get(location_id) as Button
		if marker == null:
			continue
		marker.position = _location_point(location_id) - MARKER_SIZE * 0.5


func _location_point(location_id: String) -> Vector2:
	var location := locations.get(location_id, {}) as Dictionary
	var position_value: Variant = location.get("position", {})
	if not position_value is Dictionary:
		return size * 0.5
	var normalized := position_value as Dictionary
	return Vector2(
		float(normalized.get("x", 0.5)) * size.x,
		float(normalized.get("y", 0.5)) * size.y
	)


func _marker_style(location: Dictionary, highlighted: bool, current: bool) -> StyleBoxFlat:
	var kind := str(location.get("kind", "route"))
	var color := Color("#65d8f4")
	if kind in ["town", "city"]:
		color = Color("#f1c85d")
	elif kind == "wilderness":
		color = Color("#69d69b")
	var style := StyleBoxFlat.new()
	style.bg_color = color.lightened(0.14) if highlighted else color
	style.border_color = Color("#e9f8ff") if current else Color("#07111f")
	style.set_border_width_all(3 if current else 2)
	style.set_corner_radius_all(11)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	style.shadow_size = 5 if highlighted or current else 3
	return style


func _on_marker_pressed(location_id: String) -> void:
	select_location(location_id)
	location_selected.emit(location_id)


func _t(key: String) -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null and localization_manager.has_method("text"):
		return str(localization_manager.call("text", key))
	return key
