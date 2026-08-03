extends SceneTree

const REGION_MAP_PATH := "res://data/region_maps/kanto.json"
const WORLD_ACCESS_PATH := "res://generated/world_access_catalog.json"
const POPUP_SCRIPT := preload("res://scripts/ui/town_map_popup.gd")

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var region_data := _load_json(REGION_MAP_PATH)
	var world_access := _load_json(WORLD_ACCESS_PATH)
	_check(not region_data.is_empty(), "Kanto Town Map presentation catalog loads")
	_check(not world_access.is_empty(), "Town Map can resolve the world access catalog")
	if region_data.is_empty() or world_access.is_empty():
		quit(1)
		return

	var locations := region_data.get("locations", {}) as Dictionary
	var areas := world_access.get("areas", {}) as Dictionary
	var location_groups: Dictionary = {}
	for area_value: Variant in areas.values():
		if area_value is Dictionary:
			location_groups[str((area_value as Dictionary).get("locationGroupId", ""))] = true
	_check(locations.size() == 6, "Town Map contains the currently playable Kanto location groups")
	for location_id_value: Variant in locations.keys():
		var location_id := str(location_id_value)
		var location := locations.get(location_id, {}) as Dictionary
		_check(location_groups.has(location_id), "%s is backed by a playable world location" % location_id)
		var position := location.get("position", {}) as Dictionary
		_check(
			float(position.get("x", -1.0)) >= 0.0
			and float(position.get("x", 2.0)) <= 1.0
			and float(position.get("y", -1.0)) >= 0.0
			and float(position.get("y", 2.0)) <= 1.0,
			"%s has normalized map coordinates" % location_id
		)
	for path_value: Variant in region_data.get("paths", []):
		var path := path_value as Array
		_check(path.size() == 2, "Town Map path has two endpoints")
		if path.size() == 2:
			_check(locations.has(str(path[0])) and locations.has(str(path[1])), "Town Map path endpoints exist")

	var background_path := str(region_data.get("backgroundPath", ""))
	_check(ResourceLoader.exists(background_path), "Kanto Town Map background asset exists")

	var popup := POPUP_SCRIPT.new() as TownMapPopup
	root.add_child(popup)
	await process_frame
	popup.open_for_map("kanto_oaks_lab")
	await process_frame
	_check(popup.visible, "Town Map opens as a modal")
	_check(popup.current_location_id == "kanto_pallet_town", "Interior maps resolve to their parent Town Map location")
	_check(popup.selected_location_id == "kanto_pallet_town", "Current location is selected when the map opens")
	_check(popup.map_canvas.marker_buttons.size() == locations.size(), "Every Town Map location has an interactive marker")
	popup.close()
	_check(not popup.visible, "Town Map can be closed")
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
