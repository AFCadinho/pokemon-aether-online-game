extends SceneTree

const REGION_MAP_PATH := "res://data/region_maps/kanto.json"
const REGION_LAYOUT_PATH := "res://data/region_maps/kanto_layout.json"
const WORLD_ACCESS_PATH := "res://generated/world_access_catalog.json"
const POPUP_SCRIPT := preload("res://scripts/ui/town_map_popup.gd")

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var region_data := _load_json(REGION_MAP_PATH)
	var layout_data := _load_json(REGION_LAYOUT_PATH)
	var world_access := _load_json(WORLD_ACCESS_PATH)
	_check(not region_data.is_empty(), "Kanto Town Map presentation catalog loads")
	_check(not layout_data.is_empty(), "Editable Kanto Town Map point layout loads")
	_check(not world_access.is_empty(), "Town Map can resolve the world access catalog")
	if region_data.is_empty() or layout_data.is_empty() or world_access.is_empty():
		quit(1)
		return

	var locations := region_data.get("locations", {}) as Dictionary
	var coordinate_space := layout_data.get("coordinateSpace", {}) as Dictionary
	var layout_width := float(coordinate_space.get("width", 0.0))
	var layout_height := float(coordinate_space.get("height", 0.0))
	var layout_points := layout_data.get("points", {}) as Dictionary
	_check(layout_width > 0.0 and layout_height > 0.0, "Town Map layout has a human-friendly coordinate space")
	_check((layout_points.get("kanto_pallet_town", {}) as Dictionary).get("y") == 208, "Pallet Town uses its supplied-map circle")
	_check((layout_points.get("kanto_viridian_city", {}) as Dictionary).get("y") == 151, "Viridian City uses its supplied-map circle")
	_check((layout_points.get("kanto_pewter_city", {}) as Dictionary).get("y") == 70, "Pewter City uses its supplied-map circle")
	_check((layout_points.get("kanto_route_2", {}) as Dictionary).get("y") == 140, "Route 2 uses the yellow path north of Viridian City")
	_check((layout_points.get("kanto_viridian_forest", {}) as Dictionary).get("y") == 110, "Viridian Forest uses its light-blue special-location circle")
	_check(layout_points.size() == 23, "Every baked map circle and playable route has coordinates")
	var route_points := layout_data.get("routePoints", []) as Array
	_check(route_points.size() == 23, "Every Kanto route from Route 3 through Route 25 has a map coordinate")
	_check((layout_points.get("kanto_map_point_02", {}) as Dictionary).get("kind") == "special", "Light-blue map circles are special locations")
	_check((layout_points.get("kanto_map_point_08", {}) as Dictionary).get("name") == "Cerulean City", "Named settlement points use the supplied Kanto locations")
	_check((layout_points.get("kanto_map_point_11", {}) as Dictionary).get("name") == "Diglett's Cave (Route 11)", "Named special points use the supplied Kanto locations")
	_check((layout_points.get("kanto_map_point_16", {}) as Dictionary).get("kind") == "special", "The northern Diglett's Cave entrance is a special location")
	_check((layout_points.get("kanto_map_point_17", {}) as Dictionary).get("kind") == "special", "Viridian Forest Gate is a special location")
	var route_names: Dictionary = {}
	for route_point_value: Variant in route_points:
		var route_point := route_point_value as Dictionary
		route_names[str(route_point.get("name", ""))] = true
	_check(route_names.has("Route 3") and route_names.has("Route 25"), "Named routes cover the remaining classic Kanto route range")
	_check(route_names.has("Route 22"), "Route 22 uses its yellow path west of Viridian City")
	var areas := world_access.get("areas", {}) as Dictionary
	var location_groups: Dictionary = {}
	for area_value: Variant in areas.values():
		if area_value is Dictionary:
			location_groups[str((area_value as Dictionary).get("locationGroupId", ""))] = true
	_check(locations.size() == 6, "Town Map contains the currently playable Kanto location groups")
	for location_id_value: Variant in locations.keys():
		var location_id := str(location_id_value)
		_check(location_groups.has(location_id), "%s is backed by a playable world location" % location_id)
		var point := layout_points.get(location_id, {}) as Dictionary
		_check(
			float(point.get("x", -1.0)) >= 0.0
			and float(point.get("x", layout_width + 1.0)) <= layout_width
			and float(point.get("y", -1.0)) >= 0.0
			and float(point.get("y", layout_height + 1.0)) <= layout_height,
			"%s has editable map coordinates" % location_id
		)
	var configured_location_ids: Dictionary = {}
	for configured_id_value: Variant in locations.keys():
		configured_location_ids[str(configured_id_value)] = true
	for configured_id_value: Variant in layout_points.keys():
		configured_location_ids[str(configured_id_value)] = true
	for route_point_value: Variant in route_points:
		configured_location_ids[str((route_point_value as Dictionary).get("id", ""))] = true
	for connection_value: Variant in layout_data.get("connections", []):
		var connection := connection_value as Dictionary
		var from_id := str(connection.get("from", ""))
		var to_id := str(connection.get("to", ""))
		_check(configured_location_ids.has(from_id) and configured_location_ids.has(to_id), "Town Map connection endpoints exist")
		_check(connection.get("waypoints", []) is Array, "Town Map connection accepts editable waypoints")

	var background_path := str(region_data.get("backgroundPath", ""))
	_check(ResourceLoader.exists(background_path), "Kanto Town Map background asset exists")
	var background := load(background_path) as Texture2D
	_check(background != null and background.get_width() == 400 and background.get_height() == 297, "Town Map uses the supplied 400x297 map image")

	var popup := POPUP_SCRIPT.new() as TownMapPopup
	var game_state := root.get_node_or_null("GameState")
	root.add_child(popup)
	await process_frame
	_check((popup.region_data.get("paths", []) as Array).size() == 48, "The complete Kanto route network is normalized for navigation")
	var popup_locations := popup.region_data.get("locations", {}) as Dictionary
	var planned_location_count := 0
	var planned_route_count := 0
	for location_value: Variant in popup_locations.values():
		if location_value is Dictionary and bool((location_value as Dictionary).get("planned", false)):
			planned_location_count += 1
	for location_id_value: Variant in popup_locations.keys():
		if str(location_id_value).begins_with("kanto_route_segment_"):
			planned_route_count += 1
	_check(popup_locations.size() == 46, "Town Map registers every configured point")
	_check(planned_location_count == 40, "Future settlements, special locations, and routes are planned points")
	_check(planned_route_count == 23, "Named future routes are available alongside map points")
	var towns_without_interiors := 0
	for town_value: Variant in popup_locations.values():
		if town_value is Dictionary and str((town_value as Dictionary).get("kind", "")) in ["town", "city", "settlement"]:
			if ((town_value as Dictionary).get("interiors", []) as Array).is_empty():
				towns_without_interiors += 1
	_check(towns_without_interiors == 0, "Every town and city has data-driven interiors")
	var planned_without_description := 0
	for planned_location_value: Variant in popup_locations.values():
		if planned_location_value is Dictionary and bool((planned_location_value as Dictionary).get("planned", false)):
			if str((planned_location_value as Dictionary).get("description", "")).strip_edges() == "":
				planned_without_description += 1
	_check(planned_without_description == 0, "Every planned Town Map location has a description")
	popup.open_for_map("kanto_oaks_lab")
	await process_frame
	_check(popup.visible, "Town Map opens as a modal")
	_check(
		game_state != null and bool(game_state.call("is_overworld_input_locked")),
		"Town Map blocks overworld movement while open"
	)
	_check(popup.current_location_id == "kanto_pallet_town", "Interior maps resolve to their parent Town Map location")
	_check(popup.selected_location_id == "kanto_pallet_town", "Current location is selected when the map opens")
	_check(popup.detail_name_label.size.x > 0.0, "Current location details use the full sidebar width without a duplicate portrait")
	_check(popup.detail_interiors_container.get_child_count() == 3, "Pallet Town interiors come from the world access catalog")
	_check(popup.detail_interiors_container.get_child(0) is Label, "Interiors are displayed separately from route navigation")
	popup._refresh_details("kanto_pewter_city")
	_check(popup.detail_interiors_container.get_child_count() == 1, "Pewter City only lists its accessible interior")
	var pewter_connections: Array[String] = []
	for connection_control: Control in popup.detail_connections_container.get_children():
		if connection_control is Button:
			pewter_connections.append((connection_control as Button).text)
	_check(
		pewter_connections.size() == 2
		and pewter_connections.any(func(text: String) -> bool: return text.contains("Route 2"))
		and pewter_connections.any(func(text: String) -> bool: return text.contains("Route 3")),
		"Pewter City is connected to Route 2 and Route 3"
	)
	popup._refresh_details("kanto_viridian_city")
	var viridian_connections: Array[String] = []
	for connection_control: Control in popup.detail_connections_container.get_children():
		if connection_control is Button:
			viridian_connections.append((connection_control as Button).text)
	_check(
		viridian_connections.size() == 3
		and viridian_connections.any(func(text: String) -> bool: return text.contains("Route 1"))
		and viridian_connections.any(func(text: String) -> bool: return text.contains("Route 2"))
		and viridian_connections.any(func(text: String) -> bool: return text.contains("Route 22")),
		"Viridian City is connected to Route 1, Route 2, and Route 22"
	)
	popup._refresh_details("kanto_pallet_town")
	_check(popup.map_canvas.marker_buttons.size() == popup_locations.size(), "Every Town Map location has an interactive marker")
	var hover_marker := popup.map_canvas.marker_buttons.get("kanto_pewter_city") as Button
	hover_marker.mouse_entered.emit()
	_check(popup.map_canvas.hovered_location_id == "kanto_pewter_city", "Town Map hotspots expose a visible hover state")
	hover_marker.mouse_exited.emit()
	_check(popup.map_canvas.hovered_location_id == "", "Town Map hover state clears when leaving a hotspot")
	popup._refresh_details("kanto_route_segment_03")
	_check(popup.detail_description_label.text != "", "Planned route descriptions appear in the detail panel")
	popup._refresh_details("kanto_pallet_town")
	_check(popup.legend_kind_labels.size() == 3, "Town Map distinguishes settlements, routes, and special locations")
	_check(
		popup.detail_connections_container.get_child_count() > 0
		and popup.detail_connections_container.get_child(0) is Button,
		"Connected locations are directly navigable from the detail card"
	)
	_check(not popup.map_canvas.show_connection_overlay, "Baked route lines are not drawn a second time")
	_check(not popup.map_canvas.show_marker_overlay, "Baked map circles use invisible interactive hotspots")
	popup.close()
	_check(not popup.visible, "Town Map can be closed")
	_check(
		game_state != null and not bool(game_state.call("is_overworld_input_locked")),
		"Town Map restores overworld movement when closed"
	)
	popup.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failed = true
	push_error("FAIL: %s" % message)
