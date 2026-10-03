extends SceneTree

const REGION_MAP_PATH := "res://data/region_maps/kanto.json"
const REGION_LAYOUT_PATH := "res://data/region_maps/kanto_layout.json"
const WORLD_ACCESS_PATH := "res://generated/world_access_catalog.json"
const POPUP_SCRIPT := preload("res://scripts/ui/town_map_popup.gd")
const PREVIEW_CATALOG := preload("res://scripts/services/town_map_preview_catalog.gd")
const SIGN_PORTRAIT_CATALOG := preload("res://scripts/services/sign_portrait_catalog.gd")

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
	_check((layout_points.get("kanto_pallet_town", {}) as Dictionary).get("y") == 752, "Pallet Town uses its supplied-map circle")
	_check((layout_points.get("kanto_viridian_city", {}) as Dictionary).get("y") == 532, "Viridian City uses its supplied-map circle")
	_check((layout_points.get("kanto_pewter_city", {}) as Dictionary).get("y") == 250, "Pewter City uses its supplied-map circle")
	_check((layout_points.get("kanto_route_2", {}) as Dictionary).get("y") == 488, "Route 2 uses the yellow path north of Viridian City")
	_check((layout_points.get("kanto_viridian_forest", {}) as Dictionary).get("y") == 392, "Viridian Forest uses its light-blue special-location circle")
	_check(layout_points.size() == 24, "Every baked map circle and playable route has coordinates")
	var route_points := layout_data.get("routePoints", []) as Array
	_check(route_points.size() == 23, "Every Kanto route from Route 3 through Route 25 has a map coordinate")
	_check((layout_points.get("kanto_map_point_02", {}) as Dictionary).get("kind") == "special", "Light-blue map circles are special locations")
	_check((layout_points.get("kanto_cerulean_city", {}) as Dictionary).get("name") == "Cerulean City", "Cerulean City uses its playable map point")
	_check((layout_points.get("kanto_map_point_11", {}) as Dictionary).get("name") == "Diglett's Cave (Route 11)", "Named special points use the supplied Kanto locations")
	_check((layout_points.get("kanto_map_point_16", {}) as Dictionary).get("kind") == "special", "The northern Diglett's Cave entrance is a special location")
	_check((layout_points.get("kanto_map_point_17", {}) as Dictionary).get("kind") == "special", "Viridian Forest Gate is a special location")
	var route_names: Dictionary = {}
	var route_layout_points: Dictionary = {}
	for route_point_value: Variant in route_points:
		var route_point := route_point_value as Dictionary
		route_names[str(route_point.get("name", ""))] = true
		route_layout_points[str(route_point.get("id", ""))] = route_point
	_check(route_names.has("Route 3") and route_names.has("Route 25"), "Named routes cover the remaining classic Kanto route range")
	_check(route_names.has("Route 22"), "Route 22 uses its yellow path west of Viridian City")
	var areas := world_access.get("areas", {}) as Dictionary
	var location_groups: Dictionary = {}
	for area_value: Variant in areas.values():
		if area_value is Dictionary:
			location_groups[str((area_value as Dictionary).get("locationGroupId", ""))] = true
	_check(locations.size() == 10, "Town Map contains the currently playable Kanto location groups")
	for location_id_value: Variant in locations.keys():
		var location_id := str(location_id_value)
		_check(location_groups.has(location_id), "%s is backed by a playable world location" % location_id)
		var point := layout_points.get(location_id, route_layout_points.get(location_id, {})) as Dictionary
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
	_check(background != null and background.get_width() == 1453 and background.get_height() == 1082, "Town Map uses the approved full-resolution illustrated map")

	var background_image := background.get_image()
	for point_id_value: Variant in layout_points.keys():
		var point_id := str(point_id_value)
		var point := layout_points[point_id] as Dictionary
		if bool(point.get("markerOverlay", false)):
			continue
		var pixel := background_image.get_pixel(int(point["x"]), int(point["y"]))
		_check(_is_map_network_color(pixel), "%s is centered on the painted map network" % point_id)
	for route_value: Variant in route_points:
		var point := route_value as Dictionary
		var pixel := background_image.get_pixel(int(point["x"]), int(point["y"]))
		_check(_is_gold(pixel), "%s is on its painted golden route" % str(point["name"]))

	_check(PREVIEW_CATALOG.portrait_cache.is_empty(), "New preview textures are not loaded before selecting a location")
	var popup := POPUP_SCRIPT.new() as TownMapPopup
	var game_state := root.get_node_or_null("GameState")
	root.add_child(popup)
	await process_frame
	_check((popup.region_data.get("paths", []) as Array).size() == 49, "The complete Kanto route network is normalized for navigation")
	var popup_locations := popup.region_data.get("locations", {}) as Dictionary
	var planned_location_count := 0
	var planned_route_count := 0
	for location_value: Variant in popup_locations.values():
		if location_value is Dictionary and bool((location_value as Dictionary).get("planned", false)):
			planned_location_count += 1
	for location_id_value: Variant in popup_locations.keys():
		if str(location_id_value).begins_with("kanto_route_segment_"):
			planned_route_count += 1
	_check(popup_locations.size() == 47, "Town Map registers every configured point")
	var expected_planned_count := 0
	for point_id_value: Variant in configured_location_ids.keys():
		var point_id := str(point_id_value)
		var point := layout_points.get(point_id, route_layout_points.get(point_id, {})) as Dictionary
		var point_groups: Array = [point_id]
		point_groups.append_array(point.get("locationGroupIds", []) as Array)
		var playable := false
		for area_id_value: Variant in areas.keys():
			var area_id := str(area_id_value)
			var area := areas[area_id] as Dictionary
			if bool(area.get("accessOnly", false)) or str(area.get("scenePath", "")).is_empty():
				continue
			if point_groups.has(str(area.get("locationGroupId", ""))) or (point.get("mapIds", []) as Array).has(area_id):
				playable = true
		if not playable:
			expected_planned_count += 1
	_check(planned_location_count == expected_planned_count, "Only unavailable locations remain planned points")
	_check(planned_route_count == 20, "Named remaining route points are available alongside playable Route 13")
	_check(not bool((popup_locations.get("kanto_route_4", {}) as Dictionary).get("planned", false)), "Route 4 is available as a playable route")
	_check(not bool((popup_locations.get("kanto_cerulean_city", {}) as Dictionary).get("planned", false)), "Cerulean City is available as a playable city")
	for route_value: Variant in route_points:
		var route := route_value as Dictionary
		var route_id := str(route["id"])
		var position := (popup_locations[route_id] as Dictionary)["position"] as Dictionary
		_check(
			is_equal_approx(float(position["x"]), float(route["x"]) / layout_width)
			and is_equal_approx(float(position["y"]), float(route["y"]) / layout_height),
			"%s keeps its layout position when already registered or reopened" % str(route["name"])
		)
	for point_id_value: Variant in configured_location_ids.keys():
		var point_id := str(point_id_value)
		var point := layout_points.get(point_id, route_layout_points.get(point_id, {})) as Dictionary
		for group_id_value: Variant in point.get("locationGroupIds", []):
			var group_id := str(group_id_value)
			_check(popup._resolve_location_group(group_id) == point_id, "%s resolves to its map point" % group_id)
		for map_id_value: Variant in point.get("mapIds", []):
			var map_id := str(map_id_value)
			_check(popup._resolve_location_group(map_id) == point_id, "%s selects its specific entrance" % map_id)
	for area_id_value: Variant in areas.keys():
		var area_id := str(area_id_value)
		var area := areas[area_id] as Dictionary
		if str(area.get("regionName", "")) != "Kanto" or bool(area.get("accessOnly", false)) or str(area.get("scenePath", "")).is_empty():
			continue
		_check(popup_locations.has(popup._resolve_location_group(area_id)), "%s has a current-location map point" % area_id)
	_check(popup._resolve_location_group("kanto_ss_anne_b1f") == "kanto_map_point_10", "S.S. Anne decks resolve to Vermilion Harbor")
	_check(popup._resolve_location_group("kanto_underground_path_route_6_entrance") == "kanto_route_segment_06", "The south Underground Path entrance resolves to Route 6")
	popup._apply_layout()
	_check((popup.layout_data.get("points", {}) as Dictionary).size() == 24, "Applying the layout leaves source points separate from route points")
	_check(popup._resolve_location_group("kanto_mt_moon_b2f") == "kanto_map_point_05", "Cave floors resolve to their illustrated entrance")
	_check(popup._resolve_location_group("kanto_saffron_city_north") == "kanto_route_segment_05", "The north Saffron connector belongs to Route 5")
	_check(popup._resolve_location_group("kanto_saffron_city_south") == "kanto_route_segment_06", "The south Saffron connector belongs to Route 6")
	_check(not bool((popup_locations["kanto_map_point_14"] as Dictionary)["planned"]), "Playable Lavender Town is recognized automatically")
	_check((popup_locations["kanto_map_point_09"] as Dictionary)["interiors"].size() > 0, "Playable aliased cities use their world-catalog interiors")

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
	_check(popup.detail_preview_panel.visible, "The selected location has a framed preview")
	_check(
		popup.detail_preview_image.texture == SIGN_PORTRAIT_CATALOG.get_portrait("kanto_pallet_town_town_sign"),
		"Pallet Town shares its exact overworld-sign illustration"
	)
	_check(popup.detail_preview_image.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "Preview pictures fill their frame without distortion")
	_check(PREVIEW_CATALOG.portrait_cache.is_empty(), "Opening at an existing sign image does not load new illustrations")
	var preview_paths: Dictionary = {}
	for preview_id_value: Variant in popup_locations.keys():
		var preview_id := str(preview_id_value)
		var preview_path := PREVIEW_CATALOG.get_portrait_path(preview_id)
		_check(not preview_path.is_empty() and ResourceLoader.exists(preview_path, "Texture2D"), "%s has a bundled preview illustration" % preview_id)
		_check(not preview_paths.has(preview_path), "%s has its own location illustration" % preview_id)
		preview_paths[preview_path] = true
		popup._refresh_details(preview_id)
		_check(popup.detail_preview_image.texture != null and popup.detail_preview_panel.visible, "%s updates the visible preview" % preview_id)
		if PREVIEW_CATALOG.LOCATION_PORTRAIT_PATHS.has(preview_id) and popup.detail_preview_image.texture != null:
			var preview := popup.detail_preview_image.texture
			_check(preview.get_width() <= 512 and preview.get_height() <= 512, "%s uses a compact imported preview texture" % preview_id)
		_check(popup.current_location_id == "kanto_pallet_town", "Browsing previews preserves the player's actual position")
	_check(PREVIEW_CATALOG.get_portrait("unknown_location") == null, "Unknown locations fail without stale or unrelated artwork")
	popup._refresh_location_preview("unknown_location")
	_check(popup.detail_preview_image.texture == null and not popup.detail_preview_panel.visible, "Unknown locations clear and hide the previous picture")
	popup.map_canvas.marker_buttons["kanto_route_segment_12"].pressed.emit()
	_check(popup.selected_location_id == "kanto_route_segment_12", "Clicking a map marker selects its preview")
	_check(popup.detail_preview_image.texture == PREVIEW_CATALOG.get_portrait("kanto_route_segment_12"), "A marker click loads the matching location picture")
	popup.refresh_localized_ui()
	_check(popup.detail_preview_image.texture == PREVIEW_CATALOG.get_portrait("kanto_route_segment_12"), "Refreshing localization preserves the selected preview")
	_check(popup.detail_preview_panel.tooltip_text == popup._location_name("kanto_route_segment_12"), "Preview tooltip follows the localized location name")
	popup._refresh_details("kanto_pallet_town")
	_check(popup.detail_name_label.size.x > 0.0, "Current location heading uses the available sidebar width")
	_check(popup.detail_name_label.get_parent() is HBoxContainer, "Location name and kind badge share one heading row")
	_check(popup.detail_name_label.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "Location name expands across the available heading width")
	_check(popup.detail_kind_panel.get_parent() == popup.detail_name_label.get_parent(), "Location kind badge stays beside the location name")
	_check(popup.detail_description_label.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "Location description fills the detail card width")
	_check(popup.detail_description_label.size.x >= 220.0, "Location description uses the wide sidebar instead of its minimum text width")
	_check(popup.detail_interiors_container.columns == 2, "Town Map interiors use a compact two-column grid")
	_check(popup.detail_connections_container.columns == 2, "Connected locations use a two-column navigation grid")
	_check(popup.detail_interiors_container.get_child_count() == 3, "Pallet Town interiors come from the world access catalog")
	var first_interior := popup.detail_interiors_container.get_child(0) as HBoxContainer
	_check(first_interior != null, "Interiors are displayed separately from route navigation")
	_check(
		first_interior != null
		and first_interior.get_child_count() == 2
		and first_interior.get_child(0) is TextureRect
		and (first_interior.get_child(0) as TextureRect).texture != null,
		"Town Map interiors use a browser-safe icon"
	)
	popup._refresh_details("kanto_pewter_city")
	_check(popup.detail_interiors_container.get_child_count() == 4, "Pewter City lists all accessible interiors")
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
	popup._refresh_details("kanto_route_segment_07")
	_check(popup.detail_description_label.text != "", "Planned route descriptions appear in the detail panel")
	popup._refresh_details("kanto_pallet_town")
	_check(popup.legend_kind_labels.size() == 3, "Town Map distinguishes settlements, routes, and special locations")
	_check(popup.legend_kind_icons.size() == 3, "Every Town Map legend category has an icon")
	for legend_icon_value: Variant in popup.legend_kind_icons.values():
		var legend_icon := legend_icon_value as TextureRect
		_check(legend_icon != null and legend_icon.texture != null, "Town Map legend icon is browser-safe")
	var current_icon := popup.current_location_chip.find_child("CurrentLocationIcon", true, false) as TextureRect
	_check(current_icon != null and current_icon.texture != null, "Current Town Map location uses a browser-safe icon")
	_check(
		popup.detail_connections_container.get_child_count() > 0
		and popup.detail_connections_container.get_child(0) is Button,
		"Connected locations are directly navigable from the detail card"
	)
	_check(
		(popup.detail_connections_container.get_child(0) as Button).size_flags_horizontal == Control.SIZE_EXPAND_FILL,
		"Connected-location buttons fill their grid cells"
	)
	_check(
		(popup.detail_connections_container.get_child(0) as Button).icon != null,
		"Connected-location buttons use a browser-safe icon"
	)
	(popup.detail_connections_container.get_child(0) as Button).pressed.emit()
	_check(popup.selected_location_id == "kanto_route_1", "Connected-location navigation selects Route 1 from Pallet Town")
	_check(popup.detail_preview_image.texture == PREVIEW_CATALOG.get_portrait("kanto_route_1"), "Connected-location navigation refreshes its illustration")
	_check(not popup.map_canvas.show_connection_overlay, "Baked route lines are not drawn a second time")
	_check(not popup.map_canvas.show_marker_overlay, "Baked map circles use invisible interactive hotspots")
	for map_id: String in ["kanto_route_3", "kanto_route_4", "kanto_route_5", "kanto_route_10", "kanto_route_21", "kanto_route_25", "kanto_route_12_west", "kanto_route_13", "kanto_lavender_town", "kanto_cerulean_cave_b1f"]:
		popup.open_for_map(map_id)
		_check(popup.current_location_id != "", "%s shows the current location" % map_id)
		_check(popup.map_canvas.current_location_portrait.visible, "%s shows the current portrait" % map_id)
	for canvas_size: Vector2 in [Vector2(800, 600), Vector2(800, 400), Vector2(400, 600)]:
		popup.map_canvas.size = canvas_size
		popup.map_canvas._position_markers()
		var map_rect := popup.map_canvas._map_rect()
		_check(is_equal_approx(map_rect.size.x / map_rect.size.y, 1453.0 / 1082.0), "Resizing keeps the approved map aspect ratio")
		for point_id_value: Variant in popup_locations.keys():
			var point_id := str(point_id_value)
			var position := (popup_locations[point_id] as Dictionary)["position"] as Dictionary
			var expected := map_rect.position + Vector2(float(position["x"]) * map_rect.size.x, float(position["y"]) * map_rect.size.y)
			var marker := popup.map_canvas.marker_buttons[point_id] as Button
			_check((marker.position + marker.size * 0.5).is_equal_approx(expected), "%s keeps its hotspot centered after resizing" % point_id)
		var ids := popup.map_canvas.marker_buttons.keys()
		var overlapping_pairs: Array[String] = []
		for i in range(ids.size()):
			for j in range(i + 1, ids.size()):
				var first := popup.map_canvas.marker_buttons[ids[i]] as Button
				var second := popup.map_canvas.marker_buttons[ids[j]] as Button
				if first.get_rect().intersects(second.get_rect()):
					overlapping_pairs.append("%s / %s" % [ids[i], ids[j]])
		_check(overlapping_pairs.is_empty(), "Hotspots remain separately clickable: %s" % str(overlapping_pairs))
		for path_value: Variant in popup.region_data.get("paths", []):
			var path := path_value as Dictionary
			var screen_points := popup.map_canvas._path_points(path)
			var waypoints := path["waypoints"] as Array
			for i in range(waypoints.size()):
				var waypoint := waypoints[i] as Dictionary
				var expected := map_rect.position + Vector2(float(waypoint["x"]) * map_rect.size.x, float(waypoint["y"]) * map_rect.size.y)
				_check(screen_points[i + 1].is_equal_approx(expected), "Route bends follow the map after resizing")

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


func _is_gold(pixel: Color) -> bool:
	return pixel.r > 0.75 and pixel.g > 0.65 and pixel.b < 0.45


func _is_map_network_color(pixel: Color) -> bool:
	return _is_gold(pixel) or (pixel.b > 0.45 and pixel.r < 0.4 and pixel.g < 0.7)
