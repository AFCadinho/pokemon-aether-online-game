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
	_check(layout_points.size() == 21, "Every baked map circle has coordinates, alongside Route 1")
	_check((layout_data.get("routePoints", []) as Array).size() == 19, "Every baked yellow route section has a placeholder coordinate")
	_check((layout_points.get("kanto_map_point_02", {}) as Dictionary).get("name") == "Route 22", "Route 22 is placed west of Viridian City")
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
	for connection_value: Variant in layout_data.get("connections", []):
		var connection := connection_value as Dictionary
		var from_id := str(connection.get("from", ""))
		var to_id := str(connection.get("to", ""))
		_check(locations.has(from_id) and locations.has(to_id), "Town Map connection endpoints exist")
		_check(connection.get("waypoints", []) is Array, "Town Map connection accepts editable waypoints")

	var background_path := str(region_data.get("backgroundPath", ""))
	_check(ResourceLoader.exists(background_path), "Kanto Town Map background asset exists")
	var background := load(background_path) as Texture2D
	_check(background != null and background.get_width() == 400 and background.get_height() == 297, "Town Map uses the supplied 400x297 map image")

	var popup := POPUP_SCRIPT.new() as TownMapPopup
	var game_state := root.get_node_or_null("GameState")
	root.add_child(popup)
	await process_frame
	_check((popup.region_data.get("paths", []) as Array).size() == 5, "Editable connections are normalized for rendering")
	var popup_locations := popup.region_data.get("locations", {}) as Dictionary
	var planned_location_count := 0
	var planned_route_count := 0
	for location_value: Variant in popup_locations.values():
		if location_value is Dictionary and bool((location_value as Dictionary).get("planned", false)):
			planned_location_count += 1
	for location_id_value: Variant in popup_locations.keys():
		if str(location_id_value).begins_with("kanto_route_segment_"):
			planned_route_count += 1
	_check(popup_locations.size() == 40, "Town Map registers every configured point")
	_check(planned_location_count == 34, "Unnamed baked circles and route sections are planned points")
	_check(planned_route_count == 19, "Route placeholders are available alongside map points")
	popup.open_for_map("kanto_oaks_lab")
	await process_frame
	_check(popup.visible, "Town Map opens as a modal")
	_check(
		game_state != null and bool(game_state.call("is_overworld_input_locked")),
		"Town Map blocks overworld movement while open"
	)
	_check(popup.current_location_id == "kanto_pallet_town", "Interior maps resolve to their parent Town Map location")
	_check(popup.selected_location_id == "kanto_pallet_town", "Current location is selected when the map opens")
	_check(popup.map_canvas.marker_buttons.size() == popup_locations.size(), "Every Town Map location has an interactive marker")
	_check(popup.legend_kind_labels.size() == 4, "Town Map presents a structured location legend")
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
